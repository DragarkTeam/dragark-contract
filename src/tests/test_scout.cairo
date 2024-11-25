// Starknet imports
use starknet::{get_block_timestamp, testing::{set_block_timestamp, set_contract_address}};

// Dojo imports
use dojo::{world::WorldStorageTrait, model::{ModelStorage, ModelStorageTest}};

// Internal imports
use dragark::{
    models::{
        map_info::MapInfo, mission::MissionTracking, player::{Player, IsPlayerJoined},
        position::Position, scout_info::{ScoutInfo, PlayerScoutInfo, IsScouted}
    },
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, PLAYER_A, spawn_dragark}, constants::SCOUT_MISSION_ID
};

#[test]
fn test_scout() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let destination = Position { x: 12, y: 12 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let scout_id = actions_system.scout(map_id, destination);

    // [Assert] Player
    let player_a: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player_a.area_opened, 6);
    assert_eq!(player_a.energy, 19);

    // [Assert] ScoutInfo
    let scout_info: ScoutInfo = world.read_model((map_id, scout_id, PLAYER_A()));
    assert_eq!(scout_info.destination, destination);
    assert_eq!(scout_info.time, timestamp);

    // [Assert] PlayerScoutInfo
    let player_a_scout_info: PlayerScoutInfo = world
        .read_model((map_id, PLAYER_A(), destination.x, destination.y));
    assert_eq!(player_a_scout_info.is_scouted, IsScouted::Scouted);

    // [Assert] MissionTracking
    let mission_tracking: MissionTracking = world
        .read_model((PLAYER_A(), map_id, SCOUT_MISSION_ID));
    assert_eq!(mission_tracking.current_value, 6);

    // [Assert] Map
    let map_info: MapInfo = world.read_model(map_id);
    assert_eq!(map_info.total_scout, 6);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_map_not_initialized() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let destination = Position { x: 12, y: 12 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.scout(map_id + 1, destination);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_wrong_map() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let init_timestamp = get_block_timestamp();
    set_block_timestamp(init_timestamp + 1);
    let another_map_id = actions_system.init_new_map();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let destination = Position { x: 12, y: 12 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.scout(another_map_id, destination);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let destination = Position { x: 12, y: 12 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    world.write_model_test(@player_a);

    actions_system.scout(map_id, destination);
}

#[test]
#[should_panic(expected: ("Invalid position", 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_invalid_position() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let destination = Position { x: 999999, y: 999999 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.scout(map_id, destination);
}

#[test]
#[should_panic(expected: ("Destination already scouted", 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_destination_already_scouted() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let destination = Position { x: 12, y: 12 };

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.scout(map_id, destination);
    actions_system.scout(map_id, destination);
}

#[test]
#[should_panic(expected: ("Not enough energy", 'ENTRYPOINT_FAILED',))]
fn test_scout_revert_not_enough_energy() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.scout(map_id, Position { x: 12, y: 12 });
    actions_system.scout(map_id, Position { x: 12, y: 13 });
    actions_system.scout(map_id, Position { x: 12, y: 14 });
    actions_system.scout(map_id, Position { x: 12, y: 15 });
    actions_system.scout(map_id, Position { x: 12, y: 16 });
    actions_system.scout(map_id, Position { x: 12, y: 17 });
    actions_system.scout(map_id, Position { x: 12, y: 18 });
    actions_system.scout(map_id, Position { x: 12, y: 19 });
    actions_system.scout(map_id, Position { x: 12, y: 20 });
    actions_system.scout(map_id, Position { x: 12, y: 21 });
    actions_system.scout(map_id, Position { x: 12, y: 22 });
    actions_system.scout(map_id, Position { x: 12, y: 23 });
    actions_system.scout(map_id, Position { x: 12, y: 24 });
    actions_system.scout(map_id, Position { x: 12, y: 25 });
    actions_system.scout(map_id, Position { x: 12, y: 26 });
    actions_system.scout(map_id, Position { x: 12, y: 27 });
    actions_system.scout(map_id, Position { x: 12, y: 28 });
    actions_system.scout(map_id, Position { x: 12, y: 29 });
    actions_system.scout(map_id, Position { x: 12, y: 30 });
    actions_system.scout(map_id, Position { x: 12, y: 31 });
    actions_system.scout(map_id, Position { x: 12, y: 32 });
}

