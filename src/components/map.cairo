// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::{map_info::MapInfo, position::NextBlockDirection};

// Interface
#[starknet::interface]
trait IMapActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the MapInfo model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // # Return
    // * MapInfo The MapInfo model
    fn get_map_info(self: @TContractState, world: IWorldDispatcher, map_id: usize) -> MapInfo;

    // Function to get the NextBlockDirection model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // # Return
    // * NextBlockDirection The NextBlockDirection model
    fn get_next_block_direction(
        self: @TContractState, world: IWorldDispatcher, map_id: usize
    ) -> NextBlockDirection;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for player joining the map
    // Only callable for players who haven't joined the map
    // # Argument
    // * world The world address
    // * map_id The map_id to join
    // # Return
    // * bool Whether the tx successful or not
    fn join_map(ref self: TContractState, world: IWorldDispatcher, map_id: usize) -> bool;

    // Function for player re-joining the map when all their islands are captured
    // Only callable for players who have joined the map and have no islands remaining
    // # Argument
    // * world The world address
    // * map_id The map_id to join
    // # Return
    // * bool Whether the tx successful or not
    fn re_join_map(ref self: TContractState, world: IWorldDispatcher, map_id: usize) -> bool;

    // Function for initializing a new map, only callable by admin
    // This function MUST BE CALLED FIRST in order to get the game/map operating
    // # Argument
    // * world The world address
    // # Return
    // * usize The initialized map_id
    fn init_new_map(ref self: TContractState, world: IWorldDispatcher) -> usize;
}

// Component
#[starknet::component]
mod MapActionsComponent {
    // Core imports
    use core::integer::BoundedU32;
    use poseidon::PoseidonTrait;

    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        constants::{
            START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, SCOUT_MISSION_ID, START_JOURNEY_MISSION_ID,
            DAILY_LOGIN_MISSION_ID, OWN_ISLAND_ACHIEVEMENT_ID
        },
        components::{
            scout::{IScoutActions, ScoutActionsComponent},
            mission::{IMissionActions, MissionActionsComponent},
            achievement::{IAchievementActions, AchievementActionsComponent},
            player::{IPlayerActions, PlayerActionsComponent},
            dragon::{DragonActionsComponent, DragonActionsComponent::DragonActionsInternalTrait},
            emitter::{EmitterTrait, EmitterComponent},
        },
        events::{PlayerDragarkStoneUpdate, PointsChanged},
        models::{
            player::{Player, PlayerGlobal, PlayerInviteCode, IsPlayerJoined},
            map_info::{MapInfo, IsMapInitialized}, dragon::{Dragon},
            island::{Island, IslandTrait, IslandType}, player_island_owned::PlayerIslandOwned,
            player_dragon_owned::PlayerDragonOwned,
            scout_info::{ScoutInfo, PlayerScoutInfo, IsScouted},
            player_island_slot::PlayerIslandSlot,
            position::{NextBlockDirection, NextIslandBlockDirection, Position}, mission::Mission,
            achievement::AchievementTracking
        },
        errors::{Error, assert_with_err, panic_by_err},
        utils::{_is_playable, _require_valid_time, _require_world_owner, _generate_code}
    };

    // Local imports
    use super::IMapActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(MapActionsImpl)]
    impl MapActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl ScoutActions: ScoutActionsComponent::HasComponent<TContractState>,
        impl MissionActions: MissionActionsComponent::HasComponent<TContractState>,
        impl AchievementActions: AchievementActionsComponent::HasComponent<TContractState>,
        impl PlayerActions: PlayerActionsComponent::HasComponent<TContractState>,
        impl DragonActions: DragonActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IMapActions<ComponentState<TContractState>> {
        // See IMapActions-get_map_info
        fn get_map_info(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, map_id: usize
        ) -> MapInfo {
            get!(world, (map_id), MapInfo)
        }

        // See IMapActions-get_next_block_direction
        fn get_next_block_direction(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, map_id: usize
        ) -> NextBlockDirection {
            get!(world, (map_id), NextBlockDirection)
        }

        // See IMapActions-join_map
        fn join_map(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, map_id: usize
        ) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut scout_actions_comp = get_dep_component_mut!(ref self, ScoutActions);
            let player = get!(world, (caller, map_id), Player);
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let mut map = get!(world, (map_id), MapInfo);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check the map player is in
            if (player_global.map_id == 0) {
                assert_with_err(
                    player.is_joined_map == IsPlayerJoined::NotJoined,
                    Error::INVALID_CASE_JOIN_MAP,
                    Option::None
                );

                // Set player invite code
                let mut salt: felt252 = 0;
                let mut code: felt252 = 0;
                let mut is_duplicated: bool = true;
                while (is_duplicated) {
                    code = _generate_code(salt);
                    let mut player_invite_code = get!(world, (code), PlayerInviteCode);
                    if (player_invite_code.player.is_zero()) {
                        is_duplicated = false;
                        player_invite_code.player = caller;
                        set!(world, (player_invite_code));
                    }
                    salt += 1;
                };
                player_global.invite_code = code;
            } else {
                let player_previous_map_id = player_global.map_id;
                let player_previous = get!(world, (caller, player_previous_map_id), Player);
                assert_with_err(
                    player_previous_map_id != map_id, Error::ALREADY_JOINED_IN, Option::None
                );
                assert_with_err(
                    player_previous.is_joined_map == IsPlayerJoined::Joined,
                    Error::INVALID_CASE_JOIN_MAP,
                    Option::None
                );
            }

            // Move/Set all the player's dragons to this map
            let mut i: u32 = 0;
            loop {
                if (i == player_global.num_dragons_owned) {
                    break;
                }

                let player_dragon_owned_token_id = get!(world, (caller, i), PlayerDragonOwned)
                    .dragon_token_id;
                let mut dragon = get!(world, (player_dragon_owned_token_id), Dragon);
                dragon.map_id = map_id;
                set!(world, (dragon));

                i = i + 1;
            };

            // Update player global
            player_global.map_id = map_id;
            set!(world, (player_global));

            if (player.is_joined_map == IsPlayerJoined::NotJoined) {
                // Check the map is full player or not
                assert_with_err(map.total_player < 100, Error::MAP_FULL_PLAYER, Option::None);

                // // Check num dragons owned
                // assert_with_err(player.num_dragons_owned >= 1, Error::NOT_OWN_ANY_DRAGON, Option::None);

                // Get 1 island from PlayerIslandSlot for player
                let mut block_id = ((map.cur_block_coordinates.x / 12) + 1)
                    + (map.cur_block_coordinates.y / 12) * 23;
                let mut is_empty = get!(world, (map_id, block_id), PlayerIslandSlot)
                    .island_ids
                    .is_empty();
                if (is_empty) {
                    if (map.cur_block_coordinates.x == 264 && map.cur_block_coordinates.y == 264) {
                        panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
                    }
                    while (is_empty) {
                        let next_block_direction_model = get!(world, (map_id), NextBlockDirection);
                        let mut right_1 = next_block_direction_model.right_1;
                        let mut down_2 = next_block_direction_model.down_2;
                        let mut left_3 = next_block_direction_model.left_3;
                        let mut up_4 = next_block_direction_model.up_4;
                        let mut right_5 = next_block_direction_model.right_5;
                        if (right_1 != 0
                            && down_2 != 0
                            && left_3 != 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block to the right
                            map.cur_block_coordinates.x += 3 * 4;
                            right_1 -= 1;
                        } else if (right_1 == 0
                            && down_2 != 0
                            && left_3 != 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block down
                            map.cur_block_coordinates.y -= 3 * 4;
                            down_2 -= 1;
                        } else if (right_1 == 0
                            && down_2 == 0
                            && left_3 != 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block to the left
                            map.cur_block_coordinates.x -= 3 * 4;
                            left_3 -= 1;
                        } else if (right_1 == 0
                            && down_2 == 0
                            && left_3 == 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block up
                            map.cur_block_coordinates.y += 3 * 4;
                            up_4 -= 1;
                        } else if (right_1 == 0
                            && down_2 == 0
                            && left_3 == 0
                            && up_4 == 0
                            && right_5 != 0) {
                            // Move the current block to the right
                            map.cur_block_coordinates.x += 3 * 4;
                            right_5 -= 1;
                        } else {
                            panic_by_err(Error::INVALID_CASE_BLOCK_DIRECTION, Option::None);
                        }

                        block_id = ((map.cur_block_coordinates.x / 12) + 1)
                            + (map.cur_block_coordinates.y / 12) * 23;
                        is_empty = get!(world, (map_id, block_id), PlayerIslandSlot)
                            .island_ids
                            .is_empty();

                        // Break if there's no more available
                        if (block_id == 529 && is_empty) {
                            panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
                        }

                        if (right_1 == 0
                            && down_2 == 0
                            && left_3 == 0
                            && up_4 == 0
                            && right_5 == 0) {
                            map.block_direction_count += 1;
                            right_1 = 1;
                            down_2 = 1 + (map.block_direction_count * 2);
                            left_3 = 2 + (map.block_direction_count * 2);
                            up_4 = 2 + (map.block_direction_count * 2);
                            right_5 = 2 + (map.block_direction_count * 2);
                        }

                        // Save models
                        set!(
                            world,
                            (NextBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5, })
                        );
                        set!(world, (map));
                    }
                }
                let mut player_island_slot = get!(world, (map_id, block_id), PlayerIslandSlot);
                let island_id = player_island_slot.island_ids.pop_front().unwrap();
                set!(world, (player_island_slot));

                // Get player's island & initialize the island for player
                let mut player_island = get!(world, (map_id, island_id), Island);
                player_island.owner = caller;
                player_island.cur_resources.food = player_island.max_resources.food;

                let mut points = 0;
                let player_island_level = player_island.level;
                if (player_island_level == 1) {
                    points = 10;
                } else if (player_island_level == 2) {
                    points = 20;
                } else if (player_island_level == 3) {
                    points = 32;
                } else if (player_island_level == 4) {
                    points = 46;
                } else if (player_island_level == 5) {
                    points = 62;
                } else if (player_island_level == 6) {
                    points = 80;
                } else if (player_island_level == 7) {
                    points = 100;
                } else if (player_island_level == 8) {
                    points = 122;
                } else if (player_island_level == 9) {
                    points = 150;
                } else if (player_island_level == 10) {
                    points = 200;
                }

                // Save PlayerIslandOwned model
                set!(
                    world,
                    (PlayerIslandOwned {
                        map_id, player: caller, index: 0, island_id: player_island.island_id
                    })
                );

                // Save Island model
                set!(world, (player_island));

                // Save Player model
                let daily_timestamp = cur_timestamp
                    - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
                set!(
                    world,
                    (Player {
                        player: caller,
                        map_id,
                        is_joined_map: IsPlayerJoined::Joined,
                        area_opened: 0,
                        num_islands_owned: 1,
                        points,
                        is_claim_default_dragon: false,
                        // Energy
                        energy: 25,
                        energy_reset_time: daily_timestamp,
                        energy_bought_num: 0,
                        // Stone
                        stone_rate: 0,
                        current_stone: 0,
                        stone_updated_time: 0,
                        stone_cap: 50_000_000,
                        // Dragark Stone
                        dragark_stone_balance: 10,
                        // Account Level
                        account_level: 1,
                        account_exp: 0,
                        account_lvl_upgrade_claims: 0,
                        // Invitation Level
                        invitation_level: 1,
                        invitation_exp: 0,
                        invitation_lvl_upgrade_claims: 0
                    })
                );

                // Save AchievementTracking model
                set!(
                    world,
                    (AchievementTracking {
                        player: caller,
                        map_id,
                        achievement_id: OWN_ISLAND_ACHIEVEMENT_ID,
                        current_value: 1,
                        claimed_times: 0
                    })
                );

                // Update the latest map's data
                let mut map = get!(world, (map_id), MapInfo);
                map.total_player += 1;
                map.derelict_islands_num -= 1;
                map.total_join_map += 1;
                set!(world, (map));

                // Emit events
                emitter_comp
                    .emit_points_changed(
                        world,
                        PointsChanged {
                            map_id,
                            player_earned: caller,
                            points_earned: points,
                            player_lost: Zeroable::zero(),
                            points_lost: Zeroable::zero()
                        }
                    );
                emitter_comp
                    .emit_player_dragark_stone_update(
                        world,
                        PlayerDragarkStoneUpdate {
                            map_id, player: caller, dragark_stone_balance: 10
                        }
                    );

                // Get the latest map's data
                let map = get!(world, (map_id), MapInfo);
                let island = get!(world, (map_id, island_id), Island);

                // Scout the newly initialized island sub-sub block and 8 surrounding one (if
                // possible)
                let map_coordinates = map.map_coordinates;
                let map_sizes = map.map_sizes;

                let island_position_x = island.position.x;
                let island_position_y = island.position.y;

                assert_with_err(
                    island_position_x >= map_coordinates.x && island_position_x < map_coordinates.x
                        + map_sizes
                            && island_position_y >= map_coordinates.y
                            && island_position_y < map_coordinates.y
                        + map_sizes,
                    Error::INVALID_POSITION,
                    Option::None
                );

                // Find center position
                let mut center_position = Position { x: 0, y: 0 };

                if (island_position_x % 3 == 0) {
                    center_position.x = island_position_x + 1;
                } else if (island_position_x % 3 == 1) {
                    center_position.x = island_position_x;
                } else if (island_position_x % 3 == 2) {
                    center_position.x = island_position_x - 1;
                }

                if (island_position_y % 3 == 0) {
                    center_position.y = island_position_y + 1;
                } else if (island_position_y % 3 == 1) {
                    center_position.y = island_position_y;
                } else if (island_position_y % 3 == 2) {
                    center_position.y = island_position_y - 1;
                }

                // Scout the center positions
                scout_actions_comp
                    .scout(world, map_id, Position { x: center_position.x, y: center_position.y });
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x + 3, y: center_position.y }
                    );
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x, y: center_position.y - 3 }
                    );
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x - 3, y: center_position.y }
                    );
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x, y: center_position.y + 3 }
                    );
            }

            true
        }

        // See IMapActions-re_join_map
        fn re_join_map(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, map_id: usize
        ) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut scout_actions_comp = get_dep_component_mut!(ref self, ScoutActions);
            let mut player = get!(world, (caller, map_id), Player);
            let player_global = get!(world, (caller), PlayerGlobal);
            let mut map = get!(world, (map_id), MapInfo);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let cur_timestamp = get_block_timestamp();
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);

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

            // Check if the player has no islands remaining
            assert_with_err(
                player.num_islands_owned == 0, Error::PLAYER_NOT_AVAILABLE_FOR_REJOIN, Option::None
            );

            // Check num dragons owned
            assert_with_err(
                player_global.num_dragons_owned >= 1, Error::NOT_OWN_ANY_DRAGON, Option::None
            );

            // Get 1 island from PlayerIslandSlot for player
            let mut block_id = ((map.cur_block_coordinates.x / 12) + 1)
                + (map.cur_block_coordinates.y / 12) * 23;
            let mut is_empty = get!(world, (map_id, block_id), PlayerIslandSlot)
                .island_ids
                .is_empty();
            if (is_empty) {
                if (map.cur_block_coordinates.x == 264 && map.cur_block_coordinates.y == 264) {
                    panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
                }
                while (is_empty) {
                    let next_block_direction_model = get!(world, (map_id), NextBlockDirection);
                    let mut right_1 = next_block_direction_model.right_1;
                    let mut down_2 = next_block_direction_model.down_2;
                    let mut left_3 = next_block_direction_model.left_3;
                    let mut up_4 = next_block_direction_model.up_4;
                    let mut right_5 = next_block_direction_model.right_5;
                    if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                        // Move the current block to the right
                        map.cur_block_coordinates.x += 3 * 4;
                        right_1 -= 1;
                    } else if (right_1 == 0
                        && down_2 != 0
                        && left_3 != 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block down
                        map.cur_block_coordinates.y -= 3 * 4;
                        down_2 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 != 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block to the left
                        map.cur_block_coordinates.x -= 3 * 4;
                        left_3 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 == 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block up
                        map.cur_block_coordinates.y += 3 * 4;
                        up_4 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 == 0
                        && up_4 == 0
                        && right_5 != 0) {
                        // Move the current block to the right
                        map.cur_block_coordinates.x += 3 * 4;
                        right_5 -= 1;
                    } else {
                        panic_by_err(Error::INVALID_CASE_BLOCK_DIRECTION, Option::None);
                    }

                    block_id = ((map.cur_block_coordinates.x / 12) + 1)
                        + (map.cur_block_coordinates.y / 12) * 23;
                    is_empty = get!(world, (map_id, block_id), PlayerIslandSlot)
                        .island_ids
                        .is_empty();

                    // Break if there's no more available
                    if (block_id == 529 && is_empty) {
                        panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
                    }

                    if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 == 0) {
                        map.block_direction_count += 1;
                        right_1 = 1;
                        down_2 = 1 + (map.block_direction_count * 2);
                        left_3 = 2 + (map.block_direction_count * 2);
                        up_4 = 2 + (map.block_direction_count * 2);
                        right_5 = 2 + (map.block_direction_count * 2);
                    }

                    // Save models
                    set!(
                        world,
                        (NextBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5, })
                    );
                    set!(world, (map));
                }
            }
            let mut player_island_slot = get!(world, (map_id, block_id), PlayerIslandSlot);
            let island_id = player_island_slot.island_ids.pop_front().unwrap();
            set!(world, (player_island_slot));

            // Get player's island & initialize the island for player
            let mut player_island = get!(world, (map_id, island_id), Island);
            player_island.owner = caller;
            player_island.cur_resources.food = player_island.max_resources.food;

            // Calculate points
            let mut points = 0;
            let player_island_level = player_island.level;
            if (player_island_level == 1) {
                points = 10;
            } else if (player_island_level == 2) {
                points = 20;
            } else if (player_island_level == 3) {
                points = 32;
            } else if (player_island_level == 4) {
                points = 46;
            } else if (player_island_level == 5) {
                points = 62;
            } else if (player_island_level == 6) {
                points = 80;
            } else if (player_island_level == 7) {
                points = 100;
            } else if (player_island_level == 8) {
                points = 122;
            } else if (player_island_level == 9) {
                points = 150;
            } else if (player_island_level == 10) {
                points = 200;
            }

            // Save PlayerIslandOwned model
            set!(
                world,
                (PlayerIslandOwned {
                    map_id, player: caller, index: 0, island_id: player_island.island_id
                })
            );

            // Save Island model
            set!(world, (player_island));

            // Save Player model
            player.num_islands_owned = 1;
            player.points += points;
            player.energy = 25;
            player.energy_reset_time = daily_timestamp;
            set!(world, (player));

            // Update the latest map's data
            let mut map = get!(world, (map_id), MapInfo);
            map.derelict_islands_num -= 1;
            map.total_re_join_map += 1;
            set!(world, (map));

            // Emit events
            emitter_comp
                .emit_points_changed(
                    world,
                    PointsChanged {
                        map_id,
                        player_earned: caller,
                        points_earned: points,
                        player_lost: Zeroable::zero(),
                        points_lost: Zeroable::zero()
                    }
                );

            // Get the latest map's data
            let map = get!(world, (map_id), MapInfo);
            let island = get!(world, (map_id, island_id), Island);

            // Scout the newly initialized island sub-sub block and 8 surrounding one (if possible)
            let map_coordinates = map.map_coordinates;
            let map_sizes = map.map_sizes;

            let island_position_x = island.position.x;
            let island_position_y = island.position.y;

            assert_with_err(
                island_position_x >= map_coordinates.x && island_position_x < map_coordinates.x
                    + map_sizes
                        && island_position_y >= map_coordinates.y
                        && island_position_y < map_coordinates.y
                    + map_sizes,
                Error::INVALID_POSITION,
                Option::None
            );

            // Find center position
            let mut center_position = Position { x: 0, y: 0 };

            if (island_position_x % 3 == 0) {
                center_position.x = island_position_x + 1;
            } else if (island_position_x % 3 == 1) {
                center_position.x = island_position_x;
            } else if (island_position_x % 3 == 2) {
                center_position.x = island_position_x - 1;
            }

            if (island_position_y % 3 == 0) {
                center_position.y = island_position_y + 1;
            } else if (island_position_y % 3 == 1) {
                center_position.y = island_position_y;
            } else if (island_position_y % 3 == 2) {
                center_position.y = island_position_y - 1;
            }

            // Scout the center positions

            // Scout the 1st position
            let first_player_scout_info = get!(
                world, (map_id, caller, center_position.x, center_position.y), PlayerScoutInfo
            );
            if (first_player_scout_info.is_scouted == IsScouted::NotScouted) {
                scout_actions_comp
                    .scout(world, map_id, Position { x: center_position.x, y: center_position.y });
            }

            // Scout the 2nd position
            let second_player_scout_info = get!(
                world, (map_id, caller, center_position.x + 3, center_position.y), PlayerScoutInfo
            );
            if (center_position.x
                + 3 < map_coordinates.x
                + map_sizes && second_player_scout_info.is_scouted == IsScouted::NotScouted) {
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x + 3, y: center_position.y }
                    );
            }

            // Scout the 3rd position
            let third_player_scout_info = get!(
                world, (map_id, caller, center_position.x, center_position.y - 3), PlayerScoutInfo
            );
            if (center_position.y
                - 3 >= map_coordinates.y
                    && third_player_scout_info.is_scouted == IsScouted::NotScouted) {
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x, y: center_position.y - 3 }
                    );
            }

            // Scout the 4th position
            let forth_player_scout_info = get!(
                world, (map_id, caller, center_position.x - 3, center_position.y), PlayerScoutInfo
            );
            if (center_position.x
                - 3 >= map_coordinates.x
                    && forth_player_scout_info.is_scouted == IsScouted::NotScouted) {
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x - 3, y: center_position.y }
                    );
            }

            // Scout the 5th position
            let fifth_player_scout_info = get!(
                world, (map_id, caller, center_position.x, center_position.y + 3), PlayerScoutInfo
            );
            if (center_position.y
                + 3 < map_coordinates.y
                + map_sizes && fifth_player_scout_info.is_scouted == IsScouted::NotScouted) {
                scout_actions_comp
                    .scout(
                        world, map_id, Position { x: center_position.x, y: center_position.y + 3 }
                    );
            }

            true
        }

        // See IMapActions-init_new_map
        fn init_new_map(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher
        ) -> usize {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            // Get u32 max
            let u32_max = BoundedU32::max();

            // Generate MAP_ID
            let mut data_map_id: Array<felt252> = array!['MAP_ID', get_block_timestamp().into()];
            let map_id_u256: u256 = poseidon::poseidon_hash_span(data_map_id.span())
                .try_into()
                .unwrap();
            let map_id: usize = (map_id_u256 % u32_max.into()).try_into().unwrap();

            // Check whether the map id has been initialized or not
            assert_with_err(
                get!(world, (map_id), MapInfo).is_initialized == IsMapInitialized::NotInitialized,
                Error::MAP_ALREADY_INITIALIZED,
                Option::None
            );

            // Init initial map size & coordinates
            let map_sizes = 23
                * 3
                * 4; // 23 blocks * 3 sub-blocks * 4 sub-sub-blocks ~ 276 x 276 sub-sub-blocks
            let cur_block_coordinates = Position {
                x: 132, y: 132
            }; // The starting block is in the middle of the map, with the ID of 265 ~ (132, 132)
            let cur_island_block_coordinates = cur_block_coordinates;
            let map_coordinates = Position { x: 0, y: 0 };

            // Init next block direction
            let block_direction_count = 0;
            let right_1 = 1; // 1
            let down_2 = 1 + (block_direction_count * 2); // 1
            let left_3 = 2 + (block_direction_count * 2); // 2
            let up_4 = 2 + (block_direction_count * 2); // 2
            let right_5 = 2 + (block_direction_count * 2); // 2

            // Save NextBlockDirection model
            set!(world, (NextBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 }));

            // Init next block direction (island)
            let island_block_direction_count = 0;
            let right_1 = 1; // 1
            let down_2 = 1 + (island_block_direction_count * 2); // 1
            let left_3 = 2 + (island_block_direction_count * 2); // 2
            let up_4 = 2 + (island_block_direction_count * 2); // 2
            let right_5 = 2 + (island_block_direction_count * 2); // 2

            // Save NextIslandBlockDirection model
            set!(
                world, (NextIslandBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 })
            );

            // Save MapInfo model
            set!(
                world,
                (MapInfo {
                    map_id,
                    is_initialized: IsMapInitialized::Initialized,
                    total_player: 0,
                    total_island: 0,
                    total_dragon: 0,
                    total_scout: 0,
                    total_journey: 0,
                    total_activate_dragon: 0,
                    total_deactivate_dragon: 0,
                    total_join_map: 0,
                    total_re_join_map: 0,
                    total_start_journey: 0,
                    total_finish_journey: 0,
                    total_claim_resources: 0,
                    total_claim_dragon: 0,
                    total_activate_shield: 0,
                    total_deactivate_shield: 0,
                    map_sizes,
                    map_coordinates,
                    cur_block_coordinates,
                    block_direction_count,
                    derelict_islands_num: 0,
                    cur_island_block_coordinates,
                    island_block_direction_count,
                    dragon_token_id_counter: 99999
                })
            );

            // Generate prior islands on the first middle blocks of the map
            IslandTrait::gen_island_per_block(
                world, map_id, cur_island_block_coordinates, IslandType::Normal
            );

            // Initialize mission
            let mut mission_actions_comp = get_dep_component_mut!(ref self, MissionActions);
            mission_actions_comp
                .update_mission(
                    world,
                    DAILY_LOGIN_MISSION_ID,
                    array![0],
                    array![1_000_000],
                    array![0],
                    array![50]
                );
            mission_actions_comp
                .update_mission(
                    world,
                    SCOUT_MISSION_ID,
                    array![5, 10, 20],
                    array![250_000, 500_000, 1_000_000],
                    array![0, 0, 0],
                    array![50, 50, 50]
                );
            mission_actions_comp
                .update_mission(
                    world,
                    START_JOURNEY_MISSION_ID,
                    array![1, 3, 5],
                    array![250_000, 500_000, 1_000_000],
                    array![0, 0, 0],
                    array![50, 50, 50]
                );

            // Initialize achievement
            let mut achievement_actions_comp = get_dep_component_mut!(ref self, AchievementActions);
            achievement_actions_comp
                .update_achievement(
                    world,
                    OWN_ISLAND_ACHIEVEMENT_ID,
                    array![10, 20, 30, 50, 100],
                    array![0, 0, 0, 0, 0],
                    array![20, 20, 20, 20, 20]
                );

            // Initialize account level reward
            let mut player_actions_comp = get_dep_component_mut!(ref self, PlayerActions);
            player_actions_comp.update_account_level_reward(world, 2, 500_000, 2, 1);
            player_actions_comp.update_account_level_reward(world, 3, 750_000, 4, 1);
            player_actions_comp.update_account_level_reward(world, 4, 1_000_000, 6, 1);
            player_actions_comp.update_account_level_reward(world, 5, 1_250_000, 8, 1);
            player_actions_comp.update_account_level_reward(world, 6, 1_500_000, 10, 1);
            player_actions_comp.update_account_level_reward(world, 7, 1_750_000, 12, 1);
            player_actions_comp.update_account_level_reward(world, 8, 2_000_000, 14, 1);
            player_actions_comp.update_account_level_reward(world, 9, 2_250_000, 16, 1);
            player_actions_comp.update_account_level_reward(world, 10, 2_500_000, 18, 1);
            player_actions_comp.update_account_level_reward(world, 11, 2_750_000, 20, 1);
            player_actions_comp.update_account_level_reward(world, 12, 3_000_000, 22, 1);
            player_actions_comp.update_account_level_reward(world, 13, 3_250_000, 24, 1);
            player_actions_comp.update_account_level_reward(world, 14, 3_500_000, 26, 1);
            player_actions_comp.update_account_level_reward(world, 15, 3_750_000, 28, 1);
            player_actions_comp.update_account_level_reward(world, 16, 4_000_000, 30, 1);
            player_actions_comp.update_account_level_reward(world, 17, 4_250_000, 32, 1);
            player_actions_comp.update_account_level_reward(world, 18, 4_500_000, 34, 1);
            player_actions_comp.update_account_level_reward(world, 19, 4_750_000, 36, 1);
            player_actions_comp.update_account_level_reward(world, 20, 5_000_000, 38, 1);

            // Initialize invitation level reward
            player_actions_comp.update_invitation_level_reward(world, 2, 2_000_000, 20, 1);
            player_actions_comp.update_invitation_level_reward(world, 3, 3_000_000, 40, 1);
            player_actions_comp.update_invitation_level_reward(world, 4, 4_000_000, 60, 1);
            player_actions_comp.update_invitation_level_reward(world, 5, 5_000_000, 80, 1);
            player_actions_comp.update_invitation_level_reward(world, 6, 7_000_000, 100, 1);
            player_actions_comp.update_invitation_level_reward(world, 7, 9_000_000, 120, 1);
            player_actions_comp.update_invitation_level_reward(world, 8, 12_000_000, 140, 1);
            player_actions_comp.update_invitation_level_reward(world, 9, 16_000_000, 160, 1);
            player_actions_comp.update_invitation_level_reward(world, 10, 20_000_000, 180, 1);
            player_actions_comp.update_invitation_level_reward(world, 11, 20_000_000, 200, 1);
            player_actions_comp.update_invitation_level_reward(world, 12, 20_000_000, 220, 1);
            player_actions_comp.update_invitation_level_reward(world, 13, 20_000_000, 240, 1);
            player_actions_comp.update_invitation_level_reward(world, 14, 20_000_000, 260, 1);
            player_actions_comp.update_invitation_level_reward(world, 15, 20_000_000, 280, 1);
            player_actions_comp.update_invitation_level_reward(world, 16, 20_000_000, 300, 1);

            map_id
        }
    }
}
