import 'package:flutter/material.dart';
import 'package:nami/services/lyrics_service.dart';

class LyricsView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final Duration currentPosition;
  final Function(Duration) onSeek;

  const LyricsView({
    Key? key,
    required this.lyrics,
    required this.currentPosition,
    required this.onSeek,
  }) : super(key: key);

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeIndex = LyricsService.getActiveLineIndex(widget.lyrics, widget.currentPosition);
    if (activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          activeIndex * 52.0, // Apple Music style line offset
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return const Center(
        child: Text(
          "No synchronized lyrics available",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    final activeIndex = LyricsService.getActiveLineIndex(widget.lyrics, widget.currentPosition);

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.lyrics.length,
      padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
      itemBuilder: (context, index) {
        final isActive = index == activeIndex;
        return GestureDetector(
          onTap: () => widget.onSeek(widget.lyrics[index].timestamp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              widget.lyrics[index].text,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                fontSize: isActive ? 22 : 18,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
