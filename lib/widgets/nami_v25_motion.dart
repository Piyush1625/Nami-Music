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
              if (widget.haptic) HapticFeedback.selectionClick();
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
class NamiTabMotionWrapper extends StatelessWidget {
  final int activeIndex;
  final Widget child;

  const NamiTabMotionWrapper({
    super.key,
    required this.activeIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(activeIndex),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 190),
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      builder: (_, t, c) {
        return Opacity(
          opacity: (0.72 + 0.28 * t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - t) * 7.0),
            child: c,
          ),
        );
      },
      child: child,
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
  late final AnimationController _springCtrl;
  double _dragY = 0.0;
  bool _dismissing = false;

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

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    _springCtrl.stop();
    final next = (_dragY + d.delta.dy).clamp(0.0, 420.0);
    if ((next - _dragY).abs() > 0.2) {
      setState(() => _dragY = next);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final vy = d.primaryVelocity ?? 0.0;
    if (_dragY > 115.0 || vy > 460.0) {
      _dismissing = true;
      HapticFeedback.selectionClick();
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
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      onVerticalDragCancel: () {
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
