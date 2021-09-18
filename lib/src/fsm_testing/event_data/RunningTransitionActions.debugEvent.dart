import '../../unmanaged_classes/Transition.dart';
import 'DebugEventData.dart';

class RunningTransitionActions extends DebugEventData {
	final Transition transition;

	RunningTransitionActions({
		required this.transition
	}): super(message: 'Running transition action "${transition.name}".');
}