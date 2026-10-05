//! The coffee machine's panel (E at it): brew into the mug in your hands,
//! top the water tank up, empty the grounds drawer (the grounds land in
//! your hands - into the kitchen bin with them).

use crate::coffee::{self, lines};
use crate::inventory::kind as item_kind;
use crate::protocol::{coffee_action as act, sound, Packet};

use super::player::refresh;
use super::{Say, Server};

/// Open panels are refreshed once a second (the coffee being made).
const REFRESH_TICKS: u32 = 20;

impl Server {
    pub(super) fn open_coffee_panel(&mut self, pid: u16, machine: usize) {
        if let Some(p) = self.players.get_mut(&pid) {
            p.coffee_panel = Some(machine);
        }
        self.send_coffee_panel(pid);
    }

    fn send_coffee_panel(&mut self, pid: u16) {
        let Some(i) = self.players.get(&pid).and_then(|p| p.coffee_panel) else { return };
        let Some(m) = self.machines.get(i) else { return };
        let busy = m.busy_until.saturating_sub(self.tick).div_ceil(20).min(255) as u8;
        let pk = Packet::CoffeeMachine { machine: i as u8, water: m.water, grounds: m.grounds, max: coffee::WATER_CUPS, busy };
        self.send_to(pid, &pk);
    }

    /// Still standing at machine `i`.
    fn at_machine(&self, pid: u16, i: usize) -> bool {
        self.players.get(&pid).filter(|p| p.in_building()).is_some_and(|p| coffee::machine_in_reach(&self.machines, &p.body) == Some(i))
    }

    pub(super) fn handle_coffee_action(&mut self, pid: u16, machine: u8, action: u8) {
        let i = usize::from(machine);
        let Some(p) = self.players.get_mut(&pid) else { return };
        if action == act::CLOSE {
            p.coffee_panel = None;
            return;
        }
        if p.coffee_panel != Some(i) || !self.at_machine(pid, i) {
            return;
        }
        let line = match action {
            act::BREW => Some(self.brew(pid, i)),
            act::WATER => Some(self.top_up_water(pid, i)),
            act::EMPTY_GROUNDS => Some(self.empty_grounds(pid, i)),
            _ => None,
        };
        if let Some(line) = line {
            self.says.push(Say::new(pid, line));
        }
        let viewers: Vec<u16> = self.players.values().filter(|o| o.coffee_panel == Some(i)).map(|o| o.id).collect();
        for v in viewers {
            self.send_coffee_panel(v);
        }
    }

    /// Coffee goes into a clean mug from the cupboard, held in your hands
    /// (without a kitchenette: straight into your hands).
    fn brew(&mut self, pid: u16, i: usize) -> &'static str {
        let tick = self.tick;
        let has_kitchen = self.kitchen.is_some();
        let Some(p) = self.players.get_mut(&pid) else { return lines::BUSY };
        let outcome = match p.inventory.held_kind() {
            item_kind::CUP => coffee::use_machine(&mut self.machines, i, &mut p.cup, true, tick),
            item_kind::EMPTY_CUP => return crate::kitchen::lines::DIRTY_MUG,
            _ if has_kitchen => return crate::kitchen::lines::NEED_MUG,
            _ => coffee::use_machine(&mut self.machines, i, &mut p.cup, p.inventory.hands_free(), tick),
        };
        match outcome {
            coffee::Outcome::Started => {
                if p.inventory.held_kind() == item_kind::CUP {
                    p.inventory.take_hands(); // the mug goes under the spout
                    refresh(p);
                }
                self.sound(sound::COFFEE, pid);
                lines::BREWING
            }
            coffee::Outcome::Busy => lines::BUSY,
            coffee::Outcome::HandsFull => lines::HANDS_FULL,
            coffee::Outcome::NoWater => lines::NO_WATER,
            coffee::Outcome::GroundsFull => lines::GROUNDS_FULL,
        }
    }

    fn top_up_water(&mut self, pid: u16, i: usize) -> &'static str {
        let m = &mut self.machines[i];
        if m.water >= coffee::WATER_CUPS {
            return lines::WATER_FULL;
        }
        m.water = coffee::WATER_CUPS;
        self.sound(sound::TAP, pid);
        lines::WATER_ADDED
    }

    fn empty_grounds(&mut self, pid: u16, i: usize) -> &'static str {
        if self.machines[i].grounds == 0 {
            return lines::NO_GROUNDS;
        }
        if !self.players.get(&pid).is_some_and(|p| p.inventory.hands_free()) {
            return lines::HANDS_FULL;
        }
        self.machines[i].grounds = 0;
        self.give_new(pid, item_kind::GROUNDS);
        lines::GROUNDS_OUT
    }

    /// Once a second: open panels refreshed; walked away = closed.
    pub(super) fn tick_coffee_panels(&mut self) {
        if !self.tick.is_multiple_of(REFRESH_TICKS) {
            return;
        }
        let open: Vec<(u16, usize)> = self.players.values().filter_map(|p| p.coffee_panel.map(|m| (p.id, m))).collect();
        for (pid, i) in open {
            if self.at_machine(pid, i) {
                self.send_coffee_panel(pid);
            } else if let Some(p) = self.players.get_mut(&pid) {
                p.coffee_panel = None;
            }
        }
    }
}
