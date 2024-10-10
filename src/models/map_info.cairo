// Internal imports
use dragark_test_v19::models::position::Position;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct MapInfo {
    #[key]
    map_id: usize,
    is_initialized: IsMapInitialized, 
    total_player: u32,
    total_island: u32,
    total_dragon: u32,
    total_scout: u32,
    total_journey: u32,
    total_activate_dragon: u32,
    total_deactivate_dragon: u32,
    total_join_map: u32,
    total_re_join_map: u32,
    total_start_journey: u32,
    total_finish_journey: u32,
    total_claim_resources: u32,
    total_claim_dragon: u32,
    total_activate_shield: u32,
    total_deactivate_shield: u32,
    map_sizes: u32,
    map_coordinates: Position,
    cur_block_coordinates: Position,
    block_direction_count: u32,
    derelict_islands_num: u32,
    cur_island_block_coordinates: Position,
    island_block_direction_count: u32,
    dragon_token_id_counter: u128,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum IsMapInitialized {
    NotInitialized,
    Initialized,
}
