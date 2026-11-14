import 'dart:typed_data';

class SyllableToken {
  final Duration timestamp;
  final String text;
  SyllableToken({required this.timestamp, required this.text});
}

class LyricLine {
  final Duration timestamp;
  final String text;
  final List<SyllableToken> syllables;
  LyricLine({
    required this.timestamp,
    required this.text,
    this.syllables = const [],
  });
}

class AudioTrack {
  String title;
  String artist;
  String album;
  String genre;
  String albumArtist;
  String composer;
  String comment;
  String trackNumber;
  String year;
  final String path;
  String? thumbPath;
  Uint8List? albumArt;
  String rawLyrics;
  List<LyricLine> parsedLyrics;
  bool isMetadataLoaded;
  bool isOnlineEnriched;
  bool isLyricsFetched;
  Duration duration;
  bool isFavorite;
  String addedDate;
  int addedTimestampMs;
  int fileSize;
  int bitrateKbps;
  int sampleRateHz;
  int bitDepth;
  int playCount;

  AudioTrack({
    required this.title,
    required this.artist,
    required this.album,
    this.genre = "Hip-Hop/Rap",
    this.albumArtist = "",
    this.composer = "",
    this.comment = "",
    this.trackNumber = "1/10",
    this.year = "2025",
    required this.path,
    this.thumbPath,
    this.albumArt,
    this.rawLyrics = "",
    List<LyricLine>? parsedLyrics,
    this.isMetadataLoaded = false,
    this.isOnlineEnriched = false,
    this.isLyricsFetched = false,
    this.duration = const Duration(minutes: 3, seconds: 30),
    this.isFavorite = false,
    this.addedDate = "Sep 2026",
    this.addedTimestampMs = 0,
    this.fileSize = 0,
    this.bitrateKbps = 1411,
    this.sampleRateHz = 44100,
    this.bitDepth = 24,
    this.playCount = 0,
  }) : parsedLyrics = parsedLyrics ?? [];

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'path': path,
        'thumbPath': thumbPath,
        'year': year,
        'trackNumber': trackNumber,
        'durationSec': duration.inSeconds,
        'bitrate': bitrateKbps,
        'sampleRate': sampleRateHz,
        'bitDepth': bitDepth,
        'isFavorite': isFavorite,
        'onlineDone3': isOnlineEnriched,
        'playCount': playCount,
        'addedDate': addedDate,
        'addedTimestampMs': addedTimestampMs,
      };

  factory AudioTrack.fromJson(Map<String, dynamic> j) => AudioTrack(
        title: j['title'] ?? 'Unknown',
        artist: j['artist'] ?? 'Unknown Artist',
        album: j['album'] ?? 'Unknown Album',
        genre: j['genre'] ?? 'Music',
        path: j['path'] ?? '',
        thumbPath: j['thumbPath'],
        year: j['year'] ?? '2026',
        trackNumber: j['trackNumber'] ?? '1',
        duration: Duration(seconds: j['durationSec'] ?? 210),
        bitrateKbps: j['bitrate'] ?? 1411,
        sampleRateHz: j['sampleRate'] ?? 44100,
        bitDepth: j['bitDepth'] ?? 16,
        isFavorite: j['isFavorite'] ?? false,
        isOnlineEnriched: j['onlineDone3'] ?? false,
        playCount: j['playCount'] ?? 0,
        addedDate: j['addedDate'] ?? 'Sep 2026',
        addedTimestampMs: j['addedTimestampMs'] ?? 0,
        isMetadataLoaded: (j['artist'] != null &&
            j['artist'] != 'Unknown Artist' &&
            j['thumbPath'] != null),
      );
}

class CustomPlaylist {
  String name;
  List<AudioTrack> tracks;
  CustomPlaylist({required this.name, required this.tracks});

  Map<String, dynamic> toJson() => {
        'name': name,
        'paths': tracks.map((t) => t.path).toList(),
      };
}

class MornyeExtension {
  final String name;
  final String version;
  final String author;
  final String format;
  final String category;
  final String description;
  final String? endpointUrl;
  bool isInstalled;
  bool isEnabled;

  MornyeExtension({
    required this.name,
    required this.version,
    required this.author,
    required this.format,
    this.category = 'Metadata',
    this.description = '',
    this.endpointUrl,
    this.isInstalled = true,
    this.isEnabled = true,
  });
}

class MornyeCatalogItem {
  final String title;
  final String artist;
  final String album;
  final String subtitle;
  final String type;
  final String service;
  final String? previewUrl;
  final String? artworkUrl;
  final int durationSeconds;
  final String? collectionId;

  MornyeCatalogItem({
    required this.title,
    required this.artist,
    required this.album,
    required this.subtitle,
    required this.type,
    required this.service,
    this.previewUrl,
    this.artworkUrl,
    this.durationSeconds = 210,
    this.collectionId,
  });
}
