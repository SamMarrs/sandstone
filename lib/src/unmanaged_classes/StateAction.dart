import 'BooleanStateValue.dart';
import '../fsm.dart';

class StateAction {
	/// Used for debugging.
	final String name;

	final Map<BooleanStateValue, bool> registeredStateValues;

	final void Function(StateManager manager, StateTuple currentState) action;

	StateAction({
		required this.registeredStateValues,
		required this.action,
		this.name = '',
	});
}