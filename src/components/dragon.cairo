// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::dragon::{Dragon, DragonInfo};

// Interface
#[starknet::interface]
trait IDragonActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the Dragon model info
    // # Argument
    // * world The world address
    // * dragon_token_id ID of the specified dragon
    // # Return
    // * Dragon The Dragon model
    fn get_dragon(self: @TContractState, world: IWorldDispatcher, dragon_token_id: u128) -> Dragon;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function to activate a dragon mapped from L2
    // # Argument
    // * world The world address
    // * dragon_info DragonInfo struct
    // * signature_r Signature R
    // * signature_s Signature S
    fn activate_dragon(
        ref self: TContractState,
        world: IWorldDispatcher,
        dragon_info: DragonInfo,
        signature_r: felt252,
        signature_s: felt252
    );

    // Function to deactivate a dragon
    // # Argument
    // * world The world address
    // * map_id The map_id to deactivate the dragon
    // * dragon_token_id ID of the specified dragon
    // * signature_r Signature R
    // * signature_s Signature S
    // * nonce The nonce used for the signature
    fn deactivate_dragon(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        dragon_token_id: felt252,
        signature_r: felt252,
        signature_s: felt252,
        nonce: felt252
    );

    // Function for claiming the default dragon, used when joining the game
    // # Argument
    // * world The world address
    // * map_id The map_id to init action
    // # Return
    // * bool Whether the tx successful or not
    fn claim_default_dragon(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize
    ) -> bool;

    // Function for upgrading a dragon
    // # Argument
    // * world The world address
    // * dragon_token_id ID of the dragon to upgrade
    fn upgrade_dragon(ref self: TContractState, world: IWorldDispatcher, dragon_token_id: u128);
}

// Component
#[starknet::component]
mod DragonActionsComponent {
    // Core imports
    use poseidon::PoseidonTrait;
    use ecdsa::check_ecdsa_signature;

    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        constants::{
            ADDRESS_SIGN, PUBLIC_KEY_SIGN, DRAGON_LEVEL_RANGE, dragon_upgrade_cost, model_ids
        },
        components::{
            player::{PlayerActionsComponent, PlayerActionsComponent::PlayerActionsInternalTrait},
            emitter::{EmitterTrait, EmitterComponent}
        },
        events::{DragonUpgraded, PlayerStoneUpdate, PlayerDragarkStoneUpdate},
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{IsMapInitialized, MapInfo},
            dragon::{
                Dragon, NonceUsed, DragonInfo, DragonTrait, DragonRarity, DragonElement,
                DragonState, DragonType
            },
            player_dragon_owned::PlayerDragonOwned
        },
        errors::{Error, assert_with_err}, utils::{_is_playable, _require_valid_time}
    };

    // Local imports
    use super::IDragonActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(DragonActionsImpl)]
    impl DragonActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl PlayerActions: PlayerActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IDragonActions<ComponentState<TContractState>> {
        // See IDragonActions-get_dragon
        fn get_dragon(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, dragon_token_id: u128
        ) -> Dragon {
            get!(world, (dragon_token_id), Dragon)
        }

        // See IDragonActions-activate_dragon
        fn activate_dragon(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            dragon_info: DragonInfo,
            signature_r: felt252,
            signature_s: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let map_id: usize = dragon_info.map_id.try_into().unwrap();
            let dragon_owner: ContractAddress = dragon_info.owner.try_into().unwrap();
            let mut player_global = get!(world, (dragon_owner), PlayerGlobal);
            let mut map = get!(world, (map_id), MapInfo);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check caller (burner)
            assert_with_err(dragon_owner == caller, Error::NOT_DRAGON_OWNER, Option::None);

            // Check nonce used
            let mut nonce_used = get!(world, (dragon_info.nonce), NonceUsed);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

            // Check if the dragon has been activated or not
            let dragon_token_id: u128 = dragon_info.dragon_token_id.try_into().unwrap();
            let dragon = get!(world, (dragon_token_id), Dragon);
            assert_with_err(
                dragon.dragon_type == DragonType::None && dragon.map_id == 0,
                Error::DRAGON_ALREADY_ACTIVATED,
                Option::None
            );

            // Init dragon
            let dragon: Dragon = DragonTrait::activate_dragon(
                dragon_info, signature_r, signature_s
            );

            // Save PlayerDragonOwned model
            set!(
                world,
                (PlayerDragonOwned {
                    player: dragon_owner,
                    index: player_global.num_dragons_owned,
                    dragon_token_id: dragon.dragon_token_id
                })
            );

            // Update data 
            nonce_used.is_used = true;
            map.total_activate_dragon += 1;
            map.total_dragon += 1;
            player_global.num_dragons_owned += 1;

            // Save data
            set!(world, (nonce_used));
            set!(world, (dragon));
            set!(world, (map));
            set!(world, (player_global));
        }

        // See IDragonActions-deactivate_dragon
        fn deactivate_dragon(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            dragon_token_id: felt252,
            signature_r: felt252,
            signature_s: felt252,
            nonce: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let mut map = get!(world, (map_id), MapInfo);
            let dragon_token_id_u128: u128 = dragon_token_id.try_into().unwrap();
            let dragon = get!(world, (dragon_token_id_u128), Dragon);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check num dragons owned
            assert_with_err(
                player_global.num_dragons_owned >= 1, Error::NOT_OWN_ANY_DRAGON, Option::None
            );

            // Check dragon map id
            assert_with_err(dragon.map_id == map_id, Error::INVALID_DRAGON_MAP_ID, Option::None);

            // Check caller (burner)
            assert_with_err(dragon.owner == caller, Error::NOT_DRAGON_OWNER, Option::None);

            // Check nonce used
            let mut nonce_used = get!(world, (nonce), NonceUsed);
            assert_with_err(!nonce_used.is_used, Error::NONCE_ALREADY_USED, Option::None);

            // Check dragon type
            assert_with_err(
                dragon.dragon_type == DragonType::NFT, Error::INVALID_DRAGON_TYPE, Option::None
            );

            // Verify signature
            let message: Array<felt252> = array![
                ADDRESS_SIGN, dragon.owner.into(), dragon_token_id, nonce
            ];
            let message_hash = poseidon::poseidon_hash_span(message.span());
            assert_with_err(
                check_ecdsa_signature(message_hash, PUBLIC_KEY_SIGN, signature_r, signature_s),
                Error::SIGNATURE_NOT_MATCH,
                Option::None
            );

            // Delete dragon
            delete!(world, (dragon));

            // Update player dragon owned
            let mut i: u32 = 0;
            loop {
                if (i == player_global.num_dragons_owned) {
                    break;
                }
                let dragon_owned_id = get!(world, (caller, i), PlayerDragonOwned).dragon_token_id;
                if (dragon_token_id_u128 == dragon_owned_id) {
                    break;
                }
                i = i + 1;
            }; // Get the dragon deactivated index

            let mut dragon_owned = get!(world, (caller, i), PlayerDragonOwned);
            if (i == (player_global.num_dragons_owned - 1)) {
                delete!(world, (dragon_owned));
            } else {
                let mut last_dragon_owned = get!(
                    world, (caller, player_global.num_dragons_owned - 1), PlayerDragonOwned
                );
                dragon_owned.dragon_token_id = last_dragon_owned.dragon_token_id;

                delete!(world, (last_dragon_owned));
                set!(world, (dragon_owned));
            }

            // Update data
            nonce_used.is_used = true;
            map.total_dragon -= 1;
            map.total_deactivate_dragon += 1;
            player_global.num_dragons_owned -= 1;

            set!(world, (nonce_used));
            set!(world, (map));
            set!(world, (player_global));
        }

        // See IDragonActions-claim_default_dragon
        fn claim_default_dragon(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, map_id: usize
        ) -> bool {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player = get!(world, (caller, map_id), Player);
            let mut map = get!(world, (map_id), MapInfo);
            let mut player_global = get!(world, (caller), PlayerGlobal);
            map.dragon_token_id_counter += 1;
            let default_dragon_id: u128 = map.dragon_token_id_counter;
            let default_dragon = get!(world, (default_dragon_id), Dragon);

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check the map player is in
            assert_with_err(player_global.map_id == map_id, Error::WRONG_MAP, Option::None);

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Check that the player hasn't claimed yet
            assert_with_err(!player.is_claim_default_dragon, Error::ALREADY_CLAIMED, Option::None);

            // Check that the dragon hasn't been claimed yet
            assert_with_err(default_dragon.map_id == 0, Error::ALREADY_CLAIMED, Option::None);

            // Init dragon for user
            let dragon = Dragon {
                dragon_token_id: default_dragon_id,
                collection: Zeroable::zero(),
                owner: caller,
                map_id,
                root_owner: Zeroable::zero(),
                model_id: 18399416108126480420697739837366591432520176652608561,
                bg_id: 7165065848958115634,
                rarity: DragonRarity::Common,
                element: DragonElement::Darkness,
                level: 1,
                speed: 50,
                attack: 50,
                carrying_capacity: 100,
                state: DragonState::Idling,
                dragon_type: DragonType::Default,
                is_inserted: false,
                inserted_time: 0
            };
            set!(world, (dragon));
            set!(
                world,
                (PlayerDragonOwned {
                    player: caller,
                    index: player_global.num_dragons_owned,
                    dragon_token_id: default_dragon_id,
                })
            );

            // Update data
            map.total_claim_dragon += 1;
            map.total_dragon += 1;
            player.is_claim_default_dragon = true;
            player_global.num_dragons_owned += 1;

            // Save data
            set!(world, (map));
            set!(world, (player));
            set!(world, (player_global));

            true
        }

        // See IDragonActions-upgrade_dragon
        fn upgrade_dragon(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, dragon_token_id: u128
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let mut dragon = get!(world, (dragon_token_id), Dragon);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let cur_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check whether the player has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Check if dragon exists in the map
            assert_with_err(dragon.map_id == map_id, Error::DRAGON_NOT_EXISTS, Option::None);

            // Check the player has the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check the dragon is on idling state
            assert_with_err(
                dragon.state == DragonState::Idling, Error::DRAGON_IS_NOT_AVAILABLE, Option::None
            );

            // Check the dragon level
            let dragon_level = dragon.level;
            let (min_level, max_level) = DRAGON_LEVEL_RANGE;
            assert_with_err(
                dragon_level >= min_level && dragon_level < max_level,
                Error::INVALID_DRAGON_LEVEL,
                Option::None
            );

            // Check required resources
            let mut player_actions_comp = get_dep_component_mut!(ref self, PlayerActions);
            player = player_actions_comp
                ._update_stone(player, world, cur_timestamp); // Fetch current stone
            let (stone_required, dragark_stone_required) = dragon_upgrade_cost(dragon_level);
            assert_with_err(
                player.current_stone >= stone_required
                    && player.dragark_stone_balance >= dragark_stone_required,
                Error::NOT_ENOUGH_DRAGARK_UPGRADE_RESOURCES,
                Option::None
            );

            // Update player's resources
            player.current_stone -= stone_required;
            player.dragark_stone_balance -= dragark_stone_required;

            // Update dragon data
            let old_speed = dragon.speed;
            let old_attack = dragon.attack;
            let old_carrying_capacity = dragon.carrying_capacity;
            let dragon_level_u16: u16 = dragon_level.into();
            let dragon_level_u32: u32 = dragon_level.into();
            let base_speed = old_speed * 100 / (((dragon_level_u16 - 1) * 5) + 100);
            let base_attack = old_attack * 100 / (((dragon_level_u16 - 1) * 5) + 100);
            let base_carrying_capacity = old_carrying_capacity
                * 100
                / (((dragon_level_u32 - 1) * 5) + 100);
            dragon.speed += base_speed * 5 / 100;
            dragon.attack += base_attack * 5 / 100;
            dragon.carrying_capacity += base_carrying_capacity * 5 / 100;
            dragon.level += 1;

            // Save models
            set!(world, (player));
            set!(world, (dragon));

            // Emit events
            emitter_comp
                .emit_dragon_upgraded(
                    world,
                    DragonUpgraded {
                        dragon_token_id,
                        new_level: dragon.level,
                        new_speed: dragon.speed,
                        new_attack: dragon.attack,
                        new_carrying_capacity: dragon.carrying_capacity,
                        old_speed,
                        old_attack,
                        old_carrying_capacity
                    }
                );
            if (player.current_stone != player_stone_before) {
                emitter_comp
                    .emit_player_stone_update(
                        world,
                        PlayerStoneUpdate {
                            map_id,
                            player: caller,
                            stone_rate: player.stone_rate,
                            current_stone: player.current_stone,
                            stone_updated_time: player.stone_updated_time,
                            stone_cap: player.stone_cap
                        }
                    );
            }

            if (player.dragark_stone_balance != player_dragark_stone_before) {
                emitter_comp
                    .emit_player_dragark_stone_update(
                        world,
                        PlayerDragarkStoneUpdate {
                            map_id,
                            player: caller,
                            dragark_stone_balance: player.dragark_stone_balance
                        }
                    );
            }
        }
    }

    #[generate_trait]
    impl DragonActionsInternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of DragonActionsInternalTrait<TContractState> {
        fn _claim_free_dragon(
            ref self: ComponentState<TContractState>,
            dragon_token_id: u128,
            owner: ContractAddress,
            map_id: usize
        ) -> Dragon {
            let cur_block_timestamp = get_block_timestamp();

            // Random model id
            let data_model_id: Array<felt252> = array![
                dragon_token_id.into(),
                owner.into(),
                map_id.into(),
                'data_model_id',
                cur_block_timestamp.into()
            ];
            let model_id_index_u256: u256 = poseidon::poseidon_hash_span(data_model_id.span())
                .try_into()
                .unwrap();
            let model_id_index: usize = (model_id_index_u256 % 12).try_into().unwrap();
            let model_id = *model_ids().at(model_id_index);

            // Random speed
            let data_speed: Array<felt252> = array![
                dragon_token_id.into(),
                owner.into(),
                map_id.into(),
                'data_speed',
                cur_block_timestamp.into()
            ];
            let hash_ran_cur_speed: u256 = poseidon::poseidon_hash_span(data_speed.span())
                .try_into()
                .unwrap();
            let mut speed: u16 = 25 + (hash_ran_cur_speed % 26).try_into().unwrap();
            if (hash_ran_cur_speed % 5 == 0) {
                speed = speed * 2;
            }

            // Random attack
            let data_attack: Array<felt252> = array![
                dragon_token_id.into(),
                owner.into(),
                map_id.into(),
                'data_attack',
                cur_block_timestamp.into()
            ];
            let hash_ran_cur_attack: u256 = poseidon::poseidon_hash_span(data_attack.span())
                .try_into()
                .unwrap();
            let mut attack: u16 = 25 + (hash_ran_cur_attack % 26).try_into().unwrap();
            if (hash_ran_cur_attack % 5 == 0) {
                attack = attack * 2;
            }

            // Random carrying capacity
            let data_carrying_capacity: Array<felt252> = array![
                dragon_token_id.into(),
                owner.into(),
                map_id.into(),
                'data_carrying_capacity',
                cur_block_timestamp.into()
            ];
            let hash_ran_cur_carrying_capacity: u256 = poseidon::poseidon_hash_span(
                data_carrying_capacity.span()
            )
                .try_into()
                .unwrap();
            let mut carrying_capacity: u32 = 25
                + (hash_ran_cur_carrying_capacity % 26).try_into().unwrap();
            if (hash_ran_cur_carrying_capacity % 5 == 0) {
                carrying_capacity = carrying_capacity * 2;
            }

            Dragon {
                dragon_token_id,
                collection: Zeroable::zero(),
                owner,
                map_id: 4134154341,
                root_owner: Zeroable::zero(),
                model_id,
                bg_id: 0,
                rarity: DragonRarity::Common,
                element: DragonElement::Water,
                level: 1,
                speed,
                attack,
                carrying_capacity,
                state: DragonState::Idling,
                dragon_type: DragonType::Default,
                is_inserted: false,
                inserted_time: 0
            }
        }
    }
}
