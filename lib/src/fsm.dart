import 'dart:collection';

import './typedefs.dart';
import 'package:tuple/tuple.dart';

/// hashCode of Tuple must follow some rules.
///
/// IF TupleA.hashCode == TupleB.hashCode THEN TupleA == TupleB
///
/// IF TupleA == TupleB THEN TupleA.hashCode == TupleB.hashCode
///
/// These rules do not have to be followed when Two different classes that extend Tuple are compared to each other.
class BooleanTuple {
    final List<bool> _values;

    BooleanTuple._fromList(
        List<bool> values,
    ): _values = List.unmodifiable(values);


    /// width of tuple;
    int get width => _values.length;

    UnmodifiableListView<bool> get values => UnmodifiableListView(_values);

    bool getStateValue(int index) {
        assert(index < width);
        if (index >= width) return null;
        return _values[index];
    }

    bool operator [](int i) => _values[i];

    int _hashCode;
    /// (true) => 1, (false) => 0
    ///
    /// (true, false) => 10,
    ///
    /// (false, true, true, false, true) => 01101
    @override
    int get hashCode {
        if (_hashCode == null) {
            _hashCode = 0;
            for (int index = _values.length; index > 0; index--) {
                if (_values[index - 1]) {
                    _hashCode = _hashCode | (1 << index);
                }
            }
        }
        return _hashCode;
    }

    @override
    bool operator ==(Object other) => other is BooleanTuple && other.hashCode == hashCode && other.width == width;
}

typedef BatchFunction = void Function(BooleanStateValue stateValue, bool value);
class BooleanStateManager {
    final void Function() notifyListeners;
    final List<BooleanStateValue> _managedValues;
    // UnmodifiableListView<BooleanStateValue> get managedValues => UnmodifiableListView<BooleanStateValue>(_managedValues);
    final Map<BooleanTuple, bool> _checkedStates = {};

    BooleanStateManager(
        this.notifyListeners,
        List<BooleanStateValue> managedValues
    ): _managedValues = managedValues {
        assert(_managedValues.isNotEmpty);
        int i = 0;
        _managedValues.forEach(
            (stateVal) {
                assert(stateVal._manager == null);
                stateVal._manager = this;
                stateVal._position = i;
                i++;
            }
        );
        assert(_checkIfValidInitialState());
    }

    /// debug checking if initial state is valid
    bool _checkIfValidInitialState() {
        return _isAllowed(
            BooleanTuple._fromList(
                List<bool>.generate(
                    _managedValues.length,
                    (index) {
                        return _managedValues[index].value;
                    }
                )
            )
        );
    }

    BooleanTuple _buildStateRepresentation(Map<int, bool> updates) {
        return BooleanTuple._fromList(
            List<bool>.generate(
                _managedValues.length,
                (index) {
                    if (updates.containsKey(index)) return updates[index];
                    return _managedValues[index].value;
                }
            )
        );
    }

    /// A state is only allowed if isAllowed is true for all managed values;
    bool _isAllowed(BooleanTuple state) {
        bool isGood = _checkedStates[state];
        if (isGood == null) {
            isGood = _managedValues.every((stateVal) => stateVal._isAllowed(state));
            _checkedStates[state] = isGood;
        }
        return isGood;
    }

    void updateState(BooleanStateValue stateValue, bool newValue) {
        assert(newValue != null);
        assert(_managedValues[stateValue.position] != null);
        assert(identical(_managedValues[stateValue.position], stateValue));
        if (newValue == null || stateValue.value == newValue || !identical(_managedValues[stateValue.position], stateValue)) return;

        BooleanTuple newState = _buildStateRepresentation({stateValue.position: newValue});

        if (_isAllowed(newState)) {
            stateValue._value = newValue;
            notifyListeners();
        }
    }

    Tuple2<BatchFunction, VoidFunction> batchUpdateState() {
        Map<int, bool> updates = {};

        BatchFunction bf = (BooleanStateValue stateValue, bool value) {
            assert(stateValue != null);
            assert(value != null);
            assert(_managedValues[stateValue.position] != null);
            assert(identical(_managedValues[stateValue.position], stateValue));
            if (value == null || !identical(_managedValues[stateValue.position], stateValue)) return;
            updates[stateValue.position] = value;
        };
        void Function() close = () {
            BooleanTuple newState = _buildStateRepresentation(updates);
            if (_isAllowed(newState)) {
                updates.entries.forEach(
                    (entry) => _managedValues[entry.key]._value = entry.value
                );
                notifyListeners();
            }
        };
        return Tuple2(bf, close);
    }

    void forceUpdateState(BooleanStateValue stateValue, bool newValue) {
        if (newValue == null || stateValue.value == newValue) return;

        // TODO: search for a valid state where stateValue.value == newValue
    }

    Tuple2<BatchFunction, VoidFunction>  forceBatchUpdateState() {
        Map<int, bool> updates = {};
        // TODO:
    }

}

class BooleanStateValue {
    final bool Function(BooleanTuple newState) _isAllowed;
    final bool Function(BooleanTuple currentState) _canBeTrue;
    final bool Function(BooleanTuple currentState) _canBeFalse;
    final bool initialValue;
    bool _value;
    bool get value => _value;
    // only accessible BooleanStateManager
    int _position;
    int get position => _position;
    BooleanStateManager _manager;

    BooleanStateValue.unManaged(
        bool value,
    ):  _value = value,
        initialValue = value,
        _isAllowed = ((_) => true),
        _canBeFalse = ((_) => true),
        _canBeTrue = ((_) => true);

    BooleanStateValue(
        bool value,
        bool Function(BooleanTuple newState) isAllowed,
        bool Function(BooleanTuple currentState) canBeTrue,
        bool Function(BooleanTuple currentState) canBeFalse,
    ):  _value = value,
        _isAllowed = isAllowed,
        initialValue = value,
        _canBeFalse = canBeFalse,
        _canBeTrue = canBeTrue;

    bool fromState(BooleanTuple state) {
        assert(_position != null);
        return state[_position];
    }

    // TODO: this isn't needed for Selector. The selector widget will compare the getters, which return the boolean value.
    // Needed for Selector from the Provider package.
    @override
    int get hashCode => value ? 1 : 0;
    @override
    bool operator ==(Object other) => other is BooleanStateValue && other.hashCode == hashCode;

}