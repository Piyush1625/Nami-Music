import 'package:flutter/material.dart';

class NamiCustomIcons {
  static const String home = 'assets/icons/nami/png/01_home.png';
  static const String tracks = 'assets/icons/nami/png/02_music_note.png';
  static const String artist = 'assets/icons/nami/png/03_microphone.png';
  static const String albumDisc = 'assets/icons/nami/png/04_vinyl_disc.png';
  static const String play = 'assets/icons/nami/png/05_play_circle.png';
  static const String pause = 'assets/icons/nami/png/06_pause.png';
  static const String settings = 'assets/icons/nami/png/07_settings.png';
  static const String nextTrack = 'assets/icons/nami/png/08_next_track.png';
  static const String shuffle = 'assets/icons/nami/png/09_shuffle.png';
  static const String lyrics = 'assets/icons/nami/png/10_chat_lyrics.png';
  static const String playlist = 'assets/icons/nami/png/11_playlist.png';
  static const String equalizer = 'assets/icons/nami/png/12_equalizer.png';
  static const String headphones = 'assets/icons/nami/png/13_headphones.png';
  static const String search = 'assets/icons/nami/png/14_search.png';
}

class NamiCustomIcon extends StatelessWidget {
  final String asset;
  final double size;
  final bool flipHorizontal;
  final double opacity;
  final Color? tintColor;
  final Color? color;

  const NamiCustomIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.flipHorizontal = false,
    this.opacity = 1.0,
    this.tintColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      color: tintColor,
      colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
    );
    if (flipHorizontal) {
      img = Transform.flip(
        flipX: true,
        child: img,
      );
    }
    if (opacity < 0.999) {
      img = Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: img,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: img),
    );
  }
}
