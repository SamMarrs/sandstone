import 'dart:collection';

import 'package:mockito/mockito.dart';
import 'package:sandstone/src/managed_classes/ManagedValue.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';

extension ValueReferences on InternalStateTuple {
	UnmodifiableListView<FakeManagedValue> get valueReferences => (stateTuple as FakeStateTuple)._valueReferences;
}

class FakeManagedValue extends Fake implements ManagedValue {
	final FakeStateValue _stateValue;

	FakeManagedValue(
		FakeStateValue stateValue
	): _stateValue = stateValue;
}

class FakeStateValue extends Fake implements StateValue {
	final bool? _value;
	FakeStateValue(
		bool? value
	): _value = value;
	bool? getValue() => _value;
}

class FakeStateTuple extends Fake implements StateTuple {
	late final UnmodifiableListView<bool> _values;
	@override
	late final UnmodifiableListView<FakeManagedValue> _valueReferences;

	FakeStateTuple(
		List<bool> values,
		List<FakeManagedValue> valueReferences
	): _values = UnmodifiableListView(values),
		_valueReferences = UnmodifiableListView(valueReferences);

	@override
	bool? getValue(StateValue sv) {
		bool unknown = !_valueReferences.map((e) => e._stateValue).contains(sv);
		return unknown ? null : (sv as FakeStateValue).getValue();
	}

	@override
	UnmodifiableListView<bool> getValues() => _values;
}