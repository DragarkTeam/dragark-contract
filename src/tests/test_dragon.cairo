// Starknet imports
use starknet::{get_block_timestamp, testing::{set_block_timestamp, set_contract_address}};

// Dojo imports
use dojo::{model::{ModelStorage, ModelStorageTest}, world::WorldStorageTrait};

// Internal imports
use dragark::{
    models::{
        dragon::{Dragon, DragonRarity, DragonElement, DragonState, DragonType}, map_info::MapInfo,
        player_dragon_owned::PlayerDragonOwned, player::{Player, PlayerGlobal, IsPlayerJoined}
    },
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, OWNER, PLAYER_A, spawn_dragark}
};

#[test]
fn test_claim_default_dragon() {
    // [Setup]
    let (world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);

    // [Assert] PlayerDragonOwned
    let player_a_dragon_owned: PlayerDragonOwned = world.read_model((PLAYER_A(), 0));
    assert_ne!(player_a_dragon_owned.dragon_token_id, 0);

    // [Assert] PlayerGlobal
    let player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    assert_eq!(player_a_global.num_dragons_owned, 1);

    // [Assert] Player
    let player_a: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player_a.is_claim_default_dragon, true);

    // [Assert] Dragon
    let dragon: Dragon = world.read_model(player_a_dragon_owned.dragon_token_id);
    assert_eq!(dragon.owner, PLAYER_A());
    assert_eq!(dragon.map_id, map_id);
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
    let map_info: MapInfo = world.read_model(map_id);
    assert_eq!(map_info.total_dragon, 1);
    assert_eq!(map_info.total_claim_dragon, 1);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_map_not_initialized() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id + 1);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_wrong_map() {
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
    actions_system.claim_default_dragon(another_map_id);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_player_not_joined_map() {
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
    actions_system.claim_default_dragon(map_id);
}

#[test]
#[should_panic(expected: ("Already claimed", 'ENTRYPOINT_FAILED',))]
fn test_claim_default_dragon_revert_already_claimed() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_default_dragon(map_id);
    actions_system.claim_default_dragon(map_id);
}
