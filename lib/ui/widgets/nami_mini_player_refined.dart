import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:nami/main.dart'; 

class NamiMiniPlayerRefined extends StatelessWidget {
  const NamiMiniPlayerRefined({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return Dismissible(
          key: const Key('mini_player'),
          direction: DismissDirection.down,
          onDismissed: (_) => audioHandler.stop(),
          child: GestureDetector(
            onTap: () {
              // Open NowPlayingModal
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: mediaItem.artUri != null
                              ? Image.network(mediaItem.artUri.toString(), width: 44, height: 44, fit: BoxFit.cover)
                              : const Icon(Icons.music_note, size: 44),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text(mediaItem.artist ?? 'Unknown Artist', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, stateSnapshot) {
                            final playing = stateSnapshot.data?.playing ?? false;
                            return IconButton(
                              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                              onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, stateSnapshot) {
                      final position = stateSnapshot.data?.position ?? Duration.zero;
                      final duration = mediaItem.duration ?? const Duration(milliseconds: 1);
                      final progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}