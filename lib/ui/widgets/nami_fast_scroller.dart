import 'package:flutter/material.dart';

class NamiFastScroller extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final int? itemCount;
  final String Function(int)? labelBuilder;

  const NamiFastScroller({
    super.key,
    required this.child,
    this.controller,
    this.itemCount,
    this.labelBuilder,
  });

  @override
  State<NamiFastScroller> createState() => _NamiFastScrollerState();
}

class _NamiFastScrollerState extends State<NamiFastScroller> {
  bool _isDragging = false;
  double _dragRatio = 0.0;

  void _updateScrollPosition(double localDy, double maxHeight) {
    final ctrl = widget.controller;
    if (ctrl == null || !ctrl.hasClients) return;
    final ratio = (localDy / maxHeight).clamp(0.0, 1.0);
    setState(() {
      _isDragging = true;
      _dragRatio = ratio;
    });
    final target = ratio * ctrl.position.maxScrollExtent;
    ctrl.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount ?? 0;
    if (count < 8 || widget.controller == null) return widget.child;

    final accent = Theme.of(context).colorScheme.primary;
    final currentIdx = (_dragRatio * (count - 1)).round().clamp(0, count - 1);
    final bubbleText = widget.labelBuilder != null
        ? widget.labelBuilder!(currentIdx)
        : '${currentIdx + 1}/$count';

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight - 36.0;
        final thumbTop = 12.0 + (_dragRatio * (trackHeight - 40.0)).clamp(0.0, trackHeight - 40.0);

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (!_isDragging &&
                    widget.controller != null &&
                    widget.controller!.hasClients &&
                    widget.controller!.position.maxScrollExtent > 0) {
                  final r = (widget.controller!.offset /
                          widget.controller!.position.maxScrollExtent)
                      .clamp(0.0, 1.0);
                  if ((r - _dragRatio).abs() > 0.01) {
                    setState(() => _dragRatio = r);
                  }
                }
                return false;
              },
              child: widget.child,
            ),
            if (_isDragging)
              Positioned(
                right: 36,
                top: (thumbTop - 8).clamp(8.0, constraints.maxHeight - 56.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    bubbleText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              top: 12,
              bottom: 24,
              width: 26,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (d) =>
                    _updateScrollPosition(d.localPosition.dy, trackHeight),
                onVerticalDragUpdate: (d) =>
                    _updateScrollPosition(d.localPosition.dy, trackHeight),
                onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                onVerticalDragCancel: () => setState(() => _isDragging = false),
                child: Stack(
                  children: [
                    Positioned(
                      right: 5,
                      top: (_dragRatio * (trackHeight - 36.0)).clamp(0.0, trackHeight - 36.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        width: _isDragging ? 8 : 5,
                        height: _isDragging ? 42 : 34,
                        decoration: BoxDecoration(
                          color: _isDragging ? accent : Colors.white38,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
