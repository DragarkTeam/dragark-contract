// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{island::{Resource}, player::{Player, IsPlayerJoined}},
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_gen_island_per_block() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);

    // [Act]
    systems.actions.gen_island_per_block(world, context.map_id);

    // [Assert] MapInfo
    let map_info = store.map_info(context.map_id);
    assert_eq!(map_info.total_island, 18);
    assert_eq!(map_info.derelict_islands_num, 18);

    // [Assert] NextIslandBlockDirection
    let next_island_block_direction = store.next_island_block_direction(context.map_id);
    assert_eq!(next_island_block_direction.right_1, 0);
    assert_eq!(next_island_block_direction.down_2, 1);
    assert_eq!(next_island_block_direction.left_3, 2);
    assert_eq!(next_island_block_direction.up_4, 2);
    assert_eq!(next_island_block_direction.right_5, 2);
}

#[test]
#[should_panic(expected: ('Not world owner', 'ENTRYPOINT_FAILED',))]
fn test_gen_island_per_block_revert_not_owner() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    set_contract_address(context.anyone_address);

    // [Act]
    systems.actions.gen_island_per_block(world, context.map_id);
}

#[test]
fn test_claim_resources() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a_island = store.island(context.map_id, player_a_island_id);
    player_a_island.cur_resources = Resource { food: 0, stone: 0 };
    store.set_island(player_a_island);
    set_block_timestamp(timestamp + player_a_island.claim_waiting_time);
    systems.actions.claim_resources(world, context.map_id, player_a_island_id);

    // [Assert] Island
    let player_a_island_after = store.island(context.map_id, player_a_island_id);
    assert_ge!(player_a_island_after.cur_resources.food, player_a_island.cur_resources.food);
    assert_ge!(player_a_island_after.cur_resources.stone, player_a_island.cur_resources.stone);
    assert_eq!(
        player_a_island_after.last_resources_claim, timestamp + player_a_island.claim_waiting_time
    );
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    systems.actions.claim_resources(world, context.map_id + 1, player_a_island_id);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    set_contract_address(context.owner_address);
    let another_map_id = systems.actions.init_new_map(world);
    set_contract_address(context.player_a_address);
    systems.actions.claim_resources(world, another_map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a = store.player(context.player_a_address, context.map_id);
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    store.set_player(player_a);
    systems.actions.claim_resources(world, context.map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ('Not island owner', 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_not_island_owner() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    systems.actions.claim_resources(world, context.map_id, player_a_island_id);
}

#[test]
#[should_panic(expected: ('Not time to claim yet', 'ENTRYPOINT_FAILED',))]
fn test_claim_resources_revert_not_time_to_claim_yet() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a_island = store.island(context.map_id, player_a_island_id);
    player_a_island.last_resources_claim = timestamp;
    store.set_island(player_a_island);
    systems.actions.claim_resources(world, context.map_id, player_a_island_id);
}
