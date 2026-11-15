import os
import glob

manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()

    if "READ_MEDIA_AUDIO" not in content:
        perms = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <application"""
        content = content.replace("<application", perms)

    if "AudioService" not in content:
        service_block = """        <service android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback" android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
    </application>"""
        content = content.replace("</application>", service_block)

    content = content.replace('android:name="com.ryanheise.audioservice.AudioServiceActivity"', 'android:name=".MainActivity"')

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Manifest patched successfully.")

for kt in glob.glob("android/app/src/main/**/MainActivity.kt", recursive=True):
    with open(kt, "r", encoding="utf-8") as f:
        kt_code = f.read()
    pkg_line = [l for l in kt_code.splitlines() if l.startswith("package ")][0]
    standard_kt = f"""{pkg_line}

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
"""
    with open(kt, "w", encoding="utf-8") as f:
        f.write(standard_kt)
    print("MainActivity.kt reset to FlutterActivity:", kt)

for gradle_kts in glob.glob("android/app/build.gradle.kts"):
    with open(gradle_kts, "r", encoding="utf-8") as f:
        g_code = f.read()
    if "audio_service" in g_code:
        g_code = g_code.replace("implementation(project(\":audio_service\"))", "")
        with open(gradle_kts, "w", encoding="utf-8") as f:
            f.write(g_code)
        print("Cleaned build.gradle.kts")
