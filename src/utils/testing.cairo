// Starknet imports
use starknet::{
    {ContractAddress, contract_address_const, get_block_timestamp, get_caller_address},
    testing::{set_account_contract_address, set_contract_address}
};

// Dojo imports
use dojo::{
    world::{IWorldDispatcher, IWorldDispatcherTrait},
    utils::{bytearray_hash, test::spawn_test_world}
};

// Internal imports
use dragark::{
    models::{
        achievement::{Achievement, AchievementTracking, achievement, achievement_tracking},
        base::{BaseResources, base_resources}, dragon::{Dragon, dragon},
        island::{
            Island, PositionIsland, PlayerIslandSlot, island, position_island, player_island_slot
        },
        journey::{Journey, journey}, map::{MapInfo, NonceUsed, map_info, nonce_used},
        mission::{Mission, MissionTracking, mission, mission_tracking},
        player::{
            Player, PlayerGlobal, PlayerDragonOwned, PlayerIslandOwned, PlayerInviteCode,
            AccountLevelUpgrade, InvitationLevelUpgrade, StarShopTracking, player, player_global,
            player_dragon_owned, player_island_owned, player_invite_code, account_level_upgrade,
            invitation_level_upgrade, star_shop_tracking
        },
        position::{
            NextBlockDirection, NextIslandBlockDirection, next_block_direction,
            next_island_block_direction
        },
        scout::{ScoutInfo, PlayerScoutInfo, scout_info, player_scout_info},
        shield::{Shield, shield}, treasure_hunt::{TreasureHunt, treasure_hunt}
    },
    systems::{
        achievement::contracts::{
            achievement_systems, IAchievementSystemDispatcher, IAchievementSystemDispatcherTrait
        },
        base::contracts::{base_systems, IBaseSystemDispatcher, IBaseSystemDispatcherTrait},
        dragon::contracts::{dragon_systems, IDragonSystemDispatcher, IDragonSystemDispatcherTrait},
        island::contracts::{island_systems, IIslandSystemDispatcher, IIslandSystemDispatcherTrait},
        journey::contracts::{
            journey_systems, IJourneySystemDispatcher, IJourneySystemDispatcherTrait
        },
        map::contracts::{map_systems, IMapSystemDispatcher, IMapSystemDispatcherTrait},
        mission::contracts::{
            mission_systems, IMissionSystemDispatcher, IMissionSystemDispatcherTrait
        },
        player::contracts::{player_systems, IPlayerSystemDispatcher, IPlayerSystemDispatcherTrait},
        scout::contracts::{scout_systems, IScoutSystemDispatcher, IScoutSystemDispatcherTrait},
        shield::contracts::{shield_systems, IShieldSystemDispatcher, IShieldSystemDispatcherTrait},
        treasure_hunt::contracts::{
            treasure_hunt_systems, ITreasureHuntSystemDispatcher, ITreasureHuntSystemDispatcherTrait
        }
    }
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

fn spawn_dragark() -> (IWorldDispatcher, IMapSystemDispatcher, usize) {
    // [Setup] World
    let mut models = array![
        achievement::TEST_CLASS_HASH,
        achievement_tracking::TEST_CLASS_HASH,
        base_resources::TEST_CLASS_HASH,
        dragon::TEST_CLASS_HASH,
        island::TEST_CLASS_HASH,
        position_island::TEST_CLASS_HASH,
        player_island_slot::TEST_CLASS_HASH,
        journey::TEST_CLASS_HASH,
        map_info::TEST_CLASS_HASH,
        nonce_used::TEST_CLASS_HASH,
        mission::TEST_CLASS_HASH,
        mission_tracking::TEST_CLASS_HASH,
        player::TEST_CLASS_HASH,
        player_global::TEST_CLASS_HASH,
        player_dragon_owned::TEST_CLASS_HASH,
        player_island_owned::TEST_CLASS_HASH,
        player_invite_code::TEST_CLASS_HASH,
        account_level_upgrade::TEST_CLASS_HASH,
        invitation_level_upgrade::TEST_CLASS_HASH,
        star_shop_tracking::TEST_CLASS_HASH,
        next_block_direction::TEST_CLASS_HASH,
        next_island_block_direction::TEST_CLASS_HASH,
        scout_info::TEST_CLASS_HASH,
        player_scout_info::TEST_CLASS_HASH,
        shield::TEST_CLASS_HASH,
        treasure_hunt::TEST_CLASS_HASH,
    ];
    set_account_contract_address(OWNER());
    let world = spawn_test_world(["dragark"].span(), models.span());

    // [Setup] Map
    set_contract_address(OWNER());
    let map_systems = deploy_map_systems(world);

    // [Setup] Permissions
    world.grant_writer(dojo::utils::bytearray_hash(@"dragark"), map_systems.contract_address);

    // [Setup] Init map
    let map_id = map_systems.init_new_map();

    (world, map_systems, map_id)
}

fn deploy_achievement_systems(world: IWorldDispatcher) -> IAchievementSystemDispatcher {
    let achievement_systems_address = world
        .deploy_contract(
            achievement_systems::TEST_CLASS_HASH,
            achievement_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IAchievementSystemDispatcher { contract_address: achievement_systems_address }
}

fn deploy_base_systems(world: IWorldDispatcher) -> IBaseSystemDispatcher {
    let base_systems_address = world
        .deploy_contract(
            base_systems::TEST_CLASS_HASH, base_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IBaseSystemDispatcher { contract_address: base_systems_address }
}

fn deploy_dragon_systems(world: IWorldDispatcher) -> IDragonSystemDispatcher {
    let dragon_systems_address = world
        .deploy_contract(
            dragon_systems::TEST_CLASS_HASH, dragon_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IDragonSystemDispatcher { contract_address: dragon_systems_address }
}

fn deploy_island_systems(world: IWorldDispatcher) -> IIslandSystemDispatcher {
    let island_systems_address = world
        .deploy_contract(
            island_systems::TEST_CLASS_HASH, island_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IIslandSystemDispatcher { contract_address: island_systems_address }
}

fn deploy_journey_systems(world: IWorldDispatcher) -> IJourneySystemDispatcher {
    let journey_systems_address = world
        .deploy_contract(
            journey_systems::TEST_CLASS_HASH, journey_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IJourneySystemDispatcher { contract_address: journey_systems_address }
}

fn deploy_map_systems(world: IWorldDispatcher) -> IMapSystemDispatcher {
    let map_systems_address = world
        .deploy_contract(
            map_systems::TEST_CLASS_HASH, map_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IMapSystemDispatcher { contract_address: map_systems_address }
}

fn deploy_mission_systems(world: IWorldDispatcher) -> IMissionSystemDispatcher {
    let mission_systems_address = world
        .deploy_contract(
            mission_systems::TEST_CLASS_HASH, mission_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IMissionSystemDispatcher { contract_address: mission_systems_address }
}

fn deploy_player_systems(world: IWorldDispatcher) -> IPlayerSystemDispatcher {
    let player_systems_address = world
        .deploy_contract(
            player_systems::TEST_CLASS_HASH, player_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IPlayerSystemDispatcher { contract_address: player_systems_address }
}

fn deploy_scout_systems(world: IWorldDispatcher) -> IScoutSystemDispatcher {
    let scout_systems_address = world
        .deploy_contract(
            scout_systems::TEST_CLASS_HASH, scout_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IScoutSystemDispatcher { contract_address: scout_systems_address }
}

fn deploy_shield_systems(world: IWorldDispatcher) -> IShieldSystemDispatcher {
    let shield_systems_address = world
        .deploy_contract(
            shield_systems::TEST_CLASS_HASH, shield_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    IShieldSystemDispatcher { contract_address: shield_systems_address }
}

fn deploy_treasure_hunt_systems(world: IWorldDispatcher) -> ITreasureHuntSystemDispatcher {
    let treasure_hunt_systems_address = world
        .deploy_contract(
            treasure_hunt_systems::TEST_CLASS_HASH,
            treasure_hunt_systems::TEST_CLASS_HASH.try_into().unwrap()
        );
    ITreasureHuntSystemDispatcher { contract_address: treasure_hunt_systems_address }
}
