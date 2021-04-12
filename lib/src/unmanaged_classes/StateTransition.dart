import '../fsm.dart';

import 'BooleanStateValue.dart';

class StateTransition {
	/// Used for debugging purposes
	final String name;
	final Map<BooleanStateValue, bool> stateChanges;
	final void Function(StateManager manager, StateTuple currentState, StateTuple nextState)? action;
	/// When true, sequential queuing of this transition will be ignored.
	final bool ignoreDuplicates;

	StateTransition({
		this.name = '',
		required this.stateChanges,
		this.action,
		this.ignoreDuplicates = false
	});
}