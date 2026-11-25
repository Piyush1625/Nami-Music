part of '../main.dart';

/// Namida-inspired bespoke vertical-bar waveform slider for numeric settings
/// (Fade Duration, Seek Step, Waveform Bars, etc.) with 1:1 finger scrubbing & haptics.
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
  });

  @override
  State<NamiWaveformSlider> createState() => _NamiWaveformSliderState();
}

class _NamiWaveformSliderState extends State<NamiWaveformSlider> {
  static const List<double> _barPattern = <double>[
    0.34, 0.56, 0.42, 0.78, 0.62, 0.92, 0.48, 0.70, 0.86, 0.52,
    0.64, 0.96, 0.58, 0.44, 0.82, 0.68, 0.90, 0.46, 0.74, 0.60,
    0.88, 0.50, 0.76, 0.94, 0.54, 0.40, 0.80, 0.66, 0.72, 0.48,
    0.84, 0.56,
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

  @override
  Widget build(BuildContext context) {
    final norm = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final activeBars = (norm * _barPattern.length).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(fontSize: 11.8, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.36),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  widget.valueFormatter(widget.value),
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w800,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (_, constraints) {
              final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _handleTouch(d.localPosition.dx, w),
                onHorizontalDragStart: (d) => _handleTouch(d.localPosition.dx, w),
                onHorizontalDragUpdate: (d) => _handleTouch(d.localPosition.dx, w),
                child: SizedBox(
                  height: 36,
                  width: w,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (int i = 0; i < _barPattern.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 90),
                          width: 3.4,
                          height: (8.0 + _barPattern[i] * 24.0),
                          decoration: BoxDecoration(
                            color: i < activeBars
                                ? widget.accentColor
                                : Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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

/// Step 2 (v2.9.5) — Unified Minimal Pitch-Black AMOLED Settings Hub
/// Replaces mixed stacked cards with Namida's single flat category hierarchy,
/// monochrome icons, waveform sliders, floating Search pill & smooth horizontal sub-pages.
class NamiUnifiedSettingsHub extends StatefulWidget {
  final String outputDevice;
  final bool eqEnabled;
  final VoidCallback onGrantStorage;
  final VoidCallback onRequestUsbDac;
  final VoidCallback onMergeArtists;
  final VoidCallback onPurgePlaceholders;
  final VoidCallback onBatchFetchArtists;
  final VoidCallback onSleepExpire;
  final VoidCallback onApplyAudioProps;
  final VoidCallback onSyncWidgetNow;
  final WidgetBuilder classicSettingsBuilder;

  const NamiUnifiedSettingsHub({
    super.key,
    required this.outputDevice,
    required this.eqEnabled,
    required this.onGrantStorage,
    required this.onRequestUsbDac,
    required this.onMergeArtists,
    required this.onPurgePlaceholders,
    required this.onBatchFetchArtists,
    required this.onSleepExpire,
    required this.onApplyAudioProps,
    required this.onSyncWidgetNow,
    required this.classicSettingsBuilder,
  });

  @override
  State<NamiUnifiedSettingsHub> createState() => _NamiUnifiedSettingsHubState();
}

class _NamiUnifiedSettingsHubState extends State<NamiUnifiedSettingsHub> {
  static const List<_NamiSettingSearchEntry> _searchIndex = [
    _NamiSettingSearchEntry(
      title: 'Bit-Perfect USB DAC',
      subtitle: 'Audio & DAC Engine',
      keywords: 'usb dac audio bit perfect hardware output',
      icon: Icons.usb_rounded,
      categoryIndex: 0,
    ),
    _NamiSettingSearchEntry(
      title: 'True Gapless Playback (libmpv)',
      subtitle: 'Audio & DAC Engine',
      keywords: 'gapless libmpv playback seamless audio',
      icon: Icons.join_full_rounded,
      categoryIndex: 0,
    ),
    _NamiSettingSearchEntry(
      title: 'ReplayGain Loudness Normalization',
      subtitle: 'Audio & DAC Engine',
      keywords: 'replaygain loudness volume track album gain',
      icon: Icons.graphic_eq_rounded,
      categoryIndex: 0,
    ),
    _NamiSettingSearchEntry(
      title: 'Sleep Timer',
      subtitle: 'Playback & Sleep Timer',
      keywords: 'sleep timer bedtime pause countdown minutes',
      icon: Icons.bedtime_outlined,
      categoryIndex: 1,
    ),
    _NamiSettingSearchEntry(
      title: 'Fade & Seek Duration (Waveform Sliders)',
      subtitle: 'Playback & Sleep Timer',
      keywords: 'fade seek duration waveform bars slider persist queue',
      icon: Icons.tune_rounded,
      categoryIndex: 1,
    ),
    _NamiSettingSearchEntry(
      title: '120Hz Motion Speed & Haptics',
      subtitle: 'Appearance & 120Hz Motion',
      keywords: '120hz motion speed snappy silky haptics gestures swipe',
      icon: Icons.bolt_rounded,
      categoryIndex: 2,
    ),
    _NamiSettingSearchEntry(
      title: 'Blur, Glow & Lyrics Visuals',
      subtitle: 'Appearance & 120Hz Motion',
      keywords: 'blur glow performance breathing cover art lyrics double tap',
      icon: Icons.blur_on_rounded,
      categoryIndex: 2,
    ),
    _NamiSettingSearchEntry(
      title: 'India-First Metadata & Artist Portraits',
      subtitle: 'Library & Metadata',
      keywords: 'india jiosaavn apple music artist photos placeholder merge storage files',
      icon: Icons.auto_awesome_outlined,
      categoryIndex: 3,
    ),
    _NamiSettingSearchEntry(
      title: 'YouTube Region, Audio Quality & Mornye',
      subtitle: 'YouTube & Mornye',
      keywords: 'youtube mornye extensions opus region local account',
      icon: Icons.play_circle_outline_rounded,
      categoryIndex: 4,
    ),
    _NamiSettingSearchEntry(
      title: 'Theme Colors, Equalizer, Folders & Backup',
      subtitle: 'Theme, Equalizer & Classic Controls',
      keywords: 'theme color accent equalizer eq folders backup restore',
      icon: Icons.palette_outlined,
      categoryIndex: 5,
    ),
    _NamiSettingSearchEntry(
      title: 'About Nami, Updates & AMOLED Widget',
      subtitle: 'About Nami',
      keywords: 'about version github update widget',
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
    if (index == 5) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => widget.classicSettingsBuilder(ctx),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NamiSettingsSubPage(
          categoryIndex: index,
          hubWidget: widget,
        ),
      ),
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
                        style: const TextStyle(color: Colors.white, fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: 'Search settings (DAC, sleep, blur, YouTube...)',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
                          prefixIcon: Icon(Icons.search_rounded, color: accent, size: 20),
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
                            leading: Icon(item.icon, color: Colors.white70, size: 21),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              style: const TextStyle(color: Colors.white54, fontSize: 11.8),
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

  Widget _categoryRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    Widget? trailingBadge,
  }) {
    return InkWell(
      onTap: () => _openCategory(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2.5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              const SizedBox(width: 8),
              trailingBadge,
            ],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final outName = widget.outputDevice.isNotEmpty ? widget.outputDevice : 'Phone Speaker';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Subtle Namida-style ambient watermark glow
          Positioned(
            right: -60,
            bottom: 40,
            child: IgnorePointer(
              child: Icon(
                Icons.waves_rounded,
                size: 240,
                color: Colors.white.withValues(alpha: 0.025),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 156),
            children: [
              _categoryRow(
                icon: Icons.usb_rounded,
                title: 'Audio & DAC Engine',
                subtitle: '$outName • ${widget.eqEnabled ? 'Tuned DSP' : 'Bit-Perfect'} • Gapless & ReplayGain',
                index: 0,
              ),
              _categoryRow(
                icon: Icons.play_arrow_outlined,
                title: 'Playback & Sleep Timer',
                subtitle: 'Sleep timer, queue resume, fade & seek waveform sliders',
                index: 1,
                trailingBadge: ValueListenableBuilder<Duration?>(
                  valueListenable: NamiUxPrefs.sleepRemaining,
                  builder: (_, rem, __) {
                    if (rem == null) return const SizedBox.shrink();
                    final m = rem.inMinutes.toString().padLeft(2, '0');
                    final s = (rem.inSeconds % 60).toString().padLeft(2, '0');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                icon: Icons.auto_awesome_motion_outlined,
                title: 'Appearance & 120Hz Motion',
                subtitle: 'Motion speed, haptics, lyrics blur, breathing art & GPU budget',
                index: 2,
              ),
              _categoryRow(
                icon: Icons.library_music_outlined,
                title: 'Library & Metadata',
                subtitle: 'Storage access, India-First JioSaavn/Apple IN & artist portraits',
                index: 3,
              ),
              _categoryRow(
                icon: Icons.play_circle_outline_rounded,
                title: 'YouTube & Mornye',
                subtitle: 'Region (${NamiUxPrefs.youtubeRegion}), ${NamiUxPrefs.youtubeAudioQuality} & local-first mode',
                index: 4,
              ),
              _categoryRow(
                icon: Icons.tune_rounded,
                title: 'Theme, Equalizer & Classic Controls',
                subtitle: 'Accent colors, EQ bands, library folders, backup & updater',
                index: 5,
              ),
              _categoryRow(
                icon: Icons.info_outline_rounded,
                title: 'About Nami',
                subtitle: 'v3.0.0-beta (v36) • AMOLED Home Widget & engine info',
                index: 6,
              ),
            ],
          ),

          // Namida-style floating bottom-right Search pill above persistent Mini-Player
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
                  color: const Color(0xFF14141C),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 19),
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

  const _NamiSettingsSubPage({
    required this.categoryIndex,
    required this.hubWidget,
  });

  @override
  State<_NamiSettingsSubPage> createState() => _NamiSettingsSubPageState();
}

class _NamiSettingsSubPageState extends State<_NamiSettingsSubPage> {
  static const List<String> _titles = [
    'Audio & DAC Engine',
    'Playback & Sleep Timer',
    'Appearance & 120Hz Motion',
    'Library & Metadata',
    'YouTube & Mornye',
    'Classic Controls',
    'About Nami',
  ];

  void _resetCategoryDefaults() {
    NamiUxPrefs.hapticLight();
    setState(() {
      switch (widget.categoryIndex) {
        case 0:
          NamiUxPrefs.gaplessPlayback = true;
          NamiUxPrefs.replayGainMode = 'track';
          widget.hubWidget.onApplyAudioProps();
          break;
        case 1:
          NamiUxPrefs.startSleepTimer(null, widget.hubWidget.onSleepExpire);
          NamiUxPrefs.persistSession = true;
          NamiUxPrefs.fadeDurationMs = 250;
          NamiUxPrefs.seekDurationSec = 5;
          NamiUxPrefs.waveformBarsCount = 48;
          break;
        case 2:
          NamiUxPrefs.motionSpeed = 'balanced';
          NamiUxPrefs.hapticsEnabled = true;
          NamiUxPrefs.breathingCoverArt = true;
          NamiUxPrefs.lyricsBlurDepth = true;
          NamiUxPrefs.doubleTapArtLyrics = true;
          NamiUxPrefs.swipeDownDismiss = true;
          NamiUxPrefs.trackRowSwipeActions = true;
          NamiUxPrefs.enableBlurEffect = false;
          NamiUxPrefs.enableGlowEffect = true;
          break;
        case 3:
          NamiUxPrefs.indiaFirstMetadata = true;
          break;
        case 4:
          NamiUxPrefs.youtubeRegion = 'IN';
          NamiUxPrefs.youtubeAudioQuality = 'High (Opus)';
          NamiUxPrefs.youtubeLocalOnly = true;
          NamiUxPrefs.ytSponsorBlock = true;
          NamiUxPrefs.ytReturnDislike = true;
          NamiUxPrefs.ytAudioOnlyMode = true;
          NamiUxPrefs.ytAutoStartRadio = true;
          NamiUxPrefs.ytPersonalizedFeeds = true;
          NamiUxPrefs.ytSearchCleanup = true;
          NamiUxPrefs.ytDownloadMetadataTags = true;
          NamiUxPrefs.ytDimMiniAfterSec = 15;
          NamiUxPrefs.ytDimIntensityPct = 50;
          break;
      }
    });
    NamiUxPrefs.save();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset ${_titles[widget.categoryIndex]} to defaults')),
    );
  }

  Widget _sectionLabel(String label) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: accent.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _switchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.8, color: Colors.white54),
      ),
      value: value,
      activeThumbColor: accent,
      onChanged: (v) {
        NamiUxPrefs.hapticLight();
        setState(() => onChanged(v));
        NamiUxPrefs.save();
      },
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingText,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
      leading: Icon(icon, color: Colors.white70, size: 21),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.8, color: Colors.white54),
      ),
      trailing: trailingText != null
          ? Text(trailingText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accent))
          : const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
      onTap: () {
        NamiUxPrefs.hapticLight();
        onTap();
      },
    );
  }

  Widget _pillSelector({
    required String title,
    required String subtitle,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11.8, color: Colors.white54)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: NamiSpringTap(
                    pressedScale: 0.94,
                    onTap: () {
                      setState(() => onSelect(options[i]));
                      NamiUxPrefs.save();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == options[i]
                            ? accent.withValues(alpha: 0.18)
                            : const Color(0xFF101018),
                        borderRadius: BorderRadius.circular(12),
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
                          fontSize: 11.8,
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

  List<Widget> _buildItems(Color accent) {
    switch (widget.categoryIndex) {
      case 0: // Audio & DAC Engine
        final outName = widget.hubWidget.outputDevice.isNotEmpty
            ? widget.hubWidget.outputDevice
            : 'Phone Speaker';
        return [
          _sectionLabel('Hardware Output'),
          _actionItem(
            icon: Icons.usb_rounded,
            title: 'Direct USB DAC Permission',
            subtitle: 'Active output: $outName (${widget.hubWidget.eqEnabled ? 'Tuned DSP' : 'Bit-Perfect'})',
            trailingText: 'Request',
            onTap: widget.hubWidget.onRequestUsbDac,
          ),
          const Divider(height: 1, color: Colors.white10),
          _sectionLabel('libmpv Audiophile Engine'),
          _switchItem(
            title: 'True Gapless Playback',
            subtitle: 'Zero silence between tracks on continuous albums & live mixes',
            value: NamiUxPrefs.gaplessPlayback,
            onChanged: (v) {
              NamiUxPrefs.gaplessPlayback = v;
              widget.hubWidget.onApplyAudioProps();
            },
          ),
          _pillSelector(
            title: 'ReplayGain Loudness Normalization',
            subtitle: 'Balances mastering levels across Bollywood OSTs, DHH & FLAC rips',
            options: const ['Off', 'Track Gain', 'Album Gain'],
            selected: NamiUxPrefs.replayGainMode == 'no'
                ? 'Off'
                : (NamiUxPrefs.replayGainMode == 'album' ? 'Album Gain' : 'Track Gain'),
            onSelect: (opt) {
              NamiUxPrefs.replayGainMode =
                  opt == 'Off' ? 'no' : (opt == 'Album Gain' ? 'album' : 'track');
              widget.hubWidget.onApplyAudioProps();
            },
          ),
          const Divider(height: 1, color: Colors.white10),
          _actionItem(
            icon: Icons.equalizer_rounded,
            title: 'Equalizer, AutoEQ & DSP Controls',
            subtitle: 'Open classic audio tuning & frequency bands',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (ctx) => widget.hubWidget.classicSettingsBuilder(ctx)),
            ),
          ),
        ];

      case 1: // Playback & Sleep Timer
        return [
          _sectionLabel('Sleep Timer'),
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
              return _pillSelector(
                title: rem == null
                    ? 'Auto-Pause Countdown'
                    : 'Auto-Pause Active (${rem.inMinutes.toString().padLeft(2, '0')}:${(rem.inSeconds % 60).toString().padLeft(2, '0')})',
                subtitle: 'Smoothly pauses playback when the timer ends',
                options: const ['Off', '15m', '30m', '45m', '60m'],
                selected: curLabel,
                onSelect: (opt) {
                  if (opt == 'Off') {
                    NamiUxPrefs.startSleepTimer(null, widget.hubWidget.onSleepExpire);
                  } else {
                    final mins = int.tryParse(opt.replaceAll('m', '')) ?? 30;
                    NamiUxPrefs.startSleepTimer(Duration(minutes: mins), widget.hubWidget.onSleepExpire);
                  }
                },
              );
            },
          ),
          const Divider(height: 1, color: Colors.white10),
          _sectionLabel('Session & Waveform Controls'),
          _switchItem(
            title: 'Persist Queue & Resume Position',
            subtitle: 'Saves active song, queue & exact timestamp across app restarts',
            value: NamiUxPrefs.persistSession,
            onChanged: (v) => NamiUxPrefs.persistSession = v,
          ),
          NamiWaveformSlider(
            title: 'Play / Pause Fade Duration',
            subtitle: 'Smooth volume ramp on play & pause transitions',
            value: NamiUxPrefs.fadeDurationMs.toDouble(),
            min: 0,
            max: 1000,
            divisions: 20,
            valueFormatter: (v) => '${v.round()}ms',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.fadeDurationMs = v.round());
              NamiUxPrefs.save();
            },
          ),
          NamiWaveformSlider(
            title: 'Seek Step Duration',
            subtitle: 'Skip step used for fast-forward & rewind gestures',
            value: NamiUxPrefs.seekDurationSec.toDouble(),
            min: 3,
            max: 30,
            divisions: 27,
            valueFormatter: (v) => '${v.round()}s',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.seekDurationSec = v.round());
              NamiUxPrefs.save();
            },
          ),
          NamiWaveformSlider(
            title: 'Waveform Bars Density',
            subtitle: 'Number of vertical bars rendered on the Now Playing scrubber',
            value: NamiUxPrefs.waveformBarsCount.toDouble(),
            min: 24,
            max: 96,
            divisions: 12,
            valueFormatter: (v) => '${v.round()}',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.waveformBarsCount = v.round());
              NamiUxPrefs.save();
            },
          ),
        ];

      case 2: // Appearance & 120Hz Motion
        return [
          _sectionLabel('120Hz Motion Physics'),
          _pillSelector(
            title: 'Animation Tempo',
            subtitle: 'Scales spring morph, tab swipe & sheet transition speed',
            options: const ['Snappy', 'Balanced', 'Silky'],
            selected: NamiUxPrefs.motionSpeed == 'snappy'
                ? 'Snappy'
                : (NamiUxPrefs.motionSpeed == 'silky' ? 'Silky' : 'Balanced'),
            onSelect: (opt) => NamiUxPrefs.motionSpeed = opt.toLowerCase(),
          ),
          _switchItem(
            title: 'Haptic Detents',
            subtitle: 'Tactile micro-clicks on taps, waveform scrubs & tab swipes',
            value: NamiUxPrefs.hapticsEnabled,
            onChanged: (v) => NamiUxPrefs.hapticsEnabled = v,
          ),
          _switchItem(
            title: 'Breathing Cover Art',
            subtitle: 'Subtle play/pause cover scale animation on Now Playing',
            value: NamiUxPrefs.breathingCoverArt,
            onChanged: (v) => NamiUxPrefs.breathingCoverArt = v,
          ),
          _switchItem(
            title: 'Synced Lyrics Blur Depth',
            subtitle: 'Apple Music-style blur on inactive lyric lines',
            value: NamiUxPrefs.lyricsBlurDepth,
            onChanged: (v) => NamiUxPrefs.lyricsBlurDepth = v,
          ),
          _switchItem(
            title: 'Double-Tap Art for Lyrics',
            subtitle: 'Toggle synced lyrics directly from Now Playing artwork',
            value: NamiUxPrefs.doubleTapArtLyrics,
            onChanged: (v) => NamiUxPrefs.doubleTapArtLyrics = v,
          ),
          _switchItem(
            title: 'Interactive Swipe-Down Dismiss',
            subtitle: '1:1 finger-tracked collapse from Now Playing to Mini-Player',
            value: NamiUxPrefs.swipeDownDismiss,
            onChanged: (v) => NamiUxPrefs.swipeDownDismiss = v,
          ),
          _switchItem(
            title: 'Track Row Swipe Actions',
            subtitle: 'Swipe left for Play After, swipe right for Track Info card',
            value: NamiUxPrefs.trackRowSwipeActions,
            onChanged: (v) => NamiUxPrefs.trackRowSwipeActions = v,
          ),
          const Divider(height: 1, color: Colors.white10),
          _sectionLabel('120Hz GPU Performance Budget'),
          _switchItem(
            title: 'Enable Real-Time Blur Effect',
            subtitle: 'Off by default to keep scrolling locked at 120fps (might affect GPU)',
            value: NamiUxPrefs.enableBlurEffect,
            onChanged: (v) => NamiUxPrefs.enableBlurEffect = v,
          ),
          _switchItem(
            title: 'Enable Ambient Cover Glow',
            subtitle: 'Soft radial accent lighting behind Now Playing artwork',
            value: NamiUxPrefs.enableGlowEffect,
            onChanged: (v) => NamiUxPrefs.enableGlowEffect = v,
          ),
        ];

      case 3: // Library & Metadata
        return [
          _sectionLabel('Permissions & Artist Cleanup'),
          _actionItem(
            icon: Icons.folder_special_outlined,
            title: 'Grant Full Storage Access',
            subtitle: 'Required on Android 11+ for direct FLAC tag & cover writing',
            trailingText: 'Grant',
            onTap: widget.hubWidget.onGrantStorage,
          ),
          _actionItem(
            icon: Icons.merge_type_rounded,
            title: 'Merge / Alias Duplicate Artists',
            subtitle: 'Combine variants like A. R. Rahman & A.R. Rahman',
            onTap: widget.hubWidget.onMergeArtists,
          ),
          const Divider(height: 1, color: Colors.white10),
          _sectionLabel('India-First Metadata & Artwork'),
          _pillSelector(
            title: 'Metadata Search Priority',
            subtitle: 'Choose India-first catalogs or global streaming order',
            options: const ['India-First', 'Global'],
            selected: NamiUxPrefs.indiaFirstMetadata ? 'India-First' : 'Global',
            onSelect: (opt) => NamiUxPrefs.indiaFirstMetadata = opt == 'India-First',
          ),
          _actionItem(
            icon: Icons.cleaning_services_outlined,
            title: 'Fix Blank / Mic Placeholder Artist Photos',
            subtitle: 'Removes broken placeholder icons & pulls official portraits',
            onTap: widget.hubWidget.onPurgePlaceholders,
          ),
          _actionItem(
            icon: Icons.cloud_download_outlined,
            title: 'Batch Fetch Missing Artist Portraits',
            subtitle: 'Downloads missing photos from JioSaavn IN, Apple Music IN & Spotify',
            onTap: widget.hubWidget.onBatchFetchArtists,
          ),
        ];

      case 4: // YouTube & Mornye (Ready for Steps 4 & 5 Option A)
        return [
          _sectionLabel('YouTube InnerTube Engine (v3.0.0-beta)'),
          _actionItem(
            icon: Icons.play_circle_filled_rounded,
            title: 'Open YouTube Music Engine (Beta Preview)',
            subtitle: 'Test India-first feed, live search, libmpv streaming & local history',
            trailingText: 'Launch',
            onTap: () => showNamiYoutubeEngineBetaSheet(context),
          ),
          const Divider(height: 1, color: Colors.white10),
          _sectionLabel('Playback & Storefront'),
          _pillSelector(
            title: 'Browse Storefront Region',
            subtitle: 'Controls YouTube Music charts, mixes & Bollywood/DHH feeds',
            options: const ['IN', 'US', 'Global'],
            selected: NamiUxPrefs.youtubeRegion,
            onSelect: (opt) => NamiUxPrefs.youtubeRegion = opt,
          ),
          _pillSelector(
            title: 'Stream Audio Quality',
            subtitle: 'Streams directly through Nami\'s libmpv & USB DAC pipeline',
            options: const ['High (Opus)', 'Balanced', 'Data Saver'],
            selected: NamiUxPrefs.youtubeAudioQuality,
            onSelect: (opt) => NamiUxPrefs.youtubeAudioQuality = opt,
          ),
          _switchItem(
            title: 'SponsorBlock Auto-Skip',
            subtitle: 'Automatically skips sponsors, intros & non-music segments',
            value: NamiUxPrefs.ytSponsorBlock,
            onChanged: (v) => NamiUxPrefs.ytSponsorBlock = v,
          ),
          _switchItem(
            title: 'Return YouTube Dislike',
            subtitle: 'Display community like & dislike statistics on tracks',
            value: NamiUxPrefs.ytReturnDislike,
            onChanged: (v) => NamiUxPrefs.ytReturnDislike = v,
          ),
          _switchItem(
            title: 'Remember Audio-Only Mode',
            subtitle: 'Default to crisp high-bitrate audio streams via libmpv',
            value: NamiUxPrefs.ytAudioOnlyMode,
            onChanged: (v) => NamiUxPrefs.ytAudioOnlyMode = v,
          ),
          _switchItem(
            title: 'Auto Start Radio',
            subtitle: 'Automatically queues related mix tracks when playing a single song',
            value: NamiUxPrefs.ytAutoStartRadio,
            onChanged: (v) => NamiUxPrefs.ytAutoStartRadio = v,
          ),
          const Divider(height: 1, color: Colors.white10),
          _sectionLabel('Feeds, Miniplayer & Downloads'),
          _switchItem(
            title: 'Local-First Account-Free Mode',
            subtitle: 'Keep YouTube history, mixes, channels & playlists 100% on-device',
            value: NamiUxPrefs.youtubeLocalOnly,
            onChanged: (v) => NamiUxPrefs.youtubeLocalOnly = v,
          ),
          _switchItem(
            title: 'Personalized Related & Mix Playlists',
            subtitle: 'Build Recommended & Top Recents mixes from your listens',
            value: NamiUxPrefs.ytPersonalizedFeeds,
            onChanged: (v) => NamiUxPrefs.ytPersonalizedFeeds = v,
          ),
          _switchItem(
            title: 'Enable Search Cleanup',
            subtitle: 'Normalizes search queries for cleaner YouTube Music results',
            value: NamiUxPrefs.ytSearchCleanup,
            onChanged: (v) => NamiUxPrefs.ytSearchCleanup = v,
          ),
          NamiWaveformSlider(
            title: 'Dim Miniplayer After Inactivity',
            subtitle: 'Subtly dims the player overlay during continuous playback',
            value: NamiUxPrefs.ytDimMiniAfterSec.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            valueFormatter: (v) => '${v.round()}s',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.ytDimMiniAfterSec = v.round());
              NamiUxPrefs.save();
            },
          ),
          NamiWaveformSlider(
            title: 'Dim Intensity',
            subtitle: 'Controls miniplayer dim opacity level',
            value: NamiUxPrefs.ytDimIntensityPct.toDouble(),
            min: 0,
            max: 90,
            divisions: 18,
            valueFormatter: (v) => '${v.round()}%',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.ytDimIntensityPct = v.round());
              NamiUxPrefs.save();
            },
          ),
          _switchItem(
            title: 'Downloads Metadata Tags',
            subtitle: 'Extract Artist, Title & Album automatically from video info',
            value: NamiUxPrefs.ytDownloadMetadataTags,
            onChanged: (v) => NamiUxPrefs.ytDownloadMetadataTags = v,
          ),
        ];

      default: // 6: About Nami
        return [
          _sectionLabel('Nami Music Player'),
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            leading: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
            title: Text(
              'Nami v3.0.0-beta (v36)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            subtitle: Text(
              '120Hz AMOLED Audiophile Player • libmpv Bit-Perfect USB DAC • India-First Metadata • Mornye Extensions',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          _actionItem(
            icon: Icons.widgets_outlined,
            title: 'Refresh AMOLED Home Screen Widget (4×1)',
            subtitle: 'Long-press home screen -> Widgets -> Nami Music',
            onTap: () {
              widget.hubWidget.onSyncWidgetNow();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Synced current track to Nami AMOLED Widget')),
              );
            },
          ),
          _actionItem(
            icon: Icons.system_update_outlined,
            title: 'Check for GitHub Releases & Classic About',
            subtitle: 'Open GitHub updater & full build diagnostics',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (ctx) => widget.hubWidget.classicSettingsBuilder(ctx)),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final showReset = widget.categoryIndex >= 0 && widget.categoryIndex <= 4;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            NamiUxPrefs.hapticLight();
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          _titles[widget.categoryIndex.clamp(0, _titles.length - 1)],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Colors.white,
          ),
        ),
        actions: [
          if (showReset)
            IconButton(
              tooltip: 'Reset to defaults',
              icon: const Icon(Icons.restore_rounded, color: Colors.white70, size: 21),
              onPressed: _resetCategoryDefaults,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 150),
        children: _buildItems(accent),
      ),
    );
  }
}
