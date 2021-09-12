part of '../StateManager.dart';

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

	final StateManager _manager;
	bool containsTransition(StateTransition transition) => _manager._stateTransitions.contains(transition);
	UnmodifiableListView<StateTransition> getTransitionQueue() => UnmodifiableListView(_manager._transitionBuffer);

	final _StateGraph _stateGraph;
	StateTuple? createAState( int hash ) => InternalStateTuple.fromHash(
		_manager._managedValues,
		_manager,
		hash
	);
	StateTuple get currentState => _stateGraph._currentState;
	int get numberOfStates => _stateGraph._validStates.length;
	bool containsState(StateTuple state) {
		InternalStateTuple s = InternalStateTuple(state);
		return s.manager == _manager && _stateGraph._validStates.containsKey(state);
	}
	StateTuple? getAdjacentState(StateTuple state, StateTransition transition) {
		InternalStateTuple s = InternalStateTuple(state);
		// Since StatTransition uses its identity for its hashcode, the check for existence on the manager isn't really required.
		//  _stateGraph._validStates[state]?[transition] should return null if the transition wasn't used with the manager.
		if (s.manager == _manager && _manager._stateTransitions.contains(transition)) {
			return _stateGraph._validStates[state]?[transition];
		}
		return null;
	}
	HashMap<Transition, StateTuple>? getAdjacentStates(StateTuple state) {
		InternalStateTuple s = InternalStateTuple(state);
		if (s.manager == _manager) {
			return _stateGraph._validStates[state];
		}
	}

	static Map<StateValue, bool>? findDifferenceBetweenStates(StateTuple stateA, StateTuple stateB) {
		InternalStateTuple sA = InternalStateTuple(stateA);
		InternalStateTuple sB = InternalStateTuple(stateB);
		if (sA.manager == sB.manager) {
			Map<StateValue, bool> diff = {};
			sA.valueReferences.forEach(
				(managedValue) {
					if (sA.values[managedValue._position] != sB.values[managedValue._position]) {
						diff[managedValue._stateValue] = sB.values[managedValue._position];
					}
				}
			);
			return diff;
		}
	}



	void dispose() { }
}