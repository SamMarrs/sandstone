import 'dart:collection';
import 'dart:math' as Math;

import './typedefs.dart';
import 'package:tuple/tuple.dart';

import 'unmanned_classes/BooleanStateValue.dart';
import 'unmanned_classes/StateAction.dart';


// TODO: How should data be passed to stateActions()

class BooleanStateManager {
    final void Function() _notifyListeners;
    final List<ManagedValue> _managedValues = [];
    List<ManagedValue> get managedValues => UnmodifiableListView(_managedValues);

    final Map<BooleanStateValue, int> _booleanStateValueToIndex = {};

    final List<_ManagedStateAction> _managedStateActions = [];

    HashSet<void Function()> _stateTransitions = HashSet();

    // TODO: replace HashSet.containsKey with a method that returns true if _ManagedStateAction._shouldRun returns true
    final HashSet<StateTuple> _validStates = HashSet();
    final HashSet<StateTuple> _invalidStates = HashSet();

    late StateTuple _currentState;
    StateTuple get currentState => _currentState;

    BooleanStateManager(
        void Function() notifyListeners,
        List<BooleanStateValue> managedValues,
        {
            List<StateAction>? stateActions,
            List<void Function()>? stateTransitions,
        }
    ): _notifyListeners = notifyListeners {
        for (int i = 0; i < managedValues.length; i++) {
            _booleanStateValueToIndex[managedValues[i]] = i;
            _managedValues.add(
                ManagedValue._(
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
                    _ManagedStateAction? sa = _ManagedStateAction.create(positions: _booleanStateValueToIndex, stateAction: action);
                    if (sa != null) {
                        _managedStateActions.add(sa);
                        assert(_checkIfMayRun(sa), 'A state action with ${sa.actionName == null ? 'hash ${sa.hash}' : 'name ${sa.actionName}'} will never run.');
                    }
                }
            );
        }

        if (stateTransitions != null) {
            stateTransitions.forEach((transition) => _stateTransitions.add(transition));
        }
    }

    /// debug checking if initial state is valid
    bool _checkIfValidInitialState() {
        return _isAllowed(
            StateTuple._fromList(_managedValues, this)
        );
    }

    /// Debug checking if it is possible for a state action to run.
    bool _checkIfMayRun(_ManagedStateAction stateAction) {
        _findAllGoodState();
        // TODO: This may be sped up to amortized constant time if the HashMap of _validStates is extended to work similar to _ManagedStateAction._shouldRun.
        return _validStates.any((state) => stateAction._shouldRun(state));
    }

    bool _foundAllGoodStates = false;
    /// Debug checking.
    void _findAllGoodState() {
        if (!_foundAllGoodStates) {
            int maxInt = (Math.pow(2, _managedValues.length) as int) - 1;
            for (int i = 0; i <= maxInt; i++) {
                StateTuple? st = StateTuple._fromInt(_managedValues, this, i);
                if (st != null) {
                    bool isAllowed = _isAllowed(st);
                    // If _isAllowed() didn't already populate _validStates and _inValidState, that would be done here.
                    // _validStates and _inValidStates might possibly be filled by code generation, but _isAllowed() is written to work without it.
                    if (isAllowed) {

                    } else {

                    }
                }
            }
        }
        _foundAllGoodStates = true;
    }

    /// A state is only allowed if isAllowed is true for all managed values;
    bool _isAllowed(StateTuple state) {
        bool isInValid = _validStates.contains(state);
        bool isInInvalid = _invalidStates.contains(state);
        if (isInValid) return true;
        if (isInInvalid) return false;
        bool isGood = _managedValues.every((stateVal) => stateVal._isAllowed(state));
        if (isGood) _validStates.add(state);
        if (!isGood) _invalidStates.add(state);
        return isGood;
    }

    void notify() {
        _notifyListeners();
        Future.delayed(
            Duration.zero,
            () {
                _managedStateActions.forEach(
                    (action) {
                        if (action._shouldRun(_currentState)) action.action();
                    }
                );
            }
        );
    }


    // TODO: updating state
    Map<int, bool>? _createUpdate(List<Map<ManagedValue, bool>> updates) {
        Map<int, bool> mergedUpdate = {};
        bool conflictFound = false;
        updates.forEach(
            (update) {

            }
        );

        if (conflictFound) {
            return null;
        }
        return mergedUpdate;
    }
}

class _ManagedStateAction {
    final String? actionName;
    // <position, value>
    final Map<int, bool> registeredStateValues;
    final void Function() action;


    _ManagedStateAction({
        required this.registeredStateValues,
        required this.action,
        this.actionName
    });

    static _ManagedStateAction? create({
        required Map<BooleanStateValue, int> positions,
        required StateAction stateAction
    }) {
        assert(!(positions.isEmpty || stateAction.registeredStateValues.isEmpty));
        if (positions.isEmpty || stateAction.registeredStateValues.isEmpty) return null;
        List<MapEntry<BooleanStateValue, bool>> entries = stateAction.registeredStateValues.entries.toList();
        Map<int, bool> rStateValues = {};
        for (int i = 0; i < entries.length; i++) {
            assert(positions.containsKey(entries[i].key));
            if (!positions.containsKey(entries[i].key)) return null;
            rStateValues[positions[entries[i].key]!] = entries[i].value;
        }
        return _ManagedStateAction(
            registeredStateValues: rStateValues,
            action: stateAction.action,
            actionName: stateAction.actionName
        );
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

class ManagedValue {
    final bool Function(StateTuple currentState) _canBeTrue;
    final bool Function(StateTuple currentState) _canBeFalse;
    final bool _initialValue;
    bool _value;
    bool get value => _value;
    // only accessible BooleanStateManager
    final int _position;
    final BooleanStateManager _manager;

    ManagedValue._({
        required BooleanStateValue managedValue,
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

}

/// hashCode of Tuple must follow some rules.
///
/// IF TupleA.hashCode == TupleB.hashCode THEN TupleA == TupleB
///
/// IF TupleA == TupleB THEN TupleA.hashCode == TupleB.hashCode
///
/// These rules do not have to be followed when Two different classes that extend Tuple are compared to each other.
class StateTuple {
    final List<bool> _values = [];
    final List<ManagedValue> _valueReferences;
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

    static StateTuple? _fromInt(
        List<ManagedValue> valueReferences,
        BooleanStateManager manager,
        int stateInt
    ) {
        assert(stateInt > 0);
        if (stateInt < 0) return null;
        int maxInt = (Math.pow(2, valueReferences.length) as int) - 1;
        assert(stateInt <= maxInt);
        if (stateInt > maxInt) return null;

        Map<int, bool> updates = {};
        for (int i = 0; i < valueReferences.length; i++) {
            int value = stateInt & (1 << i);
            updates[i] = value > 0;
        }
        return StateTuple._fromList(valueReferences, manager, updates);
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
