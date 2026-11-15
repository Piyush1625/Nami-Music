import os
import re

path = "lib/main.dart"
if not os.path.exists(path):
    print("Error: lib/main.dart not found!")
    exit(1)

with open(path, "r", encoding="utf-8") as f:
    code = f.read()

# 1. Remove all old or misplaced declarations of _isCheckingPerms from the entire file
code = re.sub(r'^\s*bool\s+_isCheckingPerms\s*=\s*(true|false);\s*$', '', code, flags=re.MULTILINE)

# 2. Find _NamiAppState and cleanly insert bool _isCheckingPerms = true; right inside it
pattern = r"(class\s+_NamiAppState\s+extends\s+State<\w+>\s*\{)"
if re.search(pattern, code):
    code = re.sub(pattern, r"\1\n  bool _isCheckingPerms = true;", code, count=1)
    print("Successfully injected _isCheckingPerms inside _NamiAppState.")
else:
    # Fallback to any state class if naming differs slightly
    code = re.sub(r"(class\s+_\w+State\s+extends\s+State<[^>]+>\s*\{)", r"\1\n  bool _isCheckingPerms = true;", code, count=1)
    print("Injected into state class via fallback.")

with open(path, "w", encoding="utf-8") as f:
    f.write(code)

print("lib/main.dart patched successfully!")
