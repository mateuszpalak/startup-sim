//! Server internals that the end-to-end tests can't reach cheaply.

use std::collections::HashSet;
use std::net::{Ipv4Addr, SocketAddr};
use std::time::Instant;

use super::items::DROP_HANDLE_BASE;
use super::player::{Player, Stage, Talk};
use super::{Config, Server};
use crate::board::{self, Meeting};
use crate::building::{default_building_path, Building};
use crate::inventory::kind as item_kind;
use crate::npc::NPC_ID_BASE;
use crate::protocol::{container, Packet, Profile};
use crate::recruitment::{default_recruitment_path, Recruitment};
use crate::sim::{Body, Pos};

fn server() -> Server {
    let building = Building::load(&default_building_path()).unwrap();
    let recruitment = Recruitment::load(&default_recruitment_path()).unwrap();
    let cfg = Config::new(SocketAddr::from((Ipv4Addr::LOCALHOST, 0)), recruitment);
    Server::new(building, cfg).unwrap()
}

/// A player standing in the building (no real client behind the address).
fn add_player(s: &mut Server, id: u16) {
    let addr = SocketAddr::from((Ipv4Addr::LOCALHOST, 9));
    let body = Body::at(0, Pos::tile_center(5, 5));
    let p = Player::new(id, u32::from(id), 0, addr, format!("p{id}"), Profile::default(), Stage::Working, body, Instant::now());
    s.players.insert(id, p);
}

#[test]
fn floor_items_are_capped_and_handles_stay_unique() {
    let mut s = server();
    for _ in 0..3000 {
        let item = s.mint_item(item_kind::FRUIT, "Jabłko");
        s.drop_at(0, Pos::tile_center(5, 5), item);
    }
    assert!(s.dropped.len() <= 1024, "{} items on the floor", s.dropped.len());
    let handles: HashSet<u16> = s.dropped.iter().map(|d| d.handle).collect();
    assert_eq!(handles.len(), s.dropped.len(), "duplicate entity handles");
    assert!(handles.iter().all(|h| (DROP_HANDLE_BASE..NPC_ID_BASE).contains(h)));
}

#[test]
fn player_ids_never_enter_the_entity_handle_range() {
    let mut s = server();
    s.next_id = DROP_HANDLE_BASE - 1;
    assert_eq!(s.alloc_id(), DROP_HANDLE_BASE - 1);
    assert_eq!(s.alloc_id(), 1, "ids wrap before the item handles");
}

#[test]
fn a_conversation_survives_other_meetings_going_away() {
    let mut s = server();
    let (me, other) = (1, 2);
    add_player(&mut s, me);
    add_player(&mut s, other);
    let day = s.clock.day;
    let meeting = |owner, start, state| Meeting { day, start, owner, topic: board::topic::RAISE, state };
    s.meetings.push(meeting(other, 13 * 60, board::State::Booked));
    s.meetings.push(meeting(me, 14 * 60, board::State::Talking(0)));
    let npc = s.npcs.first().map_or(NPC_ID_BASE, |n| n.id);
    s.players.get_mut(&me).unwrap().talk = Some(Talk { day, start: 14 * 60, npc, id: 1, good: 0 });

    // The other booking is cancelled mid-conversation: the list shifts.
    s.meetings.retain(|m| m.owner != other);

    assert!(matches!(s.dialog_packet(me), Some(Packet::Dialog { id: 1, .. })));
    s.end_talk(me, None);
    assert_eq!(s.meetings[0].state, board::State::Done);
    assert!(s.players[&me].talk.is_none());
}

#[test]
fn company_actions_ignore_offer_ids_that_do_not_fit_a_byte() {
    let mut s = server();
    let before = s.positions.clone();
    // 256 would wrap to offer 0 with an `as u8` cast.
    s.company_set_places(256, 3);
    assert_eq!(s.positions, before);
}

#[test]
fn an_accident_leaves_a_puddle_until_the_office_closes() {
    let mut s = server();
    add_player(&mut s, 1);
    let at = Pos::tile_center(5, 5);
    s.players.get_mut(&1).unwrap().needs.bladder = crate::needs::MAX - 1;
    let mut steps = s.simulate_players();
    s.react_to_steps(&mut steps);
    assert_eq!(s.puddles.len(), 1, "a puddle where it happened");
    assert_eq!((s.puddles[0].floor, s.puddles[0].pos), (0, at));
    assert!((DROP_HANDLE_BASE..NPC_ID_BASE).contains(&s.puddles[0].handle));
    // Still there in the evening, gone once the office closes.
    s.clock.ds = (crate::clock::CLOSE_MIN - 1) * crate::clock::DS_PER_MIN;
    s.tick_clock();
    assert_eq!(s.puddles.len(), 1);
    while s.clock.minute() != crate::clock::CLOSE_MIN {
        s.tick_clock();
    }
    assert!(s.puddles.is_empty(), "mopped up at 22:00");
}

#[test]
fn puddles_are_capped_and_never_share_a_handle() {
    let mut s = server();
    for _ in 0..1000 {
        s.leave_puddle(0, Pos::tile_center(5, 5), crate::protocol::puddle::PEE);
        let item = s.mint_item(item_kind::FRUIT, "Jabłko");
        s.drop_at(0, Pos::tile_center(5, 5), item);
    }
    assert!(s.puddles.len() <= 256, "{} puddles", s.puddles.len());
    let handles: HashSet<u16> = s.puddles.iter().map(|p| p.handle).chain(s.dropped.iter().map(|d| d.handle)).collect();
    assert_eq!(handles.len(), s.puddles.len() + s.dropped.len(), "duplicate entity handles");
}

#[test]
fn the_cleaner_mops_up_a_puddle_on_her_round() {
    let mut s = server();
    s.cfg.cleaning_at = 10 * 60;
    s.cfg.cleaning_spread = 0;
    s.clock.ds = 10 * 60 * crate::clock::DS_PER_MIN;
    let ws = crate::computer::find_workstations(&s.building);
    let w = ws.iter().find(|w| w.department == 1).unwrap();
    s.leave_puddle(w.floor, Pos::tile_center(w.tile.x, w.tile.y + 1), crate::protocol::puddle::PEE);
    let mut said = false;
    for _ in 0..20 * 120 {
        s.tick += 1;
        s.tick_cleaning();
        let events = s.tick_npcs();
        s.apply_npc_events(events);
        said |= s.says.iter().any(|l| l.text == crate::cleaning::lines::PUDDLE);
        s.says.clear();
        if s.puddles.is_empty() {
            break;
        }
    }
    assert!(s.puddles.is_empty(), "the puddle is mopped up");
    assert!(said, "and she has a word about it");
}

/// A beer (or another drink) in hands, then F.
fn drink(s: &mut Server, id: u16, kind: u8) {
    let item = s.mint_item(kind, "test");
    s.players.get_mut(&id).unwrap().inventory.hands = Some(item);
    s.use_held(id);
}

#[test]
fn five_beers_throw_up_and_more_puts_you_to_sleep() {
    use crate::protocol::{activity, sound};
    let mut s = server();
    add_player(&mut s, 1);
    for _ in 0..4 {
        drink(&mut s, 1, item_kind::BEER);
    }
    assert!(s.puddles.is_empty(), "four beers: still standing");
    assert!(s.sounds.iter().any(|x| x.0 == sound::BURP), "a burp after a beer");
    assert_eq!(s.players[&1].needs.alcohol_points(), 60);
    drink(&mut s, 1, item_kind::BEER);
    assert_eq!(s.puddles.len(), 1, "the fifth: thrown up");
    assert_eq!(s.puddles[0].kind, crate::protocol::puddle::VOMIT);
    assert!(s.sounds.iter().any(|x| x.0 == sound::VOMIT));
    assert_eq!(super::player::activity(&s.players[&1], s.tick), activity::VOMITING);
    drink(&mut s, 1, item_kind::WINE); // 65 + 30
    assert!(!s.players[&1].passed_out);
    drink(&mut s, 1, item_kind::MALPKA);
    let p = &s.players[&1];
    assert!(p.passed_out, "drank on after throwing up: asleep");
    assert_eq!(super::player::activity(p, s.tick), activity::PASSED_OUT);
    assert_eq!(s.puddles.len(), 1, "only one puddle");
    // A minute later they wake up with less in the blood.
    s.tick += crate::drunk::PASS_OUT_TICKS;
    s.simulate_players();
    let p = &s.players[&1];
    assert!(!p.passed_out && p.needs.alcohol_points() <= 60);
    assert!(s.says.iter().any(|l| l.text == crate::drunk::lines::WAKE_UP));
}

#[test]
fn the_board_tests_with_the_breathalyser_and_three_reprimands_fire() {
    let mut s = server();
    let (boss, worker) = (1, 2);
    add_player(&mut s, boss);
    add_player(&mut s, worker);
    s.company.founder = Some(boss);
    s.players.get_mut(&boss).unwrap().department = crate::company::BOARD_DEPARTMENT;
    let w = s.players.get_mut(&worker).unwrap();
    w.department = 1;
    w.contract = true;
    w.body.pos = Pos::tile_center(6, 5); // right next to the boss
                                         // Not on the board: no test.
    drink(&mut s, worker, item_kind::BREATHALYSER);
    assert!(s.says.iter().any(|l| l.text == crate::drunk::lines::NOT_BOARD));
    // Sober: a reading, no question.
    s.says.clear();
    drink(&mut s, boss, item_kind::BREATHALYSER);
    assert!(s.says.iter().any(|l| l.text.contains("0,00 ‰")), "{:?}", s.says.iter().map(|l| &l.text).collect::<Vec<_>>());
    assert!(s.players[&boss].reprimand_ask.is_none());
    for n in 1..=3u8 {
        s.players.get_mut(&worker).unwrap().needs.drink_alcohol(20);
        s.says.clear();
        drink(&mut s, boss, item_kind::BREATHALYSER);
        assert!(s.says.iter().any(|l| l.text.contains("pod wpływem")));
        let (ask, target) = s.players[&boss].reprimand_ask.expect("asked whether to reprimand");
        assert_eq!(target, worker);
        assert!(!s.answer_reprimand(boss, ask.wrapping_add(1), 0), "another dialog");
        assert!(s.answer_reprimand(boss, ask, 0));
        assert_eq!(s.players[&worker].reprimands, n);
        // Sober again for the next test.
        s.players.get_mut(&worker).unwrap().needs.alcohol = 0;
    }
    assert!(!s.players[&worker].contract, "the third reprimand: fired");
}

/// Put player `id` on a free tile next to `(floor, tile)`.
fn stand_next_to(s: &mut Server, id: u16, floor: u8, t: crate::map::Tile) {
    let m = s.building.floor(floor).unwrap();
    let (x, y) =
        [(0, 1), (0, -1), (1, 0), (-1, 0)].iter().map(|(dx, dy)| (t.x + dx, t.y + dy)).find(|&(x, y)| !m.is_blocked(x, y)).unwrap();
    let p = s.players.get_mut(&id).unwrap();
    p.body = Body::at(floor, Pos::tile_center(x, y));
    p.room = m.room_at_tile(x, y);
}

/// Run `n` whole server-side player ticks.
fn run_ticks(s: &mut Server, n: u32) {
    for _ in 0..n {
        s.tick += 1;
        let mut steps = s.simulate_players();
        s.react_to_steps(&mut steps);
    }
}

#[test]
fn five_cigarettes_in_a_row_come_back_up() {
    let mut s = server();
    add_player(&mut s, 1);
    let pack = crate::inventory::Item { count: 20, ..s.mint_item(item_kind::CIGARETTES, "") };
    s.players.get_mut(&1).unwrap().inventory.hands = Some(pack);
    for n in 1..=5 {
        s.use_held(1); // lit
        assert!(s.puddles.is_empty(), "cigarette {n}: fine so far");
        run_ticks(&mut s, crate::needs::SMOKE_TICKS + 1);
    }
    assert_eq!(s.puddles.len(), 1, "the fifth in a row: sick");
    assert_eq!(s.puddles[0].kind, crate::protocol::puddle::VOMIT);
    // With a break in between, the count starts again.
    run_ticks(&mut s, crate::drunk::VOMIT_TICKS + crate::mischief::CHAIN_GAP_TICKS + crate::needs::SMOKE_TICKS);
    for _ in 0..4 {
        s.use_held(1);
        run_ticks(&mut s, crate::needs::SMOKE_TICKS + 1);
    }
    assert_eq!(s.puddles.len(), 1, "four more: still fine");
}

#[test]
fn peeing_into_the_machine_and_a_mug_and_pooping_on_the_floor() {
    use crate::protocol::{activity, puddle};
    let mut s = server();
    add_player(&mut s, 1);
    add_player(&mut s, 2);
    let m = (s.machines[0].floor, s.machines[0].tile);
    stand_next_to(&mut s, 1, m.0, m.1);
    s.players.get_mut(&1).unwrap().needs.bladder = 0;
    s.handle_action(1, crate::protocol::action::MENU);
    let deeds = s.players[&1].deeds.clone();
    let machine = deeds.iter().position(|d| matches!(d, super::actions::Deed::PeeMachine(_))).expect("the machine in the menu");
    // Nothing to give yet.
    s.answer_mischief(1, crate::mischief::MENU_ID, machine as u8);
    assert!(s.says.iter().any(|l| l.text == crate::mischief::lines::NO_PEE));
    assert_eq!(s.machines[0].tainted, 0);
    s.players.get_mut(&1).unwrap().needs.bladder = 60 * crate::needs::SCALE;
    s.handle_action(1, crate::protocol::action::MENU);
    s.answer_mischief(1, crate::mischief::MENU_ID, machine as u8);
    assert_eq!(s.machines[0].tainted, crate::mischief::MACHINE_DOSES);
    assert_eq!(super::player::activity(&s.players[&1], s.tick), activity::PEEING);
    // The next coffee from it is "special".
    stand_next_to(&mut s, 2, m.0, m.1);
    s.players.get_mut(&2).unwrap().cup = crate::coffee::Cup::Brewing { machine: 0, until: s.tick + 1 };
    run_ticks(&mut s, 2);
    let coffee = s.players[&2].inventory.hands.clone().expect("coffee in hands");
    assert!(coffee.kind == item_kind::COFFEE && coffee.tainted);
    assert_eq!(s.machines[0].tainted, crate::mischief::MACHINE_DOSES - 1);
    let stress = s.players[&2].needs.stress;
    s.says.clear();
    s.use_held(2);
    let sick = !s.puddles.is_empty();
    let tasted = s.says.iter().any(|l| l.text == crate::mischief::lines::TASTE);
    assert!(sick ^ tasted, "either sick or just disgusted");
    assert!(s.players[&2].needs.stress > stress);
    // Into the mug somebody holds.
    let fresh = s.mint_item(item_kind::COFFEE, "");
    s.players.get_mut(&2).unwrap().inventory.hands = Some(fresh);
    s.players.get_mut(&1).unwrap().held_until = 0;
    s.players.get_mut(&1).unwrap().needs.bladder = 60 * crate::needs::SCALE;
    s.handle_action(1, crate::protocol::action::MENU);
    let cup = s.players[&1].deeds.iter().position(|d| *d == super::actions::Deed::PeeCup(2)).expect("Kuba's mug in the menu");
    s.says.clear();
    s.answer_mischief(1, crate::mischief::MENU_ID, cup as u8);
    assert!(s.players[&2].inventory.hands.as_ref().unwrap().tainted);
    assert!(s.says.iter().any(|l| l.speaker == 2 && l.text == crate::mischief::lines::OBLIVIOUS));
    // Pooping on the floor.
    s.players.get_mut(&1).unwrap().held_until = 0;
    s.players.get_mut(&1).unwrap().needs.bowels = 50 * crate::needs::SCALE;
    let puddles = s.puddles.len();
    s.handle_action(1, crate::protocol::action::MENU);
    s.answer_mischief(1, crate::mischief::MENU_ID, 1);
    assert_eq!(s.puddles.len(), puddles + 1);
    assert_eq!(s.puddles.last().unwrap().kind, puddle::POOP);
    assert_eq!(super::player::activity(&s.players[&1], s.tick), activity::POOPING);
    // The cleaner's round rinses the machine.
    s.cfg.cleaning_at = 0;
    s.cfg.cleaning_spread = 0;
    s.clock.ds = 10 * 60 * crate::clock::DS_PER_MIN;
    s.tick_cleaning();
    assert!(s.machines.iter().all(|m| m.tainted == 0));
}

#[test]
fn punches_knock_out_a_knife_calls_the_police_and_earns_a_reprimand() {
    use crate::protocol::activity;
    let mut s = server();
    add_player(&mut s, 1);
    add_player(&mut s, 2);
    s.players.get_mut(&2).unwrap().body.pos = Pos::tile_center(6, 5);
    // Ten punches, a second apart: out cold.
    for n in 1..=10 {
        s.players.get_mut(&1).unwrap().held_until = 0; // the guard is on his way; never mind
        s.handle_action(1, crate::protocol::action::ATTACK);
        assert_eq!(s.players[&2].needs.health_points(), 100 - 10 * n);
        s.handle_action(1, crate::protocol::action::ATTACK); // too soon: nothing
        assert_eq!(s.players[&2].needs.health_points(), 100 - 10 * n);
        s.tick += crate::mischief::PUNCH_COOLDOWN;
    }
    let p2 = &s.players[&2];
    assert!(p2.knocked_out && super::player::activity(p2, s.tick) == activity::KNOCKED_OUT);
    assert_eq!(s.players[&1].assault, Some(false));
    assert!(s.npcs.iter().any(|n| n.role == crate::npc::Role::Guard && n.chasing() == Some(1)), "the guard runs after them");
    assert!(s.police_calls.is_empty(), "no police for fists");
    // Lying down: not hit again.
    s.handle_action(1, crate::protocol::action::ATTACK);
    assert_eq!(s.players[&2].needs.health_points(), 0);
    // A minute later: up again with some health.
    s.tick += crate::mischief::KNOCKOUT_TICKS;
    run_ticks(&mut s, 1);
    assert!(!s.players[&2].knocked_out && s.players[&2].needs.health_points() >= 30);
    // A knife (F): a stab, the police and a reprimand.
    s.players.get_mut(&1).unwrap().contract = true;
    let knife = s.mint_item(item_kind::KNIFE, "");
    s.players.get_mut(&1).unwrap().inventory.hands = Some(knife);
    s.players.get_mut(&1).unwrap().held_until = 0;
    s.players.get_mut(&2).unwrap().needs.health = crate::needs::MAX;
    let before = s.players[&2].needs.health_points();
    s.use_held(1);
    assert_eq!(s.players[&2].needs.health_points(), before - 35);
    assert_eq!(s.puddles.last().map(|p| p.kind), Some(crate::protocol::puddle::BLOOD), "blood on the floor");
    assert!(s.police_calls.iter().any(|c| c.target == 1));
    assert_eq!(s.players[&1].reprimands, 1);
    assert_eq!(s.players[&1].assault, Some(true));
    // Caught by the guard: held, and no longer wanted.
    let guard = s.npcs.iter().find(|n| n.role == crate::npc::Role::Guard).unwrap().id;
    s.caught(guard, 1);
    assert!(s.players[&1].assault.is_none() && s.players[&1].held_until > s.tick);
}

#[test]
fn the_lift_panel_wants_the_card_except_for_the_ground_floor() {
    use crate::elevator::lines;
    let mut s = server();
    add_player(&mut s, 1);
    // In the cabin of a lift standing on floor 4.
    let i = s.elevators.iter().position(|e| e.floors().contains(&4)).unwrap();
    s.elevators[i].floor = 4;
    s.elevators[i].moving = None;
    let r = s.elevators[i].cabins.iter().find(|(f, _)| *f == 4).unwrap().1;
    let p = s.players.get_mut(&1).unwrap();
    p.body = Body::at(4, Pos::tile_center(r.x, r.y));
    p.body.access = 0; // no card yet
    let body = p.body;
    assert!(s.use_elevator(1, &body));
    let panel = s.players[&1].lift_panel.clone().expect("the panel");
    let Some(Packet::Dialog { options, items, .. }) = s.dialog_packet(1) else { panic!("no panel") };
    let ground = panel.floors.iter().position(|&f| f == 0).unwrap();
    let up = panel.floors.iter().position(|&f| f == 3).unwrap();
    assert_eq!((items[ground], items[up]), (0, 1), "only the ground floor without the card");
    assert_eq!(options.last().map(String::as_str), Some(super::doors::PANEL_CARD));
    let card = (panel.floors.len() + 1) as u8;
    // Floor 3 without the card: no.
    s.press_lift_panel(1, &panel, up as u8);
    assert!(s.says.iter().any(|l| l.text == lines::CARD_FIRST));
    assert!(s.players[&1].lift_panel.is_some(), "the panel stays");
    // No card to swipe.
    s.press_lift_panel(1, &panel, card);
    assert!(s.says.iter().any(|l| l.text == lines::NO_CARD_TO_SWIPE));
    // With the card: swiped, then floor 3 works.
    s.players.get_mut(&1).unwrap().body.access = crate::map::access::required("card").unwrap();
    s.press_lift_panel(1, &panel, card);
    let panel = s.players[&1].lift_panel.clone().unwrap();
    assert!(panel.carded);
    let Some(Packet::Dialog { items, .. }) = s.dialog_packet(1) else { panic!("no panel") };
    assert!(items.iter().all(|&k| k == 0), "every button lit");
    s.says.clear();
    s.press_lift_panel(1, &panel, up as u8);
    assert!(s.says.iter().any(|l| l.text.starts_with("Jedziemy na: Piętro 3")));
    assert!(s.players[&1].lift_panel.is_none());
}

#[test]
fn a_skid_mark_is_seen_by_the_next_one_and_scrubbed_with_the_brush() {
    use crate::needs::SpotKind;
    use crate::stains::lines;
    let mut s = server();
    add_player(&mut s, 1);
    add_player(&mut s, 2);
    s.cfg.stain_percent = 100;
    let toilet = s.spots.iter().find(|t| t.kind == SpotKind::Toilet && t.floor == 4).unwrap().clone();
    stand_next_to(&mut s, 1, toilet.floor, toilet.tile);
    let body = s.players[&1].body;
    // Sat down, got up: a skid mark, and only they are told.
    s.use_spot(1, &body);
    assert!(s.players[&1].rest.is_some());
    s.players.get_mut(&1).unwrap().body.pos.x += 16; // gets up
    run_ticks(&mut s, 1);
    assert_eq!(s.stains.len(), 1);
    assert!(s.puddles.iter().any(|p| p.kind == crate::protocol::puddle::STAIN));
    assert!(s.says.iter().any(|l| l.text == lines::MADE && l.reach == super::Reach::Whisper));
    // They don't count as a witness; the next one in the stall does.
    s.says.clear();
    s.tick = 20;
    s.tick_stains();
    assert!(!s.says.iter().any(|l| l.text == lines::SEEN));
    stand_next_to(&mut s, 2, toilet.floor, toilet.tile);
    s.tick_stains();
    assert!(s.says.iter().any(|l| l.speaker == 2 && l.text == lines::SEEN), "Znowu człowiek smuga zaatakował!");
    // Nobody sits on that.
    let body2 = s.players[&2].body;
    assert_eq!(s.use_spot(2, &body2), Some(Some(lines::DIRTY.to_string())));
    assert!(s.players[&2].rest.is_none());
    // The brush: clean again.
    s.says.clear();
    s.scrub(2);
    assert!(s.stains.is_empty() && !s.puddles.iter().any(|p| p.kind == crate::protocol::puddle::STAIN));
    assert!(s.says.iter().any(|l| l.text == lines::SCRUBBED_OTHERS));
}

#[test]
fn the_coffee_machine_needs_water_and_its_grounds_go_to_the_bin() {
    use crate::coffee::{self, lines};
    use crate::protocol::coffee_action as act;
    let mut s = server();
    add_player(&mut s, 1);
    let m = s.machines.iter().position(|m| m.floor == 4).unwrap();
    let t = s.machines[m].tile;
    stand_next_to(&mut s, 1, 4, t);
    s.open_coffee_panel(1, m);
    s.give_new(1, item_kind::CUP);
    let said = |s: &mut Server, line: &str| {
        let yes = s.says.iter().any(|l| l.text == line);
        s.says.clear();
        yes
    };
    s.machines[m].water = 0;
    s.handle_coffee_action(1, m as u8, act::BREW);
    assert!(said(&mut s, lines::NO_WATER));
    s.handle_coffee_action(1, m as u8, act::WATER);
    assert!(said(&mut s, lines::WATER_ADDED));
    assert_eq!(s.machines[m].water, coffee::WATER_CUPS);
    s.machines[m].grounds = coffee::GROUNDS_CUPS;
    s.handle_coffee_action(1, m as u8, act::BREW);
    assert!(said(&mut s, lines::GROUNDS_FULL));
    // The grounds out: hands are full (the mug) - put it away first.
    s.handle_coffee_action(1, m as u8, act::EMPTY_GROUNDS);
    assert!(said(&mut s, lines::HANDS_FULL));
    s.players.get_mut(&1).unwrap().inventory.take_hands();
    s.handle_coffee_action(1, m as u8, act::EMPTY_GROUNDS);
    assert!(said(&mut s, lines::GROUNDS_OUT));
    assert_eq!((s.machines[m].grounds, s.players[&1].inventory.held_kind()), (0, item_kind::GROUNDS));
    // Into the kitchen bin; a mug doesn't go there; rummaging gets it back.
    let k = s.kitchen.as_ref().unwrap();
    let (floor, bin) = (k.floor, k.bin.expect("a bin in the kitchen"));
    stand_next_to(&mut s, 1, floor, bin);
    s.open_container(1, container::BIN);
    s.handle_container_action(1, container::BIN, container::PUT, 0, 0);
    assert_eq!(s.kitchen.as_ref().unwrap().trash.len(), 1);
    assert!(s.players[&1].inventory.hands_free());
    s.give_new(1, item_kind::EMPTY_CUP);
    s.handle_container_action(1, container::BIN, container::PUT, 0, 0);
    assert!(said(&mut s, super::containers::say::MUG_NOT_TRASH));
    s.players.get_mut(&1).unwrap().inventory.take_hands();
    s.handle_container_action(1, container::BIN, container::TAKE, 0, item_kind::GROUNDS);
    assert_eq!(s.players[&1].inventory.held_kind(), item_kind::GROUNDS);
    // The cleaner's round: water topped up, grounds out, the bin empty.
    s.machines[m].water = 0;
    s.machines[m].service();
    assert_eq!((s.machines[m].water, s.machines[m].grounds), (coffee::WATER_CUPS, 0));
}

#[test]
fn things_go_in_and_out_of_containers_by_their_slots() {
    let mut s = server();
    add_player(&mut s, 1);
    let k = s.kitchen.as_ref().unwrap();
    let (floor, fridge, cupboard, dishwasher) = (k.floor, k.fridge, k.cupboard, k.dishwasher);
    let act = |s: &mut Server, which: u8, a: u8, arg: u8, kind: u8| s.handle_container_action(1, which, a, arg, kind);
    // A sandwich from a pocket into the fridge, signed; out again.
    stand_next_to(&mut s, 1, floor, fridge);
    s.give_new(1, item_kind::SANDWICH_HAM);
    s.open_container(1, container::FRIDGE);
    act(&mut s, container::FRIDGE, container::PUT, 1, 0);
    let stored = &s.kitchen.as_ref().unwrap().stored;
    assert_eq!((stored.len(), stored[0].label.as_str()), (1, "Kanapka z szynką (p1)"));
    assert!(!s.players[&1].inventory.has(item_kind::SANDWICH_HAM));
    act(&mut s, container::FRIDGE, container::TAKE, 0, item_kind::WATER); // not what's there now
    assert_eq!(s.kitchen.as_ref().unwrap().stored.len(), 1, "a changed slot isn't taken");
    act(&mut s, container::FRIDGE, container::TAKE, 0, item_kind::SANDWICH_HAM);
    assert!(s.players[&1].inventory.has(item_kind::SANDWICH_HAM));
    // Not at the cupboard: its window does nothing.
    let mugs = s.kitchen.as_ref().unwrap().mugs;
    act(&mut s, container::CUPBOARD, container::TAKE, 0, item_kind::CUP);
    assert_eq!(s.kitchen.as_ref().unwrap().mugs, mugs);
    // The cupboard: a mug out and back; a sandwich doesn't go in.
    stand_next_to(&mut s, 1, floor, cupboard);
    s.open_container(1, container::CUPBOARD);
    act(&mut s, container::CUPBOARD, container::TAKE, 0, item_kind::CUP);
    assert_eq!(s.players[&1].inventory.held_kind(), item_kind::CUP);
    act(&mut s, container::CUPBOARD, container::PUT, 0, 0);
    assert!(s.players[&1].inventory.hands_free());
    assert_eq!(s.kitchen.as_ref().unwrap().mugs, mugs);
    s.says.clear();
    act(&mut s, container::CUPBOARD, container::PUT, 1, 0);
    assert!(s.says.iter().any(|l| l.text == super::containers::say::NOT_HERE));
    // The dishwasher takes dirty mugs only; start, then unload to the cupboard.
    stand_next_to(&mut s, 1, floor, dishwasher);
    s.open_container(1, container::DISHWASHER);
    s.give_new(1, item_kind::EMPTY_CUP);
    act(&mut s, container::DISHWASHER, container::PUT, 0, 0);
    assert_eq!(s.kitchen.as_ref().unwrap().dirty, 1);
    act(&mut s, container::DISHWASHER, container::START, 0, 0);
    assert!(s.kitchen.as_ref().unwrap().running_until.is_some());
    let k = s.kitchen.as_mut().unwrap();
    let done = k.running_until.unwrap();
    k.tick(done);
    act(&mut s, container::DISHWASHER, container::UNLOAD, 0, 0);
    let k = s.kitchen.as_ref().unwrap();
    assert_eq!((k.washed, k.dirty), (0, 0));
    // The cabinet: a medicine back on its shelf, nothing else.
    let (cf, cabinet) = s.supplies.cabinet.unwrap();
    stand_next_to(&mut s, 1, cf, cabinet);
    s.open_container(1, container::CABINET);
    let left = s.supplies.stock.left(item_kind::VITAMIN);
    act(&mut s, container::CABINET, container::TAKE, 2, item_kind::VITAMIN);
    assert_eq!(s.supplies.stock.left(item_kind::VITAMIN), left - 1);
    let at = s.players[&1].inventory.pockets.iter().position(|i| i.as_ref().is_some_and(|i| i.kind == item_kind::VITAMIN)).unwrap();
    act(&mut s, container::CABINET, container::PUT, at as u8 + 1, 0);
    assert_eq!(s.supplies.stock.left(item_kind::VITAMIN), left);
}

#[test]
fn the_cupboard_shows_mugs_and_knives() {
    let mut s = server();
    add_player(&mut s, 1);
    let k = s.kitchen.as_ref().unwrap();
    let (floor, cupboard) = (k.floor, k.cupboard);
    stand_next_to(&mut s, 1, floor, cupboard);
    s.open_container(1, container::CUPBOARD);
    assert_eq!(s.players[&1].container, Some(container::CUPBOARD));
    s.handle_container_action(1, container::CUPBOARD, container::TAKE, 1, item_kind::KNIFE);
    assert!(s.players[&1].inventory.has(item_kind::KNIFE), "a knife in the pocket");
    assert_eq!(s.kitchen.as_ref().unwrap().knives, crate::kitchen::KNIVES - 1);
    // Back in the cupboard (from the hands).
    s.players.get_mut(&1).unwrap().inventory.take_out(0).unwrap();
    s.put_knife_back(1);
    assert!(s.players[&1].inventory.hands_free());
    assert_eq!(s.kitchen.as_ref().unwrap().knives, crate::kitchen::KNIVES);
}

#[test]
fn pani_wiesia_greets_newcomers_and_the_cashier_asks_about_the_hot_dog() {
    let mut s = server();
    add_player(&mut s, 1);
    let m = s.building.floor(0).unwrap();
    let lobby = m.room_by_name("Wiatrołap").unwrap().id;
    let hall = m.room_by_name("Hol").unwrap().id;
    let stairs = m.room_by_name("Klatka schodowa").unwrap().id;
    s.greet_entering(&[(1, 0, stairs, hall)]);
    assert!(s.says.is_empty(), "from the stairwell: already inside");
    s.greet_entering(&[(1, 0, lobby, hall)]);
    assert!(s.says.iter().any(|l| l.text.starts_with("Dzień dobry, p1! ")), "{:?}", s.says.iter().map(|l| &l.text).collect::<Vec<_>>());
    s.says.clear();
    s.greet_entering(&[(1, 0, lobby, hall)]);
    assert!(s.says.is_empty(), "not again right away");
    // At the counter with goods to pay for.
    let goods = crate::inventory::Item { unpaid: true, ..s.mint_item(item_kind::BEER, "") };
    let p = s.players.get_mut(&1).unwrap();
    p.inventory.hands = Some(goods);
    p.body = Body::at(0, Pos::tile_center(20, 53));
    s.tick_cashier();
    s.tick_cashier();
    let asked = s.says.iter().filter(|l| l.text == crate::npc::lines::CASHIER_HOTDOG).count();
    assert_eq!(asked, 1, "once");
    s.players.get_mut(&1).unwrap().body.pos = Pos::tile_center(24, 47);
    s.tick_cashier();
    s.players.get_mut(&1).unwrap().body.pos = Pos::tile_center(20, 53);
    s.tick_cashier();
    assert_eq!(s.says.iter().filter(|l| l.text == crate::npc::lines::CASHIER_HOTDOG).count(), 2, "again after stepping away");
}

/// A player job hunting on the portal.
fn on_portal(s: &mut Server, id: u16) {
    add_player(s, id);
    s.players.get_mut(&id).unwrap().stage = Stage::Portal(Box::default());
}

fn inbox_subjects(s: &Server, id: u16) -> Vec<String> {
    match &s.players[&id].stage {
        Stage::Portal(d) => d.inbox.iter().map(|m| m.subject.clone()).collect(),
        _ => Vec::new(),
    }
}

#[test]
fn asking_too_much_gets_a_no_and_a_mandate_is_for_students_under_26() {
    use crate::protocol::employment;
    let mut s = server();
    on_portal(&mut s, 1);
    on_portal(&mut s, 2);
    on_portal(&mut s, 3);
    s.players.get_mut(&3).unwrap().profile.age = 30;
    let max = s.position(1).unwrap().salary[1];
    s.handle_apply(1, 1, max + 1, employment::EMPLOYMENT, false);
    s.handle_apply(2, 1, max, employment::MANDATE, true);
    s.handle_apply(3, 1, max, employment::MANDATE, true); // 30 years old: no mandate
    match &s.players[&3].stage {
        Stage::Portal(d) => assert!(d.applied.is_empty(), "rejected at once"),
        _ => unreachable!(),
    }
    s.tick += s.cfg.recruitment.invite_delay_secs * 20 + 1;
    s.deliver_replies(1);
    s.deliver_replies(2);
    assert_eq!(inbox_subjects(&s, 1), vec![crate::pay::lines::TOO_MUCH_SUBJECT]);
    assert!(inbox_subjects(&s, 2)[0].starts_with("Zaproszenie na rozmowę"));
    // Hired: what was agreed goes with them to HR.
    s.hire(2, 1);
    assert_eq!(s.players[&2].terms, Some(crate::pay::Terms { agreed: max, form: employment::MANDATE, offered: 0 }));
}

#[test]
fn the_contract_says_less_sign_it_or_get_seen_out() {
    use crate::pay::{self, Terms};
    use crate::protocol::employment;
    let mut s = server();
    let hr = s.npcs.iter().find(|n| n.role == crate::npc::Role::Hr).unwrap().id;
    for id in [1, 2] {
        add_player(&mut s, id);
        let pass = s.mint_item(item_kind::GUEST_PASS, "");
        let p = s.players.get_mut(&id).unwrap();
        p.inventory.add(pass).unwrap();
        p.position = Some(1);
        p.department = 1;
    }
    s.players.get_mut(&1).unwrap().terms = Some(Terms { agreed: 10_000, form: employment::B2B, offered: 0 });
    // Shown: lower than agreed (B2B: +20% on top), the same every time.
    s.show_contract(hr, 1);
    let offered = s.players[&1].terms.unwrap().offered;
    assert!((9_000..=10_800).contains(&offered) && offered.is_multiple_of(100), "{offered}");
    s.show_contract(hr, 1);
    assert_eq!(s.players[&1].terms.unwrap().offered, offered);
    let money = s.players[&1].money;
    s.handle_dialog_answer(1, pay::CONTRACT_ID, 0);
    let p = &s.players[&1];
    assert!(p.contract && p.salary == offered && p.employment == employment::B2B);
    assert_eq!(p.pay_rate, pay::hourly(offered));
    assert_eq!(p.money, money, "B2B: no advance");
    assert!(p.inventory.has(item_kind::EMPLOYEE_CARD) && !p.inventory.has(item_kind::GUEST_PASS));
    // Player 2 turns it down: HR walks them out, Pani Wiesia takes the pass,
    // and it's the job portal again (the place is free again).
    let places = s.places(1);
    s.show_contract(hr, 2);
    s.handle_dialog_answer(2, pay::CONTRACT_ID, 1);
    assert_eq!(s.npcs.iter().find(|n| n.id == hr).unwrap().escorting(), Some(2));
    s.says.clear();
    s.saw_out(2);
    assert!(!s.players[&2].inventory.has(item_kind::GUEST_PASS));
    assert!(s.says.iter().any(|l| l.text == pay::lines::PASS_BACK));
    s.tick += 200;
    s.tick_to_portal();
    assert!(matches!(s.players[&2].stage, Stage::Portal(_)));
    assert_eq!(inbox_subjects(&s, 2), vec!["Rezygnacja z umowy"]);
    assert_eq!((s.places(1), s.players[&2].position), (places + 1, None));
}

#[test]
fn reception_asks_about_lunch_and_pani_maria_never_stops_talking() {
    let mut s = server();
    add_player(&mut s, 1);
    add_player(&mut s, 2);
    s.clock.ds = 10 * 60 * crate::clock::DS_PER_MIN;
    let r = s.npcs.iter().find(|n| n.role == crate::npc::Role::Receptionist).unwrap().body;
    let p = s.players.get_mut(&1).unwrap();
    p.contract = true;
    p.body = Body::at(r.floor, Pos { x: r.pos.x, y: r.pos.y + 2 * 256 });
    for _ in 0..30 {
        s.tick += 1;
        s.tick_reception();
    }
    let asked = s.says.iter().filter(|l| l.text == crate::pay::lines::LUNCH).count();
    assert_eq!(asked, 1, "once a day");
    // Pani Maria: a story to each person near her, then a break, then more.
    s.says.clear();
    let m = s.npcs.iter().find(|n| n.role == crate::npc::Role::Cleaner).unwrap().body;
    for id in [1, 2] {
        s.players.get_mut(&id).unwrap().body = Body::at(m.floor, Pos { x: m.pos.x + 256, y: m.pos.y });
    }
    let stories = |s: &Server| s.says.iter().filter(|l| crate::cleaning::lines::STORIES.contains(&l.text.as_str())).count();
    for _ in 0..(20 * 20) {
        s.tick += 1;
        s.tick_maria();
    }
    assert_eq!(stories(&s), 2, "one each, 12 s apart");
    for _ in 0..(60 * 20) {
        s.tick += 1;
        s.tick_maria();
    }
    assert_eq!(stories(&s), 4, "and again after a minute");
}

#[test]
fn the_hr_app_plans_leave_and_a_day_off_is_spent_at_home_paid() {
    use crate::hr;
    let mut s = server();
    let hr_npc = s.npcs.iter().find(|n| n.role == crate::npc::Role::Hr).unwrap().id;
    add_player(&mut s, 1);
    let pass = s.mint_item(item_kind::GUEST_PASS, "");
    let p = s.players.get_mut(&1).unwrap();
    p.inventory.add(pass).unwrap();
    p.position = Some(1);
    p.department = 1;
    p.terms = Some(crate::pay::Terms { agreed: 8_400, form: crate::protocol::employment::EMPLOYMENT, offered: 0 });
    s.show_contract(hr_npc, 1);
    s.handle_dialog_answer(1, crate::pay::CONTRACT_ID, 0);
    let p = &s.players[&1];
    assert!(p.hr.annexes[0].text.starts_with("Umowa: Programista/ka, umowa o pracę"), "{:?}", p.hr.annexes);
    assert_eq!(p.hr.leave_days, hr::START_LEAVE_DAYS);
    // Leave for tomorrow: approved (one day less).
    let tomorrow = p.day + 1;
    s.handle_hr_action(1, hr::action::REQUEST, tomorrow as u16);
    assert_eq!(s.players[&1].hr.leave_days, hr::START_LEAVE_DAYS - 1);
    assert_eq!(s.players[&1].hr.requests[0].status, hr::status::APPROVED);
    // Evening, night, morning: the day off - at home, paid 8 hours.
    s.players.get_mut(&1).unwrap().stage = Stage::Home { arrive_at: None };
    let money = s.players[&1].money;
    s.clock.ds = (crate::clock::OPEN_MIN - 1) * crate::clock::DS_PER_MIN;
    while s.clock.minute() != crate::clock::OPEN_MIN {
        s.tick_clock();
    }
    let p = &s.players[&1];
    assert_eq!(p.day, tomorrow);
    assert!(p.hr.on_leave && p.depart_at.is_none(), "staying at home");
    assert_eq!(p.money, money + hr::LEAVE_HOURS * p.pay_rate);
    assert!(matches!(s.clock_packet(p), Packet::Clock { leave: true, .. }));
}

#[test]
fn the_remote_switches_the_tv_and_the_boombox_plays_where_it_is() {
    use crate::media;
    let mut s = server();
    add_player(&mut s, 1);
    assert_eq!(s.screens.len(), 1, "one TV, in the chill room");
    let (floor, tile, room) = (s.screens[0].floor, s.screens[0].tile, s.screens[0].room);
    assert_eq!(s.building.floor(floor).unwrap().room_name(room), "Chill room");
    // The remote and the boombox lie in the chill room from the start.
    let kinds: Vec<u8> = s.dropped.iter().map(|d| d.item.kind).collect();
    assert!(kinds.contains(&item_kind::REMOTE) && kinds.contains(&item_kind::BOOMBOX));
    // Pick up the remote (it's gone from the floor), in front of the TV.
    let at = s.dropped.iter().position(|d| d.item.kind == item_kind::REMOTE).unwrap();
    let remote = s.dropped.remove(at).item;
    let m = s.building.floor(floor).unwrap();
    let spot = Pos::tile_center(tile.x, tile.y - 2);
    let p = s.players.get_mut(&1).unwrap();
    p.inventory.hands = Some(remote);
    p.body = Body::at(floor, spot);
    p.room = m.room_at(spot.x, spot.y);
    s.tick = 500;
    s.use_held(1); // the channel list
    s.answer_media(1, media::TV_DIALOG, 3);
    assert_eq!((s.screens[0].channel, s.screens[0].started), (4, 500), "Mecz");
    assert!(s.says.iter().any(|l| l.text == media::lines::tv_on("Mecz")));
    s.answer_media(1, media::TV_DIALOG, media::CHANNELS.len() as u8);
    assert_eq!(s.screens[0].channel, 0, "off");
    // Somewhere else the remote does nothing.
    s.players.get_mut(&1).unwrap().room = 0;
    s.says.clear();
    s.use_held(1);
    assert!(s.says.iter().any(|l| l.text == media::lines::NOT_HERE));
    // The boombox: a track, carried around, put down, gone.
    let at = s.dropped.iter().position(|d| d.item.kind == item_kind::BOOMBOX).unwrap();
    let boombox = s.dropped.remove(at).item;
    s.players.get_mut(&1).unwrap().inventory.put_away().unwrap(); // the remote into a pocket
    s.players.get_mut(&1).unwrap().inventory.hands = Some(boombox);
    s.answer_media(1, media::BOOMBOX_DIALOG, 1);
    assert_eq!(s.music, Some((2, 500)), "Lo-fi");
    assert_eq!(s.boombox_at(), Some((floor, spot, 1)), "plays where the holder is");
    s.handle_item_action(1, crate::protocol::item_action::DROP, 0);
    assert_eq!(s.boombox_at().map(|b| b.2), Some(0), "on the floor");
    s.dropped.retain(|d| d.item.kind != item_kind::BOOMBOX);
    s.tick_media();
    assert_eq!(s.music, None, "gone: silence");
    // Next morning it's back (the remote too, unless somebody has it).
    s.ensure_media_items();
    let kinds: Vec<u8> = s.dropped.iter().map(|d| d.item.kind).collect();
    assert!(kinds.contains(&item_kind::BOOMBOX) && !kinds.contains(&item_kind::REMOTE), "{kinds:?}");
}

#[test]
fn the_storeroom_key_is_free_only_while_the_receptionist_is_away() {
    use crate::supplies::{self, lines};
    let mut s = server();
    add_player(&mut s, 1);
    let (hf, hook) = s.supplies.hook.expect("a key hook at the reception");
    stand_next_to(&mut s, 1, hf, hook);
    let body = s.players[&1].body;
    // She's at her desk: no key.
    assert!(s.use_supplies(1, &body));
    assert!(s.says.iter().any(|l| l.text == lines::KEY_NO));
    assert!(s.supplies.key_on_hook);
    // Lunch break: she's off to the kitchenette - the key is free.
    s.clock.ds = supplies::BREAK_FROM * crate::clock::DS_PER_MIN;
    s.tick_lunch_break();
    assert!(s.supplies.on_break);
    s.use_supplies(1, &body);
    assert!(s.players[&1].inventory.has(item_kind::STORE_KEY) && !s.supplies.key_on_hook);
    assert_eq!(s.players[&1].body.access & crate::map::access::KEY, crate::map::access::KEY, "the key opens the storeroom");
    // The storeroom door needs it.
    let (sf, room) = s.supplies.storeroom.unwrap();
    let m = s.building.floor(sf).unwrap();
    let door =
        (0..m.height).flat_map(|y| (0..m.width).map(move |x| (x, y))).find(|&(x, y)| m.tile_type(x, y) == Some("storeroom_door")).unwrap();
    assert!(
        m.blocks(door.0, door.1, crate::map::access::CARD, crate::map::dir::DOWN)
            && !m.blocks(door.0, door.1, crate::map::access::KEY, crate::map::dir::DOWN)
    );
    // Inside: cola from the shelf, until it runs out.
    let shelf = s.supplies.shelves[0].1;
    stand_next_to(&mut s, 1, sf, shelf);
    assert_eq!(s.players[&1].room, room);
    let body = s.players[&1].body;
    for _ in 0..supplies::STOREROOM_STOCK {
        s.use_supplies(1, &body);
        s.handle_container_action(1, container::STOREROOM, container::TAKE, 0, item_kind::COLA);
        let p = s.players.get_mut(&1).unwrap();
        let has = p.inventory.has(item_kind::COLA);
        assert!(has, "a cola");
        p.inventory.remove_kind(item_kind::COLA);
    }
    s.says.clear();
    s.use_supplies(1, &body);
    s.handle_container_action(1, container::STOREROOM, container::TAKE, 0, item_kind::COLA);
    assert!(s.says.iter().any(|l| l.text == lines::EMPTY), "all gone for today");
    // Back at the hook: hang it up. The next morning: all full again.
    s.players.get_mut(&1).unwrap().inventory.take_out(0).ok();
    stand_next_to(&mut s, 1, hf, hook);
    let body = s.players[&1].body;
    let key_in_hands = s.players[&1].inventory.held_kind() == item_kind::STORE_KEY;
    if !key_in_hands {
        let at = s.players[&1].inventory.pockets.iter().position(|i| i.as_ref().is_some_and(|i| i.kind == item_kind::STORE_KEY)).unwrap();
        s.players.get_mut(&1).unwrap().inventory.take_out(at).unwrap();
    }
    s.use_supplies(1, &body);
    assert!(s.supplies.key_on_hook && !s.players[&1].inventory.has(item_kind::STORE_KEY));
    s.restock_supplies();
    assert_eq!(s.supplies.stock.left(item_kind::COLA), supplies::STOREROOM_STOCK);
}

#[test]
fn medicines_help_and_a_rolled_cigarette_is_as_good_as_the_rolling() {
    use crate::supplies::{self, lines};
    let mut s = server();
    add_player(&mut s, 1);
    let (cf, cabinet) = s.supplies.cabinet.expect("a first-aid cabinet");
    stand_next_to(&mut s, 1, cf, cabinet);
    let body = s.players[&1].body;
    s.players.get_mut(&1).unwrap().needs.health = 50 * crate::needs::SCALE;
    s.use_supplies(1, &body);
    assert_eq!(s.players[&1].container, Some(container::CABINET));
    s.handle_container_action(1, container::CABINET, container::TAKE, 0, item_kind::PAINKILLER);
    let at = s.players[&1].inventory.pockets.iter().position(|i| i.as_ref().is_some_and(|i| i.kind == item_kind::PAINKILLER)).unwrap();
    s.players.get_mut(&1).unwrap().inventory.take_out(at).unwrap();
    s.use_held(1);
    assert_eq!(s.players[&1].needs.health_points(), 70);
    assert_eq!(s.supplies.stock.left(item_kind::PAINKILLER), supplies::MEDICINE_STOCK - 1);
    // Tobacco from the shop (paid): roll one - a bad one crumbles, a good one smokes.
    let pack = crate::inventory::Item { count: 10, ..s.mint_item(item_kind::TOBACCO, "") };
    s.players.get_mut(&1).unwrap().inventory.hands = Some(pack);
    s.handle_roll(1, 12);
    s.handle_roll(1, 92);
    let rolls: Vec<(u8, String)> =
        s.players[&1].inventory.items().filter(|i| i.kind == item_kind::ROLLED).map(|i| (i.quality, i.label.clone())).collect();
    assert_eq!(rolls, vec![(12, "Skręt (rozsypujący się)".into()), (92, "Skręt (idealny)".into())]);
    assert_eq!(s.players[&1].inventory.hands.as_ref().unwrap().count, 8, "two rolls from the pack");
    s.players.get_mut(&1).unwrap().inventory.put_away().unwrap(); // the pack into a pocket
    let slot = |s: &Server, q: u8| s.players[&1].inventory.pockets.iter().position(|i| i.as_ref().is_some_and(|i| i.quality == q)).unwrap();
    let bad = slot(&s, 12);
    s.players.get_mut(&1).unwrap().inventory.take_out(bad).unwrap();
    s.says.clear();
    s.use_held(1);
    assert!(s.says.iter().any(|l| l.text == lines::CRUMBLED) && s.players[&1].rest.is_none());
    let good = slot(&s, 92);
    s.players.get_mut(&1).unwrap().inventory.take_out(good).unwrap();
    s.use_held(1);
    assert!(matches!(s.players[&1].rest, Some((crate::needs::Rest::Smoking { .. }, _, _))), "smoking the good one");
}

#[test]
fn typed_chat_reaches_the_room_a_whisper_one_person_a_shout_the_floor() {
    use super::Reach;
    let mut s = server();
    add_player(&mut s, 1);
    add_player(&mut s, 2);
    s.players.get_mut(&2).unwrap().body.pos = Pos::tile_center(6, 5);
    s.handle_chat_say(1, "Cześć wszystkim");
    s.handle_chat_say(1, "drugi raz od razu"); // flood guard: dropped
    assert_eq!(s.says.len(), 1);
    assert!(s.says[0].text == "Cześć wszystkim" && s.says[0].reach == Reach::Room);
    s.tick += 20;
    s.handle_chat_say(1, "/s idziemy na kawę?");
    let w = s.says.last().unwrap();
    assert!(w.reach == Reach::Whisper && w.to == Some(2) && w.text == "(szeptem) idziemy na kawę?");
    s.tick += 20;
    s.handle_chat_say(1, "/k pożar");
    let k = s.says.last().unwrap();
    assert!(k.reach == Reach::Floor && k.text == "(krzyczy) POŻAR");
    // Nobody close: the whisper goes nowhere (a note to self).
    s.players.get_mut(&2).unwrap().body.pos = Pos::tile_center(30, 30);
    s.tick += 20;
    s.handle_chat_say(1, "/s halo?");
    assert_eq!(s.says.last().unwrap().text, super::chat::lines::NOBODY_TO_WHISPER);
}

#[test]
fn the_liquor_cabinet_key_is_hidden_and_found_by_searching() {
    use crate::supplies::lines;
    let mut s = server();
    add_player(&mut s, 1);
    assert!(s.supplies.hiding.len() >= 5, "plants, bins, wardrobes: {}", s.supplies.hiding.len());
    let (lf, lt) = s.supplies.liquor.expect("a liquor cabinet");
    assert_eq!(s.building.floor(lf).unwrap().room_name(s.building.floor(lf).unwrap().room_at_tile(lt.x + 1, lt.y)), "Sala spotkań 2");
    // Locked without the key.
    stand_next_to(&mut s, 1, lf, lt);
    let body = s.players[&1].body;
    s.use_supplies(1, &body);
    assert!(s.says.iter().any(|l| l.text == lines::BAR_LOCKED));
    // Search the wrong place, then the right one.
    let at = s.supplies.bar_key_at.expect("hidden");
    let wrong = (at + 1) % s.supplies.hiding.len();
    let (f, t, _) = s.supplies.hiding[wrong];
    stand_next_to(&mut s, 1, f, t);
    let body = s.players[&1].body;
    // (If two hiding places are next to each other, the nearest is searched.)
    s.search_hideout(1, &body);
    let (f, t, _) = s.supplies.hiding[at];
    stand_next_to(&mut s, 1, f, t);
    let body = s.players[&1].body;
    s.search_hideout(1, &body);
    assert!(s.players[&1].inventory.has(item_kind::BAR_KEY), "found it");
    assert_eq!(s.supplies.bar_key_at, None);
    // Now the cabinet opens: a whisky, and it's alcohol.
    stand_next_to(&mut s, 1, lf, lt);
    let body = s.players[&1].body;
    s.use_supplies(1, &body);
    s.handle_container_action(1, container::BAR, container::TAKE, 0, item_kind::WHISKY);
    let at = s.players[&1].inventory.pockets.iter().position(|i| i.as_ref().is_some_and(|i| i.kind == item_kind::WHISKY)).unwrap();
    s.players.get_mut(&1).unwrap().inventory.take_out(at).unwrap();
    s.use_held(1);
    assert_eq!(s.players[&1].needs.alcohol_points(), 25);
    // Somebody has the key: the next morning it stays with them.
    s.hide_bar_key();
    assert_eq!(s.supplies.bar_key_at, None);
}

#[test]
fn a_lost_passerby_asks_the_way_to_number_50() {
    let mut s = server();
    add_player(&mut s, 1);
    let p = s.players.get_mut(&1).unwrap();
    p.body = Body::at(0, Pos::tile_center(30, 59)); // the sidewalk
    p.room = s.building.floor(0).unwrap().room_at_tile(30, 59);
    let npcs = s.npcs.len();
    s.send_passerby(1);
    assert_eq!(s.npcs.len(), npcs + 1, "somebody walks up");
    let id = s.npcs.last().unwrap().id;
    let mut asked = None;
    for _ in 0..2000 {
        s.tick += 1;
        let ev = s.tick_npcs();
        s.apply_npc_events(ev);
        if let Some(super::lost::Lost { phase: super::lost::Phase::Asking(d, _), .. }) = s.passersby.now {
            asked = Some(d);
            break;
        }
    }
    let dialog = asked.expect("asks the way");
    assert!(s.says.iter().any(|l| l.speaker == id && l.text == super::lost::lines::ASK));
    // "Yes, it's here": in through the door, back out with a complaint, gone.
    assert!(s.answer_lost(1, dialog, 1));
    for _ in 0..4000 {
        s.tick += 1;
        let ev = s.tick_npcs();
        s.apply_npc_events(ev);
        if s.passersby.now.is_none() {
            break;
        }
    }
    assert!(s.says.iter().any(|l| l.text == super::lost::lines::TRICKED), "tricked");
    assert!(s.passersby.now.is_none() && !s.npcs.iter().any(|n| n.id == id), "walked off");
}

#[test]
fn skipping_the_wait_is_a_vote_and_ends_in_the_morning() {
    let mut s = server();
    for id in 1..=3 {
        add_player(&mut s, id);
        s.players.get_mut(&id).unwrap().contract = true;
    }
    s.clock.ds = 15 * 60 * crate::clock::DS_PER_MIN;
    s.players.get_mut(&1).unwrap().stage = Stage::Home { arrive_at: None };
    // At work you can't start it; from home - a vote, 1 of 3 isn't enough.
    s.handle_skip_wait(2);
    assert!(s.skip_vote.is_none(), "only from home");
    s.handle_skip_wait(1);
    assert!(s.skip_vote.is_some() && !s.clock.skip);
    assert!(matches!(s.clock_packet(&s.players[&1]), Packet::Clock { skip: 1, .. }), "the vote is on");
    // A no, then a yes: 2 of 3 - passed, everybody goes home, time flies.
    assert!(s.answer_skip_vote(3, super::leave::VOTE_ID, 1));
    assert!(s.skip_vote.is_some());
    assert!(s.answer_skip_vote(2, super::leave::VOTE_ID, 0));
    assert!(s.skip_vote.is_none() && s.clock.skip);
    assert!(s.players.values().all(|p| matches!(p.stage, Stage::Home { .. })), "all at home");
    // Morning: no more skipping - there's time to pick how to get to work.
    while s.clock.minute() != crate::clock::OPEN_MIN {
        s.tick_clock();
    }
    assert!(!s.clock.skip, "the morning stops it");
    assert!(s.players.values().all(|p| p.depart_at.is_some()), "everybody still to leave");
}

#[test]
fn a_skip_vote_fails_on_no_or_when_time_is_up() {
    let mut s = server();
    for id in 1..=2 {
        add_player(&mut s, id);
        s.players.get_mut(&id).unwrap().stage = Stage::Home { arrive_at: None };
    }
    s.handle_skip_wait(1);
    s.answer_skip_vote(2, super::leave::VOTE_ID, 1);
    assert!(s.skip_vote.is_none() && !s.clock.skip, "half against: no");
    s.handle_skip_wait(2);
    s.tick += 30 * 20;
    s.tick_skip_vote();
    assert!(s.skip_vote.is_none() && !s.clock.skip, "nobody else answered in time");
    // Alone: your own yes is enough.
    s.players.remove(&2);
    s.handle_skip_wait(1);
    assert!(s.clock.skip);
}

#[test]
fn colleagues_who_left_stay_on_the_messenger_as_away() {
    let mut s = server();
    // Kuba was here (hired) and left; p1 is online (saved too: not twice).
    for (id, nick) in [(2, "Kuba"), (1, "p1")] {
        add_player(&mut s, id);
        let p = s.players.get_mut(&id).unwrap();
        p.contract = true;
        p.nick = nick.into();
        let p = s.players.remove(&id).unwrap();
        let c = s.capture(&p);
        s.offline.characters.insert(p.nick.clone(), c);
        if id == 1 {
            s.players.insert(id, p);
        }
    }
    assert_eq!(s.offline_colleagues(), vec!["Kuba".to_string()]);
}

#[test]
fn back_to_work_from_home_rested_and_fed() {
    let mut s = server();
    add_player(&mut s, 1);
    let p = s.players.get_mut(&1).unwrap();
    p.contract = true;
    p.stage = Stage::Home { arrive_at: None };
    // Went home worn out, hungry, drunk and beaten up.
    p.needs.energy = 5 * crate::needs::SCALE;
    p.needs.hunger = 95 * crate::needs::SCALE;
    p.needs.hygiene = 10 * crate::needs::SCALE;
    p.needs.alcohol = 80;
    p.needs.health = 0;
    s.clock.ds = 8 * 60 * crate::clock::DS_PER_MIN;
    s.players.get_mut(&1).unwrap().depart_at = Some(s.clock.total_minutes());
    s.tick_clock();
    let n = &s.players[&1].needs;
    assert!(matches!(s.players[&1].stage, Stage::Home { arrive_at: Some(_) }), "on the way");
    assert_eq!(*n, crate::needs::Needs::default(), "a night at home: all fresh");
}

#[test]
fn a_laptop_left_on_a_desk_shows_whose_it_is() {
    let mut s = server();
    add_player(&mut s, 2);
    let mut laptop = s.mint_item(item_kind::LAPTOP, "Laptop: Ola");
    laptop.owner = 0; // Ola logged out
    s.computers.push(crate::computer::Computer { handle: 900, station: 0, item: laptop, locked: true, user: None });
    s.players.get_mut(&2).unwrap().at_computer = Some(900);
    let nick = |s: &Server| match s.computer_packet(2) {
        Some(Packet::Computer { owner_nick, .. }) => owner_nick,
        other => panic!("{other:?}"),
    };
    assert_eq!(nick(&s), "Ola", "by the label (a save from before)");
    s.offline.laptop_owner.insert(900, "Ola2".into());
    assert_eq!(nick(&s), "Ola2", "the save knows whose it is");
}

/// Log out: the save keeps the character; log back in as a new session.
fn relog(s: &mut Server, id: u16, new_id: u16) {
    let p = s.players.remove(&id).unwrap();
    let c = s.capture(&p);
    s.offline.characters.insert(p.nick.clone(), c);
    add_player(s, new_id);
    let q = s.players.get_mut(&new_id).unwrap();
    q.nick = p.nick.clone();
    q.stage = Stage::Portal(Box::default());
    q.profile = crate::protocol::Profile::default(); // the client's stand-in
    assert!(s.restore(new_id));
}

#[test]
fn hired_and_still_at_home_keeps_the_job_after_logging_out() {
    let mut s = server();
    on_portal(&mut s, 1);
    s.players.get_mut(&1).unwrap().profile.email = "ola@poczta.pl".into();
    let places = s.places(1);
    s.hire(1, 1);
    assert_eq!(s.places(1), places - 1);
    relog(&mut s, 1, 2);
    let p = &s.players[&2];
    assert_eq!(p.profile.email, "ola@poczta.pl", "the real profile, not the stand-in");
    assert_eq!(p.position, Some(1), "still hired");
    assert!(matches!(&p.stage, Stage::Portal(d) if d.hired.is_some()), "can go to the office");
    assert!(inbox_subjects(&s, 2).contains(&"Zaproszenie na dzień próbny".to_string()), "the invitation again");
    assert_eq!(s.places(1), places - 1, "the place stays theirs, no more taken");
}

#[test]
fn on_the_trial_day_comes_back_into_the_building_with_the_pass() {
    use crate::protocol::portal_action;
    let mut s = server();
    s.clock.ds = 9 * 60 * crate::clock::DS_PER_MIN;
    on_portal(&mut s, 1);
    s.hire(1, 1);
    s.handle_portal_action(1, portal_action::GO_TO_OFFICE, 0);
    assert!(matches!(s.players[&1].stage, Stage::Working));
    let pass = s.mint_item(item_kind::GUEST_PASS, "");
    s.players.get_mut(&1).unwrap().inventory.pockets[0] = Some(pass);
    let dept = s.players[&1].department;
    relog(&mut s, 1, 2);
    let p = &s.players[&2];
    assert!(matches!(p.stage, Stage::Working), "back in the building");
    assert!(!p.contract && p.position == Some(1) && p.department == dept, "the trial day goes on");
    assert!(p.inventory.has(item_kind::GUEST_PASS), "with the porter's pass");
}

#[test]
fn back_at_work_by_car_the_car_is_parked_and_takes_you_home() {
    let mut s = server();
    s.clock = crate::clock::Clock::new(12 * 60, 1); // midday
    add_player(&mut s, 1);
    s.employ(1);
    let p = s.players.get_mut(&1).unwrap();
    p.stage = Stage::Working;
    p.commute_mode = crate::commute::mode::CAR;
    relog(&mut s, 1, 2);
    let v = s.vehicles.iter().find(|v| v.owner == 2).expect("the car is in the car park");
    assert!(v.parked());
    // Twice at the car: home.
    let p = s.players.get_mut(&2).unwrap();
    p.body = Body { access: p.body.access, ..Body::at(0, v.pos) };
    let body = p.body;
    assert_eq!(s.try_go_home(2, &body).as_deref(), Some(crate::commute::lines::GO_HOME_ASK));
    s.try_go_home(2, &body);
    assert!(matches!(s.players[&2].stage, Stage::Home { .. }), "went home by car");
    // Logging in again doesn't park a second one.
    s.players.get_mut(&2).unwrap().stage = Stage::Working;
    s.vehicles.clear();
    s.park_own_vehicle(2);
    s.park_own_vehicle(2);
    assert_eq!(s.vehicles.iter().filter(|v| v.owner == 2).count(), 1);
}

#[test]
fn hr_finds_a_lost_laptop_or_issues_a_new_one() {
    use super::lost_items::{lines, DIALOG};
    let mut s = server();
    add_player(&mut s, 1);
    add_player(&mut s, 2);
    s.employ(1);
    let hr = s.npcs.iter().find(|n| n.role == crate::npc::Role::Hr).unwrap().id;
    let ask = |s: &mut Server, choice: u8| -> String {
        s.says.clear();
        s.hr_desk(hr, 1);
        assert!(s.answer_hr_desk(1, DIALOG, choice));
        s.says.iter().find(|l| l.speaker == hr).map(|l| l.text.clone()).unwrap_or_default()
    };
    // With them: nothing to do.
    assert_eq!(ask(&mut s, 0), lines::WITH_YOU);
    // On the floor somewhere: where.
    let laptop = s.players.get_mut(&1).unwrap().inventory.take_hands().unwrap();
    s.drop_at(4, Pos::tile_center(36, 16), laptop);
    assert!(ask(&mut s, 0).starts_with("Ktoś widział twój laptop na podłodze"));
    // Somebody else has it: who.
    let d = s.dropped.iter().position(|d| d.item.kind == item_kind::LAPTOP).unwrap();
    let laptop = s.dropped.remove(d).item;
    s.give(2, laptop);
    assert_eq!(ask(&mut s, 0), lines::with("twój laptop", "p2"));
    // Really gone: a new one (only that one).
    s.players.get_mut(&2).unwrap().inventory.remove_owned_by(1);
    assert_eq!(ask(&mut s, 0), lines::NEW_LAPTOP);
    assert_eq!(s.players[&1].inventory.items().filter(|i| i.kind == item_kind::LAPTOP && i.owner == 1).count(), 1);
    // The card in the pocket: there.
    assert_eq!(ask(&mut s, 1), lines::CARD_WITH_YOU);
}

#[test]
fn the_laptop_carried_out_is_still_yours_after_logging_back_in() {
    let mut s = server();
    add_player(&mut s, 1);
    s.employ(1);
    s.players.get_mut(&1).unwrap().stage = Stage::Working;
    let own = |s: &Server, id: u16, kind: u8| s.players[&id].inventory.items().any(|i| i.kind == kind && i.owner == id);
    assert!(own(&s, 1, item_kind::LAPTOP) && own(&s, 1, item_kind::EMPLOYEE_CARD));
    relog(&mut s, 1, 2);
    assert!(own(&s, 2, item_kind::LAPTOP), "the laptop's account is still theirs (messenger, company panel)");
    assert!(own(&s, 2, item_kind::EMPLOYEE_CARD));
    // A save from before the fix (no owner on them): theirs again.
    let p = s.players.remove(&2).unwrap();
    let mut c = s.capture(&p);
    c.inventory.iter_mut().flatten().for_each(|i| i.owner.clear());
    s.offline.characters.insert(p.nick.clone(), c);
    add_player(&mut s, 3);
    s.players.get_mut(&3).unwrap().nick = p.nick.clone();
    assert!(s.restore(3));
    assert!(own(&s, 3, item_kind::LAPTOP) && own(&s, 3, item_kind::EMPLOYEE_CARD));
    // Such a laptop already put on a desk: by its label, theirs again.
    let p = s.players.get_mut(&3).unwrap();
    let mut laptop = p.inventory.take_hands().unwrap();
    assert_eq!(laptop.kind, item_kind::LAPTOP);
    laptop.owner = 0;
    s.computers.push(crate::computer::Computer { handle: 900, station: 0, item: laptop, locked: false, user: None });
    relog(&mut s, 3, 4);
    assert_eq!(s.computers.iter().find(|c| c.handle == 900).unwrap().owner(), 4);
}
