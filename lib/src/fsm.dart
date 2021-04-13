import 'dart:async';
import 'dart:collection';
import 'dart:developer' as Developer;

import 'package:flutter/cupertino.dart';

import './unmanaged_classes/StateTransition.dart';

import 'utils.dart';

import 'FSMTests.dart';
import 'unmanaged_classes/BooleanStateValue.dart';
import 'unmanaged_classes/StateAction.dart';

// TODO: Add a method to start a transition that clears and jumps the queue.
// Kind of like a hard reset option.
// Clearing the queue should be optional.


// TODO: Build a version of StateManager that allows for side effects in state transitions.
// This version will use canBeTrue/canBeFalse (like before the change to canChangeFromX).
// canBeX will be a function of the current state and the previous state.
// Instead of traversing the graph by transition changes, every possible combination of previous and next state will be considered.
// The resulting adjacency list will be much larger and back to the state => ordered list of next state setup, but will allow side effects.
// Since the current and previous states are considered, we are still able to purge the transition buffer if the queued transitions don't point to
// a state adjacent to the new state.

class StateManager {
	final void Function() _notifyListeners;

	late final _StateGraph _stateGraph;

	late final List<_ManagedStateAction> _managedStateActions;

	late final HashSet<StateTransition> _stateTransitions;

	final LinkedHashMap<BooleanStateValue, ManagedValue> _managedValues = LinkedHashMap();
	ManagedValue? getManagedValue(BooleanStateValue booleanStateValue) => _managedValues[booleanStateValue];

	final bool _showDebugLogs;

	StateManager._({
		required void Function() notifyListener,
		required bool showDebugLogs,
	}): _notifyListeners = notifyListener,
		_showDebugLogs = showDebugLogs {
		// _doActions();
	}

	// Factory constructors can no longer return null values with null safety.
	static StateManager? create({
		required void Function() notifyListeners,
		required List<BooleanStateValue> managedValues,
		required List<StateTransition> stateTransitions,
		List<StateAction>? stateActions,
		bool showDebugLogs = false
	}) {
		StateManager bsm = StateManager._(notifyListener: notifyListeners, showDebugLogs: showDebugLogs);

		// Create state transitions
		HashSet<StateTransition> _stateTransitions = HashSet();
		bool stateTransitionError = false;
		stateTransitions.forEach(
			(transition) {
				if (
					FSMTests.noDuplicateTransitions(_stateTransitions, transition)
					&& FSMTests.checkIfAllStateValuesRegistered(transition, managedValues)
				) {
					FSMTests.stateTransitionValuesNotEmpty(transition);
					_stateTransitions.add(transition);
				} else {
					stateTransitionError = true;
				}
			}
		);
		if (stateTransitionError) return null;
		bsm._stateTransitions = _stateTransitions;

		for (int i = 0; i < managedValues.length; i++) {
			bsm._managedValues[managedValues[i]] = ManagedValue._(
				managedValue: managedValues[i],
				position: i,
				manager: bsm
			);
		}
		_StateGraph? stateGraph = _StateGraph.create(
			manager: bsm,
			stateTransitions: _stateTransitions,
			unmanagedToManagedValues: bsm._managedValues
		);
		if (stateGraph == null) return null;
		bsm._stateGraph = stateGraph;

		// Create state actions.
		List<_ManagedStateAction> managedStateActions = [];
		bool stateActionError = false;
		if (stateActions != null) {
			stateActions.forEach(
				(action) {
					if (
						FSMTests.checkIfAllActionStateValuesRegistered(action, bsm._stateGraph._managedValues)
					) {
						_ManagedStateAction? sa = _ManagedStateAction.create(
							managedValues: bsm._stateGraph._managedValues,
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
		bsm._doActions();
		return bsm;
	}

	bool? getFromState(StateTuple stateTuple, BooleanStateValue value) {
		assert(stateTuple._manager == this, 'StateTuple must be from the same state manager.');
		assert(_managedValues.containsKey(value), 'BooleanStateValue must have been registered with this state manager.');
		if (stateTuple._manager != this || !_managedValues.containsKey(value)) return null;
		// Performed null check in previous if statement.
		return stateTuple._values[_managedValues[value]!._position];
	}

	void _doActions() {
		_managedStateActions.forEach(
			(action) {
				if (action.shouldRun(_stateGraph._currentState)) {
					action.action(this, _stateGraph._currentState);
				}
			}
		);
	}

	DoubleLinkedQueue<StateTransition> _transitionBuffer = DoubleLinkedQueue();
	bool _performingTransition = false;
	void queueTransition(StateTransition transition, [bool? ignoreDuplicate]) {
		_queueTransition(transition, ignoreDuplicate);
	}

	void _queueTransition(StateTransition? transition, [bool? ignoreDuplicates]) {
		if (transition == null) {
			if (_transitionBuffer.isNotEmpty && !_performingTransition) {
				Future(_processTransition);
			}
		} else {
			assert(_stateTransitions.contains(transition), 'Unknown transition.');
			// Check if transition is possible. Ignore if not.
			if (!_stateGraph._validStates[_stateGraph._currentState]!.containsKey(transition)) {
				if (_showDebugLogs) {
					Developer.log('Ignoring transition "${transition.name}" because it does not transition to a valid state.');
				}
				return;
			}
			// TODO: This assertion might not work. It is supposed to fix a debounce of multiple sequential transitions.
			// assert(_transitionBuffer.last != transition, 'The same transition has been queued sequentially.');
			// Unfortunately, that breaks for things like counting rapid button presses,
			// or if the processing of the buffer is lagging the input.
			// After the buffer purge at the end of a state change, that might improperly trigger this check.
			// [A, B, C] => purge => [A, B] => queue B => [A, B, B]
			if (
				(
					( ignoreDuplicates != null && ignoreDuplicates )
					|| (ignoreDuplicates == null && transition.ignoreDuplicates)
				)
				&& _transitionBuffer.isNotEmpty && _transitionBuffer.last == transition
			) {
				if (_showDebugLogs) {
					Developer.log('Ignoring transition "${transition.name}" because ignoreDuplicate is set.');
				}
				return;
			}
			_transitionBuffer.addLast(transition);
			if (!_performingTransition) {
				Future(_processTransition);
			}
		}
	}
	void _processTransition() {
		// If a separate isolate queues a transition, this check could change between _queueTransition and here.
		// Need to check again.
		if (_performingTransition || _transitionBuffer.isEmpty) return;
		_performingTransition = true;
		StateTransition transition = _transitionBuffer.removeFirst();
		if (_showDebugLogs) {
			Developer.log('Processing transition "${transition.name}".');
		}

		StateTuple currentState = _stateGraph._currentState;
		// If these null checks fails, it is a mistake in the implementation.
		// Checks during initialization of the manager should guarantee these.
		StateTuple? nextState = _stateGraph._validStates[currentState]![transition];
		// Check if transition is possible given the current state. Ignore if not.
		if (nextState == null) {
			_performingTransition = false;
			_queueTransition(null);
			return;
		}

		// TODO: What's the order of operations?
		// 1. update current state
		// 2. transition action
		// 3. mark need rebuild
		// 4. widgets rebuild
		// 5. run state actions
		// -- I don't think I can guarantee this order
		// 6. Queue transition that might result from transition action
		// 7. Queue transition that might result from state action
		// 8. Queue transitions that might result from rebuild

		if (currentState != nextState) {
			_stateGraph.changeState(nextState);
		}
		// Purge _transitionBuffer of invalid transitions given this new state.
		_transitionBuffer.removeWhere(
			(queuedTransition) {
				// If these null checks fails, it is a mistake in the implantation.
				// Checks during initialization of the manager should guarantee these.
				return !_stateGraph._validStates[nextState]!.containsKey(queuedTransition);
			}
		);

		if (transition.action != null) {
			transition.action!(this, currentState, nextState);
		}
		if (currentState != nextState) {
			_notifyListeners();
		}
		assert(WidgetsBinding.instance != null);
		WidgetsBinding.instance!.addPostFrameCallback(
			(timeStamp) {
				if (currentState != nextState) {
					_doActions();
				}
				_performingTransition = false;
				_queueTransition(null);
			}
		);
	}
}

class _StateGraph {
	final LinkedHashMap<BooleanStateValue, ManagedValue> _managedValues;

	final HashMap<StateTuple, HashMap<StateTransition, StateTuple>> _validStates;

	StateTuple _currentState;

	final StateManager _manager;

	_StateGraph._({
		required LinkedHashMap<BooleanStateValue, ManagedValue> managedValues,
		required HashMap<StateTuple, HashMap<StateTransition, StateTuple>> validStates,
		required StateTuple currentState,
		required StateManager manager
	}): _managedValues = managedValues,
		_validStates = validStates,
		_currentState = currentState,
		_manager = manager;

	static _StateGraph? create({
		required StateManager manager,
		required HashSet<StateTransition> stateTransitions,
		required LinkedHashMap<BooleanStateValue, ManagedValue> unmanagedToManagedValues
	}) {

		HashMap<StateTuple, HashMap<StateTransition, StateTuple>> validStates = _StateGraph._buildAdjacencyList(
			managedValues: unmanagedToManagedValues,
			manager: manager,
			stateTransitions: stateTransitions
		);
		StateTuple currentState = StateTuple._fromMap(unmanagedToManagedValues, manager);
		return _StateGraph._(
			managedValues: unmanagedToManagedValues,
			validStates: validStates,
			currentState: currentState,
			manager: manager
		);
	}

	static HashMap<StateTuple, HashMap<StateTransition, StateTuple>> _buildAdjacencyList({
		required LinkedHashMap<BooleanStateValue, ManagedValue> managedValues,
		required StateManager manager,
		required HashSet<StateTransition> stateTransitions,
	}) {
		StateTuple initialState = StateTuple._fromMap(managedValues, manager);
		HashMap<StateTuple, HashMap<StateTransition, StateTuple>> adjacencyList = HashMap();
		HashSet<StateTransition> usedTransitions = HashSet();

		void findNextStates(StateTuple state) {
			if (adjacencyList.containsKey(state)) {
				// This state has already been visited.
				return;
			}
			adjacencyList[state] = HashMap();
			stateTransitions.forEach(
				(transition) {
					bool transitionIsValid = transition.stateChanges.entries.every(
						(element) {
							BooleanStateValue key = element.key;
							bool newValue = element.value;
							assert(managedValues[key] != null);
							ManagedValue managedValue = managedValues[key]!;
							bool currentValue = state._values[managedValue._position];
							if (currentValue == newValue) {
								return true;
							} else {
								return managedValue._canChange(state);
							}
						}
					);
					if (transitionIsValid) {
						usedTransitions.add(transition);
						Map<int, bool> updates = {};
						transition.stateChanges.forEach(
							(key, value) {
								assert(managedValues[key] != null);
								updates[managedValues[key]!._position] = value;
							}
						);
						StateTuple nextState = StateTuple._fromState(state, updates);

						adjacencyList[state]![transition] = nextState;
						if (!adjacencyList.containsKey(nextState)) {
							findNextStates(nextState);
						}
					}
				}
			);
		}
		findNextStates(initialState);
		FSMTests.noUnusedTransitions(stateTransitions, usedTransitions);
		return adjacencyList;
	}

	void changeState(StateTuple newState) {
		if (_manager._showDebugLogs) {
			Developer.log(newState.toString());
		}

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

	final void Function(StateManager manager, StateTuple currentState) action;


	_ManagedStateAction({
		required this.registeredStateValues,
		required this.action,
		required this.name,
	});

	static _ManagedStateAction? create({
		required LinkedHashMap<BooleanStateValue, ManagedValue> managedValues,
		required StateAction stateAction
	}) {
		assert(managedValues.isNotEmpty); // controlled by state manager
		bool isNotEmpty = FSMTests.stateActionValuesNotEmpty(stateAction);
		if (managedValues.isEmpty || !isNotEmpty) return null;
		List<MapEntry<BooleanStateValue, bool>> entries = stateAction.registeredStateValues.entries.toList();
		Map<int, bool> rStateValues = {};
		for (int i = 0; i < entries.length; i++) {
			assert(managedValues.containsKey(entries[i].key));
			if (!managedValues.containsKey(entries[i].key)) return null;
			rStateValues[managedValues[entries[i].key]!._position] = entries[i].value;
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
	final bool Function(StateTuple currentState, StateManager manager) _canChangeToTrue;
	final bool Function(StateTuple currentState, StateManager manager) _canChangeToFalse;
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
		_canChangeToFalse = managedValue.canChangeToFalse,
		_canChangeToTrue = managedValue.canChangeToTrue;

	bool _canChange(StateTuple state)  {
		return state._values[_position] ? _canChangeToFalse(state, _manager) : _canChangeToTrue(state, _manager);
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
				values.add(oldState.values[i]);
			}
		}
		_values = UnmodifiableListView(values);
	}

	StateTuple._fromMap(
		LinkedHashMap<BooleanStateValue, ManagedValue> valueReferences,
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

	/// width of tuple;
	int get width => _values.length;

	UnmodifiableListView<bool> get values => _values;

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
