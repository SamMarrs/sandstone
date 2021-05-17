import 'StateValue.dart';
import '../StateManager.dart';

/// Defines an action to run after a state change.
class StateAction {
	/// Used for debugging.
	final String name;

	// TODO: Should this be replaced with a function that returns true/false?
	/// Defines during which states, this [StateAction] will run.
	final Map<StateValue, bool> registeredStateValues;

	/// Defines an action to run.
	///
	/// Unlike [StateTransition.action], this action will not run if a transition results in no state change.
	///
	/// This action will run after the state changes, and a new frame has been rendered (using WidgetsBinding.instance.addPostFrameCallback).
	final void Function(StateManager manager) action;

	StateAction({
		required this.registeredStateValues,
		required this.action,
		this.name = '',
	});
}