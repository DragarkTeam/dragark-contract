// Starknet imports
use starknet::{get_block_timestamp, testing::{set_block_timestamp, set_contract_address}};

// Dojo imports
use dojo::{world::WorldStorageTrait, model::{ModelStorage, ModelStorageTest}};

// Internal imports
use dragark::{
    models::{
        dragon::{Dragon, DragonState}, island::{Island, Resource},
        journey::{Journey, AttackType, AttackResult, JourneyStatus}, map_info::MapInfo,
        mission::MissionTracking, player_dragon_owned::PlayerDragonOwned,
        player_island_owned::PlayerIslandOwned, player_island_slot::PlayerIslandSlot,
        player::{Player, IsPlayerJoined}, shield::{Shield, ShieldType}
    },
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, PLAYER_A, PLAYER_B, spawn_dragark},
    constants::START_JOURNEY_MISSION_ID
};

#[test]
fn test_start_journey_capturing_user_island() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_island: Island = world.read_model((map_id, player_a_island_id));

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_island: Island = world.read_model((map_id, player_b_island_id));
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;
    let player_b_mission_tracking: MissionTracking = world
        .read_model((PLAYER_B(), map_id, START_JOURNEY_MISSION_ID));

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );

    // [Assert] Island
    let player_b_island_after: Island = world.read_model((map_id, player_b_island_id));
    assert_eq!(
        player_b_island_after.cur_resources.food + resources.food,
        player_b_island.cur_resources.food
    );

    // [Assert] Dragon
    let player_b_dragon: Dragon = world.read_model(player_b_dragon_token_id);
    assert_eq!(player_b_dragon.state, DragonState::Flying);

    // [Assert] Map
    let map: MapInfo = world.read_model(map_id);
    assert_eq!(map.total_journey, 1);
    assert_eq!(map.total_start_journey, 1);

    // [Assert] MissionTracking
    let player_b_mission_tracking_after: MissionTracking = world
        .read_model((PLAYER_B(), map_id, START_JOURNEY_MISSION_ID));
    assert_eq!(
        player_b_mission_tracking.current_value + 1, player_b_mission_tracking_after.current_value
    );

    // [Assert] Journey
    let journey: Journey = world.read_model((map_id, journey_id));
    assert_eq!(journey.owner, PLAYER_B());
    assert_eq!(journey.dragon_token_id, player_b_dragon_token_id);
    assert_eq!(journey.carrying_resources, resources);
    assert_eq!(journey.island_from_id, player_b_island_id);
    assert_eq!(journey.island_from_position, player_b_island.position);
    assert_eq!(journey.island_from_owner, PLAYER_B());
    assert_eq!(journey.island_to_id, player_a_island_id);
    assert_eq!(journey.island_to_position, player_a_island.position);
    assert_eq!(journey.island_to_owner, PLAYER_A());
    assert_eq!(journey.start_time, timestamp);
    assert_eq!(journey.attack_type, AttackType::Unknown);
    assert_eq!(journey.attack_result, AttackResult::Unknown);
    assert_eq!(journey.status, JourneyStatus::Started);
}

#[test]
fn test_finish_journey_capturing_user_island() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);

    actions_system.finish_journey(map_id, journey_id);

    // [Assert] Dragon
    let player_b_dragon: Dragon = world.read_model(player_b_dragon_token_id);
    assert_eq!(player_b_dragon.state, DragonState::Idling);

    // [Assert] Journey
    let journey: Journey = world.read_model((map_id, journey_id));
    assert_eq!(journey.attack_type, AttackType::PlayerIslandAttack);
    assert_eq!(journey.status, JourneyStatus::Finished);

    // [Assert] Map
    let map: MapInfo = world.read_model(map_id);
    assert_eq!(map.total_finish_journey, 1);
}

#[test]
fn test_start_journey_capturing_derelict_island() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_island: Island = world.read_model((map_id, player_a_island_id));
    let player_a_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_A(), 0));
    let player_a_dragon_token_id = player_a_dragon_owned.dragon_token_id;

    let map_info: MapInfo = world.read_model(map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot: PlayerIslandSlot = world.read_model((map_id, cur_block_id));
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();
    let derelict_island: Island = world.read_model((map_id, derelict_island_id));
    let player_a_mission_tracking: MissionTracking = world
        .read_model((PLAYER_A(), map_id, START_JOURNEY_MISSION_ID));

    let journey_id = actions_system
        .start_journey(
            map_id, player_a_dragon_token_id, player_a_island_id, derelict_island_id, resources
        );

    // [Assert] Island
    let player_a_island_after: Island = world.read_model((map_id, player_a_island_id));
    assert_eq!(
        player_a_island_after.cur_resources.food + resources.food,
        player_a_island.cur_resources.food
    );

    // [Assert] Dragon
    let player_a_dragon: Dragon = world.read_model(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Flying);

    // [Assert] Map
    let map: MapInfo = world.read_model(map_id);
    assert_eq!(map.total_journey, 1);
    assert_eq!(map.total_start_journey, 1);

    // [Assert] MissionTracking
    let player_a_mission_tracking_after: MissionTracking = world
        .read_model((PLAYER_A(), map_id, START_JOURNEY_MISSION_ID));
    assert_eq!(
        player_a_mission_tracking.current_value + 1, player_a_mission_tracking_after.current_value
    );

    // [Assert] Journey
    let journey: Journey = world.read_model((map_id, journey_id));
    assert_eq!(journey.owner, PLAYER_A());
    assert_eq!(journey.dragon_token_id, player_a_dragon_token_id);
    assert_eq!(journey.carrying_resources, resources);
    assert_eq!(journey.island_from_id, player_a_island_id);
    assert_eq!(journey.island_from_position, player_a_island.position);
    assert_eq!(journey.island_from_owner, PLAYER_A());
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
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_A(), 0));
    let player_a_dragon_token_id = player_a_dragon_owned.dragon_token_id;

    let map_info: MapInfo = world.read_model(map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot: PlayerIslandSlot = world.read_model((map_id, cur_block_id));
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();

    let journey_id = actions_system
        .start_journey(
            map_id, player_a_dragon_token_id, player_a_island_id, derelict_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);

    actions_system.finish_journey(map_id, journey_id);

    // [Assert] Dragon
    let player_a_dragon: Dragon = world.read_model(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Idling);

    // [Assert] Journey
    let journey: Journey = world.read_model((map_id, journey_id));
    assert_eq!(journey.attack_type, AttackType::DerelictIslandAttack);
    assert_eq!(journey.status, JourneyStatus::Finished);

    // [Assert] Map
    let map: MapInfo = world.read_model(map_id);
    assert_eq!(map.total_finish_journey, 1);
}

#[test]
fn test_start_journey_transport_resources() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_A(), 0));
    let player_a_dragon_token_id = player_a_dragon_owned.dragon_token_id;

    let map_info: MapInfo = world.read_model(map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot: PlayerIslandSlot = world.read_model((map_id, cur_block_id));
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();
    let mut derelict_island: Island = world.read_model((map_id, derelict_island_id));
    derelict_island.cur_resources = Resource { food: 0 };
    world.write_model_test(@derelict_island);

    let journey_id = actions_system
        .start_journey(
            map_id, player_a_dragon_token_id, player_a_island_id, derelict_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    let new_timestamp = journey.finish_time;
    set_block_timestamp(new_timestamp);
    actions_system.finish_journey(map_id, journey_id);

    let player_a_fisrt_island: Island = world.read_model((map_id, player_a_island_id));
    let player_a_second_island: Island = world.read_model((map_id, derelict_island_id));
    let player_a_mission_tracking: MissionTracking = world
        .read_model((PLAYER_A(), map_id, START_JOURNEY_MISSION_ID));

    let journey_id = actions_system
        .start_journey(
            map_id, player_a_dragon_token_id, player_a_island_id, derelict_island_id, resources
        );

    // [Assert] Island
    let player_a_fisrt_island_after: Island = world.read_model((map_id, player_a_island_id));
    assert_eq!(
        player_a_fisrt_island_after.cur_resources.food + resources.food,
        player_a_fisrt_island.cur_resources.food
    );
    // [Assert] Dragon
    let player_a_dragon: Dragon = world.read_model(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Flying);

    // [Assert] Map
    let map: MapInfo = world.read_model(map_id);
    assert_eq!(map.total_journey, 2);
    assert_eq!(map.total_start_journey, 2);

    // [Assert] MissionTracking
    let player_a_mission_tracking_after: MissionTracking = world
        .read_model((PLAYER_A(), map_id, START_JOURNEY_MISSION_ID));
    assert_eq!(
        player_a_mission_tracking.current_value + 1, player_a_mission_tracking_after.current_value
    );

    // [Assert] Journey
    let journey: Journey = world.read_model((map_id, journey_id));
    assert_eq!(journey.owner, PLAYER_A());
    assert_eq!(journey.dragon_token_id, player_a_dragon_token_id);
    assert_eq!(journey.carrying_resources, resources);
    assert_eq!(journey.island_from_id, player_a_island_id);
    assert_eq!(journey.island_from_position, player_a_fisrt_island.position);
    assert_eq!(journey.island_from_owner, PLAYER_A());
    assert_eq!(journey.island_to_id, derelict_island_id);
    assert_eq!(journey.island_to_position, player_a_second_island.position);
    assert_eq!(journey.island_to_owner, PLAYER_A());
    assert_eq!(journey.start_time, new_timestamp);
    assert_eq!(journey.attack_type, AttackType::Unknown);
    assert_eq!(journey.attack_result, AttackResult::Unknown);
    assert_eq!(journey.status, JourneyStatus::Started);
}

#[test]
fn test_finish_journey_transport_resources() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_A(), 0));
    let player_a_dragon_token_id = player_a_dragon_owned.dragon_token_id;

    let map_info: MapInfo = world.read_model(map_id);
    let cur_block_coordinates = map_info.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot: PlayerIslandSlot = world.read_model((map_id, cur_block_id));
    let derelict_island_id = player_island_slot.island_ids.pop_front().unwrap();
    let mut derelict_island: Island = world.read_model((map_id, derelict_island_id));
    derelict_island.cur_resources = Resource { food: 0 };
    world.write_model_test(@derelict_island);

    let journey_id = actions_system
        .start_journey(
            map_id, player_a_dragon_token_id, player_a_island_id, derelict_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    let new_timestamp = journey.finish_time;
    set_block_timestamp(new_timestamp);
    actions_system.finish_journey(map_id, journey_id);

    let player_a_second_island: Island = world.read_model((map_id, derelict_island_id));

    let journey_id = actions_system
        .start_journey(
            map_id, player_a_dragon_token_id, player_a_island_id, derelict_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);
    actions_system.finish_journey(map_id, journey_id);

    // [Assert] Island
    let player_a_second_island_after: Island = world.read_model((map_id, derelict_island_id));
    assert_eq!(
        player_a_second_island_after.cur_resources.food,
        player_a_second_island.cur_resources.food + resources.food
    );

    // [Assert] Dragon
    let player_a_dragon: Dragon = world.read_model(player_a_dragon_token_id);
    assert_eq!(player_a_dragon.state, DragonState::Idling);

    // [Assert] Journey
    let journey: Journey = world.read_model((map_id, journey_id));
    assert_eq!(journey.attack_type, AttackType::None);
    assert_eq!(journey.attack_result, AttackResult::None);
    assert_eq!(journey.status, JourneyStatus::Finished);

    // [Assert] Map
    let map: MapInfo = world.read_model(map_id);
    assert_eq!(map.total_finish_journey, 2);
}

#[test]
fn test_finish_journey_to_protected_island() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let mut player_a_island: Island = world.read_model((map_id, player_a_island_id));
    player_a_island.cur_resources = Resource { food: 0 };
    world.write_model_test(@player_a_island);
    let shield: Shield = Shield {
        player: PLAYER_A(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_a_island_id, ShieldType::Type1);

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);
    actions_system.finish_journey(map_id, journey_id);

    // [Assert] Dragon
    let player_b_dragon: Dragon = world.read_model(player_b_dragon_token_id);
    assert_eq!(player_b_dragon.state, DragonState::Idling);

    // [Assert] Journey
    let journey_after: Journey = world.read_model((map_id, journey_id));
    assert_eq!(journey_after.attack_type, AttackType::PlayerIslandAttack);
    assert_eq!(journey_after.attack_result, AttackResult::Lose);
    assert_eq!(journey_after.status, JourneyStatus::Finished);

    // [Assert] Map
    let map: MapInfo = world.read_model(map_id);
    assert_eq!(map.total_finish_journey, 1);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_map_not_initialized() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    actions_system
        .start_journey(
            map_id + 1, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_wrong_map() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let init_timestamp = get_block_timestamp();
    set_block_timestamp(init_timestamp + 1);
    let another_map_id = actions_system.init_new_map();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;
    set_contract_address(PLAYER_B());

    actions_system
        .start_journey(
            another_map_id,
            player_b_dragon_token_id,
            player_b_island_id,
            player_a_island_id,
            resources
        );
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let mut player_b: Player = world.read_model((PLAYER_B(), map_id));
    player_b.is_joined_map = IsPlayerJoined::NotJoined;
    world.write_model_test(@player_b);

    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Dragon not exists", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_dragon_not_exists() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id + 1, player_b_island_id, player_a_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Island not exists", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_island_not_exists() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    actions_system
        .start_journey(
            map_id,
            player_b_dragon_token_id,
            player_b_island_id + 1,
            player_a_island_id + 1,
            resources
        );
}

#[test]
#[should_panic(expected: ("Island from protected", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_island_from_protected() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;
    let shield: Shield = Shield {
        player: PLAYER_B(), shield_type: ShieldType::Type1, protection_time: 3600, nums_owned: 1
    };
    world.write_model_test(@shield);
    actions_system.activate_shield(map_id, player_b_island_id, ShieldType::Type1);

    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Journey to the same island", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_transport_to_the_same_island() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_b_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Not own island", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_not_own_island() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_a_island_id, player_b_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Not own dragon", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_not_own_dragon() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 20 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;
    let player_a_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_A(), 0));
    let player_a_dragon_token_id = player_a_dragon_owned.dragon_token_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;

    actions_system
        .start_journey(
            map_id, player_a_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Dragon is not available", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_dragon_is_not_available() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Not enough food", 'ENTRYPOINT_FAILED',))]
fn test_start_journey_revert_not_enough_food() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 999999 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_map_not_initialized() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);
    actions_system.finish_journey(map_id + 1, journey_id);
}

#[test]
#[should_panic(expected: ("Journey already finished", 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_journey_already_finished() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);
    actions_system.finish_journey(map_id, journey_id);
    actions_system.finish_journey(map_id, journey_id);
}

#[test]
#[should_panic(expected: ("Wrong caller", 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_wrong_caller() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);
    set_contract_address(PLAYER_A());
    actions_system.finish_journey(map_id, journey_id);
}

#[test]
#[should_panic(expected: ("Dragon should be flying", 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_dragon_should_be_flying() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    let journey: Journey = world.read_model((map_id, journey_id));
    set_block_timestamp(journey.finish_time);

    let mut player_b_dragon: Dragon = world.read_model(player_b_dragon_token_id);
    player_b_dragon.state = DragonState::Idling;
    world.write_model_test(@player_b_dragon);

    actions_system.finish_journey(map_id, journey_id);
}

#[test]
#[should_panic(expected: ("Journey in progress", 'ENTRYPOINT_FAILED',))]
fn test_finish_journey_revert_journey_in_progress() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let resources = Resource { food: 10 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let player_a_island_id = player_a_island_owned.island_id;

    set_contract_address(PLAYER_B());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    let player_b_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_B(), 0));
    let player_b_island_id = player_b_island_owned.island_id;
    let player_b_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_B(), 0));
    let player_b_dragon_token_id = player_b_dragon_owned.dragon_token_id;

    let journey_id = actions_system
        .start_journey(
            map_id, player_b_dragon_token_id, player_b_island_id, player_a_island_id, resources
        );
    actions_system.finish_journey(map_id, journey_id);
}

