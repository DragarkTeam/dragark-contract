// Starknet imports
use starknet::get_block_timestamp;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct NextBlockDirection {
    #[key]
    map_id: usize,
    right_1: u32,
    down_2: u32,
    left_3: u32,
    up_4: u32,
    right_5: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct NextIslandBlockDirection {
    #[key]
    map_id: usize,
    right_1: u32,
    down_2: u32,
    left_3: u32,
    up_4: u32,
    right_5: u32,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
struct Position {
    x: u32,
    y: u32
}
