part of '../StateManager.dart';

/// Similar in function to [BooleanStateValue], but stores metadata needed by [StateManager] and other classes.
class ManagedValue {
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) _canChangeToTrue;
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) _canChangeToFalse;
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
		_canChangeToFalse = managedValue.canChangeToFalse,
		_canChangeToTrue = managedValue.canChangeToTrue,
		_stateValue = managedValue;

	bool _canChange(StateTuple previous, StateTuple nextState,)  {
		return previous._values[_position] ? _canChangeToFalse(previous, nextState, _manager) : _canChangeToTrue(previous, nextState, _manager);
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
