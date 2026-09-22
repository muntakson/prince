import json, os, time, urllib.request
KEY = os.environ["EL"]; OUT = "assets/audio"; os.makedirs(OUT, exist_ok=True)
SFX = {
 "pickup":   ("bright short video game item pickup sparkle chime, 8-bit style, clean", 1.0),
 "jump":     ("short cartoon character jump whoosh, quick rising swoosh, video game", 0.6),
 "leap":     ("longer heroic leap whoosh with a rising tone, video game platformer", 0.9),
 "land":     ("soft thud of a character landing on stone floor, short, video game", 0.5),
 "hurt":     ("short harsh video game damage hit, character gets bitten, retro buzz", 0.6),
 "bounce":   ("springy cartoon boing bounce off a rubber shield, short", 0.6),
 "fall":     ("cartoon falling whistle descending pitch into a pit, short", 1.2),
 "defeat":   ("short sad minor-key video game defeat sting, retro synth", 1.8),
 "respawn":  ("magical shimmer reappear sparkle, video game respawn, short", 1.2),
 "grab":     ("hand gripping a rocky ledge, short cloth scrape and grunt-free grip sound", 0.6),
 "climb":    ("quick scramble climb over a ledge, cloth rustle and a soft thump, short", 0.8),
 "dlg_open": ("soft UI pop, dialogue box opening, gentle, short", 0.4),
 "dlg_next": ("subtle short text blip, video game dialogue advance, soft click", 0.3),
 "ui_click": ("clean modern menu button click, short, video game UI", 0.3),
 "pause":    ("soft swoosh UI panel sliding open, short", 0.5),
 "unpause":  ("soft swoosh UI panel sliding closed, short", 0.5),
 "title":    ("gentle cinematic chapter title reveal sting, warm synth pad swell, short", 2.0),
 "portal":   ("magical portal warp teleport whoosh, sci-fi shimmer, short", 1.5),
 "deny":     ("short negative UI buzz, action not allowed, video game", 0.5),
 "cutscene": ("dreamy sci-fi transition whoosh into a microscopic world, short", 1.5),
 "mg_start": ("bright ascending three-note video game start chime, short", 1.0),
 "mg_win":   ("short triumphant video game success jingle, cheerful synth", 2.0),
 "mg_fail":  ("short video game failure descending tones, gentle, retro", 1.5),
 "fanfare":  ("triumphant orchestral victory fanfare, short, celebratory", 3.0),
 "lock":     ("satisfying mechanical click as a puzzle piece locks into place, short", 0.5),
 "wrong":    ("soft wrong-answer buzzer, short, video game puzzle", 0.5),
 "zap":      ("short electric zap, sci-fi laser hit, video game", 0.5),
 "voice_on": ("two rising soft beeps, toggle on, UI, short", 0.5),
 "voice_off":("two falling soft beeps, toggle off, UI, short", 0.5),
}
ok=fail=0
for name, (prompt, dur) in SFX.items():
    path = "%s/%s.mp3" % (OUT, name)
    if os.path.exists(path) and os.path.getsize(path) > 1000: ok+=1; continue
    body = json.dumps({"text": prompt, "duration_seconds": max(0.5, dur), "prompt_influence": 0.6}).encode()
    for attempt in range(4):
        req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation", data=body, headers={"xi-api-key":KEY,"Content-Type":"application/json"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r: data = r.read()
            open(path,"wb").write(data); ok+=1; print("ok", name, len(data), flush=True); break
        except urllib.error.HTTPError as e:
            msg=e.read()[:200]; print("HTTP", e.code, name, msg, flush=True)
            if e.code == 429: time.sleep(5*(attempt+1)); continue
            fail+=1; break
        except Exception as e: print("ERR", name, e, flush=True); time.sleep(3)
    else: fail+=1
print("DONE ok=%d fail=%d" % (ok, fail), flush=True)
