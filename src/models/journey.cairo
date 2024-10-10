// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark_test_v19::models::{island::Resource, position::Position};

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Journey {
    #[key]
    map_id: usize,
    #[key]
    journey_id: felt252,
    owner: ContractAddress,
    dragon_token_id: u128,
    dragon_model_id: felt252,
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

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum AttackType {
    #[default]
    None,
    Unknown,
    DerelictIslandAttack,
    PlayerIslandAttack
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum AttackResult {
    #[default]
    None,
    Unknown,
    Win,
    Lose
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum JourneyStatus {
    #[default]
    None,
    Started,
    Finished,
    Cancelled
}
