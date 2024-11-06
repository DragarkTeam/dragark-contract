// Core imports
use poseidon::PoseidonTrait;
use ecdsa::check_ecdsa_signature;

// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{
        achievement::{AchievementTracking, AchievementTrait}, dragon::{Dragon, DragonTrait},
        island::Island, map::{MapInfo, NonceUsed}, shield::{Shield, ShieldType}
    },
    constants::{
        ADDRESS_SIGN, PUBLIC_KEY_SIGN, START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY,
        REDEEM_INVITATION_CODE_ACHIEVEMENT_ID, REACH_ACCOUNT_LVL_ACHIEVEMENT_ID,
        island_level_to_stone_rate
    },
    errors::{Error, assert_with_err, panic_by_err}
};

// Models
#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct Player {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    is_joined_map: IsPlayerJoined,
    area_opened: u32,
    num_islands_owned: u32,
    points: u64,
    is_claim_default_dragon: bool,
    // Energy
    energy: u32,
    energy_reset_time: u64,
    energy_bought_num: u8,
    // Stone
    stone_rate: u128, // 4 decimals
    current_stone: u128, // 4 decimals
    stone_updated_time: u64,
    stone_cap: u128, // 4 decimals
    // Dragark Stone
    dragark_stone_balance: u128,
    // Account Level
    account_level: u8,
    account_exp: u64,
    account_lvl_upgrade_claims: u8,
    // Invitation Level
    invitation_level: u8,
    invitation_exp: u64,
    invitation_lvl_upgrade_claims: u8,
    // Contribution Point
    contribution_points: u64
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerGlobal {
    #[key]
    player: ContractAddress,
    map_id: usize,
    num_dragons_owned: u32,
    // Invitation
    ref_code: felt252,
    invite_code: felt252,
    total_invites: u64,
    // Star
    star: u32,
    // Element NFT activated
    element_nft_activated: ElementNFTActivated
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerDragonOwned {
    #[key]
    player: ContractAddress,
    #[key]
    index: u32,
    dragon_token_id: u128,
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerIslandOwned {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    #[key]
    index: u32,
    island_id: usize,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct PlayerInviteCode {
    #[key]
    invite_code: felt252,
    player: ContractAddress
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct AccountLevelUpgrade {
    #[key]
    level: u8,
    stone_reward: u128,
    dragark_stone_reward: u128,
    free_dragark_reward: u8
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct InvitationLevelUpgrade {
    #[key]
    level: u8,
    stone_reward: u128,
    dragark_stone_reward: u128,
    free_dragark_reward: u8
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct StarShopTracking {
    #[key]
    player: ContractAddress,
    #[key]
    item: StarShopItemType,
    item_bought_num_reset_time: u64,
    item_bought_num: u8
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct PoolShareInfo {
    #[key]
    pool: u16,
    #[key]
    milestone: u16,
    start_time: u64,
    end_time: u64,
    total_cp: u64,
    dragark_stone_pool: u128
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct PlayerPoolShareClaim {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    #[key]
    pool: u16,
    is_claimed: bool
}

// Structs
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq)]
struct ElementNFTActivated {
    dark: bool,
    flame: bool,
    water: bool,
    lightning: bool
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum IsPlayerJoined {
    #[default]
    NotJoined,
    Joined
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum StarShopItemType {
    NonNFTDragonNormal,
    NonNFTDragon1,
    NonNFTDragon2,
    NonNFTDragon3,
    ShieldType1,
    ShieldType2,
    ShieldType3,
    ShieldType4
}

// Impls
#[generate_trait]
impl PlayerImpl of PlayerTrait {
    // Internal function to handle `buy_energy` logic
    fn buy_energy(ref player: Player, world: IWorldDispatcher, pack: u8, cur_timestamp: u64) {
        // Process logic
        if (pack == 1) {
            // Fetch stone & check balance
            Self::_update_stone(ref player, cur_timestamp);
            assert_with_err(
                player.current_stone >= 100_000_000, Error::NOT_ENOUGH_STONE, Option::None
            );

            // Check bought number
            assert_with_err(
                player.energy_bought_num < 2, Error::OUT_OF_ENERGY_BOUGHT_NUM, Option::None
            );

            // Deduct stone, update bought number & update energy
            player.current_stone -= 100_000_000;
            player.energy_bought_num += 1;
            player.energy += 5;
        } else if (pack == 2) {
            // Check dragark balance
            assert_with_err(
                player.dragark_stone_balance >= 10_000_000,
                Error::NOT_ENOUGH_DRAGARK_BALANCE,
                Option::None
            );

            // Deduct dragark & update energy
            player.dragark_stone_balance -= 10_000_000;
            player.energy += 10;
        }

        // Save models
        set!(world, (player));
    }

    // Internal function to handle `upgrade_account_level` logic
    fn upgrade_account_level(
        ref player: Player,
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        world: IWorldDispatcher,
        account_level_from_account_exp: u8,
        cur_block_timestamp: u64
    ) -> Array<Dragon> {
        let caller = player.player;
        let map_id = map.map_id;
        let player_account_level = player.account_level;
        let mut free_dragons_claimed: Array<Dragon> = array![];

        // Update player account level
        player.account_level = account_level_from_account_exp;
        player.stone_cap += 1_000_000_000;

        // Fetch current stone
        Self::_update_stone(ref player, cur_block_timestamp);

        // Process claim account level upgrade logic
        let mut current_claimed_times = player.account_lvl_upgrade_claims;
        loop {
            if (current_claimed_times + 1 == player.account_level) {
                break;
            }

            // Get reward
            let account_level_upgrade = get!(
                world, (current_claimed_times + 2), AccountLevelUpgrade
            );
            let stone_reward = account_level_upgrade.stone_reward;
            let dragark_stone_reward = account_level_upgrade.dragark_stone_reward;
            let free_dragark_reward = account_level_upgrade.free_dragark_reward;

            // Update reward
            player.current_stone += stone_reward;
            player.dragark_stone_balance += dragark_stone_reward;

            // Claim free dragon
            let mut dragon_claim_index = 0;
            loop {
                if (dragon_claim_index == free_dragark_reward) {
                    break;
                }

                map.dragon_token_id_counter += 1;
                let dragon = DragonTrait::_claim_free_dragon(
                    world, map.dragon_token_id_counter, caller, map_id, 0
                );
                free_dragons_claimed.append(dragon);
                set!(world, (dragon));
                set!(
                    world,
                    (PlayerDragonOwned {
                        player: caller,
                        index: player_global.num_dragons_owned,
                        dragon_token_id: dragon.dragon_token_id
                    })
                );

                // Update data
                map.total_claim_dragon += 1;
                map.total_dragon += 1;
                player_global.num_dragons_owned += 1;

                // Increase index
                dragon_claim_index += 1;
            };

            // Increase index
            current_claimed_times += 1;
        };

        // Update claimed times
        player.account_lvl_upgrade_claims = current_claimed_times;

        // Update invitation exp if reached milestones
        if (player_global.ref_code.is_non_zero()) {
            let player_invite_code_addr = get!(world, (player_global.ref_code), PlayerInviteCode)
                .player;
            let player_ivnite_code_global = get!(world, (player_invite_code_addr), PlayerGlobal);
            let mut player_invite_code = get!(
                world, (player_invite_code_addr, player_ivnite_code_global.map_id), Player
            );

            Self::_update_invitation_exp_acc_level(
                ref player_invite_code, player_account_level, account_level_from_account_exp
            );

            set!(world, (player_invite_code));
        }

        // Update achievement tracking
        let mut achievement_tracking = get!(
            world, (caller, map.map_id, REACH_ACCOUNT_LVL_ACHIEVEMENT_ID), AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(
            ref achievement_tracking, player.account_level.into()
        );

        // Save models
        set!(world, (player));
        set!(world, (player_global));
        set!(world, (map));
        set!(world, (achievement_tracking));

        free_dragons_claimed
    }

    // Internal function to handle `upgrade_invitation_level` logic
    fn upgrade_invitation_level(
        ref player: Player,
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        world: IWorldDispatcher,
        invitation_level_from_invitation_exp: u8,
        cur_block_timestamp: u64
    ) -> Array<Dragon> {
        let caller = player.player;
        let map_id = map.map_id;
        let mut free_dragons_claimed: Array<Dragon> = array![];

        // Update player invitation level
        player.invitation_level = invitation_level_from_invitation_exp;

        // Fetch current stone
        Self::_update_stone(ref player, cur_block_timestamp);

        // Process claim invitation level upgrade logic
        let mut current_claimed_times = player.invitation_lvl_upgrade_claims;
        loop {
            if (current_claimed_times + 1 == player.invitation_level) {
                break;
            }

            // Get reward
            let invitation_level_upgrade = get!(
                world, (current_claimed_times + 2), InvitationLevelUpgrade
            );
            let stone_reward = invitation_level_upgrade.stone_reward;
            let dragark_stone_reward = invitation_level_upgrade.dragark_stone_reward;
            let free_dragark_reward = invitation_level_upgrade.free_dragark_reward;

            // Update reward
            player.current_stone += stone_reward;
            player.dragark_stone_balance += dragark_stone_reward;

            // Claim free dragon
            let mut dragon_claim_index = 0;
            loop {
                if (dragon_claim_index == free_dragark_reward) {
                    break;
                }

                map.dragon_token_id_counter += 1;
                let dragon = DragonTrait::_claim_free_dragon(
                    world, map.dragon_token_id_counter, caller, map_id, 0
                );
                free_dragons_claimed.append(dragon);
                set!(world, (dragon));
                set!(
                    world,
                    (PlayerDragonOwned {
                        player: caller,
                        index: player_global.num_dragons_owned,
                        dragon_token_id: dragon.dragon_token_id
                    })
                );

                // Update data
                map.total_claim_dragon += 1;
                map.total_dragon += 1;
                player_global.num_dragons_owned += 1;

                // Increase index
                dragon_claim_index += 1;
            };

            // Increase index
            current_claimed_times += 1;
        };

        // Update claimed times
        player.invitation_lvl_upgrade_claims = current_claimed_times;

        // Save models
        set!(world, (player));
        set!(world, (player_global));
        set!(world, (map));

        free_dragons_claimed
    }

    // Internal function to handle `redeem_invite_code` logic
    fn redeem_invite_code(
        ref player_global: PlayerGlobal,
        ref player_invite_code_global: PlayerGlobal,
        ref player_invite_code: Player,
        world: IWorldDispatcher,
        invite_code: felt252
    ) {
        // Update data
        player_invite_code_global.total_invites += 1;
        player_global.ref_code = invite_code;

        // Update invitation exp if reached milestones
        Self::_update_invitation_exp_total_invites(
            ref player_invite_code, player_invite_code_global.total_invites
        );

        // Update achievement tracking
        let mut achievement_tracking = get!(
            world,
            (player_global.player, player_global.map_id, REDEEM_INVITATION_CODE_ACHIEVEMENT_ID),
            AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(
            ref achievement_tracking, achievement_tracking.current_value + 1
        );

        // Save models
        set!(world, (player_invite_code));
        set!(world, (player_invite_code_global));
        set!(world, (player_global));
        set!(world, (achievement_tracking));
    }

    // Internal function to handle `update_account_level_reward` logic
    fn update_account_level_reward(
        world: IWorldDispatcher,
        level: u8,
        stone_reward: u128,
        dragark_stone_reward: u128,
        free_dragark_reward: u8
    ) {
        // Save models
        set!(
            world,
            AccountLevelUpgrade { level, stone_reward, dragark_stone_reward, free_dragark_reward }
        );
    }

    // Internal function to handle `update_invitation_level_reward` logic
    fn update_invitation_level_reward(
        world: IWorldDispatcher,
        level: u8,
        stone_reward: u128,
        dragark_stone_reward: u128,
        free_dragark_reward: u8
    ) {
        // Save models
        set!(
            world,
            InvitationLevelUpgrade {
                level, stone_reward, dragark_stone_reward, free_dragark_reward
            }
        );
    }

    // Internal function to handle `buy_item_star_shop` logic
    fn buy_item_star_shop(
        ref player: Player,
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        world: IWorldDispatcher,
        item_type: StarShopItemType,
        cur_timestamp: u64
    ) -> (Dragon, u8, u32) {
        let caller = player_global.player;
        let map_id = map.map_id;
        let mut dragon_claimed = DragonTrait::new();

        // Check item bought num limit
        let mut star_shop_tracking = get!(world, (caller, item_type), StarShopTracking);
        let daily_timestamp = cur_timestamp
            - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
        if (star_shop_tracking.item_bought_num_reset_time == daily_timestamp) {
            if (item_type == StarShopItemType::NonNFTDragonNormal
                || item_type == StarShopItemType::NonNFTDragon1
                || item_type == StarShopItemType::NonNFTDragon2
                || item_type == StarShopItemType::NonNFTDragon3) {
                assert_with_err(
                    star_shop_tracking.item_bought_num < 5, Error::OUT_OF_BOUGHT_NUM, Option::None
                );
            } else {
                assert_with_err(
                    star_shop_tracking.item_bought_num < 10, Error::OUT_OF_BOUGHT_NUM, Option::None
                );
            }
        } else {
            star_shop_tracking.item_bought_num_reset_time = daily_timestamp;
        }

        // Process logic
        let mut star_bought: u32 = 0;
        if (item_type == StarShopItemType::NonNFTDragonNormal) {
            assert_with_err(
                player_global.star >= 1000, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            map.dragon_token_id_counter += 1;
            let dragon = DragonTrait::_claim_free_dragon(
                world, map.dragon_token_id_counter, caller, map_id, 0
            );
            dragon_claimed = dragon;
            set!(world, (dragon));

            set!(
                world,
                (PlayerDragonOwned {
                    player: caller,
                    index: player_global.num_dragons_owned,
                    dragon_token_id: dragon.dragon_token_id
                })
            );

            // Update data
            star_bought = 1000;
            map.total_claim_dragon += 1;
            map.total_dragon += 1;
            player_global.star -= 1000;
            player_global.num_dragons_owned += 1;
        } else if (item_type == StarShopItemType::NonNFTDragon1) {
            assert_with_err(
                player_global.star >= 5000, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            map.dragon_token_id_counter += 1;
            let dragon = DragonTrait::_claim_free_dragon(
                world, map.dragon_token_id_counter, caller, map_id, 1
            );
            dragon_claimed = dragon;
            set!(world, (dragon));

            set!(
                world,
                (PlayerDragonOwned {
                    player: caller,
                    index: player_global.num_dragons_owned,
                    dragon_token_id: dragon.dragon_token_id
                })
            );

            // Update data
            star_bought = 5000;
            map.total_claim_dragon += 1;
            map.total_dragon += 1;
            player_global.star -= 5000;
            player_global.num_dragons_owned += 1;
        } else if (item_type == StarShopItemType::NonNFTDragon2) {
            assert_with_err(
                player_global.star >= 10000, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            map.dragon_token_id_counter += 1;
            let dragon = DragonTrait::_claim_free_dragon(
                world, map.dragon_token_id_counter, caller, map_id, 2
            );
            dragon_claimed = dragon;
            set!(world, (dragon));

            set!(
                world,
                (PlayerDragonOwned {
                    player: caller,
                    index: player_global.num_dragons_owned,
                    dragon_token_id: dragon.dragon_token_id
                })
            );

            // Update data
            star_bought = 10000;
            map.total_claim_dragon += 1;
            map.total_dragon += 1;
            player_global.star -= 10000;
            player_global.num_dragons_owned += 1;
        } else if (item_type == StarShopItemType::NonNFTDragon3) {
            assert_with_err(
                player_global.star >= 15000, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            map.dragon_token_id_counter += 1;
            let dragon = DragonTrait::_claim_free_dragon(
                world, map.dragon_token_id_counter, caller, map_id, 3
            );
            dragon_claimed = dragon;
            set!(world, (dragon));

            set!(
                world,
                (PlayerDragonOwned {
                    player: caller,
                    index: player_global.num_dragons_owned,
                    dragon_token_id: dragon.dragon_token_id
                })
            );

            // Update data
            star_bought = 15000;
            map.total_claim_dragon += 1;
            map.total_dragon += 1;
            player_global.star -= 15000;
            player_global.num_dragons_owned += 1;
        } else if (item_type == StarShopItemType::ShieldType1) {
            assert_with_err(
                player_global.star >= 500, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            // Update data
            star_bought = 500;
            player_global.star -= 500;

            let mut player_shield = get!(world, (caller, ShieldType::Type1), Shield);
            player_shield.nums_owned += 1;
            player_shield.protection_time = 3600;
            set!(world, (player_shield));
        } else if (item_type == StarShopItemType::ShieldType2) {
            assert_with_err(
                player_global.star >= 1000, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            // Update data
            star_bought = 1000;
            player_global.star -= 1000;

            let mut player_shield = get!(world, (caller, ShieldType::Type2), Shield);
            player_shield.nums_owned += 1;
            player_shield.protection_time = 10800;
            set!(world, (player_shield));
        } else if (item_type == StarShopItemType::ShieldType3) {
            assert_with_err(
                player_global.star >= 3000, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            // Update data
            star_bought = 3000;
            player_global.star -= 3000;

            let mut player_shield = get!(world, (caller, ShieldType::Type3), Shield);
            player_shield.nums_owned += 1;
            player_shield.protection_time = 28800;
            set!(world, (player_shield));
        } else if (item_type == StarShopItemType::ShieldType4) {
            assert_with_err(
                player_global.star >= 5000, Error::NOT_ENOUGH_STAR_BALANCE, Option::None
            );

            // Update data
            star_bought = 3000;
            player_global.star -= 3000;

            let mut player_shield = get!(world, (caller, ShieldType::Type4), Shield);
            player_shield.nums_owned += 1;
            player_shield.protection_time = 86400;
            set!(world, (player_shield));
        }

        // Update data
        star_shop_tracking.item_bought_num += 1;

        // Save models
        set!(world, (star_shop_tracking));
        set!(world, (map));
        set!(world, (player_global));
        set!(world, (player));

        (dragon_claimed, star_shop_tracking.item_bought_num, star_bought)
    }

    // Internal function to handle `buy_resources_pack` logic
    fn buy_resources_pack(
        ref player: Player,
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        ref nonce_used: NonceUsed,
        world: IWorldDispatcher,
        signature_r: felt252,
        signature_s: felt252,
        player_contract_address: ContractAddress,
        cur_block_timestamp: u64
    ) -> Array<Dragon> {
        let caller = player.player;
        let map_id = map.map_id;
        let nonce = nonce_used.nonce;
        let mut dragons_claimed: Array<Dragon> = array![];

        // Verify signature
        let message: Array<felt252> = array![
            ADDRESS_SIGN,
            player_contract_address.into(),
            map_id.into(),
            caller.into(),
            nonce,
            'BUY_RESOURCES_PACK'
        ];
        let message_hash = poseidon::poseidon_hash_span(message.span());
        assert_with_err(
            check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
            Error::SIGNATURE_NOT_MATCH,
            Option::None
        );

        // Update data
        Self::_update_stone(ref player, cur_block_timestamp); // Fetch current stone
        nonce_used.is_used = true;
        player.current_stone += 5_000_000_000;
        player.dragark_stone_balance += 100_000_000;

        // Claim dragon
        let mut dragon_claim_index = 0;
        loop {
            if (dragon_claim_index == 2) {
                break;
            }

            map.dragon_token_id_counter += 1;
            let dragon = DragonTrait::_claim_free_dragon(
                world, map.dragon_token_id_counter, caller, map_id, 3
            );
            dragons_claimed.append(dragon);
            set!(world, (dragon));
            set!(
                world,
                (PlayerDragonOwned {
                    player: caller,
                    index: player_global.num_dragons_owned,
                    dragon_token_id: dragon.dragon_token_id
                })
            );

            // Update data
            map.total_claim_dragon += 1;
            map.total_dragon += 1;
            player_global.num_dragons_owned += 1;

            // Increase index
            dragon_claim_index += 1;
        };

        // Save models
        set!(world, (player));
        set!(world, (player_global));
        set!(world, (map));
        set!(world, (nonce_used));

        dragons_claimed
    }

    // Internal function to handle `activate_element_nft` logic
    fn activate_element_nft(
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        ref nonce_used: NonceUsed,
        world: IWorldDispatcher,
        element_nft_type: felt252,
        signature_r: felt252,
        signature_s: felt252,
        player_contract_address: ContractAddress
    ) -> bool {
        let caller = player_global.player;
        let map_id = map.map_id;
        let mut player = get!(world, (caller, map_id), Player);
        let player_contribution_points_before = player.contribution_points;
        let nonce = nonce_used.nonce;

        // Verify signature
        let message: Array<felt252> = array![
            ADDRESS_SIGN,
            player_contract_address.into(),
            map_id.into(),
            caller.into(),
            element_nft_type,
            nonce,
            'ACTIVATE_ELEMENT_NFT'
        ];
        let message_hash = poseidon::poseidon_hash_span(message.span());
        assert_with_err(
            check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
            Error::SIGNATURE_NOT_MATCH,
            Option::None
        );

        // Update data
        map.total_activate_element_nft += 1;
        nonce_used.is_used = true;
        if (element_nft_type == 0) {
            player_global.element_nft_activated.dark = true;
        } else if (element_nft_type == 1) {
            player_global.element_nft_activated.flame = true;
        } else if (element_nft_type == 2) {
            player_global.element_nft_activated.water = true;
        } else if (element_nft_type == 3) {
            player_global.element_nft_activated.lightning = true;
        }

        // Update Contribution Point (CP)
        let total_dragark_nft_level = DragonTrait::_calculate_total_dragark_nft_level(
            world, player_global
        );
        let total_bonus_element_nft = DragonTrait::_calculate_total_bonus_element_nft(
            world, player_global
        );
        Self::_update_contribution_points(
            ref player, ref map, total_dragark_nft_level, total_bonus_element_nft
        );

        let mut is_contribution_points_updated: bool = false;
        if (player.contribution_points != player_contribution_points_before) {
            is_contribution_points_updated = true;
        }

        // Save models
        set!(world, (map));
        set!(world, (nonce_used));
        set!(world, (player_global));
        set!(world, (player));

        is_contribution_points_updated
    }

    // Internal function to handle `claim_pool_share_reward` logic
    fn claim_pool_share_reward(
        ref player: Player,
        ref map: MapInfo,
        ref player_pool_share_claim: PlayerPoolShareClaim,
        ref nonce_used: NonceUsed,
        world: IWorldDispatcher,
        pool: u16,
        dragark_stone_earn: u128,
        signature_r: felt252,
        signature_s: felt252,
        player_contract_address: ContractAddress
    ) {
        let caller = player.player;
        let map_id = player.map_id;
        let nonce = nonce_used.nonce;

        // Verify signature
        let message: Array<felt252> = array![
            ADDRESS_SIGN,
            player_contract_address.into(),
            map_id.into(),
            caller.into(),
            pool.into(),
            dragark_stone_earn.into(),
            nonce,
            'CLAIM_POOL_SHARE_REWARD'
        ];
        let message_hash = poseidon::poseidon_hash_span(message.span());
        assert_with_err(
            check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
            Error::SIGNATURE_NOT_MATCH,
            Option::None
        );

        // Update data
        map.total_claim_pool_share += 1;
        player_pool_share_claim.is_claimed = true;
        nonce_used.is_used = true;
        player.dragark_stone_balance += dragark_stone_earn;

        // Save models
        set!(world, (map));
        set!(world, (player_pool_share_claim));
        set!(world, (nonce_used));
        set!(world, (player));
    }

    // Internal function to handle `update_pool_share_info` logic
    fn update_pool_share_info(
        world: IWorldDispatcher,
        pool: u16,
        milestone: u16,
        start_time: u64,
        end_time: u64,
        total_cp: u64,
        dragark_stone_pool: u128
    ) {
        set!(
            world,
            (PoolShareInfo { pool, milestone, start_time, end_time, total_cp, dragark_stone_pool })
        );
    }

    // Internal function to handle `_update_stone_finish_journey` logic
    fn _update_stone_finish_journey(
        ref player: Player, island_level: u8, is_capturing: bool, cur_block_timestamp: u64
    ) {
        // Update current stone
        if (player.stone_updated_time > 0) {
            let time_passed = cur_block_timestamp - player.stone_updated_time;
            player.current_stone += player.stone_rate * time_passed.into();
            if (player.current_stone >= player.stone_cap) {
                player.current_stone = player.stone_cap;
            }
        }

        // Update stone rate
        let stone_rate = island_level_to_stone_rate(island_level);
        if (is_capturing) {
            player.stone_rate += stone_rate;
        } else {
            player.stone_rate -= stone_rate;
        }

        // Update stone updated time
        player.stone_updated_time = cur_block_timestamp;
    }

    // Internal function to handle `_update_stone` logic
    fn _update_stone(ref player: Player, cur_block_timestamp: u64) {
        // Update current stone
        if (player.stone_updated_time > 0) {
            let time_passed = cur_block_timestamp - player.stone_updated_time;
            player.current_stone += player.stone_rate * time_passed.into();
            if (player.current_stone >= player.stone_cap) {
                player.current_stone = player.stone_cap;
            }
        }

        // Update stone updated time
        player.stone_updated_time = cur_block_timestamp;
    }

    // Internal function to handle `_update_energy` logic
    fn _update_energy(ref player: Player, daily_timestamp: u64) {
        if (daily_timestamp == player.energy_reset_time) {
            assert_with_err(player.energy > 0, Error::NOT_ENOUGH_ENERGY, Option::None);
        } else if (daily_timestamp > player
            .energy_reset_time) { // A new day passed => Reset energy & timestamp
            player.energy_reset_time = daily_timestamp;
            player.energy_bought_num = 0;
            player.energy = 10;
        } else {
            panic_by_err(Error::INVALID_CASE_DAILY_TIMESTAMP, Option::None);
        }
    }

    // Internal function to handle `_update_invitation_exp_total_invites` logic
    fn _update_invitation_exp_total_invites(ref player: Player, total_invites: u64) {
        if (total_invites == 1) {
            player.invitation_exp += 5;
        } else if (total_invites == 5) {
            player.invitation_exp += 10;
        } else if (total_invites == 10) {
            player.invitation_exp += 20;
        } else if (total_invites == 20) {
            player.invitation_exp += 50;
        } else if (total_invites == 50) {
            player.invitation_exp += 100;
        }
    }

    // Internal function to handle `_update_invitation_exp_acc_level` logic
    fn _update_invitation_exp_acc_level(ref player: Player, old_acc_level: u8, new_acc_level: u8) {
        if (old_acc_level < 5) {
            if (new_acc_level >= 5 && new_acc_level < 10) {
                player.invitation_exp += 10;
            } else if (new_acc_level >= 10 && new_acc_level < 15) {
                player.invitation_exp += 30;
            } else if (new_acc_level >= 15 && new_acc_level < 20) {
                player.invitation_exp += 60;
            } else if (new_acc_level == 20) {
                player.invitation_exp += 110;
            }
        } else if (old_acc_level >= 5 && old_acc_level < 10) {
            if (new_acc_level >= 10 && new_acc_level < 15) {
                player.invitation_exp += 20;
            } else if (new_acc_level >= 15 && new_acc_level < 20) {
                player.invitation_exp += 50;
            } else if (new_acc_level == 20) {
                player.invitation_level += 100;
            }
        } else if (old_acc_level >= 10 && old_acc_level < 15) {
            if (new_acc_level >= 15 && new_acc_level < 20) {
                player.invitation_exp += 30;
            } else if (new_acc_level == 20) {
                player.invitation_level += 80;
            }
        } else if (old_acc_level >= 15 && old_acc_level < 20) {
            if (new_acc_level == 20) {
                player.invitation_level += 50;
            }
        }
    }

    // Internal function to handle `_update_contribution_points` logic
    fn _update_contribution_points(
        ref player: Player,
        ref map: MapInfo,
        total_dragark_nft_level: u32,
        total_bonus_element_nft: u16
    ) {
        let old_cp = player.contribution_points;
        let player_account_exp = player.account_exp;
        let new_cp = player_account_exp
            + ((player_account_exp
                * (total_dragark_nft_level.into() + total_bonus_element_nft.into()))
                / 100);
        player.contribution_points = new_cp;
        if (new_cp >= old_cp) {
            map.total_contribution_points += new_cp - old_cp;
        } else {
            map.total_contribution_points -= old_cp - new_cp;
        }
    }
}
