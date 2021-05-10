//cSpell:ignore cbssm
import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import '../BottomSheet/CustomBottomSheet.alt.widget.dart';
import 'package:tuple/tuple.dart';
import 'package:sandstone/main.dart' as FSM;

// FIXME: Sometimes, something with the bottom sheet can fail with a failed assertion from Scaffold.
// ^this might actually be due to the FAB: Failed assertion: line 1205 pos 16: 'widget.currentController.status == AnimationStatus.dismissed': is not true.)
// (or also occur because of the fab)
// rapidly expand card, tap search button, tap search bar,
// The FAB also has something going on at the beginning of a frame.
// In scaffold.dart _handlePreviousAnimationStatusChanged()

class SearchFocusNode extends FocusNode {
	SearchFocusNode(): super();
}
class SearchTextController extends TextEditingController {
	SearchTextController(): super();
}

class SearchableListStateModel<ListItemType> extends ChangeNotifier {
	SearchFocusNode _focusNode = SearchFocusNode();
	/// Only use this for setting up ChangeNotifierProvider
	SearchFocusNode get focusNode => _focusNode;
	late final SearchableListDataModel<ListItemType> _dataModel;
	/// Only use this for setting up ChangeNotifierProvider
	SearchableListDataModel<ListItemType> get dataModel => _dataModel;
	final SearchTextController _stc = SearchTextController();
	/// Only use this for setting up ChangeNotifierProvider
	SearchTextController get searchTextController => _stc;
	final KeyboardVisibilityController _kvc = KeyboardVisibilityController();
	final BottomSheetConfig Function()? _getBottomSheetConfig;
	final BuildContext Function() _getScaffoldContext;
	final CustomBottomSheetStateModel _cbssm = CustomBottomSheetStateModel();
	final Future<List<Map<String, dynamic>>> Function(String searchText, int pageSize, int offset) getItems;
	final ListItemType Function(Map<String, dynamic> dbMap) fromDBMap;

	SearchableListStateModel(
		this.getItems,
		this.fromDBMap,
		BottomSheetConfig Function()? getBottomSheetConfig,
		BuildContext Function() getScaffoldContext
	): _getBottomSheetConfig = getBottomSheetConfig,
		_getScaffoldContext  = getScaffoldContext {
		_dataModel = SearchableListDataModel<ListItemType>(this);
		_stc.addListener(_stcEvent);
		_kvc.onChange.listen(_kvcEvent);
		_cbssm.addListener(_bottomSheetEvent);

		late FSM.BooleanStateValue shouldHideBottomSheet;
		late FSM.BooleanStateValue isBottomSheetVisible;
		late FSM.BooleanStateValue shouldDisplaySearchBar;
		late FSM.BooleanStateValue endFound;
		late FSM.BooleanStateValue lazyLoading;
		late FSM.BooleanStateValue searching;

		FSM.StateManager? sm = FSM.StateManager.create(
			showDebugLogs: true,
			optimisticTransitions: true,
			notifyListeners: notifyListeners,
			managedValues: [
				shouldHideBottomSheet = FSM.BooleanStateValue(
					validateFalse: (currentState, nextState, manager) => true,
					validateTrue: (currentState, nextState, manager) {
						return manager.getFromState(currentState, isBottomSheetVisible)!
							&& manager.getFromState(nextState, isBottomSheetVisible)!;
					},
					value: false
				),
				isBottomSheetVisible = FSM.BooleanStateValue(
					validateFalse: (currentState, nextState, manager) => true,
					validateTrue: (currentState, nextState, manager) {
						return !manager.getFromState(currentState, searching)!
							&& !manager.getFromState(nextState, searching)!;
					},
					value: false
				),
				shouldDisplaySearchBar = FSM.BooleanStateValue(
					validateFalse: (currentState, nextState, manager) => true,
					validateTrue: (currentState, nextState, manager) => true,
					value: false
				),
				endFound = FSM.BooleanStateValue(
					validateFalse: (currentState, nextState, manager) => true,
					validateTrue: (currentState, nextState, manager) {
						return !manager.getFromState(nextState, searching)!;
					},
					value: false
				),
				lazyLoading = FSM.BooleanStateValue(
					validateFalse: (currentState, nextState, manager) => true,
					validateTrue: (currentState, nextState, manager) {
						return !manager.getFromState(currentState, endFound)!
							&& !manager.getFromState(nextState, searching)!
							&& !manager.getFromState(currentState, lazyLoading)!;
					},
					value: false
				),
				searching = FSM.BooleanStateValue(
					validateFalse: (currentState, nextState, manager) => true,
					validateTrue: (currentState, nextState, manager) {
						return !manager.getFromState(nextState, lazyLoading)!
							&& manager.getFromState(currentState, shouldDisplaySearchBar)!
							&& manager.getFromState(nextState, shouldDisplaySearchBar)!;
					},
					value: false
				),
			],
			stateTransitions: [
				_setBottomSheetInvisible = FSM.StateTransition(
					name: '_setBottomSheetInvisible',
					stateChanges: {
						isBottomSheetVisible: false,
						shouldHideBottomSheet: false
					}
				),
				showBottomSheet = FSM.StateTransition(
					name: 'Show bottom sheet',
					stateChanges: {
						isBottomSheetVisible: true
					},
					ignoreDuplicates: true,
					action: (manager, additionalChanges) {
						BottomSheetConfig? config = _getBottomSheetConfig == null ? null : _getBottomSheetConfig!();
						if (config == null) {
							manager.queueTransition(_setBottomSheetInvisible);
						} else {
							BuildContext context = _getScaffoldContext();
							// Hide the keyboard if its up.
							FocusScopeNode  focus = FocusScope.of(context);
							if (!focus.hasPrimaryFocus && focus.focusedChild != null) {
								FocusManager.instance.primaryFocus?.unfocus();
							}
							_cbssm.showCustomBottomSheet(
								context: context,
								minimizedHeight: config.minimizedHeight,
								maximizedHeight: config.maximizedHeight,
								width: config.width,
								maximizedBody: config.maximizedBody,
								minimizedBody: config.minimizedBody,
								startMaximized: config.startExpanded,
								disableSizeSnapping: config.disableSizeSnapping,
							);
						}
					},
				),
				hideBottomSheet = FSM.StateTransition(
					name: 'hideBottomSheet',
					stateChanges: {
						shouldHideBottomSheet: true
					},
					ignoreDuplicates: true,
				),
				enableSearching = FSM.StateTransition(
					name: 'enableSearching',
					stateChanges: {
						shouldDisplaySearchBar: true
					}
				),
				startLazyLoading = FSM.StateTransition(
					name: 'startLazyLoading',
					stateChanges: {
						lazyLoading: true
					},
					ignoreDuplicates: true,
					action: (manager, additionalChanges) {
						_getItems(searchText: _searchText).then(
							(results) {
								_dataModel._addAll(results.item2);
								if (results.item1) {
									stateManager.queueTransition(_setEndFound);
								} else {
									stateManager.queueTransition(_stopLazyLoading);
								}
							}
						).catchError(
							(error) {
								assert(false, error.toString());
								stateManager.queueTransition(_setEndFound);
							}
						);
					},
				),
				_setEndFound = FSM.StateTransition(
					name: '_setEndFound',
					stateChanges: {
						endFound: true,
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
						shouldHideBottomSheet: false,
						isBottomSheetVisible: false,
						shouldDisplaySearchBar: false,
						endFound: false,
						lazyLoading: false,
						searching: false
					},
					action: (manager, additionalChanges) {
						_cbssm.close();
						_dataModel._clear();
						_stc.removeListener(_stcEvent);
						_stc.clear();
						_searchText = '';
						_stc.addListener(_stcEvent);
					},
				),
			],
			stateActions: [
				FSM.StateAction(
					name: 'search',
					registeredStateValues: {
						searching: true,
					},
					action: (manager) {
						_getItems(searchText: _searchText, offset: 0).then(
							(results) {
								_dataModel._replaceAll(results.item2);
								if (results.item1) {
									stateManager.queueTransition(_setEndFound);
								} else {
									stateManager.queueTransition(_stopSearching);
								}
							}
						).catchError(
							(error) {
								assert(false, error.toString());
								stateManager.queueTransition(_setEndFound);
							}
						);
					},
				),
				FSM.StateAction(
					name: 'hideBottomSheet',
					registeredStateValues: {
						shouldHideBottomSheet: true
					},
					action: (manager) {
						_cbssm.close();
					}
				)
			]
		);

		assert(sm != null, 'Failed to initialize the state manager.');
		if (sm == null) {
			throw 'Failed to initialize state manager';
		}
		stateManager = sm;

		_shouldHideBottomSheet = stateManager.getManagedValue(shouldHideBottomSheet)!;
		_isBottomSheetVisible = stateManager.getManagedValue(isBottomSheetVisible)!;
		// _shouldDisplayBottomSheet = stateManager.getManagedValue(shouldDisplayBottomSheet)!;
		_shouldDisplaySearchBar = stateManager.getManagedValue(shouldDisplaySearchBar)!;
		_endFound = stateManager.getManagedValue(endFound)!;
		_lazyLoading = stateManager.getManagedValue(lazyLoading)!;
		_searching = stateManager.getManagedValue(searching)!;

	}

	late final FSM.StateManager stateManager;

	bool get isBottomSheetClosed => !_isBottomSheetVisible.value;
	late final FSM.ManagedValue _isBottomSheetVisible;
	late final FSM.ManagedValue _shouldHideBottomSheet;

	bool get shouldDisplaySearchBar => _shouldDisplaySearchBar.value;
	late final FSM.ManagedValue _shouldDisplaySearchBar;
	late final FSM.ManagedValue _endFound;
	bool get endFound => _endFound.value;
	bool get lazyLoading => _lazyLoading.value;
	late final FSM.ManagedValue _lazyLoading;
	bool get searching => _searching.value;
	late final FSM.ManagedValue _searching;



	late final FSM.StateTransition _setBottomSheetInvisible;
	late final FSM.StateTransition showBottomSheet;
	late final FSM.StateTransition hideBottomSheet;

	late final FSM.StateTransition enableSearching;
	late final FSM.StateTransition startLazyLoading;
	late final FSM.StateTransition _setEndFound;
	late final FSM.StateTransition _stopLazyLoading;
	late final FSM.StateTransition _startSearching;
	late final FSM.StateTransition _stopSearching;
	late final FSM.StateTransition reset;


	bool _isBottomSheetMaximized = false;
	bool get isBottomSheetMinimized => !_isBottomSheetMaximized;
	set _bottomSheetMaximized(bool isMaximized) {
		if (_isBottomSheetMaximized != isMaximized) {
			_isBottomSheetMaximized = isMaximized;
			notifyListeners();
		}
	}
	BOTTOM_SHEET_STATES _bsState = BOTTOM_SHEET_STATES.CLOSED;
	void _bottomSheetEvent() {
		if (_cbssm.value != _bsState) {
			_bsState = _cbssm.value;
			switch (_bsState) {
				case BOTTOM_SHEET_STATES.CLOSED:
					_bottomSheetMaximized = false;
					stateManager.queueTransition(_setBottomSheetInvisible);
					break;
				case BOTTOM_SHEET_STATES.MAXIMIZED:
					_bottomSheetMaximized = true;
					break;
				case BOTTOM_SHEET_STATES.MINIMIZED:
					_bottomSheetMaximized = false;
					break;
			}
		}
	}

	String _searchText = '';
	void _stcEvent() {
		if (_searchText != _stc.text) {
			_searchText = _stc.text;
			stateManager.queueTransition(_startSearching);
		}
	}

	// While we can't control the keyboard, I'm converting events from KeyboardVisibilityController into inputs to this fsm
	bool _keyboardVisible = false;
	void _kvcEvent(bool visible) {
		if (visible && !_keyboardVisible) {
			_keyboardVisible = true;
			stateManager.queueTransition(hideBottomSheet);
		} else {
			_keyboardVisible = visible;
		}
	}

		Future<Tuple2<bool, List<ListItemType>>> _getItems({
		required String searchText,
		int? offset
	}) async {
		return getItems(searchText, _pageSize, offset == null ? _entries.length : offset).then(
			(List<Map<String, dynamic>> values) {
				bool hasEndBeenFound = _endFound.value;
				List<ListItemType> newItems = [];
				if (values.isEmpty || values.length < _pageSize) {
					hasEndBeenFound = true;
				}
				if (values.isNotEmpty) {
					values.forEach(
						(itemMap) {
							newItems.add(fromDBMap(itemMap));
						}
					);
				}
				return Tuple2(hasEndBeenFound, newItems);
			}
		);
	}


	// stored here because of reset(). Used in SearchableListDataModel so we can create independent sets of listeners.
	final int _pageSize = 10;
	List<ListItemType> _entries = [];


}

class SearchableListDataModel<ListItemType> extends ChangeNotifier {
	late final SearchableListStateModel<ListItemType> _sm;

	SearchableListDataModel(
		SearchableListStateModel<ListItemType> searchModel
	): _sm = searchModel;

	int get pageSize => _sm._pageSize;
	UnmodifiableListView<ListItemType> get entries => UnmodifiableListView(_sm._entries);
	int get numEntries => _sm._entries.length;

	void refreshEntry(int index, ListItemType newEntry) {
		if (index < _sm._entries.length &&  _sm._entries[index] != newEntry) {
			_sm._entries[index] = newEntry;
			notifyListeners();
		}
	}
	void removeEntry(int index) {
		if (index < _sm._entries.length) {
			_sm._entries.removeAt(index);
			notifyListeners();
		}
	}
	int? getIndexFromEntry(ListItemType entry) {
		int index = _sm._entries.indexOf(entry);
		if (index < 0) return null;
		return index;
	}


	void _clear() {
		if (_sm._entries.isNotEmpty) {
			_sm._entries.clear();
			notifyListeners();
		}
	}
	void _addAll(List<ListItemType> items) {
		if (items.isNotEmpty) {
			_sm._entries.addAll(items);
			notifyListeners();
		}
	}
	void _replaceAll(List<ListItemType> items) {
		_sm._entries.clear();
		_sm._entries.addAll(items);
		notifyListeners();
	}
}

class BottomSheetConfig {
	final double minimizedHeight;
	final double maximizedHeight;
	final double width;
	final Widget? maximizedBody;
	final Widget? minimizedBody;
	final bool startExpanded;
	final bool disableSizeSnapping;

	BottomSheetConfig({
		required this.minimizedHeight,
		required this.maximizedHeight,
		required this.width,
		this.maximizedBody,
		this.minimizedBody,
		this.startExpanded = false,
		this.disableSizeSnapping = false
	});
}