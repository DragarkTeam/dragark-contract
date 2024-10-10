mod systems {
    mod actions;
}

mod components {
    mod dragon;
    mod island;
    mod journey;
    mod map;
    mod scout;
    mod player;
    mod shield;
    mod mission;
    mod achievement;
    mod base;
    mod emitter;
}

mod models {
    mod dragon;
    mod map_info;
    mod island;
    mod player;
    mod player_dragon_owned;
    mod player_island_owned;
    mod player_island_slot;
    mod scout_info;
    mod journey;
    mod position;
    mod shield;
    mod mission;
    mod achievement;
    mod base;
}

mod errors;
mod constants;
mod events;
mod utils;

#[cfg(test)]
mod tests {
    mod setup;
    mod store;
    mod test_dragon;
    mod test_island;
    mod test_journey;
    mod test_map;
    mod test_scout;
    mod test_shield;
    mod test_player;
    mod test_mission;
}
