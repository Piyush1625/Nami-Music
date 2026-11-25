part of '../main.dart';

/// Smooth critically-damped 120Hz spring curve normalized exactly on [0.0, 1.0].
/// Omega ~6.2–6.4 produces Apple Music-style gliding acceleration and cushion settle
/// with zero violent snap-down on collapse.
class _NamiSpringCurve extends Curve {
  final double omega;
  const _NamiSpringCurve([this.omega = 6.4]);

  @override
  double transformInternal(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    final endVal = 1.0 - (1.0 + omega) * math.exp(-omega);
    final val = 1.0 - (1.0 + omega * t) * math.exp(-omega * t);
    return (val / endVal).clamp(0.0, 1.0);
  }
}

/// Shared state for seamless morphing between ANY mini-player and Full Now Playing.
class NamiMorphPlayerController {
  static final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  static NamiMorphNowPlayingRoute<dynamic>? activeRoute;
  static Rect? lastMiniRect;
  static Rect? lastFullArtRect;

  static bool get isMorphActive => activeRoute != null && activeRoute!.isActive;

  static void registerMiniRect(Rect rect) {
    if (rect.width > 40 && rect.height > 20) {
      lastMiniRect = rect;
    }
  }

  static void registerFullArtRect(Rect rect) {
    if (rect.width > 160 && rect.height > 160 && rect.top >= 40) {
      lastFullArtRect = rect;
    }
  }

  static void clearIfMatches(NamiMorphNowPlayingRoute<dynamic> route) {
    if (activeRoute == route) {
      activeRoute = null;
      progress.value = 0.0;
    }
  }
}

/// Lightweight zero-overhead anchor wrapper placed around Now Playing's cover art
/// to record its exact live screen Rect once settled so future morphs align to 0.0px error.
class NamiFullArtRectReporter extends StatefulWidget {
  final Widget child;
  const NamiFullArtRectReporter({super.key, required this.child});

  @override
  State<NamiFullArtRectReporter> createState() => _NamiFullArtRectReporterState();
}

class _NamiFullArtRectReporterState extends State<NamiFullArtRectReporter> {
  final GlobalKey _key = GlobalKey();

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (NamiMorphPlayerController.progress.value < 0.98) return;
      final ro = _key.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.hasSize) {
        final topLeft = ro.localToGlobal(Offset.zero);
        NamiMorphPlayerController.registerFullArtRect(topLeft & ro.size);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant NamiFullArtRectReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    /* v30_2_single_art */
    return KeyedSubtree(
      key: _key,
      child: ValueListenableBuilder<double>(
        valueListenable: NamiExpandablePlayerController.progress,
        child: widget.child,
        builder: (_, p, c) => Opacity(
          opacity: (p >= 0.988 || p <= 0.001) ? 1.0 : 0.0,
          child: c,
        ),
      ),
    );
  }
}

/// 120FPS GPU-composited Spring-Physics Morph Route (Mini-Player <-> Full Now Playing):
/// - Disables competing Flutter Hero shuttles (`HeroMode(enabled: false)`) -> zero double-art!
/// - Keeps NowPlayingModal at fixed full-screen dimensions inside RepaintBoundary -> zero relayout jank!
/// - Caches one single full-res cover texture per track -> zero 120fps disk-decode thrashing!
/// - Uses native TransitionRoute forward/reverse & animateBack(0.0) -> zero stuck/zombie routes!
class NamiMorphNowPlayingRoute<T> extends PageRoute<T> {
  final Rect? miniRect;
  final bool startFromDrag;
  final String title;
  final String artist;
  final String Function()? titleGetter;
  final String Function()? artistGetter;
  final String Function()? trackKeyGetter;
  final Widget Function(double size, double radius) coverBuilder;
  final Stream<bool> isPlayingStream;
  final bool initialPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final WidgetBuilder fullPageBuilder;

  bool _dragging = false;
  bool _fromInteractiveDrag = false;
  bool _useCurve = true;
  bool _popping = false;

  Widget? _cachedCoverWidget;
  String _cachedCoverKey = '';

  static const Curve _expandCurve = _NamiSpringCurve(6.4);
  static const Curve _collapseCurve = _NamiSpringCurve(6.2);

  NamiMorphNowPlayingRoute({
    required this.miniRect,
    required this.startFromDrag,
    required this.title,
    required this.artist,
    this.titleGetter,
    this.artistGetter,
    this.trackKeyGetter,
    required this.coverBuilder,
    required this.isPlayingStream,
    required this.initialPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.fullPageBuilder,
  });

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration {
    final scale = NamiUxPrefs.motionScale;
    return Duration(milliseconds: (390 * scale).round().clamp(240, 540));
  }

  @override
  Duration get reverseTransitionDuration {
    final scale = NamiUxPrefs.motionScale;
    return Duration(milliseconds: (350 * scale).round().clamp(220, 480));
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
              child: coverBuilder(360.0, 0.0),
            ),
          ),
        ),
      );
    }
    return _cachedCoverWidget!;
  }

  void _syncProgress() {
    final v = controller?.value ?? 0.0;
    if ((NamiMorphPlayerController.progress.value - v).abs() > 0.0005 || v == 0.0 || v == 1.0) {
      NamiMorphPlayerController.progress.value = v.clamp(0.0, 1.0);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      NamiMorphPlayerController.clearIfMatches(this);
    } else if (status == AnimationStatus.completed && !_dragging) {
      _useCurve = true;
    }
  }

  @override
  void install() {
    super.install();
    NamiMorphPlayerController.activeRoute = this;
    controller?.addListener(_syncProgress);
    controller?.addStatusListener(_handleStatus);
  }

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    if (startFromDrag && controller != null) {
      controller!.stop();
      _useCurve = false;
      _dragging = true;
      navigator?.didStartUserGesture();
      controller!.value = 0.002;
      _syncProgress();
    }
    return future;
  }

  @override
  bool didPop(T? result) {
    _popping = true;
    if (_dragging) {
      _dragging = false;
      navigator?.didStopUserGesture();
    }
    final curVal = controller?.value ?? 0.0;
    final res = super.didPop(result);
    if (_fromInteractiveDrag && controller != null && curVal > 0.001) {
      final scale = NamiUxPrefs.motionScale;
      final ms = (330 * curVal * scale).round().clamp(160, 380);
      controller!.animateBack(
        0.0,
        duration: Duration(milliseconds: ms),
        curve: _collapseCurve,
      );
    }
    return res;
  }

  @override
  void dispose() {
    if (_dragging) {
      _dragging = false;
      navigator?.didStopUserGesture();
    }
    controller?.removeListener(_syncProgress);
    controller?.removeStatusListener(_handleStatus);
    NamiMorphPlayerController.clearIfMatches(this);
    _cachedCoverWidget = null;
    super.dispose();
  }

  void beginInteractiveDismiss() {
    if (controller == null || _dragging || _popping || !isActive) return;
    _dragging = true;
    _useCurve = false;
    _fromInteractiveDrag = false;
    controller!.stop();
    navigator?.didStartUserGesture();
  }

  void updateInteractiveDrag(double deltaProgress) {
    if (controller == null || _popping || !isActive) return;
    if (!_dragging) {
      _dragging = true;
      _useCurve = false;
      navigator?.didStartUserGesture();
    }
    controller!.stop();
    controller!.value = (controller!.value + deltaProgress).clamp(0.002, 1.0);
  }

  void endInteractiveDrag({
    required double velocityPerSec,
    required bool isOpeningDrag,
  }) {
    final ctrl = controller;
    if (ctrl == null || _popping || !isActive) return;
    if (_dragging) {
      _dragging = false;
      navigator?.didStopUserGesture();
    }
    final cur = ctrl.value;
    final bool shouldOpen = isOpeningDrag
        ? (cur > 0.20 || velocityPerSec > 0.65)
        : !(cur < 0.78 || velocityPerSec < -0.65);

    if (shouldOpen) {
      final rem = (1.0 - cur).clamp(0.10, 1.0);
      final ms = (360 * rem * NamiUxPrefs.motionScale).round().clamp(160, 420);
      ctrl.animateTo(
        1.0,
        duration: Duration(milliseconds: ms),
        curve: _expandCurve,
      ).whenComplete(() {
        if (!_dragging && isActive) {
          _useCurve = true;
        }
      });
    } else {
      _fromInteractiveDrag = true;
      _useCurve = false;
      navigator?.pop();
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Wrap in HeroMode(enabled: false) + RepaintBoundary so Flutter NEVER runs
    // a competing Hero flight shuttle and GPU composites NowPlayingModal as 1 layer!
    return HeroMode(
      enabled: false,
      child: RepaintBoundary(
        child: fullPageBuilder(context),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final pad = mq.padding;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final startRect = miniRect ??
        NamiMorphPlayerController.lastMiniRect ??
        Rect.fromLTWH(10, size.height - pad.bottom - 140, size.width - 20, 64);

    // Pre-compute pixel-accurate endpoints once per layout pass
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

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (ctx, fullChild) {
        final rawT = animation.value.clamp(0.0, 1.0);
        final double t;
        if (!_useCurve || _dragging) {
          t = rawT;
        } else if (animation.status == AnimationStatus.reverse) {
          t = 1.0 - _collapseCurve.transform(1.0 - rawT);
        } else {
          t = _expandCurve.transform(rawT);
        }

        final liveTitle = titleGetter != null ? titleGetter!() : title;
        final liveArtist = artistGetter != null ? artistGetter!() : artist;
        final liveKey = trackKeyGetter != null ? trackKeyGetter!() : '$liveTitle|$liveArtist';
        final cachedCover = _getCachedCover(liveKey);

        // 1. Background dim scrim over underlying library page
        final scrimOpacity = (t * 0.92).clamp(0.0, 0.92);

        // 2. Continuously morphing outer card clip & surface color
        final cardRect = Rect.lerp(startRect, fullRect, t)!;
        final cardRadius = ui.lerpDouble(18.0, 0.0, t)!;
        final cardColor = Color.lerp(
          const Color(0xFF14141E),
          const Color(0xFF000000),
          Curves.easeOut.transform(t),
        )!;

        // 3. Interpolated shared element rects (GPU-scaled single texture -> 120fps)
        final curArtRect = Rect.lerp(miniArtRect, fullArtRect, t)!;
        final curArtRadius = ui.lerpDouble(10.0, 16.0, t)!;
        final curInfoRect = Rect.lerp(miniInfoRect, fullInfoRect, t)!;
        final titleSize = ui.lerpDouble(13.8, 20.5, t)!;
        final artistSize = ui.lerpDouble(11.5, 13.5, t)!;

        final curCtrlCenter = Offset.lerp(miniCtrlCenter, fullCtrlCenter, t)!;
        final playBtnSize = ui.lerpDouble(36.0, 58.0, t)!;
        final skipIconSize = ui.lerpDouble(20.0, 30.0, t)!;
        final ctrlGap = ui.lerpDouble(2.0, 24.0, t)!;

        // Tight, aligned cross-fade: fullChild is ALWAYS mounted at fixed full-screen size
        // (RenderOpacity skips paint at 0.0 while keeping layout cached -> zero mid-flight stutter!)
        final fullChildOpacity = t >= 0.985
            ? 1.0
            : ((t - 0.66) / 0.28).clamp(0.0, 1.0);
        final sharedOverlayOpacity = t >= 0.985
            ? 0.0
            : (1.0 - ((t - 0.84) / 0.14).clamp(0.0, 1.0));

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Underlying library dim scrim
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: t < 0.05,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: scrimOpacity),
                  ),
                ),
              ),

              // Morphing container clip around fixed full-screen NowPlayingModal (ZERO relayout!)
              Positioned.fromRect(
                rect: cardRect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: t < 0.94
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.10 * (1.0 - t)),
                              width: 0.9,
                            )
                          : null,
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: -cardRect.left,
                          top: -cardRect.top,
                          width: size.width,
                          height: size.height,
                          child: IgnorePointer(
                            ignoring: t < 0.95,
                            child: Opacity(
                              opacity: fullChildOpacity,
                              child: fullChild,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Single crisp GPU-scaled shared-element morph overlay (Art + Title/Artist + Controls)
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
                              child: cachedCover,
                            ),
                          ),
                          Positioned.fromRect(
                            rect: curInfoRect,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  liveTitle,
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
                                  liveArtist,
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
                              stream: isPlayingStream,
                              initialData: initialPlaying,
                              builder: (_, snap) {
                                final playing = snap.data ?? initialPlaying;
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
        );
      },
    );
  }
}

/// Wraps ANY mini-player across Nami (main tabs + detail floating dock):
/// - Disables HeroMode so Flutter never runs a competing Hero flight
/// - Listener captures exact live Rect on pointer down
/// - 1:1 Vertical Drag-UP & Tap morphing into Full Now Playing
/// - 1:1 Horizontal Elastic Spring Track Shifting with smooth spring slide-in
class NamiSpringMiniPlayerWrap extends StatefulWidget {
  final Widget child;
  final String? trackKey;
  final VoidCallback onOpenTap;
  final void Function(Rect rect) onStartDragOpen;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const NamiSpringMiniPlayerWrap({
    super.key,
    required this.child,
    required this.trackKey,
    required this.onOpenTap,
    required this.onStartDragOpen,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<NamiSpringMiniPlayerWrap> createState() => _NamiSpringMiniPlayerWrapState();
}

class _NamiSpringMiniPlayerWrapState extends State<NamiSpringMiniPlayerWrap>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boxKey = GlobalKey();
  late final AnimationController _hSpring;
  double _dx = 0.0;
  bool _openingDrag = false;
  int _lastShiftDir = 0;

  static const SpringDescription _hSpringDesc = SpringDescription(
    mass: 1.0,
    stiffness: 370.0,
    damping: 26.5,
  );

  @override
  void initState() {
    super.initState();
    _hSpring = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _dx = _hSpring.value);
      });
  }

  @override
  void didUpdateWidget(covariant NamiSpringMiniPlayerWrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackKey != oldWidget.trackKey && widget.trackKey != null && _lastShiftDir != 0) {
      final startOffset = _lastShiftDir < 0 ? 74.0 : -74.0;
      _lastShiftDir = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hSpring.stop();
        _dx = startOffset;
        _hSpring.animateWith(SpringSimulation(_hSpringDesc, startOffset, 0.0, 0.0));
      });
    }
  }

  @override
  void dispose() {
    _hSpring.dispose();
    super.dispose();
  }

  Rect? _measureRect() {
    final ro = _boxKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      final topLeft = ro.localToGlobal(Offset.zero);
      final r = topLeft & ro.size;
      NamiMorphPlayerController.registerMiniRect(r);
      return r;
    }
    return NamiMorphPlayerController.lastMiniRect;
  }

  /* v29_host_drag_up */
  void _onVerticalDragStart(DragStartDetails d) {
    final rect = _measureRect();
    if (rect == null) return;
    if (NamiExpandablePlayerController.hasHost) {
      if (NamiExpandablePlayerController.isExpanded) return;
      _openingDrag = true;
      NamiExpandablePlayerController.beginDrag(isOpening: true);
      return;
    }
    if (NamiMorphPlayerController.isMorphActive) return;
    _openingDrag = true;
    widget.onStartDragOpen(rect);
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (!_openingDrag) return;
    final h = MediaQuery.sizeOf(context).height;
    final dragRange = (h * 0.78).clamp(320.0, 760.0);
    if (NamiExpandablePlayerController.hasHost) {
      NamiExpandablePlayerController.updateDrag(-d.delta.dy / dragRange);
      return;
    }
    final route = NamiMorphPlayerController.activeRoute;
    if (route == null || !route.isActive) return;
    route.updateInteractiveDrag(-d.delta.dy / dragRange);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (!_openingDrag) return;
    _openingDrag = false;
    final h = MediaQuery.sizeOf(context).height;
    final dragRange = (h * 0.78).clamp(320.0, 760.0);
    final vel = -(d.primaryVelocity ?? 0.0) / dragRange;
    if (NamiExpandablePlayerController.hasHost) {
      NamiExpandablePlayerController.endDrag(velocityPerSec: vel, isOpeningDrag: true);
      return;
    }
    final route = NamiMorphPlayerController.activeRoute;
    if (route == null || !route.isActive) return;
    route.endInteractiveDrag(velocityPerSec: vel, isOpeningDrag: true);
  }

  void _onVerticalDragCancel() {
    if (!_openingDrag) return;
    _openingDrag = false;
    if (NamiExpandablePlayerController.hasHost) {
      NamiExpandablePlayerController.endDrag(velocityPerSec: -0.5, isOpeningDrag: true);
      return;
    }
    final route = NamiMorphPlayerController.activeRoute;
    if (route != null && route.isActive) {
      route.endInteractiveDrag(velocityPerSec: -0.5, isOpeningDrag: true);
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    _hSpring.stop();
    final resistance = _dx.abs() > 75.0 ? 0.35 : 0.88;
    setState(() {
      _dx = (_dx + d.delta.dx * resistance).clamp(-130.0, 130.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final vx = d.primaryVelocity ?? 0.0;
    if (_dx < -58.0 || vx < -340.0) {
      NamiUxPrefs.hapticLight();
      _lastShiftDir = -1;
      widget.onNext();
      _hSpring.animateWith(SpringSimulation(_hSpringDesc, _dx, 0.0, vx / 1200.0));
      return;
    }
    if (_dx > 58.0 || vx > 340.0) {
      NamiUxPrefs.hapticLight();
      _lastShiftDir = 1;
      widget.onPrev();
      _hSpring.animateWith(SpringSimulation(_hSpringDesc, _dx, 0.0, vx / 1200.0));
      return;
    }
    _hSpring.animateWith(SpringSimulation(_hSpringDesc, _dx, 0.0, vx / 1200.0));
  }

  @override
  Widget build(BuildContext context) {
    final dragNorm = (_dx.abs() / 90.0).clamp(0.0, 1.0);
    final scale = 1.0 - (dragNorm * 0.025);

    return HeroMode(
      enabled: false,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _measureRect(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            _measureRect();
            NamiUxPrefs.hapticLight();
            widget.onOpenTap();
          },
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onVerticalDragCancel: _onVerticalDragCancel,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: () {
            if (_dx != 0.0) {
              _hSpring.animateWith(SpringSimulation(_hSpringDesc, _dx, 0.0, 0.0));
            }
          },
          child: KeyedSubtree(
            key: _boxKey,
            child: ValueListenableBuilder<double>(
              valueListenable: NamiMorphPlayerController.progress,
              builder: (_, morphProgress, child) {
                final hidden = morphProgress > 0.005;
                return Opacity(
                  opacity: hidden ? 0.0 : 1.0,
                  child: child,
                );
              },
              child: Transform.translate(
                offset: Offset(_dx, 0),
                child: Transform.scale(
                  scale: scale,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1:1 Horizontal Elastic Spring Swipe wrapper for Now Playing album art
class NamiSpringCoverSwipe extends StatefulWidget {
  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const NamiSpringCoverSwipe({
    super.key,
    required this.child,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<NamiSpringCoverSwipe> createState() => _NamiSpringCoverSwipeState();
}

class _NamiSpringCoverSwipeState extends State<NamiSpringCoverSwipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _dx = 0.0;

  static const SpringDescription _coverSpring = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 25.0,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _dx = _ctrl.value);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final norm = (_dx.abs() / (w * 0.45)).clamp(0.0, 1.0);
    final scale = 1.0 - (norm * 0.045);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        _ctrl.stop();
        final resist = _dx.abs() > w * 0.35 ? 0.35 : 0.92;
        setState(() {
          _dx = (_dx + d.delta.dx * resist).clamp(-w * 0.55, w * 0.55);
        });
      },
      onHorizontalDragEnd: (d) {
        final vx = d.primaryVelocity ?? 0.0;
        if (_dx < -w * 0.22 || vx < -460.0) {
          NamiUxPrefs.hapticLight();
          widget.onNext();
          _ctrl.animateWith(SpringSimulation(_coverSpring, 56.0, 0.0, 0.0));
          return;
        }
        if (_dx > w * 0.22 || vx > 460.0) {
          NamiUxPrefs.hapticLight();
          widget.onPrev();
          _ctrl.animateWith(SpringSimulation(_coverSpring, -56.0, 0.0, 0.0));
          return;
        }
        _ctrl.animateWith(SpringSimulation(_coverSpring, _dx, 0.0, vx / 1200.0));
      },
      onHorizontalDragCancel: () {
        if (_dx != 0.0) {
          _ctrl.animateWith(SpringSimulation(_coverSpring, _dx, 0.0, 0.0));
        }
      },
      child: Transform.translate(
        offset: Offset(_dx, 0),
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: (1.0 - norm * 0.18).clamp(0.75, 1.0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
