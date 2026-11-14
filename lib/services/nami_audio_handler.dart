import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/nami_models.dart';

class NamiAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;

  NamiAudioHandler(this._player) {
    _initPlaybackStateStream();
  }

  void _initPlaybackStateStream() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  void updateCurrentMediaItem(AudioTrack track) {
    mediaItem.add(
      MediaItem(
        id: track.path,
        album: track.album,
        title: track.title,
        artist: track.artist,
        duration: track.duration,
        artUri: track.thumbPath != null ? Uri.file(track.thumbPath!) : null,
      ),
    );
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onSkipNext != null) {
      onSkipNext!();
    } else {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipPrevious != null) {
      onSkipPrevious!();
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}
