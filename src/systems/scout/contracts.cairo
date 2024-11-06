// Internal imports
use dragark::models::position::Position;

// Interface
#[dojo::interface]
trait IScoutSystem<TContractState> {
    // Function for player scouting the map
    // # Argument
    // * map_id The map_id to init action
    // * destination Position to scout
    // # Return
    // * Position Position of destination
    fn scout(ref world: IWorldDispatcher, map_id: usize, destination: Position) -> felt252;
}

// Contract
#[dojo::contract]
mod scout_systems {
    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            map::{MapInfo, IsMapInitialized}, mission::MissionTracking,
            player::{Player, PlayerGlobal, IsPlayerJoined}, position::{Position},
            scout::{ScoutTrait}
        },
        constants::SCOUT_MISSION_ID, errors::{Error, assert_with_err, panic_by_err},
        events::{Scouted, MissionMilestoneReached},
        utils::general::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::IScoutSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Scouted: Scouted,
        MissionMilestoneReached: MissionMilestoneReached
    }

    // Impls
    #[abi(embed_v0)]
    impl ScoutContractImpl of IScoutSystem<ContractState> {
        // See IIslandContract-scout
        fn scout(ref world: IWorldDispatcher, map_id: usize, destination: Position) -> felt252 {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let player_global = get!(world, (caller), PlayerGlobal);
            let mut player = get!(world, (caller, map_id), Player);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Scout
            let mut mission_tracking = get!(
                world, (player.player, map_id, SCOUT_MISSION_ID), MissionTracking
            );
            let scout_id = ScoutTrait::scout(
                ref player, ref map, ref mission_tracking, world, destination, cur_timestamp
            );

            // Emit events
            emit!(
                world,
                (Event::Scouted(
                    Scouted { map_id, player: caller, scout_id, destination, time: cur_timestamp }
                ))
            );

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

            scout_id
        }
    }
}
