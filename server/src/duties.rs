//! Daily duties (GDD: obowiązki dnia): every employee gets a few small jobs
//! each morning, done at a place in the building with a short minigame. All
//! of it works solo; other players only make it livelier.
//!
//! Data: `server/data/duties.json`: the duties (where, which minigame, the
//! pay), the choice pools (code review, stand-up, ...), the day and week
//! bonuses. A new duty is a new entry there, not new code.

use std::collections::HashMap;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::building::Building;
use crate::protocol::{MAX_OPTIONS, MAX_TEXT_BYTES};

pub const MAX_PER_DAY: usize = 8;
pub const MAX_TITLE_BYTES: usize = crate::protocol::MAX_DUTY_TITLE_BYTES;
pub const MAX_OPTION_BYTES: usize = crate::protocol::MAX_DUTY_OPTION_BYTES;
const MAX_HOLD_SECONDS: u8 = 30;

pub use crate::protocol::{duty_kind as kind, duty_state as state};

#[derive(Debug, Deserialize, Clone)]
pub struct StationRule {
    pub tile: String,
    #[serde(default)]
    pub room_kind: Option<String>,
    #[serde(default)]
    pub own_department: bool,
}

#[derive(Debug, Deserialize, Clone)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Game {
    Hold { seconds: u8, text: String },
    Choice { pool: String },
}

#[derive(Debug, Deserialize, Clone)]
pub struct Duty {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub departments: Vec<u8>,
    pub station: StationRule,
    pub game: Game,
    pub reward: i64,
    #[serde(default)]
    pub reward_bad: i64,
    #[serde(default)]
    pub done: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Answer {
    pub text: String,
    pub good: bool,
    pub reply: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Scenario {
    pub text: String,
    pub options: Vec<Answer>,
}

#[derive(Debug, Deserialize, Clone, Copy)]
pub struct Week {
    pub days: u32,
    pub goal: u32,
    pub bonus: i64,
}

#[derive(Debug, Deserialize)]
pub struct Duties {
    version: u32,
    pub per_day: [usize; 2],
    pub day_bonus: i64,
    pub week: Week,
    pub duties: Vec<Duty>,
    pub pools: HashMap<String, Vec<Scenario>>,
}

const BUILTIN: &str = include_str!("../data/duties.json");

impl Duties {
    pub fn builtin() -> Duties {
        Duties::parse(BUILTIN.as_bytes()).expect("server/data/duties.json is valid")
    }

    pub fn load(path: &Path) -> Result<Duties, String> {
        let bytes = std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
        Duties::parse(&bytes)
    }

    fn parse(bytes: &[u8]) -> Result<Duties, String> {
        let d: Duties = serde_json::from_slice(bytes).map_err(|e| format!("duties json: {e}"))?;
        d.validate()?;
        Ok(d)
    }

    fn validate(&self) -> Result<(), String> {
        if self.version != 1 {
            return Err(format!("unsupported duties version {}", self.version));
        }
        let [lo, hi] = self.per_day;
        if lo == 0 || lo > hi || hi > MAX_PER_DAY {
            return Err(format!("per_day must be 1..={MAX_PER_DAY}, [min, max]"));
        }
        if self.week.days == 0 || self.week.goal == 0 {
            return Err("week needs days and a goal".into());
        }
        for d in &self.duties {
            if d.title.is_empty() || d.title.len() > MAX_TITLE_BYTES {
                return Err(format!("duty {}: title must be 1..={MAX_TITLE_BYTES} bytes", d.id));
            }
            if d.done.len() > MAX_TEXT_BYTES {
                return Err(format!("duty {}: done text too long", d.id));
            }
            if self.duties.iter().filter(|o| o.id == d.id).count() > 1 {
                return Err(format!("duty {}: duplicate id", d.id));
            }
            match &d.game {
                Game::Hold { seconds, text } => {
                    if !(1..=MAX_HOLD_SECONDS).contains(seconds) || text.len() > MAX_TEXT_BYTES {
                        return Err(format!("duty {}: hold needs 1..={MAX_HOLD_SECONDS} s and a short text", d.id));
                    }
                }
                Game::Choice { pool } => {
                    if self.pools.get(pool).is_none_or(|p| p.is_empty()) {
                        return Err(format!("duty {}: unknown or empty pool '{pool}'", d.id));
                    }
                }
            }
        }
        for (name, pool) in &self.pools {
            for s in pool {
                if s.text.len() > MAX_TEXT_BYTES {
                    return Err(format!("pool {name}: '{}' too long", s.text));
                }
                if !(2..=MAX_OPTIONS).contains(&s.options.len()) || !s.options.iter().any(|o| o.good) {
                    return Err(format!("pool {name}: '{}' needs 2..={MAX_OPTIONS} options, one of them good", s.text));
                }
                if s.options.iter().any(|o| o.text.len() > MAX_OPTION_BYTES || o.reply.len() > MAX_TEXT_BYTES) {
                    return Err(format!("pool {name}: '{}' option too long", s.text));
                }
            }
        }
        Ok(())
    }

    pub fn duty(&self, id: &str) -> Option<&Duty> {
        self.duties.iter().find(|d| d.id == id)
    }

    pub fn week_of(&self, day: u32) -> u32 {
        day.saturating_sub(1) / self.week.days
    }

    /// Today's duties for someone of `department`: a few different ones,
    /// each at a random place that fits (the department's floor first).
    pub fn assign(&self, rng: &mut fastrand::Rng, department: u8, stations: &[Station]) -> Vec<Assigned> {
        let home_floor = stations.iter().find(|s| s.department == department && department != 0).map(|s| s.floor);
        let mut picks: Vec<(&Duty, Vec<&Station>)> = self
            .duties
            .iter()
            .filter(|d| d.departments.is_empty() || d.departments.contains(&department))
            .filter_map(|d| {
                let fits: Vec<&Station> = stations.iter().filter(|s| s.fits(&d.station, department)).collect();
                let near: Vec<&Station> = fits.iter().copied().filter(|s| Some(s.floor) == home_floor).collect();
                let places = if near.is_empty() { fits } else { near };
                (!places.is_empty()).then_some((d, places))
            })
            .collect();
        rng.shuffle(&mut picks);
        let [lo, hi] = self.per_day;
        let n = rng.usize(lo..=hi).min(picks.len());
        let (mut own, mut anyone): (Vec<_>, Vec<_>) = picks.into_iter().partition(|(d, _)| !d.departments.is_empty());
        let own_n = own.len().min(n.div_ceil(2));
        let mut today: Vec<_> = own.drain(..own_n).collect();
        today.extend(anyone.drain(..anyone.len().min(n - today.len())));
        today.extend(own.drain(..own.len().min(n - today.len())));
        rng.shuffle(&mut today);
        today
            .into_iter()
            .map(|(d, places)| {
                let s = places[rng.usize(..places.len())];
                Assigned { duty: d.id.clone(), floor: s.floor, x: s.x, y: s.y, state: state::TODO }
            })
            .collect()
    }
}

/// A tile where a duty can be done, with the room it belongs to.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Station {
    pub floor: u8,
    pub x: u8,
    pub y: u8,
    pub tile: String,
    pub room_kind: String,
    pub department: u8,
}

impl Station {
    pub fn fits(&self, rule: &StationRule, department: u8) -> bool {
        self.tile == rule.tile
            && rule.room_kind.as_ref().is_none_or(|k| *k == self.room_kind)
            && (!rule.own_department || (department != 0 && self.department == department))
    }
}

/// Every tile some duty may use (`rules`), on the active floors.
pub fn find_stations(b: &Building, duties: &Duties) -> Vec<Station> {
    let tiles: Vec<&str> = duties.duties.iter().map(|d| d.station.tile.as_str()).collect();
    let mut out = Vec::new();
    for (f, m) in b.active_floors() {
        for y in 0..m.height {
            for x in 0..m.width {
                let Some(t) = m.tile_type(x, y).filter(|t| tiles.contains(t)) else { continue };
                // A solid tile (a plant, a table) belongs to the room around it.
                let room = [(0, 0), (0, 1), (1, 0), (-1, 0), (0, -1)]
                    .iter()
                    .map(|(dx, dy)| m.room_at_tile(x + dx, y + dy))
                    .find_map(|rid| m.rooms.iter().find(|r| r.id == rid));
                let (Ok(x8), Ok(y8)) = (u8::try_from(x), u8::try_from(y)) else { continue };
                out.push(Station {
                    floor: f,
                    x: x8,
                    y: y8,
                    tile: t.to_string(),
                    room_kind: room.map(|r| r.kind.clone()).unwrap_or_default(),
                    department: room.map_or(0, |r| r.department),
                });
            }
        }
    }
    out
}

/// One of today's duties: which, where, how it went.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Assigned {
    pub duty: String,
    pub floor: u8,
    pub x: u8,
    pub y: u8,
    pub state: u8,
}

/// A player's duties: today's list and the week's progress (saved).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Ledger {
    pub day: u32,
    pub list: Vec<Assigned>,
    pub day_paid: bool,
    pub week: u32,
    pub week_done: u32,
    pub week_paid: bool,
}

/// What finishing a duty earned.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct Payout {
    pub duty: i64,
    pub day_bonus: i64,
    pub week_bonus: i64,
}

impl Payout {
    pub fn total(&self) -> i64 {
        self.duty + self.day_bonus + self.week_bonus
    }
}

impl Ledger {
    pub fn is_today(&self, day: u32) -> bool {
        self.day == day && !self.list.is_empty()
    }

    /// A new day's list; a new week starts the count again.
    pub fn start_day(&mut self, day: u32, list: Vec<Assigned>, week: u32) {
        if week != self.week {
            self.week = week;
            self.week_done = 0;
            self.week_paid = false;
        }
        self.day = day;
        self.list = list;
        self.day_paid = false;
    }

    /// Duty `i` finished (`good` or botched): its pay, and the bonuses it
    /// unlocked. `None` if it isn't open.
    pub fn finish(&mut self, i: usize, good: bool, duties: &Duties) -> Option<Payout> {
        let a = self.list.get_mut(i).filter(|a| a.state == state::TODO)?;
        let d = duties.duty(&a.duty)?;
        a.state = if good { state::DONE } else { state::BOTCHED };
        let mut pay = Payout { duty: if good { d.reward } else { d.reward_bad }, ..Payout::default() };
        self.week_done += 1;
        if !self.day_paid && self.list.iter().all(|a| a.state != state::TODO) {
            self.day_paid = true;
            pay.day_bonus = duties.day_bonus;
        }
        if !self.week_paid && self.week_done >= duties.week.goal {
            self.week_paid = true;
            pay.week_bonus = duties.week.bonus;
        }
        Some(pay)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn station(tile: &str, room_kind: &str, department: u8, floor: u8) -> Station {
        Station { floor, x: 1, y: 2, tile: tile.into(), room_kind: room_kind.into(), department }
    }

    fn stations() -> Vec<Station> {
        vec![
            station("plant", "corridor", 0, 4),
            station("dishwasher", "common", 0, 4),
            station("coffee_machine", "common", 0, 4),
            station("coffee_machine", "common", 0, 3),
            station("fridge", "common", 0, 4),
            station("trash_bin", "common", 0, 4),
            station("tv", "common", 0, 4),
            station("table", "meeting", 0, 4),
            station("desk", "department", 1, 4),
            station("desk", "department", 2, 4),
        ]
    }

    #[test]
    fn builtin_data_is_valid() {
        let d = Duties::builtin();
        assert!(d.duties.len() >= 8);
    }

    #[test]
    fn assigns_distinct_duties_that_fit_the_department() {
        let d = Duties::builtin();
        let mut rng = fastrand::Rng::with_seed(7);
        for _ in 0..50 {
            let list = d.assign(&mut rng, 2, &stations());
            assert!((d.per_day[0]..=d.per_day[1]).contains(&list.len()));
            let mut ids: Vec<&str> = list.iter().map(|a| a.duty.as_str()).collect();
            ids.sort_unstable();
            ids.dedup();
            assert_eq!(ids.len(), list.len(), "no duty twice a day");
            for a in &list {
                let duty = d.duty(&a.duty).unwrap();
                assert!(duty.departments.is_empty() || duty.departments.contains(&2), "{} is not for Biznes", a.duty);
            }
        }
    }

    #[test]
    fn about_half_of_the_day_is_the_department_s_own_work() {
        let d = Duties::builtin();
        let mut rng = fastrand::Rng::with_seed(11);
        for _ in 0..50 {
            let list = d.assign(&mut rng, 1, &stations());
            let own = list.iter().filter(|a| !d.duty(&a.duty).unwrap().departments.is_empty()).count();
            assert!(own >= list.len().div_ceil(2), "{own} of {} for IT", list.len());
        }
    }

    #[test]
    fn own_department_desk_only_in_that_department() {
        let rule = StationRule { tile: "desk".into(), room_kind: None, own_department: true };
        assert!(station("desk", "department", 1, 4).fits(&rule, 1));
        assert!(!station("desk", "department", 2, 4).fits(&rule, 1));
        assert!(!station("desk", "department", 0, 4).fits(&rule, 0));
    }

    #[test]
    fn prefers_the_department_floor() {
        let d = Duties::builtin();
        let mut rng = fastrand::Rng::with_seed(3);
        for _ in 0..50 {
            for a in d.assign(&mut rng, 1, &stations()) {
                assert_eq!(a.floor, 4);
            }
        }
    }

    #[test]
    fn no_places_no_duties() {
        let d = Duties::builtin();
        assert!(d.assign(&mut fastrand::Rng::with_seed(1), 1, &[]).is_empty());
    }

    #[test]
    fn finishing_pays_once_and_unlocks_the_day_bonus() {
        let d = Duties::builtin();
        let mut l = Ledger::default();
        let list = vec![
            Assigned { duty: "plants".into(), floor: 4, x: 1, y: 1, state: state::TODO },
            Assigned { duty: "standup".into(), floor: 4, x: 2, y: 2, state: state::TODO },
        ];
        l.start_day(1, list, d.week_of(1));
        let first = l.finish(0, true, &d).unwrap();
        assert_eq!(first, Payout { duty: d.duty("plants").unwrap().reward, day_bonus: 0, week_bonus: 0 });
        assert_eq!(l.finish(0, true, &d), None, "already done");
        let last = l.finish(1, false, &d).unwrap();
        assert_eq!(last.duty, d.duty("standup").unwrap().reward_bad);
        assert_eq!(last.day_bonus, d.day_bonus);
        assert_eq!(l.list[1].state, state::BOTCHED);
    }

    #[test]
    fn the_week_goal_pays_once_and_resets_next_week() {
        let d = Duties::builtin();
        let mut l = Ledger::default();
        let one = || vec![Assigned { duty: "trash".into(), floor: 4, x: 1, y: 1, state: state::TODO }];
        let mut week_bonuses = 0;
        for day in 1..=d.week.days * 2 {
            for _ in 0..d.week.goal {
                l.start_day(day, one(), d.week_of(day));
                if l.finish(0, true, &d).unwrap().week_bonus > 0 {
                    week_bonuses += 1;
                }
            }
        }
        assert_eq!(week_bonuses, 2, "once in each of the two weeks");
        assert_eq!(d.week_of(1), d.week_of(d.week.days));
        assert_eq!(d.week_of(d.week.days + 1), 1);
    }
}
