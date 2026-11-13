import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

const Map<String, String> httpHeaders = {
  'User-Agent': 'NamiMusicPlayer/2.0 (https://github.com/Piyush1625/nami)',
  'Accept': 'application/json',
};

String normName(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

bool namesMatchLoosely(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  return shorter.length >= 4 &&
      longer.contains(shorter) &&
      shorter.length / longer.length >= 0.6;
}

bool artistNamesMatch(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  return (a.length >= 3 && b.contains(a)) || (b.length >= 3 && a.contains(b));
}

bool looksLikeImage(Uint8List b) {
  if (b.length < 512) return false;
  final jpeg = b[0] == 0xFF && b[1] == 0xD8;
  final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
  final riff = b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46;
  return jpeg || png || riff;
}

String formatDurationPadded(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatTotalDurationHoursMins(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${math.max(1, minutes)}m';
}

String deterministicPathHash(String input) {
  int hash = 0x811c9dc5;
  for (int i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String colorToHex(Color c) {
  return '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
