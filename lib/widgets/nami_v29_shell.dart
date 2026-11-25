part of '../main.dart';

void _namiSafeSetNotifier<T>(ValueNotifier<T> notifier, T next) {
  if (notifier.value == next) return;
  final phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
    notifier.value = next;
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (notifier.value != next) notifier.value = next;
    });
  }
}

/// Shared live horizontal scroll tracker for main tabs & nested Option A 5th-tab handoff.
class NamiTabScrollController {
  static final ValueNotifier<double> page = ValueNotifier<double>(0.0);
  static _NamiSwipeableTabsViewState? _activeState;

  static void jumpToTab(int index) {
    _activeState?._animateToTarget(index);
  }

  static void handoffToPreviousMainTab() {
    final s = _activeState;
    if (s == null || !s.mounted) return;
    final cur = s.widget.currentIndex;
    if (cur > 0) {
      s.widget.onPageChanged(cur - 1);
      s._animateToTarget(cur - 1);
    }
  }
}

class _NamiKeepAliveTabPage extends StatefulWidget {
  final Widget child;
  const _NamiKeepAliveTabPage({super.key, required this.child});

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

/// 120Hz Keep-Alive Swipeable Main Tabs (`PageView`).
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
    _namiSafeSetNotifier<double>(NamiTabScrollController.page, widget.currentIndex.toDouble());
    NamiTabScrollController._activeState = this;
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted || !_pageController.hasClients) return;
    final p = _pageController.page;
    if (p != null && (NamiTabScrollController.page.value - p).abs() > 0.002) {
      _namiSafeSetNotifier<double>(NamiTabScrollController.page, p);
    }
  }

  void _animateToTarget(int target) {
    if (!mounted || !_pageController.hasClients) return;
    final cur = (_pageController.page ?? widget.currentIndex.toDouble()).round();
    if (cur == target) return;
    _programmaticTarget = target;
    final scale = NamiUxPrefs.motionScale;

    if ((target - cur).abs() > 1) {
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
      final target = widget.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateToTarget(target);
      });
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
          _NamiKeepAliveTabPage(key: ValueKey<int>(i), child: widget.children[i]),
      ],
    );
  }
}

class _NamiShellRootScope extends InheritedWidget {
  final Widget rootChild;

  const _NamiShellRootScope({
    required this.rootChild,
    required super.child,
  });

  static Widget of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_NamiShellRootScope>();
    return scope?.rootChild ?? const SizedBox.shrink();
  }

  @override
  bool updateShouldNotify(covariant _NamiShellRootScope oldWidget) {
    return oldWidget.rootChild != rootChild;
  }
}

class _NamiShellRouteObserver extends NavigatorObserver {
  int _depth = 0;

  void _sync() {
    _namiSafeSetNotifier<bool>(NamiShellNavigator.hasSubPage, _depth > 0);
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

class NamiShellNavigator extends StatefulWidget {
  final Widget child;
  const NamiShellNavigator({super.key, required this.child});

  static _NamiShellNavigatorState? _activeState;
  static final ValueNotifier<bool> hasSubPage = ValueNotifier<bool>(false);

  static NavigatorState? get _nav => _activeState?._navKey.currentState;
  static bool get canPop => _nav?.canPop() ?? false;

  static Future<T?> push<T>(Route<T> route, {BuildContext? fallbackContext}) {
    final nav = _nav;
    if (nav != null) {
      return nav.push<T>(route);
    }
    if (fallbackContext != null) {
      return Navigator.of(fallbackContext).push<T>(route);
    }
    return Future<T?>.value(null);
  }

  static bool maybePop() {
    final nav = _nav;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    return false;
  }

  static void popToRoot() {
    final nav = _nav;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
      _namiSafeSetNotifier<bool>(hasSubPage, false);
    }
  }

  @override
  State<NamiShellNavigator> createState() => _NamiShellNavigatorState();
}

class _NamiShellNavigatorState extends State<NamiShellNavigator> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final _NamiShellRouteObserver _observer = _NamiShellRouteObserver();

  @override
  void initState() {
    super.initState();
    NamiShellNavigator._activeState = this;
  }

  @override
  void dispose() {
    if (NamiShellNavigator._activeState == this) {
      NamiShellNavigator._activeState = null;
      _namiSafeSetNotifier<bool>(NamiShellNavigator.hasSubPage, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: _NamiShellRootScope(
        rootChild: widget.child,
        child: Navigator(
          key: _navKey,
          observers: [_observer],
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (routeCtx, __, ___) => Builder(
              builder: (innerCtx) => _NamiShellRootScope.of(innerCtx),
            ),
          ),
        ),
      ),
    );
  }
}

class NamiExpandablePlayerController {
  static final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  static final ValueNotifier<double> curvedProgress = ValueNotifier<double>(0.0);
  static final ValueNotifier<bool> hasSong = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isLyricsOpen = ValueNotifier<bool>(false);
  static _NamiExpandablePlayerHostState? _host;

  static bool get hasHost => _host != null && _host!.mounted;
  static bool get isExpanded => progress.value > 0.05;

  static void expand() => _host?._expand();
  static void collapse() => _host?._collapse();

  static void safeClose(BuildContext context) {
    if (hasHost && progress.value > 0.01) {
      collapse();
      return;
    }
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

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

/// Zero-Flicker, Zero-Blank 120FPS Permanent In-Tree Expandable Player Host (`v3.0.3`).
/// - Syncs both flying cover art AND `NamiFullArtRectReporter` to `curvedProgress` with an
///   overlapping cross-fade on `[0.94 .. 0.996]` -> mathematically impossible to flash blank!
/// - Renders a clipped mini-bar interior inside `cardRect` on `[0.0 .. 0.26]` so the mini-player
///   never turns into an empty dark box on collapse or expand.
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
  bool _immersiveApplied = false;

  Widget? _cachedCoverWidget;
  String _cachedCoverKey = '';

  static const Curve _expandCurve = _NamiSpringCurve(6.6);
  static const Curve _collapseCurve = _NamiSpringCurve(6.4);

  double _computeCurvedT(double rawT) {
    if (!_useCurve || _dragging) return rawT;
    if (_isReversing) return 1.0 - _collapseCurve.transform(1.0 - rawT);
    return _expandCurve.transform(rawT);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      value: 0.0,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 310),
    )..addListener(_syncProgress);
    NamiExpandablePlayerController._host = this;
    _namiSafeSetNotifier<bool>(NamiExpandablePlayerController.hasSong, widget.hasSong);
  }

  void _syncProgress() {
    final v = _ctrl.value.clamp(0.0, 1.0);
    final curved = _computeCurvedT(v).clamp(0.0, 1.0);
    if ((NamiExpandablePlayerController.progress.value - v).abs() > 0.0005 ||
        v == 0.0 ||
        v == 1.0) {
      _namiSafeSetNotifier<double>(NamiExpandablePlayerController.progress, v);
      _namiSafeSetNotifier<double>(NamiExpandablePlayerController.curvedProgress, curved);
      _namiSafeSetNotifier<double>(NamiMorphPlayerController.progress, curved);
      /* v30_1_immersive */
      if (NamiUxPrefs.immersiveMode) {
        if (curved > 0.88 && !_immersiveApplied) {
          _immersiveApplied = true;
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else if (curved < 0.20 && _immersiveApplied) {
          _immersiveApplied = false;
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      } else if (_immersiveApplied) {
        _immersiveApplied = false;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  @override
  void didUpdateWidget(covariant NamiExpandablePlayerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _namiSafeSetNotifier<bool>(NamiExpandablePlayerController.hasSong, widget.hasSong);
    if (!widget.hasSong && _ctrl.value > 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.hasSong && _ctrl.value > 0.0) {
          _ctrl.value = 0.0;
        }
      });
    }
  }

  @override
  void dispose() {
    if (_immersiveApplied) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (NamiExpandablePlayerController._host == this) {
      NamiExpandablePlayerController._host = null;
      _namiSafeSetNotifier<double>(NamiExpandablePlayerController.progress, 0.0);
      _namiSafeSetNotifier<double>(NamiExpandablePlayerController.curvedProgress, 0.0);
      _namiSafeSetNotifier<double>(NamiMorphPlayerController.progress, 0.0);
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
    final ms = (350 * rem * NamiUxPrefs.motionScale).round().clamp(180, 460);
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
    final ms = (310 * rem * NamiUxPrefs.motionScale).round().clamp(160, 400);
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
      final ms = (310 * rem * NamiUxPrefs.motionScale).round().clamp(140, 360);
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
      final ms = (270 * rem * NamiUxPrefs.motionScale).round().clamp(130, 330);
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

        // 1b. Global non-blocking top library banner & live mutating pill toast
        const NamiTopLibraryBannerOverlay(),
        const NamiLivePillToastOverlay(),

        // 2. Permanent Zero-Flicker 120FPS Expandable Now Playing Layer
        if (mountedFullPlayer != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ctrl,
              child: mountedFullPlayer,
              builder: (ctx, fullChild) {
                final rawT = _ctrl.value.clamp(0.0, 1.0);
                final t = _computeCurvedT(rawT).clamp(0.0, 1.0);

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

                final scrimOpacity = (t * 0.92).clamp(0.0, 0.92);
                final cardRect = Rect.lerp(startRect, fullRect, t)!;
                final cardRadius = ui.lerpDouble(18.0, 0.0, t)!;
                final cardColor = Color.lerp(
                  const Color(0xFF14141E),
                  const Color(0xFF000000),
                  Curves.easeOut.transform(t),
                )!;

                final curArtRect = Rect.lerp(miniArtRect, fullArtRect, t)!;
                final curArtRadius = ui.lerpDouble(10.0, 16.0, t)!;

                // Mini-bar interior stays visible on [0.0 .. 0.28] -> ZERO empty dark box!
                final miniInteriorOpacity = !active
                    ? 0.0
                    : (1.0 - (t / 0.28)).clamp(0.0, 1.0);

                // NowPlayingModal fades cleanly on [0.22 .. 0.72] -> ZERO overlap with mini-bar!
                final fullChildOpacity = !active
                    ? 0.0
                    : ((t - 0.22) / 0.50).clamp(0.0, 1.0);

                // Flying art stays at 1.0 until t=0.96, then dissolves cleanly on [0.96 .. 0.996]
                // while NamiFullArtRectReporter is ALREADY at 1.0 from t=0.94 -> ZERO blank flash!
                final bool lyricsActive = NamiExpandablePlayerController.isLyricsOpen.value;
                final flyingArtOpacity = !active || t >= 0.996
                    ? 0.0
                    : (lyricsActive
                        ? (t <= 0.32 ? (1.0 - (t / 0.32)).clamp(0.0, 1.0) : 0.0)
                        : (t <= 0.96 ? 1.0 : ((0.996 - t) / 0.036).clamp(0.0, 1.0)));

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

                        // Morphing AMOLED card hosting NowPlayingModal + low-t Mini-Bar interior
                        Positioned.fromRect(
                          rect: active ? cardRect : fullRect,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(active ? cardRadius : 0.0),
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
                                  // Full NowPlayingModal
                                  Positioned(
                                    left: active ? -cardRect.left : 0.0,
                                    top: active ? -cardRect.top : 0.0,
                                    width: size.width,
                                    height: size.height,
                                    child: TickerMode(
                                      enabled: active,
                                      child: IgnorePointer(
                                        ignoring: t < 0.94,
                                        child: Opacity(
                                          opacity: fullChildOpacity,
                                          child: Transform.translate(
                                            offset: Offset(0, active ? (1.0 - t) * 28.0 : 0.0),
                                            child: fullChild ?? const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Seamless Mini-Bar interior for low t (0.0 -> 0.28): ZERO blank box!
                                  if (miniInteriorOpacity > 0.01)
                                    Positioned(
                                      left: miniArtSize + 20,
                                      right: 10,
                                      top: 0,
                                      height: startRect.height,
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: miniInteriorOpacity,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      widget.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13.8,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      widget.artist,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11.4,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.white60,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              StreamBuilder<bool>(
                                                stream: widget.isPlayingStream,
                                                initialData: widget.initialPlaying,
                                                builder: (_, snap) {
                                                  final playing = snap.data ?? widget.initialPlaying;
                                                  return Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 21),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withValues(alpha: 0.10),
                                                          shape: BoxShape.circle,
                                                          border: Border.all(color: Colors.white24, width: 0.9),
                                                        ),
                                                        child: Icon(
                                                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 21),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // SINGLE GPU-scaled flying album art (overlaps static cover on [0.94..0.996] -> 0ms blank!)
                        if (flyingArtOpacity > 0.005)
                          Positioned.fromRect(
                            rect: curArtRect,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: flyingArtOpacity,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(curArtRadius),
                                  child: _getCachedCover(widget.trackKey),
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
      valueListenable: NamiExpandablePlayerController.curvedProgress,
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

/// Smoothly scales & fades a tab-specific FAB in 1:1 sync with horizontal PageView swipes.
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
