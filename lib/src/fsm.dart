import 'dart:collection';
import 'dart:math' as Math;

import 'package:fsm/src/unmanned_classes/utils.dart';

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

    HashSet<Map<ManagedValue, bool> Function()> _stateTransitions = HashSet();

    // TODO: replace HashSet.containsKey with a method that returns true if _ManagedStateAction._shouldRun returns true
    final HashSet<StateTuple> _validStates = HashSet();
    final HashSet<StateTuple> _invalidStates = HashSet();

    late StateTuple _currentState;
    StateTuple get currentState => _currentState;

    BooleanStateManager({
        required void Function() notifyListeners,
        required List<BooleanStateValue> managedValues,
        List<StateAction>? stateActions,
        List<Map<ManagedValue, bool> Function()>? stateTransitions,
    }): _notifyListeners = notifyListeners {
        // Setup managed values with correct position information.
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
        // Check if the initial state is valid, as defined by the _canBeTrue and _canBeFalse functions of all managed values.
        assert(_checkIfValidInitialState());
        _currentState = StateTuple._fromList(_managedValues, this);

        // Create state transitions
        if (stateTransitions != null) {
            stateTransitions.forEach(
                (transition) {
                    _stateTransitions.add(transition);
                    // check if possible
                    assert(_checkIfTransitionMaySucceed(transition()));
                    // TODO: check if more than one end state is possible
                }
            );

        }

        // Create state actions.
        if (stateActions != null) {
            stateActions.forEach(
                (action) {
                    _ManagedStateAction? sa = _ManagedStateAction.create(positions: _booleanStateValueToIndex, stateAction: action);
                    if (sa != null) {
                        _managedStateActions.add(sa);
                        assert(_checkIfActionMayRun(sa), 'A state action with ${sa.actionName == null ? 'hash ${sa.hash}' : 'name ${sa.actionName}'} will never run.');
                    }
                }
            );
        }

    }

    /// Debug checking if initial state is valid
    bool _checkIfValidInitialState() {
        return _isAllowed(
            StateTuple._fromList(_managedValues, this)
        );
    }

    /// Debug checking.
    bool _checkIfTransitionMaySucceed(Map<ManagedValue, bool> transitionUpdate) {
        _findAllGoodState();
        bool maySucceed = false;
        _validStates.any(
            (state) {
                return (
                    state.hashCode
                    & Utils.maskFromMap<ManagedValue>(transitionUpdate, (key) => key._position)
                ) == Utils.hashFromMap<ManagedValue>(transitionUpdate, (key) => key._position);
            }
        );
        return maySucceed;
    }

    /// Debug checking if it is possible for a state action to run.
    bool _checkIfActionMayRun(_ManagedStateAction stateAction) {
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
                StateTuple? st = StateTuple._fromHash(_managedValues, this, i);
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
    /// A map of _ManagedValue indices to a value for that _ManagedValue.
    ///
    /// Used to check if this action should run for a given state.
    final Map<int, bool> registeredStateValues;

    // An action to run.
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
        _mask = Utils.maskFromMap<int>(registeredStateValues, (key) => key);
        return mask;
    }

    int? _hash;
    int get hash {
        if (_hash != null) return _hash!;
        _hash = Utils.hashFromMap<int>(registeredStateValues, (key) => key);
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

    static StateTuple? _fromHash(
        List<ManagedValue> valueReferences,
        BooleanStateManager manager,
        int stateHash
    ) {
        assert(stateHash > 0);
        if (stateHash < 0) return null;
        int maxInt = (Math.pow(2, valueReferences.length) as int) - 1;
        assert(stateHash <= maxInt);
        if (stateHash > maxInt) return null;

        Map<int, bool> updates = {};
        for (int i = 0; i < valueReferences.length; i++) {
            int value = stateHash & (1 << i);
            updates[i] = value > 0;
        }
        StateTuple st = StateTuple._fromList(valueReferences, manager, updates);
        st._hashCode = stateHash;

        return st;
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
