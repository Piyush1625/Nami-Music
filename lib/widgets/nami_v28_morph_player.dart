part of '../main.dart';

/// Tracks the currently active morphing Now Playing route & last-known mini-player rect
/// so every screen across Nami morphs seamlessly from/to the exact mini-player bounds.
class NamiMorphPlayerController {
  static final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  static NamiMorphNowPlayingRoute<dynamic>? activeRoute;
  static Rect? lastMiniRect;

  static bool get isMorphActive => activeRoute != null;

  static void registerMiniRect(Rect rect) {
    if (rect.width > 40 && rect.height > 20) {
      lastMiniRect = rect;
    }
  }
}

/// Custom transparent 120Hz spring-physics PageRoute that continuously morphs
/// the mini-player container, album art, title/artist info, and transport controls
/// into the full-screen Now Playing view and back (1:1 interactive drag + tap).
class NamiMorphNowPlayingRoute<T> extends PageRoute<T> {
  final Rect? miniRect;
  final bool startFromDrag;
  final String title;
  final String artist;
  final Widget Function(double size, double radius) coverBuilder;
  final Stream<bool> isPlayingStream;
  final bool initialPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final WidgetBuilder fullPageBuilder;

  bool _dragging = false;
  bool _closingViaDrag = false;

  // Critically-cushioned 120Hz spring: silky velocity preservation without harsh clamping
  static const SpringDescription _expandSpring = SpringDescription(
    mass: 1.0,
    stiffness: 350.0,
    damping: 35.5,
  );
  static const SpringDescription _collapseSpring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 38.0,
  );

  NamiMorphNowPlayingRoute({
    required this.miniRect,
    required this.startFromDrag,
    required this.title,
    required this.artist,
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
    return Duration(milliseconds: (420 * scale).round().clamp(240, 620));
  }

  @override
  Duration get reverseTransitionDuration {
    final scale = NamiUxPrefs.motionScale;
    return Duration(milliseconds: (360 * scale).round().clamp(210, 540));
  }

  void _syncProgress() {
    final v = controller?.value ?? 0.0;
    if ((NamiMorphPlayerController.progress.value - v).abs() > 0.0005 || v == 0.0 || v == 1.0) {
      NamiMorphPlayerController.progress.value = v.clamp(0.0, 1.0);
    }
  }

  @override
  void install() {
    super.install();
    NamiMorphPlayerController.activeRoute = this;
    controller?.addListener(_syncProgress);
  }

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    if (controller != null) {
      if (startFromDrag) {
        controller!.stop();
        _dragging = true;
        navigator?.didStartUserGesture();
        controller!.value = 0.002;
        _syncProgress();
      } else {
        final sim = SpringSimulation(_expandSpring, 0.0, 1.0, 1.15);
        controller!.animateWith(sim);
      }
    }
    return future;
  }

  @override
  bool didPop(T? result) {
    final curVal = controller?.value ?? 0.0;
    final res = super.didPop(result);
    if (controller != null && !_closingViaDrag && curVal > 0.01) {
      final sim = SpringSimulation(_collapseSpring, curVal, 0.0, -1.15);
      controller!.animateWith(sim);
    }
    return res;
  }

  @override
  void dispose() {
    controller?.removeListener(_syncProgress);
    if (NamiMorphPlayerController.activeRoute == this) {
      NamiMorphPlayerController.activeRoute = null;
      NamiMorphPlayerController.progress.value = 0.0;
    }
    super.dispose();
  }

  /// Begin a 1:1 downward drag directly from the expanded Now Playing screen
  void beginInteractiveDismiss() {
    if (controller == null || _dragging) return;
    _dragging = true;
    _closingViaDrag = false;
    controller!.stop();
    navigator?.didStartUserGesture();
  }

  /// Scrub morph progress 1:1 (`deltaProgress > 0` expands, `< 0` collapses)
  void updateInteractiveDrag(double deltaProgress) {
    if (controller == null) return;
    if (!_dragging) {
      _dragging = true;
      navigator?.didStartUserGesture();
    }
    controller!.stop();
    controller!.value = (controller!.value + deltaProgress).clamp(0.001, 1.0);
  }

  /// Release drag and settle with velocity-preserving 120Hz SpringSimulation
  void endInteractiveDrag({
    required double velocityPerSec,
    required bool isOpeningDrag,
  }) {
    final ctrl = controller;
    if (ctrl == null) return;
    if (_dragging) {
      _dragging = false;
      navigator?.didStopUserGesture();
    }
    final cur = ctrl.value;
    final bool shouldOpen = isOpeningDrag
        ? (cur > 0.20 || velocityPerSec > 0.65)
        : !(cur < 0.78 || velocityPerSec < -0.65);

    if (shouldOpen) {
      final sim = SpringSimulation(
        _expandSpring,
        cur,
        1.0,
        velocityPerSec.clamp(-4.0, 6.0),
      );
      ctrl.animateWith(sim);
    } else {
      _closingViaDrag = true;
      final sim = SpringSimulation(
        _collapseSpring,
        cur,
        0.0,
        velocityPerSec.clamp(-6.0, 4.0),
      );
      ctrl.animateWith(sim).whenComplete(() {
        if (isActive && (controller?.value ?? 0.0) <= 0.02) {
          controller?.value = 0.0;
          navigator?.pop();
        }
      });
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return fullPageBuilder(context);
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

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (ctx, fullChild) {
        final t = animation.value.clamp(0.0, 1.0);
        final accent = Theme.of(ctx).colorScheme.primary;

        // 1. Background dim scrim over underlying library page
        final scrimOpacity = (t * 0.90).clamp(0.0, 0.90);

        // 2. Continuously morphing outer sheet bounds & corner radius
        final cardRect = Rect.lerp(startRect, fullRect, t)!;
        final cardRadius = ui.lerpDouble(18.0, 0.0, t)!;
        final cardColor = Color.lerp(
          const Color(0xFF14141E),
          const Color(0xFF000000),
          Curves.easeOut.transform(t),
        )!;

        // 3. Shared element geometries (Start = mini-player bar -> End = Now Playing)
        const miniArtSize = 46.0;
        final miniArtRect = Rect.fromLTWH(
          startRect.left + 9,
          startRect.top + (startRect.height - miniArtSize) / 2,
          miniArtSize,
          miniArtSize,
        );
        final fullArtSize = (size.width - 48).clamp(210.0, size.height * 0.42);
        final fullArtRect = Rect.fromLTWH(
          (size.width - fullArtSize) / 2,
          pad.top + 68,
          fullArtSize,
          fullArtSize,
        );
        final curArtRect = Rect.lerp(miniArtRect, fullArtRect, t)!;
        final curArtRadius = ui.lerpDouble(10.0, 18.0, t)!;

        // Title + Artist text block glides smoothly from beside mini-art to below big art
        final miniInfoWidth = (startRect.width - 178).clamp(80.0, size.width - 160);
        final miniInfoRect = Rect.fromLTWH(
          startRect.left + 64,
          startRect.top + (startRect.height - 38) / 2,
          miniInfoWidth,
          40,
        );
        final fullInfoRect = Rect.fromLTWH(
          24,
          fullArtRect.bottom + 24,
          size.width - 96,
          58,
        );
        final curInfoRect = Rect.lerp(miniInfoRect, fullInfoRect, t)!;
        final titleSize = ui.lerpDouble(13.8, 21.0, t)!;
        final artistSize = ui.lerpDouble(11.5, 13.8, t)!;

        // Transport controls [ |<  (||)  >| ] glide from right of mini-player to bottom-center
        final miniCtrlCenter = Offset(startRect.right - 64, startRect.center.dy);
        final fullCtrlCenter = Offset(
          size.width / 2,
          (fullArtRect.bottom + 188).clamp(fullArtRect.bottom + 124, size.height - pad.bottom - 94),
        );
        final curCtrlCenter = Offset.lerp(miniCtrlCenter, fullCtrlCenter, t)!;
        final playBtnSize = ui.lerpDouble(36.0, 62.0, t)!;
        final skipIconSize = ui.lerpDouble(21.0, 32.0, t)!;
        final ctrlGap = ui.lerpDouble(2.0, 26.0, t)!;

        // Cross-fade between morph overlay and live interactive NowPlayingModal at very top
        final fullChildOpacity = t >= 0.995
            ? 1.0
            : ((t - 0.68) / 0.30).clamp(0.0, 1.0);
        final sharedOverlayOpacity = t >= 0.995
            ? 0.0
            : (1.0 - ((t - 0.86) / 0.13).clamp(0.0, 1.0));

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Underlying page dimming scrim
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: t < 0.05,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: scrimOpacity),
                  ),
                ),
              ),

              // Morphing Now Playing container surface
              Positioned.fromRect(
                rect: cardRect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cardRadius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: t < 0.92
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.10 * (1.0 - t)),
                              width: 0.9,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Subtle AMOLED radial ambient glow fading in
                        if (t > 0.15)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: ((t - 0.15) / 0.85).clamp(0.0, 1.0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: const Alignment(0.0, -0.45),
                                      radius: 0.95,
                                      colors: [
                                        accent.withValues(alpha: 0.14),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.72],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Full live NowPlayingModal
                        if (fullChildOpacity > 0.005)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: t < 0.96,
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

              // Seamless shared-element morph overlay (Art + Title/Artist + Controls)
              if (sharedOverlayOpacity > 0.005)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: sharedOverlayOpacity,
                      child: Stack(
                        children: [
                          // Morphing Album Artwork
                          Positioned.fromRect(
                            rect: curArtRect,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(curArtRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.45 * t),
                                    blurRadius: 24 * t,
                                    offset: Offset(0, 10 * t),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(curArtRadius),
                                child: coverBuilder(curArtRect.width, curArtRadius),
                              ),
                            ),
                          ),

                          // Morphing Track Title & Artist Info
                          Positioned.fromRect(
                            rect: curInfoRect,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
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
                                  artist,
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

                          // Morphing Transport Controls [ |<  (||)  >| ]
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

/// Wraps ANY mini-player across Nami (main tabs + detail floating dock) to provide:
/// 1. 1:1 Vertical Drag-UP & Tap morphing directly into Full Now Playing
/// 2. 1:1 Horizontal Spring Drag track shifting (elastic bounce-back or spring slide-in)
/// 3. Live screen Rect capture & automatic zero-flicker hiding during morph
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
  int _lastShiftDir = 0; // -1 = next (came from right), +1 = prev (came from left)

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
      // Silky spring slide-in from the incoming side when track shifts!
      final startOffset = _lastShiftDir < 0 ? 74.0 : -74.0;
      _lastShiftDir = 0;
      _hSpring.stop();
      _dx = startOffset;
      _hSpring.animateWith(SpringSimulation(_hSpringDesc, startOffset, 0.0, 0.0));
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

  void _onVerticalDragStart(DragStartDetails d) {
    final rect = _measureRect();
    if (rect == null || NamiMorphPlayerController.isMorphActive) return;
    _openingDrag = true;
    widget.onStartDragOpen(rect);
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (!_openingDrag) return;
    final route = NamiMorphPlayerController.activeRoute;
    if (route == null) return;
    final h = MediaQuery.sizeOf(context).height;
    final dragRange = (h * 0.78).clamp(320.0, 760.0);
    route.updateInteractiveDrag(-d.delta.dy / dragRange);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (!_openingDrag) return;
    _openingDrag = false;
    final route = NamiMorphPlayerController.activeRoute;
    if (route == null) return;
    final h = MediaQuery.sizeOf(context).height;
    final dragRange = (h * 0.78).clamp(320.0, 760.0);
    final vel = -(d.primaryVelocity ?? 0.0) / dragRange;
    route.endInteractiveDrag(velocityPerSec: vel, isOpeningDrag: true);
  }

  void _onVerticalDragCancel() {
    if (!_openingDrag) return;
    _openingDrag = false;
    NamiMorphPlayerController.activeRoute?.endInteractiveDrag(
      velocityPerSec: -0.5,
      isOpeningDrag: true,
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    _hSpring.stop();
    // Gentle rubber-band resistance past 75px
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
    // Spring smoothly back to center
    _hSpring.animateWith(SpringSimulation(_hSpringDesc, _dx, 0.0, vx / 1200.0));
  }

  @override
  Widget build(BuildContext context) {
    final dragNorm = (_dx.abs() / 90.0).clamp(0.0, 1.0);
    final scale = 1.0 - (dragNorm * 0.025);

    return ValueListenableBuilder<double>(
      valueListenable: NamiMorphPlayerController.progress,
      builder: (_, morphProgress, child) {
        final hidden = morphProgress > 0.005;
        return Opacity(
          opacity: hidden ? 0.0 : 1.0,
          child: IgnorePointer(
            ignoring: hidden,
            child: child,
          ),
        );
      },
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
    );
  }
}

/// 1:1 Horizontal Elastic Spring Swipe wrapper for Now Playing album art
/// (mirrors the horizontal drag & spring bounce-back in video_1.mp4)
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
