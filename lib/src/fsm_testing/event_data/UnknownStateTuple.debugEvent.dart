
import 'package:sandstone/src/StateManager.dart';

import 'DebugEventData.dart';

class UnknownStateTuple extends DebugEventData {
	final StateTuple stateTuple;

	UnknownStateTuple({
		required this.stateTuple
	}): super(message: 'Encountered unknown state tuple.');
}