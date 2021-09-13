import 'DebugEventData.dart';

class FSMMirrorNoReusedTransition extends DebugEventData {

	FSMMirrorNoReusedTransition(

	): super(message: 'Cannot use MirroredTransitions in multiple instances of FSMMirror');
}