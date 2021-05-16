import '../StateManager.dart';

import 'BooleanStateValue.dart';
import 'Transition.dart';

/// Defines a transition between states.
///
/// Instances of this class will be used by [StateManager] to traverse the FSM graph defined by this and [BooleanStateValue].
///
/// Use instances of this class to change states.
/// ```dart
/// stateManager.queueTransition(this);
/// ```
class StateTransition implements Transition<BooleanStateValue> {
	/// Used for debugging purposes
	final String name;

	/// Defines inputs to the finite state machine, possible resulting in a change of state.
	final Map<BooleanStateValue, bool> stateChanges;

	/// Defines an action to run when this [StateTransition] runs.
	///
	/// Unlike [StateAction], this will run every time this [StateTransition] runs. Even when the state does not change.
	///
	/// When optimisticTransitions is enabled within [StateManager], [additionalChanges] will provide the
	/// state changes that were not explicitly defined in this transition. The map will be empty otherwise.
	final void Function(StateManager manager, Map<BooleanStateValue, bool> additionalChanges)? action;

	/// When `true`, this [StateTransition] will never appear sequentially after itself in the transition queue.
	final bool ignoreDuplicates;

	StateTransition({
		this.name = '',
		required this.stateChanges,
		this.action,
		this.ignoreDuplicates = false
	});
}