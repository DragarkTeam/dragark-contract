// Starknet imports
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerDragonOwned {
    #[key]
    player: ContractAddress,
    #[key]
    index: u32,
    dragon_token_id: u128,
}
