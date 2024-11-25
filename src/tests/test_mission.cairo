// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::{world::WorldStorageTrait, model::{ModelStorage, ModelStorageTest}};

// Internal imports
use dragark::{
    models::{mission::{Mission, MissionTracking}, player::{Player, PlayerGlobal}},
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, PLAYER_A, PLAYER_B, spawn_dragark},
    constants::{TOTAL_TIMESTAMPS_PER_DAY, DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID}
};

#[test]
fn test_claim_mission_reward() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    let daily_timestamp = timestamp - ((timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_before: Player = world.read_model((PLAYER_A(), map_id));
    let player_a_global_before: PlayerGlobal = world.read_model(PLAYER_A());
    actions_system.claim_mission_reward();

    // [Assert] Player
    let player_a: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player_a.current_stone, player_a_before.current_stone + 1_250_000);

    // [Assert] PlayerGlobal
    let player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    assert_eq!(player_a_global.dragark_balance, player_a_global_before.dragark_balance);

    // [Assert] MissionTracking
    let daily_login_mission_tracking: MissionTracking = world
        .read_model((PLAYER_A(), map_id, DAILY_LOGIN_MISSION_ID));
    let scout_mission_tracking: MissionTracking = world
        .read_model((PLAYER_A(), map_id, SCOUT_MISSION_ID));
    assert_eq!(daily_login_mission_tracking.daily_timestamp, daily_timestamp);
    assert_eq!(daily_login_mission_tracking.current_value, 0);
    assert_eq!(daily_login_mission_tracking.claimed_times, 1);
    assert_eq!(scout_mission_tracking.daily_timestamp, daily_timestamp);
    assert_eq!(scout_mission_tracking.current_value, 5);
    assert_eq!(scout_mission_tracking.claimed_times, 1);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_claim_mission_reward_revert_map_not_initialized() {
    // [Setup]
    let (_, actions_system, _) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.claim_mission_reward();
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_claim_mission_reward_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.map_id = map_id;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.claim_mission_reward();
}

#[test]
fn test_update_mission() {
    // [Setup]
    let (world, actions_system, _) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);

    // [Act]
    actions_system
        .update_mission(
            SCOUT_MISSION_ID,
            array![5, 10, 20],
            array![250_000, 750_000, 1_000_000],
            array![0, 0, 0]
        );

    // [Assert] Mission
    let mission: Mission = world.read_model(SCOUT_MISSION_ID);
    assert_eq!(mission.targets, array![5, 10, 20]);
    assert_eq!(mission.stone_rewards, array![250_000, 750_000, 1_000_000]);
    assert_eq!(mission.dragark_stone_rewards, array![0, 0, 0]);
}

#[test]
#[should_panic(expected: ("Not world owner", 'ENTRYPOINT_FAILED',))]
fn test_update_mission_revert_not_world_owner() {
    // [Setup]
    let (_, actions_system, _) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system
        .update_mission(
            SCOUT_MISSION_ID,
            array![5, 10, 20],
            array![250_000, 750_000, 1_000_000],
            array![0, 0, 0]
        );
}

#[test]
#[should_panic(expected: ("Invalid reward", 'ENTRYPOINT_FAILED',))]
fn test_update_mission_revert_invalid_reward() {
    // [Setup]
    let (_, actions_system, _) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);

    // [Act]
    actions_system
        .update_mission(SCOUT_MISSION_ID, array![5, 10, 20], array![250_000, 750_000], array![0]);
}
