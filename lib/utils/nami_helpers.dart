import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

const Map<String, String> namiHttpHeaders = {
  'User-Agent': 'NamiMusicPlayer/2.0 (https://github.com/Piyush1625/Nami-Music)',
  'Accept': 'application/json',
};

String namiFormatDurationPadded(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String namiFormatTotalDurationHoursMins(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${math.max(1, minutes)}m';
}

Color namiExtractDominantColor(Uint8List? artworkBytes, Color fallbackAccent) {
  if (artworkBytes == null || artworkBytes.length < 128) return fallbackAccent;
  int r = 0, g = 0, b = 0, count = 0;
  final step = math.max(3, artworkBytes.length ~/ 240);
  for (int i = 64; i + 2 < artworkBytes.length; i += step) {
    final pr = artworkBytes[i];
    final pg = artworkBytes[i + 1];
    final pb = artworkBytes[i + 2];
    final maxC = math.max(pr, math.max(pg, pb));
    final minC = math.min(pr, math.min(pg, pb));
    // Favor vibrant, non-greyscale mid-to-bright tones
    if (maxC - minC > 36 && maxC > 65 && maxC < 245) {
      r += pr;
      g += pg;
      b += pb;
      count++;
    }
  }
  if (count < 8) return fallbackAccent;
  final rawColor = Color.fromARGB(255, (r ~/ count).clamp(40, 240), (g ~/ count).clamp(40, 240), (b ~/ count).clamp(40, 240));
  final hsl = HSLColor.fromColor(rawColor);
  return hsl
      .withSaturation(math.max(0.65, hsl.saturation))
      .withLightness(hsl.lightness.clamp(0.45, 0.65))
      .toColor();
}

bool namiLooksLikeImage(List<int> b) {
  if (b.length < 256) return false;
  final jpeg = b[0] == 0xFF && b[1] == 0xD8;
  final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
  final riff = b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46;
  return jpeg || png || riff;
}

String namiDeterministicPathHash(String input) {
  int hash = 0x811c9dc5;
  for (int i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
