// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{dragon::DragonTrait, map::MapInfo, player::{Player, PlayerGlobal, PlayerTrait}},
    constants::{START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, DAILY_LOGIN_MISSION_ID, mission_ids},
    errors::{Error, panic_by_err}
};

// Models
#[derive(Drop, Serde)]
#[dojo::model]
struct Mission {
    #[key]
    mission_id: felt252,
    targets: Array<u32>,
    stone_rewards: Array<u128>,
    dragark_stone_rewards: Array<u128>,
    account_exp_rewards: Array<u64>
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct MissionTracking {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    #[key]
    mission_id: felt252,
    daily_timestamp: u64,
    current_value: u32,
    claimed_times: u32,
}

// Impls
#[generate_trait]
impl MissionImpl of MissionTrait {
    // Internal function to handle `claim_mission_reward` logic
    fn claim_mission_reward(
        ref player: Player, ref map: MapInfo, world: IWorldDispatcher, cur_block_timestamp: u64
    ) {
        let caller = player.player;
        let player_global = get!(world, (caller), PlayerGlobal);
        let map_id = map.map_id;
        let player_account_exp_before = player.account_exp;

        let daily_timestamp = cur_block_timestamp
            - ((cur_block_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);

        // Fetch current stone
        PlayerTrait::_update_stone(ref player, cur_block_timestamp);

        // Get all mission ids
        let mission_ids = mission_ids();
        let missions_num = mission_ids.len();
        let mut i: u32 = 0;
        loop {
            if (i == missions_num) {
                break;
            }

            // Get mission id
            let mission_id = *mission_ids.at(i);

            // Get mission info
            let mission = get!(world, (mission_id), Mission);
            let mission_targets: Array<u32> = mission.targets;
            let mission_stone_rewards: Array<u128> = mission.stone_rewards;
            let mission_dragark_stone_rewards: Array<u128> = mission.dragark_stone_rewards;
            let mission_account_exp_rewards: Array<u64> = mission.account_exp_rewards;

            // Get mission tracking
            let mut mission_tracking = get!(world, (caller, map_id, mission_id), MissionTracking);

            // If it's daily login mission & timestamp hasn't been updated => Update
            if (mission_id == DAILY_LOGIN_MISSION_ID
                && daily_timestamp > mission_tracking.daily_timestamp) {
                // Reset data
                mission_tracking.daily_timestamp = daily_timestamp;
                mission_tracking.current_value = 0;
                mission_tracking.claimed_times = 0;
            }

            // Check mission tracking timestamp
            if (daily_timestamp == mission_tracking.daily_timestamp) {
                let mut current_claimed_times: u32 = mission_tracking.claimed_times;
                loop {
                    // Check target
                    let current_target: u32 = match mission_targets.get(current_claimed_times) {
                        Option::Some(x) => { *x.unbox() },
                        Option::None => { break; }
                    };
                    if (mission_tracking.current_value < current_target) {
                        break;
                    }

                    // Update rewards
                    let stone_reward = *mission_stone_rewards.at(current_claimed_times);
                    let dragark_stone_reward = *mission_dragark_stone_rewards
                        .at(current_claimed_times);
                    let account_exp_reward = *mission_account_exp_rewards.at(current_claimed_times);
                    player.current_stone += stone_reward;
                    player.account_exp += account_exp_reward;
                    player.dragark_stone_balance += dragark_stone_reward;
                    map.total_account_exp += account_exp_reward;

                    // Increase index
                    current_claimed_times += 1;
                };

                // Update claimed times
                mission_tracking.claimed_times = current_claimed_times;

                // Save models
                set!(world, (mission_tracking));
            }

            // Increase index
            i = i + 1;
        };

        // Update Contribution Point (CP)
        if (player.account_exp != player_account_exp_before) {
            let total_dragark_nft_level = DragonTrait::_calculate_total_dragark_nft_level(
                world, player_global
            );
            let total_bonus_element_nft = DragonTrait::_calculate_total_bonus_element_nft(
                world, player_global
            );
            PlayerTrait::_update_contribution_points(
                ref player, ref map, total_dragark_nft_level, total_bonus_element_nft
            );
        }

        // Save models
        set!(world, (player));
        set!(world, (map));
    }

    // Internal function to handle `update_mission` logic
    fn update_mission(
        world: IWorldDispatcher,
        mission_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u128>,
        account_exp_rewards: Array<u64>
    ) {
        // Save models
        set!(
            world,
            Mission {
                mission_id, targets, stone_rewards, dragark_stone_rewards, account_exp_rewards
            }
        )
    }

    // Internal function to handle `_update_mission_tracking` logic
    fn _update_mission_tracking(
        ref mission_tracking: MissionTracking, world: IWorldDispatcher, daily_timestamp: u64
    ) {
        let mission_tracking_daily_timestamp = mission_tracking.daily_timestamp;

        if (daily_timestamp == mission_tracking_daily_timestamp) {
            mission_tracking.current_value += 1;
        } else if (daily_timestamp > mission_tracking_daily_timestamp) {
            mission_tracking.current_value = 1;
            mission_tracking.claimed_times = 0;
            mission_tracking.daily_timestamp = daily_timestamp;
        } else {
            panic_by_err(Error::INVALID_CASE_DAILY_TIMESTAMP, Option::None);
        }
    }
}
