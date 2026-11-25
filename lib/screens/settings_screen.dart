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
                        Text('Version 2.0.0 • Build v2.9.0 (v32)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: themeColor)),
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
              const Text("WHAT'S NEW IN v2.9.0 (v32)", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Colors.white54)),
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
    final themeColor = Theme.of(context).colorScheme.primary;
    final v16 = NamiV16Prefs.instance;
    const tabNames = ['Home', 'Tracks', 'Artists', 'Playlists'];

    void openPermissionsPage() => _openSettingsCategoryPage(
          context,
          'Permissions & Hardware',
          (ctx, setSub) => [
            _buildSettingsCard([
              ListTile(
                leading: _settingsBadge(Icons.folder_special_rounded, themeColor),
                title: const Text('Full Storage Access (All Files)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: const Text('Required for FLAC/MP3 tag writing, deleting files & .lrc/.sflx access', style: TextStyle(fontSize: 11, color: Colors.white54)),
                trailing: TextButton(
                  onPressed: () => _namiHandleAllFilesGrant(),
                  child: const Text('Grant'),
                ),
            onTap: () => _namiHandleAllFilesGrant(),
          ),
          const Divider(color: Colors.white10, height: 1),
          ListTile(
            leading: _settingsBadge(Icons.merge_type_rounded, themeColor),
            title: const Text('Merge / Alias Artists', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            subtitle: const Text('Combine duplicate artist spellings across your library', style: TextStyle(fontSize: 11, color: Colors.white54)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            onTap: () {
              Navigator.pop(context);
              _NamiHomeShellState.activeInstance?._openSettingsMergeArtistPicker();
            },
          ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: _settingsBadge(Icons.usb_rounded, themeColor),
                title: const Text('USB DAC Exclusive Permission', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: Text('Active output: ${widget.connectedDacName}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                trailing: TextButton(
                  onPressed: () => _namiHandleUsbDacRequest(),
                  child: const Text('Request'),
                ),
            onTap: () => _namiHandleUsbDacRequest(),
          ),
            ]),
          ],
        );

    void openAudioPage() => _openSettingsCategoryPage(
          context,
          'Audio & Playback',
          onResetSection: () {
            v16.resetSection('audio');
            v16.resetSection('tracks');
            _usbDac = true;
            _gapless = true;
            _pauseDisconnect = true;
            _rgMode = 'Off';
            widget.onUsbDacChanged(true);
            widget.onGaplessChanged(true);
            widget.onPauseOnDisconnectChanged(true);
            widget.onReplayGainModeChanged('Off');
          },
          (ctx, setSub) => [
            // One-Tap Audio Mode Presets Pill
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101018),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ONE-TAP AUDIO PROFILE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: Colors.white54)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'bit_perfect', icon: Icon(Icons.verified_rounded, size: 16), label: Text('Bit-Perfect', style: TextStyle(fontSize: 12))),
                        ButtonSegment(value: 'tuned', icon: Icon(Icons.headphones_rounded, size: 16), label: Text('Tuned / Commute', style: TextStyle(fontSize: 12))),
                      ],
                      selected: {v16.audioModePreset == 'tuned' ? 'tuned' : 'bit_perfect'},
                      onSelectionChanged: (sel) {
                        final mode = sel.first;
                        setSub(() {
                          v16.audioModePreset = mode;
                          if (mode == 'bit_perfect') {
                            _usbDac = true;
                            _rgMode = 'Off';
                            widget.onUsbDacChanged(true);
                            widget.onReplayGainModeChanged('Off');
                          } else {
                            _pauseDisconnect = true;
                            _rgMode = 'Track';
                            widget.onPauseOnDisconnectChanged(true);
                            widget.onReplayGainModeChanged('Track');
                          }
                        });
                        v16.save();
                        widget.onAudioModePresetSelected?.call(mode);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
            _buildSettingsCard([
              ListTile(
                leading: _settingsBadge(Icons.tune_rounded, themeColor),
                title: const Text('10-Band Equalizer, AutoEQ & DSP', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                subtitle: const Text('ISO bands, Harman IEM profiles, Crossfade, Pitch & L/R Balance', style: TextStyle(fontSize: 11, color: Colors.white54)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                onTap: widget.onOpenEqualizer,
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('USB DAC Exclusive Mode', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _usbDac,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _usbDac = v);
                  setState(() => _usbDac = v);
                  widget.onUsbDacChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Gapless Playback', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _gapless,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _gapless = v);
                  setState(() => _gapless = v);
                  widget.onGaplessChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Pause on Headphone / DAC Disconnect', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _pauseDisconnect,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _pauseDisconnect = v);
                  setState(() => _pauseDisconnect = v);
                  widget.onPauseOnDisconnectChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Resume Last Track on Launch', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _resumeSession,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _resumeSession = v);
                  setState(() => _resumeSession = v);
                  widget.onResumeSessionChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ReplayGain', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 6,
                      children: ['Off', 'Track', 'Album'].map((m) => ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(m, style: const TextStyle(fontSize: 11)),
                            selected: _rgMode == m,
                            selectedColor: themeColor,
                            onSelected: (_) {
                              setSub(() => _rgMode = m);
                              setState(() => _rgMode = m);
                              widget.onReplayGainModeChanged(m);
                            },
                          )).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Swipe Right on Track', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    DropdownButton<String>(
                      value: v16.swipeRightAction,
                      dropdownColor: const Color(0xFF161622),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'favorite', child: Text('Favorite', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'play_next', child: Text('Play Next', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'add_playlist', child: Text('Playlist', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'off', child: Text('Off', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSub(() => v16.swipeRightAction = val);
                          v16.save();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Swipe Left on Track', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    DropdownButton<String>(
                      value: v16.swipeLeftAction,
                      dropdownColor: const Color(0xFF161622),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'play_next', child: Text('Play Next', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'favorite', child: Text('Favorite', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'add_playlist', child: Text('Playlist', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'off', child: Text('Off', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSub(() => v16.swipeLeftAction = val);
                          v16.save();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Double-Tap Seek', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 6,
                      children: [5, 10, 15, 30].map((s) => ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${s}s', style: const TextStyle(fontSize: 11)),
                            selected: _seekSec == s,
                            selectedColor: themeColor,
                            onSelected: (_) {
                              setSub(() => _seekSec = s);
                              setState(() => _seekSec = s);
                              widget.onDoubleTapSeekChanged(s);
                            },
                          )).toList(),
                    ),
                  ],
                ),
              ),
            ]),
          ],
        );

    void openAppearancePage() => _openSettingsCategoryPage(
          context,
          'Appearance',
          onResetSection: () {
            _pitchBlack = true;
            _autoColor = true;
            _blurredBg = true;
            _codecBadges = true;
            _compactRows = false;
            widget.onPitchBlackChanged(true);
            widget.onAutoColoringChanged(true);
            widget.onBlurredBackdropChanged(true);
            widget.onShowCodecBadgesChanged(true);
            widget.onCompactTrackTilesChanged(false);
          },
          (ctx, setSub) => [
            // Live Visual Preview Card
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: _compactRows ? 8 : 12),
              decoration: BoxDecoration(
                color: _pitchBlack ? const Color(0xFF060609) : const Color(0xFF0E0E17),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withValues(alpha: 0.42)),
              ),
              child: Row(
                children: [
                  Container(
                    width: _compactRows ? 42 : 52,
                    height: _compactRows ? 42 : 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [themeColor, themeColor.withValues(alpha: 0.35)]),
                      borderRadius: BorderRadius.circular(_compactRows ? 8 : 10),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Appearance Preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: themeColor)),
                        const SizedBox(height: 2),
                        const Text('Kefine IEM • Bit-Perfect Lossless', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
                        if (_codecBadges) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 0.7),
                                ),
                                child: Text('FLAC 24B', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: themeColor)),
                              ),
                              const SizedBox(width: 6),
                              const Text('96.0 kHz • Live Preview', style: TextStyle(fontSize: 10, color: Colors.white38)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('Pitch-Black AMOLED Theme', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _pitchBlack,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _pitchBlack = v);
                  setState(() => _pitchBlack = v);
                  widget.onPitchBlackChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                title: const Text('Accent Color & 2D Hue Picker', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                ),
                onTap: _showColorPicker,
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Adaptive Cover Accent', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _autoColor,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _autoColor = v);
                  setState(() => _autoColor = v);
                  widget.onAutoColoringChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Blurred Now Playing Backdrop', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _blurredBg,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _blurredBg = v);
                  setState(() => _blurredBg = v);
                  widget.onBlurredBackdropChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Uppercase 24B / 16B Codec Badges', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _codecBadges,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _codecBadges = v);
                  setState(() => _codecBadges = v);
                  widget.onShowCodecBadgesChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Compact Track Rows', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _compactRows,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _compactRows = v);
                  setState(() => _compactRows = v);
                  widget.onCompactTrackTilesChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Startup Tab', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    DropdownButton<int>(
                      value: _startupTab.clamp(0, 3),
                      dropdownColor: const Color(0xFF161622),
                      underline: const SizedBox.shrink(),
                      items: List.generate(4, (i) => DropdownMenuItem(value: i, child: Text(tabNames[i], style: const TextStyle(fontSize: 12.5)))),
                      onChanged: (val) {
                        if (val != null) {
                          setSub(() => _startupTab = val);
                          setState(() => _startupTab = val);
                          widget.onDefaultStartupTabChanged(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ]),
          ],
        );

    void openLibraryPage() => _openSettingsCategoryPage(
          context,
          'Library & Storage',
          onResetSection: () {
            _ignoreShort = true;
            _splitArtists = true;
            v16.autoSyncPlaylistsM3u8 = false;
            v16.save();
            widget.onIgnoreShortClipsChanged(true);
            widget.onSplitArtistsChanged(true);
          },
          (ctx, setSub) => [
            _buildSettingsCard([
              ListTile(
                leading: _settingsBadge(Icons.folder_open_rounded, themeColor),
                title: const Text('Folder Explorer & Blacklist', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Browse folders & exclude unwanted directories', style: TextStyle(fontSize: 11, color: Colors.white54)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                onTap: widget.onOpenFolderExplorer,
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Ignore Short Audio Clips', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text('Skip clips shorter than ${_minSec}s', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                value: _ignoreShort,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _ignoreShort = v);
                  setState(() => _ignoreShort = v);
                  widget.onIgnoreShortClipsChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Split Multi-Artist Collaborations', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text('Separators: ${_separators.join(" ")}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                value: _splitArtists,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _splitArtists = v);
                  setState(() => _splitArtists = v);
                  widget.onSplitArtistsChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Auto-Sync Playlists to .m3u8', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Export playlist edits to /Music/NamiPlaylists/', style: TextStyle(fontSize: 11, color: Colors.white54)),
                value: v16.autoSyncPlaylistsM3u8,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => v16.autoSyncPlaylistsM3u8 = v);
                  v16.save();
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              FutureBuilder<String>(
                future: _cacheSizeFuture,
                builder: (_, snap) => ListTile(
                  leading: _settingsBadge(Icons.cleaning_services_rounded, themeColor),
                  title: const Text('Clear Artwork Cache', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text('Used: ${snap.data ?? "Calculating..."}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  onTap: () async {
                    await widget.onClearThumbCache();
                    setSub(() => _cacheSizeFuture = widget.thumbCacheSizeFuture);
                    setState(() {});
                  },
                ),
              ),
              if (widget.onFetchMissingCovers != null) ...[
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: _settingsBadge(Icons.auto_fix_high_rounded, themeColor),
                  title: const Text('Fetch Missing Covers & Metadata', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Enrich unmatched tracks only', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    widget.onFetchMissingCovers!();
                  },
                ),
              ],
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: _settingsBadge(Icons.refresh_rounded, themeColor),
                title: const Text('Force Full Library Rescan', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Re-read FLAC/ID3/M4A tags & purge deleted files', style: TextStyle(fontSize: 11, color: Colors.white54)),
                onTap: () {
                  widget.onRescan();
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              ),
            ]),
          ],
        );

    void openSyncPage() => _openSettingsCategoryPage(
          context,
          'Lyrics, Extensions & Sync',
          onResetSection: () {
            v16.resetSection('mornye');
            _syllableLyrics = true;
            _preferEmbedded = true;
            widget.onSyllableLyricsChanged(true);
            widget.onPreferEmbeddedChanged(true);
          },
          (ctx, setSub) => [
            _buildSettingsCard([
              ListTile(
                leading: _settingsBadge(Icons.extension_rounded, themeColor),
                title: const Text('Mornye Extension Repository & Store (.sflx)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                onTap: widget.onOpenExtensionRepo,
              ),
              if (widget.onOpenScrobbling != null) ...[
                const Divider(color: Colors.white10, height: 1),
                ListTile(
                  leading: _settingsBadge(Icons.podcasts_rounded, themeColor),
                  title: const Text('ListenBrainz Scrobbling', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Auto-scrobble plays & sync offline queue', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onOpenScrobbling!();
                  },
                ),
              ],
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Syllable Karaoke Lyrics', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _syllableLyrics,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _syllableLyrics = v);
                  setState(() => _syllableLyrics = v);
                  widget.onSyllableLyricsChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Prefer Embedded Lyrics', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _preferEmbedded,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _preferEmbedded = v);
                  setState(() => _preferEmbedded = v);
                  widget.onPreferEmbeddedChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                title: const Text('Auto-Fetch Online Metadata', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                value: _autoFetchOnline,
                activeThumbColor: themeColor,
                onChanged: (v) {
                  setSub(() => _autoFetchOnline = v);
                  setState(() => _autoFetchOnline = v);
                  widget.onAutoFetchOnlineChanged(v);
                },
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: _settingsBadge(Icons.archive_outlined, themeColor),
                title: const Text('Export Unified .nami-backup Archive', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Bundles playlists, EQ, aliases, smart mixes, covers & extensions', style: TextStyle(fontSize: 11, color: Colors.white54)),
                onTap: widget.onExportBackup,
              ),
              const Divider(color: Colors.white10, height: 1),
              ListTile(
                leading: _settingsBadge(Icons.restore_rounded, themeColor),
                title: const Text('Restore .nami-backup Archive', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                onTap: widget.onImportBackup,
              ),
            ]),
          ],
        );

    final q = _settingsSearch.trim().toLowerCase();
    final quickSearchItems = <(String, String, IconData, VoidCallback)>[
      ('Full Storage Access (All Files)', 'Permissions & Hardware', Icons.folder_special_rounded, openPermissionsPage),
      ('USB DAC Exclusive Permission', 'Permissions & Hardware', Icons.usb_rounded, openPermissionsPage),
      ('10-Band Equalizer, AutoEQ & Crossfade', 'Audio & Playback', Icons.tune_rounded, widget.onOpenEqualizer),
      ('Bit-Perfect vs Tuned Audio Profile', 'Audio & Playback', Icons.graphic_eq_rounded, openAudioPage),
      ('ReplayGain & Gapless Playback', 'Audio & Playback', Icons.volume_up_rounded, openAudioPage),
      ('Dual Swipe Gestures on Tracks', 'Audio & Playback', Icons.swipe_rounded, openAudioPage),
      ('Pitch-Black AMOLED & Accent Color', 'Appearance', Icons.palette_outlined, openAppearancePage),
      ('Uppercase 24B/16B Codec Badges', 'Appearance', Icons.high_quality_rounded, openAppearancePage),
      ('Folder Blacklist & Clear Cache', 'Library & Storage', Icons.folder_open_rounded, openLibraryPage),
      ('Fetch Missing Covers & Rescan', 'Library & Storage', Icons.auto_fix_high_rounded, openLibraryPage),
      ('Mornye Extension Repo & Store (.sflx)', 'Lyrics, Extensions & Sync', Icons.extension_rounded, widget.onOpenExtensionRepo),
      ('ListenBrainz Scrobbling', 'Lyrics, Extensions & Sync', Icons.podcasts_rounded, openSyncPage),
      ('Syllable Karaoke Lyrics', 'Lyrics, Extensions & Sync', Icons.lyrics_outlined, openSyncPage),
      ('Unified .nami-backup Export & Restore', 'Lyrics, Extensions & Sync', Icons.archive_outlined, openSyncPage),
      ('About Nami, Changelog & GitHub Updates', 'About Nami', Icons.system_update_rounded, () => _showAboutNamiSheet(context, themeColor)),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
            NamiSettingsHeroCard(
              outputDevice: widget.connectedDacName,
              eqEnabled: false,
              accentColor: Theme.of(context).colorScheme.primary,
              onGrantStorage: _namiHandleAllFilesGrant,
              onRequestUsbDac: _namiHandleUsbDacRequest,
              onMergeArtists: () {
                Navigator.of(context).pop();
                _NamiHomeShellState.activeInstance?._openSettingsMergeArtistPicker();
              },
            ),
            NamiSettingsStudioSection(
              accentColor: Theme.of(context).colorScheme.primary,
              onPurgePlaceholders: () {
                Navigator.of(context).pop();
                _NamiHomeShellState.activeInstance?._purgeBadArtistPlaceholders();
              },
              onBatchFetchArtists: () {
                Navigator.of(context).pop();
                _NamiHomeShellState.activeInstance?._batchFetchMissingArtistPhotos();
              },
              onSleepExpire: () {
                _NamiHomeShellState.activeInstance?._audioPlayer.pause();
              },
            ),
          // Top Minimalist Settings Search Pill
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              onChanged: (v) => setState(() => _settingsSearch = v),
              style: const TextStyle(fontSize: 13.5, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search settings (crossfade, DAC, cache, lyrics)...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Colors.white54),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF12121B),
                contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (q.isNotEmpty) ...[
            for (final item in quickSearchItems.where((x) => x.$1.toLowerCase().contains(q) || x.$2.toLowerCase().contains(q)))
              _minimalCategoryTile(
                icon: item.$3,
                title: item.$1,
                subtitle: item.$2,
                accent: themeColor,
                onTap: item.$4,
              ),
          ] else ...[
            FutureBuilder<PermissionStatus>(
              future: Permission.manageExternalStorage.status,
              builder: (_, permSnap) {
                final granted = permSnap.data?.isGranted == true;
                return _minimalCategoryTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Permissions & Hardware',
                  subtitle: '${granted ? "All Files Granted" : "Storage Needs Grant"} • ${widget.connectedDacName}',
                  accent: themeColor,
                  statusDotColor: granted ? Colors.greenAccent : Colors.amberAccent,
                  onTap: openPermissionsPage,
                );
              },
            ),
            _minimalCategoryTile(
              icon: Icons.graphic_eq_rounded,
              title: 'Audio & Playback',
              subtitle: '${v16.audioModePreset == "tuned" ? "Tuned Mode" : "Bit-Perfect"} • ${widget.activeEqPresetLabel ?? "AutoEQ"} • RG: $_rgMode',
              accent: themeColor,
              statusDotColor: _usbDac ? Colors.greenAccent : Colors.cyanAccent,
              onTap: openAudioPage,
            ),
            _minimalCategoryTile(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: '${_pitchBlack ? "AMOLED Pitch Black" : "Dark"} • Live Preview • ${_codecBadges ? "24B/16B Badges" : "Minimal"}',
              accent: themeColor,
              onTap: openAppearancePage,
            ),
            FutureBuilder<String>(
              future: _cacheSizeFuture,
              builder: (_, cacheSnap) => _minimalCategoryTile(
                icon: Icons.folder_outlined,
                title: 'Library & Storage',
                subtitle: '${_folders.length} folders • Cache: ${cacheSnap.data ?? "..."}',
                accent: themeColor,
                onTap: openLibraryPage,
              ),
            ),
            _minimalCategoryTile(
              icon: Icons.extension_outlined,
              title: 'Lyrics, Extensions & Sync',
              subtitle: 'Mornye Store • ListenBrainz • .nami-backup Archive',
              accent: themeColor,
              onTap: openSyncPage,
            ),
            const SizedBox(height: 8),
            _minimalCategoryTile(
              icon: Icons.info_outline_rounded,
              title: 'About Nami',
              subtitle: 'v2.0.0 • Piyush (Piyush1625) • Changelog & Updates',
              accent: themeColor,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                ),
                child: Text('v2.0.0', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: themeColor)),
              ),
              onTap: () => _showAboutNamiSheet(context, themeColor),
            ),
          ],
        ],
      ),
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
