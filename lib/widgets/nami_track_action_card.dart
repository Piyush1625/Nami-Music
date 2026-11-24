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
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.65),
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
                    backgroundColor: accent.withOpacity(0.16),
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
  VoidCallback? onFileInfo,
  VoidCallback? onDeleteForever,
}) {
  final artists = namiSplitArtists(track.artist);
  bool artistsExpanded = artists.length > 1;

  showModalBottomSheet(
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
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xF00B0B12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.11)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.70),
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
                                            color: accent.withOpacity(0.16),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: accent.withOpacity(0.35), width: 0.7),
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
                          color: artistsExpanded ? Colors.white.withOpacity(0.045) : Colors.transparent,
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
                                          color: accent.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: accent.withOpacity(0.35), width: 0.8),
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
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.09)),
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
