// Starknet imports
use starknet::ContractAddress;
use starknet::get_block_timestamp;

// Dojo imports
use dojo::world::{world::WORLD, IWorldDispatcherTrait, WorldStorage};

// Internal imports
use dragark::errors::{Error, assert_with_err};

fn _require_world_owner(world: WorldStorage, address: ContractAddress) {
    assert_with_err(world.dispatcher.is_owner(WORLD, address), Error::NOT_WORLD_OWNER);
}

fn _require_valid_time() {
    let cur_block_timestamp: u64 = get_block_timestamp();
    assert_with_err(cur_block_timestamp >= 1721890800, Error::INVALID_TIME);
}

fn _is_playable() -> bool {
    true
}
