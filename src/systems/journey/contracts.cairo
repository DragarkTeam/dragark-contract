// Internal imports
use dragark::models::island::Resource;

// Interface
#[dojo::interface]
trait IJourneySystem<TContractState> {
    // Function for player to start a new journey
    // # Argument
    // * map_id The map_id to init action
    // * dragon_token_id ID of the specified dragon
    // * island_from_id ID of the starting island
    // * island_to_id ID of the destination island
    // * resources Specified amount of resources to carry (including foods & stones)
    // # Return
    // * bool Whether the tx successful or not
    fn start_journey(
        ref world: IWorldDispatcher,
        map_id: usize,
        dragon_token_id: u128,
        island_from_id: usize,
        island_to_id: usize,
        resources: Resource
    ) -> felt252;

    // Function to finish a started journey
    // # Argument
    // * map_id The map_id to init action
    // * journey_id ID of the started journey
    // # Return
    // * bool Whether the tx successful or not
    fn finish_journey(ref world: IWorldDispatcher, map_id: usize, journey_id: felt252) -> bool;
}

// Contract
#[dojo::contract]
mod journey_systems {
    // Core imports
    use core::Zeroable;

    // Starknet imports
    use starknet::{get_block_timestamp, get_caller_address};

    // Internal imports
    use dragark::{
        models::{
            dragon::{Dragon, DragonState}, island::{Island, Resource},
            journey::{Journey, AttackType, AttackResult, JourneyStatus, JourneyTrait},
            map::{MapInfo, IsMapInitialized}, mission::MissionTracking,
            player::{Player, PlayerGlobal, IsPlayerJoined}
        },
        constants::{START_JOURNEY_MISSION_ID}, errors::{Error, assert_with_err, panic_by_err},
        events::{JourneyStarted, JourneyFinished, MissionMilestoneReached, PlayerStoneUpdate},
        utils::general::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::IJourneySystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        JourneyStarted: JourneyStarted,
        JourneyFinished: JourneyFinished,
        MissionMilestoneReached: MissionMilestoneReached,
        PlayerStoneUpdate: PlayerStoneUpdate
    }

    // Impls
    #[abi(embed_v0)]
    impl JourneyContractImpl of IJourneySystem<ContractState> {
        // See IJourneySystem-start_journey
        fn start_journey(
            ref world: IWorldDispatcher,
            map_id: usize,
            dragon_token_id: u128,
            island_from_id: usize,
            island_to_id: usize,
            resources: Resource
        ) -> felt252 {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player = get!(world, (caller, map_id), Player);
            let mut map = get!(world, (map_id), MapInfo);
            let player_global = get!(world, (caller), PlayerGlobal);
            let cur_block_timestamp = get_block_timestamp();

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

            let mut dragon = get!(world, (dragon_token_id), Dragon);
            let mut island_from = get!(world, (map_id, island_from_id), Island);
            let island_to = get!(world, (map_id, island_to_id), Island);

            // Check if dragon exists in the map
            assert_with_err(dragon.map_id == map_id, Error::DRAGON_NOT_EXISTS, Option::None);

            // Check if island exists
            assert_with_err(
                island_from.claim_waiting_time >= 30 && island_to.claim_waiting_time >= 30,
                Error::ISLAND_NOT_EXISTS,
                Option::None
            );

            // Check the island is not protected by shield
            assert_with_err(
                cur_block_timestamp > island_from.shield_protection_time,
                Error::ISLAND_FROM_PROTECTED,
                Option::None
            );

            // Verify input
            assert_with_err(dragon_token_id.is_non_zero(), Error::INVALID_DRAGON_ID, Option::None);
            assert_with_err(island_from_id.is_non_zero(), Error::INVALID_ISLAND_FROM, Option::None);
            assert_with_err(island_to_id.is_non_zero(), Error::INVALID_ISLAND_TO, Option::None);

            // Check the 2 islands are different
            assert_with_err(
                island_from_id != island_to_id, Error::JOURNEY_TO_THE_SAME_ISLAND, Option::None
            );

            // Check if the player has the island_from
            assert_with_err(island_from.owner == caller, Error::NOT_OWN_ISLAND, Option::None);

            // Check the player has the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check the dragon is on idling state
            assert_with_err(
                dragon.state == DragonState::Idling, Error::DRAGON_IS_NOT_AVAILABLE, Option::None
            );

            // Check the island_from has enough resources
            let island_from_resources = island_from.cur_resources;
            assert_with_err(
                resources.food <= island_from_resources.food, Error::NOT_ENOUGH_FOOD, Option::None
            );

            // Start journey
            let mut mission_tracking = get!(
                world, (caller, map_id, START_JOURNEY_MISSION_ID), MissionTracking
            );
            let journey = JourneyTrait::start_journey(
                ref dragon,
                ref island_from,
                ref map,
                ref mission_tracking,
                world,
                island_to,
                resources,
                cur_block_timestamp
            );
            let journey_id = journey.journey_id;

            // Emit events
            emit!(
                world,
                (Event::JourneyStarted(
                    JourneyStarted {
                        map_id,
                        player: caller,
                        journey_id,
                        dragon_token_id,
                        carrying_resources: resources,
                        island_from_id,
                        island_from_position: journey.island_from_position,
                        island_from_owner: journey.island_from_owner,
                        island_to_id,
                        island_to_position: journey.island_to_position,
                        island_to_owner: journey.island_to_owner,
                        start_time: journey.start_time,
                        finish_time: journey.finish_time,
                        attack_type: journey.attack_type,
                        attack_result: journey.attack_result,
                        status: journey.status
                    }
                ))
            );

            let mission_tracking_current_value = mission_tracking.current_value;
            if (mission_tracking_current_value == 1
                || mission_tracking_current_value == 3
                || mission_tracking_current_value == 5) {
                emit!(
                    world,
                    (Event::MissionMilestoneReached(
                        MissionMilestoneReached {
                            mission_id: START_JOURNEY_MISSION_ID,
                            map_id,
                            player: caller,
                            current_value: mission_tracking_current_value
                        }
                    ))
                );
            }

            journey_id
        }

        // See IJourneySystem-finish_journey
        fn finish_journey(ref world: IWorldDispatcher, map_id: usize, journey_id: felt252) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Verify input
            assert_with_err(journey_id.is_non_zero(), Error::INVALID_JOURNEY_ID, Option::None);
            let mut journey_info = get!(world, (map_id, journey_id), Journey);
            let dragon_token_id = journey_info.dragon_token_id;
            let mut dragon = get!(world, (dragon_token_id), Dragon);
            let cur_block_timestamp = get_block_timestamp();

            // Get capturing player
            let mut capturing_player = get!(world, (journey_info.owner, map_id), Player);

            // Check status
            assert_with_err(
                journey_info.status == JourneyStatus::Started,
                Error::JOURNEY_ALREADY_FINISHED,
                Option::None
            );

            // Check caller
            assert_with_err(caller == journey_info.owner, Error::WRONG_CALLER, Option::None);

            // Check dragon state
            assert_with_err(
                dragon.state == DragonState::Flying, Error::DRAGON_SHOULD_BE_FLYING, Option::None
            );

            let journey_captured_player = JourneyTrait::finish_journey(
                ref capturing_player,
                ref dragon,
                ref journey_info,
                ref map,
                world,
                cur_block_timestamp
            );

            // Emit events
            emit!(
                world,
                (Event::JourneyFinished(
                    JourneyFinished {
                        map_id,
                        player: caller,
                        journey_id,
                        dragon_token_id,
                        carrying_resources: journey_info.carrying_resources,
                        island_from_id: journey_info.island_from_id,
                        island_from_position: journey_info.island_from_position,
                        island_from_owner: journey_info.island_from_owner,
                        island_to_id: journey_info.island_to_id,
                        island_to_position: journey_info.island_to_position,
                        island_to_owner: journey_info.island_to_owner,
                        start_time: journey_info.start_time,
                        finish_time: journey_info.finish_time,
                        attack_type: journey_info.attack_type,
                        attack_result: journey_info.attack_result,
                        status: journey_info.status
                    }
                ))
            );

            if (journey_info.attack_result == AttackResult::Win) {
                emit!(
                    world,
                    (Event::PlayerStoneUpdate(
                        PlayerStoneUpdate {
                            map_id,
                            player: caller,
                            stone_rate: capturing_player.stone_rate,
                            current_stone: capturing_player.current_stone,
                            stone_updated_time: capturing_player.stone_updated_time,
                            stone_cap: capturing_player.stone_cap
                        }
                    ))
                );

                if (journey_info.attack_type == AttackType::PlayerIslandAttack) {
                    let captured_player = get!(world, (journey_captured_player, map_id), Player);
                    emit!(
                        world,
                        (Event::PlayerStoneUpdate(
                            PlayerStoneUpdate {
                                map_id,
                                player: journey_captured_player,
                                stone_rate: captured_player.stone_rate,
                                current_stone: captured_player.current_stone,
                                stone_updated_time: captured_player.stone_updated_time,
                                stone_cap: captured_player.stone_cap
                            }
                        ))
                    );
                }
            }

            true
        }
    }
}
