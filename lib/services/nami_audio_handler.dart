import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nami/services/playback_history_service.dart';

class NamiAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final Player player;
  final List<MediaItem> _playlistItems = [];
  String? _currentSongId;
  Duration _lastSavedPos = Duration.zero;

  NamiAudioHandler(this.player) {
    _initEmptyState();
    _initStreams();
  }

  void _initEmptyState() {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  void _broadcastState() {
    final playing = player.state.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: player.state.buffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      playing: playing,
      updatePosition: player.state.position,
      bufferedPosition: player.state.buffer,
      speed: player.state.rate,
    ));
  }

  void _initStreams() {
    player.stream.playing.listen((_) => _broadcastState());
    player.stream.buffering.listen((_) => _broadcastState());

    player.stream.duration.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration > Duration.zero && current.duration != duration) {
        final updated = current.copyWith(duration: duration);
        mediaItem.add(updated);
        final idx = _playlistItems.indexWhere((e) => e.id == current.id);
        if (idx != -1) {
          _playlistItems[idx] = updated;
          queue.add(List.from(_playlistItems));
        }
      }
      _broadcastState();
    });

    player.stream.position.listen((position) {
      // Throttle state persistence & lockscreen position updates
      if ((position - _lastSavedPos).inSeconds.abs() >= 2) {
        _lastSavedPos = position;
        playbackState.add(playbackState.value.copyWith(
          updatePosition: position,
        ));
        if (_currentSongId != null) {
          PlaybackHistoryService.savePlaybackState(_currentSongId!, position);
        }
      }
    });

    player.stream.playlist.listen((playlist) {
      final index = playlist.index;
      if (_playlistItems.isNotEmpty && index >= 0 && index < _playlistItems.length) {
        final item = _playlistItems[index];
        _currentSongId = item.id;
        mediaItem.add(item);
        playbackState.add(playbackState.value.copyWith(queueIndex: index));
        PlaybackHistoryService.incrementPlayCount(item.id);
        _broadcastState();
      }
    });
  }

  /// Play a single track or replace the active playlist and trigger lockscreen notification
  Future<void> setPlaylist(List<MediaItem> items, {int initialIndex = 0}) async {
    if (items.isEmpty) return;
    _playlistItems.clear();
    _playlistItems.addAll(items);
    queue.add(List.from(_playlistItems));

    final initialItem = items[initialIndex];
    _currentSongId = initialItem.id;
    mediaItem.add(initialItem);

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
      queueIndex: initialIndex,
      playing: true,
    ));

    final mediaKitTracks = items.map((item) => Media(item.id)).toList();
    await player.open(
      Playlist(mediaKitTracks, index: initialIndex),
      play: true,
    );

    PlaybackHistoryService.incrementPlayCount(initialItem.id);
    _broadcastState();
  }

  /// Helper to play a single song directly while still showing the notification
  Future<void> playMediaItem(MediaItem item) async {
    await setPlaylist([item], initialIndex: 0);
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    _playlistItems.add(item);
    queue.add(List.from(_playlistItems));
    await player.add(Media(item.id));
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index >= 0 && index < _playlistItems.length) {
      _playlistItems.removeAt(index);
      queue.add(List.from(_playlistItems));
      await player.remove(index);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _playlistItems.length) {
      await player.jump(index);
    }
  }

  void updateMetadata({
    required String id,
    required String title,
    required String artist,
    required String album,
    String? artUri,
    Duration? duration,
  }) {
    Uri? parsedUri;
    if (artUri != null && artUri.isNotEmpty) {
      parsedUri = artUri.startsWith('/') ? Uri.file(artUri) : Uri.tryParse(artUri);
    }
    final item = MediaItem(
      id: id,
      album: album,
      title: title,
      artist: artist,
      artUri: parsedUri,
      duration: duration ?? player.state.duration,
    );
    _currentSongId = item.id;
    mediaItem.add(item);
    _broadcastState();
  }

  @override
  Future<void> play() async {
    await player.play();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  @override
  Future<void> skipToNext() async {
    await player.next();
    _broadcastState();
  }

  @override
  Future<void> skipToPrevious() async {
    await player.previous();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
    await player.setShuffle(enabled);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        await player.setPlaylistMode(PlaylistMode.single);
        break;
      case AudioServiceRepeatMode.all:
        await player.setPlaylistMode(PlaylistMode.loop);
        break;
      case AudioServiceRepeatMode.none:
      case AudioServiceRepeatMode.group:
        await player.setPlaylistMode(PlaylistMode.none);
        break;
    }
  }
}
