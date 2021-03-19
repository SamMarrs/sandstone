import 'dart:collection';
import 'dart:math' as Math;

import 'package:fsm/src/unmanned_classes/utils.dart';
import 'package:tuple/tuple.dart';

import './typedefs.dart';

import 'unmanned_classes/BooleanStateValue.dart';
import 'unmanned_classes/StateAction.dart';


// TODO: How should data be passed to actions within stateActions

class BooleanStateManager {
    final void Function() _notifyListeners;

    late final _StateGraph _stateGraph;

    late final List<_ManagedStateAction> _managedStateActions;

    late HashSet<StateTransitionFunction> _stateTransitions;

    List<ManagedValue> get managedValues => _stateGraph._managedValues;

    BooleanStateManager._({
        required void Function() notifyListener,
    }): _notifyListeners = notifyListener;

    // Factory constructors can no longer return null values with null safety.
    static BooleanStateManager? create({
        required void Function() notifyListeners,
        required List<BooleanStateValue> managedValues,
        required List<StateTransitionFunction> stateTransitions,
        List<StateAction>? stateActions,
    }) {
        BooleanStateManager bsm = BooleanStateManager._(notifyListener: notifyListeners);
        Map<BooleanStateValue, int> _booleanStateValueToIndex = {};
        _StateGraph? stateGraph = _StateGraph.create(
            manager: bsm,
            stateValues: managedValues,
            valueToIndex: _booleanStateValueToIndex
        );
        if (stateGraph == null) return null;
        bsm._stateGraph = stateGraph;

        // Create state transitions
        HashSet<StateTransitionFunction> stateTransitions = HashSet();
        bool stateTransitionError = false;
        int i = 0;
        stateTransitions.forEach(
            (transition) {
                stateTransitions.add(transition);
                // check if possible
                bool error = stateGraph.checkIfTransitionMaySucceed(transition());
                stateTransitionError = stateTransitionError || error;
                assert(error, 'State transition at index $i will never succeed.');
                i++;
            }
        );
        if (stateTransitionError) return null;
        bsm._stateTransitions = stateTransitions;

        // Create state actions.
        // TODO: Check for transition conflicts as a result of multiple actions running.
        List<_ManagedStateAction> managedStateActions = [];
        if (stateActions != null) {
            stateActions.forEach(
                (action) {
                    _ManagedStateAction? sa = _ManagedStateAction.create(
                        positions: _booleanStateValueToIndex,
                        stateAction: action
                    );
                    if (sa != null) {
                        managedStateActions.add(sa);
                        assert(_checkIfValidTransitionsInAction(action: sa, stateTransitions: stateTransitions));
                        assert(stateGraph.checkIfActionMayRun(sa), 'A state action with ${sa.actionName == null ? 'hash ${sa.hash}' : 'name ${sa.actionName}'} will never run.');
                    }
                }
            );
        }
        bsm._managedStateActions = managedStateActions;
        assert(
            _checkForActionTransitionConflicts(
                stateTransitions: stateTransitions,
                stateActions: managedStateActions,
                stateGraph: stateGraph
            )
        );
    }

    static bool _checkIfValidTransitionsInAction({
        required _ManagedStateAction action,
        required HashSet<StateTransitionFunction> stateTransitions
    }) => action.possibleTransitions.every((element) => stateTransitions.contains(element));

    static bool _checkForActionTransitionConflicts({
        required List<_ManagedStateAction> stateActions,
        required HashSet<StateTransitionFunction> stateTransitions,
        required _StateGraph stateGraph
    }) {
        stateGraph._validStates.keys.forEach(
            (state) {
                int potentialConflicts = 0;
                List<_ManagedStateAction> possibleActions = [];
                stateActions.forEach(
                    (action) {
                        if (action._shouldRun(state)) {
                            possibleActions.add(action);
                        }
                    }
                );

                // TODO:

                if (potentialConflicts > 0) {
                    print('There are $potentialConflicts potential transition conflict due to actions running on state ${state.hashCode}');
                }

            }
        );


        // I only want this to run in debug mode.
        // Since this only produces warnings, not errors, the assertion needs to succeed.
        return true;
    }

    void _notify() {
        _notifyListeners();
        Future.delayed(
            Duration.zero,
            () {
                List<StateTransitionFunction> transitions = [];
                _managedStateActions.forEach(
                    (action) {
                        if (action._shouldRun(_stateGraph._currentState)) {
                            StateTransitionFunction? transition = action.action();
                            if (transition != null) {
                                assert(_stateTransitions.contains(transition) && action.possibleTransitions.contains(transition));
                                transitions.add(transition);
                            }
                        }
                    }
                );

                bool doesOverride(Map<ManagedValue, bool> a, Map<ManagedValue, bool> b) {
                    return a.entries.any((element) => b.containsKey(element.key) && b[element.key] != element.value);
                }

                List<Map<ManagedValue, bool>> updates = [];
                transitions.forEach(
                    (transition) => updates.add(transition())
                );
                Map<ManagedValue, bool> update = {};
                updates.forEach(
                    (transitionUpdate) {
                        assert(!doesOverride(update, transitionUpdate), 'Conflicting transitions as a result of state actions.');
                        update.addAll(transitionUpdate);
                    }
                );
                _applyStateUpdate(update);
            }
        );
    }

    void updateState(StateTransitionFunction transitionFunction) {
        assert(_stateTransitions.contains(transitionFunction), 'Unknown transition function.');
        if (_stateTransitions.contains(transitionFunction)) {
            _applyStateUpdate(transitionFunction());
        }
    }

    void _applyStateUpdate(Map<ManagedValue, bool> update) {
        List<Tuple2<StateTuple, int>> possibleStates = [];
        int mask = Utils.maskFromMap<ManagedValue>(update, (key) => key._position);
        int subHash = Utils.hashFromMap<ManagedValue>(update, (key) => key._position);

        _stateGraph.getCurrentAdjacent().forEach(
            (stateDiff) {
                StateTuple state = stateDiff.item1;
                if ((state.hashCode & mask) == subHash ) {
                    possibleStates.add(stateDiff);
                }
            }
        );

        // TODO: If _currentState is the correct state to transition to, should we re-run the actions?
        assert(possibleStates.isNotEmpty, 'Invalid state transition or the current state is the only state that the transition function can transition to.');
        if (possibleStates.isEmpty) return;
        if (possibleStates.length == 1) {
            _stateGraph._currentState = possibleStates.first.item1;
            _notify();
        } else {
            int minDiff = possibleStates[0].item2;
            List<StateTuple> minChangeStates = [
                possibleStates[0].item1
            ];
            for (int i = 1; i < possibleStates.length; i++) {
                int diff = possibleStates[i].item2;
                if (diff == minDiff) minChangeStates.add(possibleStates[i].item1);
                if (diff > minDiff) break;
            }
            assert(
                minChangeStates.length == 1,
                'Multiple valid states with the same minimum difference to the current state. Try narrowing the conditions in the state transition function.'
            );

            _stateGraph._currentState = minChangeStates.first;
            _notify();
        }
    }

}

class _StateGraph {
    final List<ManagedValue> _managedValues;

    final HashMap<StateTuple, List<Tuple2<StateTuple, int>>> _validStates;
    final HashSet<StateTuple> _invalidStates;

    StateTuple _currentState;

    _StateGraph._({
        required List<ManagedValue> managedValues,
        required HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates,
        required HashSet<StateTuple> invalidStates,
        required StateTuple currentState,
    }): _managedValues = managedValues,
        _validStates = validStates,
        _invalidStates = invalidStates,
        _currentState = currentState;

    static _StateGraph? create({
        required BooleanStateManager manager,
        required List<BooleanStateValue> stateValues,
        required Map<BooleanStateValue, int> valueToIndex
    }) {
        List<ManagedValue> managedValues = [];
        // Setup managed values with correct position information.
        for (int i = 0; i < stateValues.length; i++) {
            valueToIndex[stateValues[i]] = i;
            managedValues.add(
                ManagedValue._(
                    managedValue: stateValues[i],
                    position: i,
                    manager: manager
                )
            );
        }

        Tuple2<HashMap<StateTuple, List<Tuple2<StateTuple, int>>>, HashSet<StateTuple>> validAndInvalidStates = _StateGraph._findAllGoodState(
            managedValues: managedValues,
            manager: manager
        );
        StateTuple currentState = StateTuple._fromList(managedValues, manager);
        assert(validAndInvalidStates.item1.containsKey(currentState));
        if (!validAndInvalidStates.item1.containsKey(currentState)) {
            return null;
        }

        _StateGraph._buildAdjacencyList(
            managedValues: managedValues,
            validStates: validAndInvalidStates.item1
        );
        return _StateGraph._(
            managedValues: managedValues,
            validStates: validAndInvalidStates.item1,
            invalidStates: validAndInvalidStates.item2,
            currentState: currentState,
        );
    }

    static Tuple2<HashMap<StateTuple, List<Tuple2<StateTuple, int>>>, HashSet<StateTuple>> _findAllGoodState({
        required List<ManagedValue> managedValues,
        required BooleanStateManager manager
    }) {
        HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates = HashMap();
        HashSet<StateTuple> invalidStates = HashSet();
        int maxInt = (Math.pow(2, managedValues.length) as int) - 1;
        for (int i = 0; i <= maxInt; i++) {
            StateTuple? st = StateTuple._fromHash(managedValues, manager, i);
            if (st != null) {
                if (
                    _isAllowed(
                        state: st,
                        validStates: validStates,
                        invalidStates: invalidStates,
                        managedValues: managedValues
                    )
                ) {
                    validStates.putIfAbsent(st, () => []);
                } else {
                    invalidStates.add(st);
                }
            }
        }
        return Tuple2(validStates, invalidStates);
    }

    /// A state is only allowed if isAllowed is true for all managed values;
    static bool _isAllowed({
        required StateTuple state,
        required HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates,
        required HashSet<StateTuple> invalidStates,
        required List<ManagedValue> managedValues,
    }) {
        bool isInValid = validStates.containsKey(state);
        bool isInInvalid = invalidStates.contains(state);
        if (isInValid) return true;
        if (isInInvalid) return false;
        return managedValues.every((stateVal) => stateVal._isAllowed(state));
    }

    static void _buildAdjacencyList({
        required List<ManagedValue> managedValues,
        required HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates
    }) {
        int findDifference(StateTuple a, StateTuple b) {
            int diff = 0;
            for (int i = 0; i < managedValues.length; i++) {
                if (a._values[i] != b._values[i]) {
                    diff++;
                }
            }
            return diff;
        }

        HashMap<StateTuple, HashSet<StateTuple>> checked = HashMap();
        validStates.entries.forEach(
            (entry) {
                StateTuple primaryState = entry.key;
                List<Tuple2<StateTuple, int>> primaryStateList = entry.value;
                validStates.entries.forEach(
                    (_entry) {
                        StateTuple adjacentState = _entry.key;
                        List<Tuple2<StateTuple, int>> adjacentStateList = _entry.value;
                        // Check if the has already been done.
                        if (adjacentState == primaryState || (checked.containsKey(primaryState) && checked[primaryState]!.contains(adjacentState))) {
                            return;
                        }
                        // Make note that this state combo has been done, so it doesn't occur again
                        if (!checked.containsKey(primaryState)) {
                            checked[primaryState] = HashSet();
                            checked[primaryState]!.add(adjacentState);
                        }
                        if (!checked.containsKey(adjacentState)) {
                            checked[adjacentState] = HashSet();
                            checked[adjacentState]!.add(primaryState);
                        }

                        int diff = findDifference(primaryState, adjacentState);
                        primaryStateList.add(Tuple2(adjacentState, diff));
                        adjacentStateList.add(Tuple2(primaryState, diff));
                    }
                );
            }
        );
        validStates.entries.forEach(
            (entry) {
                entry.value.sort(
                    (a, b) => a.item2 - b.item2
                );
            }
        );
    }

    /// Debug checking.
    bool checkIfTransitionMaySucceed(Map<ManagedValue, bool> transitionUpdate) {
        bool maySucceed = false;
        int mask = Utils.maskFromMap<ManagedValue>(transitionUpdate, (key) => key._position);
        int subHash = Utils.hashFromMap<ManagedValue>(transitionUpdate, (key) => key._position);
        _validStates.keys.any(
            (state) => (state.hashCode & mask) == subHash
        );
        return maySucceed;
    }

   /// Debug checking if it is possible for a state action to run.
    bool checkIfActionMayRun(_ManagedStateAction stateAction) {
        return _validStates.keys.any((state) => stateAction._shouldRun(state));
    }

    List<Tuple2<StateTuple, int>> getCurrentAdjacent() {

        return _validStates[_currentState]!;
    }
}

class _ManagedStateAction {
    final String? actionName;

    /// A map of _ManagedValue indices to a value for that _ManagedValue.
    ///
    /// Used to check if this action should run for a given state.
    final Map<int, bool> registeredStateValues;

    final StateTransitionFunction? Function() action;

    final List<StateTransitionFunction> possibleTransitions;

    _ManagedStateAction({
        required this.registeredStateValues,
        required this.action,
        this.actionName,
        this.possibleTransitions = const []
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
            actionName: stateAction.actionName,
            possibleTransitions: stateAction.possibleTransitions
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
