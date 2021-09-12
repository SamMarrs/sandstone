part of '../StateManager.dart';

class _StateGraph {
	final LinkedHashMap<StateValue, ManagedValue> _managedValues;

	// TODO: The underlying HashMap creates far more buckets than it needs to.
	// 512 for 224 elements.
	// This map never changes after initialization of the state manager, so a sparse map may be possible.
	final HashMap<StateTuple, HashMap<Transition, StateTuple>> _validStates;

	StateTuple _currentState;

	final StateManager _manager;

	_StateGraph._({
		required LinkedHashMap<StateValue, ManagedValue> managedValues,
		required HashMap<StateTuple, HashMap<Transition, StateTuple>> validStates,
		required StateTuple currentState,
		required StateManager manager
	}): _managedValues = managedValues,
		_validStates = validStates,
		_currentState = currentState,
		_manager = manager;

	static _StateGraph? create({
		required StateManager manager,
		required HashSet<Transition> stateTransitions,
		required LinkedHashMap<StateValue, ManagedValue> unmanagedToManagedValues
	}) {

		HashMap<StateTuple, HashMap<Transition, StateTuple>>? validStates = _StateGraph._buildAdjacencyList(
			managedValues: unmanagedToManagedValues,
			manager: manager,
			stateTransitions: stateTransitions
		);
		StateTuple currentState = InternalStateTuple.fromMap(unmanagedToManagedValues, manager);
		return validStates == null ? null : _StateGraph._(
			managedValues: unmanagedToManagedValues,
			validStates: validStates,
			currentState: currentState,
			manager: manager
		);
	}

	static HashMap<StateTuple, HashMap<Transition, StateTuple>>? _buildAdjacencyList({
		required LinkedHashMap<StateValue, ManagedValue> managedValues,
		required StateManager manager,
		required HashSet<Transition> stateTransitions,
	}) {
		StateTuple initialState = InternalStateTuple.fromMap(managedValues, manager);
		HashMap<StateTuple, HashMap<Transition, StateTuple>> adjacencyList = HashMap();
		HashSet<Transition> usedTransitions = HashSet();
		bool failedMirroredTransition = false;

		late final void Function(StateTuple, MirroredTransition) findMirroredState;
		late final void Function(StateTuple) optimisticFindNextState;
		late final void Function(StateTuple) conservativeFindNextState;

		StateTuple? findNextStateOptimistically(
			StateTuple currentState,
			Transition transition,
		) {
			InternalStateTuple cs = InternalStateTuple(currentState);
			Map<int, bool> requiredChanges = {};
			transition.stateChanges.forEach(
				(key, value) {
					assert(managedValues[key] != null);
					requiredChanges[InternalManagedValue(managedValues[key]!).position] = value;
				}
			);
			// [[int, bool]]
			// Find all values that are allowed to changes. This excluded changes to mirrored values.
			List<List<dynamic>> possibleChanges = [];
			manager._managedValues.forEach(
				(sv, mv) {
					InternalManagedValue imv = InternalManagedValue(mv);
					if (!(sv is MirroredStateValue) && !requiredChanges.containsKey(imv.position)) {
						possibleChanges.add([imv.position, cs.values[imv.position]]);
					}
				}
			);

			bool isValid(StateTuple nextState) {
				InternalStateTuple ns = InternalStateTuple(nextState);
				bool _isValid = ns.valueReferences.every(
					(managedValue) {
						InternalManagedValue imv = InternalManagedValue(managedValue);
						bool newValue = ns.values[imv.position];
						bool oldValue = cs.values[imv.position];
						if (
							imv.stateValue is BooleanStateValue
							&& (
								(imv.stateValue as BooleanStateValue).stateValidationLogic == StateValidationLogic.canChangeToX
								|| (
									(imv.stateValue as BooleanStateValue).stateValidationLogic == null
									&& manager._stateValidationLogic == StateValidationLogic.canChangeToX
								)
							)
							&& newValue != oldValue
						) {
							return imv.canChange(currentState, nextState);
						}
						return true;
					}
				);
				return _isValid && manager._canBeXStates.every(
					(stateValue) => InternalManagedValue(stateValue).isValid(currentState, nextState)
				);
			}
			int mapToInt(StateTuple baseState, Map<int, bool> changes) {
				InternalStateTuple bs = InternalStateTuple(baseState);
				LinkedHashMap<int, bool> newHash = LinkedHashMap();
				bs.valueReferences.forEach(
					(mv) {
						InternalManagedValue imv = InternalManagedValue(mv);
						if (changes.containsKey(imv.position)) {
							newHash[imv.position] = changes[imv.position]!;
						} else {
							newHash[imv.position] = bs.values[imv.position];
						}
					}
				);
				return Utils.hashFromMap<int>(newHash, (key) => key);
			}

			int minDiff = 0;
			List<StateTuple> minDiffStates = [];
			int maxNumChanges = possibleChanges.length;

			void makeChanges({
				required Map<int, bool> changes,
				required int diff,
				int? upperBound
			}) {
				// N
				// i = diff - 1; i < N; i++

				// i = diff - 1; i < N; i++;
				//  j = 0; j < i; j++;

				// i = diff - 1; i < N; i++;
				//  j = 1; j < i; j++;
				//   k = 0; k < j; k++;
				if (diff == 0) {
					changes.addAll(requiredChanges);
					int hash = mapToInt(currentState, changes);
					StateTuple? nextState = InternalStateTuple.fromHash(manager._managedValues, manager, hash);
					// If this fails, it probably is an implementation mistake.
					assert(nextState != null);
					if (nextState != null && isValid(nextState)) {
						minDiffStates.add(nextState);
					}
				} else {
					for (int i = diff - 1; i < (upperBound?? possibleChanges.length); i++) {
						Map<int, bool> newChange = Map.of(changes);
						newChange[possibleChanges[i][0]] = !possibleChanges[i][1];
						makeChanges(changes: newChange, diff: diff - 1, upperBound: i);
					}
				}
			}

			while (minDiff <= maxNumChanges && minDiffStates.isEmpty) {
				minDiffStates = [];
				makeChanges(changes: {}, diff: minDiff);
				if (minDiffStates.length > 1) {
					FSMTests.noStateTransitionsWithMultipleResults(transition, currentState, minDiffStates);
					return null;
				} else if (minDiffStates.length == 1) {
					return minDiffStates.first;
				}
				minDiff++;
			}

			return null;
		}

		// If traversing with a mirrored transition, use an optimistic algorithm to find the next state.
		findMirroredState = (StateTuple state, MirroredTransition transition) {
			StateTuple? nextState = findNextStateOptimistically(state, transition);
			if (nextState == null) {
				FSMTests.noFailedMirroredTransitions(transition, state);
				failedMirroredTransition = true;
			} else {
				usedTransitions.add(transition);
				adjacencyList[state]![transition] = nextState;
				if (!adjacencyList.containsKey(nextState)) {
					if (manager._optimisticTransitions) {
						optimisticFindNextState(nextState);
					} else {
						conservativeFindNextState(nextState);
					}
				}
			}
		};

		optimisticFindNextState = (StateTuple state) {
			if (adjacencyList.containsKey(state)) {
				// This state has already been visited.
				return;
			}
			adjacencyList[state] = HashMap();
			stateTransitions.forEach(
				(transition) {
					if (transition is MirroredTransition) {
						return findMirroredState(state, transition);
					}

					StateTuple? nextState = findNextStateOptimistically(state, transition);
					if (nextState != null) {
						usedTransitions.add(transition);
						adjacencyList[state]![transition] = nextState;
						if (!adjacencyList.containsKey(nextState)) {
							optimisticFindNextState(nextState);
						}
					}
				}
			);
		};

		conservativeFindNextState = (StateTuple state) {
			InternalStateTuple s = InternalStateTuple(state);
			if (adjacencyList.containsKey(state)) {
				// This state has already been visited.
				return;
			}
			adjacencyList[state] = HashMap();
			stateTransitions.forEach(
				(transition) {
					if (transition is MirroredTransition) {
						return findMirroredState(state, transition);
					}
					Map<int, bool> updates = {};
					transition.stateChanges.forEach(
						(key, value) {
							assert(managedValues[key] != null);
							updates[InternalManagedValue(managedValues[key]!).position] = value;
						}
					);
					StateTuple nextState = InternalStateTuple.fromState(state, updates);

					bool transitionIsValid = transition.stateChanges.entries.every(
						(element) {
							StateValue key = element.key;
							bool newValue = element.value;
							assert(managedValues[key] != null);
							ManagedValue managedValue = managedValues[key]!;
							InternalManagedValue imv = InternalManagedValue(managedValue);
							if (
								imv.stateValue is BooleanStateValue
								&& (
									(imv.stateValue as BooleanStateValue).stateValidationLogic == StateValidationLogic.canChangeToX
									|| (
										(imv.stateValue as BooleanStateValue).stateValidationLogic == null
										&& manager._stateValidationLogic == StateValidationLogic.canChangeToX
									)
								)
								&& newValue != s.values[imv.position]
							) {
								return imv.canChange(state, nextState);
							}
							return true;
						}
					);
					transitionIsValid = transitionIsValid && manager._canBeXStates.every(
						(stateValue) => InternalManagedValue(stateValue).isValid(state, nextState)
					);

					if (transitionIsValid) {
						usedTransitions.add(transition);
						adjacencyList[state]![transition] = nextState;
						if (!adjacencyList.containsKey(nextState)) {
							conservativeFindNextState(nextState);
						}
					}
				}
			);
		};

		if (manager._optimisticTransitions) {
			optimisticFindNextState(initialState);
		} else {
			conservativeFindNextState(initialState);
		}
		FSMTests.noUnusedTransitions(stateTransitions, usedTransitions);
		return failedMirroredTransition ? null : adjacencyList;
	}

	void changeState(StateTuple newState) {
		InternalStateTuple ns = InternalStateTuple(newState);
		_currentState = newState;
		ns.valueReferences.forEach(
			(managedValue) {
				InternalManagedValue imv = InternalManagedValue(managedValue);
				imv.value = ns.values[imv.position];
			}
		);
	}

}
