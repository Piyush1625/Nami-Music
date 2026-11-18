c = open("lib/main.dart", encoding="utf-8").read()

a1 = c.index("            Padding(\n              padding: const EdgeInsets.symmetric(horizontal: 20),\n              child: Row(\n                children: [\n                  _buildRoundArtistAvatar(firstArtTrack, 50),")
b1 = c.index("            const SizedBox(height: 20),", a1)
r1 = """            Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF14141E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
                image: firstArtTrack.albumArt != null
                    ? DecorationImage(image: MemoryImage(firstArtTrack.albumArt!), fit: BoxFit.cover, opacity: 0.16)
                    : null,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildRoundArtistAvatar(firstArtTrack, 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(artistName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('${artistTracks.length} Tracks • ${albumsMap.length} Albums • $formattedTotal', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => _playSong(artistTracks.first),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                ],
              ),
            ),
"""

a2 = c.index("void _showFilteredListScreen(String title, List<AudioTrack> tracks) {")
b2 = c.index("void _showCreatePlaylistDialog() {", a2)
r2 = """void _showFilteredListScreen(String title, List<AudioTrack> tracks) {
  final totalSec = tracks.fold<int>(0, (sum, t) => sum + t.duration.inSeconds);
  final durText = _formatTotalDurationHoursMins(Duration(seconds: totalSec));
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
        body: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 140),
              itemCount: tracks.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF14141E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${tracks.length} Tracks', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text('Total duration • $durText', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                            ],
                          ),
                        ),
                        if (tracks.isNotEmpty) ...[
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
                            icon: const Icon(Icons.play_arrow_rounded),
                            onPressed: () => _playSong(tracks.first),
                          ),
                          const SizedBox(width: 6),
                          IconButton.outlined(
                            style: IconButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                            icon: const Icon(Icons.shuffle_rounded, size: 20),
                            onPressed: () {
                              final sh = List<AudioTrack>.from(tracks)..shuffle();
                              _playSong(sh.first);
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return _buildNamidaTrackTile(tracks[i - 1]);
              },
            ),
            Positioned(left: 10, right: 10, bottom: 12, child: _buildReactiveMiniPlayer()),
          ],
        ),
      ),
    ),
  );
}

"""

c = c[:a1] + r1 + c[b1:a2] + r2 + c[b2:]
open("lib/main.dart", "w", encoding="utf-8").write(c)
print("SUCCESS 1/3: Artist Detail & Filtered Track screens upgraded!")
