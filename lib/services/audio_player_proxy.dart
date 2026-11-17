// Drop-in bridge to route legacy audioPlayer calls to audioHandler for Lockscreen/Notification sync
import 'package:audio_service/audio_service.dart';
import 'package:nami/main.dart';

class AudioPlayerProxy {
  static Future<void> play() => audioHandler.play();
  static Future<void> pause() => audioHandler.pause();
  static Future<void> seek(Duration position) => audioHandler.seek(position);
  static Future<void> skipToNext() => audioHandler.skipToNext();
  static Future<void> skipToPrevious() => audioHandler.skipToPrevious();
  
  static Future<void> playTrack(dynamic track) async {
    final mediaItem = MediaItem(
      id: track.path,
      title: track.title,
      artist: track.artist ?? 'Unknown Artist',
      album: track.album ?? 'Nami Music',
    );
    // Cast audioHandler to NamiAudioHandler to use playMediaItem
    await (audioHandler as dynamic).playMediaItem(mediaItem);
  }
}
