

import 'dart:collection';

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
					(stateValue) {
						if (stateValue is MirroredStateValue) {
							return states.contains(stateValue);
						}
						return true;
					}
				)
			),
			'MirroredStateValues cannot be used in multiple instances of FSMMirror'
		);

		assert(
			(){
				HashSet<BooleanStateValue> affectedStates = HashSet();
				transitions.forEach(
					(transition) {
						affectedStates.addAll(transition.stateChanges.keys.where((state) => state is MirroredStateValue));
					}
				);
				return states.every((state) => affectedStates.contains(state));
			}(),
			'Not every mirrored state is affected by a transition'
		);
	}
}

class MirroredStateValue extends BooleanStateValue {
	FSMMirror? _mirror;
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
	FSMMirror? _mirror;
	FSMMirror? get mirror => _mirror;

	MirroredTransition({
		String name = '',
		required Map<BooleanStateValue, bool> stateChanges,
		bool ignoreDuplicates = true
	}): super(
		name: name,
		stateChanges: stateChanges,
		ignoreDuplicates: ignoreDuplicates
	);
}