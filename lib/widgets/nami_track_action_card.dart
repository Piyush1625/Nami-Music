// ignore_for_file: deprecated_member_use
part of '../main.dart';

List<String> namiSplitArtists(String rawArtist) {
  final cleaned = rawArtist.trim();
  if (cleaned.isEmpty || cleaned.toLowerCase() == 'unknown artist') {
    return ['Unknown Artist'];
  }
  final parts = cleaned
      .split(RegExp(r'\s*(?:,|;|&|\bfeat\.?\b|\bft\.?\b|\bfeaturing\b|/|\|)\s*', caseSensitive: false))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final seen = <String>{};
  final unique = <String>[];
  for (final p in parts) {
    final k = p.toLowerCase();
    if (seen.add(k)) unique.add(p);
  }
  return unique.isEmpty ? [cleaned] : unique;
}

void showNamiArtistPickerOrNavigate({
  required BuildContext context,
  required String rawArtist,
  required Map<String, String> artistImagePaths,
  required ValueChanged<String> onSelectArtist,
}) {
  final artists = namiSplitArtists(rawArtist);
  if (artists.length <= 1) {
    onSelectArtist(artists.first);
    return;
  }

  final accent = Theme.of(context).colorScheme.primary;
  showModalBottomSheet(
    useRootNavigator: true,
    sheetAnimationStyle: namiSmoothSheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, color: accent, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Artist',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${artists.length} artists',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ...artists.map((artist) {
                final imgPath = artistImagePaths[artist];
                final hasImg = imgPath != null && File(imgPath).existsSync();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: accent.withValues(alpha: 0.16),
                    backgroundImage: hasImg ? FileImage(File(imgPath)) : null,
                    child: hasImg
                        ? null
                        : Text(
                            artist.isNotEmpty ? artist[0].toUpperCase() : '?',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                          ),
                  ),
                  title: Text(
                    artist,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelectArtist(artist);
                  },
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    ),
  );
}

void showNamiTrackActionCard({
  required BuildContext context,
  required AudioTrack track,
  required Widget coverArt,
  required String formatBadgeText,
  required bool isFavorite,
  required VoidCallback onToggleFavorite,
  required VoidCallback onPlayNext,
  required VoidCallback onPlayLast,
  required VoidCallback onAddToPlaylist,
  required VoidCallback onGoToAlbum,
  required ValueChanged<String> onGoToArtist,
  VoidCallback? onLyricsEditor,
  VoidCallback? onEditTags,
  VoidCallback? onFetchCoverOnline,
  VoidCallback? onFileInfo,
  VoidCallback? onDeleteForever,
}) {
  final artists = namiSplitArtists(track.artist);
  bool artistsExpanded = artists.length > 1;

  showModalBottomSheet(
    useRootNavigator: true,
    sheetAnimationStyle: namiSmoothSheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setCardState) {
        final accent = Theme.of(ctx).colorScheme.primary;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NamiOptionalBlur(sigmaX: 18, sigmaY: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xF00B0B12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.70),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: Cover + Title + Artist + Album + Favorite
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(width: 50, height: 50, child: coverArt),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      if (formatBadgeText.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.7),
                                          ),
                                          child: Text(
                                            formatBadgeText,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          track.album,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFavorite ? accent : Colors.white54,
                                size: 22,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                onToggleFavorite();
                                setCardState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white10),

                      // Go to Album
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 1),
                        leading: const Icon(Icons.album_rounded, color: Colors.white70, size: 21),
                        title: const Text('Go to Album', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        subtitle: Text(track.album, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          onGoToAlbum();
                        },
                      ),

                      // Go to Artist (Namida SS4 inline expandable multi-artist selector!)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: artistsExpanded ? Colors.white.withValues(alpha: 0.045) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              leading: Icon(
                                artists.length > 1 ? Icons.groups_rounded : Icons.person_rounded,
                                color: Colors.white70,
                                size: 21,
                              ),
                              title: const Text('Go to Artist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                              subtitle: artists.length == 1
                                  ? Text(artists.first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white54))
                                  : null,
                              trailing: artists.length > 1
                                  ? Icon(
                                      artistsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white54,
                                      size: 20,
                                    )
                                  : const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                              onTap: () {
                                if (artists.length == 1) {
                                  Navigator.pop(ctx);
                                  onGoToArtist(artists.first);
                                } else {
                                  setCardState(() => artistsExpanded = !artistsExpanded);
                                }
                              },
                            ),
                            if (artists.length > 1 && artistsExpanded)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: artists.map((art) {
                                    return GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.pop(ctx);
                                        onGoToArtist(art);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.8),
                                        ),
                                        child: Text(
                                          art,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),

                      if (onFetchCoverOnline != null)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                          leading: const Icon(Icons.image_search_rounded, color: Colors.white70, size: 21),
                          title: const Text('Choose Song Cover Online', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          subtitle: const Text('Pick from Apple Music IN, JioSaavn & Deezer', style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                          onTap: () {
                            Navigator.pop(ctx);
                            onFetchCoverOnline();
                          },
                        ),

                      if (onEditTags != null)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                          leading: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 21),
                          title: const Text('Edit Tags & Cover', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          onTap: () {
                            Navigator.pop(ctx);
                            onEditTags();
                          },
                        ),

                      if (onLyricsEditor != null)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                          leading: const Icon(Icons.lyrics_rounded, color: Colors.white70, size: 20),
                          title: const Text('Lyrics Metadata & Editor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          onTap: () {
                            Navigator.pop(ctx);
                            onLyricsEditor();
                          },
                        ),

                      if (onFileInfo != null)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                          leading: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
                          title: const Text('File Info & Audio Properties', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          onTap: () {
                            Navigator.pop(ctx);
                            onFileInfo();
                          },
                        ),

                      // SS4-style Quick Action Icon Strip
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _NamiCardIconBtn(
                              icon: Icons.playlist_add_rounded,
                              label: 'Playlist',
                              onTap: () {
                                Navigator.pop(ctx);
                                onAddToPlaylist();
                              },
                            ),
                            if (onLyricsEditor != null)
                              _NamiCardIconBtn(
                                icon: Icons.subtitles_rounded,
                                label: 'Lyrics',
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onLyricsEditor();
                                },
                              ),
                            if (onEditTags != null)
                              _NamiCardIconBtn(
                                icon: Icons.sell_outlined,
                                label: 'Tags',
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onEditTags();
                                },
                              ),
                            if (onFileInfo != null)
                              _NamiCardIconBtn(
                                icon: Icons.graphic_eq_rounded,
                                label: 'Audio',
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onFileInfo();
                                },
                              ),
                            if (onDeleteForever != null)
                              _NamiCardIconBtn(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                                color: Colors.redAccent,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onDeleteForever();
                                },
                              ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: Colors.white10),

                      // SS4-style Split Bottom Bar: Play Next | Play Last
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(ctx);
                                onPlayNext();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.queue_play_next_rounded, color: Colors.white, size: 19),
                                    SizedBox(width: 8),
                                    Text('Play Next', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 24, color: Colors.white12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(ctx);
                                onPlayLast();
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_to_queue_rounded, color: Colors.white, size: 19),
                                    SizedBox(width: 8),
                                    Text('Play Last', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _NamiCardIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NamiCardIconBtn({
    required this.icon,
    required this.label,
    this.color = Colors.white70,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class NamiFloatingActionItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? textColor;
  final bool showDividerBefore;
  final VoidCallback onTap;

  const NamiFloatingActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.textColor,
    this.showDividerBefore = false,
  });
}

void showNamiFloatingActionSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  Widget? leading,
  required List<NamiFloatingActionItem> actions,
  String? footerLeftLabel,
  IconData? footerLeftIcon,
  VoidCallback? onFooterLeftTap,
  String? footerRightLabel,
  IconData? footerRightIcon,
  VoidCallback? onFooterRightTap,
}) {
  showModalBottomSheet(
    useRootNavigator: true,
    sheetAnimationStyle: namiSmoothSheetStyle,
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final hasFooter = (footerLeftLabel != null && onFooterLeftTap != null) ||
          (footerRightLabel != null && onFooterRightTap != null);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NamiOptionalBlur(sigmaX: 18, sigmaY: 18,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF00B0B12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.70),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
                      child: Row(
                        children: [
                          if (leading != null) ...[
                            leading,
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                if (subtitle != null && subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ...actions.expand((item) {
                      return [
                        if (item.showDividerBefore) const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                          leading: Icon(item.icon, color: item.iconColor ?? Colors.white70, size: 21),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: item.textColor ?? Colors.white,
                            ),
                          ),
                          subtitle: item.subtitle != null
                              ? Text(
                                  item.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(ctx);
                            item.onTap();
                          },
                        ),
                      ];
                    }),
                    if (hasFooter) ...[
                      const Divider(height: 1, color: Colors.white10),
                      Row(
                        children: [
                          if (footerLeftLabel != null && onFooterLeftTap != null)
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(ctx);
                                  onFooterLeftTap();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (footerLeftIcon != null) ...[
                                        Icon(footerLeftIcon, color: Colors.white, size: 19),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        footerLeftLabel,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (footerLeftLabel != null && footerRightLabel != null)
                            Container(width: 1, height: 24, color: Colors.white12),
                          if (footerRightLabel != null && onFooterRightTap != null)
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(ctx);
                                  onFooterRightTap();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (footerRightIcon != null) ...[
                                        Icon(footerRightIcon, color: Colors.white, size: 19),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        footerRightLabel,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ] else
                      const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<String?> showNamiRenameDialog({
  required BuildContext context,
  required String title,
  required String currentName,
  required String hintText,
}) async {
  final ctrl = TextEditingController(text: currentName);
  ctrl.selection = TextSelection(baseOffset: 0, extentOffset: currentName.length);
  final accent = Theme.of(context).colorScheme.primary;
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF101018),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.11)),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF171724),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accent, width: 1.2),
          ),
        ),
        onSubmitted: (v) {
          final trimmed = v.trim();
          if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final trimmed = ctrl.text.trim();
            if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

void showNamiMediaImagePickerSheet({
  required BuildContext context,
  required String sheetTitle,
  required String initialQuery,
  required Future<List<NamiMediaCandidate>> Function(String query) fetcher,
  required ValueChanged<NamiMediaCandidate> onPicked,
}) {
  final queryCtrl = TextEditingController(text: initialQuery);
  Future<List<NamiMediaCandidate>> currentFuture = fetcher(initialQuery);

  showModalBottomSheet(
    useRootNavigator: true,
    sheetAnimationStyle: namiSmoothSheetStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final accent = Theme.of(ctx).colorScheme.primary;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 48, 10, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NamiOptionalBlur(sigmaX: 18, sigmaY: 18,
                child: Container(
                  height: MediaQuery.of(ctx).size.height * 0.80,
                  decoration: BoxDecoration(
                    color: const Color(0xF20B0B12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            Icon(Icons.photo_library_rounded, color: accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sheetTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: queryCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText: 'Refine search (e.g. "Divine rapper India")...',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                                  isDense: true,
                                  filled: true,
                                  fillColor: const Color(0xFF161622),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (v) {
                                  if (v.trim().isEmpty) return;
                                  setSheetState(() {
                                    currentFuture = fetcher(v.trim());
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                final q = queryCtrl.text.trim();
                                if (q.isEmpty) return;
                                FocusScope.of(ctx).unfocus();
                                setSheetState(() {
                                  currentFuture = fetcher(q);
                                });
                              },
                              child: const Icon(Icons.search_rounded, size: 19),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: FutureBuilder<List<NamiMediaCandidate>>(
                          future: currentFuture,
                          builder: (_, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: accent));
                            }
                            final items = snap.data ?? [];
                            if (items.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'No matching images found.\nTry refining the search query above.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ),
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.78,
                              ),
                              itemCount: items.length,
                              itemBuilder: (_, idx) {
                                final cand = items[idx];
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(ctx);
                                    onPicked(cand);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141420),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ClipRRect(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                                child: Image.network(
                                                  cand.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.broken_image_rounded, color: Colors.white24),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 6,
                                                left: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.72),
                                                    borderRadius: BorderRadius.circular(7),
                                                  ),
                                                  child: Text(
                                                    cand.source,
                                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: accent),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cand.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                              ),
                                              if (cand.subtitle.isNotEmpty)
                                                Text(
                                                  cand.subtitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
