import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class NamiSmartRulePlaylist {
  String id;
  String name;
  String formatFilter;
  String genreContains;
  int addedWithinDays;
  int maxPlayCount;
  String excludeArtists;

  NamiSmartRulePlaylist({
    required this.id,
    required this.name,
    this.formatFilter = 'All',
    this.genreContains = '',
    this.addedWithinDays = 0,
    this.maxPlayCount = -1,
    this.excludeArtists = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'formatFilter': formatFilter,
        'genreContains': genreContains,
        'addedWithinDays': addedWithinDays,
        'maxPlayCount': maxPlayCount,
        'excludeArtists': excludeArtists,
      };

  factory NamiSmartRulePlaylist.fromJson(Map<String, dynamic> j) =>
      NamiSmartRulePlaylist(
        id: (j['id'] ?? '${DateTime.now().millisecondsSinceEpoch}').toString(),
        name: (j['name'] ?? 'Smart Mix').toString(),
        formatFilter: (j['formatFilter'] ?? 'All').toString(),
        genreContains: (j['genreContains'] ?? '').toString(),
        addedWithinDays: (j['addedWithinDays'] as num?)?.toInt() ?? 0,
        maxPlayCount: (j['maxPlayCount'] as num?)?.toInt() ?? -1,
        excludeArtists: (j['excludeArtists'] ?? '').toString(),
      );

  String describeRules() {
    final parts = <String>[];
    if (formatFilter != 'All') parts.add(formatFilter);
    if (genreContains.trim().isNotEmpty) parts.add('Genre: ${genreContains.trim()}');
    if (addedWithinDays > 0) parts.add('Last ${addedWithinDays}d');
    if (maxPlayCount == 0) {
      parts.add('Unplayed');
    } else if (maxPlayCount > 0) {
      parts.add('<= $maxPlayCount plays');
    }
    if (excludeArtists.trim().isNotEmpty) parts.add('Excl: ${excludeArtists.trim()}');
    return parts.isEmpty ? 'All library tracks' : parts.join(' • ');
  }
}

class NamiV16Prefs {
  NamiV16Prefs._();
  static final NamiV16Prefs instance = NamiV16Prefs._();

  static const String _kStore = 'nami_v16_all_prefs_json';

  static const List<String> defaultHomeShelves = [
    'recap',
    'continue',
    'time_mix',
    'jump_back',
    'heavy_rotation',
    'top_albums',
    'spotlight',
    'freshly_added',
    'featured_artists',
  ];

  static const Map<String, String> shelfLabels = {
    'recap': 'Weekly Recap Strip',
    'continue': 'Continue Listening',
    'time_mix': 'Time-of-Day & Rediscover Mixes',
    'jump_back': 'Jump Back In',
    'heavy_rotation': 'Heavy Rotation',
    'top_albums': 'Top Albums',
    'spotlight': 'Artist Spotlight',
    'freshly_added': 'Freshly Added',
    'featured_artists': 'Featured Artists',
  };

  List<String> homeShelvesOrder = List<String>.from(defaultHomeShelves);
  Set<String> hiddenHomeShelves = {};
  String dismissedRecapWeekKey = '';

  String trackSortBy = 'title';
  bool trackSortAsc = true;
  String swipeRightAction = 'favorite';
  String swipeLeftAction = 'play_next';

  Map<String, String> artistAliases = {};

  List<NamiSmartRulePlaylist> smartPlaylists = [];
  Set<String> pinnedPlaylists = {};
  Map<String, String> playlistDescriptions = {};
  Map<String, String> playlistCustomCovers = {};
  bool autoSyncPlaylistsM3u8 = false;

  String mornyePathTemplate = '{Artist}/{Album}/{Track} - {Title}';
  int mornyeMaxConcurrent = 2;
  bool mornyeWifiOnly = false;
  String mornyePreferredQuality = '24B FLAC';

  String audioModePreset = 'bit_perfect';

  String currentWeekKey() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final week = (dayOfYear ~/ 7) + 1;
    return '${now.year}-W$week';
  }

  String resolveCanonicalArtist(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return trimmed;
    final mapped = artistAliases[trimmed.toLowerCase()];
    return (mapped != null && mapped.trim().isNotEmpty) ? mapped.trim() : trimmed;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStore);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      applyFromMap(Map<String, dynamic>.from(data));
    } catch (_) {}
  }

  void applyFromMap(Map<String, dynamic> data) {
    if (data['homeShelvesOrder'] is List) {
      final list = List<String>.from(data['homeShelvesOrder']);
      for (final d in defaultHomeShelves) {
        if (!list.contains(d)) list.add(d);
      }
      homeShelvesOrder = list.where((k) => shelfLabels.containsKey(k)).toList();
    }
    if (data['hiddenHomeShelves'] is List) {
      hiddenHomeShelves = Set<String>.from(data['hiddenHomeShelves']);
    }
    dismissedRecapWeekKey = (data['dismissedRecapWeekKey'] ?? '').toString();
    trackSortBy = (data['trackSortBy'] ?? 'title').toString();
    trackSortAsc = data['trackSortAsc'] != false;
    swipeRightAction = (data['swipeRightAction'] ?? 'favorite').toString();
    swipeLeftAction = (data['swipeLeftAction'] ?? 'play_next').toString();

    if (data['artistAliases'] is Map) {
      artistAliases = {};
      (data['artistAliases'] as Map).forEach((k, v) {
        if (k != null && v != null) {
          artistAliases[k.toString().toLowerCase()] = v.toString();
        }
      });
    }
    if (data['smartPlaylists'] is List) {
      smartPlaylists = (data['smartPlaylists'] as List)
          .whereType<Map>()
          .map((e) => NamiSmartRulePlaylist.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data['pinnedPlaylists'] is List) {
      pinnedPlaylists = Set<String>.from(data['pinnedPlaylists']);
    }
    if (data['playlistDescriptions'] is Map) {
      playlistDescriptions = Map<String, String>.from(data['playlistDescriptions']);
    }
    if (data['playlistCustomCovers'] is Map) {
      playlistCustomCovers = Map<String, String>.from(data['playlistCustomCovers']);
    }
    autoSyncPlaylistsM3u8 = data['autoSyncPlaylistsM3u8'] == true;
    mornyePathTemplate = (data['mornyePathTemplate'] ?? '{Artist}/{Album}/{Track} - {Title}').toString();
    mornyeMaxConcurrent = ((data['mornyeMaxConcurrent'] as num?)?.toInt() ?? 2).clamp(1, 3);
    mornyeWifiOnly = data['mornyeWifiOnly'] == true;
    mornyePreferredQuality = (data['mornyePreferredQuality'] ?? '24B FLAC').toString();
    audioModePreset = (data['audioModePreset'] ?? 'bit_perfect').toString();
  }

  Map<String, dynamic> toMap() => {
        'homeShelvesOrder': homeShelvesOrder,
        'hiddenHomeShelves': hiddenHomeShelves.toList(),
        'dismissedRecapWeekKey': dismissedRecapWeekKey,
        'trackSortBy': trackSortBy,
        'trackSortAsc': trackSortAsc,
        'swipeRightAction': swipeRightAction,
        'swipeLeftAction': swipeLeftAction,
        'artistAliases': artistAliases,
        'smartPlaylists': smartPlaylists.map((p) => p.toJson()).toList(),
        'pinnedPlaylists': pinnedPlaylists.toList(),
        'playlistDescriptions': playlistDescriptions,
        'playlistCustomCovers': playlistCustomCovers,
        'autoSyncPlaylistsM3u8': autoSyncPlaylistsM3u8,
        'mornyePathTemplate': mornyePathTemplate,
        'mornyeMaxConcurrent': mornyeMaxConcurrent,
        'mornyeWifiOnly': mornyeWifiOnly,
        'mornyePreferredQuality': mornyePreferredQuality,
        'audioModePreset': audioModePreset,
      };

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStore, jsonEncode(toMap()));
    } catch (_) {}
  }

  Future<void> resetSection(String section) async {
    if (section == 'home') {
      homeShelvesOrder = List<String>.from(defaultHomeShelves);
      hiddenHomeShelves.clear();
      dismissedRecapWeekKey = '';
    } else if (section == 'tracks') {
      trackSortBy = 'title';
      trackSortAsc = true;
      swipeRightAction = 'favorite';
      swipeLeftAction = 'play_next';
    } else if (section == 'mornye') {
      mornyePathTemplate = '{Artist}/{Album}/{Track} - {Title}';
      mornyeMaxConcurrent = 2;
      mornyeWifiOnly = false;
      mornyePreferredQuality = '24B FLAC';
    } else if (section == 'audio') {
      audioModePreset = 'bit_perfect';
    }
    await save();
  }

  Future<String> writePortableBackup(Map<String, dynamic> extraPayload) async {
    final outFile = File('/storage/emulated/0/Download/nami_full.nami-backup');
    final bundle = {
      'format': 'nami-backup-v16',
      'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
      'v16Prefs': toMap(),
      ...extraPayload,
    };
    await outFile.writeAsString(jsonEncode(bundle));
    return outFile.path;
  }

  Future<Map<String, dynamic>?> readPortableBackup() async {
    for (final path in [
      '/storage/emulated/0/Download/nami_full.nami-backup',
      '/storage/emulated/0/Download/nami_backup.json',
    ]) {
      final f = File(path);
      if (await f.exists()) {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (map['v16Prefs'] is Map) {
            applyFromMap(Map<String, dynamic>.from(map['v16Prefs']));
            await save();
          }
          return map;
        }
      }
    }
    return null;
  }
}
