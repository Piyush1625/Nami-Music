import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class NamiReleaseInfo {
  final String tagName;
  final String title;
  final String changelog;
  final String? apkUrl;
  final String htmlUrl;
  final String publishedAt;

  const NamiReleaseInfo({
    required this.tagName,
    required this.title,
    required this.changelog,
    required this.htmlUrl,
    required this.publishedAt,
    this.apkUrl,
  });
}

class NamiGitHubUpdater {
  static const Map<String, String> _headers = {
    'User-Agent': 'NamiMusicPlayer/2.0 (https://github.com/Piyush1625/nami)',
    'Accept': 'application/vnd.github+json',
  };

  static const List<String> _repoSlugs = [
    'Piyush1625/nami',
    'Piyush1625/Nami-Music',
  ];

  static Future<NamiReleaseInfo?> checkLatestRelease() async {
    for (final slug in _repoSlugs) {
      try {
        final res = await http
            .get(Uri.parse('https://api.github.com/repos/$slug/releases/latest'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map) {
            String? apkUrl;
            final assets = data['assets'];
            if (assets is List) {
              for (final a in assets) {
                if (a is Map) {
                  final name = (a['name'] ?? '').toString().toLowerCase();
                  final dl = (a['browser_download_url'] ?? '').toString();
                  if (name.endsWith('.apk') && dl.startsWith('http')) {
                    apkUrl = dl;
                    if (name.contains('arm64')) break;
                  }
                }
              }
            }
            return NamiReleaseInfo(
              tagName: (data['tag_name'] ?? 'v2.0.0').toString(),
              title: (data['name'] ?? data['tag_name'] ?? 'Latest Release').toString(),
              changelog: (data['body'] ?? 'Signed ARM64 release build.').toString(),
              apkUrl: apkUrl,
              htmlUrl: (data['html_url'] ?? 'https://github.com/$slug/releases').toString(),
              publishedAt: (data['published_at'] ?? '').toString(),
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<String?> downloadApkToDownloads(
    String apkUrl,
    String tagName, {
    void Function(double progress)? onProgress,
  }) async {
    final safeTag = tagName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final destPath = '/storage/emulated/0/Download/nami_$safeTag.apk';
    final tmpPath = '$destPath.part';
    final client = http.Client();
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(apkUrl))..headers.addAll(_headers);
      final resp = await client.send(req).timeout(const Duration(seconds: 40));
      if (resp.statusCode != 200) return null;
      final total = resp.contentLength ?? 0;
      int got = 0;
      final tmp = File(tmpPath);
      sink = tmp.openWrite();
      await for (final chunk in resp.stream) {
        sink?.add(chunk);
        got += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress((got / total).clamp(0.0, 1.0));
        }
      }
      await sink?.flush();
      await sink?.close();
      sink = null;
      await tmp.rename(destPath);
      return destPath;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        final tf = File(tmpPath);
        if (await tf.exists()) await tf.delete();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }
}
