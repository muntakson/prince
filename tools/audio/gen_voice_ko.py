"""Korean voice clips: assets/voice/ko/<id>.mp3 for every line in
assets/help/dialogue_ko.json (same ids as the English clips). Skips existing.
   EL=<elevenlabs key> python3 tools/audio/gen_voice_ko.py
"""
import json, os, re, time, urllib.request
KEY = os.environ["EL"]
OUT = "assets/voice/ko"; os.makedirs(OUT, exist_ok=True)
KO_VOICES = {"Scroll": "aurnUodFzOtofecLd3T1",      # Jung Narrative - Korean male narrator
             "Arin": "dfGdOKe4Py3B2cmOtW1k",        # LEEHO - young Korean male
             "Mira": os.environ.get("KO_FEMALE", "cgSgspJ2msm6clMCkdW9"),  # Korean female if available, else Jessica (multilingual)
             "Synthesizer": "BaW4Cx7nYOh1XNVQBrK2", # Seojin
             "Mixer": "Mx48CWClvl522or3Frvp",       # JI HOON
             "Cell": "v1jVu1Ky28piIPEJqRrm",        # KKC RADIO
             "Ribosome": "BaW4Cx7nYOh1XNVQBrK2",    # Seojin
             "": "Mx48CWClvl522or3Frvp"}            # narrator: JI HOON
SUBS = [(r"5[′']", "5 프라임"), (r"3[′']", "3 프라임"), (r"\bmRNA\b", "엠알엔에이"), (r"\bRNA\b", "알엔에이"),
        (r"\bUTR\b", "유티알"), (r"\bAUG\b", "에이 유 지"), (r"\bORF\b", "오알에프"), (r"\bLNP\b", "엘엔피"),
        (r"\bMHC(-I)?\b", "엠에이치씨"), (r"PD-L1", "피디 엘 원"), (r"\bTCR\b", "티씨알"), (r"CCL19", "씨씨엘 19"), (r"CCR7", "씨씨알 7"),
        (r"\bpH\b", "피에이치"), (r"\bDSPC\b", "디에스피씨"), (r"PEG-지질", "페그 지질"), (r"IL-10", "아이엘 10"), (r"IL-12", "아이엘 12"),
        (r"CD28", "씨디 28"), (r"CD80/86", "씨디 80과 86"), (r"\bPDI\b", "피디아이"), (r"\bnm\b", "나노미터"), (r"mL/min", "분당 밀리리터"),
        (r"\bF1\b", "에프 원"), (r"\bJUMP\b", "점프"), (r"\bE\b(?=를)", "이 키"), (r"\bA와 D\b", "에이와 디"), (r"\(A\)", "에이"), (r"…", ", ")]
def norm(t):
    for p, r in SUBS: t = re.sub(p, r, t)
    return re.sub(r"\s+", " ", t).strip()
data = json.load(open("assets/help/dialogue_ko.json", encoding="utf-8"))
manifest = json.load(open("assets/voice/manifest.json", encoding="utf-8"))
lines = data["lines"]
print("ko lines", len(lines), "chars", sum(len(v) for v in lines.values()), flush=True)
ok = fail = 0
for i, (lid, ko) in enumerate(lines.items()):
    path = "%s/%s.mp3" % (OUT, lid)
    if os.path.exists(path) and os.path.getsize(path) > 1000: ok += 1; continue
    speaker = manifest.get(lid, {}).get("speaker", "")
    vid = KO_VOICES.get(speaker, KO_VOICES[""])
    body = json.dumps({"text": norm(ko), "model_id": "eleven_multilingual_v2",
                       "voice_settings": {"stability": 0.5, "similarity_boost": 0.8, "style": 0.1, "use_speaker_boost": True}}).encode()
    for attempt in range(4):
        req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_22050_32" % vid, data=body,
                                     headers={"xi-api-key": KEY, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r: d = r.read()
            open(path, "wb").write(d); ok += 1; print("%3d/%d ok %s %-12s %s" % (i+1, len(lines), lid, speaker, ko[:30]), flush=True); break
        except urllib.error.HTTPError as e:
            msg = e.read()[:200]; print("HTTP", e.code, msg, flush=True)
            if e.code == 429: time.sleep(5 * (attempt + 1)); continue
            fail += 1; break
        except Exception as e:
            print("ERR", e, flush=True); time.sleep(3)
    else: fail += 1
print("DONE ok=%d fail=%d" % (ok, fail), flush=True)
