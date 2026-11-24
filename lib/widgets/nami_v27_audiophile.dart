part of '../main.dart';

/// Audiophile Engine & Daily-Driver Bridge (v2.7.0):
/// - True Gapless Playback via libmpv (`gapless-audio=yes`, `audio-buffer`)
/// - ReplayGain / Loudness Normalization (`replaygain=no|track|album`)
/// - Session & Queue Persistence (survives Android process kills)
/// - Android AMOLED Home Screen Widget sync & transport controls
class NamiAudiophileEngine {
  static const MethodChannel _widgetChannel = MethodChannel('com.piyush.nami/widget');
  static bool _widgetBound = false;

  static Future<void> applyMpvProperties(Player player) async {
    try {
      final dyn = player.platform as dynamic;
      await dyn.setProperty(
        'gapless-audio',
        NamiUxPrefs.gaplessPlayback ? 'yes' : 'no',
      );
      await dyn.setProperty(
        'audio-buffer',
        NamiUxPrefs.gaplessPlayback ? '0.6' : '0.2',
      );
      await dyn.setProperty('replaygain', NamiUxPrefs.replayGainMode);
      await dyn.setProperty('replaygain-preamp', '0');
      await dyn.setProperty('replaygain-clip', 'no');
    } catch (_) {}
  }

  static Future<void> saveSession({
    required AudioTrack? currentSong,
    required Duration position,
    List<AudioTrack>? queue,
    bool? shuffleEnabled,
  }) async {
    if (!NamiUxPrefs.persistSession || currentSong == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nami_v27_last_path', currentSong.path);
      await prefs.setInt('nami_v27_last_pos_ms', position.inMilliseconds);
      if (shuffleEnabled != null) {
        await prefs.setBool('nami_v27_shuffle', shuffleEnabled);
      }
      if (queue != null && queue.isNotEmpty) {
        final paths = queue.take(150).map((t) => t.path).toList();
        await prefs.setStringList('nami_v27_queue_paths', paths);
      }
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadSavedSession() async {
    await NamiUxPrefs.ensureLoaded();
    if (!NamiUxPrefs.persistSession) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPath = prefs.getString('nami_v27_last_path');
      if (lastPath == null || lastPath.isEmpty) return null;
      return {
        'path': lastPath,
        'posMs': prefs.getInt('nami_v27_last_pos_ms') ?? 0,
        'shuffle': prefs.getBool('nami_v27_shuffle') ?? false,
        'queuePaths': prefs.getStringList('nami_v27_queue_paths') ?? const <String>[],
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateHomeWidget({
    required String title,
    required String artist,
    required bool isPlaying,
    String? coverPath,
  }) async {
    try {
      await _widgetChannel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        'coverPath': coverPath ?? '',
      });
    } catch (_) {}
  }

  static void bindWidgetControls({
    required VoidCallback onPlayPause,
    required VoidCallback onNext,
    required VoidCallback onPrev,
  }) {
    if (_widgetBound) return;
    _widgetBound = true;
    _widgetChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'playPause':
          onPlayPause();
          break;
        case 'next':
          onNext();
          break;
        case 'prev':
          onPrev();
          break;
      }
    });
  }
}

/// Audiophile Engine & Daily-Driver Settings Card (Gapless, ReplayGain, Session, Widget)
class NamiAudiophileStudioCard extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onApplyAudioProps;
  final VoidCallback onSyncWidgetNow;

  const NamiAudiophileStudioCard({
    super.key,
    required this.accentColor,
    required this.onApplyAudioProps,
    required this.onSyncWidgetNow,
  });

  @override
  State<NamiAudiophileStudioCard> createState() => _NamiAudiophileStudioCardState();
}

class _NamiAudiophileStudioCardState extends State<NamiAudiophileStudioCard> {
  @override
  void initState() {
    super.initState();
    NamiUxPrefs.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _rgChip(String label, String mode) {
    final active = NamiUxPrefs.replayGainMode == mode;
    final accent = widget.accentColor;
    return Expanded(
      child: NamiSpringTap(
        pressedScale: 0.94,
        onTap: () {
          setState(() => NamiUxPrefs.replayGainMode = mode);
          NamiUxPrefs.save();
          widget.onApplyAudioProps();
        },
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

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
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
                Icon(Icons.high_quality_rounded, color: accent, size: 18),
                const SizedBox(width: 9),
                const Text(
                  'Audiophile Playback & Daily Driver',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
            secondary: const Icon(Icons.join_full_rounded, color: Colors.white70, size: 20),
            title: const Text('True Gapless Playback (libmpv)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
            subtitle: const Text('Seamless transitions on continuous albums & live sets', style: TextStyle(fontSize: 11, color: Colors.white54)),
            value: NamiUxPrefs.gaplessPlayback,
            activeThumbColor: accent,
            onChanged: (v) {
              NamiUxPrefs.hapticLight();
              setState(() => NamiUxPrefs.gaplessPlayback = v);
              NamiUxPrefs.save();
              widget.onApplyAudioProps();
            },
          ),
          const Divider(height: 1, color: Colors.white10),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'ReplayGain Loudness Normalization',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Balances mastering volume across Bollywood OSTs, DHH & FLAC rips',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _rgChip('Off', 'no'),
                const SizedBox(width: 8),
                _rgChip('Track Gain', 'track'),
                const SizedBox(width: 8),
                _rgChip('Album Gain', 'album'),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
            secondary: const Icon(Icons.history_rounded, color: Colors.white70, size: 20),
            title: const Text('Persist Queue & Resume Position', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
            subtitle: const Text('Saves active track, queue & exact timestamp automatically', style: TextStyle(fontSize: 11, color: Colors.white54)),
            value: NamiUxPrefs.persistSession,
            activeThumbColor: accent,
            onChanged: (v) {
              NamiUxPrefs.hapticLight();
              setState(() => NamiUxPrefs.persistSession = v);
              NamiUxPrefs.save();
            },
          ),
          const Divider(height: 1, color: Colors.white10),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Icon(Icons.widgets_rounded, color: accent, size: 20),
            title: const Text('AMOLED Home Screen Widget (4×1)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
            subtitle: const Text('Long-press your home screen -> Widgets -> Nami Music. Tap to refresh.', style: TextStyle(fontSize: 11, color: Colors.white54)),
            trailing: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 19),
            onTap: () {
              NamiUxPrefs.hapticLight();
              widget.onSyncWidgetNow();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Synced current track to Nami AMOLED Home Screen Widget!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
