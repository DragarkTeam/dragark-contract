// Starknet imports
use starknet::testing::{set_block_timestamp, set_contract_address};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{
        dragon::{Dragon, DragonRarity, DragonElement, DragonState, DragonType},
        player::{PlayerGlobal},
    },
    systems::{actions::{IActionsDispatcher, IActionsDispatcherTrait}},
    tests::{store::{Store, StoreTrait}, setup::{setup, setup::{Systems, Context}}}
};

#[test]
fn test_insert_dragon() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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

    // [Assert]
    let dragon_after = store.dragon(dragon_token_id);
    assert_eq!(dragon_after.is_inserted, true);
    assert_eq!(dragon_after.inserted_time, timestamp);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
    systems.actions.insert_dragon(world, dragon_token_id);
}

#[test]
#[should_panic(expected: ('Invalid dragon id', 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_invalid_dragon_id() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.insert_dragon(world, 0);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: context.player_a_address,
        map_id: context.map_id + 1,
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
}

#[test]
#[should_panic(expected: ('Not own dragon', 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_not_own_dragon() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: context.player_b_address,
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
}

#[test]
#[should_panic(expected: ('Dragon not NFT', 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_dragon_not_nft() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
        dragon_type: DragonType::Default,
        is_inserted: false,
        inserted_time: 0
    };
    store.set_dragon(dragon);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.insert_dragon(world, dragon_token_id);
}

#[test]
#[should_panic(expected: ('Dragon already inserted', 'ENTRYPOINT_FAILED',))]
fn test_insert_dragon_revert_dragon_already_inserted() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
    systems.actions.insert_dragon(world, dragon_token_id);
}

#[test]
fn test_claim_dragark() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
    let timestamp_after = timestamp + 28800;
    set_block_timestamp(timestamp_after);
    systems.actions.claim_dragark(world, dragon_token_id);

    // [Assert] Dragon
    let dragon_after = store.dragon(dragon_token_id);
    assert_eq!(dragon_after.is_inserted, false);
    
    // [Assert] PlayerGlobal
    let player_a_global = store.player_global(context.player_a_address);
    assert_eq!(player_a_global.dragark_stone_balance, 13);
}

#[test]
#[should_panic(expected: ('Player not joined map', 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_player_not_joined_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
    systems.actions.claim_dragark(world, dragon_token_id);
}

#[test]
#[should_panic(expected: ('Invalid dragon id', 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_invalid_dragon_id() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
    systems.actions.claim_dragark(world, 0);
}

#[test]
#[should_panic(expected: ('Wrong map', 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_wrong_map() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: context.player_a_address,
        map_id: context.map_id + 1,
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
    systems.actions.claim_dragark(world, dragon_token_id);
}

#[test]
#[should_panic(expected: ('Not own dragon', 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_not_own_dragon() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
    let dragon_token_id = 1;
    let dragon = Dragon {
        dragon_token_id,
        owner: context.player_b_address,
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
    systems.actions.claim_dragark(world, dragon_token_id);
}

#[test]
#[should_panic(expected: ('Dragon not NFT', 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_dragon_not_nft() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
        dragon_type: DragonType::Default,
        is_inserted: false,
        inserted_time: 0
    };
    store.set_dragon(dragon);

    // [Act]
    systems.actions.join_map(world, context.map_id);
    systems.actions.claim_dragark(world, dragon_token_id);
}

#[test]
#[should_panic(expected: ('Dragon not inserted', 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_dragon_not_inserted() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
    systems.actions.claim_dragark(world, dragon_token_id);
}

#[test]
#[should_panic(expected: ('Not enough time to claim', 'ENTRYPOINT_FAILED',))]
fn test_claim_dragark_revert_not_enough_time_to_claim() {
    // [Setup]
    let (world, systems, context) = setup::spawn_game();
    let store = StoreTrait::new(world);
    set_contract_address(context.player_a_address);
    let timestamp = 1721890800;
    set_block_timestamp(timestamp);
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
    systems.actions.claim_dragark(world, dragon_token_id);
}