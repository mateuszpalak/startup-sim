//! Skid marks on toilets (`crate::stains`): left after a sit, seen by the
//! next one in the stall (and the office hears of it), scrubbed with the
//! brush (the minigame's result), gone overnight with the puddles.

use crate::map::Tile;
use crate::needs::{self, SpotKind};
use crate::protocol::{notice, puddle, sound};
use crate::sim::{Body, Pos, TILE_UNITS};
use crate::stains::lines;

use super::{dist2, Say, Server};

/// Somebody in the stall within this reach sees it (3 tiles).
const SEE_REACH: i32 = TILE_UNITS * 3;
/// Checked twice a second.
const SEE_TICKS: u32 = 10;

pub(super) struct Stain {
    /// The puddle that shows it.
    handle: u16,
    floor: u8,
    tile: Tile,
    /// The stall it's in.
    room: u16,
    /// Who left it (never told to anybody).
    by: u16,
    /// Somebody else saw it (and the office heard).
    seen: bool,
}

impl Server {
    /// Got up from the toilet at `at`: maybe a skid mark on it.
    pub(super) fn maybe_stain(&mut self, pid: u16, floor: u8, at: Pos) {
        let Some(tile) = needs::spot_in_reach(&self.spots, &Body::at(floor, at)).filter(|s| s.kind == SpotKind::Toilet).map(|s| s.tile)
        else {
            return;
        };
        if self.stains.iter().any(|s| s.floor == floor && s.tile == tile) || self.rng.u32(0..100) >= self.cfg.stain_percent {
            return;
        }
        self.leave_puddle(floor, Pos::tile_center(tile.x, tile.y), puddle::STAIN);
        let Some(handle) = self.puddles.last().map(|p| p.handle) else { return };
        let room = self.room_of(floor, at);
        self.stains.push(Stain { handle, floor, tile, room, by: pid, seen: false });
        self.says.push(Say::whisper(pid, lines::MADE, pid));
    }

    /// A skid mark on the toilet next to `body`.
    pub(super) fn stain_near(&self, body: &Body) -> Option<usize> {
        let reach = needs::USE_RADIUS;
        self.stains.iter().position(|s| s.floor == body.floor && dist2(Pos::tile_center(s.tile.x, s.tile.y), body.pos) <= reach * reach)
    }

    /// E at a dirty toilet: not sitting on that (and the office hears).
    pub(super) fn dirty_toilet(&mut self, pid: u16, i: usize) -> String {
        if self.stains[i].by != pid {
            self.stain_seen(i, pid);
        }
        lines::DIRTY.into()
    }

    /// The brush minigame done: the skid mark next to them is gone.
    pub(super) fn scrub(&mut self, pid: u16) {
        let Some(body) = self.players.get(&pid).map(|p| p.body) else { return };
        let Some(i) = self.stain_near(&body) else { return };
        let s = self.stains.remove(i);
        self.puddles.retain(|p| p.handle != s.handle);
        self.sounds.push((sound::FLUSH, body.floor, body.pos));
        let line = if s.by == pid { lines::SCRUBBED } else { lines::SCRUBBED_OTHERS };
        self.says.push(Say::new(pid, line));
        self.log("* a skid mark scrubbed");
    }

    fn stain_seen(&mut self, i: usize, witness: u16) {
        if self.stains[i].seen {
            return;
        }
        self.stains[i].seen = true;
        let floor = self.stains[i].floor;
        self.says.push(Say::new(witness, lines::SEEN));
        self.notify_building(witness, notice::FUN, &lines::rumour(floor));
        self.log("* człowiek smuga strikes again");
    }

    /// Twice a second: somebody else came into a stall with one.
    pub(super) fn tick_stains(&mut self) {
        if !self.tick.is_multiple_of(SEE_TICKS) {
            return;
        }
        for i in 0..self.stains.len() {
            let s = &self.stains[i];
            if s.seen {
                continue;
            }
            let at = Pos::tile_center(s.tile.x, s.tile.y);
            let witness = self
                .players
                .values()
                .find(|p| {
                    p.id != s.by
                        && p.in_building()
                        && p.body.floor == s.floor
                        && p.room == s.room
                        && dist2(p.body.pos, at) <= SEE_REACH * SEE_REACH
                })
                .map(|p| p.id);
            if let Some(w) = witness {
                self.stain_seen(i, w);
            }
        }
    }
}
