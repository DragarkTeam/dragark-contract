// Starknet imports
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
pub struct PlayerDragonOwned {
    #[key]
    pub player: ContractAddress,
    #[key]
    pub index: u32,
    pub dragon_token_id: u128,
}
