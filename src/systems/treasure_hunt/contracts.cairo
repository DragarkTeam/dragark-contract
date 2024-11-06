// Internal imports
use dragark::models::treasure_hunt::TreasureHuntType;

// Interface
#[dojo::interface]
trait ITreasureHuntSystem<TContractState> {
    // Function to insert a dragon to claim Dragark Stone later
    // # Argument
    // * treasure_hunt_type The type to treasure hunting
    // * dragon_token_ids The dragon token ids to insert
    fn insert_dragon_treasure_hunt(
        ref world: IWorldDispatcher,
        treasure_hunt_type: TreasureHuntType,
        dragon_token_ids: Array<u128>
    ) -> felt252;

    // Function to claim Dragark Stone
    // # Argument
    // * treasure_hunt_id The dragon token id to claim
    fn end_treasure_hunt(ref world: IWorldDispatcher, treasure_hunt_id: felt252);
}

// Contract
#[dojo::contract]
mod treasure_hunt_systems {
    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            map::{MapInfo, IsMapInitialized}, player::{Player, PlayerGlobal, IsPlayerJoined},
            treasure_hunt::{TreasureHunt, TreasureHuntType, TreasureHuntStatus, TreasureHuntTrait}
        },
        errors::{Error, assert_with_err},
        events::{TreasureHuntStarted, TreasureHuntFinished, PlayerDragarkStoneUpdate},
        utils::general::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::ITreasureHuntSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TreasureHuntStarted: TreasureHuntStarted,
        TreasureHuntFinished: TreasureHuntFinished,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate
    }

    // Impls
    #[abi(embed_v0)]
    impl ITreasureHuntSystemImpl of ITreasureHuntSystem<ContractState> {
        // See ITreasureHuntSystem-insert_dragon_treasure_hunt
        fn insert_dragon_treasure_hunt(
            ref world: IWorldDispatcher,
            treasure_hunt_type: TreasureHuntType,
            dragon_token_ids: Array<u128>
        ) -> felt252 {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let player = get!(world, (caller, map_id), Player);
            let current_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Verify input
            assert_with_err(
                treasure_hunt_type == TreasureHuntType::VIP
                    || treasure_hunt_type == TreasureHuntType::Normal1
                    || treasure_hunt_type == TreasureHuntType::Normal2
                    || treasure_hunt_type == TreasureHuntType::Normal3,
                Error::INVALID_TREASURE_HUNT_TYPE,
                Option::None
            );

            // Check account level & input dragon sent conditions
            let mut required_dragon_level: u8 = 1;
            let player_account_level = player.account_level;
            if (treasure_hunt_type == TreasureHuntType::Normal1) {
                assert_with_err(
                    player_account_level >= 5, Error::ACCOUNT_LEVEL_NOT_MET, Option::None
                );
                required_dragon_level = 5;
            } else if (treasure_hunt_type == TreasureHuntType::Normal2) {
                assert_with_err(
                    player_account_level >= 10, Error::ACCOUNT_LEVEL_NOT_MET, Option::None
                );
                required_dragon_level = 10;
            } else if (treasure_hunt_type == TreasureHuntType::Normal3) {
                assert_with_err(
                    player_account_level >= 15, Error::ACCOUNT_LEVEL_NOT_MET, Option::None
                );
                required_dragon_level = 15;
            }

            // Check dragon number sent
            let dragon_num = dragon_token_ids.len();
            assert_with_err(dragon_num > 0, Error::DRAGON_NUM_CANT_BE_ZERO, Option::None);
            if (player_account_level < 10) {
                assert_with_err(dragon_num <= 2, Error::DRAGON_LIMIT_EXCEEDED, Option::None);
            } else if (player_account_level >= 10) {
                assert_with_err(dragon_num <= 3, Error::DRAGON_LIMIT_EXCEEDED, Option::None);
            }

            // Insert dragon treasure hunt
            let treasure_hunt_id = TreasureHuntTrait::insert_dragon_treasure_hunt(
                ref map,
                world,
                treasure_hunt_type,
                dragon_token_ids,
                caller,
                required_dragon_level,
                current_block_timestamp
            );

            // Emit events
            let start_time = get!(world, (map_id, treasure_hunt_id), TreasureHunt).start_time;
            let finish_time = get!(world, (map_id, treasure_hunt_id), TreasureHunt).finish_time;
            let earned_dragark_stone = get!(world, (map_id, treasure_hunt_id), TreasureHunt)
                .earned_dragark_stone;
            let status = get!(world, (map_id, treasure_hunt_id), TreasureHunt).status;
            let dragon_token_ids = get!(world, (map_id, treasure_hunt_id), TreasureHunt)
                .dragon_token_ids;
            let dragon_recovery_times = get!(world, (map_id, treasure_hunt_id), TreasureHunt)
                .dragon_recovery_times;

            emit!(
                world,
                (Event::TreasureHuntStarted(
                    TreasureHuntStarted {
                        map_id,
                        player: caller,
                        treasure_hunt_id,
                        treasure_hunt_type,
                        start_time,
                        finish_time,
                        earned_dragark_stone,
                        status,
                        dragon_token_ids,
                        dragon_recovery_times
                    }
                ))
            );

            treasure_hunt_id
        }

        // See ITreasureHuntSystem-end_treasure_hunt
        fn end_treasure_hunt(ref world: IWorldDispatcher, treasure_hunt_id: felt252) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_dragark_stone_before = player.dragark_stone_balance;
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Verify input
            assert_with_err(treasure_hunt_id.is_non_zero(), Error::INVALID_DRAGON_ID, Option::None);
            let treasure_hunt = get!(world, (map_id, treasure_hunt_id), TreasureHunt);

            // Check treasure hunt status
            assert_with_err(
                treasure_hunt.status == TreasureHuntStatus::Started,
                Error::TREASURE_HUNT_ALREADY_FINISHED,
                Option::None
            );

            // Check caller
            assert_with_err(caller == treasure_hunt.owner, Error::WRONG_CALLER, Option::None);

            // Check time
            assert_with_err(
                cur_block_timestamp >= treasure_hunt.finish_time,
                Error::TREASURE_HUNT_IN_PROGRESS,
                Option::None
            );

            // End treasure hunt
            TreasureHuntTrait::end_treasure_hunt(
                ref player, world, treasure_hunt_id, cur_block_timestamp
            );

            // Emit events
            let treasure_hunt_type = get!(world, (map_id, treasure_hunt_id), TreasureHunt)
                .treasure_hunt_type;
            let start_time = get!(world, (map_id, treasure_hunt_id), TreasureHunt).start_time;
            let finish_time = get!(world, (map_id, treasure_hunt_id), TreasureHunt).finish_time;
            let earned_dragark_stone = get!(world, (map_id, treasure_hunt_id), TreasureHunt)
                .earned_dragark_stone;
            let status = get!(world, (map_id, treasure_hunt_id), TreasureHunt).status;
            let dragon_token_ids = get!(world, (map_id, treasure_hunt_id), TreasureHunt)
                .dragon_token_ids;
            let dragon_recovery_times = get!(world, (map_id, treasure_hunt_id), TreasureHunt)
                .dragon_recovery_times;

            emit!(
                world,
                (Event::TreasureHuntFinished(
                    TreasureHuntFinished {
                        map_id,
                        player: caller,
                        treasure_hunt_id,
                        treasure_hunt_type,
                        start_time,
                        finish_time,
                        earned_dragark_stone,
                        status,
                        dragon_token_ids,
                        dragon_recovery_times
                    }
                ))
            );

            if (player.dragark_stone_balance != player_dragark_stone_before) {
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
        }
    }
}
