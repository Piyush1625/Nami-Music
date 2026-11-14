import 'package:flutter/material.dart';
class MainSettingsScreen extends StatelessWidget {
  final bool usbDacExclusive, gaplessPlayback, mediaNotificationEnabled, usePitchBlack, autoColoring, ambientGlow, syllableLyricsEnabled, preferEmbeddedLyrics, autoFetchOnlineMetadata, splitMultiArtists, forceMiniColor, replayGain;
  final List<String> artistSeparators;
  final String connectedDacName;
  final VoidCallback onOpenExtensionRepo, onOpenFolderExplorer, onExportBackup, onImportBackup, onRescan;
  final ValueChanged<bool> onUsbDacChanged, onGaplessChanged, onNotificationChanged, onPitchBlackChanged, onAutoColoringChanged, onAmbientGlowChanged, onSyllableLyricsChanged, onPreferEmbeddedChanged, onAutoFetchOnlineChanged, onSplitArtistsChanged, onForceMiniColorChanged, onReplayGainChanged;
  final ValueChanged<Color> onAccentChanged;
  final ValueChanged<List<String>> onArtistSeparatorsChanged;
  const MainSettingsScreen({super.key, required this.usbDacExclusive, required this.gaplessPlayback, required this.mediaNotificationEnabled, required this.usePitchBlack, required this.autoColoring, required this.ambientGlow, required this.syllableLyricsEnabled, required this.preferEmbeddedLyrics, required this.autoFetchOnlineMetadata, required this.splitMultiArtists, required this.artistSeparators, required this.forceMiniColor, required this.replayGain, required this.connectedDacName, required this.onOpenExtensionRepo, required this.onOpenFolderExplorer, required this.onExportBackup, required this.onImportBackup, required this.onUsbDacChanged, required this.onGaplessChanged, required this.onNotificationChanged, required this.onAccentChanged, required this.onPitchBlackChanged, required this.onAutoColoringChanged, required this.onAmbientGlowChanged, required this.onSyllableLyricsChanged, required this.onPreferEmbeddedChanged, required this.onAutoFetchOnlineChanged, required this.onSplitArtistsChanged, required this.onArtistSeparatorsChanged, required this.onForceMiniColorChanged, required this.onReplayGainChanged, required this.onRescan});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: const SizedBox.shrink());
}
