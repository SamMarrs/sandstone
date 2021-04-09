import '../fsm.dart';

class BooleanStateValue {
	final bool Function(StateTuple currentState, StateManager manager) canChangeFromFalse;
	final bool Function(StateTuple currentState, StateManager manager) canChangeFromTrue;
	final bool value;

	BooleanStateValue({
		required this.canChangeFromTrue,
		required this.canChangeFromFalse,
		required this.value
	});
}