// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark::models::{island::Resource, dragon::DragonInfo, position::Position, shield::ShieldType};

// Interface
#[starknet::interface]
pub trait IActions<TContractState> {
    ////////////
    // Dragon //
    ////////////

    // Function to activate a dragon mapped from L2
    // # Argument
    // * dragon_info DragonInfo struct
    // * signature_r Signature R
    // * signature_s Signature S
    fn activate_dragon(
        ref self: TContractState,
        dragon_info: DragonInfo,
        signature_r: felt252,
        signature_s: felt252
    );

    // Function to deactivate a dragon
    // # Argument
    // * map_id The map_id to deactivate the dragon
    // * dragon_token_id ID of the specified dragon
    // * signature_r Signature R
    // * signature_s Signature S
    // * nonce The nonce used for the signature
    fn deactivate_dragon(
        ref self: TContractState,
        map_id: usize,
        dragon_token_id: felt252,
        signature_r: felt252,
        signature_s: felt252,
        nonce: felt252
    );

    // Function for claiming the default dragon
    // # Argument
    // * map_id The map_id to init action
    // # Return
    // * bool Whether the tx successful or not
    fn claim_default_dragon(ref self: TContractState, map_id: usize) -> bool;

    /////////
    // Map //
    /////////

    // Function for player joining the map
    // Only callable for players who haven't joined the map
    // # Argument
    // * map_id The map_id to join
    // # Return
    // * bool Whether the tx successful or not
    fn join_map(
        ref self: TContractState,
        map_id: usize,
        stone: u128,
        dragark_stone: u64,
        nonce: felt252,
        signature_r: felt252,
        signature_s: felt252
    ) -> bool;

    // Function for player re-joining the map when all their islands are captured
    // Only callable for players who have joined the map and have no islands remaining
    // # Argument
    // * map_id The map_id to join
    // # Return
    // * bool Whether the tx successful or not
    fn re_join_map(ref self: TContractState, map_id: usize) -> bool;

    // Function for initializing a new map, only callable by admin
    // This function MUST BE CALLED FIRST in order to get the game/map operating
    // # Return
    // * usize The initialized map_id
    fn init_new_map(ref self: TContractState) -> usize;

    ////////////
    // Island //
    ////////////

    // Function for claiming island resources
    // # Argument
    // * map_id The map_id to init action
    // * island_ids Array of island_ids to claim resources
    // # Return
    // * bool Whether the tx successful or not
    fn claim_resources(ref self: TContractState, map_id: usize, island_id: usize) -> bool;

    // Function for generating 9 islands PER block, only callable by admin
    // # Argument
    // * map_id The map_id to init action
    fn gen_island_per_block(ref self: TContractState, map_id: usize);

    ///////////
    // Scout //
    ///////////

    // Function for player scouting the map
    // # Argument
    // * map_id The map_id to init action
    // * destination Position to scout
    // # Return
    // * Position Position of destination
    fn scout(ref self: TContractState, map_id: usize, destination: Position) -> felt252;

    /////////////
    // Journey //
    /////////////

    // Function for player to start a new journey
    // # Argument
    // * map_id The map_id to init action
    // * dragon_token_id ID of the specified dragon
    // * island_from_id ID of the starting island
    // * island_to_id ID of the destination island
    // * resources Specified amount of resources to carry (including foods & stones)
    // # Return
    // * bool Whether the tx successful or not
    fn start_journey(
        ref self: TContractState,
        map_id: usize,
        dragon_token_id: u128,
        island_from_id: usize,
        island_to_id: usize,
        resources: Resource
    ) -> felt252;

    // Function to finish a started journey
    // # Argument
    // * map_id The map_id to init action
    // * journey_id ID of the started journey
    // # Return
    // * bool Whether the tx successful or not
    fn finish_journey(ref self: TContractState, map_id: usize, journey_id: felt252) -> bool;

    ////////////
    // Player //
    ////////////

    // Function to insert a dragon to claim Dragark later
    // # Argument
    // * dragon_token_id The dragon token id to insert
    fn insert_dragon(ref self: TContractState, dragon_token_id: u128);

    // Function to claim Dragark
    // # Argument
    // * dragon_token_id The dragon token id to claim
    fn claim_dragark(ref self: TContractState, dragon_token_id: u128);

    // Function for player buying energy
    // # Argument
    // * pack The number of pack to buy
    fn buy_energy(ref self: TContractState, pack: u8);

    /////////////
    // Mission //
    /////////////

    // Function for claiming the reward of mission
    fn claim_mission_reward(ref self: TContractState);

    // Function for updating (add/modify/remove) mission
    // Only callable by admin
    // # Argument
    // * mission_id The mission id
    // * targets Array of the mission's targets
    // * stone_rewards Array of the mission's stone rewards
    // * dragark_stone_rewards Array of the mission's dragark stone rewards
    fn update_mission(
        ref self: TContractState,
        mission_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u64>
    );

    ////////////
    // Shield //
    ////////////

    // Function for player to activate a shield to protect their island
    // # Argument
    // * map_id The map id
    // * island_id The island id to activate the shield on
    // * shield_type The shield type
    fn activate_shield(
        ref self: TContractState, map_id: usize, island_id: usize, shield_type: ShieldType
    );

    // Function for player to deactivate a shield from their island
    // # Argument
    // * map_id The map id
    // * island_id The island id to deactivate the shield from
    fn deactivate_shield(ref self: TContractState, map_id: usize, island_id: usize);

    // Function for player to buy a shield by using their Dragark token
    // # Argument
    // * shield_type The shield type
    fn buy_shield(ref self: TContractState, shield_type: ShieldType, num: u32);
}

// Contract
#[dojo::contract]
mod actions {
    // Core imports
    use core::{
        ecdsa::check_ecdsa_signature, num::traits::{Bounded, Sqrt}, poseidon::poseidon_hash_span,
        zeroable::Zeroable
    };

    // Starknet imports
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};

    // Dojo imports
    use dojo::{model::ModelStorage, world::WorldStorage};

    // Internal imports
    use dragark::{
        models::{
            dragon::{
                Dragon, NonceUsed, DragonInfo, DragonRarity, DragonElement, DragonState, DragonType,
                DragonTrait
            },
            island::{Island, PositionIsland, Resource, IslandType, ResourceClaimType, IslandTrait},
            journey::{Journey, AttackType, AttackResult, JourneyStatus},
            map_info::{MapInfo, IsMapInitialized}, mission::{Mission, MissionTracking},
            player_dragon_owned::{PlayerDragonOwned}, player_island_owned::{PlayerIslandOwned},
            player_island_slot::{PlayerIslandSlot}, player::{Player, PlayerGlobal, IsPlayerJoined},
            position::{NextBlockDirection, NextIslandBlockDirection, Position},
            scout_info::{ScoutInfo, PlayerScoutInfo, HasIsland, IsScouted},
            shield::{Shield, ShieldType}
        },
        constants::{
            DEFAULT_NS, PUBLIC_KEY_SIGN, ADDRESS_SIGN, START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY,
            DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID, START_JOURNEY_MISSION_ID, mission_ids
        },
        errors::{Error, panic_by_err, assert_with_err},
        events::{
            Scouted, JourneyStarted, JourneyFinished, ShieldActivated, ShieldDeactivated,
            MissionMilestoneReached, PlayerStoneUpdate, PlayerDragarkStoneUpdate
        },
        utils::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IActions;

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Scouted: Scouted,
        JourneyStarted: JourneyStarted,
        JourneyFinished: JourneyFinished,
        ShieldActivated: ShieldActivated,
        ShieldDeactivated: ShieldDeactivated,
        MissionMilestoneReached: MissionMilestoneReached,
        PlayerStoneUpdate: PlayerStoneUpdate,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate
    }

    // Impls
    #[abi(embed_v0)]
    impl IActionsImpl of IActions<ContractState> {
        ////////////
        // Dragon //
        ////////////

        // See IActions-activate_dragon
        fn activate_dragon(
            ref self: ContractState,
            dragon_info: DragonInfo,
            signature_r: felt252,
            signature_s: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let map_id: usize = dragon_info.map_id.try_into().unwrap();
            let dragon_owner: ContractAddress = dragon_info.owner.try_into().unwrap();
            let mut player_global: PlayerGlobal = world.read_model(dragon_owner);
            let mut map: MapInfo = world.read_model(map_id);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check caller (burner)
            assert_with_err(dragon_owner == caller, Error::NOT_DRAGON_OWNER);

            // Check nonce used
            let mut nonce_used: NonceUsed = world.read_model(dragon_info.nonce);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED);

            // Check if the dragon has been activated or not
            let dragon_token_id: u128 = dragon_info.dragon_token_id.try_into().unwrap();
            let dragon: Dragon = world.read_model(dragon_token_id);
            assert_with_err(
                dragon.dragon_type == DragonType::None && dragon.map_id == 0,
                Error::DRAGON_ALREADY_ACTIVATED
            );

            // Init dragon
            let dragon: Dragon = DragonTrait::activate_dragon(
                dragon_info, signature_r, signature_s
            );

            // Save PlayerDragonOwned model
            world
                .write_model(
                    @PlayerDragonOwned {
                        player: dragon_owner,
                        index: player_global.num_dragons_owned,
                        dragon_token_id: dragon.dragon_token_id
                    }
                );

            // Update data
            nonce_used.is_used = true;
            map.total_activate_dragon += 1;
            map.total_dragon += 1;
            player_global.num_dragons_owned += 1;

            // Save data
            world.write_model(@nonce_used);
            world.write_model(@dragon);
            world.write_model(@map);
            world.write_model(@player_global);
        }

        // See IActions-deactivate_dragon
        fn deactivate_dragon(
            ref self: ContractState,
            map_id: usize,
            dragon_token_id: felt252,
            signature_r: felt252,
            signature_s: felt252,
            nonce: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player_global: PlayerGlobal = world.read_model(caller);
            let mut map: MapInfo = world.read_model(map_id);
            let dragon_token_id_u128: u128 = dragon_token_id.try_into().unwrap();
            let dragon: Dragon = world.read_model(dragon_token_id_u128);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check num dragons owned
            assert_with_err(player_global.num_dragons_owned >= 1, Error::NOT_OWN_ANY_DRAGON);

            // Check dragon map id
            assert_with_err(dragon.map_id == map_id, Error::INVALID_DRAGON_MAP_ID);

            // Check caller (burner)
            assert_with_err(dragon.owner == caller, Error::NOT_DRAGON_OWNER);

            // Check nonce used
            let mut nonce_used: NonceUsed = world.read_model(nonce);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED);

            // Check dragon type
            assert_with_err(dragon.dragon_type == DragonType::NFT, Error::INVALID_DRAGON_TYPE);

            // Verify signature
            let message: Array<felt252> = array![
                ADDRESS_SIGN, dragon.owner.into(), dragon_token_id, nonce
            ];
            let message_hash = poseidon::poseidon_hash_span(message.span());
            assert_with_err(
                check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
                Error::SIGNATURE_NOT_MATCH
            );

            // Delete dragon
            world.erase_model(@dragon);

            // Update player dragon owned
            let mut i: u32 = 0;
            loop {
                if (i == player_global.num_dragons_owned) {
                    break;
                }
                let player_dragon_owned: PlayerDragonOwned = world.read_model((caller, i));
                let dragon_owned_id = player_dragon_owned.dragon_token_id;
                if (dragon_token_id_u128 == dragon_owned_id) {
                    break;
                }
                i = i + 1;
            }; // Get the dragon deactivated index

            let mut dragon_owned: PlayerDragonOwned = world.read_model((caller, i));
            if (i == (player_global.num_dragons_owned - 1)) {
                world.erase_model(@dragon_owned);
            } else {
                let mut last_dragon_owned: PlayerDragonOwned = world
                    .read_model((caller, player_global.num_dragons_owned - 1));
                dragon_owned.dragon_token_id = last_dragon_owned.dragon_token_id;

                world.erase_model(@last_dragon_owned);
                world.write_model(@dragon_owned);
            }

            // Update data
            nonce_used.is_used = true;
            map.total_dragon -= 1;
            map.total_deactivate_dragon += 1;
            player_global.num_dragons_owned -= 1;

            world.write_model(@nonce_used);
            world.write_model(@map);
            world.write_model(@player_global);
        }

        // See IActions-claim_default_dragon
        fn claim_default_dragon(ref self: ContractState, map_id: usize) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player: Player = world.read_model((caller, map_id));
            let mut map: MapInfo = world.read_model(map_id);
            let mut player_global: PlayerGlobal = world.read_model(caller);
            map.dragon_token_id_counter += 1;
            let default_dragon_id: u128 = map.dragon_token_id_counter;
            let default_dragon: Dragon = world.read_model(default_dragon_id);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Check that the player hasn't claimed yet
            assert_with_err(!player.is_claim_default_dragon, Error::ALREADY_CLAIMED);

            // Check that the dragon hasn't been claimed yet
            assert_with_err(default_dragon.map_id == 0, Error::ALREADY_CLAIMED);

            // Init dragon for user
            let dragon = Dragon {
                dragon_token_id: default_dragon_id,
                owner: caller,
                map_id,
                root_owner: Zeroable::zero(),
                model_id: 18399416108126480420697739837366591432520176652608561,
                bg_id: 7165065848958115634,
                rarity: DragonRarity::Common,
                element: DragonElement::Darkness,
                speed: 50,
                attack: 50,
                carrying_capacity: 100,
                state: DragonState::Idling,
                dragon_type: DragonType::Default,
                is_inserted: false,
                inserted_time: 0
            };
            world.write_model(@dragon);
            world
                .write_model(
                    @PlayerDragonOwned {
                        player: caller,
                        index: player_global.num_dragons_owned,
                        dragon_token_id: default_dragon_id,
                    }
                );

            // Update data
            map.total_claim_dragon += 1;
            map.total_dragon += 1;
            player.is_claim_default_dragon = true;
            player_global.num_dragons_owned += 1;

            // Save data
            world.write_model(@map);
            world.write_model(@player);
            world.write_model(@player_global);

            true
        }

        /////////
        // Map //
        /////////

        // See IActions-join_map
        fn join_map(
            ref self: ContractState,
            map_id: usize,
            stone: u128,
            dragark_stone: u64,
            nonce: felt252,
            signature_r: felt252,
            signature_s: felt252
        ) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let player: Player = world.read_model((caller, map_id));
            let mut player_global: PlayerGlobal = world.read_model((caller));
            let mut map: MapInfo = world.read_model((map_id));
            let actions_contract_address = get_contract_address();
            let cur_timestamp = get_block_timestamp();
            let mut stone_set: u128 = 0;

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check the map player is in
            if (player_global.map_id == 0) {
                assert_with_err(
                    player.is_joined_map == IsPlayerJoined::NotJoined, Error::INVALID_CASE_JOIN_MAP
                );

                // Set player dragark balance
                player_global.dragark_balance = 10;

                // Set Stone/Dragark Stone
                if (stone.is_non_zero() || dragark_stone.is_non_zero()) {
                    // Check nonce used
                    let mut nonce_used: NonceUsed = world.read_model(nonce);
                    assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED);

                    // Verify signature
                    let message: Array<felt252> = array![
                        ADDRESS_SIGN,
                        actions_contract_address.into(),
                        map_id.into(),
                        caller.into(),
                        stone.into(),
                        dragark_stone.into(),
                        nonce,
                        'INIT_STONE_DRAGARK_STONE'
                    ];
                    let message_hash = poseidon_hash_span(message.span());
                    assert_with_err(
                        check_ecdsa_signature(
                            message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s
                        ),
                        Error::SIGNATURE_NOT_MATCH
                    );

                    // Update data
                    nonce_used.is_used = true;
                    stone_set = stone;
                    player_global.dragark_balance += dragark_stone;

                    // Save models
                    world.write_model(@nonce_used);
                }

                // Emit events
                self
                    .emit(
                        PlayerDragarkStoneUpdate {
                            map_id, player: caller, dragark_stone_balance: 10
                        }
                    );
            } else {
                let player_previous_map_id = player_global.map_id;
                let player_previous: Player = world.read_model((caller, player_previous_map_id));
                assert_with_err(player_previous_map_id != map_id, Error::ALREADY_JOINED_IN);
                assert_with_err(
                    player_previous.is_joined_map == IsPlayerJoined::Joined,
                    Error::INVALID_CASE_JOIN_MAP
                );
            }

            // Move/Set all the player's dragons to this map
            let mut i: u32 = 0;
            loop {
                if (i == player_global.num_dragons_owned) {
                    break;
                }

                let player_dragon_owned: PlayerDragonOwned = world.read_model((caller, i));
                let player_dragon_owned_token_id = player_dragon_owned.dragon_token_id;
                let mut dragon: Dragon = world.read_model(player_dragon_owned_token_id);
                dragon.map_id = map_id;
                world.write_model(@dragon);

                i = i + 1;
            };

            // Update player global
            player_global.map_id = map_id;
            world.write_model(@player_global);

            if (player.is_joined_map == IsPlayerJoined::NotJoined) {
                // // Check the map is full player or not
                // assert_with_err(map.total_player < 100, Error::MAP_FULL_PLAYER);

                // Get 1 island from PlayerIslandSlot for player
                let mut block_id = ((map.cur_block_coordinates.x / 12) + 1)
                    + (map.cur_block_coordinates.y / 12) * 23;
                let init_player_island_slot: PlayerIslandSlot = world
                    .read_model((map_id, block_id));
                let mut is_empty = init_player_island_slot.island_ids.is_empty();
                if (is_empty) {
                    if (map.cur_block_coordinates.x == 264 && map.cur_block_coordinates.y == 264) {
                        panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN);
                    }
                    while (is_empty) {
                        let next_block_direction_model: NextBlockDirection = world
                            .read_model(map_id);
                        let mut right_1 = next_block_direction_model.right_1;
                        let mut down_2 = next_block_direction_model.down_2;
                        let mut left_3 = next_block_direction_model.left_3;
                        let mut up_4 = next_block_direction_model.up_4;
                        let mut right_5 = next_block_direction_model.right_5;
                        if (right_1 != 0
                            && down_2 != 0
                            && left_3 != 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block to the right
                            map.cur_block_coordinates.x += 3 * 4;
                            right_1 -= 1;
                        } else if (right_1 == 0
                            && down_2 != 0
                            && left_3 != 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block down
                            map.cur_block_coordinates.y -= 3 * 4;
                            down_2 -= 1;
                        } else if (right_1 == 0
                            && down_2 == 0
                            && left_3 != 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block to the left
                            map.cur_block_coordinates.x -= 3 * 4;
                            left_3 -= 1;
                        } else if (right_1 == 0
                            && down_2 == 0
                            && left_3 == 0
                            && up_4 != 0
                            && right_5 != 0) {
                            // Move the current block up
                            map.cur_block_coordinates.y += 3 * 4;
                            up_4 -= 1;
                        } else if (right_1 == 0
                            && down_2 == 0
                            && left_3 == 0
                            && up_4 == 0
                            && right_5 != 0) {
                            // Move the current block to the right
                            map.cur_block_coordinates.x += 3 * 4;
                            right_5 -= 1;
                        } else {
                            panic_by_err(Error::INVALID_CASE_BLOCK_DIRECTION);
                        }

                        block_id = ((map.cur_block_coordinates.x / 12) + 1)
                            + (map.cur_block_coordinates.y / 12) * 23;
                        let cur_player_island_slot: PlayerIslandSlot = world
                            .read_model((map_id, block_id));
                        is_empty = cur_player_island_slot.island_ids.is_empty();

                        // Break if there's no more available
                        if (block_id == 529 && is_empty) {
                            panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN);
                        }

                        if (right_1 == 0
                            && down_2 == 0
                            && left_3 == 0
                            && up_4 == 0
                            && right_5 == 0) {
                            map.block_direction_count += 1;
                            right_1 = 1;
                            down_2 = 1 + (map.block_direction_count * 2);
                            left_3 = 2 + (map.block_direction_count * 2);
                            up_4 = 2 + (map.block_direction_count * 2);
                            right_5 = 2 + (map.block_direction_count * 2);
                        }

                        // Save models
                        world
                            .write_model(
                                @NextBlockDirection {
                                    map_id, right_1, down_2, left_3, up_4, right_5,
                                }
                            );
                        world.write_model(@map);
                    }
                }
                let mut player_island_slot: PlayerIslandSlot = world.read_model((map_id, block_id));
                let island_id = player_island_slot.island_ids.pop_front().unwrap();
                world.write_model(@player_island_slot);

                // Get player's island & initialize the island for player
                let mut player_island: Island = world.read_model((map_id, island_id));
                player_island.owner = caller;
                player_island.cur_resources.food = player_island.max_resources.food;

                let mut points = 0;
                let player_island_level = player_island.level;
                if (player_island_level == 1) {
                    points = 10;
                } else if (player_island_level == 2) {
                    points = 20;
                } else if (player_island_level == 3) {
                    points = 32;
                } else if (player_island_level == 4) {
                    points = 46;
                } else if (player_island_level == 5) {
                    points = 62;
                } else if (player_island_level == 6) {
                    points = 80;
                } else if (player_island_level == 7) {
                    points = 100;
                } else if (player_island_level == 8) {
                    points = 122;
                } else if (player_island_level == 9) {
                    points = 150;
                } else if (player_island_level == 10) {
                    points = 200;
                }

                // Save PlayerIslandOwned model
                world
                    .write_model(
                        @PlayerIslandOwned {
                            map_id, player: caller, index: 0, island_id: player_island.island_id
                        }
                    );

                // Save Island model
                world.write_model(@player_island);

                // Save Player model
                let daily_timestamp = cur_timestamp
                    - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
                world
                    .write_model(
                        @Player {
                            player: caller,
                            map_id,
                            is_joined_map: IsPlayerJoined::Joined,
                            area_opened: 0,
                            num_islands_owned: 1,
                            points,
                            is_claim_default_dragon: false,
                            // Energy
                            energy: 25,
                            energy_reset_time: daily_timestamp,
                            energy_bought_num: 0,
                            // Stone
                            stone_rate: 0,
                            current_stone: stone_set,
                            stone_updated_time: 0,
                            stone_cap: 50_000_000
                        }
                    );

                // Update the latest map's data
                let mut map: MapInfo = world.read_model(map_id);
                map.total_player += 1;
                map.derelict_islands_num -= 1;
                map.total_join_map += 1;
                world.write_model(@map);

                // Get the latest map's data
                let map: MapInfo = world.read_model(map_id);
                let island: Island = world.read_model((map_id, island_id));

                // Scout the newly initialized island sub-sub block and 8 surrounding one (if
                // possible)
                let map_coordinates = map.map_coordinates;
                let map_sizes = map.map_sizes;

                let island_position_x = island.position.x;
                let island_position_y = island.position.y;

                assert_with_err(
                    island_position_x >= map_coordinates.x && island_position_x < map_coordinates.x
                        + map_sizes
                            && island_position_y >= map_coordinates.y
                            && island_position_y < map_coordinates.y
                        + map_sizes,
                    Error::INVALID_POSITION
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
                self.scout(map_id, Position { x: center_position.x, y: center_position.y });
                self.scout(map_id, Position { x: center_position.x + 3, y: center_position.y });
                self.scout(map_id, Position { x: center_position.x, y: center_position.y - 3 });
                self.scout(map_id, Position { x: center_position.x - 3, y: center_position.y });
                self.scout(map_id, Position { x: center_position.x, y: center_position.y + 3 });
            }
            true
        }

        // See IActions-re_join_map
        fn re_join_map(ref self: ContractState, map_id: usize) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player: Player = world.read_model((caller, map_id));
            let player_global: PlayerGlobal = world.read_model(caller);
            let mut map: MapInfo = world.read_model(map_id);
            let cur_timestamp = get_block_timestamp();
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Check if the player has no islands remaining
            assert_with_err(player.num_islands_owned == 0, Error::PLAYER_NOT_AVAILABLE_FOR_REJOIN);

            // Check num dragons owned
            assert_with_err(player_global.num_dragons_owned >= 1, Error::NOT_OWN_ANY_DRAGON);

            // Get 1 island from PlayerIslandSlot for player
            let mut block_id = ((map.cur_block_coordinates.x / 12) + 1)
                + (map.cur_block_coordinates.y / 12) * 23;
            let init_player_island_slot: PlayerIslandSlot = world.read_model((map_id, block_id));
            let mut is_empty = init_player_island_slot.island_ids.is_empty();
            if (is_empty) {
                if (map.cur_block_coordinates.x == 264 && map.cur_block_coordinates.y == 264) {
                    panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN);
                }
                while (is_empty) {
                    let next_block_direction_model: NextBlockDirection = world.read_model(map_id);
                    let mut right_1 = next_block_direction_model.right_1;
                    let mut down_2 = next_block_direction_model.down_2;
                    let mut left_3 = next_block_direction_model.left_3;
                    let mut up_4 = next_block_direction_model.up_4;
                    let mut right_5 = next_block_direction_model.right_5;
                    if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                        // Move the current block to the right
                        map.cur_block_coordinates.x += 3 * 4;
                        right_1 -= 1;
                    } else if (right_1 == 0
                        && down_2 != 0
                        && left_3 != 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block down
                        map.cur_block_coordinates.y -= 3 * 4;
                        down_2 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 != 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block to the left
                        map.cur_block_coordinates.x -= 3 * 4;
                        left_3 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 == 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block up
                        map.cur_block_coordinates.y += 3 * 4;
                        up_4 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 == 0
                        && up_4 == 0
                        && right_5 != 0) {
                        // Move the current block to the right
                        map.cur_block_coordinates.x += 3 * 4;
                        right_5 -= 1;
                    } else {
                        panic_by_err(Error::INVALID_CASE_BLOCK_DIRECTION);
                    }

                    block_id = ((map.cur_block_coordinates.x / 12) + 1)
                        + (map.cur_block_coordinates.y / 12) * 23;
                    let cur_player_island_slot: PlayerIslandSlot = world
                        .read_model((map_id, block_id));
                    is_empty = cur_player_island_slot.island_ids.is_empty();

                    // Break if there's no more available
                    if (block_id == 529 && is_empty) {
                        panic_by_err(Error::NO_MORE_ISLAND_TO_JOIN);
                    }

                    if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 == 0) {
                        map.block_direction_count += 1;
                        right_1 = 1;
                        down_2 = 1 + (map.block_direction_count * 2);
                        left_3 = 2 + (map.block_direction_count * 2);
                        up_4 = 2 + (map.block_direction_count * 2);
                        right_5 = 2 + (map.block_direction_count * 2);
                    }

                    // Save models
                    world
                        .write_model(
                            @NextBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5, }
                        );
                    world.write_model(@map);
                }
            }
            let mut player_island_slot: PlayerIslandSlot = world.read_model((map_id, block_id));
            let island_id = player_island_slot.island_ids.pop_front().unwrap();
            world.write_model(@player_island_slot);

            // Get player's island & initialize the island for player
            let mut player_island: Island = world.read_model((map_id, island_id));
            player_island.owner = caller;
            player_island.cur_resources.food = player_island.max_resources.food;

            // Calculate points
            let mut points = 0;
            let player_island_level = player_island.level;
            if (player_island_level == 1) {
                points = 10;
            } else if (player_island_level == 2) {
                points = 20;
            } else if (player_island_level == 3) {
                points = 32;
            } else if (player_island_level == 4) {
                points = 46;
            } else if (player_island_level == 5) {
                points = 62;
            } else if (player_island_level == 6) {
                points = 80;
            } else if (player_island_level == 7) {
                points = 100;
            } else if (player_island_level == 8) {
                points = 122;
            } else if (player_island_level == 9) {
                points = 150;
            } else if (player_island_level == 10) {
                points = 200;
            }

            // Save PlayerIslandOwned model
            world
                .write_model(
                    @PlayerIslandOwned {
                        map_id, player: caller, index: 0, island_id: player_island.island_id
                    }
                );

            // Save Island model
            world.write_model(@player_island);

            // Save Player model
            player.num_islands_owned = 1;
            player.points += points;
            player.energy = 25;
            player.energy_reset_time = daily_timestamp;
            world.write_model(@player);

            // Update the latest map's data
            let mut map: MapInfo = world.read_model(map_id);
            map.derelict_islands_num -= 1;
            map.total_re_join_map += 1;
            world.write_model(@map);

            // Get the latest map's data
            let map: MapInfo = world.read_model(map_id);
            let island: Island = world.read_model((map_id, island_id));

            // Scout the newly initialized island sub-sub block and 8 surrounding one (if possible)
            let map_coordinates = map.map_coordinates;
            let map_sizes = map.map_sizes;

            let island_position_x = island.position.x;
            let island_position_y = island.position.y;

            assert_with_err(
                island_position_x >= map_coordinates.x && island_position_x < map_coordinates.x
                    + map_sizes
                        && island_position_y >= map_coordinates.y
                        && island_position_y < map_coordinates.y
                    + map_sizes,
                Error::INVALID_POSITION
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
            let first_player_scout_info: PlayerScoutInfo = world
                .read_model((map_id, caller, center_position.x, center_position.y));
            if (first_player_scout_info.is_scouted == IsScouted::NotScouted) {
                self.scout(map_id, Position { x: center_position.x, y: center_position.y });
            }

            // Scout the 2nd position
            let second_player_scout_info: PlayerScoutInfo = world
                .read_model((map_id, caller, center_position.x + 3, center_position.y));
            if (center_position.x
                + 3 < map_coordinates.x
                + map_sizes && second_player_scout_info.is_scouted == IsScouted::NotScouted) {
                self.scout(map_id, Position { x: center_position.x + 3, y: center_position.y });
            }

            // Scout the 3rd position
            let third_player_scout_info: PlayerScoutInfo = world
                .read_model((map_id, caller, center_position.x, center_position.y - 3));
            if (center_position.y
                - 3 >= map_coordinates.y
                    && third_player_scout_info.is_scouted == IsScouted::NotScouted) {
                self.scout(map_id, Position { x: center_position.x, y: center_position.y - 3 });
            }

            // Scout the 4th position
            let forth_player_scout_info: PlayerScoutInfo = world
                .read_model((map_id, caller, center_position.x - 3, center_position.y));
            if (center_position.x
                - 3 >= map_coordinates.x
                    && forth_player_scout_info.is_scouted == IsScouted::NotScouted) {
                self.scout(map_id, Position { x: center_position.x - 3, y: center_position.y });
            }

            // Scout the 5th position
            let fifth_player_scout_info: PlayerScoutInfo = world
                .read_model((map_id, caller, center_position.x, center_position.y + 3));
            if (center_position.y
                + 3 < map_coordinates.y
                + map_sizes && fifth_player_scout_info.is_scouted == IsScouted::NotScouted) {
                self.scout(map_id, Position { x: center_position.x, y: center_position.y + 3 });
            }

            true
        }

        // See IActions-init_new_map
        fn init_new_map(ref self: ContractState) -> usize {
            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();

            // Check caller
            _require_world_owner(world, caller);

            // Get u32 max
            let u32_max: u32 = Bounded::MAX;

            // Generate MAP_ID
            let mut data_map_id: Array<felt252> = array!['MAP_ID', get_block_timestamp().into()];
            let map_id_u256: u256 = poseidon::poseidon_hash_span(data_map_id.span())
                .try_into()
                .unwrap();
            let map_id: usize = (map_id_u256 % u32_max.into()).try_into().unwrap();

            // Check whether the map id has been initialized or not
            let map: MapInfo = world.read_model(map_id);
            assert_with_err(
                map.is_initialized == IsMapInitialized::NotInitialized,
                Error::MAP_ALREADY_INITIALIZED
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
            world
                .write_model(
                    @NextBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 }
                );

            // Init next block direction (island)
            let island_block_direction_count = 0;
            let right_1 = 1; // 1
            let down_2 = 1 + (island_block_direction_count * 2); // 1
            let left_3 = 2 + (island_block_direction_count * 2); // 2
            let up_4 = 2 + (island_block_direction_count * 2); // 2
            let right_5 = 2 + (island_block_direction_count * 2); // 2

            // Save NextIslandBlockDirection model
            world
                .write_model(
                    @NextIslandBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 }
                );

            // Save MapInfo model
            world
                .write_model(
                    @MapInfo {
                        map_id,
                        is_initialized: IsMapInitialized::Initialized,
                        total_player: 0,
                        total_island: 0,
                        total_dragon: 0,
                        total_scout: 0,
                        total_journey: 0,
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
                        map_sizes,
                        map_coordinates,
                        cur_block_coordinates,
                        block_direction_count,
                        derelict_islands_num: 0,
                        cur_island_block_coordinates,
                        island_block_direction_count,
                        dragon_token_id_counter: 99999
                    }
                );

            // Generate prior islands on the first middle blocks of the map
            IslandTrait::gen_island_per_block(
                ref world, map_id, cur_island_block_coordinates, IslandType::Normal
            );

            // Initialize mission
            self.update_mission(DAILY_LOGIN_MISSION_ID, array![0], array![1_000_000], array![0]);
            self
                .update_mission(
                    SCOUT_MISSION_ID,
                    array![5, 10, 20],
                    array![250_000, 500_000, 1_000_000],
                    array![0, 0, 0]
                );
            self
                .update_mission(
                    START_JOURNEY_MISSION_ID,
                    array![1, 3, 5],
                    array![250_000, 500_000, 1_000_000],
                    array![0, 0, 0]
                );

            map_id
        }

        ////////////
        // Island //
        ////////////

        // See IActions-claim_resources
        fn claim_resources(ref self: ContractState, map_id: usize, island_id: usize) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let mut map: MapInfo = world.read_model(map_id);
            let caller = get_caller_address();
            let player: Player = world.read_model((caller, map_id));
            let player_global: PlayerGlobal = world.read_model(caller);
            let mut island: Island = world.read_model((map_id, island_id));

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Check owner
            assert_with_err(caller == island.owner, Error::NOT_ISLAND_OWNER);

            let cur_block_timestamp: u64 = get_block_timestamp();
            let last_resources_claim = island.last_resources_claim;
            let claim_waiting_time = island.claim_waiting_time;

            // Check if the time has passed the next claim time
            assert_with_err(
                cur_block_timestamp >= last_resources_claim + claim_waiting_time,
                Error::NOT_TIME_TO_CLAIM_YET
            );

            // Update resources
            let island_cur_resources = island.cur_resources;
            let island_max_resources = island.max_resources;

            let resources_per_claim = island.resources_per_claim;

            if (island_cur_resources.food + resources_per_claim.food >= island_max_resources.food) {
                island.cur_resources.food = island_max_resources.food;
            } else {
                island.cur_resources.food += resources_per_claim.food;
            }

            island.last_resources_claim = cur_block_timestamp;

            // Update map
            map.total_claim_resources += 1;

            // Save models
            world.write_model(@map);
            world.write_model(@island);

            true
        }

        // See IActions-gen_island_per_block
        fn gen_island_per_block(ref self: ContractState, map_id: usize) {
            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut map: MapInfo = world.read_model(map_id);
            let mut cur_island_block_coordinates = map.cur_island_block_coordinates;

            // Check caller
            _require_world_owner(world, caller);

            // Get next block direction
            let next_island_block_direction_model: NextIslandBlockDirection = world
                .read_model(map_id);
            let mut right_1 = next_island_block_direction_model.right_1;
            let mut down_2 = next_island_block_direction_model.down_2;
            let mut left_3 = next_island_block_direction_model.left_3;
            let mut up_4 = next_island_block_direction_model.up_4;
            let mut right_5 = next_island_block_direction_model.right_5;
            if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block to the right
                cur_island_block_coordinates.x += 3 * 4;
                right_1 -= 1;
            } else if (right_1 == 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block down
                cur_island_block_coordinates.y -= 3 * 4;
                down_2 -= 1;
            } else if (right_1 == 0 && down_2 == 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block to the left
                cur_island_block_coordinates.x -= 3 * 4;
                left_3 -= 1;
            } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 != 0 && right_5 != 0) {
                // Move the current block up
                cur_island_block_coordinates.y += 3 * 4;
                up_4 -= 1;
            } else if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 != 0) {
                // Move the current block to the right
                cur_island_block_coordinates.x += 3 * 4;
                right_5 -= 1;
            } else {
                panic_by_err(Error::INVALID_CASE_ISLAND_BLOCK_DIRECTION);
            }

            // Gen island
            if (cur_island_block_coordinates.x == 276 && cur_island_block_coordinates.y == 264) {
                panic_by_err(Error::REACHED_MAX_ISLAND_GENERATED);
            }
            IslandTrait::gen_island_per_block(
                ref world, map_id, cur_island_block_coordinates, IslandType::Normal
            );

            // Update the latest data
            let mut map: MapInfo = world.read_model(map_id);
            map.cur_island_block_coordinates = cur_island_block_coordinates;
            if (right_1 == 0 && down_2 == 0 && left_3 == 0 && up_4 == 0 && right_5 == 0) {
                map.island_block_direction_count += 1;
                right_1 = 1;
                down_2 = 1 + (map.island_block_direction_count * 2);
                left_3 = 2 + (map.island_block_direction_count * 2);
                up_4 = 2 + (map.island_block_direction_count * 2);
                right_5 = 2 + (map.island_block_direction_count * 2);
            }

            // Save models
            world
                .write_model(
                    @NextIslandBlockDirection { map_id, right_1, down_2, left_3, up_4, right_5 }
                );
            world.write_model(@map);
        }

        ///////////
        // Scout //
        ///////////

        // See IActions-gen_island_per_block
        fn scout(ref self: ContractState, map_id: usize, destination: Position) -> felt252 {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player: Player = world.read_model((caller, map_id));
            let mut map: MapInfo = world.read_model(map_id);
            let player_global: PlayerGlobal = world.read_model(caller);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP);

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Get map's coordinates & sizes
            let map_coordinates = map.map_coordinates;
            let map_sizes = map.map_sizes;

            // Check destination
            assert_with_err(
                destination.x >= map_coordinates.x && destination.x < map_coordinates.x
                    + map_sizes
                        && destination.y >= map_coordinates.y
                        && destination.y < map_coordinates.y
                    + map_sizes,
                Error::INVALID_POSITION
            );
            let mut player_scout_info: PlayerScoutInfo = world
                .read_model((map_id, caller, destination.x, destination.y));
            assert_with_err(
                player_scout_info.is_scouted == IsScouted::NotScouted,
                Error::DESTINATION_ALREADY_SCOUTED
            );

            // Check whether the player has enough energy
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            player = PlayerInternalTrait::_update_energy(player, daily_timestamp);

            // Check if there's an island on the destination
            let mut has_island: HasIsland = HasIsland::NoIsland;
            let position_island: PositionIsland = world
                .read_model((map_id, destination.x, destination.y));
            if (position_island.island_id != 0) {
                has_island = HasIsland::HasIsland;
            }

            // Decide points earned
            let mut points: u64 = 2;

            player.points += points;
            player.area_opened += 1;
            player.energy -= 1;
            map.total_scout += 1;

            let data_scout_id: Array<felt252> = array![
                (map.total_scout).into(), 'data_scout', map_id.into(), cur_timestamp.into()
            ];
            let scout_id = poseidon::poseidon_hash_span(data_scout_id.span());

            let mut scout_info = ScoutInfo {
                map_id,
                scout_id: scout_id,
                player: player.player,
                destination: destination,
                time: cur_timestamp,
                points_earned: points,
                has_island,
                island_id: Default::default(),
                owner: Zeroable::zero(),
                position: Default::default(),
                block_id: Default::default(),
                element: Default::default(),
                title: Default::default(),
                island_type: Default::default(),
                level: Default::default(),
                max_resources: Default::default(),
                cur_resources: Default::default(),
                resources_per_claim: Default::default(),
                claim_waiting_time: Default::default(),
                resources_claim_type: Default::default(),
                last_resources_claim: Default::default(),
                shield_protection_time: Default::default()
            };

            if (has_island == HasIsland::HasIsland) {
                let island: Island = world.read_model((map_id, position_island.island_id));
                scout_info.island_id = island.island_id;
                scout_info.owner = island.owner;
                scout_info.position = island.position;
                scout_info.block_id = island.block_id;
                scout_info.element = island.element;
                scout_info.title = island.title;
                scout_info.island_type = island.island_type;
                scout_info.level = island.level;
                scout_info.max_resources = island.max_resources;
                scout_info.cur_resources = island.cur_resources;
                scout_info.resources_per_claim = island.resources_per_claim;
                scout_info.claim_waiting_time = island.claim_waiting_time;
                scout_info.resources_claim_type = island.resources_claim_type;
                scout_info.last_resources_claim = island.last_resources_claim;
                scout_info.shield_protection_time = island.shield_protection_time;
            }

            player_scout_info.is_scouted = IsScouted::Scouted;

            // Calculate daily timestamp & update mission tracking
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            let mut mission_tracking: MissionTracking = world
                .read_model((caller, map_id, SCOUT_MISSION_ID));
            mission_tracking =
                MissionInternalTrait::_update_mission_tracking(mission_tracking, daily_timestamp);

            // Save models
            world.write_model(@player);
            world.write_model(@scout_info);
            world.write_model(@player_scout_info);
            world.write_model(@map);
            world.write_model(@mission_tracking);

            // Emit events
            self
                .emit(
                    Scouted {
                        map_id, player: player.player, scout_id, destination, time: cur_timestamp
                    }
                );

            let mission_tracking_current_value = mission_tracking.current_value;
            if (mission_tracking_current_value == 5
                || mission_tracking_current_value == 10
                || mission_tracking_current_value == 20) {
                self
                    .emit(
                        MissionMilestoneReached {
                            mission_id: SCOUT_MISSION_ID,
                            map_id,
                            player: caller,
                            current_value: mission_tracking_current_value
                        }
                    );
            }

            scout_id
        }

        /////////////
        // Journey //
        /////////////

        // See IActions-start_journey
        fn start_journey(
            ref self: ContractState,
            map_id: usize,
            dragon_token_id: u128,
            island_from_id: usize,
            island_to_id: usize,
            resources: Resource
        ) -> felt252 {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let player: Player = world.read_model((caller, map_id));
            let mut map: MapInfo = world.read_model(map_id);
            let player_global: PlayerGlobal = world.read_model(caller);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            let mut dragon: Dragon = world.read_model(dragon_token_id);
            let mut island_from: Island = world.read_model((map_id, island_from_id));
            let mut island_to: Island = world.read_model((map_id, island_to_id));

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Check if dragon exists in the map
            assert_with_err(dragon.map_id == map_id, Error::DRAGON_NOT_EXISTS);

            // Check if island exists
            assert_with_err(
                island_from.claim_waiting_time >= 30 && island_to.claim_waiting_time >= 30,
                Error::ISLAND_NOT_EXISTS
            );

            // Check the island is not protected by shield
            assert_with_err(
                cur_block_timestamp > island_from.shield_protection_time,
                Error::ISLAND_FROM_PROTECTED
            );

            // Verify input
            assert_with_err(dragon_token_id.is_non_zero(), Error::INVALID_DRAGON_ID);
            assert_with_err(island_from_id.is_non_zero(), Error::INVALID_ISLAND_FROM);
            assert_with_err(island_to_id.is_non_zero(), Error::INVALID_ISLAND_TO);

            // Check the 2 islands are different
            assert_with_err(island_from_id != island_to_id, Error::JOURNEY_TO_THE_SAME_ISLAND);

            // Check if the player has the island_from
            assert_with_err(island_from.owner == caller, Error::NOT_OWN_ISLAND);

            // Check the player has the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON);

            // Check the dragon is on idling state
            assert_with_err(dragon.state == DragonState::Idling, Error::DRAGON_IS_NOT_AVAILABLE);

            // Check the island_from has enough resources
            let island_from_resources = island_from.cur_resources;
            assert_with_err(resources.food <= island_from_resources.food, Error::NOT_ENOUGH_FOOD);

            // Update the island_from resources
            island_from.cur_resources.food -= resources.food;

            // Calculate the distance between the 2 islands
            let island_from_position = island_from.position;
            let island_to_position = island_to.position;

            assert_with_err(
                island_from_position.x != island_to_position.x
                    || island_from_position.y != island_to_position.y,
                Error::TRANSPORT_TO_THE_SAME_DESTINATION
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
            assert_with_err(distance > 0, Error::INVALID_DISTANCE);

            // Decide the speed of the dragon
            let mut speed = dragon.speed;
            if (resources.food > dragon.carrying_capacity
                && resources.food <= (dragon.carrying_capacity * 150 / 100)) {
                speed = speed * 75 / 100;
            } else if (resources.food > (dragon.carrying_capacity * 150 / 100)) {
                speed = speed * 50 / 100;
            }
            assert_with_err(speed > 0, Error::INVALID_SPEED);

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

            // Calculate daily timestamp & update mission tracking
            let daily_timestamp = cur_block_timestamp
                - ((cur_block_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            let mut mission_tracking: MissionTracking = world
                .read_model((caller, map_id, START_JOURNEY_MISSION_ID));
            mission_tracking =
                MissionInternalTrait::_update_mission_tracking(mission_tracking, daily_timestamp);

            // Save Journey
            let attack_type = AttackType::Unknown;
            let attack_result = AttackResult::Unknown;
            let status = JourneyStatus::Started;

            world
                .write_model(
                    @Journey {
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
                    }
                );

            // Update map
            map.total_journey += 1;
            map.total_start_journey += 1;

            // Save models
            world.write_model(@island_from);
            world.write_model(@dragon);
            world.write_model(@map);
            world.write_model(@mission_tracking);

            // Emit events
            self
                .emit(
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

            let mission_tracking_current_value = mission_tracking.current_value;
            if (mission_tracking_current_value == 1
                || mission_tracking_current_value == 3
                || mission_tracking_current_value == 5) {
                self
                    .emit(
                        MissionMilestoneReached {
                            mission_id: START_JOURNEY_MISSION_ID,
                            map_id,
                            player: caller,
                            current_value: mission_tracking_current_value
                        }
                    );
            }

            journey_id
        }

        // See IActions-finish_journey
        fn finish_journey(ref self: ContractState, map_id: usize, journey_id: felt252) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut map: MapInfo = world.read_model(map_id);
            let mut points = 0;

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Verify input
            assert_with_err(journey_id.is_non_zero(), Error::INVALID_JOURNEY_ID);
            let mut journey_info: Journey = world.read_model((map_id, journey_id));
            let mut dragon: Dragon = world.read_model(journey_info.dragon_token_id);
            let mut island_from: Island = world.read_model((map_id, journey_info.island_from_id));
            let mut island_to: Island = world.read_model((map_id, journey_info.island_to_id));
            let resources = journey_info.carrying_resources;
            let mut journey_captured_player: ContractAddress = Zeroable::zero();
            let cur_block_timestamp = get_block_timestamp();

            // Get capturing player
            let mut capturing_player: Player = world.read_model((journey_info.owner, map_id));

            // Check status
            assert_with_err(
                journey_info.status == JourneyStatus::Started, Error::JOURNEY_ALREADY_FINISHED
            );

            // Check caller
            assert_with_err(caller == journey_info.owner, Error::WRONG_CALLER);

            // Check dragon state
            assert_with_err(dragon.state == DragonState::Flying, Error::DRAGON_SHOULD_BE_FLYING);

            // If the player has no islands left when the journey hasn't been finished, cancel the
            // journey
            if (capturing_player.num_islands_owned == 0) {
                journey_info.attack_type = AttackType::None;
                journey_info.attack_result = AttackResult::None;
                journey_info.status = JourneyStatus::Cancelled;
            } else {
                // Check time
                assert_with_err(
                    cur_block_timestamp >= journey_info.finish_time - 5, Error::JOURNEY_IN_PROGRESS
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
                        panic_by_err(Error::INVALID_CASE_RESOURCES_UPDATE);
                    }

                    journey_info.attack_result = AttackResult::None;
                    journey_info.status = JourneyStatus::Finished;
                } else { // Else => Capture
                    // Check condition
                    assert_with_err(
                        journey_info.attack_type == AttackType::DerelictIslandAttack
                            || journey_info.attack_type == AttackType::PlayerIslandAttack,
                        Error::INVALID_ATTACK_TYPE
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
                            let mut capturing_player_island_owned: PlayerIslandOwned = world
                                .read_model(
                                    (
                                        map_id,
                                        capturing_player.player,
                                        capturing_player.num_islands_owned
                                    )
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
                                capturing_player =
                                    PlayerInternalTrait::_update_stone_finish_journey(
                                        capturing_player, island_to, true, cur_block_timestamp
                                    );
                            }

                            if (journey_info.attack_type == AttackType::PlayerIslandAttack) {
                                let mut captured_player: Player = world
                                    .read_model((island_to.owner, map_id));
                                assert_with_err(
                                    captured_player.player.is_non_zero(),
                                    Error::INVALID_PLAYER_ADDRESS
                                );

                                // Update stone
                                if (island_to.resources_claim_type == ResourceClaimType::Stone
                                    || island_to.resources_claim_type == ResourceClaimType::Both) {
                                    captured_player =
                                        PlayerInternalTrait::_update_stone_finish_journey(
                                            captured_player, island_to, false, cur_block_timestamp
                                        );
                                }

                                // Update captured player island owned
                                let mut i: u32 = 0;
                                loop {
                                    if (i == captured_player.num_islands_owned) {
                                        break;
                                    }
                                    let player_island_owned: PlayerIslandOwned = world
                                        .read_model((map_id, captured_player.player, i));
                                    let island_owned_id = player_island_owned.island_id;
                                    if (island_owned_id == island_to.island_id) {
                                        break;
                                    }
                                    i = i + 1;
                                }; // Get the island captured index

                                let mut captured_player_island_owned: PlayerIslandOwned = world
                                    .read_model((map_id, captured_player.player, i));
                                if (i == captured_player.num_islands_owned - 1) {
                                    world.erase_model(@captured_player_island_owned);
                                } else {
                                    let captured_player_last_island_owned: PlayerIslandOwned = world
                                        .read_model(
                                            (
                                                map_id,
                                                captured_player.player,
                                                captured_player.num_islands_owned - 1
                                            )
                                        );
                                    captured_player_island_owned
                                        .island_id = captured_player_last_island_owned
                                        .island_id;
                                    world.erase_model(@captured_player_last_island_owned);
                                    world.write_model(@captured_player_island_owned);
                                }

                                captured_player.num_islands_owned -= 1;
                                captured_player.points -= points;
                                world.write_model(@captured_player);
                            } else if (journey_info
                                .attack_type == AttackType::DerelictIslandAttack) {
                                map.derelict_islands_num -= 1;

                                // If the island captured is in the PlayerIslandSlot, "delete" it
                                let island_to_block_id = ((island_to.position.x / 12) + 1)
                                    + (island_to.position.y / 12) * 23;
                                let mut player_island_slot: PlayerIslandSlot = world
                                    .read_model((map_id, island_to_block_id));
                                let mut island_ids = player_island_slot.island_ids;
                                if (island_ids.len() == 3) {
                                    let first_island_id = *island_ids.at(0);
                                    let second_island_id = *island_ids.at(1);
                                    let third_island_id = *island_ids.at(2);

                                    if (island_to.island_id == first_island_id) {
                                        island_ids = array![second_island_id, third_island_id];
                                        world
                                            .write_model(
                                                @PlayerIslandSlot {
                                                    map_id, block_id: island_to_block_id, island_ids
                                                }
                                            );
                                    } else if (island_to.island_id == second_island_id) {
                                        island_ids = array![first_island_id, third_island_id];
                                        world
                                            .write_model(
                                                @PlayerIslandSlot {
                                                    map_id, block_id: island_to_block_id, island_ids
                                                }
                                            );
                                    } else if (island_to.island_id == third_island_id) {
                                        island_ids = array![first_island_id, second_island_id];
                                        world
                                            .write_model(
                                                @PlayerIslandSlot {
                                                    map_id, block_id: island_to_block_id, island_ids
                                                }
                                            );
                                    }
                                } else if (island_ids.len() == 2) {
                                    let first_island_id = *island_ids.at(0);
                                    let second_island_id = *island_ids.at(1);

                                    if (island_to.island_id == first_island_id) {
                                        island_ids = array![second_island_id];
                                        world
                                            .write_model(
                                                @PlayerIslandSlot {
                                                    map_id, block_id: island_to_block_id, island_ids
                                                }
                                            );
                                    } else if (island_to.island_id == second_island_id) {
                                        island_ids = array![first_island_id];
                                        world
                                            .write_model(
                                                @PlayerIslandSlot {
                                                    map_id, block_id: island_to_block_id, island_ids
                                                }
                                            );
                                    }
                                } else if (island_ids.len() == 1) {
                                    let first_island_id = *island_ids.at(0);

                                    if (island_to.island_id == first_island_id) {
                                        island_ids = array![];
                                        world
                                            .write_model(
                                                @PlayerIslandSlot {
                                                    map_id, block_id: island_to_block_id, island_ids
                                                }
                                            );
                                    }
                                } else {
                                    assert_with_err(
                                        island_ids.len() == 0, Error::INVALID_ISLAND_IDS_LENGTH
                                    );
                                }
                            }

                            // Set the owner of the captured island
                            island_to.owner = journey_info.owner;

                            capturing_player.num_islands_owned += 1;
                            capturing_player.points += points;

                            world.write_model(@capturing_player_island_owned);
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
                                panic_by_err(Error::INVALID_CASE_POWER_RATING);
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
            world.write_model(@island_to);
            world.write_model(@dragon);
            world.write_model(@capturing_player);
            world.write_model(@journey_info);
            world.write_model(@map);

            // Emit events
            self
                .emit(
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
                self
                    .emit(
                        PlayerStoneUpdate {
                            map_id,
                            player: caller,
                            stone_rate: capturing_player.stone_rate,
                            current_stone: capturing_player.current_stone,
                            stone_updated_time: capturing_player.stone_updated_time,
                            stone_cap: capturing_player.stone_cap
                        }
                    );

                if (journey_info.attack_type == AttackType::PlayerIslandAttack) {
                    let captured_player: Player = world
                        .read_model((journey_captured_player, map_id));
                    self
                        .emit(
                            PlayerStoneUpdate {
                                map_id,
                                player: journey_captured_player,
                                stone_rate: captured_player.stone_rate,
                                current_stone: captured_player.current_stone,
                                stone_updated_time: captured_player.stone_updated_time,
                                stone_cap: captured_player.stone_cap
                            }
                        );
                }
            }

            true
        }

        ////////////
        // Player //
        ////////////

        // See IActions-insert_dragon
        fn insert_dragon(ref self: ContractState, dragon_token_id: u128) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let player_global: PlayerGlobal = world.read_model(caller);
            let current_block_timestamp = get_block_timestamp();

            // Check the player has joined the map
            assert_with_err(player_global.map_id.is_non_zero(), Error::PLAYER_NOT_JOINED_MAP);

            // Verify input
            assert_with_err(dragon_token_id.is_non_zero(), Error::INVALID_DRAGON_ID);

            let mut dragon: Dragon = world.read_model(dragon_token_id);

            // Check map id
            assert_with_err(dragon.map_id == player_global.map_id, Error::WRONG_MAP);

            // Check the player owns the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON);

            // Check the dragon is NFT
            assert_with_err(dragon.dragon_type == DragonType::NFT, Error::DRAGON_NOT_NFT);

            // Check that the dragon isn't being inserted
            assert_with_err(!dragon.is_inserted, Error::DRAGON_ALREADY_INSERTED);

            // Check that the player hasn't inserted any dragon
            let player_num_dragons_owned = player_global.num_dragons_owned;
            let mut total_inserted = 0;
            let mut i: u32 = 0;
            loop {
                if (i == player_num_dragons_owned) {
                    break;
                }

                // Get dragon info
                let player_dragon_owned: PlayerDragonOwned = world.read_model((caller, i));
                let dragon_owned_token_id = player_dragon_owned.dragon_token_id;
                let dragon_owned: Dragon = world.read_model(dragon_owned_token_id);

                // Check & increase total inserted
                if (dragon_owned.dragon_type == DragonType::NFT
                    && dragon_owned.is_inserted == true) {
                    total_inserted += 1;
                }

                // Increase index
                i += 1;
            };
            assert_with_err(total_inserted == 0, Error::ALREADY_INSERTED_DRAGON);

            // Update the dragon inserted state
            dragon.is_inserted = true;
            dragon.inserted_time = current_block_timestamp;

            // Save models
            world.write_model(@dragon);
        }

        // See IActions-claim_dragark
        fn claim_dragark(ref self: ContractState, dragon_token_id: u128) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player_global: PlayerGlobal = world.read_model(caller);
            let cur_block_timestamp = get_block_timestamp();

            // Check the player has joined the map
            assert_with_err(player_global.map_id.is_non_zero(), Error::PLAYER_NOT_JOINED_MAP);

            // Verify input
            assert_with_err(dragon_token_id.is_non_zero(), Error::INVALID_DRAGON_ID);

            let mut dragon: Dragon = world.read_model(dragon_token_id);

            // Check map id
            assert_with_err(dragon.map_id == player_global.map_id, Error::WRONG_MAP);

            // Check the player owns the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON);

            // Check the dragon is NFT
            assert_with_err(dragon.dragon_type == DragonType::NFT, Error::DRAGON_NOT_NFT);

            // Check that the dragon is being inserted
            assert_with_err(dragon.is_inserted, Error::DRAGON_NOT_INSERTED);

            // Check the time the dragon has been inserted
            assert_with_err(
                cur_block_timestamp >= dragon.inserted_time + 28800, Error::NOT_ENOUGH_TIME_TO_CLAIM
            );

            // Update the dragon inserted state
            dragon.is_inserted = false;

            // Update the Dragark balance according to the dragon's rarity
            if (dragon.rarity == DragonRarity::Common) {
                player_global.dragark_balance += 3;
            } else if (dragon.rarity == DragonRarity::Uncommon) {
                player_global.dragark_balance += 4;
            } else if (dragon.rarity == DragonRarity::Rare) {
                player_global.dragark_balance += 5;
            } else if (dragon.rarity == DragonRarity::Epic) {
                player_global.dragark_balance += 8;
            } else if (dragon.rarity == DragonRarity::Legendary) {
                player_global.dragark_balance += 10;
            }

            // Save models
            world.write_model(@dragon);
            world.write_model(@player_global);

            // Emit events
            self
                .emit(
                    PlayerDragarkStoneUpdate {
                        map_id: player_global.map_id,
                        player: caller,
                        dragark_stone_balance: player_global.dragark_balance.into()
                    }
                );
        }

        // See IActions-buy_energy
        fn buy_energy(ref self: ContractState, pack: u8) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player_global: PlayerGlobal = world.read_model(caller);
            let mut player: Player = world.read_model((caller, player_global.map_id));
            let mut map: MapInfo = world.read_model(player_global.map_id);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Check pack number
            assert_with_err(pack == 1 || pack == 2, Error::INVALID_PACK_NUMBER);

            // Check energy
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            assert_with_err(
                daily_timestamp == player.energy_reset_time, Error::NOT_OUT_OF_ENERGY_YET
            );
            assert_with_err(player.energy == 0, Error::NOT_OUT_OF_ENERGY_YET);

            // Process logic
            if (pack == 1) {
                // Update stone & check balance
                player = PlayerInternalTrait::_update_stone(player, cur_timestamp);
                assert_with_err(player.current_stone >= 500_000, Error::NOT_ENOUGH_STONE);

                // Check bought number
                assert_with_err(player.energy_bought_num < 2, Error::OUT_OF_ENERGY_BOUGHT);

                // Deduct stone, update bought number & update energy
                player.current_stone -= 500_000;
                player.energy_bought_num += 1;
                player.energy += 10;

                self
                    .emit(
                        PlayerStoneUpdate {
                            map_id: player.map_id,
                            player: player.player,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    );
            } else if (pack == 2) {
                // Check dragark balance
                assert_with_err(
                    player_global.dragark_balance >= 2, Error::NOT_ENOUGH_DRAGARK_BALANCE
                );

                // Deduct dragark & update energy
                player_global.dragark_balance -= 2;
                player.energy += 20;
            }

            // Save models
            world.write_model(@player);
            world.write_model(@player_global);

            // Emit events
            if (pack == 1) {
                self
                    .emit(
                        PlayerStoneUpdate {
                            map_id: player_global.map_id,
                            player: caller,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    );
            } else if (pack == 2) {
                self
                    .emit(
                        PlayerDragarkStoneUpdate {
                            map_id: player_global.map_id,
                            player: caller,
                            dragark_stone_balance: player_global.dragark_balance.into()
                        }
                    );
            }
        }

        /////////////
        // Mission //
        /////////////

        // See IActions-claim_mission_reward
        fn claim_mission_reward(ref self: ContractState) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player_global: PlayerGlobal = world.read_model(caller);
            let map_id = player_global.map_id;
            let mut map: MapInfo = world.read_model(map_id);
            let mut player: Player = world.read_model((caller, map_id));
            let player_stone_before = player.current_stone;
            let cur_block_timestamp = get_block_timestamp();
            let daily_timestamp = cur_block_timestamp
                - ((cur_block_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Fetch current stone
            player = PlayerInternalTrait::_update_stone(player, cur_block_timestamp);
            let player_dragark_stone_before = player_global.dragark_balance;

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
                let mission: Mission = world.read_model(mission_id);
                let mission_targets: Array<u32> = mission.targets;
                let mission_stone_rewards: Array<u128> = mission.stone_rewards;
                let mission_dragark_stone_rewards: Array<u64> = mission.dragark_stone_rewards;

                // Get mission tracking
                let mut mission_tracking: MissionTracking = world
                    .read_model((caller, map_id, mission_id));

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
                        player.current_stone += stone_reward;
                        player_global.dragark_balance += dragark_stone_reward;

                        // Increase index
                        current_claimed_times += 1;
                    };

                    // Update claimed times
                    mission_tracking.claimed_times = current_claimed_times;

                    // Save models
                    world.write_model(@mission_tracking);
                }

                // Increase index
                i = i + 1;
            };

            // Save models
            world.write_model(@player);
            world.write_model(@player_global);

            // Emit events
            if (player.current_stone != player_stone_before) {
                self
                    .emit(
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

            if (player_global.dragark_balance != player_dragark_stone_before) {
                self
                    .emit(
                        PlayerDragarkStoneUpdate {
                            map_id,
                            player: caller,
                            dragark_stone_balance: player_global.dragark_balance.into()
                        }
                    );
            }
        }

        // See IActions-update_mission
        fn update_mission(
            ref self: ContractState,
            mission_id: felt252,
            targets: Array<u32>,
            stone_rewards: Array<u128>,
            dragark_stone_rewards: Array<u64>
        ) {
            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();

            // Check caller
            _require_world_owner(world, caller);

            // Check mission rewards
            assert_with_err(targets.len() == stone_rewards.len(), Error::INVALID_REWARD);
            assert_with_err(targets.len() == dragark_stone_rewards.len(), Error::INVALID_REWARD);

            // Save models
            world
                .write_model(
                    @Mission { mission_id, targets, stone_rewards, dragark_stone_rewards }
                );
        }

        ////////////
        // Shield //
        ////////////

        // See IActions-activate_shield
        fn activate_shield(
            ref self: ContractState, map_id: usize, island_id: usize, shield_type: ShieldType
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut map: MapInfo = world.read_model(map_id);
            let mut island: Island = world.read_model((map_id, island_id));
            let player_global: PlayerGlobal = world.read_model(caller);
            let player: Player = world.read_model((caller, map_id));
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Check if island exists
            assert_with_err(island.claim_waiting_time >= 30, Error::ISLAND_NOT_EXISTS);

            // Verify input
            assert_with_err(
                shield_type == ShieldType::Type1
                    || shield_type == ShieldType::Type2
                    || shield_type == ShieldType::Type3
                    || shield_type == ShieldType::Type4,
                Error::INVALID_SHIELD_TYPE
            );

            // Check the player owns the island
            assert_with_err(island.owner == caller, Error::NOT_OWN_ISLAND);

            // Check the island is not protected by shield
            assert_with_err(
                cur_block_timestamp > island.shield_protection_time, Error::ISLAND_ALREADY_PROTECTED
            );

            // Check the player has enough shield
            let mut player_shield: Shield = world.read_model((caller, shield_type));
            assert_with_err(player_shield.nums_owned > 0, Error::NOT_ENOUGH_SHIELD);

            // Update the player's shield
            player_shield.nums_owned -= 1;

            // Update the island's shield protection time
            island.shield_protection_time = cur_block_timestamp + player_shield.protection_time;

            // Update map
            map.total_activate_shield += 1;

            // Save models
            world.write_model(@player_shield);
            world.write_model(@island);
            world.write_model(@map);

            // Emit events
            self
                .emit(
                    ShieldActivated {
                        map_id,
                        island_id,
                        shield_type,
                        shield_protection_time: island.shield_protection_time
                    }
                );
        }

        // See IActions-deactivate_shield
        fn deactivate_shield(ref self: ContractState, map_id: usize, island_id: usize) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut map: MapInfo = world.read_model(map_id);
            let mut island: Island = world.read_model((map_id, island_id));
            let player_global: PlayerGlobal = world.read_model(caller);
            let player: Player = world.read_model((caller, map_id));
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Check if island exists
            assert_with_err(island.claim_waiting_time >= 30, Error::ISLAND_NOT_EXISTS);

            // Check the player owns the island
            assert_with_err(island.owner == caller, Error::NOT_OWN_ISLAND);

            // Check the island is being protected by shield
            assert_with_err(
                cur_block_timestamp <= island.shield_protection_time, Error::ISLAND_NOT_PROTECTED
            );

            // Update the island's shield protection time
            island.shield_protection_time = cur_block_timestamp;

            // Update map
            map.total_deactivate_shield += 1;

            // Save models
            world.write_model(@island);
            world.write_model(@map);

            // Emit events
            self
                .emit(
                    ShieldDeactivated {
                        map_id, island_id, shield_protection_time: island.shield_protection_time
                    }
                );
        }

        // See IActions-buy_shield
        fn buy_shield(ref self: ContractState, shield_type: ShieldType, num: u32) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE);

            // Check time
            _require_valid_time();

            let mut world: WorldStorage = self.world(DEFAULT_NS());
            let caller = get_caller_address();
            let mut player_global: PlayerGlobal = world.read_model(caller);
            let map_id = player_global.map_id;
            let mut map: MapInfo = world.read_model(map_id);
            let mut player: Player = world.read_model((caller, map_id));
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized, Error::MAP_NOT_INITIALIZED
            );

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined, Error::PLAYER_NOT_JOINED_MAP
            );

            // Verify input
            assert_with_err(
                shield_type == ShieldType::Type1
                    || shield_type == ShieldType::Type2
                    || shield_type == ShieldType::Type3
                    || shield_type == ShieldType::Type4,
                Error::INVALID_SHIELD_TYPE
            );
            assert_with_err(num > 0, Error::INVALID_NUM);

            let num_u64: u64 = num.into();
            let num_u128: u128 = num.into();

            // According to the shield type, check the player has enough Dragark balance & update
            // it, set the protection time
            let mut protection_time: u64 = 0;
            if (shield_type == ShieldType::Type1) {
                player =
                    PlayerInternalTrait::_update_stone(
                        player, cur_block_timestamp
                    ); // Fetch current stone
                assert_with_err(
                    player.current_stone >= 500_000 * num_u128, Error::NOT_ENOUGH_DRAGARK_BALANCE
                );
                player.current_stone -= 500_000 * num_u128;
                protection_time = 3600;

                // Emit event
                self
                    .emit(
                        PlayerStoneUpdate {
                            map_id: player.map_id,
                            player: player.player,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    );
            } else if (shield_type == ShieldType::Type2) {
                player =
                    PlayerInternalTrait::_update_stone(
                        player, cur_block_timestamp
                    ); // Fetch current stone
                assert_with_err(
                    player.current_stone >= 1_000_000 * num_u128, Error::NOT_ENOUGH_DRAGARK_BALANCE
                );
                player.current_stone -= 1_000_000 * num_u128;
                protection_time = 10800;

                // Emit event
                self
                    .emit(
                        PlayerStoneUpdate {
                            map_id: player.map_id,
                            player: player.player,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    );
            } else if (shield_type == ShieldType::Type3) {
                assert_with_err(
                    player_global.dragark_balance >= 1 * num_u64, Error::NOT_ENOUGH_DRAGARK_BALANCE
                );
                player_global.dragark_balance -= 1 * num_u64;
                protection_time = 28800;
            } else if (shield_type == ShieldType::Type4) {
                assert_with_err(
                    player_global.dragark_balance >= 2 * num_u64, Error::NOT_ENOUGH_DRAGARK_BALANCE
                );
                player_global.dragark_balance -= 2 * num_u64;
                protection_time = 86400;
            }

            // Update the player's shield
            let mut player_shield: Shield = world.read_model((caller, shield_type));
            player_shield.nums_owned += num;
            player_shield.protection_time = protection_time;

            // Save models
            world.write_model(@player);
            world.write_model(@player_global);
            world.write_model(@player_shield);

            // Emit events
            if (shield_type == ShieldType::Type1 || shield_type == ShieldType::Type2) {
                self
                    .emit(
                        PlayerStoneUpdate {
                            map_id,
                            player: caller,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    );
            } else if (shield_type == ShieldType::Type3 || shield_type == ShieldType::Type4) {
                self
                    .emit(
                        PlayerDragarkStoneUpdate {
                            map_id,
                            player: caller,
                            dragark_stone_balance: player_global.dragark_balance.into()
                        }
                    );
            }
        }
    }

    #[generate_trait]
    impl PlayerInternalImpl of PlayerInternalTrait {
        // Function for fetching stone, used for finish journey action only
        fn _update_stone_finish_journey(
            mut player: Player, island: Island, is_capturing: bool, cur_block_timestamp: u64
        ) -> Player {
            // Update current stone
            if (player.stone_updated_time > 0) {
                let time_passed = cur_block_timestamp - player.stone_updated_time;
                player.current_stone += player.stone_rate * time_passed.into();
                // if (player.current_stone >= player.stone_cap) {
            //     player.current_stone = player.stone_cap;
            // }
            }

            // Update stone rate
            if (is_capturing) {
                if (island.level == 1) {
                    player.stone_rate += 1;
                } else if (island.level == 2) {
                    player.stone_rate += 2;
                } else if (island.level == 3) {
                    player.stone_rate += 3;
                } else if (island.level == 4) {
                    player.stone_rate += 4;
                } else if (island.level == 5) {
                    player.stone_rate += 5;
                } else if (island.level == 6) {
                    player.stone_rate += 6;
                } else if (island.level == 7) {
                    player.stone_rate += 7;
                } else if (island.level == 8) {
                    player.stone_rate += 8;
                } else if (island.level == 9) {
                    player.stone_rate += 9;
                } else if (island.level == 10) {
                    player.stone_rate += 10;
                }
            } else {
                if (island.level == 1) {
                    player.stone_rate -= 1;
                } else if (island.level == 2) {
                    player.stone_rate -= 2;
                } else if (island.level == 3) {
                    player.stone_rate -= 3;
                } else if (island.level == 4) {
                    player.stone_rate -= 4;
                } else if (island.level == 5) {
                    player.stone_rate -= 5;
                } else if (island.level == 6) {
                    player.stone_rate -= 6;
                } else if (island.level == 7) {
                    player.stone_rate -= 7;
                } else if (island.level == 8) {
                    player.stone_rate -= 8;
                } else if (island.level == 9) {
                    player.stone_rate -= 9;
                } else if (island.level == 10) {
                    player.stone_rate -= 10;
                }
            }

            // Update stone updated time
            player.stone_updated_time = cur_block_timestamp;

            player
        }

        // Function for fetching stone to the current block timestamp
        fn _update_stone(mut player: Player, cur_block_timestamp: u64) -> Player {
            // Update current stone
            if (player.stone_updated_time > 0) {
                let time_passed = cur_block_timestamp - player.stone_updated_time;
                player.current_stone += player.stone_rate * time_passed.into();
                // if (player.current_stone >= player.stone_cap) {
            //     player.current_stone = player.stone_cap;
            // }
            }

            // Update stone updated time
            player.stone_updated_time = cur_block_timestamp;

            player
        }

        // Function for checking & updating energy
        fn _update_energy(mut player: Player, daily_timestamp: u64) -> Player {
            if (daily_timestamp == player.energy_reset_time) {
                assert_with_err(player.energy > 0, Error::NOT_ENOUGH_ENERGY);
            } else if (daily_timestamp > player
                .energy_reset_time) { // A new day passed => Reset energy & timestamp
                player.energy_reset_time = daily_timestamp;
                player.energy_bought_num = 0;
                player.energy = 20;
            } else {
                panic_by_err(Error::INVALID_CASE_DAILY_TIMESTAMP);
            }

            player
        }
    }

    #[generate_trait]
    impl MissionInternalImpl of MissionInternalTrait {
        fn _update_mission_tracking(
            mut mission_tracking: MissionTracking, daily_timestamp: u64
        ) -> MissionTracking {
            let mission_tracking_daily_timestamp = mission_tracking.daily_timestamp;
            if (daily_timestamp == mission_tracking_daily_timestamp) {
                mission_tracking.current_value += 1;
            } else if (daily_timestamp > mission_tracking_daily_timestamp) {
                mission_tracking.current_value = 1;
                mission_tracking.claimed_times = 0;
                mission_tracking.daily_timestamp = daily_timestamp;
            } else {
                panic_by_err(Error::INVALID_CASE_DAILY_TIMESTAMP);
            }
            mission_tracking
        }
    }
}
