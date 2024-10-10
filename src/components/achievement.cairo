// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{models::{achievement::{Achievement, AchievementTracking}}};

// Interface
#[starknet::interface]
trait IAchievementActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the Achievement model info
    // # Argument
    // * world The world address
    // * achievement_id The achievement id
    // # Return
    // * Achievement The Achievement model
    fn get_achievement(
        self: @TContractState, world: IWorldDispatcher, achievement_id: felt252
    ) -> Achievement;

    // Function to get the AchievementTracking model info
    // # Argument
    // * world The world address
    // * player The player address to get info
    // * map_id The map_id to get info
    // * achievement_id The achievement id
    // # Return
    // * AchievementTracking The AchievementTracking model
    fn get_achievement_tracking(
        self: @TContractState,
        world: IWorldDispatcher,
        player: ContractAddress,
        map_id: usize,
        achievement_id: felt252
    ) -> AchievementTracking;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for claiming the reward of achievement
    // # Argument
    // * world The world address
    fn claim_achievement_reward(ref self: TContractState, world: IWorldDispatcher);

    // Function for updating (add/modify/remove) achievement
    // Only callable by admin
    // # Argument
    // * world The world address
    // * achievement_id The achievement id
    // * targets Array of the achievement's targets
    // * stone_rewards Array of the achievement's stone rewards
    // * dragark_stone_rewards Array of the achievement's dragark stone rewards
    fn update_achievement(
        ref self: TContractState,
        world: IWorldDispatcher,
        achievement_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u64>
    );
}

// Component
#[starknet::component]
mod AchievementActionsComponent {
    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        constants::{achievement_ids},
        components::{
            player::{PlayerActionsComponent, PlayerActionsComponent::PlayerActionsInternalTrait},
            emitter::{EmitterTrait, EmitterComponent}
        },
        events::{PlayerStoneUpdate, PlayerDragarkStoneUpdate},
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{IsMapInitialized, MapInfo},
            achievement::{Achievement, AchievementTracking}
        },
        errors::{Error, assert_with_err},
        utils::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IAchievementActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(AchievementActionsImpl)]
    impl AchievementActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl PlayerActions: PlayerActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IAchievementActions<ComponentState<TContractState>> {
        // See IAchievementActions-get_achievement
        fn get_achievement(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, achievement_id: felt252
        ) -> Achievement {
            get!(world, (achievement_id), Achievement)
        }

        // See IAchievementActions-get_achievement_tracking
        fn get_achievement_tracking(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            player: ContractAddress,
            map_id: usize,
            achievement_id: felt252
        ) -> AchievementTracking {
            get!(world, (player, map_id, achievement_id), AchievementTracking)
        }

        // See IAchievementActions-claim_achievement_reward
        fn claim_achievement_reward(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let mut player_actions_comp = get_dep_component_mut!(ref self, PlayerActions);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Fetch current stone
            player = player_actions_comp._update_stone(player, world, cur_block_timestamp);

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
                let achievement_dragark_stone_rewards: Array<u64> = achievement
                    .dragark_stone_rewards;

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
                    player.current_stone += stone_reward;
                    player.dragark_stone_balance += dragark_stone_reward;

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

            // Emit events
            if (player.current_stone != player_stone_before) {
                emitter_comp
                    .emit_player_stone_update(
                        world,
                        PlayerStoneUpdate {
                            map_id,
                            player: caller,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    );
            }

            if (player.dragark_stone_balance != player_dragark_stone_before) {
                emitter_comp
                    .emit_player_dragark_stone_update(
                        world,
                        PlayerDragarkStoneUpdate {
                            map_id,
                            player: caller,
                            dragark_stone_balance: player.dragark_stone_balance
                        }
                    );
            }
        }

        // See IAchievementActions-update_achievement
        fn update_achievement(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            achievement_id: felt252,
            targets: Array<u32>,
            stone_rewards: Array<u128>,
            dragark_stone_rewards: Array<u64>
        ) {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            // Check mission rewards
            assert_with_err(
                targets.len() == stone_rewards.len(), Error::INVALID_REWARD, Option::None
            );
            assert_with_err(
                targets.len() == dragark_stone_rewards.len(), Error::INVALID_REWARD, Option::None
            );

            // Save models
            set!(
                world, Achievement { achievement_id, targets, stone_rewards, dragark_stone_rewards }
            );
        }
    }

    // Internal implementations
    #[generate_trait]
    impl AchievementActionsInternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of AchievementActionsInternalTrait<TContractState> {
        fn _update_achievement_tracking(
            ref self: ComponentState<TContractState>,
            mut achievement_tracking: AchievementTracking,
            value: u32
        ) -> AchievementTracking {
            let achievement_tracking_current_value = achievement_tracking.current_value;
            if (value > achievement_tracking_current_value) {
                achievement_tracking.current_value = value;
            }
            achievement_tracking
        }
    }
}
