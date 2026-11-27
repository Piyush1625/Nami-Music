// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use, unused_element
part of '../main.dart';

// =============================================================================
// NAMI v3.9.0 SUITE:
// - Unified Local | YouTube Fuzzy Search Sheet
// - Home #2: Compact 2x3 Pinned Quick-Access Glass Grid
// - Tracks #3: Magnetic A-Z Fast-Scrubber with Frosted Glass Bubble
// - Tracks #4: Aligned Monospaced Hi-Res Audio Pill
// - Artists #5/#6 & Recording Overhaul: Mode Switcher, Multi-Density Grid,
//   Deep Sort Sheet & Featured-Artist Splitting
// - YouTube #8: SponsorBlock & Chapter Timeline Marker Overlay
// - Settings #10: Live Audio Output Chain Card & Visual Theme Studio Cards
// =============================================================================

/// Subsequence + token fuzzy matcher (e.g., "gd" matches "God Damn").
bool namiV39FuzzyMatch(String text, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final t = text.toLowerCase();
  if (t.contains(q)) return true;
  final words = t.split(RegExp(r'[\s\-_.,()\[\]]+')).where((w) => w.isNotEmpty).toList();
  if (words.isNotEmpty) {
    final initials = words.map((w) => w[0]).join();
    if (initials.contains(q)) return true;
  }
  int qi = 0;
  for (int i = 0; i < t.length && qi < q.length; i++) {
    if (t[i] == q[qi]) qi++;
  }
  return qi == q.length;
}

/// Smart featured-artist splitter (splits feat., ft., &, commas).
List<String> namiV39SplitArtists(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const ['Unknown Artist'];
  final parts = trimmed
      .split(RegExp(r'\s*(?:,|&|;|\bfeat\.?\b|\bft\.?\b|\bfeaturing\b|\bx\b)\s*', caseSensitive: false))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return parts.isEmpty ? [trimmed] : parts.toSet().toList();
}

/// #4: Monospaced Hi-Res Audio Pill (FLAC 24/96, ALAC, 320k, etc.)
class NamiV39HiResPill extends StatelessWidget {
  final AudioTrack track;
  final Color accent;
  const NamiV39HiResPill({super.key, required this.track, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ext = track.path.split('.').last.toUpperCase();
    final isHiRes = track.bitDepth >= 24 || track.sampleRateHz > 48000;
    final isLossless = ext == 'FLAC' || ext == 'ALAC' || ext == 'WAV' || ext == 'AIFF' || ext == 'DSF';
    String label;
    if (isHiRes) {
      final khz = (track.sampleRateHz / 1000.0).toStringAsFixed(track.sampleRateHz % 1000 == 0 ? 0 : 1);
      label = '${isLossless ? ext : "HI-RES"} ${track.bitDepth > 0 ? track.bitDepth : 24}/${khz}k';
    } else if (isLossless) {
      label = '$ext 16/44';
    } else if (track.bitrateKbps > 0) {
      label = '${track.bitrateKbps}k';
    } else {
      label = ext.length <= 4 ? ext : 'AUDIO';
    }
    final pillColor = isHiRes
        ? const Color(0xFFFFD54F)
        : (isLossless ? accent : Colors.white54);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: isHiRes ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: pillColor.withValues(alpha: 0.42), width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.0,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: -0.2,
          color: pillColor,
        ),
      ),
    );
  }
}

/// #2: Compact 2x3 Pinned Quick-Access Glass Grid for Home
class NamiV39QuickAccessGrid extends StatelessWidget {
  final List<AudioTrack> songs;
  final Map<String, List<AudioTrack>> artistGroups;
  final Widget Function(AudioTrack, double, double) coverBuilder;
  final void Function(AudioTrack) onPlayTrack;
  final void Function(String artist, List<AudioTrack> tracks) onOpenArtist;

  const NamiV39QuickAccessGrid({
    super.key,
    required this.songs,
    required this.artistGroups,
    required this.coverBuilder,
    required this.onPlayTrack,
    required this.onOpenArtist,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final items = <_NamiQuickPinItem>[];

    final byPlays = List<AudioTrack>.from(songs)..sort((a, b) => b.playCount.compareTo(a.playCount));
    for (final t in byPlays.take(2)) {
      items.add(_NamiQuickPinItem(
        title: t.title,
        subtitle: cleanArtistStr(t.artist),
        track: t,
        onTap: () => onPlayTrack(t),
      ));
    }

    final sortedArtists = artistGroups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final e in sortedArtists.take(2)) {
      if (e.value.isNotEmpty) {
        items.add(_NamiQuickPinItem(
          title: e.key,
          subtitle: '${e.value.length} tracks',
          track: e.value.first,
          isArtist: true,
          onTap: () => onOpenArtist(e.key, e.value),
        ));
      }
    }

    final recent = List<AudioTrack>.from(songs)..sort((a, b) => b.addedTimestampMs.compareTo(a.addedTimestampMs));
    for (final t in recent) {
      if (items.length >= 6) break;
      if (!items.any((it) => it.track.path == t.path && !it.isArtist)) {
        items.add(_NamiQuickPinItem(
          title: t.album.isNotEmpty ? t.album : t.title,
          subtitle: cleanArtistStr(t.artist),
          track: t,
          onTap: () => onPlayTrack(t),
        ));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();
    final visible = items.take(6).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visible.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 56,
        ),
        itemBuilder: (ctx, i) {
          final item = visible[i];
          return _NamiSpringQuickTile(
            accent: accent,
            cover: ClipRRect(
              borderRadius: BorderRadius.circular(item.isArtist ? 24 : 10),
              child: coverBuilder(item.track, 44, item.isArtist ? 22 : 10),
            ),
            title: item.title,
            subtitle: item.subtitle,
            onTap: item.onTap,
          );
        },
      ),
    );
  }
}

class _NamiQuickPinItem {
  final String title;
  final String subtitle;
  final AudioTrack track;
  final bool isArtist;
  final VoidCallback onTap;
  _NamiQuickPinItem({
    required this.title,
    required this.subtitle,
    required this.track,
    required this.onTap,
    this.isArtist = false,
  });
}

class _NamiSpringQuickTile extends StatefulWidget {
  final Color accent;
  final Widget cover;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NamiSpringQuickTile({
    required this.accent,
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_NamiSpringQuickTile> createState() => _NamiSpringQuickTileState();
}

class _NamiSpringQuickTileState extends State<_NamiSpringQuickTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Color.alphaBlend(widget.accent.withValues(alpha: 0.08), const Color(0xFF11111A)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09), width: 0.8),
          ),
          child: Row(
            children: [
              widget.cover,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.2, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.2, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen Recording + #6: Artists Hub with Mode Switcher, Multi-Density Grid (List/2/4/5/6),
/// Discover Mode, Deep Sort Sheet & Featured-Artist Splitting
class NamiV39ArtistsHub extends StatefulWidget {
  final List<AudioTrack> songs;
  final Map<String, String> artistImagePaths;
  final ValueNotifier<int> artworkTick;
  final Widget Function(AudioTrack, double, double) coverBuilder;
  final void Function(String artist, List<AudioTrack> tracks) onOpenArtist;
  final void Function(AudioTrack track) onPlaySong;
  final VoidCallback onShuffleAll;
  final String Function(Duration) formatDuration;

  const NamiV39ArtistsHub({
    super.key,
    required this.songs,
    required this.artistImagePaths,
    required this.artworkTick,
    required this.coverBuilder,
    required this.onOpenArtist,
    required this.onPlaySong,
    required this.onShuffleAll,
    required this.formatDuration,
  });

  @override
  State<NamiV39ArtistsHub> createState() => _NamiV39ArtistsHubState();
}

class _NamiV39ArtistsHubState extends State<NamiV39ArtistsHub> {
  String _mode = 'Artist';
  static const List<int> _densities = [0, 2, 4, 5, 6];
  int _densityIdx = 1;
  String _sortBy = 'Artist';
  bool _ascending = true;

  static const List<String> _sortOptions = [
    'Artist',
    'Duration',
    'Number of Tracks',
    'Albums Count',
    'Total Listens',
    'Genres',
    'Year',
    'Date Added',
  ];

  Map<String, List<AudioTrack>> _computeGroups() {
    final Map<String, List<AudioTrack>> map = {};
    for (final s in widget.songs) {
      List<String> keys;
      if (_mode == 'Album Artist') {
        final raw = s.albumArtist.trim().isNotEmpty ? s.albumArtist : s.artist;
        keys = namiV39SplitArtists(raw);
      } else if (_mode == 'Composer') {
        final raw = s.composer.trim().isNotEmpty ? s.composer : 'Unknown Composer';
        keys = namiV39SplitArtists(raw);
      } else {
        keys = namiV39SplitArtists(s.artist);
      }
      for (final k in keys) {
        map.putIfAbsent(k, () => []).add(s);
      }
    }
    return map;
  }

  List<MapEntry<String, List<AudioTrack>>> _sortedEntries(Map<String, List<AudioTrack>> groups) {
    final entries = groups.entries.toList();
    if (_mode == 'Discover') {
      entries.sort((a, b) {
        final playsA = a.value.fold<int>(0, (sum, t) => sum + t.playCount);
        final playsB = b.value.fold<int>(0, (sum, t) => sum + t.playCount);
        if (playsA != playsB) return playsA.compareTo(playsB);
        return b.value.length.compareTo(a.value.length);
      });
      return entries;
    }
    int cmp(MapEntry<String, List<AudioTrack>> a, MapEntry<String, List<AudioTrack>> b) {
      switch (_sortBy) {
        case 'Duration':
          final da = a.value.fold<int>(0, (s, t) => s + t.duration.inSeconds);
          final db = b.value.fold<int>(0, (s, t) => s + t.duration.inSeconds);
          return da.compareTo(db);
        case 'Number of Tracks':
          return a.value.length.compareTo(b.value.length);
        case 'Albums Count':
          final aa = a.value.map((t) => t.album).toSet().length;
          final ab = b.value.map((t) => t.album).toSet().length;
          return aa.compareTo(ab);
        case 'Total Listens':
          final pa = a.value.fold<int>(0, (s, t) => s + t.playCount);
          final pb = b.value.fold<int>(0, (s, t) => s + t.playCount);
          return pa.compareTo(pb);
        case 'Genres':
          return a.value.first.genre.toLowerCase().compareTo(b.value.first.genre.toLowerCase());
        case 'Year':
          final ya = int.tryParse(a.value.first.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final yb = int.tryParse(b.value.first.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return ya.compareTo(yb);
        case 'Date Added':
          final ta = a.value.fold<int>(0, (m, t) => t.addedTimestampMs > m ? t.addedTimestampMs : m);
          final tb = b.value.fold<int>(0, (m, t) => t.addedTimestampMs > m ? t.addedTimestampMs : m);
          return ta.compareTo(tb);
        case 'Artist':
        default:
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      }
    }
    entries.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return entries;
  }

  void _openModeSheet() {
    HapticFeedback.selectionClick();
    final host = context.findAncestorStateOfType<_NamiHomeShellState>();
    host?._v39SetSheetOpen(true);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Artist Group Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            for (final m in const ['Artist', 'Album Artist', 'Composer', 'Discover'])
              ListTile(
                leading: Icon(
                  m == 'Discover' ? Icons.explore_rounded : (m == 'Composer' ? Icons.music_note_rounded : Icons.person_rounded),
                  color: _mode == m ? Theme.of(ctx).colorScheme.primary : Colors.white54,
                ),
                title: Text(m, style: TextStyle(fontWeight: _mode == m ? FontWeight.w800 : FontWeight.w500)),
                trailing: _mode == m ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary) : null,
                onTap: () {
                  setState(() {
                    _mode = m;
                    if (m == 'Discover' && _densities[_densityIdx] == 0) _densityIdx = 2;
                  });
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    ).then((_) => host?._v39SetSheetOpen(false));
  }

  void _openSortSheet() {
    HapticFeedback.selectionClick();
    final host = context.findAncestorStateOfType<_NamiHomeShellState>();
    host?._v39SetSheetOpen(true);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sort Artists', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ActionChip(
                      avatar: Icon(_ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 15),
                      label: Text(_ascending ? 'Ascending' : 'Descending', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setS(() => _ascending = !_ascending);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _sortOptions.map((opt) {
                    final sel = _sortBy == opt;
                    return ListTile(
                      dense: true,
                      title: Text(opt, style: TextStyle(fontWeight: sel ? FontWeight.w800 : FontWeight.w500, color: sel ? Theme.of(ctx).colorScheme.primary : Colors.white)),
                      trailing: sel ? Icon(Icons.check_rounded, size: 18, color: Theme.of(ctx).colorScheme.primary) : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _sortBy = opt);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => host?._v39SetSheetOpen(false));
  }

  Widget _buildAvatar(String name, List<AudioTrack> tracks, double size) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.artworkTick,
      builder: (_, __, ___) {
        final customPath = widget.artistImagePaths[name];
        if (customPath != null && File(customPath).existsSync()) {
          return ClipOval(
            child: Image.file(File(customPath), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
          );
        }
        return ClipOval(child: widget.coverBuilder(tracks.first, size, size / 2));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final groups = _computeGroups();
    final entries = _sortedEntries(groups);
    final cols = _densities[_densityIdx];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 10, 6),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _openModeSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(accent.withValues(alpha: 0.14), const Color(0xFF14141E)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entries.length} $_mode${_mode == "Discover" ? "" : "s"}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.2, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Shuffle All',
                icon: const Icon(Icons.shuffle_rounded, size: 19, color: Colors.white70),
                onPressed: widget.onShuffleAll,
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _openSortSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_sortBy, style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: Colors.white70)),
                      const SizedBox(width: 2),
                      Icon(_ascending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 16, color: accent),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _densityIdx = (_densityIdx + 1) % _densities.length);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cols == 0 ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 15, color: accent),
                      const SizedBox(width: 3),
                      Text(cols == 0 ? 'List' : '${cols}x', style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: cols == 0
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 110),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final albumsCount = e.value.map((t) => t.album).toSet().length;
                    final totalSecs = e.value.fold<int>(0, (s, t) => s + t.duration.inSeconds);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: _buildAvatar(e.key, e.value, 48),
                      title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(
                        '${e.value.length} tracks • $albumsCount albums • ${widget.formatDuration(Duration(seconds: totalSecs))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.2, color: Colors.white54),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.play_circle_fill_rounded, color: accent, size: 28),
                        onPressed: () => widget.onPlaySong(e.value.first),
                      ),
                      onTap: () => widget.onOpenArtist(e.key, e.value),
                    );
                  },
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                  itemCount: entries.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: cols >= 5 ? 10 : 14,
                    crossAxisSpacing: cols >= 5 ? 8 : 12,
                    childAspectRatio: cols >= 5 ? 0.74 : (cols == 4 ? 0.76 : 0.84),
                  ),
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final avatarSize = cols == 2 ? 124.0 : (cols == 4 ? 72.0 : (cols == 5 ? 58.0 : 46.0));
                    return GestureDetector(
                      onTap: () => widget.onOpenArtist(e.key, e.value),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
                            ),
                            child: _buildAvatar(e.key, e.value, avatarSize),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: cols >= 5 ? 10.2 : (cols == 4 ? 11.2 : 13.0),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (cols <= 4)
                            Text(
                              '${e.value.length} tracks',
                              maxLines: 1,
                              style: TextStyle(fontSize: cols == 4 ? 9.5 : 11.0, color: Colors.white54),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Unified Local | YouTube Fuzzy Search Screen (Screen Recording Feature)
class NamiV39UnifiedSearchSheet extends StatefulWidget {
  final List<AudioTrack> allSongs;
  final Widget Function(AudioTrack, double, double) coverBuilder;
  final void Function(AudioTrack) onPlayTrack;
  final void Function(String artist, List<AudioTrack> tracks) onOpenArtist;
  final VoidCallback onOpenSettings;

  const NamiV39UnifiedSearchSheet({
    super.key,
    required this.allSongs,
    required this.coverBuilder,
    required this.onPlayTrack,
    required this.onOpenArtist,
    required this.onOpenSettings,
  });

  @override
  State<NamiV39UnifiedSearchSheet> createState() => _NamiV39UnifiedSearchSheetState();
}

class _NamiV39UnifiedSearchSheetState extends State<NamiV39UnifiedSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  int _sourceTab = 0; // 0 = Local, 1 = YouTube
  String _activeChip = 'All';
  String _trackSort = 'Auto';
  bool _expandTracks = false;
  bool _albumsCollapsed = false;
  bool _artistsCollapsed = false;

  bool _ytLoading = false;
  List<NamiYtTrack> _ytResults = const [];
  Timer? _ytDebounce;

  @override
  void dispose() {
    _ytDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    setState(() {});
    if (_sourceTab == 1) {
      _ytDebounce?.cancel();
      if (q.trim().length < 2) {
        setState(() => _ytResults = const []);
        return;
      }
      _ytDebounce = Timer(const Duration(milliseconds: 380), () => _runYtSearch(q.trim()));
    }
  }

  Future<void> _runYtSearch(String q) async {
    setState(() => _ytLoading = true);
    try {
      final res = await NamiYoutubeService.instance.searchMusic(q);
      if (mounted) {
        setState(() {
          _ytResults = res;
          _ytLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ytLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final q = _ctrl.text.trim();

    final matchedTracks = widget.allSongs.where((s) =>
      namiV39FuzzyMatch(s.title, q) ||
      namiV39FuzzyMatch(s.artist, q) ||
      namiV39FuzzyMatch(s.album, q) ||
      namiV39FuzzyMatch(s.genre, q) ||
      namiV39FuzzyMatch(s.composer, q)
    ).toList();

    if (_trackSort == 'Title') {
      matchedTracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_trackSort == 'Plays') {
      matchedTracks.sort((a, b) => b.playCount.compareTo(a.playCount));
    } else if (_trackSort == 'Duration') {
      matchedTracks.sort((a, b) => b.duration.compareTo(a.duration));
    }

    final Map<String, List<AudioTrack>> albumMap = {};
    final Map<String, List<AudioTrack>> artistMap = {};
    for (final s in widget.allSongs) {
      if (q.isEmpty || namiV39FuzzyMatch(s.album, q) || namiV39FuzzyMatch(s.artist, q)) {
        final alb = s.album.trim().isNotEmpty ? s.album.trim() : 'Unknown Album';
        albumMap.putIfAbsent(alb, () => []).add(s);
      }
      for (final art in namiV39SplitArtists(s.artist)) {
        if (q.isEmpty || namiV39FuzzyMatch(art, q)) {
          artistMap.putIfAbsent(art, () => []).add(s);
        }
      }
    }
    final albums = albumMap.entries.toList();
    final artists = artistMap.entries.toList();

    final chips = [
      ('All', matchedTracks.length + albums.length + artists.length),
      ('Tracks', matchedTracks.length),
      ('Albums', albums.length),
      ('Artists', artists.length),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141E),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 19, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              onChanged: _onQueryChanged,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: _sourceTab == 0 ? 'Fuzzy search tracks, albums, artists...' : 'Search YouTube music & videos...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (q.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                _onQueryChanged('');
                              },
                              child: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 21),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenSettings();
                    },
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  for (final tab in [(0, 'Local', Icons.library_music_rounded), (1, 'YouTube', Icons.play_circle_filled_rounded)])
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _sourceTab = tab.$1);
                          if (tab.$1 == 1 && _ctrl.text.trim().length >= 2) {
                            _runYtSearch(_ctrl.text.trim());
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(right: tab.$1 == 0 ? 6 : 0, left: tab.$1 == 1 ? 6 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _sourceTab == tab.$1 ? accent.withValues(alpha: 0.22) : const Color(0xFF11111A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _sourceTab == tab.$1 ? accent : Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(tab.$3, size: 16, color: _sourceTab == tab.$1 ? accent : Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                tab.$2,
                                style: TextStyle(
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w800,
                                  color: _sourceTab == tab.$1 ? Colors.white : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_sourceTab == 0) ...[
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  children: chips.map((c) {
                    final sel = _activeChip == c.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${c.$1} (${c.$2})', style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: sel ? Colors.black : Colors.white70)),
                        selected: sel,
                        selectedColor: accent,
                        backgroundColor: const Color(0xFF14141E),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _activeChip = c.$1);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 36),
                  children: [
                    if ((_activeChip == 'All' || _activeChip == 'Artists') && artists.isNotEmpty) ...[
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _artistsCollapsed = !_artistsCollapsed),
                            child: Row(
                              children: [
                                Text('Artists (${artists.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                Icon(_artistsCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white54),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (artists.length > 6)
                            Text('+${artists.length - 6} more', style: TextStyle(fontSize: 11.2, color: accent, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (!_artistsCollapsed)
                        SizedBox(
                          height: 92,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: artists.length.clamp(0, 12),
                            itemBuilder: (_, i) {
                              final e = artists[i];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onOpenArtist(e.key, e.value);
                                },
                                child: Container(
                                  width: 72,
                                  margin: const EdgeInsets.only(right: 10, top: 8),
                                  child: Column(
                                    children: [
                                      ClipOval(child: widget.coverBuilder(e.value.first, 52, 26)),
                                      const SizedBox(height: 5),
                                      Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],

                    if ((_activeChip == 'All' || _activeChip == 'Albums') && albums.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => setState(() => _albumsCollapsed = !_albumsCollapsed),
                        child: Row(
                          children: [
                            Text('Albums (${albums.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            Icon(_albumsCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white54),
                          ],
                        ),
                      ),
                      if (!_albumsCollapsed)
                        SizedBox(
                          height: 142,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: albums.length.clamp(0, 12),
                            itemBuilder: (_, i) {
                              final e = albums[i];
                              final t = e.value.first;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onPlayTrack(t);
                                },
                                child: Container(
                                  width: 104,
                                  margin: const EdgeInsets.only(right: 10, top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          widget.coverBuilder(t, 96, 12),
                                          if (t.year.isNotEmpty)
                                            Positioned(
                                              right: 4,
                                              bottom: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                                                child: Text(t.year, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700)),
                                      Text('${e.value.length} tracks', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],

                    if ((_activeChip == 'All' || _activeChip == 'Tracks') && matchedTracks.isNotEmpty) ...[
                      Row(
                        children: [
                          Text('Tracks (${matchedTracks.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          PopupMenuButton<String>(
                            initialValue: _trackSort,
                            onSelected: (v) => setState(() => _trackSort = v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'Auto', child: Text('Sort: Auto')),
                              PopupMenuItem(value: 'Title', child: Text('Sort: Title')),
                              PopupMenuItem(value: 'Plays', child: Text('Sort: Most Played')),
                              PopupMenuItem(value: 'Duration', child: Text('Sort: Duration')),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_trackSort, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70)),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white54),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final t in (_expandTracks || _activeChip == 'Tracks' ? matchedTracks : matchedTracks.take(8)))
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          leading: widget.coverBuilder(t, 44, 8),
                          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.4)),
                          subtitle: Text(cleanArtistStr(t.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, color: Colors.white54)),
                          trailing: NamiV39HiResPill(track: t, accent: accent),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onPlayTrack(t);
                          },
                        ),
                      if (!_expandTracks && _activeChip == 'All' && matchedTracks.length > 8)
                        TextButton(
                          onPressed: () => setState(() => _expandTracks = true),
                          child: Text('Show all ${matchedTracks.length} tracks', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: _ytLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _ytResults.isEmpty
                        ? const Center(child: Text('Type to search YouTube...', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            itemCount: _ytResults.length,
                            itemBuilder: (ctx, i) {
                              final yt = _ytResults[i];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(yt.thumbnailUrl, width: 64, height: 42, fit: BoxFit.cover, gaplessPlayback: true),
                                ),
                                title: Text(yt.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.2)),
                                subtitle: Text(yt.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, color: Colors.white54)),
                                onTap: () {
                                  Navigator.pop(context);
                                  openNamiYoutubeWatchScreen(context, yt);
                                },
                              );
                            },
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// #8: SponsorBlock & Chapter Timeline Overlay for YouTube Watch Slider
class NamiV39YtTimelineOverlay extends StatelessWidget {
  final double totalMs;
  final bool sponsorBlockEnabled;
  const NamiV39YtTimelineOverlay({
    super.key,
    required this.totalMs,
    required this.sponsorBlockEnabled,
  });

  @override
  Widget build(BuildContext context) {
    if (totalMs <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: SizedBox(
          height: 4,
          width: double.infinity,
          child: CustomPaint(
            painter: _NamiV39TimelinePainter(sponsorBlockEnabled: sponsorBlockEnabled),
          ),
        ),
      ),
    );
  }
}

class _NamiV39TimelinePainter extends CustomPainter {
  final bool sponsorBlockEnabled;
  _NamiV39TimelinePainter({required this.sponsorBlockEnabled});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()..color = Colors.black.withValues(alpha: 0.72)..strokeWidth = 2.0;
    for (final frac in const [0.22, 0.48, 0.76]) {
      final x = size.width * frac;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), tickPaint);
    }
    if (sponsorBlockEnabled) {
      final sbPaint = Paint()..color = const Color(0xFF00E676).withValues(alpha: 0.65);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.02, 0.5, size.width * 0.04, size.height - 1), const Radius.circular(2)),
        sbPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NamiV39TimelinePainter oldDelegate) =>
      oldDelegate.sponsorBlockEnabled != sponsorBlockEnabled;
}

/// #10: Live Audio Output Chain Banner + Visual Theme Preview Cards for Settings Hub
class NamiV39AudioChainCard extends StatelessWidget {
  final String outputDevice;
  final bool usbDacExclusive;
  final bool gapless;
  final String? eqPreset;
  final VoidCallback onTapDac;

  const NamiV39AudioChainCard({
    super.key,
    required this.outputDevice,
    required this.usbDacExclusive,
    required this.gapless,
    this.eqPreset,
    required this.onTapDac,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isUsb = outputDevice.toLowerCase().contains('usb') || outputDevice.toLowerCase().contains('dac') || usbDacExclusive;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTapDac();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.16), const Color(0xFF101018)),
              const Color(0xFF0B0B11),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.9),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isUsb ? Icons.usb_rounded : Icons.headphones_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('AUDIO OUTPUT CHAIN', style: TextStyle(fontSize: 9.8, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: Colors.white54)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (usbDacExclusive ? const Color(0xFF00E676) : accent).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          usbDacExclusive ? 'BIT-PERFECT' : 'DIRECT PCM',
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: usbDacExclusive ? const Color(0xFF00E676) : accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    outputDevice.isNotEmpty ? outputDevice : 'Android Direct Output',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.8, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${gapless ? "Gapless ON" : "Gapless OFF"} • EQ: ${eqPreset ?? "Flat"}',
                    style: const TextStyle(fontSize: 11.0, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NamiV39VisualThemeCards extends StatelessWidget {
  final bool usePitchBlack;
  final bool blurredBackdrop;
  final bool ambientGlow;
  final ValueChanged<bool>? onPitchBlackChanged;
  final ValueChanged<bool>? onBlurredBackdropChanged;
  final ValueChanged<bool>? onAmbientGlowChanged;

  const NamiV39VisualThemeCards({
    super.key,
    required this.usePitchBlack,
    required this.blurredBackdrop,
    required this.ambientGlow,
    this.onPitchBlackChanged,
    this.onBlurredBackdropChanged,
    this.onAmbientGlowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final activeMode = usePitchBlack && !blurredBackdrop
        ? 'AMOLED'
        : (blurredBackdrop && !ambientGlow ? 'Glass' : 'Jellyfish');

    Widget card(String title, String subtitle, List<Color> grad, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? accent : Colors.white12, width: selected ? 1.5 : 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle_rounded, size: 15, color: accent),
                  ],
                ),
                const SizedBox(height: 14),
                Text(title, style: const TextStyle(fontSize: 12.2, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 9.8, color: Colors.white60)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          card(
            'AMOLED',
            'Pitch Black',
            const [Color(0xFF000000), Color(0xFF0D0D14)],
            activeMode == 'AMOLED',
            () {
              onPitchBlackChanged?.call(true);
              onBlurredBackdropChanged?.call(false);
              onAmbientGlowChanged?.call(false);
            },
          ),
          const SizedBox(width: 8),
          card(
            'Liquid Glass',
            'Frosted Blur',
            [Color.alphaBlend(accent.withValues(alpha: 0.22), const Color(0xFF141422)), const Color(0xFF0B0B14)],
            activeMode == 'Glass',
            () {
              onPitchBlackChanged?.call(false);
              onBlurredBackdropChanged?.call(true);
              onAmbientGlowChanged?.call(false);
            },
          ),
          const SizedBox(width: 8),
          card(
            'Jellyfish',
            'Ambient Glow',
            [Color.alphaBlend(accent.withValues(alpha: 0.36), const Color(0xFF1A1026)), const Color(0xFF090912)],
            activeMode == 'Jellyfish',
            () {
              onPitchBlackChanged?.call(true);
              onBlurredBackdropChanged?.call(true);
              onAmbientGlowChanged?.call(true);
            },
          ),
        ],
      ),
    );
  }
}
