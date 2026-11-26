part of '../main.dart';

/// Persistent UX, Motion, Metadata & Sleep Timer preferences for Nami v2.6.0+
class NamiUxPrefs {
  static bool _loaded = false;

  static bool indiaFirstMetadata = true;
  static bool hapticsEnabled = true;
  static bool breathingCoverArt = true;
  static bool lyricsBlurDepth = true;
  static bool doubleTapArtLyrics = true;
  static bool swipeDownDismiss = true;
  static String motionSpeed = 'balanced'; // 'snappy' | 'balanced' | 'silky'
  static bool gaplessPlayback = true;
  static String replayGainMode = 'track'; // 'no' | 'track' | 'album'
  static bool persistSession = true;
  static bool enableBlurEffect = false;
  static bool trackRowSwipeActions = true;
  static bool enableGlowEffect = true;
  static int fadeDurationMs = 250;
  static int seekDurationSec = 5;
  static int waveformBarsCount = 48;
  static String youtubeRegion = 'IN';
  static String youtubeAudioQuality = 'High (Opus)';
  static bool youtubeLocalOnly = true;
  static bool ytSponsorBlock = true;
  static bool ytReturnDislike = true;
  static bool ytAutoStartRadio = true;
  static bool ytPersonalizedFeeds = true;
  static bool ytSearchCleanup = true;
  static String ytDefaultMode = 'Video 480p'; // Default 480p video quality!
  static String ytDataSaver = 'Off'; // 'Off' | 'Medium' | 'High'
  static double ytPlaybackSpeed = 1.0;
  static bool ytLoopEnabled = false;
  static bool ytMiniPlayerVideo = true;
  static bool ytVideoGestures = true;
  static bool ytBackgroundVideoPause = true;
  static bool ytAutoRotateFullscreen = true;
  static String ytPreferredCodec = 'H.264 MP4'; // 'H.264 MP4' | 'Auto Best'
  static int ytMaxCacheMb = 512;
  static bool ytDownloadMetadataTags = true;
  static int ytDimMiniAfterSec = 15;
  static int ytDimIntensityPct = 50;
  static String themeModePref = 'dark';
  static bool autoColoring = false;
  static bool usePitchBlack = true;
  static bool refreshOnStartup = false;
  static bool extractFeatArtists = true;
  static bool respectNomedia = true;
  static bool preventDuplicateTracks = true;
  static int minTrackDurationSec = 5;
  static int minFileSizeKb = 100;
  static bool skipSilence = false;
  static bool enableFadeEffect = false;
  static int pauseFadeDurationMs = 300;
  static bool infinityQueue = true;
  static bool immersiveMode = false;
  static String performanceMode = '120Hz High';
  static int imageCacheLimitMb = 256;
  static int audioCacheLimitGb = 4;

  static final ValueNotifier<Duration?> sleepRemaining = ValueNotifier<Duration?>(null);
  static Timer? _sleepTicker;

  static double get motionScale {
    switch (motionSpeed) {
      case 'snappy':
        return 0.72;
      case 'silky':
        return 1.28;
      default:
        return 1.0;
    }
  }

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      indiaFirstMetadata = prefs.getBool('nami_v26_india_first') ?? true;
      hapticsEnabled = prefs.getBool('nami_v26_haptics') ?? true;
      breathingCoverArt = prefs.getBool('nami_v26_breathe_art') ?? true;
      lyricsBlurDepth = prefs.getBool('nami_v26_lyrics_blur') ?? true;
      doubleTapArtLyrics = prefs.getBool('nami_v26_double_tap_art') ?? true;
      swipeDownDismiss = prefs.getBool('nami_v26_swipe_dismiss') ?? true;
      motionSpeed = prefs.getString('nami_v26_motion_speed') ?? 'balanced';
      gaplessPlayback = prefs.getBool('nami_v27_gapless') ?? true;
      replayGainMode = prefs.getString('nami_v27_replaygain') ?? 'track';
      persistSession = prefs.getBool('nami_v27_persist_session') ?? true;
      enableBlurEffect = prefs.getBool('nami_v29_blur') ?? false;
      trackRowSwipeActions = prefs.getBool('nami_v29_8_row_swipe') ?? true;
      enableGlowEffect = prefs.getBool('nami_v29_glow') ?? true;
      fadeDurationMs = prefs.getInt('nami_v29_fade_ms') ?? 250;
      seekDurationSec = prefs.getInt('nami_v29_seek_sec') ?? 5;
      waveformBarsCount = prefs.getInt('nami_v29_wf_bars') ?? 48;
      youtubeRegion = prefs.getString('nami_v29_yt_region') ?? 'IN';
      youtubeAudioQuality = prefs.getString('nami_v29_yt_quality') ?? 'High (Opus)';
      youtubeLocalOnly = prefs.getBool('nami_v29_yt_local') ?? true;
      ytSponsorBlock = prefs.getBool('nami_v30_yt_sb') ?? true;
      ytReturnDislike = prefs.getBool('nami_v30_yt_ryd') ?? true;
      ytAutoStartRadio = prefs.getBool('nami_v30_yt_radio') ?? true;
      ytPersonalizedFeeds = prefs.getBool('nami_v30_yt_pers') ?? true;
      ytSearchCleanup = prefs.getBool('nami_v30_yt_clean') ?? true;
      ytDownloadMetadataTags = prefs.getBool('nami_v30_yt_dl_tags') ?? true;
      ytDimMiniAfterSec = prefs.getInt('nami_v30_yt_dim_sec') ?? 15;
      ytDimIntensityPct = prefs.getInt('nami_v30_yt_dim_pct') ?? 50;
      themeModePref = prefs.getString('nami_v30_theme_mode') ?? 'dark';
      autoColoring = prefs.getBool('nami_v30_auto_color') ?? false;
      usePitchBlack = prefs.getBool('nami_v30_pitch_black') ?? true;
      refreshOnStartup = prefs.getBool('nami_v30_refresh_start') ?? false;
      extractFeatArtists = prefs.getBool('nami_v30_extract_feat') ?? true;
      respectNomedia = prefs.getBool('nami_v30_nomedia') ?? true;
      preventDuplicateTracks = prefs.getBool('nami_v30_no_dups') ?? true;
      minTrackDurationSec = prefs.getInt('nami_v30_min_dur') ?? 5;
      minFileSizeKb = prefs.getInt('nami_v30_min_kb') ?? 100;
      skipSilence = prefs.getBool('nami_v30_skip_sil') ?? false;
      enableFadeEffect = prefs.getBool('nami_v30_fade_on') ?? false;
      pauseFadeDurationMs = prefs.getInt('nami_v30_pause_fade') ?? 300;
      infinityQueue = prefs.getBool('nami_v30_inf_queue') ?? true;
      immersiveMode = prefs.getBool('nami_v30_immersive') ?? false;
      performanceMode = prefs.getString('nami_v30_perf_mode') ?? '120Hz High';
      imageCacheLimitMb = prefs.getInt('nami_v30_img_cache_mb') ?? 256;
      audioCacheLimitGb = prefs.getInt('nami_v30_aud_cache_gb') ?? 4;
      NamiArtistMetadataService.indiaFirst = indiaFirstMetadata;
    } catch (_) {}
  }

  static Future<void> save() async {
    NamiArtistMetadataService.indiaFirst = indiaFirstMetadata;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('nami_v26_india_first', indiaFirstMetadata);
      await prefs.setBool('nami_v26_haptics', hapticsEnabled);
      await prefs.setBool('nami_v26_breathe_art', breathingCoverArt);
      await prefs.setBool('nami_v26_lyrics_blur', lyricsBlurDepth);
      await prefs.setBool('nami_v26_double_tap_art', doubleTapArtLyrics);
      await prefs.setBool('nami_v26_swipe_dismiss', swipeDownDismiss);
      await prefs.setString('nami_v26_motion_speed', motionSpeed);
      await prefs.setBool('nami_v27_gapless', gaplessPlayback);
      await prefs.setString('nami_v27_replaygain', replayGainMode);
      await prefs.setBool('nami_v27_persist_session', persistSession);
      await prefs.setBool('nami_v29_blur', enableBlurEffect);
      await prefs.setBool('nami_v29_8_row_swipe', trackRowSwipeActions);
      await prefs.setBool('nami_v29_glow', enableGlowEffect);
      await prefs.setInt('nami_v29_fade_ms', fadeDurationMs);
      await prefs.setInt('nami_v29_seek_sec', seekDurationSec);
      await prefs.setInt('nami_v29_wf_bars', waveformBarsCount);
      await prefs.setString('nami_v29_yt_region', youtubeRegion);
      await prefs.setString('nami_v29_yt_quality', youtubeAudioQuality);
      await prefs.setBool('nami_v29_yt_local', youtubeLocalOnly);
      await prefs.setBool('nami_v30_yt_sb', ytSponsorBlock);
      await prefs.setBool('nami_v30_yt_ryd', ytReturnDislike);
      await prefs.setBool('nami_v30_yt_radio', ytAutoStartRadio);
      await prefs.setBool('nami_v30_yt_pers', ytPersonalizedFeeds);
      await prefs.setBool('nami_v30_yt_clean', ytSearchCleanup);
      await prefs.setBool('nami_v30_yt_dl_tags', ytDownloadMetadataTags);
      await prefs.setInt('nami_v30_yt_dim_sec', ytDimMiniAfterSec);
      await prefs.setInt('nami_v30_yt_dim_pct', ytDimIntensityPct);
      await prefs.setString('nami_v30_theme_mode', themeModePref);
      await prefs.setBool('nami_v30_auto_color', autoColoring);
      await prefs.setBool('nami_v30_pitch_black', usePitchBlack);
      await prefs.setBool('nami_v30_refresh_start', refreshOnStartup);
      await prefs.setBool('nami_v30_extract_feat', extractFeatArtists);
      await prefs.setBool('nami_v30_nomedia', respectNomedia);
      await prefs.setBool('nami_v30_no_dups', preventDuplicateTracks);
      await prefs.setInt('nami_v30_min_dur', minTrackDurationSec);
      await prefs.setInt('nami_v30_min_kb', minFileSizeKb);
      await prefs.setBool('nami_v30_skip_sil', skipSilence);
      await prefs.setBool('nami_v30_fade_on', enableFadeEffect);
      await prefs.setInt('nami_v30_pause_fade', pauseFadeDurationMs);
      await prefs.setBool('nami_v30_inf_queue', infinityQueue);
      await prefs.setBool('nami_v30_immersive', immersiveMode);
      await prefs.setString('nami_v30_perf_mode', performanceMode);
      await prefs.setInt('nami_v30_img_cache_mb', imageCacheLimitMb);
      await prefs.setInt('nami_v30_aud_cache_gb', audioCacheLimitGb);
    } catch (_) {}
  }

  static void startSleepTimer(Duration? duration, VoidCallback onExpire) {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    if (duration == null || duration.inSeconds <= 0) {
      sleepRemaining.value = null;
      return;
    }
    sleepRemaining.value = duration;
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      final cur = sleepRemaining.value;
      if (cur == null || cur.inSeconds <= 1) {
        t.cancel();
        _sleepTicker = null;
        sleepRemaining.value = null;
        onExpire();
      } else {
        sleepRemaining.value = Duration(seconds: cur.inSeconds - 1);
      }
    });
  }

  static void hapticLight() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }
}

