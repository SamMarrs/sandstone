
import 'dart:collection';

import 'package:tuple/tuple.dart';

import 'fsm.dart';
import 'unmanaged_classes/BooleanStateValue.dart';
import 'unmanaged_classes/StateAction.dart';
import 'unmanaged_classes/StateTransition.dart';
import 'Utils.dart';

class FSMTests {
	static bool isValidInitialState(
		StateTuple state,
		HashMap<StateTuple, dynamic> validStates
	) {
		bool result = validStates.containsKey(state);
		assert(result, 'Initial state is invalid.');
		return result;
	}

	static bool atLeastOneValidState(
		HashMap<StateTuple, dynamic> validStates
	) {
		bool result = validStates.isNotEmpty;
		assert(result, 'State graph is empty.');
		return result;
	}

	static bool noDuplicateTransitions(
		HashSet<StateTransition> transitions,
		StateTransition newTransition
	) {
		String duplicate = '';
		bool hasDuplicate = transitions.contains(newTransition);
		// This dup check won't work because there is no guarantee that the same state value changes can't be used as inputs for multiple states.
		// transitions.any(
		//	 (transition) {
		//		 if (mapEquals(transition.stateChanges, newTransition.stateChanges)) {
		//			 duplicate = transition.name;
		//			 return true;
		//		 }
		//		 return false;
		//	 }
		// );
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
		LinkedHashMap<BooleanStateValue, ManagedValue> managedValues,
	) {
		bool allRegistered = transition.stateChanges.entries.every((element) => managedValues.containsKey(element.key));
		assert(allRegistered, 'Transition called "${transition.name}" contains BooleanStateValues that have not been registered with the state manager.');
		return allRegistered;
	}

	static bool checkIfTransitionMaySucceed<K>(
		String transitionName,
		Map<K, bool> transition,
		HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates,
		int Function(K) keyToIntOffset
	) {
		bool maySucceed = false;
		int mask = Utils.maskFromMap<K>(transition, keyToIntOffset);
		int subHash = Utils.hashFromMap<K>(transition, keyToIntOffset);
		maySucceed = validStates.keys.any(
			(state) {
				return (state.hashCode & mask) == subHash;
			}
		);

		assert(maySucceed, 'Transition called "$transitionName" will never succeed.');

		return maySucceed;
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

	static bool checkIfActionMayRun(
		HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates,
		bool Function(StateTuple) test,
		String actionName
	) {
		bool shouldRun = validStates.keys.any(test);
		assert(shouldRun, 'State action with name "$actionName" will never run');
		return shouldRun;
	}

}