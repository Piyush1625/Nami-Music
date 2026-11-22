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
  * Manage extensions in **Mornye Repo** with `.sflx` / ZIP bundle import, URL manifest import, enable/disable toggles
