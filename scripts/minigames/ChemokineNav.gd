extends CanvasLayer
## Mini-game: ride the dendritic cell to the lymph node by following the
## CCL19 chemokine gradient with its CCR7 "antennae". The concentration is
## shown as drifting chemokine dots (denser near the lymphatic vessel), the
## CCR7 receptors on the DC glow on the side facing the stronger scent, and a
## scent meter reports the local concentration. Tissue cells block the way.
## Controls: WASD / arrows, or press-and-hold anywhere to steer toward the
## pointer (touch + mouse). Emits `finished(success)` and frees itself.
## All timing from _process (web-safe: no tween callbacks).

signal finished(success: bool)

const BW := 720.0
const FIELD := Rect2(20, 150, 680, 960)
const SOURCE := Vector2(360, 195)      # lymphatic vessel mouth (CCL19 source)
const DC_RADIUS := 38.0
const SPEED := 230.0
const N_DOTS := 260
const ANTENNA_ANGLES := [-90.0, -30.0, 30.0, 90.0, 150.0, 210.0]

var debug_autoplay := false

var root: Control
var frame: Control
var field: Control
var banner: Label
var caption: Label
var meter_fill: ColorRect
var meter_label: Label
var dc_sprite: Sprite2D
var vessel_sprite: Sprite2D

var dc_pos := Vector2(360, 1066)
var waypoints: Array = []       # debug autoplay route through the gaps
var dc_vel := Vector2.ZERO
var obstacles: Array = []       # [{p: Vector2, r: float, c: Color}]
var dots: Array = []            # [{p: Vector2, ph: float}]
var _k := {"up": false, "down": false, "left": false, "right": false}
var _pointer_down := false
var _pointer := Vector2.ZERO
var _touch_id := -100
var _t := 0.0
var _done := false
var _win_t := -1.0
var _caption_stage := -1
var _caption_t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("minigame")
	_rng.seed = 20260921
	_build_world()
	_build_ui()

# --------------------------------------------------------------------------
func _build_world() -> void:
	# Rows of tissue cells with one wide gap per row (alternating sides), so a
	# winding corridor always exists from the bottom to the vessel mouth.
	var rows := [[950.0, 560.0], [770.0, 170.0], [590.0, 520.0], [410.0, 200.0], [270.0, 470.0]]
	for row in rows:
		var y: float = row[0]
		var gap_x: float = row[1]
		var x := FIELD.position.x + 40.0
		while x < FIELD.end.x - 30.0:
			var r := _rng.randf_range(38.0, 52.0)
			if absf(x - gap_x) > 80.0 + r:
				var hue := _rng.randf_range(0.02, 0.09)
				obstacles.append({"p": Vector2(x, y + _rng.randf_range(-12, 12)), "r": r, "c": Color.from_hsv(hue, 0.35, 0.95)})
			x += 112.0
		waypoints.append(Vector2(gap_x, y))
	waypoints.append(SOURCE)
	# Chemokine dots: rejection-sample so density follows the gradient.
	while dots.size() < N_DOTS:
		var p := Vector2(_rng.randf_range(FIELD.position.x, FIELD.end.x), _rng.randf_range(FIELD.position.y, FIELD.end.y))
		if _rng.randf() < concentration(p):
			dots.append({"p": p, "ph": _rng.randf() * TAU, "v": Vector2(_rng.randf_range(-6, 6), _rng.randf_range(4, 14))})

func concentration(p: Vector2) -> float:
	# CCL19 spreads from the lymphatic vessel; roughly exponential decay with distance.
	var d := p.distance_to(SOURCE)
	return clampf(exp(-d / 330.0), 0.0, 1.0)

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.03, 0.06, 1.0)
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

	_add_label(frame, Vector2(20, 26), BW - 40, "Follow the Chemokine Trail", 38, Color(1, 0.95, 0.75))
	_add_label(frame, Vector2(20, 78), BW - 40, "The DC's CCR7 antennae sense CCL19 — steer toward the strongest scent", 19, Color(0.75, 0.9, 1.0))

	# tissue backdrop (sibling below the field so the field's drawing sits on top)
	var tex_path := "res://assets/env/tissue_bg.png"
	if ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = FIELD.position
		tr.size = FIELD.size
		tr.modulate = Color(0.8, 0.72, 0.75)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
	# tissue field
	field = Field.new()
	field.mg = self
	field.position = FIELD.position
	field.size = FIELD.size
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	frame.add_child(field)
	# lymphatic vessel mouth sprite (source)
	vessel_sprite = Sprite2D.new()
	var vp := "res://assets/env/vessel_mouth.png"
	if ResourceLoader.exists(vp):
		vessel_sprite.texture = load(vp)
		var s := vessel_sprite.texture.get_size()
		vessel_sprite.scale = Vector2.ONE * (150.0 / max(s.x, s.y))
	vessel_sprite.position = SOURCE - FIELD.position + Vector2(0, -35)
	field.add_child(vessel_sprite)
	# the dendritic cell with the prince on board
	dc_sprite = Sprite2D.new()
	var dp := "res://assets/env/dc_rider.png"
	if ResourceLoader.exists(dp):
		dc_sprite.texture = load(dp)
		var s2 := dc_sprite.texture.get_size()
		dc_sprite.scale = Vector2.ONE * (2.5 * DC_RADIUS / max(s2.x, s2.y))
	dc_sprite.z_index = 2
	field.add_child(dc_sprite)

	# scent meter
	_add_label(frame, Vector2(20, 1128), 200, "CCL19 scent", 20, Color(0.8, 1.0, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	var meter_bg := ColorRect.new()
	meter_bg.position = Vector2(180, 1132)
	meter_bg.size = Vector2(420, 22)
	meter_bg.color = Color(0.1, 0.15, 0.12)
	frame.add_child(meter_bg)
	meter_fill = ColorRect.new()
	meter_fill.position = Vector2(2, 2)
	meter_fill.size = Vector2(0, 18)
	meter_fill.color = Color(0.45, 1.0, 0.6)
	meter_bg.add_child(meter_fill)
	meter_label = _add_label(frame, Vector2(610, 1128), 90, "0%", 20, Color(0.8, 1.0, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)

	caption = _add_label(frame, Vector2(20, 1165), BW - 40, "", 20, Color(0.95, 0.95, 0.8))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner = _add_label(frame, Vector2(20, 112), BW - 40, "", 26, Color(0.6, 1.0, 0.7))

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 52)
	close.position = Vector2(BW - 64, 16)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_on_close)
	frame.add_child(close)
	_set_caption(0)

const CAPTIONS := [
	"Dendritic cells that captured antigen switch on CCR7, a receptor that smells the chemokine CCL19.",
	"The scent grows stronger. Lymphatic vessels and the lymph node release CCL19 and CCL21.",
	"Almost there! CCR7 signalling steers the DC into a lymphatic vessel toward the node.",
	"The dendritic cell squeezes into the vessel — the lymph carries it to the lymph node.",
]

func _set_caption(stage: int) -> void:
	if stage == _caption_stage:
		return
	_caption_stage = stage
	caption.text = CAPTIONS[stage]
	_caption_t = 0.0

func _on_close() -> void:
	_finish(false)

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
func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey:
		for a in ["up", "down", "left", "right"]:
			if event.is_action("move_" + a):
				_k[a] = event.is_pressed()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer_down = event.pressed
		_pointer = event.position
	elif event is InputEventMouseMotion and _pointer_down:
		_pointer = event.position
	elif event is InputEventScreenTouch:
		if event.pressed and _touch_id == -100:
			_touch_id = event.index
			_pointer_down = true
			_pointer = event.position
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -100
			_pointer_down = false
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_pointer = event.position

func _steer() -> Vector2:
	var v := Vector2.ZERO
	if _k["up"]: v.y -= 1
	if _k["down"]: v.y += 1
	if _k["left"]: v.x -= 1
	if _k["right"]: v.x += 1
	if v == Vector2.ZERO and _pointer_down:
		var local := _pointer - field.global_position
		var d := local - dc_pos_local()
		if d.length() > 12.0:
			v = d.normalized()
	if v == Vector2.ZERO and debug_autoplay:
		v = _gradient_dir()
	return v.limit_length(1.0)

func dc_pos_local() -> Vector2:
	return dc_pos - FIELD.position

func _gradient_dir() -> Vector2:
	# debug autoplay: steer through the row gaps, then to the vessel
	while waypoints.size() > 1 and dc_pos.distance_to(waypoints[0]) < 30.0:
		waypoints.pop_front()
	if waypoints.is_empty():
		return (SOURCE - dc_pos).normalized()
	return (waypoints[0] - dc_pos).normalized()

func _process(delta: float) -> void:
	_t += delta
	_caption_t += delta
	if _done:
		if _win_t >= 0.0:
			_win_t += delta
			var f: float = clampf(_win_t / 1.4, 0.0, 1.0)
			dc_pos = dc_pos.lerp(SOURCE + Vector2(0, -40), f)
			dc_sprite.position = dc_pos_local()
			dc_sprite.scale = dc_sprite.scale * (1.0 - 0.9 * delta)
			dc_sprite.modulate.a = 1.0 - f
			if _win_t > 2.4:
				_finish(true)
		field.queue_redraw()
		return
	var s := _steer()
	dc_vel = dc_vel.lerp(s * SPEED, 1.0 - exp(-10.0 * delta))
	dc_pos += dc_vel * delta
	# obstacles: push out
	for o in obstacles:
		var d: Vector2 = dc_pos - o["p"]
		var min_d: float = o["r"] + DC_RADIUS
		if d.length() < min_d:
			dc_pos = o["p"] + d.normalized() * min_d
	dc_pos.x = clampf(dc_pos.x, FIELD.position.x + DC_RADIUS, FIELD.end.x - DC_RADIUS)
	dc_pos.y = clampf(dc_pos.y, FIELD.position.y + DC_RADIUS, FIELD.end.y - DC_RADIUS)
	dc_sprite.position = dc_pos_local() + Vector2(0, sin(_t * 3.0) * 3.0)
	if dc_vel.x != 0.0:
		dc_sprite.flip_h = dc_vel.x < 0.0
	# chemokine dots drift downward/outward and respawn near the source
	for dd in dots:
		dd["p"] += dd["v"] * delta
		if dd["p"].y > FIELD.end.y or dd["p"].x < FIELD.position.x or dd["p"].x > FIELD.end.x:
			dd["p"] = SOURCE + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-10, 30))
	# meter + captions
	var c := concentration(dc_pos)
	meter_fill.size.x = 416.0 * c
	meter_label.text = "%d%%" % int(round(c * 100.0))
	if c > 0.75:
		_set_caption(2)
	elif c > 0.35:
		_set_caption(1)
	if dc_pos.distance_to(SOURCE) < 62.0:
		_done = true
		_win_t = 0.0
		_set_caption(3)
		banner.text = "The DC enters the lymphatic vessel!"
		DebugConsole.dlog("ChemokineNav win")
	field.queue_redraw()

func _finish(success: bool) -> void:
	_done = true
	get_tree().paused = false
	finished.emit(success)
	queue_free()

# --------------------------------------------------------------------------
class Field extends Control:
	var mg = null
	func _draw() -> void:
		if mg == null:
			return
		var off: Vector2 = mg.FIELD.position
		# subtle gradient haze (denser rings near the source)
		for i in 6:
			var r := 90.0 + i * 95.0
			draw_arc(mg.SOURCE - off, r, 0.0, TAU, 64, Color(0.5, 1.0, 0.6, 0.06 * (6 - i) / 6.0), 18.0, true)
		# chemokine dots
		for dd in mg.dots:
			var p: Vector2 = dd["p"] - off
			var a: float = 0.55 + 0.35 * sin(mg._t * 2.0 + dd["ph"])
			draw_circle(p, 4.5, Color(0.1, 0.35, 0.2, a * 0.8))
			draw_circle(p, 3.0, Color(0.7, 1.0, 0.75, a))
		# tissue cells (obstacles)
		for o in mg.obstacles:
			var p: Vector2 = o["p"] - off
			draw_circle(p, o["r"] + 3.0, Color(0.35, 0.18, 0.2, 0.9))
			draw_circle(p, o["r"], o["c"])
			draw_circle(p + Vector2(-o["r"] * 0.25, -o["r"] * 0.25), o["r"] * 0.32, Color(0.85, 0.45, 0.55, 0.9))
			draw_circle(p + Vector2(-o["r"] * 0.3, -o["r"] * 0.3), o["r"] * 0.12, Color(1, 1, 1, 0.5))
		# CCR7 antennae around the DC: glow toward the higher concentration
		var dc: Vector2 = mg.dc_pos_local()
		var c0: float = mg.concentration(mg.dc_pos)
		var to_src: Vector2 = (mg.SOURCE - mg.dc_pos).normalized()
		for ang in mg.ANTENNA_ANGLES:
			var dir := Vector2.from_angle(deg_to_rad(ang))
			var tip: Vector2 = dc + dir * (mg.DC_RADIUS + 26.0)
			var base: Vector2 = dc + dir * (mg.DC_RADIUS - 4.0)
			var facing: float = clampf(dir.dot(to_src), 0.0, 1.0)
			var glow: float = 0.15 + 0.85 * facing * (0.4 + 0.6 * c0)
			var col := Color(0.6, 1.0, 0.7).lerp(Color(1.0, 1.0, 0.5), facing)
			col.a = 0.35 + 0.65 * glow
			draw_line(base, tip, Color(0.15, 0.3, 0.2, 0.9), 5.0, true)
			draw_line(base, tip, col, 2.5, true)
			var perp := dir.rotated(PI / 2.0)
			draw_line(tip, tip + (dir + perp * 0.8).normalized() * 12.0, col, 3.0, true)
			draw_line(tip, tip + (dir - perp * 0.8).normalized() * 12.0, col, 3.0, true)
			draw_circle(tip, 4.0 + 6.0 * glow, Color(col.r, col.g, col.b, 0.25 + 0.5 * glow))
		# scent ring around DC
		draw_arc(dc, mg.DC_RADIUS + 34.0, 0.0, TAU, 48, Color(0.6, 1.0, 0.7, 0.15 + 0.45 * c0), 3.0, true)

## Live state for browser automation (mirrored to window.__ss.mg by DebugConsole).
func debug_state() -> Dictionary:
	return {"kind": "nav", "dc": [dc_pos.x, dc_pos.y], "fx": frame.global_position.x, "fy": frame.global_position.y,
		"done": _done, "waypoints": waypoints.map(func(w): return [w.x, w.y])}
