extends CanvasLayer
## Mini-game: the T-cell chamber of the lymph node. The dendritic cell (with
## the prince aboard) presents the tumor antigen on MHC. Naive T-cells drift
## by, each with a differently shaped T-cell receptor (TCR). The player tests
## T-cells until one TCR fits the peptide–MHC "key"; then the immunological
## synapse forms (Signal 1 recognition, Signal 2 co-stimulation, adhesion ring,
## Signal 3 cytokines), the T-cell activates and clones itself.
## Controls: tap a T-cell (touch/mouse) or ←/→ + E. Emits `finished(success)`.
## All timing from _process (web-safe: no tween callbacks).

signal finished(success: bool)

const BW := 720.0
const DC_POS := Vector2(360, 960)
const KEY_POS := Vector2(360, 790)       # peptide–MHC on the DC surface
const DOCK_POS := Vector2(360, 640)      # where a tested T-cell docks
const CLUSTER_C := Vector2(360, 430)
const KEY_PATTERN := [2, 3, 1, 2]

enum Phase { SCREEN, APPROACH, TEST, REJECT, MATCH, SYNAPSE, ACTIVATE, CLONE, DONE }

var debug_autoplay := false

var root: Control
var frame: Control
var stage: Control
var caption: Label
var banner: Label
var title: Label
var dc_sprite: Sprite2D
var tex_naive: Texture2D
var tex_active: Texture2D

var cells: Array = []        # [{pos, home, pattern, tested, spr, alpha}]
var _sel := 0
var _active_i := -1
var _phase: int = Phase.SCREEN
var _pt := 0.0               # time in phase
var _t := 0.0
var _tries := 0
var _touch_id := -100
var _syn_stage := -1
var particles: Array = []    # [{p, v, life, c}]
var clones: Array = []       # [{spr, from, to}]
var _gen := 0
var _gen_t := 0.0
var _rng := RandomNumberGenerator.new()
var _hint_shake := 0.0
var clue: CluePanel
var _clues: Dictionary = {}
var _reveal_t := 0.0         # seconds the matching cell glows after the clue closes
const CLUES_PATH := "res://assets/help/tcell_clues.json"

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("minigame")
	_rng.seed = 7
	_build()

# --------------------------------------------------------------------------
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.03, 0.07, 1.0)
	root.add_child(bg)
	frame = Control.new()
	frame.anchor_left = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -BW / 2.0
	frame.offset_right = BW / 2.0
	frame.offset_top = -640
	frame.offset_bottom = 640
	root.add_child(frame)
	var bgp := "res://assets/env/lymph_bg.png"
	if ResourceLoader.exists(bgp):
		var tr := TextureRect.new()
		tr.texture = load(bgp)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2(0, 120)
		tr.size = Vector2(BW, 1000)
		tr.modulate = Color(0.55, 0.5, 0.55)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)

	title = _add_label(frame, Vector2(20, 26), BW - 40, "The Knights' Chamber", 38, Color(1, 0.95, 0.75))
	_add_label(frame, Vector2(20, 78), BW - 40, "Find the Knight (T-cell) whose lock fits the Enemy's Face", 19, Color(0.75, 0.9, 1.0))

	stage = Stage.new()
	stage.mg = self
	stage.position = Vector2.ZERO
	stage.size = Vector2(BW, 1280)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stage)

	tex_naive = _load("res://assets/env/tcell_naive.png")
	tex_active = _load("res://assets/env/tcell_active.png")

	dc_sprite = Sprite2D.new()
	var dtex := _load("res://assets/env/dc_rider.png")
	if dtex:
		dc_sprite.texture = dtex
		var s := dtex.get_size()
		dc_sprite.scale = Vector2.ONE * (250.0 / max(s.x, s.y))
	dc_sprite.position = DC_POS
	dc_sprite.z_index = 1
	stage.add_child(dc_sprite)

	# naive T-cells with distinct TCR patterns; exactly one matches the key
	var homes := [Vector2(110, 300), Vector2(360, 250), Vector2(610, 300), Vector2(140, 500), Vector2(580, 500), Vector2(250, 640), Vector2(470, 640)]
	var match_i := _rng.randi_range(0, homes.size() - 1)
	var used := [KEY_PATTERN]
	for i in homes.size():
		var pat: Array
		if i == match_i:
			pat = KEY_PATTERN.duplicate()
		else:
			while true:
				pat = [_rng.randi_range(1, 3), _rng.randi_range(1, 3), _rng.randi_range(1, 3), _rng.randi_range(1, 3)]
				if not used.has(pat):
					break
			used.append(pat)
		var spr := Sprite2D.new()
		if tex_naive:
			spr.texture = tex_naive
			var s := tex_naive.get_size()
			spr.scale = Vector2.ONE * (96.0 / max(s.x, s.y))
		spr.position = homes[i]
		spr.z_index = 2
		stage.add_child(spr)
		cells.append({"pos": homes[i], "home": homes[i], "pattern": pat, "tested": false, "spr": spr, "ph": _rng.randf() * TAU, "alpha": 1.0})

	caption = _add_label(frame, Vector2(20, 1130), BW - 40, "", 21, Color(0.95, 0.95, 0.8))
	banner = _add_label(frame, Vector2(20, 112), BW - 40, "", 26, Color(0.6, 1.0, 0.7))
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 52)
	close.position = Vector2(BW - 64, 16)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_on_close)
	frame.add_child(close)
	if FileAccess.file_exists(CLUES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CLUES_PATH))
		if parsed is Dictionary:
			_clues = parsed
	clue = CluePanel.create(frame, BW, str(_clues.get("title", "Clue")))
	clue.changed.connect(_on_clue_changed)
	CluePanel.add_button(frame, BW, 1086, func(): clue.toggle(clue_text()))
	_set_phase(Phase.SCREEN)

## F1 clue (assets/help/tcell_clues.json). Closing it reveals the matching
## T-cell with a green glow for a few seconds.
func clue_text() -> String:
	return str(_clues.get("screen" if _phase == Phase.SCREEN else "wait", ""))

func _on_clue_changed(open: bool) -> void:
	if not open and _phase == Phase.SCREEN:
		_reveal_t = 6.0
	DebugConsole.dlog("tcell clue %s" % ("open" if open else "closed"))

func match_index() -> int:
	for i in cells.size():
		if cells[i]["pattern"] == KEY_PATTERN:
			return i
	return -1

func _load(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null

func _add_label(parent: Control, pos: Vector2, w: float, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, 0)
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _on_close() -> void:
	_finish(false)

# --------------------------------------------------------------------------
func _set_phase(p: int) -> void:
	if p == Phase.MATCH:
		AudioManager.sfx("lock")
	elif p == Phase.REJECT:
		AudioManager.sfx("wrong")
	elif p == Phase.ACTIVATE:
		AudioManager.sfx("mg_start")
	_phase = p
	_pt = 0.0
	DebugConsole.dlog("TCell phase %d" % p)
	match p:
		Phase.SCREEN:
			caption.text = "Every Knight hangs a lock with its own shape. Find the one that fits the orange Enemy's Face. Tap a Knight to test it." if _tries == 0 else "No fit. Only the Knight with the matching lock knows this enemy. Try another."
		Phase.APPROACH:
			caption.text = "The Knight climbs onto the Scout Cell and tries its lock on the Enemy's Face..."
		Phase.REJECT:
			caption.text = "No fit! The lock is the wrong shape. This Knight shrugs and walks away."
		Phase.MATCH:
			caption.text = "A perfect fit! This Knight knows the enemy. That is Handshake 1 of 3."
			banner.text = "The lock fits!"
		Phase.SYNAPSE:
			caption.text = "Now the Three Handshakes. The Knight and the Scout hold on tight."
			_syn_stage = -1
		Phase.ACTIVATE:
			caption.text = "Awake! The Knight sends itself a 'grow!' message (IL-2) and gets ready to copy itself."
			banner.text = "The Knight wakes up!"
			var c: Dictionary = cells[_active_i]
			if tex_active:
				c["spr"].texture = tex_active
				var s := tex_active.get_size()
				c["spr"].scale = Vector2.ONE * (110.0 / max(s.x, s.y))
		Phase.CLONE:
			caption.text = "The Knight splits in two, again and again. Every copy carries the very same lock."
			banner.text = "Copy Army (clonal expansion)"
			_gen = 0
			_gen_t = 0.0
			var c: Dictionary = cells[_active_i]
			clones = [{"spr": c["spr"], "from": c["pos"], "to": CLUSTER_C}]
		Phase.DONE:
			caption.text = "An army of Knights, all trained to spot Mira's cancer, marches off to hunt the tumor."
			banner.text = "The Knight army is ready!"

func _begin_test(i: int) -> void:
	if _phase != Phase.SCREEN or cells[i]["tested"]:
		_hint_shake = 0.4
		return
	_active_i = i
	_tries += 1
	_set_phase(Phase.APPROACH)

# --------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if clue.handle_input(event, clue_text):
		get_viewport().set_input_as_handled()
		return
	if clue.is_open or _phase != Phase.SCREEN:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("move_left") or event.is_action("ui_left"):
			_sel = _next_untested(_sel, -1)
			get_viewport().set_input_as_handled()
		elif event.is_action("move_right") or event.is_action("ui_right") or event.is_action("move_down") or event.is_action("move_up"):
			_sel = _next_untested(_sel, 1)
			get_viewport().set_input_as_handled()
		elif event.is_action("interact") or event.is_action("ui_accept"):
			_begin_test(_sel)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_tap(event.position)

func _next_untested(from: int, dir: int) -> int:
	var i := from
	for _k in cells.size():
		i = posmod(i + dir, cells.size())
		if not cells[i]["tested"]:
			return i
	return from

func _tap(screen_pos: Vector2) -> void:
	var local := screen_pos - stage.global_position
	var best := -1
	var best_d := 70.0
	for i in cells.size():
		var d: float = local.distance_to(cells[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_sel = best
		_begin_test(best)

# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_pt += delta
	_hint_shake = maxf(0.0, _hint_shake - delta)
	_reveal_t = maxf(0.0, _reveal_t - delta)
	# idle drift for cells at home
	for i in cells.size():
		var c: Dictionary = cells[i]
		if i != _active_i:
			c["pos"] = c["home"] + Vector2(sin(_t * 0.9 + c["ph"]) * 8.0, cos(_t * 1.1 + c["ph"]) * 6.0)
		c["spr"].position = c["pos"]
		c["spr"].modulate = Color(0.55, 0.55, 0.6, c["alpha"]) if c["tested"] else Color(1, 1, 1, c["alpha"])
	match _phase:
		Phase.SCREEN:
			if debug_autoplay and _pt > 1.5:
				for i in cells.size():
					if cells[i]["pattern"] == KEY_PATTERN:
						_begin_test(i)
		Phase.APPROACH:
			var c: Dictionary = cells[_active_i]
			var f: float = clampf(_pt / 0.9, 0.0, 1.0)
			f = 1.0 - pow(1.0 - f, 3)
			c["pos"] = c["home"].lerp(DOCK_POS, f)
			if _pt > 1.0:
				_set_phase(Phase.TEST)
		Phase.TEST:
			var c: Dictionary = cells[_active_i]
			c["pos"] = DOCK_POS + Vector2(sin(_pt * 28.0) * 3.0, sin(_pt * 9.0) * 6.0 + 6.0)
			if _pt > 1.1:
				if c["pattern"] == KEY_PATTERN:
					_burst(DOCK_POS + Vector2(0, 60), 26, Color(1.0, 0.95, 0.4))
					_set_phase(Phase.MATCH)
				else:
					_burst(DOCK_POS + Vector2(0, 60), 14, Color(1.0, 0.35, 0.3))
					c["tested"] = true
					_set_phase(Phase.REJECT)
		Phase.REJECT:
			var c: Dictionary = cells[_active_i]
			var f: float = clampf(_pt / 0.8, 0.0, 1.0)
			c["pos"] = DOCK_POS.lerp(c["home"], f) + Vector2(sin(_pt * 40.0) * (1.0 - f) * 6.0, 0)
			if _pt > 1.3:
				_active_i = -1
				_sel = _next_untested(_sel, 1)
				_set_phase(Phase.SCREEN)
		Phase.MATCH:
			var c: Dictionary = cells[_active_i]
			c["pos"] = DOCK_POS + Vector2(0, 10)
			if _pt > 2.2:
				_set_phase(Phase.SYNAPSE)
		Phase.SYNAPSE:
			for i in cells.size():
				if i != _active_i:
					cells[i]["alpha"] = move_toward(cells[i]["alpha"], 0.0, delta * 1.5)
			var st := int(_pt / 2.6)
			if st != _syn_stage and st < SYN_CAPTIONS.size():
				_syn_stage = st
				caption.text = SYN_CAPTIONS[st]
			if _syn_stage == 3 and fmod(_pt, 0.12) < delta:
				_emit(KEY_POS + Vector2(_rng.randf_range(-70, 70), -20), Vector2(_rng.randf_range(-20, 20), -90), Color(1.0, 0.6, 0.9))
			if _pt > 2.6 * SYN_CAPTIONS.size() + 0.6:
				_set_phase(Phase.ACTIVATE)
		Phase.ACTIVATE:
			var c: Dictionary = cells[_active_i]
			c["pos"] = DOCK_POS.lerp(CLUSTER_C, clampf((_pt - 1.5) / 1.2, 0.0, 1.0))
			c["spr"].scale = c["spr"].scale.lerp(Vector2.ONE * (130.0 / tex_size(tex_active)), delta * 2.0)
			if fmod(_pt, 0.18) < delta:
				_emit(c["pos"] + Vector2.from_angle(_rng.randf() * TAU) * 60.0, Vector2.from_angle(_rng.randf() * TAU) * 50.0, Color(0.5, 1.0, 0.7))
			if _pt > 3.6:
				_set_phase(Phase.CLONE)
		Phase.CLONE:
			_process_clone(delta)
		Phase.DONE:
			if fmod(_pt, 0.25) < delta:
				_emit(CLUSTER_C + Vector2(_rng.randf_range(-220, 220), _rng.randf_range(-200, 200)), Vector2(0, -40), Color(1.0, 0.95, 0.5))
			if _pt > 4.0:
				_finish(true)
	# particles
	var keep: Array = []
	for pt in particles:
		pt["life"] -= delta
		pt["p"] += pt["v"] * delta
		if pt["life"] > 0.0:
			keep.append(pt)
	particles = keep
	stage.queue_redraw()

const SYN_CAPTIONS := [
	"Handshake 1: the Knight's lock fits the Enemy's Face in the Display Window (MHC).",
	"Handshake 2: a second 'this is real' touch (CD28). Without it, the Knight dozes off.",
	"A grip ring forms around the edge. It holds the two cells tightly together.",
	"Handshake 3: the Scout sends a 'go!' message (IL-12). It tells the Knight what fighter to become.",
]

func tex_size(t: Texture2D) -> float:
	if t == null:
		return 100.0
	var s := t.get_size()
	return max(s.x, s.y)

func _emit(p: Vector2, v: Vector2, c: Color) -> void:
	particles.append({"p": p, "v": v, "life": 1.2, "c": c})

func _burst(p: Vector2, n: int, c: Color) -> void:
	for i in n:
		_emit(p, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60, 160), c)

# ---- clonal expansion: 1 -> 2 -> 4 -> 8 -> 16 --------------------------------
const GEN_TIME := 1.6

func _layout(n: int) -> Array:
	var out: Array = []
	var cols := int(ceil(sqrt(float(n))))
	var rows := int(ceil(float(n) / cols))
	var sp := clampf(560.0 / cols, 70.0, 150.0)
	for i in n:
		var cx := i % cols
		var cy := i / cols
		out.append(CLUSTER_C + Vector2((cx - (cols - 1) / 2.0) * sp, (cy - (rows - 1) / 2.0) * sp * 0.9))
	return out

func _process_clone(delta: float) -> void:
	_gen_t += delta
	var f: float = clampf(_gen_t / GEN_TIME, 0.0, 1.0)
	# first 55%: pinch (mitosis), then split & glide to new layout
	var pinch := 1.0 + 0.35 * sin(clampf(f / 0.55, 0.0, 1.0) * PI)
	var size := clampf(130.0 / pow(1.35, _gen), 48.0, 130.0)
	for c in clones:
		var spr: Sprite2D = c["spr"]
		var g: float = clampf((f - 0.55) / 0.45, 0.0, 1.0)
		g = 1.0 - pow(1.0 - g, 2)
		spr.position = c["from"].lerp(c["to"], g)
		var base := size / tex_size(tex_active)
		spr.scale = Vector2(base * pinch, base / pinch) if f < 0.55 else Vector2(base, base)
	if f >= 0.55 and not clones[0].has("split_done"):
		# split every clone into two
		if _gen < 4:
			var n_new := clones.size() * 2
			var lay := _layout(n_new)
			var new_clones: Array = []
			for i in clones.size():
				var c: Dictionary = clones[i]
				var spr2 := Sprite2D.new()
				spr2.texture = tex_active
				spr2.z_index = 2
				spr2.position = c["spr"].position
				stage.add_child(spr2)
				var p0: Vector2 = c["spr"].position
				new_clones.append({"spr": c["spr"], "from": p0 + Vector2(-8, 0), "to": lay[i * 2], "split_done": true})
				new_clones.append({"spr": spr2, "from": p0 + Vector2(8, 0), "to": lay[i * 2 + 1], "split_done": true})
				_emit(p0, Vector2(0, -30), Color(0.6, 1.0, 0.8))
			clones = new_clones
		else:
			for c in clones:
				c["split_done"] = true
	if _gen_t >= GEN_TIME:
		_gen += 1
		_gen_t = 0.0
		for c in clones:
			c["from"] = c["to"]
			c.erase("split_done")
		if _gen > 4:
			_set_phase(Phase.DONE)

func _finish(success: bool) -> void:
	if success:
		GameState.set_flag("tcell_activated")
	get_tree().paused = false
	finished.emit(success)
	queue_free()

# --------------------------------------------------------------------------
## Everything schematic is drawn here: the pMHC key, each TCR lock, the
## selection ring, the synapse zoom panel, particles.
class Stage extends Control:
	var mg = null
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		if mg == null:
			return
		var ph: int = mg._phase
		# --- pMHC "key" on the DC surface ---
		_draw_mhc_key(mg.KEY_POS, mg.KEY_PATTERN)
		# --- TCR locks under each T-cell ---
		for i in mg.cells.size():
			var c: Dictionary = mg.cells[i]
			if c["alpha"] <= 0.02 or (i == mg._active_i and ph >= mg.Phase.ACTIVATE):
				continue
			var p: Vector2 = c["pos"]
			var tested: bool = c["tested"]
			var col := Color(0.5, 0.55, 0.6, c["alpha"]) if tested else Color(0.35, 0.6, 1.0, c["alpha"])
			var docked: bool = (i == mg._active_i) and (ph == mg.Phase.TEST or ph == mg.Phase.MATCH or ph == mg.Phase.SYNAPSE)
			_draw_tcr(p + Vector2(0, 46), c["pattern"], col, docked and ph != mg.Phase.TEST)
			if tested:
				draw_line(p + Vector2(-16, -16), p + Vector2(16, 16), Color(1, 0.4, 0.4, 0.9), 4.0, true)
				draw_line(p + Vector2(16, -16), p + Vector2(-16, 16), Color(1, 0.4, 0.4, 0.9), 4.0, true)
		# selection ring (keyboard) while screening
		if ph == mg.Phase.SCREEN and mg._sel >= 0 and mg._sel < mg.cells.size():
			var sp: Vector2 = mg.cells[mg._sel]["pos"]
			var shake: float = sin(mg._t * 60.0) * 6.0 * mg._hint_shake
			draw_arc(sp + Vector2(shake, 0), 62.0 + sin(mg._t * 4.0) * 3.0, 0.0, TAU, 40, Color(1, 0.95, 0.5, 0.9), 4.0, true)
			draw_string(font, sp + Vector2(-60, -66), tr("tap / E to test"), HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(1, 0.95, 0.6))
		# clue reveal: the matching cell glows green for a few seconds
		if ph == mg.Phase.SCREEN and mg._reveal_t > 0.0:
			var mi: int = mg.match_index()
			if mi >= 0:
				var mp: Vector2 = mg.cells[mi]["pos"]
				var a: float = clampf(mg._reveal_t, 0.0, 1.0)
				var pulse: float = 0.5 + 0.5 * sin(mg._t * 6.0)
				draw_circle(mp, 74.0 + pulse * 6.0, Color(0.3, 1.0, 0.5, 0.18 * a))
				draw_arc(mp, 70.0 + pulse * 6.0, 0.0, TAU, 48, Color(0.4, 1.0, 0.55, 0.95 * a), 5.0, true)
				draw_string(font, mp + Vector2(-70, 118), tr("this lock fits!"), HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(0.6, 1.0, 0.7, a))
		# synapse zoom panel
		if ph == mg.Phase.SYNAPSE:
			_draw_synapse(mg._syn_stage, mg._pt)
		# activation glow
		if ph == mg.Phase.ACTIVATE or ph == mg.Phase.CLONE or ph == mg.Phase.DONE:
			for c in mg.clones if ph != mg.Phase.ACTIVATE else [{"spr": mg.cells[mg._active_i]["spr"]}]:
				var s: Sprite2D = c["spr"]
				var r: float = 60.0 * s.scale.x * mg.tex_size(mg.tex_active) / 130.0 + 12.0
				draw_circle(s.position, r + 6.0 + sin(mg._t * 6.0) * 3.0, Color(1, 0.95, 0.5, 0.13))
		# particles
		for pt in mg.particles:
			var a: float = clampf(pt["life"] / 1.2, 0.0, 1.0)
			var c: Color = pt["c"]
			draw_circle(pt["p"], 4.0 + 3.0 * a, Color(c.r, c.g, c.b, a))

	## Peptide–MHC: a Y-shaped MHC (cream) holding an orange peptide whose top
	## edge is a 4-step "key" profile.
	func _draw_mhc_key(p: Vector2, pattern: Array) -> void:
		var stem_col := Color(0.96, 0.93, 0.7)
		var out := Color(0.15, 0.12, 0.1)
		draw_line(p + Vector2(0, 80), p + Vector2(0, 30), out, 14.0, true)
		draw_line(p + Vector2(0, 80), p + Vector2(0, 30), stem_col, 9.0, true)
		draw_line(p + Vector2(0, 30), p + Vector2(-42, -6), out, 14.0, true)
		draw_line(p + Vector2(0, 30), p + Vector2(42, -6), out, 14.0, true)
		draw_line(p + Vector2(0, 30), p + Vector2(-42, -6), stem_col, 9.0, true)
		draw_line(p + Vector2(0, 30), p + Vector2(42, -6), stem_col, 9.0, true)
		# peptide key: 4 bumps of height pattern[i]
		var w := 18.0
		var x0 := p.x - 2.0 * w
		var pts := PackedVector2Array()
		pts.append(Vector2(x0, p.y + 14))
		for i in 4:
			var h: float = 10.0 * pattern[i]
			pts.append(Vector2(x0 + i * w, p.y + 2 - h))
			pts.append(Vector2(x0 + (i + 1) * w, p.y + 2 - h))
		pts.append(Vector2(x0 + 4 * w, p.y + 14))
		draw_colored_polygon(pts, Color(1.0, 0.55, 0.15))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, out, 3.0, true)
		draw_string(font, p + Vector2(-110, 104), tr("Enemy's Face (antigen)"), HORIZONTAL_ALIGNMENT_CENTER, 220, 15, Color(1, 0.9, 0.7))

	## TCR: two arms coming down from the T-cell to a binding plate whose lower
	## edge has 4 notches of depth pattern[i] (fits the key when equal).
	func _draw_tcr(p: Vector2, pattern: Array, col: Color, glow: bool) -> void:
		var out := Color(0.1, 0.12, 0.2, col.a)
		draw_line(p + Vector2(-16, -12), p + Vector2(-8, 26), out, 10.0, true)
		draw_line(p + Vector2(16, -12), p + Vector2(8, 26), out, 10.0, true)
		draw_line(p + Vector2(-16, -12), p + Vector2(-8, 26), col, 6.0, true)
		draw_line(p + Vector2(16, -12), p + Vector2(8, 26), col, 6.0, true)
		var w := 18.0
		var x0 := p.x - 2.0 * w
		var top := p.y + 24.0
		var pts := PackedVector2Array()
		pts.append(Vector2(x0 - 4, top))
		pts.append(Vector2(x0 + 4 * w + 4, top))
		pts.append(Vector2(x0 + 4 * w + 4, top + 46))
		for i in range(3, -1, -1):
			var d: float = 10.0 * pattern[i]
			pts.append(Vector2(x0 + (i + 1) * w, top + 46))
			pts.append(Vector2(x0 + (i + 1) * w, top + 46 - d))
			pts.append(Vector2(x0 + i * w, top + 46 - d))
			pts.append(Vector2(x0 + i * w, top + 46))
		pts.append(Vector2(x0 - 4, top + 46))
		# the notch plate: hollow where the key must fit
		draw_colored_polygon(pts, Color(col.r * 0.9, col.g * 0.9, col.b, col.a))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, out, 2.5, true)
		if glow:
			draw_circle(p + Vector2(0, 50), 40.0 + sin(mg._t * 8.0) * 4.0, Color(1, 0.95, 0.4, 0.22))

	## Zoomed schematic of the immunological synapse (two membranes, molecules).
	func _draw_synapse(stage_i: int, t: float) -> void:
		var r := Rect2(60, 200, 600, 360)
		draw_rect(r, Color(0.02, 0.02, 0.06, 0.9))
		draw_rect(r, Color(1, 0.95, 0.6, 0.8), false, 3.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 28), tr("Close-up: Three Handshakes (immune synapse)"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color(1, 0.95, 0.75))
		var ty := r.position.y + 90.0     # T-cell membrane
		var dy := r.end.y - 70.0          # DC membrane
		draw_line(Vector2(r.position.x + 10, ty), Vector2(r.end.x - 10, ty), Color(0.3, 0.55, 1.0), 10.0, true)
		draw_line(Vector2(r.position.x + 10, dy), Vector2(r.end.x - 10, dy), Color(0.75, 0.45, 0.95), 10.0, true)
		draw_string(font, Vector2(r.position.x + 14, ty - 20), tr("Knight (T-cell)"), HORIZONTAL_ALIGNMENT_LEFT, 240, 16, Color(0.6, 0.8, 1.0))
		draw_string(font, Vector2(r.position.x + 14, dy + 34), tr("Scout Cell (dendritic cell)"), HORIZONTAL_ALIGNMENT_LEFT, 300, 16, Color(0.9, 0.75, 1.0))
		var cx := r.get_center().x
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		# Signal 1: TCR + pMHC (center)
		if stage_i >= 0:
			_pair(cx, ty, dy, Color(0.35, 0.6, 1.0), Color(1.0, 0.55, 0.15), "lock", "face", 16.0)
			_pair(cx + 44, ty, dy, Color(0.5, 0.8, 1.0), Color(1.0, 0.75, 0.3), "", "", 8.0)
			draw_circle(Vector2(cx, (ty + dy) / 2.0), 14.0 + pulse * 6.0, Color(1, 0.95, 0.5, 0.25))
			draw_string(font, Vector2(cx - 100, ty - 40), tr("Handshake 1"), HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(1, 0.95, 0.5))
		# Signal 2: CD28 – CD80/86
		if stage_i >= 1:
			for sx in [-110.0, 110.0]:
				_pair(cx + sx, ty, dy, Color(0.4, 0.95, 0.6), Color(0.95, 0.85, 0.3), "CD28", "CD80/86", 12.0)
			draw_string(font, Vector2(cx - 220, ty - 40), tr("Handshake 2"), HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(0.6, 1.0, 0.7))
			draw_string(font, Vector2(cx + 20, ty - 40), tr("Handshake 2"), HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(0.6, 1.0, 0.7))
		# adhesion ring: LFA-1 – ICAM-1
		if stage_i >= 2:
			for sx in [-220.0, -180.0, 180.0, 220.0]:
				_pair(cx + sx, ty, dy, Color(0.9, 0.6, 0.6), Color(0.9, 0.6, 0.6), "", "", 7.0)
			draw_string(font, Vector2(r.position.x + 10, dy - 12), tr("grip ring (LFA-1)"), HORIZONTAL_ALIGNMENT_LEFT, 200, 14, Color(1, 0.75, 0.75))
			draw_string(font, Vector2(r.end.x - 210, dy - 12), tr("grip ring (LFA-1)"), HORIZONTAL_ALIGNMENT_RIGHT, 200, 14, Color(1, 0.75, 0.75))
		# Signal 3: cytokines
		if stage_i >= 3:
			for i in 9:
				var ph2: float = fmod(t * 0.6 + i * 0.13, 1.0)
				var px := cx - 150 + i * 36.0 + sin(t * 3.0 + i) * 6.0
				var py: float = lerpf(dy - 12.0, ty + 12.0, ph2)
				draw_circle(Vector2(px, py), 6.0, Color(1.0, 0.6, 0.9, 1.0 - ph2 * 0.6))
			draw_string(font, Vector2(cx - 130, (ty + dy) / 2.0 - 60), tr("Handshake 3: 'go!' (IL-12)"), HORIZONTAL_ALIGNMENT_CENTER, 260, 16, Color(1, 0.7, 0.95))

	func _pair(x: float, ty: float, dy: float, ct: Color, cd: Color, lt: String, ld: String, w: float) -> void:
		var mid := (ty + dy) / 2.0
		draw_line(Vector2(x, ty), Vector2(x, mid - 2), ct, w, true)
		draw_line(Vector2(x, dy), Vector2(x, mid + 2), cd, w, true)
		draw_circle(Vector2(x, mid - 2), w * 0.75, ct)
		draw_circle(Vector2(x, mid + 2), w * 0.75, cd)
		if lt != "":
			draw_string(font, Vector2(x - 40, ty + 30), tr(lt), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(0.85, 0.92, 1.0))
		if ld != "":
			draw_string(font, Vector2(x - 40, dy - 20), tr(ld), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1.0, 0.9, 0.8))

## Live state for browser automation (mirrored to window.__ss.mg by DebugConsole).
func debug_state() -> Dictionary:
	var cs: Array = []
	for c in cells:
		cs.append([c["pos"].x, c["pos"].y, c["pattern"] == KEY_PATTERN, c["tested"]])
	return {"kind": "tcell", "phase": _phase, "fx": frame.global_position.x, "fy": frame.global_position.y,
		"cells": cs, "tries": _tries, "sel": _sel, "match": match_index(), "clue": clue.is_open, "reveal": _reveal_t,
		"clue_ok": [clue.ok_center().x, clue.ok_center().y], "clue_h": clue.size.y}
