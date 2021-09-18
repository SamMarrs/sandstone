

import 'dart:collection';

import 'package:sandstone/src/StateManager.dart';
import 'package:sandstone/src/fsm_testing/FSMTests.dart';
import 'package:sandstone/src/managed_classes/ManagedValue.dart';
import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateAction.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';
import 'package:sandstone/src/utilities/Utils.dart';

class ManagedStateAction {
	final String name;

	/// A map of _ManagedValue indices to a value for that _ManagedValue.
	///
	/// Used to check if this action should run for a given state.
	final Map<int, bool> registeredStateValues;

	final void Function(StateManager manager) action;


	ManagedStateAction({
		required this.registeredStateValues,
		required this.action,
		required this.name,
	});

	static ManagedStateAction? create({
		required LinkedHashMap<StateValue, ManagedValue> managedValues,
		required StateAction stateAction
	}) {
		assert(managedValues.isNotEmpty); // controlled by state manager
		bool isNotEmpty = FSMTests.stateActionValuesNotEmpty(stateAction);
		if (managedValues.isEmpty || !isNotEmpty) return null;
		List<MapEntry<StateValue, bool>> entries = stateAction.registeredStateValues.entries.toList();
		Map<int, bool> rStateValues = {};
		for (int i = 0; i < entries.length; i++) {
			assert(managedValues.containsKey(entries[i].key));
			if (!managedValues.containsKey(entries[i].key)) return null;
			rStateValues[InternalManagedValue(managedValues[entries[i].key]!).position] = entries[i].value;
		}
		return ManagedStateAction(
			registeredStateValues: rStateValues,
			action: stateAction.action,
			name: stateAction.name,
		);
	}

	int? _mask;
	int get mask {
		if (_mask == null) {
			_mask = Utils.maskFromMap<int>(registeredStateValues, (key) => key);
		}
		return _mask!;
	}

	int? _hash;
	int get hash {
		if (_hash == null) {
			_hash = Utils.hashFromMap<int>(registeredStateValues, (key) => key);
		}
		return _hash!;
	}

	bool shouldRun(StateTuple st) {
		int masked = mask & st.hashCode;
		return masked == hash;
	}
}
