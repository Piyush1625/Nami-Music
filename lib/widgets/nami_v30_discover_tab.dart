part of '../main.dart';

/// Smooth pulsing AMOLED shimmer placeholder (`#111119 -> #1D1D29`) for initial YouTube loads.
class _NamiYtShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _NamiYtShimmerBox({
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  State<_NamiYtShimmerBox> createState() => _NamiYtShimmerBoxState();
}

class _NamiYtShimmerBoxState extends State<_NamiYtShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFF12121A),
            const Color(0xFF1F1F2B),
            _ctrl.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _NamiKeepAliveSubTab extends StatefulWidget {
  final Widget child;
  const _NamiKeepAliveSubTab({super.key, required this.child});

  @override
  State<_NamiKeepAliveSubTab> createState() => _NamiKeepAliveSubTabState();
}

class _NamiKeepAliveSubTabState extends State<_NamiKeepAliveSubTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class _NamiDiscoverPillItem {
  final IconData icon;
  final String title;
  final String subLabel;

  const _NamiDiscoverPillItem({
    required this.icon,
    required this.title,
    this.subLabel = '',
  });
}

/// Step 5 (v3.0.0) — Unified 5th Tab (Option A):
/// Combines Nami's YouTube Music experience & Nami's Mornye Extensions inside one
/// 6-item morphing pill bar + nested 120Hz keep-alive `PageView` with boundary handoff.
class NamiDiscoverHubTab extends StatefulWidget {
  final Widget mornyeTab;

  const NamiDiscoverHubTab({
    super.key,
    required this.mornyeTab,
  });

  @override
  State<NamiDiscoverHubTab> createState() => _NamiDiscoverHubTabState();
}

class _NamiDiscoverHubTabState extends State<NamiDiscoverHubTab> {
  static const List<_NamiDiscoverPillItem> _pills = [
    _NamiDiscoverPillItem(icon: Icons.home_outlined, title: 'Home', subLabel: 'Local'),
    _NamiDiscoverPillItem(icon: Icons.music_note_outlined, title: 'Music'),
    _NamiDiscoverPillItem(icon: Icons.extension_outlined, title: 'Mornye', subLabel: 'Ext'),
    _NamiDiscoverPillItem(icon: Icons.people_outline_rounded, title: 'Channels', subLabel: 'Local'),
    _NamiDiscoverPillItem(icon: Icons.queue_music_rounded, title: 'Playlists', subLabel: 'Local'),
    _NamiDiscoverPillItem(icon: Icons.download_for_offline_outlined, title: 'Downloads'),
  ];

  static const List<int> _topRecentDayOptions = [1, 3, 6, 9, 12, 15];
  static const List<String> _musicMoodChips = [
    'Bollywood',
    'Punjabi',
    'DHH',
    'Feel good',
    'Party',
    'Energize',
    'Relax',
    'Romance',
    'Podcasts',
  ];

  late final PageController _subPageCtrl;
  int _subIdx = 0;
  double _leftOverscrollAccum = 0.0;

  // Sub-tab 0: Home (Local)
  int _topRecentDays = 3;

  // Sub-tab 1: Music (YouTube Music InnerTube)
  bool _loadingMusic = true;
  String _activeMusicQuick = 'Home';
  String? _activeMoodChip;
  List<NamiYtShelf> _musicShelves = const [];

  // Sub-tab 3: Channels (Local)
  String? _selectedChannelId;

  // Sub-tab 4: Playlists (Local)
  int _mostPlayedFilterDays = 0; // 0 = All time, 7 = 7 Days, 30 = 30 Days

  // Sub-tab 5: Downloads
  String _dlFilter = 'All'; // 'All' | 'Ongoing' | 'Finished'

  @override
  void initState() {
    NamiYoutubeNavController.onSelectSubTab = _selectSubTab;
    _namiSafeSetNotifier<int>(NamiYoutubeNavController.activeSubTab, _subTabIndex);
    super.initState();
    _subPageCtrl = PageController(initialPage: 0);
    NamiYoutubeStore.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    NamiYoutubeService.warmUpNativeEngine();
    _loadMusicBrowse();
  }

  @override
  void dispose() {
    if (NamiYoutubeNavController.onSelectSubTab == _selectSubTab) {
      NamiYoutubeNavController.onSelectSubTab = null;
    }
    _subPageCtrl.dispose();
    super.dispose();
  }

  void _selectSubTab(int idx) {
    /* v36_1_nav_sync */
    _namiSafeSetNotifier<int>(NamiYoutubeNavController.activeSubTab, idx);
    if (idx == _subIdx) return;
    NamiUxPrefs.hapticLight();
    setState(() => _subIdx = idx);
    final ms = (260 * NamiUxPrefs.motionScale).round().clamp(160, 360);
    _subPageCtrl.animateToPage(
      idx,
      duration: Duration(milliseconds: ms),
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
    );
  }

  Future<void> _loadMusicBrowse({
    String quickLabel = 'Home',
    String browseId = 'FEmusic_home',
    bool forceRefresh = false,
  }) async {
    setState(() {
      _loadingMusic = true;
      _activeMusicQuick = quickLabel;
      _activeMoodChip = null;
    });
    final shelves = await NamiYoutubeService.instance.fetchMusicHomeFeed(
      region: NamiUxPrefs.youtubeRegion,
      browseId: browseId,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _musicShelves = shelves;
      _loadingMusic = false;
    });
  }

  Future<void> _loadMoodTracks(String mood) async {
    NamiUxPrefs.hapticLight();
    setState(() {
      _loadingMusic = true;
      _activeMoodChip = mood;
      _activeMusicQuick = mood;
    });
    final regionTag = NamiUxPrefs.youtubeRegion == 'IN' ? 'India' : '';
    final tracks = await NamiYoutubeService.instance.searchMusic(
      '$mood music hits $regionTag'.trim(),
      region: NamiUxPrefs.youtubeRegion,
      limit: 20,
    );
    if (!mounted) return;
    setState(() {
      _musicShelves = tracks.isEmpty
          ? const []
          : [
              NamiYtShelf(
                title: '$mood Mixes',
                kicker: NamiUxPrefs.youtubeRegion == 'IN' ? 'INDIA MOOD FEED' : 'MOOD FEED',
                isSongMixes: true,
                tracks: tracks,
              ),
            ];
      _loadingMusic = false;
    });
  }

  // ---------------------------------------------------------------------------
  // 6-Item Morphing Pill Bar (matching 127228.png - 127233.png)
  // ---------------------------------------------------------------------------
  Widget _buildMorphingPillBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _pills.length; i++) _buildPillSlot(i),
        ],
      ),
    );
  }

  Widget _buildPillSlot(int idx) {
    final item = _pills[idx];
    final active = _subIdx == idx;

    return Expanded(
      flex: active ? 3 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectSubTab(idx),
        child: AnimatedContainer(
          duration: Duration(milliseconds: (230 * NamiUxPrefs.motionScale).round().clamp(140, 320)),
          curve: const Cubic(0.22, 1.0, 0.36, 1.0),
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: active ? 10 : 4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF23232C) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: Colors.white.withValues(alpha: 0.10), width: 0.8)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 19,
                color: active ? Colors.white : Colors.white60,
              ),
              if (active) ...[
                const SizedBox(width: 7),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      if (item.subLabel.isNotEmpty)
                        Text(
                          item.subLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9.6,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared 16:9 YouTube Card (used in Home Local & Playlists Local)
  // ---------------------------------------------------------------------------
  Widget _build16x9TrackCard(
    NamiYtTrack track, {
    List<NamiYtTrack>? contextList,
    bool showRelative = true,
  }) {
    return NamiSpringTap(
      pressedScale: 0.95,
      onTap: () => openNamiYoutubeWatchScreen(context, track, queue: contextList),
      onLongPress: () => showNamiYtWatchSheet(context, track),
      child: SizedBox(
        width: 158,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  SizedBox(
                    width: 158,
                    height: 90,
                    child: Image.network(
                      track.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF15151E),
                        child: const Icon(Icons.music_note_rounded, color: Colors.white30),
                      ),
                    ),
                  ),
                  if (track.durationLabel.isNotEmpty)
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          track.durationLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1.5),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 10.8),
            ),
            const SizedBox(height: 1.5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    showRelative ? track.relativePlayedLabel : track.viewsText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 10.2),
                  ),
                ),
                if (track.playCount > 0)
                  Text(
                    '${track.playCount}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 0: Home (Local) — Matches Nami 127228.png
  // ---------------------------------------------------------------------------
  Widget _buildHomeLocalTab(Color accent) {
    return const NamiYoutubeConnectedHomeFeed();
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 1: Music — Matches Nami 127229.png (Explore/Charts/Moods/New releases,
  // Genre chips, 4-row horizontally swipeable Song mixes, New releases carousels & Shimmer)
  // ---------------------------------------------------------------------------
  Widget _buildMusicBrowseTab(Color accent) {
    Widget quickNavPill(IconData icon, String label, VoidCallback onTap) {
      final sel = _activeMusicQuick == label;
      return NamiSpringTap(
        pressedScale: 0.94,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? accent.withValues(alpha: 0.18) : const Color(0xFF101016),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? accent.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.08),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: sel ? accent : Colors.white70, size: 16),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: sel ? accent : Colors.white,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: accent,
      backgroundColor: const Color(0xFF14141E),
      onRefresh: () => _loadMusicBrowse(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 160),
        children: [
          // Quick-Nav Pill Row (Explore | Charts | Moods | New releases)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                quickNavPill(Icons.explore_outlined, 'Explore', () => _loadMusicBrowse(quickLabel: 'Explore', browseId: 'FEmusic_explore')),
                const SizedBox(width: 8),
                quickNavPill(Icons.show_chart_rounded, 'Charts', () => _loadMusicBrowse(quickLabel: 'Charts', browseId: 'FEmusic_charts')),
                const SizedBox(width: 8),
                quickNavPill(Icons.mood_rounded, 'Moods', () => _loadMoodTracks('Feel good')),
                const SizedBox(width: 8),
                quickNavPill(Icons.new_releases_outlined, 'New releases', () => _loadMoodTracks('New Releases 2026')),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Genre / Mood Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _musicMoodChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final chip = _musicMoodChips[i];
                final sel = _activeMoodChip == chip;
                return GestureDetector(
                  onTap: () => _loadMoodTracks(chip),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? Colors.white.withValues(alpha: 0.16) : const Color(0xFF0E0E14),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: sel ? Colors.white38 : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Shimmer Loading Skeletons or Live Shelves
          if (_loadingMusic)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _NamiYtShimmerBox(width: 130, height: 18, radius: 6),
                  const SizedBox(height: 14),
                  for (int r = 0; r < 4; r++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: const [
                          _NamiYtShimmerBox(width: 50, height: 50, radius: 10),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _NamiYtShimmerBox(width: 190, height: 13, radius: 5),
                                SizedBox(height: 6),
                                _NamiYtShimmerBox(width: 130, height: 10, radius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  const _NamiYtShimmerBox(width: 140, height: 18, radius: 6),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      _NamiYtShimmerBox(width: 140, height: 140, radius: 14),
                      SizedBox(width: 12),
                      _NamiYtShimmerBox(width: 140, height: 140, radius: 14),
                    ],
                  ),
                ],
              ),
            )
          else if (_musicShelves.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 36),
                  const SizedBox(height: 10),
                  const Text(
                    'Pull down to refresh YouTube Music feed',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            for (final shelf in _musicShelves) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shelf.kicker.isNotEmpty)
                      Text(
                        shelf.kicker.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    Text(
                      shelf.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (shelf.tracks.isNotEmpty)
                _build4RowSongMixesCarousel(shelf.tracks)
              else if (shelf.cards.isNotEmpty)
                _buildSquareCardCarousel(shelf.cards),
              const SizedBox(height: 18),
            ],
        ],
      ),
    );
  }

  /// Nami 127229.png exact 4-row horizontally swipeable `Song mixes` pager!
  Widget _build4RowSongMixesCarousel(List<NamiYtTrack> tracks) {
    final pageCount = (tracks.length / 4).ceil().clamp(1, 6);
    final screenW = MediaQuery.sizeOf(context).width;
    final colW = (screenW * 0.84).clamp(270.0, 360.0);

    return SizedBox(
      height: 266,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: pageCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, pageIdx) {
          final start = pageIdx * 4;
          final slice = tracks.skip(start).take(4).toList();
          return SizedBox(
            width: colW,
            child: Column(
              children: [
                for (final t in slice)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      NamiUxPrefs.hapticLight();
                      openNamiYoutubeWatchScreen(context, t, queue: tracks);
                    },
                    onLongPress: () => showNamiYtWatchSheet(context, t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: Image.network(
                                t.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF161620),
                                  child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2.5),
                                Text(
                                  [
                                    t.artist,
                                    if (t.viewsText.isNotEmpty) t.viewsText,
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 19),
                            onPressed: () => showNamiYtWatchSheet(context, t),
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

  Widget _buildSquareCardCarousel(List<NamiYtCardItem> cards) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final card = cards[i];
          return NamiSpringTap(
            pressedScale: 0.95,
            onTap: () {
              if (card.videoId != null && card.videoId!.isNotEmpty) {
                openNamiYoutubeWatchScreen(context, NamiYtTrack(
                    videoId: card.videoId!,
                    title: card.title,
                    artist: card.subtitle.isNotEmpty ? card.subtitle : 'YouTube Music',
                    thumbnailUrl: card.thumbnailUrl,
                  ),);
              } else {
                _loadMoodTracks(card.title);
              }
            },
            child: SizedBox(
              width: 138,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 138,
                      height: 138,
                      child: Image.network(
                        card.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF161620),
                          child: const Icon(Icons.album_rounded, color: Colors.white30, size: 32),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12.6, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 10.8, height: 1.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 3: Channels (Local) — Account-free subscribed YouTube channels
  // ---------------------------------------------------------------------------
  Widget _buildChannelsLocalTab(Color accent) {
    return ValueListenableBuilder<int>(
      valueListenable: NamiYoutubeStore.instance.revision,
      builder: (_, __, ___) {
        final channels = NamiYoutubeStore.instance.channels;
        final history = NamiYoutubeStore.instance.history;
        final filtered = _selectedChannelId == null
            ? history
            : history
                .where((t) =>
                    t.channelId == _selectedChannelId ||
                    t.artist.toLowerCase().contains(
                          channels
                              .firstWhere(
                                (c) => c.channelId == _selectedChannelId,
                                orElse: () => const NamiYtChannel(
                                  channelId: '',
                                  name: '',
                                  subscribedAtMs: 0,
                                ),
                              )
                              .name
                              .toLowerCase(),
                        ))
                .toList();

        return Column(
          children: [
            // Circular Channel Avatar Filter Strip (`All` + subscribed local channels)
            SizedBox(
              height: 62,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedChannelId = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedChannelId == null
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFF121219),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _selectedChannelId == null
                              ? Colors.white38
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Text(
                        'All',
                        style: TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  for (final ch in channels) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _selectedChannelId = ch.channelId),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                        decoration: BoxDecoration(
                          color: _selectedChannelId == ch.channelId
                              ? accent.withValues(alpha: 0.20)
                              : const Color(0xFF121219),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _selectedChannelId == ch.channelId
                                ? accent.withValues(alpha: 0.65)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF1E1E28),
                              backgroundImage:
                                  ch.avatarUrl.startsWith('http') ? NetworkImage(ch.avatarUrl) : null,
                              child: ch.avatarUrl.startsWith('http')
                                  ? null
                                  : const Icon(Icons.person_rounded, size: 15, color: Colors.white60),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ch.name,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: channels.isEmpty && filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded, color: Colors.white30, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No local channels subscribed yet',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap the ... icon on any YouTube track and hit Subscribe to pin artists & channels here account-free.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            NamiSpringTap(
                              pressedScale: 0.94,
                              onTap: () => openNamiYoutubeSearchScreen(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181820),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Text(
                                  'Search Artists & Channels',
                                  style: TextStyle(color: Colors.white, fontSize: 12.6, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 160),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final t = filtered[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 72,
                              height: 44,
                              child: Image.network(t.thumbnailUrl, fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${t.artist} • ${t.relativePlayedLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 19),
                            onPressed: () => showNamiYtWatchSheet(context, t),
                          ),
                          onTap: () => openNamiYoutubeWatchScreen(context, t, queue: filtered),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 4: Playlists (Local) — Matches Nami 127232.png
  // ---------------------------------------------------------------------------
  Widget _buildPlaylistsLocalTab(Color accent) {
    return ValueListenableBuilder<int>(
      valueListenable: NamiYoutubeStore.instance.revision,
      builder: (_, __, ___) {
        final store = NamiYoutubeStore.instance;
        final hist = store.history;
        final most = store.mostPlayed(
          withinDays: _mostPlayedFilterDays > 0 ? _mostPlayedFilterDays : null,
        );
        final favs = store.favorites;
        final pls = store.playlists;

        return ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 160),
          children: [
            // History
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Colors.white60, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${hist.length} Videos',
                        style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hist.isNotEmpty)
              SizedBox(
                height: 152,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hist.length.clamp(0, 20),
                  separatorBuilder: (_, __) => const SizedBox(width: 11),
                  itemBuilder: (_, i) => _build16x9TrackCard(hist[i], contextList: hist),
                ),
              ),

            // Most Played
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_outlined, color: Colors.white60, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Most Played',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${most.length} Videos',
                        style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                      ),
                    ],
                  ),
                  const Spacer(),
                  for (final pair in const [(0, 'All time'), (7, '7d'), (30, '30d')])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _mostPlayedFilterDays = pair.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _mostPlayedFilterDays == pair.$1
                                ? Colors.white.withValues(alpha: 0.16)
                                : const Color(0xFF101016),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            pair.$2,
                            style: TextStyle(
                              color: _mostPlayedFilterDays == pair.$1 ? Colors.white : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (most.isNotEmpty)
              SizedBox(
                height: 152,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: most.length.clamp(0, 20),
                  separatorBuilder: (_, __) => const SizedBox(width: 11),
                  itemBuilder: (_, i) => _build16x9TrackCard(most[i], contextList: most),
                ),
              ),

            // Favourites
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border_rounded, color: Colors.white60, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Favourites',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${favs.length} Videos',
                        style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (favs.isNotEmpty)
              SizedBox(
                height: 152,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: favs.length.clamp(0, 20),
                  separatorBuilder: (_, __) => const SizedBox(width: 11),
                  itemBuilder: (_, i) => _build16x9TrackCard(favs[i], contextList: favs),
                ),
              ),

            // Custom Local Playlists Footer Header (`Playlists - N` + `+ Add`)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.queue_music_rounded, color: Colors.white60, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Playlists - ${pls.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Date Modified',
                          style: TextStyle(color: Colors.white54, fontSize: 11.2),
                        ),
                      ],
                    ),
                  ),
                  NamiSpringTap(
                    pressedScale: 0.94,
                    onTap: _showCreatePlaylistDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161F),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Add',
                            style: TextStyle(color: Colors.white, fontSize: 12.2, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final pl in pls)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141C),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.playlist_play_rounded, color: accent, size: 24),
                ),
                title: Text(
                  pl.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${pl.videoIds.length} tracks',
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
                trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white70),
                onTap: () {
                  final list = store.tracksForPlaylist(pl);
                  if (list.isNotEmpty) {
                    openNamiYoutubeWatchScreen(context, list.first, queue: list);
                  } else {
                    NamiLiveToastController.showMessage('Playlist "${pl.name}" is empty');
                  }
                },
              ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF101018),
        title: const Text('New YouTube Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await NamiYoutubeStore.instance.createPlaylist(name);
                NamiLiveToastController.showMessage('Created "$name"');
              }
              if (dCtx.mounted) Navigator.of(dCtx).pop();
            },
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-TAB 5: Downloads — Matches Nami 127233.png (`All | Ongoing | Finished`)
  // ---------------------------------------------------------------------------
  Widget _buildDownloadsTab(Color accent) {
    final shell = _NamiHomeShellState.activeInstance;
    final allSongs = shell?._songs ?? const <AudioTrack>[];
    final localDownloaded = allSongs
        .where((s) =>
            s.path.toLowerCase().contains('download') ||
            s.path.toLowerCase().contains('mornye') ||
            s.path.toLowerCase().contains('nami'))
        .toList()
      ..sort((a, b) => b.addedTimestampMs.compareTo(a.addedTimestampMs));

    return ValueListenableBuilder<List<NamiYtDownloadTask>>(
      valueListenable: NamiYtDownloadManager.instance.tasks,
      builder: (_, ytTasks, __) {
        final ongoing = ytTasks
            .where((t) =>
                t.status == NamiYtDlStatus.downloading ||
                t.status == NamiYtDlStatus.queued ||
                t.status == NamiYtDlStatus.failed)
            .toList();
        final finishedYt = ytTasks
            .where((t) => t.status == NamiYtDlStatus.completed && t.savedPath != null)
            .toList();

        final showOngoing = _dlFilter == 'All' || _dlFilter == 'Ongoing';
        final showFinished = _dlFilter == 'All' || _dlFilter == 'Finished';

        final isEmpty = (!showOngoing || ongoing.isEmpty) &&
            (!showFinished || (finishedYt.isEmpty && localDownloaded.isEmpty));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  for (final f in const ['All', 'Ongoing', 'Finished']) ...[
                    GestureDetector(
                      onTap: () {
                        NamiUxPrefs.hapticLight();
                        setState(() => _dlFilter = f);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: _dlFilter == f
                              ? Colors.white.withValues(alpha: 0.16)
                              : const Color(0xFF101016),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _dlFilter == f
                                ? Colors.white38
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          f == 'Ongoing' && ongoing.isNotEmpty
                              ? 'Ongoing (${ongoing.length})'
                              : f,
                          style: TextStyle(
                            color: _dlFilter == f ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: _dlFilter == f ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_done_rounded, color: Colors.white30, size: 42),
                          const SizedBox(height: 10),
                          Text(
                            _dlFilter == 'Ongoing'
                                ? 'No active downloads right now'
                                : 'Tap Download on any YouTube track or Mornye FLAC to save offline',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 160),
                      children: [
                        if (showOngoing && ongoing.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text(
                              'ONGOING',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          for (final task in ongoing)
                            Container(
                              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E0E15),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: Image.network(
                                            task.track.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: const Color(0xFF181822),
                                              child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 18),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 13.4, fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              task.status == NamiYtDlStatus.failed
                                                  ? (task.errorMessage ?? 'Failed')
                                                  : '${(task.progress * 100).round()}% • ${(task.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                              style: TextStyle(
                                                color: task.status == NamiYtDlStatus.failed
                                                    ? const Color(0xFFF87171)
                                                    : Colors.white54,
                                                fontSize: 11.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (task.status == NamiYtDlStatus.failed)
                                        IconButton(
                                          icon: Icon(Icons.refresh_rounded, color: accent, size: 20),
                                          onPressed: () => NamiYtDownloadManager.instance.enqueueDownload(task.track),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                                          onPressed: () => NamiYtDownloadManager.instance.cancelDownload(task.track.videoId),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: task.status == NamiYtDlStatus.failed
                                          ? 0.0
                                          : task.progress.clamp(0.02, 1.0),
                                      minHeight: 4.5,
                                      backgroundColor: Colors.white10,
                                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        if (showFinished && finishedYt.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                            child: Text(
                              'YOUTUBE OFFLINE',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          for (final task in finishedYt)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: Image.network(
                                    task.track.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF161620),
                                      child: const Icon(Icons.music_note_rounded, color: Colors.white38),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                task.track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13.6, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${task.track.artist} • ${(task.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB Offline',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                              ),
                              trailing: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 19),
                              onTap: () {
                                final p = task.savedPath;
                                if (p != null && File(p).existsSync() && shell != null) {
                                  final track = NamiYoutubePlaybackBridge.toAudioTrack(
                                    task.track,
                                    streamUrl: p,
                                    localThumbPath: task.track.cachedThumbPath,
                                  );
                                  shell._playV30YoutubeAudioTrack(track);
                                } else {
                                  NamiYoutubePlaybackBridge.playTrack(task.track);
                                }
                              },
                            ),
                        ],
                        if (showFinished && localDownloaded.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                            child: Text(
                              'MORNYE & LOCAL DOWNLOADS',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          for (final s in localDownloaded)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                              leading: shell != null
                                  ? shell._buildCoverArt(s, 46, 10)
                                  : const Icon(Icons.music_note_rounded, color: Colors.white54),
                              title: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13.6, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${cleanArtistStr(s.artist)} • ${s.album}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                              ),
                              trailing: const Icon(Icons.check_circle_outline_rounded, color: Colors.white38, size: 19),
                              onTap: () => shell?._playSong(s),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        Column(
          children: [
          /* v36_1_merged_top_nav_removed_old_row */
          Expanded(
              child: NotificationListener<OverscrollNotification>(
                onNotification: (n) {
                  // Boundary handoff: swiping right past sub-tab 0 (`Home Local`) glides back to local Playlists!
                  if (_subIdx == 0 && n.overscroll < -6.0 && n.metrics.axis == Axis.horizontal) {
                    _leftOverscrollAccum += n.overscroll.abs();
                    if (_leftOverscrollAccum > 42.0) {
                      _leftOverscrollAccum = 0.0;
                      NamiTabScrollController.handoffToPreviousMainTab();
                    }
                  } else {
                    _leftOverscrollAccum = 0.0;
                  }
                  return false;
                },
                child: PageView(
                  controller: _subPageCtrl,
                  physics: const BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast,
                  ),
                  onPageChanged: (idx) {
                  /* v36_1_page_sync */
                  _namiSafeSetNotifier<int>(NamiYoutubeNavController.activeSubTab, idx);
                    _leftOverscrollAccum = 0.0;
                    if (idx != _subIdx) {
                      NamiUxPrefs.hapticLight();
                      setState(() => _subIdx = idx);
                    }
                  },
                  children: [
                    _NamiKeepAliveSubTab(key: const ValueKey<int>(0), child: _buildHomeLocalTab(accent)),
                    _NamiKeepAliveSubTab(key: const ValueKey<int>(1), child: _buildMusicBrowseTab(accent)),
                    _NamiKeepAliveSubTab(key: const ValueKey<int>(2), child: widget.mornyeTab),
                    _NamiKeepAliveSubTab(key: const ValueKey<int>(3), child: _buildChannelsLocalTab(accent)),
                    _NamiKeepAliveSubTab(key: const ValueKey<int>(4), child: _buildPlaylistsLocalTab(accent)),
                    _NamiKeepAliveSubTab(key: const ValueKey<int>(5), child: _buildDownloadsTab(accent)),
                  ],
                ),
              ),
            ),
        ],
        ),

        // Floating Bottom-Right Square-Rounded YouTube Search FAB (127228-127233.png)
        if (_subIdx != 2)
          ValueListenableBuilder<bool>(
            valueListenable: NamiExpandablePlayerController.hasSong,
            builder: (_, hasSong, child) => AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 16,
              bottom: hasSong ? 86 : 18,
              child: child!,
            ),
            child: NamiSpringTap(
              pressedScale: 0.90,
              onTap: () => openNamiYoutubeSearchScreen(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF14141C),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.60),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
      ],
    );
  }
}

/// Nami-Style Watch Details & Radio Queue Sheet (matching 127234.png - 127236.png).
Future<void> showNamiYtWatchSheet(BuildContext context, NamiYtTrack track) {
  return openNamiYoutubeWatchScreen(context, track);
}

class _NamiYtWatchModal extends StatefulWidget {
  final NamiYtTrack track;
  const _NamiYtWatchModal({required this.track});

  @override
  State<_NamiYtWatchModal> createState() => _NamiYtWatchModalState();
}

class _NamiYtWatchModalState extends State<_NamiYtWatchModal> {
  NamiYtWatchDetails? _details;
  bool _loading = true;
  bool _showQueueMode = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final d = await NamiYoutubeService.instance.fetchWatchDetails(
      widget.track.videoId,
      region: NamiUxPrefs.youtubeRegion,
      fetchDislikes: NamiUxPrefs.ytReturnDislike,
    );
    if (!mounted) return;
    setState(() {
      _details = d;
      _loading = false;
    });
  }

  String _fmtCompact(int n) {
    if (n <= 0) return '';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _showSaveToPlaylistPicker() {
    final pls = NamiYoutubeStore.instance.playlists;
    if (pls.isEmpty) {
      NamiLiveToastController.showMessage('Create a playlist in Playlists (Local) first');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF0E0E15),
      builder: (pCtx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          for (final pl in pls)
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded, color: Colors.white70),
              title: Text(pl.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: () async {
                await NamiYoutubeStore.instance.addTrackToPlaylist(pl.id, widget.track);
                if (pCtx.mounted) Navigator.of(pCtx).pop();
                NamiLiveToastController.showMessage('Saved to "${pl.name}"');
              },
            ),
        ],
      ),
    );
  }

  Widget _watchAction(IconData icon, String label, VoidCallback onTap, {bool highlighted = false, Color? accent}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          NamiUxPrefs.hapticLight();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: highlighted ? (accent ?? Colors.white) : Colors.white70, size: 21),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlighted ? (accent ?? Colors.white) : Colors.white60,
                  fontSize: 10.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final h = MediaQuery.sizeOf(context).height;
    final d = _details;
    final fav = NamiYoutubeStore.instance.isFavorite(widget.track.videoId);
    final chId = (d?.channelId.isNotEmpty == true) ? d!.channelId : widget.track.artist;
    final subbed = NamiYoutubeStore.instance.isChannelSubscribed(chId);
    final related = d?.relatedTracks ?? NamiYoutubePlaybackBridge.radioQueue.value;

    return Container(
      height: h * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          // 16:9 Artwork Player Banner with Play Overlay (127234 / 127236.png)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 218,
                  child: Image.network(
                    widget.track.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF14141D)),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: NamiSpringTap(
                      pressedScale: 0.88,
                      onTap: () => NamiYoutubePlaybackBridge.playTrack(widget.track, upcoming: related),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 1.4),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                      ),
                    ),
                  ),
                ),
                if (widget.track.durationLabel.isNotEmpty)
                  Positioned(
                    left: 14,
                    bottom: 10,
                    child: Text(
                      widget.track.durationLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // Body: Watch Info OR Queue View (127235.png)
          Expanded(
            child: _showQueueMode
                ? ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    itemCount: related.length,
                    itemBuilder: (_, i) {
                      final r = related[i];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 72,
                            height: 44,
                            child: Image.network(r.thumbnailUrl, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 13.2, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          r.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                        ),
                        onTap: () => NamiYoutubePlaybackBridge.playTrack(r, upcoming: related),
                      );
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      Text(
                        d?.title.isNotEmpty == true ? d!.title : widget.track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          if ((d?.viewsText ?? widget.track.viewsText).isNotEmpty)
                            (d?.viewsText ?? widget.track.viewsText),
                          if ((d?.publishedText ?? widget.track.publishedText).isNotEmpty)
                            (d?.publishedText ?? widget.track.publishedText),
                        ].join('  •  '),
                        style: const TextStyle(color: Colors.white54, fontSize: 11.8),
                      ),
                      const SizedBox(height: 12),

                      // Action Strip (Like, Dislike, Share, Refresh, Fav, Save)
                      Row(
                        children: [
                          _watchAction(
                            Icons.thumb_up_outlined,
                            _fmtCompact(d?.likesCount ?? 0).isNotEmpty
                                ? _fmtCompact(d!.likesCount)
                                : 'Like',
                            () async {
                              await NamiYoutubeStore.instance.toggleFavorite(widget.track);
                              if (mounted) setState(() {});
                            },
                            highlighted: fav,
                            accent: accent,
                          ),
                          _watchAction(
                            Icons.thumb_down_outlined,
                            _fmtCompact(d?.dislikesCount ?? 0).isNotEmpty
                                ? _fmtCompact(d!.dislikesCount)
                                : 'Dislike',
                            () {},
                          ),
                          _watchAction(
                            Icons.share_outlined,
                            'Share',
                            () {
                              Clipboard.setData(
                                ClipboardData(text: 'https://youtu.be/${widget.track.videoId}'),
                              );
                              NamiLiveToastController.showMessage('Copied YouTube link');
                            },
                          ),
                          _watchAction(
                            Icons.playlist_play_rounded,
                            'Play Next',
                            () => NamiYoutubePlaybackBridge.queueYoutubeTrackAfter(widget.track),
                          ),
                          _watchAction(
                            Icons.download_rounded,
                            'Download',
                            () => NamiYtDownloadManager.instance.enqueueDownload(widget.track),
                          ),
                          _watchAction(
                            Icons.playlist_add_rounded,
                            'Save',
                            _showSaveToPlaylistPicker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Channel Row + Account-Free Subscribe Pill (127234.png)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: const Color(0xFF181822),
                            backgroundImage: (d?.channelAvatarUrl.startsWith('http') == true)
                                ? NetworkImage(d!.channelAvatarUrl)
                                : null,
                            child: (d?.channelAvatarUrl.startsWith('http') == true)
                                ? null
                                : const Icon(Icons.person_rounded, color: Colors.white60, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d?.channelName.isNotEmpty == true ? d!.channelName : widget.track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 13.8, fontWeight: FontWeight.w700),
                                ),
                                if (d?.subscriberText.isNotEmpty == true)
                                  Text(
                                    d!.subscriberText,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                                  ),
                              ],
                            ),
                          ),
                          NamiSpringTap(
                            pressedScale: 0.94,
                            onTap: () async {
                              final nowSub = await NamiYoutubeStore.instance.toggleChannelSubscription(
                                NamiYtChannel(
                                  channelId: chId,
                                  name: d?.channelName.isNotEmpty == true ? d!.channelName : widget.track.artist,
                                  avatarUrl: d?.channelAvatarUrl ?? '',
                                  subscriberText: d?.subscriberText ?? '',
                                  subscribedAtMs: DateTime.now().millisecondsSinceEpoch,
                                ),
                              );
                              if (mounted) setState(() {});
                              NamiLiveToastController.showMessage(
                                nowSub ? 'Subscribed locally' : 'Unsubscribed',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: subbed ? accent.withValues(alpha: 0.20) : const Color(0xFF16161F),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: subbed ? accent.withValues(alpha: 0.65) : Colors.white12,
                                ),
                              ),
                              child: Text(
                                subbed ? 'Subscribed' : 'Subscribe',
                                style: TextStyle(
                                  color: subbed ? accent : Colors.white,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Comments Preview Card (127234.png)
                      if (d?.topCommentText.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0E14),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Comments',
                                style: TextStyle(color: Colors.white, fontSize: 12.6, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                d!.topCommentText,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Related Videos / Up Next List
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        for (final r in related.take(10))
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => NamiYoutubePlaybackBridge.playTrack(r, upcoming: related),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          width: 112,
                                          height: 64,
                                          child: Image.network(r.thumbnailUrl, fit: BoxFit.cover),
                                        ),
                                        if (r.durationLabel.isNotEmpty)
                                          Positioned(
                                            right: 4,
                                            bottom: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.78),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                r.durationLabel,
                                                style: const TextStyle(color: Colors.white, fontSize: 9.8, fontWeight: FontWeight.w700),
                                              ),
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
                                        Text(
                                          r.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 12.8, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          [
                                            r.artist,
                                            if (r.viewsText.isNotEmpty) r.viewsText,
                                          ].join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white54, fontSize: 11),
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
          ),

          // Bottom Queue Toggle Bar (`1/N • Next: ...`, matching 127234 / 127235.png)
          SafeArea(
            top: false,
            child: InkWell(
              onTap: () {
                NamiUxPrefs.hapticLight();
                setState(() => _showQueueMode = !_showQueueMode);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E14),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(
                  children: [
                    Icon(Icons.queue_music_rounded, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showQueueMode ? 'Radio Queue (${related.length})' : '1/${related.length + 1}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.2, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            related.isNotEmpty
                                ? 'Next: ${related.first.title}'
                                : 'Auto-radio ready',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12.6, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showQueueMode ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
