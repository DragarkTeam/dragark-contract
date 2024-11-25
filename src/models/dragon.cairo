// Core imports
use core::{
    ecdsa::check_ecdsa_signature, hash::{HashStateTrait, HashStateExTrait}, option::OptionTrait,
    pedersen::PedersenTrait
};

// Starknet imports
use starknet::ContractAddress;

// Internal imports
use dragark::{
    constants::{
        ADDRESS_SIGN, PUBLIC_KEY_SIGN, STARKNET_DOMAIN_TYPE_HASH, DRAGON_INFO_STRUCT_TYPE_HASH
    },
    errors::{Error, assert_with_err, panic_by_err},
};

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Dragon {
    #[key]
    pub dragon_token_id: u128,
    pub owner: ContractAddress,
    pub map_id: usize,
    pub root_owner: ContractAddress,
    pub model_id: felt252,
    pub bg_id: felt252,
    pub rarity: DragonRarity,
    pub element: DragonElement,
    pub speed: u16,
    pub attack: u16,
    pub carrying_capacity: u32,
    pub state: DragonState,
    pub dragon_type: DragonType,
    pub is_inserted: bool,
    pub inserted_time: u64
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct NonceUsed {
    #[key]
    pub nonce: felt252,
    pub is_used: bool
}

#[derive(Copy, Drop, Serde, Hash)]
pub struct DragonInfo {
    pub dragon_token_id: felt252,
    pub owner: felt252,
    pub map_id: felt252,
    pub root_owner: felt252,
    pub model_id: felt252,
    pub bg_id: felt252,
    pub rarity: felt252,
    pub element: felt252,
    pub speed: felt252,
    pub attack: felt252,
    pub carrying_capacity: felt252,
    pub nonce: felt252,
}

#[derive(Copy, Drop, Serde, PartialEq, Hash)]
pub struct StarknetDomain {
    pub name: felt252,
    pub version: felt252,
    pub chain_id: felt252,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum DragonRarity {
    #[default]
    None,
    Common,
    Uncommon,
    Rare,
    Epic,
    Legendary,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum DragonElement {
    #[default]
    None,
    Fire,
    Water,
    Lightning,
    Darkness,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum DragonState {
    #[default]
    None,
    Idling,
    Flying,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub enum DragonType {
    #[default]
    None,
    NFT,
    Default,
}

pub trait DragonTrait {
    fn activate_dragon(
        dragon_info: DragonInfo, signature_r: felt252, signature_s: felt252
    ) -> Dragon;
}

trait IStructHash<T> {
    fn hash_struct(self: @T) -> felt252;
}

trait IOffchainMessageHash<T> {
    fn get_message_hash(self: @T) -> felt252;
}

impl DragonImpl of DragonTrait {
    fn activate_dragon(
        dragon_info: DragonInfo, signature_r: felt252, signature_s: felt252
    ) -> Dragon {
        // Verify the signature
        let message_hash = dragon_info.get_message_hash();
        assert_with_err(
            check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
            Error::SIGNATURE_NOT_MATCH
        );

        // Get rarity
        let mut rarity = DragonRarity::Common;
        if (dragon_info.rarity == 1) {
            rarity = DragonRarity::Uncommon;
        } else if (dragon_info.rarity == 2) {
            rarity = DragonRarity::Rare;
        } else if (dragon_info.rarity == 3) {
            rarity = DragonRarity::Epic;
        } else if (dragon_info.rarity == 4) {
            rarity = DragonRarity::Legendary;
        } else if (dragon_info.rarity != 0) {
            panic_by_err(Error::INVALID_CASE_DRAGON_RARITY);
        }

        // Get element
        let mut element = DragonElement::Fire;
        if (dragon_info.element == 1) {
            element = DragonElement::Water;
        } else if (dragon_info.element == 2) {
            element = DragonElement::Lightning;
        } else if (dragon_info.element == 3) {
            element = DragonElement::Darkness;
        } else if (dragon_info.element != 0) {
            panic_by_err(Error::INVALID_CASE_DRAGON_ELEMENT);
        }

        return Dragon {
            dragon_token_id: dragon_info.dragon_token_id.try_into().unwrap(),
            owner: dragon_info.owner.try_into().unwrap(),
            map_id: dragon_info.map_id.try_into().unwrap(),
            root_owner: dragon_info.root_owner.try_into().unwrap(),
            model_id: dragon_info.model_id,
            bg_id: dragon_info.bg_id,
            rarity,
            element,
            speed: dragon_info.speed.try_into().unwrap(),
            attack: dragon_info.attack.try_into().unwrap(),
            carrying_capacity: dragon_info.carrying_capacity.try_into().unwrap(),
            state: DragonState::Idling,
            dragon_type: DragonType::NFT,
            is_inserted: false,
            inserted_time: 0
        };
    }
}

impl OffchainMessageHashDragonInfo of IOffchainMessageHash<DragonInfo> {
    fn get_message_hash(self: @DragonInfo) -> felt252 {
        let domain = StarknetDomain { name: 'Dragark', version: 1, chain_id: 'SN_MAIN' };
        let address_sign: ContractAddress = ADDRESS_SIGN.try_into().unwrap();
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with('StarkNet Message');
        hashState = hashState.update_with(domain.hash_struct());
        hashState = hashState.update_with(address_sign);
        hashState = hashState.update_with(self.hash_struct());
        hashState = hashState.update_with(4);
        hashState.finalize()
    }
}

impl StructHashStarknetDomain of IStructHash<StarknetDomain> {
    fn hash_struct(self: @StarknetDomain) -> felt252 {
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(STARKNET_DOMAIN_TYPE_HASH);
        hashState = hashState.update_with(*self);
        hashState = hashState.update_with(4);
        hashState.finalize()
    }
}

impl StructHashDragonInfo of IStructHash<DragonInfo> {
    fn hash_struct(self: @DragonInfo) -> felt252 {
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(DRAGON_INFO_STRUCT_TYPE_HASH);
        hashState = hashState.update_with(*self);
        hashState = hashState.update_with(13);
        hashState.finalize()
    }
}

#[cfg(test)]
mod tests {
    // Core imports
    use core::{
        hash::{HashStateTrait, HashStateExTrait}, option::OptionTrait, pedersen::PedersenTrait
    };

    // Starknet imports
    use starknet::ContractAddress;

    // Internal imports
    use dragark::constants::{ADDRESS_SIGN, STARKNET_DOMAIN_TYPE_HASH, DRAGON_INFO_STRUCT_TYPE_HASH};

    // Local imports
    use super::{StarknetDomain, DragonInfo, DragonTrait, IOffchainMessageHash, IStructHash};

    #[test]
    fn test_struct_hash_starknet_domain() {
        // [Setup]
        let domain = StarknetDomain { name: 'Dragark', version: 1, chain_id: 'SN_MAIN' };
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(STARKNET_DOMAIN_TYPE_HASH);
        hashState = hashState.update_with(domain);
        hashState = hashState.update_with(4);
        let expected = hashState.finalize();

        // [Assert]
        assert_eq!(domain.hash_struct(), expected);
    }

    #[test]
    fn test_struct_hash_dragon_info() {
        // [Setup]
        let dragon_info = DragonInfo {
            dragon_token_id: 10000,
            owner: 0x7323d4ab9247947c48c7c797d290b7b032751e897e8f7267200f8bd6e151569,
            map_id: 2181426212,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: 4,
            element: 1,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            nonce: 1,
        };
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with(DRAGON_INFO_STRUCT_TYPE_HASH);
        hashState = hashState.update_with(dragon_info);
        hashState = hashState.update_with(13);
        let expected = hashState.finalize();

        // [Assert]
        assert_eq!(dragon_info.hash_struct(), expected);
    }

    #[test]
    fn test_offchain_message_hash_dragon_info() {
        // [Setup]
        let domain = StarknetDomain { name: 'Dragark', version: 1, chain_id: 'SN_MAIN' };
        let dragon_info = DragonInfo {
            dragon_token_id: 10000,
            owner: 0x7323d4ab9247947c48c7c797d290b7b032751e897e8f7267200f8bd6e151569,
            map_id: 2181426212,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: 4,
            element: 1,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            nonce: 1,
        };
        let address_sign: ContractAddress = ADDRESS_SIGN.try_into().unwrap();
        let mut hashState = PedersenTrait::new(0);
        hashState = hashState.update_with('StarkNet Message');
        hashState = hashState.update_with(domain.hash_struct());
        hashState = hashState.update_with(address_sign);
        hashState = hashState.update_with(dragon_info.hash_struct());
        hashState = hashState.update_with(4);
        let expected = hashState.finalize();

        // [Assert]
        assert_eq!(dragon_info.get_message_hash(), expected);
    }

    #[test]
    #[should_panic(expected: "Signature not match")]
    fn test_activate_dragon_revert_signature_not_match() {
        // [Setup]
        let dragon_info = DragonInfo {
            dragon_token_id: 10000,
            owner: 0x7323d4ab9247947c48c7c797d290b7b032751e897e8f7267200f8bd6e151569,
            map_id: 2181426212,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: 4,
            element: 1,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            nonce: 1,
        };
        let signature_r =
            624627255870296646262139706105427153309771630473261214860667773525447459923;
        let signature_s =
            122253516323277171152078917630275001185400265180223899974524514482086396429;

        // [Act]
        DragonTrait::activate_dragon(dragon_info, signature_r, signature_s);
    }
}
