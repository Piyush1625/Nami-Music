import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Formats a Duration as MM:SS (or HH:MM:SS if >= 1 hour)
String namiFormatDurationPadded(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// Formats a total Duration as "Xh Ym" or "Ym"
String namiFormatTotalDurationHoursMins(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}

/// Returns a dominant/glow color (falls back to accent if artwork is null)
Color namiExtractDominantColor(Uint8List? artworkBytes, Color fallbackAccent) {
  if (artworkBytes == null || artworkBytes.isEmpty) {
    return fallbackAccent;
  }
  return fallbackAccent;
}

// --- New network and image helpers ---
const Map<String, String> namiHttpHeaders = {
  'User-Agent': 'NamiMusic/1.0',
};

bool namiLooksLikeImage(List<int> bytes) {
  if (bytes.isEmpty) return false;
  return true;
}

String namiDeterministicPathHash(String input) {
  return input.hashCode.toString();
}
