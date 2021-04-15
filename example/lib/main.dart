import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import 'List/list_state.dart';
// import 'List/list_state.optimistic.dart';
import 'List/SearchableList.widget.dart';

void main() {
  	runApp(MyApp());
}

class MyApp extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			title: 'Flutter Demo',
			theme: ThemeData(
				primarySwatch: Colors.blue,
			),
			home: ProviderWrapper(),
		);
	}
}

class TestItem {
	final String key;
	final String value;

	TestItem({
		required this.key,
		required this.value
	});

	static TestItem fromMap(Map<String, dynamic> map) {
		return TestItem(key: map.entries.first.value, value: map.entries.first.value);
	}
}

class _BottomSheetItem extends ChangeNotifier {
	TestItem? _item;
	TestItem? get item => _item;
	int? _index;
	int? get index => _index;

	void changeUnit({
		required TestItem item,
		required int index,
	}) {

		if (_item != item || index != index) {
			_item = item;
			_index = index;
			notifyListeners();
		}
	}
}

class ProviderWrapper extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return ChangeNotifierProvider(
			create: (_) => _BottomSheetItem(),
			child: SearchableListTest(),
		);
	}
}

class SearchableListTest extends StatefulWidget {
	@override
	_SearchableListTestState createState() => _SearchableListTestState();
}

class _SearchableListTestState extends State<SearchableListTest> {
	final List<Tuple3<String, String, bool>> _sampleData = [
		Tuple3('test 1', '1', false),
		Tuple3('test 2', '2', false),
		Tuple3('test 3', '3', false),
		Tuple3('test 4', '4', false),
		Tuple3('test 5', '5', false),
		Tuple3('test 6', '6', false),
		Tuple3('test 7', '7', false),
		Tuple3('test 8', '8', false),
		Tuple3('test 9', '9', false),
		Tuple3('test 10', '10', false),
		Tuple3('test 12', '12', false),
		Tuple3('test 13', '13', false),
		Tuple3('test 14', '14', false),
		Tuple3('test 15', '15', false),
		Tuple3('test 16', '16', false),
		Tuple3('test 17', '17', false),
		Tuple3('test 18', '18', false),
		Tuple3('test 19', '19', false),
		Tuple3('test 20', '20', false),
		Tuple3('test 1', '1', false),
		Tuple3('test 2', '2', false),
		Tuple3('test 3', '3', false),
		Tuple3('test 4', '4', false),
		Tuple3('test 5', '5', false),
		Tuple3('test 6', '6', false),
		Tuple3('test 7', '7', false),
		Tuple3('test 8', '8', false),
		Tuple3('test 9', '9', false),
		Tuple3('test 10', '10', false),
		Tuple3('test 12', '12', false),
		Tuple3('test 13', '13', false),
		Tuple3('test 14', '14', false),
		Tuple3('test 15', '15', false),
		Tuple3('test 16', '16', false),
		Tuple3('test 17', '17', false),
		Tuple3('test 18', '18', false),
		Tuple3('test 19', '19', false),
		Tuple3('test 20', '20', false),
	];

	Future<List<Map<String, dynamic>>> getItems(String searchText, int pageSize, int offset) async {
		List<Tuple3<String, String, bool>> filteredList = _sampleData.where((element) => element.item1.contains(searchText) && !element.item3).toList();
		List<Tuple3<String, String, bool>> resultList = [];

		int first = offset;
		int last = offset + pageSize;
		for (int i = 0; i < filteredList.length; i++) {
			if (i >= first && i <= last) {
				resultList.add(filteredList[i]);
			}
		}
		return resultList.map((e) => {e.item1: e.item2}).toList();
	}

	TestItem fromDBMap(Map<String, dynamic> dbMap) => TestItem.fromMap(dbMap);

	Widget itemBuilder(BuildContext context, BoxConstraints constraints, int index) {
		SearchableListDataModel dm = Provider.of<SearchableListDataModel<TestItem>>(context, listen: false);
		if (index >= dm.numEntries) {
			return Container();
		}
		TestItem entry = dm.entries[index];
		return ListTile(
			key: Key(entry.key),
			title: Text(entry.key),
			subtitle: Text(entry.value),
			trailing: IconButton(
				icon: Icon(Icons.fullscreen),
				onPressed: () => _onExpand(context, entry, index)
			),
		);
	}

	Widget separatorBuilder(BuildContext context, int index, BoxConstraints constraints) {
		return SizedBox();
	}

	_onExpand(BuildContext context, TestItem item, int index) {
		_BottomSheetItem bsi = context.read<_BottomSheetItem>();
		SearchableListStateModel sm = context.read<SearchableListStateModel<TestItem>>();
		bsi.changeUnit(item: item, index: index);
		// queueing showBottomSheet will re-run the open animation for the bottom sheet.
		if (!sm.isBottomSheetVisible) {
			sm.stateManager.queueTransition(sm.showBottomSheet);
		}
	}

	_onDelete(BuildContext context, TestItem item, [int? index]) {
		if (index != null) {
			SearchableListDataModel dm = context.read<SearchableListDataModel<TestItem>>();
			SearchableListStateModel sm = context.read<SearchableListStateModel<TestItem>>();
			dm.removeEntry(index);
			// Soft deleting from _sampleData in place of removing from a database.
			Tuple3 data = _sampleData[index];
			_sampleData[index] = Tuple3(data.item1, data.item2, true);
			sm.stateManager.queueTransition(sm.hideBottomSheet);
		}
	}

	late Widget _actions;
	late Widget _actionBar;
	late Widget _expandedBody;
	late Widget _minimizedBody;

	@override
	void initState() {
		super.initState();
		_actions = Builder(
			builder: (context) {
				_BottomSheetItem bsi = context.watch<_BottomSheetItem>();
				return Row(
					mainAxisAlignment: MainAxisAlignment.start,
					children: [
						Padding(
							padding: EdgeInsets.only(right: 16),
							child: IconButton(
								icon: Icon(Icons.delete),
								tooltip: "Delete",
								onPressed: bsi.item == null ? null : () => _onDelete(context, bsi.item!, bsi.index),
							) ,
						),
					],
				);
			},
		);
		_actionBar = Builder(
			builder: (context) {
				return Row(
					mainAxisAlignment: MainAxisAlignment.end,
					children: [
						_actions
					],
				);
			},
		);
		_expandedBody = Builder(
			builder: (context) {
				_BottomSheetItem bsi = context.watch<_BottomSheetItem>();
				return Padding(
					padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_actionBar,
							Wrap(
								crossAxisAlignment: WrapCrossAlignment.end,
								children: [
									Text(
										'${bsi.item == null ? '' : bsi.item!.key}',
										style: Theme.of(context).textTheme.headline6,
									),
									SelectableText(
										bsi.item == null ? '' : bsi.item!.value,
										style: Theme.of(context).textTheme.bodyText1
									)
								],
							),
						],
					)
				);
			},
		);
		_minimizedBody = Builder(
			builder: (context) {
				_BottomSheetItem bsi = context.watch<_BottomSheetItem>();
				return Padding(
					padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
					child: Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							Expanded(
								child: Text(
									bsi.item == null ? '' : bsi.item!.key,
									overflow: TextOverflow.ellipsis,
									maxLines: 1,
									style: Theme.of(context).textTheme.headline5,
								),
							),
							_actions
						],
					)
				);
			},
		);
	}


	@override
	Widget build(BuildContext context) {
		return SearchableList<TestItem>(
			bottomSheetConfig: (context) => BottomSheetConfig(
				minimizedHeight: 100,
				maximizedHeight: MediaQuery.of(context).size.height,
				width: MediaQuery.of(context).size.width,
				startExpanded: false,
				minimizedBody: _minimizedBody,
				maximizedBody: _expandedBody
			),
			getItems: getItems,
			fromDBMap: fromDBMap,
			itemBuilder: itemBuilder,
			separatorBuilder: separatorBuilder,
			appBarTitle: (context) => 'Searchable List',
			floatingActionButton: Builder(
				builder: (context) => FloatingActionButton.extended(
					label: Text('Create'),
					icon: Icon(Icons.add),
					onPressed: () {
						// TODO: add to _sampleData
					}
				),
			),
			searchBarHintText: (context) => 'Search by name',
			searchBarLabelText: (context) => 'Search by name',
			footerText: (context) {
				SearchableListDataModel dm = Provider.of<SearchableListDataModel<TestItem>>(context, listen: false);
				SearchableListStateModel sm = Provider.of<SearchableListStateModel<TestItem>>(context, listen: false);
				if (sm.searching || sm.lazyLoading) {
					return 'Searching';
				}
				if (dm.numEntries == 0) {
					return 'Nothing found';
				}
				if (sm.endFound) {
					return 'End of list';
				}
				return 'error';
			},
		);
	}
}
