import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nami/services/playback_history_service.dart';

class NamiAudioHandler extends BaseAudioHandler with SeekHandler {
  final Player player;
  
  // Internal list to keep track of MediaItems corresponding to playlist tracks
  final List<MediaItem> _playlistItems = [];
  String? _currentSongId;

  NamiAudioHandler(this.player) {
    _initStreams();
  }

  void _initStreams() {
    // Listen to playback state changes
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
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        processingState: AudioProcessingState.ready,
      ));
    });

    // Listen to position updates and persist playback state
    player.stream.position.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));

      if (_currentSongId != null) {
        PlaybackHistoryService.savePlaybackState(_currentSongId!, position);
      }
    });

    // Listen to active playlist index changes in media_kit
    player.stream.playlist.listen((playlist) {
      final index = playlist.index;
      if (_playlistItems.isNotEmpty && index >= 0 && index < _playlistItems.length) {
        final item = _playlistItems[index];
        _currentSongId = item.id;
        mediaItem.add(item);
        
        // Increment play count for this track
        PlaybackHistoryService.incrementPlayCount(item.id);
      }
    });
  }

  // Set or replace the active queue and start playback
  Future<void> setPlaylist(List<MediaItem> items, {int initialIndex = 0}) async {
    _playlistItems.clear();
    _playlistItems.addAll(items);
    queue.add(_playlistItems);

    final mediaKitTracks = items.map((item) => Media(item.id)).toList();
    await player.open(
      Playlist(mediaKitTracks, index: initialIndex),
      play: true,
    );

    if (items.isNotEmpty) {
      _currentSongId = items[initialIndex].id;
      mediaItem.add(items[initialIndex]);
      PlaybackHistoryService.incrementPlayCount(_currentSongId!);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    _playlistItems.add(item);
    queue.add(_playlistItems);
    await player.add(Media(item.id));
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index >= 0 && index < _playlistItems.length) {
      _playlistItems.removeAt(index);
      queue.add(_playlistItems);
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
    required String title,
    required String artist,
    required String album,
    required String artUri,
    required Duration duration,
  }) {
    final item = MediaItem(
      id: artUri,
      album: album,
      title: title,
      artist: artist,
      artUri: Uri.parse(artUri),
      duration: duration,
    );
    _currentSongId = item.id;
    mediaItem.add(item);
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
