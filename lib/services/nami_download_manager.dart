import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'nami_tag_writer.dart';

enum MornyeDownloadStatus { queued, downloading, tagging, done, error, cancelled }

class MornyeDownloadTask {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String url;
  final String? artworkUrl;
  final String destPath;
  final bool isFullStream;

  double progress;
  MornyeDownloadStatus status;
  String? errorMessage;

  MornyeDownloadTask({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.url,
    required this.destPath,
    this.artworkUrl,
    this.isFullStream = false,
    this.progress = 0.0,
    this.status = MornyeDownloadStatus.queued,
    this.errorMessage,
  });
}

class NamiDownloadManager {
  NamiDownloadManager._();
  static final NamiDownloadManager instance = NamiDownloadManager._();

  static const Map<String, String> _headers = {
    'User-Agent': 'NamiMusicPlayer/2.0 (https://github.com/Piyush1625/nami)',
  };

  final ValueNotifier<List<MornyeDownloadTask>> tasksNotifier =
      ValueNotifier<List<MornyeDownloadTask>>([]);

  final Map<String, http.Client> _activeClients = {};
  bool _isRunningQueue = false;
  Future<void> Function()? onTrackSaved;

  void _notify() {
    tasksNotifier.value = List<MornyeDownloadTask>.from(tasksNotifier.value);
  }

  void enqueue(MornyeDownloadTask task) {
    final list = List<MornyeDownloadTask>.from(tasksNotifier.value);
    list.removeWhere((t) => t.id == task.id);
    list.insert(0, task);
    tasksNotifier.value = list;
    _drainQueue();
  }

  void cancelTask(String id) {
    final idx = tasksNotifier.value.indexWhere((t) => t.id == id);
    if (idx != -1) {
      tasksNotifier.value[idx].status = MornyeDownloadStatus.cancelled;
      _activeClients.remove(id)?.close();
      _notify();
    }
  }

  void retryTask(String id) {
    final idx = tasksNotifier.value.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final t = tasksNotifier.value[idx];
      t.status = MornyeDownloadStatus.queued;
      t.progress = 0.0;
      t.errorMessage = null;
      _notify();
      _drainQueue();
    }
  }

  void clearFinished() {
    tasksNotifier.value = tasksNotifier.value
        .where((t) =>
            t.status == MornyeDownloadStatus.queued ||
            t.status == MornyeDownloadStatus.downloading ||
            t.status == MornyeDownloadStatus.tagging)
        .toList();
  }

  Future<void> _drainQueue() async {
    if (_isRunningQueue) return;
    _isRunningQueue = true;
    try {
      while (true) {
        final next = tasksNotifier.value.cast<MornyeDownloadTask?>().firstWhere(
              (t) => t?.status == MornyeDownloadStatus.queued,
              orElse: () => null,
            );
        if (next == null) break;
        await _executeTask(next);
      }
    } finally {
      _isRunningQueue = false;
    }
  }

  Future<void> _executeTask(MornyeDownloadTask task) async {
    final client = http.Client();
    _activeClients[task.id] = client;
    task.status = MornyeDownloadStatus.downloading;
    task.progress = 0.0;
    _notify();

    IOSink? sink;
    final tmpPath = '${task.destPath}.part';
    try {
      final outFile = File(task.destPath);
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }
      final req = http.Request('GET', Uri.parse(task.url))..headers.addAll(_headers);
      final resp = await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final total = resp.contentLength ?? 0;
      int received = 0;
      final tmpFile = File(tmpPath);
      sink = tmpFile.openWrite();

      await for (final chunk in resp.stream) {
        if (task.status == MornyeDownloadStatus.cancelled) {
          await sink?.close();
          sink = null;
          if (await tmpFile.exists()) await tmpFile.delete();
          return;
        }
        sink?.add(chunk);
        received += chunk.length;
        if (total > 0) {
          task.progress = (received / total).clamp(0.0, 0.99);
          _notify();
        }
      }
      await sink?.flush();
      await sink?.close();
      sink = null;
      await tmpFile.rename(task.destPath);

      task.status = MornyeDownloadStatus.tagging;
      task.progress = 0.99;
      _notify();
      await _autoTagAndFetchExtras(task);

      task.status = MornyeDownloadStatus.done;
      task.progress = 1.0;
      _notify();

      if (onTrackSaved != null) {
        await onTrackSaved!();
      }
    } catch (e) {
      if (task.status != MornyeDownloadStatus.cancelled) {
        task.status = MornyeDownloadStatus.error;
        task.errorMessage = e.toString();
        _notify();
      }
      try {
        final tf = File(tmpPath);
        if (await tf.exists()) await tf.delete();
      } catch (_) {}
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      _activeClients.remove(task.id)?.close();
    }
  }

  Future<void> _autoTagAndFetchExtras(MornyeDownloadTask task) async {
    Uint8List? coverBytes;
    if (task.artworkUrl != null && task.artworkUrl!.startsWith('http')) {
      try {
        final res = await http
            .get(Uri.parse(task.artworkUrl!), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.bodyBytes.length > 512) {
          coverBytes = res.bodyBytes;
        }
      } catch (_) {}
    }

    String syncedLrc = '';
    try {
      final uri = Uri.parse(
        'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(task.title)}&artist_name=${Uri.encodeComponent(task.artist)}',
      );
      final lrcRes = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (lrcRes.statusCode == 200) {
        final data = jsonDecode(lrcRes.body);
        if (data is Map) {
          syncedLrc =
              (data['syncedLyrics'] ?? data['plainLyrics'] ?? '').toString().trim();
        }
      }
    } catch (_) {}

    if (syncedLrc.isNotEmpty && task.destPath.contains('.')) {
      try {
        final lrcPath =
            '${task.destPath.substring(0, task.destPath.lastIndexOf('.'))}.lrc';
        await File(lrcPath).writeAsString(syncedLrc);
      } catch (_) {}
    }

    final low = task.destPath.toLowerCase();
    if (low.endsWith('.flac') || low.endsWith('.mp3')) {
      await NamiTagWriter.writeTagsToFile(
        path: task.destPath,
        title: task.title,
        artist: task.artist,
        album: task.album,
        genre: 'Music',
        year: '${DateTime.now().year}',
        lyrics: syncedLrc,
        coverBytes: coverBytes,
      );
    }
  }
}
