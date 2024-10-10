// Starknet imports
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct Player {
    #[key]
    player: ContractAddress,
    #[key]
    map_id: usize,
    is_joined_map: IsPlayerJoined,
    area_opened: u32,
    num_islands_owned: u32,
    points: u64,
    is_claim_default_dragon: bool,
    // Energy
    energy: u32,
    energy_reset_time: u64,
    energy_bought_num: u8,
    // Stone
    stone_rate: u128, // 4 decimals
    current_stone: u128, // 4 decimals
    stone_updated_time: u64,
    stone_cap: u128, // 4 decimals
    // Dragark Stone
    dragark_stone_balance: u64,
    // Account Level
    account_level: u8,
    account_exp: u64,
    account_lvl_upgrade_claims: u8,
    // Invitation Level
    invitation_level: u8,
    invitation_exp: u64,
    invitation_lvl_upgrade_claims: u8
}

#[derive(Copy, Drop, Serde, PartialEq)]
#[dojo::model]
struct PlayerGlobal {
    #[key]
    player: ContractAddress,
    map_id: usize,
    num_dragons_owned: u32,
    // Invitation
    ref_code: felt252,
    invite_code: felt252,
    total_invites: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct PlayerInviteCode {
    #[key]
    invite_code: felt252,
    player: ContractAddress
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct AccountLevelUpgrade {
    #[key]
    level: u8,
    stone_reward: u128,
    dragark_stone_reward: u64,
    free_dragark_reward: u8
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct InvitationLevelUpgrade {
    #[key]
    level: u8,
    stone_reward: u128,
    dragark_stone_reward: u64,
    free_dragark_reward: u8
}


#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
enum IsPlayerJoined {
    #[default]
    NotJoined,
    Joined
}
