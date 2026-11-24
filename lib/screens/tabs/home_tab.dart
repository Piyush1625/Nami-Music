// ignore_for_file: invalid_use_of_protected_member, deprecated_member_use
part of '../../main.dart';

extension _NamiHomeTabExt on _NamiHomeShellState {
  void _showHomeShelfCustomizer() {
    final prefs = NamiV16Prefs.instance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101018),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSState) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Customize Home Shelves', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      TextButton(
                        onPressed: () async {
                          await prefs.resetSection('home');
                          setSState(() {});
                          setState(() {});
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Drag handles to reorder • Toggle switches to show/hide', style: TextStyle(fontSize: 11.5, color: Colors.white54)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: prefs.homeShelvesOrder.length,
                    onReorder: (oldIdx, newIdx) {
                      setSState(() {
                        if (newIdx > oldIdx) newIdx -= 1;
                        final moved = prefs.homeShelvesOrder.removeAt(oldIdx);
                        prefs.homeShelvesOrder.insert(newIdx, moved);
                      });
                      prefs.save();
                      setState(() {});
                    },
                    itemBuilder: (_, idx) {
                      final key = prefs.homeShelvesOrder[idx];
                      final visible = !prefs.hiddenHomeShelves.contains(key);
                      return Container(
                        key: ValueKey('shelf_$key'),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161622),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: idx,
                            child: const Icon(Icons.drag_indicator_rounded, color: Colors.white54),
                          ),
                          title: Text(NamiV16Prefs.shelfLabels[key] ?? key, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          trailing: Switch(
                            value: visible,
                            activeThumbColor: accent,
                            onChanged: (v) {
                              setSState(() {
                                if (v) {
                                  prefs.hiddenHomeShelves.remove(key);
                                } else {
                                  prefs.hiddenHomeShelves.add(key);
                                }
                              });
                              prefs.save();
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
