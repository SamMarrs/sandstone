import 'package:mockito/annotations.dart';
import 'package:sandstone/src/StateManager.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/BooleanStateValue.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/unmanaged_classes/fsm_mirroring.dart';
import 'package:test/test.dart';

import 'unmanaged_classes.mocks.dart';

@GenerateMocks([
	StateValue,
	StateTuple,
	StateManager
])
void main() {
	booleanStateValue();
	fsmMirroring();
}

void booleanStateValue() {
	group('BooleanStateValue.', () {
		test('Initializes.', () {
			BooleanStateValue bsv1 = BooleanStateValue(
				value: true,
				validateFalse: (StateTuple previous, StateTuple next, StateManager sm) => false,
				validateTrue: (StateTuple previous, StateTuple next, StateManager sm) => false
			);
			BooleanStateValue bsv2 = BooleanStateValue(
				value: false,
				validateFalse: (StateTuple previous, StateTuple next, StateManager sm) => true,
				validateTrue: (StateTuple previous, StateTuple next, StateManager sm) => true
			);
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

		test('MirroredStateValue initializes.', () {
			expect(msv1.value, isTrue);
			expect(msv1.validateFalse(MockStateTuple(), MockStateTuple(), MockStateManager()), isTrue);
			expect(msv1.validateTrue(MockStateTuple(), MockStateTuple(), MockStateManager()), isTrue);
			expect(msv2.value, isFalse);
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
			// TODO: create unit tests
		});

	});
}