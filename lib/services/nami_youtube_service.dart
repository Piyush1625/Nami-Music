import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

class NamiYtVideoFormat {
  final int itag;
  final String qualityLabel;
  final int height;
  final int fps;
  final int bitrate;
  final int contentLength;
  final String mimeType;
  final String url;
  final Map<String, String> headers;

  const NamiYtVideoFormat({
    required this.itag,
    required this.qualityLabel,
    required this.height,
    this.fps = 30,
    required this.bitrate,
    this.contentLength = 0,
    required this.mimeType,
    required this.url,
    this.headers = const {},
  });

  String get bitrateLabel => '${(bitrate / 1000).round()} kb/s';

  String sizeLabelFor(Duration dur) {
    int bytes = contentLength;
    if (bytes <= 0 && dur.inSeconds > 0 && bitrate > 0) {
      bytes = ((bitrate * dur.inSeconds) / 8).round();
    }
    if (bytes <= 0) return bitrateLabel;
    final mb = bytes / (1024 * 1024);
    return mb >= 10 ? '${mb.toStringAsFixed(1)} MB' : '${mb.toStringAsFixed(2)} MB';
  }
}

class NamiYtMediaBundle {
  final NamiYtStreamResult audioStream;
  final List<NamiYtVideoFormat> videoFormats;
  final Duration duration;

  const NamiYtMediaBundle({
    required this.audioStream,
    this.videoFormats = const [],
    this.duration = Duration.zero,
  });
}

class NamiYtComment {
  final String id;
  final String author;
  final String authorAvatarUrl;
  final String authorChannelId;
  final String text;
  final String publishedText;
  final String likesText;
  final int replyCount;
  final String replyCountText;
  final String? repliesContinuation;
  final bool isPinned;
  final bool isHearted;

  const NamiYtComment({
    required this.id,
    required this.author,
    this.authorAvatarUrl = '',
    this.authorChannelId = '',
    required this.text,
    this.publishedText = '',
    this.likesText = '',
    this.replyCount = 0,
    this.replyCountText = '',
    this.repliesContinuation,
    this.isPinned = false,
    this.isHearted = false,
  });
}

class NamiYtCommentsPage {
  final List<NamiYtComment> comments;
  final String? nextContinuation;
  final String? topSortToken;
  final String? newestSortToken;
  final String totalCountText;

  const NamiYtCommentsPage({
    required this.comments,
    this.nextContinuation,
    this.topSortToken,
    this.newestSortToken,
    this.totalCountText = '',
  });
}

class NamiYtChannelShelf {
  final String title;
  final List<NamiYtTrack> items;

  const NamiYtChannelShelf({
    required this.title,
    required this.items,
  });
}

class NamiYtChannelDetails {
  final String channelId;
  final String name;
  final String handle;
  final String avatarUrl;
  final String bannerUrl;
  final String subscriberText;
  final String videoCountText;
  final String description;
  final List<NamiYtChannelShelf> homeShelves;
  final List<NamiYtTrack> videos;
  final List<NamiYtTrack> shorts;
  final List<NamiYtTrack> releases;
  final List<NamiYtCardItem> playlists;
  final String? videosTabParams;
  final String? shortsTabParams;
  final String? releasesTabParams;
  final String? playlistsTabParams;

  const NamiYtChannelDetails({
    required this.channelId,
    required this.name,
    this.handle = '',
    this.avatarUrl = '',
    this.bannerUrl = '',
    this.subscriberText = '',
    this.videoCountText = '',
    this.description = '',
    this.homeShelves = const [],
    this.videos = const [],
    this.shorts = const [],
    this.releases = const [],
    this.playlists = const [],
    this.videosTabParams,
    this.shortsTabParams,
    this.releasesTabParams,
    this.playlistsTabParams,
  });
}

/// Core InnerTube API Engine for Nami v3.0:
/// - India-first YouTube Music browse (`FEmusic_home`, `Charts`, `Moods`, `New releases`)
/// - Resilient multi-client audio stream resolver (`ANDROID_VR` -> `IOS` -> `ANDROID_TESTSUITE` -> `Piped`)
/// - Watch metadata, Related Radio tracks, Return YouTube Dislike & SponsorBlock
/// - Disk-backed cover thumbnail cache for seamless native `Image.file` + Home Widget support
class NamiYoutubeService {
  void clearAllCaches() {
    _streamCache.clear();
    _bundleCache.clear();
  }

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

  /// Last diagnostic trace when stream resolution fails across all pure-YouTube tiers.
  static String lastResolveDiagnostic = '';
  static String _cachedVisitorData = '';
  static int _visitorDataFetchedAtMs = 0;
  static String customYoutubeCookie = '';
  static String _nativeWebViewCookie = '';
  static String _nativeWebViewUa = '';
  static final ValueNotifier<bool> isSignedIn = ValueNotifier<bool>(false);
  static const MethodChannel _ytNativeChannel = MethodChannel('com.piyush.nami/yt_engine');

  static String get _effectiveCookie =>
      customYoutubeCookie.isNotEmpty ? customYoutubeCookie : _nativeWebViewCookie;

  static void _applyNativeSessionMap(dynamic raw) {
    if (raw is! Map) return;
    final cookie = (raw['cookie'] ?? '').toString().trim();
    final ua = (raw['userAgent'] ?? '').toString().trim();
    if (ua.isNotEmpty) _nativeWebViewUa = ua;
    _nativeWebViewCookie = cookie;
    final signed = raw['signedIn'] == true ||
        _effectiveCookie.contains('SAPISID=') ||
        _effectiveCookie.contains('__Secure-3PAPISID=');
    isSignedIn.value = signed;
  }

  /// Pre-warms Android's invisible Chromium WebView & syncs live logged-in/logged-out session state.
  static Future<void> warmUpNativeEngine() async {
    await loadCustomCookie();
    try {
      final res = await _ytNativeChannel
          .invokeMethod<dynamic>('warmUp')
          .timeout(const Duration(seconds: 4));
      _applyNativeSessionMap(res);
    } catch (_) {}
  }

  static Future<void> refreshNativeSessionStatus() async {
    try {
      final res = await _ytNativeChannel
          .invokeMethod<dynamic>('getSessionStatus')
          .timeout(const Duration(seconds: 4));
      _applyNativeSessionMap(res);
    } catch (_) {}
  }

  /// Opens native in-app YouTube sign-in dialog (optional — Logged-Out BotGuard works without signing in).
  static Future<bool> openInAppSignIn() async {
    try {
      final res = await _ytNativeChannel.invokeMethod<dynamic>('openSignIn');
      _applyNativeSessionMap(res);
      return isSignedIn.value;
    } catch (_) {
      return isSignedIn.value;
    }
  }

  /// Signs out of YouTube & switches cleanly back to anonymous Logged-Out BotGuard mode.
  static Future<void> signOutYoutube() async {
    await saveCustomCookie('');
    _nativeWebViewCookie = '';
    try {
      final res = await _ytNativeChannel
          .invokeMethod<dynamic>('signOut')
          .timeout(const Duration(seconds: 5));
      _applyNativeSessionMap(res);
    } catch (_) {}
    isSignedIn.value = false;
  }

  static Future<void> loadCustomCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      customYoutubeCookie = prefs.getString('nami_v31_yt_cookie') ?? '';
      if (customYoutubeCookie.contains('SAPISID=') ||
          customYoutubeCookie.contains('__Secure-3PAPISID=')) {
        isSignedIn.value = true;
      }
    } catch (_) {}
  }

  static Future<void> saveCustomCookie(String cookie) async {
    customYoutubeCookie = cookie.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nami_v31_yt_cookie', customYoutubeCookie);
    } catch (_) {}
    isSignedIn.value = _effectiveCookie.contains('SAPISID=') ||
        _effectiveCookie.contains('__Secure-3PAPISID=');
  }

  /// Calls Android's invisible Chromium WebView to run Google's real BotGuard JS and intercept
  /// BOTH genuine audio AND video `googlevideo.com` streams (works Logged-Out & Signed-In!).
  Future<NamiYtStreamResult?> _extractViaNativeWebView(String videoId) async {
    try {
      final res = await _ytNativeChannel
          .invokeMethod<dynamic>('extractAudioStream', {'videoId': videoId})
          .timeout(const Duration(seconds: 11));
      if (res is! Map) return null;
      final url = (res['url'] ?? '').toString();
      if (!url.startsWith('http')) return null;
      final mime = (res['mimeType'] ?? 'audio/webm').toString();
      final ua = (res['userAgent'] ?? _nativeWebViewUa).toString();
      final cookie = (res['cookie'] ?? '').toString();
      if (cookie.isNotEmpty) {
        _nativeWebViewCookie = cookie;
        isSignedIn.value =
            _effectiveCookie.contains('SAPISID=') || _effectiveCookie.contains('__Secure-3PAPISID=');
      }
      final clen = (res['contentLength'] as num?)?.toInt() ?? 0;
      final clientUsed = (res['clientUsed'] ?? 'WEBVIEW_BOTGUARD').toString();
      final hdrs = <String, String>{
        'User-Agent': ua.isNotEmpty ? ua : _webUserAgent,
        if (cookie.isNotEmpty) 'Cookie': cookie,
        if (clen > 0) 'X-Nami-Content-Length': '$clen',
      };

      // Capture companion video stream returned by Chromium BotGuard (for 480p/720p playback!)
      final vUrl = (res['videoUrl'] ?? '').toString();
      if (vUrl.startsWith('http')) {
        final vMime = (res['videoMimeType'] ?? 'video/mp4').toString();
        final vClen = (res['videoContentLength'] as num?)?.toInt() ?? 0;
        final vItag = (res['videoItag'] as num?)?.toInt() ?? 135;
        final h = vItag == 137
            ? 1080
            : (vItag == 136 || vItag == 247 || vItag == 398
                ? 720
                : (vItag == 18 ? 360 : 480));
        _lastWebViewVideoFormats[videoId] = [
          NamiYtVideoFormat(
            itag: vItag,
            qualityLabel: '${h}p',
            height: h,
            bitrate: h >= 720 ? 1500000 : 750000,
            contentLength: vClen,
            mimeType: vMime.split(';').first.trim(),
            url: vUrl,
            headers: {
              'User-Agent': ua.isNotEmpty ? ua : _webUserAgent,
              if (cookie.isNotEmpty) 'Cookie': cookie,
            },
          ),
        ];
      }

      // Probe head (always accept genuine Chromium-minted BotGuard stream without rejecting on strict tail!)
      if (await _probeStreamUrl(url, hdrs, contentLength: 0)) {
        return NamiYtStreamResult(
          videoId: videoId,
          audioUrl: url,
          mimeType: mime,
          bitrate: mime.contains('webm') ? 140000 : 128000,
          duration: Duration.zero,
          headers: hdrs,
          expiresAtMs: DateTime.now()
              .add(const Duration(hours: 3))
              .millisecondsSinceEpoch,
          clientUsed: clientUsed,
        );
      }
    } catch (e) {
      debugPrint('[NamiYT] Native WebView BotGuard extract failed: $e');
    }
    return null;
  }

  /// Fetches a fresh anonymous YouTube `visitorData` token once every 30 min from `sw.js_data`.
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

  /// Computes `SAPISIDHASH <ts>_<sha1>` header whenever the user is signed into YouTube.
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

  /// Probes BOTH Byte 0 (`0..32767`, verifying real audio/video magic bytes) AND a mid/tail
  /// chunk (`>= 1.5 MB` or `65%` of contentLength, past Google's 30s/60s tokenless 403 cutoff!).
  Future<bool> _probeStreamUrl(
    String url,
    Map<String, String> headers, {
    int contentLength = 0,
  }) async {
    if (!url.startsWith('http')) return false;
    final cleanHeaders = <String, String>{};
    headers.forEach((k, v) {
      if (!k.toLowerCase().startsWith('x-nami-')) cleanHeaders[k] = v;
    });
    if (url.contains('.m3u8') || url.contains('manifest/hls')) {
      try {
        final r = await http
            .get(Uri.parse(url), headers: cleanHeaders)
            .timeout(const Duration(seconds: 6));
        return r.statusCode >= 200 && r.statusCode < 400 && r.body.contains('#EXTM3U');
      } catch (_) {
        return false;
      }
    }
    try {
      // 1. Head probe: verify HTTP 200/206 + valid audio/video container magic bytes
      final headUri = buildBoundedChunkUri(url, 0, 32767);
      final headHdrs = Map<String, String>.from(cleanHeaders);
      if (!headUri.toString().contains('range=')) {
        headHdrs['Range'] = 'bytes=0-32767';
      }
      final resp = await http
          .get(headUri, headers: headHdrs)
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200 && resp.statusCode != 206) return false;
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      if (ct.contains('text/html')) return false;
      if (!isValidAudioHeader(resp.bodyBytes)) return false;

      // Discover exact contentLength from Content-Range or ?clen= if not provided
      int clen = contentLength;
      if (clen <= 0) {
        final cr = resp.headers['content-range'] ?? '';
        final slash = cr.lastIndexOf('/');
        if (slash != -1) {
          clen = int.tryParse(cr.substring(slash + 1).trim()) ?? 0;
        }
      }
      if (clen <= 0) {
        final mClen = RegExp(r'[?&]clen=(\d+)').firstMatch(url);
        clen = int.tryParse(mClen?.group(1) ?? '') ?? 0;
      }

      // 2. Tail probe (anti-30s/60s cutoff guard!):
      //    If file is > 900 KB, verify bytes at ~68% into the track (past Google's 512KB/60s 403 wall!)
      if (clen > 900000) {
        final tailStart = ((clen * 68) ~/ 100).clamp(655360, clen - 16384);
        final tailEnd = (tailStart + 16383).clamp(tailStart, clen - 1);
        final tailUri = buildBoundedChunkUri(url, tailStart, tailEnd);
        final tailHdrs = Map<String, String>.from(cleanHeaders);
        if (!tailUri.toString().contains('range=')) {
          tailHdrs['Range'] = 'bytes=$tailStart-$tailEnd';
        }
        final tailResp = await http
            .get(tailUri, headers: tailHdrs)
            .timeout(const Duration(seconds: 5));
        if (tailResp.statusCode != 200 && tailResp.statusCode != 206) {
          debugPrint('[NamiYT] Rejected 30s/60s truncated stream (tail HTTP ${tailResp.statusCode})');
          return false;
        }
        if (tailResp.bodyBytes.length < 1024) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 100% Pure-YouTube Multi-Tier Resolver (`v3.2.0` — ZERO third-party music catalogs):
  /// - Fast Path (~250ms): Direct InnerTube (`IOS`, `ANDROID_SDKLESS`, `VISIONOS`, `ANDROID_VR`)
  ///   with live `visitorData` + shared Chromium cookies (works immediately when signed in or unflagged)
  /// - Native BotGuard Path (~1.4s): Invisible Android Chromium WebView runs YouTube's real BotGuard JS
  ///   to mint anonymous or authenticated PoTokens and capture real `googlevideo.com` audio streams!
  Future<NamiYtStreamResult?> resolveAudioStream(
    String videoId, {
    String quality = 'High (Opus)',
    String region = 'IN',
    bool forceRefresh = false,
    Set<String> excludeClients = const <String>{},
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
    final cookie = _effectiveCookie;
    final hasCookie = cookie.isNotEmpty;
    final authHdr = hasCookie ? _buildSapisidAuthHeader(cookie) : null;

    const safariUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15';
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
    ];

    // Fast InnerTube pass (~250-500ms total when unblocked or signed in)
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
          if (hasCookie) 'Cookie': cookie,
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
            .timeout(const Duration(seconds: 5));

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
          if (hasCookie) 'Cookie': cookie,
        };

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
            final contentLen =
                int.tryParse((picked['contentLength'] ?? '').toString()) ?? 0;
            if (await _probeStreamUrl(candUrl, streamHeaders, contentLength: contentLen)) {
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

    // Native Chromium Headless BotGuard PoToken Extractor (works 100% Logged-Out & Logged-In!)
    if (!excludeClients.contains('WEBVIEW_BOTGUARD') &&
        !excludeClients.contains('WEBVIEW_AUTH')) {
      final wvRes = await _extractViaNativeWebView(videoId);
      if (wvRes != null) {
        _streamCache[cacheKey] = wvRes;
        lastResolveDiagnostic = '';
        return wvRes;
      }
      diag.add('WV:timeout');
    }

    lastResolveDiagnostic = diag.join(' ');
    debugPrint('[NamiYT] Pure-YouTube resolution failed for $videoId: $lastResolveDiagnostic');
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

    /* v33_1_related_topup */
    if (related.length < 6 && (title.isNotEmpty || channelName.isNotEmpty)) {
      try {
        final q = [if (title.isNotEmpty) title, if (channelName.isNotEmpty) channelName].join(' ');
        final extra = await searchMusic(q, region: region, limit: 14);
        for (final t in extra) {
          if (t.videoId != videoId && seenIds.add(t.videoId)) {
            related.add(t);
          }
        }
      } catch (_) {}
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
      if (node is! Map) return;

      // 1. 2026 YouTube Watch & Channel `lockupViewModel` (replaced compactVideoRenderer in 2025/2026!)
      final lvm = node['lockupViewModel'];
      if (lvm is Map) {
        final ctype = (lvm['contentType'] ?? '').toString();
        final cid = (lvm['contentId'] ?? '').toString();
        if (cid.length >= 8 &&
            (ctype.isEmpty || ctype.contains('VIDEO')) &&
            seen.add(cid)) {
          String title = '';
          String artist = '';
          String views = '';
          String durStr = '';
          String thumb = '';
          String chId = '';

          final meta = lvm['metadata'];
          if (meta is Map && meta['lockupMetadataViewModel'] is Map) {
            final lm = meta['lockupMetadataViewModel'] as Map;
            if (lm['title'] is Map) {
              title = (lm['title']['content'] ?? '').toString().trim();
            }
            if (lm['metadata'] is Map &&
                lm['metadata']['contentMetadataViewModel'] is Map) {
              final cm = lm['metadata']['contentMetadataViewModel'] as Map;
              final rows = cm['metadataRows'];
              if (rows is List) {
                final parts = <String>[];
                for (final r in rows) {
                  if (r is Map && r['metadataParts'] is List) {
                    for (final mp in r['metadataParts'] as List) {
                      if (mp is Map && mp['text'] is Map) {
                        final t = (mp['text']['content'] ?? '').toString().trim();
                        if (t.isNotEmpty) parts.add(t);
                      }
                    }
                  }
                }
                if (parts.isNotEmpty) artist = parts.first;
                if (parts.length > 1) views = parts.skip(1).join(' • ');
              }
            }
            if (lm['image'] is Map) {
              _walkJson(lm['image'], (sub) {
                if (chId.isEmpty && sub is Map && sub['browseEndpoint'] is Map) {
                  final bid = (sub['browseEndpoint']['browseId'] ?? '').toString();
                  if (bid.startsWith('UC')) chId = bid;
                }
              });
            }
          }

          if (lvm['contentImage'] is Map) {
            thumb = _bestThumb(lvm['contentImage']);
            _walkJson(lvm['contentImage'], (sub) {
              if (durStr.isEmpty && sub is Map && sub['thumbnailOverlayBadgeViewModel'] is Map) {
                _walkJson(sub, (b) {
                  if (durStr.isEmpty && b is Map && b['text'] is String) {
                    final s = b['text'].toString().trim();
                    if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(s)) durStr = s;
                  }
                });
              }
            });
          }

          if (title.isNotEmpty) {
            out.add(NamiYtTrack(
              videoId: cid,
              title: title,
              artist: artist.isNotEmpty ? artist : 'YouTube',
              channelId: chId,
              duration: _parseDuration(durStr),
              thumbnailUrl: thumb.isNotEmpty
                  ? thumb
                  : 'https://i.ytimg.com/vi/$cid/hqdefault.jpg',
              viewsText: views,
            ));
          }
        }
      }

      // 2. Classic `videoRenderer`, `compactVideoRenderer`, `playlistPanelVideoRenderer`
      final vr = node['videoRenderer'] ??
          node['compactVideoRenderer'] ??
          node['playlistPanelVideoRenderer'];
      if (vr is Map) {
        final vid = (vr['videoId'] ?? '').toString();
        if (vid.length >= 8 && seen.add(vid)) {
          final title = _readText(vr['title']);
          if (title.isNotEmpty) {
            final artist = _readText(vr['longBylineText']).isNotEmpty
                ? _readText(vr['longBylineText'])
                : (_readText(vr['shortBylineText']).isNotEmpty
                    ? _readText(vr['shortBylineText'])
                    : _readText(vr['ownerText']));
            final views = _readText(vr['shortViewCountText']).isNotEmpty
                ? _readText(vr['shortViewCountText'])
                : _readText(vr['viewCountText']);
            final pub = _readText(vr['publishedTimeText']);
            final durStr = _readText(vr['lengthText']);
            String chId = '';
            _walkJson(vr['longBylineText'] ?? vr['shortBylineText'], (sub) {
              if (chId.isEmpty && sub is Map && sub['browseEndpoint'] is Map) {
                final bid = (sub['browseEndpoint']['browseId'] ?? '').toString();
                if (bid.startsWith('UC')) chId = bid;
              }
            });
            out.add(NamiYtTrack(
              videoId: vid,
              title: title,
              artist: artist.isNotEmpty ? artist : 'YouTube',
              channelId: chId,
              duration: _parseDuration(durStr),
              thumbnailUrl: _bestThumb(vr['thumbnail']).isNotEmpty
                  ? _bestThumb(vr['thumbnail'])
                  : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
              viewsText: [if (views.isNotEmpty) views, if (pub.isNotEmpty) pub].join(' • '),
            ));
          }
        }
      }
    });
  }

static String _preferredFastClient = '';
  final Map<String, NamiYtMediaBundle> _bundleCache = {};
  final Map<String, String> _commentsTokenCache = {};
  final Map<String, String> _descriptionCache = {};
  final Map<String, String> _exactDateCache = {};

  String cachedDescriptionFor(String videoId) => _descriptionCache[videoId] ?? '';
  String cachedExactDateFor(String videoId) => _exactDateCache[videoId] ?? '';
  String cachedCommentsTokenFor(String videoId) => _commentsTokenCache[videoId] ?? '';
  List<NamiYtVideoFormat> cachedVideoFormatsFor(String videoId) =>
      _bundleCache[videoId]?.videoFormats ?? const [];

  /// Fast Parallel Media Resolver (`v3.5.0`):
  /// - Races 6 InnerTube clients (`VISIONOS`, `WEB_EMBED`, `TVHTML5_EMBED`, `IOS`, `ANDROID_SDKLESS`, `ANDROID_VR`)
  /// - Pass 1: Prefers full-length tail-verified streams or HLS `.m3u8` (zero 30s cutoff!)
  /// - Pass 2: Falls back cleanly to head-verified stream (with mid-stream 403 auto-heal)
  /// - Pass 3: Native Chromium Headless BotGuard Extractor (captures BOTH audio + video!)
  /// - ALWAYS populates `lastResolveDiagnostic` on failure so errors are 100% transparent.
  Future<NamiYtMediaBundle?> resolveMediaBundle(
    String videoId, {
    String quality = 'High (Opus)',
    String region = 'IN',
    bool forceRefresh = false,
    Set<String> excludeClients = const <String>{},
  }) async {
    final cached = _bundleCache[videoId];
    if (!forceRefresh &&
        cached != null &&
        !cached.audioStream.isExpired &&
        !excludeClients.contains(cached.audioStream.clientUsed)) {
      return cached;
    }

    final (gl, hl) = _regionLocale(region);
    final visitorData = await _ensureVisitorData();
    final cookie = _effectiveCookie;
    final hasCookie = cookie.isNotEmpty;
    final authHdr = hasCookie ? _buildSapisidAuthHeader(cookie) : null;
    final diag = <String>[];

    const safariUa =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15';
    const androidUa =
        'com.google.android.youtube/20.10.38 (Linux; U; Android 14; en_IN) gzip';
    const vr171Ua =
        'com.google.android.apps.youtube.vr.oculus/1.71.26 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

    Map<String, dynamic> withVisitor(Map<String, dynamic> obj) => {
          ...obj,
          if (visitorData.isNotEmpty) 'visitorData': visitorData,
        };

    final allClients = <Map<String, dynamic>>[
      {
        'name': 'VISIONOS',
        'ua': safariUa,
        'hdr': '101',
        'ver': '1.02',
        'ctx': {
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
        'name': 'WEB_EMBED',
        'ua': safariUa,
        'hdr': '56',
        'ver': '1.20260310.04.00',
        'ctx': {
          'client': withVisitor({
            'clientName': 'WEB_EMBEDDED_PLAYER',
            'clientVersion': '1.20260310.04.00',
            'gl': gl,
            'hl': hl,
          }),
          'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
        },
      },
      {
        'name': 'TVHTML5_EMBED',
        'ua': _webUserAgent,
        'hdr': '85',
        'ver': '2.0',
        'ctx': {
          'client': withVisitor({
            'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
            'clientVersion': '2.0',
            'gl': gl,
            'hl': hl,
          }),
          'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
        },
      },
      {
        'name': 'IOS',
        'ua': _iosUserAgent,
        'hdr': '5',
        'ver': '20.10.4',
        'ctx': {
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
        'hdr': '3',
        'ver': '20.10.38',
        'ctx': {
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
        'name': 'ANDROID_VR',
        'ua': vr171Ua,
        'hdr': '28',
        'ver': '1.71.26',
        'ctx': {
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
    ];

    final headOnlyFallbacks = <NamiYtMediaBundle>[];

    Future<NamiYtMediaBundle?> tryClient(Map<String, dynamic> c) async {
      final cname = c['name'] as String;
      if (excludeClients.contains(cname)) return null;
      try {
        final ua = c['ua'] as String;
        final resp = await http
            .post(
              Uri.parse('$_ytApiBase/player?prettyPrint=false'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': ua,
                'Origin': 'https://www.youtube.com',
                'X-YouTube-Client-Name': c['hdr'] as String,
                'X-YouTube-Client-Version': c['ver'] as String,
                if (visitorData.isNotEmpty) 'X-Goog-Visitor-Id': visitorData,
                if (hasCookie) 'Cookie': cookie,
                if (authHdr != null) 'Authorization': authHdr,
              },
              body: jsonEncode({
                'videoId': videoId,
                'context': c['ctx'],
                'contentCheckOk': true,
                'racyCheckOk': true,
              }),
            )
            .timeout(const Duration(milliseconds: 4200));
        if (resp.statusCode != 200) {
          diag.add('$cname:h${resp.statusCode}');
          return null;
        }
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final psMap = json['playabilityStatus'];
        final pStatus = (psMap is Map ? (psMap['status'] ?? '') : '').toString();
        final sd = json['streamingData'];
        if (sd is! Map<String, dynamic>) {
          diag.add('$cname:${pStatus.isNotEmpty ? pStatus : 'noSD'}');
          return null;
        }

        final vd = json['videoDetails'];
        final durSec = int.tryParse(
              (vd is Map ? (vd['lengthSeconds'] ?? '0') : '0').toString(),
            ) ??
            0;
        if (vd is Map && (vd['shortDescription'] ?? '').toString().isNotEmpty) {
          _descriptionCache[videoId] = vd['shortDescription'].toString();
        }
        final mf = json['microformat'];
        if (mf is Map && mf['playerMicroformatRenderer'] is Map) {
          final pm = mf['playerMicroformatRenderer'] as Map;
          final pd = (pm['publishDate'] ?? pm['uploadDate'] ?? '').toString();
          if (pd.isNotEmpty) _exactDateCache[videoId] = pd;
        }

        final streamHeaders = <String, String>{
          'User-Agent': ua,
          if (hasCookie) 'Cookie': cookie,
        };

        final audioFormats = <Map<String, dynamic>>[];
        final videoMap = <int, NamiYtVideoFormat>{};
        final adaptive = sd['adaptiveFormats'];
        if (adaptive is List) {
          for (final f in adaptive) {
            if (f is! Map<String, dynamic>) continue;
            final mime = (f['mimeType'] ?? '').toString();
            final url = (f['url'] ?? '').toString();
            if (!url.startsWith('http')) continue;
            if (mime.startsWith('audio/')) {
              audioFormats.add(f);
            } else if (mime.startsWith('video/mp4') || mime.startsWith('video/webm')) {
              final h = (f['height'] as num?)?.toInt() ?? 0;
              if (h <= 0) continue;
              final br = (f['bitrate'] as num?)?.toInt() ?? 0;
              final fps = (f['fps'] as num?)?.toInt() ?? 30;
              final cl = int.tryParse((f['contentLength'] ?? '').toString()) ?? 0;
              final ql = (f['qualityLabel'] ?? '${h}p').toString();
              final isMp4 = mime.startsWith('video/mp4');
              final prev = videoMap[h];
              if (prev == null ||
                  (isMp4 && !prev.mimeType.startsWith('video/mp4')) ||
                  (isMp4 == prev.mimeType.startsWith('video/mp4') && br > prev.bitrate)) {
                videoMap[h] = NamiYtVideoFormat(
                  itag: (f['itag'] as num?)?.toInt() ?? 0,
                  qualityLabel: ql,
                  height: h,
                  fps: fps,
                  bitrate: br,
                  contentLength: cl,
                  mimeType: mime.split(';').first.trim(),
                  url: url,
                  headers: streamHeaders,
                );
              }
            }
          }
        }
        if (sd['formats'] is List) {
          for (final f in sd['formats'] as List) {
            if (f is! Map<String, dynamic>) continue;
            final url = (f['url'] ?? '').toString();
            if (!url.startsWith('http')) continue;
            if (audioFormats.isEmpty) audioFormats.add(f);
            final h = (f['height'] as num?)?.toInt() ?? 360;
            if (!videoMap.containsKey(h)) {
              videoMap[h] = NamiYtVideoFormat(
                itag: (f['itag'] as num?)?.toInt() ?? 18,
                qualityLabel: (f['qualityLabel'] ?? '${h}p').toString(),
                height: h,
                fps: (f['fps'] as num?)?.toInt() ?? 30,
                bitrate: (f['bitrate'] as num?)?.toInt() ?? 500000,
                contentLength: int.tryParse((f['contentLength'] ?? '').toString()) ?? 0,
                mimeType: 'video/mp4',
                url: url,
                headers: streamHeaders,
              );
            }
          }
        }

        final sortedVideos = videoMap.values.toList()
          ..sort((a, b) => b.height.compareTo(a.height));

        // 1. Check HLS manifest first on VISIONOS/IOS (zero 30s cutoff!)
        final hlsUrl = (sd['hlsManifestUrl'] ?? '').toString();
        if (hlsUrl.startsWith('http') &&
            !excludeClients.contains('${cname}_HLS') &&
            await _probeStreamUrl(hlsUrl, streamHeaders)) {
          final audio = NamiYtStreamResult(
            videoId: videoId,
            audioUrl: hlsUrl,
            mimeType: 'application/x-mpegURL',
            bitrate: 128000,
            duration: Duration(seconds: durSec),
            headers: streamHeaders,
            expiresAtMs: DateTime.now()
                .add(const Duration(hours: 2, minutes: 30))
                .millisecondsSinceEpoch,
            clientUsed: '${cname}_HLS',
          );
          return NamiYtMediaBundle(
            audioStream: audio,
            videoFormats: sortedVideos,
            duration: Duration(seconds: durSec),
          );
        }

        // 2. Check adaptive audio with full-length tail probe first; keep head-only as backup
        if (audioFormats.isNotEmpty) {
          final picked = _pickStreamByQuality(audioFormats, quality);
          final candUrl = picked['url'].toString();
          final cl = int.tryParse((picked['contentLength'] ?? '').toString()) ?? 0;
          final audio = NamiYtStreamResult(
            videoId: videoId,
            audioUrl: candUrl,
            mimeType: (picked['mimeType'] ?? 'audio/mp4').toString(),
            bitrate: (picked['bitrate'] as num?)?.toInt() ?? 128000,
            duration: Duration(seconds: durSec),
            headers: {
              ...streamHeaders,
              if (cl > 0) 'X-Nami-Content-Length': '$cl',
            },
            expiresAtMs: DateTime.now()
                .add(const Duration(hours: 3, minutes: 30))
                .millisecondsSinceEpoch,
            clientUsed: cname,
          );
          if (await _probeStreamUrl(candUrl, streamHeaders, contentLength: cl)) {
            return NamiYtMediaBundle(
              audioStream: audio,
              videoFormats: sortedVideos,
              duration: Duration(seconds: durSec),
            );
          }
          if (await _probeStreamUrl(candUrl, streamHeaders, contentLength: 0)) {
            headOnlyFallbacks.add(NamiYtMediaBundle(
              audioStream: audio,
              videoFormats: sortedVideos,
              duration: Duration(seconds: durSec),
            ));
          }
          diag.add('$cname:403');
        } else {
          diag.add('$cname:noUrl');
        }
      } catch (_) {
        diag.add('$cname:err');
      }
      return null;
    }

    // 1. Sticky winner fast-path
    if (_preferredFastClient.startsWith('WEBVIEW') &&
        !excludeClients.contains('WEBVIEW_BOTGUARD')) {
      final wvRes = await _extractViaNativeWebView(videoId);
      if (wvRes != null) {
        final bundle = NamiYtMediaBundle(
          audioStream: wvRes,
          videoFormats: _lastWebViewVideoFormats[videoId] ?? const [],
          duration: wvRes.duration,
        );
        _bundleCache[videoId] = bundle;
        _streamCache['$videoId|$quality'] = wvRes;
        lastResolveDiagnostic = '';
        return bundle;
      }
    }

    // 2. Parallel race across all 6 InnerTube clients (VISIONOS first!)
    final raceResults = await Future.wait<NamiYtMediaBundle?>(
      allClients.map(tryClient),
    );
    for (final b in raceResults) {
      if (b != null) {
        _preferredFastClient = b.audioStream.clientUsed;
        _bundleCache[videoId] = b;
        _streamCache['$videoId|$quality'] = b.audioStream;
        lastResolveDiagnostic = '';
        return b;
      }
    }

    // 3. Native Chromium Headless BotGuard Extractor (Logged-Out OR Signed-In, Audio + Video!)
    if (!excludeClients.contains('WEBVIEW_BOTGUARD') &&
        !excludeClients.contains('WEBVIEW_AUTH')) {
      final wvRes = await _extractViaNativeWebView(videoId);
      if (wvRes != null) {
        _preferredFastClient = wvRes.clientUsed;
        final bundle = NamiYtMediaBundle(
          audioStream: wvRes,
          videoFormats: _lastWebViewVideoFormats[videoId] ?? const [],
          duration: wvRes.duration,
        );
        _bundleCache[videoId] = bundle;
        _streamCache['$videoId|$quality'] = wvRes;
        lastResolveDiagnostic = '';
        return bundle;
      }
      diag.add('WV:miss');
    }

    // 4. Graceful fallback: if we captured a head-verified stream, return it with mid-stream 403 auto-heal!
    if (headOnlyFallbacks.isNotEmpty) {
      final b = headOnlyFallbacks.first;
      _bundleCache[videoId] = b;
      _streamCache['$videoId|$quality'] = b.audioStream;
      lastResolveDiagnostic = '';
      return b;
    }

    lastResolveDiagnostic = diag.join(' ');
    debugPrint('[NamiYT] resolveMediaBundle failed for $videoId: $lastResolveDiagnostic');
    return null;
  }

  final Map<String, List<NamiYtVideoFormat>> _lastWebViewVideoFormats = {};

  /// Fetches real YouTube Comments (2026 `frameworkUpdates.entityBatchUpdate.mutations` ViewModel
  /// AND legacy `commentRenderer` dual parser), with `Top` / `Newest` sort tokens & pagination.
  Future<NamiYtCommentsPage> fetchVideoComments(
    String videoId, {
    String? continuationToken,
    String region = 'IN',
  }) async {
    try {
      String token = continuationToken ?? (_commentsTokenCache[videoId] ?? '');
      String? topToken;
      String? newestToken;
      String totalCountText = '';

      // Step 1: If no continuation token cached yet, pull it from `/youtubei/v1/next`
      if (token.isEmpty) {
        final r0 = await http
            .post(
              Uri.parse('$_ytApiBase/next?prettyPrint=false'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': _webUserAgent,
                if (_effectiveCookie.isNotEmpty) 'Cookie': _effectiveCookie,
              },
              body: jsonEncode({
                'videoId': videoId,
                'context': _webContext(region),
              }),
            )
            .timeout(const Duration(seconds: 7));
        if (r0.statusCode == 200) {
          final j0 = jsonDecode(r0.body);
          _walkJson(j0, (node) {
            if (node is! Map) return;
            if (token.isEmpty && node['itemSectionRenderer'] is Map) {
              final sec = node['itemSectionRenderer'] as Map;
              final targetId = (sec['targetId'] ?? sec['sectionIdentifier'] ?? '').toString();
              if (targetId.contains('comment')) {
                _walkJson(sec, (sub) {
                  if (token.isEmpty && sub is Map && sub['continuationCommand'] is Map) {
                    final t = (sub['continuationCommand']['token'] ?? '').toString();
                    if (t.isNotEmpty) token = t;
                  }
                });
              }
            }
            if (token.isEmpty && node['engagementPanelSectionListRenderer'] is Map) {
              final ep = node['engagementPanelSectionListRenderer'] as Map;
              final pid = (ep['panelIdentifier'] ?? '').toString();
              if (pid.contains('comment')) {
                _walkJson(ep, (sub) {
                  if (token.isEmpty && sub is Map && sub['continuationCommand'] is Map) {
                    final t = (sub['continuationCommand']['token'] ?? '').toString();
                    if (t.isNotEmpty) token = t;
                  }
                });
              }
            }
          });
          if (token.isNotEmpty) _commentsTokenCache[videoId] = token;
        }
      }

      if (token.isEmpty) {
        return const NamiYtCommentsPage(comments: []);
      }

      // Step 2: Fetch comments page using the continuation token
      final resp = await http
          .post(
            Uri.parse('$_ytApiBase/next?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _webUserAgent,
              if (_effectiveCookie.isNotEmpty) 'Cookie': _effectiveCookie,
            },
            body: jsonEncode({
              'continuation': token,
              'context': _webContext(region),
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        return const NamiYtCommentsPage(comments: []);
      }
      final root = jsonDecode(resp.body);

      // Build lookup map of 2026 ViewModel `commentEntityPayload` & `engagementToolbarStateEntityPayload`
      final payloadByKey = <String, Map>{};
      final toolbarByKey = <String, Map>{};
      _walkJson(root, (node) {
        if (node is! Map) return;
        if (node['entityKey'] != null && node['payload'] is Map) {
          final key = node['entityKey'].toString();
          final payload = node['payload'] as Map;
          if (payload['commentEntityPayload'] is Map) {
            payloadByKey[key] = payload['commentEntityPayload'] as Map;
          }
          if (payload['engagementToolbarStateEntityPayload'] is Map) {
            toolbarByKey[key] = payload['engagementToolbarStateEntityPayload'] as Map;
          }
        }
        // Extract Top / Newest sort continuation tokens & comment count
        if (node['commentsHeaderRenderer'] is Map) {
          final hdr = node['commentsHeaderRenderer'] as Map;
          final cnt = _readText(hdr['countText']);
          if (cnt.isNotEmpty) totalCountText = cnt;
          _walkJson(hdr['sortMenu'], (sm) {
            if (sm is Map && sm['subMenuItems'] is List) {
              for (final it in sm['subMenuItems'] as List) {
                if (it is Map) {
                  final title = (it['title'] ?? '').toString().toLowerCase();
                  final se = it['serviceEndpoint'];
                  final cont = (se is Map && se['continuationCommand'] is Map)
                      ? (se['continuationCommand']['token'] ?? '').toString()
                      : '';
                  if (cont.isNotEmpty) {
                    if (title.contains('top')) topToken = cont;
                    if (title.contains('new')) newestToken = cont;
                  }
                }
              }
            }
          });
        }
      });

      final comments = <NamiYtComment>[];
      final seenIds = <String>{};
      String? nextCont;

      _walkJson(root, (node) {
        if (node is! Map) return;

        // A. 2026 Comment Thread Renderer (ViewModel + mutations join)
        if (node['commentThreadRenderer'] is Map) {
          final tr = node['commentThreadRenderer'] as Map;
          String? replyCont;
          if (tr['replies'] is Map) {
            _walkJson(tr['replies'], (rn) {
              if (replyCont == null && rn is Map && rn['continuationCommand'] is Map) {
                final t = (rn['continuationCommand']['token'] ?? '').toString();
                if (t.isNotEmpty) replyCont = t;
              }
            });
          }

          final cvm = tr['commentViewModel'] is Map
              ? (tr['commentViewModel']['commentViewModel'] ?? tr['commentViewModel'])
              : null;
          if (cvm is Map) {
            final cKey = (cvm['commentKey'] ?? '').toString();
            final payload = payloadByKey[cKey];
            if (payload != null) {
              final props = payload['properties'] is Map ? payload['properties'] as Map : const {};
              final authorMap = payload['author'] is Map ? payload['author'] as Map : const {};
              final toolbar = payload['toolbar'] is Map ? payload['toolbar'] as Map : const {};
              final cid = (props['commentId'] ?? cKey).toString();
              final text = (props['content'] is Map ? (props['content']['content'] ?? '') : '').toString().trim();
              if (text.isNotEmpty && seenIds.add(cid)) {
                final replyStr = (toolbar['replyCount'] ?? '').toString().trim();
                final replyNum = int.tryParse(replyStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                comments.add(NamiYtComment(
                  id: cid,
                  author: (authorMap['displayName'] ?? 'User').toString(),
                  authorAvatarUrl: (authorMap['avatarThumbnailUrl'] ?? '').toString(),
                  authorChannelId: (authorMap['channelId'] ?? '').toString(),
                  text: text,
                  publishedText: (props['publishedTime'] ?? '').toString(),
                  likesText: (toolbar['likeCountNotliked'] ?? toolbar['likeCountLiked'] ?? '').toString().trim(),
                  replyCount: replyNum,
                  replyCountText: replyStr,
                  repliesContinuation: replyCont,
                  isPinned: tr['commentViewModel'] is Map &&
                      (tr['commentViewModel']['pinnedText'] ?? '').toString().isNotEmpty,
                  isHearted: (toolbar['heartActiveTooltip'] ?? '').toString().isNotEmpty,
                ));
              }
            }
          } else if (tr['comment'] is Map && tr['comment']['commentRenderer'] is Map) {
            final cr = tr['comment']['commentRenderer'] as Map;
            final cid = (cr['commentId'] ?? '').toString();
            final text = _readText(cr['contentText']);
            if (text.isNotEmpty && seenIds.add(cid)) {
              final rc = (cr['replyCount'] as num?)?.toInt() ?? 0;
              comments.add(NamiYtComment(
                id: cid,
                author: _readText(cr['authorText']),
                authorAvatarUrl: _bestThumb(cr['authorThumbnail']),
                text: text,
                publishedText: _readText(cr['publishedTimeText']),
                likesText: _readText(cr['voteCount']),
                replyCount: rc,
                replyCountText: rc > 0 ? '$rc' : '',
                repliesContinuation: replyCont,
                isPinned: cr['pinnedCommentBadge'] != null,
              ));
            }
          }
        }

        // B. Direct reply items (`commentRenderer` or standalone `commentViewModel` inside replies)
        if (node['commentRenderer'] is Map && node['commentThreadRenderer'] == null) {
          final cr = node['commentRenderer'] as Map;
          final cid = (cr['commentId'] ?? '').toString();
          final text = _readText(cr['contentText']);
          if (cid.isNotEmpty && text.isNotEmpty && seenIds.add(cid)) {
            comments.add(NamiYtComment(
              id: cid,
              author: _readText(cr['authorText']),
              authorAvatarUrl: _bestThumb(cr['authorThumbnail']),
              text: text,
              publishedText: _readText(cr['publishedTimeText']),
              likesText: _readText(cr['voteCount']),
            ));
          }
        }

        // C. Next-page continuation item
        if (node['continuationItemRenderer'] is Map) {
          final cir = node['continuationItemRenderer'] as Map;
          final ep = cir['continuationEndpoint'];
          if (ep is Map && ep['continuationCommand'] is Map) {
            final t = (ep['continuationCommand']['token'] ?? '').toString();
            if (t.isNotEmpty && t != token) nextCont = t;
          }
        }
      });

      // Fallback: if ViewModel replies arrived only in payloadByKey without commentThreadRenderer
      if (comments.isEmpty && payloadByKey.isNotEmpty) {
        for (final entry in payloadByKey.entries) {
          final payload = entry.value;
          final props = payload['properties'] is Map ? payload['properties'] as Map : const {};
          final authorMap = payload['author'] is Map ? payload['author'] as Map : const {};
          final toolbar = payload['toolbar'] is Map ? payload['toolbar'] as Map : const {};
          final cid = (props['commentId'] ?? entry.key).toString();
          final text = (props['content'] is Map ? (props['content']['content'] ?? '') : '').toString().trim();
          if (text.isNotEmpty && seenIds.add(cid)) {
            comments.add(NamiYtComment(
              id: cid,
              author: (authorMap['displayName'] ?? 'User').toString(),
              authorAvatarUrl: (authorMap['avatarThumbnailUrl'] ?? '').toString(),
              authorChannelId: (authorMap['channelId'] ?? '').toString(),
              text: text,
              publishedText: (props['publishedTime'] ?? '').toString(),
              likesText: (toolbar['likeCountNotliked'] ?? '').toString().trim(),
            ));
          }
        }
      }

      return NamiYtCommentsPage(
        comments: comments,
        nextContinuation: nextCont,
        topSortToken: topToken,
        newestSortToken: newestToken,
        totalCountText: totalCountText,
      );
    } catch (e) {
      debugPrint('[NamiYT] fetchVideoComments error: $e');
      return const NamiYtCommentsPage(comments: []);
    }
  }

  /// Fetches full YouTube Channel Detail (Banner, Avatar, Subs, Home shelves & Videos/Shorts/Releases/Playlists tab tokens).
  Future<NamiYtChannelDetails> fetchChannelDetails(
    String channelId, {
    String fallbackName = '',
    String fallbackAvatar = '',
    String region = 'IN',
  }) async {
    String name = fallbackName;
    String handle = '';
    String avatarUrl = fallbackAvatar;
    String bannerUrl = '';
    String subsText = '';
    String videoCountText = '';
    String description = '';
    String? videosParams;
    String? shortsParams;
    String? releasesParams;
    String? playlistsParams;
    final homeShelves = <NamiYtChannelShelf>[];
    final videos = <NamiYtTrack>[];

    try {
      final resp = await http
          .post(
            Uri.parse('$_ytApiBase/browse?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _webUserAgent,
              if (_effectiveCookie.isNotEmpty) 'Cookie': _effectiveCookie,
            },
            body: jsonEncode({
              'browseId': channelId,
              'context': _webContext(region),
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final root = jsonDecode(resp.body);
        _walkJson(root, (node) {
          if (node is! Map) return;

          // Legacy c4TabbedHeaderRenderer
          if (node['c4TabbedHeaderRenderer'] is Map) {
            final h = node['c4TabbedHeaderRenderer'] as Map;
            final t = (h['title'] ?? '').toString();
            if (t.isNotEmpty) name = t;
            final av = _bestThumb(h['avatar']);
            if (av.isNotEmpty) avatarUrl = av;
            final bn = _bestThumb(h['banner']);
            if (bn.isNotEmpty) bannerUrl = bn;
            final sub = _readText(h['subscriberCountText']);
            if (sub.isNotEmpty) subsText = sub;
            final vc = _readText(h['videosCountText']);
            if (vc.isNotEmpty) videoCountText = vc;
          }

          // 2026 pageHeaderViewModel
          if (node['pageHeaderViewModel'] is Map) {
            final vm = node['pageHeaderViewModel'] as Map;
            if (vm['title'] is Map) {
              final dt = vm['title']['dynamicTextViewModel'];
              final txt = (dt is Map && dt['text'] is Map) ? (dt['text']['content'] ?? '').toString() : '';
              if (txt.isNotEmpty) name = txt;
            }
            if (vm['banner'] is Map) {
              final b = _bestThumb(vm['banner']);
              if (b.isNotEmpty) bannerUrl = b;
            }
            if (vm['image'] is Map) {
              final av = _bestThumb(vm['image']);
              if (av.isNotEmpty) avatarUrl = av;
            }
            if (vm['metadata'] is Map) {
              _walkJson(vm['metadata'], (m) {
                if (m is Map && m['content'] is String) {
                  final s = m['content'].toString();
                  if (s.startsWith('@')) handle = s;
                  if (s.toLowerCase().contains('subscriber')) subsText = s;
                  if (s.toLowerCase().contains('video')) videoCountText = s;
                }
              });
            }
            if (vm['description'] is Map) {
              _walkJson(vm['description'], (d) {
                if (description.isEmpty && d is Map && d['content'] is String) {
                  description = d['content'].toString();
                }
              });
            }
          }

          // Metadata description fallback
          if (node['channelMetadataRenderer'] is Map) {
            final cm = node['channelMetadataRenderer'] as Map;
            if (name.isEmpty && (cm['title'] ?? '').toString().isNotEmpty) {
              name = cm['title'].toString();
            }
            if (description.isEmpty && (cm['description'] ?? '').toString().isNotEmpty) {
              description = cm['description'].toString();
            }
            if (avatarUrl.isEmpty) {
              final av = _bestThumb(cm['avatar']);
              if (av.isNotEmpty) avatarUrl = av;
            }
          }

          // Channel Tabs (`Videos`, `Shorts`, `Releases`, `Playlists`)
          if (node['tabRenderer'] is Map) {
            final tr = node['tabRenderer'] as Map;
            final title = (tr['title'] ?? '').toString().toLowerCase();
            final ep = tr['endpoint'];
            final params = (ep is Map && ep['browseEndpoint'] is Map)
                ? (ep['browseEndpoint']['params'] ?? '').toString()
                : '';
            if (params.isNotEmpty) {
              if (title == 'videos') videosParams = params;
              if (title == 'shorts') shortsParams = params;
              if (title == 'releases') releasesParams = params;
              if (title == 'playlists') playlistsParams = params;
            }
          }

          // Home Shelves (`shelfRenderer` / `reelShelfRenderer`)
          if (node['shelfRenderer'] is Map) {
            final sr = node['shelfRenderer'] as Map;
            final stitle = _readText(sr['title']);
            final items = <NamiYtTrack>[];
            final seen = <String>{};
            _extractVideoRenderers(sr['content'], items, seen, 20);
            if (items.isNotEmpty) {
              homeShelves.add(NamiYtChannelShelf(
                title: stitle.isNotEmpty ? stitle : 'Featured',
                items: items,
              ));
              for (final it in items) {
                if (!videos.any((v) => v.videoId == it.videoId)) videos.add(it);
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[NamiYT] fetchChannelDetails error: $e');
    }

    return NamiYtChannelDetails(
      channelId: channelId,
      name: name.isNotEmpty ? name : 'YouTube Channel',
      handle: handle,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      subscriberText: subsText,
      videoCountText: videoCountText,
      description: description,
      homeShelves: homeShelves,
      videos: videos,
      videosTabParams: videosParams,
      shortsTabParams: shortsParams,
      releasesTabParams: releasesParams,
      playlistsTabParams: playlistsParams,
    );
  }

  /// Loads a specific Channel Tab (`Videos`, `Shorts`, `Releases`, `Playlists`) via `/youtubei/v1/browse`.
  Future<List<NamiYtTrack>> fetchChannelTabVideos(
    String channelId,
    String? tabParams, {
    String channelName = '',
    String region = 'IN',
  }) async {
    final out = <NamiYtTrack>[];
    final seen = <String>{};
    try {
      final resp = await http
          .post(
            Uri.parse('$_ytApiBase/browse?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _webUserAgent,
              if (_effectiveCookie.isNotEmpty) 'Cookie': _effectiveCookie,
            },
            body: jsonEncode({
              'browseId': channelId,
              if (tabParams != null && tabParams.isNotEmpty) 'params': tabParams,
              'context': _webContext(region),
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final root = jsonDecode(resp.body);
        _extractVideoRenderers(root, out, seen, 60);
        // Also pick up richItemRenderer / gridVideoRenderer / lockupViewModel items
        _walkJson(root, (node) {
          if (node is! Map) return;
          for (final rk in const ['gridVideoRenderer', 'playlistVideoRenderer', 'reelItemRenderer']) {
            if (node[rk] is Map) {
              final vr = node[rk] as Map;
              final vid = (vr['videoId'] ?? '').toString();
              if (vid.isEmpty || !seen.add(vid)) continue;
              final title = _readText(vr['title']).isNotEmpty
                  ? _readText(vr['title'])
                  : _readText(vr['headline']);
              if (title.isEmpty) continue;
              final views = _readText(vr['shortViewCountText']).isNotEmpty
                  ? _readText(vr['shortViewCountText'])
                  : _readText(vr['viewCountText']);
              final pub = _readText(vr['publishedTimeText']);
              final durStr = _readText(vr['lengthText']);
              out.add(NamiYtTrack(
                videoId: vid,
                title: title,
                artist: channelName.isNotEmpty ? channelName : _readText(vr['shortBylineText']),
                channelId: channelId,
                duration: _parseDuration(durStr),
                thumbnailUrl: _bestThumb(vr['thumbnail']).isNotEmpty
                    ? _bestThumb(vr['thumbnail'])
                    : 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
                viewsText: [if (views.isNotEmpty) views, if (pub.isNotEmpty) pub].join(' • '),
              ));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[NamiYT] fetchChannelTabVideos error: $e');
    }
    return out;
  }


/// Live YouTube Search Autocomplete (exact same suggestion engine as YouTube search bar!).
  Future<List<String>> fetchYoutubeAutocomplete(
    String query, {
    String region = 'IN',
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final (gl, hl) = _regionLocale(region);
    for (final base in const [
      'https://suggestqueries-clients6.youtube.com/complete/search',
      'https://suggestqueries.google.com/complete/search',
    ]) {
      try {
        final uri = Uri.parse(
          '$base?client=firefox&ds=yt&hl=$hl&gl=$gl&q=${Uri.encodeQueryComponent(q)}',
        );
        final resp = await http
            .get(uri, headers: const {'User-Agent': _webUserAgent})
            .timeout(const Duration(seconds: 4));
        if (resp.statusCode != 200) continue;
        final parsed = jsonDecode(resp.body);
        if (parsed is List && parsed.length >= 2 && parsed[1] is List) {
          final out = <String>[];
          for (final item in parsed[1] as List) {
            final s = (item is List && item.isNotEmpty)
                ? item.first.toString().trim()
                : item.toString().trim();
            if (s.isNotEmpty && !out.contains(s)) out.add(s);
          }
          if (out.isNotEmpty) return out.take(12).toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  /// Full YouTube Search (`All | Videos | Songs | Channels | Shorts`):
  /// Returns videos, channels, and post-search related suggestion chips!
  Future<Map<String, dynamic>> searchYoutubeFull(
    String query, {
    String filter = 'All',
    String region = 'IN',
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const {
        'tracks': <NamiYtTrack>[],
        'channels': <NamiYtChannel>[],
        'relatedQueries': <String>[],
      };
    }

    // YouTube InnerTube search filter params (`sp`)
    String? spParam;
    if (filter == 'Videos') spParam = 'EgIQAQ%3D%3D';
    if (filter == 'Channels') spParam = 'EgIQAg%3D%3D';
    if (filter == 'Shorts') spParam = 'EgIYAQ%3D%3D';

    final tracks = <NamiYtTrack>[];
    final channels = <NamiYtChannel>[];
    final seenVids = <String>{};
    final seenChs = <String>{};
    final relQueries = <String>[];

    // Fetch live related autocomplete suggestions in parallel!
    final suggestFut = fetchYoutubeAutocomplete(q, region: region);

    if (filter == 'Songs') {
      final songs = await searchMusic(q, region: region, limit: 24);
      tracks.addAll(songs);
    } else {
      try {
        final resp = await http
            .post(
              Uri.parse('$_ytApiBase/search?prettyPrint=false'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': _webUserAgent,
                if (_effectiveCookie.isNotEmpty) 'Cookie': _effectiveCookie,
              },
              body: jsonEncode({
                'query': q,
                if (spParam != null) 'params': Uri.decodeComponent(spParam),
                'context': _webContext(region),
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final root = jsonDecode(resp.body);
          _extractVideoRenderers(root, tracks, seenVids, 28);
          _walkJson(root, (node) {
            if (node is! Map) return;
            if (node['channelRenderer'] is Map) {
              final cr = node['channelRenderer'] as Map;
              final cid = (cr['channelId'] ?? '').toString();
              final name = _readText(cr['title']);
              if (cid.isNotEmpty && name.isNotEmpty && seenChs.add(cid)) {
                final sub = _readText(cr['videoCountText']).isNotEmpty
                    ? _readText(cr['videoCountText'])
                    : _readText(cr['subscriberCountText']);
                channels.add(NamiYtChannel(
                  channelId: cid,
                  name: name,
                  avatarUrl: _bestThumb(cr['thumbnail']),
                  subscriberText: sub,
                  subscribedAtMs: 0,
                ));
              }
            }
            if (node['searchRefinementCardRenderer'] is Map) {
              final t = _readText(node['searchRefinementCardRenderer']['query']);
              if (t.isNotEmpty && !relQueries.contains(t)) relQueries.add(t);
            }
          });
        }
      } catch (e) {
        debugPrint('[NamiYT] searchYoutubeFull error: $e');
      }
      // Top-up with YouTube Music results if web search returned sparse results
      if (tracks.length < 6 && filter != 'Channels') {
        final extra = await searchMusic(q, region: region, limit: 16);
        for (final t in extra) {
          if (seenVids.add(t.videoId)) tracks.add(t);
        }
      }
    }

    final autoSuggestions = await suggestFut;
    for (final s in autoSuggestions) {
      if (s.toLowerCase() != q.toLowerCase() && !relQueries.contains(s)) {
        relQueries.add(s);
      }
    }

    return {
      'tracks': tracks,
      'channels': channels,
      'relatedQueries': relQueries.take(10).toList(),
    };
  }

  /// History-Powered Connected YouTube Home Feed (`v3.6.2`):
  /// Builds a dynamic "For You" feed from the user's top recently watched videos, recent search
  /// queries, and cross-library artist taste — zero static generic feed!
  Future<Map<String, List<NamiYtTrack>>> fetchYoutubeHomeFeed({
    String category = 'All',
    String region = 'IN',
    List<NamiYtTrack> recentHistory = const [],
    List<String> recentSearches = const [],
    List<String> tasteArtists = const [],
  }) async {
    final becauseWatched = <NamiYtTrack>[];
    final feedVideos = <NamiYtTrack>[];
    final seen = <String>{};

    // 1. Pull real InnerTube `/next` related clusters from up to 3 recently watched videos in parallel!
    final seedTracks = recentHistory.take(3).toList();
    if (seedTracks.isNotEmpty) {
      for (final s in seedTracks) {
        seen.add(s.videoId);
      }
      final seedBatches = await Future.wait<List<NamiYtTrack>>(
        seedTracks.map(
          (seed) => fetchWatchDetails(seed.videoId, region: region, fetchDislikes: false)
              .then((wd) => wd.relatedTracks)
              .catchError((_) => const <NamiYtTrack>[]),
        ),
      );
      if (seedBatches.isNotEmpty) {
        for (final r in seedBatches.first) {
          if (seen.add(r.videoId)) becauseWatched.add(r);
        }
        // Interleave related videos from recent history #2 & #3 straight into main "For You" feed!
        for (int b = 1; b < seedBatches.length; b++) {
          for (final r in seedBatches[b]) {
            if (seen.add(r.videoId)) feedVideos.add(r);
          }
        }
      }
    }

    // 2. Category or Taste-Seeded Video Feed
    if (category == 'All') {
      final queries = <String>[];
      if (recentSearches.isNotEmpty) {
        queries.add(recentSearches.first);
      }
      if (tasteArtists.isNotEmpty) {
        queries.add('${tasteArtists.take(2).join(' ')} official video');
      }
      if (queries.isNotEmpty) {
        final qBatches = await Future.wait(
          queries.take(2).map((q) => searchYoutubeFull(q, filter: 'Videos', region: region)),
        );
        for (final res in qBatches) {
          final list = (res['tracks'] as List?)?.cast<NamiYtTrack>() ?? const <NamiYtTrack>[];
          for (final t in list) {
            if (seen.add(t.videoId)) feedVideos.add(t);
          }
        }
      }
      // Supplement with live YouTube FEwhat_to_watch browse if still under 14 items
      if (feedVideos.length < 14) {
        try {
          final resp = await http
              .post(
                Uri.parse('$_ytApiBase/browse?prettyPrint=false'),
                headers: {
                  'Content-Type': 'application/json',
                  'User-Agent': _webUserAgent,
                  if (_effectiveCookie.isNotEmpty) 'Cookie': _effectiveCookie,
                },
                body: jsonEncode({
                  'browseId': 'FEwhat_to_watch',
                  'context': _webContext(region),
                }),
              )
              .timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200) {
            final root = jsonDecode(resp.body);
            _extractVideoRenderers(root, feedVideos, seen, 26);
          }
        } catch (_) {}
      }
    }

    if (feedVideos.length < 10) {
      final tasteLead = tasteArtists.isNotEmpty ? tasteArtists.first : '';
      final query = switch (category) {
        'Music' => tasteLead.isNotEmpty
            ? '$tasteLead official music video'
            : (region == 'IN' ? 'latest hindi punjabi dhh music video 2026' : 'top music videos 2026'),
        'Trending' => region == 'IN' ? 'trending india videos 2026' : 'trending videos 2026',
        'Podcasts' => region == 'IN' ? 'indian podcast full episode 2026' : 'popular podcast full episode',
        'Gaming' => 'gaming highlights 2026',
        _ => tasteLead.isNotEmpty
            ? '$tasteLead music video'
            : (region == 'IN' ? 'trending bollywood punjabi dhh official music video 2026' : 'trending music videos 2026'),
      };
      final fallback = await searchYoutubeFull(query, filter: 'Videos', region: region);
      final list = (fallback['tracks'] as List?)?.cast<NamiYtTrack>() ?? const <NamiYtTrack>[];
      for (final t in list) {
        if (seen.add(t.videoId)) feedVideos.add(t);
      }
    }

    return {
      'becauseWatched': becauseWatched,
      'feed': feedVideos,
    };
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

  List<NamiYtChannel> get subscribedChannels =>
      List<NamiYtChannel>.unmodifiable(_channels);
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

class _NamiProgressiveSession {
  NamiYtStreamResult stream;
  Map<String, String> cleanHeaders;
  int totalLength;
  final String ext;
  final String mimeType;
  final bool isVideo;
  final Future<NamiYtStreamResult?> Function(String failedClient)? onRefreshStream;
  final Map<int, Uint8List> chunks = {};
  final List<int> chunkLruOrder = [];
  final Map<int, Future<Uint8List?>> pendingChunks = {};
  bool bgStarted = false;
  bool disposed = false;
  int healAttempts = 0;

  _NamiProgressiveSession({
    required this.stream,
    required this.cleanHeaders,
    required this.totalLength,
    required this.ext,
    required this.mimeType,
    this.isVideo = false,
    this.onRefreshStream,
  });

  int get chunkCount =>
      (totalLength + NamiYtProgressiveProxy.chunkSize - 1) ~/ NamiYtProgressiveProxy.chunkSize;

  void storeChunk(int idx, Uint8List data) {
    chunks[idx] = data;
    chunkLruOrder.remove(idx);
    chunkLruOrder.add(idx);
    if (isVideo) {
      while (chunks.length > 18 && chunkLruOrder.isNotEmpty) {
        final oldest = chunkLruOrder.removeAt(0);
        if (oldest != 0) chunks.remove(oldest);
      }
    }
  }
}

/// Self-Healing Instant-Start Progressive Chunk-Cached Streaming Server (`v3.4.0`):
/// - Separate Audio & Video pools (switching video quality NEVER evicts active audio!)
/// - Mid-stream HTTP 403 Auto-Heal (`onRefreshStream`) eliminates 30s/60s playback cutoffs!
/// - Shared keep-alive `http.Client` for faster chunk throughput & lower mobile latency.
class NamiYtProgressiveProxy {
  NamiYtProgressiveProxy._();
  static final NamiYtProgressiveProxy instance = NamiYtProgressiveProxy._();

  static const int chunkSize = 512 * 1024;
  final http.Client _httpClient = http.Client();
  HttpServer? _server;
  int _port = 0;
  final Map<String, _NamiProgressiveSession> _audioSessions = {};
  final Map<String, _NamiProgressiveSession> _videoSessions = {};

  Future<void> _ensureServer() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: true);
    _port = _server!.port;
    _server!.listen(_handleRequest, onError: (_) {});
    debugPrint('[NamiYtProgressive] Listening on http://127.0.0.1:$_port');
  }

  /// Prepares Chunk 0 (~150ms) and returns `http://127.0.0.1:<port>/stream/<id>.<ext>`.
  Future<String?> prepareAndRegister(
    NamiYtStreamResult stream, {
    bool isVideo = false,
    Future<NamiYtStreamResult?> Function(String failedClient)? onRefreshStream,
  }) async {
    if (stream.audioUrl.contains('.m3u8') ||
        stream.audioUrl.contains('manifest/hls') ||
        stream.mimeType.toLowerCase().contains('mpegurl')) {
      return null;
    }

    final cleanHeaders = <String, String>{};
    stream.headers.forEach((k, v) {
      if (!k.toLowerCase().startsWith('x-nami-')) cleanHeaders[k] = v;
    });

    int totalLen = int.tryParse(stream.headers['X-Nami-Content-Length'] ?? '') ?? 0;
    if (totalLen <= 0) {
      final mClen = RegExp(r'[?&]clen=(\d+)').firstMatch(stream.audioUrl);
      totalLen = int.tryParse(mClen?.group(1) ?? '') ?? 0;
    }

    final firstEnd = (totalLen > 0 && totalLen < chunkSize) ? totalLen - 1 : chunkSize - 1;
    final chunk0 = await _fetchBoundedChunk(
      stream.audioUrl,
      cleanHeaders,
      0,
      firstEnd,
      onTotal: (t) {
        if (t > totalLen) totalLen = t;
      },
    );
    if (chunk0 == null ||
        chunk0.isEmpty ||
        !NamiYoutubeService.isValidAudioHeader(chunk0) ||
        totalLen <= 0) {
      return null;
    }

    await _ensureServer();
    final lowerMime = stream.mimeType.toLowerCase();
    final isVid = isVideo || lowerMime.startsWith('video/');
    final ext = isVid
        ? (lowerMime.contains('webm') ? 'webm' : 'mp4')
        : ((lowerMime.contains('mp4') || lowerMime.contains('m4a') || lowerMime.contains('aac'))
            ? 'm4a'
            : (lowerMime.contains('ogg') ? 'ogg' : 'webm'));
    final safeId = stream.videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final key = '${isVid ? 'v' : 'a'}_$safeId.$ext';

    final pool = isVid ? _videoSessions : _audioSessions;
    final maxKeep = isVid ? 2 : 3;
    if (pool.length >= maxKeep) {
      final oldestKey = pool.keys.first;
      if (oldestKey != key) {
        pool[oldestKey]?.disposed = true;
        pool.remove(oldestKey);
      }
    }

    final sess = _NamiProgressiveSession(
      stream: stream,
      cleanHeaders: cleanHeaders,
      totalLength: totalLen,
      ext: ext,
      mimeType: stream.mimeType.split(';').first.trim(),
      isVideo: isVid,
      onRefreshStream: onRefreshStream,
    );
    sess.storeChunk(0, chunk0);
    pool[key] = sess;

    if (!isVid) {
      unawaited(_backgroundFillAndPersistAudio(sess));
    } else {
      unawaited(_prewarmVideoHead(sess));
    }

    return 'http://127.0.0.1:$_port/stream/$key';
  }

  Future<void> _prewarmVideoHead(_NamiProgressiveSession sess) async {
    final totalChunks = sess.chunkCount;
    final head = <int>[];
    if (totalChunks > 1) head.add(1);
    if (totalChunks > 2) head.add(2);
    if (head.isNotEmpty) {
      await Future.wait(head.map((i) => _getOrFetchChunk(sess, i)));
    }
  }

  Future<Uint8List?> _getOrFetchChunk(_NamiProgressiveSession sess, int index) async {
    final existing = sess.chunks[index];
    if (existing != null) return existing;
    final inflight = sess.pendingChunks[index];
    if (inflight != null) return inflight;

    final start = index * chunkSize;
    if (start >= sess.totalLength) return Uint8List(0);
    final end = (start + chunkSize - 1).clamp(start, sess.totalLength - 1);

    final fut = () async {
      Uint8List? data = await _fetchBoundedChunk(sess.stream.audioUrl, sess.cleanHeaders, start, end);
      // Mid-stream 403 Auto-Heal: if Chunk >= 1 fails (e.g. tokenless cutoff / URL expiry),
      // transparently refresh stream from another full-length client & retry this exact byte range!
      if ((data == null || data.isEmpty) &&
          !sess.disposed &&
          sess.onRefreshStream != null &&
          sess.healAttempts < 2) {
        sess.healAttempts++;
        try {
          final fresh = await sess.onRefreshStream!(sess.stream.clientUsed);
          if (fresh != null && fresh.audioUrl.isNotEmpty && !sess.disposed) {
            final freshHdrs = <String, String>{};
            fresh.headers.forEach((k, v) {
              if (!k.toLowerCase().startsWith('x-nami-')) freshHdrs[k] = v;
            });
            sess.stream = fresh;
            sess.cleanHeaders = freshHdrs;
            data = await _fetchBoundedChunk(fresh.audioUrl, freshHdrs, start, end);
          }
        } catch (_) {}
      }
      if (data != null && data.isNotEmpty && !sess.disposed) {
        sess.storeChunk(index, data);
      }
      return data;
    }();

    sess.pendingChunks[index] = fut;
    try {
      return await fut;
    } finally {
      sess.pendingChunks.remove(index);
    }
  }

  Future<void> _backgroundFillAndPersistAudio(_NamiProgressiveSession sess) async {
    if (sess.bgStarted || sess.isVideo) return;
    sess.bgStarted = true;
    final totalChunks = sess.chunkCount;
    for (int i = 1; i < totalChunks; i += 4) {
      if (sess.disposed) return;
      final batch = <int>[];
      for (int j = i; j < i + 4 && j < totalChunks; j++) {
        if (!sess.chunks.containsKey(j)) batch.add(j);
      }
      if (batch.isNotEmpty) {
        await Future.wait(batch.map((idx) => _getOrFetchChunk(sess, idx)));
      }
    }
    if (sess.disposed) return;

    if (sess.chunks.length >= totalChunks) {
      try {
        final safeId = sess.stream.videoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final dir = NamiYtAudioCache.instance.cacheDir;
        final fin = File('${dir.path}/$safeId.${sess.ext}');
        if (!fin.existsSync()) {
          final part = File('${fin.path}.part');
          final sink = part.openWrite();
          for (int i = 0; i < totalChunks; i++) {
            final c = sess.chunks[i];
            if (c != null) sink.add(c);
          }
          await sink.flush();
          await sink.close();
          if (fin.existsSync()) fin.deleteSync();
          await part.rename(fin.path);
        }
      } catch (_) {}
    }
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final res = req.response;
    res.bufferOutput = false;
    final segs = req.uri.pathSegments;
    if (segs.length < 2 || segs[0] != 'stream') {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final key = segs[1];
    final sess = _audioSessions[key] ?? _videoSessions[key];
    if (sess == null) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }

    final total = sess.totalLength;
    int start = 0;
    int end = total - 1;
    bool isRange = false;

    final rangeHdr = req.headers.value(HttpHeaders.rangeHeader);
    if (rangeHdr != null && rangeHdr.startsWith('bytes=')) {
      isRange = true;
      final spec = rangeHdr.substring(6).split(',').first.trim();
      final parts = spec.split('-');
      if (parts.length == 2) {
        if (parts[0].isEmpty && parts[1].isNotEmpty) {
          final suffix = int.tryParse(parts[1]) ?? 0;
          start = (total - suffix).clamp(0, total - 1);
        } else {
          start = int.tryParse(parts[0]) ?? 0;
          if (parts[1].isNotEmpty) {
            end = (int.tryParse(parts[1]) ?? (total - 1)).clamp(start, total - 1);
          }
        }
      }
    }

    if (start >= total) {
      res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
      await res.close();
      return;
    }

    final reqLen = end - start + 1;
    res.statusCode = isRange ? HttpStatus.partialContent : HttpStatus.ok;
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    res.headers.set(HttpHeaders.contentTypeHeader, sess.mimeType);
    if (isRange) {
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
    }
    res.contentLength = reqLen;

    if (req.method == 'HEAD') {
      await res.close();
      return;
    }

    try {
      int cursor = start;
      while (cursor <= end && !sess.disposed) {
        final chunkIdx = cursor ~/ chunkSize;
        final chunkOffset = cursor % chunkSize;
        final chunk = await _getOrFetchChunk(sess, chunkIdx);
        if (chunk == null || chunk.isEmpty) break;
        if (sess.isVideo &&
            chunkIdx + 1 < sess.chunkCount &&
            !sess.chunks.containsKey(chunkIdx + 1)) {
          unawaited(_getOrFetchChunk(sess, chunkIdx + 1));
        }
        final available = chunk.length - chunkOffset;
        if (available <= 0) break;
        final need = (end - cursor + 1).clamp(1, available);
        res.add(
          (chunkOffset == 0 && need == chunk.length)
              ? chunk
              : chunk.sublist(chunkOffset, chunkOffset + need),
        );
        cursor += need;
      }
      await res.close();
    } catch (_) {
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<Uint8List?> _fetchBoundedChunk(
    String rawUrl,
    Map<String, String> baseHeaders,
    int start,
    int end, {
    void Function(int total)? onTotal,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = NamiYoutubeService.buildBoundedChunkUri(rawUrl, start, end);
        final hdrs = Map<String, String>.from(baseHeaders);
        if (!uri.toString().contains('range=')) {
          hdrs['Range'] = 'bytes=$start-$end';
        }
        final resp = await _httpClient
            .get(uri, headers: hdrs)
            .timeout(const Duration(seconds: 9));
        if (resp.statusCode == 200 || resp.statusCode == 206) {
          final cr = resp.headers['content-range'] ?? '';
          final slash = cr.lastIndexOf('/');
          if (slash != -1) {
            final parsed = int.tryParse(cr.substring(slash + 1).trim()) ?? 0;
            if (parsed > 0) onTotal?.call(parsed);
          } else if (resp.statusCode == 200 && start == 0 && !uri.toString().contains('range=')) {
            final cl = int.tryParse(resp.headers['content-length'] ?? '') ?? resp.bodyBytes.length;
            if (cl > 0) onTotal?.call(cl);
          }
          return resp.bodyBytes;
        }
      } catch (_) {}
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
      }
    }
    return null;
  }
}



