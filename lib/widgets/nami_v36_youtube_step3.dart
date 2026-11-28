part of '../main.dart';

/// On-Device YouTube Taste, Resume-Timestamp, Dislike, History-Pause & Not-Interested Engine (`v3.6.2`).
class NamiYtTasteEngine {
  static const String _resumeKey = 'nami_v36_yt_resume_ms_v1';
  static const String _dislikesKey = 'nami_v36_yt_dislikes_v1';
  static const String _hiddenKey = 'nami_v36_yt_not_interested_v1';
  static const String _pauseHistKey = 'nami_v36_yt_pause_history_v1';

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, int> _resumeMs = {};
  static final Set<String> _dislikedIds = <String>{};
  static final Set<String> _hiddenIds = <String>{};
  static bool pauseWatchHistory = false;
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      pauseWatchHistory = prefs.getBool(_pauseHistKey) ?? false;
      final rawRes = prefs.getString(_resumeKey);
      if (rawRes != null && rawRes.isNotEmpty) {
        final m = jsonDecode(rawRes);
        if (m is Map) {
          m.forEach((k, v) {
            final n = (v as num?)?.toInt() ?? 0;
            if (n > 0) _resumeMs[k.toString()] = n;
          });
        }
      }
      _dislikedIds.addAll(prefs.getStringList(_dislikesKey) ?? const []);
      _hiddenIds.addAll(prefs.getStringList(_hiddenKey) ?? const []);
      _bump();
    } catch (_) {}
  }

  static void _bump() {
    _namiSafeSetNotifier<int>(revision, revision.value + 1);
  }

  static int resumePositionMs(String videoId) => _resumeMs[videoId] ?? 0;

  static Future<void> saveResumePosition(String videoId, Duration pos, Duration dur) async {
    if (videoId.isEmpty) return;
    final pMs = pos.inMilliseconds;
    final dMs = dur.inMilliseconds;
    if (dMs > 15000 && pMs >= (dMs * 0.92).round()) {
      _resumeMs.remove(videoId);
    } else if (pMs >= 4000) {
      _resumeMs[videoId] = pMs;
      if (_resumeMs.length > 120) {
        _resumeMs.remove(_resumeMs.keys.first);
      }
    } else {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_resumeKey, jsonEncode(_resumeMs));
    } catch (_) {}
  }

  static bool isDisliked(String videoId) => _dislikedIds.contains(videoId);

  static Future<bool> toggleDislike(String videoId) async {
    final added = _dislikedIds.add(videoId);
    if (!added) _dislikedIds.remove(videoId);
    _bump();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dislikesKey, _dislikedIds.toList());
    } catch (_) {}
    return added;
  }

  static Future<void> clearDislike(String videoId) async {
    if (_dislikedIds.remove(videoId)) {
      _bump();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_dislikesKey, _dislikedIds.toList());
      } catch (_) {}
    }
  }

  static bool isHidden(String videoId) => _hiddenIds.contains(videoId);

  static Future<void> markNotInterested(String videoId) async {
    if (_hiddenIds.add(videoId)) {
      _bump();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
      } catch (_) {}
    }
  }

  static Future<void> setPauseWatchHistory(bool pause) async {
    pauseWatchHistory = pause;
    _bump();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pauseHistKey, pause);
    } catch (_) {}
  }

  /// Extracts top artists from BOTH YouTube play history AND the user's offline FLAC library!
  static List<String> topTasteArtists({int limit = 6}) {
    final scores = <String, int>{};

    void addArtist(String raw, int weight) {
      final clean = raw
          .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
          .split(RegExp(r'[,&•|]'))
          .first
          .trim();
      if (clean.length < 2) return;
      final lower = clean.toLowerCase();
      if (lower == 'unknown' ||
          lower == 'unknown artist' ||
          lower == 'youtube' ||
          lower == 'various artists') {
        return;
      }
      scores[clean] = (scores[clean] ?? 0) + weight;
    }

    // 1. Weight YouTube history heavily (most recent + most played)
    final hist = NamiYoutubeStore.instance.history;
    for (int i = 0; i < hist.length && i < 20; i++) {
      final t = hist[i];
      addArtist(t.artist, 6 + (t.playCount * 2) + (i < 5 ? 4 : 0));
    }
    for (final ch in NamiYoutubeStore.instance.subscribedChannels) {
      addArtist(ch.name, 8);
    }

    // 2. Cross-seed from offline FLAC library songs (gives instant personalization on day 1!)
    final shell = _NamiHomeShellState.activeInstance;
    final localSongs = shell?._songs ?? const <AudioTrack>[];
    for (int i = 0; i < localSongs.length && i < 160; i++) {
      addArtist(localSongs[i].artist, 2);
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Reads recent YouTube search queries to enrich Home/Music recommendations.
  static Future<List<String>> recentSearchTerms({int limit = 4}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList('nami_v35_yt_search_history_v1') ?? const [])
          .take(limit)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Audio vs Video Download Picker Sheet (`v3.6.2`):
/// Lets users download either Audio (Opus/M4A) OR Video (480p/720p MP4) cleanly!
Future<void> showNamiYtDownloadPickerSheet(
  BuildContext context,
  NamiYtTrack track,
) async {
  NamiUxPrefs.hapticLight();
  final formats = NamiYtVideoBridge.activeVideoFormats.value.isNotEmpty &&
          NamiYoutubePlaybackBridge.activeYtTrack.value?.videoId == track.videoId
      ? NamiYtVideoBridge.activeVideoFormats.value
      : NamiYoutubeService.instance.cachedVideoFormatsFor(track.videoId);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: namiSmoothSheetStyle,
    builder: (sheetCtx) {
      final accent = Theme.of(sheetCtx).colorScheme.primary;
      final vidOptions = formats
          .where((f) => f.mimeType.contains('mp4') && f.height >= 360 && f.height <= 1080)
          .take(3)
          .toList();
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B11),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Download • ${track.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose offline Audio or Video format',
                style: TextStyle(color: Colors.white54, fontSize: 11.8),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: NamiCustomIcon(NamiCustomIcons.headphones, size: 21),
                ),
                title: const Text(
                  'Audio Only (Opus / M4A)',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Quality: ${NamiUxPrefs.youtubeAudioQuality} • Instant offline playback',
                  style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                ),
                trailing: Icon(Icons.download_rounded, color: accent, size: 22),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  NamiYtDownloadManager.instance.enqueueDownload(track);
                },
              ),
              const Divider(color: Colors.white10),
              if (vidOptions.isNotEmpty)
                for (final fmt in vidOptions)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF151520),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.ondemand_video_rounded, color: Colors.white70, size: 20),
                    ),
                    title: Text(
                      'Video ${fmt.qualityLabel} (MP4)',
                      style: const TextStyle(color: Colors.white, fontSize: 13.8, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${fmt.sizeLabelFor(track.duration)} • ${fmt.bitrateLabel}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                    ),
                    trailing: const Icon(Icons.download_outlined, color: Colors.white70, size: 20),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _enqueueYoutubeVideoDownload(track, fmt);
                    },
                  )
              else
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF151520),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.ondemand_video_rounded, color: Colors.white70, size: 20),
                  ),
                  title: const Text(
                    'Video 480p / 720p (MP4)',
                    style: TextStyle(color: Colors.white, fontSize: 13.8, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Resolves best MP4 video + offline audio track',
                    style: TextStyle(color: Colors.white54, fontSize: 11.4),
                  ),
                  trailing: const Icon(Icons.download_outlined, color: Colors.white70, size: 20),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _enqueueYoutubeVideoDownload(track, null);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _enqueueYoutubeVideoDownload(
  NamiYtTrack track,
  NamiYtVideoFormat? chosenFmt,
) async {
  // Always ensure offline audio is queued in NamiYtDownloadManager too!
  unawaited(NamiYtDownloadManager.instance.enqueueDownload(track));
  NamiLiveToastController.showMessage(
    'Downloading video (${chosenFmt?.qualityLabel ?? '480p'})...',
    icon: Icons.ondemand_video_rounded,
  );
  try {
    NamiYtVideoFormat? fmt = chosenFmt;
    if (fmt == null) {
      final bundle = await NamiYoutubeService.instance.resolveMediaBundle(
        track.videoId,
        quality: NamiUxPrefs.youtubeAudioQuality,
        region: NamiUxPrefs.youtubeRegion,
      );
      final mp4s = (bundle?.videoFormats ?? const <NamiYtVideoFormat>[])
          .where((f) => f.mimeType.contains('mp4'))
          .toList();
      if (mp4s.isNotEmpty) {
        fmt = mp4s.firstWhere(
          (f) => f.height <= 720 && f.height >= 360,
          orElse: () => mp4s.last,
        );
      }
    }
    if (fmt == null) return;
    final vidStream = NamiYtStreamResult(
      videoId: '${track.videoId}_vid',
      audioUrl: fmt.url,
      mimeType: fmt.mimeType,
      bitrate: fmt.bitrate,
      duration: track.duration,
      headers: {
        ...fmt.headers,
        if (fmt.contentLength > 0) 'X-Nami-Content-Length': '${fmt.contentLength}',
      },
      expiresAtMs: DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
      clientUsed: 'DL_${fmt.qualityLabel}',
    );
    final file = await NamiYtAudioCache.instance.ensureCachedAudioFile(
      vidStream,
      maxCacheMb: NamiUxPrefs.ytMaxCacheMb,
    );
    if (file != null && file.existsSync()) {
      NamiLiveToastController.showMessage(
        'Saved ${fmt.qualityLabel} video offline • ${track.title}',
        icon: Icons.download_done_rounded,
      );
    }
  } catch (_) {}
}

// =============================================================================
// STEP 3: HISTORY-POWERED YOUTUBE MUSIC TAB (Cross-Seeded with Offline FLAC Artists!)
// =============================================================================
class NamiYoutubeSmartMusicTab extends StatefulWidget {
  const NamiYoutubeSmartMusicTab({super.key});

  @override
  State<NamiYoutubeSmartMusicTab> createState() => _NamiYoutubeSmartMusicTabState();
}

class _NamiYoutubeSmartMusicTabState extends State<NamiYoutubeSmartMusicTab>
    with AutomaticKeepAliveClientMixin {
  static const List<String> _moods = ['All', 'Energize', 'Chill', 'Workout', 'Focus', 'Commute'];

  String _activeMood = 'All';
  bool _loading = true;
  List<NamiYtTrack> _quickPicks = const [];
  List<Map<String, dynamic>> _personalMixes = const [];
  List<NamiYtTrack> _newReleases = const [];
  List<String> _seedArtists = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    NamiYoutubeStore.instance.revision.addListener(_onHistoryUpdated);
    _loadMusicFeed();
  }

  @override
  void dispose() {
    NamiYoutubeStore.instance.revision.removeListener(_onHistoryUpdated);
    super.dispose();
  }

  void _onHistoryUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMusicFeed({bool force = false}) async {
    if (mounted) setState(() => _loading = true);
    await NamiYtTasteEngine.ensureLoaded();
    final svc = NamiYoutubeService.instance;
    final region = NamiUxPrefs.youtubeRegion;
    final artists = NamiYtTasteEngine.topTasteArtists(limit: 5);
    final hist = NamiYoutubeStore.instance.history;

    final picks = <NamiYtTrack>[];
    final seen = <String>{};
    final mixes = <Map<String, dynamic>>[];

    // 1. Seed Quick Picks from last played YouTube tracks + top taste artists (FLAC + YT!)
    final futures = <Future<List<NamiYtTrack>>>[];
    if (_activeMood != 'All') {
      final moodLead = artists.isNotEmpty ? artists.first : (region == 'IN' ? 'hindi punjabi' : 'music');
      futures.add(svc.searchMusic('$_activeMood $moodLead music mix', region: region, limit: 16));
      futures.add(svc.searchMusic('$_activeMood songs playlist 2026', region: region, limit: 14));
    } else {
      if (hist.isNotEmpty) {
        futures.add(
          svc
              .fetchWatchDetails(hist.first.videoId, region: region, fetchDislikes: false)
              .then((d) => d.relatedTracks)
              .catchError((_) => const <NamiYtTrack>[]),
        );
      }
      for (final a in artists.take(3)) {
        futures.add(svc.searchMusic('$a top songs', region: region, limit: 10));
      }
      if (futures.isEmpty) {
        futures.add(svc.searchMusic(region == 'IN' ? 'top hindi punjabi dhh songs 2026' : 'top music hits 2026', region: region, limit: 18));
      }
    }

    final relFuture = svc.searchMusic(
      region == 'IN' ? 'new hindi punjabi dhh song release 2026' : 'new music releases 2026',
      region: region,
      limit: 14,
    );

    final batches = await Future.wait(futures);
    for (int i = 0; i < batches.length; i++) {
      final list = batches[i].where((t) => !NamiYtTasteEngine.isHidden(t.videoId)).toList();
      for (final t in list) {
        if (seen.add(t.videoId)) picks.add(t);
      }
      // Build personal artist radio mixes from each artist batch!
      if (_activeMood == 'All') {
        final artistOffset = hist.isNotEmpty ? i - 1 : i;
        if (artistOffset >= 0 && artistOffset < artists.length && list.isNotEmpty) {
          mixes.add({
            'title': '${artists[artistOffset]} Mix',
            'subtitle': '${list.length} tracks • Based on your library & history',
            'cover': list.first.thumbnailUrl,
            'tracks': list,
          });
        }
      }
    }

    if (picks.isNotEmpty) {
      mixes.insert(0, {
        'title': _activeMood == 'All' ? 'My Supermix' : '$_activeMood Mix',
        'subtitle': artists.isNotEmpty
            ? artists.take(3).join(', ')
            : 'Tailored from your listening history',
        'cover': picks.first.thumbnailUrl,
        'tracks': picks.take(20).toList(),
      });
    }

    final releases = (await relFuture)
        .where((t) => !NamiYtTasteEngine.isHidden(t.videoId))
        .toList();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _seedArtists = artists;
      _quickPicks = picks.take(20).toList();
      _personalMixes = mixes;
      _newReleases = releases;
    });
  }

  Widget _buildQuickPickTile(NamiYtTrack t, List<NamiYtTrack> queue, Color accent) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        NamiUxPrefs.hapticLight();
        openNamiYoutubeWatchScreen(context, t, queue: queue, startVideoMode: true);
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Image.network(
                  t.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF161622),
                    child: const NamiCustomIcon(NamiCustomIcons.tracks, opacity: 0.45),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2.5),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              tooltip: 'Download',
              icon: const Icon(Icons.download_outlined, color: Colors.white54, size: 18),
              onPressed: () => showNamiYtDownloadPickerSheet(context, t),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = Theme.of(context).colorScheme.primary;
    final listenAgain = NamiYoutubeStore.instance.history
        .where((t) => !NamiYtTasteEngine.isHidden(t.videoId))
        .take(12)
        .toList();

    return RefreshIndicator(
      color: accent,
      backgroundColor: const Color(0xFF12121A),
      onRefresh: () => _loadMusicFeed(force: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 168),
        children: [
          // 1. Mood & Activity Filter Chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final mood in _moods)
                  GestureDetector(
                    onTap: () {
                      if (_activeMood == mood) return;
                      NamiUxPrefs.hapticLight();
                      setState(() => _activeMood = mood);
                      _loadMusicFeed();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeMood == mood ? Colors.white : const Color(0xFF14141C),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _activeMood == mood ? Colors.white : Colors.white12,
                        ),
                      ),
                      child: Text(
                        mood,
                        style: TextStyle(
                          color: _activeMood == mood ? Colors.black : Colors.white70,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Listen Again (0ms instant replay from history/cache!)
          if (listenAgain.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'Listen Again',
                style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: listenAgain.length,
                itemBuilder: (_, i) {
                  final t = listenAgain[i];
                  return GestureDetector(
                    onTap: () => openNamiYoutubeWatchScreen(context, t, queue: listenAgain, startVideoMode: true),
                    child: Container(
                      width: 112,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 112,
                              height: 102,
                              child: Image.network(
                                t.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161622)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            t.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 10.8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Quick Picks (2-Row Horizontal Swipeable Grid tailored to your taste!)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _seedArtists.isNotEmpty
                            ? 'SEEDED FROM ${_seedArtists.take(2).join(' • ').toUpperCase()}'
                            : 'START RADIO FROM A SONG',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Quick Picks',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                if (_quickPicks.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      NamiUxPrefs.hapticLight();
                      openNamiYoutubeWatchScreen(
                        context,
                        _quickPicks.first,
                        queue: _quickPicks,
                        startVideoMode: true,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accent.withValues(alpha: 0.55)),
                      ),
                      child: Text(
                        'Play All',
                        style: TextStyle(color: accent, fontSize: 11.8, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_loading && _quickPicks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
            )
          else if (_quickPicks.isNotEmpty)
            SizedBox(
              height: 142,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: (_quickPicks.length + 1) ~/ 2,
                itemBuilder: (_, col) {
                  final i1 = col * 2;
                  final i2 = i1 + 1;
                  return Column(
                    children: [
                      _buildQuickPickTile(_quickPicks[i1], _quickPicks, accent),
                      if (i2 < _quickPicks.length)
                        _buildQuickPickTile(_quickPicks[i2], _quickPicks, accent),
                    ],
                  );
                },
              ),
            ),

          // 4. Personal Artist Mixes (My Supermix + Top Artist Radio Mixes)
          if (_personalMixes.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                'Mixed For You',
                style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(
              height: 176,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _personalMixes.length,
                itemBuilder: (_, i) {
                  final mix = _personalMixes[i];
                  final tracks = (mix['tracks'] as List).cast<NamiYtTrack>();
                  return GestureDetector(
                    onTap: () {
                      if (tracks.isEmpty) return;
                      NamiUxPrefs.hapticLight();
                      openNamiYoutubeWatchScreen(
                        context,
                        tracks.first,
                        queue: tracks,
                        startVideoMode: true,
                      );
                    },
                    child: Container(
                      width: 148,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 148,
                                  height: 120,
                                  child: Image.network(
                                    mix['cover'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161622)),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const NamiCustomIcon(NamiCustomIcons.play, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mix['title'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            mix['subtitle'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // 5. New Music Releases
          if (_newReleases.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'New Music Releases',
                style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900),
              ),
            ),
            for (final t in _newReleases.take(10))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 56,
                    height: 46,
                    child: Image.network(
                      t.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161622)),
                    ),
                  ),
                ),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  t.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                ),
                trailing: IconButton(
                  icon: const NamiCustomIcon(NamiCustomIcons.playlist, size: 20, opacity: 0.65),
                  onPressed: () => NamiYoutubePlaybackBridge.queueYoutubeTrackAfter(t),
                ),
                onTap: () => openNamiYoutubeWatchScreen(context, t, queue: _newReleases, startVideoMode: true),
              ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// STEP 3: UNIFIED LIBRARY TAB (MERGES SS2 PLAYLISTS + SS3 DOWNLOADS INTO ONE!)
// =============================================================================
class NamiYoutubeUnifiedLibraryTab extends StatefulWidget {
  const NamiYoutubeUnifiedLibraryTab({super.key});

  @override
  State<NamiYoutubeUnifiedLibraryTab> createState() => _NamiYoutubeUnifiedLibraryTabState();
}

class _NamiYoutubeUnifiedLibraryTabState extends State<NamiYoutubeUnifiedLibraryTab>
    with AutomaticKeepAliveClientMixin {
  int _mostPlayedDays = 0; // 0 = All time | 7 = 7d | 30 = 30d
  String _dlFilter = 'All'; // All | Ongoing | Finished

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    NamiYtTasteEngine.ensureLoaded();
    NamiYoutubeStore.instance.revision.addListener(_refresh);
    NamiYtTasteEngine.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    NamiYoutubeStore.instance.revision.removeListener(_refresh);
    NamiYtTasteEngine.revision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _showCreatePlaylistDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF101018),
        title: const Text(
          'New YouTube Playlist',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(ctrl.text.trim()),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await NamiYoutubeStore.instance.createPlaylist(name);
      NamiLiveToastController.showMessage('Created "$name"', icon: Icons.playlist_add_check_rounded);
    }
  }

  Widget _buildHorizStrip(List<NamiYtTrack> list, {bool allowHide = false}) {
    if (list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 152,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: list.length.clamp(0, 16),
        itemBuilder: (_, i) {
          final t = list[i];
          final resumeMs = NamiYtTasteEngine.resumePositionMs(t.videoId);
          final durMs = t.duration.inMilliseconds;
          final resumeFrac = (resumeMs > 0 && durMs > 0) ? (resumeMs / durMs).clamp(0.0, 1.0) : 0.0;
          return GestureDetector(
            onTap: () => openNamiYoutubeWatchScreen(context, t, queue: list, startVideoMode: true),
            onLongPress: allowHide
                ? () {
                    NamiUxPrefs.hapticLight();
                    NamiYtTasteEngine.markNotInterested(t.videoId);
                    NamiLiveToastController.showMessage('Hidden from history', icon: Icons.visibility_off_outlined);
                  }
                : null,
            child: Container(
              width: 162,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SizedBox(
                      width: 162,
                      height: 92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            t.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161622)),
                          ),
                          if (t.duration.inSeconds > 0)
                            Positioned(
                              right: 5,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.84),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  t.durationLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          if (resumeFrac > 0.03)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 3,
                              child: LinearProgressIndicator(
                                value: resumeFrac,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12.4, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = Theme.of(context).colorScheme.primary;
    final store = NamiYoutubeStore.instance;
    final history = store.history.where((t) => !NamiYtTasteEngine.isHidden(t.videoId)).toList();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoffMs = _mostPlayedDays == 0 ? 0 : nowMs - (_mostPlayedDays * 86400000);
    final mostPlayed = history
        .where((t) => cutoffMs == 0 || t.lastPlayedMs >= cutoffMs)
        .toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final favs = store.favorites;
    final playlists = store.playlists;

    final shell = _NamiHomeShellState.activeInstance;
    final mornyeLocal = (shell?._songs ?? const <AudioTrack>[])
        .where((s) => s.path.toLowerCase().contains('mornye') || s.path.toLowerCase().contains('download'))
        .take(20)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 168),
      children: [
        // 1. DOWNLOADS SECTION (Merged cleanly from Ss3!)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 9),
              const Text(
                'Downloads',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              for (final f in const ['All', 'Ongoing', 'Finished'])
                GestureDetector(
                  onTap: () => setState(() => _dlFilter = f),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _dlFilter == f ? accent.withValues(alpha: 0.22) : const Color(0xFF14141C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _dlFilter == f ? accent : Colors.white12),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: _dlFilter == f ? accent : Colors.white70,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ValueListenableBuilder<List<NamiYtDownloadTask>>(
          valueListenable: NamiYtDownloadManager.instance.tasks,
          builder: (_, tasks, __) {
            final filtered = tasks.where((t) {
              if (_dlFilter == 'Ongoing') {
                return t.status == NamiYtDlStatus.downloading || t.status == NamiYtDlStatus.queued;
              }
              if (_dlFilter == 'Finished') {
                return t.status == NamiYtDlStatus.completed;
              }
              return true;
            }).toList();

            if (filtered.isEmpty && mornyeLocal.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text(
                  'No offline YouTube downloads yet — tap Download on any video',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final task in filtered)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 54,
                        height: 44,
                        child: Image.network(
                          task.track.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161622)),
                        ),
                      ),
                    ),
                    title: Text(
                      task.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700),
                    ),
                    subtitle: task.status == NamiYtDlStatus.downloading
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: task.progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(accent),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(task.progress * 100).round()}% • Downloading...',
                                style: const TextStyle(color: Colors.white54, fontSize: 10.8),
                              ),
                            ],
                          )
                        : Text(
                            task.status == NamiYtDlStatus.completed
                                ? '${task.track.artist} • Ready offline'
                                : (task.status == NamiYtDlStatus.failed
                                    ? 'Failed — tap retry'
                                    : 'Queued...'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                          ),
                    trailing: task.status == NamiYtDlStatus.completed
                        ? Icon(Icons.check_circle_outline_rounded, color: accent, size: 20)
                        : (task.status == NamiYtDlStatus.failed
                            ? IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                                onPressed: () => NamiYtDownloadManager.instance.enqueueDownload(task.track),
                              )
                            : const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )),
                    onTap: () => openNamiYoutubeWatchScreen(context, task.track, startVideoMode: true),
                  ),
                if (mornyeLocal.isNotEmpty && _dlFilter != 'Ongoing') ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'MORNYE & LOCAL DOWNLOADS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10.6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  for (final s in mornyeLocal.take(6))
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: s.thumbPath != null && File(s.thumbPath!).existsSync()
                              ? Image.file(File(s.thumbPath!), fit: BoxFit.cover, cacheWidth: 144)
                              : Container(
                                  color: const Color(0xFF181824),
                                  child: const NamiCustomIcon(NamiCustomIcons.tracks, size: 20, opacity: 0.45),
                                ),
                        ),
                      ),
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        s.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                      ),
                      trailing: const Icon(Icons.check_circle_outline_rounded, color: Colors.white54, size: 19),
                      onTap: () => shell?._playSong(s),
                    ),
                ],
              ],
            );
          },
        ),
        const Divider(color: Colors.white10, height: 22),

        // 2. HISTORY SECTION (with Pause Watch History Toggle!)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('History', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                  Text('${history.length} Videos', style: const TextStyle(color: Colors.white54, fontSize: 11.4)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  NamiUxPrefs.hapticLight();
                  final next = !NamiYtTasteEngine.pauseWatchHistory;
                  NamiYtTasteEngine.setPauseWatchHistory(next);
                  NamiLiveToastController.showMessage(
                    next ? 'Watch history paused' : 'Watch history resumed',
                    icon: next ? Icons.pause_circle_outline_rounded : Icons.history_rounded,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: NamiYtTasteEngine.pauseWatchHistory
                        ? accent.withValues(alpha: 0.20)
                        : const Color(0xFF14141C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: NamiYtTasteEngine.pauseWatchHistory ? accent : Colors.white12,
                    ),
                  ),
                  child: Text(
                    NamiYtTasteEngine.pauseWatchHistory ? 'Paused' : 'Pause',
                    style: TextStyle(
                      color: NamiYtTasteEngine.pauseWatchHistory ? accent : Colors.white70,
                      fontSize: 11.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildHorizStrip(history, allowHide: true),
        const SizedBox(height: 12),

        // 3. MOST PLAYED SECTION (working All time | 7d | 30d filter!)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: Colors.white70, size: 20),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Most Played', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                  Text('${mostPlayed.length} Videos', style: const TextStyle(color: Colors.white54, fontSize: 11.4)),
                ],
              ),
              const Spacer(),
              for (final opt in const [(0, 'All time'), (7, '7d'), (30, '30d')])
                GestureDetector(
                  onTap: () => setState(() => _mostPlayedDays = opt.$1),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _mostPlayedDays == opt.$1 ? const Color(0xFF222230) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _mostPlayedDays == opt.$1 ? Colors.white24 : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        color: _mostPlayedDays == opt.$1 ? Colors.white : Colors.white54,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildHorizStrip(mostPlayed),
        const SizedBox(height: 12),

        // 4. FAVOURITES SECTION
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.favorite_border_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Favourites', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                  Text('${favs.length} Videos', style: const TextStyle(color: Colors.white54, fontSize: 11.4)),
                ],
              ),
            ],
          ),
        ),
        _buildHorizStrip(favs),
        const SizedBox(height: 12),

        // 5. PLAYLISTS SECTION (with working + Add!)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Row(
            children: [
              const NamiCustomIcon(NamiCustomIcons.playlist, size: 22, opacity: 0.78),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Playlists - ${playlists.length}', style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                  const Text('Local YouTube Playlists', style: TextStyle(color: Colors.white54, fontSize: 11.4)),
                ],
              ),
              const Spacer(),
              NamiSpringTap(
                pressedScale: 0.94,
                onTap: _showCreatePlaylistDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141C),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Add', style: TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final pl in playlists)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: NamiCustomIcon(NamiCustomIcons.playlist, size: 24),
            ),
            title: Text(
              pl.name,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${pl.videoIds.length} videos',
              style: const TextStyle(color: Colors.white54, fontSize: 11.6),
            ),
            trailing: const NamiCustomIcon(NamiCustomIcons.play, size: 22, opacity: 0.78),
            onTap: () {
              final tracks = store.tracksForPlaylist(pl);
              if (tracks.isEmpty) {
                NamiLiveToastController.showMessage('Playlist "${pl.name}" is empty', icon: Icons.playlist_play_rounded);
                return;
              }
              openNamiYoutubeWatchScreen(context, tracks.first, queue: tracks, startVideoMode: true);
            },
          ),
      ],
    );
  }
}
