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
        bands: {'60Hz': 4.5, '230Hz': 1.2, '910Hz': -0.5, '3.6kHz': 3.2, '14kHz': 5.0},
      ),
      AutoEqPreset(
        name: 'Moondrop Blessing 3',
        headphoneModel: 'IEM Reference',
        bands: {'60Hz': 2.0, '230Hz': 0.5, '910Hz': 1.0, '3.6kHz': 4.0, '14kHz': 3.5},
      ),
      AutoEqPreset(
        name: 'Sennheiser HD600',
        headphoneModel: 'Open-Back Audiophile',
        bands: {'60Hz': 3.5, '230Hz': 1.0, '910Hz': 0.0, '3.6kHz': 2.5, '14kHz': 4.0},
      ),
      AutoEqPreset(
        name: 'Audeze LCD-X',
        headphoneModel: 'Planar Magnetic',
        bands: {'60Hz': 1.5, '230Hz': 0.0, '910Hz': 1.5, '3.6kHz': 3.0, '14kHz': 2.0},
      ),
    ];
  }
}
