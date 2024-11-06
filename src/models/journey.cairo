// Core imports
use core::num::traits::Sqrt;
use poseidon::PoseidonTrait;

// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{
        achievement::{AchievementTracking, AchievementTrait}, dragon::{Dragon, DragonState},
        island::{Island, PlayerIslandSlot, Resource, ResourceClaimType}, map::MapInfo,
        mission::{MissionTracking, MissionTrait}, player::{Player, PlayerIslandOwned, PlayerTrait},
        position::Position
    },
    constants::{
        START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, OWN_ISLAND_ACHIEVEMENT_ID, island_level_to_points
    },
    errors::{Error, assert_with_err, panic_by_err}
};

// Models
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Journey {
    #[key]
    map_id: usize,
    #[key]
    journey_id: felt252,
    owner: ContractAddress,
    dragon_token_id: u128,
    dragon_model_id: felt252,
    carrying_resources: Resource,
    island_from_id: usize,
    island_from_position: Position,
    island_from_owner: ContractAddress,
    island_to_id: usize,
    island_to_position: Position,
    island_to_owner: ContractAddress,
    start_time: u64,
    finish_time: u64,
    attack_type: AttackType,
    attack_result: AttackResult,
    status: JourneyStatus
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum AttackType {
    #[default]
    None,
    Unknown,
    DerelictIslandAttack,
    PlayerIslandAttack
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum AttackResult {
    #[default]
    None,
    Unknown,
    Win,
    Lose
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum JourneyStatus {
    #[default]
    None,
    Started,
    Finished,
    Cancelled
}

// Impls
#[generate_trait]
impl JourneyImpl of JourneyTrait {
    // Internal function to handle `start_journey` logic
    fn start_journey(
        ref dragon: Dragon,
        ref island_from: Island,
        ref map: MapInfo,
        ref mission_tracking: MissionTracking,
        world: IWorldDispatcher,
        island_to: Island,
        resources: Resource,
        cur_block_timestamp: u64
    ) -> Journey {
        let caller = dragon.owner;
        let map_id = map.map_id;
        let daily_timestamp = cur_block_timestamp
            - ((cur_block_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);

        // Update the island_from resources
        island_from.cur_resources.food -= resources.food;

        // Verify & calculate the distance between the 2 islands
        let island_from_position = island_from.position;
        let island_to_position = island_to.position;

        assert_with_err(
            island_from_position.x != island_to_position.x
                || island_from_position.y != island_to_position.y,
            Error::TRANSPORT_TO_THE_SAME_DESTINATION,
            Option::None
        );

        let mut x_distance = 0;
        if (island_to_position.x >= island_from_position.x) {
            x_distance = island_to_position.x - island_from_position.x;
        } else {
            x_distance = island_from_position.x - island_to_position.x;
        }

        let mut y_distance = 0;
        if (island_to_position.y >= island_from_position.y) {
            y_distance = island_to_position.y - island_from_position.y;
        } else {
            y_distance = island_from_position.y - island_to_position.y;
        }

        let distance = Sqrt::sqrt(x_distance * x_distance + y_distance * y_distance);
        let distance: u32 = distance.into();
        assert_with_err(distance > 0, Error::INVALID_DISTANCE, Option::None);

        // Decide the speed of the dragon
        let mut speed = dragon.speed;
        if (resources.food > dragon.carrying_capacity
            && resources.food <= (dragon.carrying_capacity * 150 / 100)) {
            speed = speed * 75 / 100;
        } else if (resources.food > (dragon.carrying_capacity * 150 / 100)) {
            speed = speed * 50 / 100;
        }
        assert_with_err(speed > 0, Error::INVALID_SPEED, Option::None);

        // Calculate the time for the dragon to fly
        let time = (((distance * 6000) + 700 - (3 * speed.into())) / (700 + (3 * speed.into())))
            * 2;

        let start_time = cur_block_timestamp;
        let finish_time = start_time + time.into();

        let data_journey_id: Array<felt252> = array![
            (map.total_journey + 1).into(),
            'data_journey_id',
            map_id.into(),
            cur_block_timestamp.into()
        ];
        let journey_id = poseidon::poseidon_hash_span(data_journey_id.span());

        // Update the dragon's state and save Dragon model
        dragon.state = DragonState::Flying;
        set!(world, (dragon));

        // Update mission tracking
        MissionTrait::_update_mission_tracking(ref mission_tracking, world, daily_timestamp);

        // Save Journey
        let attack_type = AttackType::Unknown;
        let attack_result = AttackResult::Unknown;
        let status = JourneyStatus::Started;

        let journey = Journey {
            map_id,
            journey_id,
            owner: caller,
            dragon_token_id: dragon.dragon_token_id,
            dragon_model_id: dragon.model_id,
            carrying_resources: resources,
            island_from_id: island_from.island_id,
            island_from_position,
            island_from_owner: island_from.owner,
            island_to_id: island_to.island_id,
            island_to_position,
            island_to_owner: island_to.owner,
            start_time,
            finish_time,
            attack_type,
            attack_result,
            status
        };

        set!(world, (journey));

        // Update map
        map.total_journey += 1;
        map.total_start_journey += 1;

        // Save models
        set!(world, (island_from));
        set!(world, (map));
        set!(world, (mission_tracking));

        journey
    }

    // Internal function to handle `finish_journey` logic
    fn finish_journey(
        ref capturing_player: Player,
        ref dragon: Dragon,
        ref journey_info: Journey,
        ref map: MapInfo,
        world: IWorldDispatcher,
        cur_block_timestamp: u64
    ) -> ContractAddress {
        let map_id = map.map_id;
        let mut island_to = get!(world, (map_id, journey_info.island_to_id), Island);
        let mut island_from = get!(world, (map_id, journey_info.island_from_id), Island);
        let resources = journey_info.carrying_resources;
        let mut journey_captured_player: ContractAddress = Zeroable::zero();
        let mut points = 0;

        // If the player has no islands left when the journey hasn't been finished, cancel the
        // journey
        if (capturing_player.num_islands_owned == 0) {
            journey_info.attack_type = AttackType::None;
            journey_info.attack_result = AttackResult::None;
            journey_info.status = JourneyStatus::Cancelled;
        } else {
            // Check time
            assert_with_err(
                cur_block_timestamp >= journey_info.finish_time - 5,
                Error::JOURNEY_IN_PROGRESS,
                Option::None
            );

            // Decide whether the Journey is Transport/Attack
            if (island_to.owner == journey_info.owner) {
                journey_info.attack_type = AttackType::None;
            } else if (island_to.owner != Zeroable::zero()) {
                journey_info.attack_type = AttackType::PlayerIslandAttack;
            } else if (island_to.owner == Zeroable::zero()) {
                journey_info.attack_type = AttackType::DerelictIslandAttack;
            }

            // If the attack_type is none => Transport
            if (journey_info.attack_type == AttackType::None) {
                // Update island_to resources
                if (island_to.cur_resources.food + resources.food <= island_to.max_resources.food) {
                    island_to.cur_resources.food += resources.food;
                } else if (island_to.cur_resources.food
                    + resources.food > island_to.max_resources.food) {
                    island_to.cur_resources.food = island_to.max_resources.food;
                } else {
                    panic_by_err(Error::INVALID_CASE_RESOURCES_UPDATE, Option::None);
                }

                journey_info.attack_result = AttackResult::None;
                journey_info.status = JourneyStatus::Finished;
            } else { // Else => Capture
                // Check condition
                assert_with_err(
                    journey_info.attack_type == AttackType::DerelictIslandAttack
                        || journey_info.attack_type == AttackType::PlayerIslandAttack,
                    Error::INVALID_ATTACK_TYPE,
                    Option::None
                );

                // Update journey captured player
                journey_captured_player = island_to.owner;

                // Handle whether the island to has shield or not
                if (cur_block_timestamp <= island_to.shield_protection_time) {
                    journey_info.attack_result = AttackResult::Lose;
                } else {
                    // Calculate power rating
                    let player_power_rating: u32 = journey_info.carrying_resources.food
                        + dragon.attack.into();
                    let island_power_rating: u32 = island_to.cur_resources.food;

                    // Decide whether player wins or loses and update state
                    if (player_power_rating > island_power_rating) {
                        // Set the attack result
                        journey_info.attack_result = AttackResult::Win;

                        // Get attack diff
                        let attack_diff = player_power_rating - island_power_rating;

                        // Set the captured island resources
                        if (attack_diff < journey_info.carrying_resources.food) {
                            if (attack_diff >= island_to.max_resources.food) {
                                island_to.cur_resources.food = island_to.max_resources.food;
                            } else {
                                island_to.cur_resources.food = attack_diff;
                            }
                        } else {
                            if (journey_info
                                .carrying_resources
                                .food >= island_to
                                .max_resources
                                .food) {
                                island_to.cur_resources.food = island_to.max_resources.food;
                            } else {
                                island_to.cur_resources.food = journey_info.carrying_resources.food;
                            }
                        }

                        // Update capturing player island owned
                        let mut capturing_player_island_owned = get!(
                            world,
                            (map_id, capturing_player.player, capturing_player.num_islands_owned),
                            PlayerIslandOwned
                        );
                        capturing_player_island_owned.island_id = island_to.island_id;

                        // Calculate points
                        points = island_level_to_points(island_to.level);

                        // Update stone
                        if (island_to.resources_claim_type == ResourceClaimType::Stone
                            || island_to.resources_claim_type == ResourceClaimType::Both) {
                            PlayerTrait::_update_stone_finish_journey(
                                ref capturing_player, island_to.level, true, cur_block_timestamp
                            );
                        }

                        if (journey_info.attack_type == AttackType::PlayerIslandAttack) {
                            let mut captured_player = get!(
                                world, (island_to.owner, map_id), Player
                            );
                            assert_with_err(
                                captured_player.player.is_non_zero(),
                                Error::INVALID_PLAYER_ADDRESS,
                                Option::None
                            );

                            // Update stone
                            if (island_to.resources_claim_type == ResourceClaimType::Stone
                                || island_to.resources_claim_type == ResourceClaimType::Both) {
                                PlayerTrait::_update_stone_finish_journey(
                                    ref captured_player, island_to.level, false, cur_block_timestamp
                                );
                            }

                            // Update captured player island owned
                            let mut i: u32 = 0;
                            loop {
                                if (i == captured_player.num_islands_owned) {
                                    break;
                                }
                                let island_owned_id = get!(
                                    world, (map_id, captured_player.player, i), PlayerIslandOwned
                                )
                                    .island_id;
                                if (island_owned_id == island_to.island_id) {
                                    break;
                                }
                                i = i + 1;
                            }; // Get the island captured index

                            let mut captured_player_island_owned = get!(
                                world, (map_id, captured_player.player, i), PlayerIslandOwned
                            );
                            if (i == captured_player.num_islands_owned - 1) {
                                delete!(world, (captured_player_island_owned));
                            } else {
                                let captured_player_last_island_owned = get!(
                                    world,
                                    (
                                        map_id,
                                        captured_player.player,
                                        captured_player.num_islands_owned - 1
                                    ),
                                    PlayerIslandOwned
                                );
                                captured_player_island_owned
                                    .island_id = captured_player_last_island_owned
                                    .island_id;
                                delete!(world, (captured_player_last_island_owned));
                                set!(world, (captured_player_island_owned));
                            }

                            captured_player.num_islands_owned -= 1;
                            captured_player.points -= points;
                            set!(world, (captured_player));
                        } else if (journey_info.attack_type == AttackType::DerelictIslandAttack) {
                            map.derelict_islands_num -= 1;

                            // If the island captured is in the PlayerIslandSlot, "delete" it
                            let island_to_block_id = ((island_to.position.x / 12) + 1)
                                + (island_to.position.y / 12) * 23;
                            let mut player_island_slot = get!(
                                world, (map_id, island_to_block_id), PlayerIslandSlot
                            );
                            let mut island_ids = player_island_slot.island_ids;
                            if (island_ids.len() == 3) {
                                let first_island_id = *island_ids.at(0);
                                let second_island_id = *island_ids.at(1);
                                let third_island_id = *island_ids.at(2);

                                if (island_to.island_id == first_island_id) {
                                    island_ids = array![second_island_id, third_island_id];
                                    set!(
                                        world,
                                        (PlayerIslandSlot {
                                            map_id, block_id: island_to_block_id, island_ids
                                        })
                                    );
                                } else if (island_to.island_id == second_island_id) {
                                    island_ids = array![first_island_id, third_island_id];
                                    set!(
                                        world,
                                        (PlayerIslandSlot {
                                            map_id, block_id: island_to_block_id, island_ids
                                        })
                                    );
                                } else if (island_to.island_id == third_island_id) {
                                    island_ids = array![first_island_id, second_island_id];
                                    set!(
                                        world,
                                        (PlayerIslandSlot {
                                            map_id, block_id: island_to_block_id, island_ids
                                        })
                                    );
                                }
                            } else if (island_ids.len() == 2) {
                                let first_island_id = *island_ids.at(0);
                                let second_island_id = *island_ids.at(1);

                                if (island_to.island_id == first_island_id) {
                                    island_ids = array![second_island_id];
                                    set!(
                                        world,
                                        (PlayerIslandSlot {
                                            map_id, block_id: island_to_block_id, island_ids
                                        })
                                    );
                                } else if (island_to.island_id == second_island_id) {
                                    island_ids = array![first_island_id];
                                    set!(
                                        world,
                                        (PlayerIslandSlot {
                                            map_id, block_id: island_to_block_id, island_ids
                                        })
                                    );
                                }
                            } else if (island_ids.len() == 1) {
                                let first_island_id = *island_ids.at(0);

                                if (island_to.island_id == first_island_id) {
                                    island_ids = array![];
                                    set!(
                                        world,
                                        (PlayerIslandSlot {
                                            map_id, block_id: island_to_block_id, island_ids
                                        })
                                    );
                                }
                            } else {
                                assert_with_err(
                                    island_ids.len() == 0,
                                    Error::INVALID_ISLAND_IDS_LENGTH,
                                    Option::None
                                );
                            }
                        }

                        // Set the owner of the captured island
                        island_to.owner = journey_info.owner;

                        capturing_player.num_islands_owned += 1;
                        capturing_player.points += points;

                        // Update achievement tracking
                        let mut achievement_tracking = get!(
                            world,
                            (capturing_player.player, map_id, OWN_ISLAND_ACHIEVEMENT_ID),
                            AchievementTracking
                        );
                        AchievementTrait::_update_achievement_tracking(
                            ref achievement_tracking, capturing_player.num_islands_owned
                        );

                        set!(world, (capturing_player_island_owned));
                        set!(world, (achievement_tracking));
                    } else {
                        // Set the attack result
                        journey_info.attack_result = AttackResult::Lose;

                        // Set the captured island resources
                        if (island_power_rating > player_power_rating && island_power_rating
                            - player_power_rating <= island_to.cur_resources.food) {
                            island_to.cur_resources.food = island_power_rating
                                - player_power_rating;
                        } else if (island_power_rating == player_power_rating) {
                            island_to.cur_resources.food = 0;
                        } else {
                            panic_by_err(Error::INVALID_CASE_POWER_RATING, Option::None);
                        }
                    }
                }

                // Update the journey's status
                journey_info.status = JourneyStatus::Finished;
            }
        }

        // Update the dragon's state
        dragon.state = DragonState::Idling;

        // Update journey info
        journey_info.island_from_owner = island_from.owner;
        journey_info.island_to_owner = island_to.owner;

        // Update map
        map.total_finish_journey += 1;

        // Save models
        set!(world, (island_to));
        set!(world, (dragon));
        set!(world, (capturing_player));
        set!(world, (journey_info));
        set!(world, (map));

        journey_captured_player
    }
}
