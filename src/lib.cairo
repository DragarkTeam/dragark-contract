pub mod systems {
    pub mod actions;
}

pub mod models {
    pub mod dragon;
    pub mod map_info;
    pub mod island;
    pub mod player;
    pub mod player_dragon_owned;
    pub mod player_island_owned;
    pub mod player_island_slot;
    pub mod scout_info;
    pub mod journey;
    pub mod position;
    pub mod shield;
    pub mod mission;
}

pub mod errors;
pub mod events;
pub mod constants;
pub mod utils;

#[cfg(test)]
mod tests {
    mod setup;
    mod test_dragon;
    mod test_island;
    mod test_journey;
    mod test_map;
    mod test_scout;
    mod test_shield;
    mod test_player;
    mod test_mission;
}
