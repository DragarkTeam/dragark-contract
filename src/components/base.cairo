// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::base::{BaseResources, BaseResourcesType};

// Interface
#[starknet::interface]
trait IBaseActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the BaseResources model info
    // # Argument
    // * world The world address
    // * player The player address
    // * map_id The map id
    // * base_resources_type The base resources type
    // # Return
    // * BaseResources The BaseResources model
    fn get_base_resources(
        self: @TContractState,
        world: IWorldDispatcher,
        player: ContractAddress,
        map_id: usize,
        base_resources_type: BaseResourcesType
    ) -> BaseResources;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for player to change the total worker stats value
    // # Argument
    // * world The world address
    // * map_id The map id
    // * base_resources_type The base resources type 
    fn change_value(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        base_resources_type: BaseResourcesType
    );

    // Function for deducting resources amount
    // # Argument
    // * world The world address
    // * map_id The map id
    // * base_resources_type The base resources type
    fn deduct_resources(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        base_resources_type: BaseResourcesType
    );
}

// Component
#[starknet::component]
mod BaseActionsComponent {
    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{MapInfo, IsMapInitialized},
            base::{BaseResources, BaseResourcesType}
        },
        errors::{Error, assert_with_err},
        utils::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IBaseActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(BaseActionsImpl)]
    impl BaseActions<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of IBaseActions<ComponentState<TContractState>> {
        // See IBaseActions-get_base_resources
        fn get_base_resources(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            player: ContractAddress,
            map_id: usize,
            base_resources_type: BaseResourcesType
        ) -> BaseResources {
            get!(world, (player, map_id, base_resources_type), BaseResources)
        }

        // See IBaseActions-change_value
        fn change_value(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            base_resources_type: BaseResourcesType
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let player_global = get!(world, (caller), PlayerGlobal);
            let player = get!(world, (caller, map_id), Player);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Verify base resources type
            assert_with_err(
                base_resources_type == BaseResourcesType::BaseResourcesType1
                    || base_resources_type == BaseResourcesType::BaseResourcesType2,
                Error::INVALID_BASE_RESOURCES_TYPE,
                Option::None
            );

            // Calculate & Update data based on timestamp
            let mut base_resources = get!(
                world, (caller, map_id, base_resources_type), BaseResources
            );
            let base_resources_timestamp = base_resources.timestamp;
            let base_resources_production_rate = base_resources.production_rate;
            let mut base_resources_added_amount = 0;
            let resources_time_passed: u128 = (cur_block_timestamp - base_resources_timestamp)
                .into();

            // If timestamp > 0
            if (base_resources_timestamp > 0) {
                // Update resources
                base_resources_added_amount = base_resources_production_rate
                    * resources_time_passed;

                // Update total worker stats
                if (base_resources.cur_total_worker_stats == 500) {
                    base_resources.cur_total_worker_stats = 5_000;
                } else {
                    base_resources.cur_total_worker_stats = 500;
                }
            } else { // Else timestamp = 0 => First time
                assert_with_err(
                    base_resources_timestamp == 0,
                    Error::INVALID_BASE_RESOURCES_TIMESTAMP,
                    Option::None
                );

                // Update total worker stats
                base_resources.cur_total_worker_stats = 500;
            }

            // If resources is type 2, we need to deduct the sub resources
            if (base_resources_type == BaseResourcesType::BaseResourcesType2) {
                let base_resources_sub_deproduction_rate = base_resources.sub_deproduction_rate;

                if (base_resources_sub_deproduction_rate == 0) {
                    base_resources.sub_deproduction_rate = 100_000;
                } else {
                    // Update & Deduct sub resources
                    let mut base_sub_resources = get!(
                        world,
                        (caller, map_id, BaseResourcesType::BaseResourcesType1),
                        BaseResources
                    );
                    let base_sub_resources_timestamp = base_sub_resources.timestamp;
                    let base_sub_resources_production_rate = base_sub_resources.production_rate;

                    // Update sub resources amount
                    let sub_resources_time_passed: u128 = (cur_block_timestamp
                        - base_sub_resources_timestamp)
                        .into();
                    base_sub_resources.amount += base_sub_resources_production_rate
                        * sub_resources_time_passed;

                    // Deduct sub resources amount
                    let sub_deproduction_amount = base_resources_sub_deproduction_rate
                        * resources_time_passed;
                    if (base_sub_resources.amount <= sub_deproduction_amount) {
                        base_resources_added_amount = base_resources_added_amount
                            * base_sub_resources.amount
                            / sub_deproduction_amount;
                        base_sub_resources.amount = 0;
                    } else {
                        base_sub_resources.amount -= sub_deproduction_amount;
                    }

                    // Update sub resources timestamp & save
                    base_sub_resources.timestamp = cur_block_timestamp;
                    set!(world, (base_sub_resources));
                }
            }

            // Update timestamp
            base_resources.timestamp = cur_block_timestamp;

            // Update production rate
            if (base_resources_type == BaseResourcesType::BaseResourcesType1) {
                base_resources
                    .production_rate = (10_000 * base_resources.cur_total_worker_stats / 5_000)
                    / 2;
            } else if (base_resources_type == BaseResourcesType::BaseResourcesType2) {
                base_resources
                    .production_rate = (10_000 * base_resources.cur_total_worker_stats / 2_500)
                    / 2;
            }

            // Update base resources amount & save
            base_resources.amount += base_resources_added_amount;
            set!(world, (base_resources));
        }

        // See IBaseActions-deduct_resources
        fn deduct_resources(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            base_resources_type: BaseResourcesType
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let player_global = get!(world, (caller), PlayerGlobal);
            let player = get!(world, (caller, map_id), Player);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Verify base resources type
            assert_with_err(
                base_resources_type == BaseResourcesType::BaseResourcesType1
                    || base_resources_type == BaseResourcesType::BaseResourcesType2,
                Error::INVALID_BASE_RESOURCES_TYPE,
                Option::None
            );

            let mut base_resources = get!(
                world, (caller, map_id, base_resources_type), BaseResources
            );
            let base_resources_timestamp = base_resources.timestamp;
            let base_resources_production_rate = base_resources.production_rate;
            let mut base_resources_added_amount = 0;

            // Verify base resources timestamp
            assert_with_err(
                base_resources_timestamp > 0, Error::INVALID_BASE_RESOURCES_TIMESTAMP, Option::None
            );

            // Update resources
            let resources_time_passed: u128 = (cur_block_timestamp - base_resources_timestamp)
                .into();
            base_resources_added_amount = base_resources_production_rate * resources_time_passed;

            // If resources is type 2, we need to deduct the sub resources
            if (base_resources_type == BaseResourcesType::BaseResourcesType2) {
                let base_resources_sub_deproduction_rate = base_resources.sub_deproduction_rate;

                let mut base_sub_resources = get!(
                    world, (caller, map_id, BaseResourcesType::BaseResourcesType1), BaseResources
                );
                let base_sub_resources_timestamp = base_sub_resources.timestamp;
                let base_sub_resources_production_rate = base_sub_resources.production_rate;

                // Update sub resources amount
                let sub_resources_time_passed: u128 = (cur_block_timestamp
                    - base_sub_resources_timestamp)
                    .into();
                base_sub_resources.amount += base_sub_resources_production_rate
                    * sub_resources_time_passed;

                // Deduct sub resources amount
                let sub_deproduction_amount = base_resources_sub_deproduction_rate
                    * resources_time_passed;
                if (base_sub_resources.amount <= sub_deproduction_amount) {
                    base_resources_added_amount = base_resources_added_amount
                        * base_sub_resources.amount
                        / sub_deproduction_amount;
                    base_sub_resources.amount = 0
                } else {
                    base_sub_resources.amount -= sub_deproduction_amount;
                }

                // Update sub resources timestamp & save
                base_sub_resources.timestamp = cur_block_timestamp;
                set!(world, (base_sub_resources));
            }

            // Update timestamp
            base_resources.timestamp = cur_block_timestamp;

            // Update base resources amount
            base_resources.amount += base_resources_added_amount;

            let deduct_amount: u128 = 100_000;
            assert_with_err(
                base_resources.amount >= deduct_amount,
                Error::NOT_ENOUGH_BASE_RESOURCES_AMOUNT,
                Option::None
            );

            base_resources.amount -= deduct_amount;

            // Save
            set!(world, (base_resources));
        }
    }
}
