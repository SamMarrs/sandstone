part of '../StateManager.dart';

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

		HashMap<StateTuple, HashMap<StateTransition, StateTuple>>? validStates = _StateGraph._buildAdjacencyList(
			managedValues: unmanagedToManagedValues,
			manager: manager,
			stateTransitions: stateTransitions
		);
		StateTuple currentState = StateTuple._fromMap(unmanagedToManagedValues, manager);
		return validStates == null ? null : _StateGraph._(
			managedValues: unmanagedToManagedValues,
			validStates: validStates,
			currentState: currentState,
			manager: manager
		);
	}

	static HashMap<StateTuple, HashMap<StateTransition, StateTuple>>? _buildAdjacencyList({
		required LinkedHashMap<BooleanStateValue, ManagedValue> managedValues,
		required StateManager manager,
		required HashSet<StateTransition> stateTransitions,
	}) {
		StateTuple initialState = StateTuple._fromMap(managedValues, manager);
		HashMap<StateTuple, HashMap<StateTransition, StateTuple>> adjacencyList = HashMap();
		HashSet<StateTransition> usedTransitions = HashSet();
		bool failedMirroredTransition = false;

		void optimisticFindNextState(StateTuple state) {
			if (adjacencyList.containsKey(state)) {
				// This state has already been visited.
				return;
			}
			adjacencyList[state] = HashMap();
			stateTransitions.forEach(
				(transition) {
					// Find next state with minimum difference from current state.
					// Assert that there should only be one state with the minimum difference.
					// If there is one or more states with the minimum difference, save only one as done in conservativeFindNextState
					Map<int, bool> updates = {};
					transition.stateChanges.forEach(
						(key, value) {
							assert(managedValues[key] != null);
							updates[managedValues[key]!._position] = value;
						}
					);

					// A MirroredTransition can make changes to a mirrored state, but a regular transition may not.
					// The changes specified by a MirroredTransition should be the only MirroredStateValue changes.
					bool noMirroredChanges(StateTuple nextState) {
						return !manager._mirroredStates.any(
							(managedValue) {
								bool oldValue = state._values[managedValue._position];
								bool newValue = nextState._values[managedValue._position];
								if (
									transition is MirroredTransition
									&& transition.stateChanges.containsKey(managedValue._stateValue)
									&& transition.stateChanges[managedValue._stateValue] == newValue
								) {
									return false;
								} else {
									return oldValue != newValue;
								}
							}
						);
					}

					bool hasNeededChanges(StateTuple nextState) {
						return updates.entries.every(
							(entry) {
								return nextState._values[entry.key] == entry.value;
							}
						);
					}
					bool isValid(StateTuple nextState) {
						bool _isValid = nextState._valueReferences.every(
							(managedValue) {
								bool newValue = nextState._values[managedValue._position];
								bool oldValue = state._values[managedValue._position];
								if (
									(
										managedValue._stateValue.stateValidationLogic == StateValidationLogic.canChangeToX
										|| (
											managedValue._stateValue.stateValidationLogic == null
											&& manager._stateValidationLogic == StateValidationLogic.canChangeToX
										)
									)
									&& newValue != oldValue
								) {
									return managedValue._canChange(state, nextState);
								}
								return true;
							}
						);
						return _isValid && manager._canBeXStates.every(
							(stateValue) => stateValue._isValid(state, nextState)
						);
					}
					int findDifference(StateTuple a, StateTuple b) {
						int diff = 0;
						for (int i = 0; i < managedValues.length; i++) {
							if (a._values[i] != b._values[i]) {
								diff++;
							}
						}
						return diff;
					}


					int? minDiff;
					List<StateTuple> minDiffStates = [];
					StateTuple? minDiffState;
					int maxInt = (Math.pow(2, managedValues.length) as int) - 1;
					for (int i = 0; i < maxInt; i++) {
						StateTuple? nextState = StateTuple._fromHash(managedValues, manager, i);
						if (
							nextState != null
							&& noMirroredChanges(nextState)
							&& hasNeededChanges(nextState)
							&& isValid(nextState)
						) {
							int diff = findDifference(state, nextState);
							if (minDiff == null) {
								minDiff = diff;
								minDiffState = nextState;
								minDiffStates = [nextState];
							} else if (diff < minDiff) {
								minDiff = diff;
								minDiffState = nextState;
								minDiffStates = [nextState];
							} else if (diff == minDiff) {
								minDiffStates.add(nextState);
							}
						}
					}
					if (minDiffStates.length > 1) {
						FSMTests.noStateTransitionsWithMultipleResults(transition, state, minDiffStates);
					}

					if (minDiffState == null && transition is MirroredTransition) {
						FSMTests.noFailedMirroredTransitions(transition, state);
						failedMirroredTransition = true;
					}

					if (minDiffState != null) {
						usedTransitions.add(transition);
						adjacencyList[state]![transition] = minDiffState;
						if (!adjacencyList.containsKey(minDiffState)) {
							optimisticFindNextState(minDiffState);
						}
					}
				}
			);
		}

		void conservativeFindNextState(StateTuple state) {
			if (adjacencyList.containsKey(state)) {
				// This state has already been visited.
				return;
			}
			adjacencyList[state] = HashMap();
			stateTransitions.forEach(
				(transition) {
					Map<int, bool> updates = {};
					transition.stateChanges.forEach(
						(key, value) {
							assert(managedValues[key] != null);
							updates[managedValues[key]!._position] = value;
						}
					);
					StateTuple nextState = StateTuple._fromState(state, updates);

					bool transitionIsValid = transition.stateChanges.entries.every(
						(element) {
							BooleanStateValue key = element.key;
							bool newValue = element.value;
							assert(managedValues[key] != null);
							ManagedValue managedValue = managedValues[key]!;
							if (
								(
									managedValue._stateValue.stateValidationLogic == StateValidationLogic.canChangeToX
									|| (
										managedValue._stateValue.stateValidationLogic == null
										&& manager._stateValidationLogic == StateValidationLogic.canChangeToX
									)
								)
								&& newValue != state._values[managedValue._position]
							) {
								return managedValue._canChange(state, nextState);
							}
							return true;
						}
					);
					transitionIsValid = transitionIsValid && manager._canBeXStates.every(
						(stateValue) => stateValue._isValid(state, nextState)
					);

					if (!transitionIsValid && transition is MirroredTransition) {
						FSMTests.noFailedMirroredTransitions(transition, state);
						failedMirroredTransition = true;
					}

					if (transitionIsValid) {
						usedTransitions.add(transition);
						adjacencyList[state]![transition] = nextState;
						if (!adjacencyList.containsKey(nextState)) {
							conservativeFindNextState(nextState);
						}
					}
				}
			);
		}

		if (manager._optimisticTransitions) {
			optimisticFindNextState(initialState);
		} else {
			conservativeFindNextState(initialState);
		}
		FSMTests.noUnusedTransitions(stateTransitions, usedTransitions);
		return failedMirroredTransition ? null : adjacencyList;
	}

	void changeState(StateTuple newState) {
		if (_manager._showDebugLogs) {
			Developer.log(newState.toString());
		}

		_currentState = newState;
		newState._valueReferences.forEach(
			(managedValue) {
				managedValue._value = newState._values[managedValue._position];
			}
		);
	}

}
