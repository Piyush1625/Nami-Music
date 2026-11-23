import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class NamiLibraryStore {
  static Timer? _debounceTimer;
  static Future<void> Function()? _pendingWriter;

  static void scheduleSave(
    Future<void> Function() writer, {
    Duration delay = const Duration(milliseconds: 600),
  }) {
    _pendingWriter = writer;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () async {
      final fn = _pendingWriter;
      _pendingWriter = null;
      if (fn != null) {
        await fn();
      }
    });
  }

  static Future<void> flushNow() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final fn = _pendingWriter;
    _pendingWriter = null;
    if (fn != null) {
      await fn();
    }
  }

  static Future<void> writeAtomicJson(File target, Object data) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode(data));
    await tmp.rename(target.path);
  }

  static Future<void> writeSplitTables(
    Directory dir,
    Map<String, dynamic> fullMap,
  ) async {
    final settings = Map<String, dynamic>.from(fullMap)
      ..remove('cachedTracks')
      ..remove('customPlaylists');
    final tracks = fullMap['cachedTracks'] ?? const [];
    final playlists = fullMap['customPlaylists'] ?? const [];

    await Future.wait([
      writeAtomicJson(File('${dir.path}/nami_settings_v5.json'), settings),
      writeAtomicJson(File('${dir.path}/nami_tracks_v5.json'), tracks),
      writeAtomicJson(File('${dir.path}/nami_playlists_v5.json'), playlists),
    ]);
  }

  static Future<Map<String, dynamic>?> readSplitTables(Directory dir) async {
    final settingsFile = File('${dir.path}/nami_settings_v5.json');
    if (!await settingsFile.exists()) return null;
    try {
      final rawSettings = jsonDecode(await settingsFile.readAsString());
      if (rawSettings is! Map) return null;
      final merged = Map<String, dynamic>.from(rawSettings);

      final tracksFile = File('${dir.path}/nami_tracks_v5.json');
      if (await tracksFile.exists()) {
        merged['cachedTracks'] = jsonDecode(await tracksFile.readAsString());
      }
      final playlistsFile = File('${dir.path}/nami_playlists_v5.json');
      if (await playlistsFile.exists()) {
        merged['customPlaylists'] = jsonDecode(await playlistsFile.readAsString());
      }
      return merged;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> readLazyCoverBytes(String? thumbPath) async {
    if (thumbPath == null || thumbPath.isEmpty) return null;
    try {
      final f = File(thumbPath);
      if (await f.exists()) {
        return await f.readAsBytes();
      }
    } catch (_) {}
    return null;
  }
}
