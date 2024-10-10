#[derive(Drop, Serde)]
#[dojo::model]
struct PlayerIslandSlot {
    #[key]
    map_id: usize,
    #[key]
    block_id: u32,
    island_ids: Array<usize>
}
