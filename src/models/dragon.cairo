// Core imports
use core::option::OptionTrait;
use core::{Default, Zeroable};
use core::hash::{HashStateTrait, HashStateExTrait, Hash};
use pedersen::PedersenTrait;
use ecdsa::check_ecdsa_signature;

// Starknet imports
use starknet::{ContractAddress, get_block_timestamp};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    constants::{
        ADDRESS_SIGN, PUBLIC_KEY_SIGN, STARKNET_DOMAIN_TYPE_HASH, DRAGON_INFO_STRUCT_TYPE_HASH,
        model_ids_water, model_ids_dark, model_ids_light, model_ids_fire
    },
    models::{
        achievement::{AchievementTracking, AchievementTrait}, island::Resource,
        map::{MapInfo, NonceUsed}, player::{Player, PlayerGlobal, PlayerDragonOwned, PlayerTrait}
    },
    constants::{
        UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID, UPGRADE_DRAGARK_TIME_ACHIEVEMENT_ID,
        dragon_upgrade_account_exp_bonus
    },
    errors::{Error, assert_with_err, panic_by_err}, events::DragonUpgraded
};

// Models
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Dragon {
    #[key]
    dragon_token_id: u128,
    collection: ContractAddress,
    owner: ContractAddress,
    map_id: usize,
    root_owner: ContractAddress,
    model_id: felt252,
    bg_id: felt252,
    rarity: DragonRarity,
    element: DragonElement,
    level: u8,
    base_speed: u32,
    base_attack: u32,
    base_carrying_capacity: u32,
    speed: u32,
    attack: u32,
    carrying_capacity: u32,
    state: DragonState,
    dragon_type: DragonType,
    recovery_time: u64
}

// Structs
#[derive(Copy, Drop, Serde, Hash)]
struct DragonInfo {
    dragon_token_id: felt252,
    collection: felt252,
    owner: felt252,
    map_id: felt252,
    root_owner: felt252,
    model_id: felt252,
    bg_id: felt252,
    rarity: felt252,
    element: felt252,
    level: felt252,
    speed: felt252,
    attack: felt252,
    carrying_capacity: felt252,
    nonce: felt252,
}

#[derive(Copy, Drop, Serde, PartialEq, Hash)]
struct StarknetDomain {
    name: felt252,
    version: felt252,
    chain_id: felt252,
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonRarity {
    #[default]
    None,
    Common,
    Uncommon,
    Rare,
    Epic,
    Legendary,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonElement {
    #[default]
    None,
    Fire,
    Water,
    Lightning,
    Darkness,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonState {
    #[default]
    None,
    Idling,
    Flying,
    Hunting
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonType {
    #[default]
    None,
    NFT,
    Default,
}

// Traits
trait IStructHash<T> {
    fn hash_struct(self: @T) -> felt252;
}

trait IOffchainMessageHash<T> {
    fn get_message_hash(self: @T) -> felt252;
}

// Impls
#[generate_trait]
impl DragonImpl of DragonTrait {
    // Internal function to create a new Dragon instance
    fn new() -> Dragon {
        Dragon {
            dragon_token_id: Default::default(),
            collection: Zeroable::zero(),
            owner: Zeroable::zero(),
            map_id: Default::default(),
            root_owner: Zeroable::zero(),
            model_id: Default::default(),
            bg_id: Default::default(),
            rarity: Default::default(),
            element: Default::default(),
            level: Default::default(),
            base_speed: Default::default(),
            base_attack: Default::default(),
            base_carrying_capacity: Default::default(),
            speed: Default::default(),
            attack: Default::default(),
            carrying_capacity: Default::default(),
            state: Default::default(),
            dragon_type: Default::default(),
            recovery_time: Default::default()
        }
    }

    // Internal function to handle `activate_dragon` logic
    fn activate_dragon(
        ref map: MapInfo,
        ref nonce_used: NonceUsed,
        world: IWorldDispatcher,
        dragon_info: DragonInfo,
        signature_r: felt252,
        signature_s: felt252
    ) {
        let dragon_owner: ContractAddress = dragon_info.owner.try_into().unwrap();
        let mut player_global = get!(world, (dragon_owner), PlayerGlobal);
        let map_id: usize = dragon_info.map_id.try_into().unwrap();
        let mut player = get!(world, (dragon_owner, map_id), Player);

        // Verify the signature
        let message_hash = dragon_info.get_message_hash();
        assert_with_err(
            check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
            Error::SIGNATURE_NOT_MATCH,
            Option::None
        );

        // Get rarity
        let mut rarity = DragonRarity::Common;
        if (dragon_info.rarity == 1) {
            rarity = DragonRarity::Uncommon;
        } else if (dragon_info.rarity == 2) {
            rarity = DragonRarity::Rare;
        } else if (dragon_info.rarity == 3) {
            rarity = DragonRarity::Epic;
        } else if (dragon_info.rarity == 4) {
            rarity = DragonRarity::Legendary;
        } else if (dragon_info.rarity != 0) {
            panic_by_err(Error::INVALID_CASE_DRAGON_RARITY, Option::None);
        }

        // Get element
        let mut element = DragonElement::Fire;
        if (dragon_info.element == 1) {
            element = DragonElement::Water;
        } else if (dragon_info.element == 2) {
            element = DragonElement::Lightning;
        } else if (dragon_info.element == 3) {
            element = DragonElement::Darkness;
        } else if (dragon_info.element != 0) {
            panic_by_err(Error::INVALID_CASE_DRAGON_ELEMENT, Option::None);
        }

        let level: u8 = dragon_info.level.try_into().unwrap();
        let level_u32: u32 = level.into();

        let base_speed: u32 = dragon_info.speed.try_into().unwrap();
        let base_attack: u32 = dragon_info.attack.try_into().unwrap();
        let base_carrying_capacity: u32 = dragon_info.carrying_capacity.try_into().unwrap();

        let speed = base_speed * (100 + ((level_u32 - 1) * 5)) / 100;
        let attack = base_attack * (100 + ((level_u32 - 1) * 5)) / 100;
        let carrying_capacity = base_carrying_capacity * (100 + ((level_u32 - 1) * 5)) / 100;

        let dragon = Dragon {
            dragon_token_id: dragon_info.dragon_token_id.try_into().unwrap(),
            collection: dragon_info.collection.try_into().unwrap(),
            owner: dragon_info.owner.try_into().unwrap(),
            map_id,
            root_owner: dragon_info.root_owner.try_into().unwrap(),
            model_id: dragon_info.model_id,
            bg_id: dragon_info.bg_id,
            rarity,
            element,
            level: dragon_info.level.try_into().unwrap(),
            base_speed,
            base_attack,
            base_carrying_capacity,
            speed,
            attack,
            carrying_capacity,
            state: DragonState::Idling,
            dragon_type: DragonType::NFT,
            recovery_time: 0
        };

        // Save PlayerDragonOwned model
        set!(
            world,
            (PlayerDragonOwned {
                player: dragon_owner,
                index: player_global.num_dragons_owned,
                dragon_token_id: dragon.dragon_token_id
            })
        );

        // Update data
        nonce_used.is_used = true;
        map.total_activate_dragon += 1;
        map.total_dragon += 1;
        player_global.num_dragons_owned += 1;

        // Update achievement tracking
        let mut achievement_tracking = get!(
            world,
            (dragon_owner, map.map_id, UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID),
            AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(
            ref achievement_tracking, dragon_info.level.try_into().unwrap()
        );

        // Update Contribution Point (CP)
        let total_dragark_nft_level = Self::_calculate_total_dragark_nft_level(
            world, player_global
        );
        let total_bonus_element_nft = Self::_calculate_total_bonus_element_nft(
            world, player_global
        );
        PlayerTrait::_update_contribution_points(
            ref player, ref map, total_dragark_nft_level, total_bonus_element_nft
        );

        // Save models
        set!(world, (nonce_used));
        set!(world, (dragon));
        set!(world, (map));
        set!(world, (player_global));
        set!(world, (player));
        set!(world, (achievement_tracking));
    }

    // Internal function to handle `deactivate_dragon` logic
    fn deactivate_dragon(
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        ref nonce_used: NonceUsed,
        world: IWorldDispatcher,
        dragon: Dragon,
        signature_r: felt252,
        signature_s: felt252,
    ) {
        let caller = player_global.player;
        let mut player = get!(world, (caller, map.map_id), Player);
        let dragon_token_id_u128 = dragon.dragon_token_id;
        let dragon_token_id: felt252 = dragon_token_id_u128.into();

        // Verify signature
        let message: Array<felt252> = array![
            ADDRESS_SIGN, dragon.owner.into(), dragon_token_id, nonce_used.nonce, 'DEACTIVE_DRAGON'
        ];
        let message_hash = poseidon::poseidon_hash_span(message.span());
        assert_with_err(
            check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
            Error::SIGNATURE_NOT_MATCH,
            Option::None
        );

        // Delete dragon
        delete!(world, (dragon));

        // Update player dragon owned
        let mut i: u32 = 0;
        loop {
            if (i == player_global.num_dragons_owned) {
                break;
            }
            let dragon_owned_id = get!(world, (caller, i), PlayerDragonOwned).dragon_token_id;
            if (dragon_token_id_u128 == dragon_owned_id) {
                break;
            }
            i = i + 1;
        }; // Get the dragon deactivated index

        let mut dragon_owned = get!(world, (caller, i), PlayerDragonOwned);
        if (i == (player_global.num_dragons_owned - 1)) {
            delete!(world, (dragon_owned));
        } else {
            let mut last_dragon_owned = get!(
                world, (caller, player_global.num_dragons_owned - 1), PlayerDragonOwned
            );
            dragon_owned.dragon_token_id = last_dragon_owned.dragon_token_id;

            delete!(world, (last_dragon_owned));
            set!(world, (dragon_owned));
        }

        // Update data
        nonce_used.is_used = true;
        map.total_dragon -= 1;
        map.total_deactivate_dragon += 1;
        player_global.num_dragons_owned -= 1;

        // Update Contribution Point (CP)
        let total_dragark_nft_level = Self::_calculate_total_dragark_nft_level(
            world, player_global
        );
        let total_bonus_element_nft = Self::_calculate_total_bonus_element_nft(
            world, player_global
        );
        PlayerTrait::_update_contribution_points(
            ref player, ref map, total_dragark_nft_level, total_bonus_element_nft
        );

        // Save models
        set!(world, (nonce_used));
        set!(world, (map));
        set!(world, (player_global));
        set!(world, (player));
    }

    // Internal function to handle `claim_default_dragon` logic
    fn claim_default_dragon(
        ref player: Player,
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        world: IWorldDispatcher,
        caller: ContractAddress,
        default_dragon_id: u128
    ) -> bool {
        let map_id = map.map_id;

        // Init dragon for user
        let dragon = Dragon {
            dragon_token_id: default_dragon_id,
            collection: Zeroable::zero(),
            owner: caller,
            map_id,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: DragonRarity::Common,
            element: DragonElement::Darkness,
            level: 1,
            base_speed: 50,
            base_attack: 50,
            base_carrying_capacity: 100,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            state: DragonState::Idling,
            dragon_type: DragonType::Default,
            recovery_time: 0
        };
        set!(world, (dragon));
        set!(
            world,
            (PlayerDragonOwned {
                player: caller,
                index: player_global.num_dragons_owned,
                dragon_token_id: default_dragon_id,
            })
        );

        // Update data
        map.total_claim_dragon += 1;
        map.total_dragon += 1;
        player.is_claim_default_dragon = true;
        player_global.num_dragons_owned += 1;

        // Update achievement tracking
        let mut achievement_tracking = get!(
            world, (caller, map_id, UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID), AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(
            ref achievement_tracking, dragon.level.into()
        );

        // Save data
        set!(world, (map));
        set!(world, (player));
        set!(world, (player_global));
        set!(world, (achievement_tracking));

        true
    }

    // Internal function to handle `upgrade_dragon` logic
    fn upgrade_dragon(
        ref player: Player,
        ref dragon: Dragon,
        ref map: MapInfo,
        world: IWorldDispatcher,
        stone_required: u128,
        dragark_stone_required: u128,
    ) {
        let caller = player.player;
        let player_global = get!(world, (caller), PlayerGlobal);

        // Update dragon data
        let new_dragon_level_u32: u32 = (dragon.level + 1).into();
        dragon.speed = dragon.base_speed * (100 + ((new_dragon_level_u32 - 1) * 5)) / 100;
        dragon.attack = dragon.base_attack * (100 + ((new_dragon_level_u32 - 1) * 5)) / 100;
        dragon.carrying_capacity = dragon.base_carrying_capacity
            * (100 + ((new_dragon_level_u32 - 1) * 5))
            / 100;

        dragon.level += 1;

        // Update player data
        player.current_stone -= stone_required;
        player.dragark_stone_balance -= dragark_stone_required;
        let account_exp_bonus = dragon_upgrade_account_exp_bonus(dragon.level);
        player.account_exp += account_exp_bonus;
        map.total_account_exp += account_exp_bonus;

        // Update achievement tracking

        // Level
        let mut achievement_tracking_level = get!(
            world, (caller, map.map_id, UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID), AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(
            ref achievement_tracking_level, dragon.level.into()
        );

        // Time
        let mut achievement_tracking_time = get!(
            world, (caller, map.map_id, UPGRADE_DRAGARK_TIME_ACHIEVEMENT_ID), AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(
            ref achievement_tracking_time, achievement_tracking_time.current_value + 1
        );

        // Update Contribution Point (CP)
        let total_dragark_nft_level = Self::_calculate_total_dragark_nft_level(
            world, player_global
        );
        let total_bonus_element_nft = Self::_calculate_total_bonus_element_nft(
            world, player_global
        );
        PlayerTrait::_update_contribution_points(
            ref player, ref map, total_dragark_nft_level, total_bonus_element_nft
        );

        // Save models
        set!(world, (player));
        set!(world, (dragon));
        set!(world, (map));
        set!(world, (achievement_tracking_level));
        set!(world, (achievement_tracking_time));
    }

    // Internal function to handle `_claim_free_dragon` logic
    fn _claim_free_dragon(
        world: IWorldDispatcher,
        dragon_token_id: u128,
        owner: ContractAddress,
        map_id: usize,
        dragon_type: u8
    ) -> Dragon {
        let mut base_attack = 0;
        let mut base_speed = 0;
        let mut base_carrying_capacity = 0;
        let cur_block_timestamp = get_block_timestamp();

        // Random element
        let data_element: Array<felt252> = array![
            dragon_token_id.into(),
            owner.into(),
            map_id.into(),
            'data_element',
            cur_block_timestamp.into()
        ];
        let element_index_u256: u256 = poseidon::poseidon_hash_span(data_element.span())
            .try_into()
            .unwrap();
        let element_index: u8 = (element_index_u256 % 4).try_into().unwrap();
        let mut element = DragonElement::Fire;
        if (element_index == 1) {
            element = DragonElement::Water;
        } else if (element_index == 2) {
            element = DragonElement::Lightning;
        } else if (element_index == 3) {
            element = DragonElement::Darkness;
        } else if (element_index != 0) {
            panic_by_err(Error::INVALID_CASE_DRAGON_ELEMENT, Option::None);
        }

        // Random model id
        let data_model_id: Array<felt252> = array![
            dragon_token_id.into(),
            owner.into(),
            map_id.into(),
            'data_model_id',
            cur_block_timestamp.into()
        ];
        let model_id_index_u256: u256 = poseidon::poseidon_hash_span(data_model_id.span())
            .try_into()
            .unwrap();
        let model_id_index: usize = (model_id_index_u256 % 12).try_into().unwrap();
        let mut model_id = 0;
        if (element == DragonElement::Fire) {
            model_id = *model_ids_fire().at(model_id_index);
        } else if (element == DragonElement::Water) {
            model_id = *model_ids_water().at(model_id_index);
        } else if (element == DragonElement::Lightning) {
            model_id = *model_ids_light().at(model_id_index);
        } else if (element == DragonElement::Darkness) {
            model_id = *model_ids_dark().at(model_id_index);
        }

        // Random speed
        let data_speed: Array<felt252> = array![
            dragon_token_id.into(),
            owner.into(),
            map_id.into(),
            'data_speed',
            cur_block_timestamp.into()
        ];
        let hash_ran_cur_speed: u256 = poseidon::poseidon_hash_span(data_speed.span())
            .try_into()
            .unwrap();
        let mut speed: u32 = 25 + (hash_ran_cur_speed % 26).try_into().unwrap();
        base_speed = speed;
        if (hash_ran_cur_speed % 5 == 0) {
            speed = speed * 2;
        }

        // Random attack
        let data_attack: Array<felt252> = array![
            dragon_token_id.into(),
            owner.into(),
            map_id.into(),
            'data_attack',
            cur_block_timestamp.into()
        ];
        let hash_ran_cur_attack: u256 = poseidon::poseidon_hash_span(data_attack.span())
            .try_into()
            .unwrap();
        let mut attack: u32 = 25 + (hash_ran_cur_attack % 26).try_into().unwrap();
        base_attack = attack;
        if (hash_ran_cur_attack % 5 == 0) {
            attack = attack * 2;
        }

        // Random carrying capacity
        let data_carrying_capacity: Array<felt252> = array![
            dragon_token_id.into(),
            owner.into(),
            map_id.into(),
            'data_carrying_capacity',
            cur_block_timestamp.into()
        ];
        let hash_ran_cur_carrying_capacity: u256 = poseidon::poseidon_hash_span(
            data_carrying_capacity.span()
        )
            .try_into()
            .unwrap();
        let mut carrying_capacity: u32 = 25
            + (hash_ran_cur_carrying_capacity % 26).try_into().unwrap();
        base_carrying_capacity = carrying_capacity;
        if (hash_ran_cur_carrying_capacity % 5 == 0) {
            carrying_capacity = carrying_capacity * 2;
        }

        if (dragon_type == 1) {
            if (base_speed == speed
                && base_attack == attack
                && base_carrying_capacity == carrying_capacity) {
                let data_stat_type: Array<felt252> = array![
                    dragon_token_id.into(),
                    owner.into(),
                    map_id.into(),
                    'data_stat_type',
                    dragon_type.into(),
                    cur_block_timestamp.into()
                ];
                let hash_ran_stat_type: u256 = poseidon::poseidon_hash_span(data_stat_type.span())
                    .try_into()
                    .unwrap();
                let stat_type = hash_ran_stat_type % 3;
                if (stat_type == 0) {
                    speed = speed * 2;
                } else if (stat_type == 1) {
                    attack = attack * 2;
                } else if (stat_type == 2) {
                    carrying_capacity = carrying_capacity * 2;
                }
            }
        } else if (dragon_type == 2) {
            if (base_speed == speed
                && base_attack == attack
                && base_carrying_capacity == carrying_capacity) {
                let data_stat_type: Array<felt252> = array![
                    dragon_token_id.into(),
                    owner.into(),
                    map_id.into(),
                    'data_stat_type',
                    dragon_type.into(),
                    cur_block_timestamp.into()
                ];
                let hash_ran_stat_type: u256 = poseidon::poseidon_hash_span(data_stat_type.span())
                    .try_into()
                    .unwrap();
                let stat_type = hash_ran_stat_type % 3;
                if (stat_type == 0) {
                    speed = speed * 2;
                    attack = attack * 2;
                } else if (stat_type == 1) {
                    attack = attack * 2;
                    carrying_capacity = carrying_capacity * 2;
                } else if (stat_type == 2) {
                    carrying_capacity = carrying_capacity * 2;
                    speed = speed * 2;
                }
            } else if (base_speed != speed
                && base_attack == attack
                && base_carrying_capacity == carrying_capacity) {
                let data_stat_type: Array<felt252> = array![
                    dragon_token_id.into(),
                    owner.into(),
                    map_id.into(),
                    'data_stat_type',
                    dragon_type.into(),
                    cur_block_timestamp.into()
                ];
                let hash_ran_stat_type: u256 = poseidon::poseidon_hash_span(data_stat_type.span())
                    .try_into()
                    .unwrap();
                let stat_type = hash_ran_stat_type % 2;
                if (stat_type == 0) {
                    attack = attack * 2;
                } else if (stat_type == 1) {
                    carrying_capacity = carrying_capacity * 2;
                }
            } else if (base_speed == speed
                && base_attack != attack
                && base_carrying_capacity == carrying_capacity) {
                let data_stat_type: Array<felt252> = array![
                    dragon_token_id.into(),
                    owner.into(),
                    map_id.into(),
                    'data_stat_type',
                    dragon_type.into(),
                    cur_block_timestamp.into()
                ];
                let hash_ran_stat_type: u256 = poseidon::poseidon_hash_span(data_stat_type.span())
                    .try_into()
                    .unwrap();
                let stat_type = hash_ran_stat_type % 2;
                if (stat_type == 0) {
                    speed = speed * 2;
                } else if (stat_type == 1) {
                    carrying_capacity = carrying_capacity * 2;
                }
            } else if (base_speed == speed
                && base_attack == attack
                && base_carrying_capacity != carrying_capacity) {
                let data_stat_type: Array<felt252> = array![
                    dragon_token_id.into(),
                    owner.into(),
                    map_id.into(),
                    'data_stat_type',
                    dragon_type.into(),
                    cur_block_timestamp.into()
                ];
                let hash_ran_stat_type: u256 = poseidon::poseidon_hash_span(data_stat_type.span())
                    .try_into()
                    .unwrap();
                let stat_type = hash_ran_stat_type % 2;
                if (stat_type == 0) {
                    speed = speed * 2;
                } else if (stat_type == 1) {
                    attack = attack * 2;
                }
            }
        } else if (dragon_type == 3) {
            if (base_speed == speed) {
                speed = speed * 2;
            }
            if (base_attack == attack) {
                attack = attack * 2;
            }
            if (base_carrying_capacity == carrying_capacity) {
                carrying_capacity = carrying_capacity * 2;
            }
        }

        // Update achievement tracking
        let mut achievement_tracking = get!(
            world, (owner, map_id, UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID), AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(ref achievement_tracking, 1);
        set!(world, (achievement_tracking));

        Dragon {
            dragon_token_id,
            collection: Zeroable::zero(),
            owner,
            map_id,
            root_owner: Zeroable::zero(),
            model_id,
            bg_id: 0,
            rarity: DragonRarity::Common,
            element,
            level: 1,
            base_speed: speed,
            base_attack: attack,
            base_carrying_capacity: carrying_capacity,
            speed,
            attack,
            carrying_capacity,
            state: DragonState::Idling,
            dragon_type: DragonType::Default,
            recovery_time: 0
        }
    }

    // Internal function to handle `_calculate_total_dragark_nft_level` logic
    fn _calculate_total_dragark_nft_level(
        world: IWorldDispatcher, player_global: PlayerGlobal
    ) -> u32 {
        let player = player_global.player;
        let player_num_dragons_owned = player_global.num_dragons_owned;
        let mut total_dragark_nft_level: u32 = 0;

        // Process logic
        let mut i: u32 = 0;
        loop {
            if (i == player_num_dragons_owned) {
                break;
            }

            // Get dragon token id
            let dragon_token_id = get!(world, (player, i), PlayerDragonOwned).dragon_token_id;
            let dragon = get!(world, (dragon_token_id), Dragon);

            // Add to total level if the Dragark is NFT
            if (dragon.dragon_type == DragonType::NFT) {
                total_dragark_nft_level += dragon.level.into();
            }

            // Increase index
            i += 1;
        };

        total_dragark_nft_level
    }

    // Internal function to handle `_calculate_total_bonus_element_nft` logic
    fn _calculate_total_bonus_element_nft(
        world: IWorldDispatcher, player_global: PlayerGlobal
    ) -> u16 {
        let player = player_global.player;
        let player_num_dragons_owned = player_global.num_dragons_owned;
        let player_element_nft_activated = player_global.element_nft_activated;
        let player_element_nft_activated_dark = player_element_nft_activated.dark;
        let player_element_nft_activated_flame = player_element_nft_activated.flame;
        let player_element_nft_activated_water = player_element_nft_activated.water;
        let player_element_nft_activated_lightning = player_element_nft_activated.lightning;
        let mut total_bonus_element_nft: u16 = 0;

        // Process logic
        let mut i: u32 = 0;
        loop {
            if (i == player_num_dragons_owned) {
                break;
            }

            // Get dragon token id
            let dragon_token_id = get!(world, (player, i), PlayerDragonOwned).dragon_token_id;
            let dragon = get!(world, (dragon_token_id), Dragon);

            // Check dragon level
            if (dragon.level < 10) {
                i += 1;
                continue;
            }

            // Add to total bonus if meets Element NFT activated
            if (dragon.element == DragonElement::Fire && player_element_nft_activated_flame) {
                total_bonus_element_nft += 2;
            } else if (dragon.element == DragonElement::Water
                && player_element_nft_activated_water) {
                total_bonus_element_nft += 2;
            } else if (dragon.element == DragonElement::Lightning
                && player_element_nft_activated_lightning) {
                total_bonus_element_nft += 2;
            } else if (dragon.element == DragonElement::Darkness
                && player_element_nft_activated_dark) {
                total_bonus_element_nft += 2;
            }

            // Increase index
            i += 1;
        };

        total_bonus_element_nft
    }
}

impl OffchainMessageHashDragonInfo of IOffchainMessageHash<DragonInfo> {
    fn get_message_hash(self: @DragonInfo) -> felt252 {
        let domain = StarknetDomain { name: 'Dragark', version: 1, chain_id: 'SN_MAIN' };
        let address_sign: ContractAddress = ADDRESS_SIGN.try_into().unwrap();
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with('StarkNet Message');
        hashState = hashState.update_with(domain.hash_struct());
        hashState = hashState.update_with(address_sign);
        hashState = hashState.update_with(self.hash_struct());
        hashState = hashState.update_with(4);
        hashState.finalize()
    }
}

impl StructHashStarknetDomain of IStructHash<StarknetDomain> {
    fn hash_struct(self: @StarknetDomain) -> felt252 {
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(STARKNET_DOMAIN_TYPE_HASH);
        hashState = hashState.update_with(*self);
        hashState = hashState.update_with(4);
        hashState.finalize()
    }
}

impl StructHashDragonInfo of IStructHash<DragonInfo> {
    fn hash_struct(self: @DragonInfo) -> felt252 {
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(DRAGON_INFO_STRUCT_TYPE_HASH);
        hashState = hashState.update_with(*self);
        hashState = hashState.update_with(15);
        hashState.finalize()
    }
}

// Tests
#[cfg(test)]
mod tests {
    use core::option::OptionTrait;
    use core::hash::{HashStateTrait, HashStateExTrait, Hash};
    use dragark::constants::ADDRESS_SIGN;
    use super::{STARKNET_DOMAIN_TYPE_HASH, DRAGON_INFO_STRUCT_TYPE_HASH};
    use super::{StarknetDomain, DragonInfo};
    use super::{DragonTrait, IOffchainMessageHash, IStructHash};
    use starknet::ContractAddress;
    use pedersen::PedersenTrait;

    #[test]
    fn test_struct_hash_starknet_domain() {
        // [Setup]
        let domain = StarknetDomain { name: 'Dragark', version: 1, chain_id: 'SN_MAIN' };
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(STARKNET_DOMAIN_TYPE_HASH);
        hashState = hashState.update_with(domain);
        hashState = hashState.update_with(4);
        let expected = hashState.finalize();

        // [Assert]
        assert_eq!(domain.hash_struct(), expected);
    }

    #[test]
    fn test_struct_hash_dragon_info() {
        // [Setup]
        let dragon_info = DragonInfo {
            dragon_token_id: 10000,
            collection: Zeroable::zero(),
            owner: 0x7323d4ab9247947c48c7c797d290b7b032751e897e8f7267200f8bd6e151569,
            map_id: 2181426212,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: 4,
            element: 1,
            level: 1,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            nonce: 1,
        };
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(DRAGON_INFO_STRUCT_TYPE_HASH);
        hashState = hashState.update_with(dragon_info);
        hashState = hashState.update_with(15);
        let expected = hashState.finalize();

        // [Assert]
        assert_eq!(dragon_info.hash_struct(), expected);
    }

    #[test]
    fn test_offchain_message_hash_dragon_info() {
        // [Setup]
        let domain = StarknetDomain { name: 'Dragark', version: 1, chain_id: 'SN_MAIN' };
        let dragon_info = DragonInfo {
            dragon_token_id: 10000,
            collection: Zeroable::zero(),
            owner: 0x7323d4ab9247947c48c7c797d290b7b032751e897e8f7267200f8bd6e151569,
            map_id: 2181426212,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: 4,
            element: 1,
            level: 1,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            nonce: 1,
        };
        let address_sign: ContractAddress = ADDRESS_SIGN.try_into().unwrap();
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with('StarkNet Message');
        hashState = hashState.update_with(domain.hash_struct());
        hashState = hashState.update_with(address_sign);
        hashState = hashState.update_with(dragon_info.hash_struct());
        hashState = hashState.update_with(4);
        let expected = hashState.finalize();

        // [Assert]
        assert_eq!(dragon_info.get_message_hash(), expected);
    }
}
