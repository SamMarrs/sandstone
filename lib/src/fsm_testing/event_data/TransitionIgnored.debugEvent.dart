import '../../StateManager.dart';
import 'DebugEventData.dart';

import '../../unmanaged_classes/Transition.dart';

class TransitionIgnored extends DebugEventData {
	final Transition transition;
	final StateTuple currentState;
	final bool? isUnknownTransition;
	final bool? willNotSucceed;
	final bool? ignoredBecauseOfDuplicate;
	final bool? ignoredBecausePaused;

	TransitionIgnored._({
		required this.transition,
		required this.currentState,
		required String message,
		this.isUnknownTransition,
		this.willNotSucceed,
		this.ignoredBecauseOfDuplicate,
		this.ignoredBecausePaused,
	}): super(
		message: message
	);

	factory TransitionIgnored({
		required Transition transition,
		required StateTuple currentState,
		bool? isUnknownTransition,
		bool? willNotSucceed,
		bool? ignoredBecauseOfDuplicate,
		bool? ignoredBecausePaused,
	}) {
		String message =  'Ignoring the transition "${transition.name}".';

		return TransitionIgnored._(
			transition: transition,
			currentState: currentState,
			isUnknownTransition: isUnknownTransition,
			willNotSucceed: willNotSucceed,
			ignoredBecauseOfDuplicate: ignoredBecauseOfDuplicate,
			ignoredBecausePaused: ignoredBecausePaused,
			message: message
		);
	}
}