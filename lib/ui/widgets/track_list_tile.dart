import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';

class TrackListTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final bool isPlaying;

  const TrackListTile({
    Key?