import 'dart:async';
import 'dart:collection';
import 'dart:developer' as Developer;

import 'package:flutter/widgets.dart';
import 'package:sandstone/src/fsm_testing/Testable.dart';
import 'package:sandstone/src/fsm_testing/event_data/MirroredStateTransitionStarted.debugEvent.dart';
import 'package:sandstone/src/fsm_testing/event_data/TransitionIgnored.debugEvent.dart';
import 'package:sandstone/src/fsm_testing/event_data/public_index.dart';
import 'package:sandstone/src/managed_classes/ManagedValue.dart';
import 'package:sandstone/src/managed_classes/ManagedStateAction.dart';
import 'package:sandstone/src/managed_classes/StateGraph.dart';

import 'configurations/StateValidationLogic.dart';
import 'fsm_testing/FSMEventIDs.dart';
import 'fsm_testing/FSMTests.dart';
import 'fsm_testing/event_data/DebugEventData.dart';
import 'managed_classes/StateTuple.dart';
import 'unmanaged_classes/BooleanStateValue.dart';
import 'unmanaged_classes/StateAction.dart';
import 'unmanaged_classes/StateTransition.dart';
import 'unmanaged_classes/StateValue.dart';
import 'unmanaged_classes/Transition.dart';
import 'unmanaged_classes/fsm_mirroring.dart';
import 'utilities/Tuple.dart';

// TODO: Add a parameter so that devs can access the debug stream crontroller prior to graph initialization.
// This is so that graph initialization errors can be emitted through the same interface as transition events.

// TODO: Test for no duplicate actions. ie: registeredStateValues should be unique.
// This shouldn't prevent initialization. It should only be a warning.

// TODO: If possible, check for infinite state change cycle, where the state changes indefinitely without user input.

// TODO: Let the inital value be defined outside of the managedValues constructor parameter.

// TODO: Force the state validation functions to use the new Validator class.

// TODO: Add XOR operator.

// TODO: Mirrored FSMs setup should be able to get the initial state from the mirrored FSM intead of manually defining it.
// This should remain an option, not a requirement.

// TODO: Mirrored FSMs may be autocreated from ValueNotifier with an Enum type.
// Mirrored states can be accessed with the enum values.

// TODO: Create mirrored fsm from external StateManager.

class InternalStateManager {
	final StateManager sm;

	InternalStateManager(this.sm);

	void Function() get notifyListeners => sm._notifyListeners;

	StateGraph get stateGraph => sm._stateGraph;

	LinkedHashMap<StateTuple, List<ManagedStateAction>> get managedStateActions => sm._managedStateActions;

	HashSet<Transition> get stateTransitions => sm._stateTransitions;
	HashSet<MirroredTransition> get mirroredTransitions => sm._mirroredTransitions;

	HashSet<ManagedValue> get mirroredStates => sm._mirroredStates;
	HashSet<ManagedValue> get canBeXStates => sm._canBeXStates;
	LinkedHashMap<StateValue, ManagedValue> get managedValues => sm._managedValues;

	bool get showDebugLogs => sm._showDebugLogs;
	bool get optimisticTransitions => sm._optimisticTransitions;
	StateValidationLogic get stateValidationLogic => sm._stateValidationLogic;
	void Function(void Function())? get addPostTransitionCallback => sm._addPostTransitionCallback;

	DoubleLinkedQueue<StateTransition> get transitionBuffer => sm._transitionBuffer;

}

/// Creates and manages a finite state machine.
class StateManager {
	final void Function() _notifyListeners;

	late final StateGraph _stateGraph;

	late final LinkedHashMap<StateTuple, List<ManagedStateAction>> _managedStateActions = LinkedHashMap();

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
				// TODO: Create debug event.
				Developer.log('Ignoring transitions.');
			}
		}
	}

	final List<void Function()> _disposeCallbacks = [];

	Testable? _testable;
	Testable get testable {
		if (_testable == null) {
			_testable = InternalTestable.create(
				stateGraph: _stateGraph,
				manager: this
			);
		}
		return _testable!;
	}

	StreamController<Tuple2<FSMEventIDs, DebugEventData>>? _debugEventStreamController;
	Stream<Tuple2<FSMEventIDs, DebugEventData>> get debugEventStream {
		if (_debugEventStreamController == null) {
			_debugEventStreamController = StreamController.broadcast();
		}
		return _debugEventStreamController!.stream;
	}



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
		void Function(Stream<Tuple2<FSMEventIDs, DebugEventData>> debugEventStream)? getDebugEventStream,
	}) {
		StateManager bsm = StateManager._(
			notifyListener: notifyListeners,
			showDebugLogs: showDebugLogs,
			optimisticTransitions: optimisticTransitions,
			stateValidationLogic: stateValidationLogic
		);
		if (getDebugEventStream != null) getDebugEventStream(bsm.debugEventStream);

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
				manager._managedValues[managedValues[i]] = InternalManagedValue.create(
					managedValue: managedValues[i],
					position: i,
					manager: manager
				);
				StateValue sv = InternalManagedValue(manager._managedValues[managedValues[i]]!).stateValue;
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
						manager._managedValues[fsm.states[j]] = InternalManagedValue.create(
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
			StateGraph? stateGraph = StateGraph.create(
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
			StateGraph stateGraph
		) {
			HashSet<StateAction> actionsThatMayRun = HashSet();
			bool stateActionError = false;
			if (stateActions != null) {
				stateActions.forEach(
					(action) {
						if (
							FSMTests.checkIfAllActionStateValuesRegistered(action, stateGraph.managedValues)
						) {
							ManagedStateAction? msa = ManagedStateAction.create(
								managedValues: stateGraph.managedValues,
								stateAction: action
							);
							assert(msa != null);
							if (msa != null) {
								stateGraph.validStates.forEach(
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

		bool initializeMirroredFSMCallbacks(
			StateManager manager,
			List<FSMMirror>? mirroredFSMs
		) {
			bool allValid = true;
			mirroredFSMs?.forEach(
				(mirror) {
					// Initializing InternalFSMMirror so that it's error events will get pushed to the event stream.
					if (bsm._debugEventStreamController != null) {
						InternalFSMMirror(fsmMirror: mirror).validate(bsm._debugEventStreamController!);
					}
					allValid = allValid && mirror.initializedCorrectly;
					if (allValid) {
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
				}
			);
			return allValid;
		}

		if (mirroredFSMs == null ? false : !mirroredFSMs.every((mirror) => mirror.initializedCorrectly)) return null;

		if (!initializeStateTransitions(bsm, stateTransitions, mirroredFSMs)) return null;

		initializeManagedValues(bsm, managedValues, mirroredFSMs);

		if (!initializeStateGraph(bsm, bsm._stateTransitions, bsm._managedValues)) return null;

		if (!initializeStateActions(bsm, stateActions, bsm._stateGraph)) return null;

		if (!initializeMirroredFSMCallbacks(bsm, mirroredFSMs)) return null;

		bsm._doActions();
		return bsm;
	}

	void dispose() {
		_testable?.dispose();
		_debugEventStreamController?.close();
		_disposeCallbacks.forEach((callback) => callback());
	}

	/// Returns the specified state value within the provided [StateTuple], given that [value] has been registered with this [StateManager].
	bool? getFromState(StateTuple stateTuple, StateValue value) {
		InternalStateTuple st = InternalStateTuple(stateTuple);
		assert(st.manager == this, 'StateTuple must be from the same state manager.');
		if (st.manager != this) {
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.UNKNOWN_STATE_TUPLE,
					UnknownStateTuple(
						stateTuple: stateTuple
					)
				)
			);
			return null;
		}
		assert(_managedValues.containsKey(value), 'StateValue must have been registered with this state manager.');
		if (!_managedValues.containsKey(value)) {
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.UNKNOWN_STATE_VALUE,
					UnknownStateValue(
						stateTuple: stateTuple,
						stateValue: value
					)
				)
			);
			return null;
		}
		// Performed null check in previous if statement.
		return st.values[InternalManagedValue(_managedValues[value]!).position];
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
		} else {
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.TRANSITION_IGNORED,
					TransitionIgnored(
						currentState: _stateGraph.currentState,
						transition: transition,
						ignoredBecausePaused: true
					)
				)
			);
			// Developer.log('Ignoring the transition "${transition.name}", because ignoreTransitions is set to true.');
		}
	}

	DoubleLinkedQueue<MirroredTransition> _mirroredTransitionBuffer = DoubleLinkedQueue();
	bool _routeIsolationOccurred = false;
	void _queueMirroredTransition(MirroredTransition transition) {
		assert(_stateTransitions.contains(transition), 'Unknown mirrored transition: "${transition.name}".');
		if (!_stateTransitions.contains(transition)) {
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.TRANSITION_IGNORED,
					TransitionIgnored(
						currentState: _stateGraph.currentState,
						transition: transition,
						isUnknownTransition: true
					)
				)
			);
			return;
		}
		if (_transitionsPaused) {
			_routeIsolationOccurred = true;
		}
		if (!_stateGraph.validStates[_stateGraph.currentState]!.containsKey(transition)) {
			assert(!(transition is MirroredTransition));
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.TRANSITION_IGNORED,
					TransitionIgnored(
						currentState: _stateGraph.currentState,
						transition: transition,
						willNotSucceed: true
					)
				)
			);
			// Developer.log('Ignoring mirrored transition "${transition.name}" because it does not transition to a valid state.');
			return;
		}
		if (
			transition.ignoreDuplicates
			&& _mirroredTransitionBuffer.isNotEmpty
			&& _mirroredTransitionBuffer.last == transition
		) {
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.TRANSITION_IGNORED,
					TransitionIgnored(
						currentState: _stateGraph.currentState,
						transition: transition,
						ignoredBecauseOfDuplicate: true
					)
				)
			);
			// Developer.log('Ignoring mirrored transition "${transition.name}" because ignoreDuplicate is set.');
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
			if (!_stateTransitions.contains(transition)) {
				_debugEventStreamController?.add(
					Tuple2(
						FSMEventIDs.TRANSITION_IGNORED,
						TransitionIgnored(
							currentState: _stateGraph.currentState,
							transition: transition,
							isUnknownTransition: true
						)
					)
				);
				return;
			}
			// Check if transition is possible. Ignore if not.
			if (!_stateGraph.validStates[_stateGraph.currentState]!.containsKey(transition)) {
				_debugEventStreamController?.add(
					Tuple2(
						FSMEventIDs.TRANSITION_IGNORED,
						TransitionIgnored(
							currentState: _stateGraph.currentState,
							transition: transition,
							willNotSucceed: true
						)
					)
				);
				// Developer.log('Ignoring transition "${transition.name}" because it does not transition to a valid state.');
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
				_debugEventStreamController?.add(
					Tuple2(
						FSMEventIDs.TRANSITION_IGNORED,
						TransitionIgnored(
							currentState: _stateGraph.currentState,
							transition: transition,
							ignoredBecauseOfDuplicate: true
						)
					)
				);
				// Developer.log('Ignoring transition "${transition.name}" because ignoreDuplicate is set.');
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

	void _changeState({
		required StateTuple previousState,
		required StateTuple nextState,
		Transition? transition
	}) {
		_stateGraph.changeState(nextState);
		_debugEventStreamController?.add(
			Tuple2(
				FSMEventIDs.STATE_CHANGED,
				StateChanged(
					previousState: previousState,
					nextState: nextState,
					transition: transition
				)
			)
		);
	}

	void _purgeQueue({
		required StateTuple previousState,
		required StateTuple nextState,
		StateTransition? activeTransition
	}) {
		List<StateTransition> purgedTransitions = [];
		// Purge _transitionBuffer of invalid transitions given this new state.
		_transitionBuffer.removeWhere(
			(queuedTransition) {
				// If these null checks fails, it is a mistake in the implantation.
				// Checks during initialization of the manager should guarantee these.
				bool shouldFilter = !_stateGraph.validStates[nextState]!.containsKey(queuedTransition);
				if (shouldFilter && _debugEventStreamController != null) {
					purgedTransitions.add(queuedTransition);
				}
				return shouldFilter;
			}
		);
		// If ignoreDuplicates is set, remove the transitions that might now be duplicated in the queue.
		_transitionBuffer.forEachEntry(
			(entry) {
				if (entry.element.ignoreDuplicates && entry.previousEntry() != null && entry.element == entry.previousEntry()!.element) {
					if (_debugEventStreamController != null) {
						purgedTransitions.add(entry.element);
					}
					entry.remove();
				}
			}
		);
		_debugEventStreamController?.add(
			Tuple2(
				FSMEventIDs.BUFFER_PURGED,
				BufferPurged(
					previousState: previousState,
					nextState: nextState,
					purgedTransitions: purgedTransitions,
					activeTransition: activeTransition
				)
			)
		);
	}

	_runTransitionAction({
		required Transition transition,
		required StateTuple previousState,
		required StateTuple nextState
	}) {
		if (transition.action != null) {
			Map<StateValue, bool> diff = {};
			if (_optimisticTransitions) {
				diff = InternalStateTuple.findDifference(previousState, nextState);
				diff.removeWhere((key, value) => transition.stateChanges.containsKey(key));
			}
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.RUNNING_TRANSITION_ACTIONS,
					RunningTransitionActions(
						transition: transition
					)
				)
			);
			// Developer.log('Running transition action "${transition.name}".');
			transition.action!(this, diff);
		}
	}

	void _propagateStateChanges() {
		_debugEventStreamController?.add(
			Tuple2(
				FSMEventIDs.PROPAGATING_STATE_CHANGES,
				PropagatingStateChanges()
			)
		);
		_notifyListeners();
	}

	_schedulePostTransitionActions({
		required StateTuple previousState,
		required StateTuple nextState
	}) {
		if (_addPostTransitionCallback != null) {
			_addPostTransitionCallback!(
				() {
					if (previousState != nextState) {
						_doActions();
					}
					_endTransitionProcess();
				}
			);
		} else {
			assert(WidgetsBinding.instance != null);
			WidgetsBinding.instance!.addPostFrameCallback(
				(timeStamp) {
					if (previousState != nextState) {
						_doActions();
					}
					_endTransitionProcess();
				}
			);
		}
	}

	void _doActions() {
		if (_debugEventStreamController != null) {
			List<Tuple2<String, Map<int, bool>>> actions = [];
			_managedStateActions[_stateGraph.currentState]?.forEach(
				(action) {
					actions.add(Tuple2(action.name, action.registeredStateValues));
				}
			);
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.RUNNING_STATE_ACTIONS,
					RunningStateActions(
						currentState: _stateGraph.currentState,
						actions: actions
					)
				)
			);
		}
		_managedStateActions[_stateGraph.currentState]?.forEach(
			(action) {
				// if (_showDebugLogs) {
				// 	Developer.log('Running action "${action.name}".');
				// }
				action.action(this);
			}
		);
	}

	void _endTransitionProcess() {
		_performingTransition = false;
		_debugEventStreamController?.add(
			Tuple2(
				FSMEventIDs.TRANSITION_PROCESS_ENDED,
				TransitionProcessEnded()
			)
		);
		_queueTransition(null);
	}

	void _processRouteIsolationMirrorBuffer() {
		StateTuple currentState = _stateGraph.currentState;
		StateTuple? nextState = currentState;
		// fast forward the state by applying all of the buffered transitions.
		_debugEventStreamController?.add(
			Tuple2(
				FSMEventIDs.FF_MIRRORED_TRANSITION_STARTED,
				FFMirroredTransitionStarted(
					transitionBufferIterable: _mirroredTransitionBuffer
				)
			)
		);
		// Developer.log('Fast forwarding the state with all of the buffered mirrored transitions.');
		_mirroredTransitionBuffer.forEach(
			(mirroredTransition) {
				// This assertion should never fail if StateGraph is initialized properly.
				// TODO: create error event for this assert statement
				assert(_stateGraph.validStates[nextState]!.containsKey(mirroredTransition));
				nextState = _stateGraph.validStates[nextState]![mirroredTransition];
			}
		);
		_mirroredTransitionBuffer.clear();
		assert(nextState != null);
		if (nextState == null) {
			_endTransitionProcess();
			return;
		}
		if (currentState != nextState) {
			_changeState(
				previousState: currentState,
				nextState: nextState!
			);
		}

		_purgeQueue(
			previousState: currentState,
			nextState: nextState ?? currentState
		);
		if (currentState != nextState) {
			_propagateStateChanges();
		}
		_schedulePostTransitionActions(
			previousState: currentState,
			nextState: nextState?? currentState
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

		_debugEventStreamController?.add(
			Tuple2(
				FSMEventIDs.TRANSITION_PROCESS_STARTED,
				TransitionProcessStarted()
			)
		);

		if (_mirroredTransitionBuffer.isNotEmpty && _routeIsolationOccurred) {
			_routeIsolationOccurred = false;
			return _processRouteIsolationMirrorBuffer();
		}

		StateTuple currentState = _stateGraph.currentState;
		MirroredTransition? mirroredTransition;
		StateTransition? stateTransition;
		if (_mirroredTransitionBuffer.isNotEmpty) {
			mirroredTransition = _mirroredTransitionBuffer.removeFirst();
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.MIRRORED_STATE_TRANSITION_STARTED,
					MirroredTransitionStarted(
						transition: mirroredTransition,
						currentState: currentState
					)
				)
			);
		} else {
			stateTransition = _transitionBuffer.removeFirst();
			_debugEventStreamController?.add(
				Tuple2(
					FSMEventIDs.STATE_TRANSITION_STARTED,
					StateTransitionStarted(
						transition: stateTransition,
						currentState: currentState
					)
				)
			);
			// Developer.log('Processing transition "${stateTransition.name}".');
		}

		// If these null checks fails, it is a mistake in the implementation.
		// Checks during initialization of the manager should guarantee these.
		StateTuple? nextState = _stateGraph.validStates[currentState]![stateTransition?? mirroredTransition];
		// Check if transition is possible given the current state. Ignore if not.
		if (nextState == null) {
			_endTransitionProcess();
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
			if (stateTransition == null) {
				_changeState(
					previousState: currentState,
					nextState: nextState,
					transition: mirroredTransition
				);
			} else {
				_changeState(
					previousState: currentState,
					nextState: nextState,
					transition: stateTransition
				);
			}
		}

		_purgeQueue(
			previousState: currentState,
			nextState: nextState,
			activeTransition: stateTransition
		);

		if (mirroredTransition?.action != null) {
			_runTransitionAction(
				previousState: currentState,
				nextState: nextState,
				transition: mirroredTransition!
			);
		} else if (stateTransition?.action != null) {
			_runTransitionAction(
				previousState: currentState,
				nextState: nextState,
				transition: stateTransition!
			);
		}
		if (currentState != nextState) {
			_propagateStateChanges();
		}
		_schedulePostTransitionActions(
			previousState: currentState,
			nextState: nextState
		);
	}
}