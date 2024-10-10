// Starknet imports
use starknet::ContractAddress;

#[derive(Drop, Serde)]
#[dojo::model]
struct Mission {
    #[key]
    mission_id: felt252,
    targets: Array<u32>,
    stone_rewards: Array<u128>,
    dragark_stone_rewards: Array<u64>,
    account_exp_rewards: Array<u64>
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct MissionTracking {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    #[key]
    mission_id: felt252,
    daily_timestamp: u64,
    current_value: u32,
    claimed_times: u32,
}
