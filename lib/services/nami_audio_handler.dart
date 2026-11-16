import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rxdart/rxdart.dart';

class NamiAudioHandler extends BaseAudioHandler with SeekHandler {
  final Player player;

  NamiAudioHandler(this.player) {
    _initStreams();
  }

  void _initStreams() {
    player.stream.playing.listen((playing) {
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: AudioProcessingState.ready,
      ));
    });

    player.stream.position.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  void updateMetadata({
    required String title,
    required String artist,
    required String album,
    required String artUri,
    required Duration duration,
  }) {
    mediaItem.add(MediaItem(
      id: artUri,
      album: album,
      title: title,
      artist: artist,
      artUri: Uri.parse(artUri),
      duration: duration,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.next();

  @override
  Future<void> skipToPrevious() => player.previous();

  @override
  Future<void> stop() async {
    await player.stop();
  }
}
