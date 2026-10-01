"""Sound effects for the Prince of mRNA play -> play/sfx/<nn>_<name>.mp3 (ElevenLabs sound generation).
Seven cues reuse the game's existing clips in assets/audio/ (copied, no API call).

   EL=<elevenlabs key> python3 tools/play/gen_sfx.py
Existing files are skipped; delete one to regenerate it.
"""
import json, os, shutil, sys, time, urllib.request
KEY = os.environ.get("EL")
OUT = "play/sfx"; os.makedirs(OUT, exist_ok=True)

REUSE = {"05_pickup": "pickup", "06_lock": "lock", "08_portal": "portal", "11_jump": "jump",
         "15_bounce": "bounce", "25_wrong": "wrong", "34_fanfare": "fanfare"}
SFX = {  # name: (prompt, seconds, loopable)
 "01_night_wind_bell":     ("soft night wind through a palace window with a distant single bell tolling, calm, eerie", 12, True),
 "02_cancer_pulse":        ("low ominous slow heartbeat-like pulse with a dark drone, sinister, creeping", 10, True),
 "03_footsteps_run":       ("running footsteps on a stone corridor approaching, echoing, urgent, ends at a stop", 4, False),
 "04_scroll_unroll_magic": ("old parchment scroll unrolling followed by a magical golden sparkle shimmer", 4, False),
 "07_assemble_complete":   ("bright ascending five-note magical completion chime, triumphant, clean", 3, False),
 "09_lab_hum":             ("gentle laboratory ambience, glass bubbling, soft electrical hum, faint liquid drips, sci-fi", 15, True),
 "10_trim25_snarl":        ("monster growl and sniffing, hungry creature snarling, menacing, short", 3, False),
 "12_slip_squeak":         ("cartoon slip, rubbery squeak and a sudden slide, comedic, short", 1.5, False),
 "13_mixer_swirl":         ("two liquids rushing into a glass channel and swirling together, bubbling, rising whoosh", 6, False),
 "14_particle_form":       ("crystalline droplets forming, soft glassy sparkle tinkles, magical condensation", 4, False),
 "16_syringe_inject":      ("medical syringe plunger push and liquid injection, quick, then a soft whoosh dive", 3, False),
 "17_heartbeat_bloodflow": ("steady human heartbeat with rushing blood flow whoosh, inside the body, loopable", 12, True),
 "18_engulf_squish":       ("wet squishy membrane wrapping around an object and sealing, organic, short", 2.5, False),
 "19_acid_bubbling":       ("acid bubbling and fizzing inside a chamber with a slow rising warning beep, tension, loopable", 10, True),
 "20_membrane_burst":      ("wet membrane tearing open with a burst and a splash, release, short", 2, False),
 "21_exo_chomp":           ("fast repeated chomping and crunching bites, creature eating, cartoonish, loopable", 6, True),
 "22_ribosome_typewriter": ("mechanical typewriter keys clacking in rhythm then a bell ding, machine-like", 5, False),
 "23_antigen_present":     ("bright clear shimmer and a soft click as something locks onto a display, magical", 3, False),
 "24_lymph_crowd":         ("crowd of tiny creatures murmuring and bubbling, busy hall ambience, soft, loopable", 15, True),
 "26_activation_surge":    ("energy charging up with rising electric hum ending in a powerful pulse, heroic", 4, False),
 "27_cell_division":       ("rapid repeated wet pops multiplying faster and faster, growing into a swarm, exciting", 7, False),
 "28_army_march":          ("marching army drums and stomping feet building up, determined, short", 6, False),
 "29_tumor_fog_drone":     ("dark foggy drone, low breathing, distant creaks, horror ambience, loopable", 15, True),
 "30_pdl1_shield":         ("metal shield clang blocking a hit, heavy impact, short", 1.5, False),
 "31_antibody_unlock":     ("magical unlock, shield shattering into light with a sparkling release", 3, False),
 "32_perforin_zap":        ("sharp electric zap drilling a hole, sci-fi laser punch, short", 1.5, False),
 "33_apoptosis_burst":     ("balloon-like cell bursting into many scattering wet fragments, dramatic, short", 3, False),
 "35_morning_birds":       ("gentle morning birdsong with a soft breeze and distant palace chimes, peaceful", 10, True),
 "36_memory_bell":         ("warm resonant temple bell ringing once with a long gentle decay, hopeful", 6, False),
}

for name, src in REUSE.items():
    dst = "%s/%s.mp3" % (OUT, name); s = "assets/audio/%s.mp3" % src
    if not os.path.exists(dst) and os.path.exists(s): shutil.copy(s, dst); print("copied", dst)

if not KEY:
    sys.exit("set EL=<elevenlabs key> to generate the %d new effects" % len(SFX))
ok = fail = 0
for name, (prompt, dur, loop) in SFX.items():
    path = "%s/%s.mp3" % (OUT, name)
    if os.path.exists(path) and os.path.getsize(path) > 1000: ok += 1; continue
    body = json.dumps({"text": prompt, "duration_seconds": max(0.5, min(22, dur)),
                       "prompt_influence": 0.5, "loop": loop}).encode()
    for attempt in range(4):
        req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation", data=body,
                                     headers={"xi-api-key": KEY, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r: data = r.read()
            open(path, "wb").write(data); ok += 1; print("ok", name, len(data), flush=True); break
        except urllib.error.HTTPError as e:
            msg = e.read()[:200]; print("HTTP", e.code, name, msg, flush=True)
            if e.code == 429: time.sleep(5 * (attempt + 1)); continue
            fail += 1; break
        except Exception as e:
            print("ERR", name, e, flush=True); time.sleep(3)
    else: fail += 1
print("DONE ok=%d fail=%d" % (ok, fail), flush=True)
