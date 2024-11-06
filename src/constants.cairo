// Core imports
use core::integer::{BoundedU128, BoundedU64};

// Sign
const PUBLIC_KEY_SIGN: felt252 = 0x3832eeefe028b33ccb29c2b6173b2db8e851794f0a78127157c93c0f88eba89;
const ADDRESS_SIGN: felt252 = 0x0246fF8c7B475dDFb4CB5035867cBA76025F08B22938E5684C18c2aB9d9f36D3;
const STARKNET_DOMAIN_TYPE_HASH: felt252 =
    selector!("StarkNetDomain(name:felt,version:felt,chainId:felt)");
const DRAGON_INFO_STRUCT_TYPE_HASH: felt252 =
    selector!(
        "DragonInfo(dragon_token_id:felt,collection:felt,owner:felt,map_id:felt,root_owner:felt,model_id:felt,bg_id:felt,rarity:felt,element:felt,level:felt,speed:felt,attack:felt,carrying_capacity:felt,nonce:felt)"
    );

// Timestamp
const START_TIMESTAMP: u64 = 1724976000; // 2024/30/08 00h:00m:00s
const TOTAL_TIMESTAMPS_PER_DAY: u64 = 86400;

// Fast root
const FAST_ROOT_ITER: u32 = 70;

// Code generation
const DIGITS: u8 = 6;

fn characters() -> Array<felt252> {
    array![
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z',
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'l',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9'
    ]
}

// Mission ID
const DAILY_LOGIN_MISSION_ID: felt252 = 'DAILY_LOGIN_MISSION';
const SCOUT_MISSION_ID: felt252 = 'SCOUT_MISSION';
const START_JOURNEY_MISSION_ID: felt252 = 'START_JOURNEY_MISSION';

fn mission_ids() -> Array<felt252> {
    array![DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID, START_JOURNEY_MISSION_ID]
}

// Achievement ID
const REDEEM_INVITATION_CODE_ACHIEVEMENT_ID: felt252 = 'REDEEM_INVIT_CODE_ACHIEVEMENT';
const UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID: felt252 = 'UPGRADE_DRAGARK_LVL_ACHIEVEMENT';
const OWN_ISLAND_ACHIEVEMENT_ID: felt252 = 'OWN_ISLAND_ACHIEVEMENT';
const SEND_DRAGARK_TREASURE_HUNT_TIME_ACHIEVEMENT_ID: felt252 = 'SEND_DRG_TRSR_HUNT_ACHIEVEMENT';
const REACH_ACCOUNT_LVL_ACHIEVEMENT_ID: felt252 = 'REACH_ACCOUNT_LVL_ACHIEVEMENT';
const UPGRADE_DRAGARK_TIME_ACHIEVEMENT_ID: felt252 = 'UPGRADE_DRG_TIME_ACHIEVEMENT';

fn achievement_ids() -> Array<felt252> {
    array![
        REDEEM_INVITATION_CODE_ACHIEVEMENT_ID,
        UPGRADE_DRAGARK_LEVEL_ACHIEVEMENT_ID,
        OWN_ISLAND_ACHIEVEMENT_ID,
        SEND_DRAGARK_TREASURE_HUNT_TIME_ACHIEVEMENT_ID,
        REACH_ACCOUNT_LVL_ACHIEVEMENT_ID,
        UPGRADE_DRAGARK_TIME_ACHIEVEMENT_ID
    ]
}

// Dragon upgrade
const DRAGON_LEVEL_RANGE: (u8, u8) = (1, 20);

fn dragon_upgrade_cost(level: u8) -> (u128, u128) {
    match level {
        0 => { (BoundedU128::max(), BoundedU128::max()) },
        1 => { (30_000_000, 0) },
        2 => { (50_000_000, 0) },
        3 => { (80_000_000, 0) },
        4 => { (130_000_000, 0) },
        5 => { (200_000_000, 0) },
        6 => { (320_000_000, 0) },
        7 => { (520_000_000, 0) },
        8 => { (820_000_000, 0) },
        9 => { (1_300_000_000, 0) },
        10 => { (2_100_000_000, 25_000_000) },
        11 => { (3_200_000_000, 25_000_000) },
        12 => { (5_100_000_000, 25_000_000) },
        13 => { (8_000_000_000, 25_000_000) },
        14 => { (10_000_000_000, 50_000_000) },
        15 => { (10_000_000_000, 50_000_000) },
        16 => { (10_000_000_000, 50_000_000) },
        17 => { (10_000_000_000, 75_000_000) },
        18 => { (10_000_000_000, 75_000_000) },
        19 => { (10_000_000_000, 100_000_000) },
        _ => { (BoundedU128::max(), BoundedU128::max()) }
    }
}

fn dragon_upgrade_account_exp_bonus(dragon_level: u8) -> u64 {
    match dragon_level {
        0 => { 0 },
        1 => { 0 },
        2 => { 5 },
        3 => { 15 },
        4 => { 20 },
        5 => { 25 },
        6 => { 30 },
        7 => { 35 },
        8 => { 40 },
        9 => { 45 },
        10 => { 50 },
        11 => { 55 },
        12 => { 60 },
        13 => { 65 },
        14 => { 70 },
        15 => { 75 },
        16 => { 80 },
        17 => { 85 },
        18 => { 90 },
        19 => { 95 },
        20 => { 100 },
        _ => { 0 }
    }
}

// Free dragon stats
fn model_ids_water() -> Array<felt252> {
    array![
        18773549109300972013760498787696382487854030328259126,
        18773549109300972013760498787696382487854030328259121,
        18773549109300973342988494572612255391661090608603702,
        18773549109300973342988494572612255391661090608603697,
        18773549109300974672216490357528128295468150888948278,
        18773549109300974672216490357528128295468150888948273,
        18773549109300976001444486142444001199275211169292854,
        18773549109300976001444486142444001199275211169292849,
        18773549109300972013760578015858896752191623872209462,
        18773549109300972013760578015858896752191623872209457,
        18773549109300973342988573800774769655998684152554038,
        18773549109300973342988573800774769655998684152554033
    ]
}
fn model_ids_dark() -> Array<felt252> {
    array![
        18773560527283194226213953952536219957222334444430390,
        18773560527283194226213953952536219957222334444430385,
        18773560527283195555441949737452092861029394724774966,
        18773560527283195555441949737452092861029394724774961,
        18773560527283196884669945522367965764836455005119542,
        18773560527283196884669945522367965764836455005119537,
        18773560527283198213897941307283838668643515285464118,
        18773560527283198213897941307283838668643515285464113,
        18773560527283194226214033180698734221559927988380726,
        18773560527283194226214033180698734221559927988380721,
        18773560527283195555442028965614607125366988268725302,
        18773560527283195555442028965614607125366988268725297
    ]
}
fn model_ids_light() -> Array<felt252> {
    array![
        18773606199212083076027774611895569834695550909115446,
        18773606199212083076027774611895569834695550909115441,
        18773606199212084405255770396811442738502611189460022,
        18773606199212084405255770396811442738502611189460017,
        18773606199212085734483766181727315642309671469804598,
        18773606199212085734483766181727315642309671469804593,
        18773606199212087063711761966643188546116731750149174,
        18773606199212087063711761966643188546116731750149169,
        18773606199212083076027853840058084099033144453065782,
        18773606199212083076027853840058084099033144453065777,
        18773606199212084405255849624973957002840204733410358,
        18773606199212084405255849624973957002840204733410353
    ]
}
fn model_ids_fire() -> Array<felt252> {
    array![
        18773640453158749713388140106415082242800463257629238,
        18773640453158749713388140106415082242800463257629233,
        18773640453158751042616135891330955146607523537973814,
        18773640453158751042616135891330955146607523537973809,
        18773640453158752371844131676246828050414583818318390,
        18773640453158752371844131676246828050414583818318385,
        18773640453158753701072127461162700954221644098662966,
        18773640453158753701072127461162700954221644098662961,
        18773640453158749713388219334577596507138056801579574,
        18773640453158749713388219334577596507138056801579569,
        18773640453158751042616215119493469410945117081924150,
        18773640453158751042616215119493469410945117081924145
    ]
}

// Account Level
const ACCOUNT_LEVEL_RANGE: (u8, u8) = (1, 20);

fn account_exp_to_account_level(exp: u64) -> u8 {
    if (exp < 125) {
        1
    } else if (exp < 300) {
        2
    } else if (exp < 500) {
        3
    } else if (exp < 725) {
        4
    } else if (exp < 1000) {
        5
    } else if (exp < 1300) {
        6
    } else if (exp < 2000) {
        7
    } else if (exp < 3000) {
        8
    } else if (exp < 4200) {
        9
    } else if (exp < 5500) {
        10
    } else if (exp < 7200) {
        11
    } else if (exp < 9200) {
        12
    } else if (exp < 11200) {
        13
    } else if (exp < 13400) {
        14
    } else if (exp < 15800) {
        15
    } else if (exp < 18400) {
        16
    } else if (exp < 21200) {
        17
    } else if (exp < 24200) {
        18
    } else if (exp < 27400) {
        19
    } else {
        20
    }
}

fn account_level_to_account_exp(level: u8) -> u64 {
    match level {
        0 => { BoundedU64::max() },
        1 => { 0 },
        2 => { 125 },
        3 => { 300 },
        4 => { 500 },
        5 => { 725 },
        6 => { 1000 },
        7 => { 1300 },
        8 => { 2000 },
        9 => { 3000 },
        10 => { 4200 },
        11 => { 5500 },
        12 => { 7200 },
        13 => { 9200 },
        14 => { 11200 },
        15 => { 13400 },
        16 => { 15800 },
        17 => { 18400 },
        18 => { 21200 },
        19 => { 24200 },
        20 => { 27400 },
        _ => { BoundedU64::max() }
    }
}

// Invitation Level
const INVITATION_LEVEL_RANGE: (u8, u8) = (1, 16);

fn invitation_exp_to_invitation_level(exp: u64) -> u8 {
    if (exp < 5) {
        1
    } else if (exp < 15) {
        2
    } else if (exp < 30) {
        3
    } else if (exp < 60) {
        4
    } else if (exp < 100) {
        5
    } else if (exp < 170) {
        6
    } else if (exp < 250) {
        7
    } else if (exp < 340) {
        8
    } else if (exp < 440) {
        9
    } else if (exp < 550) {
        10
    } else if (exp < 670) {
        11
    } else if (exp < 800) {
        12
    } else if (exp < 940) {
        13
    } else if (exp < 1090) {
        14
    } else if (exp < 1250) {
        15
    } else {
        16
    }
}

fn invitation_level_to_invitation_exp(level: u8) -> u64 {
    match level {
        0 => { BoundedU64::max() },
        1 => { 0 },
        2 => { 5 },
        3 => { 15 },
        4 => { 30 },
        5 => { 60 },
        6 => { 100 },
        7 => { 170 },
        8 => { 250 },
        9 => { 340 },
        10 => { 440 },
        11 => { 550 },
        12 => { 670 },
        13 => { 800 },
        14 => { 940 },
        15 => { 1090 },
        16 => { 1250 },
        _ => { BoundedU64::max() }
    }
}

// Points
fn island_level_to_points(level: u8) -> u64 {
    match level {
        0 => { 0 },
        1 => { 10 },
        2 => { 20 },
        3 => { 32 },
        4 => { 46 },
        5 => { 62 },
        6 => { 80 },
        7 => { 100 },
        8 => { 122 },
        9 => { 150 },
        10 => { 200 },
        _ => { 0 }
    }
}

// Stone rate island
fn island_level_to_stone_rate(island_level: u8) -> u128 {
    match island_level {
        0 => { 0 },
        1 => { 100 },
        2 => { 200 },
        3 => { 300 },
        4 => { 400 },
        5 => { 500 },
        6 => { 600 },
        7 => { 700 },
        8 => { 800 },
        9 => { 900 },
        10 => { 1000 },
        _ => { 0 }
    }
}
