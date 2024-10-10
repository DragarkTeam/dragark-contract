// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::{
    island::{Island, PositionIsland}, position::{NextIslandBlockDirection, Position},
    player_island_slot::PlayerIslandSlot
};

// Interface
#[starknet::interface]
trait IIslandActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the Island model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // * island_id The ID of the island
    // # Return
    // * Island The Island model
    fn get_island(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, island_id: usize
    ) -> Island;

    // Function to get the PositionIsland model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // * position The position to get info
    // # Return
    // * PositionIsland The PositionIsland model
    fn get_position_island(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, position: Position
    ) -> PositionIsland;

    // Function to get the PlayerIslandSlot model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // * block_id The block_id to get info
    // # Return
    // * PlayerIslandSlot The PlayerIslandSlot model
    fn get_player_island_slot(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, block_id: u32
    ) -> PlayerIslandSlot;

    // Function to get the NextIslandBlockDirection model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // # Return
    // * NextIslandBlockDirection The NextIslandBlockDirection model
    fn get_next_island_block_direction(
        self: @TContractState, world: IWorldDispatcher, map_id: usize
    ) -> NextIslandBlockDirection;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for claiming island resources
    // # Argument
    // * world The world address
    // * map_id The map_id to init action
    // * island_ids Array of island_ids to claim resources
    // # Return
    // * bool Whether the tx successful or not
    fn claim_resources(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, island_id: usize
    ) -> bool;

    // // Function for claiming all island owned's resources
    // // # Argument
    // // * world The world address
    // // * map_id The map_id to init action
    // // * island_ids Array of island_ids to update resources
    // // # Return
    // // * bool Whether the tx successful or not
    // fn claim_all_resources(
    //     ref self: TContractState, world: IWorldDispatcher, map_id: usize, island_ids: Array<usize>
    // );

    // Function for generating 9 islands PER block, only callable by admin
    // # Argument
    // * world The world address
    // * map_id The map_id to init action
    fn gen_island_per_block(ref self: TContractState, world: IWorldDispatcher, map_id: usize);
}

// Component
#[starknet::component]
mod IslandActionsComponent {
    // Core imports
    use poseidon::PoseidonTrait;

    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{MapInfo, IsMapInitialized},
            island::{Island, IslandTrait, PositionIsland, IslandType, Resource, ResourceClaimType},
            position::{NextIslandBlockDirection, Position}, player_island_slot::PlayerIslandSlot
        },
        errors::{Error, assert_with_err, panic_by_err},
        utils::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IIslandActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(IslandActionsImpl)]
    impl IslandActions<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IIslandActions<ComponentState<TContractState>> {
        // See IIslandActions-get_island
        fn get_island(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            island_id: usize
        ) -> Island {
            get!(world, (map_id, island_id), Island)
        }

        // See IIslandActions-get_position_island
        fn get_position_island(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            position: Position
        ) -> PositionIsland {
            get!(world, (map_id, position.x, position.y), PositionIsland)
        }

        // See IIslandActions-get_player_island_slot
        fn get_player_island_slot(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            block_id: u32
        ) -> PlayerIslandSlot {
            get!(world, (map_id, block_id), PlayerIslandSlot)
        }

        // See IIslandActions-get_next_island_block_direction
        fn get_next_island_block_direction(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, map_id: usize
        ) -> NextIslandBlockDirection {
            get!(world, (map_id), NextIslandBlockDirection)
        }

        // See IIslandActions-claim_resources
        fn claim_resources(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            island_id: usize
        ) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let mut map = get!(world, (map_id), MapInfo);
            let caller = get_caller_address();
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

            // Update resources
            let island_cur_resources = island.cur_resources;
            let island_max_resources = island.max_resources;

            let resources_per_claim = island.resources_per_claim;

            if (island_cur_resources.food + resources_per_claim.food >= island_max_resources.food) {
                island.cur_resources.food = island_max_resources.food;
            } else {
                island.cur_resources.food += resources_per_claim.food;
            }

            island.last_resources_claim = cur_block_timestamp;

            // Update map
            map.total_claim_resources += 1;

            // Save models
            set!(world, (map));
            set!(world, (island));

            true
        }

        // // See IIslandActions-claim_all_resources
        // fn claim_all_resources(
        //     ref self: ComponentState<TContractState>,
        //     world: IWorldDispatcher,
        //     map_id: usize,
        //     island_ids: Array<usize>
        // ) {
        //     let mut map = get!(world, (map_id), MapInfo);
        //     let caller = get_caller_address();
        //     let player = get!(world, (caller, map_id), Player);
        //     let player_global = get!(world, (caller), PlayerGlobal);
        //     let cur_block_timestamp: u64 = get_block_timestamp();

        //     // Check whether the map has been initialized or not
        //     assert_with_err(
        //         map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED, Option::None
        //     );

        //     // Check the map player is in
        //     assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

        //     // Check whether the player has joined the map
        //     assert_with_err(player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP, Option::None);

        //     let mut i: u32 = 0;
        //     loop {
        //         if (i == island_ids.len()) {
        //             break;
        //         }

        //         let island_id = *island_ids.at(i);
        //         let mut island = get!(world, (map_id, island_id), Island);

        //         // Check owner
        //         assert_with_err(caller == island.owner, Error::NOT_ISLAND_OWNER, Option::None);

        //         let last_resources_claim = island.last_resources_claim;
        //         let claim_waiting_time = island.claim_waiting_time;

        //         // Check if the time has passed the next claim time
        //         assert_with_err(
        //             cur_block_timestamp >= last_resources_claim + claim_waiting_time,
        //             Error::NOT_TIME_TO_CLAIM_YET, Option::None
        //         );

        //         // Update resources
        //         let island_cur_resources = island.cur_resources;
        //         let island_max_resources = island.max_resources;

        //         let resources_per_claim = island.resources_per_claim;

        //         if (island_cur_resources.food
        //             + resources_per_claim.food >= island_max_resources.food) {
        //             island.cur_resources.food = island_max_resources.food;
        //         } else {
        //             island.cur_resources.food += resources_per_claim.food;
        //         }

        //         island.last_resources_claim = cur_block_timestamp;

        //         // Update map data
        //         map.total_claim_resources += 1;

        //         // Save models
        //         set!(world, (map));
        //         set!(world, (island));

        //         i = i + 1;
        //     };
        // }

        // See IIslandActions-gen_island_per_block
        fn gen_island_per_block(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, map_id: usize
        ) {
            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let mut cur_island_block_coordinates = map.cur_island_block_coordinates;

            // Check caller
            _require_world_owner(world, caller);

            // Get next block direction
            let next_island_block_direction_model = get!(world, (map_id), NextIslandBlockDirection);
            let mut right_1 = next_island_block_direction_model.right_1;
            let mut down_2 = next_island_block_direction_model.down_2;
            let mut left_3 = next_island_block_direction_model.left_3;
            let mut up_4 = next_island_block_direction_model.up_4;
            let mut right_5 = next_island_block_direction_model.right_5;
            if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block to the right
                cur_island_block_coordinates.x += 3 * 4;
                right_1 -= 1;
            } else if (right_1 == 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block down
                cur_island_block_coordinates.y -= 3 * 4;
                down_2 -= 1;
            } else if (right_1 == 0 && down_2 == 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block to the left
                cur_island_block_coordinates.x -= 3 * 4;
                left_3 -= 1;
            } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block up
                cur_island_block_coordinates.y += 3 * 4;
                up_4 -= 1;
            } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 != 0) {
                // Move the current block to the right
                cur_island_block_coordinates.x += 3 * 4;
                right_5 -= 1;
            } else {
                panic_by_err(Error::INVALID_CASE_ISLAND_BLOCK_DIRECTION, Option::None);
            }

            // Gen island
            if (cur_island_block_coordinates.x == 276 && cur_island_block_coordinates.y == 264) {
                panic_by_err(Error::REACHED_MAX_ISLAND_GENERATED, Option::None);
            }
            IslandTrait::gen_island_per_block(
                world, map_id, cur_island_block_coordinates, IslandType::Normal
            );

            // Update the latest data
            let mut map = get!(world, (map_id), MapInfo);
            map.cur_island_block_coordinates = cur_island_block_coordinates;
            if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 == 0) {
                map.island_block_direction_count += 1;
                right_1 = 1;
                down_2 = 1 + (map.island_block_direction_count * 2);
                left_3 = 2 + (map.island_block_direction_count * 2);
                up_4 = 2 + (map.island_block_direction_count * 2);
                right_5 = 2 + (map.island_block_direction_count * 2);
            }

            // Save models
            set!(
                world, (NextIslandBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 })
            );
            set!(world, (map));
        }
    }
}
