import 'dart:collection';

import 'package:sandstone/src/StateManager.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';

abstract class Operator {
	const Operator();
}

/// Used to declare a [StateValue] within a [Validator].
///
/// Use `altState` to override the [StateTuple] provided to the [Validator].
class Value extends Operator {
	final StateValue value;
	final StateTuple? altState;

	const Value(this.value, {this.altState});
}

/// ANDs all child values together.
///
/// `stateValue1 && stateValue2 && stateValue3`
///
/// is equivalent to
///
/// ```dart
/// import 'package:...operators.dart' as Op;
///
/// Op.And([
/// 	Op.Value(stateValue1),
/// 	Op.Value(stateValue2),
/// 	Op.Value(stateValue3),
/// ]);
/// ```
class And extends Operator {
	final UnmodifiableListView<Operator> values;

	And(
		List<Operator> values
	): this.values = UnmodifiableListView(values);

}

/// ORs all child values together.
///
/// `stateValue1 || stateValue2 || stateValue3`
///
/// is equivalent to
///
/// ```dart
/// import 'package:...operators.dart' as Op;
///
/// Op.Or([
/// 	Op.Value(stateValue1),
/// 	Op.Value(stateValue2),
/// 	Op.Value(stateValue3),
/// ]);
/// ```
class Or extends Operator {
	final UnmodifiableListView<Operator> values;

	Or(
		List<Operator> values
	): this.values = UnmodifiableListView(values);

}

/// Inverts the value of the child operator
///
/// `!stateValue`
///
/// is equivalent to
///
/// ```dart
/// import 'package:...operators.dart' as Op;
///
/// Op.Not( Op.Value(stateValue) );
/// ```
class Not extends Operator {
	final Operator value;

	Not(this.value);
}

/// Every child operator must resolve to the provided [validValue].
///
/// If [values] is set to `null`, then every [StateValue] within the provided [StateTuple] must resolve
/// to the provided [validValue].
class Every extends Operator {
	final UnmodifiableListView<Operator>? values;
	final bool validValue;

	Every(
		List<Operator>? values,
		{
			this.validValue = false
		}
	): this.values = values == null ? null : UnmodifiableListView(values);
}

/// None of the child operators should resolve to the provided [invalidValue].
///
/// If [values] is set to `null`, then no [StateValue] within the provided [StateTuple]
/// should resolve to the provided [invalidValue].
class None extends Operator {
	final UnmodifiableListView<Operator>? values;
	final bool invalidValue;

	None(
		List<Operator>? values,
		{
			this.invalidValue = false
		}
	): this.values = values == null ? null : UnmodifiableListView(values);
}

/// At lease one of the child operators should resolve to the provided [validValue].
///
/// If [values] is set to null, then at least one of the [StateValue]s within the provided [StateTuple]
/// should evaluate to the provided [validValue].
class Any extends Operator {
	final UnmodifiableListView<Operator>? values;
	final bool validValue;

	Any(
		List<Operator>? values,
		{
			this.validValue = false
		}
	): this.values = values == null ? null : UnmodifiableListView(values);
}

/// Of all the [StateValue]s within the provided [StateTuple], only the provided [StateValue]s
/// should resolve to [validValue].
///
/// If [altState] is not `null`, then it will be used instead of the [StateTuple] provided to [Validator].
class Only extends Operator {
	final UnmodifiableListView<StateValue> values;
	final bool validValue;
	final StateTuple? altState;

	Only(
		List<StateValue> values,
		{
			this.validValue = false,
			this.altState
		}
	): this.values = UnmodifiableListView(values);
}