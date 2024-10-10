// Starknet imports
use starknet::ContractAddress;

#[derive(Drop, Serde)]
#[dojo::model]
struct Achievement {
    #[key]
    achievement_id: felt252,
    targets: Array<u32>,
    stone_rewards: Array<u128>,
    dragark_stone_rewards: Array<u64>,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct AchievementTracking {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    #[key]
    achievement_id: felt252,
    current_value: u32,
    claimed_times: u32
}
