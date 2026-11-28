part of '../main.dart';

/// Bespoke vertical-bar waveform slider for Nami numeric settings (compact inline right-aligned).
class NamiWaveformSlider extends StatefulWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double val) valueFormatter;
  final ValueChanged<double> onChanged;
  final Color accentColor;
  final IconData? leadingIcon;
  final bool compactInline;

  const NamiWaveformSlider({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueFormatter,
    required this.onChanged,
    required this.accentColor,
    this.leadingIcon,
    this.compactInline = true,
  });

  @override
  State<NamiWaveformSlider> createState() => _NamiWaveformSliderState();
}

class _NamiWaveformSliderState extends State<NamiWaveformSlider> {
  static const List<double> _compactBars = <double>[
    0.38, 0.62, 0.45, 0.85, 0.56, 0.96, 0.52, 0.78, 0.90, 0.46,
    0.72, 0.98, 0.60, 0.42, 0.82, 0.66, 0.88, 0.50, 0.70, 0.44,
  ];

  int _lastStep = -1;

  void _handleTouch(double localX, double width) {
    if (width <= 1) return;
    final norm = (localX / width).clamp(0.0, 1.0);
    final raw = widget.min + norm * (widget.max - widget.min);
    final stepSize = (widget.max - widget.min) / widget.divisions;
    final snappedStep = ((raw - widget.min) / stepSize).round().clamp(0, widget.divisions);
    final snappedVal = (widget.min + snappedStep * stepSize).clamp(widget.min, widget.max);
    if (snappedStep != _lastStep) {
      _lastStep = snappedStep;
      NamiUxPrefs.hapticLight();
      widget.onChanged(snappedVal);
    }
  }

  Widget _buildBars(double width, double height, double norm) {
    final activeIdx = (norm * (_compactBars.length - 1)).round();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _handleTouch(d.localPosition.dx, width),
      onHorizontalDragStart: (d) => _handleTouch(d.localPosition.dx, width),
      onHorizontalDragUpdate: (d) => _handleTouch(d.localPosition.dx, width),
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < _compactBars.length; i++)
              Container(
                width: i == activeIdx ? 2.6 : 1.9,
                height: i == activeIdx
                    ? height * 0.96
                    : (height * (0.26 + _compactBars[i] * 0.56)),
                decoration: BoxDecoration(
                  color: i == activeIdx
                      ? Colors.white
                      : (i < activeIdx
                          ? Colors.white.withValues(alpha: 0.78)
                          : Colors.white.withValues(alpha: 0.22)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final norm = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          if (widget.leadingIcon != null) ...[
            Icon(widget.leadingIcon, color: Colors.white54, size: 21),
            const SizedBox(width: 15),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (widget.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(fontSize: 11.4, color: Colors.white54),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBars(86, 26, norm),
              const SizedBox(height: 3),
              Text(
                widget.valueFormatter(widget.value),
                style: const TextStyle(
                  fontSize: 10.6,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minimal pitch-black AMOLED monochrome pill toggle switch.
class _NamiMonoSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NamiMonoSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        NamiUxPrefs.hapticLight();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF282830) : const Color(0xFF15151B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: value ? Colors.white : Colors.white.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _NamiSettingSearchEntry {
  final String title;
  final String subtitle;
  final String keywords;
  final IconData icon;
  final int categoryIndex;

  const _NamiSettingSearchEntry({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.icon,
    required this.categoryIndex,
  });
}

/// Clean, zero-redundancy AMOLED Settings Hub for Nami v3.0.3 Stable.
/// Every visible row, toggle, and slider is backed by a live functional callback.
class NamiUnifiedSettingsHub extends StatefulWidget {
  final String outputDevice;
  final String? activeEqPresetLabel;
  final bool usbDacExclusive;
  final bool gaplessPlayback;
  final bool mediaNotificationEnabled;
  final bool usePitchBlack;
  final bool autoColoring;
  final bool ambientGlow;
  final bool blurredBackdrop;
  final bool showCodecBadges;
  final bool compactTrackTiles;
  final bool forceMiniColor;
  final bool resumeSessionOnStartup;
  final bool pauseOnDisconnect;
  final bool ignoreShortClips;
  final bool syllableLyricsEnabled;
  final bool preferEmbeddedLyrics;
  final bool autoFetchOnlineMetadata;
  final bool splitMultiArtists;
  final int doubleTapSeekSec;
  final int minTrackSeconds;
  final String replayGainMode;
  final int folderCount;
  final Future<String>? thumbCacheSizeFuture;
  final Color? currentAccentColor;

  final VoidCallback onGrantStorage;
  final VoidCallback onRequestUsbDac;
  final VoidCallback onMergeArtists;
  final VoidCallback onPurgePlaceholders;
  final VoidCallback onBatchFetchArtists;
  final VoidCallback onSleepExpire;
  final VoidCallback onApplyAudioProps;
  final VoidCallback onSyncWidgetNow;
  final VoidCallback? onOpenEqualizer;
  final VoidCallback? onOpenFolderExplorer;
  final VoidCallback? onExportBackup;
  final VoidCallback? onImportBackup;
  final VoidCallback? onOpenScrobbling;
  final VoidCallback? onOpenExtensionRepo;
  final Future<void> Function()? onClearThumbCache;
  final Future<void> Function()? onFetchMissingCovers;
  final VoidCallback? onCheckForUpdates;
  final ValueChanged<bool>? onUsbDacChanged;
  final ValueChanged<bool>? onGaplessChanged;
  final ValueChanged<bool>? onNotificationChanged;
  final ValueChanged<bool>? onPitchBlackChanged;
  final ValueChanged<bool>? onAutoColoringChanged;
  final ValueChanged<bool>? onAmbientGlowChanged;
  final ValueChanged<bool>? onBlurredBackdropChanged;
  final ValueChanged<bool>? onShowCodecBadgesChanged;
  final ValueChanged<bool>? onCompactTrackTilesChanged;
  final ValueChanged<bool>? onForceMiniColorChanged;
  final ValueChanged<bool>? onResumeSessionChanged;
  final ValueChanged<bool>? onPauseOnDisconnectChanged;
  final ValueChanged<bool>? onIgnoreShortClipsChanged;
  final ValueChanged<bool>? onSyllableLyricsChanged;
  final ValueChanged<bool>? onPreferEmbeddedLyricsChanged;
  final ValueChanged<bool>? onAutoFetchMetadataChanged;
  final ValueChanged<bool>? onSplitMultiArtistsChanged;
  final ValueChanged<int>? onDoubleTapSeekChanged;
  final ValueChanged<int>? onMinTrackSecondsChanged;
  final ValueChanged<String>? onReplayGainChanged;
  final ValueChanged<Color>? onAccentColorChanged;

  const NamiUnifiedSettingsHub({
    super.key,
    required this.outputDevice,
    this.activeEqPresetLabel,
    this.usbDacExclusive = false,
    this.gaplessPlayback = true,
    this.mediaNotificationEnabled = true,
    this.usePitchBlack = true,
    this.autoColoring = false,
    this.ambientGlow = true,
    this.blurredBackdrop = false,
    this.showCodecBadges = true,
    this.compactTrackTiles = false,
    this.forceMiniColor = false,
    this.resumeSessionOnStartup = true,
    this.pauseOnDisconnect = true,
    this.ignoreShortClips = true,
    this.syllableLyricsEnabled = true,
    this.preferEmbeddedLyrics = true,
    this.autoFetchOnlineMetadata = true,
    this.splitMultiArtists = true,
    this.doubleTapSeekSec = 10,
    this.minTrackSeconds = 10,
    this.replayGainMode = 'Track',
    this.folderCount = 0,
    this.thumbCacheSizeFuture,
    this.currentAccentColor,
    required this.onGrantStorage,
    required this.onRequestUsbDac,
    required this.onMergeArtists,
    required this.onPurgePlaceholders,
    required this.onBatchFetchArtists,
    required this.onSleepExpire,
    required this.onApplyAudioProps,
    required this.onSyncWidgetNow,
    this.onOpenEqualizer,
    this.onOpenFolderExplorer,
    this.onExportBackup,
    this.onImportBackup,
    this.onOpenScrobbling,
    this.onOpenExtensionRepo,
    this.onClearThumbCache,
    this.onFetchMissingCovers,
    this.onCheckForUpdates,
    this.onUsbDacChanged,
    this.onGaplessChanged,
    this.onNotificationChanged,
    this.onPitchBlackChanged,
    this.onAutoColoringChanged,
    this.onAmbientGlowChanged,
    this.onBlurredBackdropChanged,
    this.onShowCodecBadgesChanged,
    this.onCompactTrackTilesChanged,
    this.onForceMiniColorChanged,
    this.onResumeSessionChanged,
    this.onPauseOnDisconnectChanged,
    this.onIgnoreShortClipsChanged,
    this.onSyllableLyricsChanged,
    this.onPreferEmbeddedLyricsChanged,
    this.onAutoFetchMetadataChanged,
    this.onSplitMultiArtistsChanged,
    this.onDoubleTapSeekChanged,
    this.onMinTrackSecondsChanged,
    this.onReplayGainChanged,
    this.onAccentColorChanged,
  });

  @override
  State<NamiUnifiedSettingsHub> createState() => _NamiUnifiedSettingsHubState();
}

class _NamiUnifiedSettingsHubState extends State<NamiUnifiedSettingsHub> {
  // 7 Focused Categories (Zero Duplication, Zero Filler):
  // 0: Theme & Appearance | 1: Library & Indexer | 2: Playback & DAC
  // 3: Motion, Lyrics & Gestures | 4: YouTube & Mornye | 5: Backup, Cache & Sync | 6: About Nami
  static const List<_NamiSettingSearchEntry> _searchIndex = [
    _NamiSettingSearchEntry(
      title: 'Pitch Black AMOLED, Auto Coloring & Accent Colors',
      subtitle: 'Theme & Appearance',
      keywords: 'theme pitch black amoled auto coloring accent color glow blur compact badge',
      icon: Icons.format_paint_outlined,
      categoryIndex: 0,
    ),
    _NamiSettingSearchEntry(
      title: 'Scan Folders, Storage Access & India-First Metadata',
      subtitle: 'Library & Indexer',
      keywords: 'indexer folder storage scan refresh clips duration artist photos jiosaavn apple covers merge',
      icon: Icons.layers_outlined,
      categoryIndex: 1,
    ),
    _NamiSettingSearchEntry(
      title: 'USB DAC, Gapless, ReplayGain, Sleep Timer & Seek',
      subtitle: 'Playback & DAC',
      keywords: 'playback dac usb bit perfect gapless replaygain normalize sleep timer seek notification disconnect',
      icon: Icons.play_circle_outline_rounded,
      categoryIndex: 2,
    ),
    _NamiSettingSearchEntry(
      title: '120Hz Motion, Haptics, Synced Lyrics & Swipe Gestures',
      subtitle: 'Motion, Lyrics & Gestures',
      keywords: 'customizations 120hz motion haptics breathing cover lyrics syllable blur swipe row immersive',
      icon: Icons.brush_outlined,
      categoryIndex: 3,
    ),
    _NamiSettingSearchEntry(
      title: 'YouTube Region, Audio Quality, SponsorBlock, RYD & Mornye',
      subtitle: 'YouTube & Mornye',
      keywords: 'youtube mornye extensions sponsorblock dislike radio region opus quality search cleanup',
      icon: Icons.ondemand_video_rounded,
      categoryIndex: 4,
    ),
    _NamiSettingSearchEntry(
      title: 'Backup Archive, ListenBrainz, Widget & Cover Cache',
      subtitle: 'Backup, Cache & Sync',
      keywords: 'backup restore export import archive listenbrainz scrobble widget cache clear thumbnail memory',
      icon: Icons.settings_backup_restore_rounded,
      categoryIndex: 5,
    ),
    _NamiSettingSearchEntry(
      title: 'About Nami, GitHub Releases Updater & Statistics',
      subtitle: 'About Nami',
      keywords: 'about version statistics tracks albums artists duration github update piyush',
      icon: Icons.info_outline_rounded,
      categoryIndex: 6,
    ),
  ];

  @override
  void initState() {
    super.initState();
    NamiUxPrefs.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openCategory(int index) {
    NamiUxPrefs.hapticLight();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NamiSettingsSubPage(
          categoryIndex: index,
          hubWidget: widget,
          onOpenSearch: _openSearchSheet,
        ),
      ),
    );
  }

  void _openQuickSleepSheet() {
    NamiUxPrefs.hapticLight();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: namiSmoothSheetStyle,
      builder: (sheetCtx) {
        final accent = Theme.of(sheetCtx).colorScheme.primary;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: SafeArea(
            top: false,
            child: ValueListenableBuilder<Duration?>(
              valueListenable: NamiUxPrefs.sleepRemaining,
              builder: (_, rem, __) {
                final activeLabel = rem == null
                    ? 'Off'
                    : (rem.inMinutes <= 15
                        ? '15m'
                        : (rem.inMinutes <= 30
                            ? '30m'
                            : (rem.inMinutes <= 45 ? '45m' : '60m')));
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.bedtime_outlined, color: accent, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          rem == null
                              ? 'Sleep Timer'
                              : 'Sleep Timer • ${rem.inMinutes.toString().padLeft(2, '0')}:${(rem.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (final opt in const ['Off', '15m', '30m', '45m', '60m']) ...[
                          if (opt != 'Off') const SizedBox(width: 8),
                          Expanded(
                            child: NamiSpringTap(
                              pressedScale: 0.94,
                              onTap: () {
                                if (opt == 'Off') {
                                  NamiUxPrefs.startSleepTimer(null, widget.onSleepExpire);
                                } else {
                                  final mins = int.tryParse(opt.replaceAll('m', '')) ?? 30;
                                  NamiUxPrefs.startSleepTimer(Duration(minutes: mins), widget.onSleepExpire);
                                }
                                Navigator.of(sheetCtx).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: activeLabel == opt
                                      ? accent.withValues(alpha: 0.20)
                                      : const Color(0xFF15151E),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: activeLabel == opt
                                        ? accent.withValues(alpha: 0.65)
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                    color: activeLabel == opt ? accent : Colors.white70,
                                    fontSize: 12.6,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openSearchSheet() {
    NamiUxPrefs.hapticLight();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: namiSmoothSheetStyle,
      builder: (sheetCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final q = query.trim().toLowerCase();
            final hits = q.isEmpty
                ? _searchIndex
                : _searchIndex.where((e) {
                    return e.title.toLowerCase().contains(q) ||
                        e.subtitle.toLowerCase().contains(q) ||
                        e.keywords.contains(q);
                  }).toList();
            final accent = Theme.of(ctx).colorScheme.primary;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.72),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0F),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: TextField(
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14.2),
                        decoration: InputDecoration(
                          hintText: 'Search settings (DAC, EQ, backup, YouTube...)',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.2),
                          prefixIcon: NamiCustomIcon(NamiCustomIcons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFF14141C),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: accent.withValues(alpha: 0.65)),
                          ),
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 18),
                        itemCount: hits.length,
                        itemBuilder: (_, i) {
                          final item = hits[i];
                          return ListTile(
                            leading: Icon(item.icon, color: Colors.white60, size: 21),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              style: const TextStyle(color: Colors.white54, fontSize: 11.6),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              _openCategory(item.categoryIndex);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _quickActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData rightIcon1,
    required String rightTooltip1,
    required VoidCallback onRight1,
    required IconData rightIcon2,
    required String rightTooltip2,
    required VoidCallback onRight2,
  }) {
    return InkWell(
      onTap: () {
        NamiUxPrefs.hapticLight();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 22),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.4,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.6, color: Colors.white54),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: rightTooltip1,
              icon: Icon(rightIcon1, color: Colors.white70, size: 20),
              onPressed: () {
                NamiUxPrefs.hapticLight();
                onRight1();
              },
            ),
            IconButton(
              tooltip: rightTooltip2,
              icon: Icon(rightIcon2, color: Colors.white70, size: 20),
              onPressed: () {
                NamiUxPrefs.hapticLight();
                onRight2();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow({
    required IconData icon,
    required String title,
    String subtitle = '',
    required int index,
    Widget? trailingBadge,
  }) {
    return InkWell(
      onTap: () => _openCategory(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 22),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2.5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.8, color: Colors.white54, height: 1.25),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              const SizedBox(width: 8),
              trailingBadge,
            ],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 19),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final outName = widget.outputDevice.isNotEmpty ? widget.outputDevice : 'Phone Speaker';
    final eqLabel = (widget.activeEqPresetLabel != null && widget.activeEqPresetLabel!.isNotEmpty)
        ? widget.activeEqPresetLabel!
        : 'EQ Bypass';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
          onPressed: () {
            NamiUxPrefs.hapticLight();
            final nav = Navigator.maybeOf(context);
            if (nav != null && nav.canPop()) {
              nav.pop();
            } else {
              NamiShellNavigator.maybePop();
            }
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search Settings',
            icon: const NamiCustomIcon(NamiCustomIcons.search, size: 22, opacity: 0.78),
            onPressed: _openSearchSheet,
          ),
          IconButton(
            tooltip: 'About Nami',
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 21),
            onPressed: () => _openCategory(6),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            right: -36,
            bottom: 36,
            child: IgnorePointer(
              child: Icon(
                Icons.waves_rounded,
                size: 240,
                color: Colors.white.withValues(alpha: 0.028),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 162),
            children: [
              // Quick Action 1: Scan Folders (Folder Explorer + Refresh + Artist Fetch)
              _quickActionRow(
                icon: Icons.create_new_folder_outlined,
                title: 'Scan Folders',
                subtitle: '${widget.folderCount} scan folder(s) • Local storage & FLAC tags',
                onTap: () {
                  if (widget.onOpenFolderExplorer != null) {
                    widget.onOpenFolderExplorer!();
                  } else {
                    widget.onGrantStorage();
                  }
                },
                rightIcon1: Icons.refresh_rounded,
                rightTooltip1: 'Refresh Library',
                onRight1: () {
                  _NamiHomeShellState.activeInstance?._handleV29TracksPullRefresh();
                },
                rightIcon2: Icons.cloud_download_outlined,
                rightTooltip2: 'Batch Fetch Missing Artist Portraits',
                onRight2: widget.onBatchFetchArtists,
              ),
              // Quick Action 2: Equalizer & AutoEQ (Opens Equalizer directly — NO duplicate Playback link!)
              if (widget.onOpenEqualizer != null)
                _quickActionRow(
                  icon: Icons.equalizer_rounded,
                  title: 'Equalizer & AutoEQ',
                  subtitle: '$outName • $eqLabel',
                  onTap: widget.onOpenEqualizer!,
                  rightIcon1: Icons.bedtime_outlined,
                  rightTooltip1: 'Quick Sleep Timer',
                  onRight1: _openQuickSleepSheet,
                  rightIcon2: Icons.usb_rounded,
                  rightTooltip2: 'Request Direct USB DAC',
                  onRight2: widget.onRequestUsbDac,
                ),
              const SizedBox(height: 6),

              // 7 Clean, Zero-Overlap Categories
              _categoryRow(
                icon: Icons.format_paint_outlined,
                title: 'Theme & Appearance',
                subtitle: 'Pitch Black AMOLED, Auto Coloring & Accent Colors',
                index: 0,
              ),
              _categoryRow(
                icon: Icons.layers_outlined,
                title: 'Library & Indexer',
                subtitle: 'Scan folders, storage access & India-First portraits',
                index: 1,
              ),
              _categoryRow(
                icon: Icons.play_circle_outline_rounded,
                title: 'Playback & DAC',
                subtitle: 'USB DAC, Gapless, ReplayGain, Sleep Timer & Seek',
                index: 2,
                trailingBadge: ValueListenableBuilder<Duration?>(
                  valueListenable: NamiUxPrefs.sleepRemaining,
                  builder: (_, rem, __) {
                    if (rem == null) return const SizedBox.shrink();
                    final m = rem.inMinutes.toString().padLeft(2, '0');
                    final s = (rem.inSeconds % 60).toString().padLeft(2, '0');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$m:$s',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
                      ),
                    );
                  },
                ),
              ),
              _categoryRow(
                icon: Icons.brush_outlined,
                title: 'Motion, Lyrics & Gestures',
                subtitle: '120Hz tempo, synced lyrics, track swipes & immersive mode',
                index: 3,
              ),
              _categoryRow(
                icon: Icons.ondemand_video_rounded,
                title: 'YouTube & Mornye',
                subtitle: 'Region (${NamiUxPrefs.youtubeRegion}), SponsorBlock, RYD & Extensions',
                index: 4,
              ),
              _categoryRow(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Backup, Cache & Sync',
                subtitle: '.nami-backup archive, ListenBrainz, Widget & cover cache',
                index: 5,
              ),
              _categoryRow(
                icon: Icons.info_outline_rounded,
                title: 'About Nami',
                subtitle: 'v3.8.0 Stable • Releases & Library Statistics',
                index: 6,
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: NamiExpandablePlayerController.hasSong,
            builder: (_, playingSong, child) => AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 16,
              bottom: playingSong ? 86 : 18,
              child: child!,
            ),
            child: NamiSpringTap(
              pressedScale: 0.92,
              onTap: _openSearchSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.60),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NamiCustomIcon(NamiCustomIcons.search, size: 19),
                    SizedBox(width: 8),
                    Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
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

class _NamiSettingsSubPage extends StatefulWidget {
  final int categoryIndex;
  final NamiUnifiedSettingsHub hubWidget;
  final VoidCallback onOpenSearch;

  const _NamiSettingsSubPage({
    required this.categoryIndex,
    required this.hubWidget,
    required this.onOpenSearch,
  });

  @override
  State<_NamiSettingsSubPage> createState() => _NamiSettingsSubPageState();
}

class _NamiSettingsSubPageState extends State<_NamiSettingsSubPage> {
  static const List<String> _titles = [
    'Theme & Appearance',
    'Library & Indexer',
    'Playback & DAC',
    'Motion, Lyrics & Gestures',
    'YouTube & Mornye',
    'Backup, Cache & Sync',
    'About Nami',
  ];

  static const List<String> _subtitles = [
    'Pitch Black AMOLED, Auto Coloring & Accent Colors',
    'Manage scan folders, metadata & artist portraits',
    'USB DAC, Gapless, ReplayGain, Sleep Timer & Seek',
    '120Hz motion, synced lyrics, gestures & immersive mode',
    'YouTube Music region, SponsorBlock, RYD & Mornye',
    'Backups, ListenBrainz, AMOLED Widget & cover cache',
    'Version, Developer & Library Statistics',
  ];

  static const List<IconData> _icons = [
    Icons.format_paint_outlined,
    Icons.layers_outlined,
    Icons.play_circle_outline_rounded,
    Icons.brush_outlined,
    Icons.ondemand_video_rounded,
    Icons.settings_backup_restore_rounded,
    Icons.info_outline_rounded,
  ];

  static const List<Color> _accentSwatches = [
    Color(0xFF8B5CF6),
    Color(0xFFE11D48),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFFFFFFFF),
  ];

  late bool _usbDac;
  late bool _gapless;
  late bool _notif;
  late bool _pitchBlack;
  late bool _autoColor;
  late bool _ambientGlow;
  late bool _blurredBackdrop;
  late bool _showBadges;
  late bool _compactTiles;
  late bool _forceMiniColor;
  late bool _resumeStartup;
  late bool _pauseDisconnect;
  late bool _ignoreShort;
  late bool _syllableLyrics;
  late bool _preferEmbedded;
  late bool _autoFetchMeta;
  late bool _splitMulti;
  late int _doubleTapSeek;
  late int _minTrackSec;
  late Color _selectedAccent;

  int _ytThumbBytes = 0;
  String _localCacheSizeLabel = 'Calculating...';

  @override
  void initState() {
    super.initState();
    final w = widget.hubWidget;
    _usbDac = w.usbDacExclusive;
    _gapless = w.gaplessPlayback;
    _notif = w.mediaNotificationEnabled;
    _pitchBlack = w.usePitchBlack;
    _autoColor = w.autoColoring;
    _ambientGlow = w.ambientGlow;
    _blurredBackdrop = w.blurredBackdrop;
    _showBadges = w.showCodecBadges;
    _compactTiles = w.compactTrackTiles;
    _forceMiniColor = w.forceMiniColor;
    _resumeStartup = w.resumeSessionOnStartup;
    _pauseDisconnect = w.pauseOnDisconnect;
    _ignoreShort = w.ignoreShortClips;
    _syllableLyrics = w.syllableLyricsEnabled;
    _preferEmbedded = w.preferEmbeddedLyrics;
    _autoFetchMeta = w.autoFetchOnlineMetadata;
    _splitMulti = w.splitMultiArtists;
    _doubleTapSeek = w.doubleTapSeekSec.clamp(3, 30);
    _minTrackSec = w.minTrackSeconds.clamp(0, 60);
    _selectedAccent = w.currentAccentColor ?? const Color(0xFF8B5CF6);

    if (widget.categoryIndex == 5) {
      _measureCaches();
    }
  }

  Future<void> _measureCaches() async {
    try {
      final dir = Directory('${Directory.systemTemp.path}/nami_yt_thumbs');
      int total = 0;
      if (dir.existsSync()) {
        for (final f in dir.listSync(recursive: true)) {
          if (f is File) total += f.lengthSync();
        }
      }
      if (mounted) setState(() => _ytThumbBytes = total);
    } catch (_) {}

    if (widget.hubWidget.thumbCacheSizeFuture != null) {
      try {
        final sz = await widget.hubWidget.thumbCacheSizeFuture!;
        if (mounted) setState(() => _localCacheSizeLabel = sz);
      } catch (_) {
        if (mounted) setState(() => _localCacheSizeLabel = 'Available');
      }
    } else if (mounted) {
      setState(() => _localCacheSizeLabel = 'Ready');
    }
  }

  Future<void> _clearYtThumbCache() async {
    try {
      final dir = Directory('${Directory.systemTemp.path}/nami_yt_thumbs');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
    if (mounted) {
      setState(() => _ytThumbBytes = 0);
      NamiLiveToastController.showMessage(
        'Cleared YouTube thumbnail cache',
        icon: Icons.cleaning_services_rounded,
      );
    }
  }

  void _resetCategoryDefaults() {
    NamiUxPrefs.hapticLight();
    setState(() {
      switch (widget.categoryIndex) {
        case 0:
          _pitchBlack = true;
          _autoColor = false;
          _ambientGlow = true;
          _blurredBackdrop = false;
          widget.hubWidget.onPitchBlackChanged?.call(true);
          widget.hubWidget.onAutoColoringChanged?.call(false);
          widget.hubWidget.onAmbientGlowChanged?.call(true);
          widget.hubWidget.onBlurredBackdropChanged?.call(false);
          NamiUxPrefs.enableGlowEffect = true;
          NamiUxPrefs.enableBlurEffect = false;
          break;
        case 1:
          _ignoreShort = true;
          _minTrackSec = 10;
          widget.hubWidget.onIgnoreShortClipsChanged?.call(true);
          widget.hubWidget.onMinTrackSecondsChanged?.call(10);
          NamiUxPrefs.indiaFirstMetadata = true;
          break;
        case 2:
          _gapless = true;
          NamiUxPrefs.gaplessPlayback = true;
          NamiUxPrefs.replayGainMode = 'track';
          _doubleTapSeek = 10;
          NamiUxPrefs.seekDurationSec = 10;
          widget.hubWidget.onGaplessChanged?.call(true);
          widget.hubWidget.onReplayGainChanged?.call('Track');
          widget.hubWidget.onDoubleTapSeekChanged?.call(10);
          NamiUxPrefs.startSleepTimer(null, widget.hubWidget.onSleepExpire);
          widget.hubWidget.onApplyAudioProps();
          break;
        case 3:
          NamiUxPrefs.motionSpeed = 'balanced';
          NamiUxPrefs.hapticsEnabled = true;
          NamiUxPrefs.breathingCoverArt = true;
          NamiUxPrefs.lyricsBlurDepth = true;
          NamiUxPrefs.doubleTapArtLyrics = true;
          NamiUxPrefs.swipeDownDismiss = true;
          NamiUxPrefs.trackRowSwipeActions = true;
          NamiUxPrefs.immersiveMode = false;
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          break;
        case 4:
          NamiUxPrefs.youtubeRegion = 'IN';
          NamiUxPrefs.youtubeAudioQuality = 'High (Opus)';
          NamiUxPrefs.ytSponsorBlock = true;
          NamiUxPrefs.ytReturnDislike = true;
          NamiUxPrefs.ytAutoStartRadio = true;
          NamiUxPrefs.ytSearchCleanup = true;
          break;
        case 5:
          NamiUxPrefs.imageCacheLimitMb = 256;
          PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;
          break;
      }
    });
    NamiUxPrefs.save();
    NamiLiveToastController.showMessage(
      'Reset ${_titles[widget.categoryIndex]} to defaults',
      icon: Icons.restore_rounded,
    );
  }

  Widget _divider() => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Colors.white.withValues(alpha: 0.055),
      );

  Widget _switchRow({
    required IconData icon,
    required String title,
    String subtitle = '',
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () {
        NamiUxPrefs.hapticLight();
        setState(() => onChanged(!value));
        NamiUxPrefs.save();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 21),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.4, color: Colors.white54, height: 1.25),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _NamiMonoSwitch(
              value: value,
              onChanged: (v) {
                setState(() => onChanged(v));
                NamiUxPrefs.save();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    String subtitle = '',
    required VoidCallback onTap,
    String? trailingText,
    bool showChevron = false,
  }) {
    return InkWell(
      onTap: () {
        NamiUxPrefs.hapticLight();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 21),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.4, color: Colors.white54, height: 1.25),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ],
            if (showChevron) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 19),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pillChoiceRow({
    required IconData icon,
    required String title,
    String subtitle = '',
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white54, size: 21),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11.4, color: Colors.white54),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: NamiSpringTap(
                    pressedScale: 0.95,
                    onTap: () {
                      setState(() => onSelect(options[i]));
                      NamiUxPrefs.save();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == options[i]
                            ? accent.withValues(alpha: 0.18)
                            : const Color(0xFF14141A),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: selected == options[i]
                              ? accent.withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.08),
                          width: 0.9,
                        ),
                      ),
                      child: Text(
                        options[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.4,
                          fontWeight: selected == options[i] ? FontWeight.w800 : FontWeight.w600,
                          color: selected == options[i] ? accent : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNamiAboutPage(Color accent) {
    final shell = _NamiHomeShellState.activeInstance;
    final songs = shell?._songs ?? const <AudioTrack>[];
    final trackCount = songs.length;
    final albumCount = songs.map((s) => s.album.trim()).where((a) => a.isNotEmpty).toSet().length;
    final artistCount =
        songs.map((s) => cleanArtistStr(s.artist).trim()).where((a) => a.isNotEmpty).toSet().length;
    final genreCount = songs.map((s) => s.genre.trim()).where((g) => g.isNotEmpty).toSet().length;
    int totalSec = 0;
    for (final s in songs) {
      totalSec += s.duration.inSeconds;
    }
    final totalHours = totalSec ~/ 3600;
    final totalMins = (totalSec % 3600) ~/ 60;

    final ytHist = NamiYoutubeStore.instance.history;
    int ytPlays = 0;
    int ytSec = 0;
    for (final t in ytHist) {
      ytPlays += t.playCount;
      ytSec += t.duration.inSeconds * (t.playCount > 0 ? t.playCount : 1);
    }
    final ytHours = ytSec ~/ 3600;
    final ytMins = (ytSec % 3600) ~/ 60;

    Widget statPill(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 15),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11.8, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    Widget milestoneChip(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 15),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11.6, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 155),
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 44),
              padding: const EdgeInsets.fromLTRB(18, 56, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Nami',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'v3.8.0 (v53)',
                    style: TextStyle(color: Colors.white70, fontSize: 12.6, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '120Hz AMOLED Audiophile Player',
                    style: TextStyle(color: Colors.white54, fontSize: 11.4),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withValues(alpha: 0.45)),
                        ),
                        child: NamiCustomIcon(NamiCustomIcons.artist, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Developer',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Piyush1625',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      NamiSpringTap(
                        pressedScale: 0.90,
                        onTap: () {
                          Clipboard.setData(
                            const ClipboardData(text: 'https://github.com/Piyush1625/Nami-Music'),
                          );
                          NamiLiveToastController.showMessage(
                            'Copied GitHub repo URL',
                            icon: Icons.code_rounded,
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.code_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1614),
                border: Border.all(color: accent.withValues(alpha: 0.55), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: NamiCustomIcon(NamiCustomIcons.equalizer, size: 44),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.public_rounded, color: Colors.white54, size: 22),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nami Open Source',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Direct GitHub Releases updater & AMOLED Widget',
                            style: TextStyle(color: Colors.white54, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _divider(),
              if (widget.hubWidget.onCheckForUpdates != null) ...[
                _actionRow(
                  icon: Icons.system_update_outlined,
                  title: 'Check for GitHub Release Updates',
                  subtitle: 'github.com/Piyush1625/Nami-Music',
                  trailingText: 'Check',
                  onTap: widget.hubWidget.onCheckForUpdates!,
                ),
                _divider(),
              ],
              _actionRow(
                icon: Icons.widgets_outlined,
                title: 'Sync AMOLED Home Screen Widget',
                subtitle: 'Long-press launcher -> Widgets -> Nami Music (4×1)',
                onTap: () {
                  widget.hubWidget.onSyncWidgetNow();
                  NamiLiveToastController.showMessage(
                    'Synced Nami AMOLED Widget',
                    icon: Icons.widgets_rounded,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  NamiUxPrefs.hapticLight();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const NamiStatsChartsScreen()),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: Colors.white54, size: 22),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Statistics & Charts',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tap to open 7-Day Activity, Format & Top Artist Charts',
                            style: TextStyle(color: Colors.white54, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  statPill(Icons.music_note_rounded, '$trackCount Tracks'),
                  statPill(Icons.album_outlined, '$albumCount Albums'),
                  statPill(Icons.mic_none_rounded, '$artistCount Artists'),
                  statPill(Icons.category_outlined, '$genreCount Genres'),
                  statPill(Icons.schedule_rounded, '${totalHours}h ${totalMins}min Total Duration'),
                  statPill(Icons.ondemand_video_rounded, '${ytHours}h ${ytMins}min YouTube ($ytPlays plays)'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, color: Colors.white54, size: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nami v3.8.0 Stable Engine',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '6/6 core audiophile modules active',
                          style: TextStyle(color: Colors.white54, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  milestoneChip(Icons.usb_rounded, 'Bit-Perfect USB DAC'),
                  milestoneChip(Icons.bolt_rounded, '120Hz Butter Motion'),
                  milestoneChip(Icons.lyrics_outlined, 'Synced Lyrics'),
                  milestoneChip(Icons.public_rounded, 'India-First Metadata'),
                  milestoneChip(Icons.play_circle_outline_rounded, 'YouTube Proxy Stream'),
                  milestoneChip(Icons.extension_outlined, 'Mornye Extensions'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryCardItems(Color accent) {
    final w = widget.hubWidget;
    final shell = _NamiHomeShellState.activeInstance;
    final songs = shell?._songs ?? const <AudioTrack>[];
    final outName = w.outputDevice.isNotEmpty ? w.outputDevice : 'Phone Speaker';

    switch (widget.categoryIndex) {
      case 0: // Theme & Appearance
        return [
          if (w.onPitchBlackChanged != null)
            _switchRow(
              icon: Icons.contrast_rounded,
              title: 'Use Pitch Black',
              subtitle: 'Pure #000000 AMOLED canvas across the entire player',
              value: _pitchBlack,
              onChanged: (v) {
                _pitchBlack = v;
                NamiUxPrefs.usePitchBlack = v;
                w.onPitchBlackChanged!(v);
              },
            ),
          if (w.onAutoColoringChanged != null)
            _switchRow(
              icon: Icons.color_lens_outlined,
              title: 'Auto Coloring',
              subtitle: 'Automatically pick accent colors from current artwork',
              value: _autoColor,
              onChanged: (v) {
                _autoColor = v;
                NamiUxPrefs.autoColoring = v;
                w.onAutoColoringChanged!(v);
              },
            ),
          if (w.onForceMiniColorChanged != null)
            _switchRow(
              icon: Icons.play_lesson_outlined,
              title: 'Force miniplayer to follow track colors',
              subtitle: 'Tints mini-player accent from the active track artwork',
              value: _forceMiniColor,
              onChanged: (v) {
                _forceMiniColor = v;
                w.onForceMiniColorChanged!(v);
              },
            ),
          _divider(),
          _switchRow(
            icon: Icons.flare_rounded,
            title: 'Ambient Cover Glow',
            subtitle: 'Subtle radial accent glow behind Now Playing artwork',
            value: _ambientGlow,
            onChanged: (v) {
              _ambientGlow = v;
              NamiUxPrefs.enableGlowEffect = v;
              w.onAmbientGlowChanged?.call(v);
            },
          ),
          _switchRow(
            icon: Icons.blur_on_rounded,
            title: 'Enable Real-Time Blur Effect',
            subtitle: 'OFF by default to keep scrolling locked at 120fps',
            value: _blurredBackdrop,
            onChanged: (v) {
              _blurredBackdrop = v;
              NamiUxPrefs.enableBlurEffect = v;
              w.onBlurredBackdropChanged?.call(v);
            },
          ),
          if (w.onShowCodecBadgesChanged != null)
            _switchRow(
              icon: Icons.high_quality_outlined,
              title: 'Show Codec / Format Badges',
              subtitle: 'Displays FLAC / ALAC / YT OPUS badges on track rows',
              value: _showBadges,
              onChanged: (v) {
                _showBadges = v;
                w.onShowCodecBadgesChanged!(v);
              },
            ),
          if (w.onCompactTrackTilesChanged != null)
            _switchRow(
              icon: Icons.view_headline_rounded,
              title: 'Compact Track Rows',
              subtitle: 'Fits more songs on screen at once',
              value: _compactTiles,
              onChanged: (v) {
                _compactTiles = v;
                w.onCompactTrackTilesChanged!(v);
              },
            ),
          if (w.onAccentColorChanged != null) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.palette_outlined, color: Colors.white54, size: 21),
                      SizedBox(width: 15),
                      Text(
                        'Accent Color',
                        style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final col in _accentSwatches)
                        GestureDetector(
                          onTap: () {
                            NamiUxPrefs.hapticLight();
                            setState(() => _selectedAccent = col);
                            w.onAccentColorChanged!(col);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedAccent.toARGB32() == col.toARGB32()
                                    ? Colors.white
                                    : Colors.white24,
                                width: _selectedAccent.toARGB32() == col.toARGB32() ? 2.6 : 1.0,
                              ),
                            ),
                            child: _selectedAccent.toARGB32() == col.toARGB32()
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: col.computeLuminance() > 0.6 ? Colors.black : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ];

      case 1: // Library & Indexer
        final artCount = songs
            .where((s) => (s.thumbPath != null && s.thumbPath!.isNotEmpty) || s.albumArt != null)
            .length;
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131318),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const NamiCustomIcon(NamiCustomIcons.tracks, size: 16, opacity: 0.65),
                        const SizedBox(width: 6),
                        Text(
                          'Tracks: ${songs.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131318),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_outlined, color: Colors.white60, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Artworks: $artCount/${songs.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (w.onOpenFolderExplorer != null)
            _actionRow(
              icon: Icons.create_new_folder_outlined,
              title: 'Manage Scan Folders',
              subtitle: '${w.folderCount} active music folder(s)',
              showChevron: true,
              onTap: w.onOpenFolderExplorer!,
            ),
          _actionRow(
            icon: Icons.folder_special_outlined,
            title: 'Grant Full Storage Access',
            subtitle: 'Required on Android 11+ for direct FLAC tag & cover writing',
            trailingText: 'Grant',
            onTap: w.onGrantStorage,
          ),
          _actionRow(
            icon: Icons.refresh_rounded,
            title: 'Refresh Library Now',
            subtitle: 'Verifies local files & updates library banner',
            onTap: () => shell?._handleV29TracksPullRefresh(),
          ),
          _divider(),
          if (w.onIgnoreShortClipsChanged != null)
            _switchRow(
              icon: Icons.content_cut_rounded,
              title: 'Ignore Short Audio Clips',
              subtitle: 'Filters out ringtones & short voice notes',
              value: _ignoreShort,
              onChanged: (v) {
                _ignoreShort = v;
                w.onIgnoreShortClipsChanged!(v);
              },
            ),
          if (w.onMinTrackSecondsChanged != null)
            NamiWaveformSlider(
              leadingIcon: Icons.timer_outlined,
              title: 'Minimum Track Duration',
              subtitle: 'Skips audio clips shorter than threshold',
              value: _minTrackSec.toDouble(),
              min: 0,
              max: 60,
              divisions: 12,
              valueFormatter: (v) => '${v.round()} s',
              accentColor: accent,
              onChanged: (v) {
                final sec = v.round();
                setState(() => _minTrackSec = sec);
                w.onMinTrackSecondsChanged!(sec);
              },
            ),
          if (w.onSplitMultiArtistsChanged != null)
            _switchRow(
              icon: Icons.mic_none_rounded,
              title: 'Split Multi-Artist Credits',
              subtitle: 'Separates featured & collaborating artists cleanly',
              value: _splitMulti,
              onChanged: (v) {
                _splitMulti = v;
                w.onSplitMultiArtistsChanged!(v);
              },
            ),
          if (w.onAutoFetchMetadataChanged != null)
            _switchRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Auto-Fetch Online Metadata',
              subtitle: 'Enriches missing artwork & artist portraits automatically',
              value: _autoFetchMeta,
              onChanged: (v) {
                _autoFetchMeta = v;
                w.onAutoFetchMetadataChanged!(v);
              },
            ),
          _divider(),
          _pillChoiceRow(
            icon: Icons.public_rounded,
            title: 'Metadata & Artwork Priority',
            subtitle: 'India-First (JioSaavn IN + Apple Music IN) vs Global',
            options: const ['India-First', 'Global'],
            selected: NamiUxPrefs.indiaFirstMetadata ? 'India-First' : 'Global',
            onSelect: (opt) => NamiUxPrefs.indiaFirstMetadata = opt == 'India-First',
          ),
          _actionRow(
            icon: Icons.merge_type_rounded,
            title: 'Merge / Alias Duplicate Artists',
            subtitle: 'Combine variants like A. R. Rahman & A.R. Rahman',
            showChevron: true,
            onTap: w.onMergeArtists,
          ),
          _actionRow(
            icon: Icons.cleaning_services_outlined,
            title: 'Fix Blank / Mic Placeholder Artist Photos',
            subtitle: 'Purges broken placeholders & fetches official portraits',
            onTap: w.onPurgePlaceholders,
          ),
          _actionRow(
            icon: Icons.cloud_download_outlined,
            title: 'Batch Fetch Missing Artist Portraits',
            subtitle: 'Downloads high-res portraits for Indian & global artists',
            onTap: w.onBatchFetchArtists,
          ),
          if (w.onFetchMissingCovers != null)
            _actionRow(
              icon: Icons.image_search_rounded,
              title: 'Fetch Missing Album Covers',
              subtitle: 'Scans local albums without artwork & pulls HD covers',
              onTap: () => w.onFetchMissingCovers!(),
            ),
        ];

      case 2: // Playback & DAC (Zero dead toggles, zero EQ duplication!)
        return [
          if (w.onUsbDacChanged != null)
            _switchRow(
              icon: Icons.usb_rounded,
              title: 'Bit-Perfect USB DAC Exclusive',
              subtitle: 'Active output: $outName',
              value: _usbDac,
              onChanged: (v) {
                _usbDac = v;
                w.onUsbDacChanged!(v);
              },
            ),
          _actionRow(
            icon: Icons.settings_input_component_rounded,
            title: 'Request Direct USB DAC Permission',
            subtitle: 'Grant hardware access for attached USB DAC',
            trailingText: 'Request',
            onTap: w.onRequestUsbDac,
          ),
          _actionRow(
            icon: Icons.memory_rounded,
            title: 'Audio Engine, 16 KiB & UAC2 Diagnostics',
            subtitle: 'Inspect USB DAC path, 16 KiB alignment & YT local cache',
            showChevron: true,
            onTap: () => showNamiAudioHardwareDiagnosticsSheet(
              context,
              outputDevice: outName,
              usbDacExclusive: _usbDac,
              onRequestUsbDac: w.onRequestUsbDac,
            ),
          ),
          _divider(),
          _pillChoiceRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Normalize audio (ReplayGain)',
            subtitle: 'Applies libmpv replaygain across tracks & albums',
            options: const ['Off', 'Track', 'Album'],
            selected: NamiUxPrefs.replayGainMode == 'no'
                ? 'Off'
                : (NamiUxPrefs.replayGainMode == 'album' ? 'Album' : 'Track'),
            onSelect: (opt) {
              NamiUxPrefs.replayGainMode =
                  opt == 'Off' ? 'no' : (opt == 'Album' ? 'album' : 'track');
              w.onReplayGainChanged?.call(opt);
              w.onApplyAudioProps();
            },
          ),
          _switchRow(
            icon: Icons.all_inclusive_rounded,
            title: 'True Gapless Playback (libmpv)',
            subtitle: 'Zero silence between tracks on continuous albums',
            value: _gapless,
            onChanged: (v) {
              _gapless = v;
              NamiUxPrefs.gaplessPlayback = v;
              w.onGaplessChanged?.call(v);
              w.onApplyAudioProps();
            },
          ),
          _divider(),
          ValueListenableBuilder<Duration?>(
            valueListenable: NamiUxPrefs.sleepRemaining,
            builder: (_, rem, __) {
              final curLabel = rem == null
                  ? 'Off'
                  : (rem.inMinutes <= 15
                      ? '15m'
                      : (rem.inMinutes <= 30
                          ? '30m'
                          : (rem.inMinutes <= 45 ? '45m' : '60m')));
              return _pillChoiceRow(
                icon: Icons.bedtime_outlined,
                title: rem == null
                    ? 'Sleep Timer'
                    : 'Sleep Timer (${rem.inMinutes.toString().padLeft(2, '0')}:${(rem.inSeconds % 60).toString().padLeft(2, '0')})',
                subtitle: 'Smoothly pauses playback when timer finishes',
                options: const ['Off', '15m', '30m', '45m', '60m'],
                selected: curLabel,
                onSelect: (opt) {
                  if (opt == 'Off') {
                    NamiUxPrefs.startSleepTimer(null, w.onSleepExpire);
                  } else {
                    final mins = int.tryParse(opt.replaceAll('m', '')) ?? 30;
                    NamiUxPrefs.startSleepTimer(Duration(minutes: mins), w.onSleepExpire);
                  }
                },
              );
            },
          ),
          _switchRow(
            icon: Icons.history_rounded,
            title: 'Resume Session on Startup',
            subtitle: 'Restores active track, queue & playback timestamp',
            value: _resumeStartup,
            onChanged: (v) {
              _resumeStartup = v;
              NamiUxPrefs.persistSession = v;
              w.onResumeSessionChanged?.call(v);
            },
          ),
          if (w.onPauseOnDisconnectChanged != null)
            _switchRow(
              icon: Icons.headset_off_rounded,
              title: 'Pause on Audio Disconnect',
              subtitle: 'Auto-pauses when Bluetooth or USB DAC unplugs',
              value: _pauseDisconnect,
              onChanged: (v) {
                _pauseDisconnect = v;
                w.onPauseOnDisconnectChanged!(v);
              },
            ),
          if (w.onNotificationChanged != null)
            _switchRow(
              icon: Icons.notifications_none_rounded,
              title: 'Media Notification Controls',
              subtitle: 'Lock-screen & shade playback controls',
              value: _notif,
              onChanged: (v) {
                _notif = v;
                w.onNotificationChanged!(v);
              },
            ),
          if (w.onDoubleTapSeekChanged != null)
            NamiWaveformSlider(
              leadingIcon: Icons.forward_10_rounded,
              title: 'Double-Tap Seek Duration',
              subtitle: 'Jump step on seek controls',
              value: _doubleTapSeek.toDouble(),
              min: 3,
              max: 30,
              divisions: 27,
              valueFormatter: (v) => '${v.round()}s',
              accentColor: accent,
              onChanged: (v) {
                final sec = v.round();
                setState(() => _doubleTapSeek = sec);
                NamiUxPrefs.seekDurationSec = sec;
                w.onDoubleTapSeekChanged!(sec);
                NamiUxPrefs.save();
              },
            ),
        ];

      case 3: // Motion, Lyrics & Gestures
        return [
          _pillChoiceRow(
            icon: Icons.bolt_rounded,
            title: '120Hz Animation Tempo',
            subtitle: 'Scales spring morph, tab swipe & sheet transitions',
            options: const ['Snappy', 'Balanced', 'Silky'],
            selected: NamiUxPrefs.motionSpeed == 'snappy'
                ? 'Snappy'
                : (NamiUxPrefs.motionSpeed == 'silky' ? 'Silky' : 'Balanced'),
            onSelect: (opt) => NamiUxPrefs.motionSpeed = opt.toLowerCase(),
          ),
          _divider(),
          _switchRow(
            icon: Icons.vibration_rounded,
            title: 'Haptic Detents',
            subtitle: 'Tactile micro-clicks on taps, waveform scrubs & swipes',
            value: NamiUxPrefs.hapticsEnabled,
            onChanged: (v) => NamiUxPrefs.hapticsEnabled = v,
          ),
          _switchRow(
            icon: Icons.album_outlined,
            title: 'Breathing Cover Art',
            subtitle: 'Subtle play/pause artwork scale animation',
            value: NamiUxPrefs.breathingCoverArt,
            onChanged: (v) => NamiUxPrefs.breathingCoverArt = v,
          ),
          if (w.onSyllableLyricsChanged != null)
            _switchRow(
              icon: Icons.subtitles_outlined,
              title: 'Word-by-Word Synced Lyrics',
              subtitle: 'Smooth syllable-level live lyric highlighting',
              value: _syllableLyrics,
              onChanged: (v) {
                _syllableLyrics = v;
                w.onSyllableLyricsChanged!(v);
              },
            ),
          if (w.onPreferEmbeddedLyricsChanged != null)
            _switchRow(
              icon: Icons.description_outlined,
              title: 'Prefer Embedded File Lyrics',
              subtitle: 'Reads local FLAC/MP3 lyrics tags before online lookup',
              value: _preferEmbedded,
              onChanged: (v) {
                _preferEmbedded = v;
                w.onPreferEmbeddedLyricsChanged!(v);
              },
            ),
          _switchRow(
            icon: Icons.lyrics_outlined,
            title: 'Synced Lyrics Blur Depth',
            subtitle: 'Soft blur on inactive lyric lines',
            value: NamiUxPrefs.lyricsBlurDepth,
            onChanged: (v) => NamiUxPrefs.lyricsBlurDepth = v,
          ),
          _switchRow(
            icon: Icons.touch_app_outlined,
            title: 'Double-Tap Art for Lyrics',
            subtitle: 'Toggle synced lyrics directly from cover art',
            value: NamiUxPrefs.doubleTapArtLyrics,
            onChanged: (v) => NamiUxPrefs.doubleTapArtLyrics = v,
          ),
          _switchRow(
            icon: Icons.keyboard_arrow_down_rounded,
            title: 'Interactive Swipe-Down Dismiss',
            subtitle: '1:1 finger-tracked collapse to Mini-Player',
            value: NamiUxPrefs.swipeDownDismiss,
            onChanged: (v) => NamiUxPrefs.swipeDownDismiss = v,
          ),
          _switchRow(
            icon: Icons.swipe_rounded,
            title: 'Track Row Swipe Actions',
            subtitle: 'Swipe left for Play After, right for Track Info',
            value: NamiUxPrefs.trackRowSwipeActions,
            onChanged: (v) => NamiUxPrefs.trackRowSwipeActions = v,
          ),
          _switchRow(
            icon: Icons.fullscreen_rounded,
            title: 'Immersive Fullscreen Now Playing',
            subtitle: 'Hides status & navigation bars when Now Playing expands',
            value: NamiUxPrefs.immersiveMode,
            onChanged: (v) {
              NamiUxPrefs.immersiveMode = v;
              if (!v) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              }
            },
          ),
        ];

      case 4: // YouTube & Mornye
        return [
          _switchRow(
            icon: Icons.block_rounded,
            title: 'SponsorBlock Auto-Skip',
            subtitle: 'Skips sponsors, intros & non-music segments during playback',
            value: NamiUxPrefs.ytSponsorBlock,
            onChanged: (v) => NamiUxPrefs.ytSponsorBlock = v,
          ),
          _switchRow(
            icon: Icons.thumb_down_outlined,
            title: 'Return YouTube Dislike',
            subtitle: 'Fetches community like & dislike stats on Watch sheet',
            value: NamiUxPrefs.ytReturnDislike,
            onChanged: (v) => NamiUxPrefs.ytReturnDislike = v,
          ),
          _divider(),
          _pillChoiceRow(
            icon: Icons.public_rounded,
            title: 'YouTube Music Region',
            subtitle: 'India-first charts, mixes & Bollywood/DHH feeds',
            options: const ['IN', 'US', 'Global'],
            selected: NamiUxPrefs.youtubeRegion,
            onSelect: (opt) { NamiUxPrefs.youtubeRegion = opt; NamiYoutubeService.instance.clearAllCaches(); },
          ),
          _pillChoiceRow(
            icon: Icons.ondemand_video_rounded,
            title: 'Default Video Quality',
            subtitle: 'Default YouTube video resolution (480p recommended for fast 5G start)',
            options: const ['360p', '480p', '720p', '1080p'],
            selected: NamiUxPrefs.ytDefaultMode.replaceAll('Video ', ''),
            onSelect: (opt) { NamiUxPrefs.hapticLight(); NamiUxPrefs.ytDefaultMode = 'Video $opt'; NamiUxPrefs.save(); },
          ),
          _pillChoiceRow(
            icon: Icons.speed_rounded,
            title: 'YouTube Data Saver',
            subtitle: 'Caps auto video quality & bandwidth usage on mobile data',
            options: const ['Off', 'Medium', 'High'],
            selected: NamiUxPrefs.ytDataSaver,
            onSelect: (opt) => NamiUxPrefs.ytDataSaver = opt,
          ),
          _pillChoiceRow(
            icon: Icons.video_settings_rounded,
            title: 'Preferred Video Codec',
            subtitle: 'H.264 MP4 gives fastest hardware decode on every Android device',
            options: const ['H.264 MP4', 'Auto Best'],
            selected: NamiUxPrefs.ytPreferredCodec,
            onSelect: (opt) => NamiUxPrefs.ytPreferredCodec = opt,
          ),
          _switchRow(
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'Live Video in Mini-Player',
            subtitle: 'Plays live hardware video inside the floating YouTube mini-player bar',
            value: NamiUxPrefs.ytMiniPlayerVideo,
            onChanged: (v) => NamiUxPrefs.ytMiniPlayerVideo = v,
          ),
          _switchRow(
            icon: Icons.touch_app_outlined,
            title: 'Video Player Gestures',
            subtitle: 'Double-tap ±10s seek, hold for 2x speed & swipe-down minimize',
            value: NamiUxPrefs.ytVideoGestures,
            onChanged: (v) => NamiUxPrefs.ytVideoGestures = v,
          ),
          _switchRow(
            icon: Icons.battery_saver_rounded,
            title: 'Pause Video Decoder in Background',
            subtitle: 'Saves battery when app is minimized while audio keeps playing',
            value: NamiUxPrefs.ytBackgroundVideoPause,
            onChanged: (v) => NamiUxPrefs.ytBackgroundVideoPause = v,
          ),
          _switchRow(
            icon: Icons.screen_rotation_rounded,
            title: 'Auto-Rotate on Fullscreen',
            subtitle: 'Switches to landscape orientation when tapping fullscreen',
            value: NamiUxPrefs.ytAutoRotateFullscreen,
            onChanged: (v) => NamiUxPrefs.ytAutoRotateFullscreen = v,
          ),
          _pillChoiceRow(
            icon: Icons.sd_storage_outlined,
            title: 'Max YouTube Audio Cache',
            subtitle: 'Controls automatic LRU cache budget for 0ms offline replay',
            options: const ['256 MB', '512 MB', '1024 MB'],
            selected: '${NamiUxPrefs.ytMaxCacheMb} MB',
            onSelect: (opt) {
              NamiUxPrefs.ytMaxCacheMb =
                  int.tryParse(opt.replaceAll(RegExp(r'[^0-9]'), '')) ?? 512;
            },
          ),
          _pillChoiceRow(
            icon: Icons.high_quality_outlined,
            title: 'Stream Audio Quality',
            subtitle: 'Direct localhost-proxied libmpv stream selection',
            options: const ['High (Opus)', 'Balanced', 'Data Saver'],
            selected: NamiUxPrefs.youtubeAudioQuality,
            onSelect: (opt) { NamiUxPrefs.youtubeAudioQuality = opt; NamiYoutubeService.instance.clearAllCaches(); },
          ),
          _divider(),
          _switchRow(
            icon: Icons.podcasts_rounded,
            title: 'Auto Start Radio',
            subtitle: 'Queues related mix tracks automatically after a track',
            value: NamiUxPrefs.ytAutoStartRadio,
            onChanged: (v) => NamiUxPrefs.ytAutoStartRadio = v,
          ),
          _switchRow(
            icon: Icons.cleaning_services_outlined,
            title: 'Enable Search Cleanup',
            subtitle: 'Normalizes search queries for cleaner YouTube matches',
            value: NamiUxPrefs.ytSearchCleanup,
            onChanged: (v) => NamiUxPrefs.ytSearchCleanup = v,
          ),
          _divider(),
          ValueListenableBuilder<bool>(
            valueListenable: NamiYoutubeService.isSignedIn,
            builder: (_, signedIn, __) => _actionRow(
              icon: signedIn ? Icons.verified_user_rounded : Icons.shield_outlined,
              title: 'YouTube Account & BotGuard Mode',
              subtitle: signedIn
                  ? 'Signed In • Tap to manage or switch to Logged-Out mode'
                  : 'Logged-Out Anonymous Mode (BotGuard) • Optional Sign-In',
              trailingText: signedIn ? 'Signed In' : 'Guest',
              showChevron: true,
              onTap: () => showNamiYoutubeAccountSheet(context),
            ),
          ),
          if (w.onOpenExtensionRepo != null) ...[
            _divider(),
            _actionRow(
              icon: Icons.extension_outlined,
              title: 'Mornye Extension Repository',
              subtitle: 'Manage lossless FLAC sources & extensions',
              showChevron: true,
              onTap: w.onOpenExtensionRepo!,
            ),
          ],
        ];

      default: // 5: Backup, Cache & Sync (consolidated, zero dead controls)
        final ytThumbMb = (_ytThumbBytes / (1024 * 1024)).toStringAsFixed(2);
        return [
          if (w.onExportBackup != null)
            _actionRow(
              icon: Icons.upload_file_rounded,
              title: 'Export .nami-backup Archive',
              subtitle: 'Save playlists, favorites, artist aliases & preferences',
              trailingText: 'Export',
              onTap: w.onExportBackup!,
            ),
          if (w.onImportBackup != null)
            _actionRow(
              icon: Icons.download_outlined,
              title: 'Import .nami-backup Archive',
              subtitle: 'Restore your saved Nami library backup',
              trailingText: 'Import',
              onTap: w.onImportBackup!,
            ),
          if (w.onOpenScrobbling != null) ...[
            _divider(),
            _actionRow(
              icon: Icons.podcasts_rounded,
              title: 'ListenBrainz Scrobbling',
              subtitle: 'Sync your listening history & stats',
              showChevron: true,
              onTap: w.onOpenScrobbling!,
            ),
          ],
          _divider(),
          _actionRow(
            icon: Icons.widgets_outlined,
            title: 'Sync AMOLED Home Screen Widget (4×1)',
            subtitle: 'Pushes current track & artwork to Android home widget',
            trailingText: 'Sync',
            onTap: () {
              w.onSyncWidgetNow();
              NamiLiveToastController.showMessage(
                'Refreshed Nami AMOLED Widget',
                icon: Icons.widgets_rounded,
              );
            },
          ),
          _divider(),
          NamiWaveformSlider(
            leadingIcon: Icons.memory_rounded,
            title: 'In-Memory Image Cache Limit',
            subtitle: 'Controls Flutter decoded artwork RAM budget',
            value: NamiUxPrefs.imageCacheLimitMb.toDouble().clamp(64, 1024),
            min: 64,
            max: 1024,
            divisions: 15,
            valueFormatter: (v) => '${v.round()} MB',
            accentColor: accent,
            onChanged: (v) {
              final mb = v.round();
              setState(() => NamiUxPrefs.imageCacheLimitMb = mb);
              PaintingBinding.instance.imageCache.maximumSizeBytes = mb * 1024 * 1024;
              NamiUxPrefs.save();
            },
          ),
          if (w.onClearThumbCache != null)
            _actionRow(
              icon: Icons.image_not_supported_outlined,
              title: 'Clear Local Cover Art Cache',
              subtitle: 'Used: $_localCacheSizeLabel',
              trailingText: 'Clear',
              onTap: () async {
                await w.onClearThumbCache!();
                _measureCaches();
                NamiLiveToastController.showMessage(
                  'Cleared local cover cache',
                  icon: Icons.cleaning_services_rounded,
                );
              },
            ),
          _actionRow(
            icon: Icons.delete_sweep_outlined,
            title: 'Clear YouTube Thumbnail Cache',
            subtitle: 'Used: $ytThumbMb MB',
            trailingText: 'Clear',
            onTap: _clearYtThumbCache,
          ),
          _actionRow(
            icon: Icons.audio_file_outlined,
            title: 'Clear YouTube Cached Audio Files',
            subtitle: 'Frees local offline YouTube stream cache (nami_yt_cache)',
            trailingText: 'Clear',
            onTap: () async {
              await NamiYtAudioCache.instance.clearAll();
              NamiLiveToastController.showMessage(
                'Cleared YouTube audio cache',
                icon: Icons.cleaning_services_rounded,
              );
            },
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final idx = widget.categoryIndex.clamp(0, _titles.length - 1);
    final isAbout = idx == 6;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
          onPressed: () {
            NamiUxPrefs.hapticLight();
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          isAbout ? '' : _titles[idx],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search Settings',
            icon: const NamiCustomIcon(NamiCustomIcons.search, size: 22, opacity: 0.78),
            onPressed: widget.onOpenSearch,
          ),
          if (!isAbout)
            IconButton(
              tooltip: 'Reset category defaults',
              icon: const Icon(Icons.restore_rounded, color: Colors.white70, size: 21),
              onPressed: _resetCategoryDefaults,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (isAbout)
            _buildNamiAboutPage(accent)
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 155),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0B0F),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
                        child: Row(
                          children: [
                            Icon(_icons[idx], color: Colors.white60, size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _titles[idx],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '↳ ${_subtitles[idx]}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11.4),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.flag_outlined, color: Colors.white38, size: 20),
                              onPressed: _resetCategoryDefaults,
                            ),
                          ],
                        ),
                      ),
                      _divider(),
                      ..._buildCategoryCardItems(accent),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          if (!isAbout)
            ValueListenableBuilder<bool>(
              valueListenable: NamiExpandablePlayerController.hasSong,
              builder: (_, playingSong, child) => AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                right: 16,
                bottom: playingSong ? 86 : 18,
                child: child!,
              ),
              child: NamiSpringTap(
                pressedScale: 0.92,
                onTap: widget.onOpenSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.60),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NamiCustomIcon(NamiCustomIcons.search, size: 19),
                      SizedBox(width: 8),
                      Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
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
