# Prince of mRNA

*[한국어 README](README.ko.md)*

A story-driven educational game (Godot 4.3) that teaches mRNA vaccine science.
Prince Arin rescues Princess Mira, then journeys through a molecular kingdom to
build, protect, deliver, and translate an mRNA cancer vaccine.

**Play it:** https://prince.aiedus.org (web build, also at https://prince.iotok.org)

Targets: **Desktop, Web (HTML5), Android** (portrait, touch + keyboard).
Languages: **English / 한국어** (toggle with `F3` or the title-screen button).

Credits: 제작 손문탁 박사, 사단법인 나눔과기술, 2026년 9월 19일
(Dr. Muntak Son, Sharing & Technology Association).

---

## The journey (six chapters)

Each chapter is a scene in `scripts/world/` extending `LevelBase`. The science
steps are played as mini-games (`scripts/minigames/`) or animated cutscene
stations.

1. **Cave** — tutorial: walk, run, leap the crevasse, reach Mira's chamber.
2. **Palace** — find Mira, read the mRNA scroll (starts the quest).
3. **Laboratory** — collect the 7 mRNA components (5' cap, 5' UTR, signal
   peptide, antigen, 3' UTR, poly(A) tail, modified nucleosides), assemble them
   at the synthesizer (`AssembleMRNA` drag puzzle), then encapsulate the mRNA in
   the `MicrofluidicMixer` mini-game: load lipids / mRNA into the ethanol and
   pH 4 buffer inlets, set the 3:1 flow-rate ratio and a fast total flow, watch
   the staggered-herringbone channel form LNPs (size / PDI / encapsulation
   readouts), then exchange the buffer to pH 7.4. RNases hunt the naked mRNA
   until the LNP is made.
4. **BioWorld (the cell)** — LNP uptake by a dendritic cell, endosomal escape
   (`EndosomeTiming`: break out while the ionizable lipid is charged, before the
   lysosome fuses), the poly(A) rush past exonucleases to the ribosome,
   translation and MHC antigen presentation (animated `CutsceneStation`s).
5. **Lymph node** — `ChemokineNav` (ride the dendritic cell along the CCL19
   gradient with CCR7 antennae into a lymphatic vessel) and `TCellChamber`
   (screen naive T-cells' TCRs against the antigen, immunological synapse with
   Signals 1/2/3 and the LFA-1 / ICAM-1 ring, activation, clonal expansion).
6. **Tumor** — `TCellHerd` (lead the T-cell army through Tregs, CAF collagen
   stroma and hypoxia) and `TumorHunt` (pilot a killer T-cell, read each cell's
   MHC-I peptide, kill tumor cells with perforin / granzyme B, spare healthy
   ones, beat PD-L1 with the anti-PD-1 antibody while the tumor keeps
   dividing). Then Mira's ending.

## Controls

- **Move:** WASD / arrow keys, or the on-screen joystick (touch). Hold a
  direction to break into a run; releasing from a run skids to a stop.
- **Interact / advance dialogue:** `E`, or the ✋ button (`Space` also advances).
- **Jump / leap:** `Space` (also `Shift` / `J`), or the JUMP button. A jump while
  running is a long leap. Walking onto a pit edge grabs the ledge: push away or
  jump to climb back, push in to let go. Ground hazards cannot touch the prince
  while he is in the air.
- **Pause:** `Esc` or the `II` button (Resume / Save / Help / Voice / Main Menu).
- **Help:** step-by-step walkthrough of the whole journey, English / 한국어, with a
  Copy button. Content: `assets/help/help.json`.
- **Clues:** `F1` / `H` inside a mini-game opens a science clue panel
  (`assets/help/*_clues.json`).
- **Voice:** `V` toggles voice mode. Every dialogue line has a recorded clip
  (`assets/voice/`, ElevenLabs TTS, one voice per character); when a clip is
  missing the browser / OS speech synthesis reads it. Sound effects live in
  `assets/audio/`. The setting persists in `user://settings.cfg`.
- **Language:** `F3` switches English / Korean. UI strings come from
  `assets/help/ui_ko.json` (loaded into the TranslationServer), dialogue from
  `assets/help/dialogue_ko.json`.

## Hazards

Every chapter after the palace has something hunting the message; the HUD shows a
meter (mRNA integrity / poly(A) tail) while it is at risk, and running out sends
the prince back to the last safe spot with a fresh copy.

| Chapter | Hazard | Science | How to survive |
|---|---|---|---|
| 1 Cave | Crevasse | (tutorial) | Run and press Space / JUMP to leap it |
| 3 Lab | RNases chase the naked mRNA (after assembly) | RNases shred unprotected RNA; the LNP shields it | Leap over them, reach the mixer; after the LNP is made they bounce off |
| 4 Cell | RNases in the tissue | The lipid shell repels them | Nothing to do — watch them bounce |
| 4 Cell | Endosome pH timing (mini-game) | Ionizable lipids (pKa ~6.4) charge below pH 6.6; below pH 5 the lysosome fuses | Break out inside the pH window |
| 4 Cell | Poly(A) rush + exonucleases | Deadenylation shortens the tail; when it is gone the mRNA is decapped and destroyed | Reach the ribosome before the tail meter empties; leap over the exonucleases |
| 6 Tumor | Herd the T-cells (mini-game) | Tregs (IL-10 / TGF-beta), CAF collagen stroma, hypoxia | Keep the herd close, avoid the purple fog, find the gaps, rally suppressed cells |

## Project layout

- `autoload/` — singletons: `GameState` (flags, chapters, language),
  `Inventory`, `SaveManager` (`user://savegame.json`, works on web / Android),
  `DialogueManager`, `AudioManager` (music, SFX, voice, settings),
  `SceneManager` (fade transitions + spawns), `DebugConsole`.
- `scripts/player/Player.gd` — explicit state machine
  (IDLE / WALK / RUN / JUMP / LEAP / FALL / LEDGE_GRAB / HURT); keyboard and
  touch feed the same input actions.
- `scripts/ui/` — HUD (inventory bar, dialogue box with typewriter, chapter
  title cards, virtual joystick, buttons, pause menu), title screen, help
  screen, clue panel.
- `scripts/world/`, `scripts/minigames/` — chapters, stations, mini-games.
- `assets/` — molecule sprites, environment art, cutscene frames, audio, voice,
  help / clue / translation JSON, the bundled font
  `assets/fonts/help_ko.otf` (Noto Sans CJK KR subset, OFL; it is the default
  theme font so Korean renders on the web where there is no system fallback).
- `tools/` — `subset_font.py` (rebuild the font subset from every string in the
  game; run it after changing any Korean text), `ShotRunner.tscn` (headless
  screenshots and scripted mini-game runs), `audio/` (voice / SFX generators).

## Running / building

```bash
GODOT=/home/jit/bin/godot                       # Godot 4.3 (headless-capable)

# Import assets after pulling
$GODOT --headless --path . --import

# Play (desktop)
$GODOT --path .

# Export web build -> build/web/index.html
$GODOT --headless --path . --export-release "Web" build/web/index.html

# Export + deploy to /var/www/prince with content-hashed file names (see DEPLOY.md)
./deploy.sh            # add --import after adding assets

# Rebuild the Korean font subset after editing any Korean text
python3 tools/subset_font.py

# Headless screenshot of any scene (uses xvfb)
xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 $GODOT --path . tools/ShotRunner.tscn \
  --resolution 720x1280 --rendering-driver opengl3 \
  -- scene=res://scenes/world/Cave.tscn out=/tmp/shot.png wait=100
# add FORCE_TOUCH=1 to show the on-screen touch controls in the shot
```

Android export needs the Godot Android build template + SDK configured; the
preset ("Android", `org.aiedus.princeofmrna`, portrait) is already in
`export_presets.cfg`.

## Debugging and testing

- **Chapter Select** on the title screen jumps to any chapter with the story
  flags it needs already granted.
- Web URL parameters: `?chapter=<id>` starts that chapter directly,
  `?flags=a,b` grants extra story flags, `?debug` enables the debug console
  (`DBG` button / `F4` shows the overlay; `--debug-console` does the same on
  desktop).
- Web builds mirror live state (frame, paused, dialogue, player position, active
  mini-game, flags, audio) to `window.__ss` every few frames
  (`autoload/DebugConsole.gd`), so Playwright tests can poll it instead of
  using timers.

See `DEPLOY.md` for the nginx / Cloudflare setup, the hashed-file deploy and the
loading-splash notes.
