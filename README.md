# Prince of mRNA

A story-driven educational game (Godot 4.3) that teaches mRNA vaccine science.
Prince Arin rescues Princess Mira, then journeys through a molecular kingdom to
build, protect, deliver, and translate an mRNA cancer vaccine.

Targets: **Desktop, Web (HTML5), Android** (portrait, touch + keyboard).

---

## Current state — Framework skeleton (Milestone 1 ✅)

The full adventure framework is in place and playable end-to-end as a skeleton:

- **Autoload singletons** (`autoload/`): `GameState`, `Inventory`, `SaveManager`,
  `DialogueManager`, `AudioManager`, `SceneManager` (fade transitions + spawns).
- **Player** (`scripts/player/Player.gd`): top-down movement, keyboard **and**
  touch (fed through the same input actions), bounded camera, interaction area.
- **HUD** (`scripts/ui/HUD.gd`, built in code): molecule inventory bar, dialogue
  box with typewriter, chapter title cards, virtual joystick, interact button,
  pause menu (Resume / Save / Main Menu).
- **Six chapters** (`scripts/world/`), each extending `LevelBase`:
  1. **Cave** — reach Mira's chamber.
  2. **Palace** — find Mira, read the mRNA scroll (starts the quest).
  3. **Laboratory** — collect the 7 mRNA components, assemble them at the
     synthesizer (`AssembleMRNA` drag puzzle), then encapsulate the mRNA in the
     `MicrofluidicMixer` mini-game (load lipids/mRNA into the ethanol and pH 4
     buffer inlets, set the 3:1 flow-rate ratio and a fast total flow, watch the
     staggered-herringbone channel form LNPs with size/PDI/encapsulation readouts,
     then exchange the buffer to pH 7.4). Grants the `lnp` item and `lnp_made`,
     which opens the injection door.
  4. **BioWorld** — LNP uptake, endosomal escape, translation, antigen presentation
     (animated `CutsceneStation`s).
  5. **LymphNode** — two mini-games launched from `MinigameStation`s:
     `ChemokineNav` (ride the DC along the CCL19 gradient with CCR7 antennae into a
     lymphatic vessel) and `TCellChamber` (screen naive T-cells' TCRs against the
     antigen key, immunological synapse with Signals 1/2/3 + LFA-1/ICAM-1 ring,
     activation, clonal expansion).
  6. **Tumor** — `TumorHunt` mini-game: pilot a killer T-cell through tumor tissue,
     read each cell's MHC-I peptide (vaccine antigen = tumor, self = healthy), kill
     tumor cells (perforin / granzyme B / apoptosis zoom on the first kill), spare
     healthy ones, beat PD-L1 with the anti-PD-1 antibody pickup while the tumor
     keeps dividing. Then Mira's ending. Sets `story_complete`.
- **Save/Load** to `user://savegame.json` (works on web/Android).
- **Molecule sprites** (`assets/molecules/`): sliced + alpha-keyed from the source
  sprite sheet — the 7 mRNA parts plus LNP, antibody, ribosome.

## Not yet built (next milestones)

All science steps now have mini-games or animated stations. For testing, a web
URL may carry `?flags=a,b` — those story flags are granted when a chapter is picked
from the (debug) Chapter Select menu.

Web builds mirror live state to `window.__ss` (see `autoload/DebugConsole.gd`); the
release build hides the debug overlay unless the URL contains `debug`.

## Running / building

```bash
GODOT=/home/jit/bin/godot                       # Godot 4.3 (headless-capable)

# Import assets after pulling
$GODOT --headless --path . --import

# Play (desktop)
$GODOT --path .

# Export web build -> build/web/index.html
$GODOT --headless --path . --export-release "Web" build/web/index.html

# Headless screenshot of any scene (uses xvfb)
xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 $GODOT --path . tools/ShotRunner.tscn \
  --resolution 720x1280 --rendering-driver opengl3 \
  -- scene=res://scenes/world/Cave.tscn out=/tmp/shot.png wait=100
# add FORCE_TOUCH=1 to show the on-screen touch controls in the shot
```

Android export needs the Godot Android build template + SDK configured; the
preset ("Android", `org.aiedus.princeofmrna`, portrait) is already in
`export_presets.cfg`.

## Controls

- **Move:** WASD / arrow keys, or the on-screen joystick (touch).
- **Interact / advance dialogue:** `E`, or the ✋ button (`Space` also advances dialogue).
- **Jump / leap:** `Space` (also `Shift` / `J`), or the JUMP button. Press while running for a long leap. Hazards on the ground cannot touch the prince while he is in the air.
- **Pause:** `Esc` or the `II` button.
- **Help:** the Help button on the title screen or in the pause menu opens a step-by-step walkthrough of the whole journey (English / 한국어 toggle). Content: `assets/help/help.json`; Korean font: `assets/fonts/help_ko.otf` (Noto Sans CJK KR subset, OFL).

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
