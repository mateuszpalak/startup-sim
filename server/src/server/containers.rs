//! Containers opened with E - the fridge, the kitchen cupboard, the
//! dishwasher, the first-aid cabinet, the storeroom shelves and the bar: one
//! window with their slots next to the player's things; dragging (or a
//! click) takes things out and puts them in.

use crate::inventory::{self, kind as item_kind, Item};
use crate::kitchen::{self, lines};
use crate::protocol::{container as c, sound, ContainerSlot, Packet};
use crate::supplies;

use super::player::refresh;
use super::supplies::near;
use super::{Say, Server};

/// Open windows are refreshed once a second (somebody else took something).
const REFRESH_TICKS: u32 = 20;

pub(super) mod say {
    pub const NOT_HERE: &str = "Tego tu nie schowam.";
    pub const UNPAID: &str = "Najpierw trzeba za to zapłacić.";
    pub const EMPTY: &str = "Pusto.";
    pub const PUT_BACK: &str = "Odkładam z powrotem.";
    pub const ONLY_DIRTY: &str = "Do zmywarki tylko brudne kubki.";
    pub const FREE_DRINK: &str = "Firmowe, za darmo. Dzięki, szefie!";
}

/// Where a slot's things are kept.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Source {
    Stored(usize),
    Water,
    Juice,
    Mugs,
    Knives,
    Dirty,
    Washed,
    Stock(u8),
}

struct Slot {
    kind: u8,
    count: u8,
    label: String,
    source: Source,
}

fn stock_list(which: u8) -> &'static [(u8, &'static str)] {
    match which {
        c::CABINET => &supplies::MEDICINES,
        c::STOREROOM => &supplies::STOREROOM,
        c::BAR => &supplies::BAR,
        _ => &[],
    }
}

impl Server {
    /// E at a container: its window.
    pub(super) fn open_container(&mut self, pid: u16, which: u8) {
        let noise = match which {
            c::FRIDGE => Some(sound::FRIDGE),
            c::CUPBOARD | c::CABINET | c::BAR => Some(sound::CUPBOARD),
            _ => None,
        };
        if let Some(n) = noise {
            self.sound(n, pid);
        }
        if let Some(p) = self.players.get_mut(&pid) {
            p.container = Some(which);
        }
        self.send_container(pid);
    }

    /// Still standing at it (and, for the bar, with its key).
    fn container_near(&self, pid: u16, which: u8) -> bool {
        let Some(p) = self.players.get(&pid).filter(|p| p.in_building()) else { return false };
        let body = &p.body;
        match which {
            c::FRIDGE | c::CUPBOARD | c::DISHWASHER => self.kitchen.as_ref().is_some_and(|k| {
                let t = match which {
                    c::FRIDGE => k.fridge,
                    c::CUPBOARD => k.cupboard,
                    _ => k.dishwasher,
                };
                k.near(t, body)
            }),
            c::CABINET => near(self.supplies.cabinet, body),
            c::BAR => near(self.supplies.liquor, body) && p.inventory.has(item_kind::BAR_KEY),
            c::STOREROOM => {
                self.supplies.storeroom == Some((body.floor, self.room_of(body.floor, body.pos)))
                    && self.supplies.shelves.iter().any(|&s| near(Some(s), body))
            }
            _ => false,
        }
    }

    fn container_slots(&self, which: u8) -> Vec<Slot> {
        let slot = |kind: u8, count: u8, label: &str, source: Source| Slot { kind, count, label: label.to_string(), source };
        if let Some(k) = self.kitchen.as_ref() {
            match which {
                c::FRIDGE => {
                    let mut out: Vec<Slot> =
                        k.stored.iter().enumerate().map(|(i, it)| slot(it.kind, 1, &it.label, Source::Stored(i))).collect();
                    out.push(slot(item_kind::WATER, k.water, "Woda (firmowa)", Source::Water));
                    out.push(slot(item_kind::JUICE, k.juice, "Sok (firmowy)", Source::Juice));
                    return out;
                }
                c::CUPBOARD => {
                    return vec![
                        slot(item_kind::CUP, k.mugs, "Czysty kubek", Source::Mugs),
                        slot(item_kind::KNIFE, k.knives, "Nóż kuchenny", Source::Knives),
                    ]
                }
                c::DISHWASHER => {
                    return vec![
                        slot(item_kind::EMPTY_CUP, k.dirty, "Brudne kubki", Source::Dirty),
                        slot(item_kind::CUP, k.washed, "Czyste kubki", Source::Washed),
                    ]
                }
                _ => {}
            }
        }
        stock_list(which).iter().map(|&(kind, name)| slot(kind, self.supplies.stock.left(kind), name, Source::Stock(kind))).collect()
    }

    fn container_packet(&self, which: u8) -> Packet {
        let slots = self.container_slots(which);
        let capacity = if which == c::FRIDGE { kitchen::FRIDGE_SLOTS + 2 } else { slots.len() };
        let k = self.kitchen.as_ref();
        let milk = if which == c::FRIDGE { k.map_or(0, |k| k.milk) } else { 0 };
        let now = self.clock.total_minutes();
        let minutes = match (which, k.and_then(|k| k.running_until)) {
            (c::DISHWASHER, Some(t)) => t.saturating_sub(now).clamp(1, 255) as u8,
            _ => 0,
        };
        Packet::Container {
            which,
            capacity: capacity.min(c::MAX_SLOTS) as u8,
            slots: slots.into_iter().map(|s| ContainerSlot { kind: s.kind, count: s.count, label: s.label }).collect(),
            milk,
            minutes,
        }
    }

    fn send_container(&mut self, pid: u16) {
        if let Some(which) = self.players.get(&pid).and_then(|p| p.container) {
            let pk = self.container_packet(which);
            self.send_to(pid, &pk);
        }
    }

    /// A move in the window.
    pub(super) fn handle_container_action(&mut self, pid: u16, which: u8, act: u8, arg: u8, kind: u8) {
        let Some(p) = self.players.get_mut(&pid) else { return };
        if act == c::CLOSE {
            p.container = None;
            return;
        }
        if p.container != Some(which) || !self.container_near(pid, which) {
            return;
        }
        let line = match act {
            c::TAKE => self.container_take(pid, which, usize::from(arg), kind),
            c::PUT => self.container_put(pid, which, usize::from(arg)),
            c::MILK if which == c::FRIDGE => self.fridge_milk(pid),
            c::START if which == c::DISHWASHER => self.start_dishwasher(pid),
            c::UNLOAD if which == c::DISHWASHER => self.unload_dishwasher(),
            _ => None,
        };
        if let Some(line) = line {
            self.says.push(Say::new(pid, line));
        }
        // Whoever has the same one open sees it at once.
        let viewers: Vec<u16> = self.players.values().filter(|o| o.container == Some(which)).map(|o| o.id).collect();
        for v in viewers {
            self.send_container(v);
        }
    }

    fn container_take(&mut self, pid: u16, which: u8, i: usize, kind: u8) -> Option<String> {
        let slots = self.container_slots(which);
        let s = slots.get(i).filter(|s| s.kind == kind)?;
        if s.count == 0 {
            let line = match s.source {
                Source::Mugs => lines::NO_MUGS,
                Source::Knives => lines::NO_KNIVES,
                Source::Stock(_) => supplies::lines::EMPTY,
                _ => say::EMPTY,
            };
            return Some(line.into());
        }
        if !self.players.get(&pid)?.inventory.fits(s.kind) {
            return Some(lines::HANDS_FULL.into());
        }
        let k = self.kitchen.as_mut();
        match s.source {
            Source::Stored(j) => {
                let item = k?.stored.remove(j);
                let name = inventory::display_name(item.kind).to_lowercase();
                self.give(pid, item);
                return Some(format!("Wyjmuję z lodówki: {name}."));
            }
            Source::Water | Source::Juice => {
                let k = k?;
                let left = if s.source == Source::Water { &mut k.water } else { &mut k.juice };
                *left -= 1;
                self.give_new(pid, s.kind);
                return Some(say::FREE_DRINK.into());
            }
            Source::Mugs => {
                let k = k?;
                k.mugs -= 1;
                let left = k.mugs;
                self.give_new(pid, item_kind::CUP);
                return Some(lines::took_mug(left));
            }
            Source::Knives => {
                k?.knives -= 1;
                self.give_new(pid, item_kind::KNIFE);
                return Some(lines::TOOK_KNIFE.into());
            }
            Source::Dirty => {
                let k = k?;
                if let Some(t) = k.running_until {
                    return Some(lines::dw_running(t.saturating_sub(self.clock.total_minutes()).max(1)));
                }
                k.dirty -= 1;
            }
            Source::Washed => k?.washed -= 1,
            Source::Stock(kind) => {
                if !self.supplies.stock.take(kind) {
                    return Some(supplies::lines::EMPTY.into());
                }
            }
        }
        self.give_new(pid, s.kind);
        None
    }

    fn container_put(&mut self, pid: u16, which: u8, slot: usize) -> Option<String> {
        let item = self.players.get(&pid)?.inventory.slot(slot)?;
        let (kind, unpaid, tainted) = (item.kind, item.unpaid, item.tainted);
        if unpaid {
            return Some(say::UNPAID.into());
        }
        match which {
            c::FRIDGE => self.fridge_put(pid, slot),
            c::CUPBOARD => {
                let line = match kind {
                    item_kind::CUP => {
                        self.kitchen.as_mut()?.return_mugs(1);
                        lines::PUT_MUG
                    }
                    item_kind::KNIFE => {
                        let k = self.kitchen.as_mut()?;
                        k.knives = (k.knives + 1).min(kitchen::KNIVES);
                        lines::PUT_KNIFE
                    }
                    item_kind::EMPTY_CUP => return Some(lines::DIRTY_NOT_HERE.into()),
                    _ => return Some(say::NOT_HERE.into()),
                };
                self.take_from(pid, slot);
                Some(line.into())
            }
            c::DISHWASHER if kind == item_kind::EMPTY_CUP => {
                let now = self.clock.total_minutes();
                let k = self.kitchen.as_mut()?;
                let line = if k.washed > 0 {
                    lines::DW_UNLOAD_FIRST.to_string()
                } else if let Some(t) = k.running_until {
                    lines::dw_running(t.saturating_sub(now).max(1))
                } else if k.dirty >= kitchen::DISHWASHER_CAP {
                    lines::DW_FULL.to_string()
                } else {
                    k.dirty += 1;
                    let line = lines::loaded(k.dirty);
                    self.take_from(pid, slot);
                    line
                };
                Some(line)
            }
            c::DISHWASHER => Some(say::ONLY_DIRTY.into()),
            _ if stock_list(which).iter().any(|&(k, _)| k == kind) && !tainted => {
                self.take_from(pid, slot);
                *self.supplies.stock.0.entry(kind).or_insert(0) += 1;
                Some(say::PUT_BACK.into())
            }
            _ => Some(say::NOT_HERE.into()),
        }
    }

    fn take_from(&mut self, pid: u16, slot: usize) -> Option<Item> {
        let p = self.players.get_mut(&pid)?;
        let item = p.inventory.take_slot(slot);
        refresh(p);
        item
    }

    fn fridge_put(&mut self, pid: u16, slot: usize) -> Option<String> {
        let p = self.players.get(&pid)?;
        let (kind, nick) = (p.inventory.slot(slot)?.kind, p.nick.clone());
        if !kitchen::fridge_worthy(kind) {
            return Some(lines::NOT_FOR_FRIDGE.into());
        }
        let k = self.kitchen.as_ref()?;
        if kind != item_kind::MILK && k.stored.len() >= kitchen::FRIDGE_SLOTS {
            return Some(lines::FRIDGE_FULL.into());
        }
        let mut item = self.take_from(pid, slot)?;
        let k = self.kitchen.as_mut()?;
        if kind == item_kind::MILK {
            k.milk = (k.milk + kitchen::MILK_PER_CARTON).min(kitchen::MILK_MAX);
            return Some(lines::carton(k.milk));
        }
        let name = inventory::display_name(kind).to_string();
        item.label = format!("{name} ({nick})");
        k.stored.push(item);
        Some(lines::stored(&name))
    }

    fn fridge_milk(&mut self, pid: u16) -> Option<String> {
        let k = self.kitchen.as_mut()?;
        let p = self.players.get_mut(&pid)?;
        if p.inventory.held_kind() != item_kind::COFFEE {
            return Some(lines::MILK_NEEDS_COFFEE.into());
        }
        if k.milk == 0 {
            return Some(lines::NO_MILK.into());
        }
        k.milk -= 1;
        if let Some(cup) = p.inventory.hands.as_mut() {
            cup.kind = item_kind::LATTE; // same mug, same coffee going cold
            cup.label = "Z mlekiem".into();
        }
        refresh(p);
        Some(lines::milk_added(k.milk))
    }

    fn start_dishwasher(&mut self, pid: u16) -> Option<String> {
        let now = self.clock.total_minutes();
        let k = self.kitchen.as_mut()?;
        let line = if let Some(t) = k.running_until {
            lines::dw_running(t.saturating_sub(now).max(1))
        } else if k.washed > 0 {
            lines::DW_UNLOAD_FIRST.to_string()
        } else if k.dirty == 0 {
            lines::DW_EMPTY.to_string()
        } else {
            k.running_until = Some(now + kitchen::WASH_MINUTES);
            if let Some(p) = self.players.get(&pid) {
                self.sounds.push((sound::DISHWASHER, p.body.floor, p.body.pos));
            }
            lines::DW_STARTED.to_string()
        };
        Some(line)
    }

    fn unload_dishwasher(&mut self) -> Option<String> {
        let k = self.kitchen.as_mut()?;
        if k.washed == 0 {
            return Some(say::EMPTY.into());
        }
        let n = k.washed;
        k.washed = 0;
        k.return_mugs(n);
        Some(lines::dw_unloaded(n))
    }

    /// Once a second: open windows refreshed; walked away = closed.
    pub(super) fn tick_containers(&mut self) {
        if !self.tick.is_multiple_of(REFRESH_TICKS) {
            return;
        }
        let open: Vec<(u16, u8)> = self.players.values().filter_map(|p| p.container.map(|w| (p.id, w))).collect();
        for (pid, which) in open {
            if self.container_near(pid, which) {
                self.send_container(pid);
            } else if let Some(p) = self.players.get_mut(&pid) {
                p.container = None;
            }
        }
    }
}
