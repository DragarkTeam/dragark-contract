// Interface
#[dojo::interface]
trait IIslandSystem<TContractState> {
    // Function for claiming island resources
    // # Argument
    // * map_id The map_id to init action
    // * island_id The island_ids to claim resources
    // # Return
    // * bool Whether the tx successful or not
    fn claim_resources(ref world: IWorldDispatcher, map_id: usize, island_id: usize) -> bool;

    // Function for generating 9 islands PER block, only callable by admin
    // # Argument
    // * map_id The map_id to init action
    fn gen_island_per_block(ref world: IWorldDispatcher, map_id: usize);
}

// Contract
#[dojo::contract]
mod island_systems {
    // Core imports
    use poseidon::PoseidonTrait;

    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            island::{
                Island, PositionIsland, PlayerIslandSlot, Resource, IslandType, ResourceClaimType,
                IslandTrait
            },
            map::{MapInfo, IsMapInitialized}, player::{Player, PlayerGlobal, IsPlayerJoined},
            position::{NextIslandBlockDirection, Position}
        },
        errors::{Error, assert_with_err, panic_by_err},
        utils::general::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IIslandSystem;

    // Impls
    #[abi(embed_v0)]
    impl IslandContractImpl of IIslandSystem<ContractState> {
        // See IIslandSystem-claim_resources
        fn claim_resources(ref world: IWorldDispatcher, map_id: usize, island_id: usize) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let player = get!(world, (caller, map_id), Player);
            let player_global = get!(world, (caller), PlayerGlobal);
            let mut island = get!(world, (map_id, island_id), Island);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Check owner
            assert_with_err(caller == island.owner, Error::NOT_ISLAND_OWNER, Option::None);

            let cur_block_timestamp: u64 = get_block_timestamp();
            let last_resources_claim = island.last_resources_claim;
            let claim_waiting_time = island.claim_waiting_time;

            // Check if the time has passed the next claim time
            assert_with_err(
                cur_block_timestamp >= last_resources_claim + claim_waiting_time,
                Error::NOT_TIME_TO_CLAIM_YET,
                Option::None
            );

            // Claim resources
            IslandTrait::claim_resources(ref island, ref map, world, cur_block_timestamp)
        }

        // See IIslandSystem-gen_island_per_block
        fn gen_island_per_block(ref world: IWorldDispatcher, map_id: usize) {
            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);

            // Check caller
            _require_world_owner(world, caller);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Gen island
            IslandTrait::gen_island_per_block(ref map, world, IslandType::Normal, false);
        }
    }
}
