extends CanvasLayer
## Mini-game: endosomal escape with the right pH timing.
## Proton pumps acidify the endosome (pH 7.4 -> 4). The ionizable lipids of
## the LNP (pKa ~6.4) only become positively charged once the pH drops below
## ~6.6; charged lipids destabilise the endosomal membrane and the mRNA can
## break out. Press too early and nothing happens (lipids still neutral).
## Wait too long (pH < 5.0) and the lysosome fuses: the mRNA is digested.
## Controls: tap/click anywhere, or E / Space / Jump, to break out.
## Emits `finished(success)` and frees itself. All timing from _process.

signal finished(success: bool)

const BW := 720.0
const CENTER := Vector2(360, 540)
const R := 200.0
const PH_START := 7.4
const PH_RATE := 0.36          # pH units per second
const WIN_HI := 6.6            # lipids charged below this
const WIN_LO := 5.2            # last safe moment
const FUSE_PH := 5.0           # lysosome fusion -> fail
const PKA := 6.4

var debug_autoplay := false

enum Phase { ACIDIFY, ESCAPE, FAIL, DONE }
var phase: int = Phase.ACIDIFY
var ph := PH_START
var _t := 0.0
var _phase_t := 0.0
var _shake := 0.0
var _tries := 0
var _msg_t := 0.0
var _protons: Array = []       # [{p, v}]
var _rng := RandomNumberGenerator.new()

var root: Control
var frame: Control
var scene: Control
var title: Label
var caption: Label
var msg: Label
var ph_label: Label
var charge_label: Label
var lnp_sprite: Sprite2D
var lyso_sprite: Sprite2D
var retry_btn: Button
var close_btn: Button
var go_btn: Button

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	add_to_group("minigame")
	_rng.seed = 7
	_build_ui()

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_root_input)
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.09)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	frame = Control.new()
	frame.anchor_left = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -BW / 2.0
	frame.offset_right = BW / 2.0
	frame.offset_top = -640
	frame.offset_bottom = 640
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	title = _label(frame, Vector2(20, 26), BW - 40, "Endosomal Escape", 38, Color(1, 0.95, 0.75))
	_label(frame, Vector2(20, 78), BW - 40, "Wait until the lipids are charged, then break out - before the lysosome arrives!", 19, Color(0.75, 0.9, 1.0))

	scene = Scene.new()
	scene.mg = self
	scene.position = Vector2.ZERO
	scene.size = Vector2(BW, 1280)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(scene)

	lnp_sprite = Sprite2D.new()
	var lp := "res://assets/molecules/lnp.png"
	if ResourceLoader.exists(lp):
		lnp_sprite.texture = load(lp)
		var s := lnp_sprite.texture.get_size()
		lnp_sprite.scale = Vector2.ONE * (150.0 / max(s.x, s.y))
	lnp_sprite.position = CENTER
	scene.add_child(lnp_sprite)

	lyso_sprite = Sprite2D.new()
	var lyp := "res://assets/env/lysosome.png"
	if ResourceLoader.exists(lyp):
		lyso_sprite.texture = load(lyp)
		var s2 := lyso_sprite.texture.get_size()
		lyso_sprite.scale = Vector2.ONE * (170.0 / max(s2.x, s2.y))
	lyso_sprite.position = Vector2(-140, 900)
	lyso_sprite.visible = false
	scene.add_child(lyso_sprite)

	ph_label = _label(frame, Vector2(540, 120), 160, "pH 7.4", 30, Color(0.7, 0.85, 1.0))
	charge_label = _label(frame, Vector2(20, 880), BW - 40, "Lipid charge: neutral", 22, Color(0.9, 0.9, 0.9))
	msg = _label(frame, Vector2(20, 920), BW - 40, "", 24, Color(1.0, 0.8, 0.5))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption = _label(frame, Vector2(20, 1150), BW - 40, "", 20, Color(0.95, 0.95, 0.8))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	go_btn = Button.new()
	go_btn.text = "BREAK OUT!"
	go_btn.custom_minimum_size = Vector2(320, 76)
	go_btn.position = Vector2((BW - 320) / 2.0, 1010)
	go_btn.add_theme_font_size_override("font_size", 30)
	go_btn.pressed.connect(_attempt)
	frame.add_child(go_btn)

	retry_btn = Button.new()
	retry_btn.text = "Try again"
	retry_btn.custom_minimum_size = Vector2(260, 64)
	retry_btn.position = Vector2((BW - 260) / 2.0, 1010)
	retry_btn.add_theme_font_size_override("font_size", 26)
	retry_btn.visible = false
	retry_btn.pressed.connect(_restart)
	frame.add_child(retry_btn)

	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(52, 52)
	close_btn.position = Vector2(BW - 64, 16)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(_on_close)
	frame.add_child(close_btn)
	_set_caption(0)

const CAPTIONS := [
	"V-ATPase proton pumps push H+ into the endosome. Its pH falls from 7.4 toward 4.5.",
	"Below about pH 6.6 the ionizable lipids (pKa ~6.4) pick up protons and turn positive. Now they can disrupt the membrane.",
	"Too late! Below pH 5 the endosome fuses with a lysosome full of nucleases that digest RNA.",
	"The charged lipids pair with anionic membrane lipids, the bilayer buckles, and the mRNA slips into the cytoplasm.",
]
var _cap := -1
func _set_caption(i: int) -> void:
	if i != _cap:
		_cap = i
		caption.text = CAPTIONS[i]

func _label(parent: Control, pos: Vector2, w: float, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
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
func charged_fraction() -> float:
	# Henderson-Hasselbalch: fraction of protonated (charged) ionizable lipid
	return 1.0 / (1.0 + pow(10.0, ph - PKA))

func _on_root_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_attempt()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("interact") or event.is_action("jump"):
			_attempt()
			get_viewport().set_input_as_handled()

func _attempt() -> void:
	if phase != Phase.ACIDIFY:
		return
	_tries += 1
	if ph > WIN_HI:
		_shake = 0.5
		_msg_t = 2.0
		msg.text = "Too early! At pH %.1f the lipids are still neutral - nothing happens." % ph
		DebugConsole.dlog("endo early ph=%.2f" % ph)
	elif ph >= WIN_LO:
		phase = Phase.ESCAPE
		_phase_t = 0.0
		msg.text = "The charged lipids rupture the membrane - ESCAPE!"
		go_btn.visible = false
		_set_caption(3)
		DebugConsole.dlog("endo escape ph=%.2f" % ph)
	else:
		_fail()

func _fail() -> void:
	phase = Phase.FAIL
	_phase_t = 0.0
	go_btn.visible = false
	retry_btn.visible = true
	msg.text = "The lysosome fused with the endosome. Its nucleases digested the mRNA!"
	_set_caption(2)
	DebugConsole.dlog("endo fail ph=%.2f" % ph)

func _restart() -> void:
	phase = Phase.ACIDIFY
	ph = PH_START
	_t = 0.0
	_phase_t = 0.0
	_protons.clear()
	msg.text = ""
	retry_btn.visible = false
	go_btn.visible = true
	lyso_sprite.position = Vector2(60, 900)
	lyso_sprite.visible = false
	_set_caption(0)

func _process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	_shake = maxf(0.0, _shake - delta)
	_msg_t = maxf(0.0, _msg_t - delta)
	if _msg_t <= 0.0 and phase == Phase.ACIDIFY:
		msg.text = ""
	match phase:
		Phase.ACIDIFY:
			ph = maxf(4.0, PH_START - PH_RATE * _t)
			if ph <= FUSE_PH:
				_fail()
			elif ph < WIN_HI:
				_set_caption(1)
			# lysosome creeps in as the pH nears the danger zone
			var f: float = clampf((5.8 - ph) / (5.8 - FUSE_PH), 0.0, 1.0)
			lyso_sprite.visible = f > 0.0
			lyso_sprite.position = Vector2(60, 900).lerp(CENTER + Vector2(-R - 40, R * 0.4), f)
			# protons spawn faster as pumping continues
			if _rng.randf() < delta * (4.0 + 6.0 * (PH_START - ph)):
				var a := _rng.randf() * TAU
				_protons.append({"p": CENTER + Vector2.from_angle(a) * (R - 6.0), "v": -Vector2.from_angle(a) * _rng.randf_range(40, 90)})
			if debug_autoplay and ph < WIN_HI - 0.3:
				_attempt()
		Phase.ESCAPE:
			if _phase_t > 2.4:
				_finish(true)
		Phase.FAIL:
			lyso_sprite.visible = true
			lyso_sprite.position = lyso_sprite.position.lerp(CENTER + Vector2(-R * 0.5, R * 0.2), 1.0 - exp(-3.0 * delta))
	for pr in _protons:
		pr["p"] += pr["v"] * delta
	_protons = _protons.filter(func(pr): return pr["p"].distance_to(CENTER) > 30.0)
	if _protons.size() > 80:
		_protons = _protons.slice(_protons.size() - 80)
	ph_label.text = "pH %.1f" % ph
	var cf := charged_fraction()
	charge_label.text = "Lipid charge: %s (%d%% protonated)" % ["neutral" if cf < 0.25 else ("charging" if cf < 0.6 else "POSITIVE"), int(round(cf * 100.0))]
	charge_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85).lerp(Color(1.0, 0.85, 0.3), cf))
	var off := Vector2(sin(_t * 50.0) * 6.0 * _shake, 0)
	lnp_sprite.position = CENTER + off + Vector2(0, sin(_t * 2.0) * 4.0)
	if phase == Phase.ESCAPE:
		lnp_sprite.modulate.a = clampf(1.0 - _phase_t / 1.2, 0.0, 1.0)
	scene.queue_redraw()

func _on_close() -> void:
	_finish(false)

func _finish(success: bool) -> void:
	phase = Phase.DONE
	get_tree().paused = false
	finished.emit(success)
	queue_free()

func debug_state() -> Dictionary:
	return {"kind": "endo", "ph": ph, "phase": phase, "tries": _tries,
		"fx": frame.global_position.x, "fy": frame.global_position.y}

# --------------------------------------------------------------------------
class Scene extends Control:
	var mg = null
	func _draw() -> void:
		if mg == null:
			return
		var c: Vector2 = mg.CENTER
		var r: float = mg.R
		var cf: float = mg.charged_fraction()
		var acid: float = clampf((mg.PH_START - mg.ph) / 3.4, 0.0, 1.0)
		# cytoplasm haze
		draw_circle(c, r + 90.0, Color(0.15, 0.25, 0.35, 0.25))
		# endosome lumen: colour follows the pH (blue neutral -> yellow acidic)
		var lumen := Color(0.35, 0.55, 0.85, 0.55).lerp(Color(0.95, 0.75, 0.25, 0.65), acid)
		draw_circle(c, r, lumen)
		# membrane: thick ring; buckles / opens when escaping
		var mem_col := Color(0.55, 0.75, 1.0).lerp(Color(1.0, 0.55, 0.3), cf)
		if mg.phase == mg.Phase.ESCAPE:
			var gap: float = clampf(mg._phase_t / 1.0, 0.0, 1.0) * 1.2
			draw_arc(c, r, gap, TAU - gap, 96, mem_col, 14.0, true)
			# mRNA squiggle leaving through the tear
			var pts := PackedVector2Array()
			var ex := clampf(mg._phase_t / 1.6, 0.0, 1.0)
			for i in 26:
				var x := r * 0.2 + i * 9.0 + ex * 220.0
				pts.append(c + Vector2(x, sin(i * 0.9 + mg._t * 6.0) * 12.0))
			draw_polyline(pts, Color(1.0, 0.95, 0.4), 6.0, true)
		else:
			var wob: float = 6.0 * cf
			var pts2 := PackedVector2Array()
			for i in 97:
				var a := TAU * i / 96.0
				pts2.append(c + Vector2.from_angle(a) * (r + sin(a * 9.0 + mg._t * 5.0) * wob))
			draw_polyline(pts2, mem_col, 14.0, true)
		# proton pumps on the membrane
		for k in 6:
			var a2 := TAU * k / 6.0 + 0.3
			var p := c + Vector2.from_angle(a2) * r
			draw_circle(p, 16.0, Color(0.25, 0.3, 0.45))
			draw_circle(p, 10.0, Color(0.7, 0.8, 1.0))
		# protons
		for pr in mg._protons:
			draw_circle(pr["p"], 6.0, Color(1.0, 0.9, 0.4, 0.9))
			draw_circle(pr["p"], 2.5, Color(1, 1, 1))
		# lipid charges around the LNP
		var n := int(round(cf * 10.0))
		for i in n:
			var a3: float = TAU * i / 10.0 + mg._t * 0.6
			var q: Vector2 = mg.lnp_sprite.position + Vector2.from_angle(a3) * 88.0
			draw_circle(q, 11.0, Color(1.0, 0.75, 0.2))
			draw_line(q + Vector2(-6, 0), q + Vector2(6, 0), Color(0.2, 0.1, 0), 3.0)
			draw_line(q + Vector2(0, -6), q + Vector2(0, 6), Color(0.2, 0.1, 0), 3.0)
		# pH gauge (right side)
		var gx := 640.0
		var gy0 := 170.0
		var gy1 := 860.0
		var gh := gy1 - gy0
		var zones := [[7.4, 6.6, Color(0.35, 0.55, 0.9)], [6.6, 5.2, Color(0.35, 0.85, 0.45)], [5.2, 5.0, Color(0.95, 0.6, 0.2)], [5.0, 4.0, Color(0.9, 0.25, 0.2)]]
		for z in zones:
			var y_top: float = gy0 + (7.4 - z[0]) / 3.4 * gh
			var y_bot: float = gy0 + (7.4 - z[1]) / 3.4 * gh
			draw_rect(Rect2(gx - 16, y_top, 32, y_bot - y_top), z[2])
		draw_rect(Rect2(gx - 16, gy0, 32, gh), Color(0, 0, 0, 0.9), false, 3.0)
		var yy: float = gy0 + (7.4 - mg.ph) / 3.4 * gh
		draw_colored_polygon(PackedVector2Array([Vector2(gx - 22, yy), Vector2(gx - 40, yy - 12), Vector2(gx - 40, yy + 12)]), Color(1, 1, 1))
		draw_colored_polygon(PackedVector2Array([Vector2(gx + 22, yy), Vector2(gx + 40, yy - 12), Vector2(gx + 40, yy + 12)]), Color(1, 1, 1))
		_txt("7.4", Vector2(gx + 26, gy0 + 6))
		_txt("6.6", Vector2(gx + 26, gy0 + 0.8 / 3.4 * gh + 6))
		_txt("5.2", Vector2(gx + 26, gy0 + 2.2 / 3.4 * gh + 6))
		_txt("5.0", Vector2(gx + 26, gy0 + 2.4 / 3.4 * gh + 20))
		_txt("4.0", Vector2(gx + 26, gy1 + 6))
	func _txt(t: String, p: Vector2) -> void:
		var f := ThemeDB.fallback_font
		draw_string(f, p + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0))
		draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))
