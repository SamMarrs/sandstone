import '../fsm.dart';

import 'BooleanStateValue.dart';

class StateTransition {
	/// Used for debugging purposes
	final String name;
	final Map<BooleanStateValue, bool> stateChanges;
	final void Function(StateManager manager, StateTuple currentState, StateTuple nextState)? action;

	StateTransition({
		this.name = '',
		required this.stateChanges,
		this.action
	});
}