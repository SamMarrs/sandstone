import 'BooleanStateValue.dart';

class StateAction {
    /// Used for debugging.
    final String? actionName;

    final Map<BooleanStateValue, bool> registeredStateValues;

    final void Function() action;
    // final List<Map<ManagedValue, bool>> stateUpdates

    StateAction({
        required this.registeredStateValues,
        required this.action,
        this.actionName
    });
}