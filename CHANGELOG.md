# Changelog

## v3.3.0 — 2026-11-26

### Full YouTube Audio/Video Experience, Comments & Channel Detail
- **Native Hardware Video / Audio Watch Screen (`NamiYoutubeWatchScreen` + `NamiYtVideoPlatformView.kt`):** Sticky 16:9 viewport with 1-tap **Audio Only ↔ Video (`144p`–`2160p`)** switching, quality picker showing bitrates & estimated file sizes, fullscreen landscape mode, live scrub bar, and seamless background audio via `libmpv`.
- **Fast Parallel Stream Resolution (`resolveMediaBundle`):** Parallel InnerTube race + sticky winning-client cache cuts startup latency dramatically while extracting both audiophile audio and all video resolutions in one pass.
- **Real 2026 YouTube Comments & Replies (`fetchVideoComments`):** Dual ViewModel mutations + legacy parser with **Top / Newest** sorting, pagination, like counts, and expandable inline reply threads right below the sticky video player.
- **Full YouTube Action Bar & Queue Drawer:** Like, Dislike (RYD), Share, Refresh, Download (live % progress), Save / Add to Library & Playlists, plus a persistent bottom Queue bar (`1/N • Next: ...`) expanding into an interactive Shuffle/Clear/Jump queue drawer.
- **Full YouTube Channel Detail Screen (`NamiYoutubeChannelScreen`):** Collapsible channel banner, avatar, subscriber count, Subscribe toggle, and 5 interactive tabs (**Home | Videos | Shorts | Releases | Playlists**) with sorting & 1-tap playback.

## v3.2.0 — 2026-11-26

### Pure-YouTube BotGuard & Instant Streaming Engine
- **100% Pure-YouTube Playback (Removed JioSaavn Fallback):** Every YouTube play and offline download streams genuine `googlevideo.com` audio (supports all songs, remixes, live sets, covers & podcasts).
- **Native Android Headless Chromium BotGuard Extractor (`NamiYtWebViewEngine.kt`):** Pre-warmed invisible `1x1` Chromium WebView runs real BotGuard JS on-device to mint PoTokens and extract genuine audio streams — working **both Logged-Out (anonymous) and Signed-In**.
- **1-Tap In-App YouTube Sign-In & Logged-Out Switcher:** Switch seamlessly between anonymous Logged-Out BotGuard mode and your YouTube account from the YouTube tab or **Settings → YouTube & Mornye** (shared Android `CookieManager` + `SAPISIDHASH`).
- **Instant-Start Progressive Chunk-Cached Server (`NamiYtProgressiveProxy`):** Verifies Chunk 0 (`512 KB`, ~150ms) and starts `libmpv` immediately over local `127.0.0.1` HTTP while 4 parallel workers finish caching the track to disk with instant scrubbing and 0ms replay.

## v3.1.0 — 2026-11-26

### Flagship Upgrades
- **Chunked Local Audio Cache YouTube Engine (`NamiYtAudioCache`):** Downloads YouTube audio in 4-way parallel 512KB bounded DASH chunks (`&range=start-end`) with audio magic-byte validation (`ftyp` / `EBML` / `OggS`) across an 8-tier late-2026 client matrix (`ANDROID_VR` Opus/M4A, `VISIONOS`, `IOS`, `ANDROID_CREATOR`, `TVHTML5_EMBED`, `Invidious`, `Piped`), handing `libmpv` a real local file path (0 HTTP errors, instant seeking, 0ms offline replay).
- **YouTube Offline Downloads (`NamiYtDownloadManager`):** Full live `All | Ongoing | Finished` Downloads tab with animated progress bars, Cancel/Retry, Watch Sheet `Download` action, and persistent offline playback.
- **Unified Local FLAC + YouTube Mixed Queue:** Queue YouTube tracks right behind local FLACs (`Play Next` → `yt://` placeholders) with automatic 15-second background pre-fetching for gapless transitions.
- **Interactive Listening Statistics Charts (`NamiStatsChartsScreen`):** 7-Day Activity bar chart, Audiophile Format Breakdown stacked bar, Top Artists & Top Albums reachable from **Settings → About Nami → Statistics & Charts**.
- **Lyrics Collapse Morph Polish:** Suppresses full-size cover art during collapse from Synced Lyrics mode so lyrics glide down cleanly with zero cover flash.
- **True Lossless / FLAC Integrity Inspector (`NamiLosslessInspector`):** Pure-Dart binary `STREAMINFO` / WAV PCM header inspector inside the floating **Track Info** card flagging genuine Hi-Res/CD lossless vs possible MP3-to-FLAC upscales.
- **Android 15/16 16 KiB Packaging & USB Audio Diagnostics:** Enables `extractNativeLibs=false`, `useLegacyPackaging=false`, `usesCleartextTraffic=true`, and adds an Audio Engine / UAC2 Diagnostics sheet inside **Settings → Playback & DAC**.

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
