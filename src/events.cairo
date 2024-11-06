// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark::models::{
    dragon::{DragonRarity, DragonElement, DragonState, DragonType}, island::Resource,
    journey::{AttackType, AttackResult, JourneyStatus}, player::StarShopItemType,
    shield::ShieldType, position::{Position}, treasure_hunt::{TreasureHuntType, TreasureHuntStatus}
};

// Events

// Dragon events
#[derive(Drop, Serde, starknet::Event)]
struct DragonUpgraded {
    #[key]
    dragon_token_id: u128,
    owner: ContractAddress,
    map_id: usize,
    new_level: u8,
    new_speed: u32,
    new_attack: u32,
    new_carrying_capacity: u32,
    old_speed: u32,
    old_attack: u32,
    old_carrying_capacity: u32,
    base_speed: u32,
    base_attack: u32,
    base_carrying_capacity: u32
}

#[derive(Drop, Serde, starknet::Event)]
struct FreeDragonClaimed {
    #[key]
    dragon_token_id: u128,
    owner: ContractAddress,
    map_id: usize,
    model_id: felt252,
    bg_id: felt252,
    rarity: DragonRarity,
    element: DragonElement,
    level: u8,
    base_speed: u32,
    base_attack: u32,
    base_carrying_capacity: u32,
    speed: u32,
    attack: u32,
    carrying_capacity: u32,
    state: DragonState,
    dragon_type: DragonType,
    recovery_time: u64
}

// Star shop
#[derive(Drop, Serde, starknet::Event)]
struct StarShopItemBought {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    item_type: StarShopItemType,
    item_bought_num: u8,
    star_bought: u32,
    star_left: u32
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

// TreasureHunt events
#[derive(Drop, Serde, starknet::Event)]
struct TreasureHuntStarted {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    treasure_hunt_id: felt252,
    treasure_hunt_type: TreasureHuntType,
    start_time: u64,
    finish_time: u64,
    earned_dragark_stone: u128,
    status: TreasureHuntStatus,
    dragon_token_ids: Array<u128>,
    dragon_recovery_times: Array<u64>
}

#[derive(Drop, Serde, starknet::Event)]
struct TreasureHuntFinished {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    treasure_hunt_id: felt252,
    treasure_hunt_type: TreasureHuntType,
    start_time: u64,
    finish_time: u64,
    earned_dragark_stone: u128,
    status: TreasureHuntStatus,
    dragon_token_ids: Array<u128>,
    dragon_recovery_times: Array<u64>
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
    dragark_stone_balance: u128
}

#[derive(Drop, Serde, starknet::Event)]
struct PlayerAccountExpChange {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    player_account_exp: u64,
    player_account_level: u8,
    total_account_exp: u64
}

#[derive(Drop, Serde, starknet::Event)]
struct PlayerContributionPointChange {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    player_contribution_points: u64,
    total_contribution_points: u64,
    dragark_stone_pool: u128
}

// Pool share
#[derive(Drop, Serde, starknet::Event)]
struct PoolShareRewardClaimed {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    dragark_stone_earn: u128,
    claim_time: u64
}

// Resources Pack
#[derive(Drop, Serde, starknet::Event)]
struct ResourcesPackBought {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    bought_time: u64
}
