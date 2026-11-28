part of '../main.dart';

/// Opens Nami's dedicated YouTube-Only Search Screen with live YouTube Autocomplete & Post-Search Suggestions.
Future<void> openNamiYoutubeSearchScreen(
  BuildContext context, {
  String initialQuery = '',
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => NamiYoutubeSearchScreen(initialQuery: initialQuery),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: child);
      },
    ),
  );
}

class NamiYoutubeSearchScreen extends StatefulWidget {
  final String initialQuery;
  const NamiYoutubeSearchScreen({super.key, this.initialQuery = ''});

  @override
  State<NamiYoutubeSearchScreen> createState() => _NamiYoutubeSearchScreenState();
}

class _NamiYoutubeSearchScreenState extends State<NamiYoutubeSearchScreen> {
  static const String _histPrefsKey = 'nami_v35_yt_search_history_v1';
  static const List<String> _filters = ['All', 'Videos', 'Songs', 'Channels', 'Shorts'];

  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  List<String> _recentSearches = const [];
  List<String> _liveSuggestions = const [];
  bool _showingResults = false;
  bool _loadingResults = false;
  String _activeFilter = 'All';
  String _submittedQuery = '';

  List<NamiYtTrack> _resultTracks = const [];
  List<NamiYtChannel> _resultChannels = const [];
  List<String> _relatedQueries = const [];
  List<NamiYtTrack> _postSearchSuggestions = const [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _loadSearchHistory();
    if (widget.initialQuery.trim().isNotEmpty) {
      _runSearch(widget.initialQuery.trim());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_histPrefsKey) ?? const <String>[];
      if (mounted) setState(() => _recentSearches = list);
    } catch (_) {}
  }

  Future<void> _saveSearchTerm(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) return;
    final next = <String>[
      clean,
      ..._recentSearches.where((e) => e.toLowerCase() != clean.toLowerCase()),
    ].take(20).toList();
    if (mounted) setState(() => _recentSearches = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_histPrefsKey, next);
    } catch (_) {}
  }

  Future<void> _removeSearchTerm(String term) async {
    final next = _recentSearches.where((e) => e != term).toList();
    if (mounted) setState(() => _recentSearches = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_histPrefsKey, next);
    } catch (_) {}
  }

  void _onQueryChanged(String value) {
    final q = value.trim();
    if (_showingResults) {
      setState(() => _showingResults = false);
    }
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() => _liveSuggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final suggs = await NamiYoutubeService.instance.fetchYoutubeAutocomplete(
        q,
        region: NamiUxPrefs.youtubeRegion,
      );
      if (mounted && _ctrl.text.trim() == q && !_showingResults) {
        setState(() => _liveSuggestions = suggs);
      }
    });
  }

  Future<void> _runSearch(String rawQuery, {String? filter}) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return;
    final useFilter = filter ?? _activeFilter;
    _focus.unfocus();
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    unawaited(_saveSearchTerm(q));

    setState(() {
      _submittedQuery = q;
      _activeFilter = useFilter;
      _showingResults = true;
      _loadingResults = true;
      _postSearchSuggestions = const [];
    });

    final res = await NamiYoutubeService.instance.searchYoutubeFull(
      q,
      filter: useFilter,
      region: NamiUxPrefs.youtubeRegion,
    );
    if (!mounted || _submittedQuery != q) return;

    final tracks = (res['tracks'] as List?)?.cast<NamiYtTrack>() ?? const <NamiYtTrack>[];
    final channels = (res['channels'] as List?)?.cast<NamiYtChannel>() ?? const <NamiYtChannel>[];
    final relQ = (res['relatedQueries'] as List?)?.cast<String>() ?? const <String>[];

    setState(() {
      _loadingResults = false;
      _resultTracks = tracks;
      _resultChannels = channels;
      _relatedQueries = relQ;
    });

    // Fetch YouTube-style post-search recommendations based on the top matching video/song!
    if (tracks.isNotEmpty) {
      final wd = await NamiYoutubeService.instance.fetchWatchDetails(
        tracks.first.videoId,
        region: NamiUxPrefs.youtubeRegion,
        fetchDislikes: false,
      );
      if (mounted && _submittedQuery == q) {
        final existingIds = tracks.map((t) => t.videoId).toSet();
        final postRecs = wd.relatedTracks
            .where((r) => !existingIds.contains(r.videoId))
            .take(10)
            .toList();
        setState(() => _postSearchSuggestions = postRecs);
      }
    }
  }

  Widget _buildAutocompleteView(Color accent) {
    final q = _ctrl.text.trim();
    final filteredHist = q.isEmpty
        ? _recentSearches
        : _recentSearches
            .where((h) => h.toLowerCase().contains(q.toLowerCase()))
            .take(4)
            .toList();

    final mergedSugg = _liveSuggestions
        .where((s) => !filteredHist.any((h) => h.toLowerCase() == s.toLowerCase()))
        .toList();

    if (filteredHist.isEmpty && mergedSugg.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.youtube_searched_for_rounded, color: accent.withValues(alpha: 0.7), size: 46),
              const SizedBox(height: 12),
              const Text(
                'Search YouTube Videos, Songs & Channels',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Live YouTube suggestions appear as you type',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12.2),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        for (final h in filteredHist)
          ListTile(
            dense: true,
            leading: const Icon(Icons.history_rounded, color: Colors.white54, size: 20),
            title: Text(
              h,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.north_west_rounded, color: Colors.white54, size: 18),
                  onPressed: () {
                    _ctrl.text = '$h ';
                    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
                    _onQueryChanged(_ctrl.text);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 17),
                  onPressed: () => _removeSearchTerm(h),
                ),
              ],
            ),
            onTap: () => _runSearch(h),
          ),
        for (final s in mergedSugg)
          ListTile(
            dense: true,
            leading: const NamiCustomIcon(NamiCustomIcons.search, size: 20, opacity: 0.65),
            title: Text(
              s,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14.2, fontWeight: FontWeight.w600),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.north_west_rounded, color: Colors.white54, size: 19),
              onPressed: () {
                _ctrl.text = '$s ';
                _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
                _onQueryChanged(_ctrl.text);
              },
            ),
            onTap: () => _runSearch(s),
          ),
      ],
    );
  }

  Widget _buildVideoCard(NamiYtTrack t, List<NamiYtTrack> queue, Color accent) {
    return InkWell(
      onTap: () {
        NamiUxPrefs.hapticLight();
        openNamiYoutubeWatchScreen(context, t, queue: queue);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 146,
                    height: 82,
                    child: Image.network(
                      t.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF161622),
                        child: const Icon(Icons.ondemand_video_rounded, color: Colors.white38),
                      ),
                    ),
                  ),
                ),
                if (t.duration.inSeconds > 0)
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        t.durationLabel,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: t.channelId.isNotEmpty
                        ? () => openNamiYoutubeChannelScreen(
                              context,
                              channelId: t.channelId,
                              channelName: t.artist,
                            )
                        : null,
                    child: Text(
                      t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (t.viewsText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.viewsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Play Next',
                  icon: const NamiCustomIcon(NamiCustomIcons.playlist, size: 20, opacity: 0.65),
                  onPressed: () => NamiYoutubePlaybackBridge.queueYoutubeTrackAfter(t),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Download',
                  icon: const Icon(Icons.download_outlined, color: Colors.white54, size: 18),
                  onPressed: () => showNamiYtDownloadPickerSheet(context, t),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(Color accent) {
    return Column(
      children: [
        // Filter Chips (`All | Videos | Songs | Channels | Shorts`)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            children: [
              for (final f in _filters)
                GestureDetector(
                  onTap: () {
                    if (_activeFilter == f) return;
                    NamiUxPrefs.hapticLight();
                    _runSearch(_submittedQuery, filter: f);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _activeFilter == f
                          ? Colors.white
                          : const Color(0xFF14141C),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _activeFilter == f ? Colors.white : Colors.white12,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: _activeFilter == f ? Colors.black : Colors.white70,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loadingResults
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2))
              : (_resultTracks.isEmpty && _resultChannels.isEmpty)
                  ? const Center(
                      child: Text(
                        'No YouTube results found — try another search',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        // Related Search Suggestion Pills (just like YouTube!)
                        if (_relatedQueries.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                            child: Text(
                              'Related searches',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              children: [
                                for (final rq in _relatedQueries)
                                  GestureDetector(
                                    onTap: () {
                                      NamiUxPrefs.hapticLight();
                                      _runSearch(rq);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF111118),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const NamiCustomIcon(NamiCustomIcons.search, size: 14, opacity: 0.60),
                                          const SizedBox(width: 6),
                                          Text(
                                            rq,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Matching YouTube Channels (tappable -> full NamiYoutubeChannelScreen!)
                        for (final ch in _resultChannels.take(4))
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF1A1A24),
                              backgroundImage: ch.avatarUrl.isNotEmpty ? NetworkImage(ch.avatarUrl) : null,
                              child: ch.avatarUrl.isEmpty
                                  ? const NamiCustomIcon(NamiCustomIcons.artist, opacity: 0.60)
                                  : null,
                            ),
                            title: Text(
                              ch.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              ch.subscriberText.isNotEmpty ? ch.subscriberText : 'YouTube Channel',
                              style: const TextStyle(color: Colors.white54, fontSize: 11.8),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                            onTap: () => openNamiYoutubeChannelScreen(
                              context,
                              channelId: ch.channelId,
                              channelName: ch.name,
                              channelAvatarUrl: ch.avatarUrl,
                              subscriberText: ch.subscriberText,
                            ),
                          ),

                        // Primary Search Video & Music Results
                        for (final t in _resultTracks) _buildVideoCard(t, _resultTracks, accent),

                        // Post-Search Recommendations ("Suggested after your search")
                        if (_postSearchSuggestions.isNotEmpty) ...[
                          const Divider(color: Colors.white10, height: 24),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, color: accent, size: 17),
                                const SizedBox(width: 8),
                                const Text(
                                  'Suggested For You',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final r in _postSearchSuggestions)
                            _buildVideoCard(r, _postSearchSuggestions, accent),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 23),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF14141C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              const Icon(Icons.ondemand_video_rounded, color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: const TextStyle(color: Colors.white, fontSize: 14.2),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search YouTube...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13.8),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onQueryChanged,
                  onSubmitted: (v) => _runSearch(v),
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() {
                      _showingResults = false;
                      _liveSuggestions = const [];
                    });
                    _focus.requestFocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _showingResults ? _buildResultsView(accent) : _buildAutocompleteView(accent),
    );
  }
}

/// Connected YouTube Home Feed (`v3.5.0`):
/// Displays category chips, Continue Watching history, dynamic "Because You Watched"
/// post-watch recommendations (auto-refreshes whenever you watch a video), and full 16:9 YouTube cards.
class NamiYoutubeConnectedHomeFeed extends StatefulWidget {
  const NamiYoutubeConnectedHomeFeed({super.key});

  @override
  State<NamiYoutubeConnectedHomeFeed> createState() => _NamiYoutubeConnectedHomeFeedState();
}

class _NamiYoutubeConnectedHomeFeedState extends State<NamiYoutubeConnectedHomeFeed>
    with AutomaticKeepAliveClientMixin {
  static const List<String> _cats = ['All', 'Music', 'Trending', 'Podcasts', 'Gaming', 'Recents'];

  String _activeCat = 'All';
  bool _loading = true;
  List<NamiYtTrack> _becauseWatched = const [];
  List<NamiYtTrack> _feedVideos = const [];
  String _lastSeedId = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    NamiYoutubePlaybackBridge.activeYtTrack.addListener(_onWatchedChanged);
    _loadFeed();
  }

  @override
  void dispose() {
    NamiYoutubePlaybackBridge.activeYtTrack.removeListener(_onWatchedChanged);
    super.dispose();
  }

  void _onWatchedChanged() {
    final cur = NamiYoutubePlaybackBridge.activeYtTrack.value;
    if (cur != null && cur.videoId != _lastSeedId) {
      _lastSeedId = cur.videoId;
      _loadFeed(silent: true);
    }
  }

  Future<void> _loadFeed({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final hist = NamiYoutubeStore.instance.history;
    if (hist.isNotEmpty) _lastSeedId = hist.first.videoId;
    await NamiYtTasteEngine.ensureLoaded();
    final recentQ = await NamiYtTasteEngine.recentSearchTerms(limit: 4);
    final tasteA = NamiYtTasteEngine.topTasteArtists(limit: 5);
    final res = await NamiYoutubeService.instance.fetchYoutubeHomeFeed(
      category: _activeCat,
      region: NamiUxPrefs.youtubeRegion,
      recentHistory: hist.where((t) => !NamiYtTasteEngine.isHidden(t.videoId)).toList(),
      recentSearches: recentQ,
      tasteArtists: tasteA,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _becauseWatched = (res['becauseWatched'] ?? const []).where((t) => !NamiYtTasteEngine.isHidden(t.videoId)).toList();
      _feedVideos = (res['feed'] ?? const []).where((t) => !NamiYtTasteEngine.isHidden(t.videoId)).toList();
    });
  }

  Widget _buildMiniHorizontalCard(NamiYtTrack t, List<NamiYtTrack> queue) {
    return GestureDetector(
      onTap: () {
        NamiUxPrefs.hapticLight();
        openNamiYoutubeWatchScreen(context, t, queue: queue);
      },
      child: Container(
        width: 178,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 178,
                    height: 100,
                    child: Image.network(
                      t.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF161622),
                        child: const Icon(Icons.ondemand_video_rounded, color: Colors.white38),
                      ),
                    ),
                  ),
                ),
                if (t.duration.inSeconds > 0)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        t.durationLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.4,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              t.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFull16x9FeedCard(NamiYtTrack t, List<NamiYtTrack> queue) {
    return InkWell(
      onTap: () {
        NamiUxPrefs.hapticLight();
        openNamiYoutubeWatchScreen(context, t, queue: queue);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      t.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF14141E),
                        child: const Icon(Icons.ondemand_video_rounded, color: Colors.white30, size: 42),
                      ),
                    ),
                    if (t.duration.inSeconds > 0)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t.durationLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: t.channelId.isNotEmpty
                      ? () => openNamiYoutubeChannelScreen(
                            context,
                            channelId: t.channelId,
                            channelName: t.artist,
                          )
                      : null,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1A1A26),
                    child: Text(
                      t.artist.isNotEmpty ? t.artist[0].toUpperCase() : 'Y',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.24,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          t.artist,
                          if (t.viewsText.isNotEmpty) t.viewsText,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11.6),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Play Next',
                  icon: const NamiCustomIcon(NamiCustomIcons.playlist, size: 20, opacity: 0.65),
                  onPressed: () => NamiYoutubePlaybackBridge.queueYoutubeTrackAfter(t),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = Theme.of(context).colorScheme.primary;
    final store = NamiYoutubeStore.instance;
    final history = store.history;

    return RefreshIndicator(
      color: accent,
      backgroundColor: const Color(0xFF12121A),
      onRefresh: () => _loadFeed(),
      child: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 165),
        children: [
          // 1. YouTube Home Category Filter Pills
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final cat in _cats)
                  GestureDetector(
                    onTap: () {
                      if (_activeCat == cat) return;
                      NamiUxPrefs.hapticLight();
                      setState(() => _activeCat = cat);
                      if (cat != 'Recents') _loadFeed();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeCat == cat ? Colors.white : const Color(0xFF14141C),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _activeCat == cat ? Colors.white : Colors.white12,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: _activeCat == cat ? Colors.black : Colors.white70,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Recents-only filtered mode
          if (_activeCat == 'Recents') ...[
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Center(
                  child: Text(
                    'Videos and music you watch will appear here',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              )
            else
              for (final h in history) _buildFull16x9FeedCard(h, history),
          ] else ...[
            /* v36_2_channels_strip */
            if (store.subscribedChannels.isNotEmpty) ...[
              SizedBox(
                height: 82,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: store.subscribedChannels.length,
                  itemBuilder: (_, i) {
                    final ch = store.subscribedChannels[i];
                    return GestureDetector(
                      onTap: () => openNamiYoutubeChannelScreen(
                        context,
                        channelId: ch.channelId,
                        channelName: ch.name,
                        channelAvatarUrl: ch.avatarUrl,
                        subscriberText: ch.subscriberText,
                      ),
                      child: Container(
                        width: 66,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xFF181822),
                              backgroundImage:
                                  ch.avatarUrl.isNotEmpty ? NetworkImage(ch.avatarUrl) : null,
                              child: ch.avatarUrl.isEmpty
                                  ? Text(
                                      ch.name.isNotEmpty ? ch.name[0].toUpperCase() : 'C',
                                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              ch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 10.4, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            // 2. Continue Watching / Recently Watched Strip (Connected to watch history!)
            if (history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Continue Watching',
                      style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      '${history.length} watched',
                      style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 156,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: history.length.clamp(0, 12),
                  itemBuilder: (_, i) => _buildMiniHorizontalCard(history[i], history),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 3. Personalized "Because You Watched <Last Track>" Recommendations!
            if (_becauseWatched.isNotEmpty && history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: accent, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Because you watched ${history.first.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14.8, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 156,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _becauseWatched.length.clamp(0, 14),
                  itemBuilder: (_, i) =>
                      _buildMiniHorizontalCard(_becauseWatched[i], _becauseWatched),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 4. Main Connected YouTube Recommendations Feed (Full 16:9 Cards!)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Row(
                children: [
                  Text(
                    _activeCat == 'All' ? 'Recommended For You' : '$_activeCat on YouTube',
                    style: const TextStyle(color: Colors.white, fontSize: 15.8, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => openNamiYoutubeSearchScreen(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141C),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NamiCustomIcon(NamiCustomIcons.search, size: 14, opacity: 0.78),
                          SizedBox(width: 5),
                          Text(
                            'Search YT',
                            style: TextStyle(color: Colors.white70, fontSize: 11.4, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_loading && _feedVideos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
              )
            else
              for (final v in _feedVideos) _buildFull16x9FeedCard(v, _feedVideos),
          ],
        ],
      ),
    );
  }
}

/// Shared reactive navigation controller linking Nami's merged single-row YouTube top bar
/// (`NamiYoutubeMergedAppBar`) directly to `NamiDiscoverHubTab`'s 5 unified sub-tabs (`v3.6.2`).
class NamiYoutubeNavController {
  static final ValueNotifier<int> activeSubTab = ValueNotifier<int>(0);
  static void Function(int index)? onSelectSubTab;

  static void select(int index) {
    final safe = index.clamp(0, 4);
    _namiSafeSetNotifier<int>(activeSubTab, safe);
    onSelectSubTab?.call(safe);
  }
}

class _NamiYtTopNavDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NamiYtTopNavDef(this.icon, this.activeIcon, this.label);
}

/// Bigger, Roomier 5-Tab Merged Single-Row AMOLED YouTube Header (`v3.6.2`):
/// Exact layout: `[ YouTube (21.5px) ] (left) -> [ 5 Nav Pills (40px) ] (center) -> [ Settings (24.5px) ] (right)`
/// - Merges Playlists & Downloads into one unified `Library` pill (`index 4`) with live download dot
/// - Zero top Search or Queue icons
/// - Tapping `YouTube` opens the Logged-Out BotGuard / Signed-In Account sheet
class NamiYoutubeMergedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onOpenSettings;

  const NamiYoutubeMergedAppBar({
    super.key,
    required this.onOpenSettings,
  });

  static const List<_NamiYtTopNavDef> _items = [
    _NamiYtTopNavDef(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NamiYtTopNavDef(Icons.music_note_outlined, Icons.music_note_rounded, 'Music'),
    _NamiYtTopNavDef(Icons.extension_outlined, Icons.extension_rounded, 'Mornye'),
    _NamiYtTopNavDef(Icons.people_outline_rounded, Icons.people_rounded, 'Channels'),
    _NamiYtTopNavDef(Icons.video_library_outlined, Icons.video_library_rounded, 'Library'),
  ];

  @override
  Size get preferredSize => const Size.fromHeight(62.0);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 0.7,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 62.0,
          child: Row(
            children: [
              // 1. LEFT: Bigger `YouTube` Brand Title (tap -> Account / BotGuard sheet)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: ValueListenableBuilder<bool>(
                  valueListenable: NamiYoutubeService.isSignedIn,
                  builder: (_, signedIn, __) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      NamiUxPrefs.hapticLight();
                      showNamiYoutubeAccountSheet(context);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'YouTube',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.45,
                          ),
                        ),
                        if (signedIn) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7.5,
                            height: 7.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 2. CENTER: Bigger 5-Tab YouTube Nav Pill Strip (Home | Music | Mornye | Channels | Library)
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: NamiYoutubeNavController.activeSubTab,
                  builder: (_, activeIdx, __) => ValueListenableBuilder<List<NamiYtDownloadTask>>(
                    valueListenable: NamiYtDownloadManager.instance.tasks,
                    builder: (_, dlTasks, __) {
                      final hasActiveDl = dlTasks.any(
                        (t) =>
                            t.status == NamiYtDlStatus.downloading ||
                            t.status == NamiYtDlStatus.queued,
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < _items.length; i++) ...[
                              if (i > 0) const SizedBox(width: 5.5),
                              _buildNavChip(
                                index: i,
                                def: _items[i],
                                selected: activeIdx == i,
                                accent: accent,
                                showBadgeDot: i == 4 && hasActiveDl,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. RIGHT: Bigger Clean Settings Gear Button
              IconButton(
                tooltip: 'Settings',
                padding: const EdgeInsets.symmetric(horizontal: 12),
                constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
                icon: const NamiCustomIcon(NamiCustomIcons.settings, size: 24.5),
                onPressed: () {
                  NamiUxPrefs.hapticLight();
                  onOpenSettings();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavChip({
    required int index,
    required _NamiYtTopNavDef def,
    required bool selected,
    required Color accent,
    bool showBadgeDot = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        NamiUxPrefs.hapticLight();
        NamiYoutubeNavController.select(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: selected ? 13 : 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.20)
              : const Color(0xFF111118),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.60)
                : Colors.white.withValues(alpha: 0.09),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? def.activeIcon : def.icon,
                  color: selected ? accent : Colors.white70,
                  size: 20.0,
                ),
                if (showBadgeDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                def.label,
                style: TextStyle(
                  color: accent,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

