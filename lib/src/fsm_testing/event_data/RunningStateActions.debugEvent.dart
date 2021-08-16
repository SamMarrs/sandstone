import 'dart:collection';

import '../../StateManager.dart';
import '../../utilities/Tuple.dart';
import 'DebugEventData.dart';

class RunningStateActions extends DebugEventData {
	// TODO: The state value index should probably be replaced with an actual StateValue.
	// If StateValue is used, it needs to be the same object as the developer provided to the constructor of StateManager.
	// <action name, <state value index, should run>>
	late final UnmodifiableMapView<String, UnmodifiableMapView<int, bool>> actions;
	final StateTuple currentState;

	RunningStateActions({
		required Iterable<Tuple2<String, Map<int, bool>>> actions,
		required this.currentState
	}): super(message: '') {
		Map<String, UnmodifiableMapView<int, bool>> modifiableActions = Map();
		actions.forEach(
			(actionTuple) {
				modifiableActions[actionTuple.item1] = UnmodifiableMapView(actionTuple.item2);
			}
		);
		this.actions = UnmodifiableMapView(modifiableActions);
	}
}