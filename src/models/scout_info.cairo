// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark::models::{
    island::{IslandElement, IslandTitle, IslandType, Resource, ResourceClaimType},
    position::{Position}
};

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct ScoutInfo {
    #[key]
    pub map_id: usize,
    #[key]
    pub scout_id: felt252,
    #[key]
    pub player: ContractAddress,
    pub destination: Position,
    pub time: u64,
    pub points_earned: u64,
    pub has_island: HasIsland,
    pub island_id: usize,
    pub owner: ContractAddress,
    pub position: Position,
    pub block_id: u32,
    pub element: IslandElement,
    pub title: IslandTitle,
    pub island_type: IslandType,
    pub level: u8,
    pub max_resources: Resource,
    pub cur_resources: Resource,
    pub resources_per_claim: Resource,
    pub claim_waiting_time: u64,
    pub resources_claim_type: ResourceClaimType,
    pub last_resources_claim: u64,
    pub shield_protection_time: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerScoutInfo {
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    #[key]
    pub x: u32,
    #[key]
    pub y: u32,
    pub is_scouted: IsScouted
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum IsScouted {
    #[default]
    NotScouted,
    Scouted
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default)]
pub enum HasIsland {
    #[default]
    None,
    NoIsland,
    HasIsland
}
