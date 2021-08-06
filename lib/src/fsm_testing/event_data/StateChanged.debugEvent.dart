import '../../StateManager.dart';
import '../../unmanaged_classes/Transition.dart';
import 'DebugEventData.dart';

class StateChanged extends DebugEventData {
	final StateTuple previousState;
	final StateTuple nextState;
	final Transition transition;

	StateChanged({
		required this.previousState,
		required this.nextState,
		required this.transition,
	}): super(message: '');

}