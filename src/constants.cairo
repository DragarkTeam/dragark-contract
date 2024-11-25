// Namespace
pub fn DEFAULT_NS() -> @ByteArray {
    @"dragark"
}

// Sign
pub const PUBLIC_KEY_SIGN: felt252 =
    0x3832eeefe028b33ccb29c2b6173b2db8e851794f0a78127157c93c0f88eba89;
pub const ADDRESS_SIGN: felt252 =
    0x0246fF8c7B475dDFb4CB5035867cBA76025F08B22938E5684C18c2aB9d9f36D3;
const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");
const DRAGON_INFO_STRUCT_TYPE_HASH: felt252 =
    selector!(
        "DragonInfo(dragon_token_id:felt,owner:felt,map_id:felt,root_owner:felt,model_id:felt,bg_id:felt,rarity:felt,element:felt,speed:felt,attack:felt,carrying_capacity:felt,nonce:felt)"
    );

// Timestamp
pub const START_TIMESTAMP: u64 = 1724976000; // 2024/30/08 00h:00m:00s
pub const TOTAL_TIMESTAMPS_PER_DAY: u64 = 86400;

// Mission
pub const DAILY_LOGIN_MISSION_ID: felt252 = 'DAILY_LOGIN_MISSION';
pub const SCOUT_MISSION_ID: felt252 = 'SCOUT_MISSION';
pub const START_JOURNEY_MISSION_ID: felt252 = 'START_JOURNEY_MISSION';

pub fn mission_ids() -> Array<felt252> {
    array![DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID, START_JOURNEY_MISSION_ID]
}
