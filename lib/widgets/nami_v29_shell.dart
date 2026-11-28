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
    /* v31_1_prewarm */
    if (widget.hasSong && widget.trackKey.isNotEmpty && widget.trackKey != _cachedCoverKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && widget.hasSong) _getCachedCover(widget.trackKey); });
    }
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
    return ValueListenableBuilder<NamiYtTrack?>(
      valueListenable: NamiYoutubePlaybackBridge.activeYtTrack,
      builder: (context, ytActive, _) => ValueListenableBuilder<NamiActiveSource>(
        valueListenable: NamiAudioArbitrator.activeSource,
        builder: (context, activeSrc, _) => ValueListenableBuilder<bool>(
          valueListenable: NamiYtVideoBridge.isPipMode,
          builder: (context, isPip, _) => ValueListenableBuilder<bool>(
            valueListenable: NamiAudioArbitrator.isYoutubeTabActive,
            builder: (context, onYtTab, _) {
              final bool showDockedYt =
                  ytActive != null && !isPip && (onYtTab || activeSrc == NamiActiveSource.youtube);
              final bool showPipYt = ytActive != null && isPip && _ctrl.value < 0.15;
              final bool showLocalPlayer = widget.hasSong && !onYtTab && !showDockedYt;

    final mq = MediaQuery.of(context);
    final size = mq.size;
    final pad = mq.padding;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final Widget? mountedFullPlayer = (showLocalPlayer && widget.fullPageBuilder != null)
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
                /* v31_2_no_collapse_overlap */
                final miniInteriorOpacity = !active
                    ? 0.0
                    : (1.0 - (t / 0.16)).clamp(0.0, 1.0);

                // NowPlayingModal fades cleanly on [0.22 .. 0.72] -> ZERO overlap with mini-bar!
                final fullChildOpacity = !active
                    ? 0.0
                    : ((t - 0.56) / 0.34).clamp(0.0, 1.0);

                // Flying art stays at 1.0 until t=0.96, then dissolves cleanly on [0.96 .. 0.996]
                // while NamiFullArtRectReporter is ALREADY at 1.0 from t=0.94 -> ZERO blank flash!
                final bool lyricsActive = NamiExpandablePlayerController.isLyricsOpen.value;
                final flyingArtOpacity = !active || t >= 0.985
                    ? 0.0
                    : (lyricsActive ? (t <= 0.28 ? (1.0 - (t / 0.28)).clamp(0.0, 1.0) : 0.0) : 1.0);

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
                                          child: RepaintBoundary(child: fullChild ?? const SizedBox.shrink()),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Seamless Mini-Bar interior for low t (0.0 -> 0.28): ZERO blank box!
                                  if (miniInteriorOpacity > 0.01)
                                    Positioned(
                                      left: ((curArtRect.right - cardRect.left) + 12.0).clamp(miniArtSize + 20.0, size.width - 130.0),
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
                                                      const NamiCustomIcon(NamiCustomIcons.nextTrack, size: 21, flipHorizontal: true, opacity: 0.78),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withValues(alpha: 0.10),
                                                          shape: BoxShape.circle,
                                                          border: Border.all(color: Colors.white24, width: 0.9),
                                                        ),
                                                        child: NamiCustomIcon(playing ? NamiCustomIcons.pause : NamiCustomIcons.play, size: 20),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const NamiCustomIcon(NamiCustomIcons.nextTrack, size: 21, opacity: 0.78),
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
      
        if (showDockedYt)
          NamiYoutubeMiniPlayerBar(
            track: ytActive,
            bottomInset: pad.bottom + 64.0,
            pipMode: false,
          ),
        if (showPipYt)
          NamiYoutubeMiniPlayerBar(
            track: ytActive,
            bottomInset: pad.bottom + 64.0,
            pipMode: true,
          ),
      ],
    );
  
            },
          ),
        ),
      ),
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

/// Unified Video-First Nami YouTube Mini-Player v3 (`v3.7.0`):
/// - Driven 100% by Media3 ExoPlayer (`NamiYtVideoBridge`) — plays live 120Hz GPU video
///   with full audio in both Docked Pill (`106x58`) & Draggable Floating PiP (`208x118`)!
/// - Zero Audio-Only fallback clutter; strictly arbitrated with Offline Nami Library.
class NamiYoutubeMiniPlayerBar extends StatefulWidget {
  final NamiYtTrack track;
  final double bottomInset;
  final bool pipMode;

  const NamiYoutubeMiniPlayerBar({
    super.key,
    required this.track,
    required this.bottomInset,
    this.pipMode = false,
  });

  @override
  State<NamiYoutubeMiniPlayerBar> createState() => _NamiYoutubeMiniPlayerBarState();
}

class _NamiYoutubeMiniPlayerBarState extends State<NamiYoutubeMiniPlayerBar> {
  double? _pipLeft;
  double? _pipTop;
  bool _pipDragging = false;
  bool _pipShowControls = true;
  Timer? _pipHideTimer;

  static const double _pipW = 208.0;
  static const double _pipH = 118.0;

  @override
  void dispose() {
    _pipHideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHidePipControls() {
    _pipHideTimer?.cancel();
    _pipHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _pipShowControls) {
        setState(() => _pipShowControls = false);
      }
    });
  }

  String _fmtMiniDur(int ms) {
    final s = (ms ~/ 1000).clamp(0, 86400);
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayPause() async {
    NamiUxPrefs.hapticLight();
    await NamiYtVideoBridge.togglePlayPause();
  }

  void _closeYoutube() {
    NamiUxPrefs.hapticLight();
    NamiYtVideoBridge.stopVideo();
    NamiYoutubePlaybackBridge.clearActiveYoutubeTrack();
    NamiAudioArbitrator.releaseYoutube();
  }

  Widget _buildFloatingPip(BuildContext context, Color accent, String qual) {
    final mq = MediaQuery.of(context);
    final sz = mq.size;
    final pad = mq.padding;
    final minX = 10.0;
    final maxX = (sz.width - _pipW - 10.0).clamp(minX, sz.width);
    final minY = pad.top + 64.0;
    final maxY = (sz.height - widget.bottomInset - _pipH - 12.0).clamp(minY, sz.height - _pipH);

    final left = (_pipLeft ?? maxX).clamp(minX, maxX);
    final top = (_pipTop ?? maxY).clamp(minY, maxY);

    return AnimatedPositioned(
      duration: _pipDragging ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: _pipW,
      height: _pipH,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanStart: (_) {
            setState(() {
              _pipDragging = true;
              _pipLeft = left;
              _pipTop = top;
            });
          },
          onPanUpdate: (d) {
            setState(() {
              _pipLeft = ((_pipLeft ?? left) + d.delta.dx).clamp(minX, maxX);
              _pipTop = ((_pipTop ?? top) + d.delta.dy).clamp(minY, maxY);
            });
          },
          onPanEnd: (_) {
            final curX = _pipLeft ?? left;
            final curY = _pipTop ?? top;
            final snapX = (curX + _pipW / 2) < (sz.width / 2) ? minX : maxX;
            final snapY = curY.clamp(minY, maxY);
            NamiUxPrefs.hapticLight();
            setState(() {
              _pipDragging = false;
              _pipLeft = snapX;
              _pipTop = snapY;
            });
          },
          onTap: () {
            setState(() => _pipShowControls = !_pipShowControls);
            if (_pipShowControls) _scheduleHidePipControls();
          },
          onDoubleTap: () {
            NamiUxPrefs.hapticLight();
            _namiSafeSetNotifier<bool>(NamiYtVideoBridge.isPipMode, false);
            openNamiYoutubeWatchScreen(context, widget.track);
          },
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF07070B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accent.withValues(alpha: 0.58),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.82),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.track.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF14141E),
                    child: const Icon(Icons.ondemand_video_rounded, color: Colors.white38, size: 32),
                  ), gaplessPlayback: true,
                ),
                if (NamiUxPrefs.ytMiniPlayerVideo)
                  const NamiYtGpuVideoSurface(fit: BoxFit.cover),

                // Compact Tap-to-Reveal PiP Overlay
                AnimatedOpacity(
                  opacity: _pipShowControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  child: IgnorePointer(
                    ignoring: !_pipShowControls,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.68),
                            Colors.black.withValues(alpha: 0.22),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 4, 4, 0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    NamiUxPrefs.hapticLight();
                                    _namiSafeSetNotifier<bool>(NamiYtVideoBridge.isPipMode, false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.call_received_rounded, color: Colors.white, size: 15),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.62),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    qual.toUpperCase(),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 8.6,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    NamiUxPrefs.hapticLight();
                                    _namiSafeSetNotifier<bool>(NamiYtVideoBridge.isPipMode, false);
                                    openNamiYoutubeWatchScreen(context, widget.track);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.open_in_full_rounded, color: Colors.white, size: 15),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _closeYoutube,
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: NamiYtVideoBridge.isPlaying,
                                builder: (_, playing, __) => GestureDetector(
                                  onTap: _togglePlayPause,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.64),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white30),
                                    ),
                                    child: NamiCustomIcon(playing ? NamiCustomIcons.pause : NamiCustomIcons.play, size: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  NamiUxPrefs.hapticLight();
                                  NamiYoutubePlaybackBridge.playNextInRadioQueue();
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const NamiCustomIcon(NamiCustomIcons.nextTrack, size: 18),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 5),
                            child: Text(
                              widget.track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2.6,
                  child: ValueListenableBuilder<int>(
                    valueListenable: NamiYtVideoBridge.positionMs,
                    builder: (_, posMs, __) {
                      final durMs = (NamiYtVideoBridge.durationMs.value > 0
                              ? NamiYtVideoBridge.durationMs.value
                              : widget.track.duration.inMilliseconds)
                          .clamp(1, 86400000);
                      return LinearProgressIndicator(
                        value: (posMs / durMs).clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<String>(
      valueListenable: NamiYtVideoBridge.selectedQuality,
      builder: (_, qual, __) {
        if (widget.pipMode) {
          return _buildFloatingPip(context, accent, qual);
        }

        return Positioned(
          left: 8,
          right: 8,
          bottom: widget.bottomInset,
          height: 72,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                NamiUxPrefs.hapticLight();
                openNamiYoutubeWatchScreen(context, widget.track);
              },
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -220) {
                  NamiUxPrefs.hapticLight();
                  openNamiYoutubeWatchScreen(context, widget.track);
                }
              },
              onHorizontalDragEnd: (d) {
                final vx = d.primaryVelocity ?? 0;
                if (vx < -260) {
                  NamiUxPrefs.hapticLight();
                  NamiYoutubePlaybackBridge.playNextInRadioQueue();
                } else if (vx > 260) {
                  NamiUxPrefs.hapticLight();
                  NamiYoutubePlaybackBridge.playPrevInRadioQueue();
                }
              },
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF07070B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.42),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.78),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(7, 6, 4, 4),
                        child: Row(
                          children: [
                            // Live 120Hz GPU Video Surface (`106x58`)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: SizedBox(
                                width: 106,
                                height: 58,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      widget.track.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF181822),
                                        child: const Icon(Icons.ondemand_video_rounded, color: Colors.white38, size: 22),
                                      ), gaplessPlayback: true,
                                    ),
                                    if (NamiUxPrefs.ytMiniPlayerVideo)
                                      const IgnorePointer(
                                        child: NamiYtGpuVideoSurface(fit: BoxFit.cover),
                                      ),
                                    Positioned(
                                      left: 4,
                                      bottom: 3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.78),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          qual.toUpperCase(),
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 8.2,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.2,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2.5),
                                  ValueListenableBuilder<int>(
                                    valueListenable: NamiYtVideoBridge.positionMs,
                                    builder: (_, posMs, __) {
                                      final durMs = NamiYtVideoBridge.durationMs.value > 0
                                          ? NamiYtVideoBridge.durationMs.value
                                          : widget.track.duration.inMilliseconds;
                                      final timeStr = durMs > 0
                                          ? '${_fmtMiniDur(posMs)} / ${_fmtMiniDur(durMs)}'
                                          : _fmtMiniDur(posMs);
                                      return Text(
                                        '${widget.track.artist} • $timeStr',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                              tooltip: 'Pop out Floating PiP',
                              icon: Icon(Icons.picture_in_picture_alt_rounded, color: accent, size: 18),
                              onPressed: () {
                                NamiUxPrefs.hapticLight();
                                _namiSafeSetNotifier<bool>(NamiYtVideoBridge.isPipMode, true);
                                _scheduleHidePipControls();
                              },
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: NamiYtVideoBridge.isPlaying,
                              builder: (_, playing, __) => GestureDetector(
                                onTap: _togglePlayPause,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.13),
                                    shape: BoxShape.circle,
                                  ),
                                  child: NamiCustomIcon(playing ? NamiCustomIcons.pause : NamiCustomIcons.play, size: 22),
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 36),
                              icon: const NamiCustomIcon(NamiCustomIcons.nextTrack, size: 21, opacity: 0.78),
                              onPressed: () {
                                NamiUxPrefs.hapticLight();
                                NamiYoutubePlaybackBridge.playNextInRadioQueue();
                              },
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
                              tooltip: 'Close YouTube Player',
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                              onPressed: _closeYoutube,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: NamiYtVideoBridge.positionMs,
                      builder: (_, posMs, __) {
                        final durMs = (NamiYtVideoBridge.durationMs.value > 0
                                ? NamiYtVideoBridge.durationMs.value
                                : widget.track.duration.inMilliseconds)
                            .clamp(1, 86400000);
                        return SizedBox(
                          height: 2.6,
                          width: double.infinity,
                          child: LinearProgressIndicator(
                            value: (posMs / durMs).clamp(0.0, 1.0),
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}




