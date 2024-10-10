// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{player::{Player, IsPlayerJoined}, shield::{Shield, ShieldType}},
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_activate_shield() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);

    // [Assert] Shield
    let shield_after = store.shield(context.player_a_address, ShieldType::Type1);
    assert_eq!(shield_after.nums_owned, 0);

    // [Assert] Island
    let player_a_island_after = store.island(context.map_id, player_a_island_id);
    assert_eq!(player_a_island_after.shield_protection_time, timestamp + shield.protection_time);
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems
        .actions
        .activate_shield(world, context.map_id + 1, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    set_contract_address(context.owner_address);
    let another_map_id = systems.actions.init_new_map(world);
    set_contract_address(context.player_a_address);
    systems.actions.activate_shield(world, another_map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    let mut player_a = store.player(context.player_a_address, context.map_id);
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    store.set_player(player_a);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ('Island not exists', 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_island_not_exists() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems
        .actions
        .activate_shield(world, context.map_id, player_a_island_id + 1, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ('Not own island', 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_not_own_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    let shield: Shield = Shield {
        player: context.player_b_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ('Island already protected', 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_island_already_protected() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 2
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ('Not enough shield', 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_not_enough_shield() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 0
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
fn test_deactivate_shield() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
    systems.actions.deactivate_shield(world, context.map_id, player_a_island_id);

    // [Assert] Island
    let player_a_island_after = store.island(context.map_id, player_a_island_id);
    assert_eq!(player_a_island_after.shield_protection_time, timestamp);
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
    systems.actions.deactivate_shield(world, context.map_id + 1, player_a_island_id);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
    set_contract_address(context.owner_address);
    let another_map_id = systems.actions.init_new_map(world);
    set_contract_address(context.player_a_address);
    systems.actions.deactivate_shield(world, another_map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
    let mut player_a = store.player(context.player_a_address, context.map_id);
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    store.set_player(player_a);
    systems.actions.deactivate_shield(world, context.map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ('Island not exists', 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_island_not_exists() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
    systems.actions.deactivate_shield(world, context.map_id, player_a_island_id + 1);
}

#[test]
#[should_panic(expected: ('Not own island', 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_not_own_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 3600,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);
    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    set_contract_address(context.player_a_address);
    systems.actions.deactivate_shield(world, context.map_id, player_b_island_id);
}


#[test]
#[should_panic(expected: ('Island not protected', 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_island_not_protected() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    systems.actions.deactivate_shield(world, context.map_id, player_a_island_id);
}

#[test]
fn test_buy_shield() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.buy_shield(world, ShieldType::Type1, 1);

    // [Assert] PlayerGlobal
    let player_a_global_after = store.player_global(context.player_a_address);
    assert_eq!(player_a_global_after.dragark_stone_balance, 9);

    // [Assert] Shield
    let player_shield = store.shield(context.player_a_address, ShieldType::Type1);
    assert_eq!(player_shield.nums_owned, 1);
    assert_eq!(player_shield.protection_time, 3600);
}

#[test]
#[should_panic(expected: ('Not enough dragark balance', 'ENTRYPOINT_FAILED',))]
fn test_buy_shield_revert_not_enough_dragark_balance() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.buy_shield(world, ShieldType::Type1, 1);
    systems.actions.buy_shield(world, ShieldType::Type4, 1);
}
