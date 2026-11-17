import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryManager {
  static const String _keyPlayCounts = 'nami_play_counts';
  static const String _keyHistory = 'nami_play_history';

  static Future<void> recordPlay(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final counts = prefs.getString(_keyPlayCounts) != null 
        ? Map<String, dynamic>.from(jsonDecode(prefs.getString(_keyPlayCounts)!))
        : <String, dynamic>{};
    counts[songId] = (counts[songId] ?? 0) + 1;
    await prefs.setString(_keyPlayCounts, jsonEncode(counts));

    List<String> history = prefs.getStringList(_keyHistory) ?? [];
    history.remove(songId);
    history.insert(0, songId);
    if (history.length > 100) history = history.sublist(0, 100);
    await prefs.setStringList(_keyHistory, history);
  }

  static Future<int> getPlayCount(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyPlayCounts) == null) return 0;
    final counts = Map<String, dynamic>.from(jsonDecode(prefs.getString(_keyPlayCounts)!));
    return counts[songId] ?? 0;
  }

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyHistory) ?? [];
  }
}

class QueueManager {
  static const String _keySavedQueue = 'nami_saved_queue';
  static const String _keySavedIndex = 'nami_saved_index';

  static Future<void> saveQueueState(List<String> songIds, int currentIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySavedQueue, songIds);
    await prefs.setInt(_keySavedIndex, currentIndex);
  }

  static Future<Map<String, dynamic>>> loadQueueState() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_keySavedQueue);
    final index = prefs.getInt(_keySavedIndex);
    if (queue == null || queue.isEmpty) return null;
    return {
      'queue': queue,
      'index': index ?? 0,
    };
  }
}

class MetadataCacheManager {
  static Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/metadata_cache.json');
  }

  static Future<void> saveCache(Map<String, dynamic> metadataMap) async {
    try {
      final file = await _getCacheFile();
      await file.writeAsString(jsonEncode(metadataMap));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return Map<String, dynamic>.from(jsonDecode(content));
      }
    } catch (_) {}
    return {};
  }
}
