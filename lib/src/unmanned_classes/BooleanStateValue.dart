import '../fsm.dart';

class BooleanStateValue {
    final bool Function(StateTuple currentState) canBeTrue;
    final bool Function(StateTuple currentState) canBeFalse;
    final bool value;

    BooleanStateValue({
        required this.canBeFalse,
        required this.canBeTrue,
        required this.value
    });
}