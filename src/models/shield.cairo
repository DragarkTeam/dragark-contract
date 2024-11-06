// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{island::Island, map::MapInfo, player::{Player, PlayerTrait}},
    errors::{Error, assert_with_err}
};

// Models
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Shield {
    #[key]
    player: ContractAddress,
    #[key]
    shield_type: ShieldType,
    protection_time: u64,
    nums_owned: u32
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum ShieldType {
    Type1,
    Type2,
    Type3,
    Type4
}

// Impls
#[generate_trait]
impl ShieldImpl of ShieldTrait {
    // Internal function to handle `activate_shield` logic
    fn activate_shield(
        ref player_shield: Shield,
        ref island: Island,
        ref map: MapInfo,
        world: IWorldDispatcher,
        cur_block_timestamp: u64
    ) {
        // Update the player's shield
        player_shield.nums_owned -= 1;

        // Update the island's shield protection time
        island.shield_protection_time = cur_block_timestamp + player_shield.protection_time;

        // Update map
        map.total_activate_shield += 1;

        // Save models
        set!(world, (player_shield));
        set!(world, (island));
        set!(world, (map));
    }

    // Internal function to handle `deactivate_shield` logic
    fn deactivate_shield(
        ref island: Island, ref map: MapInfo, world: IWorldDispatcher, cur_block_timestamp: u64
    ) {
        // Update the island's shield protection time
        island.shield_protection_time = cur_block_timestamp;

        // Update map
        map.total_deactivate_shield += 1;

        // Save models
        set!(world, (island));
        set!(world, (map));
    }

    // Internal function to handle `buy_shield` logic
    fn buy_shield(
        ref player: Player,
        world: IWorldDispatcher,
        shield_type: ShieldType,
        num: u32,
        cur_block_timestamp: u64
    ) {
        let caller = player.player;
        let num_u128: u128 = num.into();

        // According to the shield type, check the player has enough Dragark balance & update
        // it, set the protection time
        let mut protection_time: u64 = 0;
        if (shield_type == ShieldType::Type1) {
            PlayerTrait::_update_stone(ref player, cur_block_timestamp); // Fetch current stone
            assert_with_err(
                player.current_stone >= 50_000_000 * num_u128,
                Error::NOT_ENOUGH_DRAGARK_BALANCE,
                Option::None
            );
            player.current_stone -= 50_000_000 * num_u128;
            protection_time = 3600;
        } else if (shield_type == ShieldType::Type2) {
            PlayerTrait::_update_stone(ref player, cur_block_timestamp); // Fetch current stone
            assert_with_err(
                player.current_stone >= 100_000_000 * num_u128,
                Error::NOT_ENOUGH_DRAGARK_BALANCE,
                Option::None
            );
            player.current_stone -= 100_000_000 * num_u128;
            protection_time = 10800;
        } else if (shield_type == ShieldType::Type3) {
            assert_with_err(
                player.dragark_stone_balance >= 1_000_000 * num_u128,
                Error::NOT_ENOUGH_DRAGARK_BALANCE,
                Option::None
            );
            player.dragark_stone_balance -= 1_000_000 * num_u128;
            protection_time = 28800;
        } else if (shield_type == ShieldType::Type4) {
            assert_with_err(
                player.dragark_stone_balance >= 2_000_000 * num_u128,
                Error::NOT_ENOUGH_DRAGARK_BALANCE,
                Option::None
            );
            player.dragark_stone_balance -= 2_000_000 * num_u128;
            protection_time = 86400;
        }

        // Update the player's shield
        let mut player_shield = get!(world, (caller, shield_type), Shield);
        player_shield.nums_owned += num;
        player_shield.protection_time = protection_time;

        // Save models
        set!(world, (player));
        set!(world, (player_shield));
    }
}
