// Internal imports
use dragark::models::shield::ShieldType;

// Interface
#[dojo::interface]
trait IShieldSystem<TContractState> {
    // Function for player to activate a shield to protect their island
    // # Argument
    // * map_id The map id
    // * island_id The island id to activate the shield on
    // * shield_type The shield type
    fn activate_shield(
        ref world: IWorldDispatcher, map_id: usize, island_id: usize, shield_type: ShieldType
    );

    // Function for player to deactivate a shield from their island
    // # Argument
    // * map_id The map id
    // * island_id The island id to deactivate the shield from
    fn deactivate_shield(ref world: IWorldDispatcher, map_id: usize, island_id: usize);

    // Function for player to buy a shield to protect their island
    // # Argument
    // * shield_type The shield type
    // * num The number of shield to buy
    fn buy_shield(ref world: IWorldDispatcher, shield_type: ShieldType, num: u32);
}

// Contract
#[dojo::contract]
mod shield_systems {
    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            island::Island, map::{MapInfo, IsMapInitialized},
            player::{Player, PlayerGlobal, IsPlayerJoined},
            shield::{Shield, ShieldType, ShieldTrait}
        },
        errors::{Error, assert_with_err},
        events::{ShieldActivated, ShieldDeactivated, PlayerStoneUpdate, PlayerDragarkStoneUpdate},
        utils::general::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::IShieldSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ShieldActivated: ShieldActivated,
        ShieldDeactivated: ShieldDeactivated,
        PlayerStoneUpdate: PlayerStoneUpdate,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate
    }

    // Impls
    #[abi(embed_v0)]
    impl IShieldSystemImpl of IShieldSystem<ContractState> {
        // See IShieldSystem-activate_shield
        fn activate_shield(
            ref world: IWorldDispatcher, map_id: usize, island_id: usize, shield_type: ShieldType
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let mut island = get!(world, (map_id, island_id), Island);
            let player_global = get!(world, (caller), PlayerGlobal);
            let player = get!(world, (caller, map_id), Player);
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

            // Check if island exists
            assert_with_err(
                island.claim_waiting_time >= 30, Error::ISLAND_NOT_EXISTS, Option::None
            );

            // Verify input
            assert_with_err(
                shield_type == ShieldType::Type1
                    || shield_type == ShieldType::Type2
                    || shield_type == ShieldType::Type3
                    || shield_type == ShieldType::Type4,
                Error::INVALID_SHIELD_TYPE,
                Option::None
            );

            // Check the player owns the island
            assert_with_err(island.owner == caller, Error::NOT_OWN_ISLAND, Option::None);

            // Check the island is not protected by shield
            assert_with_err(
                cur_block_timestamp > island.shield_protection_time,
                Error::ISLAND_ALREADY_PROTECTED,
                Option::None
            );

            // Check the player has enough shield
            let mut player_shield = get!(world, (caller, shield_type), Shield);
            assert_with_err(player_shield.nums_owned > 0, Error::NOT_ENOUGH_SHIELD, Option::None);

            // Activate shield
            ShieldTrait::activate_shield(
                ref player_shield, ref island, ref map, world, cur_block_timestamp
            );

            // Emit events
            emit!(
                world,
                (Event::ShieldActivated(
                    ShieldActivated {
                        map_id,
                        island_id,
                        shield_type,
                        shield_protection_time: island.shield_protection_time
                    }
                ))
            );
        }

        // See IShieldSystem-deactivate_shield
        fn deactivate_shield(ref world: IWorldDispatcher, map_id: usize, island_id: usize) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let mut island = get!(world, (map_id, island_id), Island);
            let player_global = get!(world, (caller), PlayerGlobal);
            let player = get!(world, (caller, map_id), Player);
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

            // Check if island exists
            assert_with_err(
                island.claim_waiting_time >= 30, Error::ISLAND_NOT_EXISTS, Option::None
            );

            // Check the player owns the island
            assert_with_err(island.owner == caller, Error::NOT_OWN_ISLAND, Option::None);

            // Check the island is being protected by shield
            assert_with_err(
                cur_block_timestamp <= island.shield_protection_time,
                Error::ISLAND_NOT_PROTECTED,
                Option::None
            );

            // Deactivate shield
            ShieldTrait::deactivate_shield(ref island, ref map, world, cur_block_timestamp);

            // Emit events
            emit!(
                world,
                (Event::ShieldDeactivated(
                    ShieldDeactivated {
                        map_id, island_id, shield_protection_time: island.shield_protection_time
                    }
                ))
            );
        }

        // See IShieldSystem-buy_shield
        fn buy_shield(ref world: IWorldDispatcher, shield_type: ShieldType, num: u32) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
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
            assert_with_err(
                shield_type == ShieldType::Type1
                    || shield_type == ShieldType::Type2
                    || shield_type == ShieldType::Type3
                    || shield_type == ShieldType::Type4,
                Error::INVALID_SHIELD_TYPE,
                Option::None
            );
            assert_with_err(num > 0, Error::INVALID_NUM, Option::None);

            // Buy shield
            ShieldTrait::buy_shield(ref player, world, shield_type, num, cur_block_timestamp);

            // Emit events
            if (player.current_stone != player_stone_before) {
                emit!(
                    world,
                    (Event::PlayerStoneUpdate(
                        PlayerStoneUpdate {
                            map_id,
                            player: caller,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    ))
                );
            }

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
