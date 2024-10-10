// Core imports
use core::Zeroable;

// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{
        dragon::{DragonRarity, DragonElement, DragonState, DragonType},
        player::{Player, IsPlayerJoined},
    },
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_claim_default_dragon() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);

    // [Assert] PlayerDragonOwned
    let player_a_dragon = store.player_dragon_owned(context.player_a_address, 0);
    assert_ne!(player_a_dragon.dragon_token_id, 0);

    // [Assert] PlayerGlobal
    let player_a_global = store.player_global(context.player_a_address);
    assert_eq!(player_a_global.num_dragons_owned, 1);
    assert_eq!(player_a_global.is_claim_default_dragon, true);

    // [Assert] Dragon
    let dragon = store.dragon(player_a_dragon.dragon_token_id);
    assert_eq!(dragon.owner, context.player_a_address);
    assert_eq!(dragon.map_id, context.map_id);
    assert_eq!(dragon.root_owner, Zeroable::zero());
    assert_eq!(dragon.model_id, 18399416108126480420697739837366591432520176652608561);
    assert_eq!(dragon.bg_id, 7165065848958115634);
    assert_eq!(dragon.rarity, DragonRarity::Common);
    assert_eq!(dragon.element, DragonElement::Darkness);
    assert_eq!(dragon.speed, 50);
    assert_eq!(dragon.attack, 50);
    assert_eq!(dragon.carrying_capacity, 100);
    assert_eq!(dragon.state, DragonState::Idling);
    assert_eq!(dragon.dragon_type, DragonType::Default);

    // [Assert] Map
    let map_info = store.map_info(context.map_id);
    assert_eq!(map_info.total_dragon, 1);
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id + 1);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_wrong_map() {
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
    systems.actions.claim_default_dragon(world, another_map_id);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_player_not_joined_map() {
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
    systems.actions.claim_default_dragon(world, context.map_id);
}

#[test]
#[should_panic(expected: ('Already claimed', 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_already_claimed() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
}
