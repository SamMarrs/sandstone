import 'dart:collection';

import './typedefs.dart';
import 'package:tuple/tuple.dart';


// TODO: How do we enforce that BooleanStateValue.position is not null?
// TODO: How do we prevent BooleanStateValues from being passed to multiple state managers?
// TODO: How should data be passed to stateActions()
// TODO: Within stateActions, how order of actions be made irrelevant when choosing which action to run for the given state?

/// hashCode of Tuple must follow some rules.
///
/// IF TupleA.hashCode == TupleB.hashCode THEN TupleA == TupleB
///
/// IF TupleA == TupleB THEN TupleA.hashCode == TupleB.hashCode
///
/// These rules do not have to be followed when Two different classes that extend Tuple are compared to each other.
class StateTuple {
    final List<bool> _values = [];
    final List<BooleanStateValue> _valueReferences;
    final BooleanStateManager _manager;

    StateTuple._fromList(
        this._valueReferences,
        this._manager,
        [Map<int, bool>? updates]
    ) {
        _valueReferences.forEach(
            (ref) {
                _values.add(
                    updates != null && updates.containsKey(ref._position) ?
                        updates[ref._position]!
                        : ref.value
                );
            }
        );
    }

    /// width of tuple;
    int get width => _values.length;

    UnmodifiableListView<bool> get values => UnmodifiableListView(_values);

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
    bool operator ==(Object other) => other is StateTuple && other.width == width && other.hashCode == hashCode;


}

class StateAction {
    final Map<ManagedValue, bool> registeredStateValues;

    StateAction({
        required this.registeredStateValues
    });
}
class _StateAction {
    // <position, value>
    final Map<int, bool> registeredStateValues;

    _StateAction({
        required this.registeredStateValues
    });

    static _StateAction? create({
        required Map<ManagedValue, int> positions,
        required StateAction stateAction
    }) {
        if (positions.isEmpty || stateAction.registeredStateValues.isEmpty) return null;
        List<MapEntry<ManagedValue, bool>> entries = stateAction.registeredStateValues.entries.toList();
        Map<int, bool> rStateValues = {};
        for (int i = 0; i < entries.length; i++) {
            assert(positions.containsKey(entries[i].key));
            if (!positions.containsKey(entries[i].key)) return null;
            rStateValues[positions[entries[i].key]!] = entries[i].value;
        }
        return _StateAction(registeredStateValues: rStateValues);
    }

    int? _mask;
    int get mask {
        if (_mask != null) return _mask!;
        int mask = 0;
        List<int> masks = registeredStateValues.keys.map(
            (position) => 1 << position
        ).toList(growable: false);
        masks.forEach((m) => mask = mask | m);
        _mask = mask;
        return mask;
    }

    int? _hash;
    int get hash {
        if (_hash != null) return _hash!;
        List<int> hashes = [];
        registeredStateValues.forEach(
            (key, value) {
                if (value) {
                    hashes.add(1 << key);
                }
            }
        );
        int hash = hashes.length == 0 ? 0 : hashes.reduce((value, element) => value & element);
        _hash = hash;
        return hash;
    }

    bool _shouldRun(StateTuple st) {
        int masked = mask & st.hashCode;
        return masked == hash;
    }
}

class BooleanStateManager {
    final void Function() _notifyListeners;
    final List<BooleanStateValue> _managedValues = [];
    List<BooleanStateValue> get managedValue => UnmodifiableListView(_managedValues);

    final List<_StateAction> _stateActions = [];

    final Map<StateTuple, bool> _checkedStates = {};

    late StateTuple _currentState;
    StateTuple get currentState => _currentState;

    BooleanStateManager(
        void Function() notifyListeners,
        List<ManagedValue> managedValues,
        [List<StateAction>? stateActions]
    ): _notifyListeners = notifyListeners {
        Map<ManagedValue, int> positions = {};
        for (int i = 0; i < managedValues.length; i++) {
            positions[managedValues[i]] = i;
            _managedValues.add(
                BooleanStateValue._(
                    managedValue: managedValues[i],
                    position: i,
                    manager: this
                )
            );
        }
        assert(_checkIfValidInitialState());
        _currentState = StateTuple._fromList(_managedValues, this);

        if (stateActions != null) {
            stateActions.forEach(
                (action) {
                    _StateAction? sa = _StateAction.create(positions: positions, stateAction: action);
                    if (sa != null) {
                        _stateActions.add(sa);
                    }
                }
            );
        }
    }

    /// debug checking if initial state is valid
    bool _checkIfValidInitialState() {
        return _isAllowed(
            StateTuple._fromList(_managedValues, this)
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

    void notify() {
        _notifyListeners();
        // TODO: run state actions for current state
    }

    // TODO: updating state
}

class ManagedValue {
    final bool Function(StateTuple currentState) canBeTrue;
    final bool Function(StateTuple currentState) canBeFalse;
    final bool value;

    ManagedValue({
        required this.canBeFalse,
        required this.canBeTrue,
        required this.value
    });
}

class BooleanStateValue {
    final bool Function(StateTuple currentState) _canBeTrue;
    final bool Function(StateTuple currentState) _canBeFalse;
    final bool _initialValue;
    bool _value;
    bool get value => _value;
    // only accessible BooleanStateManager
    final int _position;
    final BooleanStateManager _manager;

    BooleanStateValue._({
        required ManagedValue managedValue,
        required int position,
        required BooleanStateManager manager
    }): _position = position,
        _manager = manager,
        _value = managedValue.value,
        _initialValue = managedValue.value,
        _canBeFalse = managedValue.canBeFalse,
        _canBeTrue = managedValue.canBeTrue;

    bool _isAllowed(StateTuple state)  {
        return state._values[_position] ? _canBeTrue(state) : _canBeFalse(state);
    }

    bool? getFromState(StateTuple stateTuple) {
        assert(stateTuple._manager == _manager, 'StateTuple must be from the same state manager.');
        if (stateTuple._manager != _manager) return null;
        return stateTuple._values[_position];
    }

    // @override
    // int get hashCode => identityHashCode(this);

    // @override
    // bool operator ==(Object other) => other is BooleanStateValue && identical(this, other);

}