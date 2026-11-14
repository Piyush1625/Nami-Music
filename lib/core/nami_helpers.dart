import 'dart:typed_data';
import 'package:flutter/material.dart';

String namiFormatDurationPadded(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String namiFormatTotalDurationHoursMins(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

Color namiExtractDominantColor(Uint8List? artworkBytes, Color fallbackAccent) {
  return fallbackAccent;
}
