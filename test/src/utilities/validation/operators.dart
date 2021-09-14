import 'package:mockito/annotations.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/utilities/validation/operators.dart' as Op;
import 'package:sandstone/src/utilities/validation/operators.dart';
import 'package:test/test.dart';
import 'operators.mocks.dart';

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
	group(
		'Validation Operator API Tests',
		_operatorTests
	);
}

void _operatorTests() {
	late MockStateTuple stateTuple;
	late MockStateValue stateValue;
	late MockValue value;
	late MockAnd and;
	late MockOr or;
	late MockNot not;
	late MockEvery every;
	late MockNone none;
	late MockAny any;
	late MockOnly only;
	late MockOperator _operator;
	setUp(
		() {
			stateTuple = MockStateTuple();
			stateValue = MockStateValue();
			value = MockValue();
			and = MockAnd();
			or = MockOr();
			not = MockNot();
			every = MockEvery();
			none = MockNone();
			any = MockAny();
			only = MockOnly();
			_operator = MockOperator();
		}
	);
	group(
		'Value tests',
		() {
			test(
				'Value is Operator',
				() {
					expect(value is Op.Operator, isTrue);
				}
			);
			test(
				'Value initializes',
				() {
					expect(Op.Value(stateValue), isNotNull);
					expect(Op.Value(stateValue, altState: stateTuple), isNotNull);
				}
			);
		}
	);
	group(
		'And tests',
		() {
			test(
				'And is Operator',
				() {
					expect(and is Op.Operator, isTrue);
				}
			);
			test(
				'And initializes',
				() {
					expect(Op.And([_operator]), isNotNull);
				}
			);
		}
	);
	group(
		'Or tests',
		() {
			test(
				'Or is Operator',
				() {
					expect(or is Op.Operator, isTrue);
				}
			);
			test(
				'Or initializes',
				() {
					expect(Op.Or([_operator]), isNotNull);
				}
			);
		}
	);
	group(
		'Not tests',
		() {
			test(
				'Not is Operator',
				() {
					expect(not is Op.Operator, isTrue);
				}
			);
			test(
				'Not initializes',
				() {
					expect(Op.Not(_operator), isNotNull);
				}
			);
		}
	);
	group('Every tests', () {
		test('Every is Operator', () {
			expect(every is Op.Operator, isTrue);
		});
		test('Every initializes', () {
			Op.Every e1 = Op.Every(null);
			Op.Every e2 = Op.Every([_operator], validValue: true);
			expect(e1.values, isNull);
			expect(e1.validValue, isFalse);
			expect(e2.validValue, isTrue);
		});
	});
	group('None tests', () {
		test('None is Operator', () {
				expect(none is Op.Operator, isTrue);
		});
		test('None initializes', () {
			Op.None n1 = Op.None(null);
			Op.None n2 = Op.None([_operator], invalidValue: true);
			expect(n1.values, isNull);
			expect(n1.invalidValue, isFalse);
			expect(n2.invalidValue, isTrue);
		});
	});
	group('Any tests', () {
		test('Any is Operator', () {
			expect(any is Op.Operator, isTrue);
		});
		test('Any initializes', () {
			Op.Any a1 = Op.Any(null);
			Op.Any a2 = Op.Any([_operator], validValue: true);
			expect(a1.values, isNull);
			expect(a1.validValue, isFalse);
			expect(a2.validValue, isTrue);
		});
	});
	group('Only tests', () {
		test('Only is Operator', () {
			expect(only is Op.Operator, isTrue);
		});
		test('Only initializes', () {
			MockStateTuple altState = MockStateTuple();
			List<StateValue> values = [stateValue];
			Op.Only a1 = Op.Only(values);
			Op.Only a2 = Op.Only(values, altState: altState, validValue: true);
			expect(a1.values.every((element) => values.contains(element)), isTrue);
			expect(a1.altState, isNull);
			expect(a1.validValue, isFalse);
			expect(a2.altState == altState, isTrue);
			expect(a2.validValue, isTrue);
		});
	});
}

