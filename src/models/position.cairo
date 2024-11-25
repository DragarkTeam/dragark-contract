#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct NextBlockDirection {
    #[key]
    pub map_id: usize,
    pub right_1: u32,
    pub down_2: u32,
    pub left_3: u32,
    pub up_4: u32,
    pub right_5: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct NextIslandBlockDirection {
    #[key]
    pub map_id: usize,
    pub right_1: u32,
    pub down_2: u32,
    pub left_3: u32,
    pub up_4: u32,
    pub right_5: u32,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Default, Debug)]
pub struct Position {
    pub x: u32,
    pub y: u32
}
