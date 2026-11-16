import 'package:media_kit/media_kit.dart';

class AutoEqPreset {
  final String name;
  final String headphoneModel;
  final Map<String, double> bands;

  AutoEqPreset({
    required this.name,
    required this.headphoneModel,
    required this.bands,
  });

  static List<AutoEqPreset> getPresets() {
    return [
      AutoEqPreset(
        name: 'Harman Target 2019v2',
        headphoneModel: 'Universal Reference',
        bands: {'60HZ': 4.5, '230HZ': 1.2, '910HZ': -0.5, '3.6KHZ': 3.2, '14KHZ': 5.0},
      ),
      AutoEqPreset(
        name: 'Moondrop Blessing 3',
        headphoneModel: 'IEM Reference',
        bands: {'60HZ': 2.0, '230HZ': 0.5, '910HZ': 1.0, '3.6KHZ': 4.0, '14KHZ': 3.5},
      ),
      AutoEqPreset(
        name: 'Sennheiser HD600',
        headphoneModel: 'Open-Back Audiophile',
        bands: {'60HZ': 3.5, '230HZ': 1.0, '910HZ': 0.0, '3.6KHZ': 2.5, '14KHZ': 4.0},
      ),
      AutoEqPreset(
        name: 'Audeze LCD-X',
        headphoneModel: 'Planar Magnetic',
        bands: {'60HZ': 1.5, '230HZ': 0.0, '910HZ': 1.5, '3.6KHZ': 3.0, '14KHZ': 2.0},
      ),
    ];
  }

  // Apply AutoEq bands to media_kit mpv audio filters (--af)
  static Future<void> applyPreset(Player player, AutoEqPreset preset) async {
    // Map band frequencies
    final freqMap = {
      '60HZ': 60,
      '230HZ': 230,
      '910HZ': 910,
      '3.6KHZ': 3600,
      '14KHZ': 14000,
    };

    List<String> filters = [];
    preset.bands.forEach((key, gain) {
      if (freqMap.containsKey(key)) {
        final hz = freqMap[key];
        // Using mpv lavfi equalizer filter syntax
        filters.add("equalizer=f=$hz:width_type=h:width=100:g=$gain");
      }
    });

    if (filters.isNotEmpty) {
      final filterString = filters.join(',');
      await player.setProperty('af', filterString);
    } else {
      await player.setProperty('af', '');
    }
  }

  // Clear equalizer filters
  static Future<void> clear(Player player) async {
    await player.setProperty('af', '');
  }
}
