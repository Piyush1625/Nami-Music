// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../../main.dart';

extension _NamiPlaylistsTabExt on _NamiHomeShellState {
  void _showSmartPlaylistBuilderDialog({NamiSmartRulePlaylist? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final genreCtrl = TextEditingController(text: existing?.genreContains ?? '');
    final exclCtrl = TextEditingController(text: existing?.excludeArtists ?? '');
    String fmt = existing?.formatFilter ?? 'FLAC';
    int days = existing?.addedWithinDays ?? 0;
    int maxPlays = existing?.maxPlayCount ?? -1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setRState) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existing == null ? 'New Smart Rule Playlist' : 'Edit Smart Playlist', style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _buildRichInputField(nameCtrl, 'Playlist Name (e.g. 24B Hip-Hop Mix)'),
                  const SizedBox(height: 10),
                  const Text('Audio Format', style: TextStyle(fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: ['All', 'FLAC', '24B', 'Lossless'].map((f) => ChoiceChip(
                          label: Text(f, style: const TextStyle(fontSize: 11.5)),
                          selected: fmt == f,
                          selectedColor: accent,
                          onSelected: (_) => setRState(() => fmt = f),
                        )).toList(),
                  ),
                  const SizedBox(height: 10),
                  _buildRichInputField(genreCtrl, 'Genre Contains (optional, e.g. Hip-Hop)'),
                  const SizedBox(height: 8),
                  _buildRichInputField(exclCtrl, 'Exclude Artists (comma-separated, optional)'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Added Within', style: TextStyle(fontSize: 12.5)),
                      Wrap(
                        spacing: 6,
                        children: [(0, 'Any'), (30, '30d'), (90, '90d'), (365, '1y')].map((d) => ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(d.$2, style: const TextStyle(fontSize: 11)),
                              selected: days == d.$1,
                              selectedColor: accent,
                              onSelected: (_) => setRState(() => days = d.$1),
                            )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Play Count', style: TextStyle(fontSize: 12.5)),
                      Wrap(
                        spacing: 6,
                        children: [(-1, 'Any'), (0, 'Unplayed'), (3, '<= 3')].map((p) => ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(p.$2, style: const TextStyle(fontSize: 11)),
                              selected: maxPlays == p.$1,
                              selectedColor: accent,
                              onSelected: (_) => setRState(() => maxPlays = p.$1),
                            )).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                        onPressed: () async {
                          final n = nameCtrl.text.trim();
                          if (n.isEmpty) return;
                          final prefs = NamiV16Prefs.instance;
                          if (existing != null) {
                            existing
                              ..name = n
                              ..formatFilter = fmt
                              ..genreContains = genreCtrl.text.trim()
                              ..addedWithinDays = days
                              ..maxPlayCount = maxPlays
                              ..excludeArtists = exclCtrl.text.trim();
                          } else {
                            prefs.smartPlaylists.add(NamiSmartRulePlaylist(
                              id: '${DateTime.now().millisecondsSinceEpoch}',
                              name: n,
                              formatFilter: fmt,
                              genreContains: genreCtrl.text.trim(),
                              addedWithinDays: days,
                              maxPlayCount: maxPlays,
                              excludeArtists: exclCtrl.text.trim(),
                            ));
                          }
                          await prefs.save();
                          if (ctx.mounted) Navigator.pop(ctx);
                          setState(() {});
                        },
                        child: const Text('Save Mix', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
