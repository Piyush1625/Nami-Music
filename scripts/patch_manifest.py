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


# --- Nami Custom Adaptive Launcher Icon Generator ---
import os as _os
import zlib as _zlib
import struct as _struct

def _write_png(path, w, h, pixels_rgba):
    def _chunk(tag, data):
        return _struct.pack(">I", len(data)) + tag + data + _struct.pack(">I", _zlib.crc32(tag + data) & 0xffffffff)
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        row_start = y * w * 4
        raw.extend(pixels_rgba[row_start:row_start + w * 4])
    ihdr = _struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", _zlib.compress(bytes(raw), 9)) + _chunk(b"IEND", b"")
    _os.makedirs(_os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as _f:
        _f.write(png)

def _render_nami_icon_rgba(size):
    buf = bytearray(size * size * 4)
    cx = cy = (size - 1) / 2.0
    rad = size * 0.44
    bars = [(-0.22, 0.22), (-0.11, 0.36), (0.00, 0.46), (0.11, 0.32), (0.22, 0.20)]
    bar_half_w = max(1.5, size * 0.032)
    for y in range(size):
        for x in range(size):
            dx = abs(x - cx) / rad
            dy = abs(y - cy) / rad
            dist = (dx ** 4 + dy ** 4) ** 0.25
            idx = (y * size + x) * 4
            if dist <= 1.0:
                t = ((x / size) + (y / size)) * 0.5
                r = int(229 + (255 - 229) * t)
                g = int(57 + (112 - 57) * t)
                b = int(53 + (67 - 53) * t)
                ny = abs(y - cy) / size
                for bx, bh in bars:
                    if abs(x - (cx + bx * size)) <= bar_half_w and ny <= bh * 0.5:
                        r, g, b = 255, 255, 255
                        break
                buf[idx:idx+4] = bytes((r, g, b, 255))
            else:
                buf[idx:idx+4] = b"\x00\x00\x00\x00"
    return buf

_res_dir = "android/app/src/main/res"
if _os.path.isdir(_res_dir):
    _os.makedirs(f"{_res_dir}/values", exist_ok=True)
    with open(f"{_res_dir}/values/ic_launcher_background.xml", "w", encoding="utf-8") as _f:
        _f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#09090F</color>\n</resources>\n')

    _os.makedirs(f"{_res_dir}/drawable", exist_ok=True)
    _fg_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    xmlns:aapt="http://schemas.android.com/aapt"\n'
        '    android:width="108dp"\n'
        '    android:height="108dp"\n'
        '    android:viewportWidth="108"\n'
        '    android:viewportHeight="108">\n'
        '    <path android:pathData="M36,24 L72,24 Q84,24 84,36 L84,72 Q84,84 72,84 L36,84 Q24,84 24,72 L24,36 Q24,24 36,24 Z">\n'
        '        <aapt:attr name="android:fillColor">\n'
        '            <gradient android:startX="24" android:startY="24" android:endX="84" android:endY="84" android:type="linear">\n'
        '                <item android:offset="0" android:color="#FFE53935"/>\n'
        '                <item android:offset="1" android:color="#FFFF7043"/>\n'
        '            </gradient>\n'
        '        </aapt:attr>\n'
        '    </path>\n'
        '    <path android:fillColor="#FFFFFFFF" android:pathData="M37,47 h4 a2,2 0 0 1 2,2 v10 a2,2 0 0 1 -2,2 h-4 a2,2 0 0 1 -2,-2 v-10 a2,2 0 0 1 2,-2 z"/>\n'
        '    <path android:fillColor="#FFFFFFFF" android:pathData="M44.5,41 h4 a2,2 0 0 1 2,2 v22 a2,2 0 0 1 -2,2 h-4 a2,2 0 0 1 -2,-2 v-22 a2,2 0 0 1 2,-2 z"/>\n'
        '    <path android:fillColor="#FFFFFFFF" android:pathData="M52,36 h4 a2,2 0 0 1 2,2 v32 a2,2 0 0 1 -2,2 h-4 a2,2 0 0 1 -2,-2 v-32 a2,2 0 0 1 2,-2 z"/>\n'
        '    <path android:fillColor="#FFFFFFFF" android:pathData="M59.5,42 h4 a2,2 0 0 1 2,2 v20 a2,2 0 0 1 -2,2 h-4 a2,2 0 0 1 -2,-2 v-20 a2,2 0 0 1 2,-2 z"/>\n'
        '    <path android:fillColor="#FFFFFFFF" android:pathData="M67,48 h4 a2,2 0 0 1 2,2 v8 a2,2 0 0 1 -2,2 h-4 a2,2 0 0 1 -2,-2 v-8 a2,2 0 0 1 2,-2 z"/>\n'
        '</vector>\n'
    )
    with open(f"{_res_dir}/drawable/ic_launcher_foreground.xml", "w", encoding="utf-8") as _f:
        _f.write(_fg_xml)

    _os.makedirs(f"{_res_dir}/mipmap-anydpi-v26", exist_ok=True)
    _adaptive_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    with open(f"{_res_dir}/mipmap-anydpi-v26/ic_launcher.xml", "w", encoding="utf-8") as _f:
        _f.write(_adaptive_xml)
    with open(f"{_res_dir}/mipmap-anydpi-v26/ic_launcher_round.xml", "w", encoding="utf-8") as _f:
        _f.write(_adaptive_xml)

    for _dpi, _px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        _rgba = _render_nami_icon_rgba(_px)
        _write_png(f"{_res_dir}/mipmap-{_dpi}/ic_launcher.png", _px, _px, _rgba)
        _write_png(f"{_res_dir}/mipmap-{_dpi}/ic_launcher_round.png", _px, _px, _rgba)
    print("Patched custom Nami adaptive launcher icon & mipmap PNGs!")


# --- Nami Persistent Release Keystore Signing (Enables In-Place APK Updates) ---
import base64 as _b64
import glob as _glob

_ks_b64 = _os.environ.get("NAMI_KEYSTORE_B64", "").strip()
_ks_pass = _os.environ.get("NAMI_KEY_PASS", "nami2026release").strip() or "nami2026release"

if _ks_b64:
    _app_dir = "android/app"
    _ks_path = f"{_app_dir}/nami-release.jks"
    with open(_ks_path, "wb") as _kf:
        _kf.write(_b64.b64decode(_ks_b64))
    with open("android/key.properties", "w", encoding="utf-8") as _kp:
        _kp.write(f"storePassword={_ks_pass}\nkeyPassword={_ks_pass}\nkeyAlias=nami\nstoreFile=nami-release.jks\n")

    for _gpath in _glob.glob("android/app/build.gradle*"):
        with open(_gpath, "r", encoding="utf-8") as _gf:
            _gtxt = _gf.read()
        if "nami-release.jks" in _gtxt:
            continue
        if _gpath.endswith(".kts"):
            _sign_block = (
                'import java.util.Properties\n'
                'import java.io.FileInputStream\n\n'
                'val keystoreProperties = Properties()\n'
                'val keystorePropertiesFile = rootProject.file("key.properties")\n'
                'if (keystorePropertiesFile.exists()) {\n'
                '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
                '}\n\n'
            )
            _gtxt = _sign_block + _gtxt
            _gtxt = _gtxt.replace(
                'signingConfig = signingConfigs.getByName("debug")',
                'signingConfigs.create("release") {\n'
                '                keyAlias = keystoreProperties.getProperty("keyAlias")\n'
                '                keyPassword = keystoreProperties.getProperty("keyPassword")\n'
                '                storeFile = file(keystoreProperties.getProperty("storeFile"))\n'
                '                storePassword = keystoreProperties.getProperty("storePassword")\n'
                '            }\n'
                '            signingConfig = signingConfigs.getByName("release")'
            )
        else:
            _sign_groovy = (
                'def keystoreProperties = new Properties()\n'
                "def keystorePropertiesFile = rootProject.file('key.properties')\n"
                'if (keystorePropertiesFile.exists()) {\n'
                '    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n'
                '}\n\n'
            )
            _gtxt = _sign_groovy + _gtxt
            _gtxt = _gtxt.replace(
                'signingConfig signingConfigs.debug',
                'signingConfigs {\n'
                '                release {\n'
                "                    keyAlias keystoreProperties['keyAlias']\n"
                "                    keyPassword keystoreProperties['keyPassword']\n"
                "                    storeFile file(keystoreProperties['storeFile'])\n"
                "                    storePassword keystoreProperties['storePassword']\n"
                '                }\n'
                '            }\n'
                '            signingConfig signingConfigs.release'
            )
        with open(_gpath, "w", encoding="utf-8") as _gf:
            _gf.write(_gtxt)
        print(f"Configured persistent release signing in {_gpath}!")


# --- Nami Native Android Audio Output Device Detector (AudioManager + Build.MODEL) ---
import glob as _glob2

for _ma_path in _glob2.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True):
    with open(_ma_path, "r", encoding="utf-8") as _mf:
        _mtxt = _mf.read()
    if "com.piyush.nami/audio_device" in _mtxt:
        continue
    _pkg_line = ""
    for _line in _mtxt.splitlines():
        if _line.strip().startswith("package "):
            _pkg_line = _line.strip()
            break
    if not _pkg_line:
        _pkg_line = "package com.piyush.nami"

    _new_kt = f"""{_pkg_line}

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {{
    private val CHANNEL = "com.piyush.nami/audio_device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {{ call, result ->
            if (call.method == "getActiveAudioDevice") {{
                result.success(detectActiveAudioDevice())
            }} else {{
                result.notImplemented()
            }}
        }}
    }}

    private fun detectActiveAudioDevice(): Map<String, Any> {{
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val model = (Build.MANUFACTURER.replaceFirstChar {{ it.uppercase() }} + " " + Build.MODEL).trim()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {{
            val outputs = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (d in outputs) {{
                if (d.type == AudioDeviceInfo.TYPE_USB_DEVICE || d.type == AudioDeviceInfo.TYPE_USB_HEADSET) {{
                    val name = d.productName?.toString()?.trim().orEmpty().ifEmpty {{ "USB Audio DAC" }}
                    return mapOf("name" to name, "type" to "USB DAC", "isExternal" to true)
                }}
            }}
            for (d in outputs) {{
                if (d.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP || (Build.VERSION.SDK_INT >= 31 && d.type == AudioDeviceInfo.TYPE_BLE_HEADSET)) {{
                    val name = d.productName?.toString()?.trim().orEmpty().ifEmpty {{ "Bluetooth Audio" }}
                    return mapOf("name" to name, "type" to "Bluetooth", "isExternal" to true)
                }}
            }}
            for (d in outputs) {{
                if (d.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES || d.type == AudioDeviceInfo.TYPE_WIRED_HEADSET) {{
                    return mapOf("name" to "Wired Headphones", "type" to "3.5mm Audio", "isExternal" to true)
                }}
            }}
        }}
        return mapOf("name" to model, "type" to "Built-in Speaker", "isExternal" to false)
    }}
}}
"""
    with open(_ma_path, "w", encoding="utf-8") as _mf:
        _mf.write(_new_kt)
    print(f"Patched native AudioManager detector into {_ma_path}!")
