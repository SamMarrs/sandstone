import '../fsm.dart';

import 'BooleanStateValue.dart';

class StateTransition {
	/// Used for debugging purposes
	final String name;
	final Map<BooleanStateValue, bool> stateChanges;
	final void Function(StateManager manager, StateTuple currentState, StateTuple nextState)? action;
	/// When true, this transition will never appear sequentially after itself in the transition queue.
	final bool ignoreDuplicates;

	StateTransition({
		this.name = '',
		required this.stateChanges,
		this.action,
		this.ignoreDuplicates = false
	});
}