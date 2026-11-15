import os, re

# --- 1. PATCH NOW PLAYING MODAL (Remove A-B Loop) ---
modal_path = "lib/ui/now_playing_modal.dart"
if os.path.exists(modal_path):
    m = open(modal_path, "r", encoding="utf-8").read()
    
    # Hide the A-B loop options from the bottom sheet by shrinking their text
    m = m.replace("const Text('Set A-B Loop Start (Point A)')", "const SizedBox.shrink()")
    m = m.replace("const Text('Set A-B Loop End (Point B)')", "const SizedBox.shrink()")
    
    open(modal_path, "w", encoding="utf-8").write(m)
    print("✅ Removed A-B Loop from Now Playing Modal")
else:
    print("❌ Could not find now_playing_modal.dart")

# --- 2. PATCH MAIN.DART (Splash, Counts, Refresh) ---
main_path = "lib/main.dart"
if os.path.exists(main_path):
    s = open(main_path, "r", encoding="utf-8").read()

    # Feature A: Instant Count Updates on Delete
    delete_target = "song.delete();"
    if delete_target in s and "uniqueArtists =" not in s.split("song.delete();")[1][:150]:
        refresh_code = """song.delete();
          setState(() {
            _songs.removeWhere((item) => item.id == song.id);
            _filteredSongs.removeWhere((item) => item.id == song.id);
            uniqueArtists = _songs.map((item) => item.artist).toSet().toList();
          });"""
        s = s.replace(delete_target, refresh_code)
        print("✅ Added instant Track/Artist count updates on delete")

    # Feature B: Swipe Down to Refresh on Tracks
    list_target = "ListView.builder("
    idx = s.find("Widget _buildTracksPageBody")
    if idx != -1:
        list_idx = s.find(list_target, idx)
        if list_idx != -1 and "RefreshIndicator" not in s[idx:list_idx]:
            # Wrap the ListView in a RefreshIndicator and automatically balance the brackets
            prefix = s[:list_idx]
            suffix = s[list_idx:]
            
            wrapper_start = "RefreshIndicator(color: Theme.of(context).colorScheme.primary, backgroundColor: const Color(0xFF14141E), onRefresh: () async { await Future.delayed(const Duration(milliseconds: 600)); setState((){}); }, child: "
            
            # Find where the ListView.builder ends to add the closing parenthesis
            open_brackets = 0
            end_list_idx = -1
            for i in range(len(suffix)):
                if suffix[i] == '(': open_brackets += 1
                elif suffix[i] == ')':
                    open_brackets -= 1
                    if open_brackets == 0:
                        end_list_idx = i
                        break
            
            if end_list_idx != -1:
                s = prefix + wrapper_start + suffix[:end_list_idx+1] + ")" + suffix[end_list_idx+1:]
                print("✅ Added Swipe-to-Refresh on Tracks Page")

    # Feature C: 1.2s Splash Screen to hide the permission flicker
    build_target = "Widget build(BuildContext context) {"
    if build_target in s and "CircularProgressIndicator" not in s.split(build_target)[1][:200]:
        splash_code = """Widget build(BuildContext context) {
    if (_isCheckingPerms) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _isCheckingPerms = false);
      });
      return const Scaffold(backgroundColor: Color(0xFF050508), body: Center(child: CircularProgressIndicator(color: Colors.white24)));
    }"""
        s = s.replace(build_target, splash_code, 1)
        print("✅ Added smooth Startup Splash Screen structure")

    open(main_path, "w", encoding="utf-8").write(s)
