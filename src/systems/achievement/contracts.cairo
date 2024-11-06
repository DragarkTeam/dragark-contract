// Interface
#[dojo::interface]
trait IAchievementSystem<TContractState> {
    // Function for claiming the reward of achievement
    fn claim_achievement_reward(ref world: IWorldDispatcher);

    // Function for updating (add/modify/remove) achievement
    // Only callable by admin
    // # Argument
    // * achievement_id The achievement id
    // * targets Array of the achievement's targets
    // * stone_rewards Array of the achievement's stone rewards
    // * dragark_stone_rewards Array of the achievement's dragark stone rewards
    fn update_achievement(
        ref world: IWorldDispatcher,
        achievement_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u128>,
        free_dragark_rewards: Array<u8>
    );
}

// Contract
#[dojo::contract]
mod achievement_systems {
    // Starknet imports
    use starknet::{get_caller_address, get_block_timestamp};

    // Internal imports
    use dragark::{
        models::{
            achievement::AchievementTrait, map::{MapInfo, IsMapInitialized},
            player::{Player, PlayerGlobal, IsPlayerJoined}
        },
        errors::{Error, assert_with_err},
        events::{
            FreeDragonClaimed, PlayerContributionPointChange, PlayerStoneUpdate,
            PlayerDragarkStoneUpdate
        },
        utils::general::{
            _is_playable, _require_valid_time, _require_world_owner,
            total_contribution_point_to_dragark_stone_pool
        }
    };

    // Local imports
    use super::IAchievementSystem;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FreeDragonClaimed: FreeDragonClaimed,
        PlayerContributionPointChange: PlayerContributionPointChange,
        PlayerStoneUpdate: PlayerStoneUpdate,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate
    }

    // Impls
    #[abi(embed_v0)]
    impl IAchievementSystemImpl of IAchievementSystem<ContractState> {
        // See IAchievementSystem-claim_achievement_reward
        fn claim_achievement_reward(ref world: IWorldDispatcher) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
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

            // Claim achievement reward
            let free_dragons_claimed = AchievementTrait::claim_achievement_reward(
                ref player, ref player_global, ref map, world, map_id, cur_block_timestamp
            );

            // Emit events
            if (!free_dragons_claimed.is_empty()) {
                let mut free_dragon_claimed_index = 0;
                let free_dragons_claimed_len = free_dragons_claimed.len();
                loop {
                    if (free_dragon_claimed_index == free_dragons_claimed_len) {
                        break;
                    }

                    let free_dragon_claimed = *free_dragons_claimed.at(free_dragon_claimed_index);
                    emit!(
                        world,
                        (Event::FreeDragonClaimed(
                            FreeDragonClaimed {
                                dragon_token_id: free_dragon_claimed.dragon_token_id,
                                owner: free_dragon_claimed.owner,
                                map_id: free_dragon_claimed.map_id,
                                model_id: free_dragon_claimed.model_id,
                                bg_id: free_dragon_claimed.bg_id,
                                rarity: free_dragon_claimed.rarity,
                                element: free_dragon_claimed.element,
                                level: free_dragon_claimed.level,
                                base_speed: free_dragon_claimed.base_speed,
                                base_attack: free_dragon_claimed.base_attack,
                                base_carrying_capacity: free_dragon_claimed.base_carrying_capacity,
                                speed: free_dragon_claimed.speed,
                                attack: free_dragon_claimed.attack,
                                carrying_capacity: free_dragon_claimed.carrying_capacity,
                                state: free_dragon_claimed.state,
                                dragon_type: free_dragon_claimed.dragon_type,
                                recovery_time: free_dragon_claimed.recovery_time
                            }
                        ))
                    );

                    free_dragon_claimed_index += 1;
                };
            }

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
        }

        // See IAchievementSystem-update_achievement
        fn update_achievement(
            ref world: IWorldDispatcher,
            achievement_id: felt252,
            targets: Array<u32>,
            stone_rewards: Array<u128>,
            dragark_stone_rewards: Array<u128>,
            free_dragark_rewards: Array<u8>
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

            // Update achievement
            AchievementTrait::update_achievement(
                world,
                achievement_id,
                targets,
                stone_rewards,
                dragark_stone_rewards,
                free_dragark_rewards
            );
        }
    }
}
