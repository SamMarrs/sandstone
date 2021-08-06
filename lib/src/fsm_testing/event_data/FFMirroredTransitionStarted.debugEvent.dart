import 'dart:collection';

import '../../unmanaged_classes/fsm_mirroring.dart';
import 'DebugEventData.dart';

class FFMirroredTransitionStarted extends DebugEventData {
	final UnmodifiableListView<MirroredTransition> transitionBuffer;


	FFMirroredTransitionStarted({
		required Iterable<MirroredTransition> transitionBufferIterable
	}): transitionBuffer = UnmodifiableListView([...transitionBufferIterable]),
		super(message: '');
}