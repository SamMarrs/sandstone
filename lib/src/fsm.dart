import 'dart:collection';
import 'dart:math' as Math;

import './unmanned_classes/utils.dart';
import 'package:tuple/tuple.dart';

import 'unmanned_classes/BooleanStateValue.dart';
import 'unmanned_classes/StateAction.dart';


// TODO: How should data be passed to actions within stateActions

class StateManager {
    final void Function() _notifyListeners;

    late final _StateGraph _stateGraph;

    late final List<_ManagedStateAction> _managedStateActions;

    late HashSet<Map<BooleanStateValue, bool>> _stateTransitions;

    List<ManagedValue> get managedValues => _stateGraph._managedValues;

    Map<BooleanStateValue, int> _booleanStateValueToIndex = {};

    StateManager._({
        required void Function() notifyListener,
    }): _notifyListeners = notifyListener;

    // TODO: Possibly make async so the stateTransitions can be async
    // Factory constructors can no longer return null values with null safety.
    static StateManager? create({
        required void Function() notifyListeners,
        required List<BooleanStateValue> managedValues,
        required List<Map<BooleanStateValue, bool>> stateTransitions,
        List<StateAction>? stateActions,
    }) {
        StateManager bsm = StateManager._(notifyListener: notifyListeners);

        _StateGraph? stateGraph = _StateGraph.create(
            manager: bsm,
            stateValues: managedValues,
            valueToIndex: bsm._booleanStateValueToIndex
        );
        if (stateGraph == null) return null;
        bsm._stateGraph = stateGraph;

        // Create state transitions
        HashSet<Map<BooleanStateValue, bool>> _stateTransitions = HashSet();
        bool stateTransitionError = false;
        int i = 0;
        stateTransitions.forEach(
            (transition) {
                _stateTransitions.add(transition);
                // check if possible
                assert(bsm._checkIfRegisteredTransition(transition), 'State transition at index $i contains unregistered state values');
                assert(stateGraph.checkIfTransitionMaySucceed(bsm._transitionConversion(transition)), 'State transition at index $i will never succeed.');
                bool error = !bsm._checkIfRegisteredTransition(transition) || !stateGraph.checkIfTransitionMaySucceed(bsm._transitionConversion(transition));
                stateTransitionError = stateTransitionError || error;
                i++;
            }
        );
        if (stateTransitionError) return null;
        bsm._stateTransitions = _stateTransitions;

        // Create state actions.
        // TODO: Check for transition conflicts as a result of multiple actions running.
        List<_ManagedStateAction> managedStateActions = [];
		bool stateActionError = false;
        if (stateActions != null) {
            stateActions.forEach(
                (action) {
                    _ManagedStateAction? sa = _ManagedStateAction.create(
                        positions: bsm._booleanStateValueToIndex,
                        stateAction: action
                    );
                    if (sa != null) {
                        managedStateActions.add(sa);
						bool validTransition = _checkIfValidTransitionsInAction(action: sa, stateTransitions: _stateTransitions);
                        assert(validTransition);
						bool willRun = stateGraph.checkIfActionMayRun(sa);
                        assert(willRun, 'A state action with ${sa.actionName == null ? 'hash ${sa.hash}' : 'name ${sa.actionName}'} will never run.');
						stateActionError = stateActionError || !willRun || !validTransition;
                    }
                }
            );
        }
		if (stateActionError) return null;
        bsm._managedStateActions = managedStateActions;
        assert(
            _checkForActionTransitionConflicts(
                stateTransitions: _stateTransitions,
                stateActions: managedStateActions,
                stateGraph: stateGraph
            )
        );
		return bsm;
    }

    bool _checkIfRegisteredTransition(Map<BooleanStateValue, bool> transition) {
        return transition.entries.every((element) => _booleanStateValueToIndex.containsKey(element.key));
    }

    Map<ManagedValue, bool> _transitionConversion(Map<BooleanStateValue, bool> transition) {
        Map<ManagedValue, bool> map = {};
        transition.forEach(
            (key, value) {
                map[managedValues[_booleanStateValueToIndex[key]!]] = value;
            }
        );
        return map;
    }

    static bool _checkIfValidTransitionsInAction({
        required _ManagedStateAction action,
        required HashSet<Map<BooleanStateValue, bool>> stateTransitions
    }) => action.possibleTransitions.every((element) => stateTransitions.contains(element));

    static bool _checkForActionTransitionConflicts({
        required List<_ManagedStateAction> stateActions,
        required HashSet<Map<BooleanStateValue, bool>> stateTransitions,
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

    bool? getFromState(StateTuple stateTuple, BooleanStateValue value) {
        assert(stateTuple._manager == this, 'StateTuple must be from the same state manager.');
        assert(_booleanStateValueToIndex.containsKey(value), 'BooleanStateValue must have been registered with this state manager.');
        if (stateTuple._manager != this || !_booleanStateValueToIndex.containsKey(value)) return null;
        // Performed null check in previous if statement.
        return stateTuple._values[_booleanStateValueToIndex[value]!];
    }

    void _notify() {
        _notifyListeners();
        Future.delayed(
            Duration.zero,
            () {
                List<Map<BooleanStateValue, bool>> transitions = [];
                _managedStateActions.forEach(
                    (action) {
                        if (action._shouldRun(_stateGraph._currentState)) {
                            Map<BooleanStateValue, bool>? transition = action.action();
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
                    (transition) => updates.add(_transitionConversion(transition))
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

    void updateState(Map<BooleanStateValue, bool> transition) {
        assert(_stateTransitions.contains(transition), 'Unknown transition.');
        if (_stateTransitions.contains(transition)) {
            _applyStateUpdate(_transitionConversion(transition));
        }
    }

    void _applyStateUpdate(Map<ManagedValue, bool> update) {
        List<Tuple2<StateTuple, int>> possibleStates = [];
        int mask = Utils.maskFromMap<ManagedValue>(update, (key) => key._position);
        int subHash = Utils.hashFromMap<ManagedValue>(update, (key) => key._position);

        // If the currentState is still valid, the update is a duplicate, and should be ignored.
        if ((_stateGraph._currentState.hashCode & mask) == subHash) {
            return;
        }

        _stateGraph.getCurrentAdjacent().forEach(
            (stateDiff) {
                StateTuple state = stateDiff.item1;
                if ((state.hashCode & mask) == subHash ) {
                    possibleStates.add(stateDiff);
                }
            }
        );

        assert(possibleStates.isNotEmpty, 'Invalid state transition or the current state is the only state that the transition function can transition to.');
        if (possibleStates.isEmpty) return;
        if (possibleStates.length == 1) {
			_stateGraph.changeState(possibleStates.first.item1);
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

            _stateGraph.changeState(minChangeStates.first);
            _notify();
        }
    }

}

class _StateGraph {
    final List<ManagedValue> _managedValues;

    final HashMap<StateTuple, List<Tuple2<StateTuple, int>>> _validStates;
    // fazing this out
    final HashSet<StateTuple> _invalidStates;

    StateTuple _currentState;

    final StateManager _manager;

    _StateGraph._({
        required List<ManagedValue> managedValues,
        required HashMap<StateTuple, List<Tuple2<StateTuple, int>>> validStates,
        required HashSet<StateTuple> invalidStates,
        required StateTuple currentState,
        required StateManager manager
    }): _managedValues = managedValues,
        _validStates = validStates,
        _invalidStates = invalidStates,
        _currentState = currentState,
        _manager = manager;

    static _StateGraph? create({
        required StateManager manager,
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
            manager: manager
        );
    }

    static Tuple2<HashMap<StateTuple, List<Tuple2<StateTuple, int>>>, HashSet<StateTuple>> _findAllGoodState({
        required List<ManagedValue> managedValues,
        required StateManager manager
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
        return Tuple2(validStates, HashSet());
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
                        if (
							adjacentState == primaryState
							|| (
								checked.containsKey(primaryState)
								&& checked[primaryState]!.contains(adjacentState)
							)
						) {
                            return;
                        }
                        // Make note that this state combo has been done, so it doesn't occur again
                        if (!checked.containsKey(primaryState)) {
                            checked[primaryState] = HashSet();
                        }
						checked[primaryState]!.add(adjacentState);
                        if (!checked.containsKey(adjacentState)) {
                            checked[adjacentState] = HashSet();
                        }
						checked[adjacentState]!.add(primaryState);

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
        maySucceed = _validStates.keys.any(
            (state) {
				return (state.hashCode & mask) == subHash;
			}
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

	void changeState(StateTuple newState) {
		_currentState = newState;
		newState._valueReferences.forEach(
			(managedValue) {
				managedValue._value = newState.values[managedValue._position];
			}
		);
	}

}

class _ManagedStateAction {
    final String? actionName;

    /// A map of _ManagedValue indices to a value for that _ManagedValue.
    ///
    /// Used to check if this action should run for a given state.
    final Map<int, bool> registeredStateValues;

    final Map<BooleanStateValue, bool>? Function() action;

    final List<Map<BooleanStateValue, bool>> possibleTransitions;

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
    final bool Function(StateTuple currentState, StateManager manager) _canBeTrue;
    final bool Function(StateTuple currentState, StateManager manager) _canBeFalse;
    final bool _initialValue;
    bool _value;
    bool get value => _value;
    // only accessible BooleanStateManager
    final int _position;
    final StateManager _manager;

    ManagedValue._({
        required BooleanStateValue managedValue,
        required int position,
        required StateManager manager
    }): _position = position,
        _manager = manager,
        _value = managedValue.value,
        _initialValue = managedValue.value,
        _canBeFalse = managedValue.canBeFalse,
        _canBeTrue = managedValue.canBeTrue;

    bool _isAllowed(StateTuple state)  {
        return state._values[_position] ? _canBeTrue(state, _manager) : _canBeFalse(state, _manager);
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
    final StateManager _manager;

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
        StateManager manager,
        int stateHash
    ) {
        assert(stateHash >= 0);
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
    /// (true, false) => 01
    ///
    /// (false, true, true, false, true) => 10110
	/// Smallest index is least significant bit.
    @override
    int get hashCode {
        if (_hashCode == null) {
            _hashCode = 0;
            for (int index = 0; index < _values.length; index++) {
                if (_values[index]) {
                    _hashCode = _hashCode! | (1 << index);
                }
            }
        }
        return _hashCode!;
    }

    @override
    bool operator ==(Object other) => other is StateTuple && other.width == width && other.hashCode == hashCode;

}
