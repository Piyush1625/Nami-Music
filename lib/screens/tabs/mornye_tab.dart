// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../../main.dart';

extension _NamiMornyeTabExt on _NamiHomeShellState {
  Future<void> _searchMornyeCatalog(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isMornyeSearching = true);
    try {
      final uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query.trim())}&media=music&entity=song,album,musicArtist&limit=28');
      final res = await http.get(uri, headers: _httpHeaders).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = (data['results'] as List?) ?? [];
        final parsed = <MornyeCatalogItem>[];
        for (final r in results) {
          if (r is! Map) continue;
          final wrapper = (r['wrapperType'] ?? '').toString();
          if (wrapper == 'track') {
            parsed.add(MornyeCatalogItem(
              title: (r['trackName'] ?? 'Unknown').toString(),
              artist: (r['artistName'] ?? 'Unknown Artist').toString(),
              album: (r['collectionName'] ?? 'Single').toString(),
              subtitle: '${r['primaryGenreName'] ?? 'Music'} • $_selectedMornyeService',
              type: 'Track',
              service: _selectedMornyeService,
              previewUrl: r['previewUrl']?.toString(),
              artworkUrl: r['artworkUrl100']?.toString().replaceAll('100x100', '600x600'),
              durationSeconds: ((r['trackTimeMillis'] ?? 210000) as int) ~/ 1000,
              collectionId: r['collectionId']?.toString(),
            ));
          } else if (wrapper == 'collection') {
            parsed.add(MornyeCatalogItem(
              title: (r['collectionName'] ?? 'Unknown Album').toString(),
              artist: (r['artistName'] ?? 'Unknown Artist').toString(),
              album: (r['collectionName'] ?? 'Album').toString(),
              subtitle: '${r['trackCount'] ?? 0} tracks • ${r['primaryGenreName'] ?? 'Album'}',
              type: 'Album',
              service: _selectedMornyeService,
              artworkUrl: r['artworkUrl100']?.toString().replaceAll('100x100', '600x600'),
              collectionId: r['collectionId']?.toString(),
            ));
          } else if (wrapper == 'artist') {
            parsed.add(MornyeCatalogItem(
              title: (r['artistName'] ?? 'Unknown Artist').toString(),
              artist: (r['artistName'] ?? 'Unknown Artist').toString(),
              album: 'Artist Catalog',
              subtitle: '${r['primaryGenreName'] ?? 'Artist'} • $_selectedMornyeService',
              type: 'Artist',
              service: _selectedMornyeService,
            ));
          }
        }
        setState(() {
          _mornyeResults = parsed;
          _isMornyeSearching = false;
        });
      } else {
        setState(() => _isMornyeSearching = false);
      }
    } catch (_) {
      setState(() => _isMornyeSearching = false);
    }
  }

  Future<void> _testMornyeExtensionEndpoint(MornyeExtension ext) async {
    final url = (ext.endpointUrl ?? '').trim();
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ext.name}: Built-in catalog mode (30s preview). Add an endpoint URL via .sflx to enable full streams.')),
        );
      }
      return;
    }
    try {
      final res = await http.get(Uri.parse(url), headers: _httpHeaders).timeout(const Duration(seconds: 6));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ext.name} endpoint responded: HTTP ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ext.name} endpoint unreachable: $e')),
        );
      }
    }
  }

  void _showMornyeDownloadsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ValueListenableBuilder<List<MornyeDownloadTask>>(
        valueListenable: NamiDownloadManager.instance.tasksNotifier,
        builder: (ctx, tasks, _) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.68,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.downloading_rounded, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Download Manager (${tasks.length})',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Templates & Rules',
                        icon: const Icon(Icons.tune_rounded, size: 20, color: Colors.white70),
                        onPressed: _showMornyeDownloadRulesDialog,
                      ),
                      if (tasks.isNotEmpty)
                        TextButton(
                          onPressed: NamiDownloadManager.instance.clearFinished,
                          child: const Text('Clear Done'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: tasks.isEmpty
                        ? const Center(
                            child: Text(
                              'No active or recent downloads.\nTap Download on any Mornye track to queue it with auto-tagging.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (_, i) {
                              final t = tasks[i];
                              final statusText = switch (t.status) {
                                MornyeDownloadStatus.queued => 'Queued...',
                                MornyeDownloadStatus.downloading =>
                                    'Downloading ${(t.progress * 100).round()}%',
                                MornyeDownloadStatus.tagging =>
                                    'Auto-tagging cover & synced .lrc...',
                                MornyeDownloadStatus.done =>
                                    t.isFullStream ? 'Saved & Tagged (Full)' : 'Saved & Tagged (30s Preview)',
                                MornyeDownloadStatus.cancelled => 'Cancelled',
                                MornyeDownloadStatus.error => 'Failed: ${t.errorMessage ?? "Error"}',
                              };
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161622),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
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
                                                t.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                              ),
                                              Text(
                                                '${t.artist} • $statusText',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11, color: Colors.white60),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (t.status == MornyeDownloadStatus.downloading ||
                                            t.status == MornyeDownloadStatus.queued)
                                          IconButton(
                                            tooltip: 'Cancel',
                                            icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                                            onPressed: () => NamiDownloadManager.instance.cancelTask(t.id),
                                          )
                                        else if (t.status == MornyeDownloadStatus.error ||
                                            t.status == MornyeDownloadStatus.cancelled)
                                          IconButton(
                                            tooltip: 'Retry',
                                            icon: Icon(Icons.refresh_rounded, color: accent, size: 20),
                                            onPressed: () => NamiDownloadManager.instance.retryTask(t.id),
                                          )
                                        else if (t.status == MornyeDownloadStatus.done)
                                          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                                      ],
                                    ),
                                    if (t.status == MornyeDownloadStatus.downloading ||
                                        t.status == MornyeDownloadStatus.tagging) ...[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: t.status == MornyeDownloadStatus.tagging ? null : t.progress,
                                          minHeight: 4,
                                          backgroundColor: Colors.white10,
                                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMornyeDownloadRulesDialog() {
    final prefs = NamiV16Prefs.instance;
    final tplCtrl = TextEditingController(text: prefs.mornyePathTemplate);
    int conc = prefs.mornyeMaxConcurrent;
    bool wifi = prefs.mornyeWifiOnly;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setRState) => AlertDialog(
          backgroundColor: const Color(0xFF14141F),
          title: const Text('Download Templates & Rules', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: tplCtrl,
                decoration: const InputDecoration(
                  labelText: 'Folder & Filename Template',
                  hintText: '{Artist}/{Album}/{Track} - {Title}',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Concurrent Downloads', style: TextStyle(fontSize: 13)),
                  Wrap(
                    spacing: 6,
                    children: [1, 2, 3].map((n) => ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text('$n'),
                          selected: conc == n,
                          selectedColor: Theme.of(ctx).colorScheme.primary,
                          onSelected: (_) => setRState(() => conc = n),
                        )).toList(),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Wi-Fi Only Downloads', style: TextStyle(fontSize: 13)),
                value: wifi,
                activeColor: Theme.of(ctx).colorScheme.primary,
                onChanged: (v) => setRState(() => wifi = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                prefs.mornyePathTemplate = tplCtrl.text.trim().isEmpty
                    ? '{Artist}/{Album}/{Track} - {Title}'
                    : tplCtrl.text.trim();
                prefs.mornyeMaxConcurrent = conc;
                prefs.mornyeWifiOnly = wifi;
                await prefs.save();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
