// Internal imports
use dragark::models::position::Position;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MapInfo {
    #[key]
    pub map_id: usize,
    pub is_initialized: IsMapInitialized, 
    pub total_player: u32,
    pub total_island: u32,
    pub total_dragon: u32,
    pub total_scout: u32,
    pub total_journey: u32,
    pub total_activate_dragon: u32,
    pub total_deactivate_dragon: u32,
    pub total_join_map: u32,
    pub total_re_join_map: u32,
    pub total_start_journey: u32,
    pub total_finish_journey: u32,
    pub total_claim_resources: u32,
    pub total_claim_dragon: u32,
    pub total_activate_shield: u32,
    pub total_deactivate_shield: u32,
    pub map_sizes: u32,
    pub map_coordinates: Position,
    pub cur_block_coordinates: Position,
    pub block_direction_count: u32,
    pub derelict_islands_num: u32,
    pub cur_island_block_coordinates: Position,
    pub island_block_direction_count: u32,
    pub dragon_token_id_counter: u128,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
pub enum IsMapInitialized {
    NotInitialized,
    Initialized,
}
