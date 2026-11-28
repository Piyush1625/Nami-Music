part of '../main.dart';

class NowPlayingModal extends StatefulWidget {
  final Player audioPlayer;
  final ValueNotifier<AudioTrack?> currentSongNotifier;
  final List<AudioTrack> allSongs;
  final List<AudioTrack> playNextQueue;
  final bool ambientGlow;
  final bool blurredBackdrop;
  final int doubleTapSeekSec;
  final bool syllableLyricsEnabled;
  final ValueChanged<String>? onGoToArtist;
  final bool shuffleEnabled;
  final int repeatMode;
  final VoidCallback onToggleShuffle,
      onCycleRepeat,
      onShowPath,
      onShowEqualizer,
      onShowSleepTimer,
      onOpenLyricsManager,
      onToggleFavorite,
      onRefreshLyrics,
      onNext,
      onPrevious,
      onOpenQueue,
      onOpenMoreMenu;

  const NowPlayingModal({
    super.key,
    required this.audioPlayer,
    required this.currentSongNotifier,
    required this.allSongs,
    required this.playNextQueue,
    required this.ambientGlow,
    required this.blurredBackdrop,
    required this.doubleTapSeekSec,
    required this.syllableLyricsEnabled,
    this.onGoToArtist,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onShowPath,
    required this.onShowEqualizer,
    required this.onShowSleepTimer,
    required this.onOpenLyricsManager,
    required this.onToggleFavorite,
    required this.onRefreshLyrics,
    required this.onNext,
    required this.onPrevious,
    required this.onOpenQueue,
    required this.onOpenMoreMenu,
  });

  @override
  State<NowPlayingModal> createState() => _NowPlayingModalState();
}

class _NowPlayingModalState extends State<NowPlayingModal> {
  int _viewMode = 0;
  final Map<String, List<double>> _realWaveformCache = {};
  String _loadingWaveformPath = '';
  late bool _shuffleLocal;
  late int _repeatLocal;
  double _lyricsShiftSec = 0.0;
  String? _seekFlashLabel;
  Timer? _seekFlashTimer;
  final ScrollController _lyricsScrollCtrl = ScrollController();
  int _lastScrolledLyricIndex = -1;

  @override
  void initState() {
    super.initState();
    _shuffleLocal = widget.shuffleEnabled;
    _repeatLocal = widget.repeatMode;
  }


  void _jumpToCurrentSyncedLyric() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewMode != 1 || !_lyricsScrollCtrl.hasClients) return;
      final lyrics = widget.lyrics;
      if (lyrics.isEmpty) return;
      final posMs = widget.audioPlayer.state.position.inMilliseconds + (_lyricsShiftSec * 1000).round();
      int activeIdx = 0;
      for (int i = 0; i < lyrics.length; i++) {
        final tMs = lyrics[i].timestamp.inMilliseconds;
        if (posMs >= tMs) {
          activeIdx = i;
        } else {
          break;
        }
      }
      _lastScrolledLyricIndex = activeIdx;
      final maxExtent = _lyricsScrollCtrl.position.maxScrollExtent;
      final targetOffset = ((activeIdx * 62.0) - 90.0).clamp(0.0, maxExtent);
      _lyricsScrollCtrl.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _triggerSeekFeedback(int deltaSec) {
    HapticFeedback.lightImpact();
    _seekRelative(deltaSec);
    _seekFlashTimer?.cancel();
    setState(() {
      _seekFlashLabel = deltaSec < 0 ? '${deltaSec}s' : '+${deltaSec}s';
    });
    _seekFlashTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _seekFlashLabel = null);
    });
  }

  static const double _lyricLineExtent = 36.0;

  Future<void> _ensureRealWaveformEnvelope(String? path) async {
    if (path == null || path.isEmpty || _realWaveformCache.containsKey(path) || _loadingWaveformPath == path) {
      return;
    }
    _loadingWaveformPath = path;
    try {
      final normalized = await Isolate.run(() => _computeAudioWaveformIsolate(path));
      if (normalized != null && normalized.isNotEmpty) {
        _realWaveformCache[path] = normalized;
        if (mounted) setState(() {});
      }
    } catch (_) {
    } finally {
      if (_loadingWaveformPath == path) _loadingWaveformPath = '';
    }
  }

  double _getWaveformBarHeight(int index, String seedTitle, [String? songPath]) {
    if (songPath != null && songPath.isNotEmpty) {
      final cached = _realWaveformCache[songPath];
      if (cached != null && index >= 0 && index < cached.length) {
        return cached[index];
      }
      _ensureRealWaveformEnvelope(songPath);
    }
    final hash = seedTitle.codeUnits.fold(0, (prev, elem) => prev + elem);
    final wave1 = math.sin((index + hash) * 0.42).abs();
    final wave2 = math.cos((index * 0.85) + (hash * 0.1)).abs();
    return ((10.0 + (wave1 * 20.0) + (wave2 * 14.0))).clamp(6.0, 38.0);
  }

  void _autoScrollToActiveLyric(int activeIdx) {
    if (activeIdx == _lastScrolledLyricIndex) return;
    _lastScrolledLyricIndex = activeIdx;
    if (_lyricsScrollCtrl.hasClients) {
      final target = (activeIdx * _lyricLineExtent).clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent);
      _lyricsScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 680),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  double _computeLineSyllableProgress(List<LyricLine> lyrics, int activeIdx, Duration pos) {
    final currentLine = lyrics[activeIdx];
    if (currentLine.syllables.isNotEmpty) {
      int passed = 0;
      for (int i = 0; i < currentLine.syllables.length; i++) {
        if (pos >= currentLine.syllables[i].timestamp) {
          passed = i + 1;
        }
      }
      return (passed / currentLine.syllables.length).clamp(0.0, 1.0);
    }
    final startMs = currentLine.timestamp.inMilliseconds;
    final endMs = (activeIdx + 1 < lyrics.length)
        ? lyrics[activeIdx + 1].timestamp.inMilliseconds
        : (startMs + 3500);
    final span = math.max(400, endMs - startMs);
    return ((pos.inMilliseconds - startMs) / span).clamp(0.0, 1.0);
  }

  void _seekRelative(int seconds) {
    final cur = widget.audioPlayer.state.position;
    final target = cur + Duration(seconds: seconds);
    widget.audioPlayer.seek(target < Duration.zero ? Duration.zero : target);
  }

  void _showMoreAndLoopSheet(AudioTrack? song) {
    showNamiFloatingActionSheet(
      context: context,
      title: song?.title ?? 'Now Playing',
      subtitle: song != null ? '${cleanArtistStr(song.artist)} • ${song.album}' : null,
      actions: [
        NamiFloatingActionItem(
          icon: Icons.lyrics_rounded,
          title: 'Lyrics Metadata & Editor',
          subtitle: 'Sync offset, fetch or edit lyrics',
          onTap: () => widget.onOpenLyricsManager(),
        ),
        NamiFloatingActionItem(
          icon: Icons.tune_rounded,
          title: 'Track Options & Tag Editor',
          subtitle: 'Artist, album, cover art, queue & file info',
          onTap: () => widget.onOpenMoreMenu(),
        ),
        if (song != null && widget.onGoToArtist != null)
          NamiFloatingActionItem(
            icon: Icons.groups_rounded,
            title: 'Go to Artist',
            subtitle: cleanArtistStr(song.artist),
            onTap: () {
              showNamiArtistPickerOrNavigate(
                context: context,
                rawArtist: song.artist,
                artistImagePaths: const <String, String>{},
                onSelectArtist: (picked) {
                  NamiExpandablePlayerController.safeClose(context);
                  widget.onGoToArtist!(picked);
                },
              );
            },
          ),
      ],
    );
  }

  @override
  void dispose() {
    _seekFlashTimer?.cancel();
    _lyricsScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<AudioTrack?>(
      valueListenable: widget.currentSongNotifier,
      builder: (context, song, _) {
        final ext = namiFormatBadgeForPath(song?.path, fallback: 'FLAC');
        final bitrate = song?.bitrateKbps ?? 1645;
        final kHz = ((song?.sampleRateHz ?? 48000) / 1000.0).toStringAsFixed(1);
        final mq = MediaQuery.of(context);
        final screenWidth = mq.size.width;
        final screenHeight = mq.size.height;
        final artSize = math.min(screenWidth - 28, screenHeight * 0.42);
        final glowColor = _extractDominantColor(song?.albumArt, accent);
        final dynamicIdx = (song != null && widget.allSongs.contains(song)) ? (widget.allSongs.indexOf(song) + 1) : 1;
        final totalCount = widget.allSongs.length;

        Widget artWidget;
        if (song?.albumArt != null && song!.albumArt!.isNotEmpty) {
          artWidget = Image.memory(song.albumArt!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true, cacheWidth: 720);
        } else if (song?.thumbPath != null && File(song!.thumbPath!).existsSync()) {
          artWidget = Image.file(File(song.thumbPath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true, cacheWidth: 720);
        } else {
          artWidget = Container(color: const Color(0xFF14141E), child: const NamiCustomIcon(NamiCustomIcons.albumDisc, size: 96, opacity: 0.45));
        }

        return Scaffold(
          backgroundColor: const Color(0xFF07070B),
          body: NamiInteractiveDragDismiss(
        onDismiss: () { if (NamiExpandablePlayerController.isExpanded) { NamiExpandablePlayerController.collapse(); } else { NamiExpandablePlayerController.safeClose(context); } },
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.45),
                      radius: 0.95,
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.72],
                    ),
                  ),
                ),
              ),
            ),
            Stack(
            children: [
              if (widget.blurredBackdrop && song?.albumArt != null && song!.albumArt!.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.24,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 46, sigmaY: 46),
                      child: Image.memory(song.albumArt!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 720),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF07070B).withValues(alpha: 0.68),
                        const Color(0xFF07070B).withValues(alpha: 0.84),
                        const Color(0xFF07070B),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                decoration: BoxDecoration(
                  gradient: widget.ambientGlow
                      ? RadialGradient(
                          center: const Alignment(0.0, -0.22),
                          radius: 1.05,
                          colors: [glowColor.withValues(alpha: 0.28), glowColor.withValues(alpha: 0.08), Colors.transparent],
                          stops: const [0.0, 0.52, 1.0],
                        )
                      : null,
                ),
                child: SafeArea(
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 28),
                        onPressed: () => NamiExpandablePlayerController.safeClose(context),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('$dynamicIdx/$totalCount', style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text((song?.album ?? 'ALBUM'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showMoreAndLoopSheet(song),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(17)),
                          child: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  Center(
                    child: _viewMode == 0
                        ? _NamiSmoothSwipeArt(
                            audioPlayer: widget.audioPlayer,
                            onNext: widget.onNext,
                            onPrevious: widget.onPrevious,
                            onDismiss: () => NamiExpandablePlayerController.safeClose(context),
                            child: StreamBuilder<bool>(
                              stream: widget.audioPlayer.stream.playing,
                              builder: (pCtx, pSnap) {
                                final isP = pSnap.data ?? widget.audioPlayer.state.playing;
                                return RepaintBoundary(
                                  child: Container(
                                    width: artSize,
                                    height: artSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isP ? accent.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.75),
                                          blurRadius: isP ? 28 : 20,
                                          spreadRadius: isP ? 2 : 1,
                                        ),
                                      ],
                                    ),
                                    child: NamiFullArtRectReporter(
                                  child: NamiSpringCoverSwipe(
                                  onNext: () => _NamiHomeShellState.activeInstance?._playNextTrack(),
                                  onPrev: () => _NamiHomeShellState.activeInstance?._playPrevTrack(),
                                  child: StreamBuilder<bool>(/* v22_art_breathe */
                                  stream: widget.audioPlayer.stream.playing,
                                  builder: (_, playSnap) {
                                    final playingNow = playSnap.data ?? widget.audioPlayer.state.playing;
                                    return AnimatedScale(
                                      scale: (!NamiUxPrefs.breathingCoverArt || playingNow) ? 1.0 : 0.93,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      child: GestureDetector(/* v19_art_double_tap */
                                  onDoubleTap: () {
                                    if (!NamiUxPrefs.doubleTapArtLyrics) return;
                                    HapticFeedback.mediumImpact();
                                    setState(() {
                                      _viewMode = _viewMode == 1 ? 0 : 1;
                                      _lastScrolledLyricIndex = -1;
                                    });
                                    if (_viewMode == 1) { widget.onRefreshLyrics(); _jumpToCurrentSyncedLyric(); }
                                  },
                                  child: Hero(
                                      tag: 'nami_np_art_${song?.path ?? ""}',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: SizedBox.expand(child: artWidget),
                                      ),
                                    ),
                                ),
                                    );
                                  },
                                ),
                                ),
                                ),
                                  ),
                                );
                              },
                            ),
                          )
                        : SizedBox(
                            width: artSize,
                            height: artSize,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.white60),
                                          onPressed: () => setState(() => _lyricsShiftSec = (_lyricsShiftSec - 0.5).clamp(-5.0, 5.0)),
                                        ),
                                        Text(
                                          'Sync ${_lyricsShiftSec >= 0 ? "+" : ""}${_lyricsShiftSec.toStringAsFixed(1)}s',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white60),
                                          onPressed: () => setState(() => _lyricsShiftSec = (_lyricsShiftSec + 0.5).clamp(-5.0, 5.0)),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: Colors.white70,
                                        backgroundColor: Colors.white.withValues(alpha: 0.07),
                                      ),
                                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                                      label: const Text('Edit LRC', style: TextStyle(fontSize: 11)),
                                      onPressed: widget.onOpenLyricsManager,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: _lyricLineExtent * 9,
                                  child: StreamBuilder<Duration>(
                                    stream: widget.audioPlayer.stream.position,
                    initialData: widget.audioPlayer.state.position,
                                    builder: (context, snapshot) {
                                      final rawPos = snapshot.data ?? Duration.zero;
                                      final pos = rawPos + Duration(milliseconds: (_lyricsShiftSec * 1000).round());
                                      final lyrics = song?.parsedLyrics ?? [];
                                      if (lyrics.isEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text("No synced lyrics found.", style: TextStyle(color: Colors.white60)),
                                              const SizedBox(height: 8),
                                              OutlinedButton(
                                                onPressed: widget.onOpenLyricsManager,
                                                child: const Text('Search or Add Lyrics'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      int activeIdx = lyrics.lastIndexWhere((l) => l.timestamp <= pos);
                                      if (activeIdx < 0) activeIdx = 0;
                                      WidgetsBinding.instance.addPostFrameCallback((_) => _autoScrollToActiveLyric(activeIdx));
                                      final sweepProgress = _computeLineSyllableProgress(lyrics, activeIdx, pos);

                                      return NamiSmoothLyricsView(
                                      lines: lyrics,
                                      positionStream: widget.audioPlayer.stream.position,
                                      initialPosition: widget.audioPlayer.state.position,
                                      playingStream: widget.audioPlayer.stream.playing,
                                      initialPlaying: widget.audioPlayer.state.playing,
                                      accentColor: Theme.of(context).colorScheme.primary,
                                      onSeek: (d) => widget.audioPlayer.seek(d),
                                    );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  const Spacer(flex: 3),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song?.title ?? 'Not Playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                              const SizedBox(height: 4),
                              GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final raw = song?.artist ?? '';
                            if (raw.trim().isEmpty || widget.onGoToArtist == null) return;
                            HapticFeedback.selectionClick();
                            showNamiArtistPickerOrNavigate(
                              context: context,
                              rawArtist: raw,
                              artistImagePaths: const <String, String>{},
                              onSelectArtist: (picked) {
                                NamiExpandablePlayerController.safeClose(context);
                                widget.onGoToArtist!(picked);
                              },
                            );
                          },
                          child: Text(cleanArtistStr(song?.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
                        ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon((song?.isFavorite ?? false) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: (song?.isFavorite ?? false) ? accent : Colors.white60, size: 25),
                          onPressed: () {
                            widget.onToggleFavorite();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  
                  StreamBuilder<Duration>(
                    stream: widget.audioPlayer.stream.position,
                    initialData: widget.audioPlayer.state.position,
                    builder: (context, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      return StreamBuilder<Duration?>(
                        stream: widget.audioPlayer.stream.duration,
                        builder: (context, durSnap) {
                          final dur = durSnap.data ?? song?.duration ?? const Duration(minutes: 3, seconds: 32);
                          double maxMs = dur.inMilliseconds.toDouble();
                          if (maxMs <= 0) maxMs = 1.0;
                          double curMs = pos.inMilliseconds.toDouble().clamp(0.0, maxMs);
                          final prog = curMs / maxMs;
                          return LayoutBuilder(
                            builder: (ctx, constraints) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (d) => widget.audioPlayer.seek(Duration(milliseconds: ((d.localPosition.dx / constraints.maxWidth) * maxMs).toInt())),
                              onHorizontalDragUpdate: (d) {
                                final ratio = (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                widget.audioPlayer.seek(Duration(milliseconds: (ratio * maxMs).toInt()));
                              },
                              child: SizedBox(
                                height: 38,
                                width: double.infinity,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    78,
                                    (i) {
                                      final ratio = i / 78;
                                      final isPlayed = ratio <= prog;
                                      final isHead = (ratio - prog).abs() < 0.015;
                                      return Container(
                                        width: isHead ? 3.0 : 2.3,
                                        height: _getWaveformBarHeight(i, song?.title ?? 'Nami', song?.path) + (isHead ? 4.0 : 0.0),
                                        decoration: BoxDecoration(
                                          color: isHead
                                              ? Colors.white
                                              : (isPlayed ? accent : Colors.white24),
                                          borderRadius: BorderRadius.circular(1.5),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () => _triggerSeekFeedback(-widget.doubleTapSeekSec),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                            child: StreamBuilder<Duration>(
                              stream: widget.audioPlayer.stream.position,
                    initialData: widget.audioPlayer.state.position,
                              builder: (ctx, snap) => Text(
                                _formatDurationPadded(snap.data ?? Duration.zero),
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        StreamBuilder<bool>(
                          stream: widget.audioPlayer.stream.playing,
                          builder: (ctx, stateSnap) {
                            final playing = stateSnap.data ?? widget.audioPlayer.state.playing;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const NamiCustomIcon(NamiCustomIcons.nextTrack, size: 27, flipHorizontal: true), onPressed: widget.onPrevious),
                                const SizedBox(width: 8.0),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    playing ? widget.audioPlayer.pause() : widget.audioPlayer.play();
                                  },
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [accent.withValues(alpha: 0.34), accent.withValues(alpha: 0.12)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.28),
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
                                      child: NamiCustomIcon(
                                        playing ? NamiCustomIcons.pause : NamiCustomIcons.play,
                                        key: ValueKey<bool>(playing),
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                IconButton(icon: const NamiCustomIcon(NamiCustomIcons.nextTrack, size: 27), onPressed: widget.onNext),
                              ],
                            );
                          },
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () => _triggerSeekFeedback(widget.doubleTapSeekSec),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                            child: StreamBuilder<Duration?>(
                              stream: widget.audioPlayer.stream.duration,
                              builder: (ctx, snap) => Text(
                                _formatDurationPadded(snap.data ?? song?.duration ?? Duration.zero),
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: widget.onShowPath,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                                  child: const NamiCustomIcon(NamiCustomIcons.headphones, size: 15),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(text: 'Audio ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                                          TextSpan(text: '• $ext • $bitrate kb/s • $kHz kHz', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        showNamiSignalChainSheet(
                          context: context,
                          song: song,
                          outputDevice: 'Audio Output',
                          eqEnabled: false,
                        );
                      },
                      child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${song?.bitDepth ?? 24}-Bit • Bit-Perfect Path',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: accent),
                                        ),
                                      ],
                                    ),
                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_seekFlashLabel != null)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: accent.withValues(alpha: 0.24), borderRadius: BorderRadius.circular(8)),
                                child: Text(_seekFlashLabel!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent)),
                              ),
                            Tooltip(
                              message: 'Tap: Repeat • Hold: Shuffle',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onCycleRepeat();
                                  final nextRep = (_repeatLocal + 1) % 3;
                                  setState(() => _repeatLocal = nextRep);
                                  const labels = ['Repeat Off', 'Repeat All', 'Repeat One'];
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        duration: const Duration(milliseconds: 900),
                                        content: Text(labels[nextRep]),
                                      ),
                                    );
                                },
                                onLongPress: () {
                                  HapticFeedback.mediumImpact();
                                  widget.onToggleShuffle();
                                  final nextShuf = !_shuffleLocal;
                                  setState(() => _shuffleLocal = nextShuf);
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        duration: const Duration(milliseconds: 900),
                                        content: Text(nextShuf ? 'Shuffle ON' : 'Shuffle OFF'),
                                      ),
                                    );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      (_repeatLocal == 0)
                                          ? NamiCustomIcon(NamiCustomIcons.shuffle, size: 21, opacity: _shuffleLocal ? 1.0 : 0.62)
                                          : Icon(
                                              _repeatLocal == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                              size: 21,
                                              color: accent,
                                            ),
                                      if (_shuffleLocal && _repeatLocal > 0)
                                        Positioned(
                                          right: -3,
                                          top: -3,
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const NamiCustomIcon(NamiCustomIcons.equalizer, size: 20, opacity: 0.88),
                              onPressed: widget.onShowEqualizer,
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onLongPress: widget.onOpenLyricsManager,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: NamiCustomIcon(NamiCustomIcons.lyrics, size: 20, opacity: _viewMode == 1 ? 1.0 : 0.72),
                                onPressed: () {
                                  setState(() {
                                    _viewMode = _viewMode == 1 ? 0 : 1;
                                    _lastScrolledLyricIndex = -1;
                                  });
                                  if (_viewMode == 1) { widget.onRefreshLyrics(); _jumpToCurrentSyncedLyric(); }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const NamiCustomIcon(NamiCustomIcons.playlist, size: 20, opacity: 0.88),
                              onPressed: widget.onOpenQueue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
          ],
        ),
      ),
        );
      },
    );
  }
}


class _NamiSmoothSwipeArt extends StatefulWidget {
  final dynamic audioPlayer;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onDismiss;
  final Widget child;

  const _NamiSmoothSwipeArt({
    required this.audioPlayer,
    required this.onNext,
    required this.onPrevious,
    required this.onDismiss,
    required this.child,
  });

  @override
  State<_NamiSmoothSwipeArt> createState() => _NamiSmoothSwipeArtState();
}

class _NamiSmoothSwipeArtState extends State<_NamiSmoothSwipeArt> {
  double _dx = 0.0;
  bool _dragging = false;

  void _resetSmooth() {
    setState(() {
      _dragging = false;
      _dx = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        setState(() => _dragging = true);
      },
      onHorizontalDragUpdate: (d) {
        final resist = _dx.abs() > 70.0 ? 0.35 : 0.85;
        setState(() {
          _dragging = true;
          _dx = (_dx + d.delta.dx * resist).clamp(-120.0, 120.0);
        });
      },
      onHorizontalDragEnd: (details) {
        final vx = details.primaryVelocity ?? 0.0;
        final goNext = _dx < -48.0 || vx < -220.0;
        final goPrev = _dx > 48.0 || vx > 220.0;
        _resetSmooth();
        if (goNext) {
          HapticFeedback.selectionClick();
          widget.onNext();
        } else if (goPrev) {
          HapticFeedback.selectionClick();
          widget.onPrevious();
        }
      },
      onHorizontalDragCancel: _resetSmooth,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 360) {
          widget.onDismiss();
        }
      },
      child: StreamBuilder<bool>(
        stream: widget.audioPlayer.stream.playing,
        builder: (ctx, snap) {
          final isP = snap.data ?? widget.audioPlayer.state.playing;
          final pauseScale = isP ? 1.0 : 0.98;
          return AnimatedSlide(
            offset: Offset(_dx / 260.0, 0.0),
            duration: Duration(milliseconds: _dragging ? 0 : 200),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: pauseScale,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
