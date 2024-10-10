// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{models::{mission::{Mission, MissionTracking}}};

// Interface
#[starknet::interface]
trait IMissionActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the Mission model info
    // # Argument
    // * world The world address
    // * mission_id The missiond id
    // # Return
    // * Mission The Mission model
    fn get_mission(self: @TContractState, world: IWorldDispatcher, mission_id: felt252) -> Mission;

    // Function to get the MissionTracking model info
    // # Argument
    // * world The world address
    // * player The player address to get info
    // * map_id The map_id to get info
    // * mission_id The missiond id
    // # Return
    // * MissionTracking The MissionTracking model
    fn get_mission_tracking(
        self: @TContractState,
        world: IWorldDispatcher,
        player: ContractAddress,
        map_id: usize,
        mission_id: felt252
    ) -> MissionTracking;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for claiming the reward of mission
    // # Argument
    // * world The world address
    fn claim_mission_reward(ref self: TContractState, world: IWorldDispatcher);

    // Function for updating (add/modify/remove) mission
    // Only callable by admin
    // # Argument
    // * world The world address
    // * mission_id The mission id
    // * targets Array of the mission's targets
    // * stone_rewards Array of the mission's stone rewards
    // * dragark_stone_rewards Array of the mission's dragark stone rewards
    fn update_mission(
        ref self: TContractState,
        world: IWorldDispatcher,
        mission_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u64>,
        account_exp_rewards: Array<u64>
    );
}

// Component
#[starknet::component]
mod MissionActionsComponent {
    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        constants::{
            START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID,
            START_JOURNEY_MISSION_ID, mission_ids
        },
        components::{
            player::{PlayerActionsComponent, PlayerActionsComponent::PlayerActionsInternalTrait},
            emitter::{EmitterTrait, EmitterComponent}
        },
        events::{MissionMilestoneReached, PlayerStoneUpdate, PlayerDragarkStoneUpdate},
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{IsMapInitialized, MapInfo},
            mission::{Mission, MissionTracking}
        },
        errors::{Error, assert_with_err, panic_by_err},
        utils::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IMissionActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(MissionActionsImpl)]
    impl MissionActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl PlayerActions: PlayerActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IMissionActions<ComponentState<TContractState>> {
        // See IMissionActions-get_mission
        fn get_mission(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, mission_id: felt252
        ) -> Mission {
            get!(world, (mission_id), Mission)
        }

        // See IMissionActions-get_mission_tracking
        fn get_mission_tracking(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            player: ContractAddress,
            map_id: usize,
            mission_id: felt252
        ) -> MissionTracking {
            get!(world, (player, map_id, mission_id), MissionTracking)
        }

        // See IMissionActions-claim_mission_reward
        fn claim_mission_reward(ref self: ComponentState<TContractState>, world: IWorldDispatcher) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let emitter_comp = get_dep_component!(@self, Emitter);
            let mut player_actions_comp = get_dep_component_mut!(ref self, PlayerActions);
            let cur_block_timestamp = get_block_timestamp();
            let daily_timestamp = cur_block_timestamp
                - ((cur_block_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);

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
                let mission_dragark_stone_rewards: Array<u64> = mission.dragark_stone_rewards;
                let mission_account_exp_rewards: Array<u64> = mission.account_exp_rewards;

                // Get mission tracking
                let mut mission_tracking = get!(
                    world, (caller, map_id, mission_id), MissionTracking
                );

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
                        let account_exp_reward = *mission_account_exp_rewards
                            .at(current_claimed_times);
                        player.current_stone += stone_reward;
                        player.account_exp += account_exp_reward;
                        player.dragark_stone_balance += dragark_stone_reward;

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

        // See IMissionActions-update_mission
        fn update_mission(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            mission_id: felt252,
            targets: Array<u32>,
            stone_rewards: Array<u128>,
            dragark_stone_rewards: Array<u64>,
            account_exp_rewards: Array<u64>
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
                world,
                Mission {
                    mission_id, targets, stone_rewards, dragark_stone_rewards, account_exp_rewards
                }
            )
        }
    }

    // Internal implementations
    #[generate_trait]
    impl MissionActionsInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of MissionActionsInternalTrait<TContractState> {
        fn _update_mission_tracking(
            ref self: ComponentState<TContractState>,
            mut mission_tracking: MissionTracking,
            world: IWorldDispatcher,
            daily_timestamp: u64
        ) -> MissionTracking {
            let emitter_comp = get_dep_component!(@self, Emitter);
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

            let mission_tracking_current_value = mission_tracking.current_value;
            if (mission_tracking.mission_id == SCOUT_MISSION_ID) {
                if (mission_tracking_current_value == 5
                    || mission_tracking_current_value == 10
                    || mission_tracking_current_value == 20) {
                    emitter_comp
                        .emit_mission_milestone_reached(
                            world,
                            MissionMilestoneReached {
                                mission_id: SCOUT_MISSION_ID,
                                map_id: mission_tracking.map_id,
                                player: mission_tracking.player,
                                current_value: mission_tracking_current_value
                            }
                        );
                }
            } else if (mission_tracking.mission_id == START_JOURNEY_MISSION_ID) {
                if (mission_tracking_current_value == 1
                    || mission_tracking_current_value == 3
                    || mission_tracking_current_value == 5) {
                    emitter_comp
                        .emit_mission_milestone_reached(
                            world,
                            MissionMilestoneReached {
                                mission_id: START_JOURNEY_MISSION_ID,
                                map_id: mission_tracking.map_id,
                                player: mission_tracking.player,
                                current_value: mission_tracking_current_value
                            }
                        );
                }
            }

            mission_tracking
        }
    }
}
