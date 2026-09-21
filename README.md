# The Secret Scroll: An mRNA Adventure

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
preset ("Android", `org.aiedus.secretscroll`, portrait) is already in
`export_presets.cfg`.

## Controls

- **Move:** WASD / arrow keys, or the on-screen joystick (touch).
- **Interact / advance dialogue:** `E` or `Space`, or the ✋ button.
- **Pause:** `Esc` or the `II` button.
