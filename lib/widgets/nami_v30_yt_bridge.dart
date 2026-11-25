part of '../main.dart';

/// Cleanly derives a short audio format badge (`FLAC 24B`, `MP3`, `YT OPUS`, `YT M4A`, `YT STREAM`)
/// without ever leaking URL query parameters onto the UI.
String namiFormatBadgeForPath(
  String? path, {
  int bitDepth = 0,
  String fallback = 'AUDIO',
}) {
  if (path == null || path.isEmpty) return fallback;
  final lower = path.toLowerCase();
  if (lower.startsWith('yt://')) return 'YT STREAM';
  if (lower.contains('nami_yt_cache') || lower.contains('nami downloads')) {
    if (lower.endsWith('.webm') || lower.endsWith('.opus')) return 'YT OPUS';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'YT M4A';
    if (lower.endsWith('.ogg')) return 'YT OGG';
    if (lower.endsWith('.ts')) return 'YT HLS';
  }
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    if (lower.contains('.m3u8') || lower.contains('manifest/hls')) return 'YT HLS';
    if (lower.endsWith('.webm') ||
        lower.endsWith('.opus') ||
        lower.contains('mime=audio%2fwebm') ||
        lower.contains('opus') ||
        lower.contains('itag=251') ||
        lower.contains('itag=250')) {
      return 'YT OPUS';
    }
    if (lower.endsWith('.m4a') ||
        lower.endsWith('.mp4') ||
        lower.contains('mime=audio%2fmp4') ||
        lower.contains('m4a') ||
        lower.contains('itag=140')) {
      return 'YT M4A';
    }
    return 'YT AUDIO';
  }
  final clean = path.split('?').first;
  final ext = clean.contains('.') ? clean.split('.').last.toUpperCase() : fallback;
  final safeExt = (ext.isEmpty || ext.length > 8) ? fallback : ext;
  return bitDepth > 0 ? '$safeExt ${bitDepth}B' : safeExt;
}

/// Unified YouTube -> Local Chunked Cache -> libmpv Playback Bridge (`v3.1.0`):
/// - Downloads verified audio chunks to a local file so `libmpv` ALWAYS opens a real file path
///   (zero `Failed to open http://` errors, instant waveform seek, 0ms offline replay)
/// - Supports Unified Mixed Local FLAC + YouTube Queue (`yt://<videoId>` placeholders)
/// - Automatically pre-fetches the next YouTube track ~15s before the current track finishes
/// - Runs SponsorBlock auto-skip & Auto-Start Radio
class NamiYoutubePlaybackBridge {
  static final ValueNotifier<NamiYtTrack?> activeYtTrack =
      ValueNotifier<NamiYtTrack?>(null);
  static final ValueNotifier<List<NamiYtTrack>> radioQueue =
      ValueNotifier<List<NamiYtTrack>>(const []);
  static final ValueNotifier<bool> isResolving = ValueNotifier<bool>(false);

  static final Map<String, NamiYtTrack> _queuedMetaById = {};
  static final Set<String> _prefetchedIds = <String>{};
  static List<NamiYtSponsorSegment> _activeSegments = const [];
  static final Set<String> _skippedKeys = <String>{};
  static StreamSubscription<Duration>? _sbSub;
  static StreamSubscription<String>? _errSub;
  static int _playSeq = 0;

  static AudioTrack toAudioTrack(
    NamiYtTrack yt, {
    required String streamUrl,
    String? localThumbPath,
    Duration? resolvedDuration,
  }) {
    final dur = (resolvedDuration != null && resolvedDuration.inSeconds > 0)
        ? resolvedDuration
        : yt.duration;
    return AudioTrack(
      title: yt.title,
      artist: yt.artist,
      album: yt.album.isNotEmpty ? yt.album : 'YouTube Music',
      comment: 'yt:${yt.videoId}',
      path: streamUrl,
      thumbPath: localThumbPath ?? yt.cachedThumbPath,
      isMetadataLoaded: true,
      duration: dur,
    );
  }

  /// Inserts a YouTube track into Nami's unified `_playNextQueue` alongside local FLACs!
  static Future<void> queueYoutubeTrackAfter(NamiYtTrack yt) async {
    final shell = _NamiHomeShellState.activeInstance;
    if (shell == null) return;
    _queuedMetaById[yt.videoId] = yt;
    final thumb = await NamiYoutubeService.instance
        .ensureCachedThumbnail(yt.videoId, yt.thumbnailUrl);
    final placeholder = toAudioTrack(
      yt.copyWith(cachedThumbPath: thumb),
      streamUrl: 'yt://${yt.videoId}',
      localThumbPath: thumb,
    );
    shell._handleV29SwipePlayAfter(placeholder);
    // Warm up the audio file in the background so playback starts immediately when reached!
    unawaited(prefetchTrack(yt));
  }

  /// Silently downloads a YouTube track into `nami_yt_cache` in the background.
  static Future<void> prefetchTrack(NamiYtTrack yt) async {
    if (yt.videoId.isEmpty) return;
    if (NamiYtAudioCache.instance.findCachedFile(yt.videoId) != null) return;
    if (!_prefetchedIds.add(yt.videoId)) return;
    try {
      final stream = await NamiYoutubeService.instance.resolveAudioStream(
        yt.videoId,
        quality: NamiUxPrefs.youtubeAudioQuality,
        region: NamiUxPrefs.youtubeRegion,
      );
      if (stream != null) {
        await NamiYtAudioCache.instance.ensureCachedAudioFile(stream);
      }
    } catch (_) {
      _prefetchedIds.remove(yt.videoId);
    }
  }

  /// Resolves & plays a queued `yt://<videoId>` track from `_playNextQueue`.
  static Future<bool> playByVideoId(
    String videoId, {
    AudioTrack? fallbackMeta,
  }) async {
    final known = _queuedMetaById[videoId] ??
        NamiYoutubeStore.instance.history.cast<NamiYtTrack?>().firstWhere(
              (t) => t?.videoId == videoId,
              orElse: () => null,
            ) ??
        NamiYtTrack(
          videoId: videoId,
          title: fallbackMeta?.title ?? 'YouTube Track',
          artist: fallbackMeta?.artist ?? 'YouTube Music',
          duration: fallbackMeta?.duration ?? Duration.zero,
          thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
          cachedThumbPath: fallbackMeta?.thumbPath,
        );
    return playTrack(known);
  }

  /// Attaches SponsorBlock auto-skip, 15s mixed-queue pre-fetcher & MPV error logging.
  static void bindSponsorBlock(Player player) {
    _errSub?.cancel();
    _errSub = player.stream.error.listen((err) {
      if (err.trim().isEmpty) return;
      debugPrint('[NamiMPV Error] $err');
    });
    _sbSub?.cancel();
    _sbSub = player.stream.position.listen((pos) {
      final dur = player.state.duration;
      // 1. Background 15-second pre-fetch for gapless mixed local/YouTube queue transitions
      if (dur.inSeconds > 20 && (dur - pos).inSeconds <= 15) {
        final shell = _NamiHomeShellState.activeInstance;
        if (shell != null && shell._playNextQueue.isNotEmpty) {
          final nextQueued = shell._playNextQueue.first;
          if (nextQueued.path.startsWith('yt://')) {
            final vid = nextQueued.path.substring(5);
            final meta = _queuedMetaById[vid];
            if (meta != null) unawaited(prefetchTrack(meta));
          }
        } else if (radioQueue.value.isNotEmpty && activeYtTrack.value != null) {
          unawaited(prefetchTrack(radioQueue.value.first));
        }
      }

      // 2. SponsorBlock auto-skip
      if (!NamiUxPrefs.ytSponsorBlock || _activeSegments.isEmpty) return;
      final active = activeYtTrack.value;
      if (active == null) return;
      final sec = pos.inMilliseconds / 1000.0;
      for (final seg in _activeSegments) {
        final segKey = '${active.videoId}|${seg.startSec.toStringAsFixed(1)}';
        if (_skippedKeys.contains(segKey)) continue;
        if (sec >= seg.startSec && sec < seg.endSec - 0.8) {
          _skippedKeys.add(segKey);
          player.seek(Duration(milliseconds: (seg.endSec * 1000).round()));
          NamiLiveToastController.showMessage(
            'SponsorBlock skipped ${seg.category}',
            icon: Icons.fast_forward_rounded,
          );
          break;
        }
      }
    });
  }

  static void dispose() {
    _sbSub?.cancel();
    _sbSub = null;
    _errSub?.cancel();
    _errSub = null;
  }

  static Future<bool> playNextInRadioQueue() async {
    final shell = _NamiHomeShellState.activeInstance;
    if (shell != null && shell._playNextQueue.isNotEmpty) {
      final next = shell._playNextQueue.removeAt(0);
      if (next.path.startsWith('yt://')) {
        return playByVideoId(next.path.substring(5), fallbackMeta: next);
      }
      await shell._playSong(next);
      return true;
    }
    final q = radioQueue.value;
    if (q.isNotEmpty) {
      final next = q.first;
      final rest = q.skip(1).toList();
      return playTrack(next, upcoming: rest);
    }
    final activeId = activeYtTrack.value?.videoId;
    final hist = NamiYoutubeStore.instance.history;
    for (final h in hist) {
      if (h.videoId != activeId) {
        return playTrack(h);
      }
    }
    if (activeId != null && activeId.isNotEmpty) {
      final details = await NamiYoutubeService.instance.fetchWatchDetails(
        activeId,
        region: NamiUxPrefs.youtubeRegion,
        fetchDislikes: false,
      );
      if (details.relatedTracks.isNotEmpty) {
        return playTrack(
          details.relatedTracks.first,
          upcoming: details.relatedTracks.skip(1).toList(),
        );
      }
    }
    return false;
  }

  static Future<bool> playPrevInRadioQueue() async {
    final hist = NamiYoutubeStore.instance.history;
    if (hist.length < 2) return false;
    return playTrack(hist[1]);
  }

  static void clearActiveYoutubeTrack() {
    _activeSegments = const [];
    _skippedKeys.clear();
    _namiSafeSetNotifier<NamiYtTrack?>(activeYtTrack, null);
  }

  /// Resolves + caches YouTube audio to a verified local file (`nami_yt_cache/<videoId>.<ext>`)
  /// using 4-way parallel bounded DASH chunks, then plays directly from disk in `libmpv`!
  static Future<bool> playTrack(
    NamiYtTrack yt, {
    List<NamiYtTrack>? upcoming,
  }) async {
    final shell = _NamiHomeShellState.activeInstance;
    if (shell == null) return false;

    final mySeq = ++_playSeq;
    _namiSafeSetNotifier<bool>(isResolving, true);

    try {
      final svc = NamiYoutubeService.instance;
      final thumbFuture = svc.ensureCachedThumbnail(yt.videoId, yt.thumbnailUrl);

      // Fast-path: already cached on disk (0ms instant offline playback!)
      File? localAudioFile = NamiYtAudioCache.instance.findCachedFile(yt.videoId);
      String clientLabel = 'CACHED';
      Duration resolvedDur = yt.duration;

      if (localAudioFile == null) {
        NamiLiveToastController.showMessage(
          'Loading ${yt.title}...',
          icon: Icons.downloading_rounded,
          duration: const Duration(seconds: 8),
        );

        final exclude = <String>{};
        int lastPctToast = -1;

        for (int attempt = 0; attempt < 5; attempt++) {
          if (mySeq != _playSeq) return false;
          final stream = await svc.resolveAudioStream(
            yt.videoId,
            quality: NamiUxPrefs.youtubeAudioQuality,
            region: NamiUxPrefs.youtubeRegion,
            forceRefresh: attempt > 0,
            excludeClients: exclude,
            fallbackTitle: yt.title,
            fallbackArtist: yt.artist,
          );
          if (stream == null || stream.audioUrl.isEmpty) break;
          if (mySeq != _playSeq) return false;

          final file = await NamiYtAudioCache.instance.ensureCachedAudioFile(
            stream,
            isCancelled: () => mySeq != _playSeq,
            onProgress: (p, _, __) {
              if (mySeq != _playSeq) return;
              final pct = (p * 100).round();
              if (pct >= lastPctToast + 25 && pct < 100) {
                lastPctToast = pct;
                NamiLiveToastController.showMessage(
                  'Buffering ${yt.title} ($pct%)',
                  icon: Icons.downloading_rounded,
                  duration: const Duration(seconds: 4),
                );
              }
            },
          );

          if (file != null && file.existsSync()) {
            localAudioFile = file;
            clientLabel = stream.clientUsed;
            if (stream.duration.inSeconds > 0) resolvedDur = stream.duration;
            break;
          }
          exclude.add(stream.clientUsed);
        }
      }

      if (mySeq != _playSeq) return false;
      final cachedThumb = await thumbFuture;

      if (localAudioFile == null || !localAudioFile.existsSync()) {
        NamiLiveToastController.showMessage(
          (NamiYoutubeService.lastResolveDiagnostic.isNotEmpty ? 'YT: ${NamiYoutubeService.lastResolveDiagnostic}' : 'YouTube audio unavailable — check network or retry'),
          icon: Icons.error_outline_rounded,
        );
        return false;
      }

      final enrichedYt = yt.copyWith(
        cachedThumbPath: cachedThumb ?? yt.cachedThumbPath,
        duration: resolvedDur.inSeconds > 0 ? resolvedDur : yt.duration,
      );
      final audioTrack = toAudioTrack(
        enrichedYt,
        streamUrl: localAudioFile.path,
        localThumbPath: cachedThumb,
        resolvedDuration: resolvedDur,
      );

      _activeSegments = const [];
      _skippedKeys.clear();
      _namiSafeSetNotifier<NamiYtTrack?>(activeYtTrack, enrichedYt);

      // Play real local file directly in libmpv (zero HTTP/TLS/403 issues ever!)
      await shell._playV30YoutubeAudioTrack(audioTrack);
      await NamiYoutubeStore.instance.recordPlay(enrichedYt);

      NamiLiveToastController.showMessage(
        clientLabel == 'CACHED'
            ? 'Playing cached • ${namiFormatBadgeForPath(localAudioFile.path)}'
            : 'Playing • $clientLabel (${namiFormatBadgeForPath(localAudioFile.path)})',
        icon: Icons.graphic_eq_rounded,
        duration: const Duration(milliseconds: 2200),
      );

      if (NamiUxPrefs.ytSponsorBlock) {
        svc.fetchSponsorSegments(yt.videoId).then((segs) {
          if (activeYtTrack.value?.videoId == yt.videoId) {
            _activeSegments = segs;
          }
        });
      }

      if (upcoming != null && upcoming.isNotEmpty) {
        _namiSafeSetNotifier<List<NamiYtTrack>>(radioQueue, upcoming);
      } else if (NamiUxPrefs.ytAutoStartRadio) {
        svc
            .fetchWatchDetails(
              yt.videoId,
              region: NamiUxPrefs.youtubeRegion,
              fetchDislikes: NamiUxPrefs.ytReturnDislike,
            )
            .then((details) {
          if (activeYtTrack.value?.videoId == yt.videoId &&
              details.relatedTracks.isNotEmpty) {
            _namiSafeSetNotifier<List<NamiYtTrack>>(
              radioQueue,
              details.relatedTracks,
            );
          }
        });
      }
      return true;
    } catch (e) {
      debugPrint('[NamiYTBridge] playTrack error: $e');
      NamiLiveToastController.showMessage(
        'YouTube playback error — tap to retry',
        icon: Icons.wifi_off_rounded,
      );
      return false;
    } finally {
      if (mySeq == _playSeq) {
        _namiSafeSetNotifier<bool>(isResolving, false);
      }
    }
  }
}


/// Step 4 Beta Preview Sheet: test India-first `FEmusic_home`, live Search,
/// 1-tap `libmpv` streaming & Local History directly before Step 5 builds the full Option A 5th tab.
Future<void> showNamiYoutubeEngineBetaSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: namiSmoothSheetStyle,
    builder: (sheetCtx) => const _NamiYtBetaEngineSheet(),
  );
}

class _NamiYtBetaEngineSheet extends StatefulWidget {
  const _NamiYtBetaEngineSheet();

  @override
  State<_NamiYtBetaEngineSheet> createState() => _NamiYtBetaEngineSheetState();
}

class _NamiYtBetaEngineSheetState extends State<_NamiYtBetaEngineSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  String _mode = 'Feed'; // 'Feed' | 'Search' | 'History'
  List<NamiYtTrack> _tracks = const [];
  String _statusLabel = 'Loading India-first YouTube Music...';

  @override
  void initState() {
    super.initState();
    NamiYoutubeStore.instance.ensureLoaded().then((_) => _loadHomeFeed());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHomeFeed() async {
    setState(() {
      _loading = true;
      _mode = 'Feed';
      _statusLabel = 'Fetching YouTube Music (${NamiUxPrefs.youtubeRegion})...';
    });
    final shelves = await NamiYoutubeService.instance.fetchMusicHomeFeed(
      region: NamiUxPrefs.youtubeRegion,
    );
    final picked = <NamiYtTrack>[];
    for (final s in shelves) {
      picked.addAll(s.tracks);
    }
    if (!mounted) return;
    setState(() {
      _tracks = picked;
      _loading = false;
      _statusLabel = picked.isEmpty
          ? 'No feed tracks returned — try searching above'
          : '${picked.length} live tracks (${NamiUxPrefs.youtubeRegion})';
    });
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _loadHomeFeed();
      return;
    }
    setState(() {
      _loading = true;
      _mode = 'Search';
      _statusLabel = 'Searching "$q"...';
    });
    final hits = await NamiYoutubeService.instance.searchMusic(
      q,
      region: NamiUxPrefs.youtubeRegion,
      cleanQuery: NamiUxPrefs.ytSearchCleanup,
    );
    if (!mounted) return;
    setState(() {
      _tracks = hits;
      _loading = false;
      _statusLabel = hits.isEmpty
          ? 'No results for "$q"'
          : '${hits.length} results for "$q"';
    });
  }

  void _showHistory() {
    setState(() {
      _mode = 'History';
      _loading = false;
      _tracks = NamiYoutubeStore.instance.history;
      _statusLabel = '${_tracks.length} local YouTube listens';
    });
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap, Color accent) {
    return Expanded(
      child: NamiSpringTap(
        pressedScale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.18) : const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? accent.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.08),
              width: 0.9,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? accent : Colors.white70,
              fontSize: 12,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final h = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: h * 0.84,
        decoration: BoxDecoration(
          color: const Color(0xFF06060A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.play_circle_filled_rounded, color: accent, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YouTube Music Search',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Streams directly into Nami libmpv • USB DAC • Lyrics',
                          style: TextStyle(color: Colors.white54, fontSize: 11.2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 21),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search YouTube Music (e.g. Boom Shaka, 11K)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: accent, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
                    onPressed: () => _runSearch(_searchCtrl.text),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF12121A),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.65)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _modeChip('Music Feed', _mode == 'Feed', _loadHomeFeed, accent),
                  const SizedBox(width: 8),
                  _modeChip('Search', _mode == 'Search', () => _runSearch(_searchCtrl.text), accent),
                  const SizedBox(width: 8),
                  _modeChip('Local History', _mode == 'History', _showHistory, accent),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _statusLabel,
                      style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: NamiYoutubePlaybackBridge.isResolving,
                    builder: (_, busy, __) => busy
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : _tracks.isEmpty
                      ? const Center(
                          child: Text(
                            'No tracks yet — search any song above to stream via libmpv',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _tracks.length,
                          itemBuilder: (_, i) {
                            final t = _tracks[i];
                            final fav = NamiYoutubeStore.instance.isFavorite(t.videoId);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: Image.network(
                                    t.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF161620),
                                      child: const Icon(Icons.music_note_rounded, color: Colors.white38),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  t.artist,
                                  if (t.viewsText.isNotEmpty) t.viewsText,
                                  if (t.durationLabel.isNotEmpty) t.durationLabel,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Play Next',
                                    icon: const Icon(Icons.playlist_play_rounded, color: Colors.white60, size: 20),
                                    onPressed: () => NamiYoutubePlaybackBridge.queueYoutubeTrackAfter(t),
                                  ),
                                  IconButton(
                                    tooltip: 'Download Offline',
                                    icon: const Icon(Icons.download_rounded, color: Colors.white60, size: 19),
                                    onPressed: () => NamiYtDownloadManager.instance.enqueueDownload(t),
                                  ),
                                ],
                              ),
                              onTap: () {
                                NamiUxPrefs.hapticLight();
                                NamiYoutubePlaybackBridge.playTrack(t);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
