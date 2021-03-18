import 'fsm.dart';

typedef VoidFunction = void Function();
typedef StateTransitionFunction = Map<ManagedValue, bool> Function();