// Core imports
use core::integer::{BoundedU128, BoundedU64};

// Sign
const PUBLIC_KEY_SIGN: felt252 = 0x3832eeefe028b33ccb29c2b6173b2db8e851794f0a78127157c93c0f88eba89;
const ADDRESS_SIGN: felt252 = 0x0246fF8c7B475dDFb4CB5035867cBA76025F08B22938E5684C18c2aB9d9f36D3;

// Timestamp
const START_TIMESTAMP: u64 = 1724976000; // 2024/30/08 00h:00m:00s
const TOTAL_TIMESTAMPS_PER_DAY: u64 = 86400;

// Code generation
const DIGITS: u8 = 6;

#[inline]
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

#[inline]
fn mission_ids() -> Array<felt252> {
    array![DAILY_LOGIN_MISSION_ID, SCOUT_MISSION_ID, START_JOURNEY_MISSION_ID]
}

// Achievement ID
const OWN_ISLAND_ACHIEVEMENT_ID: felt252 = 'OWN_ISLAND_ACHIEVEMENT';

#[inline]
fn achievement_ids() -> Array<felt252> {
    array![OWN_ISLAND_ACHIEVEMENT_ID]
}

// Dragon upgrade
const DRAGON_LEVEL_RANGE: (u8, u8) = (1, 20);

#[inline]
fn dragon_upgrade_cost(level: u8) -> (u128, u64) {
    match level {
        0 => { (BoundedU128::max(), BoundedU64::max()) },
        1 => { (300_000, 0) },
        2 => { (500_000, 0) },
        3 => { (800_000, 0) },
        4 => { (1_300_000, 0) },
        5 => { (2_000_000, 0) },
        6 => { (3_200_000, 0) },
        7 => { (5_200_000, 0) },
        8 => { (8_200_000, 0) },
        9 => { (13_000_000, 0) },
        10 => { (21_000_000, 10) },
        11 => { (32_000_000, 10) },
        12 => { (51_000_000, 10) },
        13 => { (80_000_000, 10) },
        14 => { (100_000_000, 20) },
        15 => { (100_000_000, 20) },
        16 => { (100_000_000, 20) },
        17 => { (100_000_000, 50) },
        18 => { (100_000_000, 50) },
        19 => { (100_000_000, 50) },
        _ => { (BoundedU128::max(), BoundedU64::max()) }
    }
}

// Free dragon stats

#[inline]
fn model_ids() -> Array<felt252> {
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

// Account Level
const ACCOUNT_LEVEL_RANGE: (u8, u8) = (1, 20);

#[inline]
fn account_exp_to_account_level(exp: u64) -> u8 {
    if (exp < 75) {
        1
    } else if (exp < 200) {
        2
    } else if (exp < 325) {
        3
    } else if (exp < 500) {
        4
    } else if (exp < 725) {
        5
    } else if (exp < 1000) {
        6
    } else if (exp < 1325) {
        7
    } else if (exp < 1700) {
        8
    } else if (exp < 2125) {
        9
    } else if (exp < 2600) {
        10
    } else if (exp < 3125) {
        11
    } else if (exp < 3700) {
        12
    } else if (exp < 4325) {
        13
    } else if (exp < 5000) {
        14
    } else if (exp < 5725) {
        15
    } else if (exp < 6500) {
        16
    } else if (exp < 7500) {
        17
    } else if (exp < 9000) {
        18
    } else if (exp < 12000) {
        19
    } else {
        20
    }
}

#[inline]
fn account_level_to_account_exp(level: u8) -> u64 {
    match level {
        0 => { BoundedU64::max() },
        1 => { 0 },
        2 => { 75 },
        3 => { 200 },
        4 => { 325 },
        5 => { 500 },
        6 => { 725 },
        7 => { 1000 },
        8 => { 1325 },
        9 => { 1700 },
        10 => { 2125 },
        11 => { 2600 },
        12 => { 3125 },
        13 => { 3700 },
        14 => { 4325 },
        15 => { 5000 },
        16 => { 5725 },
        17 => { 6500 },
        18 => { 7500 },
        19 => { 9000 },
        20 => { 12000 },
        _ => { BoundedU64::max() }
    }
}

// Invitation Level
const INVITATION_LEVEL_RANGE: (u8, u8) = (1, 16);

#[inline]
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

#[inline]
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
