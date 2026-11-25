# Nami Music

A custom, pitch-black AMOLED audiophile music player for Android built with Flutter and `libmpv` (`media_kit`) — designed for locked 120Hz fluidity, bit-perfect USB DAC output, India-first metadata, and seamless offline + online playback.

## Highlights (`v3.0.3` Stable)

- **120Hz Butter Motion & Zero-Blank Expandable Player:** Permanent in-tree expandable player sheet with 1:1 finger-tracked drag-up/drag-down morphing, critically damped spring curves, single-layer GPU-cached artwork handoff, and persistent Synced Lyrics state across collapses.
- **Swipeable Keep-Alive Shell:** 120Hz horizontal `PageView` across all 5 main tabs (`Home`, `Tracks`, `Artists`, `Playlists`, `YouTube`) with `AutomaticKeepAliveClientMixin` scroll preservation and a persistent nested `Navigator` keeping the Mini-Player and Bottom Navigation Bar pinned across Settings and detail pages.
- **Unified YouTube & Mornye 5th Tab (Option A):** Combines `Home (Local)`, `Music`, `Mornye (Extensions)`, `Channels (Local)`, `Playlists (Local)`, and `Downloads` inside a 6-item morphing pill bar with nested `PageView` boundary handoff and AMOLED shimmer skeletons.
- **Pure-Dart YouTube InnerTube Engine & Loopback Proxy:** Account-free local-first YouTube Music experience featuring India-first `FEmusic_home` feeds, multi-tier verified audio stream resolution bridged over a pure-Dart `127.0.0.1` loopback HTTP proxy to `libmpv`, **SponsorBlock** auto-skip, **Return YouTube Dislike**, **Auto-Start Radio**, and Watch/Queue sheets.
- **Audiophile Core (`libmpv`):** Direct bit-perfect USB DAC support, True Gapless playback, ReplayGain loudness normalization (`Off` / `Track` / `Album`), Equalizer & AutoEQ presets, and interactive Audio Signal Chain inspection.
- **India-First Metadata & Artwork Studio:** Prioritizes JioSaavn IN and Apple Music IN catalogs for accurate Indian artist portraits and album art, includes a bad-placeholder portrait cleaner, artist merge/aliasing, and permanent local FLAC/MP3 tag & cover writing.
- **Tactile Library Gestures:** 1:1 spring-back track row swipes (`Left → Play After` with an in-place mutating bottom pill toast, `Right → Floating Track Info Card`), pull-to-refresh verification with a non-blocking top status banner, and a merged tap-to-shuffle / hold-to-locate FAB.
- **Minimal AMOLED Settings & About:** Zero-filler pitch-black Settings hierarchy with direct `Scan Folders` and `Equalizer & AutoEQ` quick actions, compact inline vertical-bar waveform sliders, instant keyword search, live Library & YouTube Statistics, and an in-app GitHub Releases updater.
- **4×1 AMOLED Home Screen Widget:** Live track title, artist, album artwork, and play/pause/skip transport controls synced directly to your Android launcher.

## Building

Signed ARM64 release APKs are compiled automatically via GitHub Actions on pushes and version tags (`v*`).

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build apk --release --target-platform android-arm64
```

## License

Open-source project maintained by [Piyush1625](https://github.com/Piyush1625/Nami-Music).
