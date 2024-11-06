// Core imports
use poseidon::PoseidonTrait;

// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::{
    models::{
        island::{
            Island, PositionIsland, IslandElement, IslandTitle, IslandType, Resource,
            ResourceClaimType
        },
        map::MapInfo, mission::{MissionTracking, MissionTrait}, player::{Player, PlayerTrait},
        position::{Position}
    },
    systems::scout::contracts::scout_systems::Event,
    constants::{START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY},
    errors::{Error, assert_with_err}, events::Scouted
};

// Models
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct ScoutInfo {
    #[key]
    map_id: usize,
    #[key]
    scout_id: felt252,
    #[key]
    player: ContractAddress,
    destination: Position,
    time: u64,
    points_earned: u64,
    has_island: HasIsland,
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
    shield_protection_time: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct PlayerScoutInfo {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    #[key]
    x: u32,
    #[key]
    y: u32,
    is_scouted: IsScouted
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum IsScouted {
    #[default]
    NotScouted,
    Scouted
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default)]
enum HasIsland {
    #[default]
    None,
    NoIsland,
    HasIsland
}

// Impls
#[generate_trait]
impl ScoutImpl of ScoutTrait {
    // Internal function to handle `scout` logic
    fn scout(
        ref player: Player,
        ref map: MapInfo,
        ref mission_tracking: MissionTracking,
        world: IWorldDispatcher,
        destination: Position,
        cur_timestamp: u64,
    ) -> felt252 {
        let caller = player.player;
        let map_id = map.map_id;

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
            Error::INVALID_POSITION,
            Option::None
        );
        let mut player_scout_info = get!(
            world, (map_id, caller, destination.x, destination.y), PlayerScoutInfo
        );
        assert_with_err(
            player_scout_info.is_scouted == IsScouted::NotScouted,
            Error::DESTINATION_ALREADY_SCOUTED,
            Option::None
        );

        // Check whether the player has enough energy
        let daily_timestamp = cur_timestamp
            - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
        PlayerTrait::_update_energy(ref player, daily_timestamp);

        // Check if there's an island on the destination
        let mut has_island: HasIsland = HasIsland::NoIsland;
        let position_island = get!(world, (map_id, destination.x, destination.y), PositionIsland);
        if (position_island.island_id != 0) {
            has_island = HasIsland::HasIsland;
        }

        // Decide points earned
        let mut points: u64 = 2;

        // Update data
        player.points += points;
        player.area_opened += 1;
        player.energy -= 1;
        map.total_scout += 1;

        // Generate scout id
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
            let island = get!(world, (map_id, position_island.island_id), Island);
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

        // Update mission tracking
        MissionTrait::_update_mission_tracking(ref mission_tracking, world, daily_timestamp);

        // Save models
        set!(world, (player));
        set!(world, (scout_info));
        set!(world, (player_scout_info));
        set!(world, (map));
        set!(world, (mission_tracking));

        scout_id
    }
}
