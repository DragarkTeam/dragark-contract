// Starknet imports
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Shield {
    #[key]
    pub player: ContractAddress,
    #[key]
    shield_type: ShieldType,
    protection_time: u64,
    nums_owned: u32
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
pub enum ShieldType {
    Type1,
    Type2,
    Type3,
    Type4
}
