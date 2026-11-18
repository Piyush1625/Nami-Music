#!/usr/bin/env python3
"""
Fixes the constructor argument placement between MainSettingsScreen and NowPlayingModal
in lib/main.dart.
"""

PATH = "lib/main.dart"
with open(PATH, "r", encoding="utf-8") as f:
    c = f.read()

misplaced_block = """          ambientGlow: _ambientGlow,
          syllableLyricsEnabled: _syllableLyricsEnabled,
          shuffleEnabled: _shuffleEnabled,
          repeatMode: _repeatMode,
          onToggleShuffle: () {
            setState(() => _shuffleEnabled = !_shuffleEnabled);
            _saveStateCache();
          },
          onCycleRepeat: () {
            setState(() => _repeatMode = (_repeatMode + 1) % 3);
            _audioPlayer.setPlaylistMode(_repeatMode == 2 ? PlaylistMode.single : PlaylistMode.none);
            _saveStateCache();
          },"""

clean_block = """          ambientGlow: _ambientGlow,
          syllableLyricsEnabled: _syllableLyricsEnabled,"""

assert misplaced_block in c, "Misplaced shuffleEnabled block not found in MainSettingsScreen!"
# 1. Restore MainSettingsScreen call to clean_block
c = c.replace(misplaced_block, clean_block, 1)

# 2. Insert misplaced_block into NowPlayingModal call inside _showNowPlayingScreen()
np_call_anchor = """          playNextQueue: _playNextQueue,
          ambientGlow: _ambientGlow,
          syllableLyricsEnabled: _syllableLyricsEnabled,"""

np_call_fixed = """          playNextQueue: _playNextQueue,
          ambientGlow: _ambientGlow,
          syllableLyricsEnabled: _syllableLyricsEnabled,
          shuffleEnabled: _shuffleEnabled,
          repeatMode: _repeatMode,
          onToggleShuffle: () {
            setState(() => _shuffleEnabled = !_shuffleEnabled);
            _saveStateCache();
          },
          onCycleRepeat: () {
            setState(() => _repeatMode = (_repeatMode + 1) % 3);
            _audioPlayer.setPlaylistMode(_repeatMode == 2 ? PlaylistMode.single : PlaylistMode.none);
            _saveStateCache();
          },"""

assert np_call_anchor in c, "NowPlayingModal call anchor not found!"
c = c.replace(np_call_anchor, np_call_fixed, 1)

p_diff = c.count("(") - c.count(")")
b_diff = c.count("{") - c.count("}")
k_diff = c.count("[") - c.count("]")
print(f"Balance -> Parens: {p_diff} | Braces: {b_diff} | Brackets: {k_diff}")
assert p_diff == 0 and b_diff == 0 and k_diff == 0, "Syntax balance check failed!"

with open(PATH, "w", encoding="utf-8") as f:
    f.write(c)

print("SUCCESS: Moved shuffleEnabled & repeatMode arguments into NowPlayingModal!")
