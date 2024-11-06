// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Alexandria imports
use alexandria_math::{fast_power::fast_power, fast_root::fast_nr_optimize};

// Internal imports
use dragark::{
    models::{
        achievement::{AchievementTracking, AchievementTrait},
        dragon::{Dragon, DragonRarity, DragonType, DragonState}, map::MapInfo, player::Player
    },
    constants::{SEND_DRAGARK_TREASURE_HUNT_TIME_ACHIEVEMENT_ID, FAST_ROOT_ITER},
    errors::{Error, assert_with_err}
};

// Models
#[derive(Drop, Serde)]
#[dojo::model]
struct TreasureHunt {
    #[key]
    map_id: usize,
    #[key]
    treasure_hunt_id: felt252,
    treasure_hunt_type: TreasureHuntType,
    owner: ContractAddress,
    dragon_token_ids: Array<u128>,
    start_time: u64,
    finish_time: u64,
    earned_dragark_stone: u128,
    dragon_recovery_times: Array<u64>,
    status: TreasureHuntStatus
}

// Enums
#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum TreasureHuntType {
    VIP,
    Normal1,
    Normal2,
    Normal3
}

#[derive(Copy, Drop, Serde, IntrospectPacked, PartialEq, Debug)]
enum TreasureHuntStatus {
    Started,
    Finished
}

// Impls
#[generate_trait]
impl TreasureHuntImpl of TreasureHuntTrait {
    // Internal function to handle `insert_dragon_treasure_hunt` logic
    fn insert_dragon_treasure_hunt(
        ref map: MapInfo,
        world: IWorldDispatcher,
        treasure_hunt_type: TreasureHuntType,
        dragon_token_ids: Array<u128>,
        caller: ContractAddress,
        required_dragon_level: u8,
        current_block_timestamp: u64
    ) -> felt252 {
        let map_id = map.map_id;
        let dragon_num = dragon_token_ids.len();

        // Process logic for each dragon
        let start_time: u64 = current_block_timestamp;
        let mut finish_time: u64 = current_block_timestamp;
        let mut earned_dragark_stone: u128 = 0;
        let mut dragon_recovery_times: Array<u64> = array![];
        let mut total_attack: u32 = 0;
        let mut total_capacity: u32 = 0;
        let mut i = 0;

        loop {
            if (i == dragon_num) {
                break;
            }

            // Get the dragon
            let dragon_token_id = *dragon_token_ids.at(i);
            let mut dragon = get!(world, (dragon_token_id), Dragon);

            // Check map id
            assert_with_err(dragon.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check the player owns the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check the dragon is on idling state
            assert_with_err(
                dragon.state == DragonState::Idling, Error::DRAGON_IS_NOT_AVAILABLE, Option::None
            );

            // Check the dragon isn't in recovery time
            assert_with_err(
                current_block_timestamp > dragon.recovery_time,
                Error::DRAGON_IN_RECOVERY_TIME,
                Option::None
            );

            // Check dragon sent conditions & process logic
            if (treasure_hunt_type == TreasureHuntType::VIP) {
                // Check dragon required type
                assert_with_err(
                    dragon.dragon_type == DragonType::NFT, Error::DRAGON_NOT_NFT, Option::None
                );

                // Update data
                finish_time = current_block_timestamp + 5400;
                if (dragon.rarity == DragonRarity::Common) {
                    earned_dragark_stone += 3_000_000;
                } else if (dragon.rarity == DragonRarity::Uncommon) {
                    earned_dragark_stone += 4_000_000;
                } else if (dragon.rarity == DragonRarity::Rare) {
                    earned_dragark_stone += 5_000_000;
                } else if (dragon.rarity == DragonRarity::Epic) {
                    earned_dragark_stone += 8_000_000;
                } else if (dragon.rarity == DragonRarity::Legendary) {
                    earned_dragark_stone += 10_000_000;
                }
                dragon_recovery_times.append(0);
            } else {
                // Check dragon required level
                assert_with_err(
                    dragon.level >= required_dragon_level, Error::DRAGON_LEVEL_NOT_MET, Option::None
                );

                // Update total stats
                total_attack += dragon.attack;
                total_capacity += dragon.carrying_capacity;

                // Calculate recovery time
                let dragon_recovery_time = ((3488
                    / (fast_nr_optimize(fast_power(dragon.speed.into(), 2), 3, FAST_ROOT_ITER)))
                    * 60)
                    .try_into()
                    .unwrap();
                dragon_recovery_times.append(dragon_recovery_time);
            }

            // Update dragon treasure hunt state
            dragon.state = DragonState::Hunting;

            // Save models
            set!(world, (dragon));

            // Increase index
            i += 1;
        };

        // Process earning mechanism for normal treasure hunt type
        if (treasure_hunt_type != TreasureHuntType::VIP) {
            let dragark_stone_rate_per_sec = fast_nr_optimize(
                fast_power(total_attack.into(), 4), 3, FAST_ROOT_ITER
            )
                * 12
                / 60;
            let max_dragark_stone_mined = fast_nr_optimize(
                fast_power(total_capacity.into(), 4), 3, FAST_ROOT_ITER
            )
                * 500;

            let hunting_time = (max_dragark_stone_mined / dragark_stone_rate_per_sec) + 1;
            finish_time = start_time + hunting_time.try_into().unwrap();
            earned_dragark_stone = max_dragark_stone_mined;
        }

        let data_treasure_hunt_id: Array<felt252> = array![
            (map.total_treasure_hunt + 1).into(),
            'data_treasure_hunt_id',
            map_id.into(),
            current_block_timestamp.into()
        ];
        let treasure_hunt_id = poseidon::poseidon_hash_span(data_treasure_hunt_id.span());

        // Update data
        map.total_treasure_hunt += 1;

        // Update achievement tracking
        let mut achievement_tracking = get!(
            world,
            (caller, map_id, SEND_DRAGARK_TREASURE_HUNT_TIME_ACHIEVEMENT_ID),
            AchievementTracking
        );
        AchievementTrait::_update_achievement_tracking(
            ref achievement_tracking, achievement_tracking.current_value + 1
        );

        // Save models
        let status = TreasureHuntStatus::Started;
        set!(
            world,
            (TreasureHunt {
                map_id,
                treasure_hunt_id,
                treasure_hunt_type,
                owner: caller,
                dragon_token_ids,
                start_time,
                finish_time,
                earned_dragark_stone,
                dragon_recovery_times,
                status
            })
        );
        set!(world, (map));
        set!(world, (achievement_tracking));

        treasure_hunt_id
    }

    // Internal function to handle `end_treasure_hunt` logic
    fn end_treasure_hunt(
        ref player: Player,
        world: IWorldDispatcher,
        treasure_hunt_id: felt252,
        cur_block_timestamp: u64
    ) {
        let caller = player.player;
        let map_id = player.map_id;
        let mut treasure_hunt = get!(world, (map_id, treasure_hunt_id), TreasureHunt);
        let another_treasure_hunt = get!(world, (map_id, treasure_hunt_id), TreasureHunt);
        let another_another_treasure_hunt = get!(world, (map_id, treasure_hunt_id), TreasureHunt);

        // Process logic for each dragon
        let mut i = 0;
        let dragon_token_ids = another_treasure_hunt.dragon_token_ids;
        let dragon_recovery_times = another_another_treasure_hunt.dragon_recovery_times;
        let dragon_num = dragon_token_ids.len();
        assert_with_err(
            dragon_num == dragon_recovery_times.len(),
            Error::INVALID_TREASURE_HUNT_INFO,
            Option::None
        );
        loop {
            if (i == dragon_num) {
                break;
            }

            // Get the dragon
            let dragon_token_id = *dragon_token_ids.at(i);
            let mut dragon = get!(world, (dragon_token_id), Dragon);

            // Check map id
            assert_with_err(dragon.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check the player owns the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check that the dragon isn't being inserted
            assert_with_err(
                dragon.state == DragonState::Hunting, Error::DRAGON_NOT_INSERTED, Option::None
            );

            // Check the dragon is NFT if treasure hunt type is VIP
            if (treasure_hunt.treasure_hunt_type == TreasureHuntType::VIP) {
                assert_with_err(
                    dragon.dragon_type == DragonType::NFT, Error::DRAGON_NOT_NFT, Option::None
                );
            }

            // Update the dragon state
            dragon.state = DragonState::Idling;
            dragon.recovery_time = cur_block_timestamp + *dragon_recovery_times.at(i);

            // Save models
            set!(world, (dragon));

            // Increase index
            i += 1;
        };

        // Update data
        treasure_hunt.status = TreasureHuntStatus::Finished;
        player.dragark_stone_balance += treasure_hunt.earned_dragark_stone;

        // Save models
        set!(world, (player));
        set!(world, (treasure_hunt));
    }
}
