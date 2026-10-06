//! HR's lost and found: an employee who can't find their laptop (or card)
//! asks at HR, who checks where it is - with them, on a desk, on the floor
//! somewhere, with somebody else - and only if it's really gone issues a
//! new one.

use crate::inventory::kind as item_kind;
use crate::protocol::Packet;

use super::{Say, Server};

/// The "how can I help?" dialog (the cupboard's old id, free since the
/// containers got their own window).
pub(super) const DIALOG: u8 = 251;

pub(super) mod lines {
    pub const ASK: &str = "Umowa podpisana, wszystko gra. W czym mogę pomóc?";
    pub const LAPTOP: &str = "Zgubiłem/am laptopa";
    pub const CARD: &str = "Zgubiłem/am kartę";
    pub const NOTHING: &str = "Nic, dziękuję";
    pub const WITH_YOU: &str = "Przecież masz go przy sobie.";
    pub const CARD_WITH_YOU: &str = "Przecież masz ją przy sobie.";
    pub const HANDS_FULL: &str = "Proszę najpierw odłożyć to, co masz w rękach.";
    pub const NEW_LAPTOP: &str = "Nigdzie go nie ma… Spisujemy na straty. Proszę, nowy laptop — tym razem uważaj!";
    pub const NEW_CARD: &str = "Nigdzie jej nie ma… Stara zablokowana, proszę, nowa karta.";
    pub fn on_desk(room: &str, floor: u8) -> String {
        format!("Twój laptop stoi na biurku — {room}, piętro {floor}.")
    }
    pub fn on_floor(what: &str, room: &str, floor: u8) -> String {
        format!("Ktoś widział {what} na podłodze — {room}, piętro {floor}.")
    }
    pub fn with(what: &str, nick: &str) -> String {
        format!("Z tego, co wiem, {what} ma {nick}.")
    }
}

impl Server {
    /// E at HR as an employee: what can HR do for you.
    pub(super) fn hr_desk(&mut self, npc: u16, pid: u16) {
        let Some(p) = self.players.get_mut(&pid).filter(|p| p.contract) else { return };
        p.hr_desk = Some(npc);
        let options = vec![lines::LAPTOP.to_string(), lines::CARD.to_string(), lines::NOTHING.to_string()];
        let addr = p.addr;
        self.send(addr, &Packet::Dialog { id: DIALOG, npc, text: lines::ASK.into(), options, items: Vec::new() });
    }

    /// The answer; false if it isn't this dialog.
    pub(super) fn answer_hr_desk(&mut self, pid: u16, dialog: u8, choice: u8) -> bool {
        if dialog != DIALOG {
            return false;
        }
        let Some(p) = self.players.get_mut(&pid) else { return true };
        let Some(hr) = p.hr_desk.take() else { return true };
        let addr = p.addr;
        self.send(addr, &Packet::Dialog { id: 0, npc: hr, text: String::new(), options: Vec::new(), items: Vec::new() });
        let line = match choice {
            0 => self.find_lost(pid, item_kind::LAPTOP),
            1 => self.find_lost(pid, item_kind::EMPLOYEE_CARD),
            _ => return true,
        };
        self.says.push(Say::addressed(hr, line, pid));
        true
    }

    /// Where `kind` (theirs) is; really gone: a new one.
    fn find_lost(&mut self, pid: u16, kind: u8) -> String {
        let laptop = kind == item_kind::LAPTOP;
        let what = if laptop { "twój laptop" } else { "twoją kartę" };
        let place = |s: &Server, floor: u8, x: i32, y: i32| {
            s.building.floor(floor).map_or_else(|| "?".to_string(), |m| m.room_name(m.room_at_tile(x, y)).to_string())
        };
        let Some(p) = self.players.get(&pid) else { return String::new() };
        if p.inventory.items().any(|i| i.kind == kind && i.owner == pid) {
            return (if laptop { lines::WITH_YOU } else { lines::CARD_WITH_YOU }).into();
        }
        if laptop {
            if let Some(ws) = self.computers.iter().find(|c| c.owner() == pid).and_then(|c| self.workstations.get(c.station)) {
                return lines::on_desk(&ws.room_name, ws.floor);
            }
        }
        if let Some(d) = self.dropped.iter().find(|d| d.item.kind == kind && d.item.owner == pid) {
            let (x, y) = d.pos.tile();
            return lines::on_floor(what, &place(self, d.floor, x, y), d.floor);
        }
        if let Some(o) = self.players.values().find(|o| o.id != pid && o.inventory.items().any(|i| i.kind == kind && i.owner == pid)) {
            return lines::with(what, &o.nick);
        }
        // Really gone.
        if laptop && !p.inventory.hands_free() {
            return lines::HANDS_FULL.into();
        }
        let nick = p.nick.clone();
        self.give_new(pid, kind);
        self.log(format!("* HR issued {nick} a new {}", if laptop { "laptop" } else { "card" }));
        (if laptop { lines::NEW_LAPTOP } else { lines::NEW_CARD }).into()
    }
}
