import '../fsm.dart';

import 'BooleanStateValue.dart';

class StateTransition {
	/// Used for debugging purposes
	final String name;
	final Map<BooleanStateValue, bool> stateChanges;
	final void Function(StateManager manager, StateTuple currentState, StateTuple nextState)? action;
	/// When true, sequential queuing of this transition will be ignored.
	///
	/// When true, it is still possible for this transition to run multiple times, without another transition in between.
	/// This can happen during state changes, when the new state invalidates queued transitions that were between this transition and itself in the queue.
	final bool ignoreDuplicates;

	StateTransition({
		this.name = '',
		required this.stateChanges,
		this.action,
		this.ignoreDuplicates = false
	});
}