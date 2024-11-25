// Starknet imports
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
pub struct Player {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub map_id: usize,
    pub is_joined_map: IsPlayerJoined,
    pub area_opened: u32,
    pub num_islands_owned: u32,
    pub points: u64,
    pub is_claim_default_dragon: bool,
    // Energy
    pub energy: u32,
    pub energy_reset_time: u64,
    pub energy_bought_num: u8,
    // Stone
    pub stone_rate: u128, // 4 decimals
    pub current_stone: u128, // 4 decimals
    pub stone_updated_time: u64,
    pub stone_cap: u128, // 4 decimals
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
pub struct PlayerGlobal {
    #[key]
    pub player: ContractAddress,
    pub map_id: usize,
    pub num_dragons_owned: u32,
    pub dragark_balance: u64,
}


#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum IsPlayerJoined {
    #[default]
    NotJoined,
    Joined
}
