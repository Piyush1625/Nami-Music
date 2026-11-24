part of '../main.dart';

class HuePaletteCanvas extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const HuePaletteCanvas({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<HuePaletteCanvas> createState() => _HuePaletteCanvasState();
}

class _HuePaletteCanvasState extends State<HuePaletteCanvas> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation.clamp(0.0, 1.0);
    _value = hsv.value.clamp(0.0, 1.0);
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  void _updateSV(Offset localPosition, Size size) {
    setState(() {
      _saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
      _value = (1.0 - (localPosition.dy / size.height)).clamp(0.0, 1.0);
    });
    widget.onColorChanged(_currentColor);
  }

  void _updateHue(double localDx, double width) {
    setState(() {
      _hue = ((localDx / width) * 360.0).clamp(0.0, 360.0);
    });
    widget.onColorChanged(_currentColor);
  }

  @override
  Widget build(BuildContext context) {
    final pureHueColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2D Saturation-Brightness Canvas
        LayoutBuilder(
          builder: (context, constraints) {
            final canvasWidth = constraints.maxWidth;
            const canvasHeight = 165.0;
            final thumbX = _saturation * canvasWidth;
            final thumbY = (1.0 - _value) * canvasHeight;

            return GestureDetector(
              onPanDown: (d) =>
                  _updateSV(d.localPosition, Size(canvasWidth, canvasHeight)),
              onPanUpdate: (d) =>
                  _updateSV(d.localPosition, Size(canvasWidth, canvasHeight)),
              child: Container(
                width: canvasWidth,
                height: canvasHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      // Base Hue
                      Container(color: pureHueColor),
                      // Horizontal White -> Transparent (Saturation)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.white, Colors.transparent],
                          ),
                        ),
                      ),
                      // Vertical Transparent -> Black (Value/Brightness)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                      // 2D Crosshair Thumb
                      Positioned(
                        left: (thumbX - 11).clamp(0.0, canvasWidth - 22),
                        top: (thumbY - 11).clamp(0.0, canvasHeight - 22),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        // 360-Degree Rainbow Hue Spectrum Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final thumbX = (_hue / 360.0) * barWidth;
            return GestureDetector(
              onPanDown: (d) => _updateHue(d.localPosition.dx, barWidth),
              onPanUpdate: (d) => _updateHue(d.localPosition.dx, barWidth),
              child: SizedBox(
                width: barWidth,
                height: 28,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (thumbX - 11).clamp(0.0, barWidth - 22),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: pureHueColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Live Selected Color Preview & Hex Pill
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _colorToHex(_currentColor),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              'H: ${_hue.round()}°  S: ${(_saturation * 100).round()}%  B: ${(_value * 100).round()}%',
              style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ],
        ),
      ],
    );
  }
}

class NamiFastScroller extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final Widget child;

  const NamiFastScroller({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.child,
  });

  @override
  State<NamiFastScroller> createState() => _NamiFastScrollerState();
}

class _NamiFastScrollerState extends State<NamiFastScroller> {
  double _scrollFraction = 0.0;
  bool _isDragging = false;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant NamiFastScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isDragging || !widget.controller.hasClients) return;
    final max = widget.controller.position.maxScrollExtent;
    if (max <= 0) return;
    final frac = (widget.controller.offset / max).clamp(0.0, 1.0);
    if ((frac - _scrollFraction).abs() > 0.005 && mounted) {
      setState(() => _scrollFraction = frac);
    }
  }

  void _handleDrag(double localY, double trackHeight) {
    if (!widget.controller.hasClients ||
        trackHeight <= 0 ||
        widget.itemCount <= 0) return;
    final frac = (localY / trackHeight).clamp(0.0, 1.0);
    final max = widget.controller.position.maxScrollExtent;
    widget.controller.jumpTo(frac * max);
    final idx = (frac * (widget.itemCount - 1))
        .round()
        .clamp(0, widget.itemCount - 1);
    setState(() {
      _scrollFraction = frac;
      _activeIndex = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = (constraints.maxHeight - 105)
            .clamp(120.0, constraints.maxHeight);
        final thumbHeight = _isDragging ? 52.0 : 40.0;
        final thumbTop = 8.0 +
            (_scrollFraction * (trackHeight - thumbHeight))
                .clamp(0.0, math.max(0.0, trackHeight - thumbHeight));

        return Stack(
          children: [
            widget.child,
            if (widget.itemCount > 12)
              Positioned(
                right: 0,
                top: 8,
                height: trackHeight,
                width: 14,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (d) {
                    setState(() => _isDragging = true);
                    _handleDrag(d.localPosition.dy, trackHeight);
                  },
                  onVerticalDragUpdate: (d) =>
                      _handleDrag(d.localPosition.dy, trackHeight),
                  onVerticalDragEnd: (_) =>
                      setState(() => _isDragging = false),
                  onVerticalDragCancel: () =>
                      setState(() => _isDragging = false),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 1.5,
                        top: thumbTop - 8,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: _isDragging ? 5.0 : 3.2,
                          height: thumbHeight,
                          decoration: BoxDecoration(
                            color: _isDragging
                                ? accent
                                : Colors.white.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isDragging && widget.itemCount > 0)
              Positioned(
                right: 20,
                top: thumbTop.clamp(10.0, math.max(10.0, trackHeight - 36)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6), blurRadius: 10)
                    ],
                  ),
                  child: Text(
                    widget.labelBuilder(_activeIndex),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AnimatedPlayingBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const AnimatedPlayingBars({
    super.key,
    required this.isPlaying,
    required this.color,
    this.size = 18.0,
  });

  @override
  State<AnimatedPlayingBars> createState() => _AnimatedPlayingBarsState();
}

class _AnimatedPlayingBarsState extends State<AnimatedPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedPlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
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
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * 2 * math.pi;
        final h1 = widget.isPlaying ? (0.35 + 0.65 * ((math.sin(t) + 1) / 2)) : 0.35;
        final h2 = widget.isPlaying ? (0.35 + 0.65 * ((math.sin(t + 2.1) + 1) / 2)) : 0.62;
        final h3 = widget.isPlaying ? (0.35 + 0.65 * ((math.sin(t + 4.2) + 1) / 2)) : 0.42;
        final barW = (widget.size * 0.17).clamp(2.2, 4.0);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [h1, h2, h3]
                .map((frac) => Container(
                      width: barW,
                      height: (widget.size * frac).clamp(4.0, widget.size),
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class YoutubeSkeletonLoader extends StatelessWidget {
  const YoutubeSkeletonLoader({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 15,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 10),
                  Container(width: 140, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
