
import 'package:sandstone/src/StateManager.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/unmanaged_classes/fsm_mirroring.dart';

class InternalManagedValue {
	final ManagedValue mv;

	InternalManagedValue(this.mv);

	static ManagedValue create({
		required StateValue managedValue,
		required int position,
		required StateManager manager
	}) => ManagedValue._(managedValue: managedValue, position: position, manager: manager);

	set value(bool value) => mv._value = value;

	int get position => mv._position;

	StateValue get stateValue => mv._stateValue;

	bool isValid(StateTuple previous, StateTuple nextState) {
		InternalStateTuple ns = InternalStateTuple(nextState);
		if (ns.values[mv._position]) {
			return mv._validateTrue(previous, nextState, mv._manager);
		} else {
			return mv._validateFalse(previous, nextState, mv._manager);
		}
	}

	bool canChange(StateTuple previous, StateTuple nextState,)  {
		InternalStateTuple ps = InternalStateTuple(previous);
		return ps.values[mv._position] ? mv._validateFalse(previous, nextState, mv._manager) : mv._validateTrue(previous, nextState, mv._manager);
	}
}

/// Similar in function to [BooleanStateValue], but stores metadata needed by [StateManager] and other classes.
class ManagedValue {
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) _validateTrue;
	final bool Function(StateTuple previous, StateTuple nextState, StateManager manager) _validateFalse;
	bool _value;
	/// Returns the current value of this [ManagedValue].
	bool get value => _value;
	final int _position;
	final StateManager _manager;
	final StateValue _stateValue;

	bool get isMirrored => _stateValue is MirroredStateValue;

	ManagedValue._({
		required StateValue managedValue,
		required int position,
		required StateManager manager
	}): _position = position,
		_manager = manager,
		_value = managedValue.value,
		_validateFalse = managedValue.validateFalse,
		_validateTrue = managedValue.validateTrue,
		_stateValue = managedValue;



	/// Returns the value correlated to this [ManagedValue] within the provided [StateTuple].
	///
	/// Returns `null` if [stateTuple] was created by a different [StateManager] than this [ManagedValue].
	bool? getFromState(StateTuple stateTuple) {
		InternalStateTuple st = InternalStateTuple(stateTuple);
		assert(st.manager == _manager, 'StateTuple must be from the same state manager.');
		if (st.manager != _manager) return null;
		return st.values[_position];
	}

}
