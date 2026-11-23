# Nami Music Player — R8 / ProGuard Keep Rules
# Preserve media_kit / libmpv JNI callbacks, audio_service & Flutter MethodChannels

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# media_kit & libmpv native bindings
-keep class com.alexmercerind.** { *; }
-keep class is.xyz.mpv.** { *; }
-dontwarn com.alexmercerind.**

# audio_service & AndroidX MediaSession
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

# Nami native Kotlin MethodChannels (USB DAC, Audio Output, Gallery Picker)
-keep class com.piyush.nami.** { *; }
