// Dojo imports
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports
use dragark_test_v19::events::{
    DragonUpgraded, PointsChanged, Scouted, JourneyStarted, JourneyFinished, ShieldActivated,
    ShieldDeactivated, MissionMilestoneReached, PlayerStoneUpdate, PlayerDragarkStoneUpdate
};

// Interface
#[starknet::interface]
trait EmitterTrait<TContractState> {
    ///////////////////
    // Read Function //
    ///////////////////

    // Function for emitting the DragonUpgraded event
    // # Argument
    // * world The world address
    // * event The DragonUpgraded event
    fn emit_dragon_upgraded(self: @TContractState, world: IWorldDispatcher, event: DragonUpgraded);

    // Function for emitting the PointsChanged event
    // # Argument
    // * world The world address
    // * event The PointsChanged event
    fn emit_points_changed(self: @TContractState, world: IWorldDispatcher, event: PointsChanged);

    // Function for emitting the Scouted event
    // # Argument
    // * world The world address
    // * event The Scouted event
    fn emit_scouted(self: @TContractState, world: IWorldDispatcher, event: Scouted);

    // Function for emitting the JourneyStarted event
    // # Argument
    // * world The world address
    // * event The JourneyStarted event
    fn emit_journey_started(self: @TContractState, world: IWorldDispatcher, event: JourneyStarted);

    // Function for emitting the JourneyFinished event
    // # Argument
    // * world The world address
    // * event The JourneyFinished event
    fn emit_journey_finished(
        self: @TContractState, world: IWorldDispatcher, event: JourneyFinished
    );

    // Function for emitting the ShieldActivated event
    // # Argument
    // * world The world address
    // * event The ShieldActivated event
    fn emit_shield_activated(
        self: @TContractState, world: IWorldDispatcher, event: ShieldActivated
    );

    // Function for emitting the ShieldDeactivated event
    // # Argument
    // * world The world address
    // * event The ShieldDeactivated event
    fn emit_shield_deactivated(
        self: @TContractState, world: IWorldDispatcher, event: ShieldDeactivated
    );

    // Function for emitting the MissionMilestoneReached event
    // # Argument
    // * world The world address
    // * event The MissionMilestoneReached event
    fn emit_mission_milestone_reached(
        self: @TContractState, world: IWorldDispatcher, event: MissionMilestoneReached
    );

    // Function for emitting the PlayerStoneUpdate event
    // # Argument
    // * world The world address
    // * event The PlayerStoneUpdate event
    fn emit_player_stone_update(
        self: @TContractState, world: IWorldDispatcher, event: PlayerStoneUpdate
    );

    // Function for emitting the PlayerDragarkStoneUpdate event
    // # Argument
    // * world The world address
    // * event The PlayerDragarkStoneUpdate event
    fn emit_player_dragark_stone_update(
        self: @TContractState, world: IWorldDispatcher, event: PlayerDragarkStoneUpdate
    );
}

// Component
#[starknet::component]
mod EmitterComponent {
    // Dojo imports
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // Internal imports
    use dragark_test_v19::events::{
        DragonUpgraded, PointsChanged, Scouted, JourneyStarted, JourneyFinished, ShieldActivated,
        ShieldDeactivated, MissionMilestoneReached, PlayerStoneUpdate, PlayerDragarkStoneUpdate
    };

    // Local imports
    use super::EmitterTrait;

    // Storage
    #[storage]
    struct Storage {}

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DragonUpgraded: DragonUpgraded,
        PointsChanged: PointsChanged,
        Scouted: Scouted,
        JourneyStarted: JourneyStarted,
        JourneyFinished: JourneyFinished,
        ShieldActivated: ShieldActivated,
        ShieldDeactivated: ShieldDeactivated,
        MissionMilestoneReached: MissionMilestoneReached,
        PlayerStoneUpdate: PlayerStoneUpdate,
        PlayerDragarkStoneUpdate: PlayerDragarkStoneUpdate
    }

    // External implementations
    #[embeddable_as(EmitterImpl)]
    impl Emitter<
        TContractState, +HasComponent<TContractState>
    > of EmitterTrait<ComponentState<TContractState>> {
        // See EmitterTrait-emit_dragon_upgraded
        fn emit_dragon_upgraded(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: DragonUpgraded
        ) {
            emit!(world, (Event::DragonUpgraded(event)));
        }

        // See EmitterTrait-emit_points_changed
        fn emit_points_changed(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: PointsChanged
        ) {
            emit!(world, (Event::PointsChanged(event)));
        }

        // See EmitterTrait-emit_scouted
        fn emit_scouted(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: Scouted
        ) {
            emit!(world, (Event::Scouted(event)));
        }

        // See EmitterTrait-emit_journey_started
        fn emit_journey_started(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: JourneyStarted
        ) {
            emit!(world, (Event::JourneyStarted(event)));
        }

        // See EmitterTrait-emit_journey_finished
        fn emit_journey_finished(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: JourneyFinished
        ) {
            emit!(world, (Event::JourneyFinished(event)));
        }

        // See EmitterTrait-emit_shield_activated
        fn emit_shield_activated(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: ShieldActivated
        ) {
            emit!(world, (Event::ShieldActivated(event)));
        }

        // See EmitterTrait-emit_shield_deactivated
        fn emit_shield_deactivated(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: ShieldDeactivated
        ) {
            emit!(world, (Event::ShieldDeactivated(event)));
        }

        // See EmitterTrait-emit_mission_milestone_reached
        fn emit_mission_milestone_reached(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            event: MissionMilestoneReached
        ) {
            emit!(world, (Event::MissionMilestoneReached(event)));
        }

        // See EmitterTrait-emit_player_stone_update
        fn emit_player_stone_update(
            self: @ComponentState<TContractState>, world: IWorldDispatcher, event: PlayerStoneUpdate
        ) {
            emit!(world, (Event::PlayerStoneUpdate(event)));
        }

        // See EmitterTrait-emit_player_dragark_stone_update
        fn emit_player_dragark_stone_update(
            self: @ComponentState<TContractState>,
            world: IWorldDispatcher,
            event: PlayerDragarkStoneUpdate
        ) {
            emit!(world, (Event::PlayerDragarkStoneUpdate(event)));
        }
    }
}
