A state management library for Flutter.

## Usage
A complete example can be found [here](https://github.com/SamMarrs/sandstone/tree/main/example)

State management libraries like [Provider] are recommended to be used alongside this one.
Otherwise, a custom use of Flutter's [InheritedWidget] would be needed to propagate state changes throughout the project.

### Conservative State Transitions (Recommended)
Below is a simplified excerpt from this [example] project.
The project displays a searchable list of items that are lazy loaded as you scroll.

For this version of the state manager, the next state of a FSM will only differ from the previous state
by the exact changes defined in a `StateTransition`. Check out the next [section](#Optimistic-State-Transitions) to see how this could differ.

```dart
class SearchableListStateModel extends ChangeNotifier {
	late final FSM.ManagedValue _shouldDisplaySearchBar;
	late final FSM.ManagedValue _endFound;
	late final FSM.ManagedValue _lazyLoading;
	late final FSM.ManagedValue _searching;

	// State variables that will be visible to anything that has access to this ChangeNotifier
    bool get shouldDisplaySearchBar => _shouldDisplaySearchBar.value;
	bool get endFound => _endFound.value;
	bool get lazyLoading => _lazyLoading.value;
	bool get searching => _searching.value;

	// Pre-defined state transitions.
	// These transitions can be used by anything that has access to them and a StateManger, to affect the underlying finite state machine.
	// ex: stateManager.queueTransition(transitionName);
    late final FSM.StateTransition enableSearching;
	late final FSM.StateTransition startLazyLoading;
	late final FSM.StateTransition reset;
	late final FSM.StateTransition _setEndFound;
	late final FSM.StateTransition _stopLazyLoading;
	late final FSM.StateTransition _startSearching;
	late final FSM.StateTransition _stopSearching;

    SearchableListStateModel() {
		// References to the state values being initialized in the FSM.
        late FSM.BooleanStateValue shouldDisplaySearchBar;
        late FSM.BooleanStateValue endFound;
        late FSM.BooleanStateValue lazyLoading;
        late FSM.BooleanStateValue searching;

		// Initialization function for StateManager, and the entry point for the library as a whole.
		// The initialization can fail, but if in debug mode, messages will tell you how to fix it.
		// These failure conditions should be mistakes in your code (if they're not, please report it) that are found
		// by analyzing the underlying FSM.
        FSM.StateManager? sm = FSM.StateManager.create(
			// Useful debug messages.
            showDebugLogs: true,
			// Should be a reference to ChangeNotifier.notifyListeners, or some similar function.
            notifyListeners: notifyListeners,
            // Defines the managed state variables, and all valid states within the underlying FSM.
			// The value property of each initialized BooleanStateValue defines the initial state of the FSM.
			managedValues: [
                shouldDisplaySearchBar = FSM.BooleanStateValue(
                    canChangeToFalse: (currentState, nextState, manager) => true,
                    canChangeToTrue: (currentState, nextState, manager) => true,
                    value: false
                ),
                endFound = FSM.BooleanStateValue(
                    canChangeToFalse: (currentState, nextState, manager) => true,
                    canChangeToTrue: (currentState, nextState, manager) {
                        return true;
                    },
                    value: false
                ),
                lazyLoading = FSM.BooleanStateValue(
					// If a transition causes this state variable to change to false, is that change allowed?
                    canChangeToFalse: (currentState, nextState, manager) => true,
					// If a transition causes this state variable to change to true, is that change allowed?
                    canChangeToTrue: (currentState, nextState, manager) {
						// manager.getFromState retrieves the value for a state variable within the given state.
                        return !manager.getFromState(currentState, endFound)!
                            && !manager.getFromState(currentState, searching)!;
                    },
					// Initial value for this state variable.
                    value: false
                ),
                searching = FSM.BooleanStateValue(
                    canChangeToFalse: (currentState, nextState, manager) => true,
                    canChangeToTrue: (currentState, nextState, manager) {
                        return !manager.getFromState(currentState, lazyLoading)!
                            && manager.getFromState(currentState, shouldDisplaySearchBar)!;
                    },
                    value: false
                ),
            ],
			// Defines how the state of the FSM can be altered.
            stateTransitions: [
                enableSearching = FSM.StateTransition(
                    name: 'enableSearching',
                    stateChanges: {
                        shouldDisplaySearchBar: true
                    }
                ),
                startLazyLoading = FSM.StateTransition(
					// The name is only used for debugging.
                    name: 'startLazyLoading',
					// Changes to the state that this transition will make.
					// lazyLoading is the BooleanStateValue defined above.
                    stateChanges: {
                        lazyLoading: true
                    },
					// If true, this transition will not be applied to the FSM sequentially.
					// At least one other transition must run before this can run again.
                    ignoreDuplicates: true,
					// Business logic to be run before the state changes are propagated to any listeners, and
					// before the UI gets a chance to rebuild.
					// With conservative state transitions, additionalChanges will always be an empty object.
                    action: (manager, additionalChanges) {
                        // Async logic used for lazy loading
                        //
                        // When complete, either:
                        //  stateManager.queueTransition(_setEndFound)
                        // OR
                        //  stateManager.queueTransition(_stopLazyLoading)
                        // will be called.
                    },
                ),
                _setEndFound = FSM.StateTransition(
                    name: '_setEndFound',
                    stateChanges: {
                        endFound: true,
                        searching: false,
                        lazyLoading: false,
                    }
                ),
                _stopLazyLoading = FSM.StateTransition(
                    name: '_stopLazyLoading',
                    stateChanges: {
                        lazyLoading: false,
                    }
                ),
                _startSearching = FSM.StateTransition(
                    name: '_startSearching',
                    stateChanges: {
                        searching: true,
                        endFound: false
                    },
                    ignoreDuplicates: true,
                ),
                _stopSearching = FSM.StateTransition(
                    name: '_stopSearching',
                    stateChanges: {
                        searching: false
                    }
                ),
                reset = FSM.StateTransition(
                    name: 'reset',
                    stateChanges: {
                        shouldDisplaySearchBar: false,
                        endFound: false,
                        lazyLoading: false,
                        searching: false
                    },
                    action: (manager, additionalChanges) {
                        // logic to reset data displayed by the list
                    },
                ),
            ],
			// Defines business logic to run when certain state values are a given value.
            stateActions: [
                FSM.StateAction(
					// Only used for debug purposes.
                    name: 'search',
					// Defines when this action will run.
					// searching is the BooleanStateValue defined above.
                    registeredStateValues: {
                        searching: true,
                    },
					// Business logic to run after a state change, and after the UI rebuilds.
                    action: (manager) {
                        // Async logic used for searching
                        //
                        // When complete, either:
                        //  stateManager.queueTransition(_setEndFound)
                        // OR
                        //  stateManager.queueTransition(_stopSearching)
                        // will be called.
                    },
                ),
            ]
        );

        assert(sm != null, 'Failed to initialize the state manager.');
        if (sm == null) {
            throw 'Failed to initialize state manager';
        }
        stateManager = sm;

        _shouldDisplaySearchBar = stateManager.getManagedValue(shouldDisplaySearchBar)!;
        _endFound = stateManager.getManagedValue(endFound)!;
        _lazyLoading = stateManager.getManagedValue(lazyLoading)!;
        _searching = stateManager.getManagedValue(searching)!;
    }
}
```

### Optimistic State Transitions
To see this in action within the [example] project, swap out the imports of `list_state.dart`
with `list_state.optimistic.dart`.

The optimistic state transitions option of the `StateManager` is a less efficient method of
building the underlying FSM, but may preferable to work with by some people.
When traversing the FSM graph with conservative state transitions, the state manager will only consider
traversing to states that differ from the previous one by exactly that defined in a `StateTransition`.
When the optimistic option, optimistic option, any state with at least the difference defined by a `StateTransition`
will be considered. If (while traversing the FSM graph), multiple states are found, the next state with the
minimum difference from the previous state will be used.

```dart
class SearchableListStateModel extends ChangeNotifier {
	// ManageValue references
	// StateTransitionReferences

	SearchableListStateModel( ) {

		// BooleanStateValueReferences

		FSM.StateManager? sm = FSM.StateManager.create(
			showDebugLogs: true,
			// Enable optimistic transitions
			optimisticTransitions: true,
			notifyListeners: notifyListeners,
			managedValues: [
				// shouldDisplaySearchBar = ...
				endFound = FSM.BooleanStateValue(
					canChangeToFalse: (currentState, nextState, manager) => true,
					// There's now some use in checking for values of the next state.
					canChangeToTrue: (currentState, nextState, manager) {
						return !manager.getFromState(nextState, searching)!;
					},
					value: false
				),
				lazyLoading = FSM.BooleanStateValue(
					canChangeToFalse: (currentState, nextState, manager) => true,
					canChangeToTrue: (currentState, nextState, manager) {
						return !manager.getFromState(currentState, endFound)!
							&& !manager.getFromState(nextState, searching)!
							&& !manager.getFromState(currentState, lazyLoading)!;
					},
					value: false
				),
				searching = FSM.BooleanStateValue(
					canChangeToFalse: (currentState, nextState, manager) => true,
					canChangeToTrue: (currentState, nextState, manager) {
						return !manager.getFromState(nextState, lazyLoading)!
							&& manager.getFromState(currentState, shouldDisplaySearchBar)!
							&& manager.getFromState(nextState, shouldDisplaySearchBar)!;
					},
					value: false
				),
			],
			stateTransitions: [
				// enableSearching = ...
				startLazyLoading = FSM.StateTransition(
					name: 'startLazyLoading',
					stateChanges: {
						lazyLoading: true
					},
					ignoreDuplicates: true,
					// With Optimistic transitions, additionalChanges will be a map defining all the
					// changes not specified by this transition.
					action: (manager, additionalChanges) {
						// business logic
					},
				),
				// Now, endFound can not be true when searching is true, so we no longer need to specify it in this transition.
				// See the initialization of its BooleanStateValue: !manager.getFromState(nextState, searching)
				// With Optimistic transitions, even though no transition may set both searching and endFound to true,
				// we must specify that the state manager should not choose a state where both are true.
				_setEndFound = FSM.StateTransition(
					name: '_setEndFound',
					stateChanges: {
						endFound: true,
						lazyLoading: false,
					}
				),
				// _stopLazyLoading = ...
				// _startSearching = ...
				// _stopSearching = ...
				// reset = ...
			],
			stateActions: [
				// Nothing changed here
			]
		);
		// Nothing changed here
	}
}
```


[example]: https://github.com/SamMarrs/sandstone/tree/main/example
[provider]: https://github.com/rrousselGit/provider
[riverpod]: https://github.com/rrousselGit/river_pod
[inheritedwidget]: https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html