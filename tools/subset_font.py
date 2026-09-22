"""Rebuild assets/fonts/help_ko.otf: a Noto Sans CJK KR subset that covers every
string the game can show (all assets/help/*.json, every string literal in the
GDScript sources, printable ASCII and common punctuation). The subset is the
project's default UI font (project.godot gui/theme/custom_font), so re-run this
after editing any Korean text or adding UI strings with unusual characters.
   python3 tools/subset_font.py
"""
import glob, json, re, subprocess, os
chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set(" ·–—‘’“”…′→▼≈≤≥±°×−é")
def walk(o):
    if isinstance(o, dict): [walk(k) or walk(v) for k, v in o.items()]
    elif isinstance(o, list): [walk(v) for v in o]
    elif isinstance(o, str): chars.update(o)
for f in glob.glob("assets/help/*.json"): walk(json.load(open(f, encoding="utf-8")))
lit = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
for f in glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("autoload/*.gd"):
    for m in lit.finditer(open(f, encoding="utf-8").read()): chars.update(m.group(1))
chars |= set("한국어English복사Copied!복사됨!KO Copy X언어: 한국어 (F3)Language: English (F3)")
text = "".join(sorted(c for c in chars if ord(c) >= 0x20 and c not in "\\"))
open("/tmp/subset_chars.txt", "w", encoding="utf-8").write(text)
subprocess.run([os.path.expanduser("~/.local/bin/pyftsubset"), "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", "--font-number=1",
                "--text-file=/tmp/subset_chars.txt", "--output-file=assets/fonts/help_ko.otf"], check=True)
from fontTools.ttLib import TTFont
cmap = TTFont("assets/fonts/help_ko.otf").getBestCmap()
missing = sorted(set(c for c in text if ord(c) not in cmap))
print("glyphs:", len(cmap), "| size: %d KB" % (os.path.getsize("assets/fonts/help_ko.otf") // 1024), "| missing:", repr("".join(missing)))
