#[derive(Drop, Serde)]
#[dojo::model]
pub struct PlayerIslandSlot {
    #[key]
    pub map_id: usize,
    #[key]
    pub block_id: u32,
    pub island_ids: Array<usize>
}
