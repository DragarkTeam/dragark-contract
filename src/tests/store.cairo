//! Store struct and component management methods

// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{
        dragon::{Dragon}, island::{Island, PositionIsland}, journey::{Journey}, map_info::{MapInfo},
        player_dragon_owned::{PlayerDragonOwned},
        player_island_owned::{PlayerIslandOwned}, player_island_slot::{PlayerIslandSlot},
        player::{Player, PlayerGlobal}, position::{NextBlockDirection, NextIslandBlockDirection},
        scout_info::{ScoutInfo, PlayerScoutInfo}, shield::{Shield, ShieldType},
        mission::{PlayerMissionTracking}
    }
};

// Store struct
#[derive(Copy, Drop)]
struct Store {
    world: IWorldDispatcher,
}

// Implementation of the `StoreTrait` trait for the `Store` struct
#[generate_trait]
impl StoreImpl of StoreTrait {
    #[inline(always)]
    fn new(world: IWorldDispatcher) -> Store {
        Store { world: world }
    }

    #[inline(always)]
    fn dragon(self: Store, dragon_token_id: u128) -> Dragon {
        get!(self.world, (dragon_token_id), Dragon)
    }

    #[inline(always)]
    fn island(self: Store, map_id: usize, island_id: usize) -> Island {
        get!(self.world, (map_id, island_id), Island)
    }

    #[inline(always)]
    fn position_island(self: Store, map_id: usize, x: u32, y: u32) -> PositionIsland {
        get!(self.world, (map_id, x, y), PositionIsland)
    }

    #[inline(always)]
    fn journey(self: Store, map_id: usize, journey_id: felt252) -> Journey {
        get!(self.world, (map_id, journey_id), Journey)
    }

    #[inline(always)]
    fn map_info(self: Store, map_id: usize) -> MapInfo {
        get!(self.world, (map_id), MapInfo)
    }

    #[inline(always)]
    fn player_dragon_owned(self: Store, player: ContractAddress, index: u32) -> PlayerDragonOwned {
        get!(self.world, (player, index), PlayerDragonOwned)
    }

    #[inline(always)]
    fn player_island_owned(
        self: Store, map_id: usize, player: ContractAddress, index: u32
    ) -> PlayerIslandOwned {
        get!(self.world, (map_id, player, index), PlayerIslandOwned)
    }

    #[inline(always)]
    fn player_island_slot(self: Store, map_id: usize, block_id: u32) -> PlayerIslandSlot {
        get!(self.world, (map_id, block_id), PlayerIslandSlot)
    }

    #[inline(always)]
    fn player(self: Store, player: ContractAddress, map_id: usize) -> Player {
        get!(self.world, (player, map_id), Player)
    }

    #[inline(always)]
    fn player_global(self: Store, player: ContractAddress) -> PlayerGlobal {
        get!(self.world, (player), PlayerGlobal)
    }

    #[inline(always)]
    fn next_block_direction(self: Store, map_id: usize) -> NextBlockDirection {
        get!(self.world, (map_id), NextBlockDirection)
    }

    #[inline(always)]
    fn next_island_block_direction(self: Store, map_id: usize) -> NextIslandBlockDirection {
        get!(self.world, (map_id), NextIslandBlockDirection)
    }

    #[inline(always)]
    fn scout_info(
        self: Store, map_id: usize, scout_id: felt252, player: ContractAddress
    ) -> ScoutInfo {
        get!(self.world, (map_id, scout_id, player), ScoutInfo)
    }

    #[inline(always)]
    fn player_scout_info(
        self: Store, map_id: usize, player: ContractAddress, x: u32, y: u32
    ) -> PlayerScoutInfo {
        get!(self.world, (map_id, player, x, y), PlayerScoutInfo)
    }

    #[inline(always)]
    fn shield(self: Store, player: ContractAddress, shield_type: ShieldType) -> Shield {
        get!(self.world, (player, shield_type), Shield)
    }

    #[inline(always)]
    fn player_mission_tracking(
        self: Store, player: ContractAddress, map_id: usize
    ) -> PlayerMissionTracking {
        get!(self.world, (player, map_id), PlayerMissionTracking)
    }

    #[inline(always)]
    fn set_dragon(self: Store, dragon: Dragon) {
        set!(self.world, (dragon))
    }

    #[inline(always)]
    fn set_island(self: Store, island: Island) {
        set!(self.world, (island))
    }

    #[inline(always)]
    fn set_position_island(self: Store, position_island: PositionIsland) {
        set!(self.world, (position_island))
    }

    #[inline(always)]
    fn set_journey(self: Store, journey: Journey) {
        set!(self.world, (journey))
    }

    #[inline(always)]
    fn set_map_info(self: Store, map_info: MapInfo) {
        set!(self.world, (map_info))
    }

    #[inline(always)]
    fn set_player_dragon_owned(self: Store, player_dragon_owned: PlayerDragonOwned) {
        set!(self.world, (player_dragon_owned))
    }

    #[inline(always)]
    fn set_player_island_owned(self: Store, player_island_owned: PlayerIslandOwned) {
        set!(self.world, (player_island_owned))
    }

    #[inline(always)]
    fn set_player_island_slot(self: Store, player_island_slot: PlayerIslandSlot) {
        set!(self.world, (player_island_slot))
    }

    #[inline(always)]
    fn set_player(self: Store, player: Player) {
        set!(self.world, (player))
    }

    #[inline(always)]
    fn set_player_global(self: Store, player_global: PlayerGlobal) {
        set!(self.world, (player_global))
    }

    #[inline(always)]
    fn set_next_block_direction(self: Store, next_block_direction: NextBlockDirection) {
        set!(self.world, (next_block_direction))
    }

    #[inline(always)]
    fn set_next_island_block_direction(
        self: Store, next_island_block_direction: NextIslandBlockDirection
    ) {
        set!(self.world, (next_island_block_direction))
    }

    #[inline(always)]
    fn set_scout_info(self: Store, scout_info: ScoutInfo) {
        set!(self.world, (scout_info))
    }

    #[inline(always)]
    fn set_player_scout_info(self: Store, player_scout_info: PlayerScoutInfo) {
        set!(self.world, (player_scout_info))
    }

    #[inline(always)]
    fn set_shield(self: Store, shield: Shield) {
        set!(self.world, (shield))
    }

    #[inline(always)]
    fn set_player_mission_tracking(self: Store, player_mission_tracking: PlayerMissionTracking) {
        set!(self.world, (player_mission_tracking))
    }
}
