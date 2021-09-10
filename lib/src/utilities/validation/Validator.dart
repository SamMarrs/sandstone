part of '../../StateManager.dart';

/// Used to define a boolean as a function of the provided state, [StateTuple].
class Validator {
	final StateTuple state;
	final Op.Operator validator;

	Validator(
		this.state,
		this.validator
	);

	/// Evaluates this [Validator].
	///
	/// If `null` is returned, this [Validator] or the related [StateManager] has encountered a problem.
	/// Check [StateManager.debugEventStream] for potential causes.
	///
	/// A possible source of error is that a provided [StateValue] is not apart of the provided [StateTuple].
	bool? evaluate() {
		return _handler(validator);
	}

	bool? _handler(Op.Operator validator) {
		if (validator is Op.Value) {
			return _value(validator);
		} else if (validator is Op.And) {
			return _and(validator);
		} else if (validator is Op.Or) {
			return _or(validator);
		} else if (validator is Op.Not) {
			return _not(validator);
		} else if (validator is Op.Every) {
			return _every(validator);
		} else if (validator is Op.None) {
			return _none(validator);
		} else if (validator is Op.Any) {
			return _any(validator);
		} else if (validator is Op.Only) {
			return _only(validator);
		}
	}

	bool? _value(Op.Value validator) {
		StateTuple state = validator.altState?? this.state;
		return state.getValue(validator.value);
	}

	bool? _and(Op.And validator) {
		bool? result;
		for (int i = 0; i < validator.values.length; i++) {
			bool? handledValue = _handler(validator.values[i]);
			if (handledValue == null) {
				return null;
			}
			result = result == null ? handledValue : result && handledValue;
		}
		return result;
	}

	bool? _or(Op.Or validator) {
		bool? result;
		for (int i = 0; i < validator.values.length; i++) {
			bool? handledValue = _handler(validator.values[i]);
			// TODO: Should the result be short circuited when result first resolves to true?
			// If yes, also short circuit _every, _none, _only, and _any.
			// Doing so would prevent mistakes from being caught in stateManager.getFromState.
			if (handledValue == null) {
				return null;
			}
			result = result == null ? handledValue : result || handledValue;
		}
		return result;
	}

	bool? _not(Op.Not validator) {
		bool? result = _handler(validator.value);
		if (result != null) {
			return !result;
		}
		return null;
	}

	List<bool>? _valuesFromState() {
		List<StateValue>? stateValues = state._valueReferences.map((e) => e._stateValue).toList(growable: false);
		List<bool> values = [];
		for (int i = 0; i < stateValues.length; i++) {
			bool? value = state.getValue(stateValues[i]);
			if (value == null) {
				return null;
			}
			values.add(value);
		}

		return values;
	}

	List<bool>? _valuesFromValidator(UnmodifiableListView<Op.Operator> values) {
		List<bool> boolValues = [];
		for (int i = 0; i < values.length; i++) {
			bool? value = _handler(values[i]);
			if (value == null) {
				return null;
			}
			boolValues.add(value);
		}
		return boolValues;
	}

	bool? _every(Op.Every validator) {
		List<bool>? boolValues = validator.values == null ? _valuesFromState() : _valuesFromValidator(validator.values!);
		return boolValues == null ? null : boolValues.every((element) => element == validator.validValue);
	}

	bool? _none(Op.None validator) {
		List<bool>? boolValues = validator.values == null ? _valuesFromState() : _valuesFromValidator(validator.values!);
		return boolValues == null ? null : boolValues.every((element) => element != validator.invalidValue);
	}

	bool? _any(Op.Any validator) {
		List<bool>? boolValues = validator.values == null ? _valuesFromState() : _valuesFromValidator(validator.values!);
		return boolValues == null ? null : boolValues.any((element) => element == validator.validValue);
	}

	bool? _only(Op.Only validator) {
		List<bool> includedBoolValues = [];
		HashSet<StateValue> includedStateValues = HashSet();
		StateTuple state = validator.altState == null ? this.state : validator.altState!;

		for (int i = 0; i < validator.values.length; i++) {
			includedStateValues.add(validator.values[i]);
			bool? value = state.getValue(validator.values[i]);
			if (value == null) return null;
			includedBoolValues.add(value);
		}

		bool result = includedBoolValues.every((element) => element == validator.validValue);

		if (result) {
			for (int i = 0; i < state._values.length; i++) {
				StateValue sv = state._valueReferences[i]._stateValue;
				// Null case for state.getValue(sv) should never happen.
				if (!includedBoolValues.contains(sv) && state.getValue(sv) == validator.validValue) {
					return false;
				}
			}
		}

		return result;
	}

}