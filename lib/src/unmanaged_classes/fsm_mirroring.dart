import 'dart:async';
import 'dart:collection';

import 'package:sandstone/src/fsm_testing/FSMEventIDs.dart';
import 'package:sandstone/src/fsm_testing/event_data/DebugEventData.dart';
import 'package:sandstone/src/fsm_testing/event_data/FSMMirrorNoUnchangedStateValue.debugEvent.dart';
import 'package:sandstone/src/fsm_testing/event_data/FSMMirrorReusedStateValue.debugEvent.dart';
import 'package:sandstone/src/fsm_testing/event_data/FSMMirrorReusedTransition.debugEvent.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/utilities/Tuple.dart';

import '../StateManager.dart';
import 'Transition.dart';

typedef MirroredStateChangeCallback = void Function(MirroredTransition changes);
typedef RegisterDisposeCallback = void Function(void Function() callback);
class InternalFSMMirror {
	final FSMMirror fsmMirror;

	InternalFSMMirror({
		required this.fsmMirror
	});

	validate(
		StreamController<Tuple2<FSMEventIDs, DebugEventData>> debugEventStreamController
	) {
		fsmMirror.debugEvents.forEach(
			(event) => debugEventStreamController.add(event)
		);
	}
}

class FSMMirror{

	final List<MirroredStateValue> states;
	final List<MirroredTransition> transitions;
	final void Function(MirroredStateChangeCallback stateChangeCallback, RegisterDisposeCallback registerDisposeCallback) stateUpdates;

	late final bool initializedCorrectly;

	late final UnmodifiableListView<Tuple2<FSMEventIDs, DebugEventData>> debugEvents;

	FSMMirror({
		required this.states,
		required this.transitions,
		required this.stateUpdates,
	}) {
		bool initializedCorrectly = true;
		List<Tuple2<FSMEventIDs, DebugEventData>> debugEvents = [];

		bool sameStateMirror() {
			bool valid = states.every(
				(state) => state._mirror == null
			);
			if (!valid) {
				debugEvents.add(
					Tuple2(
						FSMEventIDs.FSM_MIRROR_NO_REUSED_STATE_VALUE,
						FSMMirrorNoReusedStateValue()
					)
				);
			}
			return valid;
		}

		bool sameTransitionMirror() {
			bool valid = transitions.every(
				(transition) => transition._mirror == null
			);
			if (!valid) {
				debugEvents.add(
					Tuple2(
						FSMEventIDs.FSM_MIRROR_NO_REUSED_TRANSITION,
						FSMMirrorNoReusedTransition()
					)
				);
			}
			return valid;
		}

		bool noUnchangedStateValue() {
			HashSet<MirroredStateValue> affectedStates = HashSet();
			transitions.forEach(
				(transition) {
					affectedStates.addAll(transition.stateChanges.keys);
				}
			);
			bool valid = states.every((state) => affectedStates.contains(state));
			if (!valid) {
				debugEvents.add(
					Tuple2(
						FSMEventIDs.FSM_MIRROR_NO_UNCHANGED_STATE_VALUE,
						FSMMirrorNoUnchangedStateValue()
					)
				);
			}
			return valid;
		}

		initializedCorrectly = sameStateMirror() && initializedCorrectly;
		states.forEach(
			(state) => state._mirror = this
		);

		initializedCorrectly = sameTransitionMirror() && initializedCorrectly;
		transitions.forEach(
			(transition) => transition._mirror = this
		);

		initializedCorrectly = noUnchangedStateValue() && initializedCorrectly;

		this.initializedCorrectly = initializedCorrectly;
		this.debugEvents = UnmodifiableListView(debugEvents);
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