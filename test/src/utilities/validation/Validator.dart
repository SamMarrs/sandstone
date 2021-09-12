import 'dart:collection';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sandstone/src/managed_classes/ManagedValue.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/utilities/validation/Validator.dart';
import 'package:sandstone/src/utilities/validation/operators.dart' as Op;
import 'package:sandstone/src/utilities/validation/operators.dart';
import 'package:test/test.dart';
import 'Validator.mocks.dart';

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

class _FakeManagedValue extends Fake implements ManagedValue {
	final _FakeStateValue _stateValue;

	_FakeManagedValue(
		_FakeStateValue stateValue
	): _stateValue = stateValue;
}

class _FakeStateValue extends Fake implements StateValue {
	final bool? _value;
	_FakeStateValue(
		bool? value
	): _value = value;
	bool? getValue() => _value;
}

class _FakeStateTuple extends Fake implements StateTuple {
	late final UnmodifiableListView<bool> _values;
	@override
	late final UnmodifiableListView<_FakeManagedValue> _valueReferences;

	_FakeStateTuple(
		List<bool> values,
		List<_FakeManagedValue> valueReferences
	): _values = UnmodifiableListView(values),
		_valueReferences = UnmodifiableListView(valueReferences);

	@override
	bool? getValue(StateValue sv) {
		bool unknown = !_valueReferences.map((e) => e._stateValue).contains(sv);
		return unknown ? null : (sv as _FakeStateValue).getValue();
	}
}

void _validatorEvaluationTests() {
	late _FakeStateTuple trueFalseState1;
	final _FakeStateValue trueValue1 = _FakeStateValue(true);
	final _FakeStateValue falseValue1 = _FakeStateValue(false);

	late _FakeStateTuple trueFalseState2;
	final _FakeStateValue trueValue2 = _FakeStateValue(true);
	final _FakeStateValue falseValue2 = _FakeStateValue(false);


	late _FakeStateTuple allTrueState;
	late _FakeStateTuple allFalseState;

	setUp(() {
		trueFalseState1 = _FakeStateTuple(
			[true, false],
			[
				_FakeManagedValue(trueValue1),
				_FakeManagedValue(falseValue1)
			]
		);
		trueFalseState2 = _FakeStateTuple(
			[true, false],
			[
				_FakeManagedValue(trueValue2),
				_FakeManagedValue(falseValue2)
			]
		);
		allTrueState = _FakeStateTuple(
			[true, true],
			[
				_FakeManagedValue(trueValue1),
				_FakeManagedValue(trueValue2)
			]
		);
		allFalseState = _FakeStateTuple(
			[false, false],
			[
				_FakeManagedValue(falseValue1),
				_FakeManagedValue(falseValue2)
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
		// FIXME: Unable to Mock
		// Validator._valuesFromState calls InternalStateTuple.valueReferences, which always gets the undefined StateTuple instead of FakeStateTuple
		// test('Null operator list.', () {
		// 	expect(
		// 		Validator(
		// 			allTrueState,
		// 			Op.Every(null)
		// 		).evaluate(),
		// 		isFalse
		// 	);
		// 	expect(
		// 		Validator(
		// 			allTrueState,
		// 			Op.Every(null, validValue: true)
		// 		).evaluate(),
		// 		isTrue
		// 	);
		// 	expect(
		// 		Validator(
		// 			trueFalseState1,
		// 			Op.Every(null, validValue: true)
		// 		).evaluate(),
		// 		isFalse
		// 	);
		// });
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
		// FIXME: Unable to Mock
		// Validator._valuesFromState calls InternalStateTuple.valueReferences, which always gets the undefined StateTuple instead of FakeStateTuple
		// test('Null operator list.', () {
		// 	expect(
		// 		Validator(
		// 			allTrueState,
		// 			Op.None(null)
		// 		).evaluate(),
		// 		isTrue
		// 	);
		// 	expect(
		// 		Validator(
		// 			allTrueState,
		// 			Op.None(null, invalidValue: true)
		// 		).evaluate(),
		// 		isFalse
		// 	);
		// 	expect(
		// 		Validator(
		// 			trueFalseState1,
		// 			Op.None(null, invalidValue: true)
		// 		).evaluate(),
		// 		isFalse
		// 	);
		// });
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
		// TODO: Null operator list tests all state values
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
		// TODO: The remaining tests will have the same issue as the "Null operator list" tests from the other operators.
	});

}

