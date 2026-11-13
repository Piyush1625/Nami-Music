class MornyeExtension {
  final String name;
  final String version;
  final String author;
  final String format;
  final String category;
  final String description;
  final String? endpointUrl;
  bool isInstalled;
  bool isEnabled;

  MornyeExtension({
    required this.name,
    required this.version,
    required this.author,
    required this.format,
    this.category = 'Metadata',
    this.description = '',
    this.endpointUrl,
    this.isInstalled = true,
    this.isEnabled = true,
  });
}

class MornyeCatalogItem {
  final String title;
  final String artist;
  final String album;
  final String subtitle;
  final String type;
  final String service;
  final String? previewUrl;
  final String? artworkUrl;
  final int durationSeconds;
  final String? collectionId;

  MornyeCatalogItem({
    required this.title,
    required this.artist,
    required this.album,
    required this.subtitle,
    required this.type,
    required this.service,
    this.previewUrl,
    this.artworkUrl,
    this.durationSeconds = 210,
    this.collectionId,
  });
}
