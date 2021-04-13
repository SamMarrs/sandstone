import '../fsm.dart';

class BooleanStateValue {
	final bool Function(StateTuple currentState, StateManager manager) canChangeToTrue;
	final bool Function(StateTuple currentState, StateManager manager) canChangeToFalse;
	final bool value;

	BooleanStateValue({
		required this.canChangeToFalse,
		required this.canChangeToTrue,
		required this.value
	});
}