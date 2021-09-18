
import 'package:mockito/annotations.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/utilities/validation/Validator.dart';
import 'package:sandstone/src/utilities/validation/operators.dart' as Op;
import 'package:sandstone/src/utilities/validation/operators.dart';
import 'package:test/test.dart';
import 'Validator.mocks.dart';
import 'fake_classes.dart';

@GenerateMocks([
	StateValue,
	StateTuple,
	Value,
	And,
	Or,
	Not,
	Every,
	None,
	Any,
	Only,
	Operator
])
void main() {
	group('Validator Tests.', _validatorTests);
}

void _validatorTests() {
	test(
		'Initialization test.',
		() {
			expect(Validator(MockStateTuple(), MockOperator()), isNotNull);
		}
	);
	group('Validator evaluation tests.', _validatorEvaluationTests);
}


void _validatorEvaluationTests() {
	late FakeStateTuple trueFalseState1;
	final FakeStateValue trueValue1 = FakeStateValue(true);
	final FakeStateValue falseValue1 = FakeStateValue(false);

	late FakeStateTuple trueFalseState2;
	final FakeStateValue trueValue2 = FakeStateValue(true);
	final FakeStateValue falseValue2 = FakeStateValue(false);


	late FakeStateTuple allTrueState;
	late FakeStateTuple allFalseState;

	setUp(() {
		trueFalseState1 = FakeStateTuple(
			[true, false],
			[
				FakeManagedValue(trueValue1),
				FakeManagedValue(falseValue1)
			]
		);
		trueFalseState2 = FakeStateTuple(
			[true, false],
			[
				FakeManagedValue(trueValue2),
				FakeManagedValue(falseValue2)
			]
		);
		allTrueState = FakeStateTuple(
			[true, true],
			[
				FakeManagedValue(trueValue1),
				FakeManagedValue(trueValue2)
			]
		);
		allFalseState = FakeStateTuple(
			[false, false],
			[
				FakeManagedValue(falseValue1),
				FakeManagedValue(falseValue2)
			]
		);
	});

	group('Value operator.', () {
		test('Return specified value.', () {
				expect(
					Validator(
						trueFalseState1,
						Op.Value(trueValue1)
					).evaluate(),
					isTrue
				);
		});
		test('Use alternate state.', () {
				expect(
					Validator(
						trueFalseState1,
						Op.Value(falseValue2, altState: trueFalseState2)
					).evaluate(),
					isFalse
				);
		});
		test('Unknown state value.', () {
				expect(
					Validator(
						trueFalseState1,
						Op.Value(trueValue2)
					).evaluate(),
					isNull
				);
		});
	});
	group('And operator.', () {
		test('Empty operator list.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.And([])
				).evaluate(),
				isNull
			);
		});
		test('Single operator.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.And([
						Op.Value(trueValue1)
					])
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.And([
						Op.Value(falseValue1)
					])
				).evaluate(),
				isFalse
			);
		});
		test('Uses &&.',() {
			expect(
				Validator(
					trueFalseState1,
					Op.And([
						Op.Value(trueValue1),
						Op.Value(trueValue1)
					])
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.And([
						Op.Value(falseValue1),
						Op.Value(falseValue1)
					])
				).evaluate(),
				isFalse
			);
			expect(
				Validator(
					trueFalseState1,
					Op.And([
						Op.Value(trueValue1),
						Op.Value(falseValue1)
					])
				).evaluate(),
				isFalse
			);
		});
		test('One known and one unknown state values.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.And([
						Op.Value(trueValue1),
						Op.Value(falseValue2)
					])
				).evaluate(),
				isNull
			);
		});
	});
	group('Or operator.', () {
		test('Empty operator list.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Or([])
				).evaluate(),
				isNull
			);
		});
		test('Single operator.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Or([
						Op.Value(trueValue1)
					])
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Or([
						Op.Value(falseValue1)
					])
				).evaluate(),
				isFalse
			);
		});
		test('Uses ||.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Or([
						Op.Value(trueValue1),
						Op.Value(trueValue1)
					])
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Or([
						Op.Value(falseValue1),
						Op.Value(falseValue1)
					])
				).evaluate(),
				isFalse
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Or([
						Op.Value(trueValue1),
						Op.Value(falseValue1)
					])
				).evaluate(),
				isTrue
			);
		});
		test('One known and one unknown state values', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Or([
						Op.Value(trueValue1),
						Op.Value(falseValue2)
					])
				).evaluate(),
				isNull
			);
		});
	});
	group('Not operator.', () {
		test('Inverts value.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Not(Op.Value(falseValue1))
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Not(Op.Value(trueValue1))
				).evaluate(),
				isFalse
			);
		});
		test('Handles unknown state value', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Not(Op.Value(trueValue2))
				).evaluate(),
				isNull
			);
		});
	});
	group('Every operator.', () {
		test('No operators.', () {
			expect(
				Validator(
					allTrueState,
					Op.Every([])
				).evaluate(),
				isNull
			);
			expect(
				Validator(
					allTrueState,
					Op.Every([], validValue: true)
				).evaluate(),
				isNull
			);
		});
		test('Null operator list.', () {
			expect(
				Validator(
					allTrueState,
					Op.Every(null)
				).evaluate(),
				isFalse
			);
			expect(
				Validator(
					allTrueState,
					Op.Every(null, validValue: true)
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Every(null, validValue: true)
				).evaluate(),
				isFalse
			);
		});
		test('Detected value option.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Every([
						Op.Value(trueValue1)
					])
				).evaluate(),
				isFalse
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Every([
						Op.Value(trueValue1)
					], validValue: true),
				).evaluate(),
				isTrue
			);
		});
		test('Unknown state value.', () {
			expect(
				Validator(
					allTrueState,
					Op.Every([
						Op.Value(falseValue2)
					])
				).evaluate(),
				isNull
			);
		});
	});
	group('None operator.', () {
		test('No operators.', () {
			expect(
				Validator(
					allTrueState,
					Op.None([])
				).evaluate(),
				isNull
			);
			expect(
				Validator(
					allTrueState,
					Op.None([], invalidValue: true)
				).evaluate(),
				isNull
			);
		});
		test('Null operator list.', () {
			expect(
				Validator(
					allTrueState,
					Op.None(null)
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					allTrueState,
					Op.None(null, invalidValue: true)
				).evaluate(),
				isFalse
			);
			expect(
				Validator(
					trueFalseState1,
					Op.None(null, invalidValue: true)
				).evaluate(),
				isFalse
			);
		});
		test('Detected value option.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.None([
						Op.Value(trueValue1)
					])
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.None([
						Op.Value(trueValue1)
					], invalidValue: true)
				).evaluate(),
				isFalse
			);
		});
		test('Unknown state value.', () {
			expect(
				Validator(
					allTrueState,
					Op.None([
						Op.Value(falseValue2)
					])
				).evaluate(),
				isNull
			);
		});
	});
	group('Any operator.', () {
		test('No operators.', () {
			expect(
				Validator(
					allTrueState,
					Op.Any([])
				).evaluate(),
				isNull
			);
			expect(
				Validator(
					allTrueState,
					Op.Any([], validValue: true)
				).evaluate(),
				isNull
			);
		});
		test('Null operator list.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Any(null)
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					allTrueState,
					Op.Any(null)
				).evaluate(),
				isFalse
			);
			expect(
				Validator(
					allTrueState,
					Op.Any(null, validValue: true)
				).evaluate(),
				isTrue
			);
		});
		test('Detects any.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Any([
						Op.Value(trueValue1),
						Op.Value(falseValue1)
					])
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					allTrueState,
					Op.Any([
						Op.Value(trueValue1),
						Op.Value(trueValue1)
					])
				).evaluate(),
				isFalse
			);
		});
		test('Unknown state value.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Any([
						Op.Value(trueValue1),
						Op.Value(falseValue2)
					])
				).evaluate(),
				isNull
			);
		});
		test('Detected value option.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Any([
						Op.Value(trueValue1),
					])
				).evaluate(),
				isFalse
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Any([
						Op.Value(trueValue1),
					], validValue: true)
				).evaluate(),
				isTrue
			);
		});
	});
	group('Only operator.', () {
		test('No operators.', () {
			expect(
				Validator(
					allTrueState,
					Op.Only([])
				).evaluate(),
				isNull
			);
			expect(
				Validator(
					allTrueState,
					Op.Only([], validValue: true)
				).evaluate(),
				isNull
			);
		});
		test('Ensures only specified value.', () {
			expect(
				Validator(
					trueFalseState1,
					Op.Only(
						[
							trueValue1
						],
						validValue: true
					),
				).evaluate(),
				isTrue
			);
			expect(
				Validator(
					trueFalseState1,
					Op.Only(
						[
							trueValue1
						],
						validValue: false
					),
				).evaluate(),
				isFalse
			);
		});
	});

}

