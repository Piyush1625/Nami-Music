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
