part of '../StateManager.dart';

/// Represents a state within a finite state machine.
class StateTuple {
	// TODO: It might be good to change this to a LinkedHashMap for some cleaner code.
	late final UnmodifiableListView<bool> _values;
	// TODO: It might be good to change this to a LinkedHashMap for some cleaner code.
	late final UnmodifiableListView<ManagedValue> _valueReferences;
	late final StateManager _manager;

	StateTuple._fromState(
		StateTuple oldState,
		[Map<int, bool>? updates]
	) {
		_valueReferences = UnmodifiableListView(oldState._valueReferences.toList(growable: false));
		_manager = oldState._manager;
		List<bool> values = [];
		for (int i = 0; i < oldState._values.length; i++) {
			if (updates != null && updates.containsKey(i)) {
				values.add(updates[i]!);
			} else {
				values.add(oldState._values[i]);
			}
		}
		_values = UnmodifiableListView(values);
	}

	StateTuple._fromMap(
		LinkedHashMap<StateValue, ManagedValue> valueReferences,
		this._manager,
		[Map<int, bool>? updates]
	) {
		_valueReferences = UnmodifiableListView(valueReferences.values.toList(growable: false));

		_values = UnmodifiableListView(
			valueReferences.values.toList().map(
				(managedValue) {
					return updates != null && updates.containsKey(managedValue._position) ?
						updates[managedValue._position]!
						: managedValue.value;
				}
			).toList(growable: false)
		);
	}

	static StateTuple? _fromHash(
		LinkedHashMap<StateValue, ManagedValue> valueReferences,
		StateManager manager,
		int stateHash
	) {
		assert(stateHash >= 0);
		if (stateHash < 0) return null;
		int maxInt = (Math.pow(2, valueReferences.length) as int) - 1;
		assert(stateHash <= maxInt);
		if (stateHash > maxInt) return null;

		Map<int, bool> updates = {};
		for (int i = 0; i < valueReferences.length; i++) {
			int value = stateHash & (1 << i);
			updates[i] = value > 0;
		}
		StateTuple st = StateTuple._fromMap(valueReferences, manager, updates);
		st._hashCode = stateHash;

		return st;
	}

	static Map<StateValue, bool> _findDifference(StateTuple stateA, StateTuple stateB) {
		assert(stateA._manager == stateB._manager);
		if (stateA._manager != stateB._manager) return {};

		Map<StateValue, bool> diff = {};
		stateA._valueReferences.forEach(
			(managedValue) {
				if (stateA._values[managedValue._position] != stateB._values[managedValue._position]) {
					diff[managedValue._stateValue] = stateB._values[managedValue._position];
				}
			}
		);
		return diff;
	}

	int? _hashCode;
	/// hashCode of [StateTuple] must follow a few rules.
	///
	/// IF TupleA.hashCode == TupleB.hashCode THEN TupleA == TupleB
	///
	/// IF TupleA == TupleB THEN TupleA.hashCode == TupleB.hashCode
	///
	/// These rules do not have to be followed when Two different classes that extend Tuple are compared to each other.
	///
	/// (true) => 1, (false) => 0
	///
	/// (true, false) => 01
	///
	/// (false, true, true, false, true) => 10110
	/// Smallest index is least significant bit.
	@override
	int get hashCode {
		if (_hashCode == null) {
			_hashCode = 0;
			for (int index = 0; index < _values.length; index++) {
				if (_values[index]) {
					_hashCode = _hashCode! | (1 << index);
				}
			}
		}
		return _hashCode!;
	}

	@override
	bool operator ==(Object other) => other is StateTuple && other._values.length == _values.length && other.hashCode == hashCode;

	@override
	String toString() {
		String ret = '';
		_valueReferences.forEach(
			(ref) {
				ret += ref._position.toString() + ' ' + _values[ref._position].toString() + ', ';
			}
		);
		return ret;
	}
}
