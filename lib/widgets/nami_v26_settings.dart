part of '../main.dart';

/// Persistent UX, Motion, Metadata & Sleep Timer preferences for Nami v2.6.0+
class NamiUxPrefs {
  static bool _loaded = false;

  static bool indiaFirstMetadata = true;
  static bool hapticsEnabled = true;
  static bool breathingCoverArt = true;
  static bool lyricsBlurDepth = true;
  static bool doubleTapArtLyrics = true;
  static bool swipeDownDismiss = true;
  static String motionSpeed = 'balanced'; // 'snappy' | 'balanced' | 'silky'
  static bool gaplessPlayback = true;
  static String replayGainMode = 'track'; // 'no' | 'track' | 'album'
  static bool persistSession = true;

  static final ValueNotifier<Duration?> sleepRemaining = ValueNotifier<Duration?>(null);
  static Timer? _sleepTicker;

  static double get motionScale {
    switch (motionSpeed) {
      case 'snappy':
        return 0.72;
      case 'silky':
        return 1.28;
      default:
        return 1.0;
    }
  }

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      indiaFirstMetadata = prefs.getBool('nami_v26_india_first') ?? true;
      hapticsEnabled = prefs.getBool('nami_v26_haptics') ?? true;
      breathingCoverArt = prefs.getBool('nami_v26_breathe_art') ?? true;
      lyricsBlurDepth = prefs.getBool('nami_v26_lyrics_blur') ?? true;
      doubleTapArtLyrics = prefs.getBool('nami_v26_double_tap_art') ?? true;
      swipeDownDismiss = prefs.getBool('nami_v26_swipe_dismiss') ?? true;
      motionSpeed = prefs.getString('nami_v26_motion_speed') ?? 'balanced';
      gaplessPlayback = prefs.getBool('nami_v27_gapless') ?? true;
      replayGainMode = prefs.getString('nami_v27_replaygain') ?? 'track';
      persistSession = prefs.getBool('nami_v27_persist_session') ?? true;
      NamiArtistMetadataService.indiaFirst = indiaFirstMetadata;
    } catch (_) {}
  }

  static Future<void> save() async {
    NamiArtistMetadataService.indiaFirst = indiaFirstMetadata;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('nami_v26_india_first', indiaFirstMetadata);
      await prefs.setBool('nami_v26_haptics', hapticsEnabled);
      await prefs.setBool('nami_v26_breathe_art', breathingCoverArt);
      await prefs.setBool('nami_v26_lyrics_blur', lyricsBlurDepth);
      await prefs.setBool('nami_v26_double_tap_art', doubleTapArtLyrics);
      await prefs.setBool('nami_v26_swipe_dismiss', swipeDownDismiss);
      await prefs.setString('nami_v26_motion_speed', motionSpeed);
      await prefs.setBool('nami_v27_gapless', gaplessPlayback);
      await prefs.setString('nami_v27_replaygain', replayGainMode);
      await prefs.setBool('nami_v27_persist_session', persistSession);
    } catch (_) {}
  }

  static void startSleepTimer(Duration? duration, VoidCallback onExpire) {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    if (duration == null || duration.inSeconds <= 0) {
      sleepRemaining.value = null;
      return;
    }
    sleepRemaining.value = duration;
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      final cur = sleepRemaining.value;
      if (cur == null || cur.inSeconds <= 1) {
        t.cancel();
        _sleepTicker = null;
        sleepRemaining.value = null;
        onExpire();
      } else {
        sleepRemaining.value = Duration(seconds: cur.inSeconds - 1);
      }
    });
  }

  static void hapticLight() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }
}

/// Feature-rich, customizable Settings Studio cards:
/// 1. Sleep Timer (with live countdown)
/// 2. Metadata & Artist Artwork Studio (India-First vs Global, Purge Placeholders, Batch Fetch)
/// 3. Motion, Gestures & 120Hz Experience Studio
class NamiSettingsStudioSection extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onPurgePlaceholders;
  final VoidCallback onBatchFetchArtists;
  final VoidCallback onSleepExpire;

  const NamiSettingsStudioSection({
    super.key,
    required this.accentColor,
    required this.onPurgePlaceholders,
    required this.onBatchFetchArtists,
    required this.onSleepExpire,
  });

  @override
  State<NamiSettingsStudioSection> createState() => _NamiSettingsStudioSectionState();
}

class _NamiSettingsStudioSectionState extends State<NamiSettingsStudioSection> {
  @override
  void initState() {
    super.initState();
    NamiUxPrefs.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _fmtTimer(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _sectionCard({required String title, required IconData icon, Widget? trailing, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.085)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
            child: Row(
              children: [
                Icon(icon, color: widget.accentColor, size: 18),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ...children,
        ],
      ),
    );
  }

  Widget _choiceChip(String label, bool active, VoidCallback onTap) {
    final accent = widget.accentColor;
    return Expanded(
      child: NamiSpringTap(
        pressedScale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: active ? accent.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.08),
              width: 0.9,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? accent : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      secondary: Icon(icon, color: Colors.white70, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      value: value,
      activeThumbColor: widget.accentColor,
      onChanged: (v) {
        NamiUxPrefs.hapticLight();
        onChanged(v);
        NamiUxPrefs.save();
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Column(
      children: [
        // 0. Audiophile Playback & Daily Driver Card (Gapless, ReplayGain, Session, Widget)
        NamiAudiophileStudioCard(
          accentColor: accent,
          onApplyAudioProps: () {
            final shell = _NamiHomeShellState.activeInstance;
            if (shell != null) {
              NamiAudiophileEngine.applyMpvProperties(shell._audioPlayer);
            }
          },
          onSyncWidgetNow: () {
            _NamiHomeShellState.activeInstance?._syncV27WidgetAndSession();
          },
        ),

        // 1. Sleep Timer Card
        ValueListenableBuilder<Duration?>(
          valueListenable: NamiUxPrefs.sleepRemaining,
          builder: (_, rem, __) {
            return _sectionCard(
              title: 'Sleep Timer',
              icon: Icons.bedtime_rounded,
              trailing: rem != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _fmtTimer(rem),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent),
                      ),
                    )
                  : const Text('Off', style: TextStyle(fontSize: 11.5, color: Colors.white38)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Row(
                    children: [
                      _choiceChip('Off', rem == null, () => NamiUxPrefs.startSleepTimer(null, widget.onSleepExpire)),
                      const SizedBox(width: 7),
                      _choiceChip('15m', rem != null && rem.inMinutes <= 15, () => NamiUxPrefs.startSleepTimer(const Duration(minutes: 15), widget.onSleepExpire)),
                      const SizedBox(width: 7),
                      _choiceChip('30m', rem != null && rem.inMinutes > 15 && rem.inMinutes <= 30, () => NamiUxPrefs.startSleepTimer(const Duration(minutes: 30), widget.onSleepExpire)),
                      const SizedBox(width: 7),
                      _choiceChip('45m', rem != null && rem.inMinutes > 30 && rem.inMinutes <= 45, () => NamiUxPrefs.startSleepTimer(const Duration(minutes: 45), widget.onSleepExpire)),
                      const SizedBox(width: 7),
                      _choiceChip('60m', rem != null && rem.inMinutes > 45, () => NamiUxPrefs.startSleepTimer(const Duration(minutes: 60), widget.onSleepExpire)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),

        // 2. Metadata & Artist Artwork Studio
        _sectionCard(
          title: 'Artist Artwork & Metadata Studio',
          icon: Icons.auto_awesome_rounded,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  _choiceChip('India-First (JioSaavn + Apple IN)', NamiUxPrefs.indiaFirstMetadata, () {
                    setState(() => NamiUxPrefs.indiaFirstMetadata = true);
                    NamiUxPrefs.save();
                  }),
                  const SizedBox(width: 8),
                  _choiceChip('Global (Spotify + Apple)', !NamiUxPrefs.indiaFirstMetadata, () {
                    setState(() => NamiUxPrefs.indiaFirstMetadata = false);
                    NamiUxPrefs.save();
                  }),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Icon(Icons.cleaning_services_rounded, color: accent, size: 20),
              title: const Text('Fix Blank / Mic Placeholder Artist Photos', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
              subtitle: const Text('Clears white mic/note icons & refreshes missing portraits', style: TextStyle(fontSize: 11, color: Colors.white54)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              onTap: () {
                NamiUxPrefs.hapticLight();
                widget.onPurgePlaceholders();
              },
            ),
            const Divider(height: 1, color: Colors.white10),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: const Icon(Icons.cloud_download_rounded, color: Colors.white70, size: 20),
              title: const Text('Batch Fetch Missing Artist Portraits', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
              subtitle: const Text('Downloads official photos for artists without artwork', style: TextStyle(fontSize: 11, color: Colors.white54)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              onTap: () {
                NamiUxPrefs.hapticLight();
                widget.onBatchFetchArtists();
              },
            ),
          ],
        ),

        // 3. 120Hz Motion & Gestures Customization Studio
        _sectionCard(
          title: '120Hz Motion, Gestures & Visuals',
          icon: Icons.bolt_rounded,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  _choiceChip('Snappy', NamiUxPrefs.motionSpeed == 'snappy', () {
                    setState(() => NamiUxPrefs.motionSpeed = 'snappy');
                    NamiUxPrefs.save();
                  }),
                  const SizedBox(width: 8),
                  _choiceChip('Balanced', NamiUxPrefs.motionSpeed == 'balanced', () {
                    setState(() => NamiUxPrefs.motionSpeed = 'balanced');
                    NamiUxPrefs.save();
                  }),
                  const SizedBox(width: 8),
                  _choiceChip('Silky', NamiUxPrefs.motionSpeed == 'silky', () {
                    setState(() => NamiUxPrefs.motionSpeed = 'silky');
                    NamiUxPrefs.save();
                  }),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            _toggleRow(
              icon: Icons.vibration_rounded,
              title: 'Haptic Detents',
              subtitle: 'Subtle tactile clicks on taps, scrubs & tab switches',
              value: NamiUxPrefs.hapticsEnabled,
              onChanged: (v) => NamiUxPrefs.hapticsEnabled = v,
            ),
            _toggleRow(
              icon: Icons.album_rounded,
              title: 'Breathing Cover Art',
              subtitle: 'Smooth play/pause scale animation on Now Playing',
              value: NamiUxPrefs.breathingCoverArt,
              onChanged: (v) => NamiUxPrefs.breathingCoverArt = v,
            ),
            _toggleRow(
              icon: Icons.blur_on_rounded,
              title: 'Synced Lyrics Blur Depth',
              subtitle: 'Apple Music-style blur on inactive lyric lines',
              value: NamiUxPrefs.lyricsBlurDepth,
              onChanged: (v) => NamiUxPrefs.lyricsBlurDepth = v,
            ),
            _toggleRow(
              icon: Icons.touch_app_rounded,
              title: 'Double-Tap Art for Lyrics',
              subtitle: 'Quickly toggle synced lyrics by double-tapping album art',
              value: NamiUxPrefs.doubleTapArtLyrics,
              onChanged: (v) => NamiUxPrefs.doubleTapArtLyrics = v,
            ),
            _toggleRow(
              icon: Icons.swipe_down_rounded,
              title: 'Interactive Swipe-Down Dismiss',
              subtitle: 'Drag down smoothly anywhere on Now Playing to close',
              value: NamiUxPrefs.swipeDownDismiss,
              onChanged: (v) => NamiUxPrefs.swipeDownDismiss = v,
            ),
          ],
        ),
      ],
    );
  }
}
