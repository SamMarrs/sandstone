import 'dart:collection';

import '../../StateManager.dart';
import '../../utilities/Tuple.dart';
import 'DebugEventData.dart';

class RunningStateActions extends DebugEventData {
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