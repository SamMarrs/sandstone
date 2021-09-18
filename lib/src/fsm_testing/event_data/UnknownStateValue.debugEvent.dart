

import 'package:sandstone/src/managed_classes/StateTuple.dart';
import 'package:sandstone/src/unmanaged_classes/StateValue.dart';

import 'DebugEventData.dart';

class UnknownStateValue extends DebugEventData {
	final StateValue stateValue;
	final StateTuple stateTuple;

	UnknownStateValue({
		required this.stateTuple,
		required this.stateValue
	}): super(message: 'Encountered unknown state value.');
}