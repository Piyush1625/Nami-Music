import 'dart:typed_data';
import 'package:isar/isar.dart';

part 'audio_track.g.dart';

@Embedded()
class SyllableToken {
  int timestampMs;
  String text;
  
  SyllableToken({this.timestampMs = 0, this.text = ''});
}

@Embedded()
class LyricLine {
  int timestampMs;
  String text;
  List<SyllableToken> syllables;
  
  LyricLine({this.timestampMs = 0, this.text = '', this.syllables = const []});
}

@Collection()
class AudioTrack {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  String title;

  @Index(type: IndexType.value)
  String artist;

  @Index(type: IndexType.value)
  String album;

  String genre;
  String albumArtist;
  String composer;
  String comment;
  String trackNumber;
  String year;
  
  @Index(unique: true, replace: true)
  String path;
  
  String? thumbPath;
  
  @Ignore()
  Uint8List? albumArt;
  
  String rawLyrics;
  List<LyricLine> parsedLyrics;
  
  bool isMetadataLoaded;
  bool isOnlineEnriched;
  bool isLyricsFetched;
  
  int durationSec;
  bool isFavorite;
  String addedDate;
  
  @Index(type: IndexType.value)
  int addedTimestampMs;
  
  int fileSize;
  int bitrateKbps;
  int sampleRateHz;
  int bitDepth;
  
  @Index(type: IndexType.value)
  int playCount;

  AudioTrack({
    this.title = 'Unknown',
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.genre = 'Music',
    this.albumArtist = '',
    this.composer = '',
    this.comment = '',
    this.trackNumber = '1/1',
    this.year = '2026',
    required this.path,
    this.thumbPath,
    this.albumArt,
    this.rawLyrics = '',
    this.parsedLyrics = const [],
    this.isMetadataLoaded = false,
    this.isOnlineEnriched = false,
    this.isLyricsFetched = false,
    this.durationSec = 210,
    this.isFavorite = false,
    this.addedDate = 'Sep 2026',
    this.addedTimestampMs = 0,
    this.fileSize = 0,
    this.bitrateKbps = 1411,
    this.sampleRateHz = 44100,
    this.bitDepth = 16,
    this.playCount = 0,
  });
}
grep -A 7 "dependencies:" pubspec.yaml
cat << 'EOF' > lib/models/audio_track.dart
import 'dart:typed_data';
import 'package:isar/isar.dart';

part 'audio_track.g.dart';

@Embedded()
class SyllableToken {
  int timestampMs;
  String text;
  SyllableToken({this.timestampMs = 0, this.text = ''});
}

@Embedded()
class LyricLine {
  int timestampMs;
  String text;
  List<SyllableToken> syllables;
  LyricLine({this.timestampMs = 0, this.text = '', this.syllables = const []});
}

@Collection()
class AudioTrack {
  Id id = Isar.autoIncrement;
  @Index(type: IndexType.value)
  String title;
  @Index(type: IndexType.value)
  String artist;
  @Index(type: IndexType.value)
  String album;
  String genre;
  String albumArtist;
  String composer;
  String comment;
  String trackNumber;
  String year;
  @Index(unique: true, replace: true)
  String path;
  String? thumbPath;
  @Ignore()
  Uint8List? albumArt;
  String rawLyrics;
  List<LyricLine> parsedLyrics;
  bool isMetadataLoaded;
  bool isOnlineEnriched;
  bool isLyricsFetched;
  int durationSec;
  bool isFavorite;
  String addedDate;
  @Index(type: IndexType.value)
  int addedTimestampMs;
  int fileSize;
  int bitrateKbps;
  int sampleRateHz;
  int bitDepth;
  @Index(type: IndexType.value)
  int playCount;

  AudioTrack({
    this.title = 'Unknown',
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.genre = 'Music',
    this.albumArtist = '',
    this.composer = '',
    this.comment = '',
    this.trackNumber = '1/1',
    this.year = '2026',
    required this.path,
    this.thumbPath,
    this.albumArt,
    this.rawLyrics = '',
    this.parsedLyrics = const [],
    this.isMetadataLoaded = false,
    this.isOnlineEnriched = false,
    this.isLyricsFetched = false,
    this.durationSec = 210,
    this.isFavorite = false,
    this.addedDate = 'Sep 2026',
    this.addedTimestampMs = 0,
    this.fileSize = 0,
    this.bitrateKbps = 1411,
    this.sampleRateHz = 44100,
    this.bitDepth = 16,
    this.playCount = 0,
  });
}
