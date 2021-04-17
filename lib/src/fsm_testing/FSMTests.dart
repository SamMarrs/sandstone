
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../StateManager.dart';
import '../unmanaged_classes/BooleanStateValue.dart';
import '../unmanaged_classes/StateAction.dart';
import '../unmanaged_classes/StateTransition.dart';

class FSMTests {
	static bool noDuplicateTransitions(
		HashSet<StateTransition> transitions,
		StateTransition newTransition
	) {
		String duplicate = '';
		bool hasDuplicate = transitions.contains(newTransition);
		hasDuplicate = hasDuplicate || transitions.any(
			 (transition) {
				 if (mapEquals(transition.stateChanges, newTransition.stateChanges)) {
					 duplicate = transition.name;
					 return true;
				 }
				 return false;
			 }
		);
		assert(!hasDuplicate, 'Duplicate transitions found with names "$duplicate" and "${newTransition.name}".');
		return !hasDuplicate;
	}

	static bool stateTransitionValuesNotEmpty(
		StateTransition transition
	) {
		bool isNotEmpty = transition.stateChanges.isNotEmpty;
		assert(isNotEmpty, 'Transition called "${transition.name}" does not make any changes to the state.');
		return isNotEmpty;
	}

	static bool checkIfAllStateValuesRegistered(
		StateTransition transition,
		List<BooleanStateValue> unmanagedValues,
	) {
		HashSet<BooleanStateValue> registeredValues = HashSet()..addAll(unmanagedValues);
		bool allRegistered = transition.stateChanges.entries.every((element) => registeredValues.contains(element.key));
		assert(allRegistered, 'Transition called "${transition.name}" contains BooleanStateValues that have not been registered with the state manager.');
		return allRegistered;
	}

	static bool noUnusedTransitions(
		HashSet<StateTransition> declaredTransitions,
		HashSet<StateTransition> usedTransitions,
	) {
		return declaredTransitions.every(
			(transition) {
				bool used = usedTransitions.contains(transition);
				assert(used, 'Transition with name "${transition.name}" will never succeed.');
				return used;
			}
		);
	}

	static bool stateActionValuesNotEmpty(
		StateAction action
	) {
		bool isNotEmpty = action.registeredStateValues.isNotEmpty;
		assert(isNotEmpty, 'Action called "${action.name}" did not match a valid state.');
		return isNotEmpty;
	}

	static bool checkIfAllActionStateValuesRegistered(
		StateAction  stateAction,
		LinkedHashMap<BooleanStateValue, ManagedValue> managedValues,
	) {
		bool allRegistered = stateAction.registeredStateValues.entries.every((element) => managedValues.containsKey(element.key));
		assert(allRegistered, 'State action called "${stateAction.name}" contains BooleanStateValues that have not been registered with the state manager.');
		return allRegistered;
	}

	static bool checkIfAllActionsMayRun(
		List<StateAction> stateActions,
		HashSet<StateAction> actionsThatMayRun
	) {
		StateAction? wontRun;
		stateActions.every(
			(action) {
				bool exists = actionsThatMayRun.contains(action);
				if (!exists) {
					wontRun = action;
				}
				return exists;
			}
		);
		assert(
			wontRun == null,
			'State action with name "${wontRun!.name}" will never run'
		);
		return wontRun == null;
	}

	static void noStateTransitionsWithMultipleResults(
		StateTransition transition,
		StateTuple previousState,
		List<StateTuple> minDiffStates
	) {
		assert(false, 'Found ${minDiffStates.length} equally possible states to transition to for state ${previousState.hashCode.toString()} and transition "${transition.name}"');
	}

}