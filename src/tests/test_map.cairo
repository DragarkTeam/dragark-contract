// Core imports
use core::Zeroable;

// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{
        map_info::{IsMapInitialized}, player::{Player, IsPlayerJoined}, position::{Position},
        shield::{Shield, ShieldType}
    },
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_init_new_map() {
    // [Setup]
    let (world, _, context) = setup::spawn_game();
    let store = StoreTrait::new(world);

    // [Assert] MapInfo
    let map_info = store.map_info(context.map_id);
    assert_eq!(map_info.is_initialized, IsMapInitialized::Initialized);
    assert_eq!(map_info.total_player, 0);
    assert_eq!(map_info.total_island, 9);
    assert_eq!(map_info.total_dragon, 0);
    assert_eq!(map_info.total_scout, 0);
    assert_eq!(map_info.total_journey, 0);
    assert_eq!(map_info.total_activate_dragon, 0);
    assert_eq!(map_info.total_deactivate_dragon, 0);
    assert_eq!(map_info.total_join_map, 0);
    assert_eq!(map_info.total_re_join_map, 0);
    assert_eq!(map_info.total_start_journey, 0);
    assert_eq!(map_info.total_finish_journey, 0);
    assert_eq!(map_info.total_claim_resources, 0);
    assert_eq!(map_info.total_claim_dragon, 0);
    assert_eq!(map_info.map_sizes, 23 * 3 * 4);
    assert_eq!(map_info.map_coordinates, Position { x: 0, y: 0 });
    assert_eq!(map_info.cur_block_coordinates, Position { x: 180, y: 180 });
    assert_eq!(map_info.block_direction_count, 0);
    assert_eq!(map_info.derelict_islands_num, 9);
    assert_eq!(map_info.cur_island_block_coordinates, Position { x: 180, y: 180 });
    assert_eq!(map_info.island_block_direction_count, 0);
    assert_eq!(map_info.dragon_token_id_counter, 99999);

    // [Assert] NextBlockDirection
    let next_block_direction = store.next_block_direction(context.map_id);
    assert_eq!(next_block_direction.right_1, 1);
    assert_eq!(next_block_direction.down_2, 1);
    assert_eq!(next_block_direction.left_3, 2);
    assert_eq!(next_block_direction.up_4, 2);
    assert_eq!(next_block_direction.right_5, 2);

    // [Assert] NextIslandBlockDirection
    let next_island_block_direction = store.next_island_block_direction(context.map_id);
    assert_eq!(next_island_block_direction.right_1, 1);
    assert_eq!(next_island_block_direction.down_2, 1);
    assert_eq!(next_island_block_direction.left_3, 2);
    assert_eq!(next_island_block_direction.up_4, 2);
    assert_eq!(next_island_block_direction.right_5, 2);
}

#[test]
#[should_panic(expected: ('Not world owner', 'ENTRYPOINT_FAILED',))]
fn test_init_new_map_revert_not_owner() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    set_contract_address(context.anyone_address);

    // [Act]
    systems.actions.init_new_map(world);
}

#[test]
fn test_join_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let map_info_before = store.map_info(context.map_id);
    let cur_block_coordinates = map_info_before.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot = store.player_island_slot(context.map_id, cur_block_id);
    let island_id = player_island_slot.island_ids.pop_front().unwrap();

    // [Act]
    systems.actions.join_map(world, context.map_id);

    // [Assert] MapInfo
    let map_info_after = store.map_info(context.map_id);
    assert_eq!(map_info_after.total_player, map_info_before.total_player + 1);
    assert_eq!(map_info_after.total_join_map, map_info_before.total_join_map + 1);
    assert_eq!(map_info_after.derelict_islands_num, map_info_before.derelict_islands_num - 1);

    // [Assert] Player
    let player = store.player(context.player_a_address, context.map_id);
    assert_eq!(player.is_joined_map, IsPlayerJoined::Joined);
    assert_eq!(player.area_opened, 9);
    assert_eq!(player.num_islands_owned, 1);

    // [Assert] PlayerGlobal
    let player_global = store.player_global(context.player_a_address);
    assert_eq!(player_global.map_id, context.map_id);

    // [Assert] PlayerIslandOwned
    let player_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    assert_eq!(player_island_owned.island_id, island_id);

    // [Assert] PlayerIslandSlot
    let player_island_slot = store.player_island_slot(context.map_id, cur_block_id);
    assert_eq!(player_island_slot.island_ids.len(), 2);

    // [Assert] Island
    let island = store.island(context.map_id, island_id);
    assert_eq!(island.owner, context.player_a_address);
    assert_eq!(island.block_id, cur_block_id);
    assert_ge!(island.level, 1);
    assert_le!(island.level, 3);
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_join_map_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id + 1);
}

#[test]
#[should_panic(expected: ('Invalid case join map', 'ENTRYPOINT_FAILED',))]
fn test_join_map_revert_invalid_case_join_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    store
        .set_player(
            Player {
                player: context.player_a_address,
                map_id: context.map_id,
                is_joined_map: IsPlayerJoined::Joined,
                area_opened: 0,
                energy: 0,
                num_islands_owned: 0,
                points: 0
            }
        );

    // [Act]
    systems.actions.join_map(world, context.map_id);
}

#[test]
#[should_panic(expected: ('Already joined in', 'ENTRYPOINT_FAILED',))]
fn test_join_map_revert_already_joined_in() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.join_map(world, context.map_id);
}

#[test]
fn test_re_join_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);

    let mut player_a = store.player(context.player_a_address, context.map_id);
    player_a.num_islands_owned = 0;
    store.set_player(player_a);

    let mut player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let island_id = player_a_island_owned.island_id;
    player_a_island_owned.island_id = 0;
    store.set_player_island_owned(player_a_island_owned);

    let mut island = store.island(context.map_id, island_id);
    island.owner = Zeroable::zero();

    systems.actions.re_join_map(world, context.map_id);

    // [Assert]
    let player_a = store.player(context.player_a_address, context.map_id);
    assert_eq!(player_a.num_islands_owned, 1);
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.re_join_map(world, context.map_id + 1);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    set_contract_address(context.owner_address);
    let another_map_id = systems.actions.init_new_map(world);
    set_contract_address(context.player_a_address);
    systems.actions.re_join_map(world, another_map_id);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let mut player_a = store.player(context.player_a_address, context.map_id);
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    store.set_player(player_a);

    systems.actions.re_join_map(world, context.map_id);
}

#[test]
#[should_panic(expected: ('Player not available for rejoin', 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_player_not_available_for_rejoin() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.re_join_map(world, context.map_id);
}

#[test]
#[should_panic(expected: ('Not own any dragon', 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_not_own_any_dragon() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);

    let mut player_a = store.player(context.player_a_address, context.map_id);
    player_a.num_islands_owned = 0;
    store.set_player(player_a);

    let mut player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let island_id = player_a_island_owned.island_id;
    player_a_island_owned.island_id = 0;
    store.set_player_island_owned(player_a_island_owned);

    let mut island = store.island(context.map_id, island_id);
    island.owner = Zeroable::zero();

    systems.actions.re_join_map(world, context.map_id);
}
