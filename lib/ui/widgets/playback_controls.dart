import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:nami/main.dart'; 

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 42,
              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
              onPressed: () => audioHandler.skipToPrevious(),
              splashRadius: 32,
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              ),
              child: IconButton(
                iconSize: 64,
                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                splashRadius: 40,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 42,
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              onPressed: () => audioHandler.skipToNext(),
              splashRadius: 32,
            ),
          ],
        );
      },
    );
  }
}