

import 'BooleanStateValue.dart';
import 'StateTransition.dart';

typedef MirroredStateChangeCallback = void Function(MirroredTransition changes, {bool clearQueue, bool jumpQueue});
class FSMMirror{

	final List<MirroredStateValue> states;
	final List<MirroredTransition> transitions;
	final void Function(MirroredStateChangeCallback stateChangeCallback) stateUpdates;

	FSMMirror({
		required this.states,
		required this.transitions,
		required this.stateUpdates,
	}) {
		// TODO: How can failing these tests be used to prevent intialiation of the state manager.
		assert(
			states.every(
				(state) => state._mirror == null
			),
			'Cannot use MirroredStateValues in multiple instances of FSMMirror'
		);
		states.forEach(
			(state) => state._mirror = this
		);

		assert(
			transitions.every(
				(transition) => transition._mirror == null
			),
			'Cannot use MirroredTransitions in multiple instances of FSMMirror'
		);
		transitions.forEach(
			(transition) => transition._mirror = this
		);

		assert(
			transitions.every(
				(transition) => transition.stateChanges.keys.every(
					(stateValue) => states.contains(stateValue)
				)
			),
			'Only MirroredStateValues initialized with this instance of FSMMirror may be used.'
		);

		assert(
			false, // TODO: Implement test
			'Not every state is affected by a transition'
		);
	}
}

class MirroredStateValue extends BooleanStateValue {
	late final FSMMirror? _mirror;
	FSMMirror? get mirror => _mirror;

  	MirroredStateValue({
		required bool value,
	}): super(
		validateFalse: (_,__,___) => true,
		validateTrue: (_,__,___) => true,
		value: value
	);
}

class MirroredTransition extends StateTransition {
	late final FSMMirror? _mirror;
	FSMMirror? get mirror => _mirror;

	MirroredTransition({
		String name = '',
		required Map<MirroredStateValue, bool> stateChanges,
		bool ignoreDuplicates = true
	}): super(
		name: name,
		stateChanges: stateChanges,
		ignoreDuplicates: ignoreDuplicates
	);
}