import os

manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Add permissions if missing
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

    # 2. Add AudioService if missing
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

    # 3. Use AudioServiceActivity
    content = content.replace('android:name=".MainActivity"', 'android:name="com.ryanheise.audioservice.AudioServiceActivity"')

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Manifest patched successfully via Python script.")

# 4. Fix MainActivity.kt package
import glob
for kt in glob.glob("android/app/src/main/**/MainActivity.kt", recursive=True):
    with open(kt, "r", encoding="utf-8") as f:
        kt_code = f.read()
    pkg_line = [l for l in kt_code.splitlines() if l.startswith("package ")][0]
    fixed_kt = f"""{pkg_line}

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity()
"""
    with open(kt, "w", encoding="utf-8") as f:
        f.write(fixed_kt)
    print("MainActivity.kt patched successfully:", kt)
