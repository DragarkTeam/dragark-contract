// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{
        dragon::{Dragon, DragonTrait}, map::MapInfo,
        player::{Player, PlayerGlobal, PlayerDragonOwned, PlayerTrait}
    },
    constants::achievement_ids
};

// Models
#[derive(Drop, Serde)]
#[dojo::model]
struct Achievement {
    #[key]
    achievement_id: felt252,
    targets: Array<u32>,
    stone_rewards: Array<u128>,
    dragark_stone_rewards: Array<u128>,
    free_dragark_rewards: Array<u8>
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct AchievementTracking {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    #[key]
    achievement_id: felt252,
    current_value: u32,
    claimed_times: u32
}

// Impls
#[generate_trait]
impl AchievementImpl of AchievementTrait {
    // Internal function to handle `claim_achievement_reward` logic
    fn claim_achievement_reward(
        ref player: Player,
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        world: IWorldDispatcher,
        map_id: usize,
        cur_block_timestamp: u64
    ) -> Array<Dragon> {
        let caller = player.player;
        let map_id = map.map_id;
        let mut is_claimed_dragon: bool = false;
        let mut free_dragons_claimed: Array<Dragon> = array![];

        // Fetch current stone
        PlayerTrait::_update_stone(ref player, cur_block_timestamp);

        // Get all achievement ids
        let achievement_ids = achievement_ids();
        let achievements_num = achievement_ids.len();
        let mut i: u32 = 0;
        loop {
            if (i == achievements_num) {
                break;
            }

            // Get achievement id
            let achievement_id = *achievement_ids.at(i);

            // Get achievement info
            let achievement = get!(world, (achievement_id), Achievement);
            let achievement_targets: Array<u32> = achievement.targets;
            let achievement_stone_rewards: Array<u128> = achievement.stone_rewards;
            let achievement_dragark_stone_rewards: Array<u128> = achievement.dragark_stone_rewards;
            let achievement_free_dragark_rewards: Array<u8> = achievement.free_dragark_rewards;

            // Get achievement tracking
            let mut achievement_tracking = get!(
                world, (caller, map_id, achievement_id), AchievementTracking
            );

            let mut current_claimed_times: u32 = achievement_tracking.claimed_times;
            loop {
                // Check target
                let current_target: u32 = match achievement_targets.get(current_claimed_times) {
                    Option::Some(x) => { *x.unbox() },
                    Option::None => { break; }
                };
                if (achievement_tracking.current_value < current_target) {
                    break;
                }

                // Update reward
                let stone_reward = *achievement_stone_rewards.at(current_claimed_times);
                let dragark_stone_reward = *achievement_dragark_stone_rewards
                    .at(current_claimed_times);
                let free_dragark_reward = *achievement_free_dragark_rewards
                    .at(current_claimed_times);
                player.current_stone += stone_reward;
                player.dragark_stone_balance += dragark_stone_reward;

                // Claim free dragon
                let mut dragon_claim_index = 0;
                loop {
                    if (dragon_claim_index == free_dragark_reward) {
                        break;
                    }

                    map.dragon_token_id_counter += 1;
                    let dragon = DragonTrait::_claim_free_dragon(
                        world, map.dragon_token_id_counter, caller, map_id, 0
                    );
                    free_dragons_claimed.append(dragon);
                    set!(world, (dragon));
                    set!(
                        world,
                        (PlayerDragonOwned {
                            player: caller,
                            index: player_global.num_dragons_owned,
                            dragon_token_id: dragon.dragon_token_id
                        })
                    );

                    // Update data
                    map.total_claim_dragon += 1;
                    map.total_dragon += 1;
                    player_global.num_dragons_owned += 1;
                    is_claimed_dragon = true;

                    // Increase index
                    dragon_claim_index += 1;
                };

                // Increase index
                current_claimed_times += 1;
            };

            // Update claimed times
            achievement_tracking.claimed_times = current_claimed_times;

            // Save models
            set!(world, (achievement_tracking));

            // Increase index
            i = i + 1;
        };

        // Save models
        set!(world, (player));
        set!(world, (player_global));
        set!(world, (map));

        free_dragons_claimed
    }

    // Internal function to handle `update_achievement` logic
    fn update_achievement(
        world: IWorldDispatcher,
        achievement_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u128>,
        free_dragark_rewards: Array<u8>
    ) {
        // Save models
        set!(
            world,
            Achievement {
                achievement_id, targets, stone_rewards, dragark_stone_rewards, free_dragark_rewards
            }
        );
    }

    // Internal function to handle `_update_achievement_tracking` logic
    fn _update_achievement_tracking(ref achievement_tracking: AchievementTracking, value: u32) {
        let achievement_tracking_current_value = achievement_tracking.current_value;
        if (value > achievement_tracking_current_value) {
            achievement_tracking.current_value = value;
        }
    }
}
