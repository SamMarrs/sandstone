import 'dart:collection';

import './typedefs.dart';
import 'package:tuple/tuple.dart';


// TODO: How do we enforce that BooleanStateValue.position is not null?
// TODO: How do we prevent BooleanStateValues from being passed to multiple state managers?

/// hashCode of Tuple must follow some rules.
///
/// IF TupleA.hashCode == TupleB.hashCode THEN TupleA == TupleB
///
/// IF TupleA == TupleB THEN TupleA.hashCode == TupleB.hashCode
///
/// These rules do not have to be followed when Two different classes that extend Tuple are compared to each other.
class StateTuple {
    late final List<bool> _values;
    late final HashSet<BooleanStateValue> _valueReferences;

    StateTuple._fromSet(
        this._valueReferences
    ) {
        _values = _valueReferences.map((ref) => ref.value).toList(growable: false);
    }

    StateTuple._fromList(
        List<bool> values,
        this._valueReferences
    ): _values = List.unmodifiable(values);

    /// width of tuple;
    int get width => _values.length;

    UnmodifiableListView<bool> get values => UnmodifiableListView(_values);

    BooleanStateValue? getStateValue(int position) {
        if (_values.length > position && position >= 0) {
            _valueReferences.elementAt(position);
        }
        return null;
    }

    bool? operator [](BooleanStateValue stateValue)  {
        if (_valueReferences.contains(stateValue)) {
            return _values[stateValue.position];
        }
        return null;
    }

    int? _hashCode;
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
                    _hashCode = _hashCode! | (1 << index);
                }
            }
        }
        return _hashCode!;
    }

    @override
    bool operator ==(Object other) => other is StateTuple && other.hashCode == hashCode && other.width == width;
}

typedef BatchFunction = void Function(BooleanStateValue stateValue, bool value);
class BooleanStateManager {
    final void Function() notifyListeners;
    final HashSet<BooleanStateValue> _managedValues;
    // UnmodifiableListView<BooleanStateValue> get managedValues => UnmodifiableListView<BooleanStateValue>(_managedValues);
    final Map<StateTuple, bool> _checkedStates = {};

    late StateTuple _currentState;
    StateTuple get currentState => _currentState;

    BooleanStateManager(
        this.notifyListeners,
        List<BooleanStateValue> managedValues,
        // TODO: void Function(BooleanTuple) stateActions,
    ): _managedValues = HashSet.of(managedValues) {
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
        _currentState = _buildStateRepresentation(null);
    }

    /// debug checking if initial state is valid
    bool _checkIfValidInitialState() {
        return _isAllowed(
            StateTuple._fromSet(_managedValues)
        );
    }

    StateTuple _buildStateRepresentation(Map<int, bool>? updates) {
        int i = 0;
        return StateTuple._fromList(
            _managedValues.map(
                (managedValue) {
                    late bool value;
                    if (updates != null && updates.containsKey(i)) value = updates[i]!;
                    value = managedValue.value;
                    i++;
                    return value;
                }
            ).toList(),
            _managedValues
        );
    }

    /// A state is only allowed if isAllowed is true for all managed values;
    bool _isAllowed(StateTuple state) {
        bool? isGood = _checkedStates[state];
        if (isGood == null) {
            isGood = _managedValues.every((stateVal) => stateVal._isAllowed(state));
            _checkedStates[state] = isGood;
        }
        return isGood;
    }

    void updateState(BooleanStateValue stateValue, bool newValue) {
        assert(_managedValues[stateValue.position] != null);
        assert(identical(_managedValues[stateValue.position], stateValue));
        if (stateValue.value == newValue || !identical(_managedValues[stateValue.position!], stateValue)) return;

        StateTuple newState = _buildStateRepresentation({stateValue.position: newValue});

        if (_isAllowed(newState)) {
            stateValue._value = newValue;
            notifyListeners();
        }
    }

    Tuple2<BatchFunction, VoidFunction> batchUpdateState() {
        Map<int?, bool> updates = {};

        BatchFunction bf = (BooleanStateValue stateValue, bool value) {
            assert(stateValue != null);
            assert(value != null);
            assert(_managedValues[stateValue.position!] != null);
            assert(identical(_managedValues[stateValue.position!], stateValue));
            if (value == null || !identical(_managedValues[stateValue.position!], stateValue)) return;
            updates[stateValue.position] = value;
        };
        void Function() close = () {
            StateTuple newState = _buildStateRepresentation(updates);
            if (_isAllowed(newState)) {
                updates.entries.forEach(
                    (entry) => _managedValues[entry.key!]._value = entry.value
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
    final bool Function(StateTuple currentState) _canBeTrue;
    final bool Function(StateTuple currentState) _canBeFalse;
    final bool initialValue;
    bool _value;
    bool get value => _value;
    // only accessible BooleanStateManager
    int? _position;
    int? get position => _position;
    BooleanStateManager? _manager;

    BooleanStateValue(
        bool value,
        bool Function(StateTuple currentState) canBeTrue,
        bool Function(StateTuple currentState) canBeFalse,
    ):  _value = value,
        initialValue = value,
        _canBeFalse = canBeFalse,
        _canBeTrue = canBeTrue;

    bool _isAllowed(StateTuple state)  {
        if (state[this] == null) {
            return false;
        }
        return state[this]! ? _canBeTrue(state) : _canBeFalse(state);
    }

    @override
    int get hashCode => identityHashCode(this);

    @override
    bool operator ==(Object other) => other is BooleanStateValue && identical(this, other);

}