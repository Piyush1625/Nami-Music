import os, re, glob

manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        m = f.read()

    required_perms = [
        "android.permission.INTERNET",
        "android.permission.WAKE_LOCK",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.READ_MEDIA_AUDIO",
    ]
    for perm in required_perms:
        if perm not in m:
            perm_tag = f'    <uses-permission android:name="{perm}"/>\n'
            m = m.replace("<application", perm_tag + "    <application", 1)

    if "android:usesCleartextTraffic" not in m:
        m = m.replace("<application", '<application android:usesCleartextTraffic="true"', 1)

    service_snippet = '''
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>

        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
    </application>'''

    if "com.ryanheise.audioservice.AudioService" not in m:
        m = m.replace("</application>", service_snippet)
    elif 'android:foregroundServiceType="mediaPlayback"' not in m:
        m = m.replace(
            'android:name="com.ryanheise.audioservice.AudioService"',
            'android:name="com.ryanheise.audioservice.AudioService" android:foregroundServiceType="mediaPlayback"'
        )

    with open(manifest_path, "w", encoding="utf-8") as f:
        f.write(m)
    print("✅ Patched AndroidManifest.xml with AudioService & Android 14 permissions")

kt_files = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
for kt in kt_files:
    with open(kt, "r", encoding="utf-8") as f:
        content = f.read()
    pkg_match = re.search(r"package\s+([a-zA-Z0-9_.]+)", content)
    pkg = pkg_match.group(1) if pkg_match else "com.example.nami"
    new_kt = f"package {pkg}\n\nimport com.ryanheise.audioservice.AudioServiceActivity\n\nclass MainActivity: AudioServiceActivity() {{\n}}\n"
    with open(kt, "w", encoding="utf-8") as f:
        f.write(new_kt)
    print(f"✅ Patched {kt} to extend AudioServiceActivity")
