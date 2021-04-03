import 'BooleanStateValue.dart';

class StateAction {
	/// Used for debugging.
	final String name;

	final Map<BooleanStateValue, bool> registeredStateValues;

	final void Function() action;

	StateAction({
		required this.registeredStateValues,
		required this.action,
		this.name = '',
	});
}