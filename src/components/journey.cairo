// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::{island::{Resource}, journey::{Journey}};

// Interface
#[starknet::interface]
trait IJourneyActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the Journey model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // * journey_id The ID of the journey
    // # Return
    // * Journey The Journey model
    fn get_journey(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, journey_id: felt252
    ) -> Journey;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for player to start a new journey
    // # Argument
    // * world The world address
    // * map_id The map_id to init action
    // * dragon_token_id ID of the specified dragon
    // * island_from_id ID of the starting island
    // * island_to_id ID of the destination island
    // * resources Specified amount of resources to carry (including foods & stones)
    // # Return
    // * bool Whether the tx successful or not
    fn start_journey(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        dragon_token_id: u128,
        island_from_id: usize,
        island_to_id: usize,
        resources: Resource
    ) -> felt252;

    // Function to finish a started journey
    // # Argument
    // * world The world address
    // * map_id The map_id to init action
    // * journey_id ID of the started journey
    // # Return
    // * bool Whether the tx successful or not
    fn finish_journey(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, journey_id: felt252
    ) -> bool;
}

// Component
#[starknet::component]
mod JourneyActionsComponent {
    // Core imports
    use core::Zeroable;
    use core::num::traits::Sqrt;
    use poseidon::PoseidonTrait;

    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        constants::{
            START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, START_JOURNEY_MISSION_ID,
            OWN_ISLAND_ACHIEVEMENT_ID
        },
        components::{
            player::{PlayerActionsComponent, PlayerActionsComponent::PlayerActionsInternalTrait},
            mission::{
                MissionActionsComponent, MissionActionsComponent::MissionActionsInternalTrait
            },
            achievement::{
                AchievementActionsComponent,
                AchievementActionsComponent::AchievementActionsInternalTrait
            },
            emitter::{EmitterTrait, EmitterComponent}
        },
        events::{JourneyStarted, JourneyFinished, PointsChanged},
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{MapInfo, IsMapInitialized},
            dragon::{Dragon, DragonState}, island::{Island, Resource, ResourceClaimType},
            player_island_owned::{PlayerIslandOwned},
            journey::{Journey, AttackType, AttackResult, JourneyStatus},
            player_island_slot::PlayerIslandSlot, position::{Position}, mission::MissionTracking,
            achievement::AchievementTracking
        },
        errors::{Error, assert_with_err, panic_by_err}, utils::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::IJourneyActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(JourneyActionsImpl)]
    impl JourneyActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl PlayerActions: PlayerActionsComponent::HasComponent<TContractState>,
        impl MissionActions: MissionActionsComponent::HasComponent<TContractState>,
        impl AchievementActions: AchievementActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IJourneyActions<ComponentState<TContractState>> {
        // See IJourneyActions-get_journey
        fn get_journey(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            journey_id: felt252
        ) -> Journey {
            get!(world, (map_id, journey_id), Journey)
        }

        // See IJourneyActions-start_journey
        fn start_journey(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            dragon_token_id: u128,
            island_from_id: usize,
            island_to_id: usize,
            resources: Resource
        ) -> felt252 {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player = get!(world, (caller, map_id), Player);
            let mut map = get!(world, (map_id), MapInfo);
            let player_global = get!(world, (caller), PlayerGlobal);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let mut mission_actions_comp = get_dep_component_mut!(ref self, MissionActions);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            let mut dragon = get!(world, (dragon_token_id), Dragon);
            let mut island_from = get!(world, (map_id, island_from_id), Island);
            let mut island_to = get!(world, (map_id, island_to_id), Island);

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Check if dragon exists in the map
            assert_with_err(dragon.map_id == map_id, Error::DRAGON_NOT_EXISTS, Option::None);

            // Check if island exists
            assert_with_err(
                island_from.claim_waiting_time >= 30 && island_to.claim_waiting_time >= 30,
                Error::ISLAND_NOT_EXISTS,
                Option::None
            );

            // Check the island is not protected by shield
            assert_with_err(
                cur_block_timestamp > island_from.shield_protection_time,
                Error::ISLAND_FROM_PROTECTED,
                Option::None
            );

            // Verify input
            assert_with_err(dragon_token_id.is_non_zero(), Error::INVALID_DRAGON_ID, Option::None);
            assert_with_err(island_from_id.is_non_zero(), Error::INVALID_ISLAND_FROM, Option::None);
            assert_with_err(island_to_id.is_non_zero(), Error::INVALID_ISLAND_TO, Option::None);

            // Check the 2 islands are different
            assert_with_err(
                island_from_id != island_to_id, Error::JOURNEY_TO_THE_SAME_ISLAND, Option::None
            );

            // Check if the player has the island_from
            assert_with_err(island_from.owner == caller, Error::NOT_OWN_ISLAND, Option::None);

            // Check the player has the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check the dragon is on idling state
            assert_with_err(
                dragon.state == DragonState::Idling, Error::DRAGON_IS_NOT_AVAILABLE, Option::None
            );

            // Check the island_from has enough resources
            let island_from_resources = island_from.cur_resources;
            assert_with_err(
                resources.food <= island_from_resources.food, Error::NOT_ENOUGH_FOOD, Option::None
            );

            // Update the island_from resources
            island_from.cur_resources.food -= resources.food;

            // Calculate the distance between the 2 islands
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

            // Calculate daily timestamp & update mission tracking
            let daily_timestamp = cur_block_timestamp
                - ((cur_block_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            let mut mission_tracking = get!(
                world, (caller, map_id, START_JOURNEY_MISSION_ID), MissionTracking
            );
            mission_tracking = mission_actions_comp
                ._update_mission_tracking(mission_tracking, world, daily_timestamp);

            // Save Journey
            let attack_type = AttackType::Unknown;
            let attack_result = AttackResult::Unknown;
            let status = JourneyStatus::Started;

            set!(
                world,
                (Journey {
                    map_id,
                    journey_id,
                    owner: caller,
                    dragon_token_id,
                    dragon_model_id: dragon.model_id,
                    carrying_resources: resources,
                    island_from_id,
                    island_from_position,
                    island_from_owner: island_from.owner,
                    island_to_id,
                    island_to_position,
                    island_to_owner: island_to.owner,
                    start_time,
                    finish_time,
                    attack_type,
                    attack_result,
                    status
                })
            );

            // Update map
            map.total_journey += 1;
            map.total_start_journey += 1;

            // Save models
            set!(world, (island_from));
            set!(world, (map));
            set!(world, (mission_tracking));

            // Emit events
            emitter_comp
                .emit_journey_started(
                    world,
                    JourneyStarted {
                        map_id,
                        player: caller,
                        journey_id,
                        dragon_token_id,
                        carrying_resources: resources,
                        island_from_id,
                        island_from_position,
                        island_from_owner: island_from.owner,
                        island_to_id,
                        island_to_position,
                        island_to_owner: island_to.owner,
                        start_time,
                        finish_time,
                        attack_type,
                        attack_result,
                        status
                    }
                );

            journey_id
        }

        // See IJourneyActions-finish_journey
        fn finish_journey(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            journey_id: felt252
        ) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let mut player_actions_comp = get_dep_component_mut!(ref self, PlayerActions);
            let mut achievement_actions_comp = get_dep_component_mut!(ref self, AchievementActions);
            let mut points = 0;

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Verify input
            assert_with_err(journey_id.is_non_zero(), Error::INVALID_JOURNEY_ID, Option::None);
            let mut journey_info = get!(world, (map_id, journey_id), Journey);
            let mut dragon = get!(world, (journey_info.dragon_token_id), Dragon);
            let mut island_from = get!(world, (map_id, journey_info.island_from_id), Island);
            let mut island_to = get!(world, (map_id, journey_info.island_to_id), Island);
            let resources = journey_info.carrying_resources;
            let mut journey_captured_player: ContractAddress = Zeroable::zero();
            let cur_block_timestamp = get_block_timestamp();

            // Get capturing player
            let mut capturing_player = get!(world, (journey_info.owner, map_id), Player);

            // Check status
            assert_with_err(
                journey_info.status == JourneyStatus::Started,
                Error::JOURNEY_ALREADY_FINISHED,
                Option::None
            );

            // Check caller
            assert_with_err(caller == journey_info.owner, Error::WRONG_CALLER, Option::None);

            // Check dragon state
            assert_with_err(
                dragon.state == DragonState::Flying, Error::DRAGON_SHOULD_BE_FLYING, Option::None
            );

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
                    if (island_to.cur_resources.food
                        + resources.food <= island_to.max_resources.food) {
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
                                    island_to
                                        .cur_resources
                                        .food = journey_info
                                        .carrying_resources
                                        .food;
                                }
                            }

                            // Update capturing player island owned
                            let mut capturing_player_island_owned = get!(
                                world,
                                (
                                    map_id,
                                    capturing_player.player,
                                    capturing_player.num_islands_owned
                                ),
                                PlayerIslandOwned
                            );
                            capturing_player_island_owned.island_id = island_to.island_id;

                            // Calculate points
                            let island_to_level = island_to.level;
                            if (island_to_level == 1) {
                                points = 10;
                            } else if (island_to_level == 2) {
                                points = 20;
                            } else if (island_to_level == 3) {
                                points = 32;
                            } else if (island_to_level == 4) {
                                points = 46;
                            } else if (island_to_level == 5) {
                                points = 62;
                            } else if (island_to_level == 6) {
                                points = 80;
                            } else if (island_to_level == 7) {
                                points = 100;
                            } else if (island_to_level == 8) {
                                points = 122;
                            } else if (island_to_level == 9) {
                                points = 150;
                            } else if (island_to_level == 10) {
                                points = 200;
                            }

                            // Update stone
                            if (island_to.resources_claim_type == ResourceClaimType::Stone
                                || island_to.resources_claim_type == ResourceClaimType::Both) {
                                capturing_player = player_actions_comp
                                    ._update_stone_finish_journey(
                                        capturing_player,
                                        world,
                                        island_to,
                                        true,
                                        cur_block_timestamp
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
                                    captured_player = player_actions_comp
                                        ._update_stone_finish_journey(
                                            captured_player,
                                            world,
                                            island_to,
                                            false,
                                            cur_block_timestamp
                                        );
                                }

                                // Update captured player island owned
                                let mut i: u32 = 0;
                                loop {
                                    if (i == captured_player.num_islands_owned) {
                                        break;
                                    }
                                    let island_owned_id = get!(
                                        world,
                                        (map_id, captured_player.player, i),
                                        PlayerIslandOwned
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
                            } else if (journey_info
                                .attack_type == AttackType::DerelictIslandAttack) {
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
                            achievement_tracking = achievement_actions_comp
                                ._update_achievement_tracking(
                                    achievement_tracking, capturing_player.num_islands_owned
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

            // Emit events
            emitter_comp
                .emit_journey_finished(
                    world,
                    JourneyFinished {
                        map_id,
                        player: journey_info.owner,
                        journey_id,
                        dragon_token_id: journey_info.dragon_token_id,
                        carrying_resources: resources,
                        island_from_id: island_from.island_id,
                        island_from_position: island_from.position,
                        island_from_owner: island_from.owner,
                        island_to_id: island_to.island_id,
                        island_to_position: island_to.position,
                        island_to_owner: island_to.owner,
                        start_time: journey_info.start_time,
                        finish_time: journey_info.finish_time,
                        attack_type: journey_info.attack_type,
                        attack_result: journey_info.attack_result,
                        status: journey_info.status
                    }
                );

            if (journey_info.attack_result == AttackResult::Win) {
                if (journey_info.attack_type == AttackType::PlayerIslandAttack) {
                    emitter_comp
                        .emit_points_changed(
                            world,
                            PointsChanged {
                                map_id,
                                player_earned: caller,
                                points_earned: points,
                                player_lost: journey_captured_player,
                                points_lost: points
                            }
                        );
                } else if (journey_info.attack_type == AttackType::DerelictIslandAttack) {
                    emitter_comp
                        .emit_points_changed(
                            world,
                            PointsChanged {
                                map_id,
                                player_earned: caller,
                                points_earned: points,
                                player_lost: Zeroable::zero(),
                                points_lost: Zeroable::zero()
                            }
                        );
                }
            }

            true
        }
    }
}
