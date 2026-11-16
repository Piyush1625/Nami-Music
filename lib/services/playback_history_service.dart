import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackHistoryService {
  static const String _keyLastSongId = 'last_song_id';
  static const String _keyLastPosition = 'last_position_ms';
  static const String _keyPlayCountPrefix = 'play_count_';

  /// Save last played track and position
  static Future<void> savePlaybackState(String songId, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSongId, songId);
    await prefs.setInt(_keyLastPosition, position.inMilliseconds);
  }

  /// Increment play count for a specific track
  static Future<void> incrementPlayCount(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPlayCountPrefix}${songId}';
    final currentCount = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, currentCount + 1);
  }

  /// Get play count for a track
  static Future<int> getPlayCount(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_keyPlayCountPrefix}${songId}') ?? 0;
  }

  /// Retrieve last saved playback state
  static Future?> getLastPlaybackState() async {
    final prefs = await SharedPreferences.getInstance();
    final songId = prefs.getString(_keyLastSongId);
    final positionMs = prefs.getInt(_keyLastPosition) ?? 0;

    if (songId == null) return null;

    return {
      'songId': songId,
      'position': Duration(milliseconds: positionMs),
    };
  }
}
