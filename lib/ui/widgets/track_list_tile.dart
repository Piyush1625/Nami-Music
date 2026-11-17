import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';

class TrackListTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final bool isPlaying;

  const TrackListTile({
    Key? key,
    required this.item,
    required this.onTap,
    this.isPlaying = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: item.artUri != null
            ? Image.network(item.artUri.toString(), width: 40, height: 40, fit: BoxFit.cover)
            : Container(width: 40, height: 40, color: Colors.grey.shade800, child: const Icon(Icons.music_note, size: 20)),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600,
          fontSize: 14.5,
          color: isPlaying ? primaryColor : Colors.white,
        ),
      ),
      subtitle: Text(
        item.artist ?? 'Unknown Artist',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: Colors.white70),
      ),
      trailing: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white54),
      onTap: onTap,
    );
  }
}
