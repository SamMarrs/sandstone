import 'dart:collection';

import 'package:sandstone/src/StateManager.dart';
import 'package:sandstone/src/managed_classes/ManagedValue.dart';
import 'package:sandstone/src/managed_classes/StateGraph.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateTransition.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/unmanaged_classes/Transition.dart';

class InternalTestable {
	static Testable create({
		required StateGraph stateGraph,
		required StateManager manager,
	}) => Testable._(stateGraph: stateGraph, manager: manager);
}

/// Only use for testing purposes.
class Testable {

	Testable._({
		required StateGraph stateGraph,
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
	bool containsTransition(StateTransition transition) {
		InternalStateManager ism = InternalStateManager(_manager);
		return ism.stateTransitions.contains(transition);
	}
	UnmodifiableListView<StateTransition> getTransitionQueue() => UnmodifiableListView(InternalStateManager(_manager).transitionBuffer);

	final StateGraph _stateGraph;
	StateTuple? createAState( int hash ) {
		InternalStateManager ism = InternalStateManager(_manager);
		return InternalStateTuple.fromHash(
			ism.managedValues,
			_manager,
			hash
		);
	}
	StateTuple get currentState => _stateGraph.currentState;
	int get numberOfStates => _stateGraph.validStates.length;
	bool containsState(StateTuple state) {
		InternalStateTuple s = InternalStateTuple(state);
		return s.manager == _manager && _stateGraph.validStates.containsKey(state);
	}
	StateTuple? getAdjacentState(StateTuple state, StateTransition transition) {
		InternalStateTuple s = InternalStateTuple(state);
		InternalStateManager ism = InternalStateManager(_manager);
		// Since StatTransition uses its identity for its hashcode, the check for existence on the manager isn't really required.
		//  _stateGraph._validStates[state]?[transition] should return null if the transition wasn't used with the manager.
		if (s.manager == _manager && ism.stateTransitions.contains(transition)) {
			return _stateGraph.validStates[state]?[transition];
		}
		return null;
	}
	HashMap<Transition, StateTuple>? getAdjacentStates(StateTuple state) {
		InternalStateTuple s = InternalStateTuple(state);
		if (s.manager == _manager) {
			return _stateGraph.validStates[state];
		}
	}

	static Map<StateValue, bool>? findDifferenceBetweenStates(StateTuple stateA, StateTuple stateB) {
		InternalStateTuple sA = InternalStateTuple(stateA);
		InternalStateTuple sB = InternalStateTuple(stateB);
		if (sA.manager == sB.manager) {
			Map<StateValue, bool> diff = {};
			sA.valueReferences.forEach(
				(managedValue) {
					InternalManagedValue imv = InternalManagedValue(managedValue);
					if (sA.values[imv.position] != sB.values[imv.position]) {
						diff[imv.stateValue] = sB.values[imv.position];
					}
				}
			);
			return diff;
		}
	}



	void dispose() { }
}