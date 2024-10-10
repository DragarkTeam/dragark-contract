// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{player::{Player, IsPlayerJoined}, position::{Position}, scout_info::{IsScouted},},
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_scout() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let destination = Position { x: 12, y: 12 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let scout_id = systems.actions.scout(world, context.map_id, destination);

    // [Assert] Player
    let player_a = store.player(context.player_a_address, context.map_id);
    assert_eq!(player_a.area_opened, 10);
    assert_eq!(player_a.energy, 8999990);

    // [Assert] ScoutInfo
    let scout_info = store.scout_info(context.map_id, scout_id, context.player_a_address);
    assert_eq!(scout_info.destination, destination);
    assert_eq!(scout_info.time, timestamp);

    // [Assert] PlayerScoutInfo
    let player_a_scout_info = store
        .player_scout_info(context.map_id, context.player_a_address, destination.x, destination.y);
    assert_eq!(player_a_scout_info.is_scouted, IsScouted::Scouted);
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let destination = Position { x: 12, y: 12 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.scout(world, context.map_id + 1, destination);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let destination = Position { x: 12, y: 12 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    set_contract_address(context.owner_address);
    let another_map_id = systems.actions.init_new_map(world);
    set_contract_address(context.player_a_address);
    systems.actions.scout(world, another_map_id, destination);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let destination = Position { x: 12, y: 12 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let mut player_a = store.player(context.player_a_address, context.map_id);
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    store.set_player(player_a);

    systems.actions.scout(world, context.map_id, destination);
}
