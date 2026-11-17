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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.artUri != null
            ? Image.network(item.artUri.toString(), width: 52, height: 52, fit: BoxFit.cover)
            : Container(width: 52, height: 52, color: Colors.grey.shade800, child: const Icon(Icons.music_note)),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600,
          fontSize: 16,
          color: isPlaying ? Theme.of(context).primaryColorH: Colors.white,
        ),
      ),
      subtitle: Text(
        item.artist ?? 'Unknown Artist',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
      trailing: const Icon(Icons.more_vert_rounded, color: Colors.white54),
      onTap: onTap,
    );
  }
}