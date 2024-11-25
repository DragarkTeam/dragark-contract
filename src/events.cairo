// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark::models::{
    island::Resource, journey::{AttackType, AttackResult, JourneyStatus}, position::Position,
    shield::ShieldType
};

// Scout events
#[derive(Drop, Serde, starknet::Event)]
pub struct Scouted {
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    pub scout_id: felt252,
    pub destination: Position,
    pub time: u64
}

// Journey events
#[derive(Drop, Serde, starknet::Event)]
pub struct JourneyStarted {
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    pub journey_id: felt252,
    pub dragon_token_id: u128,
    pub carrying_resources: Resource,
    pub island_from_id: usize,
    pub island_from_position: Position,
    pub island_from_owner: ContractAddress,
    pub island_to_id: usize,
    pub island_to_position: Position,
    pub island_to_owner: ContractAddress,
    pub start_time: u64,
    pub finish_time: u64,
    pub attack_type: AttackType,
    pub attack_result: AttackResult,
    pub status: JourneyStatus
}

#[derive(Drop, Serde, starknet::Event)]
struct JourneyFinished {
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    pub journey_id: felt252,
    pub dragon_token_id: u128,
    pub carrying_resources: Resource,
    pub island_from_id: usize,
    pub island_from_position: Position,
    pub island_from_owner: ContractAddress,
    pub island_to_id: usize,
    pub island_to_position: Position,
    pub island_to_owner: ContractAddress,
    pub start_time: u64,
    pub finish_time: u64,
    pub attack_type: AttackType,
    pub attack_result: AttackResult,
    pub status: JourneyStatus
}

// Shield events
#[derive(Drop, Serde, starknet::Event)]
pub struct ShieldActivated {
    #[key]
    pub map_id: usize,
    #[key]
    pub island_id: usize,
    pub shield_type: ShieldType,
    pub shield_protection_time: u64
}

#[derive(Drop, Serde, starknet::Event)]
pub struct ShieldDeactivated {
    #[key]
    pub map_id: usize,
    #[key]
    pub island_id: usize,
    pub shield_protection_time: u64
}

// Mission events
#[derive(Drop, Serde, starknet::Event)]
pub struct MissionMilestoneReached {
    #[key]
    pub mission_id: felt252,
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    pub current_value: u32
}

// Player events
#[derive(Drop, Serde, starknet::Event)]
struct PlayerStoneUpdate {
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    pub stone_rate: u128,
    pub current_stone: u128,
    pub stone_updated_time: u64,
    pub stone_cap: u128
}

#[derive(Drop, Serde, starknet::Event)]
struct PlayerDragarkStoneUpdate {
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    pub dragark_stone_balance: u128
}
