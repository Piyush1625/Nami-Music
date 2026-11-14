import 'package:nami/utils/nami_helpers.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audio_service/audio_service.dart';

import 'core/nami_helpers.dart';
import 'models/nami_models.dart';
import 'services/metadata_service.dart';
import 'services/nami_audio_handler.dart';
import 'services/auto_eq_service.dart';
import 'services/storage_service.dart';
import 'ui/namida_fast_scroller.dart';
import 'ui/now_playing_modal.dart';
import 'ui/settings_screen.dart';

NamiAudioHandler? namiAudioHandler;
late final AndroidEqualizer namiSharedEqualizer;
late final AndroidLoudnessEnhancer namiSharedLoudness;
late final AudioPlayer namiSharedAudioPlayer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF07070B),
  ));

  namiSharedEqualizer = AndroidEqualizer();
  namiSharedLoudness = AndroidLoudnessEnhancer();

  AudioPipeline? pipeline;
  if (Platform.isAndroid) {
    try {
      pipeline = AudioPipeline(
        androidAudioEffects: [namiSharedLoudness, namiSharedEqualizer],
      );
    } catch (_) {}
  }

  namiSharedAudioPlayer = AudioPlayer(
    audioPipeline: pipeline,
    handleInterruptions: true,
    androidApplyAudioAttributes: true,
    handleAudioSessionActivation: true,
  );

  try {
    namiAudioHandler = await AudioService.init(
      builder: () => NamiAudioHandler(namiSharedAudioPlayer),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.piyush.nami.channel.audio',
        androidNotificationChannelName: 'Nami Audiophile Playback',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (e) {
    debugPrint('AudioService.init error: $e');
  }

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
      title: 'Nami',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
          indicatorColor: accentColor.withOpacity(0.22),
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


class NamiHomeShell extends StatefulWidget {
  const NamiHomeShell({super.key});

  @override
  State<NamiHomeShell> createState() => _NamiHomeShellState();
}

class _NamiHomeShellState extends State<NamiHomeShell> {
  int _selectedIndex = 1;

  late final AndroidEqualizer _androidEqualizer;
  late final AndroidLoudnessEnhancer _androidLoudness;
  late final AudioPlayer _audioPlayer;

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
  List<String> _artistSeparators = [',', '&', '/', ';', 'feat.', 'ft.'];

  Directory _currentFolder = Directory('/storage/emulated/0/Music');
  String _lastKnownDac = "";
  StreamSubscription? _deviceSub;

  Timer? _sleepTimer;
  Timer? _fadeTimer;
  Timer? _telemetryTimer;
  int _sleepMinutesRemaining = 0;
  bool _sleepAfterCurrentTrack = false;

  int _totalListenSeconds = 0;
  int _currentTrackSecondsListened = 0;

  double _playbackSpeed = 1.0;
  String _soundstagePreset = 'Off';
  bool _eqEnabled = false;
  double _preampGainDb = 0.0;

  bool _usbDacExclusive = true;
  bool _gaplessPlayback = true;
  bool _mediaNotificationEnabled = true;
  bool _usePitchBlack = true;
  bool _autoColoring = true;
  bool _ambientGlow = false;
  bool _preferEmbeddedLyrics = true;
  bool _syllableLyricsEnabled = true;
  bool _autoFetchOnlineMetadata = true;
  bool _forceMiniColor = false;
  bool _replayGain = true;
  String _connectedDacName = "KEFINE";
  String _userName = "Piyush";
  String? _userPhotoPath;

  final Map<String, double> _eqBands = {
    '60Hz': 3.0,
    '230Hz': 1.5,
    '910Hz': 0.0,
    '3.6kHz': 2.0,
    '14kHz': 4.0,
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
  final Map<String, List<AudioTrack>> albumGroups = {};

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
    _androidEqualizer = namiSharedEqualizer;
    _androidLoudness = namiSharedLoudness;
    _audioPlayer = namiSharedAudioPlayer;

    namiAudioHandler?.onSkipNext = _playNextTrack;
    namiAudioHandler?.onSkipPrevious = _playPrevTrack;

    _initHardwareDsp();
    _initAudioSessionAndDac();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStateCache();
      await _requestPermissionsAndInitBackground();
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() {});
      if (state.processingState == ProcessingState.completed) {
        if (_sleepAfterCurrentTrack) {
          _audioPlayer.pause();
          setState(() {
            _sleepAfterCurrentTrack = false;
            _sleepMinutesRemaining = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Playback paused by Sleep Timer.')));
          return;
        }

        if (_playNextQueue.isNotEmpty) {
          final next = _playNextQueue.removeAt(0);
          _playSong(next);
        } else {
          _playNextTrack();
        }
      }
    });

    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_audioPlayer.playing) {
        _totalListenSeconds++;
        _currentTrackSecondsListened++;
        if (_currentTrackSecondsListened == 25 && _currentSong != null) {
          _currentSong!.playCount++;
          _saveStateCache();
        }
      }
    });
  }

  Future<void> _initHardwareDsp() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidEqualizer.setEnabled(_eqEnabled);
      await _androidLoudness.setEnabled(_preampGainDb > 0);
      await _androidLoudness.setTargetGain(_preampGainDb);
      if (_eqEnabled) {
        await _applyHardwareEqGains();
      }
    } catch (_) {}
  }

  Future<void> _applyHardwareEqGains() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidEqualizer.setEnabled(_eqEnabled);
      if (!_eqEnabled) return;
      final params = await _androidEqualizer.parameters;
      final bands = params.bands;
      final values = _eqBands.values.toList();
      for (int i = 0; i < bands.length && i < values.length; i++) {
        final clamped = values[i].clamp(params.minDecibels, params.maxDecibels);
        await bands[i].setGain(clamped);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _deviceSub?.cancel();
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

  Future<void> _loadStateCache() async {
    try {
      final data = await NamiStorageService.loadCacheData();
      if (data != null) {
          _totalListenSeconds = data['totalListenSeconds'] ?? 0;
          _userName = data['userName'] ?? 'Piyush';
          _userPhotoPath = data['userPhotoPath'];
          _splitMultiArtists = data['splitMultiArtists'] ?? true;
          _autoFetchOnlineMetadata = data['autoFetchOnlineMetadata'] ?? true;
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
                  .toList() ??
              [];
          for (var s in cachedSongs) {
            final expectedThumb =
                '${thumbDir.path}/${namiDeterministicPathHash(s.path)}.jpg';
            final tf = File(s.thumbPath ?? expectedThumb);
            if (await tf.exists()) {
              s.thumbPath = tf.path;
              s.albumArt = await tf.readAsBytes();
            }
          }
          if (cachedSongs.isNotEmpty && mounted) {
            setState(() {
              _songs = cachedSongs;
              _filteredSongs = List.from(cachedSongs);
            });
          }
      }
    } catch (_) {}
  }

  Future<void> _saveStateCache() async {
    try {
      final map = {
        'totalListenSeconds': _totalListenSeconds,
        'userName': _userName,
        'userPhotoPath': _userPhotoPath,
        'splitMultiArtists': _splitMultiArtists,
        'autoFetchOnlineMetadata': _autoFetchOnlineMetadata,
        'artistImageRetryAfter': _artistImageRetryAfter,
        'artistSeparators': _artistSeparators,
        'accentColor': mounted ? NamiApp.of(context).accentColor.value : null,
        'cachedTracks': _songs.map((s) => s.toJson()).toList(),
      };
      await NamiStorageService.saveCacheData(map);
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

  Future<void> _initAudioSessionAndDac() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await session.setActive(true);
      await _audioPlayer.setSpeed(_playbackSpeed);
      await _audioPlayer.setPitch(1.0);
      await _audioPlayer.setSkipSilenceEnabled(false);

      _deviceSub?.cancel();
      _deviceSub = session.devicesStream.listen((devices) {
        _checkConnectedAudioHardware(devices);
      });

      final initialDevices = await session.getDevices();
      _checkConnectedAudioHardware(initialDevices, isInitial: true);
    } catch (_) {}
  }

  void _checkConnectedAudioHardware(Set<AudioDevice> devices,
      {bool isInitial = false}) {
    for (var d in devices) {
      if (d.isOutput && d.name.isNotEmpty) {
        if (d.name != _lastKnownDac) {
          _lastKnownDac = d.name;
          _connectedDacName = d.name;
          if (mounted) setState(() {});
        }
      }
    }
  }

  void _filterSongs(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredSongs = _songs
          .where((song) =>
              song.title.toLowerCase().contains(q) ||
              song.artist.toLowerCase().contains(q) ||
              song.album.toLowerCase().contains(q))
          .toList();
    });
  }

  void _locateActivePlayingTrack() {
    if (_currentSong == null || _filteredSongs.isEmpty) return;
    int idx = _filteredSongs.indexOf(_currentSong!);
    if (idx != -1 && _trackListScrollController.hasClients) {
      _trackListScrollController.animateTo(
        idx * 64.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _playSong(AudioTrack song) async {
    if (song.path.isEmpty) return;
    _currentSong = song;
    _currentTrackSecondsListened = 0;
    _historyTracks.remove(song);
    _historyTracks.insert(0, song);
    if (_autoColoring && song.albumArt != null) {
      final dominant =
          namiExtractDominantColor(song.albumArt, const Color(0xFFE53935));
      NamiApp.of(context).updateTheme(newAccent: dominant);
    }
    if (mounted) setState(() {});
    namiAudioHandler?.updateCurrentMediaItem(song);
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
      });
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setFilePath(song.path);
      await _audioPlayer.play();
      if (_audioPlayer.duration != null &&
          _audioPlayer.duration!.inSeconds > 0) {
        song.duration = _audioPlayer.duration!;
        if (song.fileSize > 0) {
          song.bitrateKbps =
              ((song.fileSize * 8) ~/ 1000) ~/ song.duration.inSeconds;
        }
        if (mounted) setState(() {});
      }
      _saveStateCache();
    } catch (_) {}
  }

  void _playNextTrack() {
    if (_playNextQueue.isNotEmpty) {
      final next = _playNextQueue.removeAt(0);
      _playSong(next);
      return;
    }
    if (_filteredSongs.isNotEmpty && _currentSong != null) {
      int nextIdx =
          (_filteredSongs.indexOf(_currentSong!) + 1) % _filteredSongs.length;
      _playSong(_filteredSongs[nextIdx]);
    } else if (_filteredSongs.isNotEmpty) {
      _playSong(_filteredSongs.first);
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
    _audioPlayer.setVolume(1.0);

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
      double volume = (1.0 - (currentStep / fadeSteps)).clamp(0.0, 1.0);
      _audioPlayer.setVolume(volume);
      if (currentStep >= fadeSteps) {
        t.cancel();
        _audioPlayer.pause();
        _audioPlayer.setVolume(1.0);
        setState(() => _sleepMinutesRemaining = 0);
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _audioPlayer.setVolume(1.0);
    setState(() {
      _sleepMinutesRemaining = 0;
      _sleepAfterCurrentTrack = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sleep Timer cancelled')));
  }

  void _showSleepTimerDialog() {
    showModalBottomSheet(
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

  void _showAudioPathDetails(AudioTrack song) {
    final actualBitrate = song.fileSize > 0 && song.duration.inSeconds > 0
        ? ((song.fileSize * 8) / 1000 / song.duration.inSeconds).round()
        : song.bitrateKbps;
    final isHiRes = song.bitDepth >= 24 ||
        song.sampleRateHz > 48000 ||
        actualBitrate > 1000;
    final kHz = (song.sampleRateHz / 1000.0).toStringAsFixed(1);
    final pcmKbps = (song.sampleRateHz * song.bitDepth * 2) ~/ 1000;
    final extBadge = song.path.split('.').last.toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F15),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
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
                  const Text('Audio Pipeline',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: isHiRes
                            ? Colors.amber.withOpacity(0.15)
                            : Colors.white10,
                        border: Border.all(
                            color: isHiRes
                                ? Colors.amber.withOpacity(0.5)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(
                            isHiRes
                                ? Icons.high_quality_rounded
                                : Icons.bolt_rounded,
                            size: 14,
                            color: isHiRes
                                ? Colors.amber
                                : (_eqEnabled
                                    ? Colors.cyanAccent
                                    : Colors.white70)),
                        const SizedBox(width: 4),
                        Text(
                            isHiRes
                                ? 'Hi-Res Lossless'
                                : (_eqEnabled ? 'DSP Active' : 'Bit-perfect'),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isHiRes ? Colors.amber : Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAudioPathNode(
                icon: Icons.music_note_rounded,
                title: 'Source File • $extBadge',
                subtitle:
                    '${song.bitDepth}-bit • $kHz kHz • 2 ch • $actualBitrate kbps (PCM $pcmKbps kbps)',
                showConnectorDown: true,
              ),
              _buildAudioPathNode(
                icon: Icons.bolt_rounded,
                title: _eqEnabled
                    ? 'AndroidEqualizer Pipeline ($_selectedEqPreset)'
                    : 'Bit-perfect Direct',
                subtitle: _eqEnabled ? '5-Band Hardware EQ Active' : null,
                showConnectorDown: true,
              ),
              _buildAudioPathNode(
                icon: Icons.settings_input_composite_rounded,
                title: 'USB direct access',
                subtitle: '${song.bitDepth}-bit • $kHz kHz • DAC volume',
                showConnectorDown: true,
              ),
              _buildAudioPathNode(
                icon: Icons.speaker_rounded,
                title: _connectedDacName,
                subtitle: null,
                showConnectorDown: false,
              ),
            ],
          ),
        ),
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
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.2),
              ),
              child: Icon(icon, size: 18, color: Colors.white70),
            ),
            const SizedBox(width: 16),
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
                size: 12, color: Colors.white.withOpacity(0.25)),
          ),
      ],
    );
  }

  void _showEqualizerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setEqState) => Padding(
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
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) async {
                      setEqState(() => _eqEnabled = v);
                      setState(() {});
                      await _applyHardwareEqGains();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AutoEqPreset.getPresets().map((autoEq) {
                    final sel = _selectedEqPreset == autoEq.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.headphones_rounded, size: 14, color: Colors.white70),
                        label: Text(
                          '${autoEq.name} (${autoEq.headphoneModel})',
                          style: TextStyle(fontSize: 11.5, color: sel ? Colors.white : Colors.white70),
                        ),
                        selected: sel,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: const Color(0xFF0A0A0E),
                        onSelected: (_) async {
                          setEqState(() {
                            _selectedEqPreset = autoEq.name;
                            _eqEnabled = true;
                            _eqBands.addAll(autoEq.bands);
                          });
                          setState(() {});
                          await _applyHardwareEqGains();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Hi-Fi Master',
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
                            if (preset == 'Bass Boost') {
                              _eqBands['60Hz'] = 6.5;
                              _eqBands['230Hz'] = 4.0;
                              _eqBands['910Hz'] = 0.0;
                              _eqBands['3.6kHz'] = 1.0;
                              _eqBands['14kHz'] = 2.0;
                            } else if (preset == 'Flat') {
                              _eqBands.updateAll((key, value) => 0.0);
                            } else if (preset == 'Vocal Clear') {
                              _eqBands['60Hz'] = -1.5;
                              _eqBands['230Hz'] = 1.0;
                              _eqBands['910Hz'] = 3.5;
                              _eqBands['3.6kHz'] = 4.5;
                              _eqBands['14kHz'] = 2.0;
                            } else if (preset == 'Rock') {
                              _eqBands['60Hz'] = 4.5;
                              _eqBands['230Hz'] = 2.0;
                              _eqBands['910Hz'] = -1.0;
                              _eqBands['3.6kHz'] = 3.0;
                              _eqBands['14kHz'] = 4.5;
                            } else if (preset == 'Treble Sparkle') {
                              _eqBands['60Hz'] = 1.0;
                              _eqBands['230Hz'] = 0.0;
                              _eqBands['910Hz'] = 1.0;
                              _eqBands['3.6kHz'] = 4.0;
                              _eqBands['14kHz'] = 6.5;
                            } else if (preset == 'Hi-Fi Master') {
                              _eqBands['60Hz'] = 3.0;
                              _eqBands['230Hz'] = 1.5;
                              _eqBands['910Hz'] = 0.0;
                              _eqBands['3.6kHz'] = 2.0;
                              _eqBands['14kHz'] = 4.0;
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
                      try {
                        await _androidLoudness.setEnabled(v > 0);
                        await _androidLoudness.setTargetGain(v);
                      } catch (_) {}
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
                      _audioPlayer.setSpeed(v);
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
                              onSelected: (_) =>
                                  setEqState(() => _soundstagePreset = p),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNamidaLyricsManagerSheet(AudioTrack song) {
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
                headers: namiHttpHeaders,
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
                      child: ListView.builder(
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
                      ),
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

  void _showTagEditorDialog(AudioTrack song) {
    final titleCtrl = TextEditingController(text: song.title);
    final artistCtrl = TextEditingController(text: song.artist);
    final albumCtrl = TextEditingController(text: song.album);
    final genreCtrl = TextEditingController(text: song.genre);
    final lyricsCtrl = TextEditingController(text: song.rawLyrics);
    final coverPathCtrl = TextEditingController();

    showModalBottomSheet(
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
                          .withOpacity(0.12),
                    ),
                    icon: const Icon(Icons.lyrics_outlined, size: 16),
                    label: const Text('Lyrics Manager',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      _showNamidaLyricsManagerSheet(song);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                                '${thumbDir.path}/${namiDeterministicPathHash(song.path)}.jpg');
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
                      if (context.mounted) Navigator.pop(context);
                      _saveStateCache();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Tags & metadata updated!')));
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
                  _songs.remove(song);
                  _filteredSongs = List.from(_songs);
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
                    subtitle: Text('${pl.tracks.length} tracks'),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101016),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildCoverArt(song, 48, 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${song.artist} • ${song.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.playlist_play_rounded),
                title: const Text('Play Next'),
                onTap: () {
                  setState(() => _playNextQueue.add(song));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${song.title} to play next')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add to Playlist'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_rounded),
                title: const Text('Fetch Cover & Metadata Online'),
                onTap: () async {
                  Navigator.pop(context);
                  final dir = await _ensureThumbDir();
                  song.isOnlineEnriched = false;
                  await _enrichTrackOnlineIfMissing(song, dir, force: true);
                  if (mounted) setState(() {});
                  _saveStateCache();
                },
              ),
              ListTile(
                leading: const Icon(Icons.lyrics_outlined),
                title: const Text('Lyrics Metadata & Editor'),
                onTap: () {
                  Navigator.pop(context);
                  _showNamidaLyricsManagerSheet(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Edit Tags & Cover'),
                onTap: () {
                  Navigator.pop(context);
                  _showTagEditorDialog(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Go to Artist'),
                onTap: () {
                  Navigator.pop(context);
                  _buildArtistGroupsMap();
                  final primary = _splitMultiArtists
                      ? song.artist.split(RegExp(_artistSeparators.map(RegExp.escape).join('|'), caseSensitive: false)).first.trim()
                      : song.artist;
                  final tracks = artistGroups[primary] ?? _songs.where((s) => s.artist.toLowerCase().contains(primary.toLowerCase())).toList();
                  _showArtistDetailScreen(primary.isNotEmpty ? primary : song.artist, tracks);
                },
              ),
              ListTile(
                leading: const Icon(Icons.album_rounded),
                title: const Text('Go to Album'),
                onTap: () {
                  Navigator.pop(context);
                  _showAlbumDetailScreen(song.album, _songs.where((s) => s.album == song.album).toList());
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: const Text('Delete Forever', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showAdvancedDeleteDialog(song);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderExplorerModal() {
    showModalBottomSheet(
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setQueueState) {
          final activeList = _playNextQueue.isNotEmpty ? _playNextQueue : _filteredSongs;
          final totalDur = activeList.fold<Duration>(Duration.zero, (sum, item) => sum + item.duration);
          final activeIndex = _currentSong != null ? (_songs.indexOf(_currentSong!) + 1) : 1;
          final accent = Theme.of(context).colorScheme.primary;

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
                      color: const Color(0xFF101016).withOpacity(0.96),
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
                              Text(_currentSong!.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                            ],
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: _audioPlayer.playerStateStream,
                          builder: (ctx, snap) {
                            final playing = snap.data?.playing ?? _audioPlayer.playing;
                            return GestureDetector(
                              onTap: () => playing ? _audioPlayer.pause() : _audioPlayer.play(),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
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
                                    '$activeIndex/${_songs.length} • ${namiFormatTotalDurationHoursMins(totalDur)}',
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
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
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
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: _playNextQueue.isEmpty
                              ? ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: _filteredSongs.length,
                                  itemBuilder: (ctx, idx) => _buildNamidaQueueRow(
                                    song: _filteredSongs[idx],
                                    index: idx,
                                    isReorderable: false,
                                    onTap: () {
                                      _playSong(_filteredSongs[idx]);
                                      Navigator.pop(context);
                                    },
                                    onToggleFav: () {
                                      setQueueState(() => _filteredSongs[idx].isFavorite = !_filteredSongs[idx].isFavorite);
                                      setState(() {});
                                      _saveStateCache();
                                    },
                                  ),
                                )
                              : ReorderableListView.builder(
                                  scrollController: scrollController,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: _playNextQueue.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setQueueState(() {
                                      if (newIndex > oldIndex) newIndex -= 1;
                                      final item = _playNextQueue.removeAt(oldIndex);
                                      _playNextQueue.insert(newIndex, item);
                                    });
                                    setState(() {});
                                  },
                                  itemBuilder: (ctx, idx) {
                                    final qTrack = _playNextQueue[idx];
                                    return Container(
                                      key: ValueKey('q_${qTrack.path}_$idx'),
                                      child: _buildNamidaQueueRow(
                                        song: qTrack,
                                        index: idx,
                                        isReorderable: true,
                                        onTap: () {
                                          _playSong(qTrack);
                                          Navigator.pop(context);
                                        },
                                        onToggleFav: () {
                                          setQueueState(() => qTrack.isFavorite = !qTrack.isFavorite);
                                          setState(() {});
                                          _saveStateCache();
                                        },
                                        onRemove: () {
                                          setQueueState(() => _playNextQueue.removeAt(idx));
                                          setState(() {});
                                        },
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
                                  backgroundColor: accent.withOpacity(0.18),
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

  Widget _buildNamidaQueueRow({
    required AudioTrack song,
    required int index,
    required bool isReorderable,
    required VoidCallback onTap,
    required VoidCallback onToggleFav,
    VoidCallback? onRemove,
  }) {
    final isCurrent = _currentSong?.path == song.path;
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        child: Row(
          children: [
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
                    song.artist,
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
                Text(namiFormatDurationPadded(song.duration), style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainSettingsScreen(
          usbDacExclusive: _usbDacExclusive,
          gaplessPlayback: _gaplessPlayback,
          mediaNotificationEnabled: _mediaNotificationEnabled,
          usePitchBlack: _usePitchBlack,
          autoColoring: _autoColoring,
          ambientGlow: _ambientGlow,
          syllableLyricsEnabled: _syllableLyricsEnabled,
          preferEmbeddedLyrics: _preferEmbeddedLyrics,
          autoFetchOnlineMetadata: _autoFetchOnlineMetadata,
          splitMultiArtists: _splitMultiArtists,
          artistSeparators: _artistSeparators,
          forceMiniColor: _forceMiniColor,
          replayGain: _replayGain,
          connectedDacName: _connectedDacName,
          onOpenExtensionRepo: _openExtensionRepoScreen,
          onOpenFolderExplorer: _showFolderExplorerModal,
          onExportBackup: _exportBackup,
          onImportBackup: _importBackup,
          onUsbDacChanged: (v) => setState(() => _usbDacExclusive = v),
          onGaplessChanged: (v) => setState(() => _gaplessPlayback = v),
          onNotificationChanged: (v) => setState(() => _mediaNotificationEnabled = v),
          onAccentChanged: (c) {
            NamiApp.of(context).updateTheme(newAccent: c);
            _saveStateCache();
          },
          onPitchBlackChanged: (v) {
            setState(() => _usePitchBlack = v);
            NamiApp.of(context).updateTheme(isPitchBlack: v);
          },
          onAutoColoringChanged: (v) => setState(() => _autoColoring = v),
          onAmbientGlowChanged: (v) => setState(() => _ambientGlow = v),
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
          onReplayGainChanged: (v) => setState(() => _replayGain = v),
          onRescan: () => _fastScanDeviceMusic(forceReparse: true),
        ),
      ),
    );
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setRepoState) => Scaffold(
            appBar: AppBar(
              title: const Text('Mornye Extension Repo'),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.file_open_rounded, size: 18),
                  label: const Text('Import .sflx'),
                  onPressed: () async {
                    await _importSflxManifest();
                    setRepoState(() {});
                  },
                ),
              ],
            ),
            body: ListView.builder(
              itemCount: _extensions.length,
              itemBuilder: (ctx, idx) {
                final ext = _extensions[idx];
                return ListTile(
                  leading: Icon(Icons.extension_rounded, color: ext.isInstalled ? Theme.of(context).colorScheme.primary : Colors.grey),
                  title: Text('${ext.name} (${ext.version})'),
                  subtitle: Text('${ext.format} • ${ext.description}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Switch(
                    value: ext.isInstalled,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (v) {
                      setRepoState(() => ext.isInstalled = v);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openStatisticsScreen() {
    final topPlayed = List<AudioTrack>.from(_songs)..sort((a, b) => b.playCount.compareTo(a.playCount));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Listening Statistics')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF14141F), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Listen Time: ${_totalListenSeconds ~/ 60} mins', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Total Library Tracks: ${_songs.length}', style: const TextStyle(color: Colors.white70)),
                    Text('Favorites Count: ${_songs.where((s) => s.isFavorite).length}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Most Played Tracks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...topPlayed.take(15).map((s) => _buildNamidaTrackTile(s)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchMornyeCatalog(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isMornyeSearching = true);
    try {
      final uri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query.trim())}&media=music&entity=song&limit=20');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = (data['results'] as List?) ?? [];
        setState(() {
          _mornyeResults = results
              .map((r) => MornyeCatalogItem(
                    title: r['trackName'] ?? 'Unknown',
                    artist: r['artistName'] ?? 'Unknown Artist',
                    album: r['collectionName'] ?? 'Single',
                    subtitle: '${r['primaryGenreName'] ?? 'Music'} • $_selectedMornyeService',
                    type: 'track',
                    service: _selectedMornyeService,
                    previewUrl: r['previewUrl'],
                    artworkUrl: r['artworkUrl100']?.toString().replaceAll('100x100', '600x600'),
                    durationSeconds: ((r['trackTimeMillis'] ?? 210000) as int) ~/ 1000,
                  ))
              .toList();
          _isMornyeSearching = false;
        });
      } else {
        setState(() => _isMornyeSearching = false);
      }
    } catch (_) {
      setState(() => _isMornyeSearching = false);
    }
  }

  Future<void> _downloadMornyeItem(MornyeCatalogItem item) async {
    if (item.previewUrl == null) return;
    setState(() => _downloadingTitles.add(item.title));
    try {
      final res = await http.get(Uri.parse(item.previewUrl!)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final safeName = '${item.artist} - ${item.title}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final outFile = File('$_mornyeDownloadFolder/$safeName.m4a');
        await outFile.writeAsBytes(res.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${item.title} to Music folder')));
        }
        await _fastScanDeviceMusic();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloadingTitles.remove(item.title));
    }
  }

  Future<bool> _checkAnyStorageGranted() async {
    try {
      if (await Permission.audio.isGranted ||
          await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      final musicDir = Directory('/storage/emulated/0/Music');
      if (await musicDir.exists()) {
        musicDir.listSync().take(1).toList();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _requestPermissionsAndInitBackground({bool userTriggered = false}) async {
    bool granted = await _checkAnyStorageGranted();

    if (!granted) {
      var audioStatus = await Permission.audio.status;
      if (audioStatus.isDenied) {
        audioStatus = await Permission.audio.request();
      }
      if (!audioStatus.isGranted) {
        var storageStatus = await Permission.storage.status;
        if (storageStatus.isDenied) {
          storageStatus = await Permission.storage.request();
        }
      }
      if (!(await Permission.audio.isGranted) && !(await Permission.storage.isGranted)) {
        var manageStatus = await Permission.manageExternalStorage.status;
        if (manageStatus.isDenied && userTriggered) {
          manageStatus = await Permission.manageExternalStorage.request();
        }
      }
      granted = await _checkAnyStorageGranted();
    }

    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}

    if (granted || _songs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _hasPermission = true;
          if (_songs.isEmpty) _isScanning = true;
        });
      }
      await _fastScanDeviceMusic();
    } else if (mounted) {
      setState(() => _hasPermission = false);
    }
  }

  Future<void> _fastScanDeviceMusic({bool forceReparse = false}) async {
    List<AudioTrack> foundTracks = [];
    final existingMap = forceReparse ? <String, AudioTrack>{} : {for (var s in _songs) s.path: s};

    try {
      List<Directory> searchDirs = [];
      final rootMusic = Directory('/storage/emulated/0/Music');
      if (await rootMusic.exists()) searchDirs.add(rootMusic);
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) searchDirs.add(downloadDir);

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

    foundTracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    setState(() {
      _songs = foundTracks;
      _filteredSongs = foundTracks;
      _isScanning = false;
    });

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
  }) =>
      NamiMetadataService.enrichTrackOnlineIfMissing(
        track,
        thumbDir,
        force: force,
        onArtworkUpdated: () => _artworkTick.value++,
      );

  Future<void> _extractAudioMetadataUniversal(
    AudioTrack track,
    Directory thumbDir,
  ) =>
      NamiMetadataService.extractAudioMetadataUniversal(
        track,
        thumbDir,
        onArtworkUpdated: () => _artworkTick.value++,
      );

  String _sanitizeMetadataText(String input) =>
      NamiMetadataService.sanitizeMetadataText(input);

  List<LyricLine> _parseLrc(String raw) => NamiMetadataService.parseLrc(raw);

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

  Widget _buildNamidaHomeScreen(List<String> uniqueArtists) {
    final accent = Theme.of(context).colorScheme.primary;
    final mostPlayed = List<AudioTrack>.from(_songs)..sort((a, b) => b.playCount.compareTo(a.playCount));
    final recentlyAdded = List<AudioTrack>.from(_songs)..sort((a, b) => b.addedTimestampMs.compareTo(a.addedTimestampMs));
    final favSongs = _songs.where((s) => s.isFavorite).toList();
    final hiResSongs = _songs.where((s) => s.bitDepth >= 24 || s.sampleRateHz > 48000 || s.path.toLowerCase().endsWith('.flac')).toList();
    final flacCount = _songs.where((s) => s.path.toLowerCase().endsWith('.flac')).length;
    final hiResCount = _songs.where((s) => s.bitDepth >= 24 || s.sampleRateHz > 48000).length;

    final Map<String, List<AudioTrack>> albumsMap = {};
    for (var s in _songs) {
      if (s.album.isNotEmpty && s.album != 'Unknown Album') {
        albumsMap.putIfAbsent(s.album, () => []).add(s);
      }
    }
    final topAlbums = albumsMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final spotlightTrack = _currentSong ??
        (mostPlayed.isNotEmpty && mostPlayed.first.playCount > 0
            ? mostPlayed.first
            : (_songs.isNotEmpty ? _songs[DateTime.now().day % _songs.length] : null));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
      children: [
        // 1. Audiophile Hero Greeting & Live DAC Status Card
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.24), const Color(0xFF101018)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.32)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: accent.withOpacity(0.22),
                child: Icon(Icons.headphones_rounded, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, $_userName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
                          child: Text('DAC: $_connectedDacName', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_songs.length} tracks • ${_totalListenSeconds ~/ 60}m played',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Listening Statistics',
                icon: Icon(Icons.bar_chart_rounded, color: accent),
                onPressed: _openStatisticsScreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Quick-Action Bento Shortcuts
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildHomeSmartTile(
              icon: Icons.shuffle_rounded,
              title: 'Quick Shuffle',
              subtitle: '${_songs.length} tracks',
              color: Colors.greenAccent,
              onTap: _shufflePlay,
            ),
            _buildHomeSmartTile(
              icon: Icons.favorite_rounded,
              title: 'Liked Songs',
              subtitle: '${favSongs.length} favorites',
              color: accent,
              onTap: () => _showFilteredListScreen('Liked Songs', favSongs),
            ),
            _buildHomeSmartTile(
              icon: Icons.high_quality_rounded,
              title: 'Hi-Res Lossless',
              subtitle: '${hiResSongs.length} FLAC/24-bit',
              color: Colors.amberAccent,
              onTap: () => _showFilteredListScreen('Hi-Res Lossless Vault', hiResSongs),
            ),
            _buildHomeSmartTile(
              icon: Icons.folder_open_rounded,
              title: 'Folder Browser',
              subtitle: 'Direct storage',
              color: Colors.cyanAccent,
              onTap: _showFolderExplorerModal,
            ),
          ],
        ),

        // 3. Daily Spotlight / Continue Listening Card
        if (spotlightTrack != null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _playSong(spotlightTrack),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  _buildCoverArt(spotlightTrack, 64, 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentSong != null ? 'NOW ACTIVE' : 'DAILY SPOTLIGHT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: accent),
                        ),
                        const SizedBox(height: 2),
                        Text(spotlightTrack.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('${spotlightTrack.artist} • ${spotlightTrack.album}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accent,
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (_historyTracks.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildHomeSectionHeader('Jump Back In', () => _showFilteredListScreen('Play History', _historyTracks)),
          const SizedBox(height: 8),
          _buildHorizontalTrackCarousel(_historyTracks.take(15).toList()),
        ],
        if (_songs.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildHomeSectionHeader('Most Played', () => _showFilteredListScreen('Most Played', mostPlayed.take(50).toList())),
          const SizedBox(height: 8),
          _buildHorizontalTrackCarousel(mostPlayed.take(15).toList(), showPlayBadge: true),
        ],
        if (_songs.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildHomeSectionHeader('Recently Added', () => _showFilteredListScreen('Recently Added', recentlyAdded.take(50).toList())),
          const SizedBox(height: 8),
          _buildHorizontalTrackCarousel(recentlyAdded.take(15).toList()),
        ],
        if (topAlbums.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildHomeSectionHeader('Featured Albums', () => _showAlbumDetailScreen(topAlbums.first.key, topAlbums.first.value)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(topAlbums.length, 15),
              itemBuilder: (ctx, idx) {
                final entry = topAlbums[idx];
                final artTrack = entry.value.firstWhere(
                  (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
                  orElse: () => entry.value.first,
                );
                return GestureDetector(
                  onTap: () => _showAlbumDetailScreen(entry.key, entry.value),
                  child: Container(
                    width: 108,
                    margin: const EdgeInsets.only(right: 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCoverArt(artTrack, 104, 14),
                        const SizedBox(height: 5),
                        Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        Text('${entry.value.length} tracks', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (uniqueArtists.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildHomeSectionHeader('Artists (${uniqueArtists.length})', () => setState(() => _selectedIndex = 2)),
          const SizedBox(height: 8),
          SizedBox(
            height: 106,
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
                  child: Container(
                    width: 78,
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        _buildRoundArtistAvatar(firstArtTrack, 32),
                        const SizedBox(height: 5),
                        Text(aName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('${aTracks.length} tracks', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFormatStat('FLAC Lossless', '$flacCount'),
              Container(width: 1, height: 28, color: Colors.white10),
              _buildFormatStat('24-Bit Hi-Res', '$hiResCount'),
              Container(width: 1, height: 28, color: Colors.white10),
              _buildFormatStat('Artists', '${uniqueArtists.length}'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _fetchArtistImage(String rawArtistName) async {
    final primary = rawArtistName
        .split(RegExp(_artistSeparators.map(RegExp.escape).join('|'),
            caseSensitive: false))
        .first
        .trim();
    if (primary.isEmpty ||
        primary == 'Unknown Artist' ||
        _artistImagePaths.containsKey(primary)) {
      return;
    }

    if (!_artistDiskChecked.contains(primary)) {
      _artistDiskChecked.add(primary);
      final thumbDir = await _ensureThumbDir();
      final f = File(
          '${thumbDir.path}/artist_${namiDeterministicPathHash(primary.toLowerCase())}.jpg');
      if (await f.exists()) {
        _artistImagePaths[primary] = f.path;
        _artworkTick.value++;
        return;
      }
    }

    final retryAt = _artistImageRetryAfter[primary] ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < retryAt) return;

    if (_artistImageQueued.add(primary)) {
      _artistImageQueue.add(primary);
      _drainArtistImageQueue();
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
          .get(uri, headers: namiHttpHeaders)
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
                .get(Uri.parse(picUrl), headers: namiHttpHeaders)
                .timeout(const Duration(seconds: 6));
            if (imgRes.statusCode == 200 &&
                namiLooksLikeImage(imgRes.bodyBytes)) {
              final thumbDir = await _ensureThumbDir();
              final f = File(
                  '${thumbDir.path}/artist_${namiDeterministicPathHash(artistName.toLowerCase())}.jpg');
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

  Widget _buildRoundArtistAvatar(AudioTrack? track, double radius) {
    if (track != null &&
        track.artist.isNotEmpty &&
        track.artist != 'Unknown Artist') {
      _fetchArtistImage(track.artist);
    }
    return ValueListenableBuilder<int>(
      valueListenable: _artworkTick,
      builder: (context, _, __) {
        if (track != null) {
          final primary = track.artist
              .split(RegExp(_artistSeparators.map(RegExp.escape).join('|'),
                  caseSensitive: false))
              .first
              .trim();
          final artistImgPath = _artistImagePaths[primary];
          if (artistImgPath != null) {
            final af = File(artistImgPath);
            if (af.existsSync()) {
              return CircleAvatar(
                radius: radius,
                backgroundColor: const Color(0xFF161622),
                backgroundImage: FileImage(af),
              );
            }
          }
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
          child: Icon(Icons.person_rounded,
              size: radius * 0.9, color: Colors.white38),
        );
      },
    );
  }

  Widget _buildFormatStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
      ],
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
              decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
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
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(8)),
                            child: Text('${track.playCount}x', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTracksPageBody() {
    if (!_hasPermission && _songs.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: () => _requestPermissionsAndInitBackground(userTriggered: true),
          child: const Text('Grant Storage Permission'),
        ),
      );
    }
    if (_isScanning) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                    onPressed: _shufflePlay,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    onPressed: () {
                      if (_filteredSongs.isNotEmpty) _playSong(_filteredSongs.first);
                    },
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16)),
                    child: Text('${_songs.length} tracks', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.sort_rounded, size: 20),
                    tooltip: 'Reverse Order',
                    onPressed: () {
                      setState(() => _filteredSongs = _filteredSongs.reversed.toList());
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: NamidaFastScroller(
                controller: _trackListScrollController,
                itemCount: _filteredSongs.length,
                labelBuilder: (idx) {
                  final t = _filteredSongs[idx];
                  final letter = t.title.isNotEmpty ? t.title[0].toUpperCase() : '#';
                  return '$letter • ${idx + 1}/${_filteredSongs.length}';
                },
                child: ListView.builder(
                  controller: _trackListScrollController,
                  padding: const EdgeInsets.only(bottom: 95, right: 8),
                  itemCount: _filteredSongs.length,
                  itemBuilder: (context, index) => _buildNamidaTrackTile(_filteredSongs[index]),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 92,
          child: FloatingActionButton.small(
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _locateActivePlayingTrack,
            child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
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
          final clean = rawPart.trim();
          if (clean.isNotEmpty && seenForSong.add(clean.toLowerCase())) {
            artistGroups.putIfAbsent(clean, () => []).add(song);
          }
        }
      } else {
        artistGroups.putIfAbsent(song.artist, () => []).add(song);
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
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                onPressed: _shufflePlay,
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                onPressed: () {
                  if (uniqueArtists.isNotEmpty) {
                    _playSong(artistGroups[uniqueArtists.first]!.first);
                  }
                },
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16)),
                child: Text('${uniqueArtists.length} artists', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Spacer(),
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
          child: NamidaFastScroller(
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
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 95),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.92,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 6,
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
                        child: Column(
                          children: [
                            Expanded(child: _buildRoundArtistAvatar(firstArtTrack, 40)),
                            const SizedBox(height: 6),
                            Text(aName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('${aTracks.length} tracks', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
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
                      return ListTile(
                        leading: _buildRoundArtistAvatar(firstArtTrack, 24),
                        title: Text(aName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('$albumCount albums • ${aTracks.length} tracks', style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                        onTap: () => _showArtistDetailScreen(aName, aTracks),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNamidaTrackTile(AudioTrack song) {
    final isCurrent = _currentSong?.path == song.path;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 1.5, 4, 1.5),
      decoration: BoxDecoration(
        color: isCurrent ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : const Color(0xFF0C0C12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Dismissible(
        key: Key('${song.path}_${song.hashCode}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 22),
        ),
        confirmDismiss: (direction) async {
          setState(() => _playNextQueue.add(song));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queued "${song.title}" to play next')));
          return false;
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _playSong(song),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              children: [
                _buildCoverArt(song, 48, 8),
                const SizedBox(width: 12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${song.album} • Plays: ${song.playCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(namiFormatDurationPadded(song.duration), style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
        return GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < 0) {
                _playNextTrack();
              } else if (details.primaryVelocity! > 0) {
                _playPrevTrack();
              }
            }
          },
          onTap: _showNowPlayingScreen,
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _forceMiniColor ? Color.alphaBlend(accent.withOpacity(0.22), const Color(0xFF12121A)) : const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _forceMiniColor ? accent.withOpacity(0.45) : Colors.white12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.85), blurRadius: 18, spreadRadius: 4)],
            ),
            child: Row(
              children: [
                if (activeSong != null)
                  Hero(
                    tag: 'album_art_${activeSong.path}',
                    child: _buildCoverArt(activeSong, 48, 8),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.album_rounded, size: 30, color: Colors.white54),
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
                      Text(
                        activeSong?.artist ?? '24-bit / Lossless Ready',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (ctx, snap) {
                    final playing = snap.data?.playing ?? _audioPlayer.playing;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 24), onPressed: _playPrevTrack),
                        IconButton(
                          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                          onPressed: () {
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
                        ),
                        IconButton(icon: const Icon(Icons.skip_next_rounded, size: 24), onPressed: _playNextTrack),
                      ],
                    );
                  },
                ),
              ],
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
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: const Color(0xFF07070B),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => NowPlayingModal(
          audioPlayer: _audioPlayer,
          currentSongNotifier: _currentSongNotifier,
          allSongs: _songs,
          playNextQueue: _playNextQueue,
          ambientGlow: _ambientGlow,
          syllableLyricsEnabled: _syllableLyricsEnabled,
          onShowPath: () {
            if (_currentSong != null) _showAudioPathDetails(_currentSong!);
          },
          onShowEqualizer: _showEqualizerSheet,
          onShowSleepTimer: _showSleepTimerDialog,
          onOpenLyricsManager: () {
            if (_currentSong != null) _showNamidaLyricsManagerSheet(_currentSong!);
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _showArtistDetailScreen(String artistName, List<AudioTrack> artistTracks) {
    if (artistTracks.isEmpty) return;
    final firstArtTrack = artistTracks.firstWhere(
      (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
      orElse: () => artistTracks.first,
    );
    final Map<String, List<AudioTrack>> albumsMap = {};
    int totalSeconds = 0;
    for (var s in artistTracks) {
      albumsMap.putIfAbsent(s.album, () => []).add(s);
      totalSeconds += s.duration.inSeconds;
    }
    final formattedTotal = namiFormatTotalDurationHoursMins(Duration(seconds: totalSeconds));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: 'Play Artist',
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () => _playSong(artistTracks.first),
              ),
              IconButton(
                tooltip: 'Shuffle Artist',
                icon: const Icon(Icons.shuffle_rounded),
                onPressed: () {
                  final shuffled = List<AudioTrack>.from(artistTracks)..shuffle();
                  if (shuffled.isNotEmpty) _playSong(shuffled.first);
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 140),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildRoundArtistAvatar(firstArtTrack, 50),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(artistName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('${artistTracks.length} Tracks • $formattedTotal', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Albums (${albumsMap.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      children: albumsMap.entries.map((entry) {
                        final albArtTrack = entry.value.firstWhere(
                          (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
                          orElse: () => entry.value.first,
                        );
                        return GestureDetector(
                          onTap: () => _showAlbumDetailScreen(entry.key, entry.value),
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCoverArt(albArtTrack, 90, 8),
                                const SizedBox(height: 4),
                                Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('${entry.value.length} tracks', style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Songs (${artistTracks.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  ...artistTracks.map((song) => _buildNamidaTrackTile(song)),
                ],
              ),
              Positioned(left: 10, right: 10, bottom: 12, child: _buildReactiveMiniPlayer()),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlbumDetailScreen(String albumName, List<AudioTrack> albumTracks) {
    if (albumTracks.isEmpty) return;
    final firstTrack = albumTracks.first;
    final artTrack = albumTracks.firstWhere(
      (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
      orElse: () => firstTrack,
    );
    final totalSecs = albumTracks.fold<int>(0, (sum, s) => sum + s.duration.inSeconds);
    final totalDurText = namiFormatTotalDurationHoursMins(Duration(seconds: totalSecs));
    final accent = Theme.of(context).colorScheme.primary;

    Navigator.push(
      context,
      MaterialPageRoute(
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(albumName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _showArtistDetailScreen(
                                  firstTrack.artist,
                                  _songs.where((s) => s.artist.contains(firstTrack.artist)).toList(),
                                ),
                                child: Text(
                                  firstTrack.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: accent),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${albumTracks.length} Tracks • $totalDurText • ${firstTrack.year}',
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
                  ...albumTracks.map((song) => _buildNamidaTrackTile(song)),
                ],
              ),
              Positioned(left: 10, right: 10, bottom: 12, child: _buildReactiveMiniPlayer()),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilteredListScreen(String title, List<AudioTrack> tracks) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(title),
            actions: [
              if (tracks.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.shuffle_rounded),
                  onPressed: () {
                    final sh = List<AudioTrack>.from(tracks)..shuffle();
                    _playSong(sh.first);
                  },
                ),
            ],
          ),
          body: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 140),
                itemCount: tracks.length,
                itemBuilder: (ctx, i) => _buildNamidaTrackTile(tracks[i]),
              ),
              Positioned(left: 10, right: 10, bottom: 12, child: _buildReactiveMiniPlayer()),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildNamidaPlaylistsPage() {
    final accent = Theme.of(context).colorScheme.primary;
    final favSongs = _songs.where((s) => s.isFavorite).toList();
    final mostPlayed = List<AudioTrack>.from(_songs)..sort((a, b) => b.playCount.compareTo(a.playCount));
    final recentlyAdded = List<AudioTrack>.from(_songs)..sort((a, b) => b.addedTimestampMs.compareTo(a.addedTimestampMs));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.shuffle_rounded, size: 20), onPressed: _shufflePlay),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              onPressed: () {
                if (favSongs.isNotEmpty) {
                  _playSong(favSongs.first);
                } else if (_songs.isNotEmpty) {
                  _playSong(_songs.first);
                }
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16)),
              child: Text('${_customPlaylists.length + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              onPressed: _showCreatePlaylistDialog,
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.95,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildHomeSmartTile(
              icon: Icons.shuffle_rounded,
              title: 'Shuffle All',
              subtitle: '${_songs.length} tracks',
              color: Colors.greenAccent,
              onTap: _shufflePlay,
            ),
            _buildHomeSmartTile(
              icon: Icons.history_rounded,
              title: 'History',
              subtitle: '${_historyTracks.length} played',
              color: Colors.purpleAccent,
              onTap: () => _showFilteredListScreen('Play History', _historyTracks),
            ),
            _buildHomeSmartTile(
              icon: Icons.favorite_rounded,
              title: 'Favorites',
              subtitle: '${favSongs.length} tracks',
              color: accent,
              onTap: () => _showFilteredListScreen('Favorites', favSongs),
            ),
            _buildHomeSmartTile(
              icon: Icons.local_fire_department_rounded,
              title: 'Most Played',
              subtitle: 'Top rotation',
              color: Colors.orangeAccent,
              onTap: () => _showFilteredListScreen('Most Played', mostPlayed.take(50).toList()),
            ),
            _buildHomeSmartTile(
              icon: Icons.new_releases_rounded,
              title: 'Recently Added',
              subtitle: 'Latest imports',
              color: Colors.cyanAccent,
              onTap: () => _showFilteredListScreen('Recently Added', recentlyAdded.take(50).toList()),
            ),
            _buildHomeSmartTile(
              icon: Icons.folder_open_rounded,
              title: 'Folders',
              subtitle: 'Browse storage',
              color: Colors.amberAccent,
              onTap: _showFolderExplorerModal,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Your Playlists', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        _buildPlaylistCardTile(
          title: 'Liked Songs',
          subtitle: '${favSongs.length} tracks',
          icon: Icons.favorite_rounded,
          coverTrack: favSongs.isNotEmpty ? favSongs.first : null,
          onTap: () => _showFilteredListScreen('Liked Songs', favSongs),
          onPlay: () {
            if (favSongs.isNotEmpty) _playSong(favSongs.first);
          },
        ),
        ..._customPlaylists.map((p) => _buildPlaylistCardTile(
              title: p.name,
              subtitle: '${p.tracks.length} tracks',
              icon: Icons.queue_music_rounded,
              coverTrack: p.tracks.isNotEmpty ? p.tracks.first : null,
              onTap: () => _showFilteredListScreen(p.name, p.tracks),
              onPlay: () {
                if (p.tracks.isNotEmpty) _playSong(p.tracks.first);
              },
            )),
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
                decoration: BoxDecoration(color: accent.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accent, size: 24),
              ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_fill_rounded, size: 30, color: Colors.white70),
          onPressed: onPlay,
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
      _buildNamidaHomeScreen(uniqueArtistsForHome),
      _buildTracksPageBody(),
      _buildArtistsPageBody(),
      _buildNamidaPlaylistsPage(),
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mornye Catalog & Extensions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.extension_rounded, size: 16),
                label: const Text('Repo'),
                onPressed: _openExtensionRepoScreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _mornyeServices
                  .map((srv) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(srv, style: const TextStyle(fontSize: 11.5)),
                          selected: _selectedMornyeService == srv,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          onSelected: (_) => setState(() => _selectedMornyeService = srv),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mornyeSearchController,
            onSubmitted: _searchMornyeCatalog,
            decoration: InputDecoration(
              hintText: 'Search $_selectedMornyeService catalog...',
              filled: true,
              fillColor: const Color(0xFF14141F),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => _searchMornyeCatalog(_mornyeSearchController.text),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_isMornyeSearching)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)))
          else
            ..._mornyeResults.map((item) => ListTile(
                  leading: item.artworkUrl != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item.artworkUrl!, width: 46, height: 46, fit: BoxFit.cover))
                      : const Icon(Icons.music_note_rounded),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('${item.artist} • ${item.subtitle}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  trailing: _downloadingTitles.contains(item.title)
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.download_rounded),
                          onPressed: () => _downloadMornyeItem(item),
                        ),
                )),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
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
            : Text(tabTitles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
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
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings),
        ],
      ),
      body: Stack(
        children: [
          pages[_selectedIndex],
          Positioned(left: 10, right: 10, bottom: 8, child: _buildReactiveMiniPlayer()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF07070B),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'Tracks'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Artists'),
          NavigationDestination(icon: Icon(Icons.playlist_play_rounded), selectedIcon: Icon(Icons.playlist_add_check_rounded), label: 'Playlists'),
          NavigationDestination(icon: Icon(Icons.extension_outlined), selectedIcon: Icon(Icons.extension_rounded), label: 'Mornye'),
        ],
      ),
    );
  }
}
