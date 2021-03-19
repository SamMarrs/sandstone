import '../typedefs.dart';
import 'BooleanStateValue.dart';

class StateAction {
    /// Used for debugging.
    final String? actionName;

    final Map<BooleanStateValue, bool> registeredStateValues;

    final StateTransitionFunction? Function() action;
    // final List<Map<ManagedValue, bool>> stateUpdates

    final List<StateTransitionFunction> possibleTransitions;

    StateAction({
        required this.registeredStateValues,
        required this.action,
        this.actionName,
        this.possibleTransitions = const []
    });
}