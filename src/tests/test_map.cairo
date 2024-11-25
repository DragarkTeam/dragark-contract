// Starknet imports
use starknet::{get_block_timestamp, testing::{set_block_timestamp, set_contract_address}};

// Dojo imports
use dojo::{world::WorldStorageTrait, model::{ModelStorage, ModelStorageTest}};

// Internal imports
use dragark::{
    models::{
        island::Island, map_info::{MapInfo, IsMapInitialized}, mission::{Mission, MissionTracking},
        player::{Player, PlayerGlobal, IsPlayerJoined}, player_island_owned::PlayerIslandOwned,
        player_island_slot::PlayerIslandSlot,
        position::{NextBlockDirection, NextIslandBlockDirection, Position}
    },
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, PLAYER_A, ANYONE, spawn_dragark},
    constants::{
        TOTAL_TIMESTAMPS_PER_DAY, DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID, START_JOURNEY_MISSION_ID
    }
};

#[test]
fn test_init_new_map() {
    // [Setup]
    let (world, _, map_id) = spawn_dragark();

    // [Assert] MapInfo
    let map_info: MapInfo = world.read_model(map_id);
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
    assert_eq!(map_info.total_activate_shield, 0);
    assert_eq!(map_info.total_deactivate_shield, 0);
    assert_eq!(map_info.map_sizes, 23 * 3 * 4);
    assert_eq!(map_info.map_coordinates, Position { x: 0, y: 0 });
    assert_eq!(map_info.cur_block_coordinates, Position { x: 132, y: 132 });
    assert_eq!(map_info.block_direction_count, 0);
    assert_eq!(map_info.derelict_islands_num, 9);
    assert_eq!(map_info.cur_island_block_coordinates, Position { x: 132, y: 132 });
    assert_eq!(map_info.island_block_direction_count, 0);
    assert_eq!(map_info.dragon_token_id_counter, 99999);

    // [Assert] NextBlockDirection
    let next_block_direction: NextBlockDirection = world.read_model(map_id);
    assert_eq!(next_block_direction.right_1, 1);
    assert_eq!(next_block_direction.down_2, 1);
    assert_eq!(next_block_direction.left_3, 2);
    assert_eq!(next_block_direction.up_4, 2);
    assert_eq!(next_block_direction.right_5, 2);

    // [Assert] NextIslandBlockDirection
    let next_island_block_direction: NextIslandBlockDirection = world.read_model(map_id);
    assert_eq!(next_island_block_direction.right_1, 1);
    assert_eq!(next_island_block_direction.down_2, 1);
    assert_eq!(next_island_block_direction.left_3, 2);
    assert_eq!(next_island_block_direction.up_4, 2);
    assert_eq!(next_island_block_direction.right_5, 2);

    // [Assert] Mission
    let daily_login_mission: Mission = world.read_model(DAILY_LOGIN_MISSION_ID);
    let scout_mission: Mission = world.read_model(SCOUT_MISSION_ID);
    let start_journey_mission: Mission = world.read_model(START_JOURNEY_MISSION_ID);
    assert_eq!(daily_login_mission.targets, array![0]);
    assert_eq!(daily_login_mission.stone_rewards, array![1_000_000]);
    assert_eq!(daily_login_mission.dragark_stone_rewards, array![0]);
    assert_eq!(scout_mission.targets, array![5, 10, 20]);
    assert_eq!(scout_mission.stone_rewards, array![250_000, 500_000, 1_000_000]);
    assert_eq!(scout_mission.dragark_stone_rewards, array![0, 0, 0]);
    assert_eq!(start_journey_mission.targets, array![1, 3, 5]);
    assert_eq!(start_journey_mission.stone_rewards, array![250_000, 500_000, 1_000_000]);
    assert_eq!(start_journey_mission.dragark_stone_rewards, array![0, 0, 0]);
}

#[test]
#[should_panic(expected: ("Not world owner", 'ENTRYPOINT_FAILED',))]
fn test_init_new_map_revert_not_owner() {
    // [Setup]
    let (_, actions_system, _) = spawn_dragark();
    set_contract_address(ANYONE());

    // [Act]
    actions_system.init_new_map();
}

#[test]
#[should_panic(expected: ("Map already initialized", 'ENTRYPOINT_FAILED',))]
fn test_init_new_map_revert_map_already_initialized() {
    // [Setup]
    let (_, actions_system, _) = spawn_dragark();

    // [Act]
    actions_system.init_new_map();
}

#[test]
fn test_join_map() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    let daily_timestamp = timestamp - ((timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
    set_contract_address(PLAYER_A());
    let map_info_before: MapInfo = world.read_model(map_id);
    let cur_block_coordinates = map_info_before.cur_block_coordinates;
    let cur_block_id = ((cur_block_coordinates.x / 12) + 1) + (cur_block_coordinates.y / 12) * 23;
    let mut player_island_slot: PlayerIslandSlot = world.read_model((map_id, cur_block_id));
    let island_id = player_island_slot.island_ids.pop_front().unwrap();

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);

    // [Assert] MapInfo
    let map_info_after: MapInfo = world.read_model(map_id);
    assert_eq!(map_info_after.total_player, map_info_before.total_player + 1);
    assert_eq!(map_info_after.derelict_islands_num, map_info_before.derelict_islands_num - 1);
    assert_eq!(map_info_after.total_join_map, map_info_before.total_join_map + 1);
    assert_eq!(map_info_after.total_scout, map_info_before.total_scout + 5);

    // [Assert] Player
    let player: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player.is_joined_map, IsPlayerJoined::Joined);
    assert_eq!(player.area_opened, 5);
    assert_eq!(player.num_islands_owned, 1);
    assert_eq!(player.energy, 20);
    assert_eq!(player.energy_reset_time, daily_timestamp);
    assert_eq!(player.stone_cap, 50_000_000);

    // [Assert] PlayerGlobal
    let player_global: PlayerGlobal = world.read_model(PLAYER_A());
    assert_eq!(player_global.map_id, map_id);
    assert_eq!(player_global.dragark_balance, 10);

    // [Assert] PlayerIslandOwned
    let player_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    assert_eq!(player_island_owned.island_id, island_id);

    // [Assert] PlayerIslandSlot
    let player_island_slot: PlayerIslandSlot = world.read_model((map_id, cur_block_id));
    assert_eq!(player_island_slot.island_ids.len(), 2);

    // [Assert] Island
    let island: Island = world.read_model((map_id, island_id));
    assert_eq!(island.owner, PLAYER_A());
    assert_eq!(island.cur_resources.food, island.max_resources.food);
    assert_eq!(island.block_id, cur_block_id);
    assert_ge!(island.level, 1);
    assert_le!(island.level, 3);

    // [Assert] MissionTracking
    let mission_tracking: MissionTracking = world
        .read_model((PLAYER_A(), map_id, SCOUT_MISSION_ID));
    assert_eq!(mission_tracking.current_value, 5);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_join_map_revert_map_not_initialized() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id + 1, 0, 0, 0, 0, 0);
}

#[test]
#[should_panic(expected: ("Invalid case join map", 'ENTRYPOINT_FAILED',))]
fn test_join_map_revert_invalid_case_join_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.is_joined_map = IsPlayerJoined::Joined;
    world.write_model_test(@player_a);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
}

#[test]
#[should_panic(expected: ("Already joined in", 'ENTRYPOINT_FAILED',))]
fn test_join_map_revert_already_joined_in() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
}

#[test]
fn test_re_join_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);

    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.num_islands_owned = 0;
    world.write_model_test(@player_a);

    let mut player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let island_id = player_a_island_owned.island_id;
    player_a_island_owned.island_id = 0;
    world.write_model_test(@player_a_island_owned);

    let mut island: Island = world.read_model((map_id, island_id));
    island.owner = Zeroable::zero();
    world.write_model_test(@island);

    actions_system.re_join_map(map_id);

    // [Assert] Player
    let player_a: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player_a.num_islands_owned, 1);

    // [Assert] Map
    let map_info: MapInfo = world.read_model(map_id);
    assert_eq!(map_info.derelict_islands_num, 7);
    assert_eq!(map_info.total_re_join_map, 1);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_map_not_initialized() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.re_join_map(map_id + 1);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_wrong_map() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let init_timestamp = get_block_timestamp();
    set_block_timestamp(init_timestamp + 1);
    let another_map_id = actions_system.init_new_map();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.re_join_map(another_map_id);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.is_joined_map = IsPlayerJoined::NotJoined;
    world.write_model_test(@player_a);

    actions_system.re_join_map(map_id);
}

#[test]
#[should_panic(expected: ("Player not available for rejoin", 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_player_not_available_for_rejoin() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.re_join_map(map_id);
}

#[test]
#[should_panic(expected: ("Not own any dragon", 'ENTRYPOINT_FAILED',))]
fn test_re_join_map_revert_not_own_any_dragon() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);

    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.num_islands_owned = 0;
    world.write_model_test(@player_a);

    let mut player_a_island_owned: PlayerIslandOwned = world.read_model((map_id, PLAYER_A(), 0));
    let island_id = player_a_island_owned.island_id;
    player_a_island_owned.island_id = 0;
    world.write_model_test(@player_a_island_owned);

    let mut island: Island = world.read_model((map_id, island_id));
    island.owner = Zeroable::zero();
    world.write_model_test(@island);

    actions_system.re_join_map(map_id);
}

