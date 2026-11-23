#!/usr/bin/env python3
"""
Permanent Nami Android Native Configurator (replaces legacy patch_manifest.py).
Idempotently configures AndroidManifest.xml, MainActivity.kt (USB DAC + audio output),
R8 ProGuard shrinking, and persistent Base64 release keystore signing.
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
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val AUDIO_DEVICE_CHANNEL = "com.piyush.nami/audio_device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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

    if "com.ryanheise.audioservice.AudioService" not in txt:
        service_xml = """        <service
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
    </application>"""
        txt = txt.replace("</application>", service_xml, 1)

    open(MANIFEST, "w", encoding="utf-8").write(txt)
    print("Configured AndroidManifest.xml")


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
