// Core imports
use core::integer::BoundedU32;
use poseidon::PoseidonTrait;
use ecdsa::check_ecdsa_signature;

// Starknet imports
use starknet::{ContractAddress, get_block_timestamp};

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{
        achievement::{AchievementTracking, AchievementTrait}, dragon::{Dragon, DragonTrait},
        island::{Island, PlayerIslandSlot, IslandType, IslandTrait},
        mission::{MissionTracking, MissionTrait},
        player::{
            Player, PlayerGlobal, PlayerDragonOwned, PlayerIslandOwned, PlayerInviteCode,
            IsPlayerJoined, PlayerTrait
        },
        position::{NextBlockDirection, NextIslandBlockDirection, Position},
        scout::{PlayerScoutInfo, IsScouted, ScoutTrait}
    },
    constants::{
        ADDRESS_SIGN, PUBLIC_KEY_SIGN, START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY,
        DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID, START_JOURNEY_MISSION_ID,
        REDEEM_INVITATION_CODE_ACHIEVEMENT_ID, UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID,
        OWN_ISLAND_ACHIEVEMENT_ID, SEND_DRAGARK_TREASURE_HUNT_TIME_ACHIEVEMENT_ID,
        REACH_ACCOUNT_LVL_ACHIEVEMENT_ID, UPGRADE_DRAGARK_TIME_ACHIEVEMENT_ID,
        island_level_to_points
    },
    errors::{Error, assert_with_err, panic_by_err}, utils::general::_generate_code
};

// Models
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct MapInfo {
    #[key]
    map_id: usize,
    is_initialized: IsMapInitialized,
    total_player: u32,
    total_island: u32,
    total_dragon: u32,
    total_scout: u32,
    total_journey: u32,
    total_treasure_hunt: u32,
    total_activate_dragon: u32,
    total_deactivate_dragon: u32,
    total_join_map: u32,
    total_re_join_map: u32,
    total_start_journey: u32,
    total_finish_journey: u32,
    total_claim_resources: u32,
    total_claim_dragon: u32,
    total_activate_shield: u32,
    total_deactivate_shield: u32,
    total_claim_pool_share: u32,
    total_activate_element_nft: u32,
    total_account_exp: u64,
    total_contribution_points: u64,
    map_sizes: u32,
    map_coordinates: Position,
    cur_block_coordinates: Position,
    block_direction_count: u32,
    derelict_islands_num: u32,
    cur_island_block_coordinates: Position,
    island_block_direction_count: u32,
    dragon_token_id_counter: u128,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct NonceUsed {
    #[key]
    nonce: felt252,
    is_used: bool
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum IsMapInitialized {
    NotInitialized,
    Initialized,
}

// Impls
#[generate_trait]
impl MapImpl of MapTrait {
    // Internal function to handle `join_map` logic
    fn join_map(
        ref player: Player,
        ref player_global: PlayerGlobal,
        ref map: MapInfo,
        ref mission_tracking: MissionTracking,
        world: IWorldDispatcher,
        star: u32,
        nonce: felt252,
        signature_r: felt252,
        signature_s: felt252,
        map_contract_address: ContractAddress,
        cur_timestamp: u64
    ) -> (Array<Position>, Array<felt252>, bool, usize, u64) {
        let caller = player_global.player;
        let map_id = map.map_id;
        let mut scouted_destinations: Array<Position> = array![];
        let mut scout_ids: Array<felt252> = array![];
        let mut player_old_map_contribution_points_before: u64 = 0;

        // Check the map player is in
        if (player_global.map_id == 0) {
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::NotJoined,
                Error::INVALID_CASE_JOIN_MAP,
                Option::None
            );

            // Set player invite code
            let mut salt: felt252 = 0;
            let mut code: felt252 = 0;
            let mut is_duplicated: bool = true;
            while (is_duplicated) {
                code = _generate_code(salt);
                let mut player_invite_code = get!(world, (code), PlayerInviteCode);
                if (player_invite_code.player.is_zero()) {
                    is_duplicated = false;
                    player_invite_code.player = caller;
                    set!(world, (player_invite_code));
                }
                salt += 1;
            };
            player_global.invite_code = code;

            // If star > 0 => Set star
            if (star.is_non_zero()) {
                // Check nonce used
                let mut nonce_used = get!(world, (nonce), NonceUsed);
                assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

                // Verify signature
                let message: Array<felt252> = array![
                    ADDRESS_SIGN,
                    map_contract_address.into(),
                    map_id.into(),
                    caller.into(),
                    star.into(),
                    nonce,
                    'INIT_STAR'
                ];
                let message_hash = poseidon::poseidon_hash_span(message.span());
                assert_with_err(
                    check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
                    Error::SIGNATURE_NOT_MATCH,
                    Option::None
                );

                // Update data
                nonce_used.is_used = true;
                player_global.star = star;

                // Save models
                set!(world, (nonce_used));
            }
        } else {
            let player_previous_map_id = player_global.map_id;
            let player_previous = get!(world, (caller, player_previous_map_id), Player);
            assert_with_err(
                player_previous_map_id != map_id, Error::ALREADY_JOINED_IN, Option::None
            );
            assert_with_err(
                player_previous.is_joined_map == IsPlayerJoined::Joined,
                Error::INVALID_CASE_JOIN_MAP,
                Option::None
            );
        }

        // Move/Set all the player's dragons to this map
        let mut is_recalculate_cp_needed: bool = false;
        let mut old_map_id: usize = 0;
        let mut i: u32 = 0;
        loop {
            if (i == player_global.num_dragons_owned) {
                break;
            }

            // Get the dragon
            let player_dragon_owned_token_id = get!(world, (caller, i), PlayerDragonOwned)
                .dragon_token_id;
            let mut dragon = get!(world, (player_dragon_owned_token_id), Dragon);

            // Process logic
            if (dragon.map_id.is_non_zero() && dragon.map_id != map_id) {
                if (old_map_id != 0) {
                    assert_with_err(
                        dragon.map_id == old_map_id, Error::INVALID_CASE_JOIN_MAP, Option::None
                    );
                }
                is_recalculate_cp_needed = true;
                old_map_id = dragon.map_id;
            }
            dragon.map_id = map_id;
            set!(world, (dragon));

            i = i + 1;
        };

        // Recalculate the CP
        if (is_recalculate_cp_needed) {
            // Old map
            let mut player_old_map = get!(world, (caller, old_map_id), Player);
            player_old_map_contribution_points_before = player_old_map.contribution_points;
            let mut old_map = get!(world, (old_map_id), MapInfo);
            PlayerTrait::_update_contribution_points(ref player_old_map, ref old_map, 0, 0);

            // New map
            let total_dragark_nft_level = DragonTrait::_calculate_total_dragark_nft_level(
                world, player_global
            );
            let total_bonus_element_nft = DragonTrait::_calculate_total_bonus_element_nft(
                world, player_global
            );
            PlayerTrait::_update_contribution_points(
                ref player, ref map, total_dragark_nft_level, total_bonus_element_nft
            );

            // Save models
            set!(world, (player_old_map));
            set!(world, (old_map));
            set!(world, (player));
            set!(world, (map));
        }

        // Update player global
        player_global.map_id = map_id;
        set!(world, (player_global));

        if (player.is_joined_map == IsPlayerJoined::NotJoined) {
            // Check the map is full player or not
            assert_with_err(map.total_player < 100, Error::MAP_FULL_PLAYER, Option::None);

            // Get 1 island from PlayerIslandSlot for player
            let mut block_id = ((map.cur_block_coordinates.x / 12) + 1)
                + (map.cur_block_coordinates.y / 12) * 23;
            let mut is_empty = get!(world, (map_id, block_id), PlayerIslandSlot)
                .island_ids
                .is_empty();
            if (is_empty) {
                if (map.cur_block_coordinates.x == 264 && map.cur_block_coordinates.y == 264) {
                    panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
                }
                while (is_empty) {
                    let mut next_block_direction_model = get!(world, (map_id), NextBlockDirection);
                    Self::_move_next_block(ref next_block_direction_model, ref map, world);

                    block_id = ((map.cur_block_coordinates.x / 12) + 1)
                        + (map.cur_block_coordinates.y / 12) * 23;
                    is_empty = get!(world, (map_id, block_id), PlayerIslandSlot)
                        .island_ids
                        .is_empty();

                    // Break if there's no more available
                    if (block_id == 529 && is_empty) {
                        panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
                    }
                }
            }
            let mut player_island_slot = get!(world, (map_id, block_id), PlayerIslandSlot);
            let island_id = player_island_slot.island_ids.pop_front().unwrap();
            set!(world, (player_island_slot));

            // Get player's island & initialize the island for player
            let mut player_island = get!(world, (map_id, island_id), Island);
            player_island.owner = caller;
            player_island.cur_resources.food = player_island.max_resources.food;
            set!(world, (player_island));

            // Save PlayerIslandOwned model
            set!(
                world,
                (PlayerIslandOwned {
                    map_id, player: caller, index: 0, island_id: player_island.island_id
                })
            );

            // Save Player model
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            player.is_joined_map = IsPlayerJoined::Joined;
            player.area_opened = 0;
            player.num_islands_owned = 1;
            player.points = island_level_to_points(player_island.level);
            player.is_claim_default_dragon = false;
            // Energy
            player.energy = 15;
            player.energy_reset_time = daily_timestamp;
            player.energy_bought_num = 0;
            // Stone
            player.stone_rate = 0;
            player.current_stone = 0;
            player.stone_updated_time = 0;
            player.stone_cap = 5_000_000_000;
            // Dragark Stone
            player.dragark_stone_balance = 10_000_000;
            // Account Level
            player.account_level = 1;
            player.account_exp = 0;
            player.account_lvl_upgrade_claims = 0;
            // Invitation Level
            player.invitation_level = 1;
            player.invitation_exp = 0;
            player.invitation_lvl_upgrade_claims = 0;
            // Contribution Point
            player.contribution_points = 0;

            // Save AchievementTracking model
            set!(
                world,
                (AchievementTracking {
                    player: caller,
                    map_id,
                    achievement_id: OWN_ISLAND_ACHIEVEMENT_ID,
                    current_value: 1,
                    claimed_times: 0
                })
            );
            set!(
                world,
                (AchievementTracking {
                    player: caller,
                    map_id,
                    achievement_id: REACH_ACCOUNT_LVL_ACHIEVEMENT_ID,
                    current_value: 1,
                    claimed_times: 0
                })
            );

            // Update the latest map's data
            map.total_player += 1;
            map.derelict_islands_num -= 1;
            map.total_join_map += 1;

            // Scout the newly initialized island sub-sub block and 8 surrounding one (if
            // possible)
            let map_coordinates = map.map_coordinates;
            let map_sizes = map.map_sizes;

            let island_position_x = player_island.position.x;
            let island_position_y = player_island.position.y;

            assert_with_err(
                island_position_x >= map_coordinates.x && island_position_x < map_coordinates.x
                    + map_sizes
                        && island_position_y >= map_coordinates.y
                        && island_position_y < map_coordinates.y
                    + map_sizes,
                Error::INVALID_POSITION,
                Option::None
            );

            // Find center position
            let mut center_position = Position { x: 0, y: 0 };

            if (island_position_x % 3 == 0) {
                center_position.x = island_position_x + 1;
            } else if (island_position_x % 3 == 1) {
                center_position.x = island_position_x;
            } else if (island_position_x % 3 == 2) {
                center_position.x = island_position_x - 1;
            }

            if (island_position_y % 3 == 0) {
                center_position.y = island_position_y + 1;
            } else if (island_position_y % 3 == 1) {
                center_position.y = island_position_y;
            } else if (island_position_y % 3 == 2) {
                center_position.y = island_position_y - 1;
            }

            // Scout the center positions
            let scout_id_1 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x, y: center_position.y },
                cur_timestamp
            );
            scouted_destinations.append(Position { x: center_position.x, y: center_position.y });
            scout_ids.append(scout_id_1);

            let scout_id_2 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x + 3, y: center_position.y },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x + 3, y: center_position.y });
            scout_ids.append(scout_id_2);

            let scout_id_3 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x, y: center_position.y - 3 },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x, y: center_position.y - 3 });
            scout_ids.append(scout_id_3);

            let scout_id_4 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x - 3, y: center_position.y },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x - 3, y: center_position.y });
            scout_ids.append(scout_id_4);

            let scout_id_5 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x, y: center_position.y + 3 },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x, y: center_position.y + 3 });
            scout_ids.append(scout_id_5);
        }

        (
            scouted_destinations,
            scout_ids,
            is_recalculate_cp_needed,
            old_map_id,
            player_old_map_contribution_points_before
        )
    }

    // Internal function to handle `re_join_map` logic
    fn re_join_map(
        ref player: Player,
        ref map: MapInfo,
        ref mission_tracking: MissionTracking,
        world: IWorldDispatcher,
        cur_timestamp: u64
    ) -> (Array<Position>, Array<felt252>) {
        let caller = player.player;
        let map_id = map.map_id;
        let daily_timestamp = cur_timestamp
            - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
        let mut scouted_destinations: Array<Position> = array![];
        let mut scout_ids: Array<felt252> = array![];

        // Get 1 island from PlayerIslandSlot for player
        let mut block_id = ((map.cur_block_coordinates.x / 12) + 1)
            + (map.cur_block_coordinates.y / 12) * 23;
        let mut is_empty = get!(world, (map_id, block_id), PlayerIslandSlot).island_ids.is_empty();
        if (is_empty) {
            if (map.cur_block_coordinates.x == 264 && map.cur_block_coordinates.y == 264) {
                panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
            }
            while (is_empty) {
                let mut next_block_direction_model = get!(world, (map_id), NextBlockDirection);
                Self::_move_next_block(ref next_block_direction_model, ref map, world);

                block_id = ((map.cur_block_coordinates.x / 12) + 1)
                    + (map.cur_block_coordinates.y / 12) * 23;
                is_empty = get!(world, (map_id, block_id), PlayerIslandSlot).island_ids.is_empty();

                // Break if there's no more available
                if (block_id == 529 && is_empty) {
                    panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN, Option::None);
                }
            }
        }
        let mut player_island_slot = get!(world, (map_id, block_id), PlayerIslandSlot);
        let island_id = player_island_slot.island_ids.pop_front().unwrap();
        set!(world, (player_island_slot));

        // Get player's island & initialize the island for player
        let mut player_island = get!(world, (map_id, island_id), Island);
        player_island.owner = caller;
        player_island.cur_resources.food = player_island.max_resources.food;

        // Save PlayerIslandOwned model
        set!(
            world,
            (PlayerIslandOwned {
                map_id, player: caller, index: 0, island_id: player_island.island_id
            })
        );

        // Save Island model
        set!(world, (player_island));

        // Save Player model
        player.num_islands_owned = 1;
        player.points += island_level_to_points(player_island.level);
        player.energy = 15;
        player.energy_reset_time = daily_timestamp;

        // Update the latest map's data
        map.derelict_islands_num -= 1;
        map.total_re_join_map += 1;

        // Scout the newly initialized island sub-sub block and 8 surrounding one (if possible)
        let map_coordinates = map.map_coordinates;
        let map_sizes = map.map_sizes;

        let island_position_x = player_island.position.x;
        let island_position_y = player_island.position.y;

        assert_with_err(
            island_position_x >= map_coordinates.x && island_position_x < map_coordinates.x
                + map_sizes
                    && island_position_y >= map_coordinates.y
                    && island_position_y < map_coordinates.y
                + map_sizes,
            Error::INVALID_POSITION,
            Option::None
        );

        // Find center position
        let mut center_position = Position { x: 0, y: 0 };

        if (island_position_x % 3 == 0) {
            center_position.x = island_position_x + 1;
        } else if (island_position_x % 3 == 1) {
            center_position.x = island_position_x;
        } else if (island_position_x % 3 == 2) {
            center_position.x = island_position_x - 1;
        }

        if (island_position_y % 3 == 0) {
            center_position.y = island_position_y + 1;
        } else if (island_position_y % 3 == 1) {
            center_position.y = island_position_y;
        } else if (island_position_y % 3 == 2) {
            center_position.y = island_position_y - 1;
        }

        // Scout the center positions

        // Scout the 1st position
        let first_player_scout_info = get!(
            world, (map_id, caller, center_position.x, center_position.y), PlayerScoutInfo
        );
        if (first_player_scout_info.is_scouted == IsScouted::NotScouted) {
            let scout_id_1 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x, y: center_position.y },
                cur_timestamp
            );
            scouted_destinations.append(Position { x: center_position.x, y: center_position.y });
            scout_ids.append(scout_id_1);
        }

        // Scout the 2nd position
        let second_player_scout_info = get!(
            world, (map_id, caller, center_position.x + 3, center_position.y), PlayerScoutInfo
        );
        if (center_position.x
            + 3 < map_coordinates.x
            + map_sizes && second_player_scout_info.is_scouted == IsScouted::NotScouted) {
            let scout_id_2 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x + 3, y: center_position.y },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x + 3, y: center_position.y });
            scout_ids.append(scout_id_2);
        }

        // Scout the 3rd position
        let third_player_scout_info = get!(
            world, (map_id, caller, center_position.x, center_position.y - 3), PlayerScoutInfo
        );
        if (center_position.y
            - 3 >= map_coordinates.y
                && third_player_scout_info.is_scouted == IsScouted::NotScouted) {
            let scout_id_3 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x, y: center_position.y - 3 },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x, y: center_position.y - 3 });
            scout_ids.append(scout_id_3);
        }

        // Scout the 4th position
        let forth_player_scout_info = get!(
            world, (map_id, caller, center_position.x - 3, center_position.y), PlayerScoutInfo
        );
        if (center_position.x
            - 3 >= map_coordinates.x
                && forth_player_scout_info.is_scouted == IsScouted::NotScouted) {
            let scout_id_4 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x - 3, y: center_position.y },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x - 3, y: center_position.y });
            scout_ids.append(scout_id_4);
        }

        // Scout the 5th position
        let fifth_player_scout_info = get!(
            world, (map_id, caller, center_position.x, center_position.y + 3), PlayerScoutInfo
        );
        if (center_position.y
            + 3 < map_coordinates.y
            + map_sizes && fifth_player_scout_info.is_scouted == IsScouted::NotScouted) {
            let scout_id_5 = ScoutTrait::scout(
                ref player,
                ref map,
                ref mission_tracking,
                world,
                Position { x: center_position.x, y: center_position.y + 3 },
                cur_timestamp
            );
            scouted_destinations
                .append(Position { x: center_position.x, y: center_position.y + 3 });
            scout_ids.append(scout_id_5);
        }

        // Save models
        set!(world, (player));
        set!(world, (map));

        (scouted_destinations, scout_ids)
    }

    // Internal function to handle `init_new_map` logic
    fn init_new_map(world: IWorldDispatcher) -> usize {
        let cur_block_timestamp = get_block_timestamp();

        // Get u32 max
        let u32_max = BoundedU32::max();

        // Generate MAP_ID
        let mut data_map_id: Array<felt252> = array!['MAP_ID', cur_block_timestamp.into()];
        let map_id_u256: u256 = poseidon::poseidon_hash_span(data_map_id.span())
            .try_into()
            .unwrap();
        let map_id: usize = (map_id_u256 % u32_max.into()).try_into().unwrap();

        // Check whether the map id has been initialized or not
        assert_with_err(
            get!(world, (map_id), MapInfo).is_initialized == IsMapInitialized::NotInitialized,
            Error::MAP_ALREADY_INITIALIZED,
            Option::None
        );

        // Init initial map size & coordinates
        let map_sizes = 23
            * 3
            * 4; // 23 blocks * 3 sub-blocks * 4 sub-sub-blocks ~ 276 x 276 sub-sub-blocks
        let cur_block_coordinates = Position {
            x: 132, y: 132
        }; // The starting block is in the middle of the map, with the ID of 265 ~ (132, 132)
        let cur_island_block_coordinates = cur_block_coordinates;
        let map_coordinates = Position { x: 0, y: 0 };

        // Init next block direction
        let block_direction_count = 0;
        let right_1 = 1; // 1
        let down_2 = 1 + (block_direction_count * 2); // 1
        let left_3 = 2 + (block_direction_count * 2); // 2
        let up_4 = 2 + (block_direction_count * 2); // 2
        let right_5 = 2 + (block_direction_count * 2); // 2

        // Save NextBlockDirection model
        set!(world, (NextBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 }));

        // Init next block direction (island)
        let island_block_direction_count = 0;
        let right_1 = 1; // 1
        let down_2 = 1 + (island_block_direction_count * 2); // 1
        let left_3 = 2 + (island_block_direction_count * 2); // 2
        let up_4 = 2 + (island_block_direction_count * 2); // 2
        let right_5 = 2 + (island_block_direction_count * 2); // 2

        // Save NextIslandBlockDirection model
        set!(world, (NextIslandBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 }));

        // Save MapInfo model
        let mut map: MapInfo = MapInfo {
            map_id,
            is_initialized: IsMapInitialized::Initialized,
            total_player: 0,
            total_island: 0,
            total_dragon: 0,
            total_scout: 0,
            total_journey: 0,
            total_treasure_hunt: 0,
            total_activate_dragon: 0,
            total_deactivate_dragon: 0,
            total_join_map: 0,
            total_re_join_map: 0,
            total_start_journey: 0,
            total_finish_journey: 0,
            total_claim_resources: 0,
            total_claim_dragon: 0,
            total_activate_shield: 0,
            total_deactivate_shield: 0,
            total_claim_pool_share: 0,
            total_activate_element_nft: 0,
            total_account_exp: 0,
            total_contribution_points: 0,
            map_sizes,
            map_coordinates,
            cur_block_coordinates,
            block_direction_count,
            derelict_islands_num: 0,
            cur_island_block_coordinates,
            island_block_direction_count,
            dragon_token_id_counter: 99999
        };

        // Generate prior islands on the first middle blocks of the map
        IslandTrait::gen_island_per_block(ref map, world, IslandType::Normal, true);

        // Initialize mission
        MissionTrait::update_mission(
            world, DAILY_LOGIN_MISSION_ID, array![0], array![100_000_000], array![0], array![50]
        );
        MissionTrait::update_mission(
            world,
            SCOUT_MISSION_ID,
            array![5, 10, 20],
            array![25_000_000, 50_000_000, 100_000_000],
            array![0, 0, 0],
            array![50, 50, 50]
        );
        MissionTrait::update_mission(
            world,
            START_JOURNEY_MISSION_ID,
            array![1, 3, 5],
            array![25_000_000, 50_000_000, 100_000_000],
            array![0, 0, 0],
            array![50, 50, 50]
        );

        // Initialize achievement
        AchievementTrait::update_achievement(
            world,
            REDEEM_INVITATION_CODE_ACHIEVEMENT_ID,
            array![1],
            array![0],
            array![50_000_000],
            array![1]
        );
        AchievementTrait::update_achievement(
            world,
            UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID,
            array![5, 10, 20],
            array![0, 0, 0],
            array![5_000_000, 25_000_000, 75_000_000],
            array![0, 1, 1]
        );
        AchievementTrait::update_achievement(
            world,
            OWN_ISLAND_ACHIEVEMENT_ID,
            array![10, 30, 50],
            array![0, 0, 0],
            array![5_000_000, 10_000_000, 25_000_000],
            array![0, 0, 1]
        );
        AchievementTrait::update_achievement(
            world,
            SEND_DRAGARK_TREASURE_HUNT_TIME_ACHIEVEMENT_ID,
            array![1, 10, 50],
            array![0, 0, 0],
            array![5_000_000, 10_000_000, 50_000_000],
            array![0, 0, 1]
        );
        AchievementTrait::update_achievement(
            world,
            REACH_ACCOUNT_LVL_ACHIEVEMENT_ID,
            array![5, 10, 15],
            array![0, 0, 0],
            array![5_000_000, 10_000_000, 15_000_000],
            array![0, 1, 1]
        );
        AchievementTrait::update_achievement(
            world,
            UPGRADE_DRAGARK_TIME_ACHIEVEMENT_ID,
            array![1, 15, 30],
            array![0, 0, 0],
            array![5_000_000, 10_000_000, 20_000_000],
            array![0, 1, 1]
        );

        // Initialize account level reward
        PlayerTrait::update_account_level_reward(world, 2, 50_000_000, 2_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 3, 75_000_000, 4_000_000, 1);
        PlayerTrait::update_account_level_reward(world, 4, 100_000_000, 6_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 5, 125_000_000, 8_000_000, 1);
        PlayerTrait::update_account_level_reward(world, 6, 150_000_000, 10_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 7, 175_000_000, 12_000_000, 1);
        PlayerTrait::update_account_level_reward(world, 8, 200_000_000, 14_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 9, 225_000_000, 16_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 10, 250_000_000, 18_000_000, 1);
        PlayerTrait::update_account_level_reward(world, 11, 275_000_000, 20_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 12, 300_000_000, 22_000_000, 1);
        PlayerTrait::update_account_level_reward(world, 13, 325_000_000, 24_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 14, 350_000_000, 26_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 15, 375_000_000, 28_000_000, 1);
        PlayerTrait::update_account_level_reward(world, 16, 400_000_000, 30_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 17, 425_000_000, 32_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 18, 450_000_000, 34_000_000, 1);
        PlayerTrait::update_account_level_reward(world, 19, 475_000_000, 36_000_000, 0);
        PlayerTrait::update_account_level_reward(world, 20, 500_000_000, 38_000_000, 1);

        // Initialize invitation level reward
        PlayerTrait::update_invitation_level_reward(world, 2, 200_000_000, 20_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 3, 300_000_000, 40_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 4, 400_000_000, 60_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 5, 500_000_000, 80_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 6, 700_000_000, 100_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 7, 900_000_000, 120_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 8, 1_200_000_000, 140_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 9, 1_600_000_000, 160_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 10, 2_000_000_000, 180_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 11, 2_000_000_000, 200_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 12, 2_000_000_000, 220_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 13, 2_000_000_000, 240_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 14, 2_000_000_000, 260_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 15, 2_000_000_000, 280_000_000, 1);
        PlayerTrait::update_invitation_level_reward(world, 16, 2_000_000_000, 300_000_000, 1);

        // Initialize Pool Share info
        let start_time_pool_1 = cur_block_timestamp;
        let finish_time_pool_1 = start_time_pool_1 + 345_600;
        let start_time_pool_2 = finish_time_pool_1;
        let finish_time_pool_2 = start_time_pool_2 + 345_600;

        PlayerTrait::update_pool_share_info(
            world, 1, 1, start_time_pool_1, finish_time_pool_1, 0, 10_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 1, 2, start_time_pool_1, finish_time_pool_1, 200_000, 100_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 1, 3, start_time_pool_1, finish_time_pool_1, 500_000, 300_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 1, 4, start_time_pool_1, finish_time_pool_1, 1_500_000, 1_000_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 1, 5, start_time_pool_1, finish_time_pool_1, 5_000_000, 3_000_000_000_000
        );

        PlayerTrait::update_pool_share_info(
            world, 2, 1, start_time_pool_2, finish_time_pool_2, 0, 10_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 2, 2, start_time_pool_2, finish_time_pool_2, 200_000, 100_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 2, 3, start_time_pool_2, finish_time_pool_2, 500_000, 300_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 2, 4, start_time_pool_2, finish_time_pool_2, 1_500_000, 1_000_000_000_000
        );
        PlayerTrait::update_pool_share_info(
            world, 2, 5, start_time_pool_2, finish_time_pool_2, 5_000_000, 3_000_000_000_000
        );

        map_id
    }

    // Internal function to handle `_move_next_block` logic
    fn _move_next_block(
        ref block_direction: NextBlockDirection, ref map: MapInfo, world: IWorldDispatcher
    ) {
        let right_1 = block_direction.right_1;
        let down_2 = block_direction.down_2;
        let left_3 = block_direction.left_3;
        let up_4 = block_direction.up_4;
        let right_5 = block_direction.right_5;
        if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block to the right
            map.cur_block_coordinates.x += 3 * 4;
            block_direction.right_1 -= 1;
        } else if (right_1 == 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block down
            map.cur_block_coordinates.y -= 3 * 4;
            block_direction.down_2 -= 1;
        } else if (right_1 == 0 && down_2 == 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block to the left
            map.cur_block_coordinates.x -= 3 * 4;
            block_direction.left_3 -= 1;
        } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block up
            map.cur_block_coordinates.y += 3 * 4;
            block_direction.up_4 -= 1;
        } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 != 0) {
            // Move the current block to the right
            map.cur_block_coordinates.x += 3 * 4;
            block_direction.right_5 -= 1;
        } else {
            panic_by_err(Error::INVALID_CASE_BLOCK_DIRECTION, Option::None);
        }

        if (block_direction.right_1 == 0
            && block_direction.down_2 == 0
            && block_direction.left_3 == 0
            && block_direction.up_4 == 0
            && block_direction.right_5 == 0) {
            map.block_direction_count += 1;
            block_direction.right_1 = 1;
            block_direction.down_2 = 1 + (map.block_direction_count * 2);
            block_direction.left_3 = 2 + (map.block_direction_count * 2);
            block_direction.up_4 = 2 + (map.block_direction_count * 2);
            block_direction.right_5 = 2 + (map.block_direction_count * 2);
        }

        // Save models
        set!(world, (block_direction));
    }

    // Internal function to handle `_move_next_island_block` logic
    fn _move_next_island_block(
        ref island_block_direction: NextIslandBlockDirection,
        ref map: MapInfo,
        world: IWorldDispatcher
    ) {
        let right_1 = island_block_direction.right_1;
        let down_2 = island_block_direction.down_2;
        let left_3 = island_block_direction.left_3;
        let up_4 = island_block_direction.up_4;
        let right_5 = island_block_direction.right_5;
        if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block to the right
            map.cur_island_block_coordinates.x += 3 * 4;
            island_block_direction.right_1 -= 1;
        } else if (right_1 == 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block down
            map.cur_island_block_coordinates.y -= 3 * 4;
            island_block_direction.down_2 -= 1;
        } else if (right_1 == 0 && down_2 == 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block to the left
            map.cur_island_block_coordinates.x -= 3 * 4;
            island_block_direction.left_3 -= 1;
        } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 != 0 && right_5 != 0) {
            // Move the current block up
            map.cur_island_block_coordinates.y += 3 * 4;
            island_block_direction.up_4 -= 1;
        } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 != 0) {
            // Move the current block to the right
            map.cur_island_block_coordinates.x += 3 * 4;
            island_block_direction.right_5 -= 1;
        } else {
            panic_by_err(Error::INVALID_CASE_BLOCK_DIRECTION, Option::None);
        }

        if (island_block_direction.right_1 == 0
            && island_block_direction.down_2 == 0
            && island_block_direction.left_3 == 0
            && island_block_direction.up_4 == 0
            && island_block_direction.right_5 == 0) {
            map.island_block_direction_count += 1;
            island_block_direction.right_1 = 1;
            island_block_direction.down_2 = 1 + (map.island_block_direction_count * 2);
            island_block_direction.left_3 = 2 + (map.island_block_direction_count * 2);
            island_block_direction.up_4 = 2 + (map.island_block_direction_count * 2);
            island_block_direction.right_5 = 2 + (map.island_block_direction_count * 2);
        }

        // Save models
        set!(world, (island_block_direction));
    }
}
