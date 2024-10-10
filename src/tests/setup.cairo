mod setup {
    // Core imports
    use core::integer::{u32_sqrt, BoundedU32};

    // Starknet imports
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::testing::{
        set_account_contract_address, set_block_timestamp, set_caller_address, set_contract_address
    };

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // Internal imports
    use dragark_test_v19::{
        systems::{actions::{actions, IActionsDispatcher, IActionsDispatcherTrait}},
        models::{
            dragon::{Dragon, DragonInfo, DragonRarity, DragonState, DragonType, dragon},
            island::{
                Island, PositionIsland, IslandElement, IslandTitle, Resource, island,
                position_island
            },
            journey::{Journey, AttackType, AttackResult, JourneyStatus, journey},
            map_info::{MapInfo, IsMapInitialized, map_info},
            player_dragon_owned::{PlayerDragonOwned, player_dragon_owned},
            player_island_owned::{PlayerIslandOwned, player_island_owned},
            player_island_slot::{PlayerIslandSlot, player_island_slot},
            player::{Player, PlayerGlobal, IsPlayerJoined, player, player_global},
            position::{
                NextBlockDirection, NextIslandBlockDirection, next_block_direction,
                next_island_block_direction
            },
            scout_info::{
                ScoutInfo, PlayerScoutInfo, IsScouted, HasIsland, scout_info, player_scout_info
            },
            shield::{Shield, ShieldType, shield},
            mission::{Mission, MissionTracking, mission, mission_tracking},
            achievement::{Achievement, AchievementTracking, achievement, achievement_tracking},
            base::{BaseResources, base_resources}
        }
    };

    // Constants
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

    #[derive(Drop)]
    struct Systems {
        actions: IActionsDispatcher
    }

    #[derive(Drop)]
    struct Context {
        owner_address: ContractAddress,
        player_a_address: ContractAddress,
        player_b_address: ContractAddress,
        anyone_address: ContractAddress,
        map_id: usize
    }

    #[inline(always)]
    fn spawn_game() -> (IWorldDispatcher, Systems, Context) {
        // [Setup] World
        let mut models = array![
            dragon::TEST_CLASS_HASH,
            island::TEST_CLASS_HASH,
            position_island::TEST_CLASS_HASH,
            journey::TEST_CLASS_HASH,
            map_info::TEST_CLASS_HASH,
            player_dragon_owned::TEST_CLASS_HASH,
            player_island_owned::TEST_CLASS_HASH,
            player_island_slot::TEST_CLASS_HASH,
            player::TEST_CLASS_HASH,
            player_global::TEST_CLASS_HASH,
            next_block_direction::TEST_CLASS_HASH,
            next_island_block_direction::TEST_CLASS_HASH,
            scout_info::TEST_CLASS_HASH,
            player_scout_info::TEST_CLASS_HASH,
            shield::TEST_CLASS_HASH,
            mission::TEST_CLASS_HASH,
            mission_tracking::TEST_CLASS_HASH,
            achievement::TEST_CLASS_HASH,
            achievement_tracking::TEST_CLASS_HASH,
            base_resources::TEST_CLASS_HASH
        ];
        set_account_contract_address(OWNER());
        let world = spawn_test_world(models);

        // [Setup] Systems
        let actions_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap(), array![].span());
        let systems = Systems { actions: IActionsDispatcher { contract_address: actions_address } };

        // [Setup] Context
        set_contract_address(OWNER());
        let map_id = systems.actions.init_new_map(world);
        let context = Context {
            owner_address: OWNER(),
            player_a_address: PLAYER_A(),
            player_b_address: PLAYER_B(),
            anyone_address: ANYONE(),
            map_id
        };

        // [Return]
        (world, systems, context)
    }
}
