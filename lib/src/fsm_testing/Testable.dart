part of '../StateManager.dart';

enum FSMEventIDs {
	TRANSITION_IGNORED,
	TRANSITION_PROCESS_STARTED,
	STATE_TRANSITION_STARTED,
	MIRRORED_STATE_TRANSITION_STARTED,
	FF_MIRRORED_TRANSITION_STARTED,
	VALID_STATE_NOT_FOUND,
	STATE_CHANGED,
	BUFFER_PURGED,
	RUNNING_TRANSITION_ACTIONS,
	PROPAGATING_STATE_CHANGES,
	RUNNING_STATE_ACTIONS,
	TRANSITION_PROCESS_ENDED,
}

/// Only use for testing purposes.
class Testable {

	Testable._({
		required _StateGraph stateGraph,
		required StateManager manager,
	}): _stateGraph = stateGraph,
		_manager = manager;

	// TODO: add something for emitting information about an active transition
	// emit:
	// 1. active transition
	// 2. previous state
	// 3. next state
	// 4. difference between previous and next state
	// 5. transition actions
	// 6. state actions
	// 7. purged transitions

	// TODO: add something for emitting which transitions were ignored.

	StreamController<Tuple2<FSMEventIDs, DebugEventData>> _debugFSMEventStreamController = StreamController.broadcast();
	Stream<Tuple2<FSMEventIDs, DebugEventData>> get debugFSMEventStream => _debugFSMEventStreamController.stream;


	final StateManager _manager;
	bool containsTransition(StateTransition transition) => _manager._stateTransitions.contains(transition);
	UnmodifiableListView<StateTransition> getTransitionQueue() => UnmodifiableListView(_manager._transitionBuffer);

	final _StateGraph _stateGraph;
	StateTuple? createAState( int hash ) => StateTuple._fromHash(
		_manager._managedValues,
		_manager,
		hash
	);
	StateTuple get currentState => _stateGraph._currentState;
	int get numberOfStates => _stateGraph._validStates.length;
	bool containsState(StateTuple state) => state._manager == _manager && _stateGraph._validStates.containsKey(state);
	StateTuple? getAdjacentState(StateTuple state, StateTransition transition) {
		// Since StatTransition uses its identity for its hashcode, the check for existence on the manager isn't really required.
		//  _stateGraph._validStates[state]?[transition] should return null if the transition wasn't used with the manager.
		if (state._manager == _manager && _manager._stateTransitions.contains(transition)) {
			return _stateGraph._validStates[state]?[transition];
		}
		return null;
	}
	HashMap<Transition, StateTuple>? getAdjacentStates(StateTuple state) {
		if (state._manager == _manager) {
			return _stateGraph._validStates[state];
		}
	}

	static Map<StateValue, bool>? findDifferenceBetweenStates(StateTuple stateA, StateTuple stateB) {
		if (stateA._manager == stateB._manager) {
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
	}



	void dispose() {
		_debugFSMEventStreamController.close();
	}
}