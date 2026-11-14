import 'package:flutter/material.dart';

class MainSettingsScreen extends StatefulWidget {
  final bool usbDacExclusive,
      gaplessPlayback,
      mediaNotificationEnabled,
      usePitchBlack,
      autoColoring,
      ambientGlow,
      syllableLyricsEnabled,
      preferEmbeddedLyrics,
      autoFetchOnlineMetadata,
      splitMultiArtists,
      forceMiniColor,
      replayGain;
  final List<String> artistSeparators;
  final String connectedDacName;
  final VoidCallback onOpenExtensionRepo,
      onOpenFolderExplorer,
      onExportBackup,
      onImportBackup,
      onRescan;
  final ValueChanged<bool> onUsbDacChanged,
      onGaplessChanged,
      onNotificationChanged,
      onPitchBlackChanged,
      onAutoColoringChanged,
      onAmbientGlowChanged,
      onSyllableLyricsChanged,
      onPreferEmbeddedChanged,
      onAutoFetchOnlineChanged,
      onSplitArtistsChanged,
      onForceMiniColorChanged,
      onReplayGainChanged;
  final ValueChanged<Color> onAccentChanged;
  final ValueChanged<List<String>> onArtistSeparatorsChanged;

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
  State<MainSettingsScreen> createState() => _MainSettingsScreenState();
}

class _MainSettingsScreenState extends State<MainSettingsScreen> {
  late bool _usbDac;
  late bool _gapless;
  late bool _notif;
  late bool _pitchBlack;
  late bool _autoColor;
  late bool _ambientGlow;
  late bool _syllableLyrics;
  late bool _preferEmbedded;
  late bool _autoFetchOnline;
  late bool _splitArtists;
  late bool _forceMiniColor;
  late bool _replayGain;

  static const List<Color> _accentSwatches = [
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF00ACC1),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFFFB8C00),
  ];

  @override
  void initState() {
    super.initState();
    _usbDac = widget.usbDacExclusive;
    _gapless = widget.gaplessPlayback;
    _notif = widget.mediaNotificationEnabled;
    _pitchBlack = widget.usePitchBlack;
    _autoColor = widget.autoColoring;
    _ambientGlow = widget.ambientGlow;
    _syllableLyrics = widget.syllableLyricsEnabled;
    _preferEmbedded = widget.preferEmbeddedLyrics;
    _autoFetchOnline = widget.autoFetchOnlineMetadata;
    _splitArtists = widget.splitMultiArtists;
    _forceMiniColor = widget.forceMiniColor;
    _replayGain = widget.replayGain;
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nami Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _sectionTitle('Audio & Hardware DAC'),
          SwitchListTile(
            secondary: const Icon(Icons.usb_rounded),
            title: Text('USB DAC Bit-Perfect (${widget.connectedDacName})'),
            subtitle: const Text('Bypass Android mixer when external DAC is active'),
            value: _usbDac,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _usbDac = v);
              widget.onUsbDacChanged(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq_rounded),
            title: const Text('Gapless Playback'),
            subtitle: const Text('Pre-buffer transitions between consecutive tracks'),
            value: _gapless,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _gapless = v);
              widget.onGaplessChanged(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_rounded),
            title: const Text('ReplayGain Normalization'),
            subtitle: const Text('Match loudness across heterogeneous FLAC albums'),
            value: _replayGain,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _replayGain = v);
              widget.onReplayGainChanged(v);
            },
          ),
          _sectionTitle('Appearance & Namida UI'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _accentSwatches.map((color) {
                final isSelected = accent.value == color.value;
                return GestureDetector(
                  onTap: () {
                    widget.onAccentChanged(color);
                    setState(() {});
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded),
            title: const Text('AMOLED Pitch Black'),
            subtitle: const Text('True #000000 backgrounds for OLED displays'),
            value: _pitchBlack,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _pitchBlack = v);
              widget.onPitchBlackChanged(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette_rounded),
            title: const Text('Dynamic Cover Coloring'),
            subtitle: const Text('Extract dominant accent color from active artwork'),
            value: _autoColor,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _autoColor = v);
              widget.onAutoColoringChanged(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.blur_on_rounded),
            title: const Text('Now Playing Ambient Mesh Glow'),
            subtitle: const Text('Multi-point radial artwork glow behind player'),
            value: _ambientGlow,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _ambientGlow = v);
              widget.onAmbientGlowChanged(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.branding_watermark_rounded),
            title: const Text('Tint Mini-Player Bar'),
            subtitle: const Text('Apply active track accent tint to mini-player'),
            value: _forceMiniColor,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _forceMiniColor = v);
              widget.onForceMiniColorChanged(v);
            },
          ),
          _sectionTitle('Lyrics & Metadata'),
          SwitchListTile(
            secondary: const Icon(Icons.lyrics_rounded),
            title: const Text('Syllable Sweep Highlight'),
            subtitle: const Text('Smooth karaoke gradient sweep on active lyric line'),
            value: _syllableLyrics,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _syllableLyrics = v);
              widget.onSyllableLyricsChanged(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_download_rounded),
            title: const Text('Auto-Enrich Missing Covers & Tags'),
            subtitle: const Text('Fetch high-res artwork and artist photos in background'),
            value: _autoFetchOnline,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _autoFetchOnline = v);
              widget.onAutoFetchOnlineChanged(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.people_alt_rounded),
            title: const Text('Split Collaborating Artists'),
            subtitle: Text('Separators: ${widget.artistSeparators.join(" ")}'),
            value: _splitArtists,
            activeColor: accent,
            onChanged: (v) {
              setState(() => _splitArtists = v);
              widget.onSplitArtistsChanged(v);
            },
          ),
          _sectionTitle('Library, Mornye & Backup'),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Rescan Storage & Rebuild Tags'),
            subtitle: const Text('Scan /Music and /Download for FLAC, MP3, M4A, WAV'),
            onTap: () {
              Navigator.pop(context);
              widget.onRescan();
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Direct Folder Explorer'),
            subtitle: const Text('Browse device storage folders directly'),
            onTap: () {
              Navigator.pop(context);
              widget.onOpenFolderExplorer();
            },
          ),
          ListTile(
            leading: const Icon(Icons.extension_rounded),
            title: const Text('Mornye Extension Repository (.sflx)'),
            subtitle: const Text('Manage installed providers & import .sflx manifests'),
            onTap: widget.onOpenExtensionRepo,
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Text('Export Library & Playlists Backup'),
            subtitle: const Text('Save to /Download/nami_backup.json'),
            onTap: widget.onExportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download_done_rounded),
            title: const Text('Restore Backup'),
            subtitle: const Text('Import from /Download/nami_backup.json'),
            onTap: widget.onImportBackup,
          ),
        ],
      ),
    );
  }
}
