// Internal imports
use dragark::models::dragon::DragonInfo;

// Interface
#[dojo::interface]
trait IDragonSystem<TContractState> {
    // Function to activate a dragon mapped from L2
    // # Argument
    // * dragon_info DragonInfo struct
    // * signature_r Signature R
    // * signature_s Signature S
    fn activate_dragon(
        ref world: IWorldDispatcher,
        dragon_info: DragonInfo,
        signature_r: felt252,
        signature_s: felt252
    );

    // Function to deactivate a dragon
    // # Argument
    // * map_id The map_id to deactivate the dragon
    // * dragon_token_id ID of the specified dragon
    // * signature_r Signature R
    // * signature_s Signature S
    // * nonce The nonce used for the signature
    fn deactivate_dragon(
        ref world: IWorldDispatcher,
        map_id: usize,
        dragon_token_id: felt252,
        signature_r: felt252,
        signature_s: felt252,
        nonce: felt252
    );

    // Function for claiming the default dragon, used when joining the game
    // # Argument
    // * map_id The map_id to init action
    // # Return
    // * bool Whether the tx successful or not
    fn claim_default_dragon(ref world: IWorldDispatcher, map_id: usize) -> bool;

    // Function for upgrading a dragon
    // # Argument
    // * dragon_token_id ID of the dragon to upgrade
    fn upgrade_dragon(ref world: IWorldDispatcher, dragon_token_id: u128);
}

// Contract
#[dojo::contract]
mod dragon_systems {
    // Starknet imports
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            dragon::{Dragon, DragonInfo, DragonState, DragonType, DragonTrait},
            map::{MapInfo, NonceUsed, IsMapInitialized},
            player::{Player, PlayerGlobal, IsPlayerJoined, PlayerTrait}
        },
        constants::{DRAGON_LEVEL_RANGE, dragon_upgrade_cost}, errors::{Error, assert_with_err},
        events::{
            DragonUpgraded, PlayerStoneUpdate, PlayerDragarkStoneUpdate, PlayerAccountExpChange,
            PlayerContributionPointChange
        },
        utils::general::{
            _is_playable, _require_valid_time, total_contribution_point_to_dragark_stone_pool
        }
    };

    // Local imports
    use super::IDragonSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DragonUpgraded: DragonUpgraded,
        PlayerStoneUpdate: PlayerStoneUpdate,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate,
        PlayerAccountExpChange: PlayerAccountExpChange,
        PlayerContributionPointChange: PlayerContributionPointChange
    }

    // Impls
    #[abi(embed_v0)]
    impl DragonContractImpl of IDragonSystem<ContractState> {
        // See IDragonSystem-activate_dragon
        fn activate_dragon(
            ref world: IWorldDispatcher,
            dragon_info: DragonInfo,
            signature_r: felt252,
            signature_s: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let map_id: usize = dragon_info.map_id.try_into().unwrap();
            let dragon_owner: ContractAddress = dragon_info.owner.try_into().unwrap();
            let mut map = get!(world, (map_id), MapInfo);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check caller (burner)
            assert_with_err(dragon_owner == caller, Error::NOT_DRAGON_OWNER, Option::None);

            // Check nonce used
            let mut nonce_used = get!(world, (dragon_info.nonce), NonceUsed);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

            // Check if the dragon has been activated or not
            let dragon_token_id: u128 = dragon_info.dragon_token_id.try_into().unwrap();
            let dragon = get!(world, (dragon_token_id), Dragon);
            assert_with_err(
                dragon.dragon_type == DragonType::None && dragon.map_id == 0,
                Error::DRAGON_ALREADY_ACTIVATED,
                Option::None
            );

            // Activate dragon
            DragonTrait::activate_dragon(
                ref map, ref nonce_used, world, dragon_info, signature_r, signature_s
            );

            // Emit events
            let dragark_stone_pool = total_contribution_point_to_dragark_stone_pool(
                world, map.total_contribution_points, cur_block_timestamp
            );
            emit!(
                world,
                (Event::PlayerContributionPointChange(
                    PlayerContributionPointChange {
                        map_id,
                        player: caller,
                        player_contribution_points: get!(world, (caller, map_id), Player)
                            .contribution_points,
                        total_contribution_points: map.total_contribution_points,
                        dragark_stone_pool
                    }
                ))
            );
        }

        // See IDragonSystem-deactivate_dragon
        fn deactivate_dragon(
            ref world: IWorldDispatcher,
            map_id: usize,
            dragon_token_id: felt252,
            signature_r: felt252,
            signature_s: felt252,
            nonce: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let mut map = get!(world, (map_id), MapInfo);
            let dragon_token_id_u128: u128 = dragon_token_id.try_into().unwrap();
            let dragon = get!(world, (dragon_token_id_u128), Dragon);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check num dragons owned
            assert_with_err(
                player_global.num_dragons_owned >= 1, Error::NOT_OWN_ANY_DRAGON, Option::None
            );

            // Check dragon map id
            assert_with_err(dragon.map_id == map_id, Error::INVALID_DRAGON_MAP_ID, Option::None);

            // Check caller (burner)
            assert_with_err(dragon.owner == caller, Error::NOT_DRAGON_OWNER, Option::None);

            // Check nonce used
            let mut nonce_used = get!(world, (nonce), NonceUsed);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

            // Check dragon type
            assert_with_err(
                dragon.dragon_type == DragonType::NFT, Error::INVALID_DRAGON_TYPE, Option::None
            );

            // Check the dragon is not in journey
            assert_with_err(
                dragon.state == DragonState::Idling, Error::DRAGON_IS_NOT_AVAILABLE, Option::None
            );

            // Deactivate dragon
            DragonTrait::deactivate_dragon(
                ref player_global, ref map, ref nonce_used, world, dragon, signature_r, signature_s
            );

            // Emit events
            let dragark_stone_pool = total_contribution_point_to_dragark_stone_pool(
                world, map.total_contribution_points, cur_block_timestamp
            );
            emit!(
                world,
                (Event::PlayerContributionPointChange(
                    PlayerContributionPointChange {
                        map_id,
                        player: caller,
                        player_contribution_points: get!(world, (caller, map_id), Player)
                            .contribution_points,
                        total_contribution_points: map.total_contribution_points,
                        dragark_stone_pool
                    }
                ))
            );
        }

        // See IDragonSystem-claim_default_dragon
        fn claim_default_dragon(ref world: IWorldDispatcher, map_id: usize) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player = get!(world, (caller, map_id), Player);
            let mut map = get!(world, (map_id), MapInfo);
            let mut player_global = get!(world, (caller), PlayerGlobal);
            map.dragon_token_id_counter += 1;
            let default_dragon_id: u128 = map.dragon_token_id_counter;
            let default_dragon = get!(world, (default_dragon_id), Dragon);

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

            // Check that the player hasn't claimed yet
            assert_with_err(!player.is_claim_default_dragon, Error::ALREADY_CLAIMED, Option::None);

            // Check that the dragon hasn't been claimed yet
            assert_with_err(default_dragon.map_id == 0, Error::ALREADY_CLAIMED, Option::None);

            // Claim default dragon
            DragonTrait::claim_default_dragon(
                ref player, ref player_global, ref map, world, caller, default_dragon_id
            );

            true
        }

        // See IDragonSystem-upgrade_dragon
        fn upgrade_dragon(ref world: IWorldDispatcher, dragon_token_id: u128) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let player_contribution_points_before = player.contribution_points;
            let mut dragon = get!(world, (dragon_token_id), Dragon);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Check if dragon exists in the map
            assert_with_err(dragon.map_id == map_id, Error::DRAGON_NOT_EXISTS, Option::None);

            // Check the player has the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check the dragon level
            let dragon_level = dragon.level;
            let (min_level, max_level) = DRAGON_LEVEL_RANGE;
            assert_with_err(
                dragon_level >= min_level && dragon_level < max_level,
                Error::INVALID_DRAGON_LEVEL,
                Option::None
            );

            // Check required resources
            PlayerTrait::_update_stone(ref player, cur_timestamp); // Fetch current stone
            let (stone_required, dragark_stone_required) = dragon_upgrade_cost(dragon_level);
            assert_with_err(
                player.current_stone >= stone_required
                    && player.dragark_stone_balance >= dragark_stone_required,
                Error::NOT_ENOUGH_DRAGARK_UPGRADE_RESOURCES,
                Option::None
            );

            // Store old data
            let old_speed = dragon.speed;
            let old_attack = dragon.attack;
            let old_carrying_capacity = dragon.carrying_capacity;

            // Upgrade dragon
            DragonTrait::upgrade_dragon(
                ref player, ref dragon, ref map, world, stone_required, dragark_stone_required
            );

            // Emit events
            emit!(
                world,
                (Event::DragonUpgraded(
                    DragonUpgraded {
                        dragon_token_id,
                        owner: caller,
                        map_id,
                        new_level: dragon.level,
                        new_speed: dragon.speed,
                        new_attack: dragon.attack,
                        new_carrying_capacity: dragon.carrying_capacity,
                        old_speed,
                        old_attack,
                        old_carrying_capacity,
                        base_speed: dragon.base_speed,
                        base_attack: dragon.base_attack,
                        base_carrying_capacity: dragon.base_carrying_capacity
                    }
                ))
            );

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

            emit!(
                world,
                (Event::PlayerAccountExpChange(
                    PlayerAccountExpChange {
                        map_id,
                        player: caller,
                        player_account_exp: player.account_exp,
                        player_account_level: player.account_level,
                        total_account_exp: map.total_account_exp,
                    }
                ))
            );

            if (player.contribution_points != player_contribution_points_before) {
                let dragark_stone_pool = total_contribution_point_to_dragark_stone_pool(
                    world, map.total_contribution_points, cur_timestamp
                );
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
    }
}
