extends CanvasLayer
## Mini-game: the effector T-cell army reaches the tumor. The player pilots a
## killer (CD8) T-cell with the prince aboard through tumor tissue. Every cell
## shows a peptide on MHC class I: tumor cells carry the vaccine antigen (the
## orange key), healthy cells show self peptides (blue). Touch a cell to let
## the TCR inspect it: tumor cells are killed (perforin pores, granzyme B,
## caspases → apoptosis), healthy cells are spared. Some tumor cells hide
## behind PD-L1, which switches the T-cell off through PD-1 — until the player
## collects the checkpoint-inhibitor antibody. Tumor cells keep dividing, so
## speed matters. Emits `finished(success)`; all timing from _process.

signal finished(success: bool)

const BW := 720.0
const FIELD := Rect2(20, 150, 680, 960)
const KEY_PATTERN := [2, 3, 1, 2]        # vaccine antigen (same key as Chapter 5)
const SELF_PATTERN := [1, 1, 2, 1]       # a self peptide
const CTL_RADIUS := 40.0
const CELL_RADIUS := 44.0
const SPEED := 240.0
const DIVIDE_EVERY := 16.0
const MAX_TUMOR := 8
const MAX_DIVISIONS := 3

enum Phase { HUNT, INSPECT, KILL, SPARE, EXHAUST, WIN }

var debug_autoplay := false

var root: Control
var frame: Control
var field: Control
var banner: Label
var caption: Label
var counter: Label
var ctl_sprite: Sprite2D
var tex_tumor: Texture2D
var tex_dead: Texture2D
var tex_healthy: Texture2D
var tex_ab: Texture2D
var ab_sprite: Sprite2D

var ctl_pos := Vector2(360, 1060)
var ctl_vel := Vector2.ZERO
var cells: Array = []         # [{p, v, kind, spr, state, t, shield, checked, ph}]
var has_antibody := false
var ab_pos := Vector2(120, 260)
var shield_break_t := -1.0
var kills := 0
var _phase: int = Phase.HUNT
var _pt := 0.0
var _target: Dictionary = {}
var _t := 0.0
var _divide_t := 0.0
var _divisions := 0
var _done := false
var _k := {"up": false, "down": false, "left": false, "right": false}
var _pointer_down := false
var _pointer := Vector2.ZERO
var _touch_id := -100
var particles: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("minigame")
	_rng.seed = 606
	_build_ui()
	_build_world()

# --------------------------------------------------------------------------
func _load(p: String) -> Texture2D:
	return load(p) if ResourceLoader.exists(p) else null

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.02, 0.05, 1.0)
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
	_add_label(frame, Vector2(20, 26), BW - 40, "Hunt the Tumor", 38, Color(1, 0.95, 0.75))
	_add_label(frame, Vector2(20, 78), BW - 40, "Touch each cell to read its MHC-I peptide: kill tumor cells, spare healthy ones", 19, Color(0.75, 0.9, 1.0))
	var tex_path := "res://assets/env/tumor_bg.png"
	if ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = FIELD.position
		tr.size = FIELD.size
		tr.modulate = Color(0.95, 0.85, 0.95)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
		var lift := ColorRect.new()      # lighten so the dark tumor cells stand out
		lift.position = FIELD.position
		lift.size = FIELD.size
		lift.color = Color(1.0, 0.88, 0.92, 0.42)
		lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(lift)
	field = Field.new()
	field.mg = self
	field.position = FIELD.position
	field.size = FIELD.size
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	frame.add_child(field)
	tex_tumor = _load("res://assets/env/tumor_cell.png")
	tex_dead = _load("res://assets/env/tumor_dead.png")
	tex_healthy = _load("res://assets/env/healthy_cell.png")
	tex_ab = _load("res://assets/env/antibody.png")
	ab_sprite = Sprite2D.new()
	if tex_ab:
		ab_sprite.texture = tex_ab
		ab_sprite.scale = Vector2.ONE * (70.0 / _tsize(tex_ab))
	ab_sprite.position = ab_pos - FIELD.position
	ab_sprite.z_index = 2
	field.add_child(ab_sprite)
	ctl_sprite = Sprite2D.new()
	var ct := _load("res://assets/env/tcell_rider.png")
	if ct:
		ctl_sprite.texture = ct
		ctl_sprite.scale = Vector2.ONE * (2.6 * CTL_RADIUS / _tsize(ct))
	ctl_sprite.z_index = 3
	field.add_child(ctl_sprite)
	counter = _add_label(frame, Vector2(20, 1120), BW - 40, "", 22, Color(1, 0.8, 0.85))
	caption = _add_label(frame, Vector2(20, 1160), BW - 40, "", 20, Color(0.95, 0.95, 0.8))
	banner = _add_label(frame, Vector2(20, 112), BW - 40, "", 26, Color(0.6, 1.0, 0.7))
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 52)
	close.position = Vector2(BW - 64, 16)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(_on_close)
	frame.add_child(close)
	caption.text = "Tumor cells display the vaccine antigen on MHC class I. Healthy cells show self peptides. Read before you strike!"

func _tsize(t: Texture2D) -> float:
	if t == null:
		return 100.0
	var s := t.get_size()
	return max(s.x, s.y)

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

func _build_world() -> void:
	var spots := [
		[Vector2(140, 900), "tumor", false], [Vector2(560, 860), "healthy", false], [Vector2(360, 760), "tumor", false],
		[Vector2(120, 640), "healthy", false], [Vector2(600, 640), "tumor", true], [Vector2(330, 540), "healthy", false],
		[Vector2(520, 440), "tumor", false], [Vector2(170, 430), "tumor", true], [Vector2(400, 300), "healthy", false],
		[Vector2(600, 250), "tumor", false], [Vector2(250, 240), "healthy", false], [Vector2(560, 1000), "tumor", false],
	]
	for s in spots:
		_spawn_cell(s[0], s[1], s[2])

func _spawn_cell(p: Vector2, kind: String, shield: bool) -> Dictionary:
	var spr := Sprite2D.new()
	var tex := tex_tumor if kind == "tumor" else tex_healthy
	if tex:
		spr.texture = tex
		spr.scale = Vector2.ONE * (2.2 * CELL_RADIUS / _tsize(tex))
	spr.position = p - FIELD.position
	spr.z_index = 1
	field.add_child(spr)
	var c := {"p": p, "v": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(8, 22), "kind": kind, "spr": spr,
		"state": "alive", "t": 0.0, "shield": shield, "checked": false, "ph": _rng.randf() * TAU}
	cells.append(c)
	return c

func _on_close() -> void:
	_finish(false)

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

func ctl_local() -> Vector2:
	return ctl_pos - FIELD.position

func _steer() -> Vector2:
	var v := Vector2.ZERO
	if _k["up"]: v.y -= 1
	if _k["down"]: v.y += 1
	if _k["left"]: v.x -= 1
	if _k["right"]: v.x += 1
	if v == Vector2.ZERO and _pointer_down:
		var d := (_pointer - field.global_position) - ctl_local()
		if d.length() > 12.0:
			v = d.normalized()
	if v == Vector2.ZERO and debug_autoplay:
		var goal := Vector2.INF
		if not has_antibody:
			goal = ab_pos
		else:
			var best := 1e9
			for c in cells:
				if c["kind"] == "tumor" and c["state"] == "alive":
					var d: float = ctl_pos.distance_to(c["p"])
					if d < best:
						best = d
						goal = c["p"]
		if goal != Vector2.INF:
			v = (goal - ctl_pos).normalized()
	return v.limit_length(1.0)

func tumors_left() -> int:
	var n := 0
	for c in cells:
		if c["kind"] == "tumor" and c["state"] == "alive":
			n += 1
	return n

func _process(delta: float) -> void:
	_t += delta
	_pt += delta
	# --- cells drift / divide / die ---
	for c in cells:
		if c["state"] == "alive":
			if _phase == Phase.HUNT or c != _target:
				c["p"] += c["v"] * delta
				if c["p"].x < FIELD.position.x + CELL_RADIUS or c["p"].x > FIELD.end.x - CELL_RADIUS:
					c["v"].x = -c["v"].x
				if c["p"].y < FIELD.position.y + CELL_RADIUS or c["p"].y > FIELD.end.y - CELL_RADIUS:
					c["v"].y = -c["v"].y
				c["p"].x = clampf(c["p"].x, FIELD.position.x + CELL_RADIUS, FIELD.end.x - CELL_RADIUS)
				c["p"].y = clampf(c["p"].y, FIELD.position.y + CELL_RADIUS, FIELD.end.y - CELL_RADIUS)
			if c["checked"] and ctl_pos.distance_to(c["p"]) > CTL_RADIUS + CELL_RADIUS + 30:
				c["checked"] = false
		elif c["state"] == "dying":
			c["t"] += delta
			c["spr"].modulate.a = clampf(1.4 - c["t"], 0.0, 1.0)
			if c["t"] > 1.5:
				c["state"] = "dead"
				c["spr"].visible = false
		c["spr"].position = c["p"] - FIELD.position + Vector2(0, sin(_t * 1.5 + c["ph"]) * 3.0)
	# keep living cells from stacking on each other
	for i in cells.size():
		var ci: Dictionary = cells[i]
		if ci["state"] != "alive":
			continue
		for j in range(i + 1, cells.size()):
			var cj: Dictionary = cells[j]
			if cj["state"] != "alive":
				continue
			var d: Vector2 = cj["p"] - ci["p"]
			var min_d := CELL_RADIUS * 2.0 + 12.0
			var dl := d.length()
			if dl < min_d and dl > 0.001:
				var push := d.normalized() * (min_d - dl) * 0.5
				if _phase == Phase.HUNT or ci != _target:
					ci["p"] -= push
				if _phase == Phase.HUNT or cj != _target:
					cj["p"] += push
	if not _done and _phase != Phase.WIN:
		_divide_t += delta
		if _divide_t > DIVIDE_EVERY and _divisions < MAX_DIVISIONS and tumors_left() < MAX_TUMOR:
			_divide_t = 0.0
			_divisions += 1
			var parents: Array = cells.filter(func(c): return c["kind"] == "tumor" and c["state"] == "alive")
			if not parents.is_empty():
				var par: Dictionary = parents[_rng.randi_range(0, parents.size() - 1)]
				var np: Vector2 = par["p"] + Vector2.from_angle(_rng.randf() * TAU) * 60.0
				np.x = clampf(np.x, FIELD.position.x + CELL_RADIUS, FIELD.end.x - CELL_RADIUS)
				np.y = clampf(np.y, FIELD.position.y + CELL_RADIUS, FIELD.end.y - CELL_RADIUS)
				_spawn_cell(np, "tumor", false)
				_burst(np, 10, Color(0.9, 0.4, 0.8))
				caption.text = "A tumor cell divided! Cancer grows fast — hurry."
	# --- antibody pickup ---
	if not has_antibody and ctl_pos.distance_to(ab_pos) < CTL_RADIUS + 30:
		has_antibody = true
		ab_sprite.visible = false
		shield_break_t = 0.0
		_burst(ab_pos, 20, Color(1.0, 0.95, 0.5))
		banner.text = "Checkpoint inhibitor collected!"
		caption.text = "The anti-PD-1 antibody blocks PD-1, so PD-L1 can no longer switch the T-cell off. Shields down!"
	if shield_break_t >= 0.0:
		shield_break_t += delta
		if shield_break_t > 0.9:
			for c in cells:
				c["shield"] = false
			shield_break_t = -1.0
	# --- player ---
	match _phase:
		Phase.HUNT:
			if tumors_left() == 0 and kills > 0:
				_set_phase(Phase.WIN)
			var s := _steer()
			ctl_vel = ctl_vel.lerp(s * SPEED, 1.0 - exp(-10.0 * delta))
			ctl_pos += ctl_vel * delta
			ctl_pos.x = clampf(ctl_pos.x, FIELD.position.x + CTL_RADIUS, FIELD.end.x - CTL_RADIUS)
			ctl_pos.y = clampf(ctl_pos.y, FIELD.position.y + CTL_RADIUS, FIELD.end.y - CTL_RADIUS)
			if ctl_vel.x != 0.0:
				ctl_sprite.flip_h = ctl_vel.x < 0.0
			for c in cells:
				if c["state"] == "alive" and not c["checked"] and ctl_pos.distance_to(c["p"]) < CTL_RADIUS + CELL_RADIUS:
					_target = c
					c["checked"] = true
					ctl_vel = Vector2.ZERO
					_set_phase(Phase.INSPECT)
					break
		Phase.INSPECT:
			if _pt > 0.8:
				var c := _target
				if c["kind"] == "healthy":
					_set_phase(Phase.SPARE)
				elif c["shield"] and not has_antibody:
					_set_phase(Phase.EXHAUST)
				else:
					_set_phase(Phase.KILL)
		Phase.KILL:
			var c := _target
			var total := 6.4 if kills == 0 else 1.4
			if fmod(_pt, 0.1) < delta:
				_emit(ctl_pos.lerp(c["p"], 0.4) + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10)), (c["p"] - ctl_pos).normalized() * 80.0, Color(1.0, 0.5, 0.2))
			if _pt > total and c["state"] == "alive":
				c["state"] = "dying"
				c["t"] = 0.0
				if tex_dead:
					c["spr"].texture = tex_dead
					c["spr"].scale = Vector2.ONE * (2.3 * CELL_RADIUS / _tsize(tex_dead))
				kills += 1
				_burst(c["p"], 22, Color(0.8, 0.6, 0.9))
				_set_phase(Phase.HUNT)
				caption.text = "Tumor cell destroyed by apoptosis. %d to go." % tumors_left()
		Phase.SPARE:
			if _pt > 1.2:
				ctl_vel = (ctl_pos - _target["p"]).normalized() * 120.0
				_set_phase(Phase.HUNT)
		Phase.EXHAUST:
			ctl_sprite.modulate = Color(0.55, 0.55, 0.6)
			ctl_pos += (ctl_pos - _target["p"]).normalized() * 40.0 * delta
			if _pt > 2.0:
				ctl_sprite.modulate = Color(1, 1, 1)
				_set_phase(Phase.HUNT)
		Phase.WIN:
			if fmod(_pt, 0.2) < delta:
				_emit(Vector2(_rng.randf_range(FIELD.position.x, FIELD.end.x), FIELD.end.y), Vector2(0, -120), Color(1.0, 0.95, 0.5))
			if _pt > 3.5:
				_finish(true)
	ctl_sprite.position = ctl_local() + Vector2(0, sin(_t * 3.0) * 3.0)
	counter.text = "Tumor cells left: %d     Killed: %d     %s" % [tumors_left(), kills, "Antibody: yes" if has_antibody else "Antibody: no"]
	var keep: Array = []
	for pt in particles:
		pt["life"] -= delta
		pt["p"] += pt["v"] * delta
		if pt["life"] > 0.0:
			keep.append(pt)
	particles = keep
	field.queue_redraw()

func _set_phase(p: int) -> void:
	if p == Phase.KILL:
		AudioManager.sfx("zap")
	elif p == Phase.EXHAUST:
		AudioManager.sfx("wrong")
	elif p == Phase.SPARE:
		AudioManager.sfx("lock")
	_phase = p
	_pt = 0.0
	DebugConsole.dlog("Hunt phase %d" % p)
	match p:
		Phase.INSPECT:
			caption.text = "The TCR reads the peptide on this cell's MHC class I..."
		Phase.SPARE:
			caption.text = "A self peptide — this is a healthy cell. The T-cell lets it live. (That is why the vaccine antigen must be tumor-specific!)"
			_burst(_target["p"], 10, Color(0.5, 1.0, 0.6))
		Phase.EXHAUST:
			caption.text = "PD-L1 on the tumor cell grips PD-1 on the T-cell and switches the kill program off! Find the checkpoint-inhibitor antibody."
			_burst(_target["p"], 10, Color(0.6, 0.6, 0.7))
		Phase.KILL:
			caption.text = "The vaccine antigen! The T-cell locks on and delivers the lethal hit." if kills > 0 else "The vaccine antigen! A lytic synapse forms..."
		Phase.WIN:
			banner.text = "The tumor is destroyed!"
			caption.text = "Every tumor cell is gone and the healthy cells were spared. Memory T-cells will keep watch for years."

func _emit(p: Vector2, v: Vector2, c: Color) -> void:
	particles.append({"p": p, "v": v, "life": 1.0, "c": c})

func _burst(p: Vector2, n: int, c: Color) -> void:
	for i in n:
		_emit(p, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(50, 150), c)

func _finish(success: bool) -> void:
	_done = true
	if success:
		GameState.set_flag("tumor_cleared")
	get_tree().paused = false
	finished.emit(success)
	queue_free()

func debug_state() -> Dictionary:
	var cs: Array = []
	for c in cells:
		cs.append([c["p"].x, c["p"].y, c["kind"], c["state"], c["shield"]])
	return {"kind": "hunt", "ctl": [ctl_pos.x, ctl_pos.y], "fx": frame.global_position.x, "fy": frame.global_position.y,
		"phase": _phase, "left": tumors_left(), "kills": kills, "antibody": has_antibody, "ab": [ab_pos.x, ab_pos.y], "cells": cs, "done": _done}

# --------------------------------------------------------------------------
const KILL_CAPTIONS := [
	"1. Recognition — the TCR binds the vaccine antigen on the tumor cell's MHC class I.",
	"2. Perforin — the T-cell fires perforin, which punches pores through the tumor cell membrane.",
	"3. Granzyme B — enzymes pour in through the pores and activate caspases inside the cell.",
	"4. Apoptosis — the tumor cell shrinks, blebs and breaks apart. The T-cell moves on to the next.",
]

class Field extends Control:
	var mg = null
	var font: Font = ThemeDB.fallback_font
	func _draw() -> void:
		if mg == null:
			return
		var off: Vector2 = mg.FIELD.position
		# MHC-I peptide badge above each living cell; PD-L1 shield ring
		for c in mg.cells:
			if c["state"] != "alive":
				continue
			var p: Vector2 = c["p"] - off
			var pat: Array = mg.KEY_PATTERN if c["kind"] == "tumor" else mg.SELF_PATTERN
			var col := Color(1.0, 0.55, 0.15) if c["kind"] == "tumor" else Color(0.45, 0.7, 1.0)
			_key(p + Vector2(0, -mg.CELL_RADIUS - 6), pat, col)
			if c["shield"]:
				var a: float = 0.9
				if mg.shield_break_t >= 0.0:
					a = 0.9 * (1.0 - mg.shield_break_t / 0.9)
				draw_arc(p, mg.CELL_RADIUS + 10.0, 0.0, TAU, 40, Color(0.75, 0.75, 0.85, a), 5.0, true)
				for i in 8:
					var ang: float = i * TAU / 8.0 + mg._t * 0.6
					draw_circle(p + Vector2.from_angle(ang) * (mg.CELL_RADIUS + 10.0), 5.0, Color(0.9, 0.9, 1.0, a))
				draw_string(font, p + Vector2(-40, mg.CELL_RADIUS + 30), "PD-L1", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(0.9, 0.9, 1.0, a))
		# antibody label
		if not mg.has_antibody:
			draw_string(font, mg.ab_pos - off + Vector2(-70, 52), "anti-PD-1 antibody", HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(1, 0.95, 0.7))
		# TCR probe between the T-cell and its target
		var ph: int = mg._phase
		if ph == mg.Phase.INSPECT or ph == mg.Phase.KILL or ph == mg.Phase.SPARE or ph == mg.Phase.EXHAUST:
			var a: Vector2 = mg.ctl_local()
			var b: Vector2 = mg._target["p"] - off
			var col := Color(0.4, 0.7, 1.0)
			if ph == mg.Phase.KILL: col = Color(1.0, 0.45, 0.2)
			elif ph == mg.Phase.SPARE: col = Color(0.5, 1.0, 0.6)
			elif ph == mg.Phase.EXHAUST: col = Color(0.6, 0.6, 0.7)
			draw_line(a, b, Color(0, 0, 0, 0.6), 8.0, true)
			draw_line(a, b, col, 4.0, true)
			draw_circle(a.lerp(b, 0.5), 10.0 + sin(mg._t * 10.0) * 3.0, Color(col.r, col.g, col.b, 0.6))
		# first-kill zoom panel: perforin / granzyme / apoptosis
		if ph == mg.Phase.KILL and mg.kills == 0:
			_kill_panel(mg._pt)
		# PD-1 mark on the T-cell when exhausted
		if ph == mg.Phase.EXHAUST:
			draw_string(font, mg.ctl_local() + Vector2(-40, -mg.CTL_RADIUS - 12), "PD-1 off", HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color(0.9, 0.9, 1.0))
		for pt in mg.particles:
			var al: float = clampf(pt["life"], 0.0, 1.0)
			var cc: Color = pt["c"]
			draw_circle(pt["p"] - off, 3.0 + 3.0 * al, Color(cc.r, cc.g, cc.b, al))

	func _key(p: Vector2, pattern: Array, col: Color) -> void:
		var out := Color(0.12, 0.08, 0.1)
		draw_line(p + Vector2(0, 14), p + Vector2(0, 2), out, 8.0, true)
		draw_line(p + Vector2(0, 14), p + Vector2(0, 2), Color(0.96, 0.93, 0.7), 5.0, true)
		var w := 9.0
		var x0 := p.x - 2.0 * w
		var pts := PackedVector2Array()
		pts.append(Vector2(x0, p.y + 4))
		for i in 4:
			var h: float = 5.0 * pattern[i]
			pts.append(Vector2(x0 + i * w, p.y - h))
			pts.append(Vector2(x0 + (i + 1) * w, p.y - h))
		pts.append(Vector2(x0 + 4 * w, p.y + 4))
		draw_colored_polygon(pts, col)
		var o2 := pts.duplicate()
		o2.append(pts[0])
		draw_polyline(o2, out, 2.0, true)

	func _kill_panel(t: float) -> void:
		var r := Rect2(40, 40, 600, 330)
		draw_rect(r, Color(0.02, 0.02, 0.06, 0.92))
		draw_rect(r, Color(1, 0.7, 0.5, 0.9), false, 3.0)
		var st: int = clampi(int(t / 1.6), 0, 3)
		draw_string(font, Vector2(r.position.x, r.position.y + 28), "The lethal hit (zoom)", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color(1, 0.9, 0.75))
		var ty := r.position.y + 70.0     # T-cell membrane
		var dy := r.position.y + 210.0    # tumor cell membrane
		draw_line(Vector2(r.position.x + 20, ty), Vector2(r.end.x - 20, ty), Color(0.3, 0.55, 1.0), 10.0, true)
		draw_string(font, Vector2(r.position.x + 24, ty - 18), "Killer T-cell", HORIZONTAL_ALIGNMENT_LEFT, 200, 15, Color(0.6, 0.8, 1.0))
		draw_string(font, Vector2(r.position.x + 24, dy + 34), "Tumor cell", HORIZONTAL_ALIGNMENT_LEFT, 200, 15, Color(1.0, 0.7, 0.9))
		var cx := r.get_center().x
		# tumor membrane with pores appearing in stage >= 1
		var segs := 12
		var pores: Array = [3, 5, 8] if st >= 1 else []
		for i in segs:
			var x0 := r.position.x + 20 + i * (r.size.x - 40) / segs
			var x1 := x0 + (r.size.x - 40) / segs
			if i in pores:
				draw_line(Vector2(x0, dy), Vector2(x0 + 8, dy), Color(0.8, 0.35, 0.7), 10.0, true)
				draw_line(Vector2(x1 - 8, dy), Vector2(x1, dy), Color(0.8, 0.35, 0.7), 10.0, true)
				draw_circle(Vector2((x0 + x1) / 2.0, dy), 9.0, Color(1.0, 0.6, 0.3))
				draw_circle(Vector2((x0 + x1) / 2.0, dy), 5.0, Color(0.02, 0.02, 0.06))
			else:
				draw_line(Vector2(x0, dy), Vector2(x1, dy), Color(0.8, 0.35, 0.7), 10.0, true)
		# TCR–pMHC in the centre
		draw_line(Vector2(cx, ty), Vector2(cx, (ty + dy) / 2.0 - 2), Color(0.35, 0.6, 1.0), 12.0, true)
		draw_line(Vector2(cx, dy), Vector2(cx, (ty + dy) / 2.0 + 2), Color(1.0, 0.55, 0.15), 12.0, true)
		draw_string(font, Vector2(cx - 60, ty + 28), "TCR", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.85, 0.92, 1.0))
		draw_string(font, Vector2(cx - 60, dy - 16), "antigen–MHC-I", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 0.9, 0.8))
		# perforin (orange) and granzyme (purple) granules travelling down
		if st >= 1:
			for i in 6:
				var f := fmod(t * 0.8 + i * 0.17, 1.0)
				var px := cx - 150 + i * 60.0
				draw_circle(Vector2(px, lerpf(ty + 12, dy - 12, f)), 7.0, Color(1.0, 0.6, 0.3, 1.0 - f * 0.5))
			draw_string(font, Vector2(r.position.x + 20, (ty + dy) / 2.0 - 30), "perforin", HORIZONTAL_ALIGNMENT_LEFT, 120, 14, Color(1, 0.7, 0.4))
		if st >= 2:
			for i in 5:
				var f := fmod(t * 0.9 + i * 0.2, 1.0)
				var px := cx - 120 + i * 60.0
				var y: float = lerpf(ty + 12, dy + 60, f)
				draw_circle(Vector2(px, y), 6.0, Color(0.75, 0.45, 1.0, 1.0 - f * 0.4))
			draw_string(font, Vector2(r.end.x - 160, (ty + dy) / 2.0 - 30), "granzyme B", HORIZONTAL_ALIGNMENT_RIGHT, 140, 14, Color(0.85, 0.65, 1.0))
			draw_string(font, Vector2(cx - 100, dy + 62), "caspases activated", HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color(1, 0.8, 1.0))
		if st >= 3:
			for i in 7:
				var ang := i * TAU / 7.0 + t
				var pp := Vector2(cx, dy + 70) + Vector2.from_angle(ang) * (30.0 + 20.0 * fmod(t, 1.0))
				draw_circle(pp, 8.0, Color(0.7, 0.5, 0.8, 0.8))
			draw_string(font, Vector2(cx - 100, dy + 100), "apoptosis", HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(1, 0.85, 0.95))
		draw_string(font, Vector2(r.position.x + 10, r.end.y - 14), mg.KILL_CAPTIONS[st], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 14, Color(0.95, 0.95, 0.8))
