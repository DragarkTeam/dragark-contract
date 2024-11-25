// Starknet imports
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
pub struct PlayerIslandOwned {
    #[key]
    pub map_id: usize,
    #[key]
    pub player: ContractAddress,
    #[key]
    pub index: u32,
    pub island_id: usize,
}
