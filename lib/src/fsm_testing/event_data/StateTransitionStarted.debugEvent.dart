import '../../StateManager.dart';
import '../../unmanaged_classes/StateTransition.dart';
import 'DebugEventData.dart';

class StateTransitionStarted extends DebugEventData {
	StateTransition transition;
	StateTuple currentState;

	StateTransitionStarted({
		required this.transition,
		required this.currentState
	}): super(message: '');

}