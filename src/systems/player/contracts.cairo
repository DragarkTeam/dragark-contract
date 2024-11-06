// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark::models::player::StarShopItemType;

// Interface
#[dojo::interface]
trait IPlayerSystem<TContractState> {
    // Function for player buying energy
    // # Argument
    // * pack The number of pack to buy
    fn buy_energy(ref world: IWorldDispatcher, pack: u8);

    // Function for player upgrading account level & claimming account level upgrade reward
    fn upgrade_account_level(ref world: IWorldDispatcher);

    // Function for player upgrading invitation level & claimming invitation level upgrade reward
    fn upgrade_invitation_level(ref world: IWorldDispatcher);

    // Function for player redeeming invite code
    // # Argument
    // * invite_code The invite code
    fn redeem_invite_code(ref world: IWorldDispatcher, invite_code: felt252);

    // Function for updating (add/modify/remove) account level reward
    // Only callable by admin
    // # Argument
    // * level The level want to update
    // * stone_reward The level's stone reward
    // * dragark_stone_reward The level's dragark stone reward
    // * free_dragark_reward The level's free dragark reward number
    fn update_account_level_reward(
        ref world: IWorldDispatcher,
        level: u8,
        stone_reward: u128,
        dragark_stone_reward: u128,
        free_dragark_reward: u8
    );

    // Function for updating (add/modify/remove) invitation level reward
    // Only callable by admin
    // # Argument
    // * level The level want to update
    // * stone_reward The level's stone reward
    // * dragark_stone_reward The level's dragark stone reward
    // * free_dragark_reward The level's free dragark reward number
    fn update_invitation_level_reward(
        ref world: IWorldDispatcher,
        level: u8,
        stone_reward: u128,
        dragark_stone_reward: u128,
        free_dragark_reward: u8
    );

    fn set(ref world: IWorldDispatcher, addr: ContractAddress);

    // Function for buying item from star shop
    // # Argument
    // * item_type The item want to buy
    fn buy_item_star_shop(ref world: IWorldDispatcher, item_type: StarShopItemType);

    // Function for buying resources pack
    // # Argument
    // * nonce Nonce used for signature verification
    // * signature_r Signature R
    // * signature_s Signature S
    fn buy_resources_pack(
        ref world: IWorldDispatcher, nonce: felt252, signature_r: felt252, signature_s: felt252
    );

    // Function for activating the Element NFT
    // # Argument
    // * element_nft_type The array of Element NFT's type to activate
    // * map_id Map ID
    // * nonce Nonce used for signature verification
    // * signature_r Signature R
    // * signature_s Signature S
    fn activate_element_nft(
        ref world: IWorldDispatcher,
        element_nft_type: felt252,
        map_id: usize,
        nonce: felt252,
        signature_r: felt252,
        signature_s: felt252
    );

    // Function for claiming the pool share reward
    // # Argument
    // * dragark_stone_earn The dragark stone player earned
    // * nonce Nonce used for signature verification
    // * signature_r Signature R
    // * signature_s Signature S
    fn claim_pool_share_reward(
        ref world: IWorldDispatcher,
        pool: u16,
        dragark_stone_earn: u128,
        nonce: felt252,
        signature_r: felt252,
        signature_s: felt252
    );

    // Function for updating the Pool Share info
    // Only callable by admin
    fn update_pool_share_info(
        ref world: IWorldDispatcher,
        pool: u16,
        milestone: u16,
        start_time: u64,
        end_time: u64,
        total_cp: u64,
        dragark_stone_pool: u128
    );
}

// Contract
#[dojo::contract]
mod player_systems {
    // Starknet imports
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            map::{MapInfo, NonceUsed, IsMapInitialized},
            player::{
                Player, PlayerGlobal, PlayerInviteCode, PoolShareInfo, PlayerPoolShareClaim,
                ElementNFTActivated, IsPlayerJoined, StarShopItemType, PlayerTrait
            }
        },
        constants::{
            START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, ACCOUNT_LEVEL_RANGE, INVITATION_LEVEL_RANGE,
            account_exp_to_account_level, invitation_exp_to_invitation_level
        },
        errors::{Error, assert_with_err, panic_by_err},
        events::{
            FreeDragonClaimed, StarShopItemBought, PlayerStoneUpdate, PlayerDragarkStoneUpdate,
            PoolShareRewardClaimed, PlayerContributionPointChange, ResourcesPackBought
        },
        utils::general::{
            _is_playable, _require_valid_time, _require_valid_claim_time, _require_world_owner,
            total_contribution_point_to_dragark_stone_pool
        }
    };

    // Local imports
    use super::IPlayerSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FreeDragonClaimed: FreeDragonClaimed,
        StarShopItemBought: StarShopItemBought,
        PlayerStoneUpdate: PlayerStoneUpdate,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate,
        PoolShareRewardClaimed: PoolShareRewardClaimed,
        PlayerContributionPointChange: PlayerContributionPointChange,
        ResourcesPackBought: ResourcesPackBought
    }

    // Impls
    #[abi(embed_v0)]
    impl IPlayerSystemImpl of IPlayerSystem<ContractState> {
        // See IPlayerSystem-buy_energy
        fn buy_energy(ref world: IWorldDispatcher, pack: u8) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let mut player = get!(world, (caller, player_global.map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let map_id = player_global.map_id;
            let map = get!(world, (map_id), MapInfo);
            let cur_timestamp = get_block_timestamp();

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

            // Check pack number
            assert_with_err(pack == 1 || pack == 2, Error::INVALID_PACK_NUMBER, Option::None);

            // Check energy
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            assert_with_err(
                daily_timestamp == player.energy_reset_time,
                Error::NOT_OUT_OF_ENERGY_YET,
                Option::None
            );
            assert_with_err(player.energy == 0, Error::NOT_OUT_OF_ENERGY_YET, Option::None);

            // Buy energy
            PlayerTrait::buy_energy(ref player, world, pack, cur_timestamp);

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

        // See IPlayerSystem-upgrade_account_level
        fn upgrade_account_level(ref world: IWorldDispatcher) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let player_stone_cap_before = player.stone_cap;
            let cur_block_timestamp = get_block_timestamp();

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

            // Check the player level
            let player_account_level = player.account_level;
            let (min_account_level, max_account_level) = ACCOUNT_LEVEL_RANGE;
            assert_with_err(
                player_account_level >= min_account_level
                    && player_account_level < max_account_level,
                Error::INVALID_ACCOUNT_LEVEL,
                Option::None
            );

            // Check the player has enough exp to upgrade
            let player_account_exp = player.account_exp;
            let account_level_from_account_exp = account_exp_to_account_level(player_account_exp);
            assert_with_err(
                player_account_level < account_level_from_account_exp,
                Error::NOT_ENOUGH_ACCOUNT_EXP,
                Option::None
            );

            // Upgrade account level
            let free_dragons_claimed = PlayerTrait::upgrade_account_level(
                ref player,
                ref player_global,
                ref map,
                world,
                account_level_from_account_exp,
                cur_block_timestamp
            );

            // Emit events
            if (!free_dragons_claimed.is_empty()) {
                let mut free_dragon_claimed_index = 0;
                let free_dragons_claimed_len = free_dragons_claimed.len();
                loop {
                    if (free_dragon_claimed_index == free_dragons_claimed_len) {
                        break;
                    }

                    let free_dragon_claimed = *free_dragons_claimed.at(free_dragon_claimed_index);
                    emit!(
                        world,
                        (Event::FreeDragonClaimed(
                            FreeDragonClaimed {
                                dragon_token_id: free_dragon_claimed.dragon_token_id,
                                owner: free_dragon_claimed.owner,
                                map_id: free_dragon_claimed.map_id,
                                model_id: free_dragon_claimed.model_id,
                                bg_id: free_dragon_claimed.bg_id,
                                rarity: free_dragon_claimed.rarity,
                                element: free_dragon_claimed.element,
                                level: free_dragon_claimed.level,
                                base_speed: free_dragon_claimed.base_speed,
                                base_attack: free_dragon_claimed.base_attack,
                                base_carrying_capacity: free_dragon_claimed.base_carrying_capacity,
                                speed: free_dragon_claimed.speed,
                                attack: free_dragon_claimed.attack,
                                carrying_capacity: free_dragon_claimed.carrying_capacity,
                                state: free_dragon_claimed.state,
                                dragon_type: free_dragon_claimed.dragon_type,
                                recovery_time: free_dragon_claimed.recovery_time
                            }
                        ))
                    );

                    free_dragon_claimed_index += 1;
                };
            }

            if (player.current_stone != player_stone_before
                || player.stone_cap != player_stone_cap_before) {
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

        // See IPlayerSystem-upgrade_invitation_level
        fn upgrade_invitation_level(ref world: IWorldDispatcher) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
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

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Check the player level
            let player_invitation_level = player.invitation_level;
            let (min_invitation_level, max_invitation_level) = INVITATION_LEVEL_RANGE;
            assert_with_err(
                player_invitation_level >= min_invitation_level
                    && player_invitation_level < max_invitation_level,
                Error::INVALID_INVITATION_LEVEL,
                Option::None
            );

            // Check the player has enough exp to upgrade
            let player_invitation_exp = player.invitation_exp;
            let invitation_level_from_invitation_exp = invitation_exp_to_invitation_level(
                player_invitation_exp
            );
            assert_with_err(
                player_invitation_level < invitation_level_from_invitation_exp,
                Error::NOT_ENOUGH_INVITATION_EXP,
                Option::None
            );

            // Upgrade invitation level
            let free_dragons_claimed = PlayerTrait::upgrade_invitation_level(
                ref player,
                ref player_global,
                ref map,
                world,
                invitation_level_from_invitation_exp,
                cur_block_timestamp
            );

            // Emit events
            if (!free_dragons_claimed.is_empty()) {
                let mut free_dragon_claimed_index = 0;
                let free_dragons_claimed_len = free_dragons_claimed.len();
                loop {
                    if (free_dragon_claimed_index == free_dragons_claimed_len) {
                        break;
                    }

                    let free_dragon_claimed = *free_dragons_claimed.at(free_dragon_claimed_index);
                    emit!(
                        world,
                        (Event::FreeDragonClaimed(
                            FreeDragonClaimed {
                                dragon_token_id: free_dragon_claimed.dragon_token_id,
                                owner: free_dragon_claimed.owner,
                                map_id: free_dragon_claimed.map_id,
                                model_id: free_dragon_claimed.model_id,
                                bg_id: free_dragon_claimed.bg_id,
                                rarity: free_dragon_claimed.rarity,
                                element: free_dragon_claimed.element,
                                level: free_dragon_claimed.level,
                                base_speed: free_dragon_claimed.base_speed,
                                base_attack: free_dragon_claimed.base_attack,
                                base_carrying_capacity: free_dragon_claimed.base_carrying_capacity,
                                speed: free_dragon_claimed.speed,
                                attack: free_dragon_claimed.attack,
                                carrying_capacity: free_dragon_claimed.carrying_capacity,
                                state: free_dragon_claimed.state,
                                dragon_type: free_dragon_claimed.dragon_type,
                                recovery_time: free_dragon_claimed.recovery_time
                            }
                        ))
                    );

                    free_dragon_claimed_index += 1;
                };
            }

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

        // See IPlayerSystem-redeem_invite_code
        fn redeem_invite_code(ref world: IWorldDispatcher, invite_code: felt252) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let map = get!(world, (map_id), MapInfo);
            let player = get!(world, (caller, map_id), Player);

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

            // Check if the invite code is valid
            let player_invite_code_addr = get!(world, (invite_code), PlayerInviteCode).player;
            let mut player_invite_code_global = get!(
                world, (player_invite_code_addr), PlayerGlobal
            );
            let mut player_invite_code = get!(
                world, (player_invite_code_addr, player_invite_code_global.map_id), Player
            );
            assert_with_err(
                player_invite_code_addr.is_non_zero()
                    && player_invite_code_global.invite_code == invite_code
                    && player_invite_code_addr != caller,
                Error::INVALID_INVITE_CODE,
                Option::None
            );

            // Check if the player has redeemed invite code
            assert_with_err(
                player_global.ref_code.is_zero(), Error::ALREADY_REDEEMED_INVITE_CODE, Option::None
            );

            // Redeem invite code
            PlayerTrait::redeem_invite_code(
                ref player_global,
                ref player_invite_code_global,
                ref player_invite_code,
                world,
                invite_code
            );
        }

        // See IPlayerSystem-update_account_level_reward
        fn update_account_level_reward(
            ref world: IWorldDispatcher,
            level: u8,
            stone_reward: u128,
            dragark_stone_reward: u128,
            free_dragark_reward: u8
        ) {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            // Update account level reward
            PlayerTrait::update_account_level_reward(
                world, level, stone_reward, dragark_stone_reward, free_dragark_reward
            );
        }

        // See IPlayerSystem-update_invitation_level_reward
        fn update_invitation_level_reward(
            ref world: IWorldDispatcher,
            level: u8,
            stone_reward: u128,
            dragark_stone_reward: u128,
            free_dragark_reward: u8
        ) {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            // Update invitation level reward
            PlayerTrait::update_invitation_level_reward(
                world, level, stone_reward, dragark_stone_reward, free_dragark_reward
            );
        }

        fn set(ref world: IWorldDispatcher, addr: ContractAddress) {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            let mut player_global = get!(world, (addr), PlayerGlobal);
            let mut player = get!(world, (addr, player_global.map_id), Player);

            // player.account_level = 1;
            player.account_exp = 5000;

            // player.invitation_level = 1;
            player.invitation_exp = 440;

            player_global.star = 100000000;
            player_global
                .element_nft_activated =
                    ElementNFTActivated { dark: true, flame: true, water: true, lightning: true };

            set!(world, (player));
            set!(world, (player_global));
        }

        // See IPlayerSystem-buy_item_star_shop
        fn buy_item_star_shop(ref world: IWorldDispatcher, item_type: StarShopItemType) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
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

            // Verify input
            assert_with_err(
                item_type == StarShopItemType::NonNFTDragonNormal
                    || item_type == StarShopItemType::NonNFTDragon1
                    || item_type == StarShopItemType::NonNFTDragon2
                    || item_type == StarShopItemType::NonNFTDragon3
                    || item_type == StarShopItemType::ShieldType1
                    || item_type == StarShopItemType::ShieldType2
                    || item_type == StarShopItemType::ShieldType3
                    || item_type == StarShopItemType::ShieldType4,
                Error::INVALID_TREASURE_HUNT_TYPE,
                Option::None
            );

            // Buy item star shop
            let (dragon_claimed, item_bought_num, star_bought) = PlayerTrait::buy_item_star_shop(
                ref player, ref player_global, ref map, world, item_type, cur_timestamp
            );

            // Emit events
            if (item_type == StarShopItemType::NonNFTDragonNormal
                || item_type == StarShopItemType::NonNFTDragon1
                || item_type == StarShopItemType::NonNFTDragon2
                || item_type == StarShopItemType::NonNFTDragon3) {
                emit!(
                    world,
                    (Event::FreeDragonClaimed(
                        FreeDragonClaimed {
                            dragon_token_id: dragon_claimed.dragon_token_id,
                            owner: dragon_claimed.owner,
                            map_id: dragon_claimed.map_id,
                            model_id: dragon_claimed.model_id,
                            bg_id: dragon_claimed.bg_id,
                            rarity: dragon_claimed.rarity,
                            element: dragon_claimed.element,
                            level: dragon_claimed.level,
                            base_speed: dragon_claimed.base_speed,
                            base_attack: dragon_claimed.base_attack,
                            base_carrying_capacity: dragon_claimed.base_carrying_capacity,
                            speed: dragon_claimed.speed,
                            attack: dragon_claimed.attack,
                            carrying_capacity: dragon_claimed.carrying_capacity,
                            state: dragon_claimed.state,
                            dragon_type: dragon_claimed.dragon_type,
                            recovery_time: dragon_claimed.recovery_time
                        }
                    ))
                );
            }

            emit!(
                world,
                (Event::StarShopItemBought(
                    StarShopItemBought {
                        map_id,
                        player: caller,
                        item_type,
                        item_bought_num,
                        star_bought,
                        star_left: player_global.star
                    }
                ))
            );
        }

        // See IPlayerSystem-buy_resources_pack
        fn buy_resources_pack(
            ref world: IWorldDispatcher, nonce: felt252, signature_r: felt252, signature_s: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_contract_address = get_contract_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let cur_block_timestamp = get_block_timestamp();

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

            // Check nonce used
            let mut nonce_used = get!(world, (nonce), NonceUsed);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

            // Buy resources pack
            let dragons_claimed = PlayerTrait::buy_resources_pack(
                ref player,
                ref player_global,
                ref map,
                ref nonce_used,
                world,
                signature_r,
                signature_s,
                player_contract_address,
                cur_block_timestamp
            );

            // Emit events
            if (!dragons_claimed.is_empty()) {
                let mut dragon_claimed_index = 0;
                let dragons_claimed_len = dragons_claimed.len();
                loop {
                    if (dragon_claimed_index == dragons_claimed_len) {
                        break;
                    }

                    let dragon_claimed = *dragons_claimed.at(dragon_claimed_index);
                    emit!(
                        world,
                        (Event::FreeDragonClaimed(
                            FreeDragonClaimed {
                                dragon_token_id: dragon_claimed.dragon_token_id,
                                owner: dragon_claimed.owner,
                                map_id: dragon_claimed.map_id,
                                model_id: dragon_claimed.model_id,
                                bg_id: dragon_claimed.bg_id,
                                rarity: dragon_claimed.rarity,
                                element: dragon_claimed.element,
                                level: dragon_claimed.level,
                                base_speed: dragon_claimed.base_speed,
                                base_attack: dragon_claimed.base_attack,
                                base_carrying_capacity: dragon_claimed.base_carrying_capacity,
                                speed: dragon_claimed.speed,
                                attack: dragon_claimed.attack,
                                carrying_capacity: dragon_claimed.carrying_capacity,
                                state: dragon_claimed.state,
                                dragon_type: dragon_claimed.dragon_type,
                                recovery_time: dragon_claimed.recovery_time
                            }
                        ))
                    );

                    dragon_claimed_index += 1;
                };
            }

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

            emit!(
                world,
                (Event::PlayerDragarkStoneUpdate(
                    PlayerDragarkStoneUpdate {
                        map_id, player: caller, dragark_stone_balance: player.dragark_stone_balance
                    }
                ))
            );

            emit!(
                world,
                (Event::ResourcesPackBought(
                    ResourcesPackBought { map_id, player: caller, bought_time: cur_block_timestamp }
                ))
            );
        }

        // See IPlayerSystem-activate_element_nft
        fn activate_element_nft(
            ref world: IWorldDispatcher,
            element_nft_type: felt252,
            map_id: usize,
            nonce: felt252,
            signature_r: felt252,
            signature_s: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_contract_address = get_contract_address();
            let mut map = get!(world, (map_id), MapInfo);
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check if the player has already activated this Element NFT type
            if (element_nft_type == 0) {
                assert_with_err(
                    !player_global.element_nft_activated.dark,
                    Error::ELEMENT_NFT_TYPE_ALREADY_ACTIVATED,
                    Option::None
                );
            } else if (element_nft_type == 1) {
                assert_with_err(
                    !player_global.element_nft_activated.flame,
                    Error::ELEMENT_NFT_TYPE_ALREADY_ACTIVATED,
                    Option::None
                );
            } else if (element_nft_type == 2) {
                assert_with_err(
                    !player_global.element_nft_activated.water,
                    Error::ELEMENT_NFT_TYPE_ALREADY_ACTIVATED,
                    Option::None
                );
            } else if (element_nft_type == 3) {
                assert_with_err(
                    !player_global.element_nft_activated.lightning,
                    Error::ELEMENT_NFT_TYPE_ALREADY_ACTIVATED,
                    Option::None
                );
            } else {
                panic_by_err(Error::INVALID_ELEMENT_NFT_TYPE, Option::None);
            }

            // Check nonce used
            let mut nonce_used = get!(world, (nonce), NonceUsed);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

            // Activate Element NFT
            let is_contribution_points_updated = PlayerTrait::activate_element_nft(
                ref player_global,
                ref map,
                ref nonce_used,
                world,
                element_nft_type,
                signature_r,
                signature_s,
                player_contract_address
            );

            // Emit events
            if (is_contribution_points_updated) {
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
        }

        // See IPlayerSystem-claim_pool_share_reward
        fn claim_pool_share_reward(
            ref world: IWorldDispatcher,
            pool: u16,
            dragark_stone_earn: u128,
            nonce: felt252,
            signature_r: felt252,
            signature_s: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            // Check claim time
            _require_valid_claim_time();

            let caller = get_caller_address();
            let player_contract_address = get_contract_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
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

            // Check player account level
            assert_with_err(player.account_level >= 10, Error::ACCOUNT_LEVEL_NOT_MET, Option::None);

            // Verify time
            let pool_share_info = get!(world, (pool, 1), PoolShareInfo);
            assert_with_err(
                cur_block_timestamp >= pool_share_info.start_time
                    && cur_block_timestamp <= pool_share_info.end_time,
                Error::INVALID_TIME,
                Option::None
            );

            // Check pool share reward claims
            let mut player_pool_share_claim = get!(
                world, (caller, map_id, pool), PlayerPoolShareClaim
            );
            assert_with_err(
                !player_pool_share_claim.is_claimed,
                Error::ALREADY_CLAIMED_POOL_SHARE_REWARD,
                Option::None
            );

            // Check nonce used
            let mut nonce_used = get!(world, (nonce), NonceUsed);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

            // Claim pool share reward
            PlayerTrait::claim_pool_share_reward(
                ref player,
                ref map,
                ref player_pool_share_claim,
                ref nonce_used,
                world,
                pool,
                dragark_stone_earn,
                signature_r,
                signature_s,
                player_contract_address
            );

            // Emit events
            emit!(
                world,
                (Event::PoolShareRewardClaimed(
                    PoolShareRewardClaimed {
                        map_id, player: caller, dragark_stone_earn, claim_time: cur_block_timestamp
                    }
                ))
            );

            emit!(
                world,
                (Event::PlayerDragarkStoneUpdate(
                    PlayerDragarkStoneUpdate {
                        map_id, player: caller, dragark_stone_balance: player.dragark_stone_balance
                    }
                ))
            );
        }

        // See IPlayerSystem-update_pool_share_info
        fn update_pool_share_info(
            ref world: IWorldDispatcher,
            pool: u16,
            milestone: u16,
            start_time: u64,
            end_time: u64,
            total_cp: u64,
            dragark_stone_pool: u128
        ) {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            // Update Pool Share info
            PlayerTrait::update_pool_share_info(
                world, pool, milestone, start_time, end_time, total_cp, dragark_stone_pool
            );
        }
    }
}
