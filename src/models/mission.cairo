// Starknet imports
use starknet::ContractAddress;

#[derive(Drop, Serde)]
#[dojo::model]
pub struct Mission {
    #[key]
    pub mission_id: felt252,
    pub targets: Array<u32>,
    pub stone_rewards: Array<u128>,
    pub dragark_stone_rewards: Array<u64>
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MissionTracking {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub map_id: usize,
    #[key]
    pub mission_id: felt252,
    pub daily_timestamp: u64,
    pub current_value: u32,
    pub claimed_times: u32,
}
