#!/usr/bin/env python3
"""
Permanent Nami Android Native Configurator.
Configures AndroidManifest.xml (v2 embedding, storage/DAC permissions, AudioService),
MainActivity.kt (USB DAC + active audio output), R8 ProGuard & release keystore signing.
"""

import base64
import glob
import os
import re

MANIFEST = "android/app/src/main/AndroidManifest.xml"

KT_TEMPLATE = """package __PKG__

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.os.Environment
import android.net.Uri
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val AUDIO_DEVICE_CHANNEL = "com.piyush.nami/audio_device"

        override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    @Suppress("DEPRECATION")
    private fun enableHighRefreshRate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val activeDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
                val current = activeDisplay?.mode ?: return
                val bestMode = activeDisplay.supportedModes
                    .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
                    .maxByOrNull { it.refreshRate }
                if (bestMode != null && bestMode.modeId != current.modeId) {
                    val lp = window.attributes
                    lp.preferredDisplayModeId = bestMode.modeId
                    window.attributes = lp
                }
            }
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.piyush.nami/widget")
        widgetChannel.setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val prefs = getSharedPreferences(NamiMusicWidgetProvider.PREFS, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("title", call.argument<String>("title") ?: "Nami Music")
                    .putString("artist", call.argument<String>("artist") ?: "")
                    .putBoolean("isPlaying", call.argument<Boolean>("isPlaying") ?: false)
                    .putString("coverPath", call.argument<String>("coverPath") ?: "")
                    .apply()
                NamiMusicWidgetProvider.updateAll(this)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        NamiMusicWidgetProvider.onWidgetAction = { action: String ->
            runOnUiThread {
                try { widgetChannel.invokeMethod(action, null) } catch (_: Exception) {}
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                                        "hasAllFilesPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Environment.isExternalStorageManager()
                        } else {
                            true
                        }
                        result.success(granted)
                    }
                    "requestAllFilesPermission" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                if (Environment.isExternalStorageManager()) {
                                    result.success("granted")
                                } else {
                                    try {
                                        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                                        intent.data = Uri.parse("package:$packageName")
                                        startActivity(intent)
                                    } catch (_: Exception) {
                                        val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                        startActivity(intent)
                                    }
                                    result.success("opened")
                                }
                            } else {
                                result.success("granted")
                            }
                        } catch (e: Exception) {
                            result.success("error")
                        }
                    }
                    "requestUsbDacPermission" -> {
                        try {
                            val usbMgr = getSystemService(Context.USB_SERVICE) as UsbManager
                            val usbAudioDev = usbMgr.deviceList.values.firstOrNull { dev ->
                                dev.deviceClass == UsbConstants.USB_CLASS_AUDIO ||
                                    (0 until dev.interfaceCount).any {
                                        dev.getInterface(it).interfaceClass == UsbConstants.USB_CLASS_AUDIO
                                    }
                            }
                            if (usbAudioDev != null) {
                                val label = usbAudioDev.productName ?: "USB DAC"
                                if (usbMgr.hasPermission(usbAudioDev)) {
                                    result.success(mapOf("status" to "granted", "device" to label))
                                } else {
                                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                                    val pi = PendingIntent.getBroadcast(this, 0, Intent("com.piyush.nami.USB_PERMISSION"), flags)
                                    usbMgr.requestPermission(usbAudioDev, pi)
                                    result.success(mapOf("status" to "requested", "device" to label))
                                }
                            } else {
                                result.success(mapOf("status" to "no_usb_dac", "device" to ""))
                            }
                        } catch (e: Exception) {
                            result.success(mapOf("status" to "error", "device" to ""))
                        }
                    }
                    "getActiveAudioDevice" -> {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                        var name = "Phone Speaker"
                        var type = "Built-in Speaker"
                        var isExternal = false
                        for (d in devices) {
                            when (d.type) {
                                AudioDeviceInfo.TYPE_USB_HEADSET,
                                AudioDeviceInfo.TYPE_USB_DEVICE,
                                AudioDeviceInfo.TYPE_USB_ACCESSORY -> {
                                    name = d.productName?.toString()?.takeIf { it.isNotBlank() } ?: "USB DAC"
                                    type = "USB DAC"
                                    isExternal = true
                                    break
                                }
                                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                                AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
                                    name = d.productName?.toString()?.takeIf { it.isNotBlank() } ?: "Wired IEM / Headphones"
                                    type = "3.5mm Wired"
                                    isExternal = true
                                }
                                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                                AudioDeviceInfo.TYPE_BLE_HEADSET -> {
                                    if (!isExternal) {
                                        name = d.productName?.toString()?.takeIf { it.isNotBlank() } ?: "Bluetooth Audio"
                                        type = "Bluetooth"
                                        isExternal = true
                                    }
                                }
                            }
                        }
                        result.success(mapOf("name" to name, "type" to type, "isExternal" to isExternal))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
"""


def patch_manifest() -> None:
    if not os.path.exists(MANIFEST):
        print("Manifest not found, skipping.")
        return
    txt = open(MANIFEST, "r", encoding="utf-8").read()
    perms = [
        "android.permission.INTERNET",
        "android.permission.WAKE_LOCK",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.READ_EXTERNAL_STORAGE",
        "android.permission.WRITE_EXTERNAL_STORAGE",
        "android.permission.READ_MEDIA_AUDIO",
        "android.permission.READ_MEDIA_IMAGES",
        "android.permission.MANAGE_EXTERNAL_STORAGE",
        "android.permission.MODIFY_AUDIO_SETTINGS",
        "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    ]
    inserts = [f'    <uses-permission android:name="{p}"/>' for p in perms if p not in txt]
    if "android.hardware.usb.host" not in txt:
        inserts.append('    <uses-feature android:name="android.hardware.usb.host" android:required="false"/>')
    if inserts:
        txt = txt.replace("<application", "\n".join(inserts) + "\n    <application", 1)

    if "requestLegacyExternalStorage" not in txt:
        txt = txt.replace("<application", '<application android:requestLegacyExternalStorage="true"', 1)

    # Enforce Android v2 embedding
    txt = txt.replace('android:name="io.flutter.app.FlutterApplication"', 'android:name="${applicationName}"')
    if 'android:name="flutterEmbedding"' not in txt:
        meta_v2 = (
            '        <meta-data\n'
            '            android:name="flutterEmbedding"\n'
            '            android:value="2" />\n'
            '    </application>'
        )
        txt = txt.replace("</application>", meta_v2, 1)
    else:
        txt = re.sub(
            r'(<meta-data[^>]*android:name="flutterEmbedding"[^>]*android:value=")1(")',
            r"\g<1>2\g<2>",
            txt,
            flags=re.S,
        )

    if "com.ryanheise.audioservice.AudioService" not in txt:
        service_xml = (
            '        <service\n'
            '            android:name="com.ryanheise.audioservice.AudioService"\n'
            '            android:foregroundServiceType="mediaPlayback"\n'
            '            android:exported="true">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.media.browse.MediaBrowserService" />\n'
            '            </intent-filter>\n'
            '        </service>\n'
            '        <receiver\n'
            '            android:name="com.ryanheise.audioservice.MediaButtonReceiver"\n'
            '            android:exported="true">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.MEDIA_BUTTON" />\n'
            '            </intent-filter>\n'
            '        </receiver>\n'
            '    </application>'
        )
        txt = txt.replace("</application>", service_xml, 1)

    for jpath in glob.glob("android/app/src/main/java/**/MainActivity.java", recursive=True):
        jtxt = open(jpath, encoding="utf-8", errors="ignore").read()
        if "io.flutter.app.FlutterActivity" in jtxt or "GeneratedPluginRegistrant" in jtxt:
            os.remove(jpath)
            print(f"Removed legacy v1 {jpath}")

    open(MANIFEST, "w", encoding="utf-8").write(txt)
    print("Configured AndroidManifest.xml (v2 embedding)")


def patch_main_activity() -> None:
    kt_files = glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True)
    if not kt_files:
        print("MainActivity.kt not found, skipping.")
        return
    kt_path = kt_files[0]
    orig = open(kt_path, "r", encoding="utf-8").read()
    pkg_m = re.search(r"^package\s+([^\s]+)", orig, re.M)
    pkg = pkg_m.group(1) if pkg_m else "com.piyush.nami"
    open(kt_path, "w", encoding="utf-8").write(KT_TEMPLATE.replace("__PKG__", pkg))
    print(f"Configured {kt_path}")


def patch_signing_and_r8() -> None:
    b64 = os.environ.get("NAMI_KEYSTORE_B64", "").strip()
    pwd = os.environ.get("NAMI_KEY_PASS", "").strip()
    has_keystore = False
    if b64 and pwd:
        os.makedirs("android/app", exist_ok=True)
        with open("android/app/nami-release.jks", "wb") as kf:
            kf.write(base64.b64decode(b64))
        with open("android/key.properties", "w", encoding="utf-8") as pf:
            pf.write(
                f"storePassword={pwd}\n"
                f"keyPassword={pwd}\n"
                f"keyAlias=nami\n"
                f"storeFile=nami-release.jks\n"
            )
        has_keystore = True
        print("Decoded persistent release keystore & wrote android/key.properties")

    for gpath in ["android/app/build.gradle.kts", "android/app/build.gradle"]:
        if not os.path.exists(gpath):
            continue
        g = open(gpath, "r", encoding="utf-8").read()
        is_kts = gpath.endswith(".kts")
        g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", g)
        g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", g)

        if has_keystore and "nami-release.jks" not in g:
            if is_kts:
                props_init = (
                    "import java.util.Properties\n"
                    "import java.io.FileInputStream\n\n"
                    "val keystoreProperties = Properties()\n"
                    'val keystorePropertiesFile = rootProject.file("key.properties")\n'
                    "if (keystorePropertiesFile.exists()) {\n"
                    "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
                    "}\n\n"
                )
                if "keystoreProperties" not in g:
                    g = props_init + g
                g = g.replace(
                    "buildTypes {",
                    'signingConfigs {\n'
                    '        create("release") {\n'
                    '            keyAlias = keystoreProperties.getProperty("keyAlias")\n'
                    '            keyPassword = keystoreProperties.getProperty("keyPassword")\n'
                    '            storeFile = file(keystoreProperties.getProperty("storeFile", "nami-release.jks"))\n'
                    '            storePassword = keystoreProperties.getProperty("storePassword")\n'
                    "        }\n"
                    "    }\n"
                    "    buildTypes {",
                    1,
                )
                g = g.replace(
                    'signingConfig = signingConfigs.getByName("debug")',
                    'signingConfig = signingConfigs.getByName("release")\n'
                    "            isMinifyEnabled = true\n"
                    "            isShrinkResources = true\n"
                    '            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
                    1,
                )
            else:
                props_init = (
                    "def keystoreProperties = new Properties()\n"
                    'def keystorePropertiesFile = rootProject.file("key.properties")\n'
                    "if (keystorePropertiesFile.exists()) {\n"
                    "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
                    "}\n\n"
                )
                if "keystoreProperties" not in g:
                    g = props_init + g
                g = g.replace(
                    "buildTypes {",
                    "signingConfigs {\n"
                    "        release {\n"
                    '            keyAlias keystoreProperties["keyAlias"]\n'
                    '            keyPassword keystoreProperties["keyPassword"]\n'
                    '            storeFile file(keystoreProperties["storeFile"] ?: "nami-release.jks")\n'
                    '            storePassword keystoreProperties["storePassword"]\n'
                    "        }\n"
                    "    }\n"
                    "    buildTypes {",
                    1,
                )
                g = g.replace(
                    "signingConfig = signingConfigs.debug",
                    "signingConfig = signingConfigs.release\n"
                    "            minifyEnabled true\n"
                    "            shrinkResources true\n"
                    '            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"',
                    1,
                )
                g = g.replace(
                    "signingConfig signingConfigs.debug",
                    "signingConfig signingConfigs.release\n"
                    "            minifyEnabled true\n"
                    "            shrinkResources true\n"
                    '            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"',
                    1,
                )
        open(gpath, "w", encoding="utf-8").write(g)
        print(f"Configured {gpath}")


if __name__ == "__main__":
    patch_manifest()
    patch_main_activity()
    patch_signing_and_r8()


# --- V28_WIDGET_PROVIDER_GENERATOR ---
def _nami_generate_widget_provider():
    import glob as _g, os as _o, re as _r
    if not _o.path.isdir('android/app/src/main'):
        return
    ns = None
    for _gp in ['android/app/build.gradle.kts', 'android/app/build.gradle']:
        if _o.path.exists(_gp):
            _m = _r.search(r'namespace\s*=?\s*["\']([\w.]+)["\']', open(_gp, encoding='utf-8').read())
            if _m:
                ns = _m.group(1)
                break
    res_root = 'android/app/src/main/res'
    files = {'drawable/nami_widget_bg.xml': '<?xml version="1.0" encoding="utf-8"?>\n<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n    <solid android:color="#EE0B0B12" />\n    <corners android:radius="22dp" />\n    <stroke android:width="1dp" android:color="#22FFFFFF" />\n</shape>\n', 'layout/nami_widget_layout.xml': '<?xml version="1.0" encoding="utf-8"?>\n<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"\n    android:id="@+id/nami_widget_root"\n    android:layout_width="match_parent"\n    android:layout_height="match_parent"\n    android:background="@drawable/nami_widget_bg"\n    android:gravity="center_vertical"\n    android:orientation="horizontal"\n    android:paddingLeft="10dp"\n    android:paddingRight="10dp"\n    android:paddingTop="8dp"\n    android:paddingBottom="8dp">\n\n    <ImageView\n        android:id="@+id/nami_widget_art"\n        android:layout_width="46dp"\n        android:layout_height="46dp"\n        android:scaleType="centerCrop"\n        android:src="@mipmap/ic_launcher"\n        android:contentDescription="Album Art" />\n\n    <LinearLayout\n        android:layout_width="0dp"\n        android:layout_height="wrap_content"\n        android:layout_weight="1"\n        android:layout_marginStart="12dp"\n        android:layout_marginEnd="8dp"\n        android:orientation="vertical">\n\n        <TextView\n            android:id="@+id/nami_widget_title"\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:ellipsize="end"\n            android:maxLines="1"\n            android:text="Nami Music"\n            android:textColor="#FFFFFFFF"\n            android:textSize="14sp"\n            android:textStyle="bold" />\n\n        <TextView\n            android:id="@+id/nami_widget_artist"\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="2dp"\n            android:ellipsize="end"\n            android:maxLines="1"\n            android:text="Tap to open player"\n            android:textColor="#AAFFFFFF"\n            android:textSize="11.5sp" />\n    </LinearLayout>\n\n    <ImageButton\n        android:id="@+id/nami_widget_prev"\n        android:layout_width="36dp"\n        android:layout_height="36dp"\n        android:background="@android:color/transparent"\n        android:src="@android:drawable/ic_media_previous"\n        android:tint="#CCFFFFFF"\n        android:contentDescription="Previous" />\n\n    <ImageButton\n        android:id="@+id/nami_widget_play_pause"\n        android:layout_width="40dp"\n        android:layout_height="40dp"\n        android:background="@android:color/transparent"\n        android:src="@android:drawable/ic_media_play"\n        android:tint="#FFFFFFFF"\n        android:contentDescription="Play or Pause" />\n\n    <ImageButton\n        android:id="@+id/nami_widget_next"\n        android:layout_width="36dp"\n        android:layout_height="36dp"\n        android:background="@android:color/transparent"\n        android:src="@android:drawable/ic_media_next"\n        android:tint="#CCFFFFFF"\n        android:contentDescription="Next" />\n</LinearLayout>\n', 'xml/nami_widget_info.xml': '<?xml version="1.0" encoding="utf-8"?>\n<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"\n    android:minWidth="250dp"\n    android:minHeight="62dp"\n    android:targetCellWidth="4"\n    android:targetCellHeight="1"\n    android:updatePeriodMillis="0"\n    android:initialLayout="@layout/nami_widget_layout"\n    android:resizeMode="horizontal|vertical"\n    android:widgetCategory="home_screen" />\n'}
    for rel, content in files.items():
        full = _o.path.join(res_root, rel)
        _o.makedirs(_o.path.dirname(full), exist_ok=True)
        open(full, 'w', encoding='utf-8').write(content)
    kt_tpl = 'package __PKG__\n__R_IMPORT__\nimport android.app.PendingIntent\nimport android.appwidget.AppWidgetManager\nimport android.appwidget.AppWidgetProvider\nimport android.content.ComponentName\nimport android.content.Context\nimport android.content.Intent\nimport android.graphics.BitmapFactory\nimport android.os.Build\nimport android.widget.RemoteViews\nimport java.io.File\n\nclass NamiMusicWidgetProvider : AppWidgetProvider() {\n\n    companion object {\n        const val PREFS = "nami_widget_prefs"\n        const val ACTION_PLAY_PAUSE = "com.piyush.nami.WIDGET_PLAY_PAUSE"\n        const val ACTION_NEXT = "com.piyush.nami.WIDGET_NEXT"\n        const val ACTION_PREV = "com.piyush.nami.WIDGET_PREV"\n\n        var onWidgetAction: ((String) -> Unit)? = null\n\n        fun updateAll(context: Context) {\n            val mgr = AppWidgetManager.getInstance(context)\n            val ids = mgr.getAppWidgetIds(ComponentName(context, NamiMusicWidgetProvider::class.java))\n            if (ids.isEmpty()) return\n            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)\n            val title = prefs.getString("title", "Nami Music") ?: "Nami Music"\n            val artist = prefs.getString("artist", "Tap to open player") ?: "Tap to open player"\n            val isPlaying = prefs.getBoolean("isPlaying", false)\n            val coverPath = prefs.getString("coverPath", "") ?: ""\n\n            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {\n                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE\n            } else {\n                PendingIntent.FLAG_UPDATE_CURRENT\n            }\n\n            for (id in ids) {\n                val views = RemoteViews(context.packageName, R.layout.nami_widget_layout)\n                views.setTextViewText(R.id.nami_widget_title, title)\n                views.setTextViewText(R.id.nami_widget_artist, artist)\n                views.setImageViewResource(\n                    R.id.nami_widget_play_pause,\n                    if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play\n                )\n\n                var artLoaded = false\n                if (coverPath.isNotEmpty()) {\n                    try {\n                        val f = File(coverPath)\n                        if (f.exists() && f.length() > 0) {\n                            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }\n                            BitmapFactory.decodeFile(coverPath, bounds)\n                            var sample = 1\n                            while (bounds.outWidth / sample > 144 || bounds.outHeight / sample > 144) { sample *= 2 }\n                            val opts = BitmapFactory.Options().apply { inSampleSize = sample }\n                            val bmp = BitmapFactory.decodeFile(coverPath, opts)\n                            if (bmp != null) {\n                                views.setImageViewBitmap(R.id.nami_widget_art, bmp)\n                                artLoaded = true\n                            }\n                        }\n                    } catch (_: Exception) {}\n                }\n                if (!artLoaded) {\n                    views.setImageViewResource(R.id.nami_widget_art, R.mipmap.ic_launcher)\n                }\n\n                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)\n                if (launchIntent != null) {\n                    val openPi = PendingIntent.getActivity(context, 10, launchIntent, flags)\n                    views.setOnClickPendingIntent(R.id.nami_widget_root, openPi)\n                }\n\n                fun broadcastPi(action: String, reqCode: Int): PendingIntent {\n                    val i = Intent(context, NamiMusicWidgetProvider::class.java).apply { this.action = action }\n                    return PendingIntent.getBroadcast(context, reqCode, i, flags)\n                }\n                views.setOnClickPendingIntent(R.id.nami_widget_prev, broadcastPi(ACTION_PREV, 11))\n                views.setOnClickPendingIntent(R.id.nami_widget_play_pause, broadcastPi(ACTION_PLAY_PAUSE, 12))\n                views.setOnClickPendingIntent(R.id.nami_widget_next, broadcastPi(ACTION_NEXT, 13))\n\n                mgr.updateAppWidget(id, views)\n            }\n        }\n    }\n\n    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {\n        updateAll(context)\n    }\n\n    override fun onReceive(context: Context, intent: Intent) {\n        super.onReceive(context, intent)\n        when (intent.action) {\n            ACTION_PLAY_PAUSE -> onWidgetAction?.invoke("playPause")\n            ACTION_NEXT -> onWidgetAction?.invoke("next")\n            ACTION_PREV -> onWidgetAction?.invoke("prev")\n        }\n    }\n}\n'
    for kt in _g.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True):
        kt_txt = open(kt, encoding='utf-8').read()
        m_pkg = _r.search(r'^package\s+([\w.]+)', kt_txt, _r.M)
        pkg = m_pkg.group(1) if m_pkg else 'com.piyush.nami'
        r_imp = f'\nimport {ns}.R\n' if (ns and ns != pkg) else ''
        prov = _o.path.join(_o.path.dirname(kt), 'NamiMusicWidgetProvider.kt')
        open(prov, 'w', encoding='utf-8').write(kt_tpl.replace('__PKG__', pkg).replace('__R_IMPORT__', r_imp))
    man_p = 'android/app/src/main/AndroidManifest.xml'
    if _o.path.exists(man_p):
        man = open(man_p, encoding='utf-8').read()
        if 'NamiMusicWidgetProvider' not in man and '</application>' in man:
            open(man_p, 'w', encoding='utf-8').write(man.replace('</application>', '        <receiver\n            android:name=".NamiMusicWidgetProvider"\n            android:exported="true"\n            android:label="Nami Music">\n            <intent-filter>\n                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />\n                <action android:name="com.piyush.nami.WIDGET_PLAY_PAUSE" />\n                <action android:name="com.piyush.nami.WIDGET_NEXT" />\n                <action android:name="com.piyush.nami.WIDGET_PREV" />\n            </intent-filter>\n            <meta-data\n                android:name="android.appwidget.provider"\n                android:resource="@xml/nami_widget_info" />\n        </receiver>\n    </application>', 1))
    print('Generated NamiMusicWidgetProvider.kt, widget XML resources & manifest receiver.')

_nami_generate_widget_provider()

# v31_16kb_manifest_patch
def _apply_v31_16kb_android_hardening():
    import os as _os
    _mp = "android/app/src/main/AndroidManifest.xml"
    if _os.path.exists(_mp):
        _m = open(_mp, encoding="utf-8").read()
        _o = _m
        if "android:usesCleartextTraffic" not in _m:
            _m = _m.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
        if "android:extractNativeLibs" not in _m:
            _m = _m.replace("<application", '<application\n        android:extractNativeLibs="false"', 1)
        if _m != _o:
            open(_mp, "w", encoding="utf-8").write(_m)
    for _gp in ("android/app/build.gradle.kts", "android/app/build.gradle"):
        if _os.path.exists(_gp):
            _g = open(_gp, encoding="utf-8").read()
            if "useLegacyPackaging" not in _g and "android {" in _g:
                _blk = (
                    "\n    packaging {\n        jniLibs {\n            useLegacyPackaging = false\n        }\n    }\n"
                    if _gp.endswith(".kts")
                    else "\n    packagingOptions {\n        jniLibs {\n            useLegacyPackaging false\n        }\n    }\n"
                )
                open(_gp, "w", encoding="utf-8").write(_g.replace("android {", "android {" + _blk, 1))

if __name__ == "__main__":
    _apply_v31_16kb_android_hardening()

# v31_2_lock_120hz_display_mode
def _apply_v31_2_120hz_main_activity():
    import glob as _glob
    for _kt in _glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True):
        _s = open(_kt, encoding="utf-8").read()
        if "preferredDisplayModeId" in _s:
            continue
        _hook = (
            "\n    override fun onResume() {\n"
            "        super.onResume()\n"
            "        try {\n"
            "            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {\n"
            "                val modes = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) display?.supportedModes else windowManager.defaultDisplay.supportedModes\n"
            "                val best = modes?.maxByOrNull { it.refreshRate }\n"
            "                if (best != null) {\n"
            "                    val lp = window.attributes\n"
            "                    lp.preferredDisplayModeId = best.modeId\n"
            "                    window.attributes = lp\n"
            "                }\n"
            "            }\n"
            "        } catch (_: Throwable) {}\n"
            "    }\n"
        )
        _last_b = _s.rfind("}")
        if _last_b != -1:
            open(_kt, "w", encoding="utf-8").write(_s[:_last_b] + _hook + _s[_last_b:])

if __name__ == "__main__":
    _apply_v31_2_120hz_main_activity()

# v32_0_pure_youtube_webview_potoken
_NAMI_V32_YT_ENGINE_KT = 'package __PKG_NAME__\n\nimport android.annotation.SuppressLint\nimport android.app.Activity\nimport android.app.Dialog\nimport android.graphics.Color\nimport android.net.Uri\nimport android.os.Handler\nimport android.os.Looper\nimport android.view.Gravity\nimport android.view.View\nimport android.view.ViewGroup\nimport android.view.Window\nimport android.webkit.CookieManager\nimport android.webkit.WebChromeClient\nimport android.webkit.WebResourceRequest\nimport android.webkit.WebResourceResponse\nimport android.webkit.WebSettings\nimport android.webkit.WebView\nimport android.webkit.WebViewClient\nimport android.widget.FrameLayout\nimport android.widget.LinearLayout\nimport android.widget.TextView\nimport io.flutter.embedding.engine.FlutterEngine\nimport io.flutter.plugin.common.MethodChannel\nimport java.io.ByteArrayInputStream\nimport java.util.concurrent.atomic.AtomicBoolean\nimport java.util.concurrent.atomic.AtomicReference\n\n/**\n * Pure-YouTube Native Chromium BotGuard Extractor & In-App Sign-In Bridge for Nami v3.2.0.\n * - Logged-Out Mode: runs invisible 1x1 Chromium WebView on the user\'s real device IP so YouTube\'s\n *   own BotGuard JS mints anonymous PoTokens & deciphers stream signatures automatically.\n * - Logged-In Mode: optional 1-tap in-app YouTube sign-in sharing Android CookieManager across\n *   both the headless extractor and Dart InnerTube requests.\n */\nobject NamiYtWebViewEngine {\n    private const val CHANNEL_NAME = "com.piyush.nami/yt_engine"\n    private val mainHandler = Handler(Looper.getMainLooper())\n\n    private var appActivity: Activity? = null\n    private var headlessWebView: WebView? = null\n    private var cachedUserAgent: String = ""\n    private var activeVideoId: String = ""\n    private val activeResult = AtomicReference<MethodChannel.Result?>(null)\n    private val activeResolved = AtomicBoolean(false)\n    private var activeTimeoutRunnable: Runnable? = null\n    private var activeNudgeRunnable: Runnable? = null\n\n    fun attach(activity: Activity, flutterEngine: FlutterEngine) {\n        appActivity = activity\n        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)\n            .setMethodCallHandler { call, result ->\n                when (call.method) {\n                    "warmUp" -> {\n                        mainHandler.post {\n                            ensureHeadlessWebView(activity)\n                            result.success(getSessionInfoMap())\n                        }\n                    }\n                    "getSessionStatus" -> {\n                        mainHandler.post {\n                            ensureUserAgent(activity)\n                            result.success(getSessionInfoMap())\n                        }\n                    }\n                    "extractAudioStream" -> {\n                        val videoId = call.argument<String>("videoId") ?: ""\n                        if (videoId.isEmpty()) {\n                            result.success(null)\n                        } else {\n                            mainHandler.post {\n                                startHeadlessExtraction(activity, videoId, result)\n                            }\n                        }\n                    }\n                    "openSignIn" -> {\n                        mainHandler.post {\n                            openSignInDialog(activity, result)\n                        }\n                    }\n                    "signOut" -> {\n                        mainHandler.post {\n                            try {\n                                val cm = CookieManager.getInstance()\n                                cm.removeAllCookies {\n                                    cm.flush()\n                                    result.success(getSessionInfoMap())\n                                }\n                            } catch (_: Throwable) {\n                                result.success(getSessionInfoMap())\n                            }\n                        }\n                    }\n                    else -> result.notImplemented()\n                }\n            }\n    }\n\n    private fun ensureUserAgent(activity: Activity): String {\n        if (cachedUserAgent.isNotEmpty()) return cachedUserAgent\n        return try {\n            val raw = WebSettings.getDefaultUserAgent(activity)\n            cachedUserAgent = raw.replace("; wv)", ")").replace("Version/4.0 ", "")\n            cachedUserAgent\n        } catch (_: Throwable) {\n            cachedUserAgent =\n                "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"\n            cachedUserAgent\n        }\n    }\n\n    private fun getSessionInfoMap(): HashMap<String, Any> {\n        val cm = CookieManager.getInstance()\n        val cookie = cm.getCookie("https://www.youtube.com")\n            ?: cm.getCookie("https://m.youtube.com")\n            ?: ""\n        val signedIn = cookie.contains("SAPISID=") || cookie.contains("__Secure-3PAPISID=")\n        val map = HashMap<String, Any>()\n        map["signedIn"] = signedIn\n        map["cookie"] = cookie\n        map["userAgent"] = cachedUserAgent\n        return map\n    }\n\n    private fun empty204(): WebResourceResponse {\n        return WebResourceResponse("text/plain", "utf-8", 204, "No Content", emptyMap(), ByteArrayInputStream(ByteArray(0)))\n    }\n\n    private fun stripRangeParams(rawUrl: String): String {\n        return try {\n            val uri = Uri.parse(rawUrl)\n            val b = uri.buildUpon().clearQuery()\n            for (name in uri.queryParameterNames) {\n                if (name == "range" || name == "rn" || name == "rbuf" || name == "ump" || name == "srfvp") {\n                    continue\n                }\n                val v = uri.getQueryParameter(name)\n                if (v != null) b.appendQueryParameter(name, v)\n            }\n            b.build().toString()\n        } catch (_: Throwable) {\n            rawUrl\n        }\n    }\n\n    private fun finishExtraction(payload: HashMap<String, Any>?) {\n        if (!activeResolved.compareAndSet(false, true)) return\n        activeTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }\n        activeNudgeRunnable?.let { mainHandler.removeCallbacks(it) }\n        activeTimeoutRunnable = null\n        activeNudgeRunnable = null\n        val pending = activeResult.getAndSet(null)\n        mainHandler.post {\n            try {\n                headlessWebView?.stopLoading()\n                headlessWebView?.loadUrl("about:blank")\n            } catch (_: Throwable) {}\n            try {\n                pending?.success(payload)\n            } catch (_: Throwable) {}\n        }\n    }\n\n    @SuppressLint("SetJavaScriptEnabled")\n    private fun ensureHeadlessWebView(activity: Activity): WebView? {\n        headlessWebView?.let { return it }\n        return try {\n            val ua = ensureUserAgent(activity)\n            val cm = CookieManager.getInstance()\n            cm.setAcceptCookie(true)\n\n            val wv = WebView(activity)\n            cm.setAcceptThirdPartyCookies(wv, true)\n            wv.alpha = 0.0f\n            wv.visibility = View.INVISIBLE\n            wv.settings.apply {\n                javaScriptEnabled = true\n                domStorageEnabled = true\n                mediaPlaybackRequiresUserGesture = false\n                loadsImagesAutomatically = false\n                blockNetworkImage = true\n                cacheMode = WebSettings.LOAD_DEFAULT\n                mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW\n                userAgentString = ua\n            }\n            wv.webChromeClient = WebChromeClient()\n            wv.webViewClient = object : WebViewClient() {\n                override fun shouldInterceptRequest(\n                    view: WebView?,\n                    request: WebResourceRequest?\n                ): WebResourceResponse? {\n                    val url = request?.url?.toString() ?: return null\n                    val lower = url.lowercase()\n\n                    // Fast-drop non-essential assets so Chromium reaches playback JS in ~1s\n                    if (lower.contains("doubleclick.net") ||\n                        lower.contains("googlesyndication.com") ||\n                        lower.contains("googleadservices.com") ||\n                        lower.contains("/api/stats/") ||\n                        lower.contains("/youtubei/v1/log_event") ||\n                        lower.endsWith(".jpg") ||\n                        lower.endsWith(".jpeg") ||\n                        lower.endsWith(".png") ||\n                        lower.endsWith(".webp") ||\n                        lower.endsWith(".woff2")\n                    ) {\n                        return empty204()\n                    }\n\n                    // Intercept real BotGuard/PoToken-signed googlevideo.com audio stream!\n                    if (lower.contains("googlevideo.com/videoplayback")) {\n                        val isVideoOnly = lower.contains("mime=video") || lower.contains("mime%3dvideo")\n                        if (isVideoOnly) {\n                            return empty204()\n                        }\n                        val isAudio = lower.contains("mime=audio") ||\n                            lower.contains("mime%3daudio") ||\n                            lower.contains("itag=251") ||\n                            lower.contains("itag=250") ||\n                            lower.contains("itag=249") ||\n                            lower.contains("itag=140") ||\n                            lower.contains("itag=139")\n                        if (isAudio && !activeResolved.get() && activeVideoId.isNotEmpty()) {\n                            val cleanUrl = stripRangeParams(url)\n                            val uri = Uri.parse(url)\n                            val mime = uri.getQueryParameter("mime")\n                                ?: if (lower.contains("itag=140") || lower.contains("itag=139")) "audio/mp4" else "audio/webm"\n                            val clen = uri.getQueryParameter("clen")?.toLongOrNull() ?: 0L\n                            val cookie = CookieManager.getInstance().getCookie("https://www.youtube.com")\n                                ?: CookieManager.getInstance().getCookie("https://m.youtube.com")\n                                ?: ""\n                            val payload = HashMap<String, Any>()\n                            payload["url"] = cleanUrl\n                            payload["mimeType"] = mime\n                            payload["contentLength"] = clen\n                            payload["userAgent"] = cachedUserAgent\n                            payload["cookie"] = cookie\n                            payload["clientUsed"] = if (cookie.contains("SAPISID=")) "WEBVIEW_AUTH" else "WEBVIEW_BOTGUARD"\n                            finishExtraction(payload)\n                            return empty204()\n                        }\n                    }\n\n                    // Also intercept HLS audio playlist if YouTube serves HLS to Chromium\n                    if (lower.contains("manifest.googlevideo.com/api/manifest/hls") &&\n                        lower.contains(".m3u8") &&\n                        !activeResolved.get() &&\n                        activeVideoId.isNotEmpty()\n                    ) {\n                        val cookie = CookieManager.getInstance().getCookie("https://www.youtube.com") ?: ""\n                        val payload = HashMap<String, Any>()\n                        payload["url"] = url\n                        payload["mimeType"] = "application/x-mpegURL"\n                        payload["contentLength"] = 0L\n                        payload["userAgent"] = cachedUserAgent\n                        payload["cookie"] = cookie\n                        payload["clientUsed"] = "WEBVIEW_HLS"\n                        finishExtraction(payload)\n                        return empty204()\n                    }\n                    return null\n                }\n\n                override fun onPageFinished(view: WebView?, url: String?) {\n                    super.onPageFinished(view, url)\n                    if (url != null && url.contains("youtube.com") && !activeResolved.get()) {\n                        nudgePlayback(view)\n                    }\n                }\n            }\n\n            // Attach invisible 1x1 container to DecorView so Chromium runs JS & BotGuard at full speed\n            val root = activity.window?.decorView as? ViewGroup\n            if (root != null) {\n                val lp = FrameLayout.LayoutParams(1, 1)\n                lp.gravity = Gravity.TOP or Gravity.START\n                root.addView(wv, lp)\n            }\n            headlessWebView = wv\n            wv\n        } catch (_: Throwable) {\n            null\n        }\n    }\n\n    private fun nudgePlayback(wv: WebView?) {\n        if (wv == null || activeResolved.get()) return\n        val js = """\n            (function() {\n              try {\n                var v = document.querySelector(\'video\');\n                if (v) { v.muted = true; v.volume = 0; var p = v.play(); if (p && p.catch) p.catch(function(){}); }\n                var btn = document.querySelector(\'.ytp-large-play-button, .ytp-play-button, button[aria-label="Play"], .player-control-play-pause-icon\');\n                if (btn) btn.click();\n              } catch (e) {}\n            })();\n        """.trimIndent()\n        try {\n            wv.evaluateJavascript(js, null)\n        } catch (_: Throwable) {}\n    }\n\n    private fun startHeadlessExtraction(\n        activity: Activity,\n        videoId: String,\n        result: MethodChannel.Result\n    ) {\n        // Cancel any previous in-flight extraction cleanly\n        if (activeResult.get() != null) {\n            finishExtraction(null)\n        }\n        val wv = ensureHeadlessWebView(activity)\n        if (wv == null) {\n            result.success(null)\n            return\n        }\n        activeVideoId = videoId\n        activeResult.set(result)\n        activeResolved.set(false)\n\n        val nudge = Runnable {\n            if (!activeResolved.get()) {\n                nudgePlayback(headlessWebView)\n            }\n        }\n        activeNudgeRunnable = nudge\n        mainHandler.postDelayed(nudge, 1800L)\n\n        val timeout = Runnable {\n            finishExtraction(null)\n        }\n        activeTimeoutRunnable = timeout\n        mainHandler.postDelayed(timeout, 11000L)\n\n        wv.stopLoading()\n        wv.loadUrl("https://m.youtube.com/watch?v=$videoId&has_verified=1")\n    }\n\n    @SuppressLint("SetJavaScriptEnabled")\n    private fun openSignInDialog(activity: Activity, result: MethodChannel.Result) {\n        val done = AtomicBoolean(false)\n        fun completeOnce() {\n            if (!done.compareAndSet(false, true)) return\n            try {\n                CookieManager.getInstance().flush()\n            } catch (_: Throwable) {}\n            result.success(getSessionInfoMap())\n        }\n\n        try {\n            val dialog = Dialog(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen)\n            dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)\n\n            val root = LinearLayout(activity).apply {\n                orientation = LinearLayout.VERTICAL\n                setBackgroundColor(Color.BLACK)\n                layoutParams = ViewGroup.LayoutParams(\n                    ViewGroup.LayoutParams.MATCH_PARENT,\n                    ViewGroup.LayoutParams.MATCH_PARENT\n                )\n            }\n\n            // Minimal AMOLED Top Bar with Title & Close button\n            val header = LinearLayout(activity).apply {\n                orientation = LinearLayout.HORIZONTAL\n                gravity = Gravity.CENTER_VERTICAL\n                setBackgroundColor(Color.parseColor("#0B0B10"))\n                setPadding(40, 32, 32, 32)\n            }\n            val titleTv = TextView(activity).apply {\n                text = "Sign in to YouTube"\n                setTextColor(Color.WHITE)\n                textSize = 17f\n                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)\n            }\n            val closeBtn = TextView(activity).apply {\n                text = "Done"\n                setTextColor(Color.parseColor("#A78BFA"))\n                textSize = 15f\n                setPadding(28, 12, 16, 12)\n                setOnClickListener {\n                    dialog.dismiss()\n                }\n            }\n            header.addView(titleTv)\n            header.addView(closeBtn)\n\n            val ua = ensureUserAgent(activity)\n            val wv = WebView(activity).apply {\n                layoutParams = LinearLayout.LayoutParams(\n                    ViewGroup.LayoutParams.MATCH_PARENT,\n                    0,\n                    1f\n                )\n            }\n            val cm = CookieManager.getInstance()\n            cm.setAcceptCookie(true)\n            cm.setAcceptThirdPartyCookies(wv, true)\n            wv.settings.apply {\n                javaScriptEnabled = true\n                domStorageEnabled = true\n                userAgentString = ua\n                mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW\n            }\n            wv.webChromeClient = WebChromeClient()\n            wv.webViewClient = object : WebViewClient() {\n                override fun onPageFinished(view: WebView?, url: String?) {\n                    super.onPageFinished(view, url)\n                    val u = url ?: return\n                    if (u.startsWith("https://m.youtube.com") || u.startsWith("https://www.youtube.com")) {\n                        val cookie = cm.getCookie("https://www.youtube.com")\n                            ?: cm.getCookie("https://m.youtube.com")\n                            ?: ""\n                        if (cookie.contains("SAPISID=") || cookie.contains("__Secure-3PAPISID=")) {\n                            cm.flush()\n                            dialog.dismiss()\n                        }\n                    }\n                }\n            }\n\n            root.addView(header)\n            root.addView(wv)\n            dialog.setContentView(root)\n            dialog.setOnDismissListener {\n                try {\n                    wv.stopLoading()\n                    wv.destroy()\n                } catch (_: Throwable) {}\n                completeOnce()\n            }\n            dialog.show()\n            wv.loadUrl("https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fm.youtube.com%2F")\n        } catch (_: Throwable) {\n            completeOnce()\n        }\n    }\n}\n'

def _apply_v32_0_yt_webview_engine():
    import glob as _glob, os as _os, re as _re
    # 1. Ensure AndroidManifest allows localhost 127.0.0.1 progressive proxy traffic
    _mp = "android/app/src/main/AndroidManifest.xml"
    if _os.path.exists(_mp):
        _m = open(_mp, encoding="utf-8").read()
        if "android:usesCleartextTraffic" not in _m:
            open(_mp, "w", encoding="utf-8").write(
                _m.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
            )

    # 2. Write NamiYtWebViewEngine.kt beside MainActivity.kt & attach in configureFlutterEngine
    for _kt in _glob.glob("android/app/src/main/kotlin/**/MainActivity.kt", recursive=True):
        _s = open(_kt, encoding="utf-8").read()
        _pkg_m = _re.search(r"^\s*package\s+([A-Za-z0-9_.]+)", _s, _re.M)
        _pkg = _pkg_m.group(1) if _pkg_m else "com.piyush.nami"
        _engine_path = _os.path.join(_os.path.dirname(_kt), "NamiYtWebViewEngine.kt")
        open(_engine_path, "w", encoding="utf-8").write(
            _NAMI_V32_YT_ENGINE_KT.replace("__PKG_NAME__", _pkg)
        )

        if "NamiYtWebViewEngine.attach(" not in _s:
            _orig = _s
            if "import io.flutter.embedding.engine.FlutterEngine" not in _s:
                _s = _re.sub(
                    r"(^\s*package\s+[^\n]+\n)",
                    r"\1import io.flutter.embedding.engine.FlutterEngine\n",
                    _s,
                    count=1,
                    flags=_re.M,
                )
            _m_cfg = _re.search(r"override\s+fun\s+configureFlutterEngine\s*\([^)]*\)\s*\{", _s)
            if _m_cfg:
                _ins = _m_cfg.end()
                _s = _s[:_ins] + "\n        NamiYtWebViewEngine.attach(this, flutterEngine)" + _s[_ins:]
            else:
                _last_b = _s.rfind("}")
                if _last_b != -1:
                    _cfg_fn = (
                        "\n    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {\n"
                        "        super.configureFlutterEngine(flutterEngine)\n"
                        "        NamiYtWebViewEngine.attach(this, flutterEngine)\n"
                        "    }\n"
                    )
                    _s = _s[:_last_b] + _cfg_fn + _s[_last_b:]
            if _s != _orig:
                open(_kt, "w", encoding="utf-8").write(_s)

if __name__ == "__main__":
    _apply_v32_0_yt_webview_engine()
