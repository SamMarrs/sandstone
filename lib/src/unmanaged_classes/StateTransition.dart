import '../StateManager.dart';

import 'BooleanStateValue.dart';

/// Defines a transition between states.
///
/// Instances of this class will be used by [StateManager] to traverse the FSM graph defined by this and [BooleanStateValue].
///
/// Use instances of this class to change states.
/// ```dart
/// stateManager.queueTransition(this);
/// ```
class StateTransition {
	/// Used for debugging purposes
	final String name;

	/// Defines inputs to the finite state machine, possible resulting in a change of state.
	final Map<BooleanStateValue, bool> stateChanges;

	/// Defines an action to run when this [StateTransition] runs.
	///
	/// Unlike [StateAction], this will run every time this [StateTransition] runs. Even when the state does not change.
	final void Function(StateManager manager, StateTuple currentState, StateTuple nextState)? action;

	/// When `true`, this [StateTransition] will never appear sequentially after itself in the transition queue.
	final bool ignoreDuplicates;

	StateTransition({
		this.name = '',
		required this.stateChanges,
		this.action,
		this.ignoreDuplicates = false
	});
}