import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

class BlurredArtworkBackground extends StatelessWidget {
  final Uri? artUri;

  const BlurredArtworkBackground({Key? key, required this.artUri}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (artUri == null) {
      return Container(color: Theme.of(context).scaffoldBackgroundColor);
    }

    final isLocal = artUri!.scheme == 'file' || artUri!.toFilePath().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Image
        isLocal
            ? Image.file(File(artUri!.toFilePath()), fit: BoxFit.cover)
            : Image.network(artUri!.toString(), fit: BoxFit.cover),
            
        // Heavy Glassmorphism Blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
          child: Container(
            color: Colors.black.withOpacity(0.5), // Dimming layer for text readability
          ),
        ),
        
        // Subtle dark gradient from the bottom for controls
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ],
    );
  }
}