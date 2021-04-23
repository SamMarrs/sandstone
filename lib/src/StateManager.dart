import 'dart:async';
import 'dart:collection';
import 'dart:developer' as Developer;
import 'dart:math' as Math;

import 'package:flutter/widgets.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/unmanaged_classes/fsm_mirroring.dart';

import 'configurations/StateValidationLogic.dart';
import 'unmanaged_classes/Transition.dart';
import 'utilities/Utils.dart';

import 'unmanaged_classes/StateTransition.dart';


import 'fsm_testing/FSMTests.dart';
import 'unmanaged_classes/BooleanStateValue.dart';
import 'unmanaged_classes/StateAction.dart';

part 'managed_classes/ManagedValue.dart';
part 'managed_classes/StateTuple.dart';
part 'managed_classes/ManagedStateAction.dart';
part 'managed_classes/StateGraph.dart';

// TODO: Test for no duplicate actions. ie: registeredStateValues should be unique.
// This shouldn't prevent initialization. It should only be a warning.

// TODO: If possible, check for infinite state change cycle, where the state changes indefinitely without user input.

/// Creates and manages a finite state machine.
class StateManager {
	final void Function() _notifyListeners;

	late final _StateGraph _stateGraph;

	late final LinkedHashMap<StateTuple, List<_ManagedStateAction>> _managedStateActions;

	final HashSet<Transition> _stateTransitions = HashSet();
	final HashSet<MirroredTransition> _mirroredTransitions = HashSet();

	final HashSet<ManagedValue> _mirroredStates = HashSet();
	final HashSet<ManagedValue> _canBeXStates = HashSet();
	final LinkedHashMap<StateValue, ManagedValue> _managedValues = LinkedHashMap();
	ManagedValue? getManagedValue(StateValue booleanStateValue) => _managedValues[booleanStateValue];

	final bool _showDebugLogs;
	final bool _optimisticTransitions;
	final StateValidationLogic _stateValidationLogic;
	final void Function(void Function())? _addPostTransitionCallback;

	bool _transitionsPaused = false;
	/// When `shouldIgnore` is set to `true`, queuing of all non-mirrored transitions will be ignored,
	/// and all processing of transitions will be paused. When `clearQueue` is true, all non-mirrored
	/// transitions will be cleared from the queue.
	///
	/// All queued [MirroredTransition] will be buffered and run when this is set back to `false`.
	///
	/// This becomes useful when the context of this [StateManager] is no longer the currently visible route.
	/// Callbacks to this [StateManager] may still affect it when a different route is visible, even though the two routes
	/// should be independent.
	void pauseTransitions(bool shouldPause, {bool? clearQueue}) {
		if (shouldPause != _transitionsPaused) {
			_transitionsPaused = shouldPause;
			if (clearQueue?? false) {
				_transitionBuffer.clear();
			}
			if (!shouldPause) {
				_processTransition();
			} else if (_showDebugLogs) {
				Developer.log('Ignoring transitions.');
			}
		}
	}

	final List<void Function()> _disposeCallbacks = [];

	StateManager._({
		required void Function() notifyListener,
		required bool showDebugLogs,
		required bool optimisticTransitions,
		required StateValidationLogic stateValidationLogic,
		void Function(void Function())? addPostTransitionCallback,
	}): _notifyListeners = notifyListener,
		_optimisticTransitions = optimisticTransitions,
		_showDebugLogs = showDebugLogs,
		_stateValidationLogic = stateValidationLogic,
		_addPostTransitionCallback = addPostTransitionCallback;

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
	///
	/// See [StateValidationLogic] for information on [stateValidationLogic]
	/// By default, state actions are run at the end of a frame using `WidgetsBinding.instance.addPostFrameCallback`.
	/// This can overridden using [addPostTransitionCallback].
	/// [addPostTransitionCallback] must mimic [addPostFrameCallback] in that the callback function is only called once.
	static StateManager? create({
		required void Function() notifyListeners,
		required List<BooleanStateValue> managedValues,
		required List<StateTransition> stateTransitions,
		List<FSMMirror>? mirroredFSMs,
		List<StateAction>? stateActions,
		bool showDebugLogs = false,
		bool optimisticTransitions = false,
		StateValidationLogic stateValidationLogic = StateValidationLogic.canChangeToX,
		void Function(void Function())? addPostTransitionCallback,
	}) {
		StateManager bsm = StateManager._(
			notifyListener: notifyListeners,
			showDebugLogs: showDebugLogs,
			optimisticTransitions: optimisticTransitions,
			stateValidationLogic: stateValidationLogic
		);

		// Returns true or false based on success.
		bool initializeStateTransitions(
			StateManager manager,
			List<StateTransition> stateTransitions,
			List<FSMMirror>? mirroredFSMs
		) {
			bool stateTransitionError = false;
			stateTransitions.forEach(
				(transition) {
					if (
						FSMTests.noDuplicateTransitions(manager._stateTransitions, transition)
						&& FSMTests.checkIfAllStateValuesRegistered(transition, managedValues)
						&& FSMTests.noMirroredStatesInTransition(transition)
					) {
						FSMTests.stateTransitionValuesNotEmpty(transition);
						manager._stateTransitions.add(transition);
					} else {
						stateTransitionError = true;
					}
				}
			);

			// Initialize mirrored transitions.
			mirroredFSMs?.forEach(
				(fsm) {
					fsm.transitions.forEach(
						(transition) {
							if (
								FSMTests.noDuplicateTransitions(manager._stateTransitions, transition)
							) {
								FSMTests.stateTransitionValuesNotEmpty(transition);
								manager._stateTransitions.add(transition);
								manager._mirroredTransitions.add(transition);
							} else {
								stateTransitionError = true;
							}
						}
					);
				}
			);

			return !stateTransitionError;
		}
		void initializeManagedValues(
			StateManager manager,
			List<BooleanStateValue> managedValues,
			List<FSMMirror>? mirroredFSMs
		) {
			int i = 0;
			for (i = 0; i < managedValues.length; i++) {
				manager._managedValues[managedValues[i]] = ManagedValue._(
					managedValue: managedValues[i],
					position: i,
					manager: manager
				);
				StateValue sv = manager._managedValues[managedValues[i]]!._stateValue;
				if (
					sv is BooleanStateValue
					&& sv.stateValidationLogic == StateValidationLogic.canBeX
					|| (
						sv is BooleanStateValue
						&& sv.stateValidationLogic == null
						&& manager._stateValidationLogic == StateValidationLogic.canBeX
					)
				) {
					manager._canBeXStates.add(manager._managedValues[managedValues[i]]!);
				}
			}
			// Initialize mirrored states
			mirroredFSMs?.forEach(
				(fsm) {
					int j = 0;
					for (; j < fsm.states.length; j++) {
						manager._managedValues[fsm.states[j]] = ManagedValue._(
							managedValue: fsm.states[j],
							position: i + j,
							manager: manager
						);
						manager._mirroredStates.add(manager._managedValues[fsm.states[j]]!);
					}
					i += j;
				}
			);
		}
		bool initializeStateGraph(
			StateManager manager,
			HashSet<Transition> stateTransitions,
			LinkedHashMap<StateValue, ManagedValue> managedValues
		) {
			_StateGraph? stateGraph = _StateGraph.create(
				manager: manager,
				stateTransitions: stateTransitions,
				unmanagedToManagedValues: managedValues
			);
			if (stateGraph == null) {
				return false;
			}
			manager._stateGraph = stateGraph;
			return true;
		}

		bool initializeStateActions(
			StateManager manager,
			List<StateAction>? stateActions,
			_StateGraph stateGraph
		) {
			HashSet<StateAction> actionsThatMayRun = HashSet();
			bool stateActionError = false;
			if (stateActions != null) {
				stateActions.forEach(
					(action) {
						if (
							FSMTests.checkIfAllActionStateValuesRegistered(action, stateGraph._managedValues)
						) {
							_ManagedStateAction? msa = _ManagedStateAction.create(
								managedValues: stateGraph._managedValues,
								stateAction: action
							);
							assert(msa != null);
							if (msa != null) {
								stateGraph._validStates.forEach(
									(state, _) {
										if (msa.shouldRun(state)) {
											actionsThatMayRun.add(action);
											if (!manager._managedStateActions.containsKey(state)) {
												manager._managedStateActions[state] = [];
											}
											manager._managedStateActions[state]!.add(msa);
										}
									}
								);
							}
						} else {
							stateActionError = true;
						}
					}
				);
				FSMTests.checkIfAllActionsMayRun(
					stateActions,
					actionsThatMayRun
				);
			}

			return !stateActionError;
		}

		void initializeMirroredFSMCallbacks(
			StateManager manager,
			List<FSMMirror>? mirroredFSMs
		) {
			mirroredFSMs?.forEach(
				(mirror) {
					MirroredStateChangeCallback callback = (transition) {
						bool sameMirror = transition.mirror == mirror;
						assert(sameMirror);
						if (sameMirror) {
							bsm._queueMirroredTransition(transition);
						}
					};
					RegisterDisposeCallback onDisposeCallback = (callback) {
						bsm._disposeCallbacks.add(callback);
					};

					mirror.stateUpdates(callback, onDisposeCallback);
				}
			);
		}

		if (mirroredFSMs == null ? false : !mirroredFSMs.every((mirror) => mirror.initializedCorrectly)) return null;

		if (!initializeStateTransitions(bsm, stateTransitions, mirroredFSMs)) return null;

		initializeManagedValues(bsm, managedValues, mirroredFSMs);

		if (!initializeStateGraph(bsm, bsm._stateTransitions, bsm._managedValues)) return null;

		if (!initializeStateActions(bsm, stateActions, bsm._stateGraph)) return null;

		initializeMirroredFSMCallbacks(bsm, mirroredFSMs);
		bsm._doActions();
		return bsm;
	}

	void dispose() {
		_disposeCallbacks.forEach((callback) => callback());
	}

	/// Returns the specified state value within the provided [StateTuple], given that [value] has been registered with this [StateManager].
	bool? getFromState(StateTuple stateTuple, StateValue value) {
		assert(stateTuple._manager == this, 'StateTuple must be from the same state manager.');
		assert(_managedValues.containsKey(value), 'StateValue must have been registered with this state manager.');
		if (stateTuple._manager != this || !_managedValues.containsKey(value)) return null;
		// Performed null check in previous if statement.
		return stateTuple._values[_managedValues[value]!._position];
	}

	void _doActions() {
		_managedStateActions[_stateGraph._currentState]?.forEach(
			(action) {
				if (_showDebugLogs) {
					Developer.log('Running action "${action.name}".');
				}
				action.action(this);
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
	///
	/// If [clearQueue] is `true`, all queued transitions are cleared, before queueing the provided transition.
	void queueTransition(
		StateTransition transition,
		{
			bool? clearQueue,
			bool? jumpQueue
		}
	) {
		if (!_transitionsPaused) {
			_queueTransition(transition, clearQueue: clearQueue, jumpQueue: jumpQueue);
		} else if (_showDebugLogs) {
			Developer.log('Ignoring the transition "${transition.name}", because ignoreTransitions is set to true.');
		}
	}

	DoubleLinkedQueue<MirroredTransition> _mirroredTransitionBuffer = DoubleLinkedQueue();
	bool _routeIsolationOccurred = false;
	void _queueMirroredTransition(MirroredTransition transition) {
		assert(_stateTransitions.contains(transition), 'Unknown mirrored transition: "${transition.name}".');
		if (_transitionsPaused) {
			_routeIsolationOccurred = true;
		}
		if (!_stateGraph._validStates[_stateGraph._currentState]!.containsKey(transition)) {
			assert(!(transition is MirroredTransition));
			if (_showDebugLogs) {
				Developer.log('Ignoring mirrored transition "${transition.name}" because it does not transition to a valid state.');
			}
			return;
		}
		if (
			transition.ignoreDuplicates
			&& _mirroredTransitionBuffer.isNotEmpty
			&& _mirroredTransitionBuffer.last == transition
		) {
			if (_showDebugLogs) {
				Developer.log('Ignoring mirrored transition "${transition.name}" because ignoreDuplicate is set.');
			}
			return;
		}

		_mirroredTransitionBuffer.addLast(transition);
		if (!_performingTransition && !_transitionsPaused) {
			Future(_processTransition);
		}
	}

	void _queueTransition(
		StateTransition? transition,
		{
			bool? clearQueue,
			bool? jumpQueue,
		}
	) {
		if (clearQueue?? false) {
			_transitionBuffer.clear();
		}
		if (transition == null) {
			if ((_transitionBuffer.isNotEmpty || _mirroredTransitionBuffer.isNotEmpty) && !_performingTransition && !_transitionsPaused) {
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
				&& _transitionBuffer.isNotEmpty
				&& (
					( (jumpQueue?? false) && _transitionBuffer.first == transition )
					|| ( (!(jumpQueue?? false)) && _transitionBuffer.last == transition )
				)
			) {
				if (_showDebugLogs) {
					Developer.log('Ignoring transition "${transition.name}" because ignoreDuplicate is set.');
				}
				return;
			}
			if ((jumpQueue?? false)) {
				_transitionBuffer.addFirst(transition);
			} else {
				_transitionBuffer.addLast(transition);
			}
			if (!_performingTransition) {
				Future(_processTransition);
			}
		}
	}

	void _processRouteIsolationMirrorBuffer() {
		StateTuple currentState = _stateGraph._currentState;
		StateTuple? nextState = currentState;
		// fast forward the state by applying all of the buffered transitions.
		if (_showDebugLogs) {
			Developer.log('Fast forwarding the state with all of the buffered mirrored transitions.');
		}
		_mirroredTransitionBuffer.forEach(
			(mirroredTransition) {
				// This assertion should never fail if StateGraph is initialized properly.
				assert(_stateGraph._validStates[nextState]!.containsKey(mirroredTransition));
				nextState = _stateGraph._validStates[nextState]![mirroredTransition];
			}
		);
		_mirroredTransitionBuffer.clear();
		assert(nextState != null);
		if (nextState == null) {
			_performingTransition = false;
			_queueTransition(null);
			return;
		}
		if (currentState != nextState) {
			_stateGraph.changeState(nextState!);
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
			// If ignoreDuplicates is set, remove the transitions that might now be duplicated in the queue.
			_transitionBuffer.forEachEntry(
				(entry) {
					if (entry.element.ignoreDuplicates && entry.previousEntry() != null && entry.element == entry.previousEntry()!.element) {
						entry.remove();
					}
				}
			);
		}
		purgeQueue();
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

	void _processTransition() {
		// If a separate isolate queues a transition, this check could change between _queueTransition and here.
		// Need to check again.
		if (
			_performingTransition
			|| _transitionsPaused
			|| (
				_transitionBuffer.isEmpty
				&& _mirroredTransitionBuffer.isEmpty
			)
		) return;

		_performingTransition = true;
		if (_mirroredTransitionBuffer.isNotEmpty && _routeIsolationOccurred) {
			_routeIsolationOccurred = false;
			return _processRouteIsolationMirrorBuffer();
		}

		MirroredTransition? mirroredTransition;
		StateTransition? stateTransition;
		if (_mirroredTransitionBuffer.isNotEmpty) {
			mirroredTransition = _mirroredTransitionBuffer.removeFirst();
			if (_showDebugLogs) {
				Developer.log('Processing mirrored transition "${mirroredTransition.name}".');
			}
		} else {
			stateTransition = _transitionBuffer.removeFirst();
			if (_showDebugLogs) {
				Developer.log('Processing transition "${stateTransition.name}".');
			}
		}

		StateTuple currentState = _stateGraph._currentState;
		// If these null checks fails, it is a mistake in the implementation.
		// Checks during initialization of the manager should guarantee these.
		StateTuple? nextState = _stateGraph._validStates[currentState]![stateTransition?? mirroredTransition];
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
			// If ignoreDuplicates is set, remove the transitions that might now be duplicated in the queue.
			_transitionBuffer.forEachEntry(
				(entry) {
					if (entry.element.ignoreDuplicates && entry.previousEntry() != null && entry.element == entry.previousEntry()!.element) {
						entry.remove();
					}
				}
			);
		}
		purgeQueue();

		if (mirroredTransition?.action != null) {
			Map<StateValue, bool> diff = {};
			if (_optimisticTransitions) {
				diff = StateTuple._findDifference(currentState, nextState);
				diff.removeWhere((key, value) => mirroredTransition!.stateChanges.containsKey(key));
			}
			if (_showDebugLogs) {
				Developer.log('Running transition action "${mirroredTransition!.name}".');
			}
			mirroredTransition!.action!(this, diff);
		} else if (stateTransition?.action != null) {
			Map<StateValue, bool> diff = {};
			if (_optimisticTransitions) {
				diff = StateTuple._findDifference(currentState, nextState);
				diff.removeWhere((key, value) => stateTransition!.stateChanges.containsKey(key));
			}
			if (_showDebugLogs) {
				Developer.log('Running transition action "${stateTransition!.name}".');
			}
			stateTransition!.action!(this, diff);
		}
		if (currentState != nextState) {
			_notifyListeners();
		}
		if (_addPostTransitionCallback != null) {
			_addPostTransitionCallback!(
				() {
					if (currentState != nextState) {
						_doActions();
					}
					_performingTransition = false;
					_queueTransition(null);
				}
			);
		} else {
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
}