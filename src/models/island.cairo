// Core imports
use core::integer::BoundedU32;
use core::Zeroable;

// Starknet imports
use starknet::ContractAddress;
use starknet::get_block_timestamp;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{
        map::{MapInfo, IsMapInitialized, MapTrait}, position::{NextIslandBlockDirection, Position}
    },
    errors::{Error, assert_with_err, panic_by_err},
};

// Models
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Island {
    #[key]
    map_id: usize,
    #[key]
    island_id: usize,
    owner: ContractAddress,
    position: Position,
    block_id: u32,
    element: IslandElement,
    title: IslandTitle,
    island_type: IslandType,
    level: u8,
    max_resources: Resource,
    cur_resources: Resource,
    resources_per_claim: Resource,
    claim_waiting_time: u64,
    resources_claim_type: ResourceClaimType,
    last_resources_claim: u64,
    shield_protection_time: u64
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct PositionIsland {
    #[key]
    map_id: usize,
    #[key]
    x: u32,
    #[key]
    y: u32,
    island_id: usize
}

#[derive(Drop, Serde)]
#[dojo::model]
struct PlayerIslandSlot {
    #[key]
    map_id: usize,
    #[key]
    block_id: u32,
    island_ids: Array<u32>
}

// Structs
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
struct Resource {
    food: u32
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, Default)]
enum IslandElement {
    #[default]
    None,
    Fire,
    Water,
    Forest
}

#[derive(Copy, Drop, Serde, IntrospectPacked, Default)]
enum IslandTitle {
    #[default]
    None,
    ForgottenIsle,
    CoralLagoon,
    HiddenCove,
    Moonhaven,
    CielOuvert,
    Tenku,
    StormIsle,
    CloudAerie,
    SkyHaven,
    Aetherium,
    Nimbus,
    Elysium,
    Zenith,
    Laputa,
    Pandora,
    CieloAlto,
    Celeste,
    Skyforge,
    Benninging,
    Neverland
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default)]
enum IslandType {
    #[default]
    None,
    Normal,
    Event
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default)]
enum ResourceClaimType {
    #[default]
    None,
    Food,
    Stone,
    Both
}

// Impls
#[generate_trait]
impl IslandImpl of IslandTrait {
    // Internal function to handle `claim_resources` logic
    fn claim_resources(
        ref island: Island, ref map: MapInfo, world: IWorldDispatcher, cur_block_timestamp: u64
    ) -> bool {
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
        set!(world, (map));
        set!(world, (island));

        true
    }

    // Internal function to handle `gen_island_per_block` logic
    fn gen_island_per_block(
        ref map: MapInfo, world: IWorldDispatcher, island_type: IslandType, is_init: bool
    ) {
        let map_id = map.map_id;
        let cur_block_timestamp = get_block_timestamp();

        if (!is_init) {
            // Get next block direction
            let mut next_island_block_direction_model = get!(
                world, (map_id), NextIslandBlockDirection
            );
            MapTrait::_move_next_island_block(
                ref next_island_block_direction_model, ref map, world
            );

            // Check current island block coordinates
            if (map.cur_island_block_coordinates.x == 276
                && map.cur_island_block_coordinates.y == 264) {
                panic_by_err(Error::REACHED_MAX_ISLAND_GENERATED, Option::None);
            }
        }

        let block_coordinates = map.cur_island_block_coordinates;

        // Get u32 max
        let u32_max = BoundedU32::max();

        // Get position in sub-block
        let mut sub_block_pos_ids: Array<u32> = ArrayTrait::new();
        let data_sub_block_pos_ids_ord: Array<felt252> = array![
            'data_sub_block_pos_ids_ord', map_id.into(), cur_block_timestamp.into()
        ];
        let mut sub_block_pos_ids_ord_u256: u256 = poseidon::poseidon_hash_span(
            data_sub_block_pos_ids_ord.span()
        )
            .try_into()
            .unwrap();
        let sub_block_pos_ids_ord = (sub_block_pos_ids_ord_u256 % 12).try_into().unwrap();
        if (sub_block_pos_ids_ord == 0) {
            sub_block_pos_ids = array![26, 34, 43, 82, 87, 90, 122, 125, 129];
        } else if (sub_block_pos_ids_ord == 1) {
            sub_block_pos_ids = array![19, 26, 35, 67, 76, 82, 111, 114, 119];
        } else if (sub_block_pos_ids_ord == 2) {
            sub_block_pos_ids = array![28, 31, 46, 63, 78, 82, 112, 115, 130];
        } else if (sub_block_pos_ids_ord == 3) {
            sub_block_pos_ids = array![23, 32, 39, 66, 74, 81, 114, 123, 131];
        } else if (sub_block_pos_ids_ord == 4) {
            sub_block_pos_ids = array![15, 23, 30, 62, 68, 71, 99, 102, 118];
        } else if (sub_block_pos_ids_ord == 5) {
            sub_block_pos_ids = array![14, 18, 23, 62, 71, 78, 98, 105, 126];
        } else if (sub_block_pos_ids_ord == 6) {
            sub_block_pos_ids = array![22, 26, 42, 70, 76, 91, 98, 107, 127];
        } else if (sub_block_pos_ids_ord == 7) {
            sub_block_pos_ids = array![14, 20, 23, 66, 70, 74, 106, 112, 127];
        } else if (sub_block_pos_ids_ord == 8) {
            sub_block_pos_ids = array![19, 27, 34, 65, 74, 83, 103, 111, 118];
        } else if (sub_block_pos_ids_ord == 9) {
            sub_block_pos_ids = array![19, 35, 40, 67, 74, 83, 100, 118, 127];
        } else if (sub_block_pos_ids_ord == 10) {
            sub_block_pos_ids = array![14, 21, 29, 63, 71, 80, 123, 127, 130];
        } else if (sub_block_pos_ids_ord == 11) {
            sub_block_pos_ids = array![15, 34, 43, 63, 70, 78, 111, 116, 131];
        } else {
            panic_by_err(Error::INVALID_CASE_SUB_BLOCK_POSITION_IDS, Option::None);
        }

        // Loop to create 9 islands
        let mut i: u32 = 0;
        loop {
            if (i == 9) {
                break;
            }

            // Check if this island is for player
            let mut is_for_player: bool = false;
            let case = cur_block_timestamp % 9;
            if (case == 0 && (i == 0 || i == 3 || i == 6)) {
                is_for_player = true;
            } else if (case == 1 && (i == 1 || i == 4 || i == 7)) {
                is_for_player = true;
            } else if (case == 2 && (i == 2 || i == 5 || i == 8)) {
                is_for_player = true;
            } else if (case == 3 && (i == 0 || i == 1 || i == 6)) {
                is_for_player = true;
            } else if (case == 4 && (i == 2 || i == 7 || i == 8)) {
                is_for_player = true;
            } else if (case == 5 && (i == 3 || i == 4 || i == 5)) {
                is_for_player = true;
            } else if (case == 6 && (i == 0 || i == 1 || i == 5)) {
                is_for_player = true;
            } else if (case == 7 && (i == 3 || i == 4 || i == 8)) {
                is_for_player = true;
            } else if (case == 8 && (i == 2 || i == 6 || i == 7)) {
                is_for_player = true;
            }

            // Generate island id
            let data_island: Array<felt252> = array![
                (map.total_island + 1).into(),
                'data_island',
                map_id.into(),
                cur_block_timestamp.into()
            ];
            let mut island_id_u256: u256 = poseidon::poseidon_hash_span(data_island.span())
                .try_into()
                .unwrap();
            let island_id: usize = (island_id_u256 % u32_max.into()).try_into().unwrap();

            // Get sub_block_pos_id
            let sub_block_pos_id = *sub_block_pos_ids.at(i);
            let mut row_id: u32 = 0;
            let mut column_id: u32 = 0;
            if (sub_block_pos_id % 12 == 0) {
                row_id = (sub_block_pos_id / 12) - 1;
                column_id = 11;
            } else {
                row_id = sub_block_pos_id / 12;
                column_id = (sub_block_pos_id % 12) - 1
            }

            // Calculate x & y coordinates of the island in the map
            let x: u32 = block_coordinates.x + column_id;
            let y: u32 = block_coordinates.y + row_id;

            // Calculate the block id based on coordinates
            let block_id = ((x / 12) + 1) + (y / 12) * 23;

            // Randomize element
            let data_element: Array<felt252> = array![
                island_id.into(), 'data_element', map_id.into(), cur_block_timestamp.into()
            ];
            let hash_element: u256 = poseidon::poseidon_hash_span(data_element.span()).into();
            let element_num: u8 = (hash_element % 3).try_into().unwrap();
            let mut element: IslandElement = IslandElement::Fire;
            if (element_num == 1) {
                element = IslandElement::Water;
            } else if (element_num == 2) {
                element = IslandElement::Forest;
            }

            // Randomize title
            let data_title: Array<felt252> = array![
                island_id.into(), 'data_title', map_id.into(), cur_block_timestamp.into()
            ];
            let hash_tite: u256 = poseidon::poseidon_hash_span(data_title.span()).into();
            let title_num: u8 = (hash_tite % 20).try_into().unwrap();
            let mut title: IslandTitle = IslandTitle::ForgottenIsle;
            if (title_num == 1) {
                title = IslandTitle::CoralLagoon;
            } else if (title_num == 2) {
                title = IslandTitle::HiddenCove;
            } else if (title_num == 3) {
                title = IslandTitle::Moonhaven;
            } else if (title_num == 4) {
                title = IslandTitle::CielOuvert;
            } else if (title_num == 5) {
                title = IslandTitle::Tenku;
            } else if (title_num == 6) {
                title = IslandTitle::StormIsle;
            } else if (title_num == 7) {
                title = IslandTitle::CloudAerie;
            } else if (title_num == 8) {
                title = IslandTitle::SkyHaven;
            } else if (title_num == 9) {
                title = IslandTitle::Aetherium;
            } else if (title_num == 10) {
                title = IslandTitle::Nimbus;
            } else if (title_num == 11) {
                title = IslandTitle::Elysium;
            } else if (title_num == 12) {
                title = IslandTitle::Zenith;
            } else if (title_num == 13) {
                title = IslandTitle::Laputa;
            } else if (title_num == 14) {
                title = IslandTitle::Pandora;
            } else if (title_num == 15) {
                title = IslandTitle::CieloAlto;
            } else if (title_num == 16) {
                title = IslandTitle::Celeste;
            } else if (title_num == 17) {
                title = IslandTitle::Skyforge;
            } else if (title_num == 18) {
                title = IslandTitle::Benninging;
            } else if (title_num == 19) {
                title = IslandTitle::Neverland;
            }

            // Randomize level
            let data_level: Array<felt252> = array![
                island_id.into(), 'data_level', map_id.into(), get_block_timestamp().into()
            ];
            let hash_level: u256 = poseidon::poseidon_hash_span(data_level.span()).into();
            let mut level: u8 = 0;
            if (is_for_player) {
                level = ((hash_level % 3).try_into().unwrap()) + 1;
            } else {
                let rate_id: u8 = ((hash_level % 100).try_into().unwrap()) + 1;
                if (1 <= rate_id && rate_id <= 5) {
                    level = 1;
                } else if (6 <= rate_id && rate_id <= 10) {
                    level = 2;
                } else if (11 <= rate_id && rate_id <= 15) {
                    level = 3;
                } else if (16 <= rate_id && rate_id <= 30) {
                    level = 4;
                } else if (31 <= rate_id && rate_id <= 50) {
                    level = 5;
                } else if (51 <= rate_id && rate_id <= 70) {
                    level = 6;
                } else if (71 <= rate_id && rate_id <= 85) {
                    level = 7;
                } else if (86 <= rate_id && rate_id <= 90) {
                    level = 8;
                } else if (91 <= rate_id && rate_id <= 95) {
                    level = 9;
                } else if (96 <= rate_id && rate_id <= 100) {
                    level = 10;
                } else {
                    panic_by_err(Error::INVALID_CASE_ISLAND_LEVEL, Option::None);
                }
            }

            // Init stats based on the island's level
            let mut max_food: u32 = 0;

            let mut foods_per_claim: u32 = 0;
            let mut claim_waiting_time: u64 = 0;

            if (level == 1) {
                max_food = 200;
                foods_per_claim = 100;
                claim_waiting_time = 60;
            } else if (level == 2) {
                max_food = 400;
                foods_per_claim = 100;
                claim_waiting_time = 60;
            } else if (level == 3) {
                max_food = 600;
                foods_per_claim = 200;
                claim_waiting_time = 120;
            } else if (level == 4) {
                max_food = 800;
                foods_per_claim = 200;
                claim_waiting_time = 120;
            } else if (level == 5) {
                max_food = 1600;
                foods_per_claim = 400;
                claim_waiting_time = 300;
            } else if (level == 6) {
                max_food = 2600;
                foods_per_claim = 400;
                claim_waiting_time = 300;
            } else if (level == 7) {
                max_food = 3800;
                foods_per_claim = 1000;
                claim_waiting_time = 900;
            } else if (level == 8) {
                max_food = 5200;
                foods_per_claim = 1000;
                claim_waiting_time = 900;
            } else if (level == 9) {
                max_food = 7500;
                foods_per_claim = 1500;
                claim_waiting_time = 1800;
            } else if (level == 10) {
                max_food = 10000;
                foods_per_claim = 1500;
                claim_waiting_time = 1800;
            } else {
                panic_by_err(Error::INVALID_CASE_ISLAND_LEVEL_RESOURCES, Option::None);
            }

            // Calculate resources claim type
            let mut food: u32 = 0;
            let mut resources_claim_type: ResourceClaimType = ResourceClaimType::Food;
            if (!is_for_player) {
                let data_resources_claim_type: Array<felt252> = array![
                    'data_resources_claim_type', map_id.into(), get_block_timestamp().into()
                ];
                let mut hash_resources_claim_type: u256 = poseidon::poseidon_hash_span(
                    data_resources_claim_type.span()
                )
                    .into();
                let resources_claim_type_num: u8 = (hash_resources_claim_type % 4)
                    .try_into()
                    .unwrap();
                if (resources_claim_type_num == 1 || resources_claim_type_num == 3) {
                    resources_claim_type = ResourceClaimType::Food;
                } else if (resources_claim_type_num == 2) {
                    resources_claim_type = ResourceClaimType::Stone;
                } else if (resources_claim_type_num == 0) {
                    resources_claim_type = ResourceClaimType::Both;
                } else {
                    panic_by_err(Error::INVALID_CASE_RESOURCES_CLAIM_TYPE, Option::None);
                }

                if (resources_claim_type == ResourceClaimType::Stone) {
                    foods_per_claim = 0;
                }
            }

            // Calculate starting foods
            let data_ran_cur_food: Array<felt252> = array![
                'data_ran_cur_food', map_id.into(), get_block_timestamp().into()
            ];
            let mut hash_ran_cur_food: u256 = poseidon::poseidon_hash_span(data_ran_cur_food.span())
                .into();
            let ran_cur_food: u32 = 20 + (hash_ran_cur_food % 31).try_into().unwrap();
            food = max_food * ran_cur_food / 100;

            // Save PlayerIslandSlot model
            if (is_for_player) {
                let mut player_island_slot_island_ids: Array<usize> = get!(
                    world, (map_id, block_id), PlayerIslandSlot
                )
                    .island_ids;
                player_island_slot_island_ids.append(island_id);
                set!(
                    world,
                    (PlayerIslandSlot {
                        map_id, block_id, island_ids: player_island_slot_island_ids,
                    })
                );
            }

            // Save Island model
            set!(
                world,
                (Island {
                    map_id,
                    island_id,
                    owner: Zeroable::zero(),
                    position: Position { x, y },
                    block_id,
                    element,
                    title,
                    island_type,
                    level,
                    max_resources: Resource { food: max_food },
                    cur_resources: Resource { food },
                    resources_per_claim: Resource { food: foods_per_claim },
                    claim_waiting_time,
                    resources_claim_type,
                    last_resources_claim: cur_block_timestamp,
                    shield_protection_time: cur_block_timestamp
                })
            );

            // Save PositionIsland model
            set!(world, (PositionIsland { map_id, x, y, island_id }));

            // Save MapInfo model
            map.total_island += 1;
            map.derelict_islands_num += 1;

            i = i + 1;
        };

        // Save models
        set!(world, (map));
    }
}

