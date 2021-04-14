import 'package:flutter/material.dart';
import 'package:flutter_fsm/main.dart';

// If showCustomBottomSheet is called multiple times, need to make sure the prior sheet is closed
PersistentBottomSheetController? _currentBottomSheet;
GlobalKey<CustomBottomSheetState>? _currentCustomBottomSheetState;

VoidFunction showCustomBottomSheet<T>({
    required BuildContext context,
    required double minimizedHeight,
    required double maximizedHeight,
    required  double width,
    Widget? maximizedBody,
    Widget? minimizedBody,
    void Function()? afterMaximized,
    void Function()? afterMinimized,
    void Function()? afterClose,
    void Function()? afterOpen,
    bool startExpanded = false,
    bool disableSizeSnapping = false
}) {
    assert(debugCheckHasScaffold(context));

    final gKey = GlobalKey<CustomBottomSheetState>();

    bool _closing = false;
    if (_currentCustomBottomSheetState != null && _currentCustomBottomSheetState!.currentState != null) {
        _currentCustomBottomSheetState!.currentState!.close();
        _currentCustomBottomSheetState = null;
    }

    _currentBottomSheet = Scaffold.of(context).showBottomSheet<T>(
        (context) {
            _CustomBottomSheet sheet = _CustomBottomSheet(
                key: gKey,
                maximizedHeight: maximizedHeight,
                minimizedHeight: minimizedHeight,
                width: width,
                getController: () => _currentBottomSheet,
                maximizedBody: maximizedBody,
                minimizedBody: minimizedBody,
                startExpanded: startExpanded,
                disableSizeSnapping: disableSizeSnapping,
                afterMaximized: () {
                    if (afterMaximized != null) afterMaximized();
                },
                afterMinimized: () {
                    if (afterMinimized != null) afterMinimized();
                },
                afterOpen: () {
                    if (afterOpen != null) afterOpen();
                },
            );

            if (_currentCustomBottomSheetState == null && !_closing) {
                _currentCustomBottomSheetState = gKey;
            }

            return sheet;
        }
    );

    _currentBottomSheet!.closed.whenComplete(
        () {
            _currentCustomBottomSheetState = null;
            _closing = true;
            if (afterClose != null) afterClose();
        }
    );

    return () {
        if (_currentCustomBottomSheetState != null && _currentCustomBottomSheetState!.currentState != null) _currentCustomBottomSheetState!.currentState!.close();
    };
}

enum _SHEET_DRAG_STATES {
    FOLLOWING,
    DRAG_END_NO_FLING,
    DRAG_END_FLING
}
enum _SHEET_STATES {
    MAXIMIZED,
    MINIMIZED
}

class _CustomBottomSheet extends StatefulWidget {
    final double minimizedHeight;
    final double maximizedHeight;
    final double width;
    final PersistentBottomSheetController? Function() getController;
    final Widget? maximizedBody;
    final Widget? minimizedBody;
    final void Function() afterMaximized;
    final void Function() afterMinimized;
    final void Function() afterOpen;
    final bool startExpanded;
    final bool disableSizeSnapping;

    _CustomBottomSheet({
        required this.maximizedHeight,
        required this.minimizedHeight,
        required this.width,
        required this.getController,
        required this.afterMaximized,
        required this.afterMinimized,
        required this.afterOpen,
        this.startExpanded = false,
        this.disableSizeSnapping = false,
        this.maximizedBody,
        this.minimizedBody,
        Key? key,
    }): super(key: key);

    @override
    CustomBottomSheetState createState() => CustomBottomSheetState();
}

class CustomBottomSheetState extends State<_CustomBottomSheet> {
    final BorderRadius _minimizedBorderRadius = BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16)
    );
    final BorderRadius _maximizedBorderRadius = BorderRadius.zero;
    final Duration _bottomSheetEnterDuration = Duration(milliseconds: 250);

    bool isClosed = false;

    PersistentBottomSheetController? _sheetControllerHolder;
    PersistentBottomSheetController? get _sheetController {
        if (_sheetControllerHolder == null) {
            _sheetControllerHolder = widget.getController();
        }
        return _sheetControllerHolder;
    }
    _SHEET_STATES?  _currentSheetState;
    _SHEET_DRAG_STATES _sheetDragState = _SHEET_DRAG_STATES.FOLLOWING;
    late double _sheetHeightStorage;
    double get _sheetHeight => _sheetHeightStorage;
    set _sheetHeight(double height) {
        if (height > widget.maximizedHeight) {
            _sheetHeightStorage = widget.maximizedHeight;

        } else if (height < 0) {
            _sheetHeightStorage = 0;
        } else {
            _sheetHeightStorage = height;
        }
    }

    late Widget _maximizedSheet;
    late Widget _minimizedSheet;
    Widget _dragHandle = Container(
        padding: EdgeInsets.all(10),
        alignment: Alignment.center,
        child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.all(Radius.circular(10))
            ),
        ),
    );

    @override
    void initState() {
        super.initState();
        if (widget.startExpanded) {
            _sheetHeight = widget.maximizedHeight;
            _currentSheetState = _SHEET_STATES.MAXIMIZED;
        } else {
            _sheetHeight = widget.minimizedHeight;
            _currentSheetState = _SHEET_STATES.MINIMIZED;
        }

        _maximizedSheet = Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                _dragHandle,
                ...(){
                    if (widget.maximizedBody == null) return [];
                    return [widget.maximizedBody];
                }() as Iterable<Widget>

            ],
        );
        _minimizedSheet = Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                _dragHandle,
                ...(){
                    if (widget.minimizedBody == null) return [];
                    return [widget.minimizedBody];
                }() as Iterable<Widget>
            ],
        );

        WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
            widget.afterOpen();
        });
    }

    void close() {
        if (!isClosed) Navigator.of(context).pop();
        isClosed = true;
    }

    double get _followingHeight {
        if (_sheetHeight < widget.maximizedHeight) {
            // height must not go negative
            // checking for Height <= 0 still might cause problems, a 5px buffer was added
            if (_sheetHeight <= 0) {
                _sheetHeight = 0;
                return 0;
            }
            return _sheetHeight;
        }
        _sheetHeight = widget.maximizedHeight;
        return widget.maximizedHeight;
    }
    double get _midPoint {
        return ((widget.maximizedHeight - widget.minimizedHeight) / 2 ) + widget.minimizedHeight;
    }
    bool get _isAboveMid {
        return _sheetHeight >= _midPoint;
    }
    bool get _isMaximized {
        return _sheetHeight >= widget.maximizedHeight;
    }

    dynamic _getAnimationSetting(String setting) {
        if (setting == 'borderRadius') {
            if (_isMaximized) return _maximizedBorderRadius;
            return _minimizedBorderRadius;
        }
        if (_sheetDragState == _SHEET_DRAG_STATES.FOLLOWING) {
            switch (setting) {
                case 'height': return _followingHeight;
                case 'width': return widget.width;
                case 'curve': return Curves.linear;
                case 'duration': return Duration.zero;
                default: return null;
            }
        }
        if (_sheetDragState == _SHEET_DRAG_STATES.DRAG_END_FLING) {
            switch (setting) {
                case 'height': return _sheetHeight;
                case 'width': return widget.width;
                case 'curve': return Curves.easeOutCubic;
                case 'duration': return _bottomSheetEnterDuration;
                default: return null;
            }
        }
        if (_sheetDragState == _SHEET_DRAG_STATES.DRAG_END_NO_FLING) {
            switch (setting) {
                case 'height': return _sheetHeight;
                case 'width': return widget.width;
                case 'curve': return Curves.easeInCubic;
                case 'duration': return _bottomSheetEnterDuration;
                default: return null;
            }
        }
    }

    void _onAnimationEnd() {
        _SHEET_STATES newState = _isMaximized ? _SHEET_STATES.MAXIMIZED : _SHEET_STATES.MINIMIZED;
        if (
            _sheetDragState != _SHEET_DRAG_STATES.FOLLOWING
            && newState != _currentSheetState
        ) {
            // Might still be rebuilding as a result of the setState that changed the sheet's height.
            Future.delayed(
                Duration.zero,
                () {
                    switch (newState) {
                        case _SHEET_STATES.MAXIMIZED:
                            _currentSheetState = _SHEET_STATES.MAXIMIZED;
                            widget.afterMaximized();
                            break;
                        case _SHEET_STATES.MINIMIZED:
                        default:
                            _currentSheetState = _SHEET_STATES.MINIMIZED;
                            widget.afterMinimized();
                            break;
                    }
                }
            );
        }
    }

    void _onVerticalDragUpdate(DragUpdateDetails details) {
        if (_sheetController != null) {
            widget.getController()!.setState!(() {
                _sheetDragState = _SHEET_DRAG_STATES.FOLLOWING;
                _sheetHeight -= details.primaryDelta!;
            });
        }
    }

    void _onVerticalDragEnd(DragEndDetails details) {
        double? pVelocity = details.primaryVelocity;
        if (_sheetController != null) {
            if (pVelocity! < 0) {
                // fling up
                _sheetController!.setState!(() {
                    _sheetHeight = widget.maximizedHeight;
                    _sheetDragState = _SHEET_DRAG_STATES.DRAG_END_FLING;
                });
            } else if (pVelocity > 0) {
                // fling down
                _sheetController!.setState!(() {
                    _sheetDragState = _SHEET_DRAG_STATES.DRAG_END_FLING;
                    if (_sheetHeight <= widget.minimizedHeight) {
                        // close;
                        close();
                    } else {
                        _sheetHeight = widget.minimizedHeight;
                    }
                });

            } else {
                // rebound to nearest state or close
                _sheetController!.setState!(() {
                    _sheetDragState = _SHEET_DRAG_STATES.DRAG_END_NO_FLING;
                    if (_isMaximized) {
                        // there will be no animation, so the onEnd callback needs to be called now.
                        _onAnimationEnd();
                    } else if (widget.disableSizeSnapping) {
                        if (_sheetHeight < widget.minimizedHeight && _sheetHeight > widget.minimizedHeight / 2) {
                            _sheetHeight = widget.minimizedHeight;
                        }

                    } else if (!widget.disableSizeSnapping) {
                        if (_isAboveMid) {
                            _sheetHeight = widget.maximizedHeight;

                        } else if (_sheetHeight > widget.minimizedHeight / 2) {
                            _sheetHeight = widget.minimizedHeight;

                        } else {
                            close();
                        }
                    }
                });
            }
        }
    }

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: AnimatedContainer(
                height: _getAnimationSetting('height'),
                width: _getAnimationSetting('width'),
                curve: _getAnimationSetting('curve'),
                duration: _getAnimationSetting('duration'),
                decoration: BoxDecoration(
                    borderRadius: _getAnimationSetting('borderRadius'),
                    color: Theme.of(context).backgroundColor,
                    boxShadow: kElevationToShadow[8]
                ),
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                onEnd: _onAnimationEnd,
                child: SizedBox.expand(
                    child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: AnimatedCrossFade(
                            firstChild: _minimizedSheet,
                            secondChild: _maximizedSheet,
                            crossFadeState: _isAboveMid ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            // durations of zero can cause errors
                            duration: Duration(milliseconds: 1),
                        )
                    ),
                )
            ),
        );
    }
}