import '../../StateManager.dart';
import '../../unmanaged_classes/fsm_mirroring.dart';
import 'DebugEventData.dart';

class MirroredTransitionStarted extends DebugEventData {
	MirroredTransition transition;
	StateTuple currentState;

	MirroredTransitionStarted({
		required this.transition,
		required this.currentState,
	}): super(message: 'Processing mirrored transition "${transition.name}".');

}