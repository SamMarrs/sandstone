import 'DebugEventData.dart';

class FSMMirrorNoReusedStateValue extends DebugEventData {

	FSMMirrorNoReusedStateValue(

	): super(message: 'Cannot use MirroredStateValues in multiple instances of FSMMirror');
}