# Changelog

## v3.0.3 (Stable) — 2026-11-26

### New & Refined
- **Settings Consolidation & Zero-Redundancy Polish:** Separated `Equalizer & AutoEQ` (with quick Sleep Timer sheet & USB DAC request) from `Playback & DAC`, eliminated non-functional/redundant toggles, and unified Backup, ListenBrainz, Widget Sync, and Cache controls into a clean 7-category AMOLED hierarchy.
- **Zero-Blank 120Hz Expandable Morph:** Synchronized curved progress across flying artwork and Now Playing's cover anchor with an overlapping `[0.94..0.996]` crossfade and a clipped mini-bar interior on `[0.0..0.28]`, eliminating blank cover flashes and empty mini-player boxes.
- **Pure-Dart YouTube Localhost Streaming Proxy (`NamiYtLocalProxy`):** Streams verified Dart `HttpClient` chunks over `127.0.0.1` loopback HTTP directly into `libmpv` with Range seeking, 6-tier failover (`ANDROID_VR` / `ANDROID_VR_M4A` / `IOS_HLS` / `IOS` / `TVHTML5_EMBED` / `Invidious` / `Piped`), and automatic 3.8s stall recovery.
- **Clean Format Badges Everywhere:** Added `namiFormatBadgeForPath()` across every mini-player, Now Playing bar, Signal Chain sheet, and Track Info card so HTTP/YouTube streams show crisp `YT OPUS` / `YT M4A` / `YT HLS` badges.
- **Repo Audit & Identity Cleanup:** Removed dead legacy settings screens, unused transition wrappers, and third-party brand references across the codebase.

## v3.0.0 — 2026-11-25
- Added unified Option A 5th Tab sharing YouTube Music (`Home Local`, `Music`, `Channels Local`, `Playlists Local`, `Downloads`) and `Mornye` extensions inside a 6-item morphing pill bar.
- Built pure-Dart YouTube InnerTube engine, SponsorBlock auto-skip, Return YouTube Dislike, and account-free on-device YouTube persistence.
- Redesigned Settings & About page with live library/YouTube statistics and inline vertical-bar waveform sliders.

## v2.9.8 — 2026-11-24
- Added 1:1 spring-back track row swipe actions (`Play After` & `Track Info`), in-place mutating bottom pill toast, pull-to-refresh summary banner, and optional 120Hz GPU blur budget.

## v2.9.0 – v2.9.6 — 2026-11-23
- Replaced `PageRoute` player morphing with a permanent in-tree `NamiExpandablePlayerHost` (preserving Synced Lyrics state across collapses).
- Migrated main tabs to a keep-alive swipeable 120Hz `PageView` and mounted a shell-scoped nested `Navigator` keeping the Mini-Player and Bottom Nav pinned across Settings and detail screens.
