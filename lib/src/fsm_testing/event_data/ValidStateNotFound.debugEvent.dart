import '../../StateManager.dart';
import '../../unmanaged_classes/Transition.dart';
import 'DebugEventData.dart';

class ValidStateNotFound extends DebugEventData {
	final Transition transition;
	final StateTuple currentState;

	ValidStateNotFound({
		required this.transition,
		required this.currentState
	}): super(message: '');
}