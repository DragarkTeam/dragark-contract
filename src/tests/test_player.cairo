// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::{world::WorldStorageTrait, model::{ModelStorage, ModelStorageTest}};

// Internal imports
use dragark::{
    models::{
        dragon::{Dragon, DragonRarity, DragonElement, DragonState, DragonType},
        player_dragon_owned::PlayerDragonOwned, player::{Player, PlayerGlobal}, position::Position
    },
    systems::actions::IActionsDispatcherTrait,
    tests::setup::{START_TIMESTAMP, PLAYER_A, PLAYER_B, spawn_dragark}
};

#[test]
fn test_insert_dragon() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.insert_dragon(dragon_token_id);

    // [Assert]
    let dragon_after: Dragon = world.read_model(dragon_token_id);
    assert_eq!(dragon_after.is_inserted, true);
    assert_eq!(dragon_after.inserted_time, timestamp);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.insert_dragon(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Invalid dragon id", 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_invalid_dragon_id() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.insert_dragon(0);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_wrong_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id + 1,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);
    actions_system.insert_dragon(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Not own dragon", 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_not_own_dragon() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_B(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_B(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_b_global: PlayerGlobal = world.read_model(PLAYER_B());
    player_b_global.num_dragons_owned = 1;
    world.write_model_test(@player_b_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.insert_dragon(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Dragon not NFT", 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_dragon_not_nft() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
        root_owner: Zeroable::zero(),
        model_id: 18399416108126480420697739837366591432520176652608561,
        bg_id: 7165065848958115634,
        rarity: DragonRarity::Common,
        element: DragonElement::Darkness,
        speed: 50,
        attack: 50,
        carrying_capacity: 100,
        state: DragonState::Idling,
        dragon_type: DragonType::Default,
        is_inserted: false,
        inserted_time: 0
    };
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.insert_dragon(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Dragon already inserted", 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_dragon_already_inserted() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.insert_dragon(dragon_token_id);
    actions_system.insert_dragon(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Already inserted dragon", 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_already_inserted_dragon() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let first_dragon_token_id = 1;
    let second_dragon_token_id = 2;
    let frist_dragon = Dragon {
        dragon_token_id: first_dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    let second_dragon = Dragon {
        dragon_token_id: second_dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@frist_dragon);
    world.write_model_test(@second_dragon);
    world
        .write_model_test(
            @PlayerDragonOwned {
                player: PLAYER_A(), index: 0, dragon_token_id: first_dragon_token_id
            }
        );
    world
        .write_model_test(
            @PlayerDragonOwned {
                player: PLAYER_A(), index: 1, dragon_token_id: second_dragon_token_id
            }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 2;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.insert_dragon(first_dragon_token_id);
    actions_system.insert_dragon(second_dragon_token_id);
}

#[test]
fn test_claim_dragark() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    actions_system.insert_dragon(dragon_token_id);
    let timestamp_after = timestamp + 28800;
    set_block_timestamp(timestamp_after);
    actions_system.claim_dragark(dragon_token_id);

    // [Assert] Dragon
    let dragon_after: Dragon = world.read_model(dragon_token_id);
    assert_eq!(dragon_after.is_inserted, false);

    // [Assert] PlayerGlobal
    let player_a_global_after: PlayerGlobal = world.read_model(PLAYER_A());
    assert_eq!(player_a_global_after.dragark_balance, player_a_global.dragark_balance + 3);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.claim_dragark(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Invalid dragon id", 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_invalid_dragon_id() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_dragark(0);
}

#[test]
#[should_panic(expected: ("Wrong map", 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_wrong_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id + 1,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.claim_dragark(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Not own dragon", 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_not_own_dragon() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_B(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_B(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_b_global: PlayerGlobal = world.read_model(PLAYER_B());
    player_b_global.num_dragons_owned = 1;
    world.write_model_test(@player_b_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_dragark(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Dragon not NFT", 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_dragon_not_nft() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
        root_owner: Zeroable::zero(),
        model_id: 18399416108126480420697739837366591432520176652608561,
        bg_id: 7165065848958115634,
        rarity: DragonRarity::Common,
        element: DragonElement::Darkness,
        speed: 50,
        attack: 50,
        carrying_capacity: 100,
        state: DragonState::Idling,
        dragon_type: DragonType::Default,
        is_inserted: false,
        inserted_time: 0
    };
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_dragark(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Dragon not inserted", 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_dragon_not_inserted() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.claim_dragark(dragon_token_id);
}

#[test]
#[should_panic(expected: ("Not enough time to claim", 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_not_enough_time_to_claim() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: PLAYER_A(),
        map_id: map_id,
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
    world.write_model_test(@dragon);
    world
        .write_model_test(
            @PlayerDragonOwned { player: PLAYER_A(), index: 0, dragon_token_id: dragon_token_id }
        );
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.num_dragons_owned = 1;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.insert_dragon(dragon_token_id);
    actions_system.claim_dragark(dragon_token_id);
}

#[test]
fn test_buy_energy_first_pack() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
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
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.current_stone = 1_000_000;
    world.write_model_test(@player_a);
    actions_system.buy_energy(1);

    // [Assert] Player
    let player_a_after: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player_a_after.current_stone + 500_000, player_a.current_stone);
    assert_eq!(player_a_after.energy_bought_num, 1);
    assert_eq!(player_a_after.energy, player_a.energy + 10);
}

#[test]
fn test_buy_energy_second_pack() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
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
    let player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    let player_a: Player = world.read_model((PLAYER_A(), map_id));
    actions_system.buy_energy(2);

    // [Assert] Player
    let player_a_after: Player = world.read_model((PLAYER_A(), map_id));
    assert_eq!(player_a_after.energy, player_a.energy + 20);

    // [Assert] PlayerGlobal
    let player_a_global_after: PlayerGlobal = world.read_model(PLAYER_A());
    assert_eq!(player_a_global.dragark_balance, player_a_global_after.dragark_balance + 2);
}

#[test]
#[should_panic(expected: ("Map not initialized", 'ENTRYPOINT_FAILED',))]
fn test_buy_energy_revert_map_not_initialized() {
    // [Setup]
    let (_, actions_system, _) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.buy_energy(1);
}

#[test]
#[should_panic(expected: ("Player not joined map", 'ENTRYPOINT_FAILED',))]
fn test_buy_energy_revert_player_not_joined_map() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.map_id = map_id;
    world.write_model_test(@player_a_global);

    // [Act]
    actions_system.buy_energy(1);
}

#[test]
#[should_panic(expected: ("Invalid pack number", 'ENTRYPOINT_FAILED',))]
fn test_buy_energy_revert_invalid_pack_number() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.buy_energy(3);
}

#[test]
#[should_panic(expected: ("Not out of energy yet", 'ENTRYPOINT_FAILED',))]
fn test_buy_energy_revert_not_out_of_energy_yet() {
    // [Setup]
    let (_, actions_system, map_id) = spawn_dragark();
    let timestamp = START_TIMESTAMP;
    set_block_timestamp(timestamp);
    set_contract_address(PLAYER_A());

    // [Act]
    actions_system.join_map(map_id, 0, 0, 0, 0, 0);
    actions_system.buy_energy(1);
}

#[test]
#[should_panic(expected: ("Not enough stone", 'ENTRYPOINT_FAILED',))]
fn test_buy_energy_revert_not_enough_stone() {
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
    actions_system.buy_energy(1);
}

#[test]
#[should_panic(expected: ("Out of energy bought", 'ENTRYPOINT_FAILED',))]
fn test_buy_energy_revert_out_of_energy_bought() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
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
    let mut player_a: Player = world.read_model((PLAYER_A(), map_id));
    player_a.current_stone = 1_500_000;
    world.write_model_test(@player_a);
    actions_system.buy_energy(1);
    actions_system.scout(map_id, Position { x: 12, y: 32 });
    actions_system.scout(map_id, Position { x: 12, y: 33 });
    actions_system.scout(map_id, Position { x: 12, y: 34 });
    actions_system.scout(map_id, Position { x: 12, y: 35 });
    actions_system.scout(map_id, Position { x: 12, y: 36 });
    actions_system.scout(map_id, Position { x: 12, y: 37 });
    actions_system.scout(map_id, Position { x: 12, y: 38 });
    actions_system.scout(map_id, Position { x: 12, y: 39 });
    actions_system.scout(map_id, Position { x: 12, y: 40 });
    actions_system.scout(map_id, Position { x: 12, y: 41 });
    actions_system.buy_energy(1);
    actions_system.scout(map_id, Position { x: 12, y: 42 });
    actions_system.scout(map_id, Position { x: 12, y: 43 });
    actions_system.scout(map_id, Position { x: 12, y: 44 });
    actions_system.scout(map_id, Position { x: 12, y: 45 });
    actions_system.scout(map_id, Position { x: 12, y: 46 });
    actions_system.scout(map_id, Position { x: 12, y: 47 });
    actions_system.scout(map_id, Position { x: 12, y: 48 });
    actions_system.scout(map_id, Position { x: 12, y: 49 });
    actions_system.scout(map_id, Position { x: 12, y: 50 });
    actions_system.scout(map_id, Position { x: 12, y: 51 });
    actions_system.buy_energy(1);
}

#[test]
#[should_panic(expected: ("Not enough dragark balance", 'ENTRYPOINT_FAILED',))]
fn test_buy_energy_revert_not_enough_dragark_balance() {
    // [Setup]
    let (mut world, actions_system, map_id) = spawn_dragark();
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
    let mut player_a_global: PlayerGlobal = world.read_model(PLAYER_A());
    player_a_global.dragark_balance = 0;
    world.write_model_test(@player_a_global);
    actions_system.buy_energy(2);
}
