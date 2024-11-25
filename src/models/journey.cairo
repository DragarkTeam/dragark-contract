// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark::models::{island::Resource, position::Position};

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Journey {
    #[key]
    pub map_id: usize,
    #[key]
    pub journey_id: felt252,
    pub owner: ContractAddress,
    pub dragon_token_id: u128,
    pub dragon_model_id: felt252,
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

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum AttackType {
    #[default]
    None,
    Unknown,
    DerelictIslandAttack,
    PlayerIslandAttack
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum AttackResult {
    #[default]
    None,
    Unknown,
    Win,
    Lose
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum JourneyStatus {
    #[default]
    None,
    Started,
    Finished,
    Cancelled
}
