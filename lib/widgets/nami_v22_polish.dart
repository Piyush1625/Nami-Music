// ignore_for_file: deprecated_member_use
part of '../main.dart';

/// 120Hz Animated 3-Bar Equalizer indicator for the currently playing track
class NamiMiniEqBars extends StatefulWidget {
  final Color color;
  final bool isPlaying;
  final double size;

  const NamiMiniEqBars({
    super.key,
    required this.color,
    this.isPlaying = true,
    this.size = 14,
  });

  @override
  State<NamiMiniEqBars> createState() => _NamiMiniEqBarsState();
}

class _NamiMiniEqBarsState extends State<NamiMiniEqBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant NamiMiniEqBars oldWidget) {
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
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value * 2 * math.pi;
          final h1 = widget.isPlaying ? (0.32 + 0.65 * (0.5 + 0.5 * math.sin(t))) : 0.28;
          final h2 = widget.isPlaying ? (0.32 + 0.65 * (0.5 + 0.5 * math.sin(t + 2.1))) : 0.52;
          final h3 = widget.isPlaying ? (0.32 + 0.65 * (0.5 + 0.5 * math.sin(t + 4.2))) : 0.34;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [h1, h2, h3].map((f) {
              return Container(
                width: (s * 0.24).clamp(2.2, 4.0),
                height: (s * f).clamp(3.0, s),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Compact horizontal quick-filter chip strip (All, Hi-Res 24B, FLAC, Favorites)
class NamiQuickFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final List<String> options;

  const NamiQuickFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.options = const ['All', 'Hi-Res 24B', 'FLAC', 'Favorites'],
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, idx) {
          final opt = options[idx];
          final active = opt == selected;
          return NamiSpringTap(
            pressedScale: 0.94,
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.18) : const Color(0xFF13131D),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? accent.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.08),
                  width: 0.9,
                ),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? accent : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Frosted floating Audiophile Signal Chain Inspector Sheet
void showNamiSignalChainSheet({
  required BuildContext context,
  required AudioTrack? song,
  required String outputDevice,
  bool eqEnabled = false,
}) {
  final accent = Theme.of(context).colorScheme.primary;
  final ext = namiFormatBadgeForPath(song?.path);
  final bitDepth = song?.bitDepth ?? 0;
  final sampleRate = (song?.sampleRateHz ?? 0).toDouble();
  final srStr = sampleRate > 0 ? '${(sampleRate / 1000).toStringAsFixed(1)} kHz' : 'Native Rate';
  final bdStr = bitDepth > 0 ? '$bitDepth-Bit' : 'Lossless';
  final isBitPerfect = !eqEnabled && (ext == 'FLAC' || ext == 'ALAC' || ext == 'WAV');

  Widget stepRow(IconData icon, String stage, String detail, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: highlight ? accent.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: highlight ? accent.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.09),
              ),
            ),
            child: Icon(icon, size: 18, color: highlight ? accent : Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: Colors.white54),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: highlight ? accent : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  showModalBottomSheet(
    useRootNavigator: true,
    sheetAnimationStyle: namiSmoothSheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NamiOptionalBlur(sigmaX: 18, sigmaY: 18,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF00B0B12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.70), blurRadius: 28, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                    child: Row(
                      children: [
                        Icon(Icons.graphic_eq_rounded, color: accent, size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'Audio Signal Chain',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isBitPerfect ? Colors.greenAccent : accent).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isBitPerfect ? 'BIT-PERFECT' : 'TUNED DSP',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: isBitPerfect ? Colors.greenAccent : accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  stepRow(Icons.audio_file_rounded, 'Source File', '$ext • $bdStr • $srStr'),
                  stepRow(Icons.memory_rounded, 'Decoder Engine', 'libmpv Native Direct Pipeline'),
                  stepRow(
                    Icons.equalizer_rounded,
                    'DSP & Equalizer',
                    eqEnabled ? '10-Band ISO EQ / AutoEQ Active' : 'Bypassed (Zero Resampling DSP)',
                    highlight: eqEnabled,
                  ),
                  stepRow(
                    Icons.usb_rounded,
                    'Hardware Output',
                    outputDevice.isNotEmpty ? outputDevice : 'Android Audio Output',
                    highlight: isBitPerfect,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
