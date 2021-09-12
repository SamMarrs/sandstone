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
	group(
		'Every tests',
		() {
			test(
				'Every is Operator',
				() {
					expect(every is Op.Operator, isTrue);
				}
			);
			test(
				'Every initializes',
				() {
					expect(Op.Every(null), isNotNull);
					expect(Op.Every([_operator]), isNotNull);
					expect(Op.Every([_operator], validValue: true), isNotNull);
				}
			);
		}
	);
	group(
		'None tests',
		() {
			test(
				'None is Operator',
				() {
					expect(none is Op.Operator, isTrue);
				}
			);
			test(
				'None initializes',
				() {
					expect(Op.None(null), isNotNull);
					expect(Op.None([_operator]), isNotNull);
					expect(Op.None([_operator], invalidValue: true), isNotNull);
				}
			);
		}
	);
	group(
		'Any tests',
		() {
			test(
				'Any is Operator',
				() {
					expect(any is Op.Operator, isTrue);
				}
			);
			test(
				'Any initializes',
				() {
					expect(Op.Any(null), isNotNull);
					expect(Op.Any([_operator]), isNotNull);
					expect(Op.Any([_operator], validValue: true), isNotNull);
				}
			);
		}
	);
	group(
		'Only tests',
		() {
			test(
				'Only is Operator',
				() {
					expect(only is Op.Operator, isTrue);
				}
			);
			test(
				'Only initializes',
				() {
					expect(Op.Only([stateValue]), isNotNull);
					expect(Op.Only([stateValue], validValue: true, altState: stateTuple), isNotNull);
				}
			);
		}
	);
}

