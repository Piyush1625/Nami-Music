import re, subprocess

old = subprocess.check_output(["git", "show", "HEAD~1:lib/main.dart"]).decode("utf-8")
m_old = re.search(
    r'Colors\.white12\)\)\s*,\s*\)\s*,\s*\)\s*,\s*\);\s*([\s\S]*?)\n\s*\],',
    old
)
assert m_old, "Could not extract closing braces from HEAD~1"
closing_tail = m_old.group(1)

with open("lib/main.dart", "r", encoding="utf-8") as f:
    c = f.read()

p_broken = re.compile(
    r'return GestureDetector\(\s*onTap:\s*\(\)\s*=>\s*widget\.audioPlayer\.seek\(lyrics\[idx\]\.timestamp\),\s*'
    r'child:\s*AnimatedScale\([\s\S]*?\n\s*\],',
    re.DOTALL
)

fixed_block = """return GestureDetector(
                      onTap: () => widget.audioPlayer.seek(lyrics[idx].timestamp),
                      child: AnimatedScale(
                        scale: isCenter5th ? 1.06 : (distance == 1 ? 0.96 : 0.90),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            lineText, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isCenter5th ? 18.0 : (distance == 1 ? 14.5 : 12.5),
                              fontWeight: isCenter5th ? FontWeight.w800 : FontWeight.w500,
                              color: isCenter5th ? Colors.white : (distance == 1 ? Colors.white60 : (distance <= 3 ? Colors.white30 : Colors.white12)),
                            ),
                          ),
                        ),
                      ),
                    );
""" + closing_tail + "\n                  ],"

c, count = p_broken.subn(lambda _: fixed_block, c, count=1)
assert count == 1, f"Fix match failed: {count}"

with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(c)

lines = c.splitlines()
for i in range(6603, min(len(lines), 6644)):
    print(f"{i+1}: {lines[i]}")
print("SUCCESS: Restored missing closing brace for lyrics itemBuilder!")
