import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NamiScrobbleService {
  NamiScrobbleService._();
  static final NamiScrobbleService instance = NamiScrobbleService._();

  static const String _kToken = 'nami_lb_token_v1';
  static const String _kEnabled = 'nami_lb_enabled_v1';
  static const String _kPending = 'nami_lb_pending_v1';
  static const String _kTotalScrobbles = 'nami_lb_total_v1';

  String token = '';
  bool enabled = false;
  int totalScrobbled = 0;
  final List<Map<String, dynamic>> pendingQueue = [];

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = (prefs.getString(_kToken) ?? '').trim();
      enabled = prefs.getBool(_kEnabled) ?? false;
      totalScrobbled = prefs.getInt(_kTotalScrobbles) ?? 0;
      final raw = prefs.getString(_kPending);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          pendingQueue
            ..clear()
            ..addAll(list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        }
      }
    } catch (_) {}
  }

  Future<void> saveConfig({required String userToken, required bool isEnabled}) async {
    token = userToken.trim();
    enabled = isEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, token);
      await prefs.setBool(_kEnabled, enabled);
    } catch (_) {}
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPending, jsonEncode(pendingQueue));
      await prefs.setInt(_kTotalScrobbles, totalScrobbled);
    } catch (_) {}
  }

  Future<void> submitPlayingNow({
    required String title,
    required String artist,
    required String album,
  }) async {
    if (!enabled || token.isEmpty || title.trim().isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('https://api.listenbrainz.org/1/submit-listens'),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'listen_type': 'playing_now',
              'payload': [
                {
                  'track_metadata': {
                    'artist_name': artist,
                    'track_name': title,
                    'release_name': album,
                  }
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<bool> scrobbleTrack({
    required String title,
    required String artist,
    required String album,
    int? listenedAtSec,
  }) async {
    if (!enabled || token.isEmpty || title.trim().isEmpty) return false;
    final payloadItem = {
      'listened_at': listenedAtSec ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      'track_metadata': {
        'artist_name': artist,
        'track_name': title,
        'release_name': album,
      },
    };
    try {
      final res = await http
          .post(
            Uri.parse('https://api.listenbrainz.org/1/submit-listens'),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'listen_type': 'single',
              'payload': [payloadItem],
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        totalScrobbled++;
        await _saveQueue();
        if (pendingQueue.isNotEmpty) {
          await flushPending();
        }
        return true;
      }
    } catch (_) {}

    pendingQueue.add(payloadItem);
    if (pendingQueue.length > 200) {
      pendingQueue.removeAt(0);
    }
    await _saveQueue();
    return false;
  }

  Future<int> flushPending() async {
    if (!enabled || token.isEmpty || pendingQueue.isEmpty) return 0;
    try {
      final batch = List<Map<String, dynamic>>.from(pendingQueue);
      final res = await http
          .post(
            Uri.parse('https://api.listenbrainz.org/1/submit-listens'),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'listen_type': 'import',
              'payload': batch,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final count = batch.length;
        totalScrobbled += count;
        pendingQueue.clear();
        await _saveQueue();
        return count;
      }
    } catch (_) {}
    return 0;
  }
}
