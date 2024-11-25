// Starknet imports
use starknet::{
    {ContractAddress, contract_address_const},
    testing::{set_account_contract_address, set_contract_address}
};

// Dojo imports
use dojo::world::{WorldStorage, WorldStorageTrait};
use dojo_cairo_test::{
    spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    WorldStorageTestTrait
};

// Internal imports
use dragark::{
    models::{
        dragon::{Dragon, NonceUsed, m_Dragon, m_NonceUsed},
        island::{Island, PositionIsland, m_Island, m_PositionIsland}, journey::{Journey, m_Journey},
        map_info::{MapInfo, m_MapInfo},
        mission::{Mission, MissionTracking, m_Mission, m_MissionTracking},
        player_dragon_owned::{PlayerDragonOwned, m_PlayerDragonOwned},
        player_island_owned::{PlayerIslandOwned, m_PlayerIslandOwned},
        player_island_slot::{PlayerIslandSlot, m_PlayerIslandSlot},
        player::{Player, PlayerGlobal, m_Player, m_PlayerGlobal},
        position::{
            NextBlockDirection, NextIslandBlockDirection, m_NextBlockDirection,
            m_NextIslandBlockDirection
        },
        scout_info::{ScoutInfo, PlayerScoutInfo, m_ScoutInfo, m_PlayerScoutInfo},
        shield::{Shield, m_Shield}
    },
    systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait}
};

// Testing
const START_TIMESTAMP: u64 = 1724976000;

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn PLAYER_A() -> ContractAddress {
    contract_address_const::<'PLAYER_A'>()
}

fn PLAYER_B() -> ContractAddress {
    contract_address_const::<'PLAYER_B'>()
}

fn ANYONE() -> ContractAddress {
    contract_address_const::<'ANYONE'>()
}

fn namespace_def() -> NamespaceDef {
    let ndef = NamespaceDef {
        namespace: "dragark", resources: [
            TestResource::Model(m_Dragon::TEST_CLASS_HASH),
            TestResource::Model(m_NonceUsed::TEST_CLASS_HASH),
            TestResource::Model(m_Island::TEST_CLASS_HASH),
            TestResource::Model(m_PositionIsland::TEST_CLASS_HASH),
            TestResource::Model(m_Journey::TEST_CLASS_HASH),
            TestResource::Model(m_MapInfo::TEST_CLASS_HASH),
            TestResource::Model(m_Mission::TEST_CLASS_HASH),
            TestResource::Model(m_MissionTracking::TEST_CLASS_HASH),
            TestResource::Model(m_PlayerDragonOwned::TEST_CLASS_HASH),
            TestResource::Model(m_PlayerIslandOwned::TEST_CLASS_HASH),
            TestResource::Model(m_PlayerIslandSlot::TEST_CLASS_HASH),
            TestResource::Model(m_Player::TEST_CLASS_HASH),
            TestResource::Model(m_PlayerGlobal::TEST_CLASS_HASH),
            TestResource::Model(m_NextBlockDirection::TEST_CLASS_HASH),
            TestResource::Model(m_NextIslandBlockDirection::TEST_CLASS_HASH),
            TestResource::Model(m_ScoutInfo::TEST_CLASS_HASH),
            TestResource::Model(m_PlayerScoutInfo::TEST_CLASS_HASH),
            TestResource::Model(m_Shield::TEST_CLASS_HASH),
            TestResource::Contract(actions::TEST_CLASS_HASH),
        ].span()
    };

    ndef
}

fn contract_defs() -> Span<ContractDef> {
    [
        ContractDefTrait::new(@"dragark", @"actions")
            .with_writer_of([dojo::utils::bytearray_hash(@"dragark")].span())
    ].span()
}

#[test]
fn spawn_dragark() -> (WorldStorage, IActionsDispatcher, usize) {
    // [Setup] World
    let ndef = namespace_def();
    set_account_contract_address(OWNER());
    let mut world = spawn_test_world([ndef].span());
    world.sync_perms_and_inits(contract_defs());

    // [Setup] Init Map
    set_contract_address(OWNER());
    let (actions_system_addr, _) = world.dns(@"actions").unwrap();
    let actions_system = IActionsDispatcher { contract_address: actions_system_addr };
    let map_id = actions_system.init_new_map();

    (world, actions_system, map_id)
}
