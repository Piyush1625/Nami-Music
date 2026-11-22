# Nami Music

**Nami** (`Nami-Music`) is a custom open-source Flutter Android music player built for high-resolution audio playback, clean library organization, and extension-powered music discovery.

---

## Core Features

* **High-Resolution & Lossless Playback (`media_kit` + `audio_service`)**
  * Powered by `media_kit` (`libmpv`) with background audio service, notification/lockscreen media controls, and persistent playback state/queue restoration across sessions
  * Supports lossless and high-resolution formats including **FLAC** (16-Bit / 24-Bit), **ALAC**, **WAV**, **MP3**, **M4A**, and **OGG**, with codec/bit-depth badges and live audio path telemetry
  * Includes a 5-band equalizer with presets, tempo adjustment, soundstage options, and a sleep timer

* **Universal Metadata, Cover Art & Synced Lyrics**
  * Extracts embedded tags and cover art from FLAC Vorbis comments/picture blocks, ID3v2 frames, and MP4/M4A atoms, with folder cover and online metadata/artwork enrichment
  * Supports `.lrc` sidecar files, online synced lyrics lookups, syllable-level sweep highlighting, and an in-app lyrics manager/editor

* **Home, Tracks, Artists & Playlists**
  * **Home:** Personalized greeting, active audio output device badge, **Continue Listening** card, **Jump Back In**, **Heavy Rotation**, **Top Albums**, **Artist Spotlight**, **Freshly Added**, and **Featured Artists**, plus access to the **Listening & Library Statistics** screen from the top-right header
  * **Tracks:** Filter chips (`All`, `FLAC`, `24-Bit`, `Favorites`), fast scrolling, batch selection actions, and quick shuffle/locate controls
  * **Artists:** 3-column grid or list toggle, sorting by name or track count, and an artist detail screen with a hero menu to pick or fetch artist photos
  * **Playlists:** Smart shortcuts, custom playlists, `.m3u8` import/export, and drag-to-reorder track management alongside a reorderable playback queue

* **Mornye Extensions & Catalog**
  * Search tracks, albums, and artists across supported services, preview audio, and download to your music folder
  * Manage extensions in **Mornye Repo** with `.sflx` / ZIP bundle import, URL manifest import, enable/disable toggles, and delete with **Undo**

---

## Direct In-Place APK Updates

To update Nami directly over an existing installation without uninstalling first:

1. Generate and back up a persistent release keystore (`nami-release.jks`) and base64 string (`NAMI_KEYSTORE_B64`).
2. Add `NAMI_KEYSTORE_B64` and `NAMI_KEY_PASS` to your GitHub repository's **Actions secrets** and pass them into your release build workflow.
3. Increment the `+N` build number in `pubspec.yaml` (for example `2.0.0+2` -> `2.0.0+3`) before releasing a new build.

---

## Termux Workflow

1. Save `README.md` to `/storage/emulated/0/Download/README.md`.
2. Run the push commands below in Termux to copy the file into your repo, commit it, and push your branches.
