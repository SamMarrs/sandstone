import '../fsm.dart';

class BooleanStateValue {
	// TODO: Change signature to Function(StateTuple previousState, StateTuple nextState, StateManager manager)
	// may not be needed
	final bool Function(StateTuple currentState, StateTuple nextState, StateManager manager) canChangeToTrue;
	final bool Function(StateTuple currentState, StateTuple nextState, StateManager manager) canChangeToFalse;
	final bool value;

	BooleanStateValue({
		required this.canChangeToFalse,
		required this.canChangeToTrue,
		required this.value
	});
}