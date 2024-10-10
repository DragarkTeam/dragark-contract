// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::shield::{Shield, ShieldType};

// Interface
#[starknet::interface]
trait IShieldActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the Shield model info
    // # Argument
    // * world The world address
    // * player The player address
    // * shield_type The shield type
    // # Return
    // * Shield The Shield model
    fn get_shield(
        self: @TContractState,
        world: IWorldDispatcher,
        player: ContractAddress,
        shield_type: ShieldType
    ) -> Shield;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function for player to activate a shield to protect their island
    // # Argument
    // * world The world address
    // * map_id The map id
    // * island_id The island id to activate the shield on
    // * shield_type The shield type
    fn activate_shield(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        island_id: usize,
        shield_type: ShieldType
    );

    // Function for player to deactivate a shield from their island
    // # Argument
    // * world The world address
    // * map_id The map id
    // * island_id The island id to deactivate the shield from
    fn deactivate_shield(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, island_id: usize
    );

    // Function for player to buy a shield by using their Dragark token
    // # Argument
    // * world The world address
    // * shield_type The shield type
    fn buy_shield(
        ref self: TContractState, world: IWorldDispatcher, shield_type: ShieldType, num: u32
    );
}

// Component
#[starknet::component]
mod ShieldActionsComponent {
    // Core imports
    use poseidon::PoseidonTrait;

    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        components::{
            player::{PlayerActionsComponent, PlayerActionsComponent::PlayerActionsInternalTrait},
            emitter::{EmitterTrait, EmitterComponent}
        },
        events::{ShieldActivated, ShieldDeactivated, PlayerStoneUpdate, PlayerDragarkStoneUpdate},
        models::{
            player::{Player, PlayerGlobal, IsPlayerJoined}, map_info::{MapInfo, IsMapInitialized},
            island::{Island}, shield::{Shield, ShieldType}
        },
        errors::{Error, assert_with_err},
        utils::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IShieldActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(ShieldActionsImpl)]
    impl ShieldActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl PlayerActions: PlayerActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IShieldActions<ComponentState<TContractState>> {
        // See IShieldActions-get_shield
        fn get_shield(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            player: ContractAddress,
            shield_type: ShieldType
        ) -> Shield {
            get!(world, (player, shield_type), Shield)
        }

        // See IShieldActions-activate_shield
        fn activate_shield(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            island_id: usize,
            shield_type: ShieldType
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let mut island = get!(world, (map_id, island_id), Island);
            let player_global = get!(world, (caller), PlayerGlobal);
            let player = get!(world, (caller, map_id), Player);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let cur_block_timestamp = get_block_timestamp();

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

            // Check if island exists
            assert_with_err(
                island.claim_waiting_time >= 30, Error::ISLAND_NOT_EXISTS, Option::None
            );

            // Verify input
            assert_with_err(
                shield_type == ShieldType::Type1
                    || shield_type == ShieldType::Type2
                    || shield_type == ShieldType::Type3
                    || shield_type == ShieldType::Type4,
                Error::INVALID_SHIELD_TYPE,
                Option::None
            );

            // Check the player owns the island
            assert_with_err(island.owner == caller, Error::NOT_OWN_ISLAND, Option::None);

            // Check the island is not protected by shield
            assert_with_err(
                cur_block_timestamp > island.shield_protection_time,
                Error::ISLAND_ALREADY_PROTECTED,
                Option::None
            );

            // Check the player has enough shield
            let mut player_shield = get!(world, (caller, shield_type), Shield);
            assert_with_err(player_shield.nums_owned > 0, Error::NOT_ENOUGH_SHIELD, Option::None);

            // Update the player's shield
            player_shield.nums_owned -= 1;

            // Update the island's shield protection time
            island.shield_protection_time = cur_block_timestamp + player_shield.protection_time;

            // Update map
            map.total_activate_shield += 1;

            // Save models
            set!(world, (player_shield));
            set!(world, (island));
            set!(world, (map));

            // Emit events
            emitter_comp
                .emit_shield_activated(
                    world,
                    ShieldActivated {
                        map_id,
                        island_id,
                        shield_type,
                        shield_protection_time: island.shield_protection_time
                    }
                );
        }

        // See IShieldActions-deactivate_shield
        fn deactivate_shield(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            island_id: usize
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut map = get!(world, (map_id), MapInfo);
            let mut island = get!(world, (map_id, island_id), Island);
            let player_global = get!(world, (caller), PlayerGlobal);
            let player = get!(world, (caller, map_id), Player);
            let emitter_comp = get_dep_component!(@self, Emitter);
            let cur_block_timestamp = get_block_timestamp();

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

            // Check if island exists
            assert_with_err(
                island.claim_waiting_time >= 30, Error::ISLAND_NOT_EXISTS, Option::None
            );

            // Check the player owns the island
            assert_with_err(island.owner == caller, Error::NOT_OWN_ISLAND, Option::None);

            // Check the island is being protected by shield
            assert_with_err(
                cur_block_timestamp <= island.shield_protection_time,
                Error::ISLAND_NOT_PROTECTED,
                Option::None
            );

            // Update the island's shield protection time
            island.shield_protection_time = cur_block_timestamp;

            // Update map
            map.total_deactivate_shield += 1;

            // Save models
            set!(world, (island));
            set!(world, (map));

            // Emit events
            emitter_comp
                .emit_shield_deactivated(
                    world,
                    ShieldDeactivated {
                        map_id, island_id, shield_protection_time: island.shield_protection_time
                    }
                );
        }

        // See IShieldActions-buy_shield
        fn buy_shield(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            shield_type: ShieldType,
            num: u32
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let emitter_comp = get_dep_component!(@self, Emitter);
            let mut player_actions_comp = get_dep_component_mut!(ref self, PlayerActions);
            let cur_block_timestamp = get_block_timestamp();

            // Check whether the map has been initialized or not
            assert_with_err(
                map.is_initialized == IsMapInitialized::Initialized,
                Error::MAP_NOT_INITIALIZED,
                Option::None
            );

            // Check whether the player_has joined the map
            assert_with_err(
                player.is_joined_map == IsPlayerJoined::Joined,
                Error::PLAYER_NOT_JOINED_MAP,
                Option::None
            );

            // Verify input
            assert_with_err(
                shield_type == ShieldType::Type1
                    || shield_type == ShieldType::Type2
                    || shield_type == ShieldType::Type3
                    || shield_type == ShieldType::Type4,
                Error::INVALID_SHIELD_TYPE,
                Option::None
            );
            assert_with_err(num > 0, Error::INVALID_NUM, Option::None);

            let num_u64: u64 = num.into();
            let num_u128: u128 = num.into();

            // According to the shield type, check the player has enough Dragark balance & update
            // it, set the protection time
            let mut protection_time: u64 = 0;
            if (shield_type == ShieldType::Type1) {
                player = player_actions_comp
                    ._update_stone(player, world, cur_block_timestamp); // Fetch current stone
                assert_with_err(
                    player.current_stone >= 500_000 * num_u128,
                    Error::NOT_ENOUGH_DRAGARK_BALANCE,
                    Option::None
                );
                player.current_stone -= 500_000 * num_u128;
                protection_time = 3600;
            } else if (shield_type == ShieldType::Type2) {
                player = player_actions_comp
                    ._update_stone(player, world, cur_block_timestamp); // Fetch current stone
                assert_with_err(
                    player.current_stone >= 1_000_000 * num_u128,
                    Error::NOT_ENOUGH_DRAGARK_BALANCE,
                    Option::None
                );
                player.current_stone -= 1_000_000 * num_u128;
                protection_time = 10800;
            } else if (shield_type == ShieldType::Type3) {
                assert_with_err(
                    player.dragark_stone_balance >= 1 * num_u64,
                    Error::NOT_ENOUGH_DRAGARK_BALANCE,
                    Option::None
                );
                player.dragark_stone_balance -= 1 * num_u64;
                protection_time = 28800;
            } else if (shield_type == ShieldType::Type4) {
                assert_with_err(
                    player.dragark_stone_balance >= 2 * num_u64,
                    Error::NOT_ENOUGH_DRAGARK_BALANCE,
                    Option::None
                );
                player.dragark_stone_balance -= 2 * num_u64;
                protection_time = 86400;
            }

            // Update the player's shield
            let mut player_shield = get!(world, (caller, shield_type), Shield);
            player_shield.nums_owned += num;
            player_shield.protection_time = protection_time;

            // Save models
            set!(world, (player));
            set!(world, (player_shield));

            // Emit events
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
}
