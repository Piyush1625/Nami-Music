with open("lib/main.dart", "r", encoding="utf-8") as f:
    c = f.read()

# 1. Mini-player: add vertical swipe-up + bottom progress indicator
old_mini_top = """          onTap: _showNowPlayingScreen,
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _forceMiniColor ? Color.alphaBlend(accent.withOpacity(0.22), const Color(0xFF12121A)) : const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _forceMiniColor ? accent.withOpacity(0.45) : Colors.white12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.65), blurRadius: 18, spreadRadius: 4)],
            ),
            child: Row("""

new_mini_top = """          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -150) {
              _showNowPlayingScreen();
            }
          },
          onTap: _showNowPlayingScreen,
          child: Container(
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _forceMiniColor ? Color.alphaBlend(accent.withOpacity(0.22), const Color(0xFF12121A)) : const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _forceMiniColor ? accent.withOpacity(0.45) : Colors.white12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.65), blurRadius: 18, spreadRadius: 4)],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row("""

assert old_mini_top in c, "old_mini_top not found"
c = c.replace(old_mini_top, new_mini_top, 1)

old_mini_bot = """              IconButton(icon: const Icon(Icons.skip_next_rounded, size: 24), onPressed: _playNextTrack),
            ],
          ),
        ),"""

new_mini_bot = """                      IconButton(icon: const Icon(Icons.skip_next_rounded, size: 24), onPressed: _playNextTrack),
                    ],
                  ),
                ),
              ),
              StreamBuilder<Duration>(
                stream: _audioPlayer.stream.position,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final dur = _audioPlayer.state.duration;
                  final ratio = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
                  return LinearProgressIndicator(
                    value: ratio,
                    minHeight: 2.5,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  );
                },
              ),
            ],
          ),
        ),"""

assert old_mini_bot in c, "old_mini_bot not found"
c = c.replace(old_mini_bot, new_mini_bot, 1)

# 2. Richer multi-stop ambient glow on Now Playing screen
old_glow = """              gradient: widget.ambientGlow
                  ? RadialGradient(
                      center: const Alignment(0.0, -0.25),
                      radius: 0.9,
                      colors: [
                        glowColor.withOpacity(0.18),
                        const Color(0xFF07070B),
                      ],
                    )
                  : null,"""

new_glow = """              gradient: widget.ambientGlow
                  ? RadialGradient(
                      center: const Alignment(0.0, -0.22),
                      radius: 1.05,
                      colors: [
                        glowColor.withOpacity(0.32),
                        glowColor.withOpacity(0.11),
                        const Color(0xFF07070B),
                      ],
                      stops: const [0.0, 0.52, 1.0],
                    )
                  : null,"""

assert old_glow in c, "old_glow not found"
c = c.replace(old_glow, new_glow, 1)

# 3. Smooth lyric auto-scroll easing + Apple Music active line scaling
c = c.replace("duration: const Duration(milliseconds: 750),\n        curve: Curves.easeOutCubic,",
              "duration: const Duration(milliseconds: 680),\n        curve: Curves.easeInOutCubic,", 1)

old_lyric_line = """                    return GestureDetector(
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
                    );"""

new_lyric_line = """                    return GestureDetector(
                      onTap: () => widget.audioPlayer.seek(lyrics[idx].timestamp),
                      child: AnimatedScale(
                        scale: isCenter5th ? 1.06 : (distance == 1 ? 0.96 : 0.90),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            lineText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isCenter5th ? 18.0 : (distance == 1 ? 14.5 : 12.5),
                              fontWeight: isCenter5th ? FontWeight.w800 : FontWeight.w500,
                              color: isCenter5th
                                  ? Colors.white
                                  : (distance == 1 ? Colors.white60 : (distance <= 3 ? Colors.white30 : Colors.white12)),
                            ),
                          ),
                        ),
                      ),
                    );"""

assert old_lyric_line in c, "old_lyric_line not found"
c = c.replace(old_lyric_line, new_lyric_line, 1)

with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(c)

print("SUCCESS: Applied Mini-Player gestures/progress bar, Ambient Glow & Lyrics scaling!")
