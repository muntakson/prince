import re, glob, json, hashlib, sys
lines = []  # (speaker, text, file)
pair_re = re.compile(r'\[\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\]')
dict_re = re.compile(r'\{\s*"speaker"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,\s*"text"\s*:\s*"((?:[^"\\]|\\.)*)"\s*\}')
start_str_re = re.compile(r'DialogueManager\.start\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
portal_re = re.compile(r'add_portal\([^,]+,\s*"[^"]*"\s*,\s*"((?:[^"\\]|\\.)*)"')
def unesc(s): return bytes(s, "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in s else s
for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)) + sorted(glob.glob("autoload/*.gd")):
    src = open(f, encoding="utf-8").read()
    if f.replace("\\", "/").endswith("ui/Glossary.gd"): continue   # word data, not dialogue (cards added below)
    for m in pair_re.finditer(src):
        lines.append((unesc(m.group(1)), unesc(m.group(2)), f))
    for m in dict_re.finditer(src):
        lines.append((unesc(m.group(1)), unesc(m.group(2)), f))
    for m in start_str_re.finditer(src):
        lines.append(("", unesc(m.group(1)), f))
    for m in portal_re.finditer(src):
        lines.append(("", unesc(m.group(1)), f))
# Word Cards (scripts/ui/Glossary.gd): speaker "New Word", text = Glossary.card_text (nick  =  sci, newline, what)
gsrc = open("scripts/ui/Glossary.gd", encoding="utf-8").read()
wre = re.compile(r'"nick": \["([^"]*)",[^\]]*\],\s*"sci": \["([^"]*)",[^\]]*\],\s*"what": \["([^"]*)"', re.S)
for m in wre.finditer(gsrc):
    lines.append(("New Word", "%s  =  %s\n%s" % (unesc(m.group(1)), unesc(m.group(2)), unesc(m.group(3))), "scripts/ui/Glossary.gd"))
for cf in ["assets/help/mixer_clues.json", "assets/help/tcell_clues.json"]:
    for k, v in json.load(open(cf, encoding="utf-8")).items():
        if k != "title": lines.append(("Scroll", v, cf))
seen = {}
for sp, tx, f in lines:
    if len(tx) < 3 or "%" in tx and ("%d" in tx or "%s" in tx): continue
    key = sp + "|" + tx
    if key not in seen: seen[key] = (sp, tx, f)
out = [{"speaker": sp, "text": tx, "file": f, "id": hashlib.md5((sp+"|"+tx).encode("utf-8")).hexdigest()[:12]} for sp, tx, f in seen.values()]
json.dump(out, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
from collections import Counter
print("lines:", len(out), "chars:", sum(len(o["text"]) for o in out))
print("speakers:", Counter(o["speaker"] for o in out).most_common())
print("files:", Counter(o["file"] for o in out).most_common())
