import 'DebugEventData.dart';

class FSMMirrorNoUnchangedStateValue extends DebugEventData {

	FSMMirrorNoUnchangedStateValue(

	): super(message: 'Not every mirrored state is affected by a transition.');
}