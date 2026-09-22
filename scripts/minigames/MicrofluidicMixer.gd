extends CanvasLayer
## Mini-game: make the lipid nanoparticle (LNP) in a staggered-herringbone
## microfluidic mixer.
##  1. LOAD  — drag the four lipids into the ethanol inlet and the mRNA into the
##             pH 4 acetate-buffer inlet.
##  2. SET   — choose the aqueous:ethanol flow-rate ratio (recipe: 3:1) and the
##             total flow rate (fast flow = fast mixing = small particles).
##  3. RUN   — the streams meet, the herringbone grooves fold them together, the
##             protonated ionizable lipid grabs the mRNA and LNPs precipitate.
##             Bad settings give large, polydisperse particles: adjust and rerun.
##  4. BUFFER EXCHANGE — dialysis removes ethanol and raises pH to 7.4.
## Emits `finished(success)`; on success collects the "lnp" item and sets
## "lnp_made". Timing from _process only (web-safe).

signal finished(success: bool)

const BW := 720.0
const TILE := Vector2(112, 96)
enum Phase { LOAD, SET, RUN, RESULT, DIALYSIS, DONE }

const ITEMS := [
	{"id": "ionizable", "name": "Ionizable lipid", "inlet": "organic", "col": Color(1.0, 0.75, 0.2)},
	{"id": "dspc", "name": "DSPC (helper)", "inlet": "organic", "col": Color(1.0, 0.55, 0.35)},
	{"id": "chol", "name": "Cholesterol", "inlet": "organic", "col": Color(0.95, 0.9, 0.5)},
	{"id": "peg", "name": "PEG-lipid", "inlet": "organic", "col": Color(0.7, 0.9, 1.0)},
	{"id": "mrna", "name": "mRNA", "inlet": "aqueous", "col": Color(0.35, 0.7, 1.0)},
]

var debug_autoplay := false

var root: Control
var frame: Control
var stage: Control
var caption: Label
var banner: Label
var tray_tiles: Array = []      # Controls
var inlet_panels: Dictionary = {}   # "organic"/"aqueous" -> Panel
var placed: Dictionary = {"organic": [], "aqueous": []}
var ratio_slider: HSlider
var tfr_slider: HSlider
var ratio_label: Label
var tfr_label: Label
var predict_label: Label
var run_btn: Button
var dial_btn: Button
var set_box: Control
var _grabbed: Control = null
var _grab_off := Vector2.ZERO
var _touch_id := -100
var _phase: int = Phase.LOAD
var _pt := 0.0
var _t := 0.0
var _runs := 0
var result := {}
var _done := false
var _rng := RandomNumberGenerator.new()
var flow_particles: Array = []
var clue: CluePanel
var _clues: Dictionary = {}
const CLUES_PATH := "res://assets/help/mixer_clues.json"

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("minigame")
	_rng.seed = 33
	_build()

# --------------------------------------------------------------------------
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.1, 1.0)
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
	_add_label(frame, Vector2(20, 26), BW - 40, "Microfluidic Mixer", 38, Color(1, 0.95, 0.75))
	_add_label(frame, Vector2(20, 78), BW - 40, "Wrap the mRNA in a lipid nanoparticle", 20, Color(0.75, 0.9, 1.0))

	stage = Stage.new()
	stage.mg = self
	stage.size = Vector2(BW, 1280)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stage)

	# inlets
	inlet_panels["organic"] = _make_panel(frame, Vector2(20, 142), Vector2(330, 250), Color(0.25, 0.18, 0.05, 0.9), Color(1.0, 0.8, 0.3))
	_add_label(inlet_panels["organic"], Vector2(6, 6), 318, "Ethanol inlet (lipids)", 18, Color(1, 0.9, 0.6))
	inlet_panels["aqueous"] = _make_panel(frame, Vector2(370, 142), Vector2(330, 250), Color(0.05, 0.12, 0.28, 0.9), Color(0.4, 0.7, 1.0))
	_add_label(inlet_panels["aqueous"], Vector2(6, 6), 318, "pH 4 acetate buffer inlet", 18, Color(0.7, 0.85, 1.0))

	# tray tiles
	var xs := [20.0, 140.0, 260.0, 380.0, 500.0]
	for i in ITEMS.size():
		var it: Dictionary = ITEMS[i]
		var tile := _make_panel(frame, Vector2(xs[i] + 40, 760), TILE, Color(0.1, 0.13, 0.22, 0.98), Color(0.5, 0.7, 1.0))
		tile.set_meta("id", it["id"])
		tile.set_meta("home", tile.position)
		tile.set_meta("locked", false)
		var ic := Icon.new()
		ic.kind = it["id"]
		ic.col = it["col"]
		ic.position = Vector2(TILE.x / 2.0, 34)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(ic)
		var nm := _add_label(tile, Vector2(2, 62), TILE.x - 4, it["name"], 13, Color(0.9, 0.95, 1.0))
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tray_tiles.append(tile)

	# settings box (hidden until LOAD is done)
	set_box = Control.new()
	set_box.position = Vector2(20, 740)
	set_box.size = Vector2(BW - 40, 300)
	set_box.visible = false
	frame.add_child(set_box)
	ratio_label = _add_label(set_box, Vector2(0, 0), BW - 40, "", 20, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	ratio_slider = _slider(set_box, Vector2(0, 32), 1.0, 5.0, 0.5, 1.5)
	tfr_label = _add_label(set_box, Vector2(0, 80), BW - 40, "", 20, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	tfr_slider = _slider(set_box, Vector2(0, 112), 2.0, 16.0, 1.0, 4.0)
	predict_label = _add_label(set_box, Vector2(0, 160), BW - 40, "", 17, Color(0.8, 0.9, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	run_btn = Button.new()
	run_btn.text = "Run mixer"
	run_btn.position = Vector2((BW - 40) / 2.0 - 110, 220)
	run_btn.custom_minimum_size = Vector2(220, 56)
	run_btn.add_theme_font_size_override("font_size", 24)
	run_btn.pressed.connect(_on_run)
	set_box.add_child(run_btn)
	dial_btn = Button.new()
	dial_btn.text = "Exchange buffer to pH 7.4"
	dial_btn.position = Vector2((BW - 40) / 2.0 - 170, 220)
	dial_btn.custom_minimum_size = Vector2(340, 56)
	dial_btn.add_theme_font_size_override("font_size", 22)
	dial_btn.visible = false
	dial_btn.pressed.connect(_on_dialysis)
	set_box.add_child(dial_btn)

	caption = _add_label(frame, Vector2(20, 1150), BW - 40, "", 20, Color(0.95, 0.95, 0.8))
	banner = _add_label(frame, Vector2(20, 104), BW - 40, "", 21, Color(0.6, 1.0, 0.7))
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 52)
	close.position = Vector2(BW - 64, 16)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func(): _finish(false))
	frame.add_child(close)
	CluePanel.add_button(frame, BW, 1092, toggle_clue)
	_build_clue()
	_set_phase(Phase.LOAD)

## F1 clue: a popup with the ideal formulation for the current step. The
## texts live in assets/help/mixer_clues.json (shared with the voice generator).
func _build_clue() -> void:
	if FileAccess.file_exists(CLUES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CLUES_PATH))
		if parsed is Dictionary:
			_clues = parsed
	clue = CluePanel.create(frame, BW, str(_clues.get("title", "Clue")))

func _clue_key() -> String:
	match _phase:
		Phase.LOAD:
			return "load"
		Phase.SET:
			return "set"
		Phase.RESULT:
			return "finish" if result.get("ok", false) else "set"
		_:
			return "wait"

func clue_text() -> String:
	return str(_clues.get(_clue_key(), ""))

func toggle_clue() -> void:
	if _done:
		return
	if clue.is_open:
		clue.close()
		return
	if _grabbed:
		_grabbed.position = _grabbed.get_meta("home")
		_grabbed.z_index = 0
		_grabbed = null
	clue.open(clue_text())
	DebugConsole.dlog("mixer clue open: %s" % _clue_key())

func _slider(parent: Control, pos: Vector2, lo: float, hi: float, step: float, val: float) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.size = Vector2(BW - 40, 40)
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(BW - 40, 40)
	parent.add_child(s)
	return s

func _make_panel(parent: Control, pos: Vector2, size: Vector2, bgc: Color, border: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.custom_minimum_size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bgc
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = border
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p

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

# --------------------------------------------------------------------------
func _set_phase(p: int) -> void:
	if p == Phase.RUN:
		AudioManager.sfx("cutscene")
	elif p == Phase.DIALYSIS:
		AudioManager.sfx("portal")
	_phase = p
	_pt = 0.0
	DebugConsole.dlog("Mixer phase %d" % p)
	match p:
		Phase.LOAD:
			caption.text = "Drag the four lipids into the ethanol inlet and the mRNA into the pH 4 buffer inlet. Lipids only dissolve in ethanol; mRNA stays in water."
		Phase.SET:
			set_box.visible = true
			run_btn.visible = true
			dial_btn.visible = false
			caption.text = "Recipe: 1 volume lipid–ethanol to 3 volumes mRNA buffer (ratio 3:1). Fast total flow mixes in milliseconds — before lipids can clump."
			banner.text = "" if _runs == 0 else "Adjust the settings and run again"
		Phase.RUN:
			set_box.visible = false
			flow_particles.clear()
			caption.text = "The streams meet. Herringbone grooves fold them over and over; at pH 4 the ionizable lipid is charged (+) and grabs the mRNA (–). As ethanol dilutes, the lipids precipitate into nanoparticles."
		Phase.RESULT:
			set_box.visible = true
			run_btn.visible = not result["ok"]
			dial_btn.visible = result["ok"]
			if result["ok"]:
				banner.text = "LNPs formed: %d nm, PDI %.2f, %d%% mRNA encapsulated" % [result["size"], result["pdi"], result["ee"]]
				caption.text = "Small, uniform particles with the mRNA inside. One step left: the particles still sit in ethanol at pH 4."
			else:
				banner.text = "Poor batch: %d nm, PDI %.2f, %d%% encapsulated" % [result["size"], result["pdi"], result["ee"]]
				caption.text = result["why"]
		Phase.DIALYSIS:
			set_box.visible = false
			caption.text = "Dialysis: ethanol leaves and the pH rises to 7.4. The ionizable lipid turns neutral, so the LNP is gentle in the blood — it will only turn positive again inside the acidic endosome."
		Phase.DONE:
			banner.text = "Lipid nanoparticle ready!"
			caption.text = "The mRNA is packed inside a %d nm lipid shell with a PEG coat. Ready for injection." % result["size"]

func _predict() -> Dictionary:
	var ratio: float = ratio_slider.value
	var tfr: float = tfr_slider.value
	var size := 78.0 + 22.0 * absf(ratio - 3.0) + maxf(0.0, 10.0 - tfr) * 9.0
	var pdi := 0.07 + 0.04 * absf(ratio - 3.0) + maxf(0.0, 10.0 - tfr) * 0.03
	var ee := 95.0 - 6.0 * absf(ratio - 3.0) - maxf(0.0, 10.0 - tfr) * 2.5
	var ok := absf(ratio - 3.0) <= 0.5 and tfr >= 10.0
	var why := ""
	if absf(ratio - 3.0) > 0.5:
		why = "Wrong flow-rate ratio: too much ethanol lets particles fuse and grow; too little leaves lipid behind. Aim for 3:1." if ratio < 3.0 else "Wrong flow-rate ratio: with so much buffer the lipids precipitate unevenly. Aim for 3:1."
	elif tfr < 10.0:
		why = "Too slow: slow mixing gives lipids time to aggregate into big, uneven particles. Raise the total flow rate."
	return {"size": int(round(size)), "pdi": snappedf(pdi, 0.01), "ee": int(round(clampf(ee, 20.0, 99.0))), "ok": ok, "why": why}

func _on_run() -> void:
	if _phase != Phase.SET and _phase != Phase.RESULT:
		return
	_runs += 1
	result = _predict()
	_set_phase(Phase.RUN)

func _on_dialysis() -> void:
	if _phase == Phase.RESULT and result["ok"]:
		_set_phase(Phase.DIALYSIS)

# --------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("hint") and not event.is_echo():
		toggle_clue()
		get_viewport().set_input_as_handled()
		return
	if clue.is_open:
		if event.is_action_pressed("pause"):
			clue.close()
			get_viewport().set_input_as_handled()
		return
	if _phase != Phase.LOAD:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(event.position)
		else:
			_release(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and _touch_id == -100:
			_touch_id = event.index
			_try_grab(event.position)
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -100
			_release(event.position)
	elif event is InputEventMouseMotion and _grabbed:
		_grabbed.global_position = event.position + _grab_off
	elif event is InputEventScreenDrag and _grabbed and event.index == _touch_id:
		_grabbed.global_position = event.position + _grab_off

func _try_grab(pos: Vector2) -> void:
	for tile in tray_tiles:
		if tile.get_meta("locked"):
			continue
		if tile.get_global_rect().has_point(pos):
			_grabbed = tile
			_grab_off = tile.global_position - pos
			tile.z_index = 10
			return

func _release(pos: Vector2) -> void:
	if _grabbed == null:
		return
	var tile := _grabbed
	_grabbed = null
	tile.z_index = 0
	var center: Vector2 = tile.get_global_rect().get_center()
	var target := ""
	for k in inlet_panels.keys():
		if inlet_panels[k].get_global_rect().has_point(center):
			target = k
	_drop(tile, target)

func _drop(tile: Control, target: String) -> void:
	var id: String = tile.get_meta("id")
	var want := ""
	for it in ITEMS:
		if it["id"] == id:
			want = it["inlet"]
	if target == want:
		tile.set_meta("locked", true)
		placed[target].append(id)
		var panel: Panel = inlet_panels[target]
		var n: int = placed[target].size()
		var slot_pos: Vector2 = panel.position + Vector2(12 + ((n - 1) % 2) * (TILE.x + 10), 40 + ((n - 1) / 2) * (TILE.y + 6))
		if target == "aqueous":
			slot_pos = panel.position + Vector2(109, 70)
		tile.position = slot_pos
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.28, 0.16, 0.98)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.4, 1.0, 0.6)
		tile.add_theme_stylebox_override("panel", sb)
		if placed["organic"].size() == 4 and placed["aqueous"].size() == 1:
			_set_phase(Phase.SET)
	else:
		tile.position = tile.get_meta("home")
		if target != "":
			caption.text = ("The %s belongs in the ethanol inlet — lipids are hydrophobic and only dissolve in ethanol." % _name(id)) if want == "organic" else "mRNA is water-soluble and must stay in the acidic aqueous buffer, away from the ethanol."

func _name(id: String) -> String:
	for it in ITEMS:
		if it["id"] == id:
			return it["name"]
	return id

# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_pt += delta
	match _phase:
		Phase.LOAD:
			if debug_autoplay and _pt > 1.0 and fmod(_pt, 0.6) < delta:
				for tile in tray_tiles:
					if not tile.get_meta("locked"):
						var id: String = tile.get_meta("id")
						_drop(tile, "aqueous" if id == "mrna" else "organic")
						break
		Phase.SET, Phase.RESULT:
			ratio_label.text = "Flow-rate ratio (buffer : ethanol) = %.1f : 1" % ratio_slider.value
			tfr_label.text = "Total flow rate = %d mL/min" % int(tfr_slider.value)
			var pr := _predict()
			predict_label.text = "Predicted: ~%d nm, PDI %.2f, %d%% encapsulated" % [pr["size"], pr["pdi"], pr["ee"]]
			if debug_autoplay and _pt > 1.5:
				if _phase == Phase.SET:
					ratio_slider.value = 3.0
					tfr_slider.value = 12.0
					_on_run()
				elif result["ok"]:
					_on_dialysis()
				else:
					ratio_slider.value = 3.0
					tfr_slider.value = 12.0
					_on_run()
		Phase.RUN:
			# spawn flow particles at the inlets
			var rate := 0.02 + 0.06 * (1.0 - clampf(tfr_slider.value / 16.0, 0.0, 1.0))
			if fmod(_pt, rate) < delta:
				var aq := _rng.randf() < ratio_slider.value / (ratio_slider.value + 1.0)
				flow_particles.append({"s": 0.0, "aq": aq, "lane": _rng.randf_range(-1.0, 1.0), "sz": 1.0})
			var speed := 0.12 + 0.02 * tfr_slider.value
			for fp in flow_particles:
				fp["s"] += speed * delta
			flow_particles = flow_particles.filter(func(fp): return fp["s"] < 1.05)
			if _pt > 7.5:
				_set_phase(Phase.RESULT)
		Phase.DIALYSIS:
			if _pt > 6.0:
				_set_phase(Phase.DONE)
		Phase.DONE:
			if _pt > 3.0:
				_finish(true)
	stage.queue_redraw()

func _finish(success: bool) -> void:
	if _done:
		return
	_done = true
	if success:
		Inventory.collect("lnp")
		GameState.set_flag("lnp_made")
	get_tree().paused = false
	finished.emit(success)
	queue_free()

func debug_state() -> Dictionary:
	var tiles: Array = []
	for tile in tray_tiles:
		var r: Rect2 = tile.get_rect()
		tiles.append([tile.get_meta("id"), r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0, tile.get_meta("locked")])
	var inl := {}
	for k in inlet_panels.keys():
		var r: Rect2 = inlet_panels[k].get_rect()
		inl[k] = [r.get_center().x, r.get_center().y]
	var ctl := {}
	if set_box.visible:
		ctl = {"ratio": [set_box.position.x + ratio_slider.position.x, set_box.position.y + ratio_slider.position.y + 20, ratio_slider.size.x, ratio_slider.value],
			"tfr": [set_box.position.x + tfr_slider.position.x, set_box.position.y + tfr_slider.position.y + 20, tfr_slider.size.x, tfr_slider.value],
			"run": [set_box.position.x + run_btn.position.x + 110, set_box.position.y + run_btn.position.y + 28, run_btn.visible],
			"dial": [set_box.position.x + dial_btn.position.x + 170, set_box.position.y + dial_btn.position.y + 28, dial_btn.visible]}
	return {"kind": "mixer", "phase": _phase, "fx": frame.global_position.x, "fy": frame.global_position.y,
		"tiles": tiles, "inlets": inl, "ctl": ctl, "runs": _runs, "result": result, "clue": clue.is_open, "clue_key": _clue_key(),
		"clue_ok": [clue.ok_center().x, clue.ok_center().y], "clue_h": clue.size.y}

# --------------------------------------------------------------------------
class Icon extends Control:
	var kind := ""
	var col := Color.WHITE
	func _draw() -> void:
		var out := Color(0.05, 0.05, 0.1)
		match kind:
			"mrna":
				var pts := PackedVector2Array()
				for i in 13:
					pts.append(Vector2(-36 + i * 6.0, sin(i * 1.1) * 9.0))
				draw_polyline(pts, out, 7.0, true)
				draw_polyline(pts, col, 4.0, true)
			"chol":
				draw_rect(Rect2(-22, -12, 44, 24), out, true)
				draw_rect(Rect2(-20, -10, 40, 20), col, true)
				draw_rect(Rect2(-8, -10, 16, 20), col.darkened(0.2), true)
			"peg":
				draw_circle(Vector2(-14, 0), 12.0, out)
				draw_circle(Vector2(-14, 0), 9.5, col)
				var pts := PackedVector2Array()
				for i in 9:
					pts.append(Vector2(-4 + i * 5.0, sin(i * 1.5) * 6.0))
				draw_polyline(pts, out, 6.0, true)
				draw_polyline(pts, col, 3.0, true)
			_:
				draw_circle(Vector2(-12, 0), 12.0, out)
				draw_circle(Vector2(-12, 0), 9.5, col)
				draw_line(Vector2(-4, -3), Vector2(30, -12), out, 7.0, true)
				draw_line(Vector2(-4, 3), Vector2(30, 12), out, 7.0, true)
				draw_line(Vector2(-4, -3), Vector2(30, -12), col, 4.0, true)
				draw_line(Vector2(-4, 3), Vector2(30, 12), col, 4.0, true)
				if kind == "ionizable":
					draw_string(ThemeDB.fallback_font, Vector2(-20, -14), "+", HORIZONTAL_ALIGNMENT_CENTER, 16, 16, Color(1, 1, 1))

## The chip: two inlets, a Y-junction, a herringbone channel, an outlet.
class Stage extends Control:
	var mg = null
	var font: Font = ThemeDB.fallback_font
	const CH := Rect2(40, 410, 640, 300)   # chip area
	func _channel_point(s: float) -> Vector2:
		# main channel from the junction (s=0) to the outlet (s=1)
		return Vector2(CH.position.x + 150 + s * (CH.size.x - 180), CH.position.y + 160)
	func _draw() -> void:
		if mg == null:
			return
		var ph: int = mg._phase
		# chip body
		draw_rect(CH, Color(0.12, 0.2, 0.28, 0.95))
		draw_rect(CH, Color(0.5, 0.75, 0.9, 0.9), false, 3.0)
		draw_string(font, CH.position + Vector2(10, 22), "Staggered-herringbone microfluidic chip", HORIZONTAL_ALIGNMENT_LEFT, 500, 16, Color(0.75, 0.9, 1.0))
		var j := _channel_point(0.0)
		var o := _channel_point(1.0)
		var in_org := Vector2(CH.position.x + 30, CH.position.y + 80)
		var in_aq := Vector2(CH.position.x + 30, CH.position.y + 240)
		var wall := Color(0.02, 0.04, 0.08)
		# inlet channels
		for pair in [[in_org, Color(1.0, 0.8, 0.3)], [in_aq, Color(0.35, 0.7, 1.0)]]:
			draw_line(pair[0], j, wall, 26.0, true)
		draw_line(j, o, wall, 34.0, true)
		var loaded_org: bool = mg.placed["organic"].size() == 4
		var loaded_aq: bool = mg.placed["aqueous"].size() == 1
		draw_line(in_org, j, Color(1.0, 0.8, 0.3, 0.9 if loaded_org else 0.25), 18.0, true)
		draw_line(in_aq, j, Color(0.35, 0.7, 1.0, 0.9 if loaded_aq else 0.25), 18.0, true)
		draw_string(font, in_org + Vector2(-14, -20), "ethanol + lipids", HORIZONTAL_ALIGNMENT_LEFT, 160, 14, Color(1, 0.9, 0.6))
		draw_string(font, in_aq + Vector2(-14, 34), "pH 4 buffer + mRNA", HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color(0.7, 0.85, 1.0))
		# main channel fill: blend from two-tone to mixed green along s
		var running: bool = ph == mg.Phase.RUN
		var mix_len: float = 0.25 + 0.45 * (1.0 - clampf(mg.tfr_slider.value / 16.0, 0.0, 1.0)) if running or ph >= mg.Phase.RESULT else 1.0
		var segs := 40
		for i in segs:
			var s0 := float(i) / segs
			var s1 := float(i + 1) / segs
			var m: float = clampf(s0 / mix_len, 0.0, 1.0) if (running or ph >= mg.Phase.RESULT) else 0.0
			var top := Color(1.0, 0.8, 0.3, 0.85).lerp(Color(0.45, 0.85, 0.55, 0.9), m)
			var bot := Color(0.35, 0.7, 1.0, 0.85).lerp(Color(0.45, 0.85, 0.55, 0.9), m)
			if not (loaded_org and loaded_aq):
				top.a = 0.2
				bot.a = 0.2
			var a := _channel_point(s0)
			var b := _channel_point(s1)
			draw_line(a + Vector2(0, -6), b + Vector2(0, -6), top, 12.0, false)
			draw_line(a + Vector2(0, 6), b + Vector2(0, 6), bot, 12.0, false)
		# herringbone grooves
		for i in 14:
			var s := 0.08 + i * 0.064
			var p := _channel_point(s)
			var dir := 1.0 if (i / 4) % 2 == 0 else -1.0
			draw_line(p + Vector2(-8 * dir, -13), p + Vector2(0, 0), Color(0, 0, 0, 0.35), 3.0, true)
			draw_line(p + Vector2(0, 0), p + Vector2(-8 * dir, 13), Color(0, 0, 0, 0.35), 3.0, true)
		draw_string(font, o + Vector2(-90, 40), "outlet: LNPs", HORIZONTAL_ALIGNMENT_RIGHT, 180, 14, Color(0.7, 1.0, 0.8))
		# flowing particles during RUN
		if running:
			for fp in mg.flow_particles:
				var s: float = fp["s"]
				var p: Vector2
				var m: float = clampf(s / mix_len, 0.0, 1.0)
				if s < 0.0:
					continue
				var lane: float = fp["lane"]
				var y_off: float = (-8.0 if not fp["aq"] else 8.0) * (1.0 - m) + lane * 10.0 * m
				p = _channel_point(s) + Vector2(0, y_off + sin(s * 40.0 + lane) * 3.0 * (1.0 - m))
				if m < 1.0:
					draw_circle(p, 3.5, Color(1.0, 0.8, 0.3) if not fp["aq"] else Color(0.35, 0.7, 1.0))
				else:
					var grow: float = clampf((s - mix_len) / (1.0 - mix_len), 0.0, 1.0)
					var r: float = 3.0 + 6.0 * grow * (float(mg.result["size"]) / 85.0 if mg.result.has("size") else 1.0)
					draw_circle(p, r + 1.5, Color(0.05, 0.1, 0.05))
					draw_circle(p, r, Color(0.55, 0.95, 0.65))
					if grow > 0.5:
						draw_circle(p, r * 0.4, Color(0.35, 0.7, 1.0))
			# inlet feed particles
			for k in 6:
				var f: float = fmod(mg._t * 0.8 + k * 0.17, 1.0)
				draw_circle(in_org.lerp(j, f), 3.5, Color(1.0, 0.8, 0.3))
				draw_circle(in_aq.lerp(j, f), 3.5, Color(0.35, 0.7, 1.0))
			# pH 4 charge cue
			draw_string(font, j + Vector2(-60, -60), "pH 4: ionizable lipid (+) binds mRNA (–)", HORIZONTAL_ALIGNMENT_LEFT, 360, 14, Color(1, 0.95, 0.7))
		# result / dialysis / done: show a big LNP cross-section
		if ph >= mg.Phase.RESULT:
			var c: Vector2 = Vector2(BW_CENTER, 1000) if ph == mg.Phase.RESULT else Vector2(BW_CENTER, 900)
			if ph == mg.Phase.RESULT and mg.set_box.visible:
				c = Vector2(590, 652)
			_lnp(c, ph, mg._pt)
	const BW_CENTER := 360.0
	func _lnp(c: Vector2, ph: int, t: float) -> void:
		var ok: bool = mg.result.get("ok", false)
		var big: float = 1.0 if (ok or ph != mg.Phase.RESULT) else 1.8
		var r: float = 60.0 * big
		if ph == mg.Phase.RESULT and mg.set_box.visible:
			r = 26.0 * big
		var ph_f: float = 0.0
		if ph == mg.Phase.DIALYSIS:
			ph_f = clampf(t / 5.0, 0.0, 1.0)
		elif ph == mg.Phase.DONE:
			ph_f = 1.0
		# PEG corona
		draw_circle(c, r + 12, Color(0.7, 0.9, 1.0, 0.25))
		# lipid shell
		draw_circle(c, r + 3, Color(0.1, 0.1, 0.05))
		draw_circle(c, r, Color(1.0, 0.8, 0.3))
		# cholesterol flecks + PEG hairs
		for i in 16:
			var ang := i * TAU / 16.0
			draw_line(c + Vector2.from_angle(ang) * (r + 2), c + Vector2.from_angle(ang) * (r + 14), Color(0.7, 0.9, 1.0, 0.8), 2.0, true)
			if i % 3 == 0:
				draw_circle(c + Vector2.from_angle(ang + 0.1) * (r * 0.8), 4.0, Color(0.95, 0.9, 0.5))
		# core: mRNA squiggles + ionizable lipid charge
		draw_circle(c, r * 0.62, Color(0.9, 0.6, 0.25))
		for k in 3:
			var pts := PackedVector2Array()
			for i in 12:
				pts.append(c + Vector2(-r * 0.45 + i * r * 0.08, -r * 0.3 + k * r * 0.3 + sin(i * 1.3 + k) * r * 0.08))
			draw_polyline(pts, Color(0.35, 0.7, 1.0), 3.0, true)
		var charge_a := 1.0 - ph_f
		for i in 6:
			var ang := i * TAU / 6.0 + 0.5
			draw_string(font, c + Vector2.from_angle(ang) * (r * 0.78) + Vector2(-5, 6), "+", HORIZONTAL_ALIGNMENT_CENTER, 12, 16, Color(1, 1, 1, charge_a))
		if not ok and ph == mg.Phase.RESULT:
			draw_circle(c + Vector2(r * 0.9, r * 0.5), r * 0.6, Color(1.0, 0.8, 0.3, 0.9))
			draw_circle(c + Vector2(-r * 0.8, r * 0.6), r * 0.5, Color(1.0, 0.8, 0.3, 0.9))
			draw_string(font, c + Vector2(-120, r + 40), "aggregated, uneven", HORIZONTAL_ALIGNMENT_CENTER, 240, 16, Color(1, 0.6, 0.6))
		if ph == mg.Phase.DIALYSIS or ph == mg.Phase.DONE:
			# pH meter and ethanol bubbles leaving
			var mx := c.x - 200.0
			draw_rect(Rect2(mx, c.y - 90, 30, 180), Color(0.1, 0.1, 0.15))
			var lvl := lerpf(4.0, 7.4, ph_f)
			var h := (lvl - 3.0) / 6.0 * 180.0
			draw_rect(Rect2(mx, c.y + 90 - h, 30, h), Color(1.0, 0.4, 0.3).lerp(Color(0.4, 0.9, 0.6), ph_f))
			draw_string(font, Vector2(mx - 30, c.y + 115), "pH %.1f" % lvl, HORIZONTAL_ALIGNMENT_CENTER, 90, 18, Color(1, 1, 1))
			for i in 8:
				var f := fmod(t * 0.5 + i * 0.125, 1.0)
				var bp := c + Vector2(r + 40 + i * 12.0, 60 - f * 200.0)
				draw_circle(bp, 5.0, Color(1.0, 0.9, 0.6, (1.0 - f) * (1.0 - ph_f)))
			draw_string(font, c + Vector2(r + 30, 80), "ethanol out", HORIZONTAL_ALIGNMENT_LEFT, 120, 14, Color(1, 0.9, 0.7, 1.0 - ph_f))
			draw_string(font, c + Vector2(-120, -r - 30), "neutral, PEG-coated LNP" if ph_f >= 1.0 else "ionizable lipid losing its charge...", HORIZONTAL_ALIGNMENT_CENTER, 240, 16, Color(0.8, 1.0, 0.85))
