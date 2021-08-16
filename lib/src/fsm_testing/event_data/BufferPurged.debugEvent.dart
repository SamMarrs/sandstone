import 'dart:collection';

import '../../StateManager.dart';
import '../../unmanaged_classes/StateTransition.dart';
import 'DebugEventData.dart';

class BufferPurged extends DebugEventData {
	final UnmodifiableListView<StateTransition> purgedTransitions;
	final StateTuple previousState;
	final StateTuple nextState;
	final StateTransition? activeTransition;

	BufferPurged({
		required Iterable<StateTransition> purgedTransitions,
		required this.previousState,
		required this.nextState,
		this.activeTransition
	}): this.purgedTransitions = UnmodifiableListView([...purgedTransitions]),
		super(message: 'Buffer purged of ${purgedTransitions.length} transitions.');
}