import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/physics.dart';
import 'services/nami_artist_metadata_service.dart';
import 'services/nami_v16_prefs.dart';
import 'services/nami_github_updater.dart';
import 'services/nami_mornye_store.dart';
import 'services/nami_tag_writer.dart';
import 'services/nami_library_store.dart';
import 'services/nami_crossfade_engine.dart';
import 'services/nami_download_manager.dart';
import 'services/nami_scrobble_service.dart';
import 'dart:isolate';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'services/nami_audio_handler.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/services.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;


import 'package:flutter/gestures.dart';
part 'models/nami_models.dart';
part 'widgets/nami_widgets.dart';
part 'screens/settings_screen.dart';
part 'screens/now_playing_screen.dart';

part 'widgets/nami_lyrics_view.dart';
part 'widgets/nami_track_action_card.dart';
part 'screens/tabs/home_tab.dart';
part 'screens/tabs/tracks_tab.dart';
part 'screens/tabs/artists_tab.dart';
part 'screens/tabs/playlists_tab.dart';
part 'screens/tabs/mornye_tab.dart';
part 'widgets/nami_v22_polish.dart';
part 'widgets/nami_v24_ui.dart';
part 'widgets/nami_v25_motion.dart';
part 'widgets/nami_v26_settings.dart';
part 'widgets/nami_v27_audiophile.dart';
part 'widgets/nami_v28_morph_player.dart';
part 'widgets/nami_v29_shell.dart';
part 'widgets/nami_v29_settings_studio.dart';
part 'widgets/nami_v29_8_gestures.dart';
const Map<String, String> _httpHeaders = {
  'User-Agent': 'NamiMusicPlayer/2.0 (https://github.com/Piyush1625/nami)',
  'Accept': 'application/json',
};

String _normName(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

bool _namesMatchLoosely(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  return shorter.length >= 4 &&
      longer.contains(shorter) &&
      shorter.length / longer.length >= 0.6;
}

bool _artistNamesMatch(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  return (a.length >= 3 && b.contains(a)) || (b.length >= 3 && a.contains(b));
}

bool _looksLikeImage(Uint8List b) {
  if (b.length < 512) return false;
  final jpeg = b[0] == 0xFF && b[1] == 0xD8;
  final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
  final riff = b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46;
  return jpeg || png || riff;
}

String _formatDurationPadded(Duration d) {
  int minutes = d.inMinutes;
  int seconds = d.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _formatTotalDurationHoursMins(Duration d) {
  int hours = d.inHours;
  int minutes = d.inMinutes % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${math.max(1, minutes)}m';
}

String _deterministicPathHash(String input) {
  int hash = 0x811c9dc5;
  for (int i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _colorToHex(Color c) {
  return '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

Color _extractDominantColor(Uint8List? bytes, Color fallback) {
  if (bytes == null || bytes.length < 500) return fallback;
  try {
    int rTotal = 0, gTotal = 0, bTotal = 0, count = 0;
    int step = math.max(1, bytes.length ~/ 150);
    for (int i = 64; i < bytes.length - 3; i += step) {
      int r = bytes[i];
      int g = bytes[i + 1];
      int b = bytes[i + 2];
      int brightness = (r * 299 + g * 587 + b * 114) ~/ 1000;
      if (brightness > 40 && brightness < 230) {
        rTotal += r;
        gTotal += g;
        bTotal += b;
        count++;
      }
    }
    if (count > 0) {
      return Color.fromARGB(
          255, rTotal ~/ count, gTotal ~/ count, bTotal ~/ count);
    }
  } catch (_) {}
  return fallback;
}

late final Player _globalMediaKitPlayer;
late final AudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  _globalMediaKitPlayer = Player();
  audioHandler = await AudioService.init(
    builder: () => NamiAudioHandler(_globalMediaKitPlayer),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.piyush.nami.channel.audio',
      androidNotificationChannelName: 'Nami Playback',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF07070B),
  ));
  /* v28_1_error_widget */
  /* v29_5_safe_error_widget */
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0A0A10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nami UI Diagnostic',
                style: TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };
  runApp(const NamiApp());
}

class NamiApp extends StatefulWidget {
  const NamiApp({super.key});

  static _NamiAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_NamiAppState>()!;

  @override
  State<NamiApp> createState() => _NamiAppState();
}

class _NamiAppState extends State<NamiApp> {
bool pitchBlack = true;
  Color accentColor = const Color(0xFFE53935);

  void updateTheme({bool? isPitchBlack, Color? newAccent}) {
    setState(() {
      if (isPitchBlack != null) pitchBlack = isPitchBlack;
      if (newAccent != null) accentColor = newAccent;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    final bgColor =
        pitchBlack ? const Color(0xFF000000) : const Color(0xFF09090E);
    final cardColor =
        pitchBlack ? const Color(0xFF0C0C12) : const Color(0xFF13131C);

    return MaterialApp(
      scrollBehavior: const NamiButterScrollBehavior(),
      title: 'Nami',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NamiSmoothPageTransitionsBuilder(),
            TargetPlatform.iOS: NamiSmoothPageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        cardColor: cardColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: Brightness.dark,
          surface: cardColor,
          primary: accentColor,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF07070B),
          indicatorColor: accentColor.withValues(alpha: 0.22),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : Colors.white60,
            );
          }),
        ),
      ),
      home: const NamiHomeShell(),
    );
  }
}

// Interactive 2D Hue/Saturation/Value Palette Canvas
class NamiHomeShell extends StatefulWidget {
  const NamiHomeShell({super.key});

  @override
  State<NamiHomeShell> createState() => _NamiHomeShellState();
}

class _NamiHomeShellState extends State<NamiHomeShell> {
  static _NamiHomeShellState? activeInstance;
  final Set<String> _artistImageFetching = <String>{};
  int _selectedIndex = 0;

      late final Player _audioPlayer;

  final ScrollController _trackListScrollController = ScrollController();
  final ScrollController _artistListScrollController = ScrollController();

  bool _hasPermission = false;
  bool _isScanning = false;
  bool _isEnrichingMetadata = false;
  int _enrichedCount = 0;

  List<AudioTrack> _songs = [];
  List<AudioTrack> _filteredSongs = [];
  final List<AudioTrack> _playNextQueue = [];
  final List<AudioTrack> _historyTracks = [];
  final List<CustomPlaylist> _customPlaylists = [
    CustomPlaylist(name: 'Favorites Mix', tracks: []),
  ];

  final ValueNotifier<AudioTrack?> _currentSongNotifier =
      ValueNotifier<AudioTrack?>(null);
  AudioTrack? get _currentSong => _currentSongNotifier.value;
  set _currentSong(AudioTrack? val) => _currentSongNotifier.value = val;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool _artistGridMode = true;
  bool _artistSortByCount = false;
  bool _splitMultiArtists = true;
  bool _shuffleEnabled = false;
  int _repeatMode = 1; // 0 = Off, 1 = Repeat All, 2 = Repeat One
  bool _isSelectionMode = false;
  final Set<String> _selectedTrackPaths = {};
  List<String> _scanFolders = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
  ];
  bool _ignoreShortClips = true;
  List<String> _artistSeparators = [',', '&', '/', ';', 'feat.', 'ft.'];

  Directory _currentFolder = Directory('/storage/emulated/0/Music');
  String _lastKnownDac = "";
  StreamSubscription? _deviceSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;

  Timer? _sleepTimer;
  Timer? _fadeTimer;
  Timer? _telemetryTimer;
  int _sleepMinutesRemaining = 0;
  bool _sleepAfterCurrentTrack = false;

  int _totalListenSeconds = 0;
  int _currentTrackSecondsListened = 0;

  double _playbackSpeed = 1.0;
  double _playbackPitch = 1.0;
  double _stereoBalance = 0.0;
  String _soundstagePreset = 'Off';
  bool _eqEnabled = false;
  double _preampGainDb = 0.0;

  bool _usbDacExclusive = true;
  bool _gaplessPlayback = true;
  bool _mediaNotificationEnabled = true;
  bool _usePitchBlack = true;
  bool _autoColoring = true;
  bool _ambientGlow = false;
  bool _blurredBackdrop = true;
  bool _showCodecBadges = true;
  bool _compactTrackTiles = false;
  bool _resumeSessionOnStartup = true;
  bool _pauseOnDisconnect = true;
  int _doubleTapSeekSec = 10;
  int _minTrackSeconds = 30;
  String _replayGainMode = 'Track'; // 'Off', 'Track', 'Album'
  int _defaultStartupTab = 0; // 0=Home, 1=Tracks, 2=Artists, 3=Playlists
  bool _preferEmbeddedLyrics = true;
  bool _syllableLyricsEnabled = true;
  bool _autoFetchOnlineMetadata = true;
  bool _forceMiniColor = false;
  bool _replayGain = true;
  String _trackFilterMode = 'All';
  static const MethodChannel _audioDeviceChannel = MethodChannel('com.piyush.nami/audio_device');
  String _connectedDacName = "Phone Speaker";
  String _connectedDacType = "Built-in Speaker";
  bool _isExternalAudioConnected = false;
  String _userName = "Piyush";
  String? _userPhotoPath;

  final Map<String, double> _eqBands = {
    '31Hz': 2.5,
    '62Hz': 3.0,
    '125Hz': 1.5,
    '250Hz': 0.5,
    '500Hz': 0.0,
    '1kHz': 0.0,
    '2kHz': 1.5,
    '4kHz': 2.5,
    '8kHz': 3.5,
    '16kHz': 4.0,
  };
  String _selectedEqPreset = 'Hi-Fi Master';

  final TextEditingController _mornyeSearchController = TextEditingController();
  List<MornyeCatalogItem> _mornyeResults = [];
  bool _isMornyeSearching = false;
  String _selectedMornyeService = "Qobuz";
  final String _mornyeDownloadFolder = "/storage/emulated/0/Music";
  final Set<String> _downloadingTitles = {};

  final List<String> _mornyeServices = [
    "Qobuz",
    "Tidal",
    "Apple Music",
    "Spotify Web",
    "Amazon Music",
    "YouTube Music"
  ];
  String _mornyeFilterType = "All";
  String? _activePreviewKey;

  final List<MornyeExtension> _extensions = [
    MornyeExtension(
        name: 'Spotify Web',
        version: 'v1.10.6',
        author: 'Mornye Core',
        format: 'Metadata & Web Stream',
        category: 'Metadata',
        description: 'Spotify metadata provider for Mornye.',
        isInstalled: true),
    MornyeExtension(
        name: 'Amazon Music',
        version: 'v2.3.19',
        author: 'OpenAudio',
        format: 'HD / Ultra HD FLAC',
        category: 'Download',
        description: 'Amazon Music metadata and downloads.',
        isInstalled: true),
    MornyeExtension(
        name: 'Apple Music',
        version: 'v1.4.17',
        author: 'Mornye Core',
        format: '24-bit ALAC',
        category: 'Metadata',
        description: 'Apple Music metadata and lyrics provider.',
        isInstalled: true),
    MornyeExtension(
        name: 'SoundCloud',
        version: 'v1.0.14',
        author: 'Community',
        format: 'HQ Stream & MP3',
        category: 'Download',
        description: 'SoundCloud search and direct streaming.',
        isInstalled: false),
    MornyeExtension(
        name: 'YouTube Music',
        version: 'v2.4.6',
        author: 'Mornye Core',
        format: '256kbps Opus / M4A',
        category: 'Download',
        description: 'YouTube Music metadata and direct stream cache.',
        isInstalled: true),
    MornyeExtension(
        name: 'Deezer',
        version: 'v1.3.11',
        author: 'Community',
        format: '16-bit Lossless FLAC',
        category: 'Download',
        description: 'Deezer metadata and lossless downloader.',
        isInstalled: false),
    MornyeExtension(
        name: 'Qobuz',
        version: 'v1.2.27',
        author: 'OpenAudio',
        format: '24-bit / 192kHz FLAC',
        category: 'Download',
        description: 'Qobuz Studio Master direct 24-bit FLAC download.',
        isInstalled: true),
    MornyeExtension(
        name: 'Tidal Hi-Res MAX',
        version: 'v1.4.2',
        author: 'Mornye Core',
        format: '24-bit / 96kHz FLAC',
        category: 'Download',
        description: 'Tidal Hi-Res MAX streaming resolver.',
        isInstalled: true),
    MornyeExtension(
        name: 'LRCLIB Synced Lyrics',
        version: 'v2.1.0',
        author: 'LRCLIB',
        format: 'Timestamped .LRC',
        category: 'Utility',
        description: 'Real-time karaoke synced timestamp engine.',
        isInstalled: true),
  ];

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  final Map<String, List<AudioTrack>> artistGroups = {};

  final ValueNotifier<int> _artworkTick = ValueNotifier<int>(0);
  final Map<String, String> _artistImagePaths = {};
  final Set<String> _artistDiskChecked = {};
  final Set<String> _artistImageQueued = {};
  final List<String> _artistImageQueue = [];
  final Map<String, int> _artistImageRetryAfter = {};
  int _artistImageActive = 0;

  Directory? _safeThumbDirCache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initV27AudiophileBridge();
    });
    NamiUxPrefs.ensureLoaded();
    activeInstance = this;
    
    

    
    _audioPlayer = _globalMediaKitPlayer;
    if (audioHandler is NamiAudioHandler) {
      final h = audioHandler as NamiAudioHandler;
      h.onNextCallback = _playNextTrack;
      h.onPrevCallback = _playPrevTrack;
    }

    _initHardwareDsp();
    _initAudioSessionAndDac();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStateCache();
      await _loadNamiV12Prefs();
      await NamiV16Prefs.instance.init();
      await NamiScrobbleService.instance.init();
      NamiDownloadManager.instance.onTrackSaved = () async {
        if (mounted) await _fastScanDeviceMusic(forceReparse: false);
      };
      await _requestPermissionsAndInitBackground();
      _startReactiveFolderWatchers();
    });

    _playingSub = _audioPlayer.stream.playing.listen((state) {
      if (mounted) setState(() {});
      if (!state && _currentSong != null) {
        _saveStateCache();
      }
    });

    _completedSub = _audioPlayer.stream.completed.listen((completed) {
      if (!completed) return;
      if (_sleepAfterCurrentTrack) {
        _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _sleepAfterCurrentTrack = false;
            _sleepMinutesRemaining = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Playback paused by Sleep Timer.')));
        }
        return;
      }

      if (_repeatMode == 2 && _currentSong != null) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
        return;
      }

      if (_playNextQueue.isNotEmpty) {
        final next = _playNextQueue.removeAt(0);
        _playSong(next);
        return;
      }

      if (_shuffleEnabled && _filteredSongs.isNotEmpty) {
        _playNextTrack();
        return;
      }

      if (_filteredSongs.isNotEmpty && _currentSong != null) {
        final curIdx = _filteredSongs.indexOf(_currentSong!);
        if (curIdx != -1 && curIdx + 1 < _filteredSongs.length) {
          _playSong(_filteredSongs[curIdx + 1]);
        } else if (_repeatMode == 1) {
          _playSong(_filteredSongs.first);
        }
      }
    });

    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_audioPlayer.state.playing) {
        _totalListenSeconds++;
        _currentTrackSecondsListened++;
        if (_currentTrackSecondsListened == 25 && _currentSong != null) {
          _currentSong!.playCount++;
          _recordTimestampedPlayEvent(_currentSong!);
          NamiScrobbleService.instance.scrobbleTrack(
            title: _currentSong!.title,
            artist: cleanArtistStr(_currentSong!.artist),
            album: _currentSong!.album,
          );
          _saveStateCache();
        }
      }
    });
  }

  Future<void> _initHardwareDsp() async {
    try {
      await _applyDacAndAudioProperties();
      await _applyHardwareEqGains();
    } catch (_) {}
  }

  Future<void> _applyDacAndAudioProperties() async {
    try {
      final dynPlayer = _audioPlayer.platform as dynamic;
      await dynPlayer.setProperty('audio-exclusive', _usbDacExclusive ? 'yes' : 'no');
      final rgVal = (!_replayGain || _replayGainMode == 'Off')
          ? 'no'
          : (_replayGainMode == 'Album' ? 'album' : 'track');
      await dynPlayer.setProperty('replaygain', rgVal);
      await dynPlayer.setProperty('gapless-audio', _gaplessPlayback ? 'yes' : 'no');
    } catch (_) {}
  }

  Future<void> _applyHardwareEqGains() async {
    try {
      final dynPlayer = _audioPlayer.platform as dynamic;
      final List<String> filters = [];

      if (_eqEnabled) {
        const freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
        final values = _eqBands.values.toList();
        for (int i = 0; i < freqs.length && i < values.length; i++) {
          final g = values[i].clamp(-12.0, 12.0).toStringAsFixed(1);
          filters.add('equalizer=f=${freqs[i]}:t=q:w=1.2:g=$g');
        }
      }

      if (_preampGainDb > 0.05) {
        filters.add('volume=volume=${_preampGainDb.toStringAsFixed(1)}dB');
      }

      if (_stereoBalance.abs() > 0.03) {
        final leftG = (1.0 - math.max(0.0, _stereoBalance)).clamp(0.0, 1.0).toStringAsFixed(2);
        final rightG = (1.0 + math.min(0.0, _stereoBalance)).clamp(0.0, 1.0).toStringAsFixed(2);
        filters.add('pan=stereo|c0=$leftG*c0|c1=$rightG*c1');
      }

      if (_soundstagePreset == 'Studio') {
        filters.add('extrastereo=m=1.28');
      } else if (_soundstagePreset == 'Concert') {
        filters.add('aecho=0.8:0.88:42:0.22');
      }

      final afGraph = filters.isEmpty ? '' : 'lavfi=[${filters.join(",")}]';
      await dynPlayer.setProperty('af', afGraph);
    } catch (_) {}
  }

  @override
  void dispose() {
    /* v28_2_dispose_subs */
    _v28PlaySub?.cancel();
    _v28PlSub?.cancel();
    if (activeInstance == this) activeInstance = null;
    _telemetryTimer?.cancel();
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _deviceSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _stopReactiveFolderWatchers();
    _crossfadeEngine.dispose();
    NamiLibraryStore.flushNow();
    _audioPlayer.dispose();
    _trackListScrollController.dispose();
    _artistListScrollController.dispose();
    _searchController.dispose();
    _mornyeSearchController.dispose();
    super.dispose();
  }

  Future<Directory> _ensureThumbDir() async {
    if (_safeThumbDirCache != null) return _safeThumbDirCache!;
    try {
      final internalDir =
          Directory('${Directory.systemTemp.path}/nami_thumbs_v4');
      if (!await internalDir.exists()) {
        await internalDir.create(recursive: true);
      }
      _safeThumbDirCache = internalDir;
      return internalDir;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Future<File> get _cacheFile async {
    final dir = await _ensureThumbDir();
    return File('${dir.path}/nami_state_cache_v4.json');
  }

  Future<void> _loadStateCache() async {
    try {
      final thumbDirBase = await _ensureThumbDir();
      final splitData = await NamiLibraryStore.readSplitTables(thumbDirBase);
      final f = await _cacheFile;
      if (splitData != null || await f.exists()) {
        final data = splitData ?? jsonDecode(await f.readAsString());
        if (data is Map<String, dynamic>) {
          _totalListenSeconds = data['totalListenSeconds'] ?? 0;
          _userName = data['userName'] ?? 'Piyush';
          _userPhotoPath = data['userPhotoPath'];
          _splitMultiArtists = data['splitMultiArtists'] ?? true;
          _autoFetchOnlineMetadata = data['autoFetchOnlineMetadata'] ?? true;
          final rawArtistPaths = data['artistImagePaths'];
          if (rawArtistPaths is Map) {
            rawArtistPaths.forEach((k, v) {
              if (v is String && File(v).existsSync()) {
                _artistImagePaths[k.toString()] = v;
              }
            });
          }
          final rawRetry = data['artistImageRetryAfter'];
          if (rawRetry is Map) {
            rawRetry.forEach((k, v) {
              if (v is int) _artistImageRetryAfter[k.toString()] = v;
            });
          }
          if (data['artistSeparators'] != null) {
            _artistSeparators = List<String>.from(data['artistSeparators']);
          }
          if (data['accentColor'] != null && mounted) {
            final c = Color(data['accentColor']);
            NamiApp.of(context).updateTheme(newAccent: c);
          }
          final thumbDir = await _ensureThumbDir();
          final cachedSongs = (data['cachedTracks'] as List?)
                  ?.map((t) => AudioTrack.fromJson(t))
                  .where((t) => t.path.isNotEmpty && File(t.path).existsSync())
                  .toList() ??
              [];
          for (var s in cachedSongs) {
            final expectedThumb =
                '${thumbDir.path}/${_deterministicPathHash(s.path)}.jpg';
            final tf = File(s.thumbPath ?? expectedThumb);
            if (await tf.exists()) {
              s.thumbPath = tf.path;
              s.albumArt = null;
            }
          }
          _shuffleEnabled = data['shuffleEnabled'] ?? false;
          _repeatMode = data['repeatMode'] ?? 1;
          _ignoreShortClips = data['ignoreShortClips'] ?? true;
          _minTrackSeconds = data['minTrackSeconds'] ?? 30;
          _blurredBackdrop = data['blurredBackdrop'] ?? true;
          _showCodecBadges = data['showCodecBadges'] ?? true;
          _compactTrackTiles = data['compactTrackTiles'] ?? false;
          _resumeSessionOnStartup = data['resumeSessionOnStartup'] ?? true;
          _pauseOnDisconnect = data['pauseOnDisconnect'] ?? true;
          _doubleTapSeekSec = data['doubleTapSeekSec'] ?? 10;
          _replayGainMode = data['replayGainMode'] ?? 'Track';
          _replayGain = _replayGainMode != 'Off';
          _defaultStartupTab = data['defaultStartupTab'] ?? 0;
          if (_defaultStartupTab >= 0 && _defaultStartupTab <= 4) {
            _selectedIndex = _defaultStartupTab;
          }
          if (data['scanFolders'] is List && (data['scanFolders'] as List).isNotEmpty) {
            _scanFolders = List<String>.from(data['scanFolders']);
          }
          if (cachedSongs.isNotEmpty && mounted) {
            final byPath = {for (final t in cachedSongs) t.path: t};
            if (data['customPlaylists'] is List) {
              final loadedPls = <CustomPlaylist>[];
              for (final rawPl in (data['customPlaylists'] as List)) {
                if (rawPl is Map && rawPl['name'] != null) {
                  final pTracks = (rawPl['paths'] as List?)
                          ?.map((p) => byPath[p.toString()])
                          .whereType<AudioTrack>()
                          .toList() ??
                      [];
                  loadedPls.add(CustomPlaylist(name: rawPl['name'].toString(), tracks: pTracks));
                }
              }
              if (loadedPls.isNotEmpty) {
                _customPlaylists
                  ..clear()
                  ..addAll(loadedPls);
              }
            }
            final savedQueue = (data['playNextPaths'] as List?)
                    ?.map((p) => byPath[p.toString()])
                    .whereType<AudioTrack>()
                    .toList() ??
                [];
            final lastPath = data['lastSongPath']?.toString();
            final lastPosMs = (data['lastPositionMs'] as int?) ?? 0;
            final restoredSong = (lastPath != null) ? byPath[lastPath] : null;
            setState(() {
              _songs = cachedSongs;
              _filteredSongs = List.from(cachedSongs);
              _playNextQueue
                ..clear()
                ..addAll(savedQueue);
              if (restoredSong != null) {
                _currentSong = restoredSong;
              }
            });
            if (_resumeSessionOnStartup && restoredSong != null && File(restoredSong.path).existsSync()) {
              await _audioPlayer.open(Media(restoredSong.path), play: false);
              if (lastPosMs > 0) {
                await Future.delayed(const Duration(milliseconds: 180));
                await _audioPlayer.seek(Duration(milliseconds: lastPosMs));
              }
              _syncMediaNotification(restoredSong);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveStateCache() async {
    try {
      final f = await _cacheFile;
      final map = {
        'totalListenSeconds': _totalListenSeconds,
        'userName': _userName,
        'userPhotoPath': _userPhotoPath,
        'splitMultiArtists': _splitMultiArtists,
        'autoFetchOnlineMetadata': _autoFetchOnlineMetadata,
        'artistImagePaths': _artistImagePaths,
        'artistImageRetryAfter': _artistImageRetryAfter,
        'artistSeparators': _artistSeparators,
        'accentColor': mounted ? NamiApp.of(context).accentColor.value : null,
        'shuffleEnabled': _shuffleEnabled,
        'repeatMode': _repeatMode,
        'ignoreShortClips': _ignoreShortClips,
        'minTrackSeconds': _minTrackSeconds,
        'blurredBackdrop': _blurredBackdrop,
        'showCodecBadges': _showCodecBadges,
        'compactTrackTiles': _compactTrackTiles,
        'resumeSessionOnStartup': _resumeSessionOnStartup,
        'pauseOnDisconnect': _pauseOnDisconnect,
        'doubleTapSeekSec': _doubleTapSeekSec,
        'replayGainMode': _replayGainMode,
        'defaultStartupTab': _defaultStartupTab,
        'scanFolders': _scanFolders,
        'customPlaylists': _customPlaylists.map((p) => p.toJson()).toList(),
        'lastSongPath': _currentSong?.path,
        'lastPositionMs': _audioPlayer.state.position.inMilliseconds,
        'playNextPaths': _playNextQueue.map((s) => s.path).toList(),
        'cachedTracks': _songs.map((s) => s.toJson()).toList(),
      };
      NamiLibraryStore.scheduleSave(() async {
        final dir = await _ensureThumbDir();
        await NamiLibraryStore.writeSplitTables(dir, map);
      });
    } catch (_) {}
  }

  Future<void> _exportBackup() async {
    try {
      final backupFile = File('/storage/emulated/0/Download/nami_backup.json');
      final map = {
        'totalListenSeconds': _totalListenSeconds,
        'userName': _userName,
        'accentColor': NamiApp.of(context).accentColor.value,
        'favorites':
            _songs.where((s) => s.isFavorite).map((s) => s.path).toList(),
        'playlists': _customPlaylists.map((p) => p.toJson()).toList(),
      };
      await backupFile.writeAsString(jsonEncode(map));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Backup exported to /Download/nami_backup.json')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final backupFile = File('/storage/emulated/0/Download/nami_backup.json');
      if (await backupFile.exists()) {
        final map = jsonDecode(await backupFile.readAsString());
        final favPaths = Set<String>.from(map['favorites'] ?? []);
        for (var s in _songs) {
          if (favPaths.contains(s.path)) s.isFavorite = true;
        }
        setState(() {});
        _saveStateCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Backup restored successfully!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No backup found in /Download/nami_backup.json')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _refreshRealAudioOutputDevice() async {
    try {
      final res = await _audioDeviceChannel.invokeMethod('getActiveAudioDevice');
      if (res is Map) {
        final devName = (res['name']?.toString() ?? '').trim();
        final devType = (res['type']?.toString() ?? 'Built-in Speaker').trim();
        final isExt = res['isExternal'] == true;
        if (devName.isNotEmpty) {
          if (_pauseOnDisconnect && _isExternalAudioConnected && !isExt && _audioPlayer.state.playing) {
            await _audioPlayer.pause();
          }
          final changed = devName != _connectedDacName || devType != _connectedDacType || isExt != _isExternalAudioConnected;
          final wasExternal = _isExternalAudioConnected;
          _connectedDacName = devName;
          _connectedDacType = devType;
          _isExternalAudioConnected = isExt;
          if (_autoDacExclusiveProfile && wasExternal != isExt) {
            _usbDacExclusive = isExt;
            if (isExt) _eqEnabled = false;
            await _applyDacAndAudioProperties();
            await _applyHardwareEqGains();
          }
          _lastKnownDac = devName;
          if (changed && mounted) setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _initAudioSessionAndDac() async {
    try {
      await _audioPlayer.setRate(_playbackSpeed);
      await _audioPlayer.setPitch(1.0);
      await _refreshRealAudioOutputDevice();
      _deviceSub?.cancel();
      _deviceSub = Stream.periodic(const Duration(seconds: 4)).listen((_) {
        _refreshRealAudioOutputDevice();
      });
    } catch (_) {}
  }

  void _applyLibraryFilter({String? query, String? mode}) {
    final rawQ = (query ?? _searchController.text).trim().toLowerCase();
    final activeMode = mode ?? _trackFilterMode;
    final dupPaths = activeMode == 'Duplicates' ? _computeDuplicateTrackPaths() : const <String>{};
    setState(() {
      if (mode != null) _trackFilterMode = mode;
      _filteredSongs = _songs.where((song) {
        if (activeMode == 'FLAC' && !song.path.toLowerCase().endsWith('.flac')) return false;
        if (activeMode == 'Lossless') {
          final pLow = song.path.toLowerCase();
          if (!(pLow.endsWith('.flac') || pLow.endsWith('.alac') || pLow.endsWith('.wav') || pLow.endsWith('.aiff'))) {
            return false;
          }
        }
        if (activeMode == 'HiRes' && !(song.bitDepth >= 24 || song.sampleRateHz > 48000)) return false;
        if (activeMode == 'HiRate' && song.sampleRateHz <= 48000) return false;
        if (activeMode == 'Fav' && !song.isFavorite) return false;
        if (activeMode == 'Untagged' &&
            !(song.artist == 'Unknown Artist' || song.album == 'Unknown Album' || song.genre.trim().isEmpty)) {
          return false;
        }
        if (activeMode == 'NoCover' &&
            !(song.albumArt == null && (song.thumbPath == null || !File(song.thumbPath!).existsSync()))) {
          return false;
        }
        if (activeMode == 'Duplicates' && !dupPaths.contains(song.path)) return false;
        if (rawQ.isEmpty) return true;
        return song.title.toLowerCase().contains(rawQ) ||
            song.artist.toLowerCase().contains(rawQ) ||
            song.album.toLowerCase().contains(rawQ) ||
            song.path.toLowerCase().contains(rawQ);
      }).toList();
      _applySortToFilteredSongs();
    });
  }

  void _filterSongs(String query) {
    _applyLibraryFilter(query: query);
  }

  void _locateActivePlayingTrack() {
    if (_currentSong == null || _filteredSongs.isEmpty) return;
    final idx = _filteredSongs.indexOf(_currentSong!);
    if (idx != -1 && _trackListScrollController.hasClients) {
      final rowExtent = _compactTrackTiles ? 56.0 : 76.0;
      final maxOff = _trackListScrollController.position.maxScrollExtent;
      final target = (54.0 + idx * rowExtent).clamp(0.0, maxOff);
      _trackListScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  
  Future<void> _syncMediaNotification(AudioTrack song) async {
  if (audioHandler is! NamiAudioHandler) return;
  String? artPath;
  try {
    if (song.thumbPath != null && File(song.thumbPath!).existsSync()) {
      artPath = song.thumbPath!;
    } else if (song.albumArt != null && song.albumArt!.isNotEmpty) {
      final f = File('${Directory.systemTemp.path}/nami_art_${song.path.hashCode}.jpg');
      if (!f.existsSync()) await f.writeAsBytes(song.albumArt!, flush: true);
      artPath = f.path;
    }
  } catch (_) {}
  (audioHandler as NamiAudioHandler).updateMetadata(
    id: song.path,
    title: song.title,
    artist: cleanArtistStr(song.artist),
    album: song.album,
    artUri: artPath,
    duration: song.duration.inMilliseconds > 0 ? song.duration : null,
  );
}

Future<void> _playSong(AudioTrack song) async {
    if (song.path.isEmpty) return;
    final prevPath = _audioPlayer.state.playing ? _currentSong?.path : null;
    final prevPos = _audioPlayer.state.position;
    _currentSong = song;
    _currentTrackSecondsListened = 0;
    _historyTracks.remove(song);
    _historyTracks.insert(0, song);
    _syncMediaNotification(song);
    if (_autoColoring) {
      if (song.albumArt != null) {
        final dominant =
            _extractDominantColor(song.albumArt, const Color(0xFFE53935));
        NamiApp.of(context).updateTheme(newAccent: dominant);
      } else if (song.thumbPath != null) {
        NamiLibraryStore.readLazyCoverBytes(song.thumbPath).then((bytes) {
          if (bytes != null && mounted && _currentSong?.path == song.path) {
            final dominant = _extractDominantColor(bytes, const Color(0xFFE53935));
            NamiApp.of(context).updateTheme(newAccent: dominant);
          }
        });
      }
    }
    NamiScrobbleService.instance.submitPlayingNow(
      title: song.title,
      artist: cleanArtistStr(song.artist),
      album: song.album,
    );
    if (mounted) setState(() {});
    _fetchLyricsOnline(song);

    if (song.albumArt == null || song.artist == 'Unknown Artist') {
      _ensureThumbDir().then((dir) async {
        await _extractAudioMetadataUniversal(song, dir);
        if ((song.albumArt == null || song.artist == 'Unknown Artist') &&
            _autoFetchOnlineMetadata) {
          await _enrichTrackOnlineIfMissing(song, dir);
        }
        if (mounted) setState(() {});
        _saveStateCache();
        _syncMediaNotification(song);
      });
    }

    try {
      await _crossfadeEngine.transition(
        primaryPlayer: _audioPlayer,
        outgoingPath: prevPath,
        outgoingPos: prevPos,
        incomingPath: song.path,
        crossfadeSeconds: _crossfadeSeconds,
        playbackSpeed: _playbackSpeed,
        playbackPitch: _playbackPitch,
      );
      if (_audioPlayer.state.duration != null &&
          _audioPlayer.state.duration!.inSeconds > 0) {
        song.duration = _audioPlayer.state.duration!;
        if (song.fileSize > 0) {
          song.bitrateKbps =
              ((song.fileSize * 8) ~/ 1000) ~/ song.duration.inSeconds;
        }
        if (mounted) setState(() {});
      }
      _saveStateCache();
      _syncMediaNotification(song);
    } catch (_) {}
  }

  void _playNextTrack() {
    if (_playNextQueue.isNotEmpty) {
      final next = _playNextQueue.removeAt(0);
      _playSong(next);
      return;
    }
    if (_filteredSongs.isNotEmpty) {
      if (_shuffleEnabled && _filteredSongs.length > 1) {
        final rng = math.Random();
        int randIdx = rng.nextInt(_filteredSongs.length);
        if (_currentSong != null && _filteredSongs[randIdx].path == _currentSong!.path) {
          randIdx = (randIdx + 1) % _filteredSongs.length;
        }
        _playSong(_filteredSongs[randIdx]);
        return;
      }
      if (_currentSong != null) {
        int nextIdx =
            (_filteredSongs.indexOf(_currentSong!) + 1) % _filteredSongs.length;
        _playSong(_filteredSongs[nextIdx]);
      } else {
        _playSong(_filteredSongs.first);
      }
    }
  }

  void _playPrevTrack() {
    if (_filteredSongs.isNotEmpty && _currentSong != null) {
      int prevIdx = (_filteredSongs.indexOf(_currentSong!) -
              1 +
              _filteredSongs.length) %
          _filteredSongs.length;
      _playSong(_filteredSongs[prevIdx]);
    }
  }

  void _shufflePlay() {
    if (_songs.isNotEmpty) {
      List<AudioTrack> shuffled = List.from(_songs)..shuffle();
      _playSong(shuffled.first);
    }
  }

  void _startSleepTimer(int minutes, {bool stopAfterTrack = false}) {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _audioPlayer.setVolume(100.0);

    setState(() {
      _sleepAfterCurrentTrack = stopAfterTrack;
      _sleepMinutesRemaining = minutes;
    });

    if (stopAfterTrack) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Playback will stop after current track')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sleep Timer set for $minutes minutes')));

    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_sleepMinutesRemaining <= 1) {
        timer.cancel();
        _beginSmoothFadeOut();
      } else {
        setState(() => _sleepMinutesRemaining--);
      }
    });
  }

  void _beginSmoothFadeOut() {
    int fadeSteps = 30;
    int currentStep = 0;
    _fadeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      currentStep++;
      double volume = ((1.0 - (currentStep / fadeSteps)) * 100.0).clamp(0.0, 100.0);
      _audioPlayer.setVolume(volume);
      if (currentStep >= fadeSteps) {
        t.cancel();
        _audioPlayer.pause();
        _audioPlayer.setVolume(100.0);
        setState(() => _sleepMinutesRemaining = 0);
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _audioPlayer.setVolume(100.0);
    setState(() {
      _sleepMinutesRemaining = 0;
      _sleepAfterCurrentTrack = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sleep Timer cancelled')));
  }

  void _showSleepTimerDialog() {
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bedtime_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  const Text('Sleep Timer',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [15, 30, 45, 60, 90]
                    .map((mins) => ActionChip(
                          label: Text('$mins min'),
                          backgroundColor: const Color(0xFF0A0A0E),
                          onPressed: () {
                            Navigator.pop(context);
                            _startSleepTimer(mins);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.music_off_rounded, color: Colors.white70),
                title: const Text('End of current track'),
                onTap: () {
                  Navigator.pop(context);
                  _startSleepTimer(0, stopAfterTrack: true);
                },
              ),
              if (_sleepMinutesRemaining > 0 || _sleepAfterCurrentTrack)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                  title: const Text('Turn Off Sleep Timer',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _cancelSleepTimer();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMpvSampleFmt(String rawFmt, int fallbackBits) {
    final f = rawFmt.toLowerCase().trim();
    if (f.contains('16')) return '16-Bit';
    if (f.contains('24')) return '24-Bit';
    if (f.contains('32')) return '32-Bit';
    if (f.contains('float') || f.contains('dbl')) return '32-Bit Float';
    return '$fallbackBits-Bit';
  }

  Future<Map<String, String>> _queryLiveMpvTelemetry(AudioTrack song) async {
    await _refreshRealAudioOutputDevice();
    int srcRate = song.sampleRateHz;
    int outRate = song.sampleRateHz;
    String srcFmt = '${song.bitDepth}-Bit';
    String outFmt = '${song.bitDepth}-Bit';
    String channels = '2';
    String activeDev = _connectedDacName;

    try {
      final dyn = _audioPlayer.platform as dynamic;
      Future<String> prop(String key) async {
        try {
          final v = await dyn.getProperty(key);
          return (v?.toString() ?? '').trim();
        } catch (_) {
          return '';
        }
      }

      final sRateStr = await prop('audio-params/samplerate');
      final oRateStr = await prop('audio-out-params/samplerate');
      final sFmtStr = await prop('audio-params/format');
      final oFmtStr = await prop('audio-out-params/format');
      final chStr = await prop('audio-out-params/channel-count');
      final devStr = await prop('audio-device');

      if (int.tryParse(sRateStr) != null && int.parse(sRateStr) > 0) {
        srcRate = int.parse(sRateStr);
      }
      if (int.tryParse(oRateStr) != null && int.parse(oRateStr) > 0) {
        outRate = int.parse(oRateStr);
      } else {
        outRate = srcRate;
      }
      if (sFmtStr.isNotEmpty) srcFmt = _formatMpvSampleFmt(sFmtStr, song.bitDepth);
      if (oFmtStr.isNotEmpty) {
        outFmt = _formatMpvSampleFmt(oFmtStr, song.bitDepth);
      } else {
        outFmt = srcFmt;
      }
      if (chStr.isNotEmpty && chStr != '0') channels = chStr;
      if (devStr.isNotEmpty && devStr != 'auto' && devStr != 'null') {
        activeDev = devStr;
      }
    } catch (_) {}

    final isExactRate = (srcRate == outRate) && !_eqEnabled;
    return {
      'srcRate': '$srcRate',
      'outRate': '$outRate',
      'srcFmt': srcFmt,
      'outFmt': outFmt,
      'channels': channels,
      'device': activeDev,
      'isBitPerfect': isExactRate ? '1' : '0',
    };
  }

  void _showAudioPathDetails(AudioTrack song) {
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF121218),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => FutureBuilder<Map<String, String>>(
        future: _queryLiveMpvTelemetry(song),
        builder: (context, snap) {
          final data = snap.data;
          final srcRate = int.tryParse(data?['srcRate'] ?? '') ?? song.sampleRateHz;
          final outRate = int.tryParse(data?['outRate'] ?? '') ?? srcRate;
          final srcKhz = (srcRate / 1000.0).toStringAsFixed(1);
          final outKhz = (outRate / 1000.0).toStringAsFixed(1);
          final srcFmt = data?['srcFmt'] ?? '${song.bitDepth}-Bit';
          final outFmt = data?['outFmt'] ?? '${song.bitDepth}-Bit';
          final ch = data?['channels'] ?? '2';
          final isBitPerfect = (data?['isBitPerfect'] ?? (_eqEnabled ? '0' : '1')) == '1';
          final pcmKbps = (outRate * song.bitDepth * (int.tryParse(ch) ?? 2)) ~/ 1000;

          final statusLabel = _eqEnabled
              ? 'libmpv DSP'
              : (isBitPerfect ? 'Bit-perfect' : 'OS Resampled');
          final statusColor = _eqEnabled
              ? Colors.cyanAccent
              : (isBitPerfect ? Colors.amber : Colors.orangeAccent);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Audio path',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: Colors.white)),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withValues(alpha: 0.45))),
                        child: Row(
                          children: [
                            Icon(
                              isBitPerfect ? Icons.verified_rounded : Icons.bolt_rounded,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [Text('$outKhz kHz', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)), const SizedBox(height: 2), const Text('Output Rate', style: TextStyle(fontSize: 10, color: Colors.white54))]))),
                    const SizedBox(width: 8),
                    Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [Text(outFmt, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)), const SizedBox(height: 2), const Text('Word Depth', style: TextStyle(fontSize: 10, color: Colors.white54))]))),
                    const SizedBox(width: 8),
                    Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Column(children: [Text('$pcmKbps kbps', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)), const SizedBox(height: 2), const Text('PCM Stream', style: TextStyle(fontSize: 10, color: Colors.white54))]))),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: Column(children: [
                      _buildAudioPathNode(icon: Icons.music_note_rounded, title: 'Source • PCM', subtitle: '$srcFmt • $srcKhz kHz • $ch ch • $pcmKbps kbps', showConnectorDown: true),
                      _buildAudioPathNode(
                        icon: Icons.bolt_rounded,
                        title: _eqEnabled ? 'libmpv DSP Pipeline ($_selectedEqPreset)' : (isBitPerfect ? 'Bit-perfect Direct (1:1 Rate)' : 'Audio Clock Resampler'),
                        subtitle: _eqEnabled ? '10-Band ISO Parametric EQ Active' : (isBitPerfect ? '$srcKhz kHz -> $outKhz kHz (No Resampling)' : '$srcKhz kHz -> $outKhz kHz'),
                        showConnectorDown: true,
                      ),
                      _buildAudioPathNode(icon: Icons.settings_input_composite_rounded, title: 'libmpv Hardware Out', subtitle: '$outFmt • $outKhz kHz • Exclusive=${_usbDacExclusive ? "ON" : "OFF"}', showConnectorDown: true),
                      _buildAudioPathNode(
                        icon: _isExternalAudioConnected ? Icons.headphones_rounded : Icons.smartphone_rounded,
                        title: _connectedDacName,
                        subtitle: _isExternalAudioConnected ? '$_connectedDacType • Connected' : '$_connectedDacType • Android Device',
                        showConnectorDown: false,
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioPathNode({
    required IconData icon,
    required String title,
    required String? subtitle,
    required bool showConnectorDown,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.2),
              ),
              child: Icon(icon, size: 18, color: Colors.white70),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Colors.white)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (showConnectorDown)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
            child: Icon(Icons.south_rounded,
                size: 12, color: Colors.white.withValues(alpha: 0.25)),
          ),
      ],
    );
  }

  void _showEqualizerSheet() {
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setEqState) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      const Text('Hardware Equalizer & DSP',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                    ],
                  ),
                  Switch(
                    value: _eqEnabled,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) async {
                      setEqState(() => _eqEnabled = v);
                      setState(() {});
                      await _applyHardwareEqGains();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(12), border: Border.all(color: _eqEnabled ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.45) : Colors.white10)),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(_eqEnabled ? 'Active Preset: $_selectedEqPreset' : 'Bit-Perfect Bypass (EQ Off)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
    Text('Preamp ${_preampGainDb >= 0 ? "+" : ""}${_preampGainDb.toStringAsFixed(1)} dB', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
  ]),
),
const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Hi-Fi Master',
                    'AutoEQ: Harman IE',
                    'AutoEQ: IEM Neutral',
                    'AutoEQ: Studio DF',
                    'Bass Boost',
                    'Flat',
                    'Vocal Clear',
                    'Rock',
                    'Treble Sparkle'
                  ].map((preset) {
                    final sel = _selectedEqPreset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(preset,
                            style: TextStyle(
                                fontSize: 12,
                                color: sel ? Colors.white : Colors.white70)),
                        selected: sel,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: const Color(0xFF0A0A0E),
                        onSelected: (val) async {
                          setEqState(() {
                            _selectedEqPreset = preset;
                            final curves = <String, List<double>>{
                              'Hi-Fi Master':        [2.5, 3.0, 1.5, 0.5, 0.0, 0.0, 1.5, 2.5, 3.5, 4.0],
                              'AutoEQ: Harman IE':   [4.2, 3.5, 1.0, -1.2, -0.5, 0.4, 2.2, 3.4, 1.8, 1.0],
                              'AutoEQ: IEM Neutral': [1.8, 1.2, 0.0, -0.8, 0.0, 0.5, 1.6, 2.0, 1.2, 0.5],
                              'AutoEQ: Studio DF':   [-1.0, -0.5, 0.0, 0.0, 0.5, 1.2, 2.4, 3.0, 2.2, 1.5],
                              'Bass Boost':          [7.0, 6.0, 4.0, 1.5, 0.0, 0.0, 0.5, 1.0, 1.5, 2.0],
                              'Flat':                [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
                              'Vocal Clear':         [-2.0, -1.5, 0.0, 1.2, 2.5, 3.8, 4.2, 3.5, 2.0, 1.5],
                              'Rock':                [5.0, 4.0, 2.0, -0.5, -1.5, -0.5, 2.0, 3.5, 4.5, 4.5],
                              'Treble Sparkle':      [0.5, 1.0, 0.0, 0.0, 0.5, 1.0, 2.5, 4.5, 6.0, 6.5],
                            };
                            final vals = curves[preset] ?? List<double>.filled(10, 0.0);
                            final keys = _eqBands.keys.toList();
                            for (int i = 0; i < keys.length && i < vals.length; i++) {
                              _eqBands[keys[i]] = vals[i];
                            }
                          });
                          setState(() {});
                          await _applyHardwareEqGains();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              ..._eqBands.entries.map((e) => Row(
                    children: [
                      SizedBox(
                          width: 50,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70))),
                      Expanded(
                        child: Slider(
                          value: e.value,
                          min: -10.0,
                          max: 10.0,
                          activeColor: _eqEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          onChanged: _eqEnabled
                              ? (val) async {
                                  setEqState(() => _eqBands[e.key] = val);
                                  setState(() {});
                                  await _applyHardwareEqGains();
                                }
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text('${e.value.toStringAsFixed(1)}dB',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                    ],
                  )),
              const Divider(color: Colors.white12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Crossfade: ${_crossfadeSeconds == 0 ? "Off" : "${_crossfadeSeconds}s"}',
                      style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _crossfadeSeconds.toDouble().clamp(0.0, 8.0),
                      min: 0.0,
                      max: 8.0,
                      divisions: 8,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (v) {
                        setEqState(() => _crossfadeSeconds = v.round());
                        setState(() {});
                        _saveNamiV12Prefs();
                      },
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pitch: ${_playbackPitch.toStringAsFixed(2)}x',
                      style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _playbackPitch.clamp(0.75, 1.25),
                      min: 0.75,
                      max: 1.25,
                      divisions: 20,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (v) {
                        setEqState(() => _playbackPitch = v);
                        _audioPlayer.setPitch(v);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _stereoBalance.abs() < 0.04
                        ? 'Balance: Center'
                        : (_stereoBalance < 0
                            ? 'Balance: L ${(-_stereoBalance * 100).round()}%'
                            : 'Balance: R ${(_stereoBalance * 100).round()}%'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: _stereoBalance.clamp(-1.0, 1.0),
                      min: -1.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (v) async {
                        setEqState(() => _stereoBalance = v);
                        setState(() {});
                        await _applyHardwareEqGains();
                      },
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Loudness Boost: +${_preampGainDb.toStringAsFixed(1)} dB',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: _preampGainDb,
                    min: 0.0,
                    max: 10.0,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) async {
                      setEqState(() => _preampGainDb = v);
                      setState(() {});
                      await _applyHardwareEqGains();
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tempo: ${_playbackSpeed.toStringAsFixed(2)}x',
                      style: const TextStyle(fontSize: 12)),
                  Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) {
                      setEqState(() => _playbackSpeed = v);
                      _audioPlayer.setRate(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Soundstage: $_soundstagePreset',
                      style: const TextStyle(fontSize: 12)),
                  Wrap(
                    spacing: 6,
                    children: ['Off', 'Studio', 'Concert']
                        .map((p) => ChoiceChip(
                              label:
                                  Text(p, style: const TextStyle(fontSize: 10)),
                              selected: _soundstagePreset == p,
                              selectedColor:
                                  Theme.of(context).colorScheme.primary,
                              onSelected: (_) async {
                                setEqState(() => _soundstagePreset = p);
                                setState(() {});
                                await _applyHardwareEqGains();
                              },
                            ))
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        )),
      ),
    );
  }

  void _showNamiLyricsManagerSheet(AudioTrack song) {
    final searchCtrl =
        TextEditingController(text: '${song.artist} - ${song.title}');
    final lyricsEditCtrl = TextEditingController(
      text: song.rawLyrics.isNotEmpty
          ? song.rawLyrics
          : '[ti:${song.title}]\n[ar:${song.artist}]\n[al:${song.album}]\n\n[00:05.00]Instrumental / Intro...',
    );
    List<dynamic> searchResults = [];
    bool isSearchingLyrics = false;
    bool isEditingInline = false;

    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final accent = Theme.of(context).colorScheme.primary;
          final hasLyrics = lyricsEditCtrl.text.trim().isNotEmpty;

          Future<void> runSearch() async {
            if (searchCtrl.text.trim().isEmpty) return;
            setSheetState(() => isSearchingLyrics = true);
            try {
              final res = await http.get(
                Uri.parse(
                    'https://lrclib.net/api/search?q=${Uri.encodeComponent(searchCtrl.text.trim())}'),
                headers: _httpHeaders,
              ).timeout(const Duration(seconds: 6));
              if (res.statusCode == 200) {
                final data = jsonDecode(res.body);
                if (data is List) {
                  setSheetState(() {
                    searchResults = data;
                    isSearchingLyrics = false;
                  });
                }
              } else {
                setSheetState(() => isSearchingLyrics = false);
              }
            } catch (_) {
              setSheetState(() => isSearchingLyrics = false);
            }
          }

          return Container(
            margin: EdgeInsets.fromLTRB(
                12, 36, 12, MediaQuery.of(context).viewInsets.bottom + 14),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0E),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(hasLyrics ? '1' : '0',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      const Text('Lyrics',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Toggle Syllable Karaoke Sweep',
                        icon: Icon(Icons.text_fields_rounded,
                            size: 20,
                            color:
                                _syllableLyricsEnabled ? accent : Colors.white70),
                        onPressed: () {
                          setState(() =>
                              _syllableLyricsEnabled = !_syllableLyricsEnabled);
                          setSheetState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Syllable Sweep Highlight: ${_syllableLyricsEnabled ? "ON" : "OFF"}')),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Shift Timestamps -0.25s (Earlier)',
                        icon: const Icon(Icons.fast_rewind_rounded, size: 19, color: Colors.white70),
                        onPressed: () {
                          setSheetState(() {
                            lyricsEditCtrl.text = _shiftLrcTimestamps(lyricsEditCtrl.text, -0.25);
                          });
                        },
                      ),
                      IconButton(
                        tooltip: 'Shift Timestamps +0.25s (Later)',
                        icon: const Icon(Icons.fast_forward_rounded, size: 19, color: Colors.white70),
                        onPressed: () {
                          setSheetState(() {
                            lyricsEditCtrl.text = _shiftLrcTimestamps(lyricsEditCtrl.text, 0.25);
                          });
                        },
                      ),
                      IconButton(
                        tooltip: 'Copy LRC Text',
                        icon: const Icon(Icons.copy_all_rounded,
                            size: 20, color: Colors.white70),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: lyricsEditCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Copied LRC lyrics to clipboard')));
                        },
                      ),
                      IconButton(
                        tooltip: 'Import .lrc from /Download',
                        icon: const Icon(Icons.file_download_outlined,
                            size: 20, color: Colors.white70),
                        onPressed: () async {
                          try {
                            final dl = Directory('/storage/emulated/0/Download');
                            if (await dl.exists()) {
                              final lrcFiles = dl
                                  .listSync()
                                  .whereType<File>()
                                  .where((f) =>
                                      f.path.toLowerCase().endsWith('.lrc'))
                                  .toList();
                              if (lrcFiles.isNotEmpty) {
                                final content =
                                    await lrcFiles.first.readAsString();
                                setSheetState(
                                    () => lyricsEditCtrl.text = content);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'No .lrc files found in /Download')));
                              }
                            }
                          } catch (_) {}
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onSubmitted: (_) => runSearch(),
                    style: const TextStyle(fontSize: 13.5, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0E0E14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: accent)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.subdirectory_arrow_left_rounded,
                            size: 19, color: Colors.white70),
                        onPressed: runSearch,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      setState(
                          () => _preferEmbeddedLyrics = !_preferEmbeddedLyrics);
                      setSheetState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.subtitles_outlined,
                              size: 20, color: Colors.white70),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Prefer embedded lyrics',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600)),
                                Text('Global',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white54)),
                              ],
                            ),
                          ),
                          Text(
                            _preferEmbeddedLyrics ? 'Synced' : 'Online',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (isSearchingLyrics)
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: CircularProgressIndicator(color: accent)))
                  else if (searchResults.isNotEmpty)
                    Container(
                      height: 140,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12121A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: RefreshIndicator(color: Theme.of(context).colorScheme.primary, backgroundColor: const Color(0xFF14141E), onRefresh: () async { await Future.delayed(const Duration(milliseconds: 600)); setState((){}); }, child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (ctx, i) {
                          final item = searchResults[i];
                          final t = item['trackName'] ?? 'Unknown';
                          final a = item['artistName'] ?? 'Unknown';
                          final synced =
                              (item['syncedLyrics'] ?? '').toString();
                          final plain = (item['plainLyrics'] ?? '').toString();
                          return ListTile(
                            dense: true,
                            leading: Icon(
                                synced.isNotEmpty
                                    ? Icons.lyrics_rounded
                                    : Icons.notes_rounded,
                                color:
                                    synced.isNotEmpty ? accent : Colors.white54,
                                size: 18),
                            title: Text(t,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '$a • ${synced.isNotEmpty ? "Synced LRC" : "Plain"}',
                                style: const TextStyle(fontSize: 10.5)),
                            onTap: () {
                              setSheetState(() {
                                lyricsEditCtrl.text =
                                    synced.isNotEmpty ? synced : plain;
                                searchResults = [];
                              });
                            },
                          );
                        },
                      )),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lyrics_outlined,
                                size: 18, color: Colors.white70),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Synced',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        size: 11, color: accent),
                                    const SizedBox(width: 4),
                                    Text('Active',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: accent,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                  isEditingInline
                                      ? Icons.check_rounded
                                      : Icons.edit_outlined,
                                  size: 18,
                                  color: Colors.white70),
                              onPressed: () => setSheetState(
                                  () => isEditingInline = !isEditingInline),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.white54),
                              onPressed: () =>
                                  setSheetState(() => lyricsEditCtrl.clear()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 155,
                          child: Stack(
                            children: [
                              TextField(
                                controller: lyricsEditCtrl,
                                maxLines: null,
                                expands: true,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.45,
                                    color: Colors.white70,
                                    fontFamily: 'monospace'),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.only(right: 28),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: InkWell(
                                  onTap: runSearch,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Icon(Icons.refresh_rounded,
                                        size: 16, color: Colors.white70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.add_box_outlined,
                        size: 20, color: Colors.white70),
                    title: const Text('Add',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    onTap: () {
                      setSheetState(() {
                        lyricsEditCtrl.text =
                            '${lyricsEditCtrl.text}\n[00:00.00]New lyric line';
                      });
                    },
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.note_add_outlined,
                        size: 20, color: Colors.white70),
                    title: const Text('Add LRC file',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    onTap: () async {
                      try {
                        final lrcPath =
                            '${song.path.substring(0, song.path.lastIndexOf('.'))}.lrc';
                        final f = File(lrcPath);
                        if (await f.exists()) {
                          final txt = await f.readAsString();
                          setSheetState(() => lyricsEditCtrl.text = txt);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'No sidecar .lrc found next to track')));
                        }
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF181822),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: runSearch,
                        child: const Text('Search',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF181822),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: () async {
                          final updated = lyricsEditCtrl.text;
                          setState(() {
                            song.rawLyrics = updated;
                            song.parsedLyrics = _parseLrc(updated);
                            song.isLyricsFetched = true;
                          });
                          try {
                            final lrcPath =
                                '${song.path.substring(0, song.path.lastIndexOf('.'))}.lrc';
                            await File(lrcPath).writeAsString(updated);
                          } catch (_) {}
                          if (context.mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Synced lyrics saved!')));
                          }
                        },
                        child: const Text('Done',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showArtworkSelectorSheet(
    BuildContext parentContext,
    AudioTrack song,
    void Function(Uint8List bytes, String savedPath) onSelected,
  ) async {
    final queryCtrl = TextEditingController(
      text: '${song.artist != "Unknown Artist" ? song.artist : ""} ${song.title}'.trim(),
    );
    List<String> onlineUrls = [];
    List<File> localImages = [];
    bool isLoadingOnline = false;
    bool localScanned = false;

    Future<void> searchOnlineArt(StateSetter setModalState) async {
      final q = queryCtrl.text.trim();
      if (q.isEmpty) return;
      setModalState(() => isLoadingOnline = true);
      try {
        final uri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(q)}&media=music&entity=song&limit=18');
        final res = await http.get(uri).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final results = (data['results'] as List?) ?? [];
          final urls = <String>{};
          for (final r in results) {
            final u = r['artworkUrl100']?.toString().replaceAll('100x100bb', '600x600bb');
            if (u != null && u.isNotEmpty) urls.add(u);
          }
          setModalState(() {
            onlineUrls = urls.toList();
            isLoadingOnline = false;
          });
        } else {
          setModalState(() => isLoadingOnline = false);
        }
      } catch (_) {
        setModalState(() => isLoadingOnline = false);
      }
    }

    Future<void> scanGalleryImages(StateSetter setModalState) async {
      if (localScanned) return;
      localScanned = true;
      final found = <File>[];
      for (final dPath in ['/storage/emulated/0/Download', '/storage/emulated/0/Pictures', '/storage/emulated/0/DCIM/Camera', '/storage/emulated/0/Music']) {
        try {
          final d = Directory(dPath);
          if (await d.exists()) {
            await for (final entity in d.list(recursive: false, followLinks: false)) {
              if (entity is File) {
                final l = entity.path.toLowerCase();
                if (l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.webp')) {
                  found.add(entity);
                  if (found.length >= 60) break;
                }
              }
            }
          }
        } catch (_) {}
      }
      setModalState(() => localImages = found);
    }

    await showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0C14),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (!localScanned && onlineUrls.isEmpty && !isLoadingOnline) {
            Future.microtask(() {
              scanGalleryImages(setModalState);
              searchOnlineArt(setModalState);
            });
          }
          final accent = Theme.of(ctx).colorScheme.primary;
          return DefaultTabController(
            length: 2,
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 12),
                child: Column(
                  children: [
                    Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const Text('Select Cover Artwork', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 8),
                    TabBar(
                      indicatorColor: accent,
                      tabs: const [
                        Tab(icon: Icon(Icons.cloud_download_rounded, size: 18), text: 'Fetch Online'),
                        Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Device Gallery'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Column(
                            children: [
                              TextField(
                                controller: queryCtrl,
                                onSubmitted: (_) => searchOnlineArt(setModalState),
                                decoration: InputDecoration(
                                  hintText: 'Search artist or song cover...',
                                  filled: true,
                                  fillColor: const Color(0xFF151522),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                  suffixIcon: IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => searchOnlineArt(setModalState)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: isLoadingOnline
                                    ? Center(child: CircularProgressIndicator(color: accent))
                                    : GridView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                                        itemCount: onlineUrls.length,
                                        itemBuilder: (c, i) => GestureDetector(
                                          onTap: () async {
                                            try {
                                              final res = await http.get(Uri.parse(onlineUrls[i])).timeout(const Duration(seconds: 8));
                                              if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                                                final dir = await _ensureThumbDir();
                                                final f = File('${dir.path}/custom_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                                await f.writeAsBytes(res.bodyBytes);
                                                onSelected(res.bodyBytes, f.path);
                                                if (ctx.mounted) Navigator.pop(ctx);
                                              }
                                            } catch (_) {}
                                          },
                                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(onlineUrls[i], fit: BoxFit.cover)),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                            itemCount: localImages.length,
                            itemBuilder: (c, i) => GestureDetector(
                              onTap: () async {
                                try {
                                  final b = await localImages[i].readAsBytes();
                                  final dir = await _ensureThumbDir();
                                  final f = File('${dir.path}/custom_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                  await f.writeAsBytes(b);
                                  onSelected(b, f.path);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (_) {}
                              },
                              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(localImages[i], fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 300)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTagEditorDialog(AudioTrack song) {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    final albumCtrl = TextEditingController(text: song.album);
    final genreCtrl = TextEditingController(text: song.genre);
    final lyricsCtrl = TextEditingController(text: song.rawLyrics);
    final coverPathCtrl = TextEditingController();

    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF101018),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Tags & Artwork',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                    ),
                    icon: const Icon(Icons.lyrics_outlined, size: 16),
                    label: const Text('Lyrics Manager',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      _showNamiLyricsManagerSheet(song);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                      child: Text('Track #${song.trackNumber.isNotEmpty ? song.trackNumber : "1"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.image_search_rounded, size: 16),
                        label: const Text('Pick Cover', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () => _showArtworkSelectorSheet(context, song, (bytes, savedPath) {
                          setState(() {
                            song.albumArt = bytes;
                            song.thumbPath = savedPath;
                          });
                          _artworkTick.value++;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                        label: const Text('Auto-Fetch Info', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final dir = await _ensureThumbDir();
                          song.isOnlineEnriched = false;
                          await _enrichTrackOnlineIfMissing(song, dir, force: true);
                          titleCtrl.text = song.title;
                          artistCtrl.text = song.artist;
                          albumCtrl.text = song.album;
                          genreCtrl.text = song.genre;
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fetched online cover & metadata!')),
                            );
                          }
                          _saveStateCache();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _buildRichInputField(titleCtrl, 'Title'),
              const SizedBox(height: 10),
              _buildRichInputField(artistCtrl, 'Artist'),
              const SizedBox(height: 10),
              _buildRichInputField(albumCtrl, 'Album'),
              const SizedBox(height: 10),
              _buildRichInputField(genreCtrl, 'Genre'),
              const SizedBox(height: 10),
              _buildRichInputField(coverPathCtrl,
                  'Custom Cover Image Path (e.g. /storage/emulated/0/Download/cover.jpg)'),
              const SizedBox(height: 10),
              _buildRichInputField(lyricsCtrl, 'Lyrics (.LRC timestamps)',
                  maxLines: 3),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey))),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary),
                    onPressed: () async {
                      Uint8List? customArt;
                      if (coverPathCtrl.text.trim().isNotEmpty) {
                        try {
                          final imgFile = File(coverPathCtrl.text.trim());
                          if (await imgFile.exists()) {
                            customArt = await imgFile.readAsBytes();
                            final thumbDir = await _ensureThumbDir();
                            final thumbFile = File(
                                '${thumbDir.path}/${_deterministicPathHash(song.path)}.jpg');
                            await thumbFile.writeAsBytes(customArt);
                            song.thumbPath = thumbFile.path;
                          }
                        } catch (_) {}
                      }
                      setState(() {
                        song.title = titleCtrl.text.trim();
                        song.artist = artistCtrl.text.trim();
                        song.album = albumCtrl.text.trim();
                        song.genre = genreCtrl.text.trim();
                        song.rawLyrics = lyricsCtrl.text;
                        song.parsedLyrics = _parseLrc(song.rawLyrics);
                        if (customArt != null) song.albumArt = customArt;
                      });
                      _artworkTick.value++;
                      if (song.rawLyrics.trim().isNotEmpty) {
                        try {
                          final lrcPath =
                              '${song.path.substring(0, song.path.lastIndexOf('.'))}.lrc';
                          await File(lrcPath).writeAsString(song.rawLyrics);
                        } catch (_) {}
                      }
                      final coverBytesToEmbed = customArt ??
                          song.albumArt ??
                          await NamiLibraryStore.readLazyCoverBytes(song.thumbPath);
                      final wroteToDisk = await NamiTagWriter.writeTagsToFile(
                        path: song.path,
                        title: song.title,
                        artist: song.artist,
                        album: song.album,
                        genre: song.genre,
                        year: song.year,
                        lyrics: song.rawLyrics,
                        coverBytes: coverBytesToEmbed,
                      );
                      if (context.mounted) Navigator.pop(context);
                      _saveStateCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              wroteToDisk
                                  ? 'Tags & cover permanently written to audio file!'
                                  : 'Tags & metadata saved to Nami library!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichInputField(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13.5, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF161622),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  void _showAdvancedDeleteDialog(AudioTrack song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14141F),
        title: const Text('Delete File Forever?',
            style: TextStyle(
                color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
            'Permanently delete "${song.title}" from storage? This cannot be undone.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final file = File(song.path);
                if (await file.exists()) await file.delete();
                setState(() {
                  _songs.removeWhere((s) => s.path == song.path);
                  _filteredSongs.removeWhere((s) => s.path == song.path);
                  _historyTracks.removeWhere((s) => s.path == song.path);
                  _playNextQueue.removeWhere((s) => s.path == song.path);
                  for (final pl in _customPlaylists) {
                    pl.tracks.removeWhere((s) => s.path == song.path);
                  }
                  if (_currentSong?.path == song.path) {
                    _audioPlayer.stop();
                    _currentSong = null;
                  }
                });
                _saveStateCache();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('File permanently deleted.')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete file: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  void _showAddToPlaylistDialog(AudioTrack song) {
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add to Playlist', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._customPlaylists.map((pl) => ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(pl.name),
                    subtitle: Text('${pl.tracks.length} ${pl.tracks.length == 1 ? 'Track' : 'Tracks'}'),
                    onTap: () {
                      if (!pl.tracks.contains(song)) {
                        setState(() => pl.tracks.add(song));
                        _saveStateCache();
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${pl.name}')));
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackOptionsMenu(AudioTrack song) {
    showNamiTrackActionCard(
      context: context,
      track: song,
      onFetchCoverOnline: () => _openTrackCoverOnlinePicker(song),
      coverArt: _buildCoverArt(song, 50, 12),
      formatBadgeText: '${song.path.split('.').last.toUpperCase()} ${song.bitDepth > 0 ? '${song.bitDepth}B' : ''}'.trim(),
      isFavorite: false,
      onToggleFavorite: () => setState(() {}),
      onPlayNext: () { setState(() => _playNextQueue.add(song));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${song.title} to play next'))); },
      onPlayLast: () => setState(() => _playNextQueue.add(song)),
      onAddToPlaylist: () { _showAddToPlaylistDialog(song); },
      onGoToAlbum: () { _showAlbumDetailScreen(song.album, _songs.where((s) => s.album == song.album).toList()); },
      onGoToArtist: (artist) => _openArtistByName(artist),
      onLyricsEditor: () { _showNamiLyricsManagerSheet(song); },
      onEditTags: () { _showTagEditorDialog(song); },
      onFileInfo: () { _showTrackFileInfoSheet(song); },
      onDeleteForever: () { _showAdvancedDeleteDialog(song); },
    );
  }

  void _showTrackFileInfoSheet(AudioTrack song) {
    final ext = song.path.contains('.') ? song.path.split('.').last.toUpperCase() : 'AUDIO';
    final sizeMb = song.fileSize > 0 ? '${(song.fileSize / (1024 * 1024)).toStringAsFixed(2)} MB' : 'Unknown';
    final khz = (song.sampleRateHz / 1000.0).toStringAsFixed(1);
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const Text('Audio File Properties', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _infoRow('Format & Bit Depth', '$ext • ${song.bitDepth}-Bit'),
              _infoRow('Sample Rate & Bitrate', '$khz kHz • ${song.bitrateKbps} kbps'),
              _infoRow('Duration & Plays', '${_formatDurationPadded(song.duration)} • ${song.playCount} plays'),
              _infoRow('File Size', sizeMb),
              _infoRow('File Path', song.path),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 125, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showFolderExplorerModal() {
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setFolderState) {
          List<FileSystemEntity> entities = [];
          try {
            if (_currentFolder.existsSync()) {
              entities = _currentFolder.listSync().where((e) {
                final n = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
                if (n.startsWith('.')) return false;
                if (e is Directory) return true;
                final l = e.path.toLowerCase();
                return l.endsWith('.flac') || l.endsWith('.mp3') || l.endsWith('.m4a') || l.endsWith('.wav');
              }).toList();
              entities.sort((a, b) {
                if (a is Directory && b is! Directory) return -1;
                if (a is! Directory && b is Directory) return 1;
                return a.path.toLowerCase().compareTo(b.path.toLowerCase());
              });
            }
          } catch (_) {}

          final canGoUp = _currentFolder.path != '/storage/emulated/0' && _currentFolder.path != '/';

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_open_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Folder Explorer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    Builder(builder: (_) {
                      final isEx = _isPathExcluded(_currentFolder.path);
                      return TextButton.icon(
                        icon: Icon(isEx ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 16, color: isEx ? Colors.greenAccent : Colors.redAccent),
                        label: Text(isEx ? 'Include' : 'Exclude', style: TextStyle(fontSize: 11.5, color: isEx ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setFolderState(() {
                            if (isEx) {
                              _excludedFolders.removeWhere((e) => e.toLowerCase() == _currentFolder.path.toLowerCase());
                            } else {
                              _excludedFolders.add(_currentFolder.path);
                            }
                          });
                          setState(() => _applyExcludedFoldersFilter());
                          _saveNamiV12Prefs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEx ? 'Folder included in library' : 'Folder blacklisted from library')),
                          );
                        },
                      );
                    }),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF0A0A0E), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      if (canGoUp)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          onPressed: () => setFolderState(() => _currentFolder = _currentFolder.parent),
                        ),
                      Expanded(
                        child: Text(
                          _currentFolder.path.replaceFirst('/storage/emulated/0', '~'),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${entities.length} items', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: entities.length,
                    itemBuilder: (ctx, i) {
                      final e = entities[i];
                      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
                      if (e is Directory) {
                        return ListTile(
                          leading: Icon(Icons.folder_rounded, color: Theme.of(context).colorScheme.primary),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: () => setFolderState(() => _currentFolder = Directory(e.path)),
                        );
                      } else {
                        final match = _songs.firstWhere(
                          (t) => t.path == e.path,
                          orElse: () => AudioTrack(title: name, artist: 'Local Audio', album: 'Storage', path: e.path),
                        );
                        return ListTile(
                          leading: const Icon(Icons.music_note_rounded, color: Colors.white70),
                          title: Text(match.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(match.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            Navigator.pop(context);
                            _playSong(match);
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setQueueState) {
          final activeList = _playNextQueue.isNotEmpty ? _playNextQueue : _filteredSongs;
          final totalDur = activeList.fold<Duration>(Duration.zero, (sum, item) => sum + item.duration);
          final activeIndex = _currentSong != null ? (_songs.indexOf(_currentSong!) + 1) : 1;
          final accent = Theme.of(context).colorScheme.primary;
          final qFilterActive = _queueSearchQuery.isNotEmpty;
          bool matchesQ(AudioTrack t) => !qFilterActive ||
              t.title.toLowerCase().contains(_queueSearchQuery) ||
              t.artist.toLowerCase().contains(_queueSearchQuery) ||
              t.album.toLowerCase().contains(_queueSearchQuery);
          final visibleLibTracks = qFilterActive ? _filteredSongs.where(matchesQ).toList() : _filteredSongs;
          final visibleQueueTracks = qFilterActive ? _playNextQueue.where(matchesQ).toList() : _playNextQueue;

          return DraggableScrollableSheet(
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.96,
            builder: (context, scrollController) => Column(
              children: [
                if (_currentSong != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101016).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        _buildCoverArt(_currentSong!, 46, 10),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(cleanArtistStr(_currentSong!.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                            ],
                          ),
                        ),
                        StreamBuilder<bool>(
                          stream: _audioPlayer.stream.playing,
                          builder: (ctx, snap) {
                            final playing = snap.data ?? _audioPlayer.state.playing;
                            return GestureDetector(
                              onTap: () => playing ? _audioPlayer.pause() : _audioPlayer.play(),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B0B10),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            margin: const EdgeInsets.only(top: 10, bottom: 6),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$activeIndex/${_songs.length} • ${_formatTotalDurationHoursMins(totalDur)}',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (_playNextQueue.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Clear Up Next',
                                      icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.white70),
                                      onPressed: () {
                                        setQueueState(() => _playNextQueue.clear());
                                        setState(() {});
                                      },
                                    ),
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.queue_music_rounded, size: 16, color: Colors.white),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Colors.white70),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                          child: TextField(
                            onChanged: (val) => setQueueState(() => _queueSearchQuery = val.trim().toLowerCase()),
                            style: const TextStyle(fontSize: 12.5, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Filter queue tracks or artists...',
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white54),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFF14141E),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: _playNextQueue.isEmpty
                              ? ReorderableListView.builder(
                                  scrollController: scrollController,
                                  buildDefaultDragHandles: false,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: visibleLibTracks.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setQueueState(() {
                                      if (newIndex > oldIndex) newIndex -= 1;
                                      if (oldIndex >= 0 && oldIndex < _filteredSongs.length && newIndex >= 0 && newIndex < _filteredSongs.length) {
                                        final moved = _filteredSongs.removeAt(oldIndex);
                                        _filteredSongs.insert(newIndex, moved);
                                      }
                                    });
                                    setState(() {});
                                  },
                                  itemBuilder: (ctx, idx) => KeyedSubtree(
                                    key: ValueKey('lib_q_${visibleLibTracks[idx].path}_$idx'),
                                    child: _buildNamiQueueRow(
                                      song: visibleLibTracks[idx],
                                      index: idx,
                                      isReorderable: !qFilterActive,
                                      onTap: () {
                                        _playSong(visibleLibTracks[idx]);
                                        Navigator.pop(context);
                                      },
                                      onToggleFav: () {
                                        setQueueState(() => visibleLibTracks[idx].isFavorite = !visibleLibTracks[idx].isFavorite);
                                        setState(() {});
                                        _saveStateCache();
                                      },
                                    ),
                                  ),
                                )
                              : ReorderableListView.builder(
                                  scrollController: scrollController,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: visibleQueueTracks.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setQueueState(() {
                                      if (newIndex > oldIndex) newIndex -= 1;
                                      final item = _playNextQueue.removeAt(oldIndex);
                                      _playNextQueue.insert(newIndex, item);
                                    });
                                    setState(() {});
                                  },
                                  itemBuilder: (ctx, idx) {
  final qTrack = visibleQueueTracks[idx];
  return Dismissible(
    key: ValueKey('q_${qTrack.path}_$idx'),
    direction: DismissDirection.endToStart,
    background: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.only(right: 20),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
    ),
    onDismissed: (_) { setQueueState(() => _playNextQueue.removeAt(idx)); setState(() {}); },
    child: _buildNamiQueueRow(
      song: qTrack, index: idx, isReorderable: !qFilterActive,
      onTap: () { _playSong(qTrack); Navigator.pop(context); },
      onMoveToTop: idx > 0 ? () {
        setQueueState(() {
          final moved = _playNextQueue.removeAt(idx);
          _playNextQueue.insert(0, moved);
        });
        setState(() {});
      } : null,
      onToggleFav: () { setQueueState(() => qTrack.isFavorite = !qTrack.isFavorite); setState(() {}); _saveStateCache(); },
      onRemove: () { setQueueState(() => _playNextQueue.removeAt(idx)); setState(() {}); },
    ),
  );
},
),
),
Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFF09090D),
                            border: Border(top: BorderSide(color: Colors.white10)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Save Queue as Playlist',
                                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 22),
                                    onPressed: () {
                                      setState(() {
                                        _customPlaylists.add(CustomPlaylist(
                                          name: 'Queue Mix ${_customPlaylists.length + 1}',
                                          tracks: List.from(activeList),
                                        ));
                                      });
                                      _saveStateCache();
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Queue saved as playlist!')));
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Locate Active Track',
                                    icon: const Icon(Icons.my_location_rounded, color: Colors.white70, size: 20),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _locateActivePlayingTrack();
                                    },
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent.withValues(alpha: 0.18),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                icon: const Icon(Icons.shuffle_rounded, size: 18),
                                label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () {
                                  if (_playNextQueue.isNotEmpty) {
                                    setQueueState(() => _playNextQueue.shuffle());
                                    setState(() {});
                                  } else {
                                    Navigator.pop(context);
                                    _shufflePlay();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNamiQueueRow({
    required AudioTrack song,
    required int index,
    required bool isReorderable,
    required VoidCallback onTap,
    required VoidCallback onToggleFav,
    VoidCallback? onRemove,
    VoidCallback? onMoveToTop,
  }) {
    final isCurrent = _currentSong?.path == song.path;
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
  decoration: BoxDecoration(
    color: isCurrent ? Color.alphaBlend(accent.withValues(alpha: 0.14), const Color(0xFF14141E)) : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    border: isCurrent ? Border.all(color: accent.withValues(alpha: 0.45)) : null,
  ),
  child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      child: Row(children: [
        _buildCoverArt(song, 46, 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isCurrent ? accent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cleanArtistStr(song.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${song.album} • ${song.addedDate}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatDurationPadded(song.duration), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: onToggleFav,
                  child: Icon(
                    song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: song.isFavorite ? accent : Colors.white38,
                    size: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            if (isReorderable)
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.reorder_rounded, color: Colors.white54, size: 20),
              )
            else
              const Icon(Icons.reorder_rounded, color: Colors.white24, size: 20),
            const SizedBox(width: 4),
            if (onMoveToTop != null)
              IconButton(
                tooltip: 'Move to Top',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.vertical_align_top_rounded, color: Colors.white60, size: 18),
                onPressed: onMoveToTop,
              ),
            if (onRemove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                onPressed: onRemove,
              )
            else
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
                onPressed: () => _showTrackOptionsMenu(song),
              ),
          ],
        ),
      ),
    ),
  );
  }

  void _openSettings() {
    NamiShellNavigator.push(MaterialPageRoute(
        builder: (context) => MainSettingsScreen(
          usbDacExclusive: _usbDacExclusive,
          gaplessPlayback: _gaplessPlayback,
          mediaNotificationEnabled: _mediaNotificationEnabled,
          usePitchBlack: _usePitchBlack,
          autoColoring: _autoColoring,
          ambientGlow: _ambientGlow,
          blurredBackdrop: _blurredBackdrop,
          showCodecBadges: _showCodecBadges,
          compactTrackTiles: _compactTrackTiles,
          resumeSessionOnStartup: _resumeSessionOnStartup,
          pauseOnDisconnect: _pauseOnDisconnect,
          doubleTapSeekSec: _doubleTapSeekSec,
          minTrackSeconds: _minTrackSeconds,
          replayGainMode: _replayGainMode,
          defaultStartupTab: _defaultStartupTab,
          syllableLyricsEnabled: _syllableLyricsEnabled,
          preferEmbeddedLyrics: _preferEmbeddedLyrics,
          autoFetchOnlineMetadata: _autoFetchOnlineMetadata,
          splitMultiArtists: _splitMultiArtists,
          artistSeparators: _artistSeparators,
          scanFolders: _scanFolders,
          ignoreShortClips: _ignoreShortClips,
          forceMiniColor: _forceMiniColor,
          connectedDacName: _connectedDacName,
          activeEqPresetLabel: _eqEnabled ? _selectedEqPreset : 'EQ Bypass',
          onAudioModePresetSelected: (mode) async {
            setState(() {
              if (mode == 'bit_perfect') {
                _eqEnabled = false;
                _usbDacExclusive = true;
                _replayGainMode = 'Off';
                _replayGain = false;
              } else {
                _eqEnabled = true;
                _crossfadeSeconds = _crossfadeSeconds == 0 ? 3 : _crossfadeSeconds;
                _pauseOnDisconnect = true;
              }
            });
            await _applyDacAndAudioProperties();
            await _applyHardwareEqGains();
            await _saveNamiV12Prefs();
            _saveStateCache();
          },
          thumbCacheSizeFuture: _getThumbCacheSizeLabel(),
          onClearThumbCache: _clearArtworkCache,
          onFetchMissingCovers: _fetchMissingCoversBatch,
          onOpenEqualizer: _showEqualizerSheet,
          onRequestStoragePermission: _requestFullStoragePermission,
          onRequestUsbDacPermission: () => _requestUsbDacPermission(silentIfNone: false),
          onOpenScrobbling: _showListenBrainzSettingsDialog,
          onOpenExtensionRepo: _openExtensionRepoScreen,
          onOpenFolderExplorer: _showFolderExplorerModal,
          onExportBackup: _exportUnifiedNamiBackup,
          onImportBackup: _importUnifiedNamiBackup,
          onScanFoldersChanged: (list) {
            setState(() => _scanFolders = list);
            _saveStateCache();
            _startReactiveFolderWatchers();
            _fastScanDeviceMusic(forceReparse: false);
          },
          onIgnoreShortClipsChanged: (v) {
            setState(() => _ignoreShortClips = v);
            _saveStateCache();
            _fastScanDeviceMusic(forceReparse: false);
          },
          onMinTrackSecondsChanged: (sec) {
            setState(() => _minTrackSeconds = sec);
            _saveStateCache();
            _fastScanDeviceMusic(forceReparse: false);
          },
          onUsbDacChanged: (v) {
            setState(() => _usbDacExclusive = v);
            _applyDacAndAudioProperties();
            if (v) _requestUsbDacPermission(silentIfNone: false);
          },
          onGaplessChanged: (v) {
            setState(() => _gaplessPlayback = v);
            _applyDacAndAudioProperties();
          },
          onNotificationChanged: (v) => setState(() => _mediaNotificationEnabled = v),
          onPitchBlackChanged: (v) {
            setState(() => _usePitchBlack = v);
            NamiApp.of(context).updateTheme(isPitchBlack: v);
          },
          onAutoColoringChanged: (v) => setState(() => _autoColoring = v),
          onAmbientGlowChanged: (v) => setState(() => _ambientGlow = v),
          onBlurredBackdropChanged: (v) {
            setState(() => _blurredBackdrop = v);
            _saveStateCache();
          },
          onShowCodecBadgesChanged: (v) {
            setState(() => _showCodecBadges = v);
            _saveStateCache();
          },
          onCompactTrackTilesChanged: (v) {
            setState(() => _compactTrackTiles = v);
            _saveStateCache();
          },
          onResumeSessionChanged: (v) {
            setState(() => _resumeSessionOnStartup = v);
            _saveStateCache();
          },
          onPauseOnDisconnectChanged: (v) {
            setState(() => _pauseOnDisconnect = v);
            _saveStateCache();
          },
          onDoubleTapSeekChanged: (sec) {
            setState(() => _doubleTapSeekSec = sec);
            _saveStateCache();
          },
          onReplayGainModeChanged: (mode) {
            setState(() {
              _replayGainMode = mode;
              _replayGain = mode != 'Off';
            });
            _applyDacAndAudioProperties();
            _saveStateCache();
          },
          onDefaultStartupTabChanged: (tab) {
            setState(() => _defaultStartupTab = tab);
            _saveStateCache();
          },
          onSyllableLyricsChanged: (v) => setState(() => _syllableLyricsEnabled = v),
          onPreferEmbeddedChanged: (v) => setState(() => _preferEmbeddedLyrics = v),
          onAutoFetchOnlineChanged: (v) {
            setState(() => _autoFetchOnlineMetadata = v);
            _saveStateCache();
            if (v) _enrichMetadataInBackground();
          },
          onSplitArtistsChanged: (v) {
            setState(() => _splitMultiArtists = v);
            _saveStateCache();
          },
          onArtistSeparatorsChanged: (list) {
            setState(() => _artistSeparators = list);
            _saveStateCache();
          },
          onForceMiniColorChanged: (v) => setState(() => _forceMiniColor = v),
          onRescan: () => _fastScanDeviceMusic(forceReparse: true),
        ),
      ), fallbackContext: context);
  }

  Future<void> _importSflxManifest() async {
    try {
      final dlDir = Directory('/storage/emulated/0/Download');
      if (!await dlDir.exists()) return;
      final sflxFiles = dlDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.sflx'))
          .toList();
      if (sflxFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No .sflx files found in /Download')));
        }
        return;
      }
      int imported = 0;
      for (var file in sflxFiles) {
        try {
          final parsed = jsonDecode(await file.readAsString());
          if (parsed is Map<String, dynamic> && parsed['name'] != null) {
            final extName = parsed['name'].toString();
            final exists = _extensions.any((e) => e.name.toLowerCase() == extName.toLowerCase());
            if (!exists) {
              _extensions.add(MornyeExtension(
                name: extName,
                version: parsed['version']?.toString() ?? 'v1.0.0',
                author: parsed['author']?.toString() ?? 'External .sflx',
                format: parsed['format']?.toString() ?? 'FLAC / Stream',
                category: parsed['category']?.toString() ?? 'Download',
                description: parsed['description']?.toString() ?? 'Imported via .sflx manifest',
                endpointUrl: parsed['endpoint']?.toString(),
                isInstalled: true,
              ));
              if (!_mornyeServices.contains(extName)) {
                _mornyeServices.add(extName);
              }
              imported++;
            }
          }
        } catch (_) {}
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $imported .sflx extension(s)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  void _openExtensionRepoScreen() {
    String catFilter = 'All';
    int repoTab = 0; // 0 = Installed, 1 = Extension Store
    bool isPingingAll = false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setRepoState) {
            final accent = Theme.of(context).colorScheme.primary;
            final filteredExts = _extensions.where((e) => catFilter == 'All' || e.category == catFilter).toList();
            return Scaffold(
              appBar: AppBar(
                title: Text('Mornye Repo (${_extensions.where((e) => e.isInstalled).length}/${_extensions.length})'),
                actions: [
                  IconButton(
                    tooltip: 'Ping All Endpoints',
                    icon: isPingingAll
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.speed_rounded, size: 20),
                    onPressed: isPingingAll
                        ? null
                        : () async {
                            setRepoState(() => isPingingAll = true);
                            for (final e in _extensions) {
                              _mornyePingResults[e.name] = await NamiMornyeStore.pingEndpoint(e.endpointUrl);
                            }
                            if (context.mounted) setRepoState(() => isPingingAll = false);
                          },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.file_open_rounded, size: 17),
                    label: const Text('.sflx'),
                    onPressed: () async {
                      await _importSflxManifest();
                      setRepoState(() {});
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, icon: Icon(Icons.extension_rounded, size: 16), label: Text('Installed', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 1, icon: Icon(Icons.storefront_rounded, size: 16), label: Text('Extension Store', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {repoTab},
                      onSelectionChanged: (v) => setRepoState(() => repoTab = v.first),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.folder_zip_outlined, size: 16),
                            label: const Text('Import .sflx / ZIP', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showImportSflxBundleDialog(context, () {
                              if (mounted) setState(() {});
                              setRepoState(() {});
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: accent),
                            icon: const Icon(Icons.link_rounded, size: 16),
                            label: const Text('Add from URL', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showAddSflxFromUrlDialog(context, () {
                              if (mounted) setState(() {});
                              setRepoState(() {});
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (repoTab == 0) ...[
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                        children: ['All', 'Download', 'Metadata', 'Utility'].map((cat) {
                          final sel = catFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.white70)),
                              selected: sel,
                              selectedColor: accent,
                              backgroundColor: const Color(0xFF14141E),
                              onSelected: (_) => setRepoState(() => catFilter = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: filteredExts.length,
                        itemBuilder: (ctx, idx) {
                          final ext = filteredExts[idx];
                          final ping = _mornyePingResults[ext.name];
                          final dotColor = ping == null
                              ? ((ext.endpointUrl != null && ext.endpointUrl!.trim().isNotEmpty) ? Colors.cyanAccent : Colors.amberAccent)
                              : (ping.status == 'online'
                                  ? Colors.greenAccent
                                  : (ping.status == 'preview' ? Colors.amberAccent : Colors.redAccent));
                          final statusLabel = ping?.label ??
                              ((ext.endpointUrl != null && ext.endpointUrl!.trim().isNotEmpty) ? 'Full Stream Endpoint' : 'Preview Only');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E0E15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ext.isInstalled ? accent.withValues(alpha: 0.35) : Colors.white10),
                            ),
                            child: ListTile(
                              leading: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(Icons.extension_rounded, color: ext.isInstalled ? accent : Colors.white38),
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                                  ),
                                ],
                              ),
                              title: Text('${ext.name} • ${ext.version}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              subtitle: Text('${ext.category} • ${ext.format} • $statusLabel\n${ext.description}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: ext.isInstalled,
                                    activeThumbColor: accent,
                                    onChanged: (v) {
                                      setRepoState(() {
                                        ext.isInstalled = v;
                                        ext.isEnabled = v;
                                      });
                                      setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.network_check_rounded, color: Colors.cyanAccent, size: 19),
                                    tooltip: 'Ping Endpoint',
                                    onPressed: () async {
                                      final res = await NamiMornyeStore.pingEndpoint(ext.endpointUrl);
                                      setRepoState(() => _mornyePingResults[ext.name] = res);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    tooltip: 'Delete Extension',
                                    onPressed: () {
                                      final removed = ext;
                                      setState(() => _extensions.remove(ext));
                                      setRepoState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deleted "${removed.name}"'),
                                          action: SnackBarAction(
                                            label: 'Undo',
                                            onPressed: () {
                                              setState(() => _extensions.add(removed));
                                              setRepoState(() {});
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: NamiMornyeStore.curatedDirectory.length,
                        itemBuilder: (ctx, idx) {
                          final entry = NamiMornyeStore.curatedDirectory[idx];
                          final installed = _extensions.any((e) => e.name.toLowerCase() == entry.name.toLowerCase());
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E0E15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListTile(
                              leading: Icon(Icons.storefront_rounded, color: installed ? Colors.greenAccent : accent),
                              title: Text('${entry.name} • ${entry.version}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              subtitle: Text('${entry.category} • ${entry.format}\n${entry.description}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                              isThreeLine: true,
                              trailing: installed
                                  ? const Chip(label: Text('Installed', style: TextStyle(fontSize: 10.5)))
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                      onPressed: () {
                                        setState(() {
                                          _extensions.add(MornyeExtension(
                                            name: entry.name,
                                            version: entry.version,
                                            author: entry.author,
                                            format: entry.format,
                                            category: entry.category,
                                            description: entry.description,
                                            endpointUrl: entry.endpointUrl,
                                            isInstalled: true,
                                          ));
                                          if (!_mornyeServices.contains(entry.name)) {
                                            _mornyeServices.add(entry.name);
                                          }
                                        });
                                        setRepoState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Installed ${entry.name}!')));
                                      },
                                      child: const Text('Install', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Future<void> _playMornyePreview(MornyeCatalogItem item) async {
    if (item.previewUrl == null || item.previewUrl!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio preview available for this item.')),
        );
      }
      return;
    }
    try {
      setState(() => _activePreviewKey = item.itemKey);
      await _audioPlayer.stop();
      await _audioPlayer.open(Media(item.previewUrl!));
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        setState(() => _activePreviewKey = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview error: $e')),
        );
      }
    }
  }

Future<String?> _resolveFullTrackUrlFromExtensions(MornyeCatalogItem item) async {
    final activeExts = _extensions
        .where((e) =>
            e.isInstalled &&
            e.isEnabled &&
            e.endpointUrl != null &&
            e.endpointUrl!.trim().isNotEmpty)
        .toList();

    for (final ext in activeExts) {
      try {
        final base = ext.endpointUrl!.trim();
        final sep = base.contains('?') ? '&' : '?';
        final qUrl =
            '$base${sep}title=${Uri.encodeComponent(item.title)}&artist=${Uri.encodeComponent(item.artist)}&album=${Uri.encodeComponent(item.album)}';
        final res = await http
            .get(Uri.parse(qUrl), headers: _httpHeaders)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final body = res.body.trim();
          if (body.startsWith('http')) {
            return body;
          }
          if (body.startsWith('\u007b')) {
            final decoded = jsonDecode(body);
            if (decoded is Map) {
              for (final k in ['streamUrl', 'downloadUrl', 'url', 'audioUrl', 'flacUrl', 'trackUrl']) {
                final cand = decoded[k]?.toString().trim();
                if (cand != null && cand.startsWith('http')) {
                  return cand;
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }


  List<String> _extractJsonPayloadsFromBytes(Uint8List bytes) {
    final payloads = <String>[];
    // Check for ZIP magic header PK\x03\x04 (0x50, 0x4B, 0x03, 0x04)
    if (bytes.length >= 30 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      final bd = ByteData.sublistView(bytes);
      int offset = 0;
      while (offset + 30 <= bytes.length) {
        final sig = bd.getUint32(offset, Endian.little);
        if (sig != 0x04034b50) break;
        final flags = bd.getUint16(offset + 6, Endian.little);
        final method = bd.getUint16(offset + 8, Endian.little);
        final compSize = bd.getUint32(offset + 18, Endian.little);
        final nameLen = bd.getUint16(offset + 26, Endian.little);
        final extraLen = bd.getUint16(offset + 28, Endian.little);
        final nameStart = offset + 30;
        final dataStart = nameStart + nameLen + extraLen;
        if (nameStart + nameLen > bytes.length) break;
        final entryName = utf8.decode(
          bytes.sublist(nameStart, nameStart + nameLen),
          allowMalformed: true,
        ).toLowerCase();

        if ((flags & 0x08) != 0 || compSize == 0) {
          // Scan for next PK signature if data descriptor was used
          int nextSig = -1;
          for (int p = dataStart; p + 4 <= bytes.length; p++) {
            if (bytes[p] == 0x50 &&
                bytes[p + 1] == 0x4B &&
                (bytes[p + 2] == 0x03 || bytes[p + 2] == 0x01)) {
              nextSig = p;
              break;
            }
          }
          if (nextSig == -1) break;
          final rawSlice = bytes.sublist(dataStart, nextSig);
          if (!entryName.endsWith('/') &&
              (entryName.endsWith('.sflx') ||
                  entryName.endsWith('.json') ||
                  entryName.contains('manifest'))) {
            try {
              final decodedBytes = method == 8
                  ? ZLibDecoder(raw: true).convert(rawSlice)
                  : rawSlice;
              payloads.add(utf8.decode(decodedBytes, allowMalformed: true));
            } catch (_) {}
          }
          offset = nextSig;
          continue;
        }

        final dataEnd = dataStart + compSize;
        if (dataEnd > bytes.length) break;
        if (!entryName.endsWith('/') &&
            (entryName.endsWith('.sflx') ||
                entryName.endsWith('.json') ||
                entryName.contains('manifest'))) {
          try {
            final compSlice = bytes.sublist(dataStart, dataEnd);
            final decodedBytes = method == 8
                ? ZLibDecoder(raw: true).convert(compSlice)
                : compSlice;
            payloads.add(utf8.decode(decodedBytes, allowMalformed: true));
          } catch (_) {}
        }
        offset = dataEnd;
      }
    } else {
      payloads.add(utf8.decode(bytes, allowMalformed: true));
    }
    return payloads;
  }

  List<MornyeExtension> _parseExtensionsFromJsonText(String rawText) {
    final results = <MornyeExtension>[];
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return results;
    final dynamic decoded = jsonDecode(trimmed);

    void addFromMap(Map<dynamic, dynamic> m) {
      final name = (m['name'] ?? m['title'] ?? m['id'] ?? '').toString().trim();
      if (name.isEmpty) return;
      final id = (m['id'] ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'))
          .toString()
          .trim();
      final category = (m['category'] ?? m['source'] ?? 'Custom Provider').toString().trim();
      final format = (m['format'] ?? m['quality'] ?? 'FLAC / M4A').toString().trim();
      final description = (m['description'] ?? m['desc'] ?? 'Imported .sflx extension')
          .toString()
          .trim();
      final version = (m['version'] ?? '1.0.0').toString().trim();
      final author = (m['author'] ?? 'Community').toString().trim();
      final endpointUrl = (m['endpointUrl'] ??
              m['streamEndpoint'] ??
              m['apiUrl'] ??
              m['baseUrl'] ??
              m['url'] ??
              '')
          .toString()
          .trim();

      results.add(MornyeExtension(
        name: name,
      category: category,
      format: format,
      description: description,
      version: version,
      author: author,
      endpointUrl: endpointUrl,
      isInstalled: true,
      isEnabled: true,
      ));
    }

    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) addFromMap(item);
      }
    } else if (decoded is Map) {
      if (decoded['extensions'] is List) {
        for (final item in (decoded['extensions'] as List)) {
          if (item is Map) addFromMap(item);
        }
      } else if (decoded['providers'] is List) {
        for (final item in (decoded['providers'] as List)) {
          if (item is Map) addFromMap(item);
        }
      } else {
        addFromMap(decoded);
      }
    }
    return results;
  }

  Future<int> _importSflxFromBytes(Uint8List bytes, {String sourceLabel = 'bundle'}) async {
    final payloads = _extractJsonPayloadsFromBytes(bytes);
    final parsed = <MornyeExtension>[];
    for (final p in payloads) {
      try {
        parsed.addAll(_parseExtensionsFromJsonText(p));
      } catch (_) {}
    }
    if (parsed.isEmpty) return 0;

    setState(() {
      for (final ext in parsed) {
        final idx = _extensions.indexWhere(
          (e) => e.name.toLowerCase() == ext.name.toLowerCase(),
        );
        if (idx != -1) {
          _extensions[idx] = ext;
        } else {
          _extensions.add(ext);
        }
      }
    });
    await _saveStateCache();
    return parsed.length;
  }

  Future<void> _importSflxFromFilePath(String path) async {
    try {
      final file = File(path.trim());
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File not found: $path')),
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      final count = await _importSflxFromBytes(bytes, sourceLabel: file.path.split('/').last);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Imported $count .sflx extension(s) from ${file.path.split('/').last}'
                  : 'No valid .sflx manifest found inside ${file.path.split('/').last}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importSflxFromUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid http:// or https:// .sflx URL')),
        );
      }
      return;
    }
    try {
      final res = await http
          .get(Uri.parse(url), headers: _httpHeaders)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final count = await _importSflxFromBytes(res.bodyBytes, sourceLabel: url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count > 0
                    ? 'Added $count extension(s) from URL'
                    : 'URL loaded, but no valid .sflx JSON/ZIP manifest was found',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('URL fetch failed (HTTP ${res.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL import error: $e')),
        );
      }
    }
  }

  Future<void> _showImportSflxBundleDialog(BuildContext parentCtx, VoidCallback refreshRepo) async {
    final pathCtrl = TextEditingController();
    final discovered = <File>[];
    for (final dirPath in [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      _mornyeDownloadFolder,
    ]) {
      try {
        final d = Directory(dirPath);
        if (await d.exists()) {
          await for (final ent in d.list(followLinks: false)) {
            if (ent is File) {
              final lower = ent.path.toLowerCase();
              if (lower.endsWith('.sflx') ||
                  lower.endsWith('.zip') ||
                  (lower.endsWith('.json') && lower.contains('sflx'))) {
                discovered.add(ent);
              }
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text('Import .sflx / ZIP Bundle', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (discovered.isNotEmpty) ...[
                  const Text(
                    'Detected in storage (tap to import):',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  ...discovered.take(12).map(
                        (f) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.extension_rounded, color: Color(0xFFE53935), size: 20),
                          title: Text(
                            f.path.split('/').last,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            f.parent.path,
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _importSflxFromFilePath(f.path);
                            refreshRepo();
                          },
                        ),
                      ),
                  const Divider(color: Colors.white12),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No .sflx or .zip bundles auto-detected in /Download. Enter a file path below:',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                TextField(
                  controller: pathCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Custom .sflx / .json / .zip path',
                    hintText: '/storage/emulated/0/Download/bundle.sflx',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () async {
              final p = pathCtrl.text.trim();
              Navigator.of(ctx).pop();
              if (p.isNotEmpty) {
                await _importSflxFromFilePath(p);
                refreshRepo();
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSflxFromUrlDialog(BuildContext parentCtx, VoidCallback refreshRepo) async {
    final urlCtrl = TextEditingController();
    await showDialog<void>(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text('Add .sflx from URL', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a direct URL to a .sflx manifest, JSON repo index, or .zip extension bundle:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Extension / Repo URL',
                hintText: 'https://example.com/provider.sflx',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () async {
              final u = urlCtrl.text.trim();
              Navigator.of(ctx).pop();
              if (u.isNotEmpty) {
                await _importSflxFromUrl(u);
                refreshRepo();
              }
            },
            child: const Text('Fetch & Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadMornyeItem(MornyeCatalogItem item) async {
    setState(() => _downloadingTitles.add(item.itemKey));
    try {
      final fullUrl = await _resolveFullTrackUrlFromExtensions(item);
      final targetUrl = (fullUrl != null && fullUrl.isNotEmpty) ? fullUrl : item.previewUrl;
      final isFullStream = fullUrl != null && fullUrl.isNotEmpty;

      if (targetUrl == null || targetUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No direct audio stream for "${item.title}". Add a Mornye extension URL in Repo or search a track.',
              ),
            ),
          );
        }
        return;
      }

      final lowerUrl = targetUrl.toLowerCase();
      final ext = lowerUrl.contains('.flac')
          ? '.flac'
          : (lowerUrl.contains('.mp3') ? '.mp3' : '.m4a');
      final destPath = NamiMornyeStore.renderDownloadPath(
        rootFolder: _mornyeDownloadFolder,
        template: NamiV16Prefs.instance.mornyePathTemplate,
        artist: item.artist,
        album: item.album,
        title: item.title,
        trackNumber: '01',
        extension: ext,
        isFullStream: isFullStream,
      );

      NamiDownloadManager.instance.enqueue(
        MornyeDownloadTask(
          id: item.itemKey,
          title: item.title,
          artist: item.artist,
          album: item.album,
          url: targetUrl,
          artworkUrl: item.artworkUrl,
          destPath: destPath,
          isFullStream: isFullStream,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Queued "${item.title}" in Download Manager'),
            action: SnackBarAction(
              label: 'Queue',
              onPressed: _showMornyeDownloadsSheet,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingTitles.remove(item.itemKey));
      }
    }
  }

  Future<void> _requestFullStoragePermission() async {
    try {
      var manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        manageStatus = await Permission.manageExternalStorage.request();
      }
      if (!manageStatus.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Grant "All Files Access" for tag writing, file deletion & full folder scanning.'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      } else if (manageStatus.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full Storage Access granted!')),
        );
      }
    } catch (_) {}
  }

  Future<void> _requestUsbDacPermission({bool silentIfNone = false}) async {
    try {
      final res = await _audioDeviceChannel.invokeMethod('requestUsbDacPermission');
      if (res is Map && mounted) {
        final status = (res['status'] ?? '').toString();
        final dev = (res['device'] ?? 'USB DAC').toString();
        if (status == 'granted') {
          if (!silentIfNone) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('USB DAC Exclusive access granted: $dev')),
            );
          }
        } else if (status == 'requested') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Requested USB exclusive permission for $dev')),
          );
        } else if (!silentIfNone) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connect a USB DAC to request exclusive USB hardware permission.')),
          );
        }
      }
    } catch (_) {
      if (!silentIfNone && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('USB DAC Exclusive mode enabled via libmpv audio-exclusive.')),
        );
      }
    }
  }

  Future<void> _requestPermissionsAndInitBackground() async {
    await requestNotificationPermission();
    PermissionStatus status = await Permission.audio.request();
    await Permission.photos.request();
    if (!status.isGranted) status = await Permission.storage.request();

    try {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    } catch (_) {}

    if (_usbDacExclusive) {
      await _requestUsbDacPermission(silentIfNone: true);
    }

    try {
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {}

    if (status.isGranted || await Permission.storage.isGranted || await Permission.manageExternalStorage.isGranted) {
      setState(() {
        _hasPermission = true;
        if (_songs.isEmpty) _isScanning = true;
      });
      await _fastScanDeviceMusic();
    }
  }

  Future<void> _fastScanDeviceMusic({bool forceReparse = false}) async {
    List<AudioTrack> foundTracks = [];
    final existingMap = forceReparse ? <String, AudioTrack>{} : {for (var s in _songs) s.path: s};

    try {
      List<Directory> searchDirs = [];
      for (final folderPath in _scanFolders) {
        final d = Directory(folderPath);
        if (await d.exists()) searchDirs.add(d);
      }
      if (searchDirs.isEmpty) {
        final fallback = Directory('/storage/emulated/0/Music');
        if (await fallback.exists()) searchDirs.add(fallback);
      }

      final Set<String> seenPaths = {};

      for (var dir in searchDirs) {
        if (!await dir.exists()) continue;
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            String path = entity.path;
            String lower = path.toLowerCase();
            String fileName = entity.uri.pathSegments.last;
            if (fileName.startsWith('.')) continue;

            if (lower.endsWith('.flac') || lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.ogg') || lower.endsWith('.wav')) {
              if (seenPaths.contains(path)) continue;
              seenPaths.add(path);

              if (existingMap.containsKey(path)) {
                foundTracks.add(existingMap[path]!);
                continue;
              }

              String baseName = fileName.substring(0, fileName.lastIndexOf('.')).replaceAll('_', ' ');
              String cleanTitle = _sanitizeMetadataText(baseName);
              String artist = 'Unknown Artist';
              String folderAlbum = entity.parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
              if (folderAlbum == 'Music' || folderAlbum == 'Download') {
                folderAlbum = cleanTitle;
              }

              if (cleanTitle.contains(' - ')) {
                final parts = cleanTitle.split(' - ');
                artist = _sanitizeMetadataText(parts[0]);
                cleanTitle = _sanitizeMetadataText(parts.sublist(1).join(' - '));
              }

              String formattedDate = "Sep 2026";
              int modMs = 0;
              try {
                final stat = await entity.stat();
                formattedDate = "${_monthNames[stat.modified.month - 1]} ${stat.modified.year}";
                modMs = stat.modified.millisecondsSinceEpoch;
              } catch (_) {}

              final track = AudioTrack(
                title: cleanTitle,
                artist: artist,
                album: folderAlbum,
                path: path,
                addedDate: formattedDate,
                addedTimestampMs: modMs,
              );
              foundTracks.add(track);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning music: $e');
    }

    if (_ignoreShortClips) {
      foundTracks.removeWhere((t) => t.duration.inSeconds > 0 && t.duration.inSeconds < _minTrackSeconds);
    }
    foundTracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final livePaths = foundTracks.map((t) => t.path).toSet();
    setState(() {
      _songs = foundTracks;
      _filteredSongs = foundTracks;
      _historyTracks.removeWhere((t) => !livePaths.contains(t.path) || !File(t.path).existsSync());
      _playNextQueue.removeWhere((t) => !t.path.startsWith('http') && (!livePaths.contains(t.path) || !File(t.path).existsSync()));
      for (final pl in _customPlaylists) {
        pl.tracks.removeWhere((t) => !livePaths.contains(t.path) || !File(t.path).existsSync());
      }
      if (_currentSong != null && !File(_currentSong!.path).existsSync()) {
        _audioPlayer.stop();
        _currentSong = null;
      }
      _isScanning = false;
    });
    _saveStateCache();

    _enrichMetadataInBackground(forceReparse: forceReparse);
  }

  Future<void> _enrichMetadataInBackground({bool forceReparse = false}) async {
    if (_isEnrichingMetadata && !forceReparse) return;
    _isEnrichingMetadata = true;
    final thumbDir = await _ensureThumbDir();

    try {
      // Pass 1: Local binary metadata + embedded/folder artwork extraction
      for (int i = 0; i < _songs.length; i++) {
        final s = _songs[i];
        if (forceReparse ||
            !s.isMetadataLoaded ||
            s.artist == 'Unknown Artist' ||
            s.albumArt == null) {
          await _extractAudioMetadataUniversal(s, thumbDir);
          _enrichedCount = i + 1;
          if (i % 8 == 0 && mounted) {
            _artworkTick.value++;
            setState(() {});
          }
        }
      }
      if (_ignoreShortClips) {
        final beforeLen = _songs.length;
        _songs.removeWhere((t) => t.duration.inSeconds > 0 && t.duration.inSeconds < _minTrackSeconds);
        if (_songs.length != beforeLen) {
          _filteredSongs = List.from(_songs);
        }
      }
      if (mounted) {
        _artworkTick.value++;
        setState(() {});
      }
      await _saveStateCache();

      // Pass 2: Online cover art & metadata enrichment
      if (_autoFetchOnlineMetadata) {
        int fetchedCount = 0;
        for (int i = 0; i < _songs.length; i++) {
          final s = _songs[i];
          if ((s.albumArt == null ||
                  s.artist == 'Unknown Artist' ||
                  s.album == 'Unknown Album') &&
              (!s.isOnlineEnriched || forceReparse)) {
            await _enrichTrackOnlineIfMissing(s, thumbDir, force: forceReparse);
            fetchedCount++;
            if (fetchedCount % 4 == 0 && mounted) {
              _artworkTick.value++;
              setState(() {});
              await _saveStateCache();
            }
            await Future.delayed(const Duration(milliseconds: 220));
          }
        }
        if (mounted) {
          _artworkTick.value++;
          setState(() {});
        }
        await _saveStateCache();
      }
    } finally {
      _isEnrichingMetadata = false;
    }
  }

  Future<void> _enrichTrackOnlineIfMissing(
    AudioTrack track,
    Directory thumbDir, {
    bool force = false,
  }) async {
    if (!force &&
        track.isOnlineEnriched &&
        track.albumArt != null &&
        track.artist != 'Unknown Artist') {
      return;
    }

    final cleanTitle = _sanitizeMetadataText(
      track.title
          .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
          .replaceAll(
              RegExp(r'\b(official|video|audio|lyrics|hd|hq|320kbps|flac)\b',
                  caseSensitive: false),
              '')
          .replaceAll('_', ' '),
    ).trim();
    if (cleanTitle.isEmpty) return;

    final hasValidArtist = track.artist.isNotEmpty &&
        track.artist != 'Unknown Artist' &&
        track.artist != 'Local Audio';
    final primaryArtist = hasValidArtist
        ? track.artist
            .split(RegExp(r'[,&/;]|feat\.|ft\.', caseSensitive: false))
            .first
            .trim()
        : '';

    final query =
        primaryArtist.isNotEmpty ? '$primaryArtist $cleanTitle' : cleanTitle;

    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&media=music&entity=song&limit=5',
      );
      final res = await http
          .get(uri, headers: _httpHeaders)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = (data['results'] as List?) ?? [];
        if (results.isNotEmpty) {
          Map<String, dynamic> bestHit =
              Map<String, dynamic>.from(results.first);
          for (final rawHit in results) {
            if (rawHit is Map) {
              final tNorm = _normName((rawHit['trackName'] ?? '').toString());
              final aNorm = _normName((rawHit['artistName'] ?? '').toString());
              if (_namesMatchLoosely(tNorm, _normName(cleanTitle)) &&
                  (primaryArtist.isEmpty ||
                      _artistNamesMatch(aNorm, _normName(primaryArtist)))) {
                bestHit = Map<String, dynamic>.from(rawHit);
                break;
              }
            }
          }

          final apiTitle = (bestHit['trackName'] ?? '').toString().trim();
          final apiArtist = (bestHit['artistName'] ?? '').toString().trim();
          final apiAlbum = (bestHit['collectionName'] ?? '').toString().trim();
          final apiGenre =
              (bestHit['primaryGenreName'] ?? '').toString().trim();

          if (!hasValidArtist && apiArtist.isNotEmpty) {
            track.artist = apiArtist;
          }
          if (track.title.contains(' - ') && apiTitle.isNotEmpty) {
            track.title = apiTitle;
          }
          if ((track.album == track.title ||
                  track.album == 'Unknown Album' ||
                  track.album == 'Music' ||
                  track.album == 'Download') &&
              apiAlbum.isNotEmpty) {
            track.album = apiAlbum;
          }
          if (apiGenre.isNotEmpty) {
            track.genre = apiGenre;
          }

          final artUrl = bestHit['artworkUrl100']
              ?.toString()
              .replaceAll('100x100bb', '600x600bb')
              .replaceAll('100x100', '600x600');
          if (artUrl != null &&
              artUrl.isNotEmpty &&
              (track.albumArt == null || force)) {
            final imgRes = await http
                .get(Uri.parse(artUrl), headers: _httpHeaders)
                .timeout(const Duration(seconds: 6));
            if (imgRes.statusCode == 200 &&
                _looksLikeImage(imgRes.bodyBytes)) {
              track.albumArt = imgRes.bodyBytes;
              final tf = File(
                  '${thumbDir.path}/${_deterministicPathHash(track.path)}.jpg');
              await tf.writeAsBytes(track.albumArt!);
              track.thumbPath = tf.path;
              _artworkTick.value++;
            }
          }
          track.isOnlineEnriched = true;
        }
      }
    } catch (_) {}
  }

  // Universal Metadata & Cover Art Extractor:
  // Scans ID3v2 (UTF-16/UTF-8/Latin1), FLAC (anywhere in first 64KB), Base64 METADATA_BLOCK_PICTURE, M4A atoms, folder covers & raw JPEG/PNG fallback.
  Future<void> _extractAudioMetadataUniversal(AudioTrack track, Directory thumbDir) async {
    RandomAccessFile? raf;
    try {
      final file = File(track.path);
      track.fileSize = await file.length();
      if (track.fileSize < 128) return;

      raf = await file.open(mode: FileMode.read);
      final head12 = await raf.read(12);
      if (head12.length < 12) return;

      int id3EndOffset = 0;

      // Step A: Parse ID3v2 if present at byte 0
      if (head12[0] == 0x49 && head12[1] == 0x44 && head12[2] == 0x33) {
        int version = head12[3];
        int flags = head12[5];
        int tagSize = ((head12[6] & 0x7F) << 21) | ((head12[7] & 0x7F) << 14) | ((head12[8] & 0x7F) << 7) | (head12[9] & 0x7F);
        int footerSize = ((flags & 0x10) != 0) ? 10 : 0;
        id3EndOffset = 10 + tagSize + footerSize;

        int readCap = math.min(10 + tagSize, math.min(track.fileSize, 8 * 1024 * 1024));
        await raf.setPosition(0);
        final id3Data = await raf.read(readCap);

        int offset = 10;
        if ((flags & 0x40) != 0 && offset + 4 <= id3Data.length) {
          int extSize = (version == 4)
              ? (((id3Data[offset] & 0x7F) << 21) | ((id3Data[offset + 1] & 0x7F) << 14) | ((id3Data[offset + 2] & 0x7F) << 7) | (id3Data[offset + 3] & 0x7F))
              : ((id3Data[offset] << 24) | (id3Data[offset + 1] << 16) | (id3Data[offset + 2] << 8) | id3Data[offset + 3]);
          offset += (version == 4) ? extSize : (extSize + 4);
        }

        String? id3Artist;
        while (offset + 10 < id3Data.length) {
          String frameId = String.fromCharCodes(id3Data.sublist(offset, offset + 4));
          if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(frameId)) break;
          int frameSize = (version == 4)
              ? (((id3Data[offset + 4] & 0x7F) << 21) | ((id3Data[offset + 5] & 0x7F) << 14) | ((id3Data[offset + 6] & 0x7F) << 7) | (id3Data[offset + 7] & 0x7F))
              : ((id3Data[offset + 4] << 24) | (id3Data[offset + 5] << 16) | (id3Data[offset + 6] << 8) | id3Data[offset + 7]);
          offset += 10;
          if (frameSize <= 0 || offset + frameSize > id3Data.length) break;

          final payload = id3Data.sublist(offset, offset + frameSize);
          if (frameId == 'TIT2') {
            final t = _decodeId3TextProper(payload);
            if (t.isNotEmpty) track.title = t;
          } else if (frameId == 'TPE1' || frameId == 'TPE2') {
            final a = _decodeId3TextProper(payload);
            if (a.isNotEmpty) {
              if (id3Artist == null) {
                id3Artist = a;
              } else if (!id3Artist.contains(a)) {
                id3Artist = '$id3Artist, $a';
              }
            }
          } else if (frameId == 'TALB') {
            final al = _decodeId3TextProper(payload);
            if (al.isNotEmpty) track.album = al;
          } else if (frameId == 'TCON') {
            final g = _decodeId3TextProper(payload);
            if (g.isNotEmpty) track.genre = g;
          } else if ((frameId == 'TYER' || frameId == 'TDRC') && payload.isNotEmpty) {
            final y = _decodeId3TextProper(payload);
            if (y.isNotEmpty) track.year = y;
          } else if (frameId == 'USLT' && payload.length > 4) {
            final lyr = _decodeId3TextProper(Uint8List.fromList([payload[0], ...payload.sublist(4)]));
            if (lyr.isNotEmpty) {
              track.rawLyrics = lyr;
              track.parsedLyrics = _parseLrc(lyr);
            }
          } else if (frameId == 'APIC' && track.albumArt == null) {
            track.albumArt = _extractApicImageProper(payload);
          }
          offset += frameSize;
        }
        if (id3Artist != null && id3Artist.isNotEmpty) {
          track.artist = id3Artist;
        }
        if (track.path.toLowerCase().endsWith('.mp3')) {
          track.bitrateKbps = 320;
          track.bitDepth = 16;
        }
      }

      // Step B: Search for 'fLaC' magic marker around id3EndOffset (handles prepended ID3 + padding bytes!)
      int flacMagicPos = -1;
      if (head12[0] == 0x66 && head12[1] == 0x4C && head12[2] == 0x61 && head12[3] == 0x43) {
        flacMagicPos = 0;
      } else if (id3EndOffset < track.fileSize - 4) {
        final probeLen = math.min(65536, track.fileSize - id3EndOffset);
        await raf.setPosition(id3EndOffset);
        final probe = await raf.read(probeLen);
        for (int i = 0; i < probe.length - 4; i++) {
          if (probe[i] == 0x66 && probe[i + 1] == 0x4C && probe[i + 2] == 0x61 && probe[i + 3] == 0x43) {
            flacMagicPos = id3EndOffset + i;
            break;
          }
        }
      }

      if (flacMagicPos >= 0) {
        int pos = flacMagicPos + 4;
        while (pos + 4 < track.fileSize) {
          await raf.setPosition(pos);
          final hdr = await raf.read(4);
          if (hdr.length < 4) break;
          bool isLast = (hdr[0] & 0x80) != 0;
          int blockType = hdr[0] & 0x7F;
          int length = (hdr[1] << 16) | (hdr[2] << 8) | hdr[3];
          pos += 4;
          if (length < 0 || pos + length > track.fileSize) break;

          if (blockType == 0 && length >= 18) {
            final data = await raf.read(18);
            int sr = (data[10] << 12) | (data[11] << 4) | ((data[12] & 0xF0) >> 4);
            int bps = (((data[12] & 0x01) << 4) | ((data[13] & 0xF0) >> 4)) + 1;
            int totalSamples = ((data[13] & 0x0F) << 32) | (data[14] << 24) | (data[15] << 16) | (data[16] << 8) | data[17];
            if (sr > 0) {
              track.sampleRateHz = sr;
              if (totalSamples > 0) {
                final secs = totalSamples ~/ sr;
                if (secs > 0) {
                  track.duration = Duration(seconds: secs);
                  track.bitrateKbps = ((track.fileSize * 8) ~/ 1000) ~/ secs;
                }
              }
            }
            if (bps >= 16) track.bitDepth = bps;
          } else if (blockType == 4 && length <= 4 * 1024 * 1024) {
            final data = await raf.read(length);
            int p = 0;
            if (p + 4 <= data.length) {
              int vendorLen = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
              p += 4 + vendorLen;
              if (p + 4 <= data.length) {
                int commentCount = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
                p += 4;
                String? parsedArtist;
                for (int c = 0; c < commentCount && p + 4 <= data.length; c++) {
                  int cLen = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
                  p += 4;
                  if (cLen < 0 || p + cLen > data.length) break;
                  final commentStr = utf8.decode(data.sublist(p, p + cLen), allowMalformed: true);
                  p += cLen;
                  final eqIdx = commentStr.indexOf('=');
                  if (eqIdx > 0) {
                    final key = commentStr.substring(0, eqIdx).trim().toUpperCase();
                    final rawVal = commentStr.substring(eqIdx + 1);
                    if (key == 'METADATA_BLOCK_PICTURE' && track.albumArt == null) {
                      try {
                        final picBytes = base64Decode(rawVal.trim());
                        track.albumArt = _parseFlacPictureBlock(picBytes);
                      } catch (_) {}
                      continue;
                    }
                    final val = _sanitizeMetadataText(rawVal);
                    if (val.isNotEmpty) {
                      if (key == 'TITLE') {
                        track.title = val;
                      } else if (key == 'ARTIST' || key == 'ALBUMARTIST' || key == 'PERFORMER') {
                        if (parsedArtist == null) {
                          parsedArtist = val;
                        } else if (!parsedArtist.contains(val)) {
                          parsedArtist = '$parsedArtist, $val';
                        }
                      } else if (key == 'ALBUM') {
                        track.album = val;
                      } else if (key == 'GENRE') {
                        track.genre = val;
                      } else if (key == 'DATE' || key == 'YEAR') {
                        track.year = val;
                      } else if (key == 'TRACKNUMBER') {
                        track.trackNumber = val;
                      } else if (key == 'LYRICS' || key == 'UNSYNCEDLYRICS') {
                        track.rawLyrics = val;
                        track.parsedLyrics = _parseLrc(val);
                      }
                    }
                  }
                }
                if (parsedArtist != null && parsedArtist.isNotEmpty) {
                  track.artist = parsedArtist;
                }
              }
            }
          } else if (blockType == 6 && length > 32 && length <= 15 * 1024 * 1024 && track.albumArt == null) {
            await raf.setPosition(pos);
            final picBlock = await raf.read(length);
            track.albumArt = _parseFlacPictureBlock(picBlock);
          }

          pos += length;
          if (isLast) break;
        }
      }

      // Step C: M4A / MP4 ('ftyp' at byte 4) Atom Parser
      if (head12[4] == 0x66 && head12[5] == 0x74 && head12[6] == 0x79 && head12[7] == 0x70) {
        await _parseMp4Atoms(raf, track);
      }

      // Step D: Raw JPEG/PNG Header Scan Fallback (catches embedded covers in Ogg/Opus/WAV/non-standard tags)
      if (track.albumArt == null) {
        final scanCap = math.min(track.fileSize, 2500 * 1024);
        await raf.setPosition(0);
        final rawBuf = await raf.read(scanCap);
        track.albumArt = _extractEmbeddedImageBytes(rawBuf, 0, rawBuf.length);
      }

      // Step E: Folder Cover Image Fallback (cover.jpg / folder.jpg / front.jpg)
      if (track.albumArt == null) {
        try {
          final parentDir = file.parent;
          if (await parentDir.exists()) {
            const coverNames = {'cover.jpg', 'cover.png', 'cover.jpeg', 'folder.jpg', 'folder.png', 'front.jpg', 'album.jpg'};
            for (var entity in parentDir.listSync(followLinks: false)) {
              if (entity is File) {
                final name = entity.uri.pathSegments.last.toLowerCase();
                if (coverNames.contains(name)) {
                  track.albumArt = await entity.readAsBytes();
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      // Step F: Fallback filename "Artist - Title" parser if tags had no artist
      if (track.artist == 'Unknown Artist' || track.artist.trim().isEmpty) {
        final fileName = track.path.split('/').last;
        final dotIdx = fileName.lastIndexOf('.');
        final base = (dotIdx > 0 ? fileName.substring(0, dotIdx) : fileName)
            .replaceAll('_', ' ')
            .trim();
        final dashParts = base.split(RegExp(r'\s+[-–—]\s+'));
        if (dashParts.length >= 2) {
          final candidateArtist = _sanitizeMetadataText(dashParts.first);
          final candidateTitle =
              _sanitizeMetadataText(dashParts.sublist(1).join(' - '));
          if (candidateArtist.isNotEmpty && candidateTitle.isNotEmpty) {
            track.artist = candidateArtist;
            if (track.title == base || track.title.contains(' - ')) {
              track.title = candidateTitle;
            }
          }
        }
      }

      final tf =
          File('${thumbDir.path}/${_deterministicPathHash(track.path)}.jpg');
      if (track.albumArt != null && _looksLikeImage(track.albumArt!)) {
        if (!await tf.exists()) {
          await tf.writeAsBytes(track.albumArt!);
        }
        track.thumbPath = tf.path;
        _artworkTick.value++;
      } else if (await tf.exists()) {
        final diskBytes = await tf.readAsBytes();
        if (_looksLikeImage(diskBytes)) {
          track.albumArt = diskBytes;
          track.thumbPath = tf.path;
        }
      }
    } catch (_) {
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
    track.isMetadataLoaded = true;
  }

  Uint8List? _extractEmbeddedImageBytes(Uint8List buf, int start, int end) {
    final limit = math.min(buf.length, end);
    for (int i = math.max(0, start); i < limit - 16; i++) {
      // JPEG magic header: FF D8 FF E0 / E1 / DB
      if (buf[i] == 0xFF &&
          buf[i + 1] == 0xD8 &&
          buf[i + 2] == 0xFF &&
          (buf[i + 3] == 0xE0 || buf[i + 3] == 0xE1 || buf[i + 3] == 0xDB)) {
        for (int j = i + 256; j < limit - 1; j++) {
          if (buf[j] == 0xFF && buf[j + 1] == 0xD9) {
            final candidate = buf.sublist(i, j + 2);
            if (_looksLikeImage(candidate)) return candidate;
            break;
          }
        }
      }
      // PNG magic header: 89 50 4E 47
      if (buf[i] == 0x89 &&
          buf[i + 1] == 0x50 &&
          buf[i + 2] == 0x4E &&
          buf[i + 3] == 0x47) {
        for (int j = i + 256; j < limit - 8; j++) {
          if (buf[j] == 0x49 &&
              buf[j + 1] == 0x45 &&
              buf[j + 2] == 0x4E &&
              buf[j + 3] == 0x44) {
            final endIdx = math.min(limit, j + 8);
            final candidate = buf.sublist(i, endIdx);
            if (_looksLikeImage(candidate)) return candidate;
            break;
          }
        }
      }
    }
    return null;
  }

  Uint8List? _parseFlacPictureBlock(Uint8List picBlock) {
    if (picBlock.length < 32) return null;
    int mimeLen = (picBlock[4] << 24) | (picBlock[5] << 16) | (picBlock[6] << 8) | picBlock[7];
    int descLenPos = 8 + mimeLen;
    if (descLenPos + 4 > picBlock.length) return null;
    int descLen = (picBlock[descLenPos] << 24) | (picBlock[descLenPos + 1] << 16) | (picBlock[descLenPos + 2] << 8) | picBlock[descLenPos + 3];
    int dataLenPos = descLenPos + 4 + descLen + 16;
    if (dataLenPos + 4 > picBlock.length) return null;
    int dataLen = (picBlock[dataLenPos] << 24) | (picBlock[dataLenPos + 1] << 16) | (picBlock[dataLenPos + 2] << 8) | picBlock[dataLenPos + 3];
    int imgStart = dataLenPos + 4;
    if (dataLen > 256 && imgStart + dataLen <= picBlock.length) {
      return picBlock.sublist(imgStart, imgStart + dataLen);
    }
    return null;
  }

  Future<void> _parseMp4Atoms(RandomAccessFile raf, AudioTrack track) async {
    int pos = 0;
    while (pos + 8 < track.fileSize) {
      await raf.setPosition(pos);
      final hdr = await raf.read(8);
      if (hdr.length < 8) break;
      int size = (hdr[0] << 24) | (hdr[1] << 16) | (hdr[2] << 8) | hdr[3];
      String type = latin1.decode(hdr.sublist(4, 8), allowInvalid: true);
      if (size < 8 || pos + size > track.fileSize) break;

      if (type == 'moov' && size <= 8 * 1024 * 1024) {
        final moovData = await raf.read(size - 8);
        _scanMp4MetadataContainer(moovData, 0, moovData.length, track);
        track.bitrateKbps = 256;
        track.bitDepth = 16;
        break;
      }
      pos += size;
    }
  }

  void _scanMp4MetadataContainer(Uint8List buf, int start, int end, AudioTrack track) {
    int p = start;
    while (p + 8 <= end) {
      int size = (buf[p] << 24) | (buf[p + 1] << 16) | (buf[p + 2] << 8) | buf[p + 3];
      String type = latin1.decode(buf.sublist(p + 4, p + 8), allowInvalid: true);
      if (size < 8 || p + size > end) break;

      if (type == 'udta' || type == 'ilst') {
        _scanMp4MetadataContainer(buf, p + 8, p + size, track);
      } else if (type == 'meta' && p + 12 <= p + size) {
        _scanMp4MetadataContainer(buf, p + 12, p + size, track);
      } else if (type == '\xA9nam' || type == '\xA9ART' || type == 'aART' || type == '\xA9alb' || type == '\xA9gen' || type == '\xA9day' || type == 'covr') {
        int inner = p + 8;
        while (inner + 16 <= p + size) {
          int dSize = (buf[inner] << 24) | (buf[inner + 1] << 16) | (buf[inner + 2] << 8) | buf[inner + 3];
          String dType = latin1.decode(buf.sublist(inner + 4, inner + 8), allowInvalid: true);
          if (dSize < 16 || inner + dSize > p + size) break;
          if (dType == 'data') {
            final valBytes = buf.sublist(inner + 16, inner + dSize);
            if (type == 'covr' && track.albumArt == null && valBytes.length > 256) {
              track.albumArt = valBytes;
            } else {
              final str = _sanitizeMetadataText(utf8.decode(valBytes, allowMalformed: true));
              if (str.isNotEmpty) {
                if (type == '\xA9nam') track.title = str;
                if (type == '\xA9ART' || (type == 'aART' && track.artist == 'Unknown Artist')) track.artist = str;
                if (type == '\xA9alb') track.album = str;
                if (type == '\xA9gen') track.genre = str;
                if (type == '\xA9day') track.year = str;
              }
            }
          }
          inner += dSize;
        }
      }
      p += size;
    }
  }

  String _sanitizeMetadataText(String input) {
    return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  String _decodeId3TextProper(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    int encoding = bytes[0];
    Uint8List content = bytes.sublist(1);
    if (content.isEmpty) return '';

    if (encoding == 0) {
      final nullIdx = content.indexOf(0);
      if (nullIdx >= 0) content = content.sublist(0, nullIdx);
      return _sanitizeMetadataText(latin1.decode(content, allowInvalid: true));
    } else if (encoding == 3) {
      final nullIdx = content.indexOf(0);
      if (nullIdx >= 0) content = content.sublist(0, nullIdx);
      return _sanitizeMetadataText(utf8.decode(content, allowMalformed: true));
    } else if (encoding == 1 || encoding == 2) {
      bool littleEndian = false;
      int start = 0;
      if (encoding == 1 && content.length >= 2) {
        if (content[0] == 0xFF && content[1] == 0xFE) {
          littleEndian = true;
          start = 2;
        } else if (content[0] == 0xFE && content[1] == 0xFF) {
          littleEndian = false;
          start = 2;
        }
      }
      final units = <int>[];
      for (int i = start; i + 1 < content.length; i += 2) {
        int code = littleEndian ? (content[i] | (content[i + 1] << 8)) : ((content[i] << 8) | content[i + 1]);
        if (code == 0) break;
        units.add(code);
      }
      return _sanitizeMetadataText(String.fromCharCodes(units));
    }
    return _sanitizeMetadataText(utf8.decode(content, allowMalformed: true));
  }

  Uint8List? _extractApicImageProper(Uint8List payload) {
    if (payload.length < 16) return null;
    int encoding = payload[0];
    int p = 1;
    while (p < payload.length && payload[p] != 0) {
      p++;
    }
    p++;
    if (p >= payload.length) return null;
    p++;

    if (encoding == 1 || encoding == 2) {
      while (p + 1 < payload.length && !(payload[p] == 0 && payload[p + 1] == 0)) {
        p += 2;
      }
      p += 2;
    } else {
      while (p < payload.length && payload[p] != 0) {
        p++;
      }
      p += 1;
    }
    if (p < payload.length && payload.length - p > 256) {
      return payload.sublist(p);
    }
    return null;
  }

  List<LyricLine> _parseLrc(String raw) {
    final lines = raw.split('\n');
    final List<LyricLine> result = [];
    final lineRegExp = RegExp(r'\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\](.*)');
    final syllableRegExp = RegExp(r'<(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?>([^<]+)');

    for (var line in lines) {
      final match = lineRegExp.firstMatch(line.trim());
      if (match != null) {
        final min = int.tryParse(match.group(1)!) ?? 0;
        final sec = int.tryParse(match.group(2)!) ?? 0;
        final msStr = match.group(3) ?? '0';
        final ms = int.tryParse(msStr.padRight(3, '0').substring(0, 3)) ?? 0;
        final rawBody = match.group(4)!.trim();

        final List<SyllableToken> syllables = [];
        for (final sm in syllableRegExp.allMatches(rawBody)) {
          final sMin = int.tryParse(sm.group(1)!) ?? 0;
          final sSec = int.tryParse(sm.group(2)!) ?? 0;
          final sMsStr = sm.group(3) ?? '0';
          final sMs = int.tryParse(sMsStr.padRight(3, '0').substring(0, 3)) ?? 0;
          syllables.add(SyllableToken(
            timestamp: Duration(minutes: sMin, seconds: sSec, milliseconds: sMs),
            text: sm.group(4) ?? '',
          ));
        }

        final cleanText = rawBody.replaceAll(RegExp(r'<\d{1,2}:\d{2}(?:[\.:]\d{1,3})?>'), '').trim();
        if (cleanText.isNotEmpty) {
          result.add(LyricLine(
            timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: cleanText,
            syllables: syllables,
          ));
        }
      }
    }
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  Future<void> _fetchLyricsOnline(AudioTrack song) async {
    if (song.isLyricsFetched && song.parsedLyrics.isNotEmpty) return;
    try {
      final lrcPath = '${song.path.substring(0, song.path.lastIndexOf('.'))}.lrc';
      final lrcFile = File(lrcPath);
      if (await lrcFile.exists()) {
        final localLrc = await lrcFile.readAsString();
        if (localLrc.trim().isNotEmpty) {
          song.rawLyrics = localLrc;
          song.parsedLyrics = _parseLrc(localLrc);
          song.isLyricsFetched = true;
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}

    final cleanTitle = _sanitizeMetadataText(song.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')).trim();
    final primaryArtist = _sanitizeMetadataText(song.artist.split(RegExp(r'[,&•/]|feat\.|ft\.', caseSensitive: false)).first).trim();

    try {
      final getUri = Uri.parse(
        'https://lrclib.net/api/get?track_name=${Uri.encodeComponent(cleanTitle)}&artist_name=${Uri.encodeComponent(primaryArtist)}',
      );
      final getRes = await http.get(getUri, headers: {'User-Agent': 'NamiMusicPlayer/1.0'}).timeout(const Duration(seconds: 4));
      if (getRes.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(getRes.body);
        final String? synced = data['syncedLyrics']?.toString();
        final String? plain = data['plainLyrics']?.toString();
        if ((synced != null && synced.isNotEmpty) || (plain != null && plain.isNotEmpty)) {
          song.rawLyrics = (synced != null && synced.isNotEmpty) ? synced : plain!;
          song.parsedLyrics = _parseLrc(song.rawLyrics);
          song.isLyricsFetched = true;
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _showEditProfileSheet() async {
    final nameCtrl = TextEditingController(text: _userName);
    String? tempPhoto = _userPhotoPath;
    final foundPhotos = <File>[];
    for (final dirPath in [
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM/Camera',
    ]) {
      try {
        final d = Directory(dirPath);
        if (await d.exists()) {
          for (final ent in d.listSync(followLinks: false)) {
            if (ent is File) {
              final l = ent.path.toLowerCase();
              if (l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.webp')) {
                foundPhotos.add(ent);
                if (foundPhotos.length >= 24) break;
              }
            }
          }
        }
      } catch (_) {}
      if (foundPhotos.length >= 24) break;
    }

    if (!mounted) return;
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setProfState) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final chosen = await _pickPhotoDirectlyFromGallery(ctx, title: 'Choose Profile Photo');
                        if (chosen != null && chosen.isNotEmpty && File(chosen).existsSync()) {
                          setProfState(() => tempPhoto = chosen);
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          (tempPhoto != null && File(tempPhoto!).existsSync())
                              ? CircleAvatar(radius: 30, backgroundImage: FileImage(File(tempPhoto!)))
                              : CircleAvatar(
                                  radius: 30,
                                  backgroundColor: accent.withValues(alpha: 0.18),
                                  child: Icon(Icons.headphones_rounded, color: accent, size: 28),
                                ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, size: 11, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          filled: true,
                          fillColor: const Color(0xFF0E0E15),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                if (foundPhotos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Choose Avatar From Device', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      if (tempPhoto != null)
                        TextButton(
                          onPressed: () => setProfState(() => tempPhoto = null),
                          child: const Text('Reset Icon', style: TextStyle(fontSize: 11.5)),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: foundPhotos.length,
                      itemBuilder: (_, idx) {
                        final f = foundPhotos[idx];
                        final selected = tempPhoto == f.path;
                        return GestureDetector(
                          onTap: () => setProfState(() => tempPhoto = f.path),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: selected ? accent : Colors.transparent, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundImage: FileImage(f),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        if (nameCtrl.text.trim().isNotEmpty) {
                          _userName = nameCtrl.text.trim();
                        }
                        _userPhotoPath = tempPhoto;
                      });
                      _saveStateCache();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String> _getThumbCacheSizeLabel() async {
    try {
      final dir = await _ensureThumbDir();
      if (!await dir.exists()) return '0.0 MB';
      int totalBytes = 0;
      int fileCount = 0;
      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is File && !ent.path.endsWith('.json')) {
          totalBytes += await ent.length();
          fileCount++;
        }
      }
      final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB ($fileCount cached covers)';
    } catch (_) {
      return '0.0 MB';
    }
  }

  Future<void> _clearArtworkCache() async {
    try {
      final dir = await _ensureThumbDir();
      if (await dir.exists()) {
        await for (final ent in dir.list(recursive: true, followLinks: false)) {
          if (ent is File && !ent.path.endsWith('.json')) {
            await ent.delete();
          }
        }
      }
      _artistImagePaths.clear();
      _artistDiskChecked.clear();
      for (final s in _songs) {
        s.thumbPath = null;
        s.albumArt = null;
        s.isOnlineEnriched = false;
      }
      _artworkTick.value++;
      if (mounted) setState(() {});
      await _saveStateCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cleared cached cover art. Tap Rescan to rebuild.')),
        );
      }
    } catch (_) {}
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildNamiHomeScreen(List<String> uniqueArtists) {
    final accent = Theme.of(context).colorScheme.primary;
    final prefs = NamiV16Prefs.instance;
    final mostPlayed = List<AudioTrack>.from(_songs)
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final recentlyAdded = List<AudioTrack>.from(_songs)
      ..sort((a, b) => b.addedTimestampMs.compareTo(a.addedTimestampMs));
    final hiResTracks = _songs
        .where((s) => s.bitDepth >= 24 || s.sampleRateHz > 48000)
        .toList();
    final favSongs = _songs.where((s) => s.isFavorite).toList();

    final Map<String, List<AudioTrack>> albMap = {};
    for (final s in _songs) {
      final k = s.album.trim().isNotEmpty ? s.album.trim() : 'Unknown Album';
      albMap.putIfAbsent(k, () => []).add(s);
    }
    final topAlbums = albMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    String? spotlightArtist;
    List<AudioTrack> spotlightTracks = [];
    if (uniqueArtists.isNotEmpty) {
      final sortedArtists = List<String>.from(uniqueArtists)
        ..sort((a, b) {
          final playsB = (artistGroups[b] ?? []).fold<int>(0, (sum, t) => sum + t.playCount);
          final playsA = (artistGroups[a] ?? []).fold<int>(0, (sum, t) => sum + t.playCount);
          if (playsB != playsA) return playsB.compareTo(playsA);
          return (artistGroups[b]?.length ?? 0).compareTo(artistGroups[a]?.length ?? 0);
        });
      spotlightArtist = sortedArtists.first;
      spotlightTracks = artistGroups[spotlightArtist] ?? [];
    }

    final resumeTrack = _currentSong ??
        (_historyTracks.isNotEmpty
            ? _historyTracks.first
            : (_songs.isNotEmpty ? _songs.first : null));

    // Time-of-Day & Rediscover Mixes
    final hour = DateTime.now().hour;
    final timeMixTitle = hour < 12
        ? 'Morning Rotation'
        : (hour < 17 ? 'Afternoon Drive' : (hour < 21 ? 'Evening Chill' : 'Late Night Sessions'));
    final recentPaths = _historyTracks.take(15).map((t) => t.path).toSet();
    final forgottenFavs = _songs
        .where((s) => (s.playCount >= 2 || s.isFavorite) && !recentPaths.contains(s.path))
        .toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final timeMixTracks = mostPlayed.where((s) => s.bitDepth >= 16).take(20).toList();

    // Weekly Recap stats
    final weekKey = prefs.currentWeekKey();
    final weeklyMins = _computeLast7DaysMinutes().fold<double>(0.0, (a, b) => a + b).round();
    final streakDays = _computeListeningStreakDays();
    final curRateTag = _currentSong != null
        ? '${_currentSong!.bitDepth}B • ${(_currentSong!.sampleRateHz / 1000.0).toStringAsFixed(1)}kHz'
        : (_eqEnabled ? _selectedEqPreset : 'Bit-Perfect');

    Widget? buildShelf(String key) {
      if (prefs.hiddenHomeShelves.contains(key)) return null;
      switch (key) {
        case 'recap':
          if (prefs.dismissedRecapWeekKey == weekKey || _songs.isEmpty) return null;
          return Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color.alphaBlend(accent.withValues(alpha: 0.10), const Color(0xFF101018)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_graph_rounded, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _openStatisticsScreen,
                    child: Text(
                      'Weekly Recap • ${weeklyMins > 0 ? "${weeklyMins}m" : "${_totalListenSeconds ~/ 60}m"} • ${streakDays}d streak${spotlightArtist != null ? " • Top: $spotlightArtist" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => prefs.dismissedRecapWeekKey = weekKey);
                    prefs.save();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                  ),
                ),
              ],
            ),
          );

        case 'continue':
          if (resumeTrack == null) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: StreamBuilder<bool>(
              stream: _audioPlayer.stream.playing,
              builder: (ctx, playSnap) {
                final isPlaying = playSnap.data ?? _audioPlayer.state.playing;
                final isSameSong = _currentSong?.path == resumeTrack.path;
                final activeHere = isPlaying && isSameSong;
                return GestureDetector(
                  onTap: () {
                    if (isSameSong) {
                      isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                    } else {
                      _playSong(resumeTrack);
                    }
                  },
                  onLongPress: () => _showHomeQuickActionSheet(track: resumeTrack),
                  child: Container(
                    height: 110,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12121C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              if (resumeTrack.albumArt != null && resumeTrack.albumArt!.isNotEmpty)
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.25,
                                    child: ImageFiltered(
                                      imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                                      child: Image.memory(resumeTrack.albumArt!, fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                child: Row(
                                  children: [
                                    _buildCoverArt(resumeTrack, 80, 14),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                activeHere ? 'NOW PLAYING' : 'CONTINUE LISTENING',
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: accent),
                                              ),
                                              const SizedBox(width: 6),
                                              if (_showCodecBadges) _buildFormatPill(resumeTrack, accent),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(resumeTrack.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                          const SizedBox(height: 2),
                                          Text('${cleanArtistStr(resumeTrack.artist)} • ${resumeTrack.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 12)],
                                      ),
                                      child: Icon(activeHere ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<Duration>(
                          stream: _audioPlayer.stream.position,
                          builder: (pCtx, pSnap) {
                            final pos = isSameSong ? (pSnap.data ?? Duration.zero) : Duration.zero;
                            final durMs = math.max(1, resumeTrack.duration.inMilliseconds);
                            final frac = (pos.inMilliseconds / durMs).clamp(0.0, 1.0);
                            return LinearProgressIndicator(
                              value: frac,
                              minHeight: 2.5,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );

        case 'time_mix':
          if (_songs.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Curated Mixes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildHomeSmartTile(
                        icon: hour >= 21 || hour < 6 ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                        title: timeMixTitle,
                        subtitle: '${timeMixTracks.length} picks',
                        color: accent,
                        onTap: () => _showFilteredListScreen(timeMixTitle, timeMixTracks),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHomeSmartTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Forgotten Favorites',
                        subtitle: '${forgottenFavs.isNotEmpty ? forgottenFavs.length : _songs.length} to rediscover',
                        color: Colors.amberAccent,
                        onTap: () => _showFilteredListScreen(
                          'Forgotten Favorites',
                          forgottenFavs.isNotEmpty ? forgottenFavs : (List<AudioTrack>.from(_songs)..shuffle()).take(30).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

        case 'jump_back':
          if (_historyTracks.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeSectionHeader('Jump Back In', () => _showFilteredListScreen('Play History', _historyTracks)),
                const SizedBox(height: 8),
                _buildHorizontalTrackCarousel(_historyTracks.take(15).toList()),
              ],
            ),
          );

        case 'heavy_rotation':
          if (_songs.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeSectionHeader('Heavy Rotation', () => _showFilteredListScreen('Most Played', mostPlayed.take(50).toList())),
                const SizedBox(height: 8),
                _buildHorizontalTrackCarousel(mostPlayed.take(15).toList(), showPlayBadge: true),
              ],
            ),
          );

        case 'top_albums':
          if (topAlbums.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeSectionHeader('Top Albums', _showAlbumsBrowserScreen),
                const SizedBox(height: 8),
                SizedBox(
                  height: 158,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: math.min(topAlbums.length, 15),
                    itemBuilder: (ctx, idx) {
                      final albEntry = topAlbums[idx];
                      final albTracks = albEntry.value;
                      final artTrack = albTracks.firstWhere(
                        (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
                        orElse: () => albTracks.first,
                      );
                      return GestureDetector(
                        onTap: () => _showAlbumDetailScreen(albEntry.key, albTracks),
                        onLongPress: () => _showHomeQuickActionSheet(albumName: albEntry.key, albumTracks: albTracks),
                        child: Container(
                          width: 114,
                          margin: const EdgeInsets.only(right: 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  _buildCoverArt(artTrack, 110, 14),
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.76), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${albTracks.length} ${albTracks.length == 1 ? 'track' : 'tracks'}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(albEntry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              Text(cleanArtistStr(albTracks.first.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

        case 'spotlight':
          if (spotlightArtist == null || spotlightTracks.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: GestureDetector(
              onTap: () => _showArtistDetailScreen(spotlightArtist!, spotlightTracks),
              onLongPress: () => _showHomeQuickActionSheet(artistName: spotlightArtist, artistTracks: spotlightTracks),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF11111A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    _buildRoundArtistAvatar(spotlightTracks.first, 28, artistNameOverride: spotlightArtist),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ARTIST SPOTLIGHT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: accent)),
                          const SizedBox(height: 2),
                          Text(spotlightArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                          Text('${spotlightTracks.length} songs in your library', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Play', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _playSong(spotlightTracks.first),
                    ),
                  ],
                ),
              ),
            ),
          );

        case 'freshly_added':
          if (_songs.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeSectionHeader('Freshly Added', () => _showFilteredListScreen('Recently Added', recentlyAdded.take(50).toList())),
                const SizedBox(height: 8),
                _buildHorizontalTrackCarousel(recentlyAdded.take(15).toList()),
              ],
            ),
          );

        case 'featured_artists':
          if (uniqueArtists.isEmpty) return null;
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeSectionHeader('Featured Artists', () => setState(() => _selectedIndex = 2)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 112,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: math.min(uniqueArtists.length, 15),
                    itemBuilder: (ctx, idx) {
                      final aName = uniqueArtists[idx];
                      final aTracks = artistGroups[aName] ?? _songs.where((s) => s.artist.contains(aName)).toList();
                      final firstArtTrack = aTracks.isNotEmpty
                          ? aTracks.firstWhere((s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()), orElse: () => aTracks.first)
                          : null;
                      return GestureDetector(
                        onTap: () => _showArtistDetailScreen(aName, aTracks),
                        onLongPress: () => _showHomeQuickActionSheet(artistName: aName, artistTracks: aTracks),
                        child: Container(
                          width: 82,
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            children: [
                              _buildRoundArtistAvatar(firstArtTrack, 34, artistNameOverride: aName),
                              const SizedBox(height: 6),
                              Text(aName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text('${aTracks.length} ${aTracks.length == 1 ? 'Track' : 'Tracks'}', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 115),
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.alphaBlend(accent.withValues(alpha: 0.18), const Color(0xFF13131E)),
                const Color(0xFF0E0E16),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showEditProfileSheet,
                child: Stack(
                  children: [
                    (_userPhotoPath != null && File(_userPhotoPath!).existsSync())
                        ? CircleAvatar(radius: 26, backgroundImage: FileImage(File(_userPhotoPath!)))
                        : CircleAvatar(radius: 26, backgroundColor: accent.withValues(alpha: 0.20), child: Icon(Icons.headphones_rounded, color: accent, size: 25)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF13131E), width: 1.5)),
                        child: const Icon(Icons.edit_rounded, size: 9, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_timeGreeting()}, $_userName', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: _showLiveOutputProfileSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent.withValues(alpha: 0.45), width: 0.7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isExternalAudioConnected ? Icons.usb_rounded : Icons.smartphone_rounded, size: 12, color: accent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$_connectedDacName • $curRateTag',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.expand_more_rounded, size: 13, color: accent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Customize Home Shelves',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.dashboard_customize_outlined, color: Colors.white70, size: 20),
                onPressed: _showHomeShelfCustomizer,
              ),
              IconButton(
                tooltip: 'Listening Statistics',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.06)),
                icon: Icon(Icons.bar_chart_rounded, color: accent, size: 20),
                onPressed: _openStatisticsScreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildHomePillChip(Icons.shuffle_rounded, 'Shuffle All', accent, _shufflePlay),
              _buildHomePillChip(Icons.high_quality_rounded, '24B Hi-Res (${hiResTracks.length})', Colors.cyanAccent, () => _showFilteredListScreen('24B Hi-Res Audio', hiResTracks)),
              _buildHomePillChip(Icons.favorite_rounded, 'Favorites (${favSongs.length})', Colors.pinkAccent, () => _showFilteredListScreen('Favorites', favSongs)),
              _buildHomePillChip(Icons.album_rounded, 'Albums (${topAlbums.length})', Colors.amberAccent, _showAlbumsBrowserScreen),
              _buildHomePillChip(Icons.tune_rounded, 'Equalizer', Colors.tealAccent, _showEqualizerSheet),
              _buildHomePillChip(Icons.bedtime_rounded, 'Sleep Timer', Colors.deepPurpleAccent, _showSleepTimerDialog),
            ],
          ),
        ),
        for (final shelfKey in prefs.homeShelvesOrder)
          if (buildShelf(shelfKey) != null) buildShelf(shelfKey)!,
      ],
    );
  }

  Widget _buildHomePillChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF12121B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _fetchArtistImage(String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty || clean == 'Unknown Artist') return;
    final existing = _artistImagePaths[clean];
    if (existing != null && File(existing).existsSync()) return;
    if (_artistImageFetching.contains(clean)) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final retryAfter = _artistImageRetryAfter[clean] ?? 0;
    if (nowMs < retryAfter) return;

    _artistImageFetching.add(clean);
    try {
      final photoUrl = await NamiArtistMetadataService.fetchBestArtistPhotoUrl(clean);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        final res = await http.get(Uri.parse(photoUrl), headers: _httpHeaders).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final dir = await _ensureThumbDir();
          final artistDir = Directory('${dir.path}/artist_photos');
          if (!await artistDir.exists()) await artistDir.create(recursive: true);
          final safe = clean.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final f = File('${artistDir.path}/$safe.jpg');
          await f.writeAsBytes(res.bodyBytes, flush: true);
          await FileImage(f).evict();
          if (mounted) {
            setState(() {
              _artistImagePaths[clean] = f.path;
              _artworkTick.value++;
            });
          } else {
            _artistImagePaths[clean] = f.path;
          }
          _artistImageRetryAfter.remove(clean);
          _saveStateCache();
          return;
        }
      }
      _artistImageRetryAfter[clean] = nowMs + const Duration(hours: 6).inMilliseconds;
    } catch (_) {
      _artistImageRetryAfter[clean] = nowMs + const Duration(hours: 2).inMilliseconds;
    } finally {
      _artistImageFetching.remove(clean);
    }
  }

  Future<void> _drainArtistImageQueue() async {
    if (_artistImageActive >= 2 || _artistImageQueue.isEmpty) return;
    _artistImageActive++;
    final artistName = _artistImageQueue.removeAt(0);
    try {
      final uri = Uri.parse(
          'https://api.deezer.com/search/artist?q=${Uri.encodeComponent(artistName)}&limit=1');
      final res = await http
          .get(uri, headers: _httpHeaders)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List?) ?? [];
        if (list.isNotEmpty) {
          final picUrl = (list.first['picture_medium'] ??
                  list.first['picture_big'] ??
                  '')
              .toString();
          if (picUrl.isNotEmpty) {
            final imgRes = await http
                .get(Uri.parse(picUrl), headers: _httpHeaders)
                .timeout(const Duration(seconds: 6));
            if (imgRes.statusCode == 200 &&
                _looksLikeImage(imgRes.bodyBytes)) {
              final thumbDir = await _ensureThumbDir();
              final f = File(
                  '${thumbDir.path}/artist_${_deterministicPathHash(artistName.toLowerCase())}.jpg');
              await f.writeAsBytes(imgRes.bodyBytes);
              _artistImagePaths[artistName] = f.path;
              _artworkTick.value++;
            }
          }
        }
      }
    } catch (_) {
      _artistImageRetryAfter[artistName] =
          DateTime.now().millisecondsSinceEpoch + 3600000;
    } finally {
      _artistImageActive--;
      if (_artistImageQueue.isNotEmpty) _drainArtistImageQueue();
    }
  }

  Widget _buildRoundArtistAvatar(AudioTrack? track, double radius, {String? artistNameOverride}) {
    final lookupName = (artistNameOverride != null && artistNameOverride.trim().isNotEmpty)
        ? artistNameOverride.trim()
        : (track != null && track.artist.isNotEmpty && track.artist != 'Unknown Artist'
            ? track.artist
                .split(RegExp(_artistSeparators.map(RegExp.escape).join('|'), caseSensitive: false))
                .first
                .trim()
            : '');
    if (lookupName.isNotEmpty && lookupName != 'Unknown Artist') {
      _fetchArtistImage(lookupName);
    }
    return ValueListenableBuilder<int>(
      valueListenable: _artworkTick,
      builder: (context, tick, __) {
        if (lookupName.isNotEmpty) {
          String? artistImgPath = _artistImagePaths[lookupName];
          if (artistImgPath == null) {
            final lowerKey = lookupName.toLowerCase();
            for (final entry in _artistImagePaths.entries) {
              if (entry.key.toLowerCase() == lowerKey) {
                artistImgPath = entry.value;
                break;
              }
            }
          }
          if (artistImgPath != null) {
            final af = File(artistImgPath);
            if (af.existsSync()) {
              return CircleAvatar(
                key: ValueKey('artist_av_${lookupName}_${af.path}_$tick'),
                radius: radius,
                backgroundColor: const Color(0xFF161622),
                backgroundImage: FileImage(af),
              );
            }
          }
        }
        if (track != null) {
          if (track.albumArt != null && track.albumArt!.isNotEmpty) {
            return CircleAvatar(
              radius: radius,
              backgroundColor: const Color(0xFF161622),
              backgroundImage: MemoryImage(track.albumArt!),
            );
          }
          if (track.thumbPath != null) {
            final f = File(track.thumbPath!);
            if (f.existsSync()) {
              return CircleAvatar(
                radius: radius,
                backgroundColor: const Color(0xFF161622),
                backgroundImage: FileImage(f),
              );
            }
          }
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF161622),
          child: Icon(Icons.person_rounded, size: radius * 0.9, color: Colors.white38),
        );
      },
    );
  }


  Widget _buildHomeSmartTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        GestureDetector(
          onTap: onSeeAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
            child: const Text('See all', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalTrackCarousel(List<AudioTrack> items, {bool showPlayBadge = false}) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final track = items[i];
          return GestureDetector(
            onTap: () => _playSong(track),
            onLongPress: () => _showHomeQuickActionSheet(track: track),
            child: Container(
              width: 108,
              margin: const EdgeInsets.only(right: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _buildCoverArt(track, 104, 14),
                      if (showPlayBadge && track.playCount > 0)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(8)),
                            child: Text('${track.playCount}x', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  Text(cleanArtistStr(track.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTracksPageBody() {
    if (!_hasPermission) {
      return GestureDetector(onTap: () async { await Permission.storage.request(); await Permission.audio.request(); }, child: const Scaffold(backgroundColor: Color(0xFF07070B), body: SafeArea(child: YoutubeSkeletonLoader())));
    }
    if (_isScanning) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 15,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                // Skeleton Album Art
                Container(
                  width: 52, height: 52, 
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10))
                ),
                const SizedBox(width: 8.0),
                // Skeleton Text Lines
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 200, height: 14, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 10),
                      Container(width: 120, height: 10, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                // Skeleton trailing icon
                Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), shape: BoxShape.circle)),
              ],
            ),
          );
        },
      );
    }
    final accent = Theme.of(context).colorScheme.primary;
    final tracksHeaderBar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.shuffle_rounded, size: 20), onPressed: _shufflePlay),
            IconButton(icon: const Icon(Icons.play_arrow_rounded, size: 22), onPressed: () { if (_filteredSongs.isNotEmpty) _playSong(_filteredSongs.first); }),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16)), child: Text(_filteredSongs.length == _songs.length ? '${_songs.length} ${_songs.length == 1 ? 'Track' : 'Tracks'}' : '${_filteredSongs.length} / ${_songs.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: Colors.white70),
              icon: const Icon(Icons.album_rounded, size: 17),
              label: const Text('Albums', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: _showAlbumsBrowserScreen,
            ),
            IconButton(icon: const Icon(Icons.sort_rounded, size: 20), tooltip: 'Sort & Order', onPressed: _showTrackSortSheet),
          ]),
        ),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            children: [
              for (final entry in [('All', 'All'), ('FLAC', 'FLAC'), ('Lossless', 'Lossless'), ('HiRes', '24B'), ('HiRate', '>48kHz'), ('Fav', 'Favorites'), ('Untagged', 'Untagged'), ('NoCover', 'No Cover'), ('Duplicates', 'Duplicates')])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(entry.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _trackFilterMode == entry.$1 ? Colors.white : Colors.white70)),
                    selected: _trackFilterMode == entry.$1,
                    selectedColor: accent,
                    backgroundColor: const Color(0xFF12121B),
                    onSelected: (_) => _applyLibraryFilter(mode: entry.$1),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (_filteredSongs.isEmpty) {
      return Column(
        children: [
          tracksHeaderBar,
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded, size: 42, color: Colors.white30),
                  const SizedBox(height: 10),
                  const Text('No matching tracks found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white70)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset Filter'),
                    onPressed: () {
                      _searchController.clear();
                      _applyLibraryFilter(query: '', mode: 'All');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(children: [
      NamiFastScroller(
        controller: _trackListScrollController,
        itemCount: _filteredSongs.length,
        labelBuilder: (idx) {
          final t = _filteredSongs[idx];
          return '${t.title.isNotEmpty ? t.title[0].toUpperCase() : '#'} • ${idx + 1}/${_filteredSongs.length}';
        },
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: const Color(0xFF14141E),
          onRefresh: _handleV29TracksPullRefresh,
          child: ListView.builder(
            controller: _trackListScrollController,
            padding: const EdgeInsets.only(bottom: 95, right: 8),
            itemCount: _filteredSongs.length + 1,
            itemBuilder: (context, index) {
                            if (index == 0) return tracksHeaderBar;
                            final track = _filteredSongs[index - 1];
                            return NamiSwipeableTrackRow(
                              onPlayAfter: () => _handleV29SwipePlayAfter(track),
                              onShowInfo: () => showNamiFloatingTrackInfoCard(
                                context,
                                track: track,
                                coverArt: _buildCoverArt(track, 62, 14),
                                onPlayNow: () => _playSong(track),
                                onPlayNext: () => _handleV29SwipePlayAfter(track),
                              ),
                              child: _buildNamiTrackTile(track),
                            );
                          },
          ),
        ),
      ),
      if (!_isSelectionMode && _currentSong != null)
        Positioned(
          right: 20,
          bottom: 92,
          child: /* v26_merged_shuffle_locate */
          Tooltip(
            message: 'Tap to Shuffle • Hold to Locate Current Track',
            child: NamiSpringTap(
              pressedScale: 0.90,
              onTap: () {
                _shufflePlay();
              },
              onLongPress: () {
                _locateActivePlayingTrack();
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.shuffle_rounded, color: Colors.black, size: 24),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 11,
                        color: Colors.black.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _buildArtistGroupsMap() {
    artistGroups.clear();
    final escaped = _artistSeparators.map((s) => RegExp.escape(s)).join('|');
    final splitter = (_splitMultiArtists && escaped.isNotEmpty) ? RegExp(escaped, caseSensitive: false) : null;

    for (var song in _songs) {
      if (splitter != null) {
        final parts = song.artist.split(splitter);
        final seenForSong = <String>{};
        for (var rawPart in parts) {
          final clean = NamiV16Prefs.instance.resolveCanonicalArtist(rawPart.trim());
          if (clean.isNotEmpty && seenForSong.add(clean.toLowerCase())) {
            artistGroups.putIfAbsent(clean, () => []).add(song);
          }
        }
      } else {
        artistGroups.putIfAbsent(NamiV16Prefs.instance.resolveCanonicalArtist(cleanArtistStr(song.artist)), () => []).add(song);
      }
    }

    final uniqueArtists = artistGroups.keys.toList();
    if (_artistSortByCount) {
      uniqueArtists.sort((a, b) => artistGroups[b]!.length.compareTo(artistGroups[a]!.length));
    } else {
      uniqueArtists.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return uniqueArtists;
  }

  Widget _buildArtistsPageBody() {
    final uniqueArtists = _buildArtistGroupsMap();
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 12, 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                onPressed: _shufflePlay,
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                onPressed: () {
                  if (uniqueArtists.isNotEmpty) {
                    _playSong(artistGroups[uniqueArtists.first]!.first);
                  }
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16)),
                child: Text('${uniqueArtists.length} artists', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Merge Duplicate Artists',
                icon: const Icon(Icons.merge_type_rounded, size: 20),
                onPressed: () => _showArtistAliasMergeDialog(),
              ),
              IconButton(
                tooltip: _artistGridMode ? 'Switch to List View' : 'Switch to 3-Column Grid',
                icon: Icon(_artistGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
                onPressed: () => setState(() => _artistGridMode = !_artistGridMode),
              ),
              IconButton(
                tooltip: _artistSortByCount ? 'Sort Alphabetically (A-Z)' : 'Sort by Track Count',
                icon: Icon(_artistSortByCount ? Icons.sort_by_alpha_rounded : Icons.sort_rounded, size: 20, color: _artistSortByCount ? accent : Colors.white),
                onPressed: () => setState(() => _artistSortByCount = !_artistSortByCount),
              ),
            ],
          ),
        ),
        Expanded(
          child: NamiFastScroller(
            controller: _artistListScrollController,
            itemCount: uniqueArtists.length,
            labelBuilder: (idx) {
              final name = uniqueArtists[idx];
              final letter = name.isNotEmpty ? name[0].toUpperCase() : '#';
              return '$letter • ${idx + 1}/${uniqueArtists.length}';
            },
            child: _artistGridMode
                ? GridView.builder(
                    controller: _artistListScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 95),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: uniqueArtists.length,
                    itemBuilder: (context, index) {
                      final aName = uniqueArtists[index];
                      final aTracks = artistGroups[aName]!;
                      final firstArtTrack = aTracks.firstWhere(
                        (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
                        orElse: () => aTracks.first,
                      );
                      return GestureDetector(
                      onTap: () => _showArtistDetailScreen(aName, aTracks),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                        child: Column(children: [
                          Expanded(child: _buildRoundArtistAvatar(firstArtTrack, 38, artistNameOverride: aName)),
                          const SizedBox(height: 6),
                          Text(aName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 1),
                          Text('${aTracks.length} ${aTracks.length == 1 ? 'Track' : 'Tracks'}', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                        ]),
                      ),
                    );
                    },
                  )
                : ListView.builder(
                    controller: _artistListScrollController,
                    padding: const EdgeInsets.fromLTRB(10, 4, 12, 95),
                    itemCount: uniqueArtists.length,
                    itemBuilder: (context, index) {
                      final aName = uniqueArtists[index];
                      final aTracks = artistGroups[aName]!;
                      final albumCount = aTracks.map((s) => s.album).toSet().length;
                      final firstArtTrack = aTracks.firstWhere(
                        (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
                        orElse: () => aTracks.first,
                      );
                      return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: _buildRoundArtistAvatar(firstArtTrack, 24, artistNameOverride: aName),
                        title: Text(aName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                        subtitle: Text('$albumCount albums • ${aTracks.length} ${aTracks.length == 1 ? 'track' : 'tracks'}', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                        onTap: () => _showArtistDetailScreen(aName, aTracks),
                      ),
                    );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showAlbumsBrowserScreen() {
    String sortBy = 'title'; // 'title', 'artist', 'year', 'count'
    bool gridMode = true;
    String filterQuery = '';

    NamiShellNavigator.push(MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setAlbState) {
            final Map<String, List<AudioTrack>> map = {};
            for (final s in _songs) {
              final key = s.album.trim().isNotEmpty ? s.album.trim() : 'Unknown Album';
              map.putIfAbsent(key, () => []).add(s);
            }
            var entries = map.entries.where((e) {
              if (filterQuery.isEmpty) return true;
              final q = filterQuery.toLowerCase();
              return e.key.toLowerCase().contains(q) ||
                  e.value.first.artist.toLowerCase().contains(q);
            }).toList();

            entries.sort((a, b) {
              if (sortBy == 'artist') {
                return a.value.first.artist.toLowerCase().compareTo(b.value.first.artist.toLowerCase());
              } else if (sortBy == 'year') {
                return b.value.first.year.compareTo(a.value.first.year);
              } else if (sortBy == 'count') {
                return b.value.length.compareTo(a.value.length);
              }
              return a.key.toLowerCase().compareTo(b.key.toLowerCase());
            });

            final accent = Theme.of(context).colorScheme.primary;
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: Text('Albums (${entries.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(
                    tooltip: gridMode ? 'List View' : 'Grid View',
                    icon: Icon(gridMode ? Icons.view_list_rounded : Icons.grid_view_rounded),
                    onPressed: () => setAlbState(() => gridMode = !gridMode),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort_rounded),
                    color: const Color(0xFF14141E),
                    onSelected: (v) => setAlbState(() => sortBy = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'title', child: Text('Sort: Album A–Z')),
                      PopupMenuItem(value: 'artist', child: Text('Sort: Artist A–Z')),
                      PopupMenuItem(value: 'year', child: Text('Sort: Year (Newest)')),
                      PopupMenuItem(value: 'count', child: Text('Sort: Track Count')),
                    ],
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                        child: TextField(
                          onChanged: (v) => setAlbState(() => filterQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Filter albums or artists...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            filled: true,
                            fillColor: const Color(0xFF14141E),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      Expanded(
                        child: gridMode
                            ? GridView.builder(
                                padding: const EdgeInsets.fromLTRB(14, 2, 14, 110),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.78,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: entries.length,
                                itemBuilder: (ctx, idx) {
                                  final albName = entries[idx].key;
                                  final tracks = entries[idx].value;
                                  final artTrack = tracks.firstWhere(
                                    (t) => t.albumArt != null || (t.thumbPath != null && File(t.thumbPath!).existsSync()),
                                    orElse: () => tracks.first,
                                  );
                                  return GestureDetector(
                                    onTap: () => _showAlbumDetailScreen(albName, tracks),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF101018),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Center(child: _buildCoverArt(artTrack, 138, 12)),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(albName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${cleanArtistStr(tracks.first.artist)} • ${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, color: Colors.white60),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 2, 12, 110),
                                itemCount: entries.length,
                                itemBuilder: (ctx, idx) {
                                  final albName = entries[idx].key;
                                  final tracks = entries[idx].value;
                                  final artTrack = tracks.firstWhere(
                                    (t) => t.albumArt != null || (t.thumbPath != null && File(t.thumbPath!).existsSync()),
                                    orElse: () => tracks.first,
                                  );
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF101018),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ListTile(
                                      leading: _buildCoverArt(artTrack, 50, 10),
                                      title: Text(albName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text('${cleanArtistStr(tracks.first.artist)} • ${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'} • ${tracks.first.year}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                                      trailing: Icon(Icons.play_circle_fill_rounded, color: accent, size: 28),
                                      onTap: () => _showAlbumDetailScreen(albName, tracks),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  Positioned(left: 12, right: 12, bottom: 14, child: _buildDetailFloatingDock(context, scopeTitle: 'All Albums', scopeTracks: _songs)),
                ],
              ),
            );
          },
        ),
      ), fallbackContext: context);
  }

  void _toggleTrackSelection(AudioTrack song) {
    setState(() {
      if (_selectedTrackPaths.contains(song.path)) {
        _selectedTrackPaths.remove(song.path);
        if (_selectedTrackPaths.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedTrackPaths.add(song.path);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTrackPaths.clear();
    });
  }

  List<AudioTrack> get _selectedTracksList =>
      _songs.where((s) => _selectedTrackPaths.contains(s.path)).toList();

  void _showBatchAddToPlaylistDialog(List<AudioTrack> batch) {
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add ${batch.length} ${batch.length == 1 ? 'Track' : 'Tracks'} to Playlist', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._customPlaylists.map((pl) => ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(pl.name),
                    subtitle: Text('${pl.tracks.length} ${pl.tracks.length == 1 ? 'Track' : 'Tracks'}'),
                    onTap: () {
                      setState(() {
                        for (final s in batch) {
                          if (!pl.tracks.contains(s)) pl.tracks.add(s);
                        }
                      });
                      _saveStateCache();
                      _exitSelectionMode();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${batch.length} ${batch.length == 1 ? 'track' : 'tracks'} to ${pl.name}')));
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchSelectionBar() {
    final accent = Theme.of(context).colorScheme.primary;
    final batch = _selectedTracksList;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.75), blurRadius: 16)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            icon: Icon(Icons.playlist_play_rounded, color: accent, size: 20),
            label: const Text('Play Next', style: TextStyle(fontSize: 11.5, color: Colors.white)),
            onPressed: () {
              setState(() => _playNextQueue.addAll(batch));
              _exitSelectionMode();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queued ${batch.length} ${batch.length == 1 ? 'track' : 'tracks'}')));
            },
          ),
          TextButton.icon(
            icon: Icon(Icons.playlist_add_rounded, color: accent, size: 20),
            label: const Text('Playlist', style: TextStyle(fontSize: 11.5, color: Colors.white)),
            onPressed: () => _showBatchAddToPlaylistDialog(batch),
          ),
          TextButton.icon(
            icon: Icon(Icons.edit_note_rounded, color: accent, size: 20),
            label: const Text('Tags', style: TextStyle(fontSize: 11.5, color: Colors.white)),
            onPressed: () => _showBatchTagEditorSheet(batch),
          ),
          TextButton.icon(
            icon: Icon(Icons.favorite_rounded, color: accent, size: 18),
            label: const Text('Fav', style: TextStyle(fontSize: 11.5, color: Colors.white)),
            onPressed: () {
              setState(() {
                for (final s in batch) {
                  s.isFavorite = true;
                }
              });
              _saveStateCache();
              _exitSelectionMode();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Favorited ${batch.length} ${batch.length == 1 ? 'track' : 'tracks'}')));
            },
          ),
          IconButton(
            tooltip: 'Delete Selected',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: () async {
              for (final s in batch) {
                try {
                  final f = File(s.path);
                  if (await f.exists()) await f.delete();
                } catch (_) {}
              }
              setState(() {
                _songs.removeWhere((s) => _selectedTrackPaths.contains(s.path));
                _filteredSongs.removeWhere((s) => _selectedTrackPaths.contains(s.path));
              });
              _saveStateCache();
              _exitSelectionMode();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNamiTrackTile(AudioTrack song) {
    final isCurrent = _currentSong?.path == song.path;
    final isSelected = _selectedTrackPaths.contains(song.path);
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 1.5, 4, 1.5),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.22)
            : (isCurrent ? accent.withValues(alpha: 0.12) : const Color(0xFF0C0C12)),
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: accent.withValues(alpha: 0.6)) : null,
      ),
      child: Dismissible(
        key: Key('${song.path}_${song.hashCode}'),
        direction: _isSelectionMode ? DismissDirection.none : DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 22),
        ),
        confirmDismiss: (direction) async {
          final act = direction == DismissDirection.startToEnd
              ? NamiV16Prefs.instance.swipeRightAction
              : NamiV16Prefs.instance.swipeLeftAction;
          if (act == 'favorite') {
            HapticFeedback.lightImpact();
            setState(() => song.isFavorite = !song.isFavorite);
            _saveStateCache();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(song.isFavorite ? 'Added "${song.title}" to Favorites' : 'Removed "${song.title}" from Favorites')),
            );
          } else if (act == 'play_next') {
            HapticFeedback.lightImpact();
            setState(() => _playNextQueue.insert(0, song));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queued "${song.title}" to play next')));
          } else if (act == 'add_playlist') {
            _showAddToPlaylistDialog(song);
          }
          return false;
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _toggleTrackSelection(song);
          },
          onTap: () {
            if (_isSelectionMode) {
              _toggleTrackSelection(song);
            } else {
              _playSong(song);
            }
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, _compactTrackTiles ? 4.5 : 8, 6, _compactTrackTiles ? 4.5 : 8),
            child: Row(children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? accent : Colors.white38,
                    size: 22,
                  ),
                ),
              Stack(
                alignment: Alignment.center,
                children: [
                  _buildCoverArt(song, _compactTrackTiles ? 44 : 54, _compactTrackTiles ? 8 : 10),
                  if (isCurrent)
                    Container(
                      width: _compactTrackTiles ? 44 : 54,
                      height: _compactTrackTiles ? 44 : 54,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.65),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: StreamBuilder<bool>(
                          stream: _audioPlayer.stream.playing,
                          builder: (ctx, snap) => AnimatedPlayingBars(
                            isPlaying: snap.data ?? _audioPlayer.state.playing,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cleanArtistStr(song.artist),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white70),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (_showCodecBadges) ...[
                          _buildFormatPill(song, Theme.of(context).colorScheme.primary, onTap: () => _applyLibraryFilter(mode: song.bitDepth >= 24 ? 'HiRes' : 'FLAC')),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            '${song.album} • ${formatReleaseDate(song.year)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatDurationPadded(song.duration), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () {
                        setState(() => song.isFavorite = !song.isFavorite);
                        _saveStateCache();
                      },
                      child: Icon(
                        song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: song.isFavorite ? Theme.of(context).colorScheme.primary : Colors.white38,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 19),
                  onPressed: () => _showTrackOptionsMenu(song),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactiveMiniPlayer() {
    final accent = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<AudioTrack?>(
      valueListenable: _currentSongNotifier,
      builder: (context, activeSong, _) {
        return NamiSpringMiniPlayerWrap(/* v28_main_mini_spring */
            trackKey: _currentSong?.path,
            onOpenTap: () => _openMorphNowPlaying(),
            onStartDragOpen: (rect) => _openMorphNowPlaying(miniRect: rect, startFromDrag: true),
            onNext: () => _playNextTrack(),
            onPrev: () => _playPrevTrack(),
            child: GestureDetector(
          
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -150) _showNowPlayingScreen();
          },
          onTap: _showNowPlayingScreen,
          child: Container(
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _forceMiniColor ? Color.alphaBlend(accent.withValues(alpha: 0.22), const Color(0xFF12121A)) : const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _forceMiniColor ? accent.withValues(alpha: 0.45) : Colors.white12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.65), blurRadius: 18, spreadRadius: 4)],
            ),
            child: Column(children: [
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(
              children: [
                if (activeSong != null)
                  Hero(tag: 'nami_np_art_${activeSong.path}', child: _buildCoverArt(activeSong, 48, 10))
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: 0.24), Colors.white.withValues(alpha: 0.06)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Icon(Icons.graphic_eq_rounded, size: 24, color: accent),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeSong?.title ?? 'Tap any song to play',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Row(
                          children: [
                            Expanded(
                              child: Text(
                                cleanArtistStr(activeSong?.artist),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                              ),
                            ),
                            if (activeSong != null && _showCodecBadges) ...[
                              const SizedBox(width: 6),
                              _buildFormatPill(activeSong, accent),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                StreamBuilder<bool>(
                  stream: _audioPlayer.stream.playing,
                  builder: (ctx, snap) {
                    final playing = snap.data ?? _audioPlayer.state.playing;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.skip_previous_rounded, size: 23, color: Colors.white70),
                          onPressed: _playPrevTrack,
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (playing) {
                              _audioPlayer.pause();
                            } else {
                              if (_currentSong == null && _filteredSongs.isNotEmpty) {
                                _playSong(_filteredSongs.first);
                              } else {
                                _audioPlayer.play();
                              }
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.20),
                              shape: BoxShape.circle,
                              border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.1),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                key: ValueKey<bool>(playing),
                                size: 23,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.skip_next_rounded, size: 23, color: Colors.white70),
                          onPressed: _playNextTrack,
                        ),
                ],
              );
            },
          ),
        ],
      ))),
      StreamBuilder<Duration>(
        stream: _audioPlayer.stream.position,
        builder: (context, snap) {
          final pos = snap.data ?? Duration.zero;
          final dur = _audioPlayer.state.duration;
          final ratio = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
          return LinearProgressIndicator(value: ratio, minHeight: 2.5, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(accent));
        },
      ),
    ]),
  ),
        ),
          );
      },
    );
  }

  Widget _buildCoverArt(AudioTrack song, double size, double radius) {
    return ValueListenableBuilder<int>(
      valueListenable: _artworkTick,
      builder: (context, _, __) {
        if (song.albumArt != null && song.albumArt!.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              song.albumArt!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: (size * 2.5).round().clamp(64, 512),
              errorBuilder: (_, __, ___) => _defaultArt(size, radius),
            ),
          );
        }
        if (song.thumbPath != null) {
          final f = File(song.thumbPath!);
          if (f.existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Image.file(
                f,
                width: size,
                height: size,
                fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: (size * 2.5).round().clamp(64, 512),
                errorBuilder: (_, __, ___) => _defaultArt(size, radius),
              ),
            );
          }
        }
        return _defaultArt(size, radius);
      },
    );
  }

  Widget _defaultArt(double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(radius)),
      child: Icon(Icons.album_rounded, size: size * 0.5, color: Colors.white38),
    );
  }

  void _showNowPlayingScreen() {
    if (_currentSong == null && _filteredSongs.isNotEmpty) {
      _playSong(_filteredSongs.first);
    } else if (_currentSong != null) {
      _fetchLyricsOnline(_currentSong!);
    }
    _openMorphNowPlaying();
  }

void _showAlbumDetailScreen(String albumName, List<AudioTrack> albumTracks) {
    if (albumTracks.isEmpty) return;
    final firstTrack = albumTracks.first;
    final artTrack = albumTracks.firstWhere(
      (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
      orElse: () => firstTrack,
    );
    final totalSecs = albumTracks.fold<int>(0, (sum, s) => sum + s.duration.inSeconds);
    final totalDurText = _formatTotalDurationHoursMins(Duration(seconds: totalSecs));
    final accent = Theme.of(context).colorScheme.primary;

    NamiShellNavigator.push(MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Album', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 140),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCoverArt(artTrack, 116, 16),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(albumName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _showArtistDetailScreen(
                                  cleanArtistStr(firstTrack.artist),
                                  _songs.where((s) => s.artist.contains(firstTrack.artist)).toList(),
                                ),
                                child: Text(
                                  cleanArtistStr(firstTrack.artist),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: accent),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${albumTracks.length} ${albumTracks.length == 1 ? 'Track' : 'Tracks'} • $totalDurText • ${firstTrack.year}',
                                style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                    label: const Text('Play', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _playSong(albumTracks.first),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    icon: const Icon(Icons.shuffle_rounded, size: 16),
                                    label: const Text('Shuffle', style: TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      final sh = List<AudioTrack>.from(albumTracks)..shuffle();
                                      _playSong(sh.first);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 6),
                  ...albumTracks.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final song = entry.value;
                    final badge = song.trackNumber.isNotEmpty ? song.trackNumber.split('/').first : '$idx';
                    return Stack(
                      children: [
                        _buildNamiTrackTile(song),
                        Positioned(
                          top: 8,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(5)),
                            child: Text('#$badge', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              Positioned(left: 12, right: 12, bottom: 14, child: _buildDetailFloatingDock(context, scopeTitle: albumName, scopeTracks: albumTracks)),
            ],
          ),
        ),
      ), fallbackContext: context);
  }

  void _showFilteredListScreen(String title, List<AudioTrack> tracks) {
  final totalSec = tracks.fold<int>(0, (sum, t) => sum + t.duration.inSeconds);
  final durText = _formatTotalDurationHoursMins(Duration(seconds: totalSec));
  Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
    appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
    body: Stack(children: [
      ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 140),
        itemCount: tracks.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${tracks.length} ${tracks.length == 1 ? 'Track' : 'Tracks'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Total duration • $durText', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                ])),
                if (tracks.isNotEmpty) ...[
                  IconButton.filled(style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black), icon: const Icon(Icons.play_arrow_rounded), onPressed: () => _playSong(tracks.first)),
                  const SizedBox(width: 6),
                  IconButton.outlined(style: IconButton.styleFrom(side: const BorderSide(color: Colors.white24)), icon: const Icon(Icons.shuffle_rounded, size: 20), onPressed: () { final sh = List<AudioTrack>.from(tracks)..shuffle(); _playSong(sh.first); }),
                ],
              ]),
            );
          }
          return _buildNamiTrackTile(tracks[i - 1]);
        },
      ),
      Positioned(left: 10, right: 10, bottom: 12, child: _buildReactiveMiniPlayer()),
    ]),
  )));
}

void _showCreatePlaylistDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14141F),
        title: const Text('New Playlist'),
        content: TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Playlist name...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() => _customPlaylists.add(CustomPlaylist(name: nameCtrl.text.trim(), tracks: [])));
                _saveStateCache();
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPlaylistM3u8(CustomPlaylist playlist) async {
    try {
      final safeName = playlist.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final outDir = Directory('/storage/emulated/0/Music');
      if (!await outDir.exists()) await outDir.create(recursive: true);
      final outFile = File('${outDir.path}/$safeName.m3u8');
      final buf = StringBuffer('#EXTM3U\n');
      for (final t in playlist.tracks) {
        buf.writeln('#EXTINF:${t.duration.inSeconds},${cleanArtistStr(t.artist)} - ${t.title}');
        buf.writeln(t.path);
      }
      await outFile.writeAsString(buf.toString(), encoding: utf8);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${outFile.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importPlaylistsM3u8() async {
    final byPath = {for (final s in _songs) s.path: s};
    final byFileName = {for (final s in _songs) s.path.split('/').last.toLowerCase(): s};
    int importedCount = 0;

    for (final dirPath in ['/storage/emulated/0/Music', '/storage/emulated/0/Download']) {
      try {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;
        for (final ent in dir.listSync(recursive: true, followLinks: false)) {
          if (ent is File) {
            final lower = ent.path.toLowerCase();
            if (lower.endsWith('.m3u8') || lower.endsWith('.m3u')) {
              final lines = await ent.readAsLines();
              final matched = <AudioTrack>[];
              for (final rawLine in lines) {
                final line = rawLine.trim();
                if (line.isEmpty || line.startsWith('#')) continue;
                final direct = byPath[line];
                if (direct != null) {
                  if (!matched.contains(direct)) matched.add(direct);
                } else {
                  final fname = line.split(RegExp(r'[/\\]')).last.toLowerCase();
                  final byName = byFileName[fname];
                  if (byName != null && !matched.contains(byName)) {
                    matched.add(byName);
                  }
                }
              }
              final rawName = ent.uri.pathSegments.last;
              final plName = rawName.substring(0, rawName.lastIndexOf('.'));
              final existingIdx = _customPlaylists.indexWhere((p) => p.name.toLowerCase() == plName.toLowerCase());
              if (existingIdx != -1) {
                for (final t in matched) {
                  if (!_customPlaylists[existingIdx].tracks.contains(t)) {
                    _customPlaylists[existingIdx].tracks.add(t);
                  }
                }
              } else {
                _customPlaylists.add(CustomPlaylist(name: plName, tracks: matched));
              }
              importedCount++;
            }
          }
        }
      } catch (_) {}
    }

    if (importedCount > 0) {
      setState(() {});
      _saveStateCache();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importedCount > 0
              ? 'Imported $importedCount .m3u8 playlist(s)!'
              : 'No .m3u8 files found in /Music or /Download'),
        ),
      );
    }
  }

  void _showRenamePlaylistDialog(CustomPlaylist playlist) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141F),
        title: const Text('Rename Playlist'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => playlist.name = ctrl.text.trim());
                _saveStateCache();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openPlaylistEditorScreen(CustomPlaylist playlist) {
    String plSearch = '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setEdState) {
            final accent = Theme.of(context).colorScheme.primary;
            final totalSec = playlist.tracks.fold<int>(0, (sum, t) => sum + t.duration.inSeconds);
            final durText = _formatTotalDurationHoursMins(Duration(seconds: totalSec));
            final q = plSearch.trim().toLowerCase();
            final visible = q.isEmpty
                ? playlist.tracks
                : playlist.tracks.where((s) =>
                    s.title.toLowerCase().contains(q) ||
                    s.artist.toLowerCase().contains(q) ||
                    s.album.toLowerCase().contains(q)).toList();

            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(
                    tooltip: 'Remove Duplicate Tracks',
                    icon: const Icon(Icons.cleaning_services_outlined, size: 20),
                    onPressed: () {
                      final seen = <String>{};
                      final before = playlist.tracks.length;
                      setEdState(() {
                        playlist.tracks.retainWhere((t) => seen.add(t.path));
                      });
                      setState(() {});
                      _saveStateCache();
                      _autoSyncPlaylistM3u8IfEnabled(playlist);
                      final removed = before - playlist.tracks.length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(removed > 0 ? 'Removed $removed duplicate(s)!' : 'No duplicates found.')),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Sort & Save Order',
                    icon: const Icon(Icons.sort_rounded),
                    color: const Color(0xFF14141E),
                    onSelected: (by) {
                      setEdState(() {
                        playlist.tracks.sort((a, b) {
                          if (by == 'artist') return a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
                          if (by == 'album') return a.album.toLowerCase().compareTo(b.album.toLowerCase());
                          if (by == 'duration') return a.duration.inSeconds.compareTo(b.duration.inSeconds);
                          if (by == 'added') return b.addedTimestampMs.compareTo(a.addedTimestampMs);
                          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
                        });
                      });
                      setState(() {});
                      _saveStateCache();
                      _autoSyncPlaylistM3u8IfEnabled(playlist);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sorted by $by & saved order!')));
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'title', child: Text('Sort: Title (Save Order)')),
                      PopupMenuItem(value: 'artist', child: Text('Sort: Artist (Save Order)')),
                      PopupMenuItem(value: 'album', child: Text('Sort: Album (Save Order)')),
                      PopupMenuItem(value: 'duration', child: Text('Sort: Duration (Save Order)')),
                      PopupMenuItem(value: 'added', child: Text('Sort: Date Added (Save Order)')),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Add Tracks',
                    icon: const Icon(Icons.playlist_add_rounded),
                    onPressed: () {
                      showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xFF12121A),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (bCtx) => StatefulBuilder(
                          builder: (bCtx, setPickState) => SizedBox(
                            height: MediaQuery.of(bCtx).size.height * 0.75,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Add Songs to Playlist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                      TextButton(onPressed: () => Navigator.pop(bCtx), child: const Text('Done')),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _songs.length,
                                    itemBuilder: (_, i) {
                                      final s = _songs[i];
                                      final inPl = playlist.tracks.contains(s);
                                      return ListTile(
                                        leading: _buildCoverArt(s, 42, 8),
                                        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        subtitle: Text(cleanArtistStr(s.artist), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        trailing: Icon(inPl ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: inPl ? accent : Colors.white54),
                                        onTap: () {
                                          setPickState(() {
                                            inPl ? playlist.tracks.remove(s) : playlist.tracks.add(s);
                                          });
                                          setEdState(() {});
                                          setState(() {});
                                          _saveStateCache();
                                          _autoSyncPlaylistM3u8IfEnabled(playlist);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Export .m3u8',
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: () => _exportPlaylistM3u8(playlist),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            _buildPlaylistCollageArt(playlist, 48, 10),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${playlist.tracks.length} ${playlist.tracks.length == 1 ? 'Track' : 'Tracks'} • $durText', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  const Text('Drag handle to reorder • Search below', style: TextStyle(fontSize: 11, color: Colors.white54)),
                                ],
                              ),
                            ),
                            if (playlist.tracks.isNotEmpty) ...[
                              IconButton.filled(
                                style: IconButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                                icon: const Icon(Icons.play_arrow_rounded),
                                onPressed: () => _playSong(playlist.tracks.first),
                              ),
                              const SizedBox(width: 6),
                              IconButton.outlined(
                                style: IconButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                                icon: const Icon(Icons.shuffle_rounded, size: 20),
                                onPressed: () {
                                  final sh = List<AudioTrack>.from(playlist.tracks)..shuffle();
                                  _playSong(sh.first);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: TextField(
                          onChanged: (v) => setEdState(() => plSearch = v),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Filter songs in ${playlist.name}...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFF12121B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(child: Text('No matching tracks in playlist.', style: TextStyle(color: Colors.white54)))
                            : ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                padding: const EdgeInsets.fromLTRB(10, 4, 10, 120),
                                itemCount: visible.length,
                                onReorder: (oldIndex, newIndex) {
                                  if (q.isNotEmpty) return;
                                  setEdState(() {
                                    if (newIndex > oldIndex) newIndex -= 1;
                                    final item = playlist.tracks.removeAt(oldIndex);
                                    playlist.tracks.insert(newIndex, item);
                                  });
                                  setState(() {});
                                  _saveStateCache();
                                  _autoSyncPlaylistM3u8IfEnabled(playlist);
                                },
                                itemBuilder: (ctx, idx) {
                                  final s = visible[idx];
                                  return Container(
                                    key: ValueKey('pl_${playlist.name}_${s.path}_$idx'),
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0E0E15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      leading: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (q.isEmpty)
                                            ReorderableDragStartListener(
                                              index: idx,
                                              child: const Padding(
                                                padding: EdgeInsets.only(right: 8),
                                                child: Icon(Icons.drag_indicator_rounded, color: Colors.white38, size: 20),
                                              ),
                                            ),
                                          _buildCoverArt(s, 44, 8),
                                        ],
                                      ),
                                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                      subtitle: Text(cleanArtistStr(s.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          setEdState(() => playlist.tracks.remove(s));
                                          setState(() {});
                                          _saveStateCache();
                                          _autoSyncPlaylistM3u8IfEnabled(playlist);
                                        },
                                      ),
                                      onTap: () => _playSong(s),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  Positioned(left: 10, right: 10, bottom: 12, child: _buildReactiveMiniPlayer()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNamiPlaylistsPage() {
    final accent = Theme.of(context).colorScheme.primary;
    final prefs = NamiV16Prefs.instance;
    final favSongs = _songs.where((s) => s.isFavorite).toList();
    final mostPlayed = List<AudioTrack>.from(_songs)..sort((a, b) => b.playCount.compareTo(a.playCount));
    final unplayedSongs = _songs.where((s) => s.playCount == 0).toList();
    final cutoff30d = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final recent30dSongs = _songs.where((s) => s.addedTimestampMs >= cutoff30d).toList();

    final sortedCustom = List<CustomPlaylist>.from(_customPlaylists)
      ..sort((a, b) {
        final pa = prefs.pinnedPlaylists.contains(a.name) ? 0 : 1;
        final pb = prefs.pinnedPlaylists.contains(b.name) ? 0 : 1;
        if (pa != pb) return pa.compareTo(pb);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16)),
              child: Text('${_customPlaylists.length + prefs.smartPlaylists.length + 1} playlists', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Smart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => _showSmartPlaylistBuilderDialog(),
            ),
            TextButton.icon(
              icon: const Icon(Icons.file_open_rounded, size: 16),
              label: const Text('.m3u8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _importPlaylistsM3u8,
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _showCreatePlaylistDialog,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Compact Horizontal Shortcuts Strip so personal playlists stay above the fold
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildHomePillChip(Icons.shuffle_rounded, 'Shuffle (${_songs.length})', Colors.greenAccent, _shufflePlay),
              _buildHomePillChip(Icons.history_rounded, 'History (${_historyTracks.length})', Colors.purpleAccent, () => _showFilteredListScreen('Play History', _historyTracks)),
              _buildHomePillChip(Icons.category_rounded, 'Genres', Colors.pinkAccent, _openGenresBrowserScreen),
              _buildHomePillChip(Icons.favorite_rounded, 'Favorites (${favSongs.length})', accent, () => _showFilteredListScreen('Favorites', favSongs)),
              _buildHomePillChip(Icons.album_rounded, 'Albums', Colors.cyanAccent, _showAlbumsBrowserScreen),
              _buildHomePillChip(Icons.local_fire_department_rounded, 'Most Played', Colors.orangeAccent, () => _showFilteredListScreen('Most Played', mostPlayed.take(50).toList())),
              _buildHomePillChip(Icons.fiber_new_rounded, 'Unplayed (${unplayedSongs.length})', Colors.tealAccent, () => _showFilteredListScreen('Unplayed Tracks', unplayedSongs)),
              _buildHomePillChip(Icons.calendar_month_rounded, 'Recent 30d (${recent30dSongs.length})', Colors.lightBlueAccent, () => _showFilteredListScreen('Added Last 30 Days', recent30dSongs)),
            ],
          ),
        ),
        if (prefs.smartPlaylists.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Smart Rule Mixes', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          for (final rule in prefs.smartPlaylists)
            Builder(builder: (_) {
              final matched = _evaluateSmartRulePlaylist(rule);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.auto_awesome_rounded, color: accent, size: 22),
                  ),
                  title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${matched.length} ${matched.length == 1 ? 'Track' : 'Tracks'} • ${rule.describeRules()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                    color: const Color(0xFF14141E),
                    onSelected: (v) async {
                      if (v == 'edit') _showSmartPlaylistBuilderDialog(existing: rule);
                      if (v == 'delete') {
                        prefs.smartPlaylists.removeWhere((x) => x.id == rule.id);
                        await prefs.save();
                        setState(() {});
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit Rules')),
                      PopupMenuItem(value: 'delete', child: Text('Delete Smart Mix', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                  onTap: () => _showFilteredListScreen(rule.name, matched),
                ),
              );
            }),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('Your Playlists', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                prefs.autoSyncPlaylistsM3u8 = !prefs.autoSyncPlaylistsM3u8;
                await prefs.save();
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_rounded, size: 14, color: prefs.autoSyncPlaylistsM3u8 ? accent : Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      prefs.autoSyncPlaylistsM3u8 ? 'Auto .m3u8 ON' : 'Auto .m3u8 OFF',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: prefs.autoSyncPlaylistsM3u8 ? accent : Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildPlaylistCardTile(
          title: 'Liked Songs',
          subtitle: '${favSongs.length} ${favSongs.length == 1 ? 'Track' : 'Tracks'}',
          icon: Icons.favorite_rounded,
          coverTrack: favSongs.isNotEmpty ? favSongs.first : null,
          onTap: () => _showFilteredListScreen('Liked Songs', favSongs),
          onPlay: () {
            if (favSongs.isNotEmpty) _playSong(favSongs.first);
          },
        ),
        ...sortedCustom.map((p) {
          final isPinned = prefs.pinnedPlaylists.contains(p.name);
          final desc = prefs.playlistDescriptions[p.name] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isPinned ? accent.withValues(alpha: 0.45) : Colors.white10),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
              leading: _buildPlaylistCollageArt(p, 50, 10),
              title: Row(
                children: [
                  if (isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(Icons.push_pin_rounded, size: 13, color: accent),
                    ),
                  Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                ],
              ),
              subtitle: Text(
                desc.isNotEmpty ? '${p.tracks.length} ${p.tracks.length == 1 ? 'Track' : 'Tracks'} • $desc' : '${p.tracks.length} ${p.tracks.length == 1 ? 'Track' : 'Tracks'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Colors.white54),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 30, color: Colors.white70),
                    onPressed: () {
                      if (p.tracks.isNotEmpty) _playSong(p.tracks.first);
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                    color: const Color(0xFF14141E),
                    onSelected: (val) async {
                      if (val == 'edit') _openPlaylistEditorScreen(p);
                      if (val == 'pin') {
                        if (isPinned) {
                          prefs.pinnedPlaylists.remove(p.name);
                        } else {
                          prefs.pinnedPlaylists.add(p.name);
                        }
                        await prefs.save();
                        setState(() {});
                      }
                      if (val == 'cover') {
                        final img = await _pickPhotoDirectlyFromGallery(context, title: 'Playlist Cover (${p.name})');
                        if (img != null && img.isNotEmpty) {
                          prefs.playlistCustomCovers[p.name] = img;
                          await prefs.save();
                          setState(() {});
                        }
                      }
                      if (val == 'desc') {
                        final dCtrl = TextEditingController(text: desc);
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: const Color(0xFF14141F),
                            title: const Text('Playlist Description'),
                            content: TextField(controller: dCtrl, autofocus: true, decoration: const InputDecoration(hintText: 'Add a short note...')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () async {
                                  prefs.playlistDescriptions[p.name] = dCtrl.text.trim();
                                  await prefs.save();
                                  if (dCtx.mounted) Navigator.pop(dCtx);
                                  setState(() {});
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      }
                      if (val == 'rename') _showRenamePlaylistDialog(p);
                      if (val == 'export') _exportPlaylistM3u8(p);
                      if (val == 'delete') {
                        setState(() => _customPlaylists.remove(p));
                        _saveStateCache();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit, Search & Sort Tracks')),
                      PopupMenuItem(value: 'pin', child: Text(isPinned ? 'Unpin Playlist' : 'Pin to Top')),
                      const PopupMenuItem(value: 'cover', child: Text('Pick Custom Cover')),
                      const PopupMenuItem(value: 'desc', child: Text('Edit Description')),
                      const PopupMenuItem(value: 'rename', child: Text('Rename Playlist')),
                      const PopupMenuItem(value: 'export', child: Text('Export as .m3u8')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Playlist', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ],
              ),
              onTap: () => _openPlaylistEditorScreen(p),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlaylistCardTile({
    required String title,
    required String subtitle,
    required IconData icon,
    AudioTrack? coverTrack,
    required VoidCallback onTap,
    required VoidCallback onPlay,
    Widget? trailingExtra,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
        leading: coverTrack != null
            ? _buildCoverArt(coverTrack, 48, 10)
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accent, size: 24),
              ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, size: 30, color: Colors.white70),
              onPressed: onPlay,
            ),
            if (trailingExtra != null) trailingExtra,
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniqueArtistsForHome = _buildArtistGroupsMap();
    final List<String> tabTitles = ['Nami', 'Tracks', 'Artists', 'Playlists', 'Mornye'];

    final List<Widget> pages = [
      _buildNamiHomeScreen(uniqueArtistsForHome),
      _buildTracksPageBody(),
      _buildArtistsPageBody(),
      _buildNamiPlaylistsPage(),
      ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 115),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.travel_explore_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mornye Catalog & Repo', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                      Text(
                        '${_extensions.where((e) => e.isInstalled).length} active extensions • Save -> $_mornyeDownloadFolder',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<List<MornyeDownloadTask>>(
                  valueListenable: NamiDownloadManager.instance.tasksNotifier,
                  builder: (_, tasks, __) {
                    final activeCount = tasks
                        .where((t) =>
                            t.status == MornyeDownloadStatus.queued ||
                            t.status == MornyeDownloadStatus.downloading ||
                            t.status == MornyeDownloadStatus.tagging)
                        .length;
                    return IconButton(
                      tooltip: 'Download Manager',
                      icon: Badge(
                        isLabelVisible: activeCount > 0,
                        label: Text('$activeCount', style: const TextStyle(fontSize: 9.5)),
                        child: const Icon(Icons.downloading_rounded, size: 20),
                      ),
                      onPressed: _showMornyeDownloadsSheet,
                    );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.extension_rounded, size: 16),
                  label: const Text('Repo'),
                  onPressed: _openExtensionRepoScreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _mornyeServices
                  .map((srv) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(srv, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          selected: _selectedMornyeService == srv,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor: const Color(0xFF12121B),
                          onSelected: (_) => setState(() => _selectedMornyeService = srv),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _mornyeSearchController,
            onSubmitted: _searchMornyeCatalog,
            decoration: InputDecoration(
              hintText: 'Search $_selectedMornyeService tracks, albums, artists...',
              filled: true,
              fillColor: const Color(0xFF14141F),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => _searchMornyeCatalog(_mornyeSearchController.text),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Track', 'Album', 'Artist'].map((tFilter) {
                final sel = _mornyeFilterType == tFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tFilter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.white70)),
                    selected: sel,
                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                    backgroundColor: const Color(0xFF0E0E15),
                    onSelected: (_) => setState(() => _mornyeFilterType = tFilter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (_isMornyeSearching)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
            )
          else if (_mornyeResults.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  const Text('Quick Search Suggestions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getSmartMornyeQuickSearches()
                        .map((sampleQ) => ActionChip(
                              label: Text(sampleQ, style: const TextStyle(fontSize: 11.5)),
                              backgroundColor: const Color(0xFF161622),
                              onPressed: () {
                                _mornyeSearchController.text = sampleQ;
                                _searchMornyeCatalog(sampleQ);
                              },
                            ))
                        .toList(),
                  ),
                ],
              ),
            )
          else
            ..._mornyeResults
                .where((item) => _mornyeFilterType == 'All' || item.type == _mornyeFilterType)
                .map((item) {
                  final isPlayingPreview = _activePreviewKey == item.itemKey && _audioPlayer.state.playing;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListTile(
                      onTap: (item.type == 'Album' || item.type == 'Artist')
                          ? () => _openMornyeDrillDownScreen(item)
                          : () => _playMornyePreview(item),
                      leading: item.artworkUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(item.artworkUrl!, width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(9)),
                              child: Icon(
                                item.type == 'Artist'
                                    ? Icons.person_rounded
                                    : (item.type == 'Album' ? Icons.album_rounded : Icons.music_note_rounded),
                                color: Colors.white60,
                              ),
                            ),
                      title: Row(
                        children: [
                          Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
                          if (item.type == 'Track' && _isTrackInLocalLibrary(item.title, item.artist))
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Tooltip(
                                message: 'Already in Library',
                                child: Icon(Icons.check_circle_rounded, size: 15, color: Colors.greenAccent),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.type} • ${item.artist}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          const SizedBox(height: 2),
                          Text(
                            _extensions.any((e) => e.isInstalled && e.isEnabled && (e.endpointUrl ?? '').trim().isNotEmpty)
                                ? '${item.service} • ${NamiV16Prefs.instance.mornyePreferredQuality}'
                                : '${item.service} • 30s Preview',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                      trailing: (item.type == 'Album' || item.type == 'Artist')
                          ? const Icon(Icons.chevron_right_rounded, color: Colors.white54)
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.previewUrl != null && item.previewUrl!.isNotEmpty)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: isPlayingPreview ? 'Pause Preview' : 'Preview Track',
                                    icon: Icon(
                                      isPlayingPreview ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      if (isPlayingPreview) {
                                        _audioPlayer.pause();
                                        setState(() => _activePreviewKey = null);
                                      } else {
                                        _playMornyePreview(item);
                                      }
                                    },
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Queue Stream Directly',
                                  icon: const Icon(Icons.playlist_add_rounded, size: 20, color: Colors.white70),
                                  onPressed: () => _queueMornyeStreamTrack(item),
                                ),
                                if (item.previewUrl != null && item.previewUrl!.isNotEmpty)
                                  _downloadingTitles.contains(item.itemKey)
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Download to Music',
                                          icon: const Icon(Icons.download_rounded),
                                          onPressed: () => _downloadMornyeItem(item),
                                        ),
                              ],
                            ),
                    ),
                  );
                }),
        ],
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (NamiExpandablePlayerController.isExpanded) {
          NamiExpandablePlayerController.collapse();
          return;
        }
        if (NamiShellNavigator.maybePop()) return;
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
        SystemNavigator.pop();
      },
      child: NamiExpandablePlayerHost(
        hasSong: _currentSong != null,
        title: _currentSong?.title ?? '',
        artist: _currentSong != null ? cleanArtistStr(_currentSong!.artist) : '',
        trackKey: _currentSong?.path ?? '',
        coverBuilder: (sz, rad) => _currentSong != null
            ? _buildCoverArt(_currentSong!, sz, rad)
            : const SizedBox.shrink(),
        isPlayingStream: _audioPlayer.stream.playing,
        initialPlaying: _audioPlayer.state.playing,
        fullPageBuilder: _currentSong == null
            ? null
            : (_) {
                final song = _currentSong!;
                return NowPlayingModal(
        onGoToArtist: (artist) => _openArtistByName(artist),
          audioPlayer: _audioPlayer,
          currentSongNotifier: _currentSongNotifier,
          allSongs: _songs,
          playNextQueue: _playNextQueue,
          ambientGlow: _ambientGlow,
          blurredBackdrop: _blurredBackdrop,
          doubleTapSeekSec: _doubleTapSeekSec,
          syllableLyricsEnabled: _syllableLyricsEnabled,
          shuffleEnabled: _shuffleEnabled,
          repeatMode: _repeatMode,
          onToggleShuffle: () {
            setState(() => _shuffleEnabled = !_shuffleEnabled);
            _saveStateCache();
          },
          onCycleRepeat: () {
            setState(() => _repeatMode = (_repeatMode + 1) % 3);
            _audioPlayer.setPlaylistMode(_repeatMode == 2 ? PlaylistMode.single : PlaylistMode.none);
            _saveStateCache();
          },
          onShowPath: () {
            if (_currentSong != null) _showAudioPathDetails(_currentSong!);
          },
          onShowEqualizer: _showEqualizerSheet,
          onShowSleepTimer: _showSleepTimerDialog,
          onOpenLyricsManager: () {
            if (_currentSong != null) _showNamiLyricsManagerSheet(_currentSong!);
          },
          onToggleFavorite: () {
            if (_currentSong != null) {
              setState(() => _currentSong!.isFavorite = !_currentSong!.isFavorite);
              _saveStateCache();
            }
          },
          onRefreshLyrics: () {
            if (_currentSong != null) {
              _currentSong!.isLyricsFetched = false;
              _fetchLyricsOnline(_currentSong!);
            }
          },
          onNext: _playNextTrack,
          onPrevious: _playPrevTrack,
          onOpenQueue: () => _showQueueBottomSheet(context),
          onOpenMoreMenu: () {
            if (_currentSong != null) _showTrackOptionsMenu(_currentSong!);
          },
        );
              },
        child: Scaffold(
      body: Stack(
        children: [
          NamiShellNavigator(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF12121C),
              leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _exitSelectionMode),
              title: Text('${_selectedTrackPaths.length} Selected', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedTrackPaths.length == _filteredSongs.length) {
                        _exitSelectionMode();
                      } else {
                        _selectedTrackPaths.addAll(_filteredSongs.map((s) => s.path));
                      }
                    });
                  },
                  child: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _filterSongs,
                      decoration: const InputDecoration(hintText: 'Search library...', border: InputBorder.none),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded, size: 17, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(tabTitles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                    ],
                  ),
              actions: [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _filteredSongs = _songs;
                      }
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Playback Queue',
                  icon: Badge(
                    isLabelVisible: _playNextQueue.isNotEmpty,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    label: Text('${_playNextQueue.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    child: const Icon(Icons.queue_music_rounded),
                  ),
                  onPressed: () => _showQueueBottomSheet(context),
                ),
                IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings),
              ],
            ),
            body: NamiSwipeableTabsView(
              currentIndex: _selectedIndex,
              onPageChanged: (idx) {
                if (mounted && _selectedIndex != idx) {
                  setState(() => _selectedIndex = idx);
                }
              },
              children: pages,
            ),
          ),
        ),
          if (_isSelectionMode)
            Positioned(left: 10, right: 10, bottom: 86, child: _buildBatchSelectionBar()),
          Positioned(left: 10, right: 10, bottom: 8, child: _buildReactiveMiniPlayer()),
        ],
      ),
      bottomNavigationBar: NamiExpandableBottomNavWrap(
        child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          child: NavigationBar(
            height: 64,
            backgroundColor: const Color(0xFF07070B),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
            indicatorShape: const StadiumBorder(),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) {
              HapticFeedback.selectionClick();
              NamiShellNavigator.popToRoot(); setState(() => _selectedIndex = idx);
            },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.white60, size: 23),
              selectedIcon: Icon(Icons.home_rounded, color: Colors.white, size: 23),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined, color: Colors.white60, size: 23),
              selectedIcon: Icon(Icons.library_music_rounded, color: Colors.white, size: 23),
              label: 'Tracks',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: Colors.white60, size: 23),
              selectedIcon: Icon(Icons.people_rounded, color: Colors.white, size: 23),
              label: 'Artists',
            ),
            NavigationDestination(
              icon: Icon(Icons.queue_music_outlined, color: Colors.white60, size: 23),
              selectedIcon: Icon(Icons.queue_music_rounded, color: Colors.white, size: 23),
              label: 'Playlists',
            ),
            NavigationDestination(
              icon: Icon(Icons.extension_outlined, color: Colors.white60, size: 23),
              selectedIcon: Icon(Icons.extension_rounded, color: Colors.white, size: 23),
              label: 'Mornye',
            ),
          ],
        ),
        ),
      ),
      ),
    ),
      ),
    );
  }

List<String> _getSmartMornyeQuickSearches() {
    final counts = <String, int>{};
    for (final s in _songs) {
      final raw = s.artist.toString().trim();
      if (raw.isEmpty || raw.toLowerCase() == 'unknown artist') continue;
      final primary = raw.split(RegExp(r'[,&]|feat\.|ft\.', caseSensitive: false)).first.trim();
      if (primary.isNotEmpty) counts[primary] = (counts[primary] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final picks = sorted.take(5).map((e) => e.key).toList();
    if (picks.length < 5) {
      for (final fb in ['FLAC Lossless', '24-Bit Hi-Res', 'Instrumental', 'Acoustic Sessions', 'Live Performance']) {
        if (!picks.contains(fb)) picks.add(fb);
        if (picks.length == 5) break;
      }
    }
    return picks;
  }

  /// Fetches multiple artist photo options from Deezer + iTunes so user can select which one they want
  Future<List<Map<String, String>>> _fetchArtistPhotoCandidates(String artistName) async {
    final candidates = <Map<String, String>>[];
    final seenUrls = <String>{};
    final q = Uri.encodeComponent(artistName.trim());

    try {
      final res = await http
          .get(Uri.parse('https://api.deezer.com/search/artist?q=$q&limit=10'), headers: _httpHeaders)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          for (final item in (data['data'] as List)) {
            if (item is Map) {
              final url = (item['picture_xl'] ?? item['picture_big'] ?? item['picture_medium'] ?? '').toString().trim();
              final name = (item['name'] ?? artistName).toString().trim();
              if (url.startsWith('http') && !url.contains('/artist//') && seenUrls.add(url)) {
                candidates.add({'url': url, 'label': '$name (Artist Portrait)'});
              }
            }
          }
        }
      }
    } catch (_) {}

    try {
      final albRes = await http
          .get(Uri.parse('https://api.deezer.com/search/album?q=$q&limit=8'), headers: _httpHeaders)
          .timeout(const Duration(seconds: 12));
      if (albRes.statusCode == 200) {
        final data = jsonDecode(albRes.body);
        if (data is Map && data['data'] is List) {
          for (final item in (data['data'] as List)) {
            if (item is Map) {
              final url = (item['cover_xl'] ?? item['cover_big'] ?? item['cover_medium'] ?? '').toString().trim();
              final title = (item['title'] ?? 'Cover').toString().trim();
              if (url.startsWith('http') && seenUrls.add(url)) {
                candidates.add({'url': url, 'label': '$title (Cover Art)'});
              }
            }
          }
        }
      }
    } catch (_) {}

    try {
      final itRes = await http
          .get(Uri.parse('https://itunes.apple.com/search?term=$q&entity=album&limit=8'), headers: _httpHeaders)
          .timeout(const Duration(seconds: 12));
      if (itRes.statusCode == 200) {
        final data = jsonDecode(itRes.body);
        if (data is Map && data['results'] is List) {
          for (final item in (data['results'] as List)) {
            if (item is Map) {
              final rawArt = (item['artworkUrl100'] ?? '').toString().trim();
              final collName = (item['collectionName'] ?? 'Apple Music').toString().trim();
              if (rawArt.startsWith('http')) {
                final hiRes = rawArt.replaceAll('100x100bb', '600x600bb');
                if (seenUrls.add(hiRes)) {
                  candidates.add({'url': hiRes, 'label': '$collName (Hi-Res)'});
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return candidates;
  }

  Future<void> _saveArtistImageFromUrlOrFile(String artistName, String sourcePathOrUrl, {VoidCallback? onUpdated}) async {
    try {
      final dir = await _ensureThumbDir();
      final artistDir = Directory('${dir.path}/artist_custom');
      if (!await artistDir.exists()) await artistDir.create(recursive: true);
      final safe = artistName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final savedFile = File('${artistDir.path}/${safe}_$ts.jpg');

      if (sourcePathOrUrl.startsWith('http://') || sourcePathOrUrl.startsWith('https://')) {
        final res = await http.get(Uri.parse(sourcePathOrUrl), headers: _httpHeaders).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          await savedFile.writeAsBytes(res.bodyBytes, flush: true);
        } else {
          return;
        }
      } else {
        final srcFile = File(sourcePathOrUrl);
        if (!await srcFile.exists()) return;
        await srcFile.copy(savedFile.path);
      }

      final oldPath = _artistImagePaths[artistName];
      if (oldPath != null && oldPath != savedFile.path) {
        try {
          await FileImage(File(oldPath)).evict();
          if (oldPath.contains('artist_custom')) {
            final of = File(oldPath);
            if (await of.exists()) await of.delete();
          }
        } catch (_) {}
      }
      await FileImage(savedFile).evict();

      setState(() {
        _artistImagePaths[artistName] = savedFile.path;
        _artworkTick.value++;
      });
      await _saveStateCache();
      if (onUpdated != null) onUpdated();
    } catch (_) {}
  }

  Future<void> _showArtistFetchedPhotoSelector(BuildContext parentCtx, String artistName, {VoidCallback? onUpdated}) async {
    bool loading = true;
    List<Map<String, String>> options = [];
    bool started = false;

    await showModalBottomSheet<void>(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (!started) {
            started = true;
            _fetchArtistPhotoCandidates(artistName).then((res) {
              if (ctx.mounted) {
                setSheetState(() {
                  options = res;
                  loading = false;
                });
              }
            });
          }
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.68,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Artist Photo • $artistName',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library_outlined, size: 17),
                        label: const Text('From Gallery', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final picked = await _pickPhotoDirectlyFromGallery(parentCtx, title: 'Choose Artist Photo');
                          if (picked != null && picked.isNotEmpty) {
                            await _saveArtistImageFromUrlOrFile(artistName, picked, onUpdated: onUpdated);
                            if (mounted) {
                              ScaffoldMessenger.of(parentCtx).showSnackBar(
                                SnackBar(content: Text('Updated artist photo for $artistName')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the image you want to apply as artist avatar & cover:',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Color(0xFFE53935)),
                                SizedBox(height: 12),
                                Text('Fetching artist photos...', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          )
                        : options.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.white38),
                                    const SizedBox(height: 10),
                                    const Text('No online artist photos found.', style: TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 10),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                                      label: const Text('Pick Photo from Gallery'),
                                      onPressed: () async {
                                        Navigator.of(ctx).pop();
                                        final picked = await _pickPhotoDirectlyFromGallery(parentCtx, title: 'Choose Artist Photo');
                                        if (picked != null && picked.isNotEmpty) {
                                          await _saveArtistImageFromUrlOrFile(artistName, picked, onUpdated: onUpdated);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: options.length,
                                itemBuilder: (_, idx) {
                                  final item = options[idx];
                                  return GestureDetector(
                                    onTap: () async {
                                      Navigator.of(ctx).pop();
                                      if (mounted) {
                                        ScaffoldMessenger.of(parentCtx).showSnackBar(
                                          SnackBar(content: Text('Applying selected photo for $artistName...')),
                                        );
                                      }
                                      await _saveArtistImageFromUrlOrFile(artistName, item['url']!, onUpdated: onUpdated);
                                      if (mounted) {
                                        ScaffoldMessenger.of(parentCtx).showSnackBar(
                                          SnackBar(content: Text('Updated artist photo for $artistName')),
                                        );
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A24),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                              child: Image.network(
                                                item['url']!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(5),
                                            child: Text(
                                              item['label'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Picks a photo directly from Android Gallery (via native MethodChannel first, then visual device Gallery Grid — zero URL input!)
  Future<String?> _pickPhotoDirectlyFromGallery(BuildContext parentCtx, {String title = 'Select Photo from Gallery'}) async {
    try {
      const channel = MethodChannel('com.nami.music/gallery_picker');
      final nativePath = await channel.invokeMethod<String>('pickImageFromGallery');
      if (nativePath != null && nativePath.isNotEmpty && File(nativePath).existsSync()) {
        return nativePath;
      }
    } catch (_) {}

    // Visual Device Gallery Grid (scans DCIM, Pictures, Download, Screenshots, WhatsApp Images — no URL field)
    final galleryImages = <File>[];
    final dirsToScan = [
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/DCIM/Screenshots',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Pictures/Screenshots',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
    ];
    for (final dirPath in dirsToScan) {
      try {
        final d = Directory(dirPath);
        if (await d.exists()) {
          await for (final ent in d.list(followLinks: false)) {
            if (ent is File) {
              final l = ent.path.toLowerCase();
              if (l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.webp')) {
                galleryImages.add(ent);
              }
            }
          }
        }
      } catch (_) {}
    }
    galleryImages.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    if (!mounted) return null;
    return showModalBottomSheet<String>(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.65,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library_rounded, color: Color(0xFFE53935), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: galleryImages.isEmpty
                    ? const Center(
                        child: Text(
                          'No photos found in DCIM, Pictures, or Download.\nGrant storage/media permission in Android Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: galleryImages.length > 90 ? 90 : galleryImages.length,
                        itemBuilder: (_, idx) {
                          final img = galleryImages[idx];
                          return GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(img.path),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(img, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

/// Namida-style Home Screen Listening Statistics Card with Interactive Donut/Pie Chart & Heavy Detail



  /// Parses [mm:ss.xx] LRC text into sorted timed lines
  /// Parses [mm:ss.xx] LRC text AND splits inline tags / dummy [00:00.00] lines cleanly



  /// Namida-Style Fullscreen Synced Lyrics Mode
  /// Namida-Style Fullscreen Synced Lyrics Mode (opens on Long-Press of Lyrics in Now Playing!)
  /// Matches Namida UI: Top-left back chevron, centered Title/Artist, top-right Lyrics Sheet icon,
  /// dark warm-tinted gradient, ShaderMask top/bottom fade, highlighted translucent pill for active line,
  /// tap-to-seek, bottom waveform seekbar + timestamps + Namida outlined transport controls!



// 0 = Off, 1 = Repeat Queue, 2 = Repeat One, 3 = Repeat N Times
// sourceKey -> last played track path



















  double _lyricsOffsetSeconds = 0.0;
  double _lyricsFontSize = 21.0;
  bool _lyricsCenterAlign = true;
  bool _autoFetchLyricsEnabled = true;

  int _trackDurationMs(dynamic track) {
    try {
      final d = (track as dynamic).duration;
      if (d is Duration) return d.inMilliseconds;
      if (d is int) return d > 10000 ? d : d * 1000;
    } catch (_) {}
    try {
      final ms = (track as dynamic).durationMs;
      if (ms is int) return ms;
    } catch (_) {}
    return 0;
  }

  void _openStatisticsScreen() {
    final accent = Theme.of(context).colorScheme.primary;
    int detailTab = 0; // 0 = Listening Share, 1 = Audio Quality, 2 = Library Artists, 3 = Release Eras
    int selectedSlice = -1;

    int totalBytes = 0;
    int totalDurationMs = 0;
    int flac24Count = 0;
    int flac16Count = 0;
    int alacWavCount = 0;
    int lossyCount = 0;
    int favCount = 0;
    final artistTrackCounts = <String, int>{};
    final albumSet = <String>{};
    final eraCounts = <String, int>{};

    for (final s in _songs) {
      try {
        if (s.fileSize > 0) {
          totalBytes += s.fileSize;
        } else {
          final f = File(s.path);
          if (f.existsSync()) totalBytes += f.lengthSync();
        }
      } catch (_) {}
      totalDurationMs += _trackDurationMs(s);
      if (s.isFavorite) favCount++;
      final alb = s.album.trim();
      if (alb.isNotEmpty) albumSet.add(alb);

      final pathLower = s.path.toLowerCase();
      if (pathLower.endsWith('.flac')) {
        if (s.bitDepth >= 24) {
          flac24Count++;
        } else {
          flac16Count++;
        }
      } else if (pathLower.endsWith('.alac') || pathLower.endsWith('.wav') || pathLower.endsWith('.aiff')) {
        alacWavCount++;
      } else {
        lossyCount++;
      }

      final rawArt = s.artist.trim();
      if (rawArt.isNotEmpty && rawArt.toLowerCase() != 'unknown artist') {
        final primary = rawArt.split(RegExp(r'[,&]|feat\.|ft\.', caseSensitive: false)).first.trim();
        if (primary.isNotEmpty) artistTrackCounts[primary] = (artistTrackCounts[primary] ?? 0) + 1;
      }

      final yr = int.tryParse(s.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (yr >= 2020) {
        eraCounts['2020s'] = (eraCounts['2020s'] ?? 0) + 1;
      } else if (yr >= 2010) {
        eraCounts['2010s'] = (eraCounts['2010s'] ?? 0) + 1;
      } else if (yr >= 2000) {
        eraCounts['2000s'] = (eraCounts['2000s'] ?? 0) + 1;
      } else if (yr > 1900) {
        eraCounts['Classic (<2000)'] = (eraCounts['Classic (<2000)'] ?? 0) + 1;
      } else {
        eraCounts['Untagged'] = (eraCounts['Untagged'] ?? 0) + 1;
      }
    }

    int listenTotalMs = _totalListenSeconds * 1000;
    int hiResPlays = 0;
    int cdPlays = 0;
    int lossyPlays = 0;
    final playedArtistCounts = <String, int>{};
    final playedArtistMs = <String, int>{};
    final playedTrackCounts = <String, int>{};
    final playedTrackTitles = <String, String>{};
    final recentPlayBars = List<double>.filled(7, 0.0);

    for (int i = 0; i < _historyTracks.length; i++) {
      final h = _historyTracks[i];
      final dMs = _trackDurationMs(h);
      if (_totalListenSeconds == 0) listenTotalMs += dMs;
      recentPlayBars[i % 7] += (dMs > 0 ? dMs / 60000.0 : 3.5);

      final pLow = h.path.toLowerCase();
      if (pLow.endsWith('.flac') && h.bitDepth >= 24) {
        hiResPlays++;
      } else if (pLow.endsWith('.flac') || pLow.endsWith('.alac') || pLow.endsWith('.wav')) {
        cdPlays++;
      } else {
        lossyPlays++;
      }

      final rawA = h.artist.trim();
      final pArt = rawA.isEmpty ? 'Unknown Artist' : rawA.split(RegExp(r'[,&]|feat\.|ft\.', caseSensitive: false)).first.trim();
      playedArtistCounts[pArt] = (playedArtistCounts[pArt] ?? 0) + 1;
      playedArtistMs[pArt] = (playedArtistMs[pArt] ?? 0) + dMs;

      playedTrackCounts[h.path] = (playedTrackCounts[h.path] ?? 0) + 1;
      playedTrackTitles[h.path] = '${h.title} • $pArt';
    }

    final topPlayedArtists = playedArtistCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topPlayedTracks = playedTrackCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLibArtists = artistTrackCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final mostPlayedSongs = List<AudioTrack>.from(_songs)..sort((a, b) => b.playCount.compareTo(a.playCount));

    final listenHours = listenTotalMs ~/ 3600000;
    final listenMins = (listenTotalMs % 3600000) ~/ 60000;
    final avgSessionSec = _historyTracks.isEmpty ? 0 : (listenTotalMs ~/ 1000) ~/ _historyTracks.length;
    final discoveryRatio = _songs.isEmpty ? 0 : ((playedTrackCounts.length * 100) / _songs.length).clamp(0, 100).round();
    final totalGb = totalBytes / (1024 * 1024 * 1024);
    final avgBitrateKbps = totalDurationMs > 0 ? ((totalBytes * 8) ~/ totalDurationMs) : 0;
    final totalLibHours = totalDurationMs ~/ 3600000;
    final totalLibMins = (totalDurationMs % 3600000) ~/ 60000;
    final losslessPct = _songs.isEmpty ? 0 : (((flac24Count + flac16Count + alacWavCount) * 100) / _songs.length).round();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (ctx, setStatsState) {
            List<_NamiPieSlice> slices;
            String centerTop;
            String centerSub;

            if (detailTab == 0) {
              if (_historyTracks.isNotEmpty) {
                final palette = [accent, const Color(0xFF00ACC1), const Color(0xFF8E24AA), const Color(0xFF43A047), const Color(0xFFFFB300), const Color(0xFF546E7A)];
                if (topPlayedArtists.length >= 2) {
                  final top4 = topPlayedArtists.take(4).toList();
                  final top4Plays = top4.fold<int>(0, (s, e) => s + e.value);
                  final otherPlays = (_historyTracks.length - top4Plays).clamp(0, _historyTracks.length);
                  slices = [
                    for (int i = 0; i < top4.length; i++)
                      _NamiPieSlice(label: top4[i].key, value: top4[i].value.toDouble(), color: palette[i % palette.length]),
                    if (otherPlays > 0)
                      _NamiPieSlice(label: 'Other Artists', value: otherPlays.toDouble(), color: palette[5]),
                  ];
                } else {
                  slices = [
                    _NamiPieSlice(label: '24-Bit Hi-Res Plays', value: hiResPlays.toDouble(), color: accent),
                    _NamiPieSlice(label: '16-Bit Lossless Plays', value: cdPlays.toDouble(), color: const Color(0xFF00ACC1)),
                    _NamiPieSlice(label: 'Lossy Plays', value: lossyPlays.toDouble(), color: const Color(0xFFFFB300)),
                  ];
                }
                centerTop = '${_historyTracks.length}';
                centerSub = 'Total Plays';
              } else {
                slices = [
                  _NamiPieSlice(label: '24-Bit Ready', value: flac24Count.toDouble(), color: accent),
                  _NamiPieSlice(label: '16-Bit Ready', value: flac16Count.toDouble(), color: const Color(0xFF00ACC1)),
                ];
                centerTop = '${listenHours}h ${listenMins}m';
                centerSub = 'Listen Time';
              }
            } else if (detailTab == 1) {
              slices = [
                _NamiPieSlice(label: 'FLAC 24-Bit Hi-Res', value: flac24Count.toDouble(), color: accent),
                _NamiPieSlice(label: 'FLAC 16-Bit CD', value: flac16Count.toDouble(), color: const Color(0xFF00ACC1)),
                _NamiPieSlice(label: 'ALAC / WAV', value: alacWavCount.toDouble(), color: const Color(0xFF43A047)),
                _NamiPieSlice(label: 'AAC / MP3', value: lossyCount.toDouble(), color: const Color(0xFFFFB300)),
              ];
              centerTop = '$losslessPct%';
              centerSub = 'Lossless';
            } else if (detailTab == 2) {
              final palette = [accent, const Color(0xFF00ACC1), const Color(0xFF8E24AA), const Color(0xFF43A047), const Color(0xFFFFB300), const Color(0xFF546E7A)];
              final top4 = topLibArtists.take(4).toList();
              final top4Sum = top4.fold<int>(0, (s, e) => s + e.value);
              final restCount = (_songs.length - top4Sum).clamp(0, _songs.length);
              slices = [
                for (int i = 0; i < top4.length; i++)
                  _NamiPieSlice(label: top4[i].key, value: top4[i].value.toDouble(), color: palette[i % palette.length]),
                if (restCount > 0)
                  _NamiPieSlice(label: 'Other Artists', value: restCount.toDouble(), color: palette[5]),
              ];
              centerTop = '${artistTrackCounts.length}';
              centerSub = 'Artists';
            } else {
              final palette = [accent, const Color(0xFF00ACC1), const Color(0xFF8E24AA), const Color(0xFF43A047), const Color(0xFF546E7A)];
              final entries = eraCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              slices = [
                for (int i = 0; i < entries.length; i++)
                  _NamiPieSlice(label: entries[i].key, value: entries[i].value.toDouble(), color: palette[i % palette.length]),
              ];
              centerTop = '${albumSet.length}';
              centerSub = 'Albums';
            }

            final totalSliceVal = slices.fold<double>(0, (s, e) => s + e.value);
            final activeSlice = (selectedSlice >= 0 && selectedSlice < slices.length) ? slices[selectedSlice] : null;

            Widget heavyCard(IconData icon, String title, String value, String sub, Color col) {
              return Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF13131C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 15, color: col),
                        const SizedBox(width: 6),
                        Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.white60), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white54), overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            }

            return Scaffold(
              backgroundColor: const Color(0xFF08080C),
              appBar: AppBar(
                backgroundColor: const Color(0xFF08080C),
                title: const Text('Listening & Library Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111119),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, color: accent, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Interactive Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                            Text('${_songs.length} ${_songs.length == 1 ? 'Track' : 'Tracks'}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final tab in [(0, 'Listening Share'), (1, 'Audio Quality'), (2, 'Library Artists'), (3, 'Release Eras')])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(tab.$2, style: const TextStyle(fontSize: 11)),
                                    selected: detailTab == tab.$1,
                                    selectedColor: accent,
                                    onSelected: (_) => setStatsState(() {
                                      detailTab = tab.$1;
                                      selectedSlice = -1;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 205,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTapUp: (details) {
                                  const boxSize = 185.0;
                                  final dx = details.localPosition.dx - boxSize / 2;
                                  final dy = details.localPosition.dy - boxSize / 2;
                                  double angle = math.atan2(dy, dx) + math.pi / 2;
                                  if (angle < 0) angle += 2 * math.pi;
                                  if (totalSliceVal > 0) {
                                    double acc = 0;
                                    for (int i = 0; i < slices.length; i++) {
                                      final sw = (slices[i].value / totalSliceVal) * 2 * math.pi;
                                      if (angle >= acc && angle <= acc + sw) {
                                        setStatsState(() => selectedSlice = (selectedSlice == i) ? -1 : i);
                                        break;
                                      }
                                      acc += sw;
                                    }
                                  }
                                },
                                child: SizedBox(
                                  width: 185,
                                  height: 185,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                        size: const Size(185, 185),
                                        painter: _NamiPieChartPainter(slices: slices, selectedIndex: selectedSlice),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            activeSlice != null ? '${activeSlice.value.toInt()}' : centerTop,
                                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          Text(
                                            activeSlice != null ? activeSlice.label : centerSub,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 10, color: Colors.white60),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int i = 0; i < slices.length; i++)
                                      if (slices[i].value > 0)
                                        InkWell(
                                          onTap: () => setStatsState(() => selectedSlice = (selectedSlice == i) ? -1 : i),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Container(width: 10, height: 10, decoration: BoxDecoration(color: slices[i].color, shape: BoxShape.circle)),
                                                const SizedBox(width: 7),
                                                Expanded(
                                                  child: Text(
                                                    slices[i].label,
                                                    style: TextStyle(fontSize: 11, fontWeight: selectedSlice == i ? FontWeight.bold : FontWeight.normal, color: Colors.white),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  '${slices[i].value.toInt()} (${totalSliceVal > 0 ? ((slices[i].value * 100) / totalSliceVal).round() : 0}%)',
                                                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111119),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, color: accent, size: 19),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Listening Activity Cadence • ${_computeListeningStreakDays()}d Streak', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                            Text('${listenHours}h ${listenMins}m total', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 115,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _NamiActivityBarChartPainter(
                              values: _timestampedPlayEvents.isNotEmpty ? _computeLast7DaysMinutes() : recentPlayBars,
                              labels: _timestampedPlayEvents.isNotEmpty ? const ['D-6', 'D-5', 'D-4', 'D-3', 'D-2', 'Yest', 'Today'] : const ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'],
                              accentColor: accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('28-Day Listening Heatmap', style: TextStyle(fontSize: 11.5, color: Colors.white60, fontWeight: FontWeight.w600)),
                            Text('${_timestampedPlayEvents.length} logged sessions', style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Builder(builder: (_) {
                          final heat = _compute28DayHeatmapCounts();
                          final maxH = heat.fold<int>(1, (m, v) => v > m ? v : m);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 28,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 14,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            itemBuilder: (_, idx) {
                              final cnt = heat[idx];
                              final alpha = cnt == 0 ? 0.08 : (0.25 + 0.75 * (cnt / maxH)).clamp(0.25, 1.0);
                              return Container(
                                decoration: BoxDecoration(
                                  color: cnt == 0 ? Colors.white.withValues(alpha: 0.07) : accent.withValues(alpha: alpha),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.65,
                    children: [
                      heavyCard(Icons.headphones_rounded, 'Total Listen Time', '${listenHours}h ${listenMins}m', '${_historyTracks.length} session plays', const Color(0xFFFFB300)),
                      heavyCard(Icons.explore_rounded, 'Library Explored', '$discoveryRatio%', '${playedTrackCounts.length} of ${_songs.length} ${_songs.length == 1 ? 'track' : 'tracks'} heard', const Color(0xFF00ACC1)),
                      heavyCard(Icons.timer_outlined, 'Avg Session Length', '${avgSessionSec ~/ 60}m ${(avgSessionSec % 60).toString().padLeft(2, '0')}s', 'Per track playback', const Color(0xFF43A047)),
                      heavyCard(Icons.graphic_eq_rounded, 'Hi-Res vs CD Plays', '$hiResPlays Hi-Res', '$cdPlays CD • $lossyPlays Lossy plays', accent),
                      heavyCard(Icons.sd_storage_rounded, 'Library Footprint', '${totalGb.toStringAsFixed(2)} GB', '$avgBitrateKbps kbps average', const Color(0xFF8E24AA)),
                      heavyCard(Icons.schedule_rounded, 'Catalog Runtime', '${totalLibHours}h ${totalLibMins}m', '${albumSet.length} Albums • ${artistTrackCounts.length} Artists', const Color(0xFF00ACC1)),
                      heavyCard(Icons.verified_rounded, 'Lossless Purity', '$losslessPct%', '${flac24Count + flac16Count + alacWavCount} lossless files', const Color(0xFF43A047)),
                      heavyCard(Icons.favorite_rounded, 'Liked & Queued', '$favCount Liked', '${_playNextQueue.length} in Play Next', accent),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111119),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topPlayedArtists.isNotEmpty ? 'Most Played Artists' : 'Top Library Artists',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        for (final entry in (topPlayedArtists.isNotEmpty ? topPlayedArtists : topLibArtists).take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                    Text(
                                      topPlayedArtists.isNotEmpty
                                          ? '${entry.value} plays • ${(playedArtistMs[entry.key] ?? 0) ~/ 60000}m'
                                          : '${entry.value} tracks',
                                      style: const TextStyle(fontSize: 11, color: Colors.white60),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: entry.value / (topPlayedArtists.isNotEmpty ? topPlayedArtists.first.value : topLibArtists.first.value),
                                    minHeight: 6,
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (topPlayedTracks.isNotEmpty) ...[
                          const Divider(color: Colors.white12, height: 20),
                          const Text('Most Replayed Tracks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          for (final tEntry in topPlayedTracks.take(5))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 16, color: accent),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(playedTrackTitles[tEntry.key] ?? 'Track', style: const TextStyle(fontSize: 12, color: Colors.white), overflow: TextOverflow.ellipsis)),
                                  Text('${tEntry.value}x', style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Most Played Tracks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...mostPlayedSongs.take(15).map((song) => _buildNamiTrackTile(song)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }



  bool _autoDacExclusiveProfile = true;
  String _queueSearchQuery = '';

  String _shiftLrcTimestamps(String rawLrc, double offsetSeconds) {
    if (offsetSeconds.abs() < 0.001) return rawLrc;
    final lineReg = RegExp(r'\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\]');
    return rawLrc.split('\n').map((line) {
      return line.replaceAllMapped(lineReg, (m) {
        final mins = int.tryParse(m.group(1)!) ?? 0;
        final secs = int.tryParse(m.group(2)!) ?? 0;
        final msStr = (m.group(3) ?? '0').padRight(3, '0').substring(0, 3);
        final ms = int.tryParse(msStr) ?? 0;
        final origMs = (mins * 60000) + (secs * 1000) + ms;
        final shiftedMs = math.max(0, origMs + (offsetSeconds * 1000).round());
        final nMin = (shiftedMs ~/ 60000).toString().padLeft(2, '0');
        final nSec = ((shiftedMs % 60000) ~/ 1000).toString().padLeft(2, '0');
        final nHundredths = ((shiftedMs % 1000) ~/ 10).toString().padLeft(2, '0');
        return '[$nMin:$nSec.$nHundredths]';
      });
    }).join('\n');
  }

  Future<void> _fetchMissingCoversBatch() async {
    final missing = _songs
        .where((s) => s.albumArt == null || s.artist == 'Unknown Artist' || s.album == 'Unknown Album')
        .toList();
    if (missing.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All tracks already have cover art & metadata!')),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetching metadata & covers for ${missing.length} unmatched track(s)...')),
      );
    }
    final thumbDir = await _ensureThumbDir();
    int updated = 0;
    for (final s in missing) {
      s.isOnlineEnriched = false;
      await _enrichTrackOnlineIfMissing(s, thumbDir, force: true);
      if (s.albumArt != null || s.artist != 'Unknown Artist') updated++;
      if (updated % 4 == 0 && mounted) {
        _artworkTick.value++;
        setState(() {});
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _artworkTick.value++;
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated $updated of ${missing.length} unmatched tracks!')),
      );
    }
    await _saveStateCache();
  }

int _crossfadeSeconds = 0;
  final List<String> _excludedFolders = [];
  final List<Map<String, dynamic>> _timestampedPlayEvents = [];

  Future<void> _loadNamiV12Prefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _crossfadeSeconds = prefs.getInt('nami_crossfade_sec_v1') ?? 0;
      final ex = prefs.getStringList('nami_excluded_folders_v1');
      if (ex != null) {
        _excludedFolders
          ..clear()
          ..addAll(ex);
      }
      final rawEvents = prefs.getString('nami_timestamped_play_events_v1');
      if (rawEvents != null && rawEvents.isNotEmpty) {
        final decoded = jsonDecode(rawEvents);
        if (decoded is List) {
          _timestampedPlayEvents
            ..clear()
            ..addAll(decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        }
      }
      _applyExcludedFoldersFilter();
    } catch (_) {}
  }

  Future<void> _saveNamiV12Prefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('nami_crossfade_sec_v1', _crossfadeSeconds);
      await prefs.setStringList('nami_excluded_folders_v1', _excludedFolders);
      final trimmed = _timestampedPlayEvents.length > 500
          ? _timestampedPlayEvents.sublist(_timestampedPlayEvents.length - 500)
          : _timestampedPlayEvents;
      await prefs.setString('nami_timestamped_play_events_v1', jsonEncode(trimmed));
    } catch (_) {}
  }

  void _recordTimestampedPlayEvent(AudioTrack track) {
    _timestampedPlayEvents.add({
      'path': track.path,
      'title': track.title,
      'artist': track.artist,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
      'durationSec': track.duration.inSeconds,
    });
    _saveNamiV12Prefs();
  }

  bool _isPathExcluded(String path) {
    final p = path.toLowerCase();
    for (final ex in _excludedFolders) {
      final e = ex.toLowerCase().trim();
      if (e.isNotEmpty && (p == e || p.startsWith('$e/'))) return true;
    }
    return false;
  }

  void _applyExcludedFoldersFilter() {
    if (_excludedFolders.isEmpty) return;
    _songs.removeWhere((s) => _isPathExcluded(s.path));
    _filteredSongs.removeWhere((s) => _isPathExcluded(s.path));
  }

  int _computeListeningStreakDays() {
    if (_timestampedPlayEvents.isEmpty) return 0;
    final dayKeys = <String>{};
    for (final ev in _timestampedPlayEvents) {
      final ts = ev['timestampMs'];
      if (ts is int && ts > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        dayKeys.add('${dt.year}-${dt.month}-${dt.day}');
      }
    }
    int streak = 0;
    DateTime cursor = DateTime.now();
    while (true) {
      final key = '${cursor.year}-${cursor.month}-${cursor.day}';
      if (dayKeys.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (streak == 0) {
        // Allow streak to start from yesterday if user hasn't played yet today
        final yest = cursor.subtract(const Duration(days: 1));
        final yKey = '${yest.year}-${yest.month}-${yest.day}';
        if (dayKeys.contains(yKey)) {
          cursor = yest;
          continue;
        }
        break;
      } else {
        break;
      }
    }
    return streak;
  }

  List<double> _computeLast7DaysMinutes() {
    final out = List<double>.filled(7, 0.0);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    for (final ev in _timestampedPlayEvents) {
      final ts = ev['timestampMs'];
      final dur = ev['durationSec'];
      if (ts is int && ts > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final evDay = DateTime(dt.year, dt.month, dt.day);
        final diffDays = todayStart.difference(evDay).inDays;
        if (diffDays >= 0 && diffDays < 7) {
          final idx = 6 - diffDays;
          final mins = (dur is int && dur > 0) ? (dur / 60.0) : 3.2;
          out[idx] += mins;
        }
      }
    }
    return out;
  }

  List<int> _compute28DayHeatmapCounts() {
    final out = List<int>.filled(28, 0);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    for (final ev in _timestampedPlayEvents) {
      final ts = ev['timestampMs'];
      if (ts is int && ts > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        final evDay = DateTime(dt.year, dt.month, dt.day);
        final diffDays = todayStart.difference(evDay).inDays;
        if (diffDays >= 0 && diffDays < 28) {
          out[27 - diffDays]++;
        }
      }
    }
    return out;
  }

  void _openGenresBrowserScreen() {
    final accent = Theme.of(context).colorScheme.primary;
    final genreMap = <String, List<AudioTrack>>{};
    for (final s in _songs) {
      final raw = s.genre.trim();
      final g = raw.isEmpty ? 'Uncategorized' : raw;
      genreMap.putIfAbsent(g, () => []).add(s);
    }
    final sortedGenres = genreMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF08080C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF08080C),
            title: Text('Genres (${sortedGenres.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          body: sortedGenres.isEmpty
              ? const Center(child: Text('No genres found in library', style: TextStyle(color: Colors.white54)))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: sortedGenres.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final entry = sortedGenres[i];
                    final tracks = entry.value;
                    final artists = tracks.map((t) => t.artist).toSet().length;
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF13131C),
                      leading: CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.18),
                        child: Icon(Icons.category_rounded, color: accent, size: 20),
                      ),
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text('${tracks.length} ${tracks.length == 1 ? 'track' : 'tracks'} • $artists artists', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                      onTap: () => _showFilteredListScreen(entry.key, tracks),
                    );
                  },
                ),
        ),
      ),
    );
  }



  final NamiDualDeckCrossfade _crossfadeEngine = NamiDualDeckCrossfade();
  final List<StreamSubscription<FileSystemEvent>> _folderWatchSubs = [];
  Timer? _folderWatchDebounce;

  void _startReactiveFolderWatchers() {
    _stopReactiveFolderWatchers();
    for (final dirPath in _scanFolders) {
      try {
        final d = Directory(dirPath);
        if (d.existsSync()) {
          final sub = d.watch(recursive: true).listen((event) {
            final l = event.path.toLowerCase();
            if (l.endsWith('.flac') ||
                l.endsWith('.mp3') ||
                l.endsWith('.m4a') ||
                l.endsWith('.wav') ||
                l.endsWith('.ogg')) {
              _folderWatchDebounce?.cancel();
              _folderWatchDebounce = Timer(const Duration(seconds: 2), () {
                if (mounted && !_isScanning) {
                  _fastScanDeviceMusic(forceReparse: false);
                }
              });
            }
          }, onError: (_) {});
          _folderWatchSubs.add(sub);
        }
      } catch (_) {}
    }
  }

  void _stopReactiveFolderWatchers() {
    _folderWatchDebounce?.cancel();
    for (final s in _folderWatchSubs) {
      s.cancel();
    }
    _folderWatchSubs.clear();
  }

void _showListenBrainzSettingsDialog() {
    final tokenCtrl = TextEditingController(text: NamiScrobbleService.instance.token);
    bool lbEnabled = NamiScrobbleService.instance.enabled;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLbState) => AlertDialog(
          backgroundColor: const Color(0xFF14141F),
          title: const Text('ListenBrainz Scrobbling', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Auto-Scrobbling', style: TextStyle(fontSize: 13.5)),
                subtitle: Text(
                  '${NamiScrobbleService.instance.totalScrobbled} scrobbled • ${NamiScrobbleService.instance.pendingQueue.length} pending offline',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                value: lbEnabled,
                activeThumbColor: Theme.of(ctx).colorScheme.primary,
                onChanged: (v) => setLbState(() => lbEnabled = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tokenCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'ListenBrainz User Token',
                  hintText: 'Paste token from listenbrainz.org/settings',
                  border: OutlineInputBorder(),
                ),
              ),
              if (NamiScrobbleService.instance.pendingQueue.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text('Sync ${NamiScrobbleService.instance.pendingQueue.length} Offline Scrobbles'),
                  onPressed: () async {
                    final synced = await NamiScrobbleService.instance.flushPending();
                    if (ctx.mounted) {
                      setLbState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(synced > 0 ? 'Synced $synced scrobbles!' : 'Sync failed — check token or internet')),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary),
              onPressed: () async {
                await NamiScrobbleService.instance.saveConfig(
                  userToken: tokenCtrl.text,
                  isEnabled: lbEnabled,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lbEnabled ? 'ListenBrainz scrobbling enabled!' : 'ListenBrainz scrobbling paused')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }



  final Map<String, MornyePingResult> _mornyePingResults = {};

  bool _isTrackInLocalLibrary(String title, String artist) {
    final nt = _normName(title);
    final na = _normName(artist);
    for (final s in _songs) {
      if (_namesMatchLoosely(_normName(s.title), nt) &&
          (na.isEmpty || _artistNamesMatch(_normName(s.artist), na))) {
        return true;
      }
    }
    return false;
  }

  List<AudioTrack> _evaluateSmartRulePlaylist(NamiSmartRulePlaylist rule) {
    final cutoffMs = rule.addedWithinDays > 0
        ? DateTime.now().subtract(Duration(days: rule.addedWithinDays)).millisecondsSinceEpoch
        : 0;
    final genreQ = rule.genreContains.trim().toLowerCase();
    final excl = rule.excludeArtists
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    return _songs.where((s) {
      final pLow = s.path.toLowerCase();
      if (rule.formatFilter == 'FLAC' && !pLow.endsWith('.flac')) return false;
      if (rule.formatFilter == '24B' && !(s.bitDepth >= 24 || s.sampleRateHz > 48000)) return false;
      if (rule.formatFilter == 'Lossless' &&
          !(pLow.endsWith('.flac') || pLow.endsWith('.alac') || pLow.endsWith('.wav') || pLow.endsWith('.aiff'))) {
        return false;
      }
      if (genreQ.isNotEmpty && !s.genre.toLowerCase().contains(genreQ)) return false;
      if (cutoffMs > 0 && s.addedTimestampMs < cutoffMs) return false;
      if (rule.maxPlayCount >= 0 && s.playCount > rule.maxPlayCount) return false;
      if (excl.isNotEmpty) {
        final aLow = s.artist.toLowerCase();
        for (final ex in excl) {
          if (aLow.contains(ex)) return false;
        }
      }
      return true;
    }).toList();
  }

  void _applySortToFilteredSongs() {
    final prefs = NamiV16Prefs.instance;
    final mul = prefs.trackSortAsc ? 1 : -1;
    _filteredSongs.sort((a, b) {
      int cmp;
      switch (prefs.trackSortBy) {
        case 'artist':
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          break;
        case 'album':
          cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());
          break;
        case 'added':
          cmp = a.addedTimestampMs.compareTo(b.addedTimestampMs);
          break;
        case 'year':
          cmp = a.year.compareTo(b.year);
          break;
        case 'quality':
          final qa = a.bitDepth * 1000000 + a.sampleRateHz + a.bitrateKbps;
          final qb = b.bitDepth * 1000000 + b.sampleRateHz + b.bitrateKbps;
          cmp = qa.compareTo(qb);
          break;
        case 'duration':
          cmp = a.duration.inSeconds.compareTo(b.duration.inSeconds);
          break;
        default:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      return cmp * mul;
    });
  }

  Set<String> _computeDuplicateTrackPaths() {
    final groups = <String, List<AudioTrack>>{};
    for (final s in _songs) {
      final key = '${_normName(s.title)}__${_normName(s.artist.split(RegExp(r"[,&/;]|feat\.|ft\.", caseSensitive: false)).first)}';
      if (key.length > 3) {
        groups.putIfAbsent(key, () => []).add(s);
      }
    }
    final dupPaths = <String>{};
    for (final g in groups.values) {
      if (g.length > 1) {
        for (final t in g) {
          dupPaths.add(t.path);
        }
      }
    }
    return dupPaths;
  }

  void _showTrackSortSheet() {
    final prefs = NamiV16Prefs.instance;
    const options = [
      ('title', 'Title (A–Z)', Icons.sort_by_alpha_rounded),
      ('artist', 'Artist', Icons.person_rounded),
      ('album', 'Album', Icons.album_rounded),
      ('added', 'Date Added', Icons.schedule_rounded),
      ('year', 'Release Year', Icons.calendar_today_rounded),
      ('quality', 'Bit-Depth & Sample Rate', Icons.high_quality_rounded),
      ('duration', 'Duration', Icons.timer_outlined),
    ];
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sort & Order Tracks', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Asc', style: TextStyle(fontSize: 11.5))),
                          ButtonSegment(value: false, label: Text('Desc', style: TextStyle(fontSize: 11.5))),
                        ],
                        selected: {prefs.trackSortAsc},
                        onSelectionChanged: (val) {
                          setSheet(() => prefs.trackSortAsc = val.first);
                          prefs.save();
                          setState(_applySortToFilteredSongs);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final opt in options)
                    ListTile(
                      dense: true,
                      leading: Icon(opt.$3, color: prefs.trackSortBy == opt.$1 ? accent : Colors.white54, size: 20),
                      title: Text(
                        opt.$2,
                        style: TextStyle(
                          fontWeight: prefs.trackSortBy == opt.$1 ? FontWeight.w800 : FontWeight.w500,
                          color: prefs.trackSortBy == opt.$1 ? accent : Colors.white,
                        ),
                      ),
                      trailing: prefs.trackSortBy == opt.$1 ? Icon(Icons.check_rounded, color: accent) : null,
                      onTap: () {
                        setSheet(() => prefs.trackSortBy = opt.$1);
                        prefs.save();
                        setState(_applySortToFilteredSongs);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBatchTagEditorSheet(List<AudioTrack> batch) {
    if (batch.isEmpty) return;
    final artistCtrl = TextEditingController();
    final albumCtrl = TextEditingController();
    final genreCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    String? pickedCoverPath;

    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBState) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batch Edit ${batch.length} ${batch.length == 1 ? 'Track' : 'Tracks'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Leave fields blank to keep existing values. Writes directly to FLAC/MP3 files.', style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                  const SizedBox(height: 12),
                  _buildRichInputField(artistCtrl, 'Artist (optional)'),
                  const SizedBox(height: 8),
                  _buildRichInputField(albumCtrl, 'Album (optional)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildRichInputField(genreCtrl, 'Genre')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildRichInputField(yearCtrl, 'Year')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(pickedCoverPath == null ? 'Pick Shared Album Cover (Gallery)' : 'Cover Selected: ${pickedCoverPath!.split('/').last}'),
                    onPressed: () async {
                      final p = await _pickPhotoDirectlyFromGallery(ctx, title: 'Batch Cover Artwork');
                      if (p != null && p.isNotEmpty) setBState(() => pickedCoverPath = p);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                        onPressed: () async {
                          Uint8List? sharedCover;
                          if (pickedCoverPath != null && File(pickedCoverPath!).existsSync()) {
                            sharedCover = await File(pickedCoverPath!).readAsBytes();
                          }
                          final thumbDir = await _ensureThumbDir();
                          int writtenFiles = 0;
                          for (final s in batch) {
                            if (artistCtrl.text.trim().isNotEmpty) s.artist = artistCtrl.text.trim();
                            if (albumCtrl.text.trim().isNotEmpty) s.album = albumCtrl.text.trim();
                            if (genreCtrl.text.trim().isNotEmpty) s.genre = genreCtrl.text.trim();
                            if (yearCtrl.text.trim().isNotEmpty) s.year = yearCtrl.text.trim();
                            if (sharedCover != null) {
                              final tf = File('${thumbDir.path}/${_deterministicPathHash(s.path)}.jpg');
                              await tf.writeAsBytes(sharedCover);
                              await FileImage(tf).evict();
                              s.thumbPath = tf.path;
                              s.albumArt = null;
                            }
                            final ok = await NamiTagWriter.writeTagsToFile(
                              path: s.path,
                              title: s.title,
                              artist: s.artist,
                              album: s.album,
                              genre: s.genre,
                              year: s.year,
                              lyrics: s.rawLyrics,
                              coverBytes: sharedCover,
                            );
                            if (ok) writtenFiles++;
                          }
                          _artworkTick.value++;
                          if (ctx.mounted) Navigator.pop(ctx);
                          _exitSelectionMode();
                          _saveStateCache();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Updated ${batch.length} ${batch.length == 1 ? 'track' : 'tracks'} ($writtenFiles written to disk)!')),
                            );
                          }
                        },
                        child: const Text('Apply to All', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showHomeQuickActionSheet({
    AudioTrack? track,
    String? albumName,
    List<AudioTrack>? albumTracks,
    String? artistName,
    List<AudioTrack>? artistTracks,
  }) {
    if (albumName != null && track == null) {
      /* v20_floating_album_artist */
      final list = albumTracks ?? _songs.where((s) => s.album == albumName).toList();
      showNamiFloatingActionSheet(
        context: context,
        title: albumName,
        subtitle: '${list.length} ${list.length == 1 ? 'Track' : 'Tracks'}',
        leading: list.isNotEmpty ? _buildCoverArt(list.first, 44, 10) : null,
        actions: [
          NamiFloatingActionItem(
            icon: Icons.album_rounded,
            title: 'Open Album',
            onTap: () => _showAlbumDetailScreen(albumName, list),
          ),
          NamiFloatingActionItem(
            icon: Icons.drive_file_rename_outline_rounded,
            title: 'Rename Album',
            subtitle: 'Change album name across all tracks',
            onTap: () => _renameAlbumEverywhere(albumName),
          ),
        ],
        footerLeftLabel: 'Play All',
        footerLeftIcon: Icons.play_arrow_rounded,
        onFooterLeftTap: () {
          if (list.isNotEmpty) _playSong(list.first);
        },
        footerRightLabel: 'Shuffle',
        footerRightIcon: Icons.shuffle_rounded,
        onFooterRightTap: () {
          if (list.isNotEmpty) {
            final shuf = List<AudioTrack>.from(list)..shuffle();
            _playSong(shuf.first);
          }
        },
      );
      return;
    }
    if (artistName != null && track == null) {
      final list = artistTracks ?? _songs.where((s) => s.artist.toLowerCase().contains(artistName.toLowerCase())).toList();
      final imgPath = _artistImagePaths[artistName];
      final hasImg = imgPath != null && File(imgPath).existsSync();
      showNamiFloatingActionSheet(
        context: context,
        title: artistName,
        subtitle: '${list.length} ${list.length == 1 ? 'Track' : 'Tracks'}',
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white10,
          backgroundImage: hasImg ? FileImage(File(imgPath)) : null,
          child: hasImg ? null : const Icon(Icons.person_rounded, color: Colors.white70),
        ),
        actions: [
          NamiFloatingActionItem(
            icon: Icons.person_rounded,
            title: 'Open Artist',
            onTap: () => _showArtistDetailScreen(artistName, list),
          ),
          NamiFloatingActionItem(
            icon: Icons.drive_file_rename_outline_rounded,
            title: 'Rename Artist',
            subtitle: 'Change artist name across all tracks',
            onTap: () => _renameArtistEverywhere(artistName),
          ),
          NamiFloatingActionItem(
            icon: Icons.auto_fix_high_rounded,
            title: 'Choose Artist Photo Online',
            subtitle: 'Pick from JioSaavn IN, Apple Music IN & Spotify',
            onTap: () {
              NamiArtistMetadataService.invalidate(artistName);
              _openArtistPhotoOnlinePicker(artistName, tracks: list);
            },
          ),
        ],
        footerLeftLabel: 'Play All',
        footerLeftIcon: Icons.play_arrow_rounded,
        onFooterLeftTap: () {
          if (list.isNotEmpty) _playSong(list.first);
        },
        footerRightLabel: 'Shuffle',
        footerRightIcon: Icons.shuffle_rounded,
        onFooterRightTap: () {
          if (list.isNotEmpty) {
            final shuf = List<AudioTrack>.from(list)..shuffle();
            _playSong(shuf.first);
          }
        },
      );
      return;
    }
    if (track != null && albumName == null && artistName == null) {
      showNamiTrackActionCard(
        context: context,
        track: track,
      onFetchCoverOnline: () => _openTrackCoverOnlinePicker(track),
        coverArt: _buildCoverArt(track, 50, 12),
        formatBadgeText: '${track.path.split('.').last.toUpperCase()} ${track.bitDepth > 0 ? '${track.bitDepth}B' : ''}'.trim(),
        isFavorite: false,
        onToggleFavorite: () => setState(() {}),
        onPlayNext: () => setState(() => _playNextQueue.insert(0, track)),
        onPlayLast: () => setState(() => _playNextQueue.add(track)),
        onAddToPlaylist: () => _showAddToPlaylistDialog(track),
        onGoToAlbum: () {
          final albTracks = _songs.where((s) => s.album == track.album).toList();
          _showAlbumDetailScreen(track.album, albTracks);
        },
        onGoToArtist: (artist) => _openArtistByName(artist),
        onEditTags: () => _showTagEditorDialog(track),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (track != null) ...[
                ListTile(
                  leading: _buildCoverArt(track, 44, 8),
                  title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(cleanArtistStr(track.artist), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.playlist_play_rounded),
                  title: const Text('Play Next'),
                  onTap: () {
                    setState(() => _playNextQueue.insert(0, track));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playing "${track.title}" next')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Add to Queue'),
                  onTap: () {
                    setState(() => _playNextQueue.add(track));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "${track.title}" to queue')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: const Text('Go to Artist'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _buildArtistGroupsMap();
                    final p = NamiV16Prefs.instance.resolveCanonicalArtist(
                      track.artist.split(RegExp(_artistSeparators.map(RegExp.escape).join('|'), caseSensitive: false)).first,
                    );
                    _openArtistOrPicker(track.artist);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.album_rounded),
                  title: const Text('Go to Album'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAlbumDetailScreen(track.album, _songs.where((s) => s.album == track.album).toList());
                  },
                ),
              ] else if (albumName != null && albumTracks != null) ...[
                ListTile(
                  leading: const Icon(Icons.album_rounded),
                  title: Text(albumName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${albumTracks.length} ${albumTracks.length == 1 ? 'Track' : 'Tracks'}'),
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.shuffle_rounded),
                  title: const Text('Shuffle Album'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final sh = List<AudioTrack>.from(albumTracks)..shuffle();
                    if (sh.isNotEmpty) _playSong(sh.first);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_play_rounded),
                  title: const Text('Play Album Next'),
                  onTap: () {
                    setState(() => _playNextQueue.insertAll(0, albumTracks));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queued $albumName')));
                  },
                ),
              ] else if (artistName != null && artistTracks != null) ...[
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text(artistName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${artistTracks.length} ${artistTracks.length == 1 ? 'Track' : 'Tracks'}'),
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.shuffle_rounded),
                  title: const Text('Shuffle Artist'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final sh = List<AudioTrack>.from(artistTracks)..shuffle();
                    if (sh.isNotEmpty) _playSong(sh.first);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: const Text('Add All to Queue'),
                  onTap: () {
                    setState(() => _playNextQueue.addAll(artistTracks));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queued ${artistTracks.length} ${artistTracks.length == 1 ? 'track' : 'tracks'} by $artistName')));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

void _showLiveOutputProfileSheet() {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setOState) {
          final cur = _currentSong;
          final rateStr = cur != null ? '${cur.bitDepth}B • ${(cur.sampleRateHz / 1000.0).toStringAsFixed(1)}kHz' : '24B • Ready';
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_isExternalAudioConnected ? Icons.usb_rounded : Icons.headphones_rounded, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_connectedDacName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('$_connectedDacType • $rateStr', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Bit-Perfect Bypass', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          selected: !_eqEnabled,
                          selectedColor: accent,
                          onSelected: (_) async {
                            setOState(() {
                              _eqEnabled = false;
                              _usbDacExclusive = true;
                              _replayGainMode = 'Off';
                              _replayGain = false;
                            });
                            NamiV16Prefs.instance.audioModePreset = 'bit_perfect';
                            await NamiV16Prefs.instance.save();
                            await _applyDacAndAudioProperties();
                            await _applyHardwareEqGains();
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('AutoEQ ($_selectedEqPreset)', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
                          selected: _eqEnabled,
                          selectedColor: accent,
                          onSelected: (_) async {
                            setOState(() => _eqEnabled = true);
                            NamiV16Prefs.instance.audioModePreset = 'tuned';
                            await NamiV16Prefs.instance.save();
                            await _applyHardwareEqGains();
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cur != null)
                        TextButton.icon(
                          icon: const Icon(Icons.route_rounded, size: 17),
                          label: const Text('Audio Path'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAudioPathDetails(cur);
                          },
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: const Text('Open 10-Band EQ'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEqualizerSheet();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showArtistAliasMergeDialog({String? prefillAlias}) {
    final aliasCtrl = TextEditingController(text: prefillAlias ?? '');
    final targetCtrl = TextEditingController();
    final prefs = NamiV16Prefs.instance;

    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setAState) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Artist Alias & Merge Tool', style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Merge duplicate artist spellings (e.g. Kr\$Na -> KR\$NA) under one profile.', style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                  const SizedBox(height: 12),
                  _buildRichInputField(aliasCtrl, 'Duplicate / Alias Spelling (e.g. Kr\$Na)'),
                  const SizedBox(height: 8),
                  _buildRichInputField(targetCtrl, 'Merge Into Canonical Name (e.g. KR\$NA)'),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                      icon: const Icon(Icons.merge_type_rounded, size: 18),
                      label: const Text('Merge Artist'),
                      onPressed: () async {
                        final a = aliasCtrl.text.trim();
                        final t = targetCtrl.text.trim();
                        if (a.isNotEmpty && t.isNotEmpty && a.toLowerCase() != t.toLowerCase()) {
                          prefs.artistAliases[a.toLowerCase()] = t;
                          await prefs.save();
                          aliasCtrl.clear();
                          targetCtrl.clear();
                          setAState(() {});
                          setState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Merged "$a" into "$t"')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  if (prefs.artistAliases.isNotEmpty) ...[
                    const Divider(color: Colors.white12, height: 22),
                    const Text('Active Merges', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    for (final e in prefs.artistAliases.entries.toList())
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${e.key}  ->  ${e.value}', style: const TextStyle(fontSize: 12.5)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          onPressed: () async {
                            prefs.artistAliases.remove(e.key);
                            await prefs.save();
                            setAState(() {});
                            setState(() {});
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

Widget _buildPlaylistCollageArt(CustomPlaylist playlist, double size, double radius) {
    final customPath = NamiV16Prefs.instance.playlistCustomCovers[playlist.name];
    if (customPath != null && File(customPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(customPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 2.5).round().clamp(64, 256),
        ),
      );
    }
    final uniqueAlbumTracks = <AudioTrack>[];
    final seenAlbs = <String>{};
    for (final t in playlist.tracks) {
      if (seenAlbs.add(t.album.toLowerCase())) {
        uniqueAlbumTracks.add(t);
        if (uniqueAlbumTracks.length == 4) break;
      }
    }
    if (uniqueAlbumTracks.length >= 4) {
      final half = size / 2;
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Column(
            children: [
              Row(children: [_buildCoverArt(uniqueAlbumTracks[0], half, 0), _buildCoverArt(uniqueAlbumTracks[1], half, 0)]),
              Row(children: [_buildCoverArt(uniqueAlbumTracks[2], half, 0), _buildCoverArt(uniqueAlbumTracks[3], half, 0)]),
            ],
          ),
        ),
      );
    }
    if (uniqueAlbumTracks.isNotEmpty) {
      return _buildCoverArt(uniqueAlbumTracks.first, size, radius);
    }
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(radius)),
      child: Icon(Icons.queue_music_rounded, color: accent, size: size * 0.5),
    );
  }

  Future<void> _autoSyncPlaylistM3u8IfEnabled(CustomPlaylist playlist) async {
    if (!NamiV16Prefs.instance.autoSyncPlaylistsM3u8) return;
    try {
      final dir = Directory('/storage/emulated/0/Music/NamiPlaylists');
      if (!await dir.exists()) await dir.create(recursive: true);
      final safe = playlist.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final f = File('${dir.path}/$safe.m3u8');
      final buf = StringBuffer('#EXTM3U\n');
      for (final t in playlist.tracks) {
        buf.writeln('#EXTINF:${t.duration.inSeconds},${cleanArtistStr(t.artist)} - ${t.title}');
        buf.writeln(t.path);
      }
      await f.writeAsString(buf.toString());
    } catch (_) {}
  }

  Future<void> _queueMornyeStreamTrack(MornyeCatalogItem item) async {
    final fullUrl = await _resolveFullTrackUrlFromExtensions(item);
    final url = (fullUrl != null && fullUrl.isNotEmpty) ? fullUrl : item.previewUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No stream URL available for "${item.title}"')),
        );
      }
      return;
    }
    final streamTrack = AudioTrack(
      title: item.title,
      artist: item.artist,
      album: item.album,
      path: url,
      duration: Duration(seconds: item.durationSeconds > 0 ? item.durationSeconds : 30),
      bitDepth: fullUrl != null ? 24 : 16,
      sampleRateHz: fullUrl != null ? 96000 : 44100,
    );
    setState(() => _playNextQueue.insert(0, streamTrack));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Queued "${item.title}" (${fullUrl != null ? "Full Stream" : "Preview"}) in Play Next')),
      );
    }
  }

  void _openMornyeDrillDownScreen(MornyeCatalogItem headerItem) {
    final isAlbum = headerItem.type == 'Album';
    String selectedQuality = NamiV16Prefs.instance.mornyePreferredQuality;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDState) {
            final accent = Theme.of(ctx).colorScheme.primary;
            return Scaffold(
              backgroundColor: const Color(0xFF07070B),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: Text(headerItem.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              body: FutureBuilder<List<Map<String, dynamic>>>(
                future: isAlbum
                    ? NamiMornyeStore.fetchAlbumTracklist(
                        collectionId: headerItem.collectionId,
                        albumTitle: headerItem.title,
                        artistName: headerItem.artist,
                      )
                    : NamiMornyeStore.fetchArtistCatalog(headerItem.artist),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: accent));
                  }
                  final rows = snap.data ?? [];
                  final items = rows.map((r) => MornyeCatalogItem(
                        title: (r['trackName'] ?? 'Unknown').toString(),
                        artist: (r['artistName'] ?? headerItem.artist).toString(),
                        album: (r['collectionName'] ?? headerItem.album).toString(),
                        subtitle: '${r['trackNumber'] ?? ''} • $_selectedMornyeService',
                        type: 'Track',
                        service: _selectedMornyeService,
                        previewUrl: r['previewUrl']?.toString(),
                        artworkUrl: r['artworkUrl100']?.toString().replaceAll('100x100', '600x600') ?? headerItem.artworkUrl,
                        durationSeconds: ((r['trackTimeMillis'] ?? 210000) as int) ~/ 1000,
                        collectionId: r['collectionId']?.toString(),
                      )).toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12121B),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (headerItem.artworkUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(headerItem.artworkUrl!, width: 76, height: 76, fit: BoxFit.cover),
                                  )
                                else
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                                    child: Icon(isAlbum ? Icons.album_rounded : Icons.person_rounded, size: 36, color: Colors.white54),
                                  ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(headerItem.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 3),
                                      Text('${headerItem.artist} • ${items.length} ${items.length == 1 ? 'track' : 'tracks'}', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    children: ['24B FLAC', '16B FLAC', 'M4A'].map((q) => ChoiceChip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text(q, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                          selected: selectedQuality == q,
                                          selectedColor: accent,
                                          onSelected: (_) {
                                            setDState(() => selectedQuality = q);
                                            NamiV16Prefs.instance.mornyePreferredQuality = q;
                                            NamiV16Prefs.instance.save();
                                          },
                                        )).toList(),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                                  label: Text(isAlbum ? 'Download Album' : 'Download All', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  onPressed: items.isEmpty
                                      ? null
                                      : () async {
                                          for (final t in items) {
                                            await _downloadMornyeItem(t);
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final t in items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0E15),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                                if (_isTrackInLocalLibrary(t.title, t.artist))
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(Icons.check_circle_rounded, size: 15, color: Colors.greenAccent),
                                  ),
                              ],
                            ),
                            subtitle: Text('${t.artist} • ${_formatDurationPadded(Duration(seconds: t.durationSeconds))}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Queue Stream',
                                  icon: const Icon(Icons.playlist_add_rounded, size: 20, color: Colors.white70),
                                  onPressed: () => _queueMornyeStreamTrack(t),
                                ),
                                IconButton(
                                  tooltip: 'Download',
                                  icon: Icon(Icons.download_rounded, size: 20, color: accent),
                                  onPressed: () => _downloadMornyeItem(t),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

Future<void> _exportUnifiedNamiBackup() async {
    try {
      final outPath = await NamiV16Prefs.instance.writePortableBackup({
        'totalListenSeconds': _totalListenSeconds,
        'userName': _userName,
        'accentColor': NamiApp.of(context).accentColor.value,
        'eqBands': _eqBands,
        'selectedEqPreset': _selectedEqPreset,
        'excludedFolders': _excludedFolders,
        'artistImagePaths': _artistImagePaths,
        'favorites': _songs.where((s) => s.isFavorite).map((s) => s.path).toList(),
        'playlists': _customPlaylists.map((p) => p.toJson()).toList(),
        'extensions': _extensions.map((e) => {
              'name': e.name,
              'version': e.version,
              'author': e.author,
              'format': e.format,
              'category': e.category,
              'description': e.description,
              'endpointUrl': e.endpointUrl,
              'isInstalled': e.isInstalled,
            }).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unified backup saved to $outPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _importUnifiedNamiBackup() async {
    try {
      final map = await NamiV16Prefs.instance.readPortableBackup();
      if (map == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No .nami-backup or nami_backup.json found in /Download')),
          );
        }
        return;
      }
      final favPaths = Set<String>.from(map['favorites'] ?? []);
      for (final s in _songs) {
        if (favPaths.contains(s.path)) s.isFavorite = true;
      }
      if (map['eqBands'] is Map) {
        (map['eqBands'] as Map).forEach((k, v) {
          if (_eqBands.containsKey(k.toString()) && v is num) {
            _eqBands[k.toString()] = v.toDouble();
          }
        });
      }
      if (map['excludedFolders'] is List) {
        _excludedFolders
          ..clear()
          ..addAll(List<String>.from(map['excludedFolders']));
      }
      if (map['artistImagePaths'] is Map) {
        (map['artistImagePaths'] as Map).forEach((k, v) {
          if (v is String && File(v).existsSync()) {
            _artistImagePaths[k.toString()] = v;
          }
        });
      }
      if (map['accentColor'] is int && mounted) {
        NamiApp.of(context).updateTheme(newAccent: Color(map['accentColor'] as int));
      }
      setState(() => _applyExcludedFoldersFilter());
      await _applyHardwareEqGains();
      await _saveStateCache();
      await _saveNamiV12Prefs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored unified .nami-backup!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }



  void _showScopedTracksSearchSheet({
    required String scopeTitle,
    required List<AudioTrack> scopeTracks,
  }) {
    String q = '';
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSState) {
          final accent = Theme.of(ctx).colorScheme.primary;
          final query = q.trim().toLowerCase();
          final matches = query.isEmpty
              ? scopeTracks
              : scopeTracks.where((s) =>
                  s.title.toLowerCase().contains(query) ||
                  s.artist.toLowerCase().contains(query) ||
                  s.album.toLowerCase().contains(query)).toList();

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.78,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setSState(() => q = v),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search in $scopeTitle (${scopeTracks.length} songs)...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: accent, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF161622),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: matches.isEmpty
                      ? const Center(child: Text('No matching tracks found.', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                          itemCount: matches.length,
                          itemBuilder: (_, idx) {
                            final song = matches[idx];
                            return ListTile(
                              leading: _buildCoverArt(song, 44, 9),
                              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              subtitle: Text('${cleanArtistStr(song.artist)} • ${song.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                              trailing: _showCodecBadges ? _buildFormatPill(song, accent) : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                _playSong(song);
                              },
                              onLongPress: () => _showHomeQuickActionSheet(track: song),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailFloatingDock(
    BuildContext pageContext, {
    required String scopeTitle,
    required List<AudioTrack> scopeTracks,
  }) {
    /* v29_shell_compact_dock */
    if (NamiShellNavigator.hasSubPage.value) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(right: 12, bottom: _currentSong != null ? 78 : 12),
          child: Align(
            alignment: Alignment.bottomRight,
          child: NamiSpringTap(
            pressedScale: 0.90,
            onTap: () {
              _showScopedTracksSearchSheet(scopeTitle: scopeTitle, scopeTracks: scopeTracks);
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xEB12121A),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.50),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 23),
            ),
          ),
        ),
              ),
      );
    }
    final accent = Theme.of(pageContext).colorScheme.primary;
    return SafeArea(
      top: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -16,
            right: -16,
            top: -18,
            bottom: -18,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000), Color(0xF5000000)],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              // Left: Frosted Home circle button
              NamiSpringTap(
                pressedScale: 0.90,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedIndex = 0);
                  Navigator.of(pageContext).popUntil((route) => route.isFirst);
                },
                child: ClipOval(
                  child: NamiOptionalBlur(sigmaX: 16, sigmaY: 16,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xCC12121A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: Icon(Icons.home_rounded, color: accent, size: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Center: Frosted Pill Mini-Player with live 2px accent progress hairline
              Expanded(
                child: StreamBuilder<bool>(
                  stream: _audioPlayer.stream.playing,
                  builder: (_, playSnap) {
                    final song = _currentSong;
                    final isPlaying = playSnap.data ?? _audioPlayer.state.playing;
                    return NamiSpringMiniPlayerWrap(
                      trackKey: song?.path,
                      onOpenTap: () {
                        if (song != null) {
                          _openMorphNowPlaying(navContext: pageContext);
                        }
                      },
                      onStartDragOpen: (rect) {
                        if (song != null) {
                          _openMorphNowPlaying(
                            miniRect: rect,
                            startFromDrag: true,
                            navContext: pageContext,
                          );
                        }
                      },
                      onNext: () => _playNextTrack(),
                      onPrev: () => _playPrevTrack(),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: NamiOptionalBlur(sigmaX: 16, sigmaY: 16,
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xCC12121A),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                  child: Row(
                                    children: [
                                      if (song != null)
                                        _buildCoverArt(song, 40, 10)
                                      else
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                                          child: Icon(Icons.music_note_rounded, color: accent, size: 20),
                                        ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (song != null && isPlaying) ...[
                                                  NamiMiniEqBars(color: accent, isPlaying: true, size: 11),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    song?.title ?? 'Nothing Playing',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 13.8, fontWeight: FontWeight.w800, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              song != null ? cleanArtistStr(song.artist) : 'Tap a track to play',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                        icon: Icon(
                                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 27,
                                        ),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          if (song == null && scopeTracks.isNotEmpty) {
                                            _playSong(scopeTracks.first);
                                          } else if (song != null) {
                                            isPlaying ? _audioPlayer.pause() : _audioPlayer.play();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Live 2px accent progress hairline along bottom edge of pill
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 0,
                                  child: StreamBuilder<Duration>(
                                    stream: _audioPlayer.stream.position,
                                    builder: (_, posSnap) {
                                      final posMs = (posSnap.data ?? _audioPlayer.state.position).inMilliseconds;
                                      final durMs = _audioPlayer.state.duration.inMilliseconds;
                                      final frac = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: frac,
                                          minHeight: 2.0,
                                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                                          valueColor: AlwaysStoppedAnimation<Color>(accent.withValues(alpha: 0.92)),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Right: Frosted Scoped Search circle button
              NamiSpringTap(
                pressedScale: 0.90,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showScopedTracksSearchSheet(scopeTitle: scopeTitle, scopeTracks: scopeTracks);
                },
                child: ClipOval(
                  child: NamiOptionalBlur(sigmaX: 16, sigmaY: 16,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xCC12121A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.50), blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refreshArtistPhotoFromStreaming(String artistName, {VoidCallback? onUpdated}) async {
    NamiArtistMetadataService.invalidate(artistName);
    final url = await NamiArtistMetadataService.fetchBestArtistPhotoUrl(artistName, forceRefresh: true);
    if (url != null && url.isNotEmpty) {
      await _saveArtistImageFromUrlOrFile(artistName, url, onUpdated: onUpdated);
    }
  }


  void _openArtistByName(String artist) {
    final target = artist.trim().toLowerCase();
    final tracks = _songs.where((s) =>
      namiSplitArtists(s.artist).any((a) => a.toLowerCase() == target) ||
      s.artist.toLowerCase().contains(target)
    ).toList();
    _showArtistDetailScreen(artist, tracks);
  }

  void _openArtistOrPicker(String rawArtist) {
    showNamiArtistPickerOrNavigate(
      context: context,
      rawArtist: rawArtist,
      artistImagePaths: _artistImagePaths,
      onSelectArtist: (picked) => _openArtistByName(picked),
    );
  }

  void _openSettingsMergeArtistPicker() {
    final artistSet = <String>{};
    for (final s in _songs) {
      for (final a in namiSplitArtists(s.artist)) {
        if (a.isNotEmpty && a != 'Unknown Artist') artistSet.add(a);
      }
    }
    final artists = artistSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    showModalBottomSheet(
    sheetAnimationStyle: namiSmoothSheetStyle,
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E15),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.72,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 2, 18, 10),
              child: Row(
                children: [
                  Icon(Icons.merge_type_rounded, color: Colors.white70, size: 20),
                  SizedBox(width: 10),
                  Text('Select Artist to Merge / Alias', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: ListView.builder(
                itemCount: artists.length,
                itemBuilder: (_, i) {
                  final artist = artists[i];
                  return ListTile(
                    title: Text(artist, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openArtistByName(artist);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _renameArtistEverywhere(String oldName) async {
    final oldTrim = oldName.trim();
    final newName = await showNamiRenameDialog(
      context: context,
      title: 'Rename Artist',
      currentName: oldTrim,
      hintText: 'Enter new artist name',
    );
    if (newName == null || newName.isEmpty || newName == oldTrim) return null;

    final oldLower = oldTrim.toLowerCase();
    int updated = 0;
    for (final s in _songs) {
      final parts = namiSplitArtists(s.artist);
      if (parts.any((p) => p.toLowerCase() == oldLower)) {
        final replaced = parts.map((p) => p.toLowerCase() == oldLower ? newName : p).toList();
        s.artist = replaced.join(', ');
        updated++;
      } else if (s.artist.trim().toLowerCase() == oldLower) {
        s.artist = newName;
        updated++;
      }
    }

    if (_artistImagePaths.containsKey(oldTrim)) {
      final oldImg = _artistImagePaths.remove(oldTrim);
      if (oldImg != null) _artistImagePaths[newName] = oldImg;
    }
    NamiArtistMetadataService.invalidate(oldTrim);
    NamiArtistMetadataService.invalidate(newName);

    if (mounted) {
      setState(() {
        _artworkTick.value++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed artist to "$newName" ($updated tracks updated)')),
      );
    }
    _saveStateCache();
    return newName;
  }

  Future<String?> _renameAlbumEverywhere(String oldAlbum) async {
    final oldTrim = oldAlbum.trim();
    final newAlbum = await showNamiRenameDialog(
      context: context,
      title: 'Rename Album',
      currentName: oldTrim,
      hintText: 'Enter new album name',
    );
    if (newAlbum == null || newAlbum.isEmpty || newAlbum == oldTrim) return null;

    final oldLower = oldTrim.toLowerCase();
    int updated = 0;
    for (final s in _songs) {
      if (s.album.trim().toLowerCase() == oldLower) {
        s.album = newAlbum;
        updated++;
      }
    }

    if (mounted) {
      setState(() {
        _artworkTick.value++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed album to "$newAlbum" ($updated tracks updated)')),
      );
    }
    _saveStateCache();
    return newAlbum;
  }

  void _openTrackCoverOnlinePicker(AudioTrack track) {
    final initialQ = '${track.title} ${cleanArtistStr(track.artist)}'.trim();
    showNamiMediaImagePickerSheet(
      context: context,
      sheetTitle: 'Choose Cover: ${track.title}',
      initialQuery: initialQ,
      fetcher: (q) => NamiArtistMetadataService.fetchTrackCoverCandidates(q),
      onPicked: (cand) async {
        try {
          final res = await http.get(Uri.parse(cand.imageUrl), headers: _httpHeaders).timeout(const Duration(seconds: 12));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            final dir = await _ensureThumbDir();
            final safe = track.path.hashCode.abs().toString();
            final f = File('${dir.path}/custom_cover_$safe.jpg');
            await f.writeAsBytes(res.bodyBytes, flush: true);
            await FileImage(f).evict();
            track.thumbPath = f.path;
            if (mounted) {
              setState(() {
                _artworkTick.value++;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Updated cover art from ${cand.source}!')),
              );
            }
            _saveStateCache();
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to download selected cover art.')),
            );
          }
        }
      },
    );
  }

  void _openArtistPhotoOnlinePicker(String artistName, {List<AudioTrack>? tracks, VoidCallback? onUpdated}) {
    final sampleTitles = (tracks ?? const <AudioTrack>[]).take(3).map((t) => t.title).toList();
    showNamiMediaImagePickerSheet(
      context: context,
      sheetTitle: 'Choose Photo: $artistName',
      initialQuery: artistName,
      fetcher: (q) => NamiArtistMetadataService.fetchArtistPhotoCandidates(q, sampleTracks: sampleTitles),
      onPicked: (cand) async {
        await _saveArtistImageFromUrlOrFile(artistName, cand.imageUrl, onUpdated: onUpdated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated $artistName photo from ${cand.source}!')),
          );
        }
      },
    );
  }

  Future<void> _purgeBadArtistPlaceholders() async {
    int removed = 0;
    final keysToRemove = <String>[];
    for (final entry in _artistImagePaths.entries) {
      final f = File(entry.value);
      if (!f.existsSync()) {
        keysToRemove.add(entry.key);
        continue;
      }
      final len = await f.length();
      // Deezer white-mic & broken icon placeholders are tiny (< 4.8KB) or empty
      if (len < 4800) {
        try {
          await f.delete();
        } catch (_) {}
        keysToRemove.add(entry.key);
      }
    }
    for (final k in keysToRemove) {
      _artistImagePaths.remove(k);
      NamiArtistMetadataService.invalidate(k);
      removed++;
    }
    if (mounted) {
      setState(() {
        _artworkTick.value++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed > 0
                ? 'Cleared $removed placeholder artist photo(s). Re-fetching real portraits...'
                : 'No broken placeholder artist photos found. Checking missing artists...',
          ),
        ),
      );
    }
    _saveStateCache();
    _batchFetchMissingArtistPhotos();
  }

  Future<void> _batchFetchMissingArtistPhotos() async {
    final artistTracksMap = <String, List<String>>{};
    for (final s in _songs) {
      for (final a in namiSplitArtists(s.artist)) {
        if (a.isEmpty || a == 'Unknown Artist') continue;
        artistTracksMap.putIfAbsent(a, () => []).add(s.title);
      }
    }
    final missing = artistTracksMap.keys.where((a) {
      final p = _artistImagePaths[a];
      return p == null || !File(p).existsSync();
    }).take(25).toList();

    if (missing.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All artists already have photos!')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetching official portraits for ${missing.length} artists...')),
      );
    }

    int fetched = 0;
    for (final artist in missing) {
      try {
        final url = await NamiArtistMetadataService.fetchBestArtistPhotoUrl(
          artist,
          sampleTracks: artistTracksMap[artist]?.take(2).toList() ?? const [],
        );
        if (NamiArtistMetadataService.isValidRealPhotoUrl(url)) {
          await _saveArtistImageFromUrlOrFile(artist, url!);
          fetched++;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _artworkTick.value++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetched $fetched new artist portrait(s)!')),
      );
    }
    _saveStateCache();
  }

    String _v28LastWidgetSig = '';
  StreamSubscription<bool>? _v28PlaySub;
  StreamSubscription<dynamic>? _v28PlSub;

  void _syncV27WidgetAndSession({bool force = false}) {
    /* v28_2_dedup_sync */
    try {
      final song = _currentSong;
      final playing = _audioPlayer.state.playing;
      final sig = '${song?.path ?? ''}|$playing';
      if (!force && sig == _v28LastWidgetSig) return;
      _v28LastWidgetSig = sig;
      NamiAudiophileEngine.updateHomeWidget(
        title: song?.title ?? 'Nami Music',
        artist: song != null ? cleanArtistStr(song.artist) : 'Tap to open player',
        isPlaying: playing,
        coverPath: song?.thumbPath,
      );
      if (song != null) {
        NamiAudiophileEngine.saveSession(
          currentSong: song,
          position: _audioPlayer.state.position,
        );
      }
    } catch (_) {}
  }

  void _initV27AudiophileBridge() {
    /* v28_1_safe_guard */
    try {
    NamiUxPrefs.ensureLoaded().then((_) {
      NamiAudiophileEngine.applyMpvProperties(_audioPlayer);
    });
    NamiAudiophileEngine.bindWidgetControls(
      onPlayPause: () {
        if (_audioPlayer.state.playing) {
          _audioPlayer.pause();
        } else {
          _audioPlayer.play();
        }
      },
      onNext: () => _playNextTrack(),
      onPrev: () => _playPrevTrack(),
    );
    _v28PlaySub?.cancel();
    _v28PlaySub = _audioPlayer.stream.playing.listen((_) {
      if (mounted) _syncV27WidgetAndSession();
    });
    _v28PlSub?.cancel();
    _v28PlSub = _audioPlayer.stream.playlist.listen((_) {
      if (mounted) _syncV27WidgetAndSession();
    });
      } catch (_) {}
  }

  void _openMorphNowPlaying({
    Rect? miniRect,
    bool startFromDrag = false,
    BuildContext? navContext,
  }) {
    final song = _currentSong;
    if (song == null) return;
    if (NamiExpandablePlayerController.hasHost) {
      if (miniRect != null) NamiMorphPlayerController.registerMiniRect(miniRect);
      if (startFromDrag) {
        NamiExpandablePlayerController.beginDrag(isOpening: true);
      } else {
        NamiExpandablePlayerController.expand();
      }
      return;
    }
    if (NamiMorphPlayerController.isMorphActive) return;
    final targetCtx = navContext ?? context;
    Navigator.of(targetCtx).push(
      NamiMorphNowPlayingRoute<void>(
        miniRect: miniRect ?? NamiMorphPlayerController.lastMiniRect,
        startFromDrag: startFromDrag,
        title: song.title,
        artist: cleanArtistStr(song.artist),
        titleGetter: () => _currentSong?.title ?? song.title,
        artistGetter: () => cleanArtistStr((_currentSong ?? song).artist),
        trackKeyGetter: () => (_currentSong ?? song).path,
        coverBuilder: (sz, rad) => _buildCoverArt(_currentSong ?? song, sz, rad),
        isPlayingStream: _audioPlayer.stream.playing,
        initialPlaying: _audioPlayer.state.playing,
        onPlayPause: () {
          if (_audioPlayer.state.playing) {
            _audioPlayer.pause();
          } else {
            _audioPlayer.play();
          }
        },
        onNext: () => _playNextTrack(),
        onPrev: () => _playPrevTrack(),
        fullPageBuilder: (_) => NowPlayingModal(
        onGoToArtist: (artist) => _openArtistByName(artist),
          audioPlayer: _audioPlayer,
          currentSongNotifier: _currentSongNotifier,
          allSongs: _songs,
          playNextQueue: _playNextQueue,
          ambientGlow: _ambientGlow,
          blurredBackdrop: _blurredBackdrop,
          doubleTapSeekSec: _doubleTapSeekSec,
          syllableLyricsEnabled: _syllableLyricsEnabled,
          shuffleEnabled: _shuffleEnabled,
          repeatMode: _repeatMode,
          onToggleShuffle: () {
            setState(() => _shuffleEnabled = !_shuffleEnabled);
            _saveStateCache();
          },
          onCycleRepeat: () {
            setState(() => _repeatMode = (_repeatMode + 1) % 3);
            _audioPlayer.setPlaylistMode(_repeatMode == 2 ? PlaylistMode.single : PlaylistMode.none);
            _saveStateCache();
          },
          onShowPath: () {
            if (_currentSong != null) _showAudioPathDetails(_currentSong!);
          },
          onShowEqualizer: _showEqualizerSheet,
          onShowSleepTimer: _showSleepTimerDialog,
          onOpenLyricsManager: () {
            if (_currentSong != null) _showNamiLyricsManagerSheet(_currentSong!);
          },
          onToggleFavorite: () {
            if (_currentSong != null) {
              setState(() => _currentSong!.isFavorite = !_currentSong!.isFavorite);
              _saveStateCache();
            }
          },
          onRefreshLyrics: () {
            if (_currentSong != null) {
              _currentSong!.isLyricsFetched = false;
              _fetchLyricsOnline(_currentSong!);
            }
          },
          onNext: _playNextTrack,
          onPrevious: _playPrevTrack,
          onOpenQueue: () => _showQueueBottomSheet(context),
          onOpenMoreMenu: () {
            if (_currentSong != null) _showTrackOptionsMenu(_currentSong!);
          },
        ),
      ),
    );
  }

  void _handleV29SwipePlayAfter(AudioTrack song) {
    final burstIdx = NamiLiveToastController.activeQueueBurstCount;
    _playNextQueue.removeWhere((s) => s.path == song.path);
    final insertAt = burstIdx.clamp(0, _playNextQueue.length);
    setState(() {
      _playNextQueue.insert(insertAt, song);
    });
    NamiLiveToastController.showQueueAdded();
  }

  Future<void> _handleV29TracksPullRefresh() async {
    final beforeCount = _songs.length;
    final missingPaths = <String>{};
    for (final s in _songs) {
      if (!s.path.startsWith('http') && !File(s.path).existsSync()) {
        missingPaths.add(s.path);
      }
    }
    final removed = missingPaths.length;
    if (removed > 0) {
      _songs.removeWhere((s) => missingPaths.contains(s.path));
      _filteredSongs.removeWhere((s) => missingPaths.contains(s.path));
      _playNextQueue.removeWhere((s) => missingPaths.contains(s.path));
    }
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      setState(() {});
      final added = (_songs.length - beforeCount + removed).clamp(0, 99999);
      NamiTopBannerController.showLibraryUpdate(
        total: _songs.length,
        added: added,
        changed: 0,
        removed: removed,
      );
    }
  }
}

Widget _buildFormatPill(AudioTrack song, Color accent, {VoidCallback? onTap}) {
  final dotIdx = song.path.lastIndexOf('.');
  final ext = (dotIdx != -1 ? song.path.substring(dotIdx + 1) : 'AUDIO').toUpperCase();
  final isLossless = ext == 'FLAC' || ext == 'WAV' || ext == 'ALAC' || ext == 'AIFF';
  final label = isLossless ? '$ext ${song.bitDepth}B' : ext;
  final pillColor = isLossless ? accent : Colors.white54;
  final badge = Container(
    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
    decoration: BoxDecoration(
      color: isLossless ? accent.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(
        color: isLossless ? accent.withValues(alpha: 0.42) : Colors.white12,
        width: 0.7,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        color: pillColor,
      ),
    ),
  );
  if (onTap == null) return badge;
  return GestureDetector(onTap: onTap, child: badge);
}

String cleanArtistStr(String? raw) {
  if (raw == null || raw.isEmpty) return 'Unknown Artist';
  final parts = raw.split(RegExp(r',\s*')).map((x) => x.trim()).toList();
  final unique = <String>[];
  for (var p in parts) {
    if (!unique.map((e) => e.toLowerCase()).contains(p.toLowerCase())) unique.add(p);
  }
  return unique.join(', ');
}

String formatReleaseDate(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) return '';
  try {
    final parts = rawDate.split('-');
    if (parts.length >= 2) {
      final year = parts[0];
      final m = int.tryParse(parts[1]) ?? 1;
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[m - 1]}.$year';
    }
    return rawDate;
  } catch (e) {
    return rawDate;
  }
}


Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}













class _NamiPieSlice {
  final String label;
  final double value;
  final Color color;
  final String subtitle;
  const _NamiPieSlice({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle = '',
  });
}

class _NamiPieChartPainter extends CustomPainter {
  final List<_NamiPieSlice> slices;
  final int selectedIndex;
  final double holeRadiusFactor;

  const _NamiPieChartPainter({
    required this.slices,
    this.selectedIndex = -1,
    this.holeRadiusFactor = 0.58,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + (e.value > 0 ? e.value : 0));
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2 - 8;
    if (total <= 0 || baseRadius <= 0) {
      final bgPaint = Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18;
      canvas.drawCircle(center, baseRadius * 0.8, bgPaint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi;
      final isSel = i == selectedIndex;
      final r = isSel ? baseRadius + 5 : baseRadius;
      final midAngle = startAngle + sweep / 2;
      final offset = isSel
          ? Offset(math.cos(midAngle) * 4, math.sin(midAngle) * 4)
          : Offset.zero;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center + offset, radius: r),
        startAngle,
        sweep - (slices.length > 1 ? 0.025 : 0),
        true,
        paint,
      );
      startAngle += sweep;
    }

    final holePaint = Paint()
      ..color = const Color(0xFF0E0E14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * holeRadiusFactor, holePaint);
  }

  @override
  bool shouldRepaint(covariant _NamiPieChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.slices != slices;
  }
}

class _NamiActivityBarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color accentColor;

  const _NamiActivityBarChartPainter({
    required this.values,
    required this.labels,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<double>(0.0, (m, v) => v > m ? v : m);
    final effectiveMax = maxVal <= 0 ? 1.0 : maxVal;
    final chartH = size.height - 20;
    final barSlotW = size.width / values.length;
    final barW = math.max(6.0, barSlotW * 0.56);

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    for (int g = 1; g <= 3; g++) {
      final y = chartH * (1 - g / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < values.length; i++) {
      final ratio = (values[i] / effectiveMax).clamp(0.0, 1.0);
      final barH = math.max(values[i] > 0 ? 6.0 : 3.0, chartH * ratio);
      final left = i * barSlotW + (barSlotW - barW) / 2;
      final top = chartH - barH;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barW, barH),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      final paint = Paint()
        ..color = values[i] > 0 ? accentColor.withValues(alpha: 0.35 + 0.65 * ratio) : Colors.white12
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);

      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(fontSize: 9, color: Colors.white54),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(left + (barW - tp.width) / 2, chartH + 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NamiActivityBarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.accentColor != accentColor;
  }
}

class _NamiLyricEntry {
  final Duration time;
  final String text;
  const _NamiLyricEntry(this.time, this.text);
}


List<double>? _computeAudioWaveformIsolate(String path) {
  try {
    final f = File(path);
    if (!f.existsSync()) return null;
    final len = f.lengthSync();
    if (len <= 4096) return null;
    const bars = 78;
    const sampleChunk = 512;
    final raf = f.openSync();
    final peaks = List<double>.filled(bars, 0.25);
    final skipHeader = math.min(4096, len ~/ 12);
    final usable = math.max(bars * sampleChunk, len - skipHeader);
    for (int i = 0; i < bars; i++) {
      final pos = skipHeader + ((usable * i) ~/ bars);
      if (pos + sampleChunk < len) {
        raf.setPositionSync(pos);
        final chunk = raf.readSync(sampleChunk);
        double rms = 0;
        for (int b = 1; b < chunk.length; b++) {
          rms += (chunk[b] - chunk[b - 1]).abs();
        }
        peaks[i] = rms / math.max(1, chunk.length);
      }
    }
    raf.closeSync();
    final minP = peaks.reduce(math.min);
    final maxP = peaks.reduce(math.max);
    final span = math.max(1.0, maxP - minP);
    return peaks.map((p) => (6.0 + ((p - minP) / span) * 32.0).clamp(6.0, 38.0)).toList();
  } catch (_) {
    return null;
  }
}
