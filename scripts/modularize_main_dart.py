#!/usr/bin/env python3
"""
Safely modularizes lib/main.dart into Dart part files:
  - lib/models/nami_models.dart
  - lib/widgets/nami_widgets.dart
  - lib/screens/settings_screen.dart
  - lib/screens/now_playing_screen.dart
Idempotent and bracket/brace-verified. Run inside ~/nami.
"""

import os
import re

MAIN_PATH = "lib/main.dart"


def _advance_dart_string(text: str, start_idx: int) -> int:
    n = len(text)
    i = start_idx
    is_raw = False
    if text[i] == "r" and i + 1 < n and text[i + 1] in ("'", '"'):
        is_raw = True
        i += 1
    t_sq = "'" * 3
    t_dq = '"' * 3
    bslash = chr(92)
    if text[i : i + 3] in (t_sq, t_dq):
        quote = text[i : i + 3]
        i += 3
    else:
        quote = text[i]
        i += 1
    q_len = len(quote)
    while i < n:
        if not is_raw and text[i] == bslash:
            i += 2
            continue
        if not is_raw and text[i : i + 2] == "${":
            i += 2
            interp_depth = 1
            while i < n and interp_depth > 0:
                if text[i] == bslash:
                    i += 2
                    continue
                if text[i] in ("'", '"') or (
                    text[i] == "r" and i + 1 < n and text[i + 1] in ("'", '"')
                ):
                    i = _advance_dart_string(text, i)
                    continue
                if text[i] == "{":
                    interp_depth += 1
                elif text[i] == "}":
                    interp_depth -= 1
                i += 1
            continue
        if text[i : i + q_len] == quote:
            return i + q_len
        i += 1
    return n


def _find_matching_brace(text: str, open_idx: int) -> int:
    depth = 0
    i, n = open_idx, len(text)
    while i < n:
        ch = text[i]
        if text[i : i + 2] == "//":
            nl = text.find("\n", i)
            i = n if nl == -1 else nl + 1
            continue
        if text[i : i + 2] == "/*":
            end_c = text.find("*/", i + 2)
            i = n if end_c == -1 else end_c + 2
            continue
        if ch in ("'", '"') or (ch == "r" and i + 1 < n and text[i + 1] in ("'", '"')):
            i = _advance_dart_string(text, i)
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _count_code_tokens(text: str) -> tuple[int, int]:
    p_diff, b_diff = 0, 0
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if text[i : i + 2] == "//":
            nl = text.find("\n", i)
            i = n if nl == -1 else nl + 1
            continue
        if text[i : i + 2] == "/*":
            end_c = text.find("*/", i + 2)
            i = n if end_c == -1 else end_c + 2
            continue
        if ch in ("'", '"') or (ch == "r" and i + 1 < n and text[i + 1] in ("'", '"')):
            i = _advance_dart_string(text, i)
            continue
        if ch == "(":
            p_diff += 1
        elif ch == ")":
            p_diff -= 1
        elif ch == "{":
            b_diff += 1
        elif ch == "}":
            b_diff -= 1
        i += 1
    return p_diff, b_diff


def _extract_class_block(text: str, class_name: str) -> tuple[str, str]:
    m = re.search(rf"^class\s+{re.escape(class_name)}\b[^{{]*\{{", text, re.M)
    if not m:
        return text, ""
    start = m.start()
    open_b = m.end() - 1
    close_b = _find_matching_brace(text, open_b)
    if close_b == -1:
        return text, ""
    end = close_b + 1
    while end < len(text) and text[end] in (" ", "\t", "\r", "\n"):
        end += 1
    block = text[start : close_b + 1]
    remaining = text[:start] + text[end:]
    return remaining, block


def _write_file(path: str, content: str) -> None:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def main() -> None:
    if not os.path.exists(MAIN_PATH):
        print("lib/main.dart not found, skipping modularization.")
        return

    c = open(MAIN_PATH, "r", encoding="utf-8").read()
    orig_len = len(c)

    if "part 'models/nami_models.dart';" in c:
        p, b = _count_code_tokens(c)
        assert p == 0 and b == 0, f"main.dart unbalanced: P={p} B={b}"
        print(f"lib/main.dart is already modularized ({orig_len} chars).")
        return

    groups = {
        "lib/models/nami_models.dart": [
            "SyllableToken",
            "LyricLine",
            "AudioTrack",
            "CustomPlaylist",
            "MornyeExtension",
            "MornyeCatalogItem",
        ],
        "lib/widgets/nami_widgets.dart": [
            "HuePaletteCanvas",
            "_HuePaletteCanvasState",
            "NamiFastScroller",
            "_NamiFastScrollerState",
            "AnimatedPlayingBars",
            "_AnimatedPlayingBarsState",
            "YoutubeSkeletonLoader",
        ],
        "lib/screens/settings_screen.dart": [
            "MainSettingsScreen",
            "_MainSettingsScreenState",
        ],
        "lib/screens/now_playing_screen.dart": [
            "NowPlayingModal",
            "_NowPlayingModalState",
        ],
    }

    part_directives = []
    for rel_path, class_list in groups.items():
        chunks = []
        for cls in class_list:
            c, blk = _extract_class_block(c, cls)
            if blk:
                chunks.append(blk)
        if chunks:
            part_content = "part of '../main.dart';\n\n" + "\n\n".join(chunks) + "\n"
            p_p, b_p = _count_code_tokens(part_content)
            assert p_p == 0 and b_p == 0, f"{rel_path} unbalanced: P={p_p} B={b_p}"
            _write_file(rel_path, part_content)
            part_rel = rel_path.replace("lib/", "", 1)
            part_directives.append(f"part '{part_rel}';")
            print(f"  Extracted {rel_path} ({len(chunks)} classes)")

    if part_directives:
        last_imp = None
        for m in re.finditer(r"^import\s+[^\n]+;\s*$", c, re.M):
            last_imp = m
        if last_imp:
            ins = "\n\n" + "\n".join(part_directives) + "\n"
            c = c[: last_imp.end()] + ins + c[last_imp.end() :]
        else:
            c = "\n".join(part_directives) + "\n\n" + c

    p_m, b_m = _count_code_tokens(c)
    assert p_m == 0 and b_m == 0, f"main.dart unbalanced after split: P={p_m} B={b_m}"
    _write_file(MAIN_PATH, c)
    print(f"SUCCESS: Modularized lib/main.dart ({orig_len} -> {len(c)} chars) | Balance P=0 B=0")


if __name__ == "__main__":
    main()
