import 'dart:collection';

import 'package:sandstone/src/unmanaged_classes/StateValue.dart';

import '../StateManager.dart';
import 'Transition.dart';

typedef MirroredStateChangeCallback = void Function(MirroredTransition changes);
typedef RegisterDisposeCallback = void Function(void Function() callback);
class FSMMirror{

	final List<MirroredStateValue> states;
	final List<MirroredTransition> transitions;
	final void Function(MirroredStateChangeCallback stateChangeCallback, RegisterDisposeCallback registerDisposeCallback) stateUpdates;

	late final bool initializedCorrectly;

	FSMMirror({
		required this.states,
		required this.transitions,
		required this.stateUpdates,
	}) {
		bool initializedCorrectly = true;

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

		bool noUnchangedStateValue() {
			HashSet<StateValue> affectedStates = HashSet();
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
		initializedCorrectly = initializedCorrectly && noUnchangedStateValue();

		this.initializedCorrectly = initializedCorrectly;
	}
}

class MirroredStateValue implements StateValue {
	FSMMirror? _mirror;
	FSMMirror? get mirror => _mirror;

	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) validateTrue = (_,__,___) => true;
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) validateFalse = (_,__,___) => true;
	final bool value;

  	MirroredStateValue({
		required this.value,
	});
}

class MirroredTransition implements Transition<MirroredStateValue> {
	FSMMirror? _mirror;
	FSMMirror? get mirror => _mirror;

	final String name;
	final Map<MirroredStateValue, bool> stateChanges;
	final void Function(StateManager manager, Map<StateValue, bool> additionalChanges)? action;
	final bool ignoreDuplicates;

	MirroredTransition({
		this.name = '',
		required this.stateChanges,
		this.action,
		this.ignoreDuplicates = true
	});
}