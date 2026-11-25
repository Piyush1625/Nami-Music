part of '../main.dart';

/// Namida-inspired bespoke vertical-bar waveform slider.
/// Supports both `compactInline: true` (94px wide on right side of row with value below,
/// matching Namida's Indexer/Playback/YouTube/Advanced screenshots) and full-width mode.
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

  static const List<double> _wideBars = <double>[
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

  Widget _buildBars(List<double> pattern, double width, double height, double norm) {
    final activeIdx = (norm * (pattern.length - 1)).round();
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
            for (int i = 0; i < pattern.length; i++)
              Container(
                width: i == activeIdx ? 2.6 : 1.9,
                height: i == activeIdx
                    ? height * 0.96
                    : (height * (0.26 + pattern[i] * 0.56)),
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

    if (widget.compactInline) {
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
                _buildBars(_compactBars, 86, 26, norm),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Text(
                widget.valueFormatter(widget.value),
                style: TextStyle(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w800,
                  color: widget.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (_, c) => _buildBars(
              _wideBars,
              c.maxWidth.isFinite ? c.maxWidth : 280.0,
              30,
              norm,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sleek Namida-style monochrome pill toggle switch (dark pill track + crisp white thumb).
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

/// Redesigned Minimal Pitch-Black AMOLED Settings Hub matching Namida screenshots (`127239-127250`)
/// while preserving 100% of Nami's audiophile, India-first & Mornye features.
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
  // Category indices:
  // 0: Theme | 1: Indexer | 2: Playback | 3: Customizations | 4: YouTube
  // 5: Extras | 6: Backup & Restore | 7: Advanced | 8: About
  static const List<_NamiSettingSearchEntry> _searchIndex = [
    _NamiSettingSearchEntry(
      title: 'Theme Mode, Pitch Black & Accent Colors',
      subtitle: 'Theme',
      keywords: 'theme dark pitch black amoled auto coloring wallpaper accent color',
      icon: Icons.format_paint_outlined,
      categoryIndex: 0,
    ),
    _NamiSettingSearchEntry(
      title: 'Library Indexer, Folders & India-First Portraits',
      subtitle: 'Indexer',
      keywords: 'indexer folder storage scan refresh nomedia duplicate artist photos jiosaavn apple',
      icon: Icons.layers_outlined,
      categoryIndex: 1,
    ),
    _NamiSettingSearchEntry(
      title: 'USB DAC, Gapless, ReplayGain, Sleep & Fades',
      subtitle: 'Playback',
      keywords: 'playback dac usb bit perfect gapless replaygain normalize sleep timer fade seek silence eq',
      icon: Icons.play_circle_outline_rounded,
      categoryIndex: 2,
    ),
    _NamiSettingSearchEntry(
      title: '120Hz Motion, Lyrics Blur, Gestures & GPU Blur',
      subtitle: 'Customizations',
      keywords: 'customizations 120hz motion haptics breathing cover lyrics blur swipe row waveform',
      icon: Icons.brush_outlined,
      categoryIndex: 3,
    ),
    _NamiSettingSearchEntry(
      title: 'SponsorBlock, Return YouTube Dislike, Radio & Region',
      subtitle: 'YouTube',
      keywords: 'youtube mornye sponsorblock dislike radio dim region opus quality search cleanup',
      icon: Icons.ondemand_video_rounded,
      categoryIndex: 4,
    ),
    _NamiSettingSearchEntry(
      title: 'Extras, Widget Sync, Immersive Mode & Image Source',
      subtitle: 'Extras',
      keywords: 'extras widget amoled immersive search cleanup image source',
      icon: Icons.extension_outlined,
      categoryIndex: 5,
    ),
    _NamiSettingSearchEntry(
      title: 'Backup & Restore Settings / Equalizer / Folders',
      subtitle: 'Backup & Restore',
      keywords: 'backup restore export import database folders equalizer',
      icon: Icons.settings_backup_restore_rounded,
      categoryIndex: 6,
    ),
    _NamiSettingSearchEntry(
      title: 'Performance Mode & Cache Limits',
      subtitle: 'Advanced',
      keywords: 'advanced cache clear image audio youtube thumbnail performance 120hz reset',
      icon: Icons.tune_rounded,
      categoryIndex: 7,
    ),
    _NamiSettingSearchEntry(
      title: 'About Nami, Developer & Library Statistics',
      subtitle: 'About',
      keywords: 'about version statistics tracks albums artists duration github update piyush',
      icon: Icons.info_outline_rounded,
      categoryIndex: 8,
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
    if (index == 6) {
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
          onOpenSearch: _openSearchSheet,
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
                        style: const TextStyle(color: Colors.white, fontSize: 14.2),
                        decoration: InputDecoration(
                          hintText: 'Search settings (Theme, Indexer, DAC, YouTube...)',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.2),
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
    required VoidCallback onRight1,
    required IconData rightIcon2,
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
              icon: Icon(rightIcon1, color: Colors.white70, size: 20),
              onPressed: () {
                NamiUxPrefs.hapticLight();
                onRight1();
              },
            ),
            IconButton(
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
            icon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
            onPressed: _openSearchSheet,
          ),
          IconButton(
            tooltip: 'About Nami',
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 21),
            onPressed: () => _openCategory(8),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Faint ambient jellyfish/wave watermark at bottom-right matching Namida 127239.png
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
              // Top 2 Quick Action Rows (Namida 127239.png)
              _quickActionRow(
                icon: Icons.create_new_folder_outlined,
                title: 'Add Folder',
                subtitle: 'Local storage, FLAC tags, India-First metadata',
                onTap: widget.onGrantStorage,
                rightIcon1: Icons.refresh_rounded,
                onRight1: () {
                  _NamiHomeShellState.activeInstance?._handleV29TracksPullRefresh();
                },
                rightIcon2: Icons.cloud_download_outlined,
                onRight2: widget.onBatchFetchArtists,
              ),
              _quickActionRow(
                icon: Icons.headphones_outlined,
                title: 'Sound & Sleep',
                subtitle: '$outName • ${widget.eqEnabled ? 'Tuned DSP' : 'Bit-Perfect'}',
                onTap: () => _openCategory(2),
                rightIcon1: Icons.timer_outlined,
                onRight1: () => _openCategory(2),
                rightIcon2: Icons.graphic_eq_rounded,
                onRight2: () => _openCategory(6),
              ),
              const SizedBox(height: 6),

              // 9 Clean Monochrome Categories matching Namida 127239.png
              _categoryRow(
                icon: Icons.format_paint_outlined,
                title: 'Theme',
                subtitle: 'The overall vibe of your player',
                index: 0,
              ),
              _categoryRow(
                icon: Icons.layers_outlined,
                title: 'Indexer',
                subtitle: 'Manage your music Library',
                index: 1,
              ),
              _categoryRow(
                icon: Icons.play_circle_outline_rounded,
                title: 'Playback',
                subtitle: 'USB DAC, Gapless, ReplayGain, fades & sleep timer',
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
                title: 'Customizations',
                subtitle: 'Customize how your player looks, make it yours',
                index: 3,
              ),
              _categoryRow(
                icon: Icons.ondemand_video_rounded,
                title: 'YouTube',
                subtitle: 'Customize YouTube & Mornye experience',
                index: 4,
              ),
              _categoryRow(
                icon: Icons.extension_outlined,
                title: 'Extras',
                subtitle: 'Extra Settings to fine your experience',
                index: 5,
              ),
              _categoryRow(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Backup & Restore',
                subtitle: 'Backup your database, folders & classic controls',
                index: 6,
              ),
              _categoryRow(
                icon: Icons.tune_rounded,
                title: 'Advanced',
                subtitle: 'Performance mode & cache management',
                index: 7,
              ),
              _categoryRow(
                icon: Icons.info_outline_rounded,
                title: 'About',
                index: 8,
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
    'Theme',
    'Indexer',
    'Playback',
    'Customizations',
    'YouTube',
    'Extras',
    'Backup & Restore',
    'Advanced',
    'About',
  ];

  static const List<String> _subtitles = [
    'The overall vibe of your player',
    'Manage your music Library',
    'Audio engine, DAC, Gapless, ReplayGain & fades',
    'Customize how your player looks, make it yours',
    'Customize YouTube & Mornye experience',
    'Extra Settings to fine your experience',
    'Backup your database and settings',
    'Advanced Settings, cache & performance',
    'Version, Developer & Library Statistics',
  ];

  static const List<IconData> _icons = [
    Icons.format_paint_outlined,
    Icons.layers_outlined,
    Icons.play_circle_outline_rounded,
    Icons.brush_outlined,
    Icons.ondemand_video_rounded,
    Icons.extension_outlined,
    Icons.settings_backup_restore_rounded,
    Icons.tune_rounded,
    Icons.info_outline_rounded,
  ];

  int _ytThumbBytes = 0;

  @override
  void initState() {
    super.initState();
    if (widget.categoryIndex == 7) {
      _measureCacheSizes();
    }
  }

  Future<void> _measureCacheSizes() async {
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
  }

  Future<void> _clearYtThumbCache() async {
    try {
      final dir = Directory('${Directory.systemTemp.path}/nami_yt_thumbs');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
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
          NamiUxPrefs.themeModePref = 'dark';
          NamiUxPrefs.autoColoring = false;
          NamiUxPrefs.usePitchBlack = true;
          break;
        case 1:
          NamiUxPrefs.indiaFirstMetadata = true;
          NamiUxPrefs.refreshOnStartup = false;
          NamiUxPrefs.extractFeatArtists = true;
          NamiUxPrefs.respectNomedia = true;
          NamiUxPrefs.preventDuplicateTracks = true;
          NamiUxPrefs.minTrackDurationSec = 5;
          NamiUxPrefs.minFileSizeKb = 100;
          break;
        case 2:
          NamiUxPrefs.gaplessPlayback = true;
          NamiUxPrefs.replayGainMode = 'track';
          NamiUxPrefs.skipSilence = false;
          NamiUxPrefs.enableFadeEffect = false;
          NamiUxPrefs.fadeDurationMs = 300;
          NamiUxPrefs.pauseFadeDurationMs = 300;
          NamiUxPrefs.persistSession = true;
          NamiUxPrefs.infinityQueue = true;
          NamiUxPrefs.seekDurationSec = 5;
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
          NamiUxPrefs.enableBlurEffect = false;
          NamiUxPrefs.enableGlowEffect = true;
          NamiUxPrefs.waveformBarsCount = 48;
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
        case 5:
          NamiUxPrefs.immersiveMode = false;
          NamiUxPrefs.ytSearchCleanup = true;
          break;
        case 7:
          NamiUxPrefs.performanceMode = '120Hz High';
          NamiUxPrefs.imageCacheLimitMb = 256;
          NamiUxPrefs.audioCacheLimitGb = 4;
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
    bool indented = false,
  }) {
    return InkWell(
      onTap: () {
        NamiUxPrefs.hapticLight();
        setState(() => onChanged(!value));
        NamiUxPrefs.save();
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(indented ? 30 : 16, 12, 16, 12),
        child: Row(
          children: [
            if (indented) ...[
              Container(width: 1.4, height: 28, color: Colors.white12),
              const SizedBox(width: 14),
            ],
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

  /// Exact Namida About Page Layout (`127250.png`):
  /// Floating circular Nami badge, Developer Piyush1625 card, Project Links card,
  /// live Library & YouTube Statistics pill grid, and Nami Milestones card.
  Widget _buildNamidaAboutPage(Color accent) {
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
              ),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 155),
      children: [
        // 1. Hero Card with Overlapping Circular Emblem (127250.png)
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'v3.0.0 (v37)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.6,
                      fontWeight: FontWeight.w700,
                    ),
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
                        child: Icon(Icons.person_rounded, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Developer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
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
              child: Icon(Icons.graphic_eq_rounded, color: accent, size: 44),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Project & Updates Card (mirrors Namida's Socials card)
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
                            'Releases, ARM64 builds & AMOLED Home Widget',
                            style: TextStyle(color: Colors.white54, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _divider(),
              _actionRow(
                icon: Icons.system_update_outlined,
                title: 'Check GitHub Releases & Updates',
                subtitle: 'github.com/Piyush1625/Nami-Music',
                showChevron: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (ctx) => widget.hubWidget.classicSettingsBuilder(ctx),
                  ),
                ),
              ),
              _divider(),
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

        // 3. Live Library & YouTube Statistics Card (mirrors Namida 127250.png)
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
                  Icon(Icons.bar_chart_rounded, color: Colors.white54, size: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statistics',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Here is some info about your library',
                          style: TextStyle(color: Colors.white54, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  statPill(Icons.schedule_rounded, '${totalHours}h ${totalMins}min Total Tracks Duration'),
                  statPill(Icons.ondemand_video_rounded, '${ytHours}h ${ytMins}min YouTube ($ytPlays plays)'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Nami Engine Highlights Card (clean authentic Nami equivalent)
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
                          'Nami v3.0 Engine',
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
                  milestoneChip(Icons.lyrics_outlined, 'Apple-Style Lyrics'),
                  milestoneChip(Icons.public_rounded, 'India-First Metadata'),
                  milestoneChip(Icons.play_circle_outline_rounded, 'YouTube InnerTube'),
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
    final shell = _NamiHomeShellState.activeInstance;
    final songs = shell?._songs ?? const <AudioTrack>[];
    final outName = widget.hubWidget.outputDevice.isNotEmpty
        ? widget.hubWidget.outputDevice
        : 'Phone Speaker';

    switch (widget.categoryIndex) {
      case 0: // Theme (127240.png)
        Widget modeBtn(IconData ic, String mode) {
          final sel = NamiUxPrefs.themeModePref == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                NamiUxPrefs.hapticLight();
                setState(() => NamiUxPrefs.themeModePref = mode);
                NamiUxPrefs.save();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF42424C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  ic,
                  size: 18,
                  color: sel ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        }

        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.brightness_6_outlined, color: Colors.white54, size: 21),
                const SizedBox(width: 15),
                const Expanded(
                  child: Text(
                    'Theme Mode',
                    style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                Container(
                  width: 146,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCDCE2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      modeBtn(Icons.brightness_auto_rounded, 'auto'),
                      modeBtn(Icons.light_mode_outlined, 'light'),
                      modeBtn(Icons.dark_mode_outlined, 'dark'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _divider(),
          _switchRow(
            icon: Icons.color_lens_outlined,
            title: 'Auto Coloring',
            subtitle: 'Automatically pick player colors from current artwork. Might affect performance',
            value: NamiUxPrefs.autoColoring,
            onChanged: (v) => NamiUxPrefs.autoColoring = v,
          ),
          _switchRow(
            icon: Icons.contrast_rounded,
            title: 'Use Pitch Black',
            subtitle: 'Useful for AMOLED screens.. and looks cooler',
            value: NamiUxPrefs.usePitchBlack,
            onChanged: (v) => NamiUxPrefs.usePitchBlack = v,
          ),
          _divider(),
          _actionRow(
            icon: Icons.palette_outlined,
            title: 'Accent Colors & Classic Theme Picker',
            subtitle: 'Customize Nami primary accent color & palette',
            showChevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (ctx) => widget.hubWidget.classicSettingsBuilder(ctx),
              ),
            ),
          ),
        ];

      case 1: // Indexer (127241-127242.png)
        final artCount = songs
            .where((s) => (s.thumbPath != null && s.thumbPath!.isNotEmpty) || s.albumArt != null)
            .length;
        final folderCount = shell?._scanFolders.length ?? 0;

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
                        const Icon(Icons.music_note_outlined, color: Colors.white60, size: 16),
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
          _actionRow(
            icon: Icons.create_new_folder_outlined,
            title: 'Add Folder & Full Storage Access',
            subtitle: 'Active folders: $folderCount • Required for direct FLAC tag writing',
            trailingText: 'Grant',
            onTap: widget.hubWidget.onGrantStorage,
          ),
          _actionRow(
            icon: Icons.refresh_rounded,
            title: 'Refresh Library',
            subtitle: 'Check for newly added or deleted music',
            onTap: () => shell?._handleV29TracksPullRefresh(),
          ),
          _divider(),
          _switchRow(
            icon: Icons.sync_rounded,
            title: 'Refresh on startup',
            subtitle: 'Automatically verify folders when Nami launches',
            value: NamiUxPrefs.refreshOnStartup,
            onChanged: (v) => NamiUxPrefs.refreshOnStartup = v,
          ),
          _switchRow(
            icon: Icons.mic_none_rounded,
            title: 'Extract feat. artists from title',
            subtitle: 'Splits multi-artist credits cleanly across library',
            value: NamiUxPrefs.extractFeatArtists,
            onChanged: (v) => NamiUxPrefs.extractFeatArtists = v,
          ),
          _actionRow(
            icon: Icons.merge_type_rounded,
            title: 'Merge / Alias Duplicate Artists',
            subtitle: 'Combine variants like A. R. Rahman & A.R. Rahman',
            showChevron: true,
            onTap: widget.hubWidget.onMergeArtists,
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
            icon: Icons.cleaning_services_outlined,
            title: 'Fix Blank / Mic Placeholder Artist Photos',
            subtitle: 'Purges broken placeholder images & pulls official portraits',
            onTap: widget.hubWidget.onPurgePlaceholders,
          ),
          _actionRow(
            icon: Icons.cloud_download_outlined,
            title: 'Batch Fetch Missing Artist Portraits',
            subtitle: 'Downloads high-res portraits for Indian & global artists',
            onTap: widget.hubWidget.onBatchFetchArtists,
          ),
          _divider(),
          _switchRow(
            icon: Icons.visibility_off_outlined,
            title: 'Respect .nomedia',
            subtitle: 'Skip folders containing a .nomedia marker file',
            value: NamiUxPrefs.respectNomedia,
            onChanged: (v) => NamiUxPrefs.respectNomedia = v,
          ),
          NamiWaveformSlider(
            leadingIcon: Icons.timer_outlined,
            title: 'Minimum Track Duration',
            subtitle: 'Ignore short clips on refresh',
            value: NamiUxPrefs.minTrackDurationSec.toDouble(),
            min: 0,
            max: 60,
            divisions: 12,
            valueFormatter: (v) => '${v.round()} s',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.minTrackDurationSec = v.round());
              NamiUxPrefs.save();
            },
          ),
          NamiWaveformSlider(
            leadingIcon: Icons.data_usage_rounded,
            title: 'Minimum File Size',
            subtitle: 'Ignore tiny voice notes on refresh',
            value: NamiUxPrefs.minFileSizeKb.toDouble(),
            min: 0,
            max: 1000,
            divisions: 20,
            valueFormatter: (v) => '${v.round()} KB',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.minFileSizeKb = v.round());
              NamiUxPrefs.save();
            },
          ),
          _switchRow(
            icon: Icons.filter_none_rounded,
            title: 'Prevent Duplicated tracks',
            subtitle: 'Skips copies matching same title, artist and duration',
            value: NamiUxPrefs.preventDuplicateTracks,
            onChanged: (v) => NamiUxPrefs.preventDuplicateTracks = v,
          ),
        ];

      case 2: // Playback (127243, 127246.png)
        return [
          _actionRow(
            icon: Icons.usb_rounded,
            title: 'Sound Control & USB DAC',
            subtitle: '$outName • ${widget.hubWidget.eqEnabled ? 'Tuned DSP' : 'Bit-Perfect'}',
            trailingText: 'USB DAC',
            onTap: widget.hubWidget.onRequestUsbDac,
          ),
          _actionRow(
            icon: Icons.equalizer_rounded,
            title: 'Equalizer, AutoEQ & DSP Bands',
            subtitle: 'Open Nami audio tuning & frequency sliders',
            showChevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (ctx) => widget.hubWidget.classicSettingsBuilder(ctx),
              ),
            ),
          ),
          _divider(),
          _pillChoiceRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Normalize audio (ReplayGain)',
            subtitle: 'Balances mastering loudness across tracks & albums',
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
          _switchRow(
            icon: Icons.fast_forward_outlined,
            title: 'Skip Silence',
            subtitle: 'Trims silent lead-in/out gaps during playback',
            value: NamiUxPrefs.skipSilence,
            onChanged: (v) => NamiUxPrefs.skipSilence = v,
          ),
          _switchRow(
            icon: Icons.all_inclusive_rounded,
            title: 'Gapless Playback (libmpv)',
            subtitle: 'Seamless track transitions on continuous albums',
            value: NamiUxPrefs.gaplessPlayback,
            onChanged: (v) {
              NamiUxPrefs.gaplessPlayback = v;
              widget.hubWidget.onApplyAudioProps();
            },
          ),
          _switchRow(
            icon: Icons.blur_linear_rounded,
            title: 'Enable Fade Effect on Play/Pause',
            subtitle: 'Smooth ramp transitions on play & pause',
            value: NamiUxPrefs.enableFadeEffect,
            onChanged: (v) => NamiUxPrefs.enableFadeEffect = v,
          ),
          if (NamiUxPrefs.enableFadeEffect) ...[
            NamiWaveformSlider(
              leadingIcon: Icons.play_arrow_outlined,
              title: 'Play Fade Duration',
              subtitle: '',
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
              leadingIcon: Icons.pause_outlined,
              title: 'Pause Fade Duration',
              subtitle: '',
              value: NamiUxPrefs.pauseFadeDurationMs.toDouble(),
              min: 0,
              max: 1000,
              divisions: 20,
              valueFormatter: (v) => '${v.round()}ms',
              accentColor: accent,
              onChanged: (v) {
                setState(() => NamiUxPrefs.pauseFadeDurationMs = v.round());
                NamiUxPrefs.save();
              },
            ),
          ],
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
                subtitle: 'Auto-pause playback after countdown',
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
          _switchRow(
            icon: Icons.history_rounded,
            title: 'Persist Queue & Resume Position',
            subtitle: 'Saves active track, queue & timestamp automatically',
            value: NamiUxPrefs.persistSession,
            onChanged: (v) => NamiUxPrefs.persistSession = v,
          ),
          _switchRow(
            icon: Icons.all_inclusive_rounded,
            title: 'Infinity Queue on Next/Previous',
            subtitle: 'Wraps seamlessly from last track back to first',
            value: NamiUxPrefs.infinityQueue,
            onChanged: (v) => NamiUxPrefs.infinityQueue = v,
          ),
          NamiWaveformSlider(
            leadingIcon: Icons.forward_10_rounded,
            title: 'Seek Step Duration',
            subtitle: 'Jump step for rewind & fast-forward controls',
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
        ];

      case 3: // Customizations
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
          _switchRow(
            icon: Icons.lyrics_outlined,
            title: 'Synced Lyrics Blur Depth',
            subtitle: 'Apple Music-style blur on inactive lyric lines',
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
          _divider(),
          NamiWaveformSlider(
            leadingIcon: Icons.graphic_eq_rounded,
            title: 'Waveform Bars Count',
            subtitle: 'Now Playing scrubber vertical bar density',
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
          _switchRow(
            icon: Icons.blur_on_rounded,
            title: 'Enable Blur Effect',
            subtitle: 'Might affect performance — OFF by default for 120Hz lock',
            value: NamiUxPrefs.enableBlurEffect,
            onChanged: (v) => NamiUxPrefs.enableBlurEffect = v,
          ),
          _switchRow(
            icon: Icons.flare_rounded,
            title: 'Enable Glow Effect',
            subtitle: 'Subtle ambient radial glow behind Now Playing art',
            value: NamiUxPrefs.enableGlowEffect,
            onChanged: (v) => NamiUxPrefs.enableGlowEffect = v,
          ),
        ];

      case 4: // YouTube (127237-127238.png)
        return [
          _switchRow(
            icon: Icons.block_rounded,
            title: 'SponsorBlock',
            subtitle: 'Automatically skips sponsors, intros & non-music segments',
            value: NamiUxPrefs.ytSponsorBlock,
            onChanged: (v) => NamiUxPrefs.ytSponsorBlock = v,
          ),
          _switchRow(
            icon: Icons.thumb_down_outlined,
            title: 'Return YouTube Dislike',
            subtitle: 'Show community likes & dislikes on Watch sheet',
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
            onSelect: (opt) => NamiUxPrefs.youtubeRegion = opt,
          ),
          _pillChoiceRow(
            icon: Icons.high_quality_outlined,
            title: 'Stream Audio Quality',
            subtitle: 'Direct libmpv stream selection',
            options: const ['High (Opus)', 'Balanced', 'Data Saver'],
            selected: NamiUxPrefs.youtubeAudioQuality,
            onSelect: (opt) => NamiUxPrefs.youtubeAudioQuality = opt,
          ),
          _divider(),
          _switchRow(
            icon: Icons.music_note_outlined,
            title: 'Remember audio only mode',
            subtitle: 'Prefer pure audio streams via libmpv & USB DAC',
            value: NamiUxPrefs.ytAudioOnlyMode,
            onChanged: (v) => NamiUxPrefs.ytAudioOnlyMode = v,
          ),
          _switchRow(
            icon: Icons.podcasts_rounded,
            title: 'Auto start radio',
            subtitle: 'Automatically adds a mix playlist when playing a single track',
            value: NamiUxPrefs.ytAutoStartRadio,
            onChanged: (v) => NamiUxPrefs.ytAutoStartRadio = v,
          ),
          _switchRow(
            icon: Icons.playlist_play_rounded,
            title: 'Personalized Mix Playlists',
            subtitle: 'Build Recommended & Supremacy mixes locally',
            value: NamiUxPrefs.ytPersonalizedFeeds,
            onChanged: (v) => NamiUxPrefs.ytPersonalizedFeeds = v,
          ),
          _switchRow(
            icon: Icons.cleaning_services_outlined,
            title: 'Enable Search Cleanup',
            subtitle: 'Normalizes search queries for cleaner matches',
            value: NamiUxPrefs.ytSearchCleanup,
            onChanged: (v) => NamiUxPrefs.ytSearchCleanup = v,
          ),
          _divider(),
          NamiWaveformSlider(
            leadingIcon: Icons.nights_stay_outlined,
            title: 'Dim miniplayer after inactivity',
            subtitle: 'Subtle ambient dim timer',
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
            leadingIcon: Icons.brightness_low_rounded,
            title: 'Dim Intensity',
            subtitle: 'Dim opacity intensity level',
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
          _switchRow(
            icon: Icons.file_download_outlined,
            title: 'Downloads Metadata tags',
            subtitle: 'Extract Artist, Title & Album from video info by default',
            value: NamiUxPrefs.ytDownloadMetadataTags,
            onChanged: (v) => NamiUxPrefs.ytDownloadMetadataTags = v,
          ),
        ];

      case 5: // Extras (127247-127248.png)
        return [
          _actionRow(
            icon: Icons.tab_rounded,
            title: 'Library Tabs',
            subtitle: 'Home, Tracks, Artists, Playlists, YouTube + Mornye (Option A)',
            trailingText: '5',
            onTap: () {},
          ),
          _switchRow(
            icon: Icons.cleaning_services_outlined,
            title: 'Enable Search Cleanup',
            subtitle: 'Trims symbols and extra spaces while searching',
            value: NamiUxPrefs.ytSearchCleanup,
            onChanged: (v) => NamiUxPrefs.ytSearchCleanup = v,
          ),
          _switchRow(
            icon: Icons.fullscreen_rounded,
            title: 'Immersive Mode',
            subtitle: 'Clean edge-to-edge layout while Now Playing is expanded',
            value: NamiUxPrefs.immersiveMode,
            onChanged: (v) => NamiUxPrefs.immersiveMode = v,
          ),
          _divider(),
          _actionRow(
            icon: Icons.widgets_outlined,
            title: 'AMOLED Home Screen Widget (4×1)',
            subtitle: 'Tap to push current track & cover to launcher widget',
            onTap: () {
              widget.hubWidget.onSyncWidgetNow();
              NamiLiveToastController.showMessage(
                'Refreshed Nami AMOLED Widget',
                icon: Icons.widgets_rounded,
              );
            },
          ),
          _actionRow(
            icon: Icons.play_circle_outline_rounded,
            title: 'Quick YouTube Search Modal',
            subtitle: 'Launch instant YouTube Music search overlay',
            showChevron: true,
            onTap: () => showNamiYoutubeEngineBetaSheet(context),
          ),
        ];

      default: // 7: Advanced (127249.png)
        final ytThumbMb = (_ytThumbBytes / (1024 * 1024)).toStringAsFixed(2);
        return [
          _pillChoiceRow(
            icon: Icons.speed_rounded,
            title: 'Performance mode',
            subtitle: 'Optimize animations & background enrichment',
            options: const ['120Hz High', 'Balanced', 'Battery'],
            selected: NamiUxPrefs.performanceMode,
            onSelect: (opt) => NamiUxPrefs.performanceMode = opt,
          ),
          _divider(),
          NamiWaveformSlider(
            leadingIcon: Icons.image_not_supported_outlined,
            title: 'Clear Image Cache',
            subtitle: 'YouTube thumbs: $ytThumbMb MB (tap slider or row below)',
            value: NamiUxPrefs.imageCacheLimitMb.toDouble(),
            min: 64,
            max: 1024,
            divisions: 15,
            valueFormatter: (v) => '${v.round()} MB',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.imageCacheLimitMb = v.round());
              NamiUxPrefs.save();
            },
          ),
          _actionRow(
            icon: Icons.delete_sweep_outlined,
            title: 'Purge YouTube Thumbnail Cache Now',
            subtitle: 'Frees $ytThumbMb MB of cached network artwork',
            trailingText: 'Clear',
            onTap: _clearYtThumbCache,
          ),
          NamiWaveformSlider(
            leadingIcon: Icons.audiotrack_outlined,
            title: 'Audio Cache Budget',
            subtitle: 'libmpv stream & buffer headroom limit',
            value: NamiUxPrefs.audioCacheLimitGb.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            valueFormatter: (v) => '${v.round()}.00 GB',
            accentColor: accent,
            onChanged: (v) {
              setState(() => NamiUxPrefs.audioCacheLimitGb = v.round());
              NamiUxPrefs.save();
            },
          ),
          _divider(),
          _actionRow(
            icon: Icons.restore_rounded,
            title: 'Open Classic Diagnostics & Backup',
            subtitle: 'Access raw settings, folders & export tools',
            showChevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (ctx) => widget.hubWidget.classicSettingsBuilder(ctx),
              ),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final idx = widget.categoryIndex.clamp(0, _titles.length - 1);
    final isAbout = idx == 8;

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
            icon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
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
            _buildNamidaAboutPage(accent)
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 155),
              children: [
                // Single unified rounded AMOLED category card matching Namida screenshots!
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0B0F),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.065)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Header Strip inside Card
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

          // Persistent floating Search pill on sub-pages too (matching 127240-127249.png!)
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
