// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    constants::game::{START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY},
    models::{
        dragon::{Dragon, DragonRarity, DragonElement, DragonState, DragonType}, island::Resource,
        player::{Player, PlayerGlobal}, position::Position, mission::PlayerMissionTracking
    },
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_claim_scout_mission_daily() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_mission_tracking_before = store
        .player_mission_tracking(context.player_a_address, context.map_id);
    systems
        .actions
        .scout(
            world, context.map_id, Position { x: 12, y: 12 }
        ); // We only need to scout one more time because we've scouted 9 times when joining map
    let player_before = store.player(context.player_a_address, context.map_id);
    systems.actions.claim_scout_mission_daily(world);

    // [Assert] PlayerMissionTracking
    let player_mission_tracking_after = store
        .player_mission_tracking(context.player_a_address, context.map_id);
    assert_eq!(
        player_mission_tracking_before.total_scout + 1, player_mission_tracking_after.total_scout
    );
    assert_eq!(
        player_mission_tracking_after.total_claim_scout,
        player_mission_tracking_before.total_claim_scout + 1
    );

    // [Assert] Player
    let player_after = store.player(context.player_a_address, context.map_id);
    assert_eq!(player_after.points, player_before.points + 100);
}

#[test]
#[should_panic(expected: ('Not complete mission yet', 'ENTRYPOINT_FAILED',))]
fn test_claim_scout_mission_daily_revert_not_complete_mission_yet() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_scout_mission_daily(world);
}

#[test]
#[should_panic(expected: ('Reached maximum claim time', 'ENTRYPOINT_FAILED',))]
fn test_claim_scout_mission_daily_revert_reached_maximum_claim_time() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 0 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 1 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 2 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 3 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 4 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 5 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 6 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 7 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 8 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 9 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 10 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 11 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 12 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 13 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 14 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 15 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 16 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 17 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 18 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 19 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 20 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 21 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 22 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 23 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 24 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 25 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 26 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 27 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 28 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 29 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 30 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 31 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 32 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 33 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 34 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 35 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 36 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 37 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 38 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 39 });
    systems.actions.scout(world, context.map_id, Position { x: 0, y: 40 });
    systems.actions.claim_scout_mission_daily(world);
    systems.actions.claim_scout_mission_daily(world);
    systems.actions.claim_scout_mission_daily(world);
    systems.actions.claim_scout_mission_daily(world);
}

#[test]
fn test_claim_start_journey_mission_daily() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 2, stone: 0 };

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

    let player_mission_tracking_before = store
        .player_mission_tracking(context.player_a_address, context.map_id);

    // Journey 1
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

    // Journey 2
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

    // Journey 3
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

    let player_before = store.player(context.player_a_address, context.map_id);
    systems.actions.claim_start_journey_mission_daily(world);

    // [Assert] PlayerMissionTracking
    let player_mission_tracking_after = store
        .player_mission_tracking(context.player_a_address, context.map_id);
    assert_eq!(
        player_mission_tracking_before.total_start_journey + 3,
        player_mission_tracking_after.total_start_journey
    );
    assert_eq!(
        player_mission_tracking_after.total_claim_start_journey,
        player_mission_tracking_before.total_claim_start_journey + 1
    );

    // [Assert] Player
    let player_after = store.player(context.player_a_address, context.map_id);
    assert_eq!(player_after.points, player_before.points + 100);
}

#[test]
#[should_panic(expected: ('Not complete mission yet', 'ENTRYPOINT_FAILED',))]
fn test_claim_start_journey_mission_daily_revert_not_complete_mission_yet() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_start_journey_mission_daily(world);
}

#[test]
#[should_panic(expected: ('Reached maximum claim time', 'ENTRYPOINT_FAILED',))]
fn test_claim_start_journey_mission_daily_revert_reached_maximum_claim_time() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let resources = Resource { food: 2, stone: 0 };

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

    // Journey 1
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

    // Journey 2
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

    // Journey 3
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

    // Journey 4
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

    // Journey 5
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

    // Journey 6
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

    // Journey 7
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

    // Journey 8
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

    // Journey 9
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

    // Journey 10
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

    systems.actions.claim_start_journey_mission_daily(world);
    systems.actions.claim_start_journey_mission_daily(world);
    systems.actions.claim_start_journey_mission_daily(world);
    systems.actions.claim_start_journey_mission_daily(world);
}

#[test]
fn test_claim_insert_dragon_mission_daily() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: context.player_a_address,
        map_id: context.map_id,
        root_owner: Zeroable::zero(),
        model_id: 18399416108126480420697739837366591432520176652608561,
        bg_id: 7165065848958115634,
        rarity: DragonRarity::Common,
        element: DragonElement::Darkness,
        speed: 50,
        attack: 50,
        carrying_capacity: 100,
        state: DragonState::Idling,
        dragon_type: DragonType::NFT,
        is_inserted: false,
        inserted_time: 0
    };
    store.set_dragon(dragon);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    let player_mission_tracking_before = store
        .player_mission_tracking(context.player_a_address, context.map_id);
    systems.actions.insert_dragon(world, dragon_token_id);

    let player_before = store.player(context.player_a_address, context.map_id);
    systems.actions.claim_insert_dragon_mission_daily(world);

    // [Assert] PlayerMissionTracking
    let player_mission_tracking_after = store
        .player_mission_tracking(context.player_a_address, context.map_id);
    assert_eq!(
        player_mission_tracking_before.total_insert_dragon + 1,
        player_mission_tracking_after.total_insert_dragon
    );
    assert_eq!(
        player_mission_tracking_after.total_claim_insert_dragon,
        player_mission_tracking_before.total_claim_insert_dragon + 1
    );

    // [Assert] Player
    let player_after = store.player(context.player_a_address, context.map_id);
    assert_eq!(player_after.points, player_before.points + 100);
}

#[test]
#[should_panic(expected: ('Not complete mission yet', 'ENTRYPOINT_FAILED',))]
fn test_claim_insert_dragon_mission_daily_revert_not_complete_mission_yet() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_insert_dragon_mission_daily(world);
}

#[test]
#[should_panic(expected: ('Reached maximum claim time', 'ENTRYPOINT_FAILED',))]
fn test_claim_insert_dragon_mission_daily_revert_reached_maximum_claim_time() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    let timestamp = 1725596022;
    set_block_timestamp(timestamp);
    set_contract_address(context.player_a_address);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: context.player_a_address,
        map_id: context.map_id,
        root_owner: Zeroable::zero(),
        model_id: 18399416108126480420697739837366591432520176652608561,
        bg_id: 7165065848958115634,
        rarity: DragonRarity::Common,
        element: DragonElement::Darkness,
        speed: 50,
        attack: 50,
        carrying_capacity: 100,
        state: DragonState::Idling,
        dragon_type: DragonType::NFT,
        is_inserted: false,
        inserted_time: 0
    };
    store.set_dragon(dragon);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.insert_dragon(world, dragon_token_id);
    set_block_timestamp(timestamp + 28800);
    systems.actions.claim_dragark(world, dragon_token_id);
    systems.actions.insert_dragon(world, dragon_token_id);
    set_block_timestamp(timestamp + 2 * 28800);
    systems.actions.claim_dragark(world, dragon_token_id);
    systems.actions.insert_dragon(world, dragon_token_id);

    systems.actions.claim_insert_dragon_mission_daily(world);
    systems.actions.claim_insert_dragon_mission_daily(world);
    systems.actions.claim_insert_dragon_mission_daily(world);
    systems.actions.claim_insert_dragon_mission_daily(world);
}
