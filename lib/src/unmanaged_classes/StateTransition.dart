import '../typedefs.dart';

import 'BooleanStateValue.dart';

class StateTransition {
    /// Used for debugging purposes
    final String name;
    final Map<BooleanStateValue, bool> stateChanges;
    final List<VoidFunction>? actions;

    StateTransition({
        this.name = '',
        required this.stateChanges,
        this.actions
    });
}