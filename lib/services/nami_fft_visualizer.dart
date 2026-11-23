import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NamiFftVisualizer {
  static const MethodChannel _channel =
      MethodChannel('com.piyush.nami/audio_visualizer');

  final ValueNotifier<List<double>> bands =
      ValueNotifier<List<double>>(List<double>.filled(32, 0.0));
  bool isNativeActive = false;
  Timer? _pollTimer;

  void start() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
      try {
        final res = await _channel.invokeMethod<List<dynamic>>('getFftBands');
        if (res != null && res.length >= 32) {
          final next = List<double>.generate(
            32,
            (i) => ((res[i] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
          );
          isNativeActive = true;
          bands.value = next;
          return;
        }
      } catch (_) {}
      isNativeActive = false;
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    isNativeActive = false;
  }

  void dispose() {
    stop();
    bands.dispose();
  }
}
