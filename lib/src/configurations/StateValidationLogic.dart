/// This represents various ways states are determined to be valid when the state manager initializes, and constructs the FSM.
///
/// When [canBeX] is used, every [BooleanStateValue] marked as such must have their validate functions return true for a state to be valid.
///
/// When [canChangeToX] is used, only the [BooleanStateValues] that have changed values will be used to evaluate the validity of a state after a transition.
///
/// These two options can be intermixed.
enum StateValidationLogic {
	/// When used, every [BooleanStateValue] marked as such must have their validate functions return true for a state to be valid.
	canBeX,
	/// When used, only the [BooleanStateValues] that have changed values will be used to evaluate the validity of a state after a transition.
	canChangeToX
}