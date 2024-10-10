// Core imports
use core::option::OptionTrait;
use core::hash::{HashStateTrait, HashStateExTrait, Hash};
use pedersen::PedersenTrait;
use ecdsa::check_ecdsa_signature;

// Starknet imports
use starknet::ContractAddress;
use starknet::{get_block_timestamp, get_tx_info};

// Internal imports
use dragark_test_v19::{
    constants::{ADDRESS_SIGN, PUBLIC_KEY_SIGN}, models::island::Resource,
    errors::{Error, assert_with_err, panic_by_err},
};

const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");
const DRAGON_INFO_STRUCT_TYPE_HASH: felt252 =
    selector!(
        "DragonInfo(dragon_token_id:felt,collection:felt,owner:felt,map_id:felt,root_owner:felt,model_id:felt,bg_id:felt,rarity:felt,element:felt,level:felt,speed:felt,attack:felt,carrying_capacity:felt,nonce:felt)"
    );

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct Dragon {
    #[key]
    dragon_token_id: u128,
    collection: ContractAddress,
    owner: ContractAddress,
    map_id: usize,
    root_owner: ContractAddress,
    model_id: felt252,
    bg_id: felt252,
    rarity: DragonRarity,
    element: DragonElement,
    level: u8,
    speed: u16,
    attack: u16,
    carrying_capacity: u32,
    state: DragonState,
    dragon_type: DragonType,
    is_inserted: bool,
    inserted_time: u64
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct NonceUsed {
    #[key]
    nonce: felt252,
    is_used: bool
}

#[derive(Copy, Drop, Serde, Hash)]
struct DragonInfo {
    dragon_token_id: felt252,
    collection: felt252,
    owner: felt252,
    map_id: felt252,
    root_owner: felt252,
    model_id: felt252,
    bg_id: felt252,
    rarity: felt252,
    element: felt252,
    level: u8,
    speed: felt252,
    attack: felt252,
    carrying_capacity: felt252,
    nonce: felt252,
}

#[derive(Copy, Drop, Serde, PartialEq, Hash)]
struct StarknetDomain {
    name: felt252,
    version: felt252,
    chain_id: felt252,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonRarity {
    #[default]
    None,
    Common,
    Uncommon,
    Rare,
    Epic,
    Legendary,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonElement {
    #[default]
    None,
    Fire,
    Water,
    Lightning,
    Darkness,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonState {
    #[default]
    None,
    Idling,
    Flying,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum DragonType {
    #[default]
    None,
    NFT,
    Default,
}

trait DragonTrait {
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
            Error::SIGNATURE_NOT_MATCH,
            Option::None
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
            panic_by_err(Error::INVALID_CASE_DRAGON_RARITY, Option::None);
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
            panic_by_err(Error::INVALID_CASE_DRAGON_ELEMENT, Option::None);
        }

        return Dragon {
            dragon_token_id: dragon_info.dragon_token_id.try_into().unwrap(),
            collection: dragon_info.collection.try_into().unwrap(),
            owner: dragon_info.owner.try_into().unwrap(),
            map_id: dragon_info.map_id.try_into().unwrap(),
            root_owner: dragon_info.root_owner.try_into().unwrap(),
            model_id: dragon_info.model_id,
            bg_id: dragon_info.bg_id,
            rarity,
            element,
            level: dragon_info.level.try_into().unwrap(),
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
        hashState = hashState.update_with(15);
        hashState.finalize()
    }
}

#[cfg(test)]
mod tests {
    use core::option::OptionTrait;
    use core::hash::{HashStateTrait, HashStateExTrait, Hash};
    use dragark_test_v19::constants::ADDRESS_SIGN;
    use super::{STARKNET_DOMAIN_TYPE_HASH, DRAGON_INFO_STRUCT_TYPE_HASH};
    use super::{StarknetDomain, DragonInfo};
    use super::{DragonTrait, IOffchainMessageHash, IStructHash};
    use starknet::ContractAddress;
    use pedersen::PedersenTrait;

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
    #[should_panic(expected: ('Signature not match',))]
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

    #[test]
    #[should_panic(expected: ('Invalid case dragon rarity',))]
    fn test_activate_dragon_revert_invalid_case_dragon_rarity() {
        // [Setup]
        let dragon_info = DragonInfo {
            dragon_token_id: 10000,
            owner: 0x7323d4ab9247947c48c7c797d290b7b032751e897e8f7267200f8bd6e151569,
            map_id: 2181426212,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: 5,
            element: 1,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            nonce: 1,
        };
        let signature_r =
            2678022746803393520267281642733240550071633883712318494911020143000443079598;
        let signature_s =
            105335863238357048549009051573318508875152469883431238659549647953206166000;

        // [Act]
        DragonTrait::activate_dragon(dragon_info, signature_r, signature_s);
    }

    #[test]
    #[should_panic(expected: ('Invalid case dragon element',))]
    fn test_activate_dragon_revert_invalid_case_dragon_element() {
        // [Setup]
        let dragon_info = DragonInfo {
            dragon_token_id: 10000,
            owner: 0x7323d4ab9247947c48c7c797d290b7b032751e897e8f7267200f8bd6e151569,
            map_id: 2181426212,
            root_owner: Zeroable::zero(),
            model_id: 18399416108126480420697739837366591432520176652608561,
            bg_id: 7165065848958115634,
            rarity: 4,
            element: 4,
            speed: 50,
            attack: 50,
            carrying_capacity: 100,
            nonce: 1,
        };
        let signature_r =
            3267584384491901260694307252910594496204474162773050615005852511212026992401;
        let signature_s =
            3576488043381388293601080180068265290854275361943771684622145688974300961472;

        // [Act]
        DragonTrait::activate_dragon(dragon_info, signature_r, signature_s);
    }
}
