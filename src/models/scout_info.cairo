// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark_test_v19::models::{
    island::{IslandElement, IslandTitle, IslandType, Resource, ResourceClaimType},
    position::{Position}
};

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct ScoutInfo {
    #[key]
    map_id: usize,
    #[key]
    scout_id: felt252,
    #[key]
    player: ContractAddress,
    destination: Position,
    time: u64,
    points_earned: u64,
    has_island: HasIsland,
    island_id: usize,
    owner: ContractAddress,
    position: Position,
    block_id: u32,
    element: IslandElement,
    title: IslandTitle,
    island_type: IslandType,
    level: u8,
    max_resources: Resource,
    cur_resources: Resource,
    resources_per_claim: Resource,
    claim_waiting_time: u64,
    resources_claim_type: ResourceClaimType,
    last_resources_claim: u64,
    shield_protection_time: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct PlayerScoutInfo {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    #[key]
    x: u32,
    #[key]
    y: u32,
    is_scouted: IsScouted
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum IsScouted {
    #[default]
    NotScouted,
    Scouted
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default)]
enum HasIsland {
    #[default]
    None,
    NoIsland,
    HasIsland
}
