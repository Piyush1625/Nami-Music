class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

class LyricsService {
  /// Parses standard .lrc file format into structured timestamped lines
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = lrcContent.split('\n');
    final List<LyricLine> parsedLines = [];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (var line in lines) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!.padRight(3, '0').substring(0, 3));
        
        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        final text = line.replaceAll(regExp, '').trim();
        if (text.isNotEmpty) {
          parsedLines.add(LyricLine(timestamp: duration, text: text));
        }
      }
    }
    parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return parsedLines;
  }

  /// Finds the currently active lyric line index based on playback position
  static int getActiveLineIndex(List<LyricLine> lines, Duration position) {
    if (lines.isEmpty) return 0;
    int activeIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      if (position >= lines[i].timestamp) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }
}
