import 'dart:io';
import 'dart:ui';
import '../models/nami_models.dart';

class NamiMetadataService {
  static Future<void> enrichTrackOnlineIfMissing(
    AudioTrack track,
    Directory thumbDir, {
    bool force = false,
    VoidCallback? onArtworkUpdated,
  }) async {
    track.isOnlineEnriched = true;
  }

  static Future<void> extractAudioMetadataUniversal(
    AudioTrack track,
    Directory thumbDir, {
    VoidCallback? onArtworkUpdated,
  }) async {
    track.isMetadataLoaded = true;
  }

  static String sanitizeMetadataText(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<LyricLine> parseLrc(String raw) {
    final List<LyricLine> lines = [];
    final reg = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)');
    for (final line in raw.split('\n')) {
      final match = reg.firstMatch(line.trim());
      if (match != null) {
        final mins = int.tryParse(match.group(1)!) ?? 0;
        final secs = double.tryParse(match.group(2)!) ?? 0.0;
        final text = match.group(3)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(milliseconds: (mins * 60000 + secs * 1000).round()),
            text: text,
          ));
        }
      }
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
