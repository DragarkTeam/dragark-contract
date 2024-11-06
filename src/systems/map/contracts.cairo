// Interface
#[dojo::interface]
trait IMapSystem<TContractState> {
    // Function for player joining the map
    // Only callable for players who haven't joined the map
    // # Argument
    // * map_id The map_id to join
    // * star User's star
    // * nonce Nonce used for signature verification
    // * signature_r Signature R
    // * signature_s Signature S
    // # Return
    // * bool Whether the tx successful or not
    fn join_map(
        ref world: IWorldDispatcher,
        map_id: usize,
        star: u32,
        nonce: felt252,
        signature_r: felt252,
        signature_s: felt252
    ) -> bool;

    // Function for player re-joining the map when all their islands are captured
    // Only callable for players who have joined the map and have no islands remaining
    // # Argument
    // * map_id The map_id to join
    // # Return
    // * bool Whether the tx successful or not
    fn re_join_map(ref world: IWorldDispatcher, map_id: usize) -> bool;

    // Function for initializing a new map, only callable by admin
    // This function MUST BE CALLED FIRST in order to get the game/map operating
    // # Return
    // * usize The initialized map_id
    fn init_new_map(ref world: IWorldDispatcher) -> usize;
}

// Contract
#[dojo::contract]
mod map_systems {
    // Starknet imports
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

    // Internal imports
    use dragark::{
        models::{
            map::{MapInfo, IsMapInitialized, MapTrait}, mission::MissionTracking,
            player::{Player, PlayerGlobal, IsPlayerJoined}
        },
        constants::SCOUT_MISSION_ID, errors::{Error, assert_with_err, panic_by_err},
        events::{
            Scouted, MissionMilestoneReached, PlayerDragarkStoneUpdate,
            PlayerContributionPointChange
        },
        utils::general::{
            _is_playable, _require_valid_time, _require_world_owner,
            total_contribution_point_to_dragark_stone_pool
        }
    };

    // Local imports
    use super::IMapSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Scouted: Scouted,
        MissionMilestoneReached: MissionMilestoneReached,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate,
        PlayerContributionPointChange: PlayerContributionPointChange
    }

    // Impls
    #[abi(embed_v0)]
    impl MapContractImpl of IMapSystem<ContractState> {
        // See IMapSystem-join_map
        fn join_map(
            ref world: IWorldDispatcher,
            map_id: usize,
            star: u32,
            nonce: felt252,
            signature_r: felt252,
            signature_s: felt252
        ) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let map_contract_address = get_contract_address();
            let mut player = get!(world, (caller, map_id), Player);
            let player_join_map_status = player.is_joined_map;
            let player_contribution_points_before = player.contribution_points;
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let mut map = get!(world, (map_id), MapInfo);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Join map
            let mut mission_tracking = get!(
                world, (player.player, map_id, SCOUT_MISSION_ID), MissionTracking
            );
            let (
                scouted_destinations,
                scout_ids,
                is_recalculate_cp_needed,
                old_map_id,
                player_old_map_contribution_points_before
            ) =
                MapTrait::join_map(
                ref player,
                ref player_global,
                ref map,
                ref mission_tracking,
                world,
                star,
                nonce,
                signature_r,
                signature_s,
                map_contract_address,
                cur_timestamp
            );

            // Emit events
            if (!scouted_destinations.is_empty()) {
                let mut scouted_index = 0;
                let scouted_destinations_len = scouted_destinations.len();
                loop {
                    if (scouted_index == scouted_destinations_len) {
                        break;
                    }

                    let scouted_destination = *scouted_destinations.at(scouted_index);
                    let scout_id = *scout_ids.at(scouted_index);
                    emit!(
                        world,
                        (Event::Scouted(
                            Scouted {
                                map_id,
                                player: caller,
                                scout_id,
                                destination: scouted_destination,
                                time: cur_timestamp,
                            }
                        ))
                    );

                    scouted_index += 1;
                }
            }

            let mission_tracking_current_value = mission_tracking.current_value;
            if (mission_tracking_current_value == 5
                || mission_tracking_current_value == 10
                || mission_tracking_current_value == 20) {
                emit!(
                    world,
                    (Event::MissionMilestoneReached(
                        MissionMilestoneReached {
                            mission_id: SCOUT_MISSION_ID,
                            map_id,
                            player: caller,
                            current_value: mission_tracking_current_value
                        }
                    ))
                );
            }

            if (player_join_map_status == IsPlayerJoined::NotJoined) {
                emit!(
                    world,
                    (Event::PlayerDragarkStoneUpdate(
                        PlayerDragarkStoneUpdate {
                            map_id,
                            player: caller,
                            dragark_stone_balance: player.dragark_stone_balance
                        }
                    ))
                );
            }

            if (is_recalculate_cp_needed) {
                let old_map = get!(world, (old_map_id), MapInfo);
                let dragark_stone_pool = total_contribution_point_to_dragark_stone_pool(
                    world, map.total_contribution_points, cur_timestamp
                );
                let dragark_stone_pool_old_map = total_contribution_point_to_dragark_stone_pool(
                    world, old_map.total_contribution_points, cur_timestamp
                );

                // Old map
                let player_old_map = get!(world, (caller, old_map_id), Player);
                if (player_old_map
                    .contribution_points != player_old_map_contribution_points_before) {
                    emit!(
                        world,
                        (Event::PlayerContributionPointChange(
                            PlayerContributionPointChange {
                                map_id: old_map_id,
                                player: caller,
                                player_contribution_points: player_old_map.contribution_points,
                                total_contribution_points: old_map.total_contribution_points,
                                dragark_stone_pool: dragark_stone_pool_old_map
                            }
                        ))
                    );
                }

                // New map
                if (player.contribution_points != player_contribution_points_before) {
                    emit!(
                        world,
                        (Event::PlayerContributionPointChange(
                            PlayerContributionPointChange {
                                map_id,
                                player: caller,
                                player_contribution_points: player.contribution_points,
                                total_contribution_points: map.total_contribution_points,
                                dragark_stone_pool
                            }
                        ))
                    );
                }
            }

            true
        }

        // See IMapSystem-re_join_map
        fn re_join_map(ref world: IWorldDispatcher, map_id: usize) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player = get!(world, (caller, map_id), Player);
            let player_global = get!(world, (caller), PlayerGlobal);
            let mut map = get!(world, (map_id), MapInfo);
            let cur_timestamp = get_block_timestamp();

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

            // Re join map
            let mut mission_tracking = get!(
                world, (player.player, map_id, SCOUT_MISSION_ID), MissionTracking
            );
            let (scouted_destinations, scout_ids) = MapTrait::re_join_map(
                ref player, ref map, ref mission_tracking, world, cur_timestamp
            );

            // Emit events
            if (!scouted_destinations.is_empty()) {
                let mut scouted_index = 0;
                let scouted_destinations_len = scouted_destinations.len();
                loop {
                    if (scouted_index == scouted_destinations_len) {
                        break;
                    }

                    let scouted_destination = *scouted_destinations.at(scouted_index);
                    let scout_id = *scout_ids.at(scouted_index);
                    emit!(
                        world,
                        (Event::Scouted(
                            Scouted {
                                map_id,
                                player: caller,
                                scout_id,
                                destination: scouted_destination,
                                time: cur_timestamp,
                            }
                        ))
                    );

                    scouted_index += 1;
                }
            }

            let mission_tracking_current_value = mission_tracking.current_value;
            if (mission_tracking_current_value == 5
                || mission_tracking_current_value == 10
                || mission_tracking_current_value == 20) {
                emit!(
                    world,
                    (Event::MissionMilestoneReached(
                        MissionMilestoneReached {
                            mission_id: SCOUT_MISSION_ID,
                            map_id,
                            player: caller,
                            current_value: mission_tracking_current_value
                        }
                    ))
                );
            }

            true
        }

        // See IMapSystem-init_new_map
        fn init_new_map(ref world: IWorldDispatcher) -> usize {
            let caller = get_caller_address();

            // Check caller
            _require_world_owner(world, caller);

            // Init new map
            MapTrait::init_new_map(world)
        }
    }
}
