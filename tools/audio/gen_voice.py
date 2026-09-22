import json, os, re, sys, time, hashlib, urllib.request
KEY = os.environ["EL"]
OUT = "assets/voice"; os.makedirs(OUT, exist_ok=True)
VOICES = {"Scroll":"JBFqnCBsd6RMkjVDRZzb", "Arin":"SOYHLrjzK2X1ezoPC6cr", "Mira":"cgSgspJ2msm6clMCkdW9",
          "Synthesizer":"onwK4e9ZLuTAKqWW03F9", "Mixer":"CwhRBWXzGAHq8TQ4Fs17", "Cell":"N2lVS1w4EtoT3dr4eOWO",
          "Ribosome":"nPczCjzI2devNBz1zQrb", "":"Xb7hH8MSUJpSbSDYk0k2"}
DEFAULT = "Xb7hH8MSUJpSbSDYk0k2"
lines = json.load(open(sys.argv[1], encoding="utf-8"))
lines = [l for l in lines if not re.fullmatch(r"[a-z_0-9]+", l["speaker"])]
comps = {"cap5":("5′ Cap","Protects the mRNA and helps ribosomes find the start."),
 "utr5":("5′ UTR","Untranslated region that tunes how efficiently mRNA is read."),
 "start_codon":("Start Codon","AUG — where translation begins."),
 "orf":("Antigen ORF","Open reading frame coding the tumor antigen."),
 "stop_codon":("Stop Codon","Signals the ribosome to release the finished protein."),
 "utr3":("3′ UTR","Untranslated region controlling mRNA stability."),
 "polya":("Poly(A) Tail","A tail of adenines that stabilizes the mRNA."),
 "lnp":("Lipid Nanoparticle","Delivery vehicle that protects and carries the mRNA."),
 "antibody":("Antibody","Immune protein that recognizes the presented antigen."),
 "ribosome":("Ribosome","Molecular machine that reads mRNA into protein.")}
for n, b in comps.values():
    lines.append({"speaker":"Arin","text":"The %s!" % n}); lines.append({"speaker":"Scroll","text":b})
for h in ["The gate is sealed. Collect all 7 components and operate the Synthesizer first.", "The way is not open yet."]:
    lines.append({"speaker":"","text":h})
seen=set(); uniq=[]
for l in lines:
    k=l["speaker"]+"|"+l["text"]
    if k in seen: continue
    seen.add(k); l["id"]=hashlib.md5(k.encode("utf-8")).hexdigest()[:12]; uniq.append(l)
SUBS = [(r"5[′']", "five-prime"), (r"3[′']", "three-prime"), (r"\bmRNA\b", "m-R-N-A"), (r"\bRNA\b", "R-N-A"),
 (r"poly\(A\)", "poly-A"), (r"\bUTRs?\b", "U-T-R"), (r"\bAUG\b", "A-U-G"), (r"\bORF\b", "O-R-F"), (r"\bLNPs?\b", "L-N-P"),
 (r"\bMHC(-I+)?\b", "M-H-C"), (r"PD-L1", "P-D-L-1"), (r"PD-1", "P-D-1"), (r"CD28", "C-D-28"), (r"CD80/86", "C-D-80 and 86"),
 (r"IL-12", "I-L-12"), (r"\bTCRs?\b", "T-C-R"), (r"CCR7", "C-C-R-7"), (r"CCL19", "C-C-L-19"), (r"RNases", "R-N-ases"), (r"RNase", "R-N-ase"),
 (r"\bpH\b", "p-H"), (r"\bDCs?\b", "D-C"), (r"\bSPACE\b", "space"), (r"\bJUMP\b", "jump"), (r"\bIN ORDER\b", "in order"),
 (r"[—–→]", ", "), (r"\bDSPC\b", "D-S-P-C"), (r"\bPDI\b", "P-D-I"), (r"\bnm\b", "nanometres"), (r"mL/min", "millilitres per minute"), (r"\bPEG-lipid", "peg-lipid"), (r"STEP (\d) - ", r"Step \1. "), (r"\bE\b(?= key| or| to)", "the E key")]
def norm(t):
    for p, r in SUBS: t = re.sub(p, r, t)
    return re.sub(r"\s+", " ", t).strip()
manifest = {}
if os.path.exists(OUT+"/manifest.json"): manifest = json.load(open(OUT+"/manifest.json", encoding="utf-8"))
manifest.update({l["id"]:{"speaker":l["speaker"],"text":l["text"]} for l in uniq})
json.dump(manifest, open(OUT+"/manifest.json","w",encoding="utf-8"), ensure_ascii=False, indent=1)
print("lines", len(uniq), "chars", sum(len(l["text"]) for l in uniq), flush=True)
done=fail=0
for i, l in enumerate(uniq):
    path = "%s/%s.mp3" % (OUT, l["id"])
    if os.path.exists(path) and os.path.getsize(path) > 1000: done+=1; continue
    body = json.dumps({"text": norm(l["text"]), "model_id":"eleven_multilingual_v2",
        "voice_settings":{"stability":0.5,"similarity_boost":0.8,"style":0.15,"use_speaker_boost":True}}).encode()
    vid = VOICES.get(l["speaker"], DEFAULT)
    for attempt in range(4):
        req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_22050_32" % vid, data=body,
              headers={"xi-api-key":KEY,"Content-Type":"application/json"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r: data = r.read()
            open(path,"wb").write(data); done+=1
            print("%3d/%d ok %s %-12s %s" % (i+1, len(uniq), l["id"], l["speaker"], l["text"][:50]), flush=True); break
        except urllib.error.HTTPError as e:
            msg = e.read()[:200]; print("HTTP", e.code, msg, flush=True)
            if e.code == 429: time.sleep(5*(attempt+1)); continue
            fail+=1; break
        except Exception as e:
            print("ERR", e, flush=True); time.sleep(3)
    else: fail+=1
print("DONE ok=%d fail=%d" % (done, fail), flush=True)
