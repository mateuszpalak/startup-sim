//! Daily duties at work (`crate::duties`): today's list each morning, E at
//! a duty's place opens its minigame, the result pays.

use crate::duties::{state, Game};
use crate::needs::USE_RADIUS;
use crate::protocol::{self as proto, DutyInfo, Packet};
use crate::shop;
use crate::sim::{Body, Pos};

use super::player::Stage;
use super::{dist2, Server, TICK_HZ};

const RESEND_TICKS: u32 = 5 * TICK_HZ;
/// Network jitter allowed on a hold minigame's length.
const HOLD_SLACK_TICKS: u32 = TICK_HZ / 2;
/// Walking this far from the duty's place closes its minigame.
const LEAVE_RADIUS: i32 = USE_RADIUS * 2;
/// Put off with Esc: E there does its usual thing this long.
const SNOOZE_TICKS: u32 = 10 * TICK_HZ;

/// The minigame a player has open.
#[derive(Debug, Clone)]
pub(super) struct DutyGame {
    pub(super) session: u8,
    pub(super) index: usize,
    pub(super) opened: u32,
    /// Choice: the scenario of the pool, and the original option behind each
    /// shown one (they are shuffled).
    pub(super) scenario: usize,
    pub(super) order: Vec<usize>,
}

fn station_pos(a: &crate::duties::Assigned) -> Pos {
    Pos::tile_center(i32::from(a.x), i32::from(a.y))
}

fn close_packet() -> Packet {
    Packet::DutyStart { session: 0, kind: 0, seconds: 0, title: String::new(), text: String::new(), options: Vec::new() }
}

impl Server {
    /// New lists for whoever starts a working day, minigames left behind
    /// closed, the list sent when it changed and every few seconds.
    pub(super) fn tick_duties(&mut self) {
        let starting: Vec<u16> = self
            .players
            .values()
            .filter(|p| p.contract && matches!(p.stage, Stage::Working) && p.duties.day != p.day)
            .map(|p| p.id)
            .collect();
        for pid in starting {
            self.assign_duties(pid);
        }
        let walked_off: Vec<u16> = self
            .players
            .values()
            .filter(|p| {
                p.duty_game.as_ref().is_some_and(|g| {
                    let off = !matches!(p.stage, Stage::Working)
                        || p.duties
                            .list
                            .get(g.index)
                            .is_none_or(|a| a.floor != p.body.floor || dist2(station_pos(a), p.body.pos) > LEAVE_RADIUS * LEAVE_RADIUS);
                    off
                })
            })
            .map(|p| p.id)
            .collect();
        for pid in walked_off {
            if let Some(p) = self.players.get_mut(&pid) {
                p.duty_game = None;
            }
            self.send_to(pid, &close_packet());
        }
        let due: Vec<u16> = self
            .players
            .values()
            .filter(|p| p.duties_dirty || (p.contract && (self.tick + u32::from(p.id)).is_multiple_of(RESEND_TICKS)))
            .map(|p| p.id)
            .collect();
        for pid in due {
            let Some(p) = self.players.get_mut(&pid) else { continue };
            p.duties_dirty = false;
            let packet = self.duties_packet(pid);
            self.send_to(pid, &packet);
        }
    }

    fn assign_duties(&mut self, pid: u16) {
        let Some(p) = self.players.get_mut(&pid) else { return };
        let duties = &self.cfg.duties;
        let list = duties.assign(&mut self.rng, p.department, &self.stations);
        let week = duties.week_of(p.day);
        let n = list.len();
        p.duties.start_day(p.day, list, week);
        p.duty_game = None;
        p.duties_dirty = true;
        let msg = format!("* {} gets {n} duties for day {}", p.nick, p.day);
        self.log(msg);
    }

    pub(super) fn duties_packet(&self, pid: u16) -> Packet {
        let d = &self.cfg.duties;
        let reward = |gr: i64| u32::try_from(gr.max(0)).unwrap_or(u32::MAX);
        let Some(p) = self.players.get(&pid).filter(|p| p.contract) else {
            return Packet::Duties { week_done: 0, week_goal: 0, week_bonus: 0, day_bonus: 0, duties: Vec::new() };
        };
        let duties = p
            .duties
            .list
            .iter()
            .filter_map(|a| {
                let def = d.duty(&a.duty)?;
                Some(DutyInfo { title: def.title.clone(), floor: a.floor, x: a.x, y: a.y, state: a.state, reward: reward(def.reward) })
            })
            .collect();
        Packet::Duties {
            week_done: u8::try_from(p.duties.week_done).unwrap_or(u8::MAX),
            week_goal: u8::try_from(d.week.goal).unwrap_or(u8::MAX),
            week_bonus: reward(d.week.bonus),
            day_bonus: reward(d.day_bonus),
            duties,
        }
    }

    /// E at the place of one of today's open duties, hands free: its
    /// minigame; `false` if there is none in reach (with something in hands
    /// E does the place's usual thing: coffee with a mug, a laptop on a desk).
    pub(super) fn use_duty(&mut self, pid: u16, body: &Body) -> bool {
        let Some(p) = self.players.get(&pid).filter(|p| p.contract && p.inventory.hands_free()) else { return false };
        if let Some(g) = &p.duty_game {
            let index = g.index;
            let packet = self.duty_start_packet(pid, index);
            if let Some(pk) = packet {
                self.send_to(pid, &pk);
            }
            return true;
        }
        let snoozed = p.duty_snooze.filter(|&(_, until)| self.tick < until).map(|(i, _)| i);
        let Some(index) = p
            .duties
            .list
            .iter()
            .enumerate()
            .filter(|&(i, a)| a.state == state::TODO && a.floor == body.floor && Some(i) != snoozed && !self.laptop_on(a))
            .map(|(i, a)| (i, dist2(station_pos(a), body.pos)))
            .filter(|&(_, d)| d <= USE_RADIUS * USE_RADIUS)
            .min_by_key(|&(_, d)| d)
            .map(|(i, _)| i)
        else {
            return false;
        };
        let Some(def) = p.duties.list.get(index).and_then(|a| self.cfg.duties.duty(&a.duty)) else { return false };
        let (scenario, order) = match &def.game {
            Game::Hold { .. } => (0, Vec::new()),
            Game::Choice { pool } => {
                let scenarios = &self.cfg.duties.pools[pool];
                let scenario = self.rng.usize(..scenarios.len());
                let mut order: Vec<usize> = (0..scenarios[scenario].options.len()).collect();
                self.rng.shuffle(&mut order);
                (scenario, order)
            }
        };
        let tick = self.tick;
        let Some(p) = self.players.get_mut(&pid) else { return false };
        p.next_duty_session = p.next_duty_session.wrapping_add(1).max(1);
        p.duty_game = Some(DutyGame { session: p.next_duty_session, index, opened: tick, scenario, order });
        if let Some(pk) = self.duty_start_packet(pid, index) {
            self.send_to(pid, &pk);
        }
        true
    }

    /// A laptop stands on the duty's desk: E there is for the computer.
    fn laptop_on(&self, a: &crate::duties::Assigned) -> bool {
        self.computers
            .iter()
            .filter_map(|c| self.workstations.get(c.station))
            .any(|w| w.floor == a.floor && (w.tile.x, w.tile.y) == (i32::from(a.x), i32::from(a.y)))
    }

    fn duty_start_packet(&self, pid: u16, index: usize) -> Option<Packet> {
        let p = self.players.get(&pid)?;
        let g = p.duty_game.as_ref()?;
        let def = self.cfg.duties.duty(&p.duties.list.get(index)?.duty)?;
        Some(match &def.game {
            Game::Hold { seconds, text } => Packet::DutyStart {
                session: g.session,
                kind: proto::duty_kind::HOLD,
                seconds: *seconds,
                title: def.title.clone(),
                text: text.clone(),
                options: Vec::new(),
            },
            Game::Choice { pool } => {
                let s = self.cfg.duties.pools.get(pool)?.get(g.scenario)?;
                Packet::DutyStart {
                    session: g.session,
                    kind: proto::duty_kind::CHOICE,
                    seconds: 0,
                    title: def.title.clone(),
                    text: s.text.clone(),
                    options: g.order.iter().filter_map(|&i| s.options.get(i)).map(|o| o.text.clone()).collect(),
                }
            }
        })
    }

    /// The minigame's result: held long enough, or the option picked.
    pub(super) fn handle_duty_result(&mut self, pid: u16, session: u8, value: u8) {
        let Some(p) = self.players.get(&pid) else { return };
        let Some(g) = p.duty_game.clone().filter(|g| g.session == session) else { return };
        if value == proto::DUTY_LATER {
            let until = self.tick + SNOOZE_TICKS;
            let Some(p) = self.players.get_mut(&pid) else { return };
            p.duty_game = None;
            p.duty_snooze = Some((g.index, until));
            self.send_to(pid, &close_packet());
            return;
        }
        let Some(a) = p.duties.list.get(g.index) else { return };
        let Some(def) = self.cfg.duties.duty(&a.duty).cloned() else { return };
        let (good, reply) = match &def.game {
            Game::Hold { seconds, .. } => {
                let needed = u32::from(*seconds) * TICK_HZ;
                if self.tick.saturating_sub(g.opened) + HOLD_SLACK_TICKS < needed {
                    return;
                }
                (true, def.done.clone())
            }
            Game::Choice { pool } => {
                let Some(o) =
                    g.order.get(usize::from(value)).and_then(|&i| self.cfg.duties.pools.get(pool)?.get(g.scenario)?.options.get(i))
                else {
                    return;
                };
                (o.good, o.reply.clone())
            }
        };
        let Some(p) = self.players.get_mut(&pid) else { return };
        p.duty_game = None;
        let Some(pay) = p.duties.finish(g.index, good, &self.cfg.duties) else { return };
        p.money += pay.total();
        p.duties_dirty = true;
        let nick = p.nick.clone();
        self.save_soon = true;
        self.send_to(pid, &close_packet());
        if !reply.is_empty() {
            self.notify(pid, proto::notice::FUN, reply);
        }
        let verdict = if good { "Zrobione" } else { "Poszło średnio" };
        self.notify(pid, proto::notice::INFO, format!("{verdict}: {} (+{})", def.title, shop::zl(pay.duty)));
        if pay.day_bonus > 0 {
            self.notify(pid, proto::notice::FUN, format!("Wszystkie obowiązki na dziś! Premia +{}", shop::zl(pay.day_bonus)));
        }
        if pay.week_bonus > 0 {
            self.notify(pid, proto::notice::FUN, format!("Cel tygodnia osiągnięty! Premia +{}", shop::zl(pay.week_bonus)));
        }
        self.log(format!("* {nick} finished duty {} ({}), paid {}", def.id, if good { "good" } else { "botched" }, shop::zl(pay.total())));
    }
}
