// Interface
#[dojo::interface]
trait IMissionSystem<TContractState> {
    // Function for claiming the reward of mission
    fn claim_mission_reward(ref world: IWorldDispatcher);

    // Function for updating (add/modify/remove) mission
    // Only callable by admin
    // # Argument
    // * mission_id The mission id
    // * targets Array of the mission's targets
    // * stone_rewards Array of the mission's stone rewards
    // * dragark_stone_rewards Array of the mission's dragark stone rewards
    // * account_exp_rewards Array of the mission's account exp rewards
    fn update_mission(
        ref world: IWorldDispatcher,
        mission_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u128>,
        account_exp_rewards: Array<u64>
    );
}

// Contract
#[dojo::contract]
mod mission_systems {
    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            map::{MapInfo, IsMapInitialized, IsPlayerJoined}, mission::MissionTrait,
            player::{Player, PlayerGlobal}
        },
        errors::{Error, assert_with_err},
        events::{
            PlayerStoneUpdate, PlayerDragarkStoneUpdate, PlayerAccountExpChange,
            PlayerContributionPointChange
        },
        utils::general::{
            _is_playable, _require_valid_time, _require_world_owner,
            total_contribution_point_to_dragark_stone_pool
        }
    };

    // Local imports
    use super::IMissionSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PlayerStoneUpdate: PlayerStoneUpdate,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate,
        PlayerAccountExpChange: PlayerAccountExpChange,
        PlayerContributionPointChange: PlayerContributionPointChange
    }

    // Impls
    #[abi(embed_v0)]
    impl IMissionSystemImpl of IMissionSystem<ContractState> {
        // See IMissionSystem-claim_mission_reward
        fn claim_mission_reward(ref world: IWorldDispatcher) {
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
            let player_account_exp_before = player.account_exp;
            let player_contribution_points_before = player.contribution_points;
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

            // Claim mission reward
            MissionTrait::claim_mission_reward(ref player, ref map, world, cur_block_timestamp);

            // Emit events
            if (player.current_stone != player_stone_before) {
                emit!(
                    world,
                    (Event::PlayerStoneUpdate(
                        PlayerStoneUpdate {
                            map_id,
                            player: caller,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    ))
                );
            }
            if (player.dragark_stone_balance != player_dragark_stone_before) {
                emit!(
                    world,
                    (Event::PlayerDragarkStoneUpdate(
                        PlayerDragarkStoneUpdate {
                            map_id,
                            player: caller,
                            dragark_stone_balance: player.dragark_stone_balance
                        }
                    ))
                );
            }
            if (player.account_exp != player_account_exp_before) {
                emit!(
                    world,
                    (Event::PlayerAccountExpChange(
                        PlayerAccountExpChange {
                            map_id,
                            player: caller,
                            player_account_exp: player.account_exp,
                            player_account_level: player.account_level,
                            total_account_exp: map.total_account_exp,
                        }
                    ))
                );
            }
            if (player.contribution_points != player_contribution_points_before) {
                let dragark_stone_pool = total_contribution_point_to_dragark_stone_pool(
                    world, map.total_contribution_points, cur_block_timestamp
                );
                emit!(
                    world,
                    (Event::PlayerContributionPointChange(
                        PlayerContributionPointChange {
                            map_id,
                            player: caller,
                            player_contribution_points: player.contribution_points,
                            total_contribution_points: map.total_contribution_points,
                            dragark_stone_pool
                        }
                    ))
                );
            }
        }

        // See IMissionSystem-update_mission
        fn update_mission(
            ref world: IWorldDispatcher,
            mission_id: felt252,
            targets: Array<u32>,
            stone_rewards: Array<u128>,
            dragark_stone_rewards: Array<u128>,
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

            // Update mission
            MissionTrait::update_mission(
                world,
                mission_id,
                targets,
                stone_rewards,
                dragark_stone_rewards,
                account_exp_rewards
            );
        }
    }
}
