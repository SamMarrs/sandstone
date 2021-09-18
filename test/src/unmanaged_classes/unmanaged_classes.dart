import 'package:mockito/annotations.dart';
import 'package:sandstone/src/StateManager.dart';
import 'package:sandstone/src/fsm_testing/FSMEventIDs.dart';
import 'package:sandstone/src/fsm_testing/event_data/DebugEventData.dart';
import 'package:sandstone/src/fsm_testing/event_data/FSMMirrorNoUnchangedStateValue.debugEvent.dart';
import 'package:sandstone/src/fsm_testing/event_data/FSMMirrorReusedStateValue.debugEvent.dart';
import 'package:sandstone/src/fsm_testing/event_data/FSMMirrorReusedTransition.debugEvent.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/BooleanStateValue.dart';
import 'package:sandstone/src/unmanaged_classes/StateAction.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/unmanaged_classes/fsm_mirroring.dart';
import 'package:sandstone/src/unmanaged_classes/public_index.dart';
import 'package:sandstone/src/utilities/Tuple.dart';
import 'package:test/test.dart';

import 'unmanaged_classes.mocks.dart';

@GenerateMocks([
	StateValue,
	StateTuple,
	StateManager,
	BooleanStateValue
])
void main() {
	booleanStateValue();
	fsmMirroring();
	stateAction();
	stateTransition();
}

void booleanStateValue() {
	group('BooleanStateValue.', () {
		late BooleanStateValue bsv1;
		late BooleanStateValue bsv2;
		setUp((){
			bsv1 = BooleanStateValue(
				value: true,
				validateFalse: (StateTuple previous, StateTuple next, StateManager sm) => false,
				validateTrue: (StateTuple previous, StateTuple next, StateManager sm) => false
			);
			bsv2 = BooleanStateValue(
				value: false,
				validateFalse: (StateTuple previous, StateTuple next, StateManager sm) => true,
				validateTrue: (StateTuple previous, StateTuple next, StateManager sm) => true
			);
		});

		test('Is StateValue.', () {
			expect(bsv1 is StateValue, isTrue);
		});
		test('Initializes.', () {
			expect(bsv1.value, isTrue);
			expect(bsv1.validateFalse(MockStateTuple(), MockStateTuple(), MockStateManager()), isFalse);
			expect(bsv1.validateTrue(MockStateTuple(), MockStateTuple(), MockStateManager()), isFalse);
			expect(bsv2.value, isFalse);
			expect(bsv2.validateFalse(MockStateTuple(), MockStateTuple(), MockStateManager()), isTrue);
			expect(bsv2.validateTrue(MockStateTuple(), MockStateTuple(), MockStateManager()), isTrue);

		});
	});
}

void fsmMirroring() {
	group('FSM Mirroring.', () {
		late MirroredStateValue msv1;
		late MirroredStateValue msv2;
		late Map<MirroredStateValue, bool> sc1;
		late Map<MirroredStateValue, bool> sc2;
		late MirroredTransition transition1;
		late MirroredTransition transition2;

		setUp(() {
			msv1 = MirroredStateValue(value: true,);
			msv2 = MirroredStateValue(value: false,);
			sc1 = { msv1: false, msv2: true };
			sc2 = { msv1: true, msv2: false };
			transition1 = MirroredTransition(
				name: 'name1',
				stateChanges: sc1,
				action: (StateManager sm, Map<StateValue, bool> additionalChanges) {}
			);
			transition2 = MirroredTransition(
				name: 'name2',
				stateChanges: sc2,
				ignoreDuplicates: false
			);
		});

		test('MirroredStateValue is StateValue.', () {
			expect(msv1 is StateValue, isTrue);
		});
		test('MirroredStateValue initializes.', () {
			expect(msv1.value, isTrue);
			expect(msv1.validateFalse(MockStateTuple(), MockStateTuple(), MockStateManager()), isTrue);
			expect(msv1.validateTrue(MockStateTuple(), MockStateTuple(), MockStateManager()), isTrue);
			expect(msv2.value, isFalse);
		});
		test('MirroredTransition is Transition.', () {
			expect(transition1 is Transition<MirroredStateValue>, isTrue);
		});
		test('MirroredTransition initializes.', () {
			expect(
				transition1.name,
				'name1'
			);
			expect(
				transition2.name,
				'name2'
			);
			expect(
				transition1.ignoreDuplicates,
				isTrue
			);
			expect(
				transition2.ignoreDuplicates,
				isFalse
			);
			expect(
				transition1.stateChanges == sc1,
				isTrue
			);

		});
		test('FSMMirror initializes.', () {
			List<MirroredStateValue> states = [msv1, msv2];
			List<MirroredTransition> transitions = [transition1, transition2];
			void stateUpdates(MirroredStateChangeCallback scc, RegisterDisposeCallback rdc) {}
			FSMMirror fsmMirror1 = FSMMirror(
				states: states,
				transitions: transitions,
				stateUpdates: stateUpdates
			);
			FSMMirror fsmMirror2 = FSMMirror(
				states: [msv1, msv2],
				transitions: [transition1, transition2],
				stateUpdates: stateUpdates
			);

			expect(fsmMirror1.states == states, isTrue);
			expect(fsmMirror1.transitions == transitions, isTrue);
			expect(fsmMirror1.stateUpdates == stateUpdates, isTrue);
			expect(fsmMirror1.initializedCorrectly, isTrue);

		});
		test('FSMMirror errors detected.', () {
			List<MirroredStateValue> states = [msv1, msv2];
			List<MirroredTransition> transitions = [transition1, transition2];
			void stateUpdates(MirroredStateChangeCallback scc, RegisterDisposeCallback rdc) {}
			FSMMirror fsmMirror1 = FSMMirror(
				states: states,
				transitions: transitions,
				stateUpdates: stateUpdates
			);
			FSMMirror fsmMirror2 = FSMMirror(
				states: [msv1, msv2, MirroredStateValue(value: false,)],
				transitions: [transition1, transition2],
				stateUpdates: stateUpdates
			);
			expect(fsmMirror2.initializedCorrectly, isFalse);
			expect(fsmMirror2.debugEvents.length > 0, isTrue);
			expect(
				fsmMirror2.debugEvents.singleWhere(
					(eventTuple) => eventTuple.item1 == FSMEventIDs.FSM_MIRROR_NO_REUSED_STATE_VALUE
				),
				predicate<Tuple2<FSMEventIDs, DebugEventData>>(
					(item) => item.item2 is FSMMirrorNoReusedStateValue
				)
			);
			expect(
				fsmMirror2.debugEvents.singleWhere(
					(eventTuple) => eventTuple.item1 == FSMEventIDs.FSM_MIRROR_NO_REUSED_TRANSITION
				),
				predicate<Tuple2<FSMEventIDs, DebugEventData>>(
					(item) => item.item2 is FSMMirrorNoReusedTransition
				)
			);
			expect(
				fsmMirror2.debugEvents.singleWhere(
					(eventTuple) => eventTuple.item1 == FSMEventIDs.FSM_MIRROR_NO_UNCHANGED_STATE_VALUE
				),
				predicate<Tuple2<FSMEventIDs, DebugEventData>>(
					(item) => item.item2 is FSMMirrorNoUnchangedStateValue
				)
			);
		});

	});
}

void stateAction() {
	group('StateAction.', () {
		test('Initializes.', () {
			Map<StateValue, bool> registeredStates = {
				MockStateValue(): true
			};
			StateAction sa = StateAction(
				name: 'name',
				action: (StateManager manager) {},
				registeredStateValues: registeredStates
			);
			expect(sa.name, 'name');
			expect(sa.registeredStateValues == registeredStates, isTrue);
		});
	});
}

void stateTransition() {
	group('StateTransition.', () {
		String name = 'name';
		Map<MockBooleanStateValue, bool> stateChanges = {
			MockBooleanStateValue(): true
		};
		void action(StateManager m, Map<StateValue, bool> a) {}
		late StateTransition transitionA;
		late StateTransition transitionB;

		setUp((){
			transitionA = StateTransition(
				name: name,
				stateChanges: stateChanges,
				action: action
			);
			transitionB = StateTransition(
				name: name,
				stateChanges: stateChanges,
				action: action,
				ignoreDuplicates: true
			);
		});

		test('Is Transition.', () {
			expect(transitionA is Transition<BooleanStateValue>, isTrue);
		});
		test('Initializes.', () {
			expect(transitionA.name, name);
			expect(transitionA.stateChanges == stateChanges, isTrue);
			expect(transitionA.action == action, isTrue);
			expect(transitionA.ignoreDuplicates, isFalse);
			expect(transitionB.ignoreDuplicates, isTrue);
		});
	});
}
