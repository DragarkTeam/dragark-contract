// Core imports
use core::Zeroable;

// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{
        dragon::{DragonState}, island::{Resource},
        journey::{AttackType, AttackResult, JourneyStatus}, player::{Player, IsPlayerJoined},
        shield::{Shield, ShieldType}
    },
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_start_journey_capturing_user_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_island = store.island(context.map_id, player_a_island_id);

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_island = store.island(context.map_id, player_b_island_id);
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );

    // [Assert] Island
    let player_b_island_after = store.island(context.map_id, player_b_island_id);
    assert_eq!(
        player_b_island_after.cur_resources.food + resources.food,
        player_b_island.cur_resources.food
    );
    assert_eq!(
        player_b_island_after.cur_resources.stone + resources.stone,
        player_b_island.cur_resources.stone
    );

    // [Assert] Dragon
    let player_b_dragon = store.dragon(player_b_dragon_token_id);
    assert_eq!(player_b_dragon.state, DragonState::Flying);

    // [Assert] Journey
    let journey = store.journey(context.map_id, journey_id);
    assert_eq!(journey.owner, context.player_b_address);
    assert_eq!(journey.dragon_token_id, player_b_dragon_token_id);
    assert_eq!(journey.carrying_resources, resources);
    assert_eq!(journey.island_from_id, player_b_island_id);
    assert_eq!(journey.island_from_position, player_b_island.position);
    assert_eq!(journey.island_from_owner, context.player_b_address);
    assert_eq!(journey.island_to_id, player_a_island_id);
    assert_eq!(journey.island_to_position, player_a_island.position);
    assert_eq!(journey.island_to_owner, context.player_a_address);
    assert_eq!(journey.start_time, timestamp);
    assert_eq!(journey.attack_type, AttackType::Unknown);
    assert_eq!(journey.attack_result, AttackResult::Unknown);
    assert_eq!(journey.status, JourneyStatus::Started);
}

#[test]
fn test_finish_journey_capturing_user_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);

    systems.actions.finish_journey(world, context.map_id, journey_id);

    // [Assert] Dragon
    let player_b_dragon = store.dragon(player_b_dragon_token_id);
    assert_eq!(player_b_dragon.state, DragonState::Idling);

    // [Assert] Journey
    let journey = store.journey(context.map_id, journey_id);
    assert_eq!(journey.attack_type, AttackType::PlayerIslandAttack);
    assert_eq!(journey.status, JourneyStatus::Finished);
}

#[test]
fn test_start_journey_capturing_derelict_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_island = store.island(context.map_id, player_a_island_id);
    let player_a_dragon_token_id = store
        .player_dragon_owned(context.player_a_address, 0)
        .dragon_token_id;

    let map_info = store.map_info(context.map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot = store.player_island_slot(context.map_id, cur_block_id);
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();
    let derelict_island = store.island(context.map_id, derelict_island_id);

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_a_dragon_token_id,
            player_a_island_id,
            derelict_island_id,
            resources
        );

    // [Assert] Island
    let player_a_island_after = store.island(context.map_id, player_a_island_id);
    assert_eq!(
        player_a_island_after.cur_resources.food + resources.food,
        player_a_island.cur_resources.food
    );
    assert_eq!(
        player_a_island_after.cur_resources.stone + resources.stone,
        player_a_island.cur_resources.stone
    );

    // [Assert] Dragon
    let player_a_dragon = store.dragon(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Flying);

    // [Assert] Journey
    let journey = store.journey(context.map_id, journey_id);
    assert_eq!(journey.owner, context.player_a_address);
    assert_eq!(journey.dragon_token_id, player_a_dragon_token_id);
    assert_eq!(journey.carrying_resources, resources);
    assert_eq!(journey.island_from_id, player_a_island_id);
    assert_eq!(journey.island_from_position, player_a_island.position);
    assert_eq!(journey.island_from_owner, context.player_a_address);
    assert_eq!(journey.island_to_id, derelict_island_id);
    assert_eq!(journey.island_to_position, derelict_island.position);
    assert_eq!(journey.island_to_owner, Zeroable::zero());
    assert_eq!(journey.start_time, timestamp);
    assert_eq!(journey.attack_type, AttackType::Unknown);
    assert_eq!(journey.attack_result, AttackResult::Unknown);
    assert_eq!(journey.status, JourneyStatus::Started);
}

#[test]
fn test_finish_journey_capturing_derelict_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_token_id = store
        .player_dragon_owned(context.player_a_address, 0)
        .dragon_token_id;

    let map_info = store.map_info(context.map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot = store.player_island_slot(context.map_id, cur_block_id);
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_a_dragon_token_id,
            player_a_island_id,
            derelict_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);

    systems.actions.finish_journey(world, context.map_id, journey_id);

    // [Assert] Dragon
    let player_a_dragon = store.dragon(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Idling);

    // [Assert] Journey
    let journey = store.journey(context.map_id, journey_id);
    assert_eq!(journey.attack_type, AttackType::DerelictIslandAttack);
    assert_eq!(journey.status, JourneyStatus::Finished);
}

#[test]
fn test_start_journey_transport_resources() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_token_id = store
        .player_dragon_owned(context.player_a_address, 0)
        .dragon_token_id;

    let map_info = store.map_info(context.map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot = store.player_island_slot(context.map_id, cur_block_id);
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();
    let mut derelict_island = store.island(context.map_id, derelict_island_id);
    derelict_island.cur_resources = Resource { food: 0, stone: 0 };
    store.set_island(derelict_island);

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_a_dragon_token_id,
            player_a_island_id,
            derelict_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    let new_timestamp = journey.finish_time;
    set_block_timestamp(new_timestamp);
    systems.actions.finish_journey(world, context.map_id, journey_id);

    let player_a_fisrt_island = store.island(context.map_id, player_a_island_id);
    let player_a_second_island = store.island(context.map_id, derelict_island_id);

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_a_dragon_token_id,
            player_a_island_id,
            derelict_island_id,
            resources
        );

    // [Assert] Island
    let player_a_fisrt_island_after = store.island(context.map_id, player_a_island_id);
    assert_eq!(
        player_a_fisrt_island_after.cur_resources.food + resources.food,
        player_a_fisrt_island.cur_resources.food
    );
    assert_eq!(
        player_a_fisrt_island_after.cur_resources.stone + resources.stone,
        player_a_fisrt_island.cur_resources.stone
    );

    // [Assert] Dragon
    let player_a_dragon = store.dragon(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Flying);

    // [Assert] Journey
    let journey = store.journey(context.map_id, journey_id);
    assert_eq!(journey.owner, context.player_a_address);
    assert_eq!(journey.dragon_token_id, player_a_dragon_token_id);
    assert_eq!(journey.carrying_resources, resources);
    assert_eq!(journey.island_from_id, player_a_island_id);
    assert_eq!(journey.island_from_position, player_a_fisrt_island.position);
    assert_eq!(journey.island_from_owner, context.player_a_address);
    assert_eq!(journey.island_to_id, derelict_island_id);
    assert_eq!(journey.island_to_position, player_a_second_island.position);
    assert_eq!(journey.island_to_owner, context.player_a_address);
    assert_eq!(journey.start_time, new_timestamp);
    assert_eq!(journey.attack_type, AttackType::Unknown);
    assert_eq!(journey.attack_result, AttackResult::Unknown);
    assert_eq!(journey.status, JourneyStatus::Started);
}

#[test]
fn test_finish_journey_transport_resources() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_token_id = store
        .player_dragon_owned(context.player_a_address, 0)
        .dragon_token_id;

    let map_info = store.map_info(context.map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot = store.player_island_slot(context.map_id, cur_block_id);
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();
    let mut derelict_island = store.island(context.map_id, derelict_island_id);
    derelict_island.cur_resources = Resource { food: 0, stone: 0 };
    store.set_island(derelict_island);

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_a_dragon_token_id,
            player_a_island_id,
            derelict_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    let new_timestamp = journey.finish_time;
    set_block_timestamp(new_timestamp);
    systems.actions.finish_journey(world, context.map_id, journey_id);

    let player_a_second_island = store.island(context.map_id, derelict_island_id);

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_a_dragon_token_id,
            player_a_island_id,
            derelict_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);
    systems.actions.finish_journey(world, context.map_id, journey_id);

    // [Assert] Island
    let player_a_second_island_after = store.island(context.map_id, derelict_island_id);
    assert_eq!(
        player_a_second_island_after.cur_resources.food,
        player_a_second_island.cur_resources.food + resources.food
    );
    assert_eq!(
        player_a_second_island_after.cur_resources.stone,
        player_a_second_island.cur_resources.stone + resources.stone
    );

    // [Assert] Dragon
    let player_a_dragon = store.dragon(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Idling);

    // [Assert] Journey
    let journey = store.journey(context.map_id, journey_id);
    assert_eq!(journey.attack_type, AttackType::None);
    assert_eq!(journey.attack_result, AttackResult::None);
    assert_eq!(journey.status, JourneyStatus::Finished);
}

#[test]
fn test_finish_journey_to_protected_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a_island = store.island(context.map_id, player_a_island_id);
    player_a_island.cur_resources = Resource { food: 0, stone: 0 };
    store.set_island(player_a_island);
    let shield: Shield = Shield {
        player: context.player_a_address,
        shield_type: ShieldType::Type1,
        protection_time: 1800,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_a_island_id, ShieldType::Type1);

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);
    systems.actions.finish_journey(world, context.map_id, journey_id);

    // [Assert] Journey
    let journey_after = store.journey(context.map_id, journey_id);
    assert_eq!(journey_after.attack_type, AttackType::PlayerIslandAttack);
    assert_eq!(journey_after.attack_result, AttackResult::Lose);
    assert_eq!(journey_after.status, JourneyStatus::Finished);
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id + 1,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    set_contract_address(context.owner_address);
    let another_map_id = systems.actions.init_new_map(world);
    set_contract_address(context.player_b_address);

    systems
        .actions
        .start_journey(
            world,
            another_map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let mut player_b = store.player(context.player_b_address, context.map_id);
    player_b.is_joined_map = IsPlayerJoined::NotJoined;
    store.set_player(player_b);

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Dragon not exists', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_dragon_not_exists() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id + 1,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Island not exists', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_island_not_exists() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id + 1,
            player_a_island_id + 1,
            resources
        );
}

#[test]
#[should_panic(expected: ('Island from protected', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_island_from_protected() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;
    let shield: Shield = Shield {
        player: context.player_b_address,
        shield_type: ShieldType::Type1,
        protection_time: 1800,
        nums_owned: 1
    };
    store.set_shield(shield);
    systems.actions.activate_shield(world, context.map_id, player_b_island_id, ShieldType::Type1);

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Transport to the same island', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_transport_to_the_same_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_b_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Not own island', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_not_own_island() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_a_island_id,
            player_b_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Not own dragon', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_not_own_dragon() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 20, stone: 2 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_token_id = store
        .player_dragon_owned(context.player_a_address, 0)
        .dragon_token_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_a_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Dragon is not available', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_dragon_is_not_available() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Not enough food', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_not_enough_food() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 999999, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Not enough stone', 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_not_enough_stone() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 9999 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ('Map not initialized', 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_map_not_initialized() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);
    systems.actions.finish_journey(world, context.map_id + 1, journey_id);
}

#[test]
#[should_panic(expected: ('Journey already finished', 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_journey_already_finished() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);
    systems.actions.finish_journey(world, context.map_id, journey_id);
    systems.actions.finish_journey(world, context.map_id, journey_id);
}

#[test]
#[should_panic(expected: ('Wrong caller', 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_wrong_caller() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);
    set_contract_address(context.player_a_address);
    systems.actions.finish_journey(world, context.map_id, journey_id);
}

#[test]
#[should_panic(expected: ('Dragon should be flying', 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_dragon_should_be_flying() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    let journey = store.journey(context.map_id, journey_id);
    set_block_timestamp(journey.finish_time);

    let mut player_b_dragon = store.dragon(player_b_dragon_token_id);
    player_b_dragon.state = DragonState::Idling;
    store.set_dragon(player_b_dragon);

    systems.actions.finish_journey(world, context.map_id, journey_id);
}

#[test]
#[should_panic(expected: ('Journey in progress', 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_journey_in_progress() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 10, stone: 1 };

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_a_island_owned = store
        .player_island_owned(context.map_id, context.player_a_address, 0);
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(context.player_b_address);
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_default_dragon(world, context.map_id);
    let player_b_island_owned = store
        .player_island_owned(context.map_id, context.player_b_address, 0);
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_token_id = store
        .player_dragon_owned(context.player_b_address, 0)
        .dragon_token_id;

    let journey_id = systems
        .actions
        .start_journey(
            world,
            context.map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
    systems.actions.finish_journey(world, context.map_id, journey_id);
}
