import 'dart:convert';
import 'package:http/http.dart' as http;

class MornyeStoreEntry {
  final String name;
  final String version;
  final String author;
  final String format;
  final String category;
  final String description;
  final String? endpointUrl;

  const MornyeStoreEntry({
    required this.name,
    required this.version,
    required this.author,
    required this.format,
    required this.category,
    required this.description,
    this.endpointUrl,
  });
}

class MornyePingResult {
  final String status;
  final int latencyMs;
  final String label;

  const MornyePingResult({
    required this.status,
    required this.latencyMs,
    required this.label,
  });
}

class NamiMornyeStore {
  static const Map<String, String> _headers = {
    'User-Agent': 'NamiMusicPlayer/2.0 (https://github.com/Piyush1625/nami)',
    'Accept': 'application/json',
  };

  static const List<MornyeStoreEntry> curatedDirectory = [
    MornyeStoreEntry(
      name: 'Qobuz Studio Hi-Res',
      version: 'v1.4.0',
      author: 'Mornye Community',
      format: '24B / 192kHz FLAC',
      category: 'Download',
      description: 'Hi-Res Qobuz catalog resolver & 24-bit FLAC metadata provider.',
    ),
    MornyeStoreEntry(
      name: 'Tidal MAX Lossless',
      version: 'v1.5.2',
      author: 'Mornye Community',
      format: '24B / 96kHz FLAC',
      category: 'Download',
      description: 'Tidal MAX stream metadata & album tracklist index.',
    ),
    MornyeStoreEntry(
      name: 'Apple Music ALAC',
      version: 'v1.6.0',
      author: 'Mornye Core',
      format: '24B ALAC / AAC',
      category: 'Metadata',
      description: 'High-resolution artwork (600x600), lossless tags & Apple catalog.',
    ),
    MornyeStoreEntry(
      name: 'LRCLIB Karaoke Sync',
      version: 'v2.2.0',
      author: 'LRCLIB',
      format: 'Synced .LRC',
      category: 'Utility',
      description: 'Timestamped synced lyrics & syllable line lookup.',
      endpointUrl: 'https://lrclib.net/api/search?q=test',
    ),
    MornyeStoreEntry(
      name: 'Deezer FLAC Bridge',
      version: 'v1.4.5',
      author: 'OpenAudio',
      format: '16B / 44.1kHz FLAC',
      category: 'Download',
      description: 'Deezer artist portraits, lossless catalog & preview resolver.',
      endpointUrl: 'https://api.deezer.com/infos',
    ),
    MornyeStoreEntry(
      name: 'MusicBrainz Picard Tags',
      version: 'v1.1.0',
      author: 'MetaBrainz',
      format: 'Vorbis / ID3v2',
      category: 'Metadata',
      description: 'Release dates, genres, track numbers & acoustic metadata.',
      endpointUrl: 'https://musicbrainz.org/ws/2/artist/?query=test&fmt=json',
    ),
  ];

  static Future<MornyePingResult> pingEndpoint(String? url) async {
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) {
      return const MornyePingResult(
        status: 'preview',
        latencyMs: 0,
        label: 'Preview Only',
      );
    }
    final sw = Stopwatch()..start();
    try {
      final res = await http
          .get(Uri.parse(trimmed), headers: _headers)
          .timeout(const Duration(seconds: 6));
      sw.stop();
      if (res.statusCode >= 200 && res.statusCode < 500) {
        return MornyePingResult(
          status: 'online',
          latencyMs: sw.elapsedMilliseconds,
          label: 'Online • ${sw.elapsedMilliseconds}ms',
        );
      }
      return MornyePingResult(
        status: 'unreachable',
        latencyMs: sw.elapsedMilliseconds,
        label: 'HTTP ${res.statusCode}',
      );
    } catch (_) {
      sw.stop();
      return const MornyePingResult(
        status: 'unreachable',
        latencyMs: 0,
        label: 'Unreachable',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAlbumTracklist({
    String? collectionId,
    required String albumTitle,
    required String artistName,
  }) async {
    try {
      Uri uri;
      if (collectionId != null && collectionId.trim().isNotEmpty) {
        uri = Uri.parse(
          'https://itunes.apple.com/lookup?id=${Uri.encodeComponent(collectionId)}&entity=song&limit=50',
        );
      } else {
        uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent("$artistName $albumTitle")}&media=music&entity=song&limit=30',
        );
      }
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['results'] as List?) ?? [];
        return list
            .whereType<Map>()
            .where((r) => (r['wrapperType'] ?? '').toString() == 'track')
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchArtistCatalog(String artistName) async {
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(artistName)}&media=music&entity=song&limit=35',
      );
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['results'] as List?) ?? [];
        return list
            .whereType<Map>()
            .where((r) => (r['wrapperType'] ?? '').toString() == 'track')
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static String renderDownloadPath({
    required String rootFolder,
    required String template,
    required String artist,
    required String album,
    required String title,
    required String trackNumber,
    required String extension,
    required bool isFullStream,
  }) {
    String clean(String s) =>
        s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
    final safeArtist = clean(artist.isEmpty ? 'Unknown Artist' : artist);
    final safeAlbum = clean(album.isEmpty ? 'Singles' : album);
    final safeTitle = clean(title.isEmpty ? 'Track' : title);
    final safeTrack = clean(trackNumber.isEmpty ? '01' : trackNumber.padLeft(2, '0'));

    var rel = template
        .replaceAll('{Artist}', safeArtist)
        .replaceAll('{Album}', safeAlbum)
        .replaceAll('{Title}', safeTitle)
        .replaceAll('{Track}', safeTrack);
    rel = rel.replaceAll(RegExp(r'^/+|/+$'), '');
    if (rel.isEmpty) rel = '$safeArtist - $safeTitle';
    final suffix = isFullStream ? '' : '_30s_preview';
    return '$rootFolder/$rel$suffix$extension';
  }

  static final Map<String, String> _bioCache = {};

  static Future<String> fetchArtistBio(String artistName, {required int localTracks, required int localAlbums}) async {
    final key = artistName.trim().toLowerCase();
    if (_bioCache.containsKey(key)) return _bioCache[key]!;
    try {
      final slug = Uri.encodeComponent(artistName.trim().replaceAll(' ', '_'));
      final res = await http
          .get(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$slug'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          final extract = (data['extract'] ?? '').toString().trim();
          if (extract.length > 40) {
            _bioCache[key] = extract;
            return extract;
          }
        }
      }
    } catch (_) {}
    final fallback =
        '$artistName has $localTracks track(s) across $localAlbums album(s) in your Nami lossless library.';
    _bioCache[key] = fallback;
    return fallback;
  }
}
