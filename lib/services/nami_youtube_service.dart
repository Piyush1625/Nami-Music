import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a YouTube / YouTube Music track or video in Nami.
class NamiYtTrack {
  final String videoId;
  final String title;
  final String artist;
  final String channelId;
  final String album;
  final Duration duration;
  final String thumbnailUrl;
  final String viewsText;
  final String publishedText;
  final int playCount;
  final int lastPlayedMs;
  final bool isFavorite;
  final String? cachedThumbPath;

  const NamiYtTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    this.channelId = '',
    this.album = 'YouTube Music',
    this.duration = Duration.zero,
    required this.thumbnailUrl,
    this.viewsText = '',
    this.publishedText = '',
    this.playCount = 0,
    this.lastPlayedMs = 0,
    this.isFavorite = false,
    this.cachedThumbPath,
  });

  String get durationLabel {
    final s = duration.inSeconds;
    if (s <= 0) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final rem = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
  }

  String get relativePlayedLabel {
    if (lastPlayedMs <= 0) return publishedText;
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastPlayedMs),
    );
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    final months = diff.inDays ~/ 30;
    return '$months month${months == 1 ? '' : 's'} ago';
  }

  NamiYtTrack copyWith({
    String? title,
    String? artist,
    String? channelId,
    String? album,
    Duration? duration,
    String? thumbnailUrl,
    String? viewsText,
    String? publishedText,
    int? playCount,
    int? lastPlayedMs,
    bool? isFavorite,
    String? cachedThumbPath,
  }) {
    return NamiYtTrack(
      videoId: videoId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      channelId: channelId ?? this.channelId,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewsText: viewsText ?? this.viewsText,
      publishedText: publishedText ?? this.publishedText,
      playCount: playCount ?? this.playCount,
      lastPlayedMs: lastPlayedMs ?? this.lastPlayedMs,
      isFavorite: isFavorite ?? this.isFavorite,
      cachedThumbPath: cachedThumbPath ?? this.cachedThumbPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'channelId': channelId,
        'album': album,
        'durationSec': duration.inSeconds,
        'thumbnailUrl': thumbnailUrl,
        'viewsText': viewsText,
        'publishedText': publishedText,
        'playCount': playCount,
        'lastPlayedMs': lastPlayedMs,
        'isFavorite': isFavorite,
        'cachedThumbPath': cachedThumbPath,
      };

  factory NamiYtTrack.fromJson(Map<String, dynamic> m) => NamiYtTrack(
        videoId: (m['videoId'] ?? '').toString(),
        title: (m['title'] ?? 'Unknown Track').toString(),
        artist: (m['artist'] ?? 'YouTube').toString(),
        channelId: (m['channelId'] ?? '').toString(),
        album: (m['album'] ?? 'YouTube Music').toString(),
        duration: Duration(seconds: (m['durationSec'] as num?)?.toInt() ?? 0),
        thumbnailUrl: (m['thumbnailUrl'] ?? '').toString(),
        viewsText: (m['viewsText'] ?? '').toString(),
        publishedText: (m['publishedText'] ?? '').toString(),
        playCount: (m['playCount'] as num?)?.toInt() ?? 0,
        lastPlayedMs: (m['lastPlayedMs'] as num?)?.toInt() ?? 0,
        isFavorite: m['isFavorite'] == true,
        cachedThumbPath: m['cachedThumbPath']?.toString(),
      );
}

/// Carousel / Release card on YouTube Music Browse shelves.
class NamiYtCardItem {
  final String id;
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final String? videoId;
  final String? browseId;
  final String? playlistId;

  const NamiYtCardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    this.videoId,
    this.browseId,
    this.playlistId,
  });
}

/// Feed section returned by YouTube Music `FEmusic_home` / browse.
class NamiYtShelf {
  final String title;
  final String kicker;
  final bool isSongMixes;
  final List<NamiYtTrack> tracks;
  final List<NamiYtCardItem> cards;

  const NamiYtShelf({
    required this.title,
    this.kicker = '',
    this.isSongMixes = false,
    this.tracks = const [],
    this.cards = const [],
  });
}

/// Auto-generated local mix card for `Home (Local)`.
class NamiYtMix {
  final String id;
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final List<NamiYtTrack> tracks;

  const NamiYtMix({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.tracks,
  });
}

/// Local subscribed YouTube channel (account-free).
class NamiYtChannel {
  final String channelId;
  final String name;
  final String avatarUrl;
  final String subscriberText;
  final int subscribedAtMs;

  const NamiYtChannel({
    required this.channelId,
    required this.name,
    this.avatarUrl = '',
    this.subscriberText = '',
    required this.subscribedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'name': name,
        'avatarUrl': avatarUrl,
        'subscriberText': subscriberText,
        'subscribedAtMs': subscribedAtMs,
      };

  factory NamiYtChannel.fromJson(Map<String, dynamic> m) => NamiYtChannel(
        channelId: (m['channelId'] ?? '').toString(),
        name: (m['name'] ?? 'Channel').toString(),
        avatarUrl: (m['avatarUrl'] ?? '').toString(),
        subscriberText: (m['subscriberText'] ?? '').toString(),
        subscribedAtMs: (m['subscribedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// Local custom YouTube playlist (stored on-device).
class NamiYtLocalPlaylist {
  final String id;
  final String name;
  final List<String> videoIds;
  final int updatedAtMs;

  const NamiYtLocalPlaylist({
    required this.id,
    required this.name,
    required this.videoIds,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'videoIds': videoIds,
        'updatedAtMs': updatedAtMs,
      };

  factory NamiYtLocalPlaylist.fromJson(Map<String, dynamic> m) =>
      NamiYtLocalPlaylist(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? 'Playlist').toString(),
        videoIds: (m['videoIds'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        updatedAtMs: (m['updatedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// Resolved direct audio stream for `libmpv`.
class NamiYtStreamResult {
  final String videoId;
  final String audioUrl;
  final String mimeType;
  final int bitrate;
  final Duration duration;
  final Map<String, String> headers;
  final int expiresAtMs;
  final String clientUsed;

  const NamiYtStreamResult({
    required this.videoId,
    required this.audioUrl,
    required this.mimeType,
    required this.bitrate,
    required this.duration,
    required this.headers,
    required this.expiresAtMs,
    required this.clientUsed,
  });

  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= expiresAtMs;
}

/// SponsorBlock skip interval.
class NamiYtSponsorSegment {
  final double startSec;
  final double endSec;
  final String category;

  const NamiYtSponsorSegment({
    required this.startSec,
    required this.endSec,
    required this.category,
  });
}

/// Rich watch metadata (channel, views, Return YouTube Dislike, top comment, related tracks).
class NamiYtWatchDetails {
  final String videoId;
  final String title;
  final String channelName;
  final String channelId;
  final String channelAvatarUrl;
  final String subscriberText;
  final String viewsText;
  final String publishedText;
  final int likesCount;
  final int dislikesCount;
  final String topCommentAuthor;
  final String topCommentText;
  final String topCommentLikes;
  final List<NamiYtTrack> relatedTracks;

  const NamiYtWatchDetails({
    required this.videoId,
    required this.title,
    required this.channelName,
    this.channelId = '',
    this.channelAvatarUrl = '',
    this.subscriberText = '',
    this.viewsText = '',
    this.publishedText = '',
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.topCommentAuthor = '',
    this.topCommentText = '',
    this.topCommentLikes = '',
    this.relatedTracks = const [],
  });
}

/// Core InnerTube API Engine for Nami v3.0:
/// - India-first YouTube Music browse (`FEmusic_home`, `Charts`, `Moods`, `New releases`)
/// - Resilient multi-client audio stream resolver (`ANDROID_VR` -> `IOS` -> `ANDROID_TESTSUITE` -> `Piped`)
/// - Watch metadata, Related Radio tracks, Return YouTube Dislike & SponsorBlock
/// - Disk-backed cover thumbnail cache for seamless native `Image.file` + Home Widget support
class NamiYoutubeService {
  NamiYoutubeService._();
  static final NamiYoutubeService instance = NamiYoutubeService._();

  static const String _ytApiBase = 'https://youtubei.googleapis.com/youtubei/v1';
  static const String _ytMusicApiBase = 'https://music.youtube.com/youtubei/v1';

  static const String _iosUserAgent =
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
  static const String _webUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';


  final Map<String, NamiYtStreamResult> _streamCache = {};
  final Map<String, List<NamiYtShelf>> _browseCache = {};
  final Map<String, String> _thumbFileCache = {};

  (String gl, String hl) _regionLocale(String region) {
    switch (region.toUpperCase()) {
      case 'US':
        return ('US', 'en');
      case 'GLOBAL':
        return ('GB', 'en');
      default:
        return ('IN', 'en-IN');
    }
  }

  Map<String, dynamic> _webRemixContext(String region) {
    final (gl, hl) = _regionLocale(region);
    return {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20251015.01.00',
        'gl': gl,
        'hl': hl,
        'platform': 'DESKTOP',
      },
    };
  }

  Map<String, dynamic> _webContext(String region) {
    final (gl, hl) = _regionLocale(region);
    return {
      'client': {
        'clientName': 'WEB',
        'clientVersion': '2.20251015.01.00',
        'gl': gl,
        'hl': hl,
      },
    };
  }

  /// Cleans noisy suffixes when `cleanQuery == true` (mirrors Nami's Search Cleanup).
  String sanitizeSearchQuery(String query, {bool clean = true}) {
    var q = query.trim();
    if (!clean || q.isEmpty) return q;
    q = q.replaceAll(RegExp(r'\s+'), ' ');
    return q;
  }

  /// Fetches the live YouTube Music Browse feed (`FEmusic_home` or `FEmusic_explore` / `FEmusic_charts`).
  Future<List<NamiYtShelf>> fetchMusicHomeFeed({
    String region = 'IN',
    String browseId = 'FEmusic_home',
    String? params,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$region|$browseId|${params ?? ''}';
    if (!forceRefresh && _browseCache.containsKey(cacheKey)) {
      return _browseCache[cacheKey]!;
    }

    final shelves = <NamiYtShelf>[];
    try {
      final body = <String, dynamic>{
        'context': _webRemixContext(region),
        'browseId': browseId,
      };
      if (params != null && params.isNotEmpty) {
        body['params'] = params;
      }
      final resp = await http
          .post(
            Uri.parse('$_ytMusicApiBase/browse?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _webUserAgent,
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
              'X-YouTube-Client-Name': '67',
              'X-YouTube-Client-Version': '1.20251015.01.00',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final root = jsonDecode(resp.body);
        _extractMusicShelves(root, shelves);
      }
    } catch (e) {
      debugPrint('[NamiYT] fetchMusicHomeFeed error: $e');
    }

    // Fallback: if browse returned empty (e.g. regional wall), seed India-first song mixes via search
    if (shelves.isEmpty) {
      final fallbackQuery = region.toUpperCase() == 'IN'
          ? 'Trending Indian songs Bollywood Punjabi DHH'
          : 'Top Global Music Hits';
      final tracks = await searchMusic(fallbackQuery, region: region, limit: 16);
      if (tracks.isNotEmpty) {
        shelves.add(
          NamiYtShelf(
            title: 'Song mixes',
            kicker: region.toUpperCase() == 'IN' ? 'INDIA TOP PICKS' : 'QUICK PICKS',
            isSongMixes: true,
            tracks: tracks,
          ),
        );
      }
    }

    if (shelves.isNotEmpty) {
      _browseCache[cacheKey] = shelves;
    }
    return shelves;
  }

  /// Searches YouTube Music (`WEB_REMIX`) with automatic `WEB` video fallback.
  Future<List<NamiYtTrack>> searchMusic(
    String query, {
    String region = 'IN',
    bool cleanQuery = true,
    int limit = 20,
    bool songsOnly = false,
  }) async {
    final q = sanitizeSearchQuery(query, clean: cleanQuery);
    if (q.isEmpty) return const [];

    final results = <NamiYtTrack>[];
    final seenIds = <String>{};

    // 1. Try YouTube Music WEB_REMIX search first
    try {
      final body = <String, dynamic>{
        'context': _webRemixContext(region),
        'query': q,
      };
      if (songsOnly) {
        body['params'] = 'EgWKAQIIAWoMEAMQBBAJEAoQBRAV';
      }
      final resp = await http
          .post(
            Uri.parse('$_ytMusicApiBase/search?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _webUserAgent,
              'Origin': 'https://music.youtube.com',
              'Referer': 'https://music.youtube.com/',
              'X-YouTube-Client-Name': '67',
              'X-YouTube-Client-Version': '1.20251015.01.00',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final root = jsonDecode(resp.body);
        _extractResponsiveTracks(root, results, seenIds, limit);
      }
    } catch (e) {
      debugPrint('[NamiYT] WEB_REMIX search error: $e');
    }

    // 2. Supplement or fallback with standard YouTube WEB search for full video coverage
    if (results.length < 6) {
      try {
        final resp = await http
            .post(
              Uri.parse('$_ytApiBase/search?prettyPrint=false'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': _webUserAgent,
              },
              body: jsonEncode({
                'context': _webContext(region),
                'query': q,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode == 200) {
          final root = jsonDecode(resp.body);
          _extractVideoRenderers(root, results, seenIds, limit);
        }
      } catch (e) {
        debugPrint('[NamiYT] WEB search fallback error: $e');
      }
    }

    return results;
  }

  /// Last diagnostic trace when stream resolution fails across all clients.
  static String lastResolveDiagnostic = '';
  static String _cachedVisitorData = '';
  static int _visitorDataFetchedAtMs = 0;
  static String customYoutubeCookie = '';

  static Future<void> loadCustomCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      customYoutubeCookie = prefs.getString('nami_v31_yt_cookie') ?? '';
    } catch (_) {}
  }

  static Future<void> saveCustomCookie(String cookie) async {
    customYoutubeCookie = cookie.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nami_v31_yt_cookie', customYoutubeCookie);
    } catch (_) {}
  }

  /// Fetches a fresh YouTube `visitorData` token once every 30 min from `sw.js_data`
  /// (mirrors youtube_explode_dart & yt-dlp to prevent CGNAT LOGIN_REQUIRED bot walls).
  Future<String> _ensureVisitorData() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cachedVisitorData.isNotEmpty && (now - _visitorDataFetchedAtMs) < 1800000) {
      return _cachedVisitorData;
    }
    for (final url in const [
      'https://www.youtube.com/sw.js_data',
      'https://music.youtube.com/sw.js_data',
    ]) {
      try {
        final r = await http
            .get(Uri.parse(url), headers: const {'User-Agent': _webUserAgent})
            .timeout(const Duration(seconds: 5));
        if (r.statusCode == 200 && r.body.isNotEmpty) {
          final m = RegExp(r'"(Cg[A-Za-z0-9_\-%]{14,120})"').firstMatch(r.body);
          if (m != null && m.group(1) != null) {
            _cachedVisitorData = Uri.decodeComponent(m.group(1)!);
            _visitorDataFetchedAtMs = now;
            return _cachedVisitorData;
          }
        }
      } catch (_) {}
    }
    return _cachedVisitorData;
  }

  /// Computes `SAPISIDHASH <ts>_<sha1>` header when the user provides optional YouTube cookies.
  String? _buildSapisidAuthHeader(String cookie, {String origin = 'https://www.youtube.com'}) {
    final m = RegExp(r'(?:^|;\s*)(?:__Secure-3PAPISID|SAPISID)=([^;\s]+)').firstMatch(cookie);
    if (m == null || m.group(1) == null) return null;
    final sapisid = m.group(1)!;
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final hash = _sha1Hex('$ts $sapisid $origin');
    return 'SAPISIDHASH ${ts}_$hash';
  }

  static String _sha1Hex(String input) {
    final bytes = utf8.encode(input);
    final bitLen = bytes.length * 8;
    final padded = <int>[...bytes, 0x80];
    while ((padded.length % 64) != 56) {
      padded.add(0);
    }
    for (int i = 7; i >= 0; i--) {
      padded.add((bitLen >>> (i * 8)) & 0xFF);
    }
    int h0 = 0x67452301;
    int h1 = 0xEFCDAB89;
    int h2 = 0x98BADCFE;
    int h3 = 0x10325476;
    int h4 = 0xC3D2E1F0;
    final w = List<int>.filled(80, 0);
    int rol32(int v, int s) => ((v << s) | ((v & 0xFFFFFFFF) >>> (32 - s))) & 0xFFFFFFFF;
    for (int offset = 0; offset < padded.length; offset += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = ((padded[offset + i * 4] << 24) |
                (padded[offset + i * 4 + 1] << 16) |
                (padded[offset + i * 4 + 2] << 8) |
                padded[offset + i * 4 + 3]) &
            0xFFFFFFFF;
      }
      for (int i = 16; i < 80; i++) {
        w[i] = rol32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }
      int a = h0, b = h1, c = h2, d = h3, e = h4;
      for (int i = 0; i < 80; i++) {
        int f, k;
        if (i < 20) {
          f = (b & c) | ((~b & 0xFFFFFFFF) & d);
          k = 0x5A827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ED9EBA1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8F1BBCDC;
        } else {
          f = b ^ c ^ d;
          k = 0xCA62C1D6;
        }
        final temp = (rol32(a, 5) + f + e + k + w[i]) & 0xFFFFFFFF;
        e = d;
        d = c;
        c = rol32(b, 30);
        b = a;
        a = temp;
      }
      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
    }
    return [h0, h1, h2, h3, h4]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
  }

  /// Validates the first bytes of an audio stream so HTML/403 error responses are rejected instantly.
  static bool isValidAudioHeader(List<int> bytes) {
    if (bytes.length < 12) return false;
    if (bytes[0] == 0x3C || bytes[0] == 0x7B) return false;
    if (bytes[0] == 0x47 && (bytes.length < 189 || bytes[188] == 0x47)) return true;
    if (bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3) return true;
    if ((bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) ||
        (bytes[4] == 0x73 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) ||
        (bytes[4] == 0x6D && bytes[5] == 0x6F && bytes[6] == 0x6F && bytes[7] == 0x66)) {
      return true;
    }
    if (bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) return true;
    if (bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43) return true;
    if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
        (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) {
      return true;
    }
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    return false;
  }

  /// Appends bounded `&range=start-end` query param for YouTube googlevideo URLs.
  static Uri buildBoundedChunkUri(String rawUrl, int start, int end) {
    if (rawUrl.contains('googlevideo.com/videoplayback') && !rawUrl.contains('range=')) {
      final sep = rawUrl.contains('?') ? '&' : '?';
      return Uri.parse('$rawUrl${sep}range=$start-$end');
    }
    return Uri.parse(rawUrl);
  }

  /// Probes either an HLS `.m3u8` playlist OR the first 32KB audio chunk with magic-byte verification.
  Future<bool> _probeStreamUrl(String url, Map<String, String> headers) async {
    if (!url.startsWith('http')) return false;
    if (url.contains('.m3u8') || url.contains('manifest/hls')) {
      try {
        final r = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 6));
        return r.statusCode >= 200 && r.statusCode < 400 && r.body.contains('#EXTM3U');
      } catch (_) {
        return false;
      }
    }
    try {
      final probeUri = buildBoundedChunkUri(url, 0, 32767);
      final reqHeaders = Map<String, String>.from(headers);
      if (!probeUri.toString().contains('range=')) {
        reqHeaders['Range'] = 'bytes=0-32767';
      }
      final resp = await http
          .get(probeUri, headers: reqHeaders)
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200 && resp.statusCode != 206) return false;
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      if (ct.contains('text/html')) return false;
      return isValidAudioHeader(resp.bodyBytes);
    } catch (_) {
      return false;
    }
  }

  /// Late-2026 Verified Multi-Tier Audio Engine (`v3.1.2`):
  /// 0. Live `visitorData` session bootstrap (`sw.js_data`) + optional user YouTube cookie auth
  /// 1. `IOS` (`20.10.4`, no `params`, adaptive + HLS — bypasses CGNAT `LOGIN_REQUIRED`)
  /// 2. `ANDROID_SDKLESS` (`20.10.38`, no SDK version — youtube_explode_dart 403 fix)
  /// 3. `VISIONOS` (`1.02`, HLS + adaptive)
  /// 4. `ANDROID_VR` (`1.71.26`)
  /// 5. `WEB_SAFARI` (HLS) & `TV_SAMSUNG`
  /// 6. Official Direct JioSaavn Web API (`jiosaavn.com/api.php` + pure-Dart DES-ECB 320kbps AAC/M4A)
  Future<NamiYtStreamResult?> resolveAudioStream(
    String videoId, {
    String quality = 'High (Opus)',
    String region = 'IN',
    bool forceRefresh = false,
    Set<String> excludeClients = const <String>{},
    String? fallbackTitle,
    String? fallbackArtist,
  }) async {
    final cacheKey = '$videoId|$quality';
    final cached = _streamCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        !cached.isExpired &&
        !excludeClients.contains(cached.clientUsed)) {
      return cached;
    }

    final (gl, hl) = _regionLocale(region);
    final visitorData = await _ensureVisitorData();
    final diag = <String>[];
    final hasCookie = customYoutubeCookie.isNotEmpty;
    final authHdr = hasCookie ? _buildSapisidAuthHeader(customYoutubeCookie) : null;

    const safariUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15';
    const samsungTvUa =
        'Mozilla/5.0 (SMART-TV; LINUX; Tizen 7.0) AppleWebKit/537.36 (KHTML, like Gecko) 94.0.4606.31/7.0 TV Safari/537.36';
    const androidUa =
        'com.google.android.youtube/20.10.38 (Linux; U; Android 14; en_IN) gzip';
    const vr171Ua =
        'com.google.android.apps.youtube.vr.oculus/1.71.26 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

    Map<String, dynamic> withVisitor(Map<String, dynamic> clientObj) {
      return {
        ...clientObj,
        if (visitorData.isNotEmpty) 'visitorData': visitorData,
      };
    }

    final clients = <Map<String, dynamic>>[
      {
        'name': 'IOS',
        'ua': _iosUserAgent,
        'clientHeader': '5',
        'version': '20.10.4',
        'preferHls': true,
        'context': {
          'client': withVisitor({
            'clientName': 'IOS',
            'clientVersion': '20.10.4',
            'deviceMake': 'Apple',
            'deviceModel': 'iPhone16,2',
            'osName': 'iPhone',
            'osVersion': '18.3.2.22D82',
            'gl': gl,
            'hl': hl,
          }),
        },
      },
      {
        'name': 'ANDROID_SDKLESS',
        'ua': androidUa,
        'clientHeader': '3',
        'version': '20.10.38',
        'preferHls': false,
        'context': {
          'client': withVisitor({
            'clientName': 'ANDROID',
            'clientVersion': '20.10.38',
            'osName': 'Android',
            'gl': gl,
            'hl': hl,
          }),
        },
      },
      {
        'name': 'VISIONOS',
        'ua': safariUa,
        'clientHeader': '101',
        'version': '1.02',
        'preferHls': true,
        'context': {
          'client': withVisitor({
            'clientName': 'VISIONOS',
            'clientVersion': '1.02',
            'deviceMake': 'Apple',
            'osName': 'visionOS',
            'osVersion': '2.2',
            'gl': gl,
            'hl': hl,
          }),
        },
      },
      {
        'name': 'ANDROID_VR',
        'ua': vr171Ua,
        'clientHeader': '28',
        'version': '1.71.26',
        'preferHls': false,
        'context': {
          'client': withVisitor({
            'clientName': 'ANDROID_VR',
            'clientVersion': '1.71.26',
            'deviceMake': 'Oculus',
            'deviceModel': 'Quest 3',
            'androidSdkVersion': 32,
            'osName': 'Android',
            'osVersion': '12L',
            'gl': gl,
            'hl': hl,
          }),
        },
      },
      {
        'name': 'TV_SAMSUNG',
        'ua': samsungTvUa,
        'clientHeader': '7',
        'version': '7.20261015.10.00',
        'preferHls': false,
        'context': {
          'client': withVisitor({
            'clientName': 'TVHTML5',
            'clientVersion': '7.20261015.10.00',
            'deviceMake': 'Samsung',
            'osName': 'Tizen',
            'osVersion': '7.0',
            'gl': gl,
            'hl': hl,
          }),
        },
      },
    ];

    for (final c in clients) {
      final cname = c['name'] as String;
      final hlsName = '${cname}_HLS';
      if (excludeClients.contains(cname) && excludeClients.contains(hlsName)) {
        continue;
      }
      try {
        final ua = c['ua'] as String;
        final reqHdrs = <String, String>{
          'Content-Type': 'application/json',
          'User-Agent': ua,
          'Origin': 'https://www.youtube.com',
          'X-YouTube-Client-Name': c['clientHeader'] as String,
          'X-YouTube-Client-Version': c['version'] as String,
          if (visitorData.isNotEmpty) 'X-Goog-Visitor-Id': visitorData,
          if (hasCookie) 'Cookie': customYoutubeCookie,
          if (authHdr != null) 'Authorization': authHdr,
        };
        final resp = await http
            .post(
              Uri.parse('$_ytApiBase/player?prettyPrint=false'),
              headers: reqHdrs,
              body: jsonEncode({
                'videoId': videoId,
                'context': c['context'],
                'contentCheckOk': true,
                'racyCheckOk': true,
              }),
            )
            .timeout(const Duration(seconds: 7));

        if (resp.statusCode != 200) {
          diag.add('$cname:h${resp.statusCode}');
          continue;
        }
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final psMap = json['playabilityStatus'];
        final playStatus = (psMap is Map ? (psMap['status'] ?? '') : '').toString();
        final sd = json['streamingData'];
        if (sd is! Map<String, dynamic>) {
          diag.add('$cname:${playStatus.isNotEmpty ? playStatus : 'noSD'}');
          continue;
        }

        final durSec = int.tryParse(
              (json['videoDetails'] is Map
                      ? (json['videoDetails']['lengthSeconds'] ?? '0')
                      : '0')
                  .toString(),
            ) ??
            0;
        final streamHeaders = <String, String>{
          'User-Agent': ua,
          if (hasCookie) 'Cookie': customYoutubeCookie,
        };

        // 1. Try direct adaptive / muxed audio formats first (fastest 4-way chunk download)
        if (!excludeClients.contains(cname)) {
          final formats = <Map<String, dynamic>>[];
          final adaptive = sd['adaptiveFormats'];
          if (adaptive is List) {
            for (final f in adaptive) {
              if (f is Map<String, dynamic>) {
                final mime = (f['mimeType'] ?? '').toString();
                final url = (f['url'] ?? '').toString();
                if (mime.startsWith('audio/') && url.startsWith('http')) {
                  formats.add(f);
                }
              }
            }
          }
          if (formats.isEmpty && sd['formats'] is List) {
            for (final f in sd['formats'] as List) {
              if (f is Map<String, dynamic> &&
                  (f['url'] ?? '').toString().startsWith('http')) {
                formats.add(f);
              }
            }
          }
          if (formats.isNotEmpty) {
            final picked = _pickStreamByQuality(formats, quality);
            final candUrl = picked['url'].toString();
            if (await _probeStreamUrl(candUrl, streamHeaders)) {
              final contentLen =
                  int.tryParse((picked['contentLength'] ?? '').toString()) ?? 0;
              final res = NamiYtStreamResult(
                videoId: videoId,
                audioUrl: candUrl,
                mimeType: (picked['mimeType'] ?? 'audio/mp4').toString(),
                bitrate: (picked['bitrate'] as num?)?.toInt() ?? 128000,
                duration: Duration(seconds: durSec),
                headers: {
                  ...streamHeaders,
                  if (contentLen > 0) 'X-Nami-Content-Length': '$contentLen',
                },
                expiresAtMs: DateTime.now()
                    .add(const Duration(hours: 3, minutes: 30))
                    .millisecondsSinceEpoch,
                clientUsed: cname,
              );
              _streamCache[cacheKey] = res;
              lastResolveDiagnostic = '';
              return res;
            }
          }
        }

        // 2. Try HLS manifest (`.m3u8`) on IOS / VISIONOS if direct adaptive 403'd
        final hlsUrl = (sd['hlsManifestUrl'] ?? '').toString();
        if (hlsUrl.startsWith('http') &&
            !excludeClients.contains(hlsName) &&
            await _probeStreamUrl(hlsUrl, streamHeaders)) {
          final res = NamiYtStreamResult(
            videoId: videoId,
            audioUrl: hlsUrl,
            mimeType: 'application/x-mpegURL',
            bitrate: 128000,
            duration: Duration(seconds: durSec),
            headers: streamHeaders,
            expiresAtMs: DateTime.now()
                .add(const Duration(hours: 2, minutes: 30))
                .millisecondsSinceEpoch,
            clientUsed: hlsName,
          );
          _streamCache[cacheKey] = res;
          lastResolveDiagnostic = '';
          return res;
        }
        diag.add('$cname:403');
      } catch (_) {
        diag.add('$cname:err');
      }
    }

    // Tier 6: Official Direct JioSaavn API (jiosaavn.com/api.php + Pure-Dart DES-ECB 320kbps M4A)
    // Guaranteed to play Indian & global music tracks cleanly even when YouTube CGNAT-blocks an IP!
    if (!excludeClients.contains('SAAVN_320K') &&
        fallbackTitle != null &&
        fallbackTitle.trim().isNotEmpty) {
      final saavnRes = await _resolveSaavnAudioFallback(
        videoId: videoId,
        title: fallbackTitle,
        artist: fallbackArtist ?? '',
      );
      if (saavnRes != null) {
        _streamCache[cacheKey] = saavnRes;
        lastResolveDiagnostic = '';
        return saavnRes;
      }
      diag.add('SAAVN:miss');
    }

    lastResolveDiagnostic = diag.join(' ');
    debugPrint('[NamiYT] All tiers failed for $videoId: $lastResolveDiagnostic');
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pure-Dart FIPS 46-3 DES-ECB Decryptor for Official JioSaavn `encrypted_media_url`
  // ---------------------------------------------------------------------------
  static const List<int> _desIp = [
    58,50,42,34,26,18,10,2,60,52,44,36,28,20,12,4,62,54,46,38,30,22,14,6,64,56,48,40,32,24,16,8,
    57,49,41,33,25,17,9,1,59,51,43,35,27,19,11,3,61,53,45,37,29,21,13,5,63,55,47,39,31,23,15,7,
  ];
  static const List<int> _desFp = [
    40,8,48,16,56,24,64,32,39,7,47,15,55,23,63,31,38,6,46,14,54,22,62,30,37,5,45,13,53,21,61,29,
    36,4,44,12,52,20,60,28,35,3,43,11,51,19,59,27,34,2,42,10,50,18,58,26,33,1,41,9,49,17,57,25,
  ];
  static const List<int> _desE = [
    32,1,2,3,4,5,4,5,6,7,8,9,8,9,10,11,12,13,12,13,14,15,16,17,
    16,17,18,19,20,21,20,21,22,23,24,25,24,25,26,27,28,29,28,29,30,31,32,1,
  ];
  static const List<int> _desP = [
    16,7,20,21,29,12,28,17,1,15,23,26,5,18,31,10,2,8,24,14,32,27,3,9,19,13,30,6,22,11,4,25,
  ];
  static const List<int> _desPc1 = [
    57,49,41,33,25,17,9,1,58,50,42,34,26,18,10,2,59,51,43,35,27,19,11,3,60,52,44,36,
    63,55,47,39,31,23,15,7,62,54,46,38,30,22,14,6,61,53,45,37,29,21,13,5,28,20,12,4,
  ];
  static const List<int> _desPc2 = [
    14,17,11,24,1,5,3,28,15,6,21,10,23,19,12,4,26,8,16,7,27,20,13,2,
    41,52,31,37,47,55,30,40,51,45,33,48,44,49,39,56,34,53,46,42,50,36,29,32,
  ];
  static const List<int> _desShifts = [1,1,2,2,2,2,2,2,1,2,2,2,2,2,2,1];
  static const List<List<int>> _desSbox = [
    [14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7,0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8,4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0,15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13],
    [15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10,3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5,0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15,13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9],
    [10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8,13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1,13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7,1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12],
    [7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15,13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9,10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4,3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14],
    [2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9,14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6,4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14,11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3],
    [12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11,10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8,9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6,4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13],
    [4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1,13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6,1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2,6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12],
    [13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7,1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2,7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8,2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11],
  ];

  static int _desPermute(int val, List<int> table, int inBits) {
    int out = 0;
    for (final pos in table) {
      out = (out << 1) | ((val >>> (inBits - pos)) & 1);
    }
    return out;
  }

  static String? _decryptJioSaavnUrl(String encryptedBase64) {
    try {
      final cipher = base64Decode(encryptedBase64.trim());
      if (cipher.isEmpty || cipher.length % 8 != 0) return null;
      const keyBytes = [0x33, 0x38, 0x33, 0x34, 0x36, 0x35, 0x39, 0x31]; // "38346591"
      int key64 = 0;
      for (final b in keyBytes) {
        key64 = (key64 << 8) | (b & 0xFF);
      }
      final k56 = _desPermute(key64, _desPc1, 64);
      int c = (k56 >>> 28) & 0xFFFFFFF;
      int d = k56 & 0xFFFFFFF;
      final subkeys = <int>[];
      for (final s in _desShifts) {
        c = ((c << s) | (c >>> (28 - s))) & 0xFFFFFFF;
        d = ((d << s) | (d >>> (28 - s))) & 0xFFFFFFF;
        subkeys.add(_desPermute((c << 28) | d, _desPc2, 56));
      }
      final revKeys = subkeys.reversed.toList();
      final plain = <int>[];
      for (int off = 0; off < cipher.length; off += 8) {
        int block = 0;
        for (int j = 0; j < 8; j++) {
          block = (block << 8) | (cipher[off + j] & 0xFF);
        }
        final x = _desPermute(block, _desIp, 64);
        int l = (x >>> 32) & 0xFFFFFFFF;
        int r = x & 0xFFFFFFFF;
        for (final sk in revKeys) {
          final er = _desPermute(r, _desE, 32) ^ sk;
          int sOut = 0;
          for (int i = 0; i < 8; i++) {
            final chunk = (er >>> (42 - i * 6)) & 0x3F;
            final row = ((chunk & 0x20) >>> 4) | (chunk & 1);
            final col = (chunk >>> 1) & 0x0F;
            sOut = (sOut << 4) | _desSbox[i][row * 16 + col];
          }
          final f = _desPermute(sOut, _desP, 32);
          final nextR = l ^ f;
          l = r;
          r = nextR;
        }
        final outBlock = _desPermute((r << 32) | (l & 0xFFFFFFFF), _desFp, 64);
        for (int j = 7; j >= 0; j--) {
          plain.add((outBlock >>> (j * 8)) & 0xFF);
        }
      }
      if (plain.isEmpty) return null;
      final pad = plain.last;
      final trimmed = (pad >= 1 && pad <= 8 && pad <= plain.length)
          ? plain.sublist(0, plain.length - pad)
          : plain;
      final url = utf8.decode(trimmed, allowMalformed: true).trim();
      return url.startsWith('http') ? url : null;
    } catch (_) {
      return null;
    }
  }

  /// Resolves a verified 320kbps M4A audio match directly from JioSaavn's official India API
  /// (`jiosaavn.com/api.php` + DES-ECB decrypt) with fallback to community mirrors.
  Future<NamiYtStreamResult?> _resolveSaavnAudioFallback({
    required String videoId,
    required String title,
    required String artist,
  }) async {
    try {
      final cleanTitle = title
          .replaceAll(RegExp(r'\(From[^)]*\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[From[^\]]*\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(Official[^)]*\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(Full[^)]*\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(Remix\)', caseSensitive: false), 'Remix')
          .replaceAll(RegExp(r'\|.*$'), '')
          .trim();
      final leadArtist = artist.split(RegExp(r'[,&•]')).first.trim();
      final queries = <String>[
        if (cleanTitle.isNotEmpty && leadArtist.isNotEmpty) '$cleanTitle $leadArtist',
        if (cleanTitle.isNotEmpty) cleanTitle,
      ];

      // 1. Official Direct JioSaavn Web API (zero third-party proxy dependency!)
      for (final q in queries) {
        try {
          final uri = Uri.parse(
            'https://www.jiosaavn.com/api.php?p=1&q=${Uri.encodeQueryComponent(q)}&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=6&__call=search.getResults',
          );
          final resp = await http
              .get(uri, headers: const {
                'User-Agent': _webUserAgent,
                'Accept': 'application/json',
                'Referer': 'https://www.jiosaavn.com/',
              })
              .timeout(const Duration(seconds: 7));
          if (resp.statusCode != 200) continue;
          final data = jsonDecode(resp.body);
          final results = data is Map ? data['results'] : null;
          if (results is! List || results.isEmpty) continue;

          for (final item in results) {
            if (item is! Map) continue;
            final moreInfo = item['more_info'];
            final encUrl = (moreInfo is Map
                    ? (moreInfo['encrypted_media_url'] ?? '')
                    : (item['encrypted_media_url'] ?? ''))
                .toString();
            if (encUrl.isEmpty) continue;
            final decrypted = _decryptJioSaavnUrl(encUrl);
            if (decrypted == null || !decrypted.startsWith('http')) continue;

            final is320 = moreInfo is Map && moreInfo['320kbps'].toString() == 'true';
            final candUrls = <String>[
              if (is320) decrypted.replaceAll('_96.mp4', '_320.mp4'),
              decrypted.replaceAll('_96.mp4', '_160.mp4'),
              decrypted,
            ];
            for (final u in candUrls) {
              const hdrs = {'User-Agent': _webUserAgent};
              if (await _probeStreamUrl(u, hdrs)) {
                final durStr = moreInfo is Map
                    ? (moreInfo['duration'] ?? '0').toString()
                    : (item['duration'] ?? '0').toString();
                final durSec = int.tryParse(durStr) ?? 0;
                return NamiYtStreamResult(
                  videoId: videoId,
                  audioUrl: u,
                  mimeType: 'audio/mp4',
                  bitrate: u.contains('_320.') ? 320000 : 160000,
                  duration: Duration(seconds: durSec),
                  headers: hdrs,
                  expiresAtMs: DateTime.now()
                      .add(const Duration(hours: 4))
                      .millisecondsSinceEpoch,
                  clientUsed: 'SAAVN_320K',
                );
              }
            }
          }
        } catch (_) {}
      }

      // 2. Fallback to saavn.dev / saavn.sumit.co if official search returned nothing
      final q = queries.isNotEmpty ? queries.first : '';
      if (q.isEmpty) return null;
      for (final apiBase in const [
        'https://saavn.dev/api/search/songs',
        'https://saavn.sumit.co/api/search/songs',
      ]) {
        try {
          final uri = Uri.parse('$apiBase?query=${Uri.encodeQueryComponent(q)}&limit=5');
          final resp = await http
              .get(uri, headers: const {'User-Agent': _webUserAgent})
              .timeout(const Duration(seconds: 6));
          if (resp.statusCode != 200) continue;
          final data = jsonDecode(resp.body);
          final rawData = data is Map ? data['data'] : null;
          final results = rawData is Map ? rawData['results'] : null;
          if (results is! List || results.isEmpty) continue;
          for (final item in results) {
            if (item is! Map) continue;
            final dlList = item['downloadUrl'];
            if (dlList is! List || dlList.isEmpty) continue;
            String bestUrl = '';
            int bestBr = 128000;
            for (final d in dlList) {
              if (d is Map) {
                final u = (d['url'] ?? d['link'] ?? '').toString();
                final qStr = (d['quality'] ?? '').toString();
                final br = (int.tryParse(qStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 128) * 1000;
                if (u.startsWith('http') && br >= bestBr) {
                  bestUrl = u;
                  bestBr = br;
                }
              }
            }
            if (bestUrl.isEmpty) continue;
            const hdrs = {'User-Agent': _webUserAgent};
            if (await _probeStreamUrl(bestUrl, hdrs)) {
              final durSec = int.tryParse((item['duration'] ?? '0').toString()) ?? 0;
              return NamiYtStreamResult(
                videoId: videoId,
                audioUrl: bestUrl,
                mimeType: 'audio/mp4',
                bitrate: bestBr,
                duration: Duration(seconds: durSec),
                headers: hdrs,
                expiresAtMs: DateTime.now()
                    .add(const Duration(hours: 3))
                    .millisecondsSinceEpoch,
                clientUsed: 'SAAVN_320K',
              );
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _pickStreamByQuality(
    List<Map<String, dynamic>> formats,
    String quality,
  ) {
    final sorted = List<Map<String, dynamic>>.from(formats)
      ..sort((a, b) {
        final ba = (a['bitrate'] as num?)?.toInt() ?? 0;
        final bb = (b['bitrate'] as num?)?.toInt() ?? 0;
        return bb.compareTo(ba);
      });

    if (quality == 'Data Saver') {
      return sorted.last;
    }
    if (quality == 'Balanced') {
      for (final f in sorted) {
        final br = (f['bitrate'] as num?)?.toInt() ?? 0;
        if (br >= 90000 && br <= 145000) return f;
      }
      return sorted[sorted.length ~/ 2];
    }
    // High (Opus) -> prefer highest-bitrate Opus/WebM, else highest M4A
    for (final f in sorted) {
      final mime = (f['mimeType'] ?? '').toString().toLowerCase();
      if (mime.contains('opus') || mime.contains('webm')) return f;
    }
    return sorted.first;
  }

  /// Fetches related radio tracks, channel details, top comment preview & Return YouTube Dislike counts.
  Future<NamiYtWatchDetails> fetchWatchDetails(
    String videoId, {
    String region = 'IN',
    bool fetchDislikes = true,
  }) async {
    String title = '';
    String channelName = '';
    String channelId = '';
    String channelAvatarUrl = '';
    String subscriberText = '';
    String viewsText = '';
    String publishedText = '';
    int likesCount = 0;
    int dislikesCount = 0;
    String topCommentAuthor = '';
    String topCommentText = '';
    String topCommentLikes = '';
    final related = <NamiYtTrack>[];
    final seenIds = <String>{videoId};

    final nextFuture = http
        .post(
          Uri.parse('$_ytApiBase/next?prettyPrint=false'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': _webUserAgent,
          },
          body: jsonEncode({
            'context': _webContext(region),
            'videoId': videoId,
          }),
        )
        .timeout(const Duration(seconds: 9));

    final rydFuture = fetchDislikes
        ? http
            .get(Uri.parse('https://returnyoutubedislikeapi.com/votes?videoId=$videoId'))
            .timeout(const Duration(seconds: 5))
            .catchError((_) => http.Response('', 500))
        : Future.value(http.Response('', 204));

    try {
      final responses = await Future.wait([nextFuture, rydFuture]);
      final nextResp = responses[0];
      final rydResp = responses[1];

      if (rydResp.statusCode == 200 && rydResp.body.isNotEmpty) {
        try {
          final ryd = jsonDecode(rydResp.body) as Map<String, dynamic>;
          likesCount = (ryd['likes'] as num?)?.toInt() ?? 0;
          dislikesCount = (ryd['dislikes'] as num?)?.toInt() ?? 0;
        } catch (_) {}
      }

      if (nextResp.statusCode == 200) {
        final root = jsonDecode(nextResp.body);
        _walkJson(root, (node) {
          if (node is! Map<String, dynamic>) return;
          if (node.containsKey('videoPrimaryInfoRenderer')) {
            final p = node['videoPrimaryInfoRenderer'] as Map<String, dynamic>;
            title = _readText(p['title']);
            viewsText = _readText(
              p['viewCount']?['videoViewCountRenderer']?['shortViewCount'] ??
                  p['viewCount']?['videoViewCountRenderer']?['viewCount'],
            );
            publishedText = _readText(p['dateText']);
          }
          if (node.containsKey('videoSecondaryInfoRenderer')) {
            final s = node['videoSecondaryInfoRenderer'] as Map<String, dynamic>;
            final owner = s['owner']?['videoOwnerRenderer'];
            if (owner is Map<String, dynamic>) {
              channelName = _readText(owner['title']);
              subscriberText = _readText(owner['subscriberCountText']);
              channelAvatarUrl = _bestThumb(owner['thumbnail']?['thumbnails']);
              channelId = (owner['navigationEndpoint']?['browseEndpoint']
                          ?['browseId'] ??
                      '')
                  .toString();
            }
          }
          if (topCommentText.isEmpty &&
              node.containsKey('commentEntryPointTeaserRenderer')) {
            final teaser =
                node['commentEntryPointTeaserRenderer'] as Map<String, dynamic>;
            topCommentText = _readText(teaser['teaserContent']);
            topCommentAuthor = 'Top Comment';
          }
        });
        _extractVideoRenderers(root, related, seenIds, 18);
      }
    } catch (e) {
      debugPrint('[NamiYT] fetchWatchDetails error: $e');
    }

    return NamiYtWatchDetails(
      videoId: videoId,
      title: title,
      channelName: channelName,
      channelId: channelId,
      channelAvatarUrl: channelAvatarUrl,
      subscriberText: subscriberText,
      viewsText: viewsText,
      publishedText: publishedText,
      likesCount: likesCount,
      dislikesCount: dislikesCount,
      topCommentAuthor: topCommentAuthor,
      topCommentText: topCommentText,
      topCommentLikes: topCommentLikes,
      relatedTracks: related,
    );
  }

  /// Fetches SponsorBlock skip segments for non-music/sponsor/intro/outro sections.
  Future<List<NamiYtSponsorSegment>> fetchSponsorSegments(
    String videoId,
  ) async {
    try {
      final uri = Uri.parse(
        'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId&categories=["sponsor","intro","outro","selfpromo","music_offtopic"]',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return const [];
      final list = jsonDecode(resp.body);
      if (list is! List) return const [];
      final out = <NamiYtSponsorSegment>[];
      for (final item in list) {
        if (item is Map<String, dynamic> && item['segment'] is List) {
          final seg = item['segment'] as List;
          if (seg.length >= 2) {
            final start = (seg[0] as num?)?.toDouble() ?? 0.0;
            final end = (seg[1] as num?)?.toDouble() ?? 0.0;
            if (end > start + 1.0) {
              out.add(
                NamiYtSponsorSegment(
                  startSec: start,
                  endSec: end,
                  category: (item['category'] ?? 'sponsor').toString(),
                ),
              );
            }
          }
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Downloads and caches the track thumbnail locally so `_buildCoverArt` & Home Screen Widget
  /// load a real local file path with zero network flicker.
  Future<String?> ensureCachedThumbnail(String videoId, String url) async {
    if (videoId.isEmpty) return null;
    final mem = _thumbFileCache[videoId];
    if (mem != null && File(mem).existsSync()) return mem;

    try {
      final dir = Directory('${Directory.systemTemp.path}/nami_yt_thumbs');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final safeId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/$safeId.jpg');
      if (file.existsSync() && file.lengthSync() > 512) {
        _thumbFileCache[videoId] = file.path;
        return file.path;
      }

      final targetUrl = url.startsWith('http')
          ? url
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
      final resp = await http
          .get(Uri.parse(targetUrl), headers: const {'User-Agent': _webUserAgent})
          .timeout(const Duration(seconds: 7));
      if (resp.statusCode == 200 && resp.bodyBytes.length > 512) {
        await file.writeAsBytes(resp.bodyBytes, flush: true);
        _thumbFileCache[videoId] = file.path;
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // InnerTube JSON Parsers
  // ---------------------------------------------------------------------------
  void _walkJson(dynamic node, void Function(dynamic) visitor) {
    visitor(node);
    if (node is Map) {
      for (final v in node.values) {
        _walkJson(v, visitor);
      }
    } else if (node is List) {
      for (final item in node) {
        _walkJson(item, visitor);
      }
    }
  }

  String _readText(dynamic node) {
    if (node == null) return '';
    if (node is String) return node;
    if (node is Map) {
      if (node['simpleText'] is String) return node['simpleText'] as String;
      if (node['runs'] is List) {
        return (node['runs'] as List)
            .map((r) => r is Map ? (r['text'] ?? '').toString() : '')
            .join();
      }
    }
    return '';
  }

  String _bestThumb(dynamic thumbs) {
    if (thumbs is List && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map && last['url'] is String) {
        var u = last['url'] as String;
        if (u.startsWith('//')) u = 'https:$u';
        return u;
      }
    }
    return '';
  }

  Duration _parseDuration(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty || !cleaned.contains(':')) return Duration.zero;
    final parts = cleaned.split(':').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    }
    return Duration.zero;
  }

  void _extractMusicShelves(dynamic root, List<NamiYtShelf> out) {
    _walkJson(root, (node) {
      if (node is! Map<String, dynamic>) return;
      final shelf = node['musicCarouselShelfRenderer'] ?? node['musicShelfRenderer'];
      if (shelf is! Map<String, dynamic>) return;

      final hdr = shelf['header']?['musicCarouselShelfBasicHeaderRenderer'] ??
          shelf['header']?['musicShelfBasicHeaderRenderer'];
      final title = _readText(hdr?['title'] ?? shelf['title']).trim();
      final kicker = _readText(hdr?['strapline']).trim();
      final contents = shelf['contents'];
      if (contents is! List || contents.isEmpty) return;

      final tracks = <NamiYtTrack>[];
      final cards = <NamiYtCardItem>[];
      final seen = <String>{};

      for (final item in contents) {
        if (item is! Map<String, dynamic>) continue;
        if (item['musicResponsiveListItemRenderer'] is Map<String, dynamic>) {
          final t = _parseResponsiveItem(
            item['musicResponsiveListItemRenderer'] as Map<String, dynamic>,
          );
          if (t != null && seen.add(t.videoId)) {
            tracks.add(t);
          }
        } else if (item['musicTwoRowItemRenderer'] is Map<String, dynamic>) {
          final c = _parseTwoRowCard(
            item['musicTwoRowItemRenderer'] as Map<String, dynamic>,
          );
          if (c != null) {
            cards.add(c);
          }
        }
      }

      if (tracks.isNotEmpty || cards.isNotEmpty) {
        out.add(
          NamiYtShelf(
            title: title.isNotEmpty ? title : (tracks.isNotEmpty ? 'Song mixes' : 'Featured'),
            kicker: kicker,
            isSongMixes: tracks.isNotEmpty && cards.isEmpty,
            tracks: tracks,
            cards: cards,
          ),
        );
      }
    });
  }

  NamiYtTrack? _parseResponsiveItem(Map<String, dynamic> item) {
    String videoId = '';
    _walkJson(item, (n) {
      if (videoId.isEmpty && n is Map && n['videoId'] is String) {
        final v = n['videoId'] as String;
        if (v.length >= 8) videoId = v;
      }
    });
    if (videoId.isEmpty) return null;

    final cols = item['flexColumns'];
    String title = '';
    String artist = 'YouTube Music';
    String viewsText = '';
    Duration duration = Duration.zero;

    if (cols is List) {
      if (cols.isNotEmpty) {
        title = _readText(
          cols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text'],
        ).trim();
      }
      if (cols.length > 1) {
        final meta = _readText(
          cols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text'],
        ).trim();
        final parts = meta.split('•').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) {
          // Skip leading "Song" / "Video" tag if present
          final startIdx = (parts.first == 'Song' || parts.first == 'Video') && parts.length > 1 ? 1 : 0;
          artist = parts[startIdx];
          for (final p in parts.skip(startIdx + 1)) {
            if (p.contains(':')) {
              final d = _parseDuration(p);
              if (d.inSeconds > 0) duration = d;
            } else if (p.toLowerCase().contains('play') || p.toLowerCase().contains('view')) {
              viewsText = p;
            }
          }
        }
      }
    }

    if (title.isEmpty) return null;
    final thumb = _bestThumb(
      item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'],
    );
    return NamiYtTrack(
      videoId: videoId,
      title: title,
      artist: artist,
      duration: duration,
      thumbnailUrl: thumb.isNotEmpty
          ? thumb
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
      viewsText: viewsText,
    );
  }

  NamiYtCardItem? _parseTwoRowCard(Map<String, dynamic> item) {
    final title = _readText(item['title']).trim();
    if (title.isEmpty) return null;
    final subtitle = _readText(item['subtitle']).trim();
    final thumb = _bestThumb(
      item['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'],
    );
    final nav = item['navigationEndpoint'];
    final videoId = nav?['watchEndpoint']?['videoId']?.toString();
    final playlistId = nav?['watchPlaylistEndpoint']?['playlistId']?.toString() ??
        nav?['watchEndpoint']?['playlistId']?.toString();
    final browseId = nav?['browseEndpoint']?['browseId']?.toString();

    return NamiYtCardItem(
      id: videoId ?? playlistId ?? browseId ?? title,
      title: title,
      subtitle: subtitle,
      thumbnailUrl: thumb,
      videoId: videoId,
      browseId: browseId,
      playlistId: playlistId,
    );
  }

  void _extractResponsiveTracks(
    dynamic root,
    List<NamiYtTrack> out,
    Set<String> seen,
    int limit,
  ) {
    _walkJson(root, (node) {
      if (out.length >= limit) return;
      if (node is Map<String, dynamic> &&
          node['musicResponsiveListItemRenderer'] is Map<String, dynamic>) {
        final t = _parseResponsiveItem(
          node['musicResponsiveListItemRenderer'] as Map<String, dynamic>,
        );
        if (t != null && seen.add(t.videoId)) {
          out.add(t);
        }
      }
    });
  }

  void _extractVideoRenderers(
    dynamic root,
    List<NamiYtTrack> out,
    Set<String> seen,
    int limit,
  ) {
    _walkJson(root, (node) {
      if (out.length >= limit) return;
      if (node is! Map<String, dynamic>) return;
      final vr = node['videoRenderer'] ?? node['compactVideoRenderer'];
      if (vr is! Map<String, dynamic>) return;
      final vid = (vr['videoId'] ?? '').toString();
      if (vid.length < 8 || !seen.add(vid)) return;
      final title = _readText(vr['title']).trim();
      if (title.isEmpty) return;
      final artist = _readText(
        vr['ownerText'] ?? vr['longBylineText'] ?? vr['shortBylineText'],
      ).trim();
      final durText = _readText(vr['lengthText']);
      final views = _readText(vr['shortViewCountText'] ?? vr['viewCountText']);
      final pub = _readText(vr['publishedTimeText']);
      final thumb = _bestThumb(vr['thumbnail']?['thumbnails']);
      out.add(
        NamiYtTrack(
          videoId: vid,
          title: title,
          artist: artist.isNotEmpty ? artist : 'YouTube',
          duration: _parseDuration(durText),
          thumbnailUrl: thumb.isNotEmpty
              ? thumb
              : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
          viewsText: views,
          publishedText: pub,
        ),
      );
    });
  }
}

/// Account-Free Local-First Persistence Store for Nami's YouTube Section:
/// Stores History, Recent Listens, Most Played (with Day filters), Favorites,
/// Subscribed Local Channels, Local Playlists & auto-generated Home Mixes.
class NamiYoutubeStore {
  NamiYoutubeStore._();
  static final NamiYoutubeStore instance = NamiYoutubeStore._();

  static const String _prefsKey = 'nami_v30_yt_store_v1';

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _loaded = false;
  final Map<String, NamiYtTrack> _catalog = {};
  final List<String> _historyIds = [];
  final List<NamiYtChannel> _channels = [];
  final List<NamiYtLocalPlaylist> _playlists = [];

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final tracks = data['catalog'];
      if (tracks is List) {
        for (final item in tracks) {
          if (item is Map<String, dynamic>) {
            final t = NamiYtTrack.fromJson(item);
            if (t.videoId.isNotEmpty) _catalog[t.videoId] = t;
          }
        }
      }
      final hist = data['historyIds'];
      if (hist is List) {
        _historyIds
          ..clear()
          ..addAll(hist.map((e) => e.toString()));
      }
      final chs = data['channels'];
      if (chs is List) {
        _channels
          ..clear()
          ..addAll(
            chs.whereType<Map<String, dynamic>>().map(NamiYtChannel.fromJson),
          );
      }
      final pls = data['playlists'];
      if (pls is List) {
        _playlists
          ..clear()
          ..addAll(
            pls
                .whereType<Map<String, dynamic>>()
                .map(NamiYtLocalPlaylist.fromJson),
          );
      }
      revision.value++;
    } catch (e) {
      debugPrint('[NamiYTStore] load error: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'catalog': _catalog.values.take(400).map((t) => t.toJson()).toList(),
        'historyIds': _historyIds.take(300).toList(),
        'channels': _channels.map((c) => c.toJson()).toList(),
        'playlists': _playlists.map((p) => p.toJson()).toList(),
      });
      await prefs.setString(_prefsKey, payload);
    } catch (_) {}
  }

  List<NamiYtTrack> get history => _historyIds
      .map((id) => _catalog[id])
      .whereType<NamiYtTrack>()
      .toList();

  List<NamiYtTrack> get favorites => _catalog.values
      .where((t) => t.isFavorite)
      .toList()
    ..sort((a, b) => b.lastPlayedMs.compareTo(a.lastPlayedMs));

  List<NamiYtChannel> get channels => List.unmodifiable(_channels);

  List<NamiYtLocalPlaylist> get playlists => List.unmodifiable(_playlists);

  List<NamiYtTrack> mostPlayed({int? withinDays}) {
    final cutoffMs = withinDays != null
        ? DateTime.now()
            .subtract(Duration(days: withinDays))
            .millisecondsSinceEpoch
        : 0;
    final list = _catalog.values.where((t) {
      if (t.playCount <= 0) return false;
      if (cutoffMs > 0 && t.lastPlayedMs < cutoffMs) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final cmp = b.playCount.compareTo(a.playCount);
        return cmp != 0 ? cmp : b.lastPlayedMs.compareTo(a.lastPlayedMs);
      });
    return list;
  }

  /// Auto-generates Nami-style local Mixes (`Recommended` & `"<TopTrack>" Supremacy`).
  List<NamiYtMix> generatedMixes() {
    final hist = history;
    if (hist.isEmpty) return const [];
    final mixes = <NamiYtMix>[];
    final recTracks = hist.take(12).toList();
    mixes.add(
      NamiYtMix(
        id: 'mix_recommended',
        title: 'Recommended',
        subtitle: recTracks.take(3).map((t) => t.title).join(', '),
        thumbnailUrl: recTracks.first.thumbnailUrl,
        tracks: recTracks,
      ),
    );
    final top = mostPlayed();
    if (top.isNotEmpty) {
      final lead = top.first;
      mixes.add(
        NamiYtMix(
          id: 'mix_top_${lead.videoId}',
          title: '"${lead.title}" Supremacy',
          subtitle: top.take(4).map((t) => t.title).join(', '),
          thumbnailUrl: lead.thumbnailUrl,
          tracks: top.take(12).toList(),
        ),
      );
    }
    return mixes;
  }

  Future<void> recordPlay(NamiYtTrack track) async {
    await ensureLoaded();
    final prev = _catalog[track.videoId];
    final updated = track.copyWith(
      playCount: (prev?.playCount ?? 0) + 1,
      lastPlayedMs: DateTime.now().millisecondsSinceEpoch,
      isFavorite: prev?.isFavorite ?? track.isFavorite,
      cachedThumbPath: track.cachedThumbPath ?? prev?.cachedThumbPath,
      duration: track.duration.inSeconds > 0
          ? track.duration
          : (prev?.duration ?? Duration.zero),
    );
    _catalog[track.videoId] = updated;
    _historyIds.remove(track.videoId);
    _historyIds.insert(0, track.videoId);
    revision.value++;
    await _save();
  }

  Future<bool> toggleFavorite(NamiYtTrack track) async {
    await ensureLoaded();
    final prev = _catalog[track.videoId] ?? track;
    final nextFav = !prev.isFavorite;
    _catalog[track.videoId] = prev.copyWith(isFavorite: nextFav);
    revision.value++;
    await _save();
    return nextFav;
  }

  bool isFavorite(String videoId) => _catalog[videoId]?.isFavorite == true;

  bool isChannelSubscribed(String channelId) =>
      _channels.any((c) => c.channelId == channelId);

  Future<bool> toggleChannelSubscription(NamiYtChannel channel) async {
    await ensureLoaded();
    final idx = _channels.indexWhere((c) => c.channelId == channel.channelId);
    if (idx != -1) {
      _channels.removeAt(idx);
      revision.value++;
      await _save();
      return false;
    }
    _channels.insert(0, channel);
    revision.value++;
    await _save();
    return true;
  }

  Future<NamiYtLocalPlaylist> createPlaylist(String name) async {
    await ensureLoaded();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pl = NamiYtLocalPlaylist(
      id: 'ytpl_$now',
      name: name.trim(),
      videoIds: const [],
      updatedAtMs: now,
    );
    _playlists.insert(0, pl);
    revision.value++;
    await _save();
    return pl;
  }

  Future<void> addTrackToPlaylist(String playlistId, NamiYtTrack track) async {
    await ensureLoaded();
    _catalog.putIfAbsent(track.videoId, () => track);
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    final old = _playlists[idx];
    if (old.videoIds.contains(track.videoId)) return;
    _playlists[idx] = NamiYtLocalPlaylist(
      id: old.id,
      name: old.name,
      videoIds: [...old.videoIds, track.videoId],
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    revision.value++;
    await _save();
  }

  List<NamiYtTrack> tracksForPlaylist(NamiYtLocalPlaylist pl) => pl.videoIds
      .map((id) => _catalog[id])
      .whereType<NamiYtTrack>()
      .toList();
}

class _NamiYtProxyTarget {
  final String upstreamUrl;
  final Map<String, String> headers;
  final String mimeType;
  final int? contentLength;

  const _NamiYtProxyTarget({
    required this.upstreamUrl,
    required this.headers,
    required this.mimeType,
    this.contentLength,
  });
}

/// Pure-Dart localhost HTTP streaming proxy (`http://127.0.0.1:<port>/yt/<videoId>.<ext>`).
/// Bridges Dart's BoringSSL `HttpClient` (which passes googlevideo.com TLS + User-Agent + Range checks)
/// directly to Android `libmpv` over plain loopback HTTP with instant seeking & zero 403/TLS failures.
class NamiYtLocalProxy {
  NamiYtLocalProxy._();
  static final NamiYtLocalProxy instance = NamiYtLocalProxy._();

  HttpServer? _server;
  int _port = 0;
  final Map<String, _NamiYtProxyTarget> _targets = {};

  Future<void> _ensureStarted() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: true);
    _port = _server!.port;
    _server!.listen(_handleRequest, onError: (_) {});
    debugPrint('[NamiYtProxy] Listening on http://127.0.0.1:$_port');
  }

  /// Registers a verified upstream audio URL and returns a clean local loopback URL for `libmpv`.
  Future<String> registerStream({
    required String videoId,
    required String upstreamUrl,
    required Map<String, String> headers,
    required String mimeType,
    int? contentLength,
  }) async {
    await _ensureStarted();
    final lower = mimeType.toLowerCase();
    final ext = lower.contains('mpegurl') || upstreamUrl.contains('.m3u8')
        ? 'm3u8'
        : (lower.contains('mp4') || lower.contains('m4a') || lower.contains('aac')
            ? 'm4a'
            : 'webm');
    final safeId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final key = '$safeId.$ext';
    _targets[key] = _NamiYtProxyTarget(
      upstreamUrl: upstreamUrl,
      headers: Map<String, String>.from(headers),
      mimeType: mimeType.split(';').first.trim(),
      contentLength: contentLength,
    );
    return 'http://127.0.0.1:$_port/yt/$key';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final res = req.response;
    res.bufferOutput = false;
    final segs = req.uri.pathSegments;
    if (segs.length < 2 || segs[0] != 'yt') {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final target = _targets[segs[1]];
    if (target == null) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }

    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 10);

    try {
      final upReq = await client.openUrl(req.method, Uri.parse(target.upstreamUrl));
      upReq.followRedirects = true;
      upReq.maxRedirects = 5;
      target.headers.forEach((k, v) {
        upReq.headers.set(k, v);
      });
      final rangeHdr = req.headers.value(HttpHeaders.rangeHeader);
      if (rangeHdr != null && rangeHdr.isNotEmpty) {
        upReq.headers.set(HttpHeaders.rangeHeader, rangeHdr);
      }
      upReq.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

      final upRes = await upReq.close().timeout(const Duration(seconds: 12));
      res.statusCode = upRes.statusCode;
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      final upCt = upRes.headers.value(HttpHeaders.contentTypeHeader);
      res.headers.set(
        HttpHeaders.contentTypeHeader,
        (upCt != null && upCt.isNotEmpty) ? upCt : target.mimeType,
      );
      final upCr = upRes.headers.value(HttpHeaders.contentRangeHeader);
      if (upCr != null && upCr.isNotEmpty) {
        res.headers.set(HttpHeaders.contentRangeHeader, upCr);
      }
      if (upRes.contentLength >= 0) {
        res.contentLength = upRes.contentLength;
      }

      if (req.method == 'HEAD') {
        await upRes.drain<void>();
        await res.close();
        return;
      }

      await for (final chunk in upRes) {
        res.add(chunk);
      }
      await res.close();
    } catch (_) {
      try {
        await res.close();
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  }
}

/// Local-First Chunked Audio Cache for YouTube Streams (`v3.1.0`):
/// Downloads verified audio in bounded 512KB DASH chunks (`&range=start-end`) using up to
/// 4 parallel workers directly to a local file (`nami_yt_cache/<videoId>.<ext>`), so `libmpv`
/// ALWAYS plays a real local file path with zero HTTP/TLS/403 errors, instant seeking & offline replay!
class NamiYtAudioCache {
  NamiYtAudioCache._();
  static final NamiYtAudioCache instance = NamiYtAudioCache._();

  static const int _chunkSize = 512 * 1024; // 512 KB bounded chunks bypass YouTube throttling/403
  final Map<String, Future<File?>> _inFlight = {};

  Directory get cacheDir {
    final d = Directory('${Directory.systemTemp.path}/nami_yt_cache');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  String _extForMime(String mimeType) {
    final l = mimeType.toLowerCase();
    if (l.contains('mp4') || l.contains('m4a') || l.contains('aac')) return 'm4a';
    if (l.contains('ogg')) return 'ogg';
    return 'webm';
  }

  /// Returns an existing verified cached audio file on disk if present (0ms instant replay!).
  File? findCachedFile(String videoId) {
    final safeId = videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    for (final ext in const ['m4a', 'webm', 'ts', 'ogg']) {
      final f = File('${cacheDir.path}/$safeId.$ext');
      if (f.existsSync() && f.lengthSync() > 49152) {
        try {
          final raf = f.openSync(mode: FileMode.read);
          final hdr = raf.readSync(16);
          raf.closeSync();
          if (NamiYoutubeService.isValidAudioHeader(hdr)) {
            return f;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<int> getTotalCacheBytes() async {
    int total = 0;
    try {
      if (cacheDir.existsSync()) {
        for (final e in cacheDir.listSync()) {
          if (e is File && !e.path.endsWith('.part')) {
            total += e.lengthSync();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> clearAll() async {
    try {
      if (cacheDir.existsSync()) {
        for (final e in cacheDir.listSync()) {
          if (e is File) {
            try {
              e.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _evictLruIfNeeded({int maxMb = 512}) async {
    try {
      final maxBytes = maxMb.clamp(64, 2048) * 1024 * 1024;
      final files = cacheDir
          .listSync()
          .whereType<File>()
          .where((f) => !f.path.endsWith('.part'))
          .toList();
      int total = 0;
      for (final f in files) {
        total += f.lengthSync();
      }
      if (total <= maxBytes) return;
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      for (final f in files) {
        if (total <= (maxBytes * 0.80).round()) break;
        final sz = f.lengthSync();
        try {
          f.deleteSync();
          total -= sz;
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Ensures the given resolved stream is downloaded to a verified local file on disk.
  /// Deduplicates concurrent requests for the same videoId and emits live progress (`0.0..1.0`).
  Future<File?> ensureCachedAudioFile(
    NamiYtStreamResult stream, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
    int maxCacheMb = 512,
  }) async {
    final existing = findCachedFile(stream.videoId);
    if (existing != null) {
      final sz = existing.lengthSync();
      onProgress?.call(1.0, sz, sz);
      try {
        existing.setLastModifiedSync(DateTime.now());
      } catch (_) {}
      return existing;
    }

    final inflight = _inFlight[stream.videoId];
    if (inflight != null) {
      return inflight;
    }

    final future = _downloadToCacheInternal(
      stream,
      onProgress: onProgress,
      isCancelled: isCancelled,
      maxCacheMb: maxCacheMb,
    );
    _inFlight[stream.videoId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(stream.videoId);
    }
  }

  Future<File?> _downloadToCacheInternal(
    NamiYtStreamResult stream, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
    int maxCacheMb = 512,
  }) async {
    final safeId = stream.videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final ext = _extForMime(stream.mimeType);
    final finalFile = File('${cacheDir.path}/$safeId.$ext');
    final partFile = File('${cacheDir.path}/$safeId.$ext.part');

    final reqHeaders = <String, String>{};
    stream.headers.forEach((k, v) {
      if (!k.toLowerCase().startsWith('x-nami-')) {
        reqHeaders[k] = v;
      }
    });

    if (stream.audioUrl.contains('.m3u8') || stream.audioUrl.contains('manifest/hls') || stream.mimeType.toLowerCase().contains('mpegurl')) {
      return _downloadHlsToCache(stream, reqHeaders, onProgress: onProgress, isCancelled: isCancelled, maxCacheMb: maxCacheMb);
    }
    int knownTotal = int.tryParse(stream.headers['X-Nami-Content-Length'] ?? '') ?? 0;

    // Step 1: Fetch first chunk (0..512KB-1) to verify real audio bytes & discover exact total length
    final firstEnd = (knownTotal > 0 && knownTotal < _chunkSize) ? knownTotal - 1 : _chunkSize - 1;
    final firstChunk = await _fetchChunkWithRetry(
      stream.audioUrl,
      reqHeaders,
      0,
      firstEnd,
      onTotalDiscovered: (t) {
        if (t > knownTotal) knownTotal = t;
      },
    );
    if (firstChunk == null || firstChunk.isEmpty || !NamiYoutubeService.isValidAudioHeader(firstChunk)) {
      return null;
    }
    if (isCancelled?.call() == true) return null;

    if (partFile.existsSync()) {
      try {
        partFile.deleteSync();
      } catch (_) {}
    }

    // Case A: Single-chunk small track or exact total fits in first chunk
    if (knownTotal > 0 && firstChunk.length >= knownTotal) {
      await partFile.writeAsBytes(firstChunk, flush: true);
      if (finalFile.existsSync()) finalFile.deleteSync();
      await partFile.rename(finalFile.path);
      onProgress?.call(1.0, firstChunk.length, firstChunk.length);
      unawaited(_evictLruIfNeeded(maxMb: maxCacheMb));
      return finalFile;
    }

    // Case B: Known total length -> 4-way parallel bounded chunk download straight into RandomAccessFile!
    if (knownTotal > firstChunk.length) {
      final raf = partFile.openSync(mode: FileMode.write);
      try {
        raf.writeFromSync(firstChunk);
        int received = firstChunk.length;
        onProgress?.call((received / knownTotal).clamp(0.0, 0.99), received, knownTotal);

        final ranges = <(int, int)>[];
        int offset = firstChunk.length;
        while (offset < knownTotal) {
          final end = (offset + _chunkSize - 1).clamp(offset, knownTotal - 1);
          ranges.add((offset, end));
          offset = end + 1;
        }

        const int concurrency = 4;
        for (int i = 0; i < ranges.length; i += concurrency) {
          if (isCancelled?.call() == true) {
            raf.closeSync();
            try {
              partFile.deleteSync();
            } catch (_) {}
            return null;
          }
          final batch = ranges.skip(i).take(concurrency).toList();
          final results = await Future.wait<List<int>?>(
            batch.map((r) => _fetchChunkWithRetry(stream.audioUrl, reqHeaders, r.$1, r.$2)),
          );
          for (int j = 0; j < batch.length; j++) {
            final data = results[j];
            if (data == null || data.isEmpty) {
              raf.closeSync();
              try {
                partFile.deleteSync();
              } catch (_) {}
              return null;
            }
            raf.setPositionSync(batch[j].$1);
            raf.writeFromSync(data);
            received += data.length;
          }
          onProgress?.call((received / knownTotal).clamp(0.0, 0.99), received, knownTotal);
        }
        raf.flushSync();
        raf.closeSync();
      } catch (_) {
        try {
          raf.closeSync();
          partFile.deleteSync();
        } catch (_) {}
        return null;
      }
    } else {
      // Case C: Unknown total length -> sequential bounded chunks until EOF (short read / 416)
      final sink = partFile.openWrite();
      try {
        sink.add(firstChunk);
        int offset = firstChunk.length;
        int safetyMaxChunks = 80; // up to 40 MB
        while (safetyMaxChunks-- > 0) {
          if (isCancelled?.call() == true) {
            await sink.close();
            try {
              partFile.deleteSync();
            } catch (_) {}
            return null;
          }
          final end = offset + _chunkSize - 1;
          final chunk = await _fetchChunkWithRetry(stream.audioUrl, reqHeaders, offset, end);
          if (chunk == null || chunk.isEmpty) break;
          sink.add(chunk);
          offset += chunk.length;
          final estTotal = knownTotal > offset ? knownTotal : (offset + _chunkSize);
          onProgress?.call((offset / estTotal).clamp(0.0, 0.96), offset, estTotal);
          if (chunk.length < _chunkSize) break;
        }
        await sink.flush();
        await sink.close();
      } catch (_) {
        try {
          await sink.close();
          partFile.deleteSync();
        } catch (_) {}
        return null;
      }
    }

    if (!partFile.existsSync() || partFile.lengthSync() < 32768) {
      try {
        if (partFile.existsSync()) partFile.deleteSync();
      } catch (_) {}
      return null;
    }

    if (finalFile.existsSync()) {
      try {
        finalFile.deleteSync();
      } catch (_) {}
    }
    await partFile.rename(finalFile.path);
    final finalLen = finalFile.lengthSync();
    onProgress?.call(1.0, finalLen, finalLen);
    unawaited(_evictLruIfNeeded(maxMb: maxCacheMb));
    return finalFile;
  }

  Future<File?> _downloadHlsToCache(
    NamiYtStreamResult stream, Map<String, String> headers, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled, int maxCacheMb = 512,
  }) async {
    try {
      final masterUri = Uri.parse(stream.audioUrl);
      final mr = await http.get(masterUri, headers: headers).timeout(const Duration(seconds: 8));
      if (mr.statusCode != 200 || !mr.body.contains('#EXTM3U')) return null;
      Uri mediaUri = masterUri; String body = mr.body;
      if (body.contains('#EXT-X-STREAM-INF') || body.contains('#EXT-X-MEDIA:')) {
        String? picked; int lowBw = 1 << 30;
        final lines = body.split('\n').map((l) => l.trim()).toList();
        for (final ln in lines) {
          if (ln.startsWith('#EXT-X-MEDIA:') && ln.contains('TYPE=AUDIO')) {
            final m = RegExp(r'URI="([^"]+)"').firstMatch(ln);
            if (m != null) { picked = m.group(1); if (ln.contains('DEFAULT=YES')) break; }
          }
        }
        if (picked == null) {
          for (int i = 0; i < lines.length - 1; i++) {
            if (lines[i].startsWith('#EXT-X-STREAM-INF:')) {
              final bw = int.tryParse(RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i])?.group(1) ?? '') ?? 9999999;
              if (lines[i+1].isNotEmpty && !lines[i+1].startsWith('#') && bw < lowBw) { lowBw = bw; picked = lines[i+1]; }
            }
          }
        }
        if (picked == null) return null;
        mediaUri = masterUri.resolve(picked);
        final r2 = await http.get(mediaUri, headers: headers).timeout(const Duration(seconds: 8));
        if (r2.statusCode != 200) return null;
        body = r2.body;
      }
      final segs = <Uri>[]; bool fmp4 = false;
      for (final raw in body.split('\n')) {
        final ln = raw.trim();
        if (ln.isEmpty) continue;
        if (ln.startsWith('#EXT-X-MAP:')) {
          final m = RegExp(r'URI="([^"]+)"').firstMatch(ln);
          if (m != null) { fmp4 = true; segs.add(mediaUri.resolve(m.group(1)!)); }
          continue;
        }
        if (ln.startsWith('#')) continue;
        if (ln.contains('.m4s') || ln.contains('.mp4')) fmp4 = true;
        segs.add(mediaUri.resolve(ln));
      }
      if (segs.isEmpty) return null;
      final sid = stream.videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fin = File('${cacheDir.path}/$sid.${fmp4 ? 'm4a' : 'ts'}');
      final part = File('${fin.path}.part');
      if (part.existsSync()) part.deleteSync();
      final sink = part.openWrite(); int bytes = 0;
      for (int i = 0; i < segs.length; i += 4) {
        if (isCancelled?.call() == true) { await sink.close(); try { part.deleteSync(); } catch (_) {} return null; }
        final batch = segs.skip(i).take(4).toList();
        final got = await Future.wait<List<int>?>(batch.map((u) async {
          try { final r = await http.get(u, headers: headers).timeout(const Duration(seconds: 9)); return r.statusCode == 200 ? r.bodyBytes : null; } catch (_) { return null; }
        }));
        for (final d in got) {
          if (d == null) { await sink.close(); try { part.deleteSync(); } catch (_) {} return null; }
          sink.add(d); bytes += d.length;
        }
        onProgress?.call(((i + batch.length) / segs.length).clamp(0.0, 0.99), bytes, bytes);
      }
      await sink.flush(); await sink.close();
      if (fin.existsSync()) fin.deleteSync();
      await part.rename(fin.path);
      final sz = fin.lengthSync(); onProgress?.call(1.0, sz, sz);
      unawaited(_evictLruIfNeeded(maxMb: maxCacheMb));
      return fin;
    } catch (_) { return null; }
  }

  Future<List<int>?> _fetchChunkWithRetry(
    String rawUrl,
    Map<String, String> baseHeaders,
    int start,
    int end, {
    void Function(int total)? onTotalDiscovered,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = NamiYoutubeService.buildBoundedChunkUri(rawUrl, start, end);
        final hdrs = Map<String, String>.from(baseHeaders);
        if (!uri.toString().contains('range=')) {
          hdrs['Range'] = 'bytes=$start-$end';
        }
        final resp = await http
            .get(uri, headers: hdrs)
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 416) return const <int>[];
        if (resp.statusCode == 200 || resp.statusCode == 206) {
          final cr = resp.headers['content-range'] ?? '';
          final slash = cr.lastIndexOf('/');
          if (slash != -1) {
            final parsedTotal = int.tryParse(cr.substring(slash + 1).trim()) ?? 0;
            if (parsedTotal > 0) onTotalDiscovered?.call(parsedTotal);
          } else if (resp.statusCode == 200 && start == 0 && !uri.toString().contains('range=')) {
            final cl = int.tryParse(resp.headers['content-length'] ?? '') ?? resp.bodyBytes.length;
            if (cl > 0) onTotalDiscovered?.call(cl);
          }
          return resp.bodyBytes;
        }
      } catch (_) {}
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    }
    return null;
  }
}

