// Starknet imports
use starknet::ContractAddress;

// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::models::{
    island::{Island, PositionIsland, Resource}, dragon::{Dragon, DragonInfo}, journey::{Journey},
    map_info::{MapInfo}, player_dragon_owned::{PlayerDragonOwned},
    player_island_owned::{PlayerIslandOwned}, player_island_slot::{PlayerIslandSlot},
    player::{Player, PlayerGlobal, PlayerInviteCode, AccountLevelUpgrade, InvitationLevelUpgrade},
    position::{NextBlockDirection, NextIslandBlockDirection, Position},
    scout_info::{ScoutInfo, PlayerScoutInfo}, shield::{Shield, ShieldType},
    mission::{Mission, MissionTracking}, achievement::{Achievement, AchievementTracking}
};

#[starknet::interface]
trait IActions<TContractState> {
    // Dragon
    fn get_dragon(self: @TContractState, world: IWorldDispatcher, dragon_token_id: u128) -> Dragon;
    fn activate_dragon(
        ref self: TContractState,
        world: IWorldDispatcher,
        dragon_info: DragonInfo,
        signature_r: felt252,
        signature_s: felt252
    );
    fn deactivate_dragon(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        dragon_token_id: felt252,
        signature_r: felt252,
        signature_s: felt252,
        nonce: felt252
    );
    fn claim_default_dragon(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize
    ) -> bool;

    // Map
    fn get_map_info(self: @TContractState, world: IWorldDispatcher, map_id: usize) -> MapInfo;
    fn get_next_block_direction(
        self: @TContractState, world: IWorldDispatcher, map_id: usize
    ) -> NextBlockDirection;
    fn join_map(ref self: TContractState, world: IWorldDispatcher, map_id: usize) -> bool;
    fn re_join_map(ref self: TContractState, world: IWorldDispatcher, map_id: usize) -> bool;
    fn init_new_map(ref self: TContractState, world: IWorldDispatcher) -> usize;

    // Scout
    fn get_scout_info(
        self: @TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        scout_id: felt252,
        player: ContractAddress
    ) -> ScoutInfo;
    fn get_player_scout_info(
        self: @TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        player: ContractAddress,
        position: Position
    ) -> PlayerScoutInfo;
    fn scout(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, destination: Position
    ) -> felt252;

    // Journey
    fn get_journey(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, journey_id: felt252
    ) -> Journey;
    fn start_journey(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        dragon_token_id: u128,
        island_from_id: usize,
        island_to_id: usize,
        resources: Resource
    ) -> felt252;
    fn finish_journey(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, journey_id: felt252
    ) -> bool;

    // Island
    fn get_island(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, island_id: usize
    ) -> Island;
    fn get_position_island(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, position: Position
    ) -> PositionIsland;
    fn get_player_island_slot(
        self: @TContractState, world: IWorldDispatcher, map_id: usize, block_id: u32
    ) -> PlayerIslandSlot;
    fn get_next_island_block_direction(
        self: @TContractState, world: IWorldDispatcher, map_id: usize
    ) -> NextIslandBlockDirection;
    fn claim_resources(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, island_id: usize
    ) -> bool;
    // fn claim_all_resources(
    //     ref self: TContractState, world: IWorldDispatcher, map_id: usize, island_ids: Array<usize>
    // );
    fn gen_island_per_block(ref self: TContractState, world: IWorldDispatcher, map_id: usize);

    // Shield
    fn get_shield(
        self: @TContractState,
        world: IWorldDispatcher,
        player: ContractAddress,
        shield_type: ShieldType
    ) -> Shield;
    fn activate_shield(
        ref self: TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        island_id: usize,
        shield_type: ShieldType
    );
    fn deactivate_shield(
        ref self: TContractState, world: IWorldDispatcher, map_id: usize, island_id: usize
    );
    fn buy_shield(
        ref self: TContractState, world: IWorldDispatcher, shield_type: ShieldType, num: u32
    );

    // Player
    fn get_player_dragon_owned(
        self: @TContractState, world: IWorldDispatcher, player: ContractAddress, index: u32
    ) -> PlayerDragonOwned;
    fn get_player_island_owned(
        self: @TContractState,
        world: IWorldDispatcher,
        map_id: usize,
        player: ContractAddress,
        index: u32
    ) -> PlayerIslandOwned;
    fn get_player(
        self: @TContractState, world: IWorldDispatcher, player: ContractAddress, map_id: usize
    ) -> Player;
    fn get_player_global(
        self: @TContractState, world: IWorldDispatcher, player: ContractAddress
    ) -> PlayerGlobal;
    fn get_player_invite_code(
        self: @TContractState, world: IWorldDispatcher, invite_code: felt252
    ) -> PlayerInviteCode;
    fn get_account_level_upgrade(
        self: @TContractState, world: IWorldDispatcher, level: u8
    ) -> AccountLevelUpgrade;
    fn get_invitation_level_upgrade(
        self: @TContractState, world: IWorldDispatcher, level: u8
    ) -> InvitationLevelUpgrade;
    fn insert_dragon(ref self: TContractState, world: IWorldDispatcher, dragon_token_id: u128);
    fn claim_dragark_stone(
        ref self: TContractState, world: IWorldDispatcher, dragon_token_id: u128
    );
    fn buy_energy(ref self: TContractState, world: IWorldDispatcher, pack: u8);

    // Mission
    fn get_mission(self: @TContractState, world: IWorldDispatcher, mission_id: felt252) -> Mission;
    fn get_mission_tracking(
        self: @TContractState,
        world: IWorldDispatcher,
        player: ContractAddress,
        map_id: usize,
        mission_id: felt252
    ) -> MissionTracking;
    fn claim_mission_reward(ref self: TContractState, world: IWorldDispatcher);
    fn update_mission(
        ref self: TContractState,
        world: IWorldDispatcher,
        mission_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u64>
    );

    // Achievement
    fn get_achievement(
        self: @TContractState, world: IWorldDispatcher, achievement_id: felt252
    ) -> Achievement;
    fn get_achievement_tracking(
        self: @TContractState,
        world: IWorldDispatcher,
        player: ContractAddress,
        map_id: usize,
        achievement_id: felt252
    ) -> AchievementTracking;
    fn claim_achievement_reward(ref self: TContractState, world: IWorldDispatcher);
    fn update_achievement(
        ref self: TContractState,
        world: IWorldDispatcher,
        achievement_id: felt252,
        targets: Array<u32>,
        stone_rewards: Array<u128>,
        dragark_stone_rewards: Array<u64>
    );
}

#[dojo::contract]
mod actions {
    // Component imports
    use dragark_test_v19::components::{
        dragon::DragonActionsComponent, island::IslandActionsComponent,
        journey::JourneyActionsComponent, map::MapActionsComponent, player::PlayerActionsComponent,
        scout::ScoutActionsComponent, shield::ShieldActionsComponent,
        mission::MissionActionsComponent, achievement::AchievementActionsComponent,
        base::BaseActionsComponent, emitter::EmitterComponent
    };

    // Components
    component!(path: DragonActionsComponent, storage: dragon, event: DragonActionsEvent);
    component!(path: IslandActionsComponent, storage: island, event: IslandActionsEvent);
    component!(path: JourneyActionsComponent, storage: journey, event: JourneyActionsEvent);
    component!(path: MapActionsComponent, storage: map, event: MapActionsEvent);
    component!(path: PlayerActionsComponent, storage: player, event: PlayerActionsEvent);
    component!(path: ScoutActionsComponent, storage: scout, event: ScoutActionsEvent);
    component!(path: ShieldActionsComponent, storage: shield, event: ShieldActionsEvent);
    component!(path: MissionActionsComponent, storage: mission, event: MissionActionsEvent);
    component!(
        path: AchievementActionsComponent, storage: achievement, event: AchievementActionsEvent
    );
    component!(path: BaseActionsComponent, storage: base, event: BaseActionsEvent);
    component!(path: EmitterComponent, storage: emitter, event: EmitterEvent);

    // Component impl
    #[abi(embed_v0)]
    impl DragonActionsImpl =
        DragonActionsComponent::DragonActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl IslandActionsImpl =
        IslandActionsComponent::IslandActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl JourneyActionsImpl =
        JourneyActionsComponent::JourneyActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl MapActionsImpl = MapActionsComponent::MapActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl PlayerActionsImpl =
        PlayerActionsComponent::PlayerActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl ScoutActionsImpl = ScoutActionsComponent::ScoutActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl ShieldActionsImpl =
        ShieldActionsComponent::ShieldActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl MissionActionsImpl =
        MissionActionsComponent::MissionActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl AchievementActionsImpl =
        AchievementActionsComponent::AchievementActionsImpl<ContractState>;
    #[abi(embed_v0)]
    impl BaseActionsImpl = BaseActionsComponent::BaseActionsImpl<ContractState>;
    impl EmitterImpl = EmitterComponent::EmitterImpl<ContractState>;

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        dragon: DragonActionsComponent::Storage,
        #[substorage(v0)]
        island: IslandActionsComponent::Storage,
        #[substorage(v0)]
        journey: JourneyActionsComponent::Storage,
        #[substorage(v0)]
        map: MapActionsComponent::Storage,
        #[substorage(v0)]
        player: PlayerActionsComponent::Storage,
        #[substorage(v0)]
        scout: ScoutActionsComponent::Storage,
        #[substorage(v0)]
        shield: ShieldActionsComponent::Storage,
        #[substorage(v0)]
        mission: MissionActionsComponent::Storage,
        #[substorage(v0)]
        achievement: AchievementActionsComponent::Storage,
        #[substorage(v0)]
        base: BaseActionsComponent::Storage,
        #[substorage(v0)]
        emitter: EmitterComponent::Storage
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        DragonActionsEvent: DragonActionsComponent::Event,
        #[flat]
        IslandActionsEvent: IslandActionsComponent::Event,
        #[flat]
        JourneyActionsEvent: JourneyActionsComponent::Event,
        #[flat]
        MapActionsEvent: MapActionsComponent::Event,
        #[flat]
        PlayerActionsEvent: PlayerActionsComponent::Event,
        #[flat]
        ScoutActionsEvent: ScoutActionsComponent::Event,
        #[flat]
        ShieldActionsEvent: ShieldActionsComponent::Event,
        #[flat]
        MissionActionsEvent: MissionActionsComponent::Event,
        #[flat]
        AchievementActionsEvent: AchievementActionsComponent::Event,
        #[flat]
        BaseActionsEvent: BaseActionsComponent::Event,
        #[flat]
        EmitterEvent: EmitterComponent::Event
    }
}
