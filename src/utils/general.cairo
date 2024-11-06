// Core imports
use poseidon::PoseidonTrait;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Starknet imports
use starknet::{
    {ContractAddress, contract_address_const, get_block_timestamp, get_caller_address},
    testing::set_account_contract_address
};

// Internal imports
use dragark::{
    models::player::PoolShareInfo, constants::{DIGITS, characters}, errors::{Error, assert_with_err}
};

fn _require_world_owner(world: IWorldDispatcher, address: ContractAddress) {
    assert_with_err(world.is_owner(0, address), Error::NOT_WORLD_OWNER, Option::None);
}

fn _require_valid_time() {
    let cur_block_timestamp: u64 = get_block_timestamp();
    assert_with_err(cur_block_timestamp >= 1721890800, Error::INVALID_TIME, Option::None);
}

fn _require_valid_claim_time() {
    let cur_block_timestamp: u64 = get_block_timestamp();
    assert_with_err(cur_block_timestamp >= 1729829715, Error::INVALID_TIME, Option::None);
}

fn _is_playable() -> bool {
    true
}

fn _generate_code(salt: felt252) -> felt252 {
    let cur_timestamp = get_block_timestamp();
    let mut code: ByteArray = "";
    let player_address: felt252 = get_caller_address().into();
    let mut i = 0;
    loop {
        if (i == DIGITS) {
            break;
        }

        // Prepare random seed
        let seed: u256 = poseidon::poseidon_hash_span(
            array![player_address, i.into(), 'invite_code', cur_timestamp.into(), salt].span()
        )
            .try_into()
            .unwrap();

        // Get random index & character
        let random_index: u32 = (seed % 36).try_into().unwrap();
        let random_character = *characters().at(random_index);

        // Append to code
        code.append_word(random_character, 1);

        i += 1;
    };

    let res: felt252 = code.pending_word;

    res
}

fn total_contribution_point_to_dragark_stone_pool(
    world: IWorldDispatcher, total_contribution_points: u64, cur_block_timestamp: u64
) -> u128 {
    let mut pool: u16 = 1;
    let mut milestone: u16 = 1;
    let mut cur_dragark_stone_pool: u128 = 0;

    loop {
        let pool_share_info = get!(world, (pool, milestone), PoolShareInfo);

        // Check if the pool exists
        if (pool_share_info.start_time == 0) {
            break;
        }

        // Check time
        if (cur_block_timestamp < pool_share_info.start_time
            || cur_block_timestamp > pool_share_info.end_time) {
            pool += 1;
            continue;
        }

        // Check milestone
        if (total_contribution_points >= pool_share_info.total_cp) {
            cur_dragark_stone_pool = pool_share_info.dragark_stone_pool;
            milestone += 1;
            continue;
        } else {
            break;
        }
    };

    cur_dragark_stone_pool
}
