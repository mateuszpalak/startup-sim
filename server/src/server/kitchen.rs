//! The kitchenette: the mug cupboard, the dishwasher and the fridge (E -
//! their windows are in `containers`), the dishwasher cycle.

use crate::inventory::{kind as item_kind, Item};
use crate::kitchen::{self, lines};
use crate::map::Tile;
use crate::protocol::container;
use crate::sim::{Body, Pos};

use super::player::refresh;
use super::{Say, Server};

/// What in the kitchenette is being used.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Thing {
    Cupboard,
    Dishwasher,
    Fridge,
    Bin,
}

fn dist2(t: Tile, body: &Body) -> i32 {
    let c = Pos::tile_center(t.x, t.y);
    (c.x - body.pos.x).pow(2) + (c.y - body.pos.y).pow(2)
}

impl Server {
    /// E in the kitchenette; `false` = nothing of it in reach (or the
    /// coffee machine / a sink is nearer - they have their own handling).
    pub(super) fn use_kitchen(&mut self, pid: u16, body: &Body) -> bool {
        let Some(k) = &self.kitchen else { return false };
        let mut best: Option<(i32, Thing)> = None;
        let things = [
            (Some(k.cupboard), Thing::Cupboard),
            (Some(k.dishwasher), Thing::Dishwasher),
            (Some(k.fridge), Thing::Fridge),
            (k.bin, Thing::Bin),
        ];
        for (t, thing) in things.into_iter().filter_map(|(t, th)| t.map(|t| (t, th))) {
            if k.near(t, body) {
                let d = dist2(t, body);
                if best.is_none_or(|(bd, _)| d < bd) {
                    best = Some((d, thing));
                }
            }
        }
        let Some((d, thing)) = best else { return false };
        // The machine or a spot (sink, fruit bowl, sanitizer) right in front
        // of you wins.
        let machine_nearer = self.machines.iter().any(|m| m.floor == body.floor && dist2(m.tile, body) < d);
        let spot_nearer = crate::needs::spot_in_reach(&self.spots, body).is_some_and(|s| dist2(s.tile, body) < d);
        if machine_nearer || spot_nearer {
            return false;
        }
        match thing {
            Thing::Cupboard => self.use_cupboard(pid),
            Thing::Dishwasher => self.use_dishwasher(pid),
            Thing::Fridge => self.open_container(pid, container::FRIDGE),
            Thing::Bin => self.open_container(pid, container::BIN),
        }
        true
    }

    /// E at the cupboard: a mug / knife in hands goes back; otherwise a
    /// look inside (the window).
    fn use_cupboard(&mut self, pid: u16) {
        let Some(p) = self.players.get_mut(&pid) else { return };
        let Some(k) = self.kitchen.as_mut() else { return };
        let line = match p.inventory.held_kind() {
            item_kind::CUP => {
                p.inventory.take_hands();
                k.return_mugs(1);
                refresh(p);
                lines::PUT_MUG.to_string()
            }
            item_kind::KNIFE => return self.put_knife_back(pid),
            item_kind::EMPTY_CUP => lines::DIRTY_NOT_HERE.to_string(),
            _ => return self.open_container(pid, container::CUPBOARD),
        };
        self.sound(crate::protocol::sound::CUPBOARD, pid);
        self.says.push(Say::new(pid, line));
    }

    /// E at the dishwasher: a dirty mug in hands goes in; otherwise its
    /// window (load, start, unload).
    fn use_dishwasher(&mut self, pid: u16) {
        let Some(p) = self.players.get_mut(&pid) else { return };
        if p.inventory.held_kind() != item_kind::EMPTY_CUP {
            return self.open_container(pid, container::DISHWASHER);
        }
        let now = self.clock.total_minutes();
        let Some(k) = self.kitchen.as_mut() else { return };
        let line = if k.washed > 0 {
            lines::DW_UNLOAD_FIRST.to_string()
        } else if let Some(t) = k.running_until {
            lines::dw_running(t.saturating_sub(now).max(1))
        } else if k.dirty >= kitchen::DISHWASHER_CAP {
            lines::DW_FULL.to_string()
        } else {
            p.inventory.take_hands();
            refresh(p);
            k.dirty += 1;
            lines::loaded(k.dirty)
        };
        self.says.push(Say::new(pid, line));
    }

    /// The dishwasher's cycle.
    pub(super) fn tick_kitchen(&mut self) {
        let now = self.clock.total_minutes();
        if let Some(k) = self.kitchen.as_mut() {
            if k.tick(now) {
                self.log("* dishwasher done");
            }
        }
    }

    /// Mugs somebody took away (left the game): back to the cupboard.
    pub(super) fn return_mugs_of(&mut self, items: &[Item]) {
        let n =
            items.iter().filter(|i| matches!(i.kind, item_kind::CUP | item_kind::EMPTY_CUP | item_kind::COFFEE | item_kind::LATTE)).count();
        if let Some(k) = self.kitchen.as_mut() {
            k.return_mugs(u8::try_from(n).unwrap_or(u8::MAX));
        }
    }
}
