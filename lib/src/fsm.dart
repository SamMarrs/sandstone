import 'dart:collection';
import 'dart:math' as Math;

import './unmanaged_classes/StateTransition.dart';

import './unmanned_classes/utils.dart';
import 'package:tuple/tuple.dart';

import 'FSMTests.dart';
import 'unmanaged_classes/BooleanStateValue.dart';
import 'unmanaged_classes/StateAction.dart';

class StateManager {
	final void Function() _notifyListeners;

	late final _StateGraph _stateGraph;

	late final List<_ManagedStateAction> _managedStateActions;

	late final HashSet<StateTransition> _stateTransitions;
	// late HashSet<Map<BooleanStateValue, bool>> _stateTransitions;

	List<ManagedValue> get managedValues => _stateGraph._managedValues;

	Map<BooleanStateValue, int> _booleanStateValueToIndex = {};

	StateManager._({
		required void Function() notifyListener,
	}): _notifyListeners = notifyListener {
		_doActions();
	}

	// TODO: Possibly make async so the stateTransitions can be async
	// Factory constructors can no longer return null values with null safety.
	static StateManager? create({
		required void Function() notifyListeners,
		required List<BooleanStateValue> managedValues,
		required List<StateTransition> stateTransitions,
		List<StateAction>? stateActions,
	}) {
		StateManager bsm = StateManager._(notifyListener: notifyListeners);

		_StateGraph? stateGraph = _StateGraph.create(
			manager: bsm,
			stateValues: managedValues,
			valueToIndex: bsm._booleanStateValueToIndex
		);
		if (stateGraph == null) return null;
		bsm._stateGraph = stateGraph;

		// Create state transitions
		HashSet<StateTransition> _stateTransitions = HashSet();
		bool stateTransitionError = false;
		stateTransitions.forEach(
			(transition) {
				if (
					FSMTests.noDuplicateTransitions(_stateTransitions, transition)
					&& FSMTests.checkIfAllStateValuesRegistered(transition, bsm._booleanStateValueToIndex)
				) {
					FSMTests.stateTransitionValuesNotEmpty(transition);
					// If the transition can't succeed, it will be ignored.
					// So, we don't need to prevent the initialization fo the manager if this check fails.
					// But, we still need to add it to prevent future errors.
					FSMTests.checkIfTransitionMaySucceed<ManagedValue>(
						transition.name,
						bsm._transitionConversion(transition.stateChanges),
						bsm._stateGraph._validStates,
						(key) => key._position
					);
					_stateTransitions.add(transition);
				} else {
					stateTransitionError = true;
				}
			}
		);
		if (stateTransitionError) return null;
		bsm._stateTransitions = _stateTransitions;

		// Create state actions.
		List<_ManagedStateAction> managedStateActions = [];
		bool stateActionError = false;
		if (stateActions != null) {
			stateActions.forEach(
				(action) {
					if (
						FSMTests.checkIfAllActionStateValuesRegistered(action, bsm._booleanStateValueToIndex)
					) {
						_ManagedStateAction? sa = _ManagedStateAction.create(
							positions: bsm._booleanStateValueToIndex,
							stateAction: action
						);
						if (sa != null) {
							FSMTests.checkIfActionMayRun(
								bsm._stateGraph._validStates,
								(state) => sa.shouldRun(state),
								sa.name
							);
							managedStateActions.add(sa);
						}
					} else {
						stateActionError = true;
					}
				}
			);
		}
		if (stateActionError) return null;
		bsm._managedStateActions = managedStateActions;
		return bsm;
	}

	Map<ManagedValue, bool> _transitionConversion(Map<BooleanStateValue, bool> transition) {
		Map<ManagedValue, bool> map = {};
		transition.forEach(
			(key, value) {
				map[managedValues[_booleanStateValueToIndex[key]!]] = value;
			}
		);
		return map;
	}

	bool? getFromState(StateTuple stateTuple, BooleanStateValue value) {
		assert(stateTuple._manager == this, 'StateTuple must be from the same state manager.');
		assert(_booleanStateValueToIndex.containsKey(value), 'BooleanStateValue must have been registered with this state manager.');
		if (stateTuple._manager != this || !_booleanStateValueToIndex.containsKey(value)) return null;
		// Performed null check in previous if statement.
		return stateTuple._values[_booleanStateValueToIndex[value]!];
	}

	void _notify() {
		_notifyListeners();
		_doActions();
	}

	void _doActions() {
		Future.delayed(
			Duration.zero,
			() {
				List<Map<BooleanStateValue, bool>> transitions = [];
				_managedStateActions.forEach(
					(action) {
						if (action.shouldRun(_stateGraph._currentState)) {
							action.action();
						}
					}
				);
			}
		);
	}

	DoubleLinkedQueue<StateTransition> _updateQueue = DoubleLinkedQueue();
	void queueUpdate(StateTransition transition) {
		assert(_stateTransitions.contains(transition), 'Unknown transition.');
		// TODO: when canChangeFromTrue/canChangeFromFalse implemented, check if transition is possible. Ignore if not.

		if (_updateQueue.last == transition) return;
	}

	// FIXME: This doesn't work as intended.
	// Possibly do this:
	// 1. When canChangeFromTrue/canChangeFromFalse implemented, check if transition is possible. Else ignore.
	// 2. If many of the same transitions occur sequentially, before the execution, ignore the duplicates.
	// 3. If a different transition is queued prior to execution of the former, queue the latter into a later event.
	// 4. If the first and third queued transitions are the same, with the second being different prior to execution, create three separate events.
	// 5. Once a transition event is executed, check if it is still valid, otherwise ignore.
	HashSet<Map<BooleanStateValue, bool>> _queuedUpdates = HashSet();
	void queueStateUpdate(Map<BooleanStateValue, bool> transition) {
		assert(_stateTransitions.contains(transition), 'Unknown transition.');
		assert(_queuedUpdates.isEmpty || _queuedUpdates.contains(transition), 'Multiple different transitions queued at the same time.');
		if (
			_stateTransitions.contains(transition)
			&& (
				_queuedUpdates.isEmpty
				|| _queuedUpdates.contains(transition)
			)
		) {
			// If the queue doesn't start empty, that means multiple transitions have been queued before the transitions were able to run.
			// This would happen with multiple sequential calls to queueStateUpdate.
			// Only Future.delayed when the queue is empty acts as a debouncer to repeated, sequential calls to queueStateUpdate.
			bool wasEmpty = _queuedUpdates.isEmpty;
			_queuedUpdates.add(transition);
			if (wasEmpty) {
				Future.delayed(
					Duration.zero,
					() => _processQueuedUpdates()
				);
			}
		}
	}

	void _processQueuedUpdates() {
		if (_queuedUpdates.isEmpty) return;
		List<Map<ManagedValue, bool>> queued = _queuedUpdates.map(
			(update) => _transitionConversion(update)
		).toList();
		_queuedUpdates.clear();

		Map<ManagedValue, bool> merged = {};
		queued.forEach(
			(newUpdate) {
				// As of writing, this should never happen due to assertions and checks in queueStateUpdate.
				assert(!merged.entries.any((entry) => entry.value != newUpdate[entry.key]), 'Encountered conflicting transition requests.');
				merged.addAll(newUpdate);
			}
		);
		_applyStateUpdate(merged);
	}

	void _applyStateUpdate(Map<ManagedValue, bool> update) {
		List<Tuple2<StateTuple, int>> possibleStates = [];
		int mask = Utils.maskFromMap<ManagedValue>(update, (key) => key._position);
		int subHash = Utils.hashFromMap<ManagedValue>(update, (key) => key._position);

		// If the currentState is still valid, the update is a duplicate, and should be ignored.
		if ((_stateGraph._currentState.hashCode & mask) == subHash) {
			return;
		}

		_stateGraph.getCurrentAdjacent().forEach(
			(stateDiff) {
				StateTuple state = stateDiff.item1;
				if ((state.hashCode & mask) == subHash ) {
					possibleStates.add(stateDiff);
				}
			}
		);

		assert(possibleStates.isNotEmpty, 'Invalid state transition.');
		if (possibleStates.isEmpty) return;
		if (possibleStates.length == 1) {
			_stateGraph.changeState(possibleStates.first.item1);
			_notify();
		} else {
			int minDiff = possibleStates[0].item2;
			List<StateTuple> minChangeStates = [
				possibleStates[0].item1
			];
			for (int i = 1; i < possibleStates.length; i++) {
				int diff = possibleStates[i].item2;
				if (diff == minDiff) minChangeStates.add(possibleStates[i].item1);
				if (diff > minDiff) break;
			}
			assert(
				minChangeStates.length == 1,
				'Multiple valid states with the same minimum difference to the current state. Try narrowing the conditions in the state transition function.'
			);

			_stateGraph.changeState(minChangeStates.first);
			_notify();
		}
	}

}

class _StateGraph {
	final List<ManagedValue> _managedValues;

	final HashMap<StateTuple, List<Tuple2<StateTuple, int>>> _validStates;

	StateTuple _currentState;

	_StateGraph._({
		required List<ManagedValue> managedValues,
		required HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates,
		required StateTuple currentState,
	}): _managedValues = managedValues,
		_validStates = validStates,
		_currentState = currentState;

	static _StateGraph? create({
		required StateManager manager,
		required List<BooleanStateValue> stateValues,
		required Map<BooleanStateValue, int> valueToIndex
	}) {
		List<ManagedValue> managedValues = [];
		// Setup managed values with correct position information.
		for (int i = 0; i < stateValues.length; i++) {
			valueToIndex[stateValues[i]] = i;
			managedValues.add(
				ManagedValue._(
					managedValue: stateValues[i],
					position: i,
					manager: manager
				)
			);
		}

		HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates = _StateGraph._findAllGoodState(
			managedValues: managedValues,
			manager: manager
		);
		StateTuple currentState = StateTuple._fromList(managedValues, manager);

		_StateGraph._buildAdjacencyList(
			managedValues: managedValues,
			validStates: validStates
		);

		if (!FSMTests.isValidInitialState(currentState, validStates)) return null;
		if (!FSMTests.atLeastOneValidState(validStates)) return null;
		return _StateGraph._(
			managedValues: managedValues,
			validStates: validStates,
			currentState: currentState,
		);
	}

	// TODO: Convert to traversing the tree by using canChangeFromTrue/canChangeFromFalse logic
	static HashMap<StateTuple, List<Tuple2<StateTuple, int>>> _findAllGoodState({
		required List<ManagedValue> managedValues,
		required StateManager manager
	}) {
		HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates = HashMap();
		int maxInt = (Math.pow(2, managedValues.length) as int) - 1;
		for (int i = 0; i <= maxInt; i++) {
			StateTuple? st = StateTuple._fromHash(managedValues, manager, i);
			if (st != null) {
				if ( managedValues.every((stateVal) => stateVal._isAllowed(st))) {
					validStates.putIfAbsent(st, () => []);
				}
			}
		}
		return validStates;
	}

	static void _buildAdjacencyList({
		required List<ManagedValue> managedValues,
		required HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates
	}) {
		int findDifference(StateTuple a, StateTuple b) {
			int diff = 0;
			for (int i = 0; i < managedValues.length; i++) {
				if (a._values[i] != b._values[i]) {
					diff++;
				}
			}
			return diff;
		}

		HashMap<StateTuple, HashSet<StateTuple>> checked = HashMap();
		validStates.entries.forEach(
			(entry) {
				StateTuple primaryState = entry.key;
				List<Tuple2<StateTuple, int>> primaryStateList = entry.value;
				validStates.entries.forEach(
					(_entry) {
						StateTuple adjacentState = _entry.key;
						List<Tuple2<StateTuple, int>> adjacentStateList = _entry.value;
						// Check if the has already been done.
						if (
							adjacentState == primaryState
							|| (
								checked.containsKey(primaryState)
								&& checked[primaryState]!.contains(adjacentState)
							)
						) {
							return;
						}
						// Make note that this state combo has been done, so it doesn't occur again
						if (!checked.containsKey(primaryState)) {
							checked[primaryState] = HashSet();
						}
						checked[primaryState]!.add(adjacentState);
						if (!checked.containsKey(adjacentState)) {
							checked[adjacentState] = HashSet();
						}
						checked[adjacentState]!.add(primaryState);

						int diff = findDifference(primaryState, adjacentState);
						primaryStateList.add(Tuple2(adjacentState, diff));
						adjacentStateList.add(Tuple2(primaryState, diff));
					}
				);
			}
		);
		validStates.entries.forEach(
			(entry) {
				entry.value.sort(
					(a, b) => a.item2 - b.item2
				);
			}
		);
	}


	List<Tuple2<StateTuple, int>> getCurrentAdjacent() {

		return _validStates[_currentState]!;
	}

	void changeState(StateTuple newState) {
		// print(newState.hashCode.toRadixString(2) + ' ' + newState.hashCode.toString());
		print(newState.toString());
		_currentState = newState;
		newState._valueReferences.forEach(
			(managedValue) {
				managedValue._value = newState.values[managedValue._position];
			}
		);
	}

}

class _ManagedStateAction {
	final String name;

	/// A map of _ManagedValue indices to a value for that _ManagedValue.
	///
	/// Used to check if this action should run for a given state.
	final Map<int, bool> registeredStateValues;

	final void Function() action;


	_ManagedStateAction({
		required this.registeredStateValues,
		required this.action,
		required this.name,
	});

	static _ManagedStateAction? create({
		required Map<BooleanStateValue, int> positions,
		required StateAction stateAction
	}) {
		assert(positions.isNotEmpty); // controlled by state manager
		bool isNotEmpty = FSMTests.stateActionValuesNotEmpty(stateAction);
		if (positions.isEmpty || !isNotEmpty) return null;
		List<MapEntry<BooleanStateValue, bool>> entries = stateAction.registeredStateValues.entries.toList();
		Map<int, bool> rStateValues = {};
		for (int i = 0; i < entries.length; i++) {
			assert(positions.containsKey(entries[i].key));
			if (!positions.containsKey(entries[i].key)) return null;
			rStateValues[positions[entries[i].key]!] = entries[i].value;
		}
		return _ManagedStateAction(
			registeredStateValues: rStateValues,
			action: stateAction.action,
			name: stateAction.name,
		);
	}

	int? _mask;
	int get mask {
		if (_mask != null) return _mask!;
		_mask = Utils.maskFromMap<int>(registeredStateValues, (key) => key);
		return mask;
	}

	int? _hash;
	int get hash {
		if (_hash != null) return _hash!;
		_hash = Utils.hashFromMap<int>(registeredStateValues, (key) => key);
		return hash;
	}

	bool shouldRun(StateTuple st) {
		int masked = mask & st.hashCode;
		return masked == hash;
	}
}

class ManagedValue {
	final bool Function(StateTuple currentState, StateManager manager) _canBeTrue;
	final bool Function(StateTuple currentState, StateManager manager) _canBeFalse;
	bool _value;
	bool get value => _value;
	// only accessible BooleanStateManager
	final int _position;
	final StateManager _manager;

	ManagedValue._({
		required BooleanStateValue managedValue,
		required int position,
		required StateManager manager
	}): _position = position,
		_manager = manager,
		_value = managedValue.value,
		_canBeFalse = managedValue.canBeFalse,
		_canBeTrue = managedValue.canBeTrue;

	bool _isAllowed(StateTuple state)  {
		return state._values[_position] ? _canBeTrue(state, _manager) : _canBeFalse(state, _manager);
	}

	bool? getFromState(StateTuple stateTuple) {
		assert(stateTuple._manager == _manager, 'StateTuple must be from the same state manager.');
		if (stateTuple._manager != _manager) return null;
		return stateTuple._values[_position];
	}

}

/// hashCode of Tuple must follow some rules.
///
/// IF TupleA.hashCode == TupleB.hashCode THEN TupleA == TupleB
///
/// IF TupleA == TupleB THEN TupleA.hashCode == TupleB.hashCode
///
/// These rules do not have to be followed when Two different classes that extend Tuple are compared to each other.
class StateTuple {
	final List<bool> _values = [];
	final List<ManagedValue> _valueReferences;
	final StateManager _manager;

	StateTuple._fromList(
		this._valueReferences,
		this._manager,
		[Map<int, bool>? updates]
	) {
		_valueReferences.forEach(
			(ref) {
				_values.add(
					updates != null && updates.containsKey(ref._position) ?
						updates[ref._position]!
						: ref.value
				);
			}
		);
	}

	static StateTuple? _fromHash(
		List<ManagedValue> valueReferences,
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
		StateTuple st = StateTuple._fromList(valueReferences, manager, updates);
		st._hashCode = stateHash;

		return st;
	}

	/// width of tuple;
	int get width => _values.length;

	UnmodifiableListView<bool> get values => UnmodifiableListView(_values);

	int? _hashCode;
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
	bool operator ==(Object other) => other is StateTuple && other.width == width && other.hashCode == hashCode;


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
