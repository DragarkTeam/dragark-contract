// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::{
    models::{
        player_island_owned::PlayerIslandOwned,
        player::{
            Player, PlayerGlobal, PlayerInviteCode, AccountLevelUpgrade, InvitationLevelUpgrade
        },
        player_dragon_owned::PlayerDragonOwned
    },
};

// Interface
#[starknet::interface]
trait IPlayerActions<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function to get the PlayerDragonOwned model info
    // # Argument
    // * world The world address
    // * player The player to get info
    // * index The index of the dragon
    // # Return
    // * PlayerDragonOwned The PlayerDragonOwned model
    fn get_player_dragon_owned(
        self: @TContractState, world: IWorldDispatcher, player: ContractAddress, index: u32
    ) -> PlayerDragonOwned;

    // Function to get the PlayerIslandOwned model info
    // # Argument
    // * world The world address
    // * map_id The map_id to get info
    // * player The player to get info
    // * index The index of the island
    // # Return
    // * PlayerIslandOwned The PlayerIslandOwned model
    fn get_player_island_owned(
        self: @TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        player: ContractAddress,
        index: u32
    ) -> PlayerIslandOwned;

    // Function to get the Player model info
    // # Argument
    // * world The world address
    // * player The player to get info
    // * map_id The map_id to get info
    // # Return
    // * Player The Player model
    fn get_player(
        self: @TContractState, world: IWorldDispatcher, player: ContractAddress, map_id: usize
    ) -> Player;

    // Function to get the PlayerGlobal model info
    // # Argument
    // * world The world address
    // * player The player to get info
    // # Return
    // * PlayerGlobal The PlayerGlobal model
    fn get_player_global(
        self: @TContractState, world: IWorldDispatcher, player: ContractAddress
    ) -> PlayerGlobal;

    // Function to get the PlayerInviteCode model info
    // # Argument
    // * world The world address
    // * invite_code The invite code to get info
    // # Return
    // * PlayerInviteCode The PlayerInviteCode model
    fn get_player_invite_code(
        self: @TContractState, world: IWorldDispatcher, invite_code: felt252
    ) -> PlayerInviteCode;

    // Function to get the AccountLevelUpgrade model info
    // # Argument
    // * world The world address
    // * level The account level to get info
    // # Return
    // * AccountLevelUpgrade The AccountLevelUpgrade model
    fn get_account_level_upgrade(
        self: @TContractState, world: IWorldDispatcher, level: u8
    ) -> AccountLevelUpgrade;

    // Function to get the InvitationLevelUpgrade model info
    // # Argument
    // * world The world address
    // * level The invitation level to get info
    // # Return
    // * InvitationLevelUpgrade The InvitationLevelUpgrade model
    fn get_invitation_level_upgrade(
        self: @TContractState, world: IWorldDispatcher, level: u8
    ) -> InvitationLevelUpgrade;

    ////////////////////
    // Write Function //
    ////////////////////

    // Function to insert a dragon to claim Dragark Stone later
    // # Argument
    // * world The world address
    // * dragon_token_id The dragon token id to insert
    fn insert_dragon(ref self: TContractState, world: IWorldDispatcher, dragon_token_id: u128);

    // Function to claim Dragark Stone
    // # Argument
    // * world The world address
    // * dragon_token_id The dragon token id to claim
    fn claim_dragark_stone(
        ref self: TContractState, world: IWorldDispatcher, dragon_token_id: u128
    );

    // Function for player buying energy
    // # Argument
    // * world The world address
    // * pack The number of pack to buy
    fn buy_energy(ref self: TContractState, world: IWorldDispatcher, pack: u8);

    // Function for player upgrading account level & claimming account level upgrade reward
    // # Argument
    // * world The world address
    fn upgrade_account_level(ref self: TContractState, world: IWorldDispatcher);

    // Function for player upgrading invitation level & claimming invitation level upgrade reward
    // # Argument
    // * world The world address
    fn upgrade_invitation_level(ref self: TContractState, world: IWorldDispatcher);

    // Function for player redeeming invite code
    // # Argument
    // * world The world address
    // * invite_code The invite code
    fn redeem_invite_code(ref self: TContractState, world: IWorldDispatcher, invite_code: felt252);

    // Function for updating (add/modify/remove) account level reward
    // Only callable by admin
    // # Argument
    // * world The world address
    // * level The level want to update
    // * stone_reward The level's stone reward
    // * dragark_stone_reward The level's dragark stone reward
    fn update_account_level_reward(
        ref self: TContractState,
        world: IWorldDispatcher,
        level: u8,
        stone_reward: u128,
        dragark_stone_reward: u64,
        free_dragark_reward: u8
    );

    // Function for updating (add/modify/remove) invitation level reward
    // Only callable by admin
    // # Argument
    // * world The world address
    // * level The level want to update
    // * stone_reward The level's stone reward
    // * dragark_stone_reward The level's dragark stone reward
    fn update_invitation_level_reward(
        ref self: TContractState,
        world: IWorldDispatcher,
        level: u8,
        stone_reward: u128,
        dragark_stone_reward: u64,
        free_dragark_reward: u8
    );
}

// Component
#[starknet::component]
mod PlayerActionsComponent {
    // Starknet imports
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::{
        constants::{
            START_TIMESTAMP, TOTAL_TIMESTAMPS_PER_DAY, ACCOUNT_LEVEL_RANGE, INVITATION_LEVEL_RANGE,
            account_exp_to_account_level, account_level_to_account_exp,
            invitation_exp_to_invitation_level, invitation_level_to_invitation_exp
        },
        components::{
            dragon::{
                IDragonActions, DragonActionsComponent,
                DragonActionsComponent::DragonActionsInternalTrait
            },
            emitter::{EmitterTrait, EmitterComponent}
        },
        events::{PlayerStoneUpdate, PlayerDragarkStoneUpdate},
        models::{
            player::{
                Player, PlayerGlobal, PlayerInviteCode, AccountLevelUpgrade, InvitationLevelUpgrade,
                IsPlayerJoined
            },
            player_island_owned::PlayerIslandOwned, player_dragon_owned::PlayerDragonOwned,
            dragon::{Dragon, DragonRarity, DragonType}, map_info::{IsMapInitialized, MapInfo},
            island::Island
        },
        errors::{Error, assert_with_err, panic_by_err},
        utils::{_is_playable, _require_valid_time, _require_world_owner}
    };

    // Local imports
    use super::IPlayerActions;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // External implementations
    #[embeddable_as(PlayerActionsImpl)]
    impl PlayerActions<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl DragonActions: DragonActionsComponent::HasComponent<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of IPlayerActions<ComponentState<TContractState>> {
        // See IPlayerActions-get_player_dragon_owned
        fn get_player_dragon_owned(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            player: ContractAddress,
            index: u32
        ) -> PlayerDragonOwned {
            get!(world, (player, index), PlayerDragonOwned)
        }

        // See IPlayerActions-get_player_island_owned
        fn get_player_island_owned(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            map_id: usize,
            player: ContractAddress,
            index: u32
        ) -> PlayerIslandOwned {
            get!(world, (map_id, player, index), PlayerIslandOwned)
        }

        // See IPlayerActions-get_player
        fn get_player(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            player: ContractAddress,
            map_id: usize
        ) -> Player {
            get!(world, (player, map_id), Player)
        }

        // See IPlayerActions-get_player_global
        fn get_player_global(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, player: ContractAddress
        ) -> PlayerGlobal {
            get!(world, (player), PlayerGlobal)
        }

        // See IPlayerActions-get_player_invite_code
        fn get_player_invite_code(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, invite_code: felt252
        ) -> PlayerInviteCode {
            get!(world, (invite_code), PlayerInviteCode)
        }

        // See IPlayerActions-get_account_level_upgrade
        fn get_account_level_upgrade(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, level: u8
        ) -> AccountLevelUpgrade {
            get!(world, (level), AccountLevelUpgrade)
        }

        // See IPlayerActions-get_invitation_level_upgrade
        fn get_invitation_level_upgrade(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, level: u8
        ) -> InvitationLevelUpgrade {
            get!(world, (level), InvitationLevelUpgrade)
        }

        // See IPlayerActions-insert_dragon
        fn insert_dragon(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, dragon_token_id: u128
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let current_block_timestamp = get_block_timestamp();

            // Check the player has joined the map
            assert_with_err(
                player_global.map_id.is_non_zero(), Error::PLAYER_NOT_JOINED_MAP, Option::None
            );

            // Verify input
            assert_with_err(dragon_token_id.is_non_zero(), Error::INVALID_DRAGON_ID, Option::None);

            let mut dragon = get!(world, (dragon_token_id), Dragon);

            // Check map id
            assert_with_err(dragon.map_id == player_global.map_id, Error::WRONG_MAP, Option::None);

            // Check the player owns the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check the dragon is NFT
            assert_with_err(
                dragon.dragon_type == DragonType::NFT, Error::DRAGON_NOT_NFT, Option::None
            );

            // Check that the dragon isn't being inserted
            assert_with_err(!dragon.is_inserted, Error::DRAGON_ALREADY_INSERTED, Option::None);

            // Update the dragon inserted state
            dragon.is_inserted = true;
            dragon.inserted_time = current_block_timestamp;

            // Save models
            set!(world, (dragon));
        }

        // See IPlayerActions-claim_dragark_stone
        fn claim_dragark_stone(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, dragon_token_id: u128
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let map = get!(world, (map_id), MapInfo);
            let mut player = get!(world, (caller, map_id), Player);
            let player_dragark_stone_before = player.dragark_stone_balance;
            let emitter_comp = get_dep_component!(@self, Emitter);
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
            assert_with_err(dragon_token_id.is_non_zero(), Error::INVALID_DRAGON_ID, Option::None);

            let mut dragon = get!(world, (dragon_token_id), Dragon);

            // Check map id
            assert_with_err(dragon.map_id == player_global.map_id, Error::WRONG_MAP, Option::None);

            // Check the player owns the dragon
            assert_with_err(dragon.owner == caller, Error::NOT_OWN_DRAGON, Option::None);

            // Check the dragon is NFT
            assert_with_err(
                dragon.dragon_type == DragonType::NFT, Error::DRAGON_NOT_NFT, Option::None
            );

            // Check that the dragon is being inserted
            assert_with_err(dragon.is_inserted, Error::DRAGON_NOT_INSERTED, Option::None);

            // // Check the time the dragon has been inserted
            // assert_with_err(
            //     cur_block_timestamp >= dragon.inserted_time + 28800,
            //     Error::NOT_ENOUGH_TIME_TO_CLAIM, Option::None
            // );

            // Check the time the dragon has been inserted
            assert_with_err(
                cur_block_timestamp >= dragon.inserted_time + 600,
                Error::NOT_ENOUGH_TIME_TO_CLAIM,
                Option::None
            );

            // Update the dragon inserted state
            dragon.is_inserted = false;

            // Update the Dragark balance according to the dragon's rarity
            if (dragon.rarity == DragonRarity::Common) {
                player.dragark_stone_balance += 3;
            } else if (dragon.rarity == DragonRarity::Uncommon) {
                player.dragark_stone_balance += 4;
            } else if (dragon.rarity == DragonRarity::Rare) {
                player.dragark_stone_balance += 5;
            } else if (dragon.rarity == DragonRarity::Epic) {
                player.dragark_stone_balance += 8;
            } else if (dragon.rarity == DragonRarity::Legendary) {
                player.dragark_stone_balance += 10;
            }

            // Save models
            set!(world, (dragon));
            set!(world, (player));

            // Emit events
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

        // See IPlayerActions-buy_energy
        fn buy_energy(ref self: ComponentState<TContractState>, world: IWorldDispatcher, pack: u8) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let mut player = get!(world, (caller, player_global.map_id), Player);
            let map_id = player_global.map_id;
            let mut map = get!(world, (map_id), MapInfo);
            let player_stone_before = player.current_stone;
            let player_dragark_stone_before = player.dragark_stone_balance;
            let emitter_comp = get_dep_component!(@self, Emitter);
            let cur_timestamp = get_block_timestamp();

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

            // Check pack number
            assert_with_err(pack == 1 || pack == 2, Error::INVALID_PACK_NUMBER, Option::None);

            // Check energy
            let daily_timestamp = cur_timestamp
                - ((cur_timestamp - START_TIMESTAMP) % TOTAL_TIMESTAMPS_PER_DAY);
            assert_with_err(
                daily_timestamp == player.energy_reset_time,
                Error::NOT_OUT_OF_ENERGY_YET,
                Option::None
            );
            assert_with_err(player.energy == 0, Error::NOT_OUT_OF_ENERGY_YET, Option::None);

            // Process logic
            if (pack == 1) {
                // Fetch stone & check balance
                player = self._update_stone(player, world, cur_timestamp);
                assert_with_err(
                    player.current_stone >= 500_000, Error::NOT_ENOUGH_STONE, Option::None
                );

                // Check bought number
                assert_with_err(
                    player.energy_bought_num < 2, Error::OUT_OF_ENERGY_BOUGHT, Option::None
                );

                // Deduct stone, update bought number & update energy
                player.current_stone -= 500_000;
                player.energy_bought_num += 1;
                player.energy += 10;
            } else if (pack == 2) {
                // Check dragark balance
                assert_with_err(
                    player.dragark_stone_balance >= 2,
                    Error::NOT_ENOUGH_DRAGARK_BALANCE,
                    Option::None
                );

                // Deduct dragark & update energy
                player.dragark_stone_balance -= 2;
                player.energy += 20;
            }

            // Save models
            set!(world, (player));

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

        // See IPlayerActions-upgrade_account_level
        fn upgrade_account_level(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher
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
            let mut dragon_actions_comp = get_dep_component_mut!(ref self, DragonActions);
            let cur_block_timestamp = get_block_timestamp();

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

            // Check the player level
            let player_account_level = player.account_level;
            let (min_account_level, max_account_level) = ACCOUNT_LEVEL_RANGE;
            assert_with_err(
                player_account_level >= min_account_level
                    && player_account_level < max_account_level,
                Error::INVALID_ACCOUNT_LEVEL,
                Option::None
            );

            // Check the player has enough exp to upgrade
            let player_account_exp = player.account_exp;
            let account_level_from_account_exp = account_exp_to_account_level(player_account_exp);
            assert_with_err(
                player_account_level < account_level_from_account_exp,
                Error::NOT_ENOUGH_ACCOUNT_EXP,
                Option::Some(
                    (account_level_to_account_exp(account_level_from_account_exp + 1)
                        - player_account_exp)
                        .into()
                )
            );

            // Update player account level
            player.account_level = account_level_from_account_exp;

            // Fetch current stone
            player = self._update_stone(player, world, cur_block_timestamp);

            // Process claim account level upgrade logic
            let mut current_claimed_times = player.account_lvl_upgrade_claims;
            loop {
                if (current_claimed_times + 1 == player.account_level) {
                    break;
                }

                // Get reward
                let account_level_upgrade = get!(
                    world, (current_claimed_times + 2), AccountLevelUpgrade
                );
                let stone_reward = account_level_upgrade.stone_reward;
                let dragark_stone_reward = account_level_upgrade.dragark_stone_reward;
                let free_dragark_reward = account_level_upgrade.free_dragark_reward;

                // Update reward
                player.current_stone += stone_reward;
                player.dragark_stone_balance += dragark_stone_reward;

                // Claim free dragon
                let mut dragon_claim_index = 0;
                loop {
                    if (dragon_claim_index == free_dragark_reward) {
                        break;
                    }

                    map.dragon_token_id_counter += 1;
                    let dragon = dragon_actions_comp
                        ._claim_free_dragon(map.dragon_token_id_counter, caller, map_id);
                    set!(world, (dragon));
                    set!(
                        world,
                        (PlayerDragonOwned {
                            player: caller,
                            index: player_global.num_dragons_owned,
                            dragon_token_id: dragon.dragon_token_id
                        })
                    );

                    // Update data
                    map.total_claim_dragon += 1;
                    map.total_dragon += 1;
                    player_global.num_dragons_owned += 1;

                    // Increase index
                    dragon_claim_index += 1;
                };

                // Increase index
                current_claimed_times += 1;
            };

            // Update claimed times
            player.account_lvl_upgrade_claims = current_claimed_times;

            // Update invitation exp if reached milestones
            if (player_global.ref_code.is_non_zero()) {
                let player_invite_code_addr = get!(
                    world, (player_global.ref_code), PlayerInviteCode
                )
                    .player;
                let player_ivnite_code_global = get!(
                    world, (player_invite_code_addr), PlayerGlobal
                );
                let mut player_invite_code = get!(
                    world, (player_invite_code_addr, player_ivnite_code_global.map_id), Player
                );

                player_invite_code = self
                    ._update_invitation_exp_acc_level(
                        player_invite_code, player_account_level, account_level_from_account_exp
                    );

                set!(world, (player_invite_code));
            }

            // Save models
            set!(world, (player));
            set!(world, (player_global));
            set!(world, (map));

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

        // See IPlayerActions-upgrade_invitation_level
        fn upgrade_invitation_level(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher
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
            let mut dragon_actions_comp = get_dep_component_mut!(ref self, DragonActions);
            let cur_block_timestamp = get_block_timestamp();

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

            // Check the player level
            let player_invitation_level = player.invitation_level;
            let (min_invitation_level, max_invitation_level) = INVITATION_LEVEL_RANGE;
            assert_with_err(
                player_invitation_level >= min_invitation_level
                    && player_invitation_level < max_invitation_level,
                Error::INVALID_INVITATION_LEVEL,
                Option::None
            );

            // Check the player has enough exp to upgrade
            let player_invitation_exp = player.invitation_exp;
            let invitation_level_from_invitation_exp = invitation_exp_to_invitation_level(
                player_invitation_exp
            );
            assert_with_err(
                player_invitation_level < invitation_level_from_invitation_exp,
                Error::NOT_ENOUGH_INVITATION_EXP,
                Option::Some(
                    (invitation_level_to_invitation_exp(invitation_level_from_invitation_exp + 1)
                        - player_invitation_exp)
                        .into()
                )
            );

            // Update player account level
            player.invitation_level = invitation_level_from_invitation_exp;

            // Fetch current stone
            player = self._update_stone(player, world, cur_block_timestamp);

            // Process claim invitation level upgrade logic
            let mut current_claimed_times = player.invitation_lvl_upgrade_claims;
            loop {
                if (current_claimed_times + 1 == player.account_level) {
                    break;
                }

                // Get reward
                let invitation_level_upgrade = get!(
                    world, (current_claimed_times + 2), AccountLevelUpgrade
                );
                let stone_reward = invitation_level_upgrade.stone_reward;
                let dragark_stone_reward = invitation_level_upgrade.dragark_stone_reward;
                let free_dragark_reward = invitation_level_upgrade.free_dragark_reward;

                // Update reward
                player.current_stone += stone_reward;
                player.dragark_stone_balance += dragark_stone_reward;

                // Claim free dragon
                let mut dragon_claim_index = 0;
                loop {
                    if (dragon_claim_index == free_dragark_reward) {
                        break;
                    }

                    map.dragon_token_id_counter += 1;
                    let dragon = dragon_actions_comp
                        ._claim_free_dragon(map.dragon_token_id_counter, caller, map_id);
                    set!(world, (dragon));
                    set!(
                        world,
                        (PlayerDragonOwned {
                            player: caller,
                            index: player_global.num_dragons_owned,
                            dragon_token_id: dragon.dragon_token_id
                        })
                    );

                    // Update data
                    map.total_claim_dragon += 1;
                    map.total_dragon += 1;
                    player_global.num_dragons_owned += 1;

                    // Increase index
                    dragon_claim_index += 1;
                };

                // Increase index
                current_claimed_times += 1;
            };

            // Update claimed times
            player.invitation_lvl_upgrade_claims = current_claimed_times;

            // Save models
            set!(world, (player));
            set!(world, (player_global));
            set!(world, (map));

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

        // See IPlayerActions-buy_energy
        fn redeem_invite_code(
            ref self: ComponentState<TContractState>, world: IWorldDispatcher, invite_code: felt252
        ) {
            // Check is the game playable
            assert_with_err(_is_playable(), Error::GAME_NOT_PLAYABLE, Option::None);

            // Check time
            _require_valid_time();

            let caller = get_caller_address();
            let mut player_global = get!(world, (caller), PlayerGlobal);
            let map_id = player_global.map_id;
            let map = get!(world, (map_id), MapInfo);
            let player = get!(world, (caller, map_id), Player);

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

            // Check if the invite code is valid
            let player_invite_code_addr = get!(world, (invite_code), PlayerInviteCode).player;
            let mut player_invite_code_global = get!(
                world, (player_invite_code_addr), PlayerGlobal
            );
            let mut player_invite_code = get!(
                world, (player_invite_code_addr, player_invite_code_global.map_id), Player
            );
            assert_with_err(
                player_invite_code_addr.is_non_zero()
                    && player_invite_code_global.invite_code == invite_code,
                Error::INVALID_INVITE_CODE,
                Option::None
            );

            // Check if the player has redeemed invite code
            assert_with_err(
                player_global.ref_code.is_zero(), Error::ALREADY_REDEEMED_INVITE_CODE, Option::None
            );

            // Update data
            player_invite_code_global.total_invites += 1;
            player_global.ref_code = invite_code;

            // Update invitation exp if reached milestones
            player_invite_code = self
                ._update_invitation_exp_total_invites(
                    player_invite_code, player_invite_code_global.total_invites
                );

            // Save models
            set!(world, (player_invite_code));
            set!(world, (player_invite_code_global));
            set!(world, (player_global));
        }

        // See IPlayerActions-update_account_level_reward
        fn update_account_level_reward(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            level: u8,
            stone_reward: u128,
            dragark_stone_reward: u64,
            free_dragark_reward: u8
        ) {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            // Save models
            set!(
                world,
                AccountLevelUpgrade {
                    level, stone_reward, dragark_stone_reward, free_dragark_reward
                }
            )
        }

        // See IPlayerActions-update_invitation_level_reward
        fn update_invitation_level_reward(
            ref self: ComponentState<TContractState>,
            world: IWorldDispatcher,
            level: u8,
            stone_reward: u128,
            dragark_stone_reward: u64,
            free_dragark_reward: u8
        ) {
            // Check caller
            let caller = get_caller_address();
            _require_world_owner(world, caller);

            // Save models
            set!(
                world,
                InvitationLevelUpgrade {
                    level, stone_reward, dragark_stone_reward, free_dragark_reward
                }
            )
        }
    }

    // Internal implementations
    #[generate_trait]
    impl PlayerActionsInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Emitter: EmitterComponent::HasComponent<TContractState>
    > of PlayerActionsInternalTrait<TContractState> {
        // Function for fetching stone, used for finish journey action only
        fn _update_stone_finish_journey(
            ref self: ComponentState<TContractState>,
            mut player: Player,
            world: IWorldDispatcher,
            island: Island,
            is_capturing: bool,
            cur_block_timestamp: u64
        ) -> Player {
            let emitter_comp = get_dep_component!(@self, Emitter);

            // Update current stone
            if (player.stone_updated_time > 0) {
                let time_passed = cur_block_timestamp - player.stone_updated_time;
                player.current_stone += player.stone_rate * time_passed.into();
                if (player.current_stone >= player.stone_cap) {
                    player.current_stone = player.stone_cap;
                }
            }

            // Update stone rate
            if (is_capturing) {
                if (island.level == 1) {
                    player.stone_rate += 1;
                } else if (island.level == 2) {
                    player.stone_rate += 2;
                } else if (island.level == 3) {
                    player.stone_rate += 3;
                } else if (island.level == 4) {
                    player.stone_rate += 4;
                } else if (island.level == 5) {
                    player.stone_rate += 5;
                } else if (island.level == 6) {
                    player.stone_rate += 6;
                } else if (island.level == 7) {
                    player.stone_rate += 7;
                } else if (island.level == 8) {
                    player.stone_rate += 8;
                } else if (island.level == 9) {
                    player.stone_rate += 9;
                } else if (island.level == 10) {
                    player.stone_rate += 10;
                }
            } else {
                if (island.level == 1) {
                    player.stone_rate -= 1;
                } else if (island.level == 2) {
                    player.stone_rate -= 2;
                } else if (island.level == 3) {
                    player.stone_rate -= 3;
                } else if (island.level == 4) {
                    player.stone_rate -= 4;
                } else if (island.level == 5) {
                    player.stone_rate -= 5;
                } else if (island.level == 6) {
                    player.stone_rate -= 6;
                } else if (island.level == 7) {
                    player.stone_rate -= 7;
                } else if (island.level == 8) {
                    player.stone_rate -= 8;
                } else if (island.level == 9) {
                    player.stone_rate -= 9;
                } else if (island.level == 10) {
                    player.stone_rate -= 10;
                }
            }

            // Update stone updated time
            player.stone_updated_time = cur_block_timestamp;

            // Emit events
            emitter_comp
                .emit_player_stone_update(
                    world,
                    PlayerStoneUpdate {
                        map_id: player.map_id,
                        player: player.player,
                        stone_rate: player.stone_rate,
                        current_stone: player.current_stone,
                        stone_updated_time: player.stone_updated_time,
                        stone_cap: player.stone_cap
                    }
                );

            player
        }

        // Function for fetching stone to the current block timestamp
        fn _update_stone(
            ref self: ComponentState<TContractState>,
            mut player: Player,
            world: IWorldDispatcher,
            cur_block_timestamp: u64
        ) -> Player {
            let emitter_comp = get_dep_component!(@self, Emitter);

            // Update current stone
            if (player.stone_updated_time > 0) {
                let time_passed = cur_block_timestamp - player.stone_updated_time;
                player.current_stone += player.stone_rate * time_passed.into();
                if (player.current_stone >= player.stone_cap) {
                    player.current_stone = player.stone_cap;
                }
            }

            // Update stone updated time
            player.stone_updated_time = cur_block_timestamp;

            // Emit events
            emitter_comp
                .emit_player_stone_update(
                    world,
                    PlayerStoneUpdate {
                        map_id: player.map_id,
                        player: player.player,
                        stone_rate: player.stone_rate,
                        current_stone: player.current_stone,
                        stone_updated_time: player.stone_updated_time,
                        stone_cap: player.stone_cap
                    }
                );

            player
        }

        // Function for checking & updating energy
        fn _update_energy(
            ref self: ComponentState<TContractState>, mut player: Player, daily_timestamp: u64
        ) -> Player {
            if (daily_timestamp == player.energy_reset_time) {
                assert_with_err(player.energy > 0, Error::NOT_ENOUGH_ENERGY, Option::None);
            } else if (daily_timestamp > player
                .energy_reset_time) { // A new day passed => Reset energy & timestamp
                player.energy_reset_time = daily_timestamp;
                player.energy_bought_num = 0;
                player.energy = 20;
            } else {
                panic_by_err(Error::INVALID_CASE_DAILY_TIMESTAMP, Option::None);
            }

            player
        }

        // Function for updating invitation exp based on total invites milestone
        fn _update_invitation_exp_total_invites(
            ref self: ComponentState<TContractState>, mut player: Player, total_invites: u64
        ) -> Player {
            if (total_invites == 1) {
                player.invitation_exp += 5;
            } else if (total_invites == 5) {
                player.invitation_exp += 10;
            } else if (total_invites == 10) {
                player.invitation_exp += 20;
            } else if (total_invites == 20) {
                player.invitation_exp += 50;
            } else if (total_invites == 50) {
                player.invitation_exp += 100;
            }

            player
        }

        // Function for updating invitation exp based on account level
        fn _update_invitation_exp_acc_level(
            ref self: ComponentState<TContractState>,
            mut player: Player,
            old_acc_level: u8,
            new_acc_level: u8
        ) -> Player {
            if (old_acc_level < 5) {
                if (new_acc_level >= 5 && new_acc_level < 10) {
                    player.invitation_exp += 10;
                } else if (new_acc_level >= 10 && new_acc_level < 15) {
                    player.invitation_exp += 30;
                } else if (new_acc_level >= 15 && new_acc_level < 20) {
                    player.invitation_exp += 60;
                } else if (new_acc_level == 20) {
                    player.invitation_exp += 110;
                }
            } else if (old_acc_level >= 5 && old_acc_level < 10) {
                if (new_acc_level >= 10 && new_acc_level < 15) {
                    player.invitation_exp += 20;
                } else if (new_acc_level >= 15 && new_acc_level < 20) {
                    player.invitation_exp += 50;
                } else if (new_acc_level == 20) {
                    player.invitation_level += 100;
                }
            } else if (old_acc_level >= 10 && old_acc_level < 15) {
                if (new_acc_level >= 15 && new_acc_level < 20) {
                    player.invitation_exp += 30;
                } else if (new_acc_level == 20) {
                    player.invitation_level += 80;
                }
            } else if (old_acc_level >= 15 && old_acc_level < 20) {
                if (new_acc_level == 20) {
                    player.invitation_level += 50;
                }
            }
            player
        }
    }
}
