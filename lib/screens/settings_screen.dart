part of '../main.dart';

class MainSettingsScreen extends StatefulWidget {
  final bool usbDacExclusive;
  final bool gaplessPlayback;
  final bool mediaNotificationEnabled;
  final bool usePitchBlack;
  final bool autoColoring;
  final bool ambientGlow;
  final bool blurredBackdrop;
  final bool showCodecBadges;
  final bool compactTrackTiles;
  final bool resumeSessionOnStartup;
  final bool pauseOnDisconnect;
  final int doubleTapSeekSec;
  final int minTrackSeconds;
  final String replayGainMode;
  final int defaultStartupTab;
  final bool syllableLyricsEnabled;
  final bool preferEmbeddedLyrics;
  final bool autoFetchOnlineMetadata;
  final bool splitMultiArtists;
  final List<String> artistSeparators;
  final List<String> scanFolders;
  final bool ignoreShortClips;
  final bool forceMiniColor;
  final String connectedDacName;
  final String? activeEqPresetLabel;
  final ValueChanged<String>? onAudioModePresetSelected;
  final Future<String> thumbCacheSizeFuture;
  final Future<void> Function() onClearThumbCache;
  final Future<void> Function()? onFetchMissingCovers;
  final VoidCallback onOpenEqualizer;
  final Future<void> Function()? onRequestStoragePermission;
  final Future<void> Function()? onRequestUsbDacPermission;
  final VoidCallback? onOpenScrobbling;
  final VoidCallback onOpenExtensionRepo;
  final VoidCallback onOpenFolderExplorer;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final ValueChanged<List<String>> onScanFoldersChanged;
  final ValueChanged<bool> onIgnoreShortClipsChanged;
  final ValueChanged<int> onMinTrackSecondsChanged;
  final ValueChanged<bool> onUsbDacChanged;
  final ValueChanged<bool> onGaplessChanged;
  final ValueChanged<bool> onNotificationChanged;
  final ValueChanged<bool> onPitchBlackChanged;
  final ValueChanged<bool> onAutoColoringChanged;
  final ValueChanged<bool> onAmbientGlowChanged;
  final ValueChanged<bool> onBlurredBackdropChanged;
  final ValueChanged<bool> onShowCodecBadgesChanged;
  final ValueChanged<bool> onCompactTrackTilesChanged;
  final ValueChanged<bool> onResumeSessionChanged;
  final ValueChanged<bool> onPauseOnDisconnectChanged;
  final ValueChanged<int> onDoubleTapSeekChanged;
  final ValueChanged<String> onReplayGainModeChanged;
  final ValueChanged<int> onDefaultStartupTabChanged;
  final ValueChanged<bool> onSyllableLyricsChanged;
  final ValueChanged<bool> onPreferEmbeddedChanged;
  final ValueChanged<bool> onAutoFetchOnlineChanged;
  final ValueChanged<bool> onSplitArtistsChanged;
  final ValueChanged<List<String>> onArtistSeparatorsChanged;
  final ValueChanged<bool> onForceMiniColorChanged;
  final VoidCallback onRescan;

  const MainSettingsScreen({
    super.key,
    required this.usbDacExclusive,
    required this.gaplessPlayback,
    required this.mediaNotificationEnabled,
    required this.usePitchBlack,
    required this.autoColoring,
    required this.ambientGlow,
    required this.blurredBackdrop,
    required this.showCodecBadges,
    required this.compactTrackTiles,
    required this.resumeSessionOnStartup,
    required this.pauseOnDisconnect,
    required this.doubleTapSeekSec,
    required this.minTrackSeconds,
    required this.replayGainMode,
    required this.defaultStartupTab,
    required this.syllableLyricsEnabled,
    required this.preferEmbeddedLyrics,
    required this.autoFetchOnlineMetadata,
    required this.splitMultiArtists,
    required this.artistSeparators,
    required this.scanFolders,
    required this.ignoreShortClips,
    required this.forceMiniColor,
    required this.connectedDacName,
    this.activeEqPresetLabel,
    this.onAudioModePresetSelected,
    required this.thumbCacheSizeFuture,
    required this.onClearThumbCache,
    this.onFetchMissingCovers,
    required this.onOpenEqualizer,
    this.onRequestStoragePermission,
    this.onRequestUsbDacPermission,
    this.onOpenScrobbling,
    required this.onOpenExtensionRepo,
    required this.onOpenFolderExplorer,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onScanFoldersChanged,
    required this.onIgnoreShortClipsChanged,
    required this.onMinTrackSecondsChanged,
    required this.onUsbDacChanged,
    required this.onGaplessChanged,
    required this.onNotificationChanged,
    required this.onPitchBlackChanged,
    required this.onAutoColoringChanged,
    required this.onAmbientGlowChanged,
    required this.onBlurredBackdropChanged,
    required this.onShowCodecBadgesChanged,
    required this.onCompactTrackTilesChanged,
    required this.onResumeSessionChanged,
    required this.onPauseOnDisconnectChanged,
    required this.onDoubleTapSeekChanged,
    required this.onReplayGainModeChanged,
    required this.onDefaultStartupTabChanged,
    required this.onSyllableLyricsChanged,
    required this.onPreferEmbeddedChanged,
    required this.onAutoFetchOnlineChanged,
    required this.onSplitArtistsChanged,
    required this.onArtistSeparatorsChanged,
    required this.onForceMiniColorChanged,
    required this.onRescan,
  });

  @override
  State<MainSettingsScreen> createState() => _MainSettingsScreenState();
}

class _MainSettingsScreenState extends State<MainSettingsScreen> {
  late bool _usbDac;
  late bool _gapless;
  late bool _mediaNotif;
  late bool _pitchBlack;
  late bool _autoColor;
  late bool _ambientGlow;
  late bool _blurredBg;
  late bool _codecBadges;
  late bool _compactRows;
  late bool _resumeSession;
  late bool _pauseDisconnect;
  late int _seekSec;
  late int _minSec;
  late String _rgMode;
  late int _startupTab;
  late bool _syllableLyrics;
  late bool _preferEmbedded;
  late bool _autoFetchOnline;
  late bool _splitArtists;
  late List<String> _separators;
  late List<String> _folders;
  late bool _ignoreShort;
  late bool _forceMini;
  late Future<String> _cacheSizeFuture;

  final List<Color> _swatches = [
    const Color(0xFFE53935),
    const Color(0xFFFF9800),
    const Color(0xFFFFEB3B),
    const Color(0xFF00E676),
    const Color(0xFF00E5FF),
    const Color(0xFF2979FF),
    const Color(0xFF7C4DFF),
    const Color(0xFFFF4081),
    const Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _usbDac = widget.usbDacExclusive;
    _gapless = widget.gaplessPlayback;
    _mediaNotif = widget.mediaNotificationEnabled;
    _pitchBlack = widget.usePitchBlack;
    _autoColor = widget.autoColoring;
    _ambientGlow = widget.ambientGlow;
    _blurredBg = widget.blurredBackdrop;
    _codecBadges = widget.showCodecBadges;
    _compactRows = widget.compactTrackTiles;
    _resumeSession = widget.resumeSessionOnStartup;
    _pauseDisconnect = widget.pauseOnDisconnect;
    _seekSec = widget.doubleTapSeekSec;
    _minSec = widget.minTrackSeconds;
    _rgMode = widget.replayGainMode;
    _startupTab = widget.defaultStartupTab;
    _syllableLyrics = widget.syllableLyricsEnabled;
    _preferEmbedded = widget.preferEmbeddedLyrics;
    _autoFetchOnline = widget.autoFetchOnlineMetadata;
    _splitArtists = widget.splitMultiArtists;
    _separators = List<String>.from(widget.artistSeparators);
    _folders = List<String>.from(widget.scanFolders);
    _ignoreShort = widget.ignoreShortClips;
    _forceMini = widget.forceMiniColor;
    _cacheSizeFuture = widget.thumbCacheSizeFuture;
  }

  void _showAddSeparatorDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14141F),
        title: const Text('Add Artist Separator'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. ; or vs. or x'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              final token = ctrl.text.trim();
              if (token.isNotEmpty && !_separators.contains(token)) {
                setState(() => _separators.add(token));
                widget.onArtistSeparatorsChanged(_separators);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    final currentAccent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Pick Nami Accent Color', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 14),
              HuePaletteCanvas(
                initialColor: currentAccent,
                onColorChanged: (color) => NamiApp.of(context).updateTheme(newAccent: color),
              ),
              const SizedBox(height: 16),
              const Text('Preset Swatches', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _swatches
                    .map((color) => GestureDetector(
                          onTap: () {
                            NamiApp.of(context).updateTheme(newAccent: color);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 2),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: accent),
          ),
        ],
      ),
    );
  }

  Widget _settingsBadge(IconData icon, Color color) {
    /* v24_squircle_badge */
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.9),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }

  String _settingsSearch = '';

  void _showAboutNamiSheet(BuildContext context, Color themeColor) {
    bool checkingUpdate = false;
    NamiReleaseInfo? latestRelease;
    String? updateStatusMsg;
    double? downloadProg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setAboutState) => DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.48,
          maxChildSize: 0.94,
          expand: false,
          builder: (ctx, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [themeColor, themeColor.withValues(alpha: 0.55)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nami Music Player', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 3),
                        Text('Version 2.0.0 • Build v3.6.1 (v50)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: themeColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF151520),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_rounded, size: 17, color: themeColor),
                        const SizedBox(width: 8),
                        const Text('Author & Maintainer', style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Piyush (Piyush1625)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    const Text('github.com/Piyush1625/nami • Bit-Perfect libmpv + AudioService + Mornye Engine', style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // In-App GitHub Update Checker
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E17),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeColor.withValues(alpha: 0.32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GitHub Releases Updater', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: checkingUpdate
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.system_update_rounded, size: 16),
                          label: Text(checkingUpdate ? 'Checking...' : 'Check for Updates', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: checkingUpdate
                              ? null
                              : () async {
                                  setAboutState(() {
                                    checkingUpdate = true;
                                    updateStatusMsg = null;
                                  });
                                  final rel = await NamiGitHubUpdater.checkLatestRelease();
                                  setAboutState(() {
                                    checkingUpdate = false;
                                    latestRelease = rel;
                                    updateStatusMsg = rel == null
                                        ? 'No published GitHub releases found yet (or offline).'
                                        : 'Latest release: ${rel.tagName} — ${rel.title}';
                                  });
                                },
                        ),
                      ],
                    ),
                    if (updateStatusMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(updateStatusMsg!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                    if (latestRelease != null && latestRelease!.apkUrl != null) ...[
                      const SizedBox(height: 8),
                      if (downloadProg != null)
                        LinearProgressIndicator(value: downloadProg, color: themeColor, backgroundColor: Colors.white12)
                      else
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 17),
                          label: Text('Download ${latestRelease!.tagName} Signed APK to /Download'),
                          onPressed: () async {
                            setAboutState(() => downloadProg = 0.05);
                            final saved = await NamiGitHubUpdater.downloadApkToDownloads(
                              latestRelease!.apkUrl!,
                              latestRelease!.tagName,
                              onProgress: (p) => setAboutState(() => downloadProg = p),
                            );
                            setAboutState(() {
                              downloadProg = null;
                              updateStatusMsg = saved != null
                                  ? 'APK downloaded to $saved — tap it in Files to install in place!'
                                  : 'APK download failed.';
                            });
                          },
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text("WHAT'S NEW IN v3.6.1 (v50)", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Colors.white54)),
              const SizedBox(height: 10),
              for (final item in const [
                ('Home Overhaul', 'Customizable reorderable shelves, live tappable DAC output & AutoEQ switcher, Time-of-Day & Forgotten Favorites mixes, Weekly Recap strip, and long-press card actions.'),
                ('Tracks Power Suite', 'Full sort sheet, Library Health filters (Untagged, No Cover, Duplicates), Batch Tag & Cover Editor, dual customizable swipe gestures, and uppercase 24B/16B codec pills.'),
                ('Artists Parallax & Discography', 'Edge-to-edge collapsing hero header, chronological album timeline, Top 5 tracks, Primary vs Appears On split, Artist Alias/Merge tool, expandable Bio & Similar Local Artists.'),
                ('Playlists Studio', 'Compact horizontal shortcuts rail, Rule-Based Smart Playlist Builder, auto 2x2 mosaic collage covers, custom covers & descriptions, in-playlist search/sort/dedupe, pins & auto .m3u8 sync.'),
                ('Mornye Store & Drill-Down', 'Interactive Album & Artist pages with Download Entire Album, In-Library badges, Extension Store directory + live latency ping, folder templates, and direct Stream-to-Queue.'),
                ('Refined Minimal Settings', 'Top settings search bar, live status dots, Bit-Perfect vs Tuned presets, Appearance live preview card, unified .nami-backup archive, per-section resets & GitHub updater.'),
              ])
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0E17),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(Icons.check_circle_rounded, size: 15, color: themeColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(item.$2, style: const TextStyle(fontSize: 11.5, color: Colors.white60, height: 1.35)),
                          ],
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
  }

  void _openSettingsCategoryPage(
    BuildContext context,
    String title,
    List<Widget> Function(BuildContext ctx, StateSetter setSubState) builder, {
    VoidCallback? onResetSection,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (ctx, setSubState) => Scaffold(
            backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              actions: [
                if (onResetSection != null)
                  TextButton(
                    onPressed: () {
                      onResetSection();
                      setSubState(() {});
                      setState(() {});
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Reset $title to defaults')));
                    },
                    child: const Text('Reset', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: builder(ctx, setSubState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _minimalCategoryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
    Widget? trailing,
    Color? statusDotColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101018),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            _settingsBadge(icon, accent),
            if (statusDotColor != null)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusDotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF101018), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamiUnifiedSettingsHub(
      outputDevice: widget.connectedDacName,
      activeEqPresetLabel: widget.activeEqPresetLabel,
      usbDacExclusive: widget.usbDacExclusive,
      gaplessPlayback: widget.gaplessPlayback,
      mediaNotificationEnabled: widget.mediaNotificationEnabled,
      usePitchBlack: widget.usePitchBlack,
      autoColoring: widget.autoColoring,
      ambientGlow: widget.ambientGlow,
      blurredBackdrop: widget.blurredBackdrop,
      showCodecBadges: widget.showCodecBadges,
      compactTrackTiles: widget.compactTrackTiles,
      forceMiniColor: widget.forceMiniColor,
      resumeSessionOnStartup: widget.resumeSessionOnStartup,
      pauseOnDisconnect: widget.pauseOnDisconnect,
      ignoreShortClips: widget.ignoreShortClips,
      syllableLyricsEnabled: widget.syllableLyricsEnabled,
      preferEmbeddedLyrics: widget.preferEmbeddedLyrics,
      autoFetchOnlineMetadata: widget.autoFetchOnlineMetadata,
      splitMultiArtists: widget.splitMultiArtists,
      doubleTapSeekSec: widget.doubleTapSeekSec,
      minTrackSeconds: widget.minTrackSeconds,
      replayGainMode: widget.replayGainMode,
      folderCount: widget.scanFolders.length,
      thumbCacheSizeFuture: widget.thumbCacheSizeFuture,
      currentAccentColor: null,
      onGrantStorage: _namiHandleAllFilesGrant,
      onRequestUsbDac: _namiHandleUsbDacRequest,
      onMergeArtists: () {
        NamiShellNavigator.popToRoot();
        _NamiHomeShellState.activeInstance?._openSettingsMergeArtistPicker();
      },
      onPurgePlaceholders: () {
        NamiShellNavigator.popToRoot();
        _NamiHomeShellState.activeInstance?._purgeBadArtistPlaceholders();
      },
      onBatchFetchArtists: () {
        NamiShellNavigator.popToRoot();
        _NamiHomeShellState.activeInstance?._batchFetchMissingArtistPhotos();
      },
      onSleepExpire: () {
        _NamiHomeShellState.activeInstance?._audioPlayer.pause();
      },
      onApplyAudioProps: () {
        final shell = _NamiHomeShellState.activeInstance;
        if (shell != null) {
          NamiAudiophileEngine.applyMpvProperties(shell._audioPlayer);
        }
      },
      onSyncWidgetNow: () {
        _NamiHomeShellState.activeInstance?._syncV27WidgetAndSession(force: true);
      },
      onOpenEqualizer: widget.onOpenEqualizer,
      onOpenFolderExplorer: widget.onOpenFolderExplorer,
      onExportBackup: widget.onExportBackup,
      onImportBackup: widget.onImportBackup,
      onOpenScrobbling: widget.onOpenScrobbling,
      onOpenExtensionRepo: widget.onOpenExtensionRepo,
      onClearThumbCache: widget.onClearThumbCache,
      onFetchMissingCovers: widget.onFetchMissingCovers,
      onCheckForUpdates: null,
      onUsbDacChanged: widget.onUsbDacChanged,
      onGaplessChanged: widget.onGaplessChanged,
      onNotificationChanged: widget.onNotificationChanged,
      onPitchBlackChanged: widget.onPitchBlackChanged,
      onAutoColoringChanged: widget.onAutoColoringChanged,
      onAmbientGlowChanged: widget.onAmbientGlowChanged,
      onBlurredBackdropChanged: widget.onBlurredBackdropChanged,
      onShowCodecBadgesChanged: widget.onShowCodecBadgesChanged,
      onCompactTrackTilesChanged: widget.onCompactTrackTilesChanged,
      onForceMiniColorChanged: widget.onForceMiniColorChanged,
      onResumeSessionChanged: widget.onResumeSessionChanged,
      onPauseOnDisconnectChanged: widget.onPauseOnDisconnectChanged,
      onIgnoreShortClipsChanged: widget.onIgnoreShortClipsChanged,
      onSyllableLyricsChanged: widget.onSyllableLyricsChanged,
      onPreferEmbeddedLyricsChanged: null,
      onAutoFetchMetadataChanged: null,
      onSplitMultiArtistsChanged: null,
      onDoubleTapSeekChanged: widget.onDoubleTapSeekChanged,
      onMinTrackSecondsChanged: widget.onMinTrackSecondsChanged,
      onReplayGainChanged: widget.onReplayGainModeChanged,
      onAccentColorChanged: null,
    );
  }



  static const MethodChannel _namiPermChannel = MethodChannel('com.piyush.nami/audio_device');

  Future<void> _namiHandleAllFilesGrant() async {
    try {
      final res = await _namiPermChannel.invokeMethod<dynamic>('requestAllFilesPermission');
      if (!mounted) return;
      final msg = res == 'granted'
          ? 'Full Storage Access (All Files) is already granted!'
          : 'Enable "Allow access to manage all files" for Nami, then return.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open Android Settings > Apps > Nami > Permissions to grant All Files Access.')),
      );
    }
  }

  Future<void> _namiHandleUsbDacRequest() async {
    try {
      final res = await _namiPermChannel.invokeMethod<dynamic>('requestUsbDacPermission');
      if (!mounted) return;
      String status = '';
      String dev = '';
      if (res is Map) {
        status = (res['status'] ?? '').toString();
        dev = (res['device'] ?? '').toString();
      }
      String msg;
      if (status == 'granted') {
        msg = 'Exclusive USB DAC permission already granted${dev.isNotEmpty ? ' ($dev)' : ''}.';
      } else if (status == 'requested') {
        msg = 'USB DAC permission prompt opened${dev.isNotEmpty ? ' for $dev' : ''}.';
      } else if (status == 'no_usb_dac') {
        msg = 'No USB DAC detected. Plug in your USB-C DAC and tap Request again.';
      } else {
        msg = 'Could not query USB audio devices on this phone.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plug in a USB-C DAC and tap Request again.')),
      );
    }
  }
}
