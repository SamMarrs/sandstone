import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import 'list_state.dart';
// import 'list_state.canBeX.dart';
// import 'list_state.canBeX.optimistic.dart';
// import 'list_state.optimistic.dart';

class SearchableList<ListItemType> extends StatelessWidget {
    final Future<List<Map<String, dynamic>>> Function(String searchText, int pageSize, int offset) getItems;
    final ListItemType Function(Map<String, dynamic> dbMap) fromDBMap;
    final Widget Function(BuildContext context, BoxConstraints constraints, int index) itemBuilder;
    final Widget Function(BuildContext context, int index, BoxConstraints constraints) separatorBuilder;
    final Widget? floatingActionButton;
    final String Function(BuildContext context)? appBarTitle;
    final String Function(BuildContext context)? searchBarLabelText;
    final String Function(BuildContext context)? searchBarHintText;
    final String Function(BuildContext context)? footerText;


    final SearchableListStateModel<ListItemType> _searchModel;

	final GlobalKey<SearchableListWidgetState> _listWidgetState;
	BuildContext get scaffoldContext => _listWidgetState.currentState!.scaffoldContext;

    SearchableList._init({
        // required Key? key,
        required SearchableListStateModel<ListItemType> searchModel,
        required this.getItems,
        required this.fromDBMap,
        required this.itemBuilder,
        required this.separatorBuilder,
        this.floatingActionButton,
        this.appBarTitle,
        this.searchBarHintText,
        this.searchBarLabelText,
        this.footerText,
		required GlobalKey<SearchableListWidgetState> listWidgetState
    }): _searchModel = searchModel,
		_listWidgetState = listWidgetState;


    factory SearchableList({
        required Future<List<Map<String, dynamic>>> Function(String searchText, int pageSize, int offset) getItems,
        required ListItemType Function(Map<String, dynamic> dbMap) fromDBMap,
        required Widget Function(BuildContext context, BoxConstraints constraints, int index) itemBuilder,
        required Widget Function(BuildContext context, int index, BoxConstraints constraints) separatorBuilder,
        Widget? floatingActionButton,
        String Function(BuildContext context)? appBarTitle,
        String Function(BuildContext context)? searchBarHintText,
        String Function(BuildContext context)? searchBarLabelText,
        String Function(BuildContext context)? footerText,
        BottomSheetConfig Function(BuildContext listContext)? bottomSheetConfig,
        Key? key
    }) {
		GlobalKey<SearchableListWidgetState> listState = GlobalKey<SearchableListWidgetState>();
        SearchableListStateModel<ListItemType> searchModel = SearchableListStateModel<ListItemType>(
			getItems,
			fromDBMap,
			bottomSheetConfig == null ? null : () => bottomSheetConfig(listState.currentState!.scaffoldContext),
			() => listState.currentState!.scaffoldContext
		);

        return SearchableList._init(
            searchModel: searchModel,
            getItems: getItems,
            fromDBMap: fromDBMap,
            itemBuilder: itemBuilder,
            separatorBuilder: separatorBuilder,
            floatingActionButton: floatingActionButton,
            appBarTitle: appBarTitle,
            searchBarHintText: searchBarHintText,
            searchBarLabelText: searchBarLabelText,
            footerText: footerText,
            // key: key,
			listWidgetState: listState,
        );
    }

    @override
    Widget build(BuildContext context) {
        return MultiProvider(
            providers: [
                ChangeNotifierProvider<SearchFocusNode>.value(value: _searchModel.focusNode),
                ChangeNotifierProvider<SearchTextController>.value(value: _searchModel.searchTextController),
                ChangeNotifierProvider<SearchableListStateModel<ListItemType>>.value(value: _searchModel),
                ChangeNotifierProvider<SearchableListDataModel<ListItemType>>.value(value: _searchModel.dataModel),
            ],
            child: _SearchableList(
                getItems: getItems,
                fromDBMap: fromDBMap,
                itemBuilder: itemBuilder,
                separatorBuilder: separatorBuilder,
                appBarTitle: appBarTitle,
                searchBarHintText: searchBarHintText,
                searchBarLabelText: searchBarLabelText,
                footerText: footerText,
                floatingActionButton: floatingActionButton,
                key: _listWidgetState
            ),
        );
    }
}

class _SearchableList<ListItemType> extends StatefulWidget {
    final Future<List<Map<String, dynamic>>> Function(String searchText, int pageSize, int offset) getItems;
    final ListItemType Function(Map<String, dynamic> dbMap) fromDBMap;
    final Widget Function(BuildContext context, BoxConstraints constraints, int index) itemBuilder;
    final Widget Function(BuildContext context, int index, BoxConstraints constraints) separatorBuilder;
    final Widget? floatingActionButton;
    final String Function(BuildContext context)? appBarTitle;
    final String Function(BuildContext context)? searchBarLabelText;
    final String Function(BuildContext context)? searchBarHintText;
    final String Function(BuildContext context)? footerText;

    _SearchableList({
        required this.getItems,
        required this.fromDBMap,
        required this.itemBuilder,
        required this.separatorBuilder,
        this.floatingActionButton,
        this.appBarTitle,
        this.searchBarHintText,
        this.searchBarLabelText,
        this.footerText,
        Key? key
    }): super(key: key);

    @override
    SearchableListWidgetState<ListItemType> createState() => SearchableListWidgetState<ListItemType>();
}

class SearchableListWidgetState<ListItemType> extends State<_SearchableList> {

	late BuildContext _scaffoldContext;
	BuildContext get scaffoldContext => _scaffoldContext;

    Widget Function(BuildContext, int) _itemBuilder(
        BoxConstraints constraints,
        SearchableListDataModel<ListItemType> dm
    ) {
        return (BuildContext context, int index) {
            SearchableListStateModel model = Provider.of<SearchableListStateModel<ListItemType>>(context, listen: false);
            // Accounting for header item.
            index = index - 1;
            if (
                (dm.entries.isEmpty || index == dm.entries.length - 2) && !model.endFound
            ) {
				model.stateManager.queueTransition(model.startLazyLoading);
            }

            // header
            if (index == -1) {
                return Container();
            }

            if (index == dm.entries.length) {
                return _listFooter;
            }

            return widget.itemBuilder(context, constraints, index);
        };
    }


    late Widget _listFooter;
    late Widget _itemList;
    late Widget _searchBar;
    Widget _clearIcon = Builder (
        builder: (context) {
            return IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                    SearchTextController stc = context.read<SearchTextController>();
                    stc.clear();
                },
                color: Theme.of(context).primaryTextTheme.subtitle1?.color
            );
        },
    );

    @override
    void initState() {
        super.initState();
        _searchBar = Builder(
            builder: (context) {
                return TextField(
                    focusNode: Provider.of<SearchFocusNode>(context, listen: false),
                    controller: Provider.of<SearchTextController>(context, listen: false),
                    style: Theme.of(context).primaryTextTheme.subtitle1,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: widget.searchBarLabelText == null ? null : widget.searchBarLabelText!(context),
                        labelStyle: Theme.of(context).primaryTextTheme.subtitle1,
                        hintText: widget.searchBarHintText == null ? null : widget.searchBarHintText!(context),
                        hintStyle: Theme.of(context).primaryTextTheme.subtitle1?.copyWith(
                            color: Colors.white60
                        ),
                        contentPadding: EdgeInsets.fromLTRB(12, 0, 12, 0),
                        floatingLabelBehavior: FloatingLabelBehavior.never,
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                width: 0,
                                style: BorderStyle.none
                            )
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                width: 0,
                                style: BorderStyle.none
                            )
                        ),
                        filled: true,
                        fillColor: Theme.of(context).primaryColorLight,
                        suffixIcon: _clearIcon,
                    ),
                );
            },
        );
        _itemList = LayoutBuilder(
            builder: (context, constraints) {
				_scaffoldContext = context;
                SearchableListDataModel<ListItemType> dm = context.watch<SearchableListDataModel<ListItemType>>();
                return ListView.separated(
                    physics: const  AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16, top: 16, left: 8, right: 8),
                    itemCount: dm.numEntries + 2,
                    separatorBuilder:  (BuildContext context, int index) => widget.separatorBuilder(context, index, constraints),
                    itemBuilder: _itemBuilder(constraints, dm),
                );
            },
        );
        _listFooter = Selector<SearchableListStateModel<ListItemType>, Tuple2<bool, bool>>(
            selector: (_, sm) => Tuple2(sm.searching, sm.lazyLoading),
            builder: (_, searching, __) => Selector<SearchableListDataModel<ListItemType>, int>(
                selector: (_ , dm) => dm.numEntries,
                builder: (context, numEntries, __) {
                    return Container(
                        constraints: BoxConstraints(maxHeight: 80),
                        child: Center(
                            child: Text(
                                    widget.footerText == null ?
                                        searching.item1 || searching.item2 ?
                                            'Searching'
                                            : numEntries == 0 ?
                                                'Nothing found'
                                                : 'End of list'
                                        : widget.footerText!(context),
                                    style: Theme.of(context).textTheme.caption,
                                    textAlign: TextAlign.center,
                            ),
                        ),
                    );
                },
            ),
        );
    }

    @override
    Widget build(BuildContext context) {

        SearchableListStateModel sm = context.watch<SearchableListStateModel<ListItemType>>();

        return Scaffold(
            appBar: AppBar(
                title: sm.shouldDisplaySearchBar ? _searchBar : Text(widget.appBarTitle == null ? '' : widget.appBarTitle!(context)),
                leading: !sm.shouldDisplaySearchBar ? null : Builder(
                    builder: (BuildContext context) {
                        return BackButton(
                            onPressed: () {
								sm.stateManager.queueTransition(sm.reset);
                            },
                        );
                    },
                ),
                actions: sm.shouldDisplaySearchBar ? null : [
                    IconButton(
                        icon: Icon(Icons.search),
                        onPressed: () {
							sm.stateManager.queueTransition(sm.enableSearching);
                        },
                    )
                ],
            ),
            body: _itemList,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: !sm.shouldDisplaySearchBar && (sm.isBottomSheetMinimized || sm.isBottomSheetClosed)  ? widget.floatingActionButton : null
        );
    }
}