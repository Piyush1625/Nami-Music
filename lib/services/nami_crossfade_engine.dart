import 'dart:async';
import 'package:media_kit/media_kit.dart';

class NamiDualDeckCrossfade {
  Player? _fadeOutDeck;
  int _transitionToken = 0;

  Player _ensureDeck() {
    _fadeOutDeck ??= Player();
    return _fadeOutDeck!;
  }

  Future<void> transition({
    required Player primaryPlayer,
    required String? outgoingPath,
    required Duration outgoingPos,
    required String incomingPath,
    required int crossfadeSeconds,
    double playbackSpeed = 1.0,
    double playbackPitch = 1.0,
  }) async {
    final token = ++_transitionToken;

    if (crossfadeSeconds <= 0 || outgoingPath == null || outgoingPath.isEmpty) {
      await _stopFadeDeck();
      await primaryPlayer.stop();
      await primaryPlayer.setVolume(100.0);
      await primaryPlayer.open(Media(incomingPath));
      await primaryPlayer.setRate(playbackSpeed);
      await primaryPlayer.setPitch(playbackPitch);
      await primaryPlayer.play();
      return;
    }

    final deck = _ensureDeck();
    try {
      await deck.stop();
      await deck.setVolume(100.0);
      await deck.open(Media(outgoingPath), play: false);
      if (outgoingPos > Duration.zero) {
        await deck.seek(outgoingPos);
      }
      await deck.setRate(playbackSpeed);
      await deck.setPitch(playbackPitch);
      await deck.play();
    } catch (_) {}

    await primaryPlayer.stop();
    await primaryPlayer.setVolume(0.0);
    await primaryPlayer.open(Media(incomingPath));
    await primaryPlayer.setRate(playbackSpeed);
    await primaryPlayer.setPitch(playbackPitch);
    await primaryPlayer.play();

    final steps = (crossfadeSeconds * 10).clamp(6, 40);
    final stepMs = ((crossfadeSeconds * 1000) ~/ steps).clamp(40, 200);
    for (int i = 1; i <= steps; i++) {
      if (token != _transitionToken) return;
      final t = i / steps;
      final inVol = (t * 100.0).clamp(0.0, 100.0);
      final outVol = ((1.0 - t) * 100.0).clamp(0.0, 100.0);
      try {
        await Future.wait([
          primaryPlayer.setVolume(inVol),
          deck.setVolume(outVol),
        ]);
      } catch (_) {}
      await Future.delayed(Duration(milliseconds: stepMs));
    }

    if (token == _transitionToken) {
      await _stopFadeDeck();
      try {
        await primaryPlayer.setVolume(100.0);
      } catch (_) {}
    }
  }

  Future<void> _stopFadeDeck() async {
    try {
      await _fadeOutDeck?.stop();
    } catch (_) {}
  }

  void dispose() {
    _transitionToken++;
    try {
      _fadeOutDeck?.dispose();
    } catch (_) {}
    _fadeOutDeck = null;
  }
}
