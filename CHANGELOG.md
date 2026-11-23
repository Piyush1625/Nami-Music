# Changelog

All notable changes to **Nami Music** are documented in this file.

## [v2.0.0 — Repo & Architecture Overhaul (v17)] - 2026-11
### Infrastructure & Distribution
- Added 45-second `flutter analyze` pre-build CI gate, Pub/Gradle caching, monotonic CI build numbers, and automated GitHub Releases publishing (`nami-arm64-v8a.apk` + `SHA256SUMS.txt`).
- Modularized `lib/main.dart` into `lib/models/nami_models.dart`, `lib/widgets/nami_widgets.dart`, `lib/screens/settings_screen.dart`, `lib/screens/now_playing_screen.dart`, and `lib/services/`.
- Added R8 ProGuard keep-rules (`android/app/proguard-rules.pro`) and permanent native configurator (`scripts/configure_android_native.py`).
- Added visual `README.md` with SVG waveform banner, Obtainium import config, MIT `LICENSE`, GitHub Issue Templates, Mornye `.sflx` spec & starter manifests, Fastlane metadata, and GitHub Pages landing site (`docs/index.html`).

## [v2.0.0 — All-5-Tabs & Settings Overhaul (v16)] - 2026-11
- **Home:** Drag-to-reorder & hide/show shelves, live tappable DAC output & AutoEQ switcher, Time-of-Day & Forgotten Favorites mixes, Weekly Recap strip, and long-press quick action sheets.
- **Tracks:** Full Sort & Order sheet, Library Health filters (`Untagged`, `No Cover`, `Duplicates`), Batch Tag & Cover Editor, dual customizable swipe gestures, and uppercase `24B`/`16B` codec badges.
- **Artists:** Edge-to-edge parallax hero header, chronological album timeline, Top 5 preview, Primary vs. Appears On split, Artist Alias/Merge tool, expandable bio, and Similar Local Artists.
- **Playlists:** Compact horizontal shortcuts rail, Rule-Based Smart Playlist Builder, 2x2 mosaic collage covers, custom covers & descriptions, in-playlist search/sort/dedupe, pins, and auto `.m3u8` sync.
- **Mornye:** Interactive Album & Artist drill-down pages with Download Entire Album, In-Library badges, Extension Store directory + live endpoint latency pings, folder templates, and direct Stream-to-Queue.
- **Settings:** Top search bar, live status dots, Bit-Perfect vs. Tuned presets, Appearance live preview, unified `.nami-backup` archive, per-section resets, and in-app GitHub Releases updater.

## [v2.0.0 — Polish, Permissions & Core Engines (v11–v15)] - 2026-11
- Added 10-band ISO Equalizer with AutoEQ IEM profiles, true Dual-Deck Overlapping Crossfade, permanent FLAC/MP3 in-file tag & cover writer, Mornye queued Download Manager, ListenBrainz scrobbling, reactive folder watchers, and lazy split-table caching.
- Added Full Storage (`MANAGE_EXTERNAL_STORAGE`) and USB DAC (`UsbManager.requestPermission`) permissions, minimal categorized Settings with interactive About Nami changelog, unified Tap/Hold Repeat/Shuffle button, instant artist photo updates, and ghost-track purging.
