part of '../main.dart';

/// Dart bridge to AndroidX Media3 ExoPlayer native Video Viewport
/// (`com.piyush.nami/yt_video`) synced 1:1 to `libmpv` audio playback.
class NamiYtVideoBridge {
  static const MethodChannel _ch = MethodChannel('com.piyush.nami/yt_video');
  static final ValueNotifier<List<NamiYtVideoFormat>> activeVideoFormats =
      ValueNotifier<List<NamiYtVideoFormat>>(const []);
  static final ValueNotifier<String> selectedQuality =
      ValueNotifier<String>('Audio Only');
  static final ValueNotifier<String> videoState =
      ValueNotifier<String>('idle'); // idle | buffering | ready | error | ended
  static final ValueNotifier<String> lastVideoError =
      ValueNotifier<String>('');
  static bool _handlerBound = false;

  static void ensureBound() {
    if (_handlerBound) return;
    _handlerBound = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onVideoState' && call.arguments is Map) {
        final args = call.arguments as Map;
        final st = (args['state'] ?? 'idle').toString();
        final det = (args['detail'] ?? '').toString();
        _namiSafeSetNotifier<String>(videoState, st);
        if (det.isNotEmpty) _namiSafeSetNotifier<String>(lastVideoError, det);
      }
    });
  }

  static Future<void> loadVideo({
    required String url,
    Map<String, String> headers = const {},
    int seekMs = 0,
    bool playing = true,
    double speed = 1.0,
  }) async {
    ensureBound();
    _namiSafeSetNotifier<String>(videoState, 'buffering');
    _namiSafeSetNotifier<String>(lastVideoError, '');
    try {
      await _ch.invokeMethod<void>('loadVideo', {
        'url': url,
        'headers': headers,
        'seekMs': seekMs,
        'playing': playing,
        'speed': speed,
      });
    } catch (_) {}
  }

  static Future<void> syncState({
    required int positionMs,
    required bool playing,
  }) async {
    try {
      await _ch.invokeMethod<void>('syncState', {
        'positionMs': positionMs,
        'playing': playing,
      });
    } catch (_) {}
  }

  static Future<void> setSpeed(double speed) async {
    try {
      await _ch.invokeMethod<void>('setSpeed', {'speed': speed});
    } catch (_) {}
  }

  static Future<void> stopVideo() async {
    _namiSafeSetNotifier<String>(videoState, 'idle');
    try {
      await _ch.invokeMethod<void>('stopVideo');
    } catch (_) {}
  }
}

/// Opens Nami's full-featured AMOLED YouTube Audio/Video Watch Page (modeled on full YouTube player).
Future<void> openNamiYoutubeWatchScreen(
  BuildContext context,
  NamiYtTrack track, {
  List<NamiYtTrack>? queue,
  bool startVideoMode = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => NamiYoutubeWatchScreen(
        initialTrack: track,
        initialQueue: queue,
        startVideoMode: startVideoMode,
      ),
    ),
  );
}

/// Opens Nami's full-featured YouTube Channel Detail Screen (Banner, Subs, Home/Videos/Shorts/Releases/Playlists).
Future<void> openNamiYoutubeChannelScreen(
  BuildContext context, {
  required String channelId,
  String channelName = '',
  String channelAvatarUrl = '',
  String subscriberText = '',
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => NamiYoutubeChannelScreen(
        channelId: channelId,
        initialName: channelName,
        initialAvatarUrl: channelAvatarUrl,
        initialSubs: subscriberText,
      ),
    ),
  );
}

// =============================================================================
// FULL-SCREEN AMOLED YOUTUBE AUDIO / VIDEO WATCH SCREEN
// =============================================================================
class NamiYoutubeWatchScreen extends StatefulWidget {
  final NamiYtTrack initialTrack;
  final List<NamiYtTrack>? initialQueue;
  final bool startVideoMode;

  const NamiYoutubeWatchScreen({
    super.key,
    required this.initialTrack,
    this.initialQueue,
    this.startVideoMode = false,
  });

  @override
  State<NamiYoutubeWatchScreen> createState() => _NamiYoutubeWatchScreenState();
}

class _NamiYoutubeWatchScreenState extends State<NamiYoutubeWatchScreen>
    with WidgetsBindingObserver {
  late NamiYtTrack _track;
  NamiYtWatchDetails? _details;
  bool _loadingDetails = true;
  bool _descExpanded = false;

  // Body mode below sticky 16:9 viewport: 0 = Watch Overview | 1 = Comments | 2 = Queue
  int _bodyMode = 0;

  // Video / Audio player overlay state
  bool _isVideoActive = false;
  bool _loadingVideoStream = false;
  bool _isFullscreen = false;
  bool _showOverlay = true;
  String _qualityLabel = 'Audio Only';
  Timer? _overlayHideTimer;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Duration _curPos = Duration.zero;
  Duration _curDur = Duration.zero;
  bool _isPlaying = false;
  double? _scrubDragMs;
  int _lastVideoSyncMs = 0;

  // Local engagement toggles
  bool _liked = false;
  bool _disliked = false;

  // Real YouTube Comments state
  List<NamiYtComment> _comments = const [];
  String? _commentsNextCont;
  String? _topSortToken;
  String? _newestSortToken;
  String _commentsCountText = '';
  bool _commentsSortNewest = false;
  bool _loadingComments = false;
  final Set<String> _expandedCommentIds = <String>{};
  final Map<String, List<NamiYtComment>> _loadedReplies = {};
  final Set<String> _loadingReplyIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _track = widget.initialTrack;
    _liked = NamiYoutubeStore.instance.isFavorite(_track.videoId);
    NamiYtVideoBridge.ensureBound();
    NamiYtVideoBridge.videoState.addListener(_onVideoBridgeStateChanged);
    NamiYoutubePlaybackBridge.activeYtTrack.addListener(_onExternalTrackChanged);
    _bindPlayerStreams();
    _loadWatchData(_track, autoStartPlay: true);
    _scheduleHideOverlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause hardware video decoder cleanly on background while libmpv keeps playing audio!
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isVideoActive) {
        NamiYtVideoBridge.syncState(positionMs: _curPos.inMilliseconds, playing: false);
      }
    } else if (state == AppLifecycleState.resumed && _isVideoActive) {
      NamiYtVideoBridge.syncState(positionMs: _curPos.inMilliseconds, playing: _isPlaying);
    }
  }

  void _bindPlayerStreams() {
    final shell = _NamiHomeShellState.activeInstance;
    final player = shell?._audioPlayer;
    if (player == null) return;
    _curPos = player.state.position;
    _curDur = player.state.duration;
    _isPlaying = player.state.playing;

    _posSub?.cancel();
    _posSub = player.stream.position.listen((p) {
      if (!mounted) return;
      final d = player.state.duration;
      setState(() {
        _curPos = p;
        if (d.inSeconds > 0) _curDur = d;
      });
      if (_isVideoActive) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastVideoSyncMs > 700) {
          _lastVideoSyncMs = now;
          NamiYtVideoBridge.syncState(
            positionMs: p.inMilliseconds,
            playing: _isPlaying,
          );
        }
      }
    });

    _playSub?.cancel();
    NamiYtVideoBridge.videoState.removeListener(_onVideoBridgeStateChanged);
    NamiYoutubePlaybackBridge.activeYtTrack.removeListener(_onExternalTrackChanged);
    _playSub = player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      if (_isVideoActive) {
        NamiYtVideoBridge.syncState(
          positionMs: _curPos.inMilliseconds,
          playing: playing,
        );
      }
    });
  }

  void _scheduleHideOverlay() {
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && _showOverlay) {
        setState(() => _showOverlay = false);
      }
    });
  }

  Future<void> _loadWatchData(
    NamiYtTrack target, {
    bool autoStartPlay = false,
    bool forceRefresh = false,
  }) async {
    final vid = target.videoId;
    setState(() {
      _track = target;
      _loadingDetails = true;
      _descExpanded = false;
      _liked = NamiYoutubeStore.instance.isFavorite(vid);
      _disliked = false;
      _comments = const [];
      _commentsNextCont = null;
      _topSortToken = null;
      _newestSortToken = null;
      _commentsCountText = '';
      _loadedReplies.clear();
      if (_bodyMode == 1) _bodyMode = 0;
    });

    if (autoStartPlay) {
      final activeId = NamiYoutubePlaybackBridge.activeYtTrack.value?.videoId;
      if (forceRefresh || activeId != vid) {
        NamiYtVideoBridge.stopVideo();
        setState(() {
          _isVideoActive = false;
          _qualityLabel = 'Audio Only';
        });
        unawaited(
          NamiYoutubePlaybackBridge.playTrack(
            target,
            upcoming: widget.initialQueue,
          ).then((ok) {
            if (ok && mounted && _track.videoId == vid && (widget.startVideoMode || NamiUxPrefs.ytDefaultMode != 'Audio Only')) {
              _activateDefaultVideoQuality();
            }
          }),
        );
      } else if (widget.startVideoMode && !_isVideoActive) {
        unawaited(_activateDefaultVideoQuality());
      }
    }

    // Fetch rich watch metadata + comments preview + RYD dislikes concurrently
    final details = await NamiYoutubeService.instance.fetchWatchDetails(
      vid,
      region: NamiUxPrefs.youtubeRegion,
      fetchDislikes: NamiUxPrefs.ytReturnDislike,
    );
    if (!mounted || _track.videoId != vid) return;
    setState(() {
      _details = details;
      _loadingDetails = false;
    });

    // Preload first batch of real YouTube comments in background so opening Comments is instant!
    unawaited(_loadComments(vid, reset: true));
  }

  Future<void> _loadComments(
    String videoId, {
    bool reset = false,
    String? customToken,
  }) async {
    if (_loadingComments) return;
    setState(() => _loadingComments = true);
    final page = await NamiYoutubeService.instance.fetchVideoComments(
      videoId,
      continuationToken: customToken ?? (reset ? null : _commentsNextCont),
      region: NamiUxPrefs.youtubeRegion,
    );
    if (!mounted || _track.videoId != videoId) return;
    setState(() {
      _loadingComments = false;
      if (reset || customToken != null) {
        _comments = page.comments;
      } else {
        _comments = [..._comments, ...page.comments];
      }
      _commentsNextCont = page.nextContinuation;
      if (page.topSortToken != null) _topSortToken = page.topSortToken;
      if (page.newestSortToken != null) _newestSortToken = page.newestSortToken;
      if (page.totalCountText.isNotEmpty) _commentsCountText = page.totalCountText;
    });
  }

  Future<void> _loadRepliesFor(NamiYtComment comment) async {
    final token = comment.repliesContinuation;
    if (token == null || token.isEmpty || _loadingReplyIds.contains(comment.id)) return;
    setState(() => _loadingReplyIds.add(comment.id));
    final page = await NamiYoutubeService.instance.fetchVideoComments(
      _track.videoId,
      continuationToken: token,
      region: NamiUxPrefs.youtubeRegion,
    );
    if (!mounted) return;
    setState(() {
      _loadingReplyIds.remove(comment.id);
      _loadedReplies[comment.id] = page.comments;
    });
  }

  Future<void> _activateDefaultVideoQuality() async {
    final formats = NamiYtVideoBridge.activeVideoFormats.value.isNotEmpty
        ? NamiYtVideoBridge.activeVideoFormats.value
        : NamiYoutubeService.instance.cachedVideoFormatsFor(_track.videoId);
    if (formats.isEmpty) {
      // Trigger a bundle resolve if video formats aren't populated yet
      final bundle = await NamiYoutubeService.instance.resolveMediaBundle(
        _track.videoId,
        quality: NamiUxPrefs.youtubeAudioQuality,
        region: NamiUxPrefs.youtubeRegion,
      );
      if (bundle != null && bundle.videoFormats.isNotEmpty) {
        _namiSafeSetNotifier<List<NamiYtVideoFormat>>(
          NamiYtVideoBridge.activeVideoFormats,
          bundle.videoFormats,
        );
      }
    }
    final list = NamiYtVideoBridge.activeVideoFormats.value;
    if (list.isEmpty) {
      NamiLiveToastController.showMessage(
        'Video stream unavailable for this track — playing Audio Only',
        icon: Icons.music_note_rounded,
      );
      return;
    }
    // Respect Data Saver & Default Mode cap; prefer hardware H.264 MP4 for instant Frame 1!
    final maxH = NamiUxPrefs.ytDataSaver == 'High'
        ? 240
        : (NamiUxPrefs.ytDataSaver == 'Medium' || NamiUxPrefs.ytDefaultMode == 'Video 480p'
            ? 480
            : 720);
    final mp4s = list.where((f) => f.mimeType.contains('mp4')).toList();
    final pool = mp4s.isNotEmpty ? mp4s : list;
    final pick = pool.firstWhere(
      (f) => f.height <= maxH && f.height >= 240,
      orElse: () => pool.last,
    );
    await _selectVideoFormat(pick);
  }

  Future<void> _selectAudioOnly() async {
    await NamiYtVideoBridge.stopVideo();
    if (!mounted) return;
    setState(() {
      _isVideoActive = false;
      _loadingVideoStream = false;
      _qualityLabel = 'Audio Only';
    });
    _namiSafeSetNotifier<String>(NamiYtVideoBridge.selectedQuality, 'Audio Only');
    NamiLiveToastController.showMessage(
      'Switched to Audio Only (libmpv)',
      icon: Icons.headphones_rounded,
    );
  }

  Future<void> _selectVideoFormat(NamiYtVideoFormat fmt) async {
    setState(() {
      _loadingVideoStream = true;
      _qualityLabel = fmt.qualityLabel;
    });
    _namiSafeSetNotifier<String>(NamiYtVideoBridge.selectedQuality, fmt.qualityLabel);

    // Route video stream through our bounded-chunk progressive local server so MediaPlayer plays cleanly!
    final proxyStream = NamiYtStreamResult(
      videoId: '${_track.videoId}_v${fmt.itag}',
      audioUrl: fmt.url,
      mimeType: fmt.mimeType,
      bitrate: fmt.bitrate,
      duration: _curDur,
      headers: {
        ...fmt.headers,
        if (fmt.contentLength > 0) 'X-Nami-Content-Length': '${fmt.contentLength}',
      },
      expiresAtMs: DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
      clientUsed: 'VIDEO_${fmt.qualityLabel}',
    );

    final localUrl = await NamiYtProgressiveProxy.instance.prepareAndRegister(
      proxyStream,
      isVideo: true,
    );
    if (!mounted) return;

    final targetUrl = (localUrl != null && localUrl.isNotEmpty) ? localUrl : fmt.url;
    final useHdrs = (localUrl != null && localUrl.isNotEmpty)
        ? const <String, String>{}
        : fmt.headers;
    setState(() {
      _isVideoActive = true;
      _loadingVideoStream = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NamiYtVideoBridge.loadVideo(
        url: targetUrl,
        headers: useHdrs,
        seekMs: _curPos.inMilliseconds,
        playing: _isPlaying,
        speed: NamiUxPrefs.ytPlaybackSpeed,
      );
    });
    NamiLiveToastController.showMessage(
      'Video • ${fmt.qualityLabel}',
      icon: Icons.ondemand_video_rounded,
    );
  }

  void _toggleFullscreen() {
    NamiUxPrefs.hapticLight();
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    }
  }

  void _openQualityMenu() {
    NamiUxPrefs.hapticLight();
    final formats = NamiYtVideoBridge.activeVideoFormats.value.isNotEmpty
        ? NamiYtVideoBridge.activeVideoFormats.value
        : NamiYoutubeService.instance.cachedVideoFormatsFor(_track.videoId);
    final dur = _curDur.inSeconds > 0 ? _curDur : _track.duration;
    final shell = _NamiHomeShellState.activeInstance;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: namiSmoothSheetStyle,
      builder: (sheetCtx) {
        final accent = Theme.of(sheetCtx).colorScheme.primary;
        return StatefulBuilder(
          builder: (ctx, setS) => Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.78),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
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
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'Video Quality & Player Settings',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        // 1. Data Saver Mode Row (Off | Medium | High)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.speed_rounded, color: Colors.white70, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Data Saver',
                                    style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final preset in const ['Off', 'Medium', 'High']) ...[
                                    if (preset != 'Off') const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          NamiUxPrefs.hapticLight();
                                          NamiUxPrefs.ytDataSaver = preset;
                                          NamiUxPrefs.save();
                                          setS(() {});
                                          if (mounted) setState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: NamiUxPrefs.ytDataSaver == preset
                                                ? accent.withValues(alpha: 0.22)
                                                : const Color(0xFF151520),
                                            borderRadius: BorderRadius.circular(11),
                                            border: Border.all(
                                              color: NamiUxPrefs.ytDataSaver == preset
                                                  ? accent
                                                  : Colors.white12,
                                            ),
                                          ),
                                          child: Text(
                                            preset,
                                            style: TextStyle(
                                              color: NamiUxPrefs.ytDataSaver == preset
                                                  ? accent
                                                  : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10),

                        // 2. Audio Only + All Video Qualities (`144p..2160p`)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.headphones_rounded,
                            color: !_isVideoActive ? accent : Colors.white60,
                          ),
                          title: Text(
                            'Audio Only',
                            style: TextStyle(
                              color: !_isVideoActive ? accent : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Audiophile libmpv stream • EQ, USB DAC & lowest data',
                            style: TextStyle(color: Colors.white54, fontSize: 11.2),
                          ),
                          trailing: !_isVideoActive
                              ? Icon(Icons.check_rounded, color: accent, size: 20)
                              : null,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            _selectAudioOnly();
                          },
                        ),
                        if (formats.isEmpty)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.refresh_rounded, color: Colors.white54),
                            title: const Text(
                              'Fetch Video Resolutions',
                              style: TextStyle(color: Colors.white70, fontSize: 13.2, fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text(
                              'Tap to refresh 144p–1080p video tracks',
                              style: TextStyle(color: Colors.white54, fontSize: 11.2),
                            ),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              _activateDefaultVideoQuality();
                            },
                          ),
                        for (final fmt in formats)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.ondemand_video_rounded,
                              color: (_isVideoActive && _qualityLabel == fmt.qualityLabel)
                                  ? accent
                                  : Colors.white54,
                            ),
                            title: Text(
                              '${fmt.qualityLabel} • ${fmt.sizeLabelFor(dur)}',
                              style: TextStyle(
                                color: (_isVideoActive && _qualityLabel == fmt.qualityLabel)
                                    ? accent
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.6,
                              ),
                            ),
                            subtitle: Text(
                              '${fmt.bitrateLabel} • ${fmt.mimeType.contains('mp4') ? 'H.264 MP4' : 'VP9'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11.2),
                            ),
                            trailing: (_isVideoActive && _qualityLabel == fmt.qualityLabel)
                                ? Icon(Icons.check_rounded, color: accent, size: 20)
                                : null,
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              _selectVideoFormat(fmt);
                            },
                          ),
                        const Divider(color: Colors.white10),

                        // 3. Playback Speed (0.5x .. 2.0x — synced to BOTH libmpv & ExoPlayer!)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shutter_speed_rounded, color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Playback Speed (${NamiUxPrefs.ytPlaybackSpeed}x)',
                                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final spd in const [0.75, 1.0, 1.25, 1.5, 2.0]) ...[
                                    if (spd != 0.75) const SizedBox(width: 6),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          NamiUxPrefs.hapticLight();
                                          NamiUxPrefs.ytPlaybackSpeed = spd;
                                          shell?._audioPlayer.setRate(spd);
                                          NamiYtVideoBridge.setSpeed(spd);
                                          setS(() {});
                                          if (mounted) setState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 7),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: (NamiUxPrefs.ytPlaybackSpeed - spd).abs() < 0.05
                                                ? accent.withValues(alpha: 0.22)
                                                : const Color(0xFF151520),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: (NamiUxPrefs.ytPlaybackSpeed - spd).abs() < 0.05
                                                  ? accent
                                                  : Colors.white12,
                                            ),
                                          ),
                                          child: Text(
                                            '${spd}x',
                                            style: TextStyle(
                                              color: (NamiUxPrefs.ytPlaybackSpeed - spd).abs() < 0.05
                                                  ? accent
                                                  : Colors.white70,
                                              fontSize: 11.4,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10),

                        // 4. Live Half-Screen YouTube Settings Toggles
                        SwitchListTile(
                          dense: true,
                          activeColor: accent,
                          secondary: const Icon(Icons.repeat_one_rounded, color: Colors.white70, size: 20),
                          title: const Text('Loop Current Video / Track', style: TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700)),
                          value: NamiUxPrefs.ytLoopEnabled,
                          onChanged: (v) {
                            NamiUxPrefs.ytLoopEnabled = v;
                            shell?._audioPlayer.setPlaylistMode(
                              v ? PlaylistMode.single : PlaylistMode.none,
                            );
                            setS(() {});
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          activeColor: accent,
                          secondary: const Icon(Icons.block_rounded, color: Colors.white70, size: 20),
                          title: const Text('SponsorBlock Auto-Skip', style: TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700)),
                          value: NamiUxPrefs.ytSponsorBlock,
                          onChanged: (v) {
                            NamiUxPrefs.ytSponsorBlock = v;
                            NamiUxPrefs.save();
                            setS(() {});
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          activeColor: accent,
                          secondary: const Icon(Icons.podcasts_rounded, color: Colors.white70, size: 20),
                          title: const Text('Auto-Play Next / Radio', style: TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700)),
                          value: NamiUxPrefs.ytAutoStartRadio,
                          onChanged: (v) {
                            NamiUxPrefs.ytAutoStartRadio = v;
                            NamiUxPrefs.save();
                            setS(() {});
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          activeColor: accent,
                          secondary: const Icon(Icons.thumb_down_outlined, color: Colors.white70, size: 20),
                          title: const Text('Return YouTube Dislike', style: TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700)),
                          value: NamiUxPrefs.ytReturnDislike,
                          onChanged: (v) {
                            NamiUxPrefs.ytReturnDislike = v;
                            NamiUxPrefs.save();
                            setS(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSaveToLibrarySheet(NamiYtTrack target) {
    NamiUxPrefs.hapticLight();
    final store = NamiYoutubeStore.instance;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: namiSmoothSheetStyle,
      builder: (sheetCtx) {
        final accent = Theme.of(sheetCtx).colorScheme.primary;
        return StatefulBuilder(
          builder: (ctx, setS) {
            final isFav = store.isFavorite(target.videoId);
            final playlists = store.playlists;
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B11),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
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
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add to Library / Playlist',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final ctrl = TextEditingController();
                            final name = await showDialog<String>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: const Color(0xFF12121A),
                                title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
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
                              final pl = await store.createPlaylist(name);
                              await store.addTrackToPlaylist(pl.id, target);
                              setS(() {});
                              NamiLiveToastController.showMessage(
                                'Saved to "$name"',
                                icon: Icons.playlist_add_check_rounded,
                              );
                            }
                          },
                          icon: Icon(Icons.add_rounded, color: accent, size: 18),
                          label: Text('New', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    ListTile(
                      leading: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? accent : Colors.white60,
                      ),
                      title: const Text(
                        'Liked / Favorites Library',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      trailing: isFav ? Icon(Icons.check_rounded, color: accent) : null,
                      onTap: () async {
                        final next = await store.toggleFavorite(target);
                        if (target.videoId == _track.videoId && mounted) {
                          setState(() => _liked = next);
                        }
                        setS(() {});
                        NamiLiveToastController.showMessage(
                          next ? 'Added to Library Favorites' : 'Removed from Favorites',
                          icon: next ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        );
                      },
                    ),
                    if (playlists.isNotEmpty) const Divider(color: Colors.white10),
                    for (final pl in playlists)
                      ListTile(
                        leading: const Icon(Icons.playlist_play_rounded, color: Colors.white60),
                        title: Text(
                          pl.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.8),
                        ),
                        subtitle: Text(
                          '${pl.videoIds.length} track(s)',
                          style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                        ),
                        trailing: pl.videoIds.contains(target.videoId)
                            ? Icon(Icons.check_rounded, color: accent)
                            : const Icon(Icons.add_rounded, color: Colors.white38),
                        onTap: () async {
                          await store.addTrackToPlaylist(pl.id, target);
                          setS(() {});
                          NamiLiveToastController.showMessage(
                            'Added to "${pl.name}"',
                            icon: Icons.playlist_add_check_rounded,
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openTrackMenu(NamiYtTrack t) {
    NamiUxPrefs.hapticLight();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: namiSmoothSheetStyle,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C12),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded, color: Colors.white70),
                title: const Text('Play Next / Add to Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  NamiYoutubePlaybackBridge.queueYoutubeTrackAfter(t);
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_add_outlined, color: Colors.white70),
                title: const Text('Add to Library / Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openSaveToLibrarySheet(t);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.white70),
                title: const Text('Download Offline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  NamiYtDownloadManager.instance.enqueueDownload(t);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white70),
                title: const Text('Share YouTube Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: 'https://youtu.be/${t.videoId}'));
                  NamiLiveToastController.showMessage('Copied YouTube link', icon: Icons.share_rounded);
                },
              ),
              if (t.channelId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded, color: Colors.white70),
                  title: Text('Open Channel • ${t.artist}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openNamiYoutubeChannelScreen(
                      context,
                      channelId: t.channelId,
                      channelName: t.artist,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _fmtDur(Duration d) {
    final s = d.inSeconds.clamp(0, 86400);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }


  void _onExternalTrackChanged() {
    final ext = NamiYoutubePlaybackBridge.activeYtTrack.value;
    if (!mounted || ext == null || ext.videoId == _track.videoId) return;
    _loadWatchData(ext, autoStartPlay: false);
  }

  void _onVideoBridgeStateChanged() {
    if (!mounted || !_isVideoActive) return;
    if (NamiYtVideoBridge.videoState.value == 'error') {
      final list = NamiYtVideoBridge.activeVideoFormats.value;
      final fallback = list.cast<NamiYtVideoFormat?>().firstWhere(
            (f) => f != null && f.mimeType.contains('mp4') && f.height <= 480 && f.qualityLabel != _qualityLabel,
            orElse: () => null,
          );
      if (fallback != null) {
        _selectVideoFormat(fallback);
      } else {
        NamiLiveToastController.showMessage(
          'Video decoder error (${NamiYtVideoBridge.lastVideoError.value}) — using Audio Only',
          icon: Icons.headphones_rounded,
        );
        _selectAudioOnly();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayHideTimer?.cancel();
    _posSub?.cancel();
    _playSub?.cancel();
    NamiYtVideoBridge.stopVideo();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    }
    super.dispose();
  }

  Widget _buildViewport(Color accent) {
    final shell = _NamiHomeShellState.activeInstance;
    final player = shell?._audioPlayer;
    final totalMs = (_curDur.inMilliseconds > 0
            ? _curDur.inMilliseconds
            : _track.duration.inMilliseconds)
        .clamp(1, 36000000);
    final posMs = (_scrubDragMs ?? _curPos.inMilliseconds.toDouble())
        .clamp(0.0, totalMs.toDouble());

    final viewport = GestureDetector(
      onTap: () {
        setState(() => _showOverlay = !_showOverlay);
        if (_showOverlay) _scheduleHideOverlay();
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Thumbnail (always visible underneath for 0ms transitions)
            Image.network(
              _track.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF101018),
                child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 54),
              ),
            ),

            // 2. Native Hardware-Accelerated Android TextureView Video Layer
            if (_isVideoActive)
              const AndroidView(
                viewType: 'com.piyush.nami/yt_video_view',
                creationParamsCodec: StandardMessageCodec(),
              ),

            // 3. Live ExoPlayer buffering indicator (auto-hides on Frame 1 ready!)
            ValueListenableBuilder<String>(
              valueListenable: NamiYtVideoBridge.videoState,
              builder: (_, vst, __) {
                if (!_loadingVideoStream && !(_isVideoActive && vst == 'buffering')) {
                  return const SizedBox.shrink();
                }
                return const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                  ),
                );
              },
            ),

            // 4. Interactive YouTube Overlay Controls
            IgnorePointer(
              ignoring: !_showOverlay,
              child: AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.72),
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Bar: Minimize, Audio/Video Pill Toggle, Quality Gear, Fullscreen
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed: () {
                                if (_isFullscreen) {
                                  _toggleFullscreen();
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                              },
                            ),
                            const Spacer(),
                            // Quick 1-Tap Audio <-> Video Switch Pill
                            GestureDetector(
                              onTap: () {
                                NamiUxPrefs.hapticLight();
                                if (_isVideoActive) {
                                  _selectAudioOnly();
                                } else {
                                  _activateDefaultVideoQuality();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _isVideoActive
                                      ? accent.withValues(alpha: 0.28)
                                      : Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _isVideoActive ? accent : Colors.white30,
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isVideoActive
                                          ? Icons.ondemand_video_rounded
                                          : Icons.headphones_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _qualityLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.2,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quality Settings',
                              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                              onPressed: _openQualityMenu,
                            ),
                            IconButton(
                              tooltip: 'Fullscreen',
                              icon: Icon(
                                _isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: _toggleFullscreen,
                            ),
                          ],
                        ),
                      ),

                      // Center Transport Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 32),
                            onPressed: () {
                              NamiUxPrefs.hapticLight();
                              NamiYoutubePlaybackBridge.playPrevInRadioQueue().then((ok) {
                                final cur = NamiYoutubePlaybackBridge.activeYtTrack.value;
                                if (ok && cur != null && mounted) {
                                  _loadWatchData(cur, autoStartPlay: false);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 18),
                          ValueListenableBuilder<bool>(
                            valueListenable: NamiYoutubePlaybackBridge.isResolving,
                            builder: (_, resolving, __) => GestureDetector(
                              onTap: () {
                                NamiUxPrefs.hapticLight();
                                player?.playOrPause();
                                _scheduleHideOverlay();
                              },
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: resolving
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
                            onPressed: () {
                              NamiUxPrefs.hapticLight();
                              NamiYoutubePlaybackBridge.playNextInRadioQueue().then((ok) {
                                final cur = NamiYoutubePlaybackBridge.activeYtTrack.value;
                                if (ok && cur != null && mounted) {
                                  _loadWatchData(cur, autoStartPlay: false);
                                }
                              });
                            },
                          ),
                        ],
                      ),

                      // Bottom Time & Interactive Scrub Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_fmtDur(Duration(milliseconds: posMs.round()))} / ${_fmtDur(Duration(milliseconds: totalMs))}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.6,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: accent,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: posMs,
                                min: 0.0,
                                max: totalMs.toDouble(),
                                onChangeStart: (_) => _overlayHideTimer?.cancel(),
                                onChanged: (v) => setState(() => _scrubDragMs = v),
                                onChangeEnd: (v) {
                                  final target = Duration(milliseconds: v.round());
                                  player?.seek(target);
                                  if (_isVideoActive) {
                                    NamiYtVideoBridge.syncState(
                                      positionMs: target.inMilliseconds,
                                      playing: _isPlaying,
                                    );
                                  }
                                  setState(() => _scrubDragMs = null);
                                  _scheduleHideOverlay();
                                },
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
          ],
        ),
      ),
    );

    if (_isFullscreen) {
      return Expanded(child: viewport);
    }
    return AspectRatio(aspectRatio: 16 / 9, child: viewport);
  }

  Widget _buildWatchOverview(Color accent) {
    final d = _details;
    final store = NamiYoutubeStore.instance;
    final title = (d != null && d.title.isNotEmpty) ? d.title : _track.title;
    final channelName = (d != null && d.channelName.isNotEmpty) ? d.channelName : _track.artist;
    final channelId = (d != null && d.channelId.isNotEmpty) ? d.channelId : _track.channelId;
    final channelAvatar = (d != null && d.channelAvatarUrl.isNotEmpty) ? d.channelAvatarUrl : '';
    final subText = d?.subscriberText ?? '';
    final viewsText = (d != null && d.viewsText.isNotEmpty) ? d.viewsText : _track.viewsText;
    final pubText = d?.publishedText ?? '';
    final exactDate = NamiYoutubeService.instance.cachedExactDateFor(_track.videoId);
    final desc = NamiYoutubeService.instance.cachedDescriptionFor(_track.videoId);
    final likesCount = (d?.likesCount ?? 0) + (_liked ? 1 : 0);
    final dislikesCount = (d?.dislikesCount ?? 0) + (_disliked ? 1 : 0);
    final subscribed = channelId.isNotEmpty && store.isChannelSubscribed(channelId);
    final related = d?.relatedTracks ?? NamiYoutubePlaybackBridge.radioQueue.value;

    // Preview comment (prefer freshly loaded first comment, fallback to teaser)
    final previewComment = _comments.isNotEmpty ? _comments.first : null;
    final topAuthor = previewComment?.author ?? (d?.topCommentAuthor ?? '');
    final topText = previewComment?.text ?? (d?.topCommentText ?? '');
    final topAvatar = previewComment?.authorAvatarUrl ?? '';
    final topLikes = previewComment?.likesText ?? (d?.topCommentLikes ?? '');
    final topReplies = previewComment?.replyCountText ?? '';

    Widget actionBtn({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool active = false,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            NamiUxPrefs.hapticLight();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: active ? accent : Colors.white, size: 22),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? accent : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // 1. Title + Stats + Expandable Description
        GestureDetector(
          onTap: () => setState(() => _descExpanded = !_descExpanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: _descExpanded ? 5 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _descExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white60,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (viewsText.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined, color: Colors.white54, size: 13.5),
                        const SizedBox(width: 4),
                        Text(viewsText, style: const TextStyle(color: Colors.white60, fontSize: 11.6)),
                      ],
                    ),
                  if (exactDate.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Colors.white54, size: 12.5),
                        const SizedBox(width: 4),
                        Text(exactDate, style: const TextStyle(color: Colors.white60, fontSize: 11.6)),
                      ],
                    ),
                  if (pubText.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, color: Colors.white54, size: 13.5),
                        const SizedBox(width: 4),
                        Text(pubText, style: const TextStyle(color: Colors.white60, fontSize: 11.6)),
                      ],
                    ),
                ],
              ),
              if (_descExpanded && desc.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0E15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    desc,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. 6-Button Action Bar (Like, Dislike, Share, Refresh, Download, Save/Library)
        ValueListenableBuilder<List<NamiYtDownloadTask>>(
          valueListenable: NamiYtDownloadManager.instance.tasks,
          builder: (_, dlTasks, __) {
            final dl = dlTasks.cast<NamiYtDownloadTask?>().firstWhere(
                  (t) => t?.track.videoId == _track.videoId,
                  orElse: () => null,
                );
            final dlLabel = dl == null
                ? 'Download'
                : (dl.status == NamiYtDlStatus.completed
                    ? 'Saved'
                    : (dl.status == NamiYtDlStatus.downloading
                        ? '${(dl.progress * 100).round()}%'
                        : 'Download'));
            return Row(
              children: [
                actionBtn(
                  icon: _liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  label: likesCount > 0 ? _fmtCount(likesCount) : 'Like',
                  active: _liked,
                  onTap: () async {
                    final next = await store.toggleFavorite(_track);
                    if (mounted) {
                      setState(() {
                        _liked = next;
                        if (next) _disliked = false;
                      });
                    }
                  },
                ),
                actionBtn(
                  icon: _disliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                  label: dislikesCount > 0 ? _fmtCount(dislikesCount) : 'Dislike',
                  active: _disliked,
                  onTap: () => setState(() {
                    _disliked = !_disliked;
                    if (_disliked) _liked = false;
                  }),
                ),
                actionBtn(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: 'https://youtu.be/${_track.videoId}'));
                    NamiLiveToastController.showMessage(
                      'Copied YouTube link',
                      icon: Icons.share_rounded,
                    );
                  },
                ),
                actionBtn(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  onTap: () => _loadWatchData(_track, autoStartPlay: true, forceRefresh: true),
                ),
                actionBtn(
                  icon: dl?.status == NamiYtDlStatus.completed
                      ? Icons.download_done_rounded
                      : Icons.download_outlined,
                  label: dlLabel,
                  active: dl?.status == NamiYtDlStatus.completed,
                  onTap: () => NamiYtDownloadManager.instance.enqueueDownload(_track),
                ),
                actionBtn(
                  icon: Icons.library_add_outlined,
                  label: 'Save',
                  onTap: () => _openSaveToLibrarySheet(_track),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),

        // 3. Channel Row (Tappable -> Full YouTube Channel Detail Screen!)
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (channelId.isNotEmpty) {
              NamiUxPrefs.hapticLight();
              openNamiYoutubeChannelScreen(
                context,
                channelId: channelId,
                channelName: channelName,
                channelAvatarUrl: channelAvatar,
                subscriberText: subText,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: const Color(0xFF1A1A24),
                  backgroundImage:
                      channelAvatar.isNotEmpty ? NetworkImage(channelAvatar) : null,
                  child: channelAvatar.isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.white54, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subText.isNotEmpty)
                        Text(
                          subText,
                          style: const TextStyle(color: Colors.white54, fontSize: 11.8),
                        ),
                    ],
                  ),
                ),
                NamiSpringTap(
                  pressedScale: 0.94,
                  onTap: () async {
                    if (channelId.isEmpty) return;
                    await store.toggleChannelSubscription(
                      NamiYtChannel(
                        channelId: channelId,
                        name: channelName,
                        avatarUrl: channelAvatar,
                        subscriberText: subText,
                        subscribedAtMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: subscribed ? const Color(0xFF181822) : const Color(0xFF14141C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: subscribed ? accent.withValues(alpha: 0.65) : Colors.white24,
                      ),
                    ),
                    child: Text(
                      subscribed ? 'Subscribed' : 'Subscribe',
                      style: TextStyle(
                        color: subscribed ? accent : Colors.white,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 4. Comments Preview Card (Tappable -> Full In-Page Comments Panel!)
        GestureDetector(
          onTap: () {
            NamiUxPrefs.hapticLight();
            setState(() => _bodyMode = 1);
            if (_comments.isEmpty && !_loadingComments) {
              _loadComments(_track.videoId, reset: true);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.comment_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _commentsCountText.isNotEmpty
                          ? 'Comments  $_commentsCountText'
                          : 'Comments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _loadComments(_track.videoId, reset: true),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 17),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (topText.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: const Color(0xFF1D1D28),
                        backgroundImage:
                            topAvatar.isNotEmpty ? NetworkImage(topAvatar) : null,
                        child: topAvatar.isEmpty
                            ? const Icon(Icons.person_rounded, color: Colors.white54, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (topAuthor.isNotEmpty)
                              Text(
                                topAuthor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              topText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.2,
                                height: 1.32,
                              ),
                            ),
                            if (topLikes.isNotEmpty || topReplies.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  if (topLikes.isNotEmpty) ...[
                                    const Icon(Icons.thumb_up_outlined, color: Colors.white54, size: 12),
                                    const SizedBox(width: 4),
                                    Text(topLikes, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    const SizedBox(width: 12),
                                  ],
                                  if (topReplies.isNotEmpty)
                                    Text(
                                      'Replies • $topReplies',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _loadingComments
                        ? 'Loading comments...'
                        : 'Tap to view comments & replies',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 5. Related / Up Next Videos List
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Text(
                'Up Next & Suggestions',
                style: TextStyle(color: Colors.white, fontSize: 14.2, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (related.isNotEmpty)
                Text(
                  '${related.length} videos',
                  style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                ),
            ],
          ),
        ),
        if (_loadingDetails && related.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          for (final r in related)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                NamiUxPrefs.hapticLight();
                _loadWatchData(r, autoStartPlay: true);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 138,
                            height: 78,
                            child: Image.network(
                              r.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF161622),
                                child: const Icon(Icons.music_note_rounded, color: Colors.white38),
                              ),
                            ),
                          ),
                        ),
                        if (r.duration.inSeconds > 0)
                          Positioned(
                            right: 5,
                            bottom: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                r.durationLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (r.viewsText.isNotEmpty)
                            Text(
                              r.viewsText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 11.2),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            r.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 36),
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 19),
                      onPressed: () => _openTrackMenu(r),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildCommentsPanel(Color accent) {
    return Column(
      children: [
        // Comments Header: Back | Comments | Top / Newest | Refresh
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 26),
                onPressed: () => setState(() => _bodyMode = 0),
              ),
              const Text(
                'Comments',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              for (final isNew in const [false, true])
                GestureDetector(
                  onTap: () {
                    if (_commentsSortNewest == isNew) return;
                    NamiUxPrefs.hapticLight();
                    setState(() => _commentsSortNewest = isNew);
                    final tok = isNew ? _newestSortToken : _topSortToken;
                    _loadComments(_track.videoId, reset: true, customToken: tok);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _commentsSortNewest == isNew
                          ? accent.withValues(alpha: 0.20)
                          : const Color(0xFF14141C),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _commentsSortNewest == isNew ? accent : Colors.white12,
                      ),
                    ),
                    child: Text(
                      isNew ? 'Newest' : 'Top',
                      style: TextStyle(
                        color: _commentsSortNewest == isNew ? accent : Colors.white70,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 20),
                onPressed: () => _loadComments(_track.videoId, reset: true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingComments && _comments.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments found for this video',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                      itemCount: _comments.length + (_commentsNextCont != null ? 1 : 0),
                      itemBuilder: (_, idx) {
                        if (idx >= _comments.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: OutlinedButton(
                                onPressed: _loadingComments
                                    ? null
                                    : () => _loadComments(_track.videoId, reset: false),
                                child: Text(
                                  _loadingComments ? 'Loading...' : 'Load More Comments',
                                  style: TextStyle(color: accent),
                                ),
                              ),
                            ),
                          );
                        }
                        final c = _comments[idx];
                        final expanded = _expandedCommentIds.contains(c.id);
                        final replies = _loadedReplies[c.id];
                        final loadingRep = _loadingReplyIds.contains(c.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF1A1A24),
                                backgroundImage: c.authorAvatarUrl.isNotEmpty
                                    ? NetworkImage(c.authorAvatarUrl)
                                    : null,
                                child: c.authorAvatarUrl.isEmpty
                                    ? Text(
                                        c.author.isNotEmpty ? c.author[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      [
                                        c.author,
                                        if (c.publishedText.isNotEmpty) c.publishedText,
                                      ].join(' • '),
                                      style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        if (expanded) {
                                          _expandedCommentIds.remove(c.id);
                                        } else {
                                          _expandedCommentIds.add(c.id);
                                        }
                                      }),
                                      child: Text(
                                        c.text,
                                        maxLines: expanded ? 40 : 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.thumb_up_outlined, color: Colors.white54, size: 13.5),
                                        const SizedBox(width: 4),
                                        Text(
                                          c.likesText.isNotEmpty ? c.likesText : '0',
                                          style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                                        ),
                                        if (c.repliesContinuation != null &&
                                            c.repliesContinuation!.isNotEmpty) ...[
                                          const SizedBox(width: 16),
                                          GestureDetector(
                                            onTap: () => _loadRepliesFor(c),
                                            child: Text(
                                              loadingRep
                                                  ? 'Loading replies...'
                                                  : (c.replyCountText.isNotEmpty
                                                      ? 'Replies • ${c.replyCountText}'
                                                      : 'View Replies'),
                                              style: TextStyle(
                                                color: accent,
                                                fontSize: 11.8,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (replies != null && replies.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.only(left: 10),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            left: BorderSide(color: Colors.white12, width: 1.5),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            for (final rep in replies.take(8))
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 10),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${rep.author} • ${rep.publishedText}',
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 10.8,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      rep.text,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12.2,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildQueuePanel(Color accent) {
    return ValueListenableBuilder<List<NamiYtTrack>>(
      valueListenable: NamiYoutubePlaybackBridge.radioQueue,
      builder: (_, queue, __) {
        final fullList = <NamiYtTrack>[_track, ...queue.where((q) => q.videoId != _track.videoId)];
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Queue',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '1/${fullList.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11.6),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Shuffle Queue',
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 20),
                    onPressed: () {
                      final copy = List<NamiYtTrack>.from(queue)..shuffle();
                      _namiSafeSetNotifier<List<NamiYtTrack>>(
                        NamiYoutubePlaybackBridge.radioQueue,
                        copy,
                      );
                      NamiLiveToastController.showMessage('Shuffled queue', icon: Icons.shuffle_rounded);
                    },
                  ),
                  IconButton(
                    tooltip: 'Clear Upcoming Queue',
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70, size: 21),
                    onPressed: () {
                      _namiSafeSetNotifier<List<NamiYtTrack>>(
                        NamiYoutubePlaybackBridge.radioQueue,
                        const [],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
                    onPressed: () => setState(() => _bodyMode = 0),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: fullList.length,
                itemBuilder: (_, i) {
                  final item = fullList[i];
                  final isCurrent = item.videoId == _track.videoId;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? accent.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 68,
                          height: 44,
                          child: Image.network(
                            item.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A24)),
                          ),
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? accent : Colors.white,
                          fontSize: 13.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        item.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.graphic_eq_rounded, color: accent, size: 20)
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                              onPressed: () {
                                final next = queue.where((q) => q.videoId != item.videoId).toList();
                                _namiSafeSetNotifier<List<NamiYtTrack>>(
                                  NamiYoutubePlaybackBridge.radioQueue,
                                  next,
                                );
                              },
                            ),
                      onTap: () {
                        if (!isCurrent) {
                          _loadWatchData(item, autoStartPlay: true);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomQueueBar(Color accent) {
    return ValueListenableBuilder<List<NamiYtTrack>>(
      valueListenable: NamiYoutubePlaybackBridge.radioQueue,
      builder: (_, queue, __) {
        final nextTrack = queue.isNotEmpty ? queue.first : null;
        final total = queue.length + 1;
        return GestureDetector(
          onTap: () {
            NamiUxPrefs.hapticLight();
            setState(() => _bodyMode = _bodyMode == 2 ? 0 : 2);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0A10),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Image.network(
                        (nextTrack ?? _track).thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A24)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1/$total',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          nextTrack != null
                              ? 'Next: ${nextTrack.title}'
                              : 'Queue • ${_track.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_play_rounded, color: Colors.white70, size: 22),
                    onPressed: () => setState(() => _bodyMode = _bodyMode == 2 ? 0 : 2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white70, size: 21),
                    onPressed: () => _openSaveToLibrarySheet(_track),
                  ),
                  Icon(
                    _bodyMode == 2
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        bottom: false,
        top: !_isFullscreen,
        child: Column(
          children: [
            _buildViewport(accent),
            if (!_isFullscreen) ...[
              Expanded(
                child: _bodyMode == 1
                    ? _buildCommentsPanel(accent)
                    : (_bodyMode == 2
                        ? _buildQueuePanel(accent)
                        : _buildWatchOverview(accent)),
              ),
              _buildBottomQueueBar(accent),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FULL YOUTUBE CHANNEL DETAIL SCREEN (Banner, Avatar, Subs, Home/Videos/Shorts/Releases/Playlists)
// =============================================================================
class NamiYoutubeChannelScreen extends StatefulWidget {
  final String channelId;
  final String initialName;
  final String initialAvatarUrl;
  final String initialSubs;

  const NamiYoutubeChannelScreen({
    super.key,
    required this.channelId,
    this.initialName = '',
    this.initialAvatarUrl = '',
    this.initialSubs = '',
  });

  @override
  State<NamiYoutubeChannelScreen> createState() => _NamiYoutubeChannelScreenState();
}

class _NamiYoutubeChannelScreenState extends State<NamiYoutubeChannelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  NamiYtChannelDetails? _details;
  bool _loading = true;
  final Map<int, List<NamiYtTrack>> _tabVideos = {};
  final Set<int> _loadingTabs = <int>{};
  bool _sortPopular = false;

  static const List<String> _tabs = ['Home', 'Videos', 'Shorts', 'Releases', 'Playlists'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) {
          _ensureTabLoaded(_tabCtrl.index);
        }
      });
    _loadChannel();
  }

  Future<void> _loadChannel() async {
    setState(() => _loading = true);
    final res = await NamiYoutubeService.instance.fetchChannelDetails(
      widget.channelId,
      fallbackName: widget.initialName,
      fallbackAvatar: widget.initialAvatarUrl,
      region: NamiUxPrefs.youtubeRegion,
    );
    if (!mounted) return;
    setState(() {
      _details = res;
      _loading = false;
      if (res.videos.isNotEmpty) _tabVideos[1] = res.videos;
    });
    _ensureTabLoaded(1);
  }

  Future<void> _ensureTabLoaded(int idx) async {
    if (idx == 0 || _details == null || _loadingTabs.contains(idx)) return;
    if ((_tabVideos[idx]?.length ?? 0) >= 15) return;
    final params = switch (idx) {
      1 => _details!.videosTabParams,
      2 => _details!.shortsTabParams,
      3 => _details!.releasesTabParams,
      4 => _details!.playlistsTabParams,
      _ => null,
    };
    setState(() => _loadingTabs.add(idx));
    final list = await NamiYoutubeService.instance.fetchChannelTabVideos(
      widget.channelId,
      params,
      channelName: _details!.name,
      region: NamiUxPrefs.youtubeRegion,
    );
    if (!mounted) return;
    setState(() {
      _loadingTabs.remove(idx);
      if (list.isNotEmpty) _tabVideos[idx] = list;
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Widget _buildVideoRow(NamiYtTrack t) {
    return InkWell(
      onTap: () => openNamiYoutubeWatchScreen(context, t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 136,
                    height: 76,
                    child: Image.network(
                      t.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161622)),
                    ),
                  ),
                ),
                if (t.duration.inSeconds > 0)
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        t.durationLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 10.2, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.4,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (t.viewsText.isNotEmpty)
                    Text(
                      t.viewsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.playlist_play_rounded, color: Colors.white54, size: 20),
              tooltip: 'Play Next',
              onPressed: () => NamiYoutubePlaybackBridge.queueYoutubeTrackAfter(t),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final store = NamiYoutubeStore.instance;
    final d = _details;
    final name = (d != null && d.name.isNotEmpty) ? d.name : widget.initialName;
    final avatar = (d != null && d.avatarUrl.isNotEmpty) ? d.avatarUrl : widget.initialAvatarUrl;
    final banner = d?.bannerUrl ?? '';
    final subs = (d != null && d.subscriberText.isNotEmpty) ? d.subscriberText : widget.initialSubs;
    final subscribed = store.isChannelSubscribed(widget.channelId);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          name.isNotEmpty ? name : 'Channel',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 21),
            onPressed: _loadChannel,
          ),
        ],
      ),
      body: Column(
        children: [
          // Channel Banner + Avatar + Name + Subs + Subscribe
          if (banner.isNotEmpty)
            SizedBox(
              height: 86,
              width: double.infinity,
              child: Image.network(
                banner,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF181822),
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.white54, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'YouTube Channel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (d != null && d.handle.isNotEmpty) d.handle,
                          if (subs.isNotEmpty) subs,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                NamiSpringTap(
                  pressedScale: 0.94,
                  onTap: () async {
                    await store.toggleChannelSubscription(
                      NamiYtChannel(
                        channelId: widget.channelId,
                        name: name,
                        avatarUrl: avatar,
                        subscriberText: subs,
                        subscribedAtMs: DateTime.now().millisecondsSinceEpoch,
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: subscribed ? accent.withValues(alpha: 0.20) : const Color(0xFF15151E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: subscribed ? accent : Colors.white24),
                    ),
                    child: Text(
                      subscribed ? 'Subscribed' : 'Subscribe',
                      style: TextStyle(
                        color: subscribed ? accent : Colors.white,
                        fontSize: 12.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Channel Navigation Tabs (`Home | Videos | Shorts | Releases | Playlists`)
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 2.4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            tabs: [for (final t in _tabs) Tab(text: t)],
          ),
          const Divider(height: 1, color: Colors.white10),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // Tab 0: Home (Shelves + Featured)
                      ListView(
                        padding: const EdgeInsets.only(top: 10, bottom: 90),
                        children: [
                          if (d != null && d.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                d.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ),
                          for (final shelf in (d?.homeShelves ?? const <NamiYtChannelShelf>[])) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: Text(
                                shelf.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 162,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                itemCount: shelf.items.length,
                                itemBuilder: (_, i) {
                                  final item = shelf.items[i];
                                  return GestureDetector(
                                    onTap: () => openNamiYoutubeWatchScreen(
                                      context,
                                      item,
                                      queue: shelf.items,
                                    ),
                                    child: Container(
                                      width: 176,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(11),
                                            child: SizedBox(
                                              width: 176,
                                              height: 99,
                                              child: Image.network(
                                                item.thumbnailUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(color: const Color(0xFF161622)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.2,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if ((d?.homeShelves ?? const []).isEmpty)
                            for (final v in (d?.videos ?? const <NamiYtTrack>[])) _buildVideoRow(v),
                        ],
                      ),

                      // Tabs 1..4: Videos, Shorts, Releases, Playlists
                      for (int ti = 1; ti < _tabs.length; ti++)
                        Builder(
                          builder: (_) {
                            final items = _tabVideos[ti] ?? const <NamiYtTrack>[];
                            final busy = _loadingTabs.contains(ti);
                            if (busy && items.isEmpty) {
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            if (items.isEmpty) {
                              return Center(
                                child: Text(
                                  'No ${_tabs[ti].toLowerCase()} available',
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              );
                            }
                            final displayList = _sortPopular
                                ? List<NamiYtTrack>.from(items.reversed)
                                : items;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() => _sortPopular = !_sortPopular),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF14141C),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.sort_rounded, color: Colors.white70, size: 15),
                                              const SizedBox(width: 5),
                                              Text(
                                                _sortPopular ? 'Oldest' : 'Latest',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF101016),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: Text(
                                          '${displayList.length} items',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 11.6,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 90),
                                    itemCount: displayList.length,
                                    itemBuilder: (_, i) => _buildVideoRow(displayList[i]),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
