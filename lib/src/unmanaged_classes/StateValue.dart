
import '../StateManager.dart';

abstract class StateValue {
	bool Function(StateTuple previous, StateTuple nextState, StateManager manager) get validateTrue;
	bool Function(StateTuple previous, StateTuple nextState, StateManager manager) get validateFalse;
	bool get value;
}