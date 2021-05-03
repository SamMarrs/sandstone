part of '../StateManager.dart';

/// Similar in function to [BooleanStateValue], but stores metadata needed by [StateManager] and other classes.
class ManagedValue {
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) _validateTrue;
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) _validateFalse;
	bool _value;
	/// Returns the current value of this [ManagedValue].
	bool get value => _value;
	final int _position;
	final StateManager _manager;
	final BooleanStateValue _stateValue;

	ManagedValue._({
		required BooleanStateValue managedValue,
		required int position,
		required StateManager manager
	}): _position = position,
		_manager = manager,
		_value = managedValue.value,
		_validateFalse = managedValue.validateFalse,
		_validateTrue = managedValue.validateTrue,
		_stateValue = managedValue;

	bool _isValid(StateTuple previous, StateTuple nextState) {
		if (nextState._values[_position]) {
			return _validateTrue(previous, nextState, _manager);
		} else {
			return _validateFalse(previous, nextState, _manager);
		}
	}

	bool _canChange(StateTuple previous, StateTuple nextState,)  {
		return previous._values[_position] ? _validateFalse(previous, nextState, _manager) : _validateTrue(previous, nextState, _manager);
	}

	/// Returns the value correlated to this [ManagedValue] within the provided [StateTuple].
	///
	/// Returns `null` if [stateTuple] was created by a different [StateManager] than this [ManagedValue].
	bool? getFromState(StateTuple stateTuple) {
		assert(stateTuple._manager == _manager, 'StateTuple must be from the same state manager.');
		if (stateTuple._manager != _manager) return null;
		return stateTuple._values[_position];
	}

}
