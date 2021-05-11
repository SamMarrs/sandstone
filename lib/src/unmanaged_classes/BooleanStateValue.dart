import '../configurations/StateValidationLogic.dart';

import '../StateManager.dart';

/// Defines a variable that makes up a state within a finite state machine, and how that variable should change.
///
/// Instances of this class will be used by the [StateManager] to build out a finite state machine.
/// The [StateManager] will use [BooleanStateValue.validateTrue] and [BooleanStateValue.validateFalse] to determine if a possible node within
/// the FSM graph is valid. The starting node of the FSM will be the cumulative [BooleanStateValue.value] of all initialized state values.
/// During initialization of [StateManager], [StateTransition]s will be used to traverse the FSM graph, to fine all valid states.
class BooleanStateValue {
	/// Used to define when a state is valid given that this variable is true after the transition.
	/// The [stateValidationLogic] found here, combined with the option found in [StateManager] controls how this function is used.
	///
	///
	/// To get the value correlated to this [BooleanStateValue] within the provided [StateTuple]s, use the provided [StateManager]
	/// ```dart
	/// manager.getFromState(state, this)
	/// ```
	///
	/// If optimisticTransitions is `false` within [StateManager], [nextState] will only differ from [previousState]
	/// changes defined within a [StateTransition]. [nextState] can safely be ignored.
	///
	/// If optimisticTransitions is `true` within [StateManager], [nextState] will possibly differ from [previousState]
	/// more than the changes defined within a [StateTransition]. In this case, it may be useful to look at [nextState].
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) validateTrue;

	/// Used to define when a state is valid given that this variable is false after the transition.
	/// The [stateValidationLogic] found here, combined with the option found in [StateManager] controls how this function is used.
	///
	/// To get the value correlated to this [BooleanStateValue] within the provided [StateTuple]s, use the provided [StateManager]
	/// ```dart
	/// manager.getFromState(state, this)
	/// ```
	///
	/// If optimisticTransitions is `false` within [StateManager], [nextState] will only differ from [previousState]
	/// changes defined within a [StateTransition]. [nextState] can safely be ignored.
	///
	/// If optimisticTransitions is `true` within [StateManager], [nextState] will possibly differ from [previousState]
	/// more than the changes defined within a [StateTransition]. In this case, it may be useful to look at [nextState].
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) validateFalse;

	/// Initial value this variable.
	final bool value;

	/// Defaults to what is set in [StateManager.create].
	///
	/// Overrides the [StateManager] value if set.
	///
	/// See [StateValidationLogic] for more details.
	final StateValidationLogic? stateValidationLogic;

	BooleanStateValue({
		required this.validateFalse,
		required this.validateTrue,
		required this.value,
		this.stateValidationLogic
	});
}