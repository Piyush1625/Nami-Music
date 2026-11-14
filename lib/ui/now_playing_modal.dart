import 'package:nami/core/nami_helpers.dart';
import 'package:nami/utils/nami_helpers.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../core/nami_helpers.dart';
import '../models/nami_models.dart';

class NowPlayingModal extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final ValueNotifier<AudioTrack?> currentSongNotifier;
  final List<AudioTrack> allSongs;
  final List<AudioTrack> playNextQueue;
  final bool ambientGlow;
  final bool syllableLyricsEnabled;
  final VoidCallback onShowPath,
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
    required this.syllableLyricsEnabled,
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
  bool _isLooping = false;
  Duration? _loopA;
  Duration? _loopB;
  final ScrollController _lyricsScrollCtrl = ScrollController();
  int _lastScrolledLyricIndex = -1;
  Timer? _lyricSmoothTicker;
  int _smoothFrame = 0;

  static const double _lyricLineExtent = 42.0;

  @override
  void initState() {
    super.initState();
    _lyricSmoothTicker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted && _viewMode == 1 && widget.audioPlayer.playing) {
        setState(() => _smoothFrame++);
      }
    });
  }

  @override
  void dispose() {
    _lyricSmoothTicker?.cancel();
    _lyricsScrollCtrl.dispose();
    super.dispose();
  }

  double _getWaveformBarHeight(int index, String seedTitle) {
    final hash = seedTitle.codeUnits.fold(0, (prev, elem) => prev + elem);
    final wave1 = math.sin((index + hash) * 0.42).abs();
    final wave2 = math.cos((index * 0.85) + (hash * 0.1)).abs();
    return ((10.0 + (wave1 * 20.0) + (wave2 * 14.0))).clamp(6.0, 40.0);
  }

  void _autoScrollToActiveLyric(int activeIdx) {
    if (activeIdx == _lastScrolledLyricIndex) return;
    _lastScrolledLyricIndex = activeIdx;
    if (_lyricsScrollCtrl.hasClients) {
      final target = (activeIdx * _lyricLineExtent).clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent);
      _lyricsScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  double _computeLineSyllableProgress(List<LyricLine> lyrics, int activeIdx, Duration pos) {
    final currentLine = lyrics[activeIdx];
    final posMs = pos.inMilliseconds;
    if (currentLine.syllables.isNotEmpty) {
      final syls = currentLine.syllables;
      final total = syls.length;
      for (int i = 0; i < total; i++) {
        final sStart = syls[i].timestamp.inMilliseconds;
        final sEnd = (i + 1 < total)
            ? syls[i + 1].timestamp.inMilliseconds
            : ((activeIdx + 1 < lyrics.length)
                ? lyrics[activeIdx + 1].timestamp.inMilliseconds
                : sStart + 450);
        if (posMs < sStart) {
          return (i / total).clamp(0.0, 1.0);
        }
        if (posMs >= sStart && posMs <= sEnd) {
          final span = math.max(80, sEnd - sStart);
          final subFraction = ((posMs - sStart) / span).clamp(0.0, 1.0);
          return ((i + subFraction) / total).clamp(0.0, 1.0);
        }
      }
      return 1.0;
    }
    final startMs = currentLine.timestamp.inMilliseconds;
    final endMs = (activeIdx + 1 < lyrics.length)
        ? lyrics[activeIdx + 1].timestamp.inMilliseconds
        : (startMs + 3500);
    final span = math.max(400, endMs - startMs);
    return ((posMs - startMs) / span).clamp(0.0, 1.0);
  }

  void _seekRelative(int seconds) {
    final cur = widget.audioPlayer.position;
    final target = cur + Duration(seconds: seconds);
    widget.audioPlayer.seek(target < Duration.zero ? Duration.zero : target);
  }

  void _showMoreAndLoopSheet(AudioTrack? song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101016),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.repeat_one_on_rounded),
                title: Text(_loopA == null ? 'Set A-B Loop Start (Point A)' : (_loopB == null ? 'Set A-B Loop End (Point B)' : 'Clear A-B Loop')),
                onTap: () {
                  setState(() {
                    if (_loopA == null) {
                      _loopA = widget.audioPlayer.position;
                    } else if (_loopB == null) {
                      _loopB = widget.audioPlayer.position;
                    } else {
                      _loopA = null;
                      _loopB = null;
                    }
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lyrics_outlined),
                title: const Text('Lyrics Metadata & Editor'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenLyricsManager();
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Sleep Timer'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onShowSleepTimer();
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz_rounded),
                title: const Text('Track Options & Tag Editor'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenMoreMenu();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<AudioTrack?>(
      valueListenable: widget.currentSongNotifier,
      builder: (context, song, _) {
        final ext = (song?.path.split('.').last ?? 'FLAC').toUpperCase();
        final bitrate = song?.bitrateKbps ?? 1645;
        final kHz = ((song?.sampleRateHz ?? 48000) / 1000.0).toStringAsFixed(1);
        final screenWidth = MediaQuery.of(context).size.width;
        final artSize = screenWidth * 0.89;
        final glowColor = namiExtractDominantColor(song?.albumArt, accent);
        final dynamicIdx = (song != null && widget.allSongs.contains(song)) ? (widget.allSongs.indexOf(song) + 1) : 1;
        final totalCount = widget.allSongs.length;

        Widget artWidget;
        if (song?.albumArt != null && song!.albumArt!.isNotEmpty) {
          artWidget = Image.memory(song.albumArt!, fit: BoxFit.cover);
        } else if (song?.thumbPath != null && File(song!.thumbPath!).existsSync()) {
          artWidget = Image.file(File(song.thumbPath!), fit: BoxFit.cover);
        } else {
          artWidget = Container(color: const Color(0xFF14141E), child: const Icon(Icons.album_rounded, size: 100, color: Colors.white24));
        }

        final meshColor1 = glowColor.withOpacity(0.26);
        final meshColor2 =
            glowColor.withRed((glowColor.red * 0.8).toInt()).withOpacity(0.16);
        final meshColor3 = glowColor
            .withBlue((glowColor.blue * 1.2).clamp(0, 255).toInt())
            .withOpacity(0.20);

        return Scaffold(
          backgroundColor: const Color(0xFF050508),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF050508),
              gradient: widget.ambientGlow
                  ? RadialGradient(
                      center: const Alignment(-0.5, -0.5),
                      radius: 1.5,
                      colors: [meshColor1, const Color(0xFF050508)],
                    )
                  : null,
            ),
            child: Stack(
              children: [
                if (widget.ambientGlow)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.8, 0.2),
                          radius: 1.2,
                          colors: [meshColor2, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                if (widget.ambientGlow)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, 0.8),
                          radius: 1.0,
                          colors: [meshColor3, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'PLAYING $dynamicIdx/$totalCount',
                                    style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: 1.3),
                                  ),
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

                        const Spacer(flex: 2),

                        Center(
                          child: _viewMode == 0
                              ? GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onDoubleTap: () => _seekRelative(-5),
                                  child: Hero(
                                    tag: song != null ? 'album_art_${song.path}' : 'album_art_empty',
                                    child: Container(
                                      width: artSize,
                                      height: artSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: glowColor.withOpacity(0.32),
                                            blurRadius: 40,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 14),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: artWidget,
                                      ),
                                    ),
                                  ),
                                )
                        : SizedBox(
                            width: artSize,
                            height: artSize,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: Colors.white70,
                                      backgroundColor: Colors.white.withOpacity(0.07),
                                    ),
                                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                                    label: const Text('Edit LRC', style: TextStyle(fontSize: 11)),
                                    onPressed: widget.onOpenLyricsManager,
                                  ),
                                ),
                                SizedBox(
                                  height: _lyricLineExtent * 9,
                                  child: StreamBuilder<Duration>(
                                    stream: widget.audioPlayer.positionStream,
                                    builder: (context, snapshot) {
                                      final pos = snapshot.data ?? Duration.zero;
                                      if (_loopB != null && _loopA != null && pos >= _loopB!) {
                                        widget.audioPlayer.seek(_loopA!);
                                      }
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

                                      return ListView.builder(
                                        controller: _lyricsScrollCtrl,
                                        itemExtent: _lyricLineExtent,
                                        padding: const EdgeInsets.symmetric(vertical: _lyricLineExtent * 4),
                                        itemCount: lyrics.length,
                                        itemBuilder: (context, idx) {
                                          final isCenter5th = idx == activeIdx;
                                          final distance = (idx - activeIdx).abs();
                                          final lineText = lyrics[idx].text;

                                          if (isCenter5th && widget.syllableLyricsEnabled) {
                                            final featherStart = (sweepProgress - 0.04).clamp(0.0, 1.0);
                                            final featherEnd = (sweepProgress + 0.14).clamp(0.0, 1.0);
                                            return GestureDetector(
                                              onTap: () => widget.audioPlayer.seek(lyrics[idx].timestamp),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 220),
                                                curve: Curves.easeOutCubic,
                                                alignment: Alignment.center,
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                transform: Matrix4.translationValues(0, -1.5, 0),
                                                child: ShaderMask(
                                                  blendMode: BlendMode.srcIn,
                                                  shaderCallback: (bounds) => LinearGradient(
                                                    colors: const [
                                                      Colors.white,
                                                      Colors.white,
                                                      Color(0xB3FFFFFF),
                                                      Color(0x47FFFFFF),
                                                    ],
                                                    stops: [0.0, featherStart, sweepProgress, featherEnd],
                                                  ).createShader(bounds),
                                                  child: Text(
                                                    lineText,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 17.5,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.2,
                                                      shadows: [
                                                        Shadow(color: Color(0x55FFFFFF), blurRadius: 12),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          return GestureDetector(
                                            onTap: () => widget.audioPlayer.seek(lyrics[idx].timestamp),
                                            child: Container(
                                              alignment: Alignment.center,
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Text(
                                                lineText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: isCenter5th ? 16.5 : (distance == 1 ? 14.0 : 12.5),
                                                  fontWeight: isCenter5th ? FontWeight.w800 : FontWeight.w500,
                                                  color: isCenter5th
                                                      ? Colors.white
                                                      : (distance == 1 ? Colors.white54 : (distance <= 3 ? Colors.white30 : Colors.white12)),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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
                              Text(song?.title ?? 'Aankhon Ne Maara', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(song?.artist ?? 'Farhan Khan, Mr Doss', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
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
                    stream: widget.audioPlayer.positionStream,
                    builder: (context, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      if (_loopB != null && _loopA != null && pos >= _loopB!) {
                        widget.audioPlayer.seek(_loopA!);
                      }
                      return StreamBuilder<Duration?>(
                        stream: widget.audioPlayer.durationStream,
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
                                    (i) => Container(
                                      width: 2.2,
                                      height: _getWaveformBarHeight(i, song?.title ?? 'Aankhon Ne Maara'),
                                      decoration: BoxDecoration(color: (i / 78) <= prog ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(1.5)),
                                    ),
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
                        StreamBuilder<Duration>(
                          stream: widget.audioPlayer.positionStream,
                          builder: (ctx, snap) => Text(
                            namiFormatDurationPadded(snap.data ?? Duration.zero),
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: widget.audioPlayer.playerStateStream,
                          builder: (ctx, stateSnap) {
                            final playing = stateSnap.data?.playing ?? widget.audioPlayer.playing;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 28, color: Colors.white), onPressed: widget.onPrevious),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () => playing ? widget.audioPlayer.pause() : widget.audioPlayer.play(),
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                                    child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(icon: const Icon(Icons.skip_next_rounded, size: 28, color: Colors.white), onPressed: widget.onNext),
                              ],
                            );
                          },
                        ),
                        StreamBuilder<Duration?>(
                          stream: widget.audioPlayer.durationStream,
                          builder: (ctx, snap) => Text(
                            namiFormatDurationPadded(snap.data ?? song?.duration ?? const Duration(minutes: 3, seconds: 32)),
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
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
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                                  child: const Icon(Icons.headphones_outlined, size: 14, color: Colors.white70),
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
                                    const SizedBox(height: 1),
                                    const Text('24-bit Hi-Res Lossless', style: TextStyle(fontSize: 9, color: Colors.white38)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(_isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded, size: 20, color: _isLooping ? accent : Colors.white70),
                              onPressed: () {
                                setState(() => _isLooping = !_isLooping);
                                widget.audioPlayer.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
                              },
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.tune_rounded, size: 20, color: Colors.white70),
                              onPressed: widget.onShowEqualizer,
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onLongPress: widget.onOpenLyricsManager,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.lyrics_outlined, size: 20, color: _viewMode == 1 ? accent : Colors.white70),
                                onPressed: () {
                                  setState(() {
                                    _viewMode = _viewMode == 1 ? 0 : 1;
                                    _lastScrolledLyricIndex = -1;
                                  });
                                  if (_viewMode == 1) widget.onRefreshLyrics();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.queue_music_rounded, size: 20, color: Colors.white70),
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
          ),
        );
      },
    );
  }
}
