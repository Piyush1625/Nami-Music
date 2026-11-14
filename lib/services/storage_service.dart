import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class NamiStorageService {
  static Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/nami_persistent_cache_v3.json');
  }

  static Future<void> saveCacheData(Map<String, dynamic> data) async {
    try {
      final file = await _localFile;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadCacheData() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        return jsonDecode(contents) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
