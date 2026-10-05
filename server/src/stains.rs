//! "Człowiek smuga": now and then a toilet is left with a skid mark. Whoever
//! did it can scrub it with the toilet brush (a minigame on the client);
//! left there, the next person into the stall sees it - and the whole
//! office hears about it (never who it was). Gone overnight.

/// Chance (%) a toilet used gets one.
pub const CHANCE_PERCENT: u32 = 25;

pub mod lines {
    pub const MADE: &str = "Ups… na sedesie została smuga. Wypadałoby umyć szczotką (E przy sedesie).";
    pub const SEEN: &str = "Znowu człowiek smuga zaatakował!";
    pub const DIRTY: &str = "Fuj! Ktoś zostawił smugę… Najpierw szczotka.";
    pub const SCRUBBED: &str = "Czysto! Nikt się nie dowie.";
    pub const SCRUBBED_OTHERS: &str = "Umyte. Ktoś musiał…";
    pub fn rumour(floor: u8) -> String {
        format!("W biurze huczy: znowu człowiek smuga zaatakował! (łazienka, piętro {floor})")
    }
}
