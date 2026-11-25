part of '../main.dart';

/// Shared live horizontal scroll tracker for main tabs & nested Option A 5th-tab handoff.
class NamiTabScrollController {
  static final ValueNotifier<double> page = ValueNotifier<double>(0.0);
  static _NamiSwipeableTabsViewState? _activeState;

  static void jumpToTab(int index) {
    _activeState?._animateToTarget(index);
  }

  /// Allows nested PageViews (like Step 5's YouTube + Mornye Option A 5th tab)
  /// to hand off left-boundary overscroll smoothly back to the previous main tab.
  static void handoffToPreviousMainTab() {
    final s = _activeState;
    if (s == null) return;
    final cur = s.widget.currentIndex;
    if (cur > 0) {
      s.widget.onPageChanged(cur - 1);
      s._animateToTarget(cur - 1);
    }
  }
}

class _NamiKeepAliveTabPage extends StatefulWidget {
  final Widget child;
  const _NamiKeepAliveTabPage({required this.child});

  @override
  State<_NamiKeepAliveTabPage> createState() => _NamiKeepAliveTabPageState();
}

class _NamiKeepAliveTabPageState extends State<_NamiKeepAliveTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

/// 120Hz Keep-Alive Swipeable Main Tabs (`PageView`) replacing tap-only `IndexedStack`.
/// Preserves every tab's scroll offset and slides 1:1 with your finger across all tabs.
class NamiSwipeableTabsView extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;

  const NamiSwipeableTabsView({
    super.key,
    required this.currentIndex,
    required this.onPageChanged,
    required this.children,
  });

  @override
  State<NamiSwipeableTabsView> createState() => _NamiSwipeableTabsViewState();
}

class _NamiSwipeableTabsViewState extends State<NamiSwipeableTabsView> {
  late final PageController _pageController;
  int? _programmaticTarget;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentIndex);
    NamiTabScrollController.page.value = widget.currentIndex.toDouble();
    NamiTabScrollController._activeState = this;
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_pageController.hasClients) return;
    final p = _pageController.page;
    if (p != null && (NamiTabScrollController.page.value - p).abs() > 0.001) {
      NamiTabScrollController.page.value = p;
    }
  }

  void _animateToTarget(int target) {
    if (!_pageController.hasClients) return;
    final cur = (_pageController.page ?? widget.currentIndex.toDouble()).round();
    if (cur == target) return;
    _programmaticTarget = target;
    final scale = NamiUxPrefs.motionScale;

    if ((target - cur).abs() > 1) {
      // Namida-style direct jump across distant tabs without flashing intermediate pages
      final staging = target > cur ? target - 1 : target + 1;
      _pageController.jumpToPage(staging);
      final ms = (240 * scale).round().clamp(150, 340);
      _pageController
          .animateToPage(
            target,
            duration: Duration(milliseconds: ms),
            curve: const Cubic(0.22, 1.0, 0.36, 1.0),
          )
          .whenComplete(() {
        if (_programmaticTarget == target) _programmaticTarget = null;
      });
    } else {
      final ms = (280 * scale).round().clamp(170, 380);
      _pageController
          .animateToPage(
            target,
            duration: Duration(milliseconds: ms),
            curve: const Cubic(0.22, 1.0, 0.36, 1.0),
          )
          .whenComplete(() {
        if (_programmaticTarget == target) _programmaticTarget = null;
      });
    }
  }

  @override
  void didUpdateWidget(covariant NamiSwipeableTabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _animateToTarget(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    if (NamiTabScrollController._activeState == this) {
      NamiTabScrollController._activeState = null;
    }
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(
        decelerationRate: ScrollDecelerationRate.fast,
      ),
      onPageChanged: (idx) {
        if (_programmaticTarget != null && idx != _programmaticTarget) {
          return;
        }
        _programmaticTarget = null;
        if (idx != widget.currentIndex) {
          NamiUxPrefs.hapticLight();
          widget.onPageChanged(idx);
        }
      },
      children: [
        for (int i = 0; i < widget.children.length; i++)
          _NamiKeepAliveTabPage(child: widget.children[i]),
      ],
    );
  }
}

class _NamiShellRouteObserver extends NavigatorObserver {
  int _depth = 0;

  void _sync() {
    final next = _depth > 0;
    if (NamiShellNavigator.hasSubPage.value != next) {
      NamiShellNavigator.hasSubPage.value = next;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _depth++;
      _sync();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) {
      _depth--;
      _sync();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_depth > 0) {
      _depth--;
      _sync();
    }
  }
}

/// Nested Shell Navigator mounted inside the main viewport ABOVE the persistent
/// Mini-Player and Bottom Navigation Bar so Settings, Artist Detail, Album Detail
/// & Albums inherit the exact same persistent player chrome seamlessly.
class NamiShellNavigator extends StatefulWidget {
  final Widget child;
  const NamiShellNavigator({super.key, required this.child});

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  static final ValueNotifier<bool> hasSubPage = ValueNotifier<bool>(false);

  static bool get canPop => navKey.currentState?.canPop() ?? false;

  static Future<T?> push<T>(Route<T> route, {BuildContext? fallbackContext}) {
    final nav = navKey.currentState;
    if (nav != null) {
      return nav.push<T>(route);
    }
    if (fallbackContext != null) {
      return Navigator.of(fallbackContext).push<T>(route);
    }
    return Future<T?>.value(null);
  }

  static bool maybePop() {
    final nav = navKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    return false;
  }

  static void popToRoot() {
    final nav = navKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
      hasSubPage.value = false;
    }
  }

  @override
  State<NamiShellNavigator> createState() => _NamiShellNavigatorState();
}

class _NamiShellNavigatorState extends State<NamiShellNavigator> {
  final _NamiShellRouteObserver _observer = _NamiShellRouteObserver();
  late final ValueNotifier<Widget> _rootChildNotifier;

  @override
  void initState() {
    super.initState();
    _rootChildNotifier = ValueNotifier<Widget>(widget.child);
  }

  @override
  void didUpdateWidget(covariant NamiShellNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rootChildNotifier.value = widget.child;
  }

  @override
  void dispose() {
    _rootChildNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Navigator(
        key: NamiShellNavigator.navKey,
        observers: [_observer],
        onGenerateRoute: (_) => PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => ValueListenableBuilder<Widget>(
            valueListenable: _rootChildNotifier,
            builder: (_, child, __) => child,
          ),
        ),
      ),
    );
  }
}

/// Global controller for the permanent In-Tree Expandable Player Sheet (0.0 -> 1.0).
class NamiExpandablePlayerController {
  static final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  static _NamiExpandablePlayerHostState? _host;

  static bool get hasHost => _host != null && _host!.mounted;
  static bool get isExpanded => progress.value > 0.05;

  static void expand() => _host?._expand();
  static void collapse() => _host?._collapse();

  static void beginDrag({required bool isOpening}) =>
      _host?._beginDrag(isOpening: isOpening);

  static void updateDrag(double deltaProgress) =>
      _host?._updateDrag(deltaProgress);

  static void endDrag({
    required double velocityPerSec,
    required bool isOpeningDrag,
  }) =>
      _host?._endDrag(
        velocityPerSec: velocityPerSec,
        isOpeningDrag: isOpeningDrag,
      );
}

/// Permanent In-Tree Expandable Player Host living in `_NamiHomeShellState`'s root Stack.
/// - Zero PageRoute handoffs, zero Hero shuttle fights, zero relayout jitter!
/// - Keeps `NowPlayingModal` mounted at fixed full-screen size with `TickerMode(enabled: t > 0.005)`
///   so Synced Lyrics mode, scroll offset & waveform state survive every collapse/re-open!
class NamiExpandablePlayerHost extends StatefulWidget {
  final Widget child;
  final bool hasSong;
  final String title;
  final String artist;
  final String trackKey;
  final Widget Function(double size, double radius) coverBuilder;
  final Stream<bool> isPlayingStream;
  final bool initialPlaying;
  final WidgetBuilder? fullPageBuilder;

  const NamiExpandablePlayerHost({
    super.key,
    required this.child,
    required this.hasSong,
    required this.title,
    required this.artist,
    required this.trackKey,
    required this.coverBuilder,
    required this.isPlayingStream,
    required this.initialPlaying,
    required this.fullPageBuilder,
  });

  @override
  State<NamiExpandablePlayerHost> createState() => _NamiExpandablePlayerHostState();
}

class _NamiExpandablePlayerHostState extends State<NamiExpandablePlayerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _dragging = false;
  bool _useCurve = true;
  bool _isReversing = false;

  Widget? _cachedCoverWidget;
  String _cachedCoverKey = '';

  static const Curve _expandCurve = _NamiSpringCurve(6.4);
  static const Curve _collapseCurve = _NamiSpringCurve(6.2);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      value: 0.0,
      duration: const Duration(milliseconds: 390),
      reverseDuration: const Duration(milliseconds: 340),
    )..addListener(_syncProgress);
    NamiExpandablePlayerController._host = this;
  }

  void _syncProgress() {
    final v = _ctrl.value.clamp(0.0, 1.0);
    if ((NamiExpandablePlayerController.progress.value - v).abs() > 0.0005 ||
        v == 0.0 ||
        v == 1.0) {
      NamiExpandablePlayerController.progress.value = v;
      NamiMorphPlayerController.progress.value = v;
    }
  }

  @override
  void didUpdateWidget(covariant NamiExpandablePlayerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasSong && _ctrl.value > 0.0) {
      _ctrl.value = 0.0;
    }
  }

  @override
  void dispose() {
    if (NamiExpandablePlayerController._host == this) {
      NamiExpandablePlayerController._host = null;
      NamiExpandablePlayerController.progress.value = 0.0;
      NamiMorphPlayerController.progress.value = 0.0;
    }
    _ctrl.removeListener(_syncProgress);
    _ctrl.dispose();
    _cachedCoverWidget = null;
    super.dispose();
  }

  Widget _getCachedCover(String key) {
    if (_cachedCoverWidget == null || _cachedCoverKey != key) {
      _cachedCoverKey = key;
      _cachedCoverWidget = RepaintBoundary(
        child: HeroMode(
          enabled: false,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: widget.coverBuilder(360.0, 0.0),
            ),
          ),
        ),
      );
    }
    return _cachedCoverWidget!;
  }

  void _expand() {
    if (!widget.hasSong || !mounted) return;
    _dragging = false;
    _useCurve = true;
    _isReversing = false;
    final rem = (1.0 - _ctrl.value).clamp(0.15, 1.0);
    final ms = (390 * rem * NamiUxPrefs.motionScale).round().clamp(180, 520);
    _ctrl.animateTo(
      1.0,
      duration: Duration(milliseconds: ms),
      curve: Curves.linear,
    );
  }

  void _collapse() {
    if (!mounted) return;
    _dragging = false;
    _useCurve = true;
    _isReversing = true;
    final rem = _ctrl.value.clamp(0.15, 1.0);
    final ms = (340 * rem * NamiUxPrefs.motionScale).round().clamp(160, 460);
    _ctrl.animateBack(
      0.0,
      duration: Duration(milliseconds: ms),
      curve: Curves.linear,
    );
  }

  void _beginDrag({required bool isOpening}) {
    if (!widget.hasSong || !mounted) return;
    _dragging = true;
    _useCurve = false;
    _isReversing = !isOpening;
    _ctrl.stop();
    if (isOpening && _ctrl.value < 0.002) {
      _ctrl.value = 0.002;
    }
  }

  void _updateDrag(double deltaProgress) {
    if (!widget.hasSong || !mounted) return;
    if (!_dragging) {
      _dragging = true;
      _useCurve = false;
    }
    _ctrl.stop();
    _ctrl.value = (_ctrl.value + deltaProgress).clamp(0.002, 1.0);
  }

  void _endDrag({
    required double velocityPerSec,
    required bool isOpeningDrag,
  }) {
    if (!mounted) return;
    _dragging = false;
    final cur = _ctrl.value;
    final bool shouldOpen = isOpeningDrag
        ? (cur > 0.18 || velocityPerSec > 0.55)
        : !(cur < 0.80 || velocityPerSec < -0.55);

    _useCurve = false;
    if (shouldOpen) {
      _isReversing = false;
      final rem = (1.0 - cur).clamp(0.08, 1.0);
      final ms = (340 * rem * NamiUxPrefs.motionScale).round().clamp(140, 400);
      _ctrl
          .animateTo(
            1.0,
            duration: Duration(milliseconds: ms),
            curve: _expandCurve,
          )
          .whenComplete(() {
        if (!_dragging && mounted) _useCurve = true;
      });
    } else {
      _isReversing = true;
      final rem = cur.clamp(0.08, 1.0);
      final ms = (300 * rem * NamiUxPrefs.motionScale).round().clamp(130, 360);
      _ctrl
          .animateBack(
            0.0,
            duration: Duration(milliseconds: ms),
            curve: _collapseCurve,
          )
          .whenComplete(() {
        if (!_dragging && mounted) _useCurve = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final pad = mq.padding;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Pre-build persistent NowPlayingModal ONCE per parent rebuild (not per animation frame!)
    final Widget? mountedFullPlayer = (widget.hasSong && widget.fullPageBuilder != null)
        ? HeroMode(
            enabled: false,
            child: RepaintBoundary(
              child: widget.fullPageBuilder!(context),
            ),
          )
        : null;

    return Stack(
      children: [
        // 1. Main app shell (Tabs + Nested Navigator + Mini-Player + Bottom Nav)
        widget.child,

        // 2. Permanent In-Tree Expandable Now Playing Layer (zero Route handoff!)
        if (mountedFullPlayer != null)
          AnimatedBuilder(
            animation: _ctrl,
            child: mountedFullPlayer,
            builder: (ctx, fullChild) {
              final rawT = _ctrl.value.clamp(0.0, 1.0);
              final double t;
              if (!_useCurve || _dragging) {
                t = rawT;
              } else if (_isReversing) {
                t = 1.0 - _collapseCurve.transform(1.0 - rawT);
              } else {
                t = _expandCurve.transform(rawT);
              }

              final active = t > 0.0015;
              final startRect = NamiMorphPlayerController.lastMiniRect ??
                  Rect.fromLTWH(10, size.height - pad.bottom - 140, size.width - 20, 64);

              final fallbackArtSize = (size.width - 30).clamp(220.0, size.height * 0.425);
              final fullArtRect = NamiMorphPlayerController.lastFullArtRect ??
                  Rect.fromLTWH(
                    (size.width - fallbackArtSize) / 2,
                    size.height * 0.1745,
                    fallbackArtSize,
                    fallbackArtSize,
                  );

              final miniArtSize = (startRect.height - 16).clamp(38.0, 48.0);
              final miniArtRect = Rect.fromLTWH(
                startRect.left + 9,
                startRect.top + (startRect.height - miniArtSize) / 2,
                miniArtSize,
                miniArtSize,
              );

              final miniInfoWidth = (startRect.width - 178).clamp(80.0, size.width - 160);
              final miniInfoRect = Rect.fromLTWH(
                startRect.left + miniArtSize + 20,
                startRect.top + (startRect.height - 38) / 2,
                miniInfoWidth,
                40,
              );
              final fullInfoRect = Rect.fromLTWH(
                24,
                fullArtRect.bottom + 14,
                size.width - 96,
                56,
              );

              final miniCtrlCenter = Offset(startRect.right - 64, startRect.center.dy);
              final fullCtrlCenter = Offset(
                size.width / 2,
                (size.height * 0.864).clamp(fullArtRect.bottom + 150, size.height - pad.bottom - 78),
              );

              final scrimOpacity = (t * 0.94).clamp(0.0, 0.94);
              final cardRect = Rect.lerp(startRect, fullRect, t)!;
              final cardRadius = ui.lerpDouble(18.0, 0.0, t)!;
              final cardColor = Color.lerp(
                const Color(0xFF14141E),
                const Color(0xFF000000),
                Curves.easeOut.transform(t),
              )!;

              final curArtRect = Rect.lerp(miniArtRect, fullArtRect, t)!;
              final curArtRadius = ui.lerpDouble(10.0, 16.0, t)!;
              final curInfoRect = Rect.lerp(miniInfoRect, fullInfoRect, t)!;
              final titleSize = ui.lerpDouble(13.8, 20.5, t)!;
              final artistSize = ui.lerpDouble(11.5, 13.5, t)!;

              final curCtrlCenter = Offset.lerp(miniCtrlCenter, fullCtrlCenter, t)!;
              final playBtnSize = ui.lerpDouble(36.0, 58.0, t)!;
              final skipIconSize = ui.lerpDouble(20.0, 30.0, t)!;
              final ctrlGap = ui.lerpDouble(2.0, 24.0, t)!;

              final fullChildOpacity = !active
                  ? 0.0
                  : (t >= 0.985 ? 1.0 : ((t - 0.66) / 0.28).clamp(0.0, 1.0));
              final sharedOverlayOpacity = !active || t >= 0.985
                  ? 0.0
                  : (1.0 - ((t - 0.84) / 0.14).clamp(0.0, 1.0));

              return IgnorePointer(
                ignoring: !active,
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      if (active)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: scrimOpacity),
                          ),
                        ),

                      // Permanent fixed-slot NowPlayingModal container (ZERO unmounts -> Lyrics persists!)
                      Positioned.fromRect(
                        rect: cardRect,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(cardRadius),
                          child: DecoratedBox(
                            decoration: active
                                ? BoxDecoration(
                                    color: cardColor,
                                    border: t < 0.94
                                        ? Border.all(
                                            color: Colors.white.withValues(alpha: 0.10 * (1.0 - t)),
                                            width: 0.9,
                                          )
                                        : null,
                                  )
                                : const BoxDecoration(),
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  left: -cardRect.left,
                                  top: -cardRect.top,
                                  width: size.width,
                                  height: size.height,
                                  child: TickerMode(
                                    enabled: active,
                                    child: IgnorePointer(
                                      ignoring: t < 0.95,
                                      child: Opacity(
                                        opacity: fullChildOpacity,
                                        child: fullChild,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Crisp GPU-scaled shared-element morph overlay (Art + Title/Artist + Controls)
                      if (sharedOverlayOpacity > 0.005)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: sharedOverlayOpacity,
                              child: Stack(
                                children: [
                                  Positioned.fromRect(
                                    rect: curArtRect,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(curArtRadius),
                                      child: _getCachedCover(widget.trackKey),
                                    ),
                                  ),
                                  Positioned.fromRect(
                                    rect: curInfoRect,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: titleSize,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2 * t,
                                            color: Colors.white,
                                            height: 1.15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: artistSize,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white60,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    left: curCtrlCenter.dx - (playBtnSize / 2 + skipIconSize + ctrlGap + 14),
                                    top: curCtrlCenter.dy - (playBtnSize / 2 + 4),
                                    child: StreamBuilder<bool>(
                                      stream: widget.isPlayingStream,
                                      initialData: widget.initialPlaying,
                                      builder: (_, snap) {
                                        final playing = snap.data ?? widget.initialPlaying;
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: skipIconSize + 10,
                                              height: playBtnSize + 8,
                                              child: Icon(
                                                Icons.skip_previous_rounded,
                                                color: Colors.white.withValues(alpha: 0.85),
                                                size: skipIconSize,
                                              ),
                                            ),
                                            SizedBox(width: ctrlGap),
                                            Container(
                                              width: playBtnSize,
                                              height: playBtnSize,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.08 + 0.05 * t),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.16 + 0.12 * t),
                                                  width: 1.0 + 0.3 * t,
                                                ),
                                              ),
                                              child: Icon(
                                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: playBtnSize * 0.56,
                                              ),
                                            ),
                                            SizedBox(width: ctrlGap),
                                            SizedBox(
                                              width: skipIconSize + 10,
                                              height: playBtnSize + 8,
                                              child: Icon(
                                                Icons.skip_next_rounded,
                                                color: Colors.white.withValues(alpha: 0.85),
                                                size: skipIconSize,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Slides & fades the Bottom Navigation Bar downward 1:1 as Now Playing expands.
class NamiExpandableBottomNavWrap extends StatelessWidget {
  final Widget child;
  const NamiExpandableBottomNavWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: NamiExpandablePlayerController.progress,
      child: child,
      builder: (_, t, c) {
        final clamped = t.clamp(0.0, 1.0);
        if (clamped <= 0.002) return c!;
        return IgnorePointer(
          ignoring: clamped > 0.05,
          child: Transform.translate(
            offset: Offset(0, clamped * 88.0),
            child: Opacity(
              opacity: (1.0 - clamped * 1.45).clamp(0.0, 1.0),
              child: c,
            ),
          ),
        );
      },
    );
  }
}

/// Smoothly scales & fades a tab-specific FAB (like Tracks' merged Shuffle/Locate FAB)
/// in 1:1 sync with horizontal PageView swipes and hides it whenever a nested sub-page is open.
class NamiShellTabFabWrap extends StatelessWidget {
  final int targetTabIndex;
  final Widget child;
  const NamiShellTabFabWrap({
    super.key,
    required this.targetTabIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NamiShellNavigator.hasSubPage,
      builder: (_, hasSub, __) {
        return ValueListenableBuilder<double>(
          valueListenable: NamiTabScrollController.page,
          child: child,
          builder: (_, curPage, c) {
            final dist = (curPage - targetTabIndex).abs();
            final vis = hasSub ? 0.0 : (1.0 - dist * 1.65).clamp(0.0, 1.0);
            return IgnorePointer(
              ignoring: vis < 0.25,
              child: Opacity(
                opacity: vis,
                child: Transform.scale(
                  scale: 0.78 + 0.22 * vis,
                  child: c,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
