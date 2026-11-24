// ignore_for_file: deprecated_member_use
part of '../main.dart';

class NamiSmoothLyricsView extends StatefulWidget {
  final List<LyricLine> lines;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Stream<bool> playingStream;
  final bool initialPlaying;
  final Color accentColor;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onClose;

  const NamiSmoothLyricsView({
    super.key,
    required this.lines,
    required this.positionStream,
    required this.initialPosition,
    required this.playingStream,
    required this.initialPlaying,
    required this.accentColor,
    required this.onSeek,
    this.onClose,
  });

  @override
  State<NamiSmoothLyricsView> createState() => _NamiSmoothLyricsViewState();
}

class _NamiSmoothLyricsViewState extends State<NamiSmoothLyricsView>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final Ticker _ticker;
  late final AnimationController _springScrollCtrl;
  final Stopwatch _clock = Stopwatch();
  final Map<int, GlobalKey> _lineKeys = {};

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Timer? _manualScrollResumeTimer;

  double _anchorPosMs = 0.0;
  int _anchorWallUs = 0;
  double _smoothPosMs = 0.0;
  bool _isPlaying = false;
  int _activeLineIndex = -1;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _clock.start();
    _anchorPosMs = widget.initialPosition.inMilliseconds.toDouble();
    _smoothPosMs = _anchorPosMs;
    _anchorWallUs = _clock.elapsedMicroseconds;
    _isPlaying = widget.initialPlaying;

    _springScrollCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onSpringTick);

    _posSub = widget.positionStream.listen((d) {
      final newMs = d.inMilliseconds.toDouble();
      // Smoothly resync anchor without visual jumps for tiny drift (<90ms)
      final drift = (newMs - _smoothPosMs).abs();
      if (drift > 90 || !_isPlaying) {
        _anchorPosMs = newMs;
        _smoothPosMs = newMs;
      } else {
        // Gentle blend toward hardware stream position
        _anchorPosMs = _smoothPosMs + (newMs - _smoothPosMs) * 0.35;
      }
      _anchorWallUs = _clock.elapsedMicroseconds;
    });

    _playSub = widget.playingStream.listen((playing) {
      _isPlaying = playing;
      _anchorPosMs = _smoothPosMs;
      _anchorWallUs = _clock.elapsedMicroseconds;
    });

    _ticker = createTicker(_onFrameTick)..start();
    _activeLineIndex = _findActiveIndex(_smoothPosMs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _activeLineIndex >= 0) {
        _springScrollToLine(_activeLineIndex, instant: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant NamiSmoothLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines) {
      _lineKeys.clear();
      _activeLineIndex = _findActiveIndex(_smoothPosMs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeLineIndex >= 0) {
          _springScrollToLine(_activeLineIndex, instant: true);
        }
      });
    }
  }

  void _onSpringTick() {
    if (!_scrollController.hasClients || _userScrolling) return;
    final maxExt = _scrollController.position.maxScrollExtent;
    final target = _springScrollCtrl.value.clamp(0.0, maxExt);
    _scrollController.jumpTo(target);
  }

  void _onFrameTick(Duration _) {
    if (!mounted) return;
    double nextMs = _anchorPosMs;
    if (_isPlaying) {
      final elapsedMs = (_clock.elapsedMicroseconds - _anchorWallUs) / 1000.0;
      // Clamp extrapolation so a stalled stream doesn't drift wildly
      nextMs = _anchorPosMs + elapsedMs.clamp(0.0, 450.0);
    }

    if ((nextMs - _smoothPosMs).abs() < 0.4) return;
    _smoothPosMs = nextMs;

    final idx = _findActiveIndex(_smoothPosMs);
    if (idx != _activeLineIndex) {
      _activeLineIndex = idx;
      if (!_userScrolling && idx >= 0) {
        _springScrollToLine(idx);
      }
    }
    setState(() {});
  }

  int _findActiveIndex(double posMs) {
    final lines = widget.lines;
    if (lines.isEmpty) return -1;
    int active = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timestamp.inMilliseconds <= posMs + 60) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  void _springScrollToLine(int idx, {bool instant = false}) {
    if (!_scrollController.hasClients) return;
    final key = _lineKeys[idx];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final listBox = context.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.hasSize) return;

    final linePos = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
    final desiredY = listBox.size.height * 0.28;
    final delta = linePos - desiredY;
    final currentOffset = _scrollController.offset;
    final maxExt = _scrollController.position.maxScrollExtent;
    final targetOffset = (currentOffset + delta).clamp(0.0, maxExt);

    if ((targetOffset - currentOffset).abs() < 1.5) return;

    if (instant) {
      _springScrollCtrl.stop();
      _scrollController.jumpTo(targetOffset);
      return;
    }

    // Apple Music-style critically damped spring physics
    const spring = SpringDescription(mass: 1.0, stiffness: 118.0, damping: 20.5);
    final sim = SpringSimulation(spring, currentOffset, targetOffset, 0.0);
    _springScrollCtrl.animateWith(sim);
  }

  void _onUserScrollStart() {
    _springScrollCtrl.stop();
    if (!_userScrolling) {
      setState(() => _userScrolling = true);
    }
    _manualScrollResumeTimer?.cancel();
    _manualScrollResumeTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() => _userScrolling = false);
      if (_activeLineIndex >= 0) {
        _springScrollToLine(_activeLineIndex);
      }
    });
  }

  double _lineEndMs(int index) {
    final lines = widget.lines;
    final startMs = lines[index].timestamp.inMilliseconds.toDouble();
    if (index + 1 < lines.length) {
      final nextStart = lines[index + 1].timestamp.inMilliseconds.toDouble();
      if (nextStart > startMs + 150) return nextStart;
    }
    return startMs + 3600.0;
  }

  Widget _buildSmoothWordLine(LyricLine line, int index, bool isActive) {
    final startMs = line.timestamp.inMilliseconds.toDouble();
    final endMs = _lineEndMs(index);
    final rawText = line.text.trim();
    if (rawText.isEmpty) {
      return const SizedBox(height: 16);
    }

    // Build timed word segments: use native syllable/word tokens when present,
    // otherwise distribute smoothly by character weight across the line window
    final words = <_TimedWord>[];
    final nativeTokens = line.syllables;
    if (nativeTokens.isNotEmpty) {
      for (int i = 0; i < nativeTokens.length; i++) {
        final tk = nativeTokens[i];
        final tStart = tk.timestamp.inMilliseconds.toDouble();
        double tEnd;
        if (false) {
          tEnd = 0.0;
        } else if (i + 1 < nativeTokens.length) {
          tEnd = nativeTokens[i + 1].timestamp.inMilliseconds.toDouble();
        } else {
          tEnd = endMs;
        }
        if (tEnd <= tStart + 40) tEnd = tStart + 260;
        words.add(_TimedWord(tk.text, tStart, tEnd));
      }
    } else {
      final parts = rawText.split(RegExp(r'\s+'));
      final totalChars = parts.fold<int>(0, (acc, w) => acc + w.length.clamp(2, 24));
      final span = (endMs - startMs).clamp(450.0, 9000.0);
      double cursor = startMs;
      for (int i = 0; i < parts.length; i++) {
        final w = parts[i];
        final weight = w.length.clamp(2, 24) / (totalChars == 0 ? 1 : totalChars);
        final dur = (span * weight).clamp(110.0, 1400.0);
        words.add(_TimedWord(i == parts.length - 1 ? w : '$w ', cursor, cursor + dur));
        cursor += dur;
      }
    }

    const baseStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      height: 1.32,
      letterSpacing: -0.35,
      color: Colors.white,
    );

    if (!isActive) {
      return Text(
        rawText,
        style: baseStyle.copyWith(color: Colors.white.withOpacity(0.88)),
      );
    }

    return Wrap(
      runSpacing: 2,
      children: words.map((tw) {
        final dur = (tw.endMs - tw.startMs).clamp(80.0, 5000.0);
        final rawProgress = ((_smoothPosMs - tw.startMs) / dur).clamp(0.0, 1.0);
        // Smooth easeOutSine curve eliminates mechanical linear stiffness
        final progress = Curves.easeOutSine.transform(rawProgress);
        final lift = rawProgress > 0.0 && rawProgress < 1.0
            ? -2.0 * math.sin(rawProgress * math.pi)
            : 0.0;

        // Soft feathered horizontal wipe across the word
        final lead = (progress - 0.14).clamp(0.0, 1.0);
        final trail = (progress + 0.14).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, lift),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white.withOpacity(0.32),
                  Colors.white.withOpacity(0.32),
                ],
                stops: [0.0, lead, trail, 1.0],
              ).createShader(bounds);
            },
            child: Text(tw.text, style: baseStyle),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _springScrollCtrl.dispose();
    _posSub?.cancel();
    _playSub?.cancel();
    _manualScrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const Center(
        child: Text(
          'No synced lyrics available for this track.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        if (n.direction != ScrollDirection.idle) {
          _onUserScrollStart();
        }
        return false;
      },
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, 0.10, 0.86, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 84, 22, 180),
          itemCount: widget.lines.length,
          itemBuilder: (ctx, i) {
            final line = widget.lines[i];
            final isActive = i == _activeLineIndex;
            final dist = _activeLineIndex < 0 ? 0 : (i - _activeLineIndex).abs();
            final blurSigma = _userScrolling
                ? 0.0
                : (dist == 0
                    ? 0.0
                    : dist == 1
                        ? 0.85
                        : dist == 2
                            ? 1.65
                            : 2.4);
            final targetOpacity = _userScrolling
                ? (isActive ? 1.0 : 0.72)
                : (dist == 0
                    ? 1.0
                    : dist == 1
                        ? 0.56
                        : dist == 2
                            ? 0.36
                            : 0.22);
            final targetScale = isActive ? 1.0 : (dist == 1 ? 0.96 : 0.93);

            final key = _lineKeys.putIfAbsent(i, () => GlobalKey());

            Widget content = AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              opacity: targetOpacity,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                scale: targetScale,
                alignment: Alignment.centerLeft,
                child: _buildSmoothWordLine(line, i, isActive),
              ),
            );

            if (blurSigma > 0.05) {
              content = ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: content,
              );
            }

            return GestureDetector(
              key: key,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                final seekDur = Duration(milliseconds: line.timestamp.inMilliseconds.toInt());
                _anchorPosMs = seekDur.inMilliseconds.toDouble();
                _smoothPosMs = _anchorPosMs;
                _anchorWallUs = _clock.elapsedMicroseconds;
                _userScrolling = false;
                widget.onSeek(seekDur);
                _springScrollToLine(i);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimedWord {
  final String text;
  final double startMs;
  final double endMs;
  const _TimedWord(this.text, this.startMs, this.endMs);
}
