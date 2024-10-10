// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::{position::{Position}, scout_info::{ScoutInfo, PlayerScoutInfo}};

// Interface
#[starknet::interface]
trait IScoutActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the ScoutInfo model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // * scout_id The scout_id to get info
    // * player The player to get info
    // # Return
    // * ScoutInfo The ScoutInfo model
    fn get_scout_info(
        self: @TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        scout_id: felt252,
        player: ContractAddress
    ) -> ScoutInfo;

    // Function to get the PlayerScoutInfo model info, to check whether the position is scouted by
    // player or not # Argument
    // * world The world address
    // * map_id The map_id to get info
    // * player The player to get info
    // * position The position to get info
    // # Return
    // * PlayerScoutInfo The PlayerScoutInfo model
    fn get_player_scout_info(
        self: @TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        player: ContractAddress,
        position: Position
    ) -> PlayerScoutInfo;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for player scouting the map
    // # Argument
    // * world The world address
    // * map_id The map_id to init action
    // * destination Position to scout
    // # Return
    // * Position Position of destination
    fn scout(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, destination: Position
    ) -> felt252;
}

// Component
#[starknet::component]
mod ScoutActionsComponent {
    // Core imports
    use poseidon::PoseidonTrait;

    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        constants::{START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, SCOUT_MISSION_ID},
        components::{
            mission::{
                MissionActionsComponent, MissionActionsComponent::MissionActionsInternalTrait
            },
            player::{PlayerActionsComponent, PlayerActionsComponent::PlayerActionsInternalTrait},
            emitter::{EmitterTrait, EmitterComponent}
        },
        events::{Scouted, PointsChanged},
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{IsMapInitialized, MapInfo},
            island::{Island, PositionIsland},
            scout_info::{ScoutInfo, PlayerScoutInfo, IsScouted, HasIsland},
            mission::MissionTracking, position::{Position}
        },
        errors::{Error, assert_with_err, panic_by_err}, utils::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::IScoutActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(ScoutActionsImpl)]
    impl ScoutActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl MissionActions: MissionActionsComponent::HasComponent<TContractState>,
        impl PlayerActions: PlayerActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IScoutActions<ComponentState<TContractState>> {
        // See IScoutActions-get_scout_info
        fn get_scout_info(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            scout_id: felt252,
            player: ContractAddress
        ) -> ScoutInfo {
            get!(world, (map_id, scout_id, player), ScoutInfo)
        }

        // See IScoutActions-get_player_scout_info
        fn get_player_scout_info(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            player: ContractAddress,
            position: Position
        ) -> PlayerScoutInfo {
            get!(world, (map_id, player, position.x, position.y), PlayerScoutInfo)
        }

        // See IScoutActions-scout
        fn scout(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            destination: Position
        ) -> felt252 {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player = get!(world, (caller, map_id), Player);
            let mut map = get!(world, (map_id), MapInfo);
            let player_global = get!(world, (caller), PlayerGlobal);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let mut mission_actions_comp = get_dep_component_mut!(ref self, MissionActions);
            let mut player_actions_comp = get_dep_component_mut!(ref self, PlayerActions);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
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
            player = player_actions_comp._update_energy(player, daily_timestamp);

            // Check if there's an island on the destination
            let mut has_island: HasIsland = HasIsland::NoIsland;
            let position_island = get!(
                world, (map_id, destination.x, destination.y), PositionIsland
            );
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

            // Calculate daily timestamp & update mission tracking
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            let mut mission_tracking = get!(
                world, (caller, map_id, SCOUT_MISSION_ID), MissionTracking
            );
            mission_tracking = mission_actions_comp
                ._update_mission_tracking(mission_tracking, world, daily_timestamp);

            // Save models
            set!(world, (player));
            set!(world, (scout_info));
            set!(world, (player_scout_info));
            set!(world, (map));
            set!(world, (mission_tracking));

            // Emit events
            emitter_comp
                .emit_scouted(
                    world,
                    Scouted {
                        map_id, player: player.player, scout_id, destination, time: cur_timestamp
                    }
                );
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

            scout_id
        }
    }
}
