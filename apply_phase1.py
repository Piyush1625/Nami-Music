import os, re
print("🚀 Modifying files for MediaKit...")

def patch_file(path, func):
    if os.path.exists(path):
        with open(path, "r") as f: s = f.read()
        s = func(s)
        with open(path, "w") as f: f.write(s)
        print(f"✅ {path} updated")
    else:
        print(f"❌ {path} not found")

def update_pubspec(s):
    s = re.sub(r"\s*just_audio:.*", "", s)
    s = re.sub(r"\s*just_audio_background:.*", "", s)
    s = re.sub(r"\s*audio_session:.*", "", s)
    if "media_kit:" not in s:
        s = s.replace("dependencies:", "dependencies:\n  media_kit: ^1.1.11+1\n  media_kit_video: ^1.2.4\n  media_kit_libs_android_audio: ^1.0.4")
    return s

def update_gradle(s):
    return re.sub(r"minSdkVersion\s+\d+", "minSdkVersion 21", s)

def update_main(s):
    if "MediaKit.ensureInitialized()" not in s:
        s = s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:media_kit/media_kit.dart';")
        s = s.replace("WidgetsFlutterBinding.ensureInitialized();", "")
        main_match = re.search(r'main\(\)\s*(?:async)?\s*\{', s)
        if main_match:
            idx = main_match.end()
            s = s[:idx] + "\n  WidgetsFlutterBinding.ensureInitialized();\n  MediaKit.ensureInitialized();" + s[idx:]
    return s

patch_file("pubspec.yaml", update_pubspec)
patch_file("android/app/build.gradle", update_gradle)
patch_file("lib/main.dart", update_main)
