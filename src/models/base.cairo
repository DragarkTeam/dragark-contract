// Starknet imports
use starknet::ContractAddress;

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

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum BaseResourcesType {
    BaseResourcesType1, // Dragark Potions
    BaseResourcesType2, // Gem
    BaseResourcesType3, // ...
}
