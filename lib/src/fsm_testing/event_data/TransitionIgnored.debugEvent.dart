import '../../StateManager.dart';
import 'DebugEventData.dart';

import '../../unmanaged_classes/Transition.dart';

class TransitionIgnored extends DebugEventData {
	final Transition transition;
	final StateTuple currentState;
	final bool? isNotKnownTransition;
	final bool? willNotSucceed;
	final bool? ignoredBecauseOfDuplicate;
	final bool? ignoredBecausePaused;

	TransitionIgnored({
		required this.transition,
		required this.currentState,
		this.isNotKnownTransition,
		this.willNotSucceed,
		this.ignoredBecauseOfDuplicate,
		this.ignoredBecausePaused,
	}): super(message: '');
}