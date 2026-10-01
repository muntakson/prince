"""Korean voice clips for every dialogue line of play/희곡.md (ElevenLabs, eleven_multilingual_v2).

   EL=<elevenlabs key> python3 tools/play/gen_voice.py            # all lines, skips existing clips
   EL=<key> python3 tools/play/gen_voice.py --force 미라           # regenerate one speaker

Output: play/voice/<id>.mp3 (id = md5("speaker|text")[:12]) and play/voice/manifest.json
        {id: {speaker, voice, text, scene, duration}}. The dashboard server reads the manifest.
"""
import hashlib, json, os, re, subprocess, sys, time, urllib.request

KEY = os.environ.get("EL")
SCRIPT = "play/희곡.md"; OUT = "play/voice"; os.makedirs(OUT, exist_ok=True)

# role -> (voice id, settings)   Korean voices from the account; a few expressive English multilingual voices for the villains
VOICES = {
 "해설":          ("aurnUodFzOtofecLd3T1", 0.55, 0.15),   # Jung Narrative - Korean narrator
 "아린":          ("dfGdOKe4Py3B2cmOtW1k", 0.45, 0.35),   # LEEHO - deep young Korean male
 "미라":          ("uyVNoMrnUku1dZyVEXwD", 0.45, 0.30),   # Anna Kim - young Korean female
 "수지상세포":     ("BaW4Cx7nYOh1XNVQBrK2", 0.50, 0.20),   # Seojin - warm clear Korean male
 "리보솜":        ("Mx48CWClvl522or3Frvp", 0.70, 0.05),   # JI HOON - calm (machine-like)
 "혼합기":        ("Mx48CWClvl522or3Frvp", 0.75, 0.05),   # JI HOON
 "T세포":         ("v1jVu1Ky28piIPEJqRrm", 0.40, 0.40),   # KKC RADIO - young energetic Korean male
 "암세포":        ("N2lVS1w4EtoT3dr4eOWO", 0.35, 0.55),   # Callum - husky trickster (multilingual)
 "TRIM25":       ("pNInz6obpgDQGcFmaJgB", 0.40, 0.45),   # Adam - dominant, firm (multilingual)
 "엑소뉴클레아제":  ("IKne3meq5aSn9XLyUdCD", 0.35, 0.55),   # Charlie - energetic (multilingual)
}
ALIASES = {"해설(두루마리)": "해설", "해설(혼합기)": "혼합기", "수지상세포(리보솜 목소리)": "리보솜",
           "T세포(활성화)": "T세포", "TRIM25·엑소뉴클레아제": "TRIM25"}

SUBS = [(r"5[′']", "5 프라임"), (r"3[′']", "3 프라임"), (r"\bmRNA\b", "엠알엔에이"), (r"\bRNA\b", "알엔에이"), (r"\bDNA\b", "디엔에이"),
        (r"\bUTR\b", "유티알"), (r"A·U·G", "에이 유 지"), (r"G·C·U", "지 씨 유"), (r"U·G·G", "유 지 지"), (r"\bAUG\b", "에이 유 지"),
        (r"\bORF\b", "오알에프"), (r"\bLNP\b", "엘엔피"), (r"MHC-I", "엠에이치씨 원"), (r"\bMHC\b", "엠에이치씨"), (r"PD-L1", "피디 엘 원"),
        (r"\bTCR\b", "티씨알"), (r"CCL19", "씨씨엘 19"), (r"CCR7", "씨씨알 7"), (r"\bpH\b", "피에이치"), (r"\bDSPC\b", "디에스피씨"),
        (r"PEG-지질", "페그 지질"), (r"IL-12", "아이엘 12"), (r"IL-10", "아이엘 10"), (r"CD28", "씨디 28"), (r"CD80/86", "씨디 80, 86"),
        (r"TRIM25", "트림 25"), (r"m1Ψ\(엠원-슈도유리딘\)", "엠원 슈도유리딘"), (r"m1Ψ", "엠원 슈도유리딘"), (r"폴리\(A\)", "폴리 에이"),
        (r"\bA… A… A…", "에이… 에이… 에이…"), (r"\bA\b(?= 카드)", "에이"), (r"(\d+)나노미터", r"\1 나노미터"), (r"\bnm\b", "나노미터"),
        (r"\bX\b", "엑스"), (r"·", ", "), (r"…", ", "), (r"\s+", " ")]
def spoken(t):
    t = re.sub(r"\([^()]*[가-힣][^()]*\)", " ", t)       # drop Korean stage notes in parentheses, keep 폴리(A)
    for p, r in SUBS: t = re.sub(p, r, t)
    return t.strip(" ,")

def parse_script():
    lines, scene = [], ""
    for raw in open(SCRIPT, encoding="utf-8").read().split("\n"):
        if raw.startswith("## "): scene = raw[3:].strip(); continue
        if raw.startswith("## 등장인물") or not scene or scene.startswith(("등장인물", "주요 소품")): continue
        m = re.match(r"\*\*(.+?)\*\*\s*(.*)", raw)
        if not m: continue
        sp, text = m.group(1).strip(), m.group(2).strip()
        role = ALIASES.get(sp, sp)
        if role not in VOICES or not text: continue
        lid = hashlib.md5((role + "|" + text).encode("utf-8")).hexdigest()[:12]
        lines.append({"id": lid, "speaker": sp, "role": role, "text": text, "scene": scene})
    return lines

def duration(path):
    try: return round(float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).decode().strip()), 2)
    except Exception: return None

lines = parse_script()
print("lines", len(lines), "chars", sum(len(l["text"]) for l in lines), flush=True)
force = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == "--force" else None
manifest = json.load(open(OUT + "/manifest.json", encoding="utf-8")) if os.path.exists(OUT + "/manifest.json") else {}
if not KEY: sys.exit("set EL=<elevenlabs key>")
ok = fail = 0
for l in lines:
    path = "%s/%s.mp3" % (OUT, l["id"])
    if force and l["role"] == force and os.path.exists(path): os.remove(path)
    vid, stab, style = VOICES[l["role"]]
    if os.path.exists(path) and os.path.getsize(path) > 1000:
        ok += 1
    else:
        body = json.dumps({"text": spoken(l["text"]), "model_id": "eleven_multilingual_v2", "language_code": "ko",
                           "voice_settings": {"stability": stab, "similarity_boost": 0.8, "style": style, "use_speaker_boost": True}}).encode()
        done = False
        for attempt in range(4):
            req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % vid, data=body,
                                         headers={"xi-api-key": KEY, "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=120) as r: data = r.read()
                open(path, "wb").write(data); ok += 1; done = True; print("ok", l["role"], l["id"], len(data), flush=True); break
            except urllib.error.HTTPError as e:
                msg = e.read()[:200]; print("HTTP", e.code, l["role"], msg, flush=True)
                if e.code == 429: time.sleep(5 * (attempt + 1)); continue
                if e.code == 400 and b"language_code" in msg:   # voice/model without language support: retry without it
                    body = json.dumps({**json.loads(body), "language_code": None}).encode(); continue
                break
            except Exception as e: print("ERR", l["role"], e, flush=True); time.sleep(3)
        if not done: fail += 1; continue
    manifest[l["id"]] = {"speaker": l["speaker"], "role": l["role"], "voice": vid, "text": l["text"], "scene": l["scene"], "duration": duration(path)}
json.dump(manifest, open(OUT + "/manifest.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("DONE ok=%d fail=%d manifest=%d" % (ok, fail, len(manifest)), flush=True)
