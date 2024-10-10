// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark_test_v19::models::{
    island::Resource, journey::{AttackType, AttackResult, JourneyStatus}, shield::ShieldType,
    position::{Position}
};

// Events

// Dragon upgrade events
#[derive(Drop, Serde, starknet::Event)]
struct DragonUpgraded {
    #[key]
    dragon_token_id: u128,
    new_level: u8,
    new_speed: u16,
    new_attack: u16,
    new_carrying_capacity: u32,
    old_speed: u16,
    old_attack: u16,
    old_carrying_capacity: u32
}


// Points event
#[derive(Drop, Serde, starknet::Event)]
struct PointsChanged {
    #[key]
    map_id: usize,
    #[key]
    player_earned: ContractAddress,
    points_earned: u64,
    player_lost: ContractAddress,
    points_lost: u64
}

// Scout events
#[derive(Drop, Serde, starknet::Event)]
struct Scouted {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    scout_id: felt252,
    destination: Position,
    time: u64
}

// Journey events
#[derive(Drop, Serde, starknet::Event)]
struct JourneyStarted {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    journey_id: felt252,
    dragon_token_id: u128,
    carrying_resources: Resource,
    island_from_id: usize,
    island_from_position: Position,
    island_from_owner: ContractAddress,
    island_to_id: usize,
    island_to_position: Position,
    island_to_owner: ContractAddress,
    start_time: u64,
    finish_time: u64,
    attack_type: AttackType,
    attack_result: AttackResult,
    status: JourneyStatus
}

#[derive(Drop, Serde, starknet::Event)]
struct JourneyFinished {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    journey_id: felt252,
    dragon_token_id: u128,
    carrying_resources: Resource,
    island_from_id: usize,
    island_from_position: Position,
    island_from_owner: ContractAddress,
    island_to_id: usize,
    island_to_position: Position,
    island_to_owner: ContractAddress,
    start_time: u64,
    finish_time: u64,
    attack_type: AttackType,
    attack_result: AttackResult,
    status: JourneyStatus
}

// Shield events
#[derive(Drop, Serde, starknet::Event)]
struct ShieldActivated {
    #[key]
    map_id: usize,
    #[key]
    island_id: usize,
    shield_type: ShieldType,
    shield_protection_time: u64
}

#[derive(Drop, Serde, starknet::Event)]
struct ShieldDeactivated {
    #[key]
    map_id: usize,
    #[key]
    island_id: usize,
    shield_protection_time: u64
}

// Mission events
#[derive(Drop, Serde, starknet::Event)]
struct MissionMilestoneReached {
    #[key]
    mission_id: felt252,
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    current_value: u32
}

// Player events
#[derive(Drop, Serde, starknet::Event)]
struct PlayerStoneUpdate {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    stone_rate: u128,
    current_stone: u128,
    stone_updated_time: u64,
    stone_cap: u128
}

#[derive(Drop, Serde, starknet::Event)]
struct PlayerDragarkStoneUpdate {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    dragark_stone_balance: u64
}
