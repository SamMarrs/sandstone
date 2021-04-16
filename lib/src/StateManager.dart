import 'dart:async';
import 'dart:collection';
import 'dart:developer' as Developer;
import 'dart:math' as Math;

import 'package:flutter/cupertino.dart';

import 'unmanaged_classes/StateTransition.dart';

import 'utils.dart';

import 'FSMTests.dart';
import 'unmanaged_classes/BooleanStateValue.dart';
import 'unmanaged_classes/StateAction.dart';

part 'managed_classes/ManagedValue.dart';
part 'managed_classes/StateTuple.dart';
part 'managed_classes/ManagedStateAction.dart';
part 'managed_classes/StateGraph.dart';


// TODO: Possibly add a method to start a transition that clears and jumps the queue.
// Kind of like a hard reset option.
// Clearing the queue should be optional.


/// Creates and manages a finite state machine.
class StateManager {
	final void Function() _notifyListeners;

	late final _StateGraph _stateGraph;

	late final List<_ManagedStateAction> _managedStateActions;

	late final HashSet<StateTransition> _stateTransitions;

	final LinkedHashMap<BooleanStateValue, ManagedValue> _managedValues = LinkedHashMap();
	ManagedValue? getManagedValue(BooleanStateValue booleanStateValue) => _managedValues[booleanStateValue];

	final bool _showDebugLogs;
	final bool _optimisticTransitions;

	StateManager._({
		required void Function() notifyListener,
		required bool showDebugLogs,
		required bool optimisticTransitions
	}): _notifyListeners = notifyListener,
		_optimisticTransitions = optimisticTransitions,
		_showDebugLogs = showDebugLogs;

	/// Attempts to initialize the [StateManager] and will return `null` upon failure.
	///
	/// [notifyListeners] is called every time a state changes.
	///
	/// [managedValues] is used to define the variables that make up a state within the FSM.
	///
	/// [stateTransitions] is used to (as the name suggests) define the transitions between states.
	/// Using the [optimisticTransitions] option, you can configure this state manager to either:
	/// 1. When `false`, only transition to states with the exact changes defined in the [StateTransition].
	/// 2. When `true`, find a new state that has the minimal difference from the current state, and has the changes made by the [StateTransition].
	///
	/// In the second case, more state variables can change then specified in the [StateTransition].
	static StateManager? create({
		required void Function() notifyListeners,
		required List<BooleanStateValue> managedValues,
		required List<StateTransition> stateTransitions,
		List<StateAction>? stateActions,
		bool showDebugLogs = false,
		bool optimisticTransitions = false
	}) {
		StateManager bsm = StateManager._(notifyListener: notifyListeners, showDebugLogs: showDebugLogs, optimisticTransitions: optimisticTransitions);

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

	/// Returns the specified state value within the provided [StateTuple], given that [value] has been registered with this [StateManager].
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
					action.action(this);
				}
			}
		);
	}

	DoubleLinkedQueue<StateTransition> _transitionBuffer = DoubleLinkedQueue();
	bool _performingTransition = false;
	/// Queues a [StateTransition] to run.
	///
	/// The transition may not run immediately, or at all.
	///
	/// State transitions are queued in a buffer, and processed one at a time.
	///
	/// If queued transitions are no longer valid after a state change, they are removed from the queue.
	///
	/// If [StateTransition.ignoreDuplicates] is `true` for a given transition, any duplicates of that transition
	/// are found sequentially in the queue, the sequential duplicates will be reduced to one entry.
	void queueTransition(StateTransition transition) {
		_queueTransition(transition);
	}

	void _queueTransition(StateTransition? transition) {
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
			if (
				transition.ignoreDuplicates
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

		// What's correct the order of operations? Possibly:
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

		void purgeQueue() {
			// Purge _transitionBuffer of invalid transitions given this new state.
			_transitionBuffer.removeWhere(
				(queuedTransition) {
					// If these null checks fails, it is a mistake in the implantation.
					// Checks during initialization of the manager should guarantee these.
					return !_stateGraph._validStates[nextState]!.containsKey(queuedTransition);
				}
			);
			// If ignoreDuplicates is set, remove the transitions that might not be duplicated in the queue.
			_transitionBuffer.forEachEntry(
				(entry) {
					if (entry.element.ignoreDuplicates && entry.previousEntry() != null && entry.element == entry.previousEntry()!.element) {
						entry.remove();
					}
				}
			);
		}
		purgeQueue();

		if (transition.action != null) {
			if (_optimisticTransitions) {
				Map<BooleanStateValue, bool> diff = StateTuple._findDifference(currentState, nextState);
				diff.removeWhere((key, value) => transition.stateChanges.containsKey(key));
				transition.action!(this, diff);
			} else {
				transition.action!(this, {});
			}
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