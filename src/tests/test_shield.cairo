// Starknet imports
use starknet::{get_block_timestamp, testing::{set_block_timestamp, set_contract_address}};

// Dojo imports
use dojo::{world::WorldStorageTrait, model::{ModelStorage, ModelStorageTest}};

// Internal imports
use dragark::{
    models::{
        island::Island, map_info::MapInfo, player_island_owned::PlayerIslandOwned,
        player::{Player, PlayerGlobal, IsPlayerJoined}, shield::{Shield, ShieldType}
    },
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, PLAYER_A, PLAYER_B, spawn_dragark}
};

#[test]
fn test_activate_shield() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);

    // [Assert] Shield
    let shield_after: Shield = world.read_model((PLAYER_A(), ShieldType::Type1));
    assert_eq!(shield_after.nums_owned, 0);

    // [Assert] Island
    let player_a_island_after: Island = world.read_model((map_id, player_a_island_id));
    assert_eq!(player_a_island_after.shield_protection_time, timestamp + shield.protection_time);

    // [Assert] Map
    let map_info: MapInfo = world.read_model(map_id);
    assert_eq!(map_info.total_activate_shield, 1);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_map_not_initialized() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id + 1, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_wrong_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let init_timestamp = get_block_timestamp();
    set_block_timestamp(init_timestamp + 1);
    let another_map_id = actions_system.init_new_map();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(another_map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    world.write_model_test(@player_a);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ("Island not exists", 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_island_not_exists() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id + 1, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ("Not own island", 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_not_own_island() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let shield: Shield = Shield {
        player: PLAYER_B(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ("Island already protected", 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_island_already_protected() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 2
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
#[should_panic(expected: ("Not enough shield", 'ENTRYPOINT_FAILED',))]
fn test_activate_shield_revert_not_enough_shield() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 0
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
}

#[test]
fn test_deactivate_shield() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
    actions_system.deactivate_shield(map_id, player_a_island_id);

    // [Assert] Island
    let player_a_island_after: Island = world.read_model((map_id, player_a_island_id));
    assert_eq!(player_a_island_after.shield_protection_time, timestamp);

    // [Assert] Map
    let map_info: MapInfo = world.read_model(map_id);
    assert_eq!(map_info.total_deactivate_shield, 1);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_map_not_initialized() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
    actions_system.deactivate_shield(map_id + 1, player_a_island_id);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_wrong_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let init_timestamp = get_block_timestamp();
    set_block_timestamp(init_timestamp + 1);
    let another_map_id = actions_system.init_new_map();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
    actions_system.deactivate_shield(another_map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    world.write_model_test(@player_a);
    actions_system.deactivate_shield(map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ("Island not exists", 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_island_not_exists() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
    actions_system.deactivate_shield(map_id, player_a_island_id + 1);
}

#[test]
#[should_panic(expected: ("Not own island", 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_not_own_island() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);
    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    set_contract_address(PLAYER_A());
    actions_system.deactivate_shield(map_id, player_b_island_id);
}

#[test]
#[should_panic(expected: ("Island not protected", 'ENTRYPOINT_FAILED',))]
fn test_deactivate_shield_revert_island_not_protected() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    actions_system.deactivate_shield(map_id, player_a_island_id);
}

#[test]
fn test_buy_shield_using_stone() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.current_stone = 1_000_000;
    world.write_model_test(@player_a);
    actions_system.buy_shield(ShieldType::Type1, 2);

    // [Assert] Player
    let player_a_after: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player_a.current_stone, player_a_after.current_stone + (500_000 * 2));

    // [Assert] Shield
    let player_shield: Shield = world.read_model((PLAYER_A(), ShieldType::Type1));
    assert_eq!(player_shield.nums_owned, 2);
    assert_eq!(player_shield.protection_time, 3600);
}

#[test]
fn test_buy_shield_using_dragark_stone() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    actions_system.buy_shield(ShieldType::Type3, 2);

    // [Assert] PlayerGlobal
    let player_a_global_after: PlayerGlobal = world.read_model(PLAYER_A());
    assert_eq!(player_a_global.dragark_balance, player_a_global_after.dragark_balance + (1 * 2));

    // [Assert] Shield
    let player_shield: Shield = world.read_model((PLAYER_A(), ShieldType::Type3));
    assert_eq!(player_shield.nums_owned, 2);
    assert_eq!(player_shield.protection_time, 28800);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_buy_shield_revert_map_not_initialized() {
    // [Setup]
    let (_, actions_system, _) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.buy_shield(ShieldType::Type1, 2);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_buy_shield_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.map_id = map_id;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.buy_shield(ShieldType::Type1, 2);
}

#[test]
#[should_panic(expected: ("Invalid num", 'ENTRYPOINT_FAILED',))]
fn test_buy_shield_revert_invalid_num() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.current_stone = 1_000_000;
    world.write_model_test(@player_a);
    actions_system.buy_shield(ShieldType::Type1, 0);
}

#[test]
#[should_panic(expected: ("Not enough dragark balance", 'ENTRYPOINT_FAILED',))]
fn test_buy_shield_revert_not_enough_dragark_balance() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.buy_shield(ShieldType::Type1, 2);
}
