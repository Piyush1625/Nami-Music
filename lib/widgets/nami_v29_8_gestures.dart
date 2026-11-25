part of '../main.dart';

/// Optional GPU blur wrapper: renders crisp zero-cost surfaces when
/// `NamiUxPrefs.enableBlurEffect` is OFF (120Hz default) and full glassmorphism when ON.
class NamiOptionalBlur extends StatelessWidget {
  final double sigmaX;
  final double sigmaY;
  final Widget child;

  const NamiOptionalBlur({
    super.key,
    this.sigmaX = 14.0,
    this.sigmaY = 14.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!NamiUxPrefs.enableBlurEffect) return child;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: child,
    );
  }
}

class _NamiPillToastData {
  final String message;
  final String? badge;
  final IconData icon;
  final int pulseSeq;
  final bool isQueueBurst;

  const _NamiPillToastData({
    required this.message,
    this.badge,
    required this.icon,
    required this.pulseSeq,
    this.isQueueBurst = false,
  });
}

/// Global controller for Nami's Namida-style in-place mutating bottom pill toast.
/// Swiping multiple tracks updates the existing pill (`Added: 2 Tracks  +1`) instead of stacking SnackBars.
class NamiLiveToastController {
  static final ValueNotifier<_NamiPillToastData?> current =
      ValueNotifier<_NamiPillToastData?>(null);
  static Timer? _dismissTimer;
  static int _queueBurstCount = 0;
  static int _pulseSeq = 0;

  static int get activeQueueBurstCount =>
      (current.value != null && current.value!.isQueueBurst) ? _queueBurstCount : 0;

  static void showQueueAdded() {
    _dismissTimer?.cancel();
    if (current.value != null && current.value!.isQueueBurst) {
      _queueBurstCount++;
    } else {
      _queueBurstCount = 1;
    }
    _pulseSeq++;
    final label = _queueBurstCount == 1
        ? 'Added: 1 Track'
        : 'Added: $_queueBurstCount Tracks';
    final badge = _queueBurstCount > 1 ? '+1' : null;
    _namiSafeSetNotifier<_NamiPillToastData?>(
      current,
      _NamiPillToastData(
        message: label,
        badge: badge,
        icon: Icons.playlist_play_rounded,
        pulseSeq: _pulseSeq,
        isQueueBurst: true,
      ),
    );
    _dismissTimer = Timer(const Duration(milliseconds: 3000), dismiss);
  }

  static void showMessage(
    String message, {
    IconData icon = Icons.check_circle_outline_rounded,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    _dismissTimer?.cancel();
    _queueBurstCount = 0;
    _pulseSeq++;
    _namiSafeSetNotifier<_NamiPillToastData?>(
      current,
      _NamiPillToastData(
        message: message,
        icon: icon,
        pulseSeq: _pulseSeq,
        isQueueBurst: false,
      ),
    );
    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _queueBurstCount = 0;
    _namiSafeSetNotifier<_NamiPillToastData?>(current, null);
  }
}

/// Floating compact pill toast mounted inside `NamiExpandablePlayerHost`.
class NamiLivePillToastOverlay extends StatelessWidget {
  const NamiLivePillToastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ValueListenableBuilder<double>(
      valueListenable: NamiExpandablePlayerController.progress,
      builder: (_, playerProgress, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: NamiExpandablePlayerController.hasSong,
          builder: (_, hasSong, __) {
            return ValueListenableBuilder<_NamiPillToastData?>(
              valueListenable: NamiLiveToastController.current,
              builder: (_, toast, __) {
                final visible = toast != null && playerProgress < 0.08;
                final bottomOffset = (hasSong ? 150.0 : 84.0) + bottomInset;

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: const Cubic(0.22, 1.0, 0.36, 1.0),
                  left: 20,
                  right: 20,
                  bottom: visible ? bottomOffset : bottomOffset - 18,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: visible ? 1.0 : 0.0,
                      child: Center(
                        child: toast == null
                            ? const SizedBox.shrink()
                            : TweenAnimationBuilder<double>(
                                key: ValueKey<int>(toast.pulseSeq),
                                tween: Tween<double>(begin: 0.93, end: 1.0),
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                builder: (_, sc, child) => Transform.scale(scale: sc, child: child),
                                child: GestureDetector(
                                  onTap: NamiLiveToastController.dismiss,
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xF212121A),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.13),
                                          width: 0.9,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.62),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(toast.icon, color: accent, size: 19),
                                          const SizedBox(width: 9),
                                          Flexible(
                                            child: Text(
                                              toast.message,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.0,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ),
                                          if (toast.badge != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: accent.withValues(alpha: 0.22),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                toast.badge!,
                                                style: TextStyle(
                                                  color: accent,
                                                  fontSize: 11.2,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _NamiLibraryBannerData {
  final int total;
  final int added;
  final int changed;
  final int removed;

  const _NamiLibraryBannerData({
    required this.total,
    required this.added,
    required this.changed,
    required this.removed,
  });
}

/// Global controller for Namida-style non-blocking top Library Refresh status banner.
class NamiTopBannerController {
  static final ValueNotifier<_NamiLibraryBannerData?> current =
      ValueNotifier<_NamiLibraryBannerData?>(null);
  static Timer? _timer;

  static void showLibraryUpdate({
    required int total,
    required int added,
    required int changed,
    required int removed,
  }) {
    _timer?.cancel();
    _namiSafeSetNotifier<_NamiLibraryBannerData?>(
      current,
      _NamiLibraryBannerData(
        total: total,
        added: added,
        changed: changed,
        removed: removed,
      ),
    );
    _timer = Timer(const Duration(milliseconds: 3400), dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _namiSafeSetNotifier<_NamiLibraryBannerData?>(current, null);
  }
}

/// Sleek top slide-down status banner (`Done • Finished Updating Library`).
class NamiTopLibraryBannerOverlay extends StatelessWidget {
  const NamiTopLibraryBannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final topPad = MediaQuery.paddingOf(context).top;

    return ValueListenableBuilder<_NamiLibraryBannerData?>(
      valueListenable: NamiTopBannerController.current,
      builder: (_, data, __) {
        final visible = data != null;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 260),
          curve: const Cubic(0.22, 1.0, 0.36, 1.0),
          left: 14,
          right: 14,
          top: visible ? topPad + 10 : -110,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: visible ? 1.0 : 0.0,
              child: data == null
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: NamiTopBannerController.dismiss,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xF5111119),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 0.9,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.65),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.done_rounded, color: accent, size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Done • Finished Updating Library',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2.5),
                                    Text(
                                      'Tracks: ${data.total}  •  New: ${data.added}  •  Changed: ${data.changed}  •  Removed: ${data.removed}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11.2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Edge-aware horizontal recognizer so drags near the screen edges (`< 28dp`) pass
/// cleanly through to `NamiSwipeableTabsView`, while drags on a track row slide it 1:1.
class _NamiInnerRowDragRecognizer extends HorizontalDragGestureRecognizer {
  final double edgeMargin;
  final double screenWidth;

  _NamiInnerRowDragRecognizer({
    required this.edgeMargin,
    required this.screenWidth,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final x = event.position.dx;
    if (x < edgeMargin || x > screenWidth - edgeMargin) {
      return;
    }
    super.addAllowedPointer(event);
  }
}

/// 1:1 Spring-back horizontal swipe wrapper for Track rows:
/// - Swipe Left -> `Play After` (queues track + mutating bottom pill toast)
/// - Swipe Right -> `Info` (opens centered AMOLED Floating Track Info Card)
class NamiSwipeableTrackRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onPlayAfter;
  final VoidCallback onShowInfo;

  const NamiSwipeableTrackRow({
    super.key,
    required this.child,
    required this.onPlayAfter,
    required this.onShowInfo,
  });

  @override
  State<NamiSwipeableTrackRow> createState() => _NamiSwipeableTrackRowState();
}

class _NamiSwipeableTrackRowState extends State<NamiSwipeableTrackRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring;
  double _dx = 0.0;
  bool _crossedThreshold = false;

  static const double _triggerThreshold = 64.0;
  static const double _maxExtent = 104.0;
  static const SpringDescription _snapSpring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 29.0,
  );

  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _dx = _spring.value);
      });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _spring.stop();
    final resist = _dx.abs() > _triggerThreshold ? 0.32 : 0.90;
    final next = (_dx + d.delta.dx * resist).clamp(-_maxExtent, _maxExtent);
    final nowCrossed = next.abs() >= _triggerThreshold;
    if (nowCrossed && !_crossedThreshold) {
      NamiUxPrefs.hapticLight();
    }
    _crossedThreshold = nowCrossed;
    setState(() => _dx = next);
  }

  void _onDragEnd(DragEndDetails d) {
    final vx = d.primaryVelocity ?? 0.0;
    final shouldPlayAfter = _dx <= -_triggerThreshold || (vx < -520.0 && _dx < -24.0);
    final shouldShowInfo = _dx >= _triggerThreshold || (vx > 520.0 && _dx > 24.0);

    _crossedThreshold = false;
    _spring.animateWith(SpringSimulation(_snapSpring, _dx, 0.0, vx / 1400.0));

    if (shouldPlayAfter) {
      widget.onPlayAfter();
    } else if (shouldShowInfo) {
      widget.onShowInfo();
    }
  }

  void _onDragCancel() {
    _crossedThreshold = false;
    if (_dx != 0.0) {
      _spring.animateWith(SpringSimulation(_snapSpring, _dx, 0.0, 0.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!NamiUxPrefs.trackRowSwipeActions) return widget.child;

    final screenW = MediaQuery.sizeOf(context).width;
    final accent = Theme.of(context).colorScheme.primary;
    final activeLeft = _dx < -4.0;
    final activeRight = _dx > 4.0;
    final progress = (_dx.abs() / _triggerThreshold).clamp(0.0, 1.0);

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _NamiInnerRowDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_NamiInnerRowDragRecognizer>(
          () => _NamiInnerRowDragRecognizer(
            edgeMargin: 28.0,
            screenWidth: screenW,
          ),
          (_NamiInnerRowDragRecognizer inst) {
            inst.onUpdate = _onDragUpdate;
            inst.onEnd = _onDragEnd;
            inst.onCancel = _onDragCancel;
          },
        ),
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (activeLeft || activeRight)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: _crossedThreshold
                      ? accent.withValues(alpha: 0.16)
                      : const Color(0xFF12121A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _crossedThreshold
                        ? accent.withValues(alpha: 0.48)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      activeLeft ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Opacity(
                      opacity: progress,
                      child: Transform.scale(
                        scale: 0.84 + 0.16 * progress,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: activeLeft
                              ? [
                                  Text(
                                    'Play After',
                                    style: TextStyle(
                                      color: _crossedThreshold ? accent : Colors.white70,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Icon(
                                    Icons.playlist_play_rounded,
                                    color: _crossedThreshold ? accent : Colors.white70,
                                    size: 21,
                                  ),
                                ]
                              : [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: _crossedThreshold ? accent : Colors.white70,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Info',
                                    style: TextStyle(
                                      color: _crossedThreshold ? accent : Colors.white70,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Centered Namida-style Pitch-Black AMOLED Floating Track Info Card (`220ms` 0.92 -> 1.0 scale + fade).
Future<void> showNamiFloatingTrackInfoCard(
  BuildContext context, {
  required AudioTrack track,
  required Widget coverArt,
  required VoidCallback onPlayNow,
  required VoidCallback onPlayNext,
}) {
  final ext = namiFormatBadgeForPath(track.path);
  final durSec = track.duration.inSeconds;
  final durStr =
      '${(durSec ~/ 60).toString().padLeft(2, '0')}:${(durSec % 60).toString().padLeft(2, '0')}';
  final sizeMb = track.fileSize > 0
      ? '${(track.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB'
      : 'Unknown';
  final fileName = track.path.split('/').last;
  final folderName = track.path.contains('/')
      ? track.path.substring(0, track.path.lastIndexOf('/'))
      : track.path;

  Widget metaRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Track Info',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogCtx, _, __) {
      final accent = Theme.of(dialogCtx).colorScheme.primary;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NamiOptionalBlur(
                sigmaX: 16,
                sigmaY: 16,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xF50B0B11),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(width: 62, height: 62, child: coverArt),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  cleanArtistStr(track.artist),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12.6,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '$ext • $durStr • $sizeMb',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 10.6,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Colors.white10),
                      const SizedBox(height: 8),
                      metaRow('Album', track.album),
                      metaRow('Year', track.year),
                      metaRow('Genre', track.genre),
                      metaRow('File', fileName),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: track.path));
                          NamiUxPrefs.hapticLight();
                          NamiLiveToastController.showMessage(
                            'File path copied',
                            icon: Icons.copy_rounded,
                          );
                        },
                        child: metaRow('Folder', folderName),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Colors.white10),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: NamiSpringTap(
                              pressedScale: 0.94,
                              onTap: () {
                                Navigator.of(dialogCtx).pop();
                                onPlayNow();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.55),
                                    width: 0.9,
                                  ),
                                ),
                                child: Text(
                                  'Play Now',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12.6,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NamiSpringTap(
                              pressedScale: 0.94,
                              onTap: () {
                                Navigator.of(dialogCtx).pop();
                                onPlayNext();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    width: 0.9,
                                  ),
                                ),
                                child: const Text(
                                  'Play After',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          NamiSpringTap(
                            pressedScale: 0.92,
                            onTap: () => Navigator.of(dialogCtx).pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12.6,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
