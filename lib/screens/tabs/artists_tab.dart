// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../../main.dart';

extension _NamiArtistsTabExt on _NamiHomeShellState {
  void _showArtistDetailScreen(String artistName, List<AudioTrack> artistTracks) {
    if (artistTracks.isEmpty) return;
    final accent = Theme.of(context).colorScheme.primary;
    final firstArtTrack = artistTracks.firstWhere(
      (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
      orElse: () => artistTracks.first,
    );

    // Primary Releases vs Appears On split
    final primaryTracks = <AudioTrack>[];
    final appearsOnTracks = <AudioTrack>[];
    final escaped = _artistSeparators.map((s) => RegExp.escape(s)).join('|');
    final splitter = escaped.isNotEmpty ? RegExp(escaped, caseSensitive: false) : null;
    for (final s in artistTracks) {
      final firstArt = splitter != null ? s.artist.split(splitter).first.trim() : s.artist.trim();
      final canonicalFirst = NamiV16Prefs.instance.resolveCanonicalArtist(firstArt);
      if (canonicalFirst.toLowerCase() == artistName.toLowerCase()) {
        primaryTracks.add(s);
      } else {
        appearsOnTracks.add(s);
      }
    }

    // Chronological Album Timeline
    final Map<String, List<AudioTrack>> albumsMap = {};
    int totalSeconds = 0;
    for (final s in (primaryTracks.isNotEmpty ? primaryTracks : artistTracks)) {
      albumsMap.putIfAbsent(s.album, () => []).add(s);
      totalSeconds += s.duration.inSeconds;
    }
    for (final s in appearsOnTracks) {
      totalSeconds += s.duration.inSeconds;
    }
    final chronologicalAlbums = albumsMap.entries.toList()
      ..sort((a, b) {
        final ya = int.tryParse(a.value.first.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final yb = int.tryParse(b.value.first.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return yb.compareTo(ya);
      });
    final formattedTotal = _formatTotalDurationHoursMins(Duration(seconds: totalSeconds));

    // Top 5 Tracks Preview
    final top5Tracks = List<AudioTrack>.from(artistTracks)
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final topPreview = top5Tracks.take(5).toList();

    // Similar Local Artists (shared genres & collaborations)
    final artistGenres = artistTracks.map((t) => t.genre.toLowerCase().trim()).where((g) => g.isNotEmpty).toSet();
    final similarArtists = <String>[];
    for (final entry in artistGroups.entries) {
      if (entry.key.toLowerCase() == artistName.toLowerCase()) continue;
      final sharesCollab = entry.value.any((t) => artistTracks.contains(t));
      final sharesGenre = entry.value.any((t) => artistGenres.contains(t.genre.toLowerCase().trim()));
      if (sharesCollab || sharesGenre) {
        similarArtists.add(entry.key);
        if (similarArtists.length >= 12) break;
      }
    }

    bool bioExpanded = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setAdState) => Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 275,
                      pinned: true,
                      backgroundColor: const Color(0xFF000000),
                      actions: [
                        _buildArtistHeroThreeDotsButton(ctx, artistName, artistTracks, onUpdated: () {
                          setAdState(() {});
                          setState(() {});
                        }),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        titlePadding: const EdgeInsets.only(left: 52, bottom: 14, right: 92),
                        title: Text(
                          artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        background: ValueListenableBuilder<int>(
                          valueListenable: _artworkTick,
                          builder: (_, __, ___) {
                            final customPath = _artistImagePaths[artistName];
                            Widget bgImage;
                            if (customPath != null && File(customPath).existsSync()) {
                              bgImage = Image.file(File(customPath), fit: BoxFit.cover);
                            } else if (firstArtTrack.albumArt != null) {
                              bgImage = Image.memory(firstArtTrack.albumArt!, fit: BoxFit.cover);
                            } else if (firstArtTrack.thumbPath != null && File(firstArtTrack.thumbPath!).existsSync()) {
                              bgImage = Image.file(File(firstArtTrack.thumbPath!), fit: BoxFit.cover);
                            } else {
                              bgImage = Container(color: const Color(0xFF14141E), child: const Icon(Icons.person_rounded, size: 96, color: Colors.white24));
                            }
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                bgImage,
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black38, Colors.transparent, Color(0xCC000000), Color(0xFF000000)],
                                      stops: [0.0, 0.35, 0.78, 1.0],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${artistTracks.length} Tracks • ${chronologicalAlbums.length} Albums • $formattedTotal',
                              style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                    onPressed: () => _playSong(artistTracks.first),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                    label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                    onPressed: () {
                                      final sh = List<AudioTrack>.from(artistTracks)..shuffle();
                                      _playSong(sh.first);
                                    },
                                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                                    label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            FutureBuilder<NamiArtistProfile>(
                              future: NamiArtistMetadataService.fetchArtistProfile(
                                artistName,
                                localTracks: artistTracks.length,
                                localAlbums: chronologicalAlbums.length,
                                sampleTracks: artistTracks.take(3).map((t) => t.title).toList(),
                                sampleAlbums: chronologicalAlbums.take(3).map((e) => e.key).toList(),
                              ),
                              builder: (_, profSnap) {
                                final prof = profSnap.data;
                                if (prof == null) return const SizedBox.shrink();
                                // Auto-apply Apple Music / Spotify portrait if no custom gallery photo is set
                                if (prof.photoUrl != null &&
                                    prof.photoUrl!.isNotEmpty &&
                                    !(_artistImagePaths[artistName]?.contains('artist_custom') ?? false)) {
                                  final curPath = _artistImagePaths[artistName];
                                  if (curPath == null || !File(curPath).existsSync()) {
                                    _fetchArtistImage(artistName);
                                  }
                                }
                                final metaTags = <String>[
                                  if (prof.primaryGenre != null && prof.primaryGenre!.isNotEmpty) prof.primaryGenre!,
                                  if (prof.origin != null && prof.origin!.isNotEmpty) prof.origin!,
                                  if (prof.activeSince != null && prof.activeSince!.isNotEmpty) 'Since ${prof.activeSince!}',
                                  if (prof.spotifyListeners != null && prof.spotifyListeners!.isNotEmpty) prof.spotifyListeners!,
                                ];
                                return GestureDetector(
                                  onTap: () => setAdState(() => bioExpanded = !bioExpanded),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0E0E15),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'ABOUT $artistName'.toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: accent),
                                              ),
                                            ),
                                            if (prof.combinedSourceLabel.isNotEmpty)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  prof.combinedSourceLabel,
                                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white60),
                                                ),
                                              ),
                                            Icon(bioExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: Colors.white54),
                                          ],
                                        ),
                                        if (metaTags.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: metaTags.map((tag) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: accent.withOpacity(0.14),
                                                    borderRadius: BorderRadius.circular(7),
                                                    border: Border.all(color: accent.withOpacity(0.32), width: 0.7),
                                                  ),
                                                  child: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                                )).toList(),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          prof.bio,
                                          maxLines: bioExpanded ? 14 : 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            Text('Albums Timeline (${chronologicalAlbums.length})', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 154,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: chronologicalAlbums.map((entry) {
                                  final albArtTrack = entry.value.firstWhere(
                                    (s) => s.albumArt != null || (s.thumbPath != null && File(s.thumbPath!).existsSync()),
                                    orElse: () => entry.value.first,
                                  );
                                  final yr = entry.value.first.year.replaceAll(RegExp(r'[^0-9]'), '');
                                  return GestureDetector(
                                    onTap: () => _showAlbumDetailScreen(entry.key, entry.value),
                                    child: Container(
                                      width: 106,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Stack(
                                            children: [
                                              _buildCoverArt(albArtTrack, 102, 12),
                                              if (yr.length >= 4)
                                                Positioned(
                                                  left: 6,
                                                  top: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(6)),
                                                    child: Text(yr.substring(0, 4), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                          Text('${entry.value.length} Tracks', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            if (topPreview.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('Top Tracks', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildNamiTrackTile(topPreview[i]),
                        childCount: topPreview.length,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                        child: Text('Primary Releases (${primaryTracks.length})', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _buildNamiTrackTile(primaryTracks[i]),
                        childCount: primaryTracks.length,
                      ),
                    ),
                    if (appearsOnTracks.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                          child: Text('Appears On (${appearsOnTracks.length})', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildNamiTrackTile(appearsOnTracks[i]),
                          childCount: appearsOnTracks.length,
                        ),
                      ),
                    ],
                    if (similarArtists.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Similar in Your Library', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 108,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: similarArtists.length,
                                  itemBuilder: (_, idx) {
                                    final simName = similarArtists[idx];
                                    final simTracks = artistGroups[simName] ?? [];
                                    return GestureDetector(
                                      onTap: () => _showArtistDetailScreen(simName, simTracks),
                                      child: Container(
                                        width: 80,
                                        margin: const EdgeInsets.only(right: 10),
                                        child: Column(
                                          children: [
                                            _buildRoundArtistAvatar(simTracks.isNotEmpty ? simTracks.first : null, 32, artistNameOverride: simName),
                                            const SizedBox(height: 6),
                                            Text(simName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            Text('${simTracks.length} Tracks', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 130)),
                  ],
                ),
                Positioned(left: 12, right: 12, bottom: 14, child: _buildDetailFloatingDock(ctx, scopeTitle: artistName, scopeTracks: artistTracks)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtistHeroThreeDotsButton(BuildContext ctx, String artistName, List<dynamic> artistSongs, {VoidCallback? onUpdated}) {
    return IconButton(
      tooltip: 'Artist Options',
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 19),
      ),
      onPressed: () {
        final imgPath = _artistImagePaths[artistName];
        final hasImg = imgPath != null && File(imgPath).existsSync();
        showNamiFloatingActionSheet(
          context: context,
          title: artistName,
          subtitle: 'Artist Options',
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white10,
            backgroundImage: hasImg ? FileImage(File(imgPath)) : null,
            child: hasImg ? null : const Icon(Icons.person_rounded, color: Colors.white70),
          ),
          actions: [
                NamiFloatingActionItem(
                  icon: Icons.auto_fix_high_rounded,
                  title: 'Fetch Spotify / Apple Music',
                  subtitle: 'Download official artist portrait & bio',
                  onTap: () {
                    NamiArtistMetadataService.invalidate(artistName);
                    _refreshArtistPhotoFromStreaming(artistName, onUpdated: onUpdated);
                  },
                ),
NamiFloatingActionItem(
                  icon: Icons.drive_file_rename_outline_rounded,
                  title: 'Rename Artist',
                  subtitle: 'Update artist name across all tracks',
                  showDividerBefore: true,
                  onTap: () async {
                    final renamed = await _renameArtistEverywhere(artistName);
                    if (renamed != null && context.mounted) {
                      Navigator.of(context).pop();
                      _openArtistByName(renamed);
                    }
                  },
                ),
          ],
        );
      },
    );
  }
}
