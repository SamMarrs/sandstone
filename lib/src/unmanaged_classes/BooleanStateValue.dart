import '../fsm.dart';

class BooleanStateValue {
	final bool Function(StateTuple currentState, StateManager manager) canBeTrue;
	final bool Function(StateTuple currentState, StateManager manager) canBeFalse;
	final bool value;

	BooleanStateValue({
		required this.canBeFalse,
		required this.canBeTrue,
		required this.value
	});
}