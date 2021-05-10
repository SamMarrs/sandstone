

import 'dart:collection';

import 'BooleanStateValue.dart';
import 'StateTransition.dart';

typedef MirroredStateChangeCallback = void Function(MirroredTransition changes);
class FSMMirror{

	final List<MirroredStateValue> states;
	final List<MirroredTransition> transitions;
	final void Function(MirroredStateChangeCallback stateChangeCallback) stateUpdates;

	late final bool initializedCorrectly;

	FSMMirror({
		required this.states,
		required this.transitions,
		required this.stateUpdates,
	}) {
		bool initializedCorrectly = true;
		// TODO: How can failing these tests be used to prevent initialization of the state manager.

		bool sameStateMirror() {
			bool valid = states.every(
				(state) => state._mirror == null
			);
			assert(valid, 'Cannot use MirroredStateValues in multiple instances of FSMMirror');
			return valid;
		}

		bool sameTransitionMirror() {
			bool valid = transitions.every(
				(transition) => transition._mirror == null
			);
			assert(valid, 'Cannot use MirroredTransitions in multiple instances of FSMMirror');
			return valid;
		}

		bool transitionChangesFromThisMirror() {
			bool valid = transitions.every(
				(transition) => transition.stateChanges.keys.every(
					(stateValue) {
						if (stateValue is MirroredStateValue) {
							return states.contains(stateValue);
						}
						return true;
					}
				)
			);
			assert(valid, 'Found MirroredStateValue from different FSMMirror in a MirroredTransition.');
			return valid;
		}

		bool noUnChangedStateValue() {
			HashSet<BooleanStateValue> affectedStates = HashSet();
			transitions.forEach(
				(transition) {
					affectedStates.addAll(transition.stateChanges.keys.where((state) => state is MirroredStateValue));
				}
			);
			bool valid = states.every((state) => affectedStates.contains(state));
			assert(valid, 'Not every mirrored state is affected by a transition.');
			return valid;
		}

		initializedCorrectly = initializedCorrectly && sameStateMirror();
		states.forEach(
			(state) => state._mirror = this
		);

		initializedCorrectly = initializedCorrectly && sameTransitionMirror();
		transitions.forEach(
			(transition) => transition._mirror = this
		);

		initializedCorrectly = initializedCorrectly && transitionChangesFromThisMirror();
		initializedCorrectly = initializedCorrectly && noUnChangedStateValue();

		this.initializedCorrectly = initializedCorrectly;
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