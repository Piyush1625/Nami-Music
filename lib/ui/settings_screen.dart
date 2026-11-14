import 'package:flutter/material.dart';

class MainSettingsScreen extends StatelessWidget {
  final bool usbDacExclusive;
  final bool gaplessPlayback;
  final bool mediaNotificationEnabled;
  final bool usePitchBlack;
  final bool autoColoring;
  final bool ambientGlow;
  final bool syllableLyricsEnabled;
  final bool preferEmbeddedLyrics;
  final bool autoFetchOnlineMetadata;
  final bool splitMultiArtists;
  final List<String> artistSeparators;
  final bool forceMiniColor;
  final bool replayGain;
  final String connectedDacName;
  final VoidCallback onOpenExtensionRepo;
  final VoidCallback onOpenFolderExplorer;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final ValueChanged<bool> onUsbDacChanged;
  final ValueChanged<bool> onGaplessChanged;
  final ValueChanged<bool> onNotificationChanged;
  final ValueChanged<Color> onAccentChanged;
  final ValueChanged<bool> onPitchBlackChanged;
  final ValueChanged<bool> onAutoColoringChanged;
  final ValueChanged<bool> onAmbientGlowChanged;
  final ValueChanged<bool> onSyllableLyricsChanged;
  final ValueChanged<bool> onPreferEmbeddedChanged;
  final ValueChanged<bool> onAutoFetchOnlineChanged;
  final ValueChanged<bool> onSplitArtistsChanged;
  final ValueChanged<List<String>> onArtistSeparatorsChanged;
  final ValueChanged<bool> onForceMiniColorChanged;
  final ValueChanged<bool> onReplayGainChanged;
  final VoidCallback onRescan;

  const MainSettingsScreen({
    super.key,
    required this.usbDacExclusive,
    required this.gaplessPlayback,
    required this.mediaNotificationEnabled,
    required this.usePitchBlack,
    required this.autoColoring,
    required this.ambientGlow,
    required this.syllableLyricsEnabled,
    required this.preferEmbeddedLyrics,
    required this.autoFetchOnlineMetadata,
    required this.splitMultiArtists,
    required this.artistSeparators,
    required this.forceMiniColor,
    required this.replayGain,
    required this.connectedDacName,
    required this.onOpenExtensionRepo,
    required this.onOpenFolderExplorer,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onUsbDacChanged,
    required this.onGaplessChanged,
    required this.onNotificationChanged,
    required this.onAccentChanged,
    required this.onPitchBlackChanged,
    required this.onAutoColoringChanged,
    required this.onAmbientGlowChanged,
    required this.onSyllableLyricsChanged,
    required this.onPreferEmbeddedChanged,
    required this.onAutoFetchOnlineChanged,
    required this.onSplitArtistsChanged,
    required this.onArtistSeparatorsChanged,
    required this.onForceMiniColorChanged,
    required this.onReplayGainChanged,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.usb_rounded),
            title: const Text('Connected DAC'),
            subtitle: Text(connectedDacName),
          ),
          SwitchListTile(
            title: const Text('USB DAC Exclusive Mode'),
            value: usbDacExclusive,
            onChanged: onUsbDacChanged,
          ),
          SwitchListTile(
            title: const Text('Gapless Playback'),
            value: gaplessPlayback,
            onChanged: onGaplessChanged,
          ),
          SwitchListTile(
            title: const Text('Pitch Black AMOLED Theme'),
            value: usePitchBlack,
            onChanged: onPitchBlackChanged,
          ),
          SwitchListTile(
            title: const Text('Dynamic Cover Coloring'),
            value: autoColoring,
            onChanged: onAutoColoringChanged,
          ),
          SwitchListTile(
            title: const Text('Ambient Glow in Now Playing'),
            value: ambientGlow,
            onChanged: onAmbientGlowChanged,
          ),
          SwitchListTile(
            title: const Text('Syllable Karaoke Lyrics'),
            value: syllableLyricsEnabled,
            onChanged: onSyllableLyricsChanged,
          ),
          SwitchListTile(
            title: const Text('Auto-Fetch Online Metadata'),
            value: autoFetchOnlineMetadata,
            onChanged: onAutoFetchOnlineChanged,
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Rescan Music Library'),
            onTap: () {
              Navigator.pop(context);
              onRescan();
            },
          ),
          ListTile(
            leading: const Icon(Icons.extension_rounded),
            title: const Text('Mornye Extensions'),
            onTap: () {
              Navigator.pop(context);
              onOpenExtensionRepo();
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Text('Export Backup'),
            onTap: onExportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Import Backup'),
            onTap: onImportBackup,
          ),
        ],
      ),
    );
  }
}
