// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark::errors::{Error, assert_with_err};

// Models
#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct BaseResources {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    #[key]
    base_resources_type: BaseResourcesType,
    timestamp: u64,
    amount: u128, // 4 decimals
    production_rate: u128, // Per secs & 4 decimals
    sub_deproduction_rate: u128, // Per secs & 4 decimals
    cur_total_worker_stats: u128,
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum BaseResourcesType {
    BaseResourcesType1, // Dragark Potions
    BaseResourcesType2, // Gem
    BaseResourcesType3, // ...
}

// Impls
#[generate_trait]
impl BaseImpl of BaseTrait {
    // Internal function to handle `change_value` logic
    fn change_value(
        world: IWorldDispatcher,
        caller: ContractAddress,
        map_id: usize,
        base_resources_type: BaseResourcesType,
        cur_block_timestamp: u64
    ) {
        // Calculate & Update data based on timestamp
        let mut base_resources = get!(world, (caller, map_id, base_resources_type), BaseResources);
        let base_resources_timestamp = base_resources.timestamp;
        let base_resources_production_rate = base_resources.production_rate;
        let mut base_resources_added_amount = 0;
        let resources_time_passed: u128 = (cur_block_timestamp - base_resources_timestamp).into();

        // If timestamp > 0
        if (base_resources_timestamp > 0) {
            // Update resources
            base_resources_added_amount = base_resources_production_rate * resources_time_passed;

            // Update total worker stats
            if (base_resources.cur_total_worker_stats == 500) {
                base_resources.cur_total_worker_stats = 5_000;
            } else {
                base_resources.cur_total_worker_stats = 500;
            }
        } else { // Else timestamp = 0 => First time
            assert_with_err(
                base_resources_timestamp == 0, Error::INVALID_BASE_RESOURCES_TIMESTAMP, Option::None
            );

            // Update total worker stats
            base_resources.cur_total_worker_stats = 500;
        }

        // If resources is type 2, we need to deduct the sub resources
        if (base_resources_type == BaseResourcesType::BaseResourcesType2) {
            let base_resources_sub_deproduction_rate = base_resources.sub_deproduction_rate;

            if (base_resources_sub_deproduction_rate == 0) {
                base_resources.sub_deproduction_rate = 10_000_000;
            } else {
                // Update & Deduct sub resources
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
                .production_rate = (1_000_000 * base_resources.cur_total_worker_stats / 5_000)
                / 2;
        } else if (base_resources_type == BaseResourcesType::BaseResourcesType2) {
            base_resources
                .production_rate = (1_000_000 * base_resources.cur_total_worker_stats / 2_500)
                / 2;
        }

        // Update base resources amount & save
        base_resources.amount += base_resources_added_amount;
        set!(world, (base_resources));
    }

    // Internal function to handle `deduct_resources` logic
    fn deduct_resources(
        world: IWorldDispatcher,
        caller: ContractAddress,
        map_id: usize,
        base_resources_type: BaseResourcesType,
        cur_block_timestamp: u64
    ) {
        let mut base_resources = get!(world, (caller, map_id, base_resources_type), BaseResources);
        let base_resources_timestamp = base_resources.timestamp;
        let base_resources_production_rate = base_resources.production_rate;
        let mut base_resources_added_amount = 0;

        // Verify base resources timestamp
        assert_with_err(
            base_resources_timestamp > 0, Error::INVALID_BASE_RESOURCES_TIMESTAMP, Option::None
        );

        // Update resources
        let resources_time_passed: u128 = (cur_block_timestamp - base_resources_timestamp).into();
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

        let deduct_amount: u128 = 10_000_000;
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
