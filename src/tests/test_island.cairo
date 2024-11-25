// Starknet imports
use starknet::{get_block_timestamp, testing::{set_block_timestamp, set_contract_address}};

// Dojo imports
use dojo::{world::WorldStorageTrait, model::{ModelStorage, ModelStorageTest}};

// Internal imports
use dragark::{
    models::{
        island::{Island, Resource}, map_info::MapInfo, player_island_owned::PlayerIslandOwned,
        player::{Player, IsPlayerJoined}, position::NextIslandBlockDirection
    },
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, PLAYER_A, PLAYER_B, ANYONE, spawn_dragark}
};

#[test]
fn test_gen_island_per_block() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);

    // [Act]
    actions_system.gen_island_per_block(map_id);

    // [Assert] MapInfo
    let map_info: MapInfo = world.read_model(map_id);
    assert_eq!(map_info.total_island, 18);
    assert_eq!(map_info.derelict_islands_num, 18);

    // [Assert] NextIslandBlockDirection
    let next_island_block_direction: NextIslandBlockDirection = world.read_model(map_id);
    assert_eq!(next_island_block_direction.right_1, 0);
    assert_eq!(next_island_block_direction.down_2, 1);
    assert_eq!(next_island_block_direction.left_3, 2);
    assert_eq!(next_island_block_direction.up_4, 2);
    assert_eq!(next_island_block_direction.right_5, 2);
}

#[test]
#[should_panic(expected: ("Not world owner", 'ENTRYPOINT_FAILED',))]
fn test_gen_island_per_block_revert_not_owner() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    set_contract_address(ANYONE());

    // [Act]
    actions_system.gen_island_per_block(map_id);
}

#[test]
fn test_claim_resources() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a_island: Island = world.read_model((map_id, player_a_island_id));
    player_a_island.cur_resources = Resource { food: 0 };
    world.write_model_test(@player_a_island);
    set_block_timestamp(timestamp + player_a_island.claim_waiting_time);
    actions_system.claim_resources(map_id, player_a_island_id);

    // [Assert] Island
    let player_a_island_after: Island = world.read_model((map_id, player_a_island_id));
    assert_ge!(player_a_island_after.cur_resources.food, player_a_island.cur_resources.food);
    assert_eq!(
        player_a_island_after.last_resources_claim, timestamp + player_a_island.claim_waiting_time
    );

    // [Assert] Map
    let map_info: MapInfo = world.read_model(map_id);
    assert_eq!(map_info.total_claim_resources, 1);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_map_not_initialized() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    actions_system.claim_resources(map_id + 1, player_a_island_id);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_wrong_map() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
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
    actions_system.claim_resources(another_map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    world.write_model_test(@player_a);
    actions_system.claim_resources(map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ("Not island owner", 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_not_island_owner() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_resources(map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ("Not time to claim yet", 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_not_time_to_claim_yet() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a_island: Island = world.read_model((map_id, player_a_island_id));
    player_a_island.last_resources_claim = timestamp;
    world.write_model_test(@player_a_island);
    actions_system.claim_resources(map_id, player_a_island_id);
}
