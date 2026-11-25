part of '../main.dart';

/// Global 120Hz elastic scroll behavior: silky fast-decelerating bouncing physics
/// across every ListView, GridView, CustomScrollView & horizontal shelf in Nami.
class NamiButterScrollBehavior extends MaterialScrollBehavior {
  const NamiButterScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Global 120Hz Page Transition: iOS/Namida-inspired parallax slide + subtle depth scale
/// with critically smooth Cubic(0.22, 1.0, 0.36, 1.0) curves for every page jump.
class NamiSmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const NamiSmoothPageTransitionsBuilder();

  static const Curve _forwardCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve _reverseCurve = Cubic(0.32, 0.0, 0.67, 0.0);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;

    final primary = CurvedAnimation(
      parent: animation,
      curve: _forwardCurve,
      reverseCurve: _reverseCurve,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: _forwardCurve,
      reverseCurve: _reverseCurve,
    );

    final slideIn = Tween<Offset>(
      begin: const Offset(0.16, 0.0),
      end: Offset.zero,
    ).animate(primary);

    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
        reverseCurve: const Interval(0.35, 1.0, curve: Curves.easeInCubic),
      ),
    );

    final parallaxOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.08, 0.0),
    ).animate(secondary);

    final scaleOut = Tween<double>(begin: 1.0, end: 0.965).animate(secondary);

    return SlideTransition(
      position: parallaxOut,
      child: ScaleTransition(
        scale: scaleOut,
        child: FadeTransition(
          opacity: fadeIn,
          child: SlideTransition(
            position: slideIn,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tactile 120Hz spring-press micro-animation for buttons, dock pills & cards.
class NamiSpringTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const NamiSpringTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.955,
    this.haptic = true,
  });

  @override
  State<NamiSpringTap> createState() => _NamiSpringTapState();
}

class _NamiSpringTapState extends State<NamiSpringTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic && NamiUxPrefs.hapticsEnabled) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: Duration(milliseconds: _down ? 85 : 220),
        curve: _down ? Curves.easeOutQuad : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// State-preserving 120Hz tab transition wrapper: gives IndexedStack tab switches
/// a crisp 190ms glide + fade without losing scroll positions on any tab.
class NamiTabMotionWrapper extends StatefulWidget {
  final int activeIndex;
  final Widget child;

  const NamiTabMotionWrapper({
    super.key,
    required this.activeIndex,
    required this.child,
  });

  @override
  State<NamiTabMotionWrapper> createState() => _NamiTabMotionWrapperState();
}

class _NamiTabMotionWrapperState extends State<NamiTabMotionWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
      value: 1.0,
    );
    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
    );
  }

  @override
  void didUpdateWidget(covariant NamiTabMotionWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex != oldWidget.activeIndex) {
      final ms = (190 * NamiUxPrefs.motionScale).round().clamp(110, 280);
      _ctrl.duration = Duration(milliseconds: ms);
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: widget.child,
      builder: (_, c) {
        final t = _anim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: (0.76 + 0.24 * t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - t) * 6.0),
            child: c,
          ),
        );
      },
    );
  }
}

/// Interactive 120Hz Drag-to-Dismiss wrapper for Now Playing:
/// tracks your finger 1:1 with live translation, subtle scale-down & rounded corners,
/// springing back cleanly if released early or dismissing smoothly on flick/pull.
class NamiInteractiveDragDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const NamiInteractiveDragDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
  });

  @override
  State<NamiInteractiveDragDismiss> createState() => _NamiInteractiveDragDismissState();
}

class _NamiInteractiveDragDismissState extends State<NamiInteractiveDragDismiss>
    with SingleTickerProviderStateMixin {
  /* v29_host_drag_down */
  late final AnimationController _springCtrl;
  double _dragY = 0.0;
  bool _dismissing = false;
  bool _drivingHost = false;
  bool _drivingMorphRoute = false;

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _dragY = _springCtrl.value.clamp(0.0, 900.0));
      });
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    if (_dismissing || !NamiUxPrefs.swipeDownDismiss) return;
    if (NamiExpandablePlayerController.hasHost && NamiExpandablePlayerController.isExpanded) {
      _drivingHost = true;
      _drivingMorphRoute = false;
      NamiExpandablePlayerController.beginDrag(isOpening: false);
      return;
    }
    _drivingHost = false;
    final morphRoute = NamiMorphPlayerController.activeRoute;
    if (morphRoute != null && morphRoute.isActive) {
      _drivingMorphRoute = true;
      morphRoute.beginInteractiveDismiss();
    } else {
      _drivingMorphRoute = false;
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing || !NamiUxPrefs.swipeDownDismiss) return;
    final h = MediaQuery.sizeOf(context).height;
    final dragRange = (h * 0.78).clamp(320.0, 760.0);
    if (_drivingHost) {
      NamiExpandablePlayerController.updateDrag(-d.delta.dy / dragRange);
      return;
    }
    if (_drivingMorphRoute) {
      final morphRoute = NamiMorphPlayerController.activeRoute;
      if (morphRoute != null && morphRoute.isActive) {
        morphRoute.updateInteractiveDrag(-d.delta.dy / dragRange);
        return;
      }
      _drivingMorphRoute = false;
    }
    _springCtrl.stop();
    final next = (_dragY + d.delta.dy).clamp(0.0, 420.0);
    if ((next - _dragY).abs() > 0.2) {
      setState(() => _dragY = next);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final h = MediaQuery.sizeOf(context).height;
    final dragRange = (h * 0.78).clamp(320.0, 760.0);
    final vel = -(d.primaryVelocity ?? 0.0) / dragRange;
    if (_drivingHost) {
      _drivingHost = false;
      NamiExpandablePlayerController.endDrag(velocityPerSec: vel, isOpeningDrag: false);
      return;
    }
    if (_drivingMorphRoute) {
      _drivingMorphRoute = false;
      final morphRoute = NamiMorphPlayerController.activeRoute;
      if (morphRoute != null && morphRoute.isActive) {
        morphRoute.endInteractiveDrag(velocityPerSec: vel, isOpeningDrag: false);
        return;
      }
    }
    final vy = d.primaryVelocity ?? 0.0;
    if (_dragY > 115.0 || vy > 460.0) {
      _dismissing = true;
      NamiUxPrefs.hapticLight();
      widget.onDismiss();
      return;
    }
    const spring = SpringDescription(mass: 1.0, stiffness: 320.0, damping: 28.0);
    final sim = SpringSimulation(spring, _dragY, 0.0, vy / 1000.0);
    _springCtrl.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragY / 280.0).clamp(0.0, 1.0);
    final scale = 1.0 - (progress * 0.055);
    final radius = progress * 28.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onVerticalDragCancel: () {
        if (_drivingHost) {
          _drivingHost = false;
          NamiExpandablePlayerController.endDrag(velocityPerSec: 0.5, isOpeningDrag: false);
          return;
        }
        if (_drivingMorphRoute) {
          _drivingMorphRoute = false;
          final morphRoute = NamiMorphPlayerController.activeRoute;
          if (morphRoute != null && morphRoute.isActive) {
            morphRoute.endInteractiveDrag(velocityPerSec: 0.5, isOpeningDrag: false);
          }
          return;
        }
        if (!_dismissing && _dragY > 0) {
          const spring = SpringDescription(mass: 1.0, stiffness: 320.0, damping: 28.0);
          _springCtrl.animateWith(SpringSimulation(spring, _dragY, 0.0, 0.0));
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragY),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: radius > 0.5
              ? ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}

/// Shared 120Hz bottom sheet animation style for all floating cards & pickers.
const AnimationStyle namiSmoothSheetStyle = AnimationStyle(
  duration: Duration(milliseconds: 280),
  reverseDuration: Duration(milliseconds: 200),
  curve: Cubic(0.22, 1.0, 0.36, 1.0),
  reverseCurve: Curves.easeInCubic,
);
