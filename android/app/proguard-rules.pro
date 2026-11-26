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

# Optional Play Core deferred component classes referenced by Flutter engine
-dontwarn com.google.android.play.core.**
-dontwarn java.lang.invoke.StringConcatFactory

# NewPipeExtractor v0.27.1 (Mozilla Rhino live player.js solver)
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter
-dontwarn org.mozilla.javascript.tools.**
-dontwarn org.schabi.newpipe.extractor.**

# R8 missing desktop-JVM class suppressions for Mozilla Rhino / NewPipeExtractor
-dontwarn jdk.dynalink.**
-dontwarn java.lang.invoke.**
-dontwarn java.beans.**
-dontwarn javax.swing.**
-dontwarn javax.naming.**
-dontwarn sun.misc.**
-dontwarn org.mozilla.javascript.**
-dontwarn org.mozilla.classfile.**
-dontwarn org.jsoup.**
-dontwarn com.grack.nanojson.**
