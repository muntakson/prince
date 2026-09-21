extends CanvasLayer
## Mini-game: herd the activated T-cells from the blood vessel to the tumor.
## The prince runs through the tumor stroma; T-cells flock after him. Hazards:
##  - Regulatory T-cells (Tregs) drift about in a purple fog of IL-10 / TGF-beta:
##    a T-cell that lingers in the fog is SUPPRESSED (grey, stops following)
##    until the prince runs past it to rally it again.
##  - Cancer-associated fibroblast (CAF) stroma: collagen walls with gaps.
##  - Hypoxic pockets: T-cells inside crawl.
## Win: at least NEED of the T-cells reach the tumor before the timer ends.
## Controls: WASD / arrows, or press-and-hold to steer toward the pointer.
## Emits `finished(success)` and frees itself. All timing from _process.

signal finished(success: bool)

const BW := 720.0
const FIELD := Rect2(20, 150, 680, 960)
const GOAL := Vector2(360, 235)
const GOAL_R := 95.0
const START := Vector2(360, 1050)
const N_CELLS := 12
const NEED := 8
const TIME_LIMIT := 100.0
const PRINCE_SPEED := 250.0
const CELL_SPEED := 210.0
const FOLLOW_R := 320.0
const SUPPRESS_TIME := 0.9
const RALLY_R := 60.0

var debug_autoplay := false

var root: Control
var frame: Control
var field: Control
var banner: Label
var caption: Label
var status: Label
var timer_label: Label
var prince: AnimatedSprite2D
var tumor_sprite: Sprite2D
var treg_tex: Texture2D
var tcell_tex: Texture2D

var prince_pos := START
var prince_vel := Vector2.ZERO
var cells: Array = []          # {p, v, state: 0 follow / 1 suppressed / 2 arrived, fog_t, ph}
var tregs: Array = []          # {p, v, r}
var walls: Array = []          # Rect2 (field coords)
var hypoxia: Array = []        # {p, r}
var _k := {"up": false, "down": false, "left": false, "right": false}
var _pointer_down := false
var _pointer := Vector2.ZERO
var _touch_id := -100
var _t := 0.0
var _time_left := TIME_LIMIT
var _done := false
var _win_t := -1.0
var _caption_stage := -1
var _rng := RandomNumberGenerator.new()
var waypoints: Array = []

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("minigame")
	_rng.seed = 6
	_build_world()
	_build_ui()

func _build_world() -> void:
	# stroma walls (field coords): three bands with offset gaps -> winding route
	walls = [
		Rect2(FIELD.position.x, 850, 470, 26),
		Rect2(FIELD.position.x + 210, 640, 470, 26),
		Rect2(FIELD.position.x, 430, 430, 26),
	]
	waypoints = [Vector2(600, 860), Vector2(120, 650), Vector2(560, 440), GOAL]
	tregs = [
		{"p": Vector2(200, 760), "v": Vector2(70, 0), "r": 95.0},
		{"p": Vector2(520, 540), "v": Vector2(-60, 0), "r": 95.0},
		{"p": Vector2(300, 340), "v": Vector2(55, 0), "r": 90.0},
	]
	hypoxia = [{"p": Vector2(430, 960), "r": 110.0}, {"p": Vector2(360, 560), "r": 90.0}]
	for i in N_CELLS:
		var a := TAU * i / N_CELLS
		cells.append({"p": START + Vector2.from_angle(a) * _rng.randf_range(50, 90), "v": Vector2.ZERO,
			"state": 0, "fog_t": 0.0, "ph": _rng.randf() * TAU})

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.03, 0.05)
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
	_add_label(frame, Vector2(20, 26), BW - 40, "Herd the T-Cells to the Tumor", 36, Color(1, 0.95, 0.75))
	_add_label(frame, Vector2(20, 76), BW - 40, "Keep the fighters close - avoid the purple Treg fog and find the gaps in the stroma", 18, Color(0.75, 0.9, 1.0))

	var tex_path := "res://assets/env/tumor_bg.png"
	if ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = FIELD.position
		tr.size = FIELD.size
		tr.modulate = Color(1.0, 0.85, 0.9)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
	field = Field.new()
	field.mg = self
	field.position = FIELD.position
	field.size = FIELD.size
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	frame.add_child(field)

	var tp := "res://assets/env/tumor_cell.png"
	tumor_sprite = Sprite2D.new()
	if ResourceLoader.exists(tp):
		tumor_sprite.texture = load(tp)
		var s := tumor_sprite.texture.get_size()
		tumor_sprite.scale = Vector2.ONE * (150.0 / max(s.x, s.y))
	tumor_sprite.position = GOAL - FIELD.position
	tumor_sprite.z_index = 1
	field.add_child(tumor_sprite)
	var trp := "res://assets/env/treg.png"
	if ResourceLoader.exists(trp):
		treg_tex = load(trp)
	var tcp := "res://assets/env/tcell_active.png"
	if ResourceLoader.exists(tcp):
		tcell_tex = load(tcp)

	# the prince (walk cycle)
	prince = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 10.0)
	for i in 6:
		var p := "res://assets/characters/prince_hd/walk_%d.png" % i
		if ResourceLoader.exists(p):
			sf.add_frame("walk", load(p))
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 3.0)
	for i in 2:
		var p2 := "res://assets/characters/prince_hd/idle_%d.png" % i
		if ResourceLoader.exists(p2):
			sf.add_frame("idle", load(p2))
	prince.sprite_frames = sf
	prince.scale = Vector2(0.5, 0.5)
	prince.z_index = 3
	prince.play("idle")
	field.add_child(prince)

	status = _add_label(frame, Vector2(20, 1120), 420, "", 22, Color(0.8, 1.0, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	timer_label = _add_label(frame, Vector2(500, 1120), 200, "", 22, Color(1.0, 0.9, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	caption = _add_label(frame, Vector2(20, 1160), BW - 40, "", 19, Color(0.95, 0.95, 0.8))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner = _add_label(frame, Vector2(20, 108), BW - 40, "", 26, Color(0.6, 1.0, 0.7))
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 52)
	close.position = Vector2(BW - 64, 16)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_on_close)
	frame.add_child(close)
	_set_caption(0)

const CAPTIONS := [
	"Effector T-cells leave the blood vessel, following CXCL9 and CXCL10 chemokines released around the tumor.",
	"Regulatory T-cells (Tregs) secrete IL-10 and TGF-beta. A fighter caught in their fog is switched off - run past it to rally it.",
	"Cancer-associated fibroblasts lay down dense collagen that walls the tumor in. Find the gaps.",
	"Hypoxic pockets (no oxygen) drain the T-cells' energy: they crawl until they get out.",
	"The T-cells have infiltrated the tumor!",
]

func _set_caption(i: int) -> void:
	if i != _caption_stage:
		_caption_stage = i
		caption.text = CAPTIONS[i]

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
		var d := local - (prince_pos - FIELD.position)
		if d.length() > 12.0:
			v = d.normalized()
	if v == Vector2.ZERO and debug_autoplay:
		while waypoints.size() > 1 and prince_pos.distance_to(waypoints[0]) < 30.0:
			waypoints.pop_front()
		var tgt: Vector2 = waypoints[0] if not waypoints.is_empty() else GOAL
		# autoplay: wait for the herd to catch up now and then
		var behind := 0
		for c in cells:
			if c["state"] == 0 and c["p"].distance_to(prince_pos) > FOLLOW_R * 0.6:
				behind += 1
		v = Vector2.ZERO if behind > 2 else (tgt - prince_pos).normalized()
	return v.limit_length(1.0)

func _collide_walls(p: Vector2, r: float) -> Vector2:
	for w in walls:
		var g: Rect2 = w.grow(r)
		if g.has_point(p):
			# push out along the shortest axis
			var dl: float = p.x - g.position.x
			var dr: float = g.end.x - p.x
			var dt: float = p.y - g.position.y
			var db: float = g.end.y - p.y
			var m: float = min(dl, dr, dt, db)
			if m == dl: p.x = g.position.x
			elif m == dr: p.x = g.end.x
			elif m == dt: p.y = g.position.y
			else: p.y = g.end.y
	p.x = clampf(p.x, FIELD.position.x + r, FIELD.end.x - r)
	p.y = clampf(p.y, FIELD.position.y + r, FIELD.end.y - r)
	return p

func wall_gap_x(w: Rect2) -> float:
	# each band leaves its gap on the side it does not touch
	return (w.end.x + 70.0) if w.position.x <= FIELD.position.x + 1.0 else (w.position.x - 70.0)

func in_hypoxia(p: Vector2) -> bool:
	for hz in hypoxia:
		if p.distance_to(hz["p"]) < hz["r"]:
			return true
	return false

func in_fog(p: Vector2) -> bool:
	for tg in tregs:
		if p.distance_to(tg["p"]) < tg["r"]:
			return true
	return false

func arrived_count() -> int:
	var n := 0
	for c in cells:
		if c["state"] == 2:
			n += 1
	return n

func _process(delta: float) -> void:
	_t += delta
	if _done:
		if _win_t >= 0.0:
			_win_t += delta
			if _win_t > 2.2:
				_finish(true)
		field.queue_redraw()
		return
	_time_left -= delta
	# prince
	var s := _steer()
	var spd := PRINCE_SPEED * (0.55 if in_hypoxia(prince_pos) else 1.0)
	prince_vel = prince_vel.lerp(s * spd, 1.0 - exp(-12.0 * delta))
	prince_pos = _collide_walls(prince_pos + prince_vel * delta, 20.0)
	prince.position = prince_pos - FIELD.position + Vector2(0, -30)
	if prince_vel.length() > 20.0:
		if prince.animation != "walk": prince.play("walk")
		prince.flip_h = prince_vel.x < 0.0
	elif prince.animation != "idle":
		prince.play("idle")
	# tregs drift horizontally and bounce off the field edges
	for tg in tregs:
		tg["p"] += tg["v"] * delta
		if tg["p"].x < FIELD.position.x + tg["r"] * 0.6 or tg["p"].x > FIELD.end.x - tg["r"] * 0.6:
			tg["v"].x = -tg["v"].x
	# cells
	for c in cells:
		if c["state"] == 2:
			c["p"] = c["p"].lerp(GOAL + Vector2.from_angle(c["ph"]) * 55.0, 1.0 - exp(-3.0 * delta))
			continue
		var fog := in_fog(c["p"])
		if c["state"] == 0:
			c["fog_t"] = c["fog_t"] + delta if fog else maxf(0.0, c["fog_t"] - delta)
			if c["fog_t"] > SUPPRESS_TIME:
				c["state"] = 1
				c["fog_t"] = 0.0
				_set_caption(1)
				DebugConsole.dlog("herd: cell suppressed")
			var want := Vector2.ZERO
			var d: Vector2 = prince_pos - c["p"]
			if d.length() < FOLLOW_R:
				# follow, but keep a small distance
				if d.length() > 46.0:
					want = d.normalized()
			else:
				# lost the leader: trail after him slowly along his chemokine scent
				want = d.normalized() * 0.4 + Vector2.from_angle(c["ph"] + _t * 0.7) * 0.15
			# steer toward the gap when pressed against a stroma wall
			for w in walls:
				var g: Rect2 = w.grow(40.0)
				if g.has_point(c["p"]) or (absf(c["p"].y - w.get_center().y) < 60.0 and c["p"].x > w.position.x and c["p"].x < w.end.x):
					want += Vector2(signf(wall_gap_x(w) - c["p"].x), 0) * 0.9
			# avoid fog when following
			for tg in tregs:
				var away: Vector2 = c["p"] - tg["p"]
				if away.length() < tg["r"] + 30.0:
					want += away.normalized() * 0.6
			# separation
			for o in cells:
				if o == c or o["state"] == 2: continue
				var sep: Vector2 = c["p"] - o["p"]
				if sep.length() < 34.0 and sep.length() > 0.1:
					want += sep.normalized() * 0.8
			var cs := CELL_SPEED * (0.35 if in_hypoxia(c["p"]) else 1.0)
			c["v"] = c["v"].lerp(want.limit_length(1.0) * cs, 1.0 - exp(-6.0 * delta))
		else:
			# suppressed: drifts slowly; rallied when the prince comes close
			c["v"] = c["v"].lerp(Vector2(sin(_t + c["ph"]) * 12.0, 8.0), 1.0 - exp(-3.0 * delta))
			if prince_pos.distance_to(c["p"]) < RALLY_R and not fog:
				c["state"] = 0
				DebugConsole.dlog("herd: cell rallied")
		c["p"] = _collide_walls(c["p"] + c["v"] * delta, 16.0)
		if c["p"].distance_to(GOAL) < GOAL_R:
			c["state"] = 2
			DebugConsole.dlog("herd: arrived %d" % arrived_count())
	# captions by progress
	if prince_pos.y < 900 and _caption_stage == 0:
		_set_caption(2)
	if in_hypoxia(prince_pos):
		_set_caption(3)
	var n := arrived_count()
	status.text = "In the tumor: %d / %d   (need %d)" % [n, N_CELLS, NEED]
	timer_label.text = "%d s" % int(ceil(_time_left))
	if n >= NEED:
		_done = true
		_win_t = 0.0
		_set_caption(4)
		banner.text = "The T-cell army is inside the tumor!"
		DebugConsole.dlog("herd win n=%d" % n)
	elif _time_left <= 0.0:
		banner.text = "Time's up - too few T-cells made it."
		_done = true
		_win_t = -1.0
		_finish_later = 1.6
	field.queue_redraw()

var _finish_later := -1.0
func _physics_process(delta: float) -> void:
	if _finish_later > 0.0:
		_finish_later -= delta
		if _finish_later <= 0.0:
			_finish(false)

func _on_close() -> void:
	_finish(false)

func _finish(success: bool) -> void:
	_done = true
	get_tree().paused = false
	finished.emit(success)
	queue_free()

func debug_state() -> Dictionary:
	return {"kind": "herd", "prince": [prince_pos.x, prince_pos.y], "arrived": arrived_count(), "time": _time_left,
		"done": _done, "fx": frame.global_position.x, "fy": frame.global_position.y,
		"waypoints": waypoints.map(func(w): return [w.x, w.y]),
		"cells": cells.map(func(c): return [int(c["p"].x), int(c["p"].y), c["state"]])}

# --------------------------------------------------------------------------
class Field extends Control:
	var mg = null
	func _draw() -> void:
		if mg == null:
			return
		var off: Vector2 = mg.FIELD.position
		# hypoxia pockets
		for hz in mg.hypoxia:
			var p: Vector2 = hz["p"] - off
			draw_circle(p, hz["r"], Color(0.25, 0.2, 0.4, 0.45))
			draw_arc(p, hz["r"], 0, TAU, 48, Color(0.5, 0.4, 0.7, 0.6), 3.0, true)
			_txt("hypoxia", p + Vector2(-34, 6))
		# tumor goal ring
		draw_circle(mg.GOAL - off, mg.GOAL_R, Color(0.9, 0.4, 0.5, 0.18))
		draw_arc(mg.GOAL - off, mg.GOAL_R, 0, TAU, 64, Color(1.0, 0.6, 0.7, 0.7 + 0.3 * sin(mg._t * 3.0)), 4.0, true)
		# stroma walls: collagen bands
		for w in mg.walls:
			var r: Rect2 = Rect2(w.position - off, w.size)
			draw_rect(r.grow(4), Color(0.45, 0.3, 0.2))
			draw_rect(r, Color(0.85, 0.7, 0.5))
			var x: float = r.position.x + 8.0
			while x < r.end.x - 8.0:
				draw_line(Vector2(x, r.position.y + 4), Vector2(x + 12, r.end.y - 4), Color(0.6, 0.45, 0.3), 2.0)
				x += 22.0
		# tregs + fog
		for tg in mg.tregs:
			var p: Vector2 = tg["p"] - off
			draw_circle(p, tg["r"], Color(0.6, 0.3, 0.8, 0.22 + 0.06 * sin(mg._t * 2.0)))
			draw_arc(p, tg["r"], 0, TAU, 48, Color(0.75, 0.5, 0.95, 0.5), 2.0, true)
			if mg.treg_tex:
				var s: Vector2 = mg.treg_tex.get_size()
				var f: float = 90.0 / max(s.x, s.y)
				draw_set_transform(p, 0.0, Vector2(f, f))
				draw_texture(mg.treg_tex, -s / 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_circle(p, 30.0, Color(0.5, 0.2, 0.7))
			_txt("Treg", p + Vector2(-18, 58))
		# T-cells
		for c in mg.cells:
			var p: Vector2 = c["p"] - off
			var col := Color(1, 1, 1)
			if c["state"] == 1:
				col = Color(0.45, 0.45, 0.5)
			if mg.tcell_tex:
				var s2: Vector2 = mg.tcell_tex.get_size()
				var f2: float = 44.0 / max(s2.x, s2.y)
				draw_set_transform(p, 0.0, Vector2(f2, f2))
				draw_texture(mg.tcell_tex, -s2 / 2.0, col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_circle(p, 16.0, Color(0.4, 0.6, 1.0) * col)
			if c["state"] == 1:
				_txt("zz", p + Vector2(14, -16))
		# follow radius hint around the prince
		draw_arc(mg.prince_pos - off, mg.FOLLOW_R, 0, TAU, 64, Color(1.0, 0.95, 0.6, 0.18), 2.0, true)
	func _txt(t: String, p: Vector2) -> void:
		var f := ThemeDB.fallback_font
		draw_string(f, p + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0))
		draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
