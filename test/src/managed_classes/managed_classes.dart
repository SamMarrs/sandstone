import 'package:mockito/annotations.dart';
import 'package:sandstone/src/StateManager.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/managed_classes/ManagedValue.dart';
import 'package:sandstone/src/unmanaged_classes/BooleanStateValue.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/unmanaged_classes/fsm_mirroring.dart';
import 'package:test/test.dart';

import '../unmanaged_classes/unmanaged_classes.mocks.dart';

@GenerateMocks([
	StateTuple,
	StateManager,
	StateValue
])
void main() {
	managedValue();
}

void managedValue() {
	group('ManagedValue.', () {
		bool falseValidateTrue(StateTuple previous, StateTuple nextState, StateManager manager) => false;
		bool falseValidateFalse(StateTuple previous, StateTuple nextState, StateManager manager) => false;
		bool trueValidateTrue(StateTuple previous, StateTuple nextState, StateManager manager) => true;
		bool trueValidateFalse(StateTuple previous, StateTuple nextState, StateManager manager) => true;
		int position = 0;
		BooleanStateValue trueBSV = BooleanStateValue(validateFalse: falseValidateFalse, validateTrue: falseValidateTrue, value: true);
		BooleanStateValue falseBSV = BooleanStateValue(validateFalse: falseValidateFalse, validateTrue: falseValidateTrue, value: false);
		MirroredStateValue trueMSV = MirroredStateValue(value: true);
		MirroredStateValue falseMSV = MirroredStateValue(value: false);
		MockStateManager msm = MockStateManager();
		ManagedValue booleanManagedValue = InternalManagedValue.create(
			managedValue: trueBSV,
			position: position,
			manager: msm
		);
		InternalManagedValue ibmv = InternalManagedValue(booleanManagedValue);

		ManagedValue mirroredManagedValue = InternalManagedValue.create(
			managedValue: trueMSV,
			position: position,
			manager: msm
		);
		InternalManagedValue immv = InternalManagedValue(mirroredManagedValue);



		test('Initializes.', () {
			expect(ibmv.mv == booleanManagedValue, isTrue);
			expect(ibmv.validateFalse == falseValidateFalse, isTrue);
			expect(ibmv.validateTrue == falseValidateTrue, isTrue);
			expect(ibmv.position == position, isTrue);
			expect(ibmv.manager == msm, isTrue);
			expect(ibmv.stateValue == trueBSV, isTrue);

			expect(booleanManagedValue.value, isTrue);

		});
		test('isMirrored.', () {
			expect(booleanManagedValue.isMirrored, isFalse);
			expect(mirroredManagedValue.isMirrored, isTrue);
		});
		test('isValid.', () {
			// TODO: implement
		});
		test('canChange.', () {
			// TODO: implement
		});
	});
}