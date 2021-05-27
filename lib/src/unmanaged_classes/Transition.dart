import 'package:sandstone/src/unmanaged_classes/StateValue.dart';

import '../StateManager.dart';

abstract class Transition<S extends StateValue> {
	String get name;
	Map<StateValue, bool> get stateChanges;
	void Function(StateManager manager, Map<S, bool> additionalChanges)? get action;
	bool get ignoreDuplicates;
}