part of '../main.dart';

/// Wraps the Now Playing waveform bar with a non-intrusive Listener that displays
/// a floating frosted timestamp pill directly above the user's thumb while scrubbing,
/// with crisp haptic detents every 5 seconds.
class NamiWaveformScrubOverlay extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color accentColor;

  const NamiWaveformScrubOverlay({
    super.key,
    required this.child,
    required this.duration,
    required this.accentColor,
  });

  @override
  State<NamiWaveformScrubOverlay> createState() => _NamiWaveformScrubOverlayState();
}

class _NamiWaveformScrubOverlayState extends State<NamiWaveformScrubOverlay> {
  bool _scrubbing = false;
  double _frac = 0.0;
  int _lastDetentBucket = -1;

  String _fmt(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _updateFromLocalX(double localX, double width) {
    if (width <= 1) return;
    final f = (localX / width).clamp(0.0, 1.0);
    final targetSec = (widget.duration.inSeconds * f).round();
    final bucket = targetSec ~/ 5;
    if (_scrubbing && bucket != _lastDetentBucket && _lastDetentBucket != -1) {
      HapticFeedback.selectionClick();
    }
    _lastDetentBucket = bucket;
    setState(() {
      _scrubbing = true;
      _frac = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetMs = (widget.duration.inMilliseconds * _frac).round();
    final label = _fmt(Duration(milliseconds: targetMs));

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
        const pillW = 68.0;
        final left = (_frac * w - pillW / 2).clamp(0.0, (w - pillW).clamp(0.0, double.infinity));

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => _updateFromLocalX(e.localPosition.dx, w),
              onPointerMove: (e) => _updateFromLocalX(e.localPosition.dx, w),
              onPointerUp: (_) => setState(() {
                _scrubbing = false;
                _lastDetentBucket = -1;
              }),
              onPointerCancel: (_) => setState(() {
                _scrubbing = false;
                _lastDetentBucket = -1;
              }),
              child: widget.child,
            ),
            Positioned(
              left: left,
              top: -40,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _scrubbing && widget.duration.inMilliseconds > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: AnimatedScale(
                    scale: _scrubbing ? 1.0 : 0.85,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          width: pillW,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xE80D0D16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.accentColor.withValues(alpha: 0.55),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: widget.accentColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Flagship AMOLED Settings Hero Card showing live hardware output, audio mode,
/// version pill, and one-tap quick actions.
class NamiSettingsHeroCard extends StatelessWidget {
  final String outputDevice;
  final bool eqEnabled;
  final Color accentColor;
  final VoidCallback onGrantStorage;
  final VoidCallback onMergeArtists;
  final VoidCallback onRequestUsbDac;

  const NamiSettingsHeroCard({
    super.key,
    required this.outputDevice,
    required this.eqEnabled,
    required this.accentColor,
    required this.onGrantStorage,
    required this.onMergeArtists,
    required this.onRequestUsbDac,
  });

  @override
  Widget build(BuildContext context) {
    final isExternal = outputDevice.toLowerCase().contains('usb') ||
        outputDevice.toLowerCase().contains('dac') ||
        outputDevice.toLowerCase().contains('wired') ||
        outputDevice.toLowerCase().contains('bluetooth');

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.16),
            const Color(0xFF0E0E17),
            const Color(0xFF090910),
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withValues(alpha: 0.42)),
                  ),
                  child: Icon(
                    isExternal ? Icons.usb_rounded : Icons.graphic_eq_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Nami Audio Engine',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 7),
                          Text(
                            'v2.8.1',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isExternal ? Colors.greenAccent : accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              outputDevice.isNotEmpty ? outputDevice : 'Phone Speaker',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (eqEnabled ? accentColor : Colors.greenAccent).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (eqEnabled ? accentColor : Colors.greenAccent).withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    eqEnabled ? 'TUNED DSP' : 'BIT-PERFECT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: eqEnabled ? accentColor : Colors.greenAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _HeroQuickChip(
                  icon: Icons.folder_special_rounded,
                  label: 'All Files',
                  accent: accentColor,
                  onTap: onGrantStorage,
                ),
                const SizedBox(width: 8),
                _HeroQuickChip(
                  icon: Icons.usb_rounded,
                  label: 'USB DAC',
                  accent: accentColor,
                  onTap: onRequestUsbDac,
                ),
                const SizedBox(width: 8),
                _HeroQuickChip(
                  icon: Icons.merge_type_rounded,
                  label: 'Merge Artists',
                  accent: accentColor,
                  onTap: onMergeArtists,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroQuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _HeroQuickChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
