import 'package:sandstone/src/managed_classes/StateTuple.dart';

import '../StateManager.dart';

/// See [BooleanStateValue] and [MirroredStateValue] for implementations.
abstract class StateValue {
	bool Function(StateTuple previous, StateTuple nextState, StateManager manager) get validateTrue;
	bool Function(StateTuple previous, StateTuple nextState, StateManager manager) get validateFalse;
	bool get value;
}