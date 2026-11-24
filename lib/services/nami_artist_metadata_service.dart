import 'dart:convert';
import 'package:http/http.dart' as http;

class NamiArtistProfile {
  final String artistName;
  final String? photoUrl;
  final String photoSource;
  final String bio;
  final String bioSource;
  final String? primaryGenre;
  final String? origin;
  final String? activeSince;
  final String? spotifyListeners;
  final String? appleMusicUrl;
  final String? spotifyUrl;

  const NamiArtistProfile({
    required this.artistName,
    required this.bio,
    required this.bioSource,
    this.photoUrl,
    this.photoSource = '',
    this.primaryGenre,
    this.origin,
    this.activeSince,
    this.spotifyListeners,
    this.appleMusicUrl,
    this.spotifyUrl,
  });

  String get combinedSourceLabel {
    final sources = <String>[];
    if (appleMusicUrl != null || photoSource == 'Apple Music' || bioSource == 'Apple Music') {
      sources.add('Apple Music');
    }
    if (spotifyUrl != null || photoSource == 'Spotify' || spotifyListeners != null) {
      sources.add('Spotify');
    }
    if (sources.isEmpty && bioSource.isNotEmpty) sources.add(bioSource);
    return sources.join(' • ');
  }
}

class NamiArtistMetadataService {
  static const Map<String, String> _jsonHeaders = {
    'User-Agent': 'NamiMusicPlayer/2.3 (https://github.com/Piyush1625/Nami-Music)',
    'Accept': 'application/json',
  };

  static const Map<String, String> _webHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static final Map<String, NamiArtistProfile> _cache = {};

  static void invalidate(String artistName) {
    _cache.remove(artistName.trim().toLowerCase());
  }

  static Future<NamiArtistProfile> fetchArtistProfile(
    String artistName, {
    int localTracks = 0,
    int localAlbums = 0,
    List<String> sampleTracks = const [],
    List<String> sampleAlbums = const [],
    bool forceRefresh = false,
  }) async {
    final cleanName = artistName.trim();
    final key = cleanName.toLowerCase();
    if (!forceRefresh && _cache.containsKey(key)) {
      return _cache[key]!;
    }

    final results = await Future.wait<Map<String, String?>>([
      _fetchFromAppleMusic(cleanName, sampleTracks: sampleTracks, sampleAlbums: sampleAlbums),
      _fetchFromSpotifyViaMusicBrainz(cleanName, sampleTracks: sampleTracks),
    ]);

    final apple = results[0];
    final spotify = results[1];

    // Prefer Apple Music photo when we disambiguated via a local track, else Spotify -> Apple -> Deezer
    String? photoUrl = (apple['matchedByTrack'] == '1' ? apple['photoUrl'] : null) ??
        spotify['photoUrl'] ??
        apple['photoUrl'];
    String photoSource = (photoUrl != null && photoUrl == apple['photoUrl'])
        ? 'Apple Music'
        : (photoUrl != null && photoUrl == spotify['photoUrl'] ? 'Spotify' : '');

    if (photoUrl == null || photoUrl.isEmpty) {
      final dz = await _fetchDeezerPhotoFallback(cleanName);
      if (dz != null && dz.isNotEmpty) {
        photoUrl = dz;
        photoSource = 'Deezer';
      }
    }

    String? bio = apple['bio'];
    String bioSource = (bio != null && bio.isNotEmpty) ? 'Apple Music' : '';

    if (bio == null || bio.isEmpty) {
      final wikiBio = await _fetchWikipediaMusicBio(cleanName, genreHint: apple['genre']);
      if (wikiBio != null && wikiBio.isNotEmpty) {
        bio = wikiBio;
        bioSource = 'Wikipedia';
      }
    }

    if (bio == null || bio.isEmpty) {
      if (spotify['bio'] != null && spotify['bio']!.isNotEmpty) {
        bio = spotify['bio'];
        bioSource = 'Spotify';
      } else {
        bio = '$cleanName has $localTracks track(s) across $localAlbums album(s) in your Nami library.';
        bioSource = 'Library';
      }
    }

    final profile = NamiArtistProfile(
      artistName: cleanName,
      photoUrl: photoUrl,
      photoSource: photoSource,
      bio: bio ?? '',
      bioSource: bioSource,
      primaryGenre: apple['genre'] ?? spotify['genre'],
      origin: apple['origin'] ?? spotify['origin'],
      activeSince: apple['activeSince'] ?? spotify['activeSince'],
      spotifyListeners: spotify['listeners'],
      appleMusicUrl: apple['url'],
      spotifyUrl: spotify['url'],
    );

    _cache[key] = profile;
    return profile;
  }

  static Future<String?> fetchBestArtistPhotoUrl(
    String artistName, {
    List<String> sampleTracks = const [],
    bool forceRefresh = false,
  }) async {
    final profile = await fetchArtistProfile(
      artistName,
      sampleTracks: sampleTracks,
      forceRefresh: forceRefresh,
    );
    return profile.photoUrl;
  }

  static Future<Map<String, String?>> _fetchFromAppleMusic(
    String artistName, {
    List<String> sampleTracks = const [],
    List<String> sampleAlbums = const [],
  }) async {
    final out = <String, String?>{};
    try {
      String? link;
      String? genre;

      // 1. Disambiguate using a local track/album first (e.g. "Divine 100 Million" -> Indian rapper DIVINE)
      final contextHint = sampleTracks.isNotEmpty
          ? sampleTracks.first
          : (sampleAlbums.isNotEmpty ? sampleAlbums.first : '');
      if (contextHint.isNotEmpty) {
        final trackUri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent('$artistName $contextHint')}&entity=song&limit=6',
        );
        final tRes = await http.get(trackUri, headers: _jsonHeaders).timeout(const Duration(seconds: 7));
        if (tRes.statusCode == 200) {
          final dec = jsonDecode(tRes.body);
          final list = (dec['results'] as List?)?.whereType<Map>().toList() ?? [];
          final lowerTarget = artistName.toLowerCase();
          for (final item in list) {
            final aName = (item['artistName'] ?? '').toString().toLowerCase();
            final aUrl = (item['artistViewUrl'] ?? '').toString().trim();
            if (aUrl.isNotEmpty && (aName == lowerTarget || aName.contains(lowerTarget))) {
              link = aUrl;
              genre = (item['primaryGenreName'] ?? '').toString().trim();
              out['matchedByTrack'] = '1';
              break;
            }
          }
        }
      }

      // 2. Fallback to direct musicArtist search
      if (link == null || link.isEmpty) {
        final searchUri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(artistName)}&entity=musicArtist&limit=6',
        );
        final res = await http.get(searchUri, headers: _jsonHeaders).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final list = (decoded['results'] as List?)?.whereType<Map>().toList() ?? [];
          if (list.isNotEmpty) {
            final lowerTarget = artistName.toLowerCase();
            Map best = list.first;
            for (final item in list) {
              final n = (item['artistName'] ?? '').toString().trim().toLowerCase();
              if (n == lowerTarget) {
                best = item;
                break;
              }
            }
            genre ??= (best['primaryGenreName'] ?? '').toString().trim();
            link = (best['artistLinkUrl'] ?? '').toString().trim();
          }
        }
      }

      if (genre != null && genre.isNotEmpty) out['genre'] = genre;
      if (link == null || link.isEmpty) return out;
      out['url'] = link;

      final pageRes = await http.get(Uri.parse(link), headers: _webHeaders).timeout(const Duration(seconds: 8));
      if (pageRes.statusCode != 200) return out;
      final html = pageRes.body;

      final ogImgM = RegExp(
        r'<meta[^>]+(?:property|name)=["\x27]og:image["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]',
        caseSensitive: false,
      ).firstMatch(html);
      String? imgUrl = ogImgM?.group(1);
      if (imgUrl == null || imgUrl.isEmpty) {
        final mzM = RegExp(
          r'https://is\d-ssl\.mzstatic\.com/image/thumb/[^"\x27\s\\]+/(?:\d+x\d+[a-z]*\.(?:jpg|jpeg|png|webp))',
          caseSensitive: false,
        ).firstMatch(html);
        imgUrl = mzM?.group(0);
      }
      if (imgUrl != null && imgUrl.startsWith('http')) {
        imgUrl = imgUrl.replaceAll(RegExp(r'/\d+x\d+[a-z]*\.(jpg|jpeg|png|webp)$', caseSensitive: false), '/800x800cc.jpg');
        out['photoUrl'] = imgUrl;
      }

      final edStd = RegExp(r'"editorialNotes"\s*:\s*\{[^}]*?"standard"\s*:\s*"((?:[^"\\]|\\.)+)"').firstMatch(html);
      final edShort = RegExp(r'"editorialNotes"\s*:\s*\{[^}]*?"short"\s*:\s*"((?:[^"\\]|\\.)+)"').firstMatch(html);
      final rawBio = edStd?.group(1) ?? edShort?.group(1);
      if (rawBio != null && rawBio.length > 30) {
        final cleaned = _unescapeJsonText(rawBio).replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (cleaned.length > 30) out['bio'] = cleaned;
      }

      final originM = RegExp(r'"origin"\s*:\s*"((?:[^"\\]|\\.)+)"').firstMatch(html);
      if (originM != null) {
        final o = _unescapeJsonText(originM.group(1)!).trim();
        if (o.isNotEmpty && o.length < 48) out['origin'] = o;
      }

      final bornM = RegExp(r'"bornOrFormed"\s*:\s*"((?:[^"\\]|\\.)+)"').firstMatch(html);
      if (bornM != null) {
        final b = _unescapeJsonText(bornM.group(1)!).trim();
        if (b.isNotEmpty && b.length < 32) out['activeSince'] = b;
      }
    } catch (_) {}
    return out;
  }

  static Future<Map<String, String?>> _fetchFromSpotifyViaMusicBrainz(
    String artistName, {
    List<String> sampleTracks = const [],
  }) async {
    final out = <String, String?>{};
    try {
      String? mbid;
      Map? best;

      // Try recording lookup first when we have a sample track so homonymous artists (e.g. "Divine") resolve accurately
      if (sampleTracks.isNotEmpty) {
        final recUri = Uri.parse(
          'https://musicbrainz.org/ws/2/recording/?query=recording:${Uri.encodeComponent(sampleTracks.first)}%20AND%20artist:${Uri.encodeComponent(artistName)}&fmt=json&limit=3',
        );
        final recRes = await http.get(recUri, headers: _jsonHeaders).timeout(const Duration(seconds: 6));
        if (recRes.statusCode == 200) {
          final rData = jsonDecode(recRes.body);
          final recs = (rData['recordings'] as List?)?.whereType<Map>().toList() ?? [];
          for (final rec in recs) {
            final credits = (rec['artist-credit'] as List?)?.whereType<Map>().toList() ?? [];
            for (final cr in credits) {
              final art = cr['artist'];
              if (art is Map) {
                final n = (art['name'] ?? '').toString().trim().toLowerCase();
                if (n == artistName.toLowerCase()) {
                  mbid = (art['id'] ?? '').toString().trim();
                  best = art;
                  break;
                }
              }
            }
            if (mbid != null && mbid.isNotEmpty) break;
          }
        }
      }

      if (mbid == null || mbid.isEmpty) {
        final mbUri = Uri.parse(
          'https://musicbrainz.org/ws/2/artist/?query=artist:${Uri.encodeComponent(artistName)}&fmt=json&limit=5',
        );
        final res = await http.get(mbUri, headers: _jsonHeaders).timeout(const Duration(seconds: 7));
        if (res.statusCode != 200) return out;
        final data = jsonDecode(res.body);
        final artists = (data['artists'] as List?)?.whereType<Map>().toList() ?? [];
        if (artists.isEmpty) return out;

        final lowerTarget = artistName.toLowerCase();
        best = artists.first;
        for (final a in artists) {
          final n = (a['name'] ?? '').toString().trim().toLowerCase();
          final ended = a['life-span']?['ended'] == true;
          if (n == lowerTarget && !ended) {
            best = a;
            break;
          }
        }
        mbid = (best?['id'] ?? '').toString().trim();
      }

      final area = (best?['begin-area']?['name'] ?? best?['area']?['name'] ?? '').toString().trim();
      if (area.isNotEmpty) out['origin'] = area;
      final begin = (best?['life-span']?['begin'] ?? '').toString().trim();
      if (begin.length >= 4) out['activeSince'] = begin.substring(0, 4);

      if (mbid.isEmpty) return out;

      final relUri = Uri.parse('https://musicbrainz.org/ws/2/artist/$mbid?inc=url-rels&fmt=json');
      final relRes = await http.get(relUri, headers: _jsonHeaders).timeout(const Duration(seconds: 7));
      if (relRes.statusCode != 200) return out;
      final relData = jsonDecode(relRes.body);
      final rels = (relData['relations'] as List?)?.whereType<Map>().toList() ?? [];

      String? spotifyUrl;
      for (final r in rels) {
        final u = (r['url']?['resource'] ?? '').toString().trim();
        if (u.contains('open.spotify.com/artist/')) {
          spotifyUrl = u;
          break;
        }
      }
      if (spotifyUrl == null) return out;
      out['url'] = spotifyUrl;

      try {
        final oembedUri = Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(spotifyUrl)}');
        final oeRes = await http.get(oembedUri, headers: _jsonHeaders).timeout(const Duration(seconds: 6));
        if (oeRes.statusCode == 200) {
          final oe = jsonDecode(oeRes.body);
          final thumb = (oe['thumbnail_url'] ?? '').toString().trim();
          if (thumb.startsWith('http')) out['photoUrl'] = thumb;
        }
      } catch (_) {}

      try {
        final spRes = await http.get(Uri.parse(spotifyUrl), headers: _webHeaders).timeout(const Duration(seconds: 7));
        if (spRes.statusCode == 200) {
          final html = spRes.body;
          if (out['photoUrl'] == null) {
            final ogImg = RegExp(
              r'<meta[^>]+property=["\x27]og:image["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]',
              caseSensitive: false,
            ).firstMatch(html)?.group(1);
            if (ogImg != null && ogImg.startsWith('http')) out['photoUrl'] = ogImg;
          }
          final ogDesc = RegExp(
            r'<meta[^>]+(?:property|name)=["\x27](?:og:description|description)["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]',
            caseSensitive: false,
          ).firstMatch(html)?.group(1);
          if (ogDesc != null && ogDesc.isNotEmpty) {
            final cleanDesc = _decodeHtmlEntities(ogDesc).trim();
            final listM = RegExp(r'([\d.,]+[KMB]?\s+monthly\s+listeners)', caseSensitive: false).firstMatch(cleanDesc);
            if (listM != null) out['listeners'] = listM.group(1);
            if (cleanDesc.length > 25) out['bio'] = cleanDesc;
          }
        }
      } catch (_) {}
    } catch (_) {}
    return out;
  }

  static Future<String?> _fetchDeezerPhotoFallback(String artistName) async {
    try {
      final res = await http
          .get(Uri.parse('https://api.deezer.com/search/artist?q=${Uri.encodeComponent(artistName)}&limit=3'), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List?)?.whereType<Map>().toList() ?? [];
        if (list.isNotEmpty) {
          final pic = (list.first['picture_xl'] ?? list.first['picture_big'] ?? '').toString().trim();
          if (pic.startsWith('http')) return pic;
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _looksLikeMusicBio(String text) {
    final l = text.toLowerCase();
    const kws = ['rapper', 'singer', 'musician', 'band', 'songwriter', 'composer', 'producer', 'hip hop', 'album', 'music', 'discography', 'dj'];
    return kws.any((k) => l.contains(k));
  }

  static Future<String?> _fetchWikipediaMusicBio(String artistName, {String? genreHint}) async {
    final candidates = <String>[
      if (genreHint != null && genreHint.toLowerCase().contains('hip')) '$artistName (rapper)',
      '$artistName (rapper)',
      '$artistName (musician)',
      '$artistName (singer)',
      artistName,
    ];
    for (final title in candidates) {
      try {
        final slug = Uri.encodeComponent(title.trim().replaceAll(' ', '_'));
        final res = await http
            .get(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$slug'), headers: _jsonHeaders)
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map) {
            final extract = (data['extract'] ?? '').toString().trim();
            if (extract.length > 40 && _looksLikeMusicBio(extract)) {
              return extract;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static String _unescapeJsonText(String raw) {
    try {
      return jsonDecode('"$raw"').toString();
    } catch (_) {
      return raw.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
    }
  }

  static String _decodeHtmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&middot;', '•')
        .replaceAll('&#183;', '•');
  }
}
