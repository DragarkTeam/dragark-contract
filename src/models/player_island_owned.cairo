// Starknet imports
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerIslandOwned {
    #[key]
    map_id: usize,
    #[key]
    player: ContractAddress,
    #[key]
    index: u32,
    island_id: usize,
}
