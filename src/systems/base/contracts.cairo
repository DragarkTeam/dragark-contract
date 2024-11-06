// Internal imports
use dragark::models::base::BaseResourcesType;

// Interface
#[dojo::interface]
trait IBaseSystem<TContractState> {
    // Function for player to change the total worker stats value
    // # Argument
    // * map_id The map id
    // * base_resources_type The base resources type
    fn change_value(
        ref world: IWorldDispatcher, map_id: usize, base_resources_type: BaseResourcesType
    );

    // Function for deducting resources amount
    // # Argument
    // * map_id The map id
    // * base_resources_type The base resources type
    fn deduct_resources(
        ref world: IWorldDispatcher, map_id: usize, base_resources_type: BaseResourcesType
    );
}

// Contract
#[dojo::contract]
mod base_systems {
    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            base::{BaseResourcesType, BaseTrait}, map::{MapInfo, IsMapInitialized},
            player::{Player, PlayerGlobal, IsPlayerJoined}
        },
        errors::{Error, assert_with_err}, utils::general::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::IBaseSystem;

    // Impls
    #[abi(embed_v0)]
    impl IBaseSystemImpl of IBaseSystem<ContractState> {
        // See IBaseSystem-change_value
        fn change_value(
            ref world: IWorldDispatcher, map_id: usize, base_resources_type: BaseResourcesType
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let map = get!(world, (map_id), MapInfo);
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

            // Verify base resources type
            assert_with_err(
                base_resources_type == BaseResourcesType::BaseResourcesType1
                    || base_resources_type == BaseResourcesType::BaseResourcesType2,
                Error::INVALID_BASE_RESOURCES_TYPE,
                Option::None
            );

            // Change value
            BaseTrait::change_value(
                world, caller, map_id, base_resources_type, cur_block_timestamp
            );
        }

        // See IBaseSystem-deduct_resources
        fn deduct_resources(
            ref world: IWorldDispatcher, map_id: usize, base_resources_type: BaseResourcesType
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let map = get!(world, (map_id), MapInfo);
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

            // Verify base resources type
            assert_with_err(
                base_resources_type == BaseResourcesType::BaseResourcesType1
                    || base_resources_type == BaseResourcesType::BaseResourcesType2,
                Error::INVALID_BASE_RESOURCES_TYPE,
                Option::None
            );

            // Deduct resources
            BaseTrait::deduct_resources(
                world, caller, map_id, base_resources_type, cur_block_timestamp
            );
        }
    }
}
