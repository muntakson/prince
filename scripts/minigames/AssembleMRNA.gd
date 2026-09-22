extends CanvasLayer
## Mini-game: assemble the mRNA by dragging the 7 components into the correct
## 5′ → 3′ order. Drag works via raw pointer events (mouse + touch), so it is
## reliable in the Godot web export. Emits `finished(success)` and frees itself.

signal finished(success: bool)

const ORDER: Array = Inventory.MRNA_ORDER   # cap5, utr5, start_codon, orf, stop_codon, utr3, polya

# base design space (matches project viewport 720 x 1280)
const BW := 720.0
const TILE := Vector2(92, 118)

var root: Control
var slots: Array = []          # [{panel, index, tile}]
var tiles: Array = []          # tile Controls
var banner: Label

var _grabbed: Control = null
var _grab_off: Vector2 = Vector2.ZERO
var _touch_id: int = -100
var _solved := 0
var _done := false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build()

# --------------------------------------------------------------------------
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.11, 0.96)
	root.add_child(bg)

	# a centered design-space container so layout is resolution independent
	var frame := Control.new()
	frame.anchor_left = 0.5
	frame.anchor_top = 0.0
	frame.offset_left = -BW / 2.0
	frame.offset_right = BW / 2.0
	frame.offset_top = 0
	frame.offset_bottom = 1280
	root.add_child(frame)

	_add_label(frame, Vector2(20, 40), BW - 40, "Assemble the mRNA", 40, Color(1, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(frame, Vector2(20, 96), BW - 40, "Drag each part into the correct 5′ → 3′ order", 22, Color(0.65, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)

	# 5' and 3' end markers
	_add_label(frame, Vector2(24, 150), 80, "5′", 30, Color(0.9, 0.9, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	_add_label(frame, Vector2(BW - 100, 150), 80, "3′", 30, Color(0.9, 0.9, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)

	# ---- target slots (in order, labeled with the role) ----
	var n := ORDER.size()
	var gap := 6.0
	var sw := (BW - 40 - gap * (n - 1)) / n
	var y_slot := 190.0
	for i in n:
		var x := 20.0 + i * (sw + gap)
		var panel := _make_panel(frame, Vector2(x, y_slot), Vector2(sw, 150), Color(0.08, 0.10, 0.2, 0.9), Color(0.3, 0.4, 0.7))
		var num := _add_label(panel, Vector2(0, 6), sw, str(i + 1), 20, Color(0.7, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm := _add_label(panel, Vector2(2, 108), sw - 4, Inventory.component_name(ORDER[i]), 14, Color(0.8, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slots.append({"panel": panel, "index": i, "tile": null, "rect_node": panel})

	# ---- draggable tiles (shuffled) in a tray ----
	var shuffled := ORDER.duplicate()
	shuffled.shuffle()
	var ty := 470.0
	var per_row := 4
	var trow_gap := 14.0
	var tw := TILE.x
	for k in shuffled.size():
		var id: String = shuffled[k]
		var col := k % per_row
		var rown := k / per_row
		var row_count: int = min(per_row, shuffled.size() - rown * per_row)
		var total_w := row_count * tw + (row_count - 1) * trow_gap
		var start_x := (BW - total_w) / 2.0
		var tx := start_x + col * (tw + trow_gap)
		var tyy := ty + rown * (TILE.y + 20.0)
		var tile := _make_tile(frame, id, Vector2(tx, tyy))
		tiles.append(tile)

	# ---- banner + buttons ----
	banner = _add_label(frame, Vector2(20, 720), BW - 40, "", 30, Color(0.6, 1.0, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(52, 52)
	close.position = Vector2(BW - 64, 20)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func(): _finish(false))
	frame.add_child(close)

	var hint := _add_label(frame, Vector2(20, 780), BW - 40, "Order: 5′ Cap · 5′ UTR · Start · Antigen ORF · Stop · 3′ UTR · Poly(A)", 15, Color(0.6, 0.65, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# --------------------------------------------------------------------------
func _make_panel(parent: Control, pos: Vector2, size: Vector2, bg: Color, border: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.custom_minimum_size = size
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = border
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p

func _make_tile(parent: Control, id: String, pos: Vector2) -> Control:
	var tile := _make_panel(parent, pos, TILE, Color(0.12, 0.16, 0.28, 0.98), Color(0.5, 0.7, 1.0))
	tile.set_meta("id", id)
	tile.set_meta("home", pos)
	tile.set_meta("locked", false)
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.position = Vector2(6, 6)
	tex.size = Vector2(TILE.x - 12, TILE.y - 34)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tp := Inventory.sprite_path(id)
	if ResourceLoader.exists(tp):
		tex.texture = load(tp)
	tile.add_child(tex)
	var nm := _add_label(tile, Vector2(2, TILE.y - 26), TILE.x - 4, Inventory.component_name(id), 12, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return tile

func _add_label(parent: Control, pos: Vector2, w: float, text: String, size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, 0)
	l.custom_minimum_size = Vector2(w, 0)
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

# --------------------------------------------------------------------------
# drag handling (mouse + touch)
func _input(event: InputEvent) -> void:
	if _done:
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
	for tile in tiles:
		if tile.get_meta("locked"):
			continue
		if tile.get_global_rect().has_point(pos):
			_grabbed = tile
			_grab_off = tile.global_position - pos
			# free any slot this tile occupied
			for s in slots:
				if s["tile"] == tile:
					s["tile"] = null
			tile.z_index = 10
			return

func _release(pos: Vector2) -> void:
	if _grabbed == null:
		return
	var tile := _grabbed
	tile.z_index = 0
	_grabbed = null
	# find slot under the tile's center
	var center := tile.get_global_rect().get_center()
	var target = null
	for s in slots:
		if s["rect_node"].get_global_rect().has_point(center) and s["tile"] == null:
			target = s
			break
	if target != null and ORDER[target["index"]] == tile.get_meta("id"):
		# correct placement — snap in and lock
		var slot_rect: Rect2 = target["rect_node"].get_global_rect()
		tile.global_position = slot_rect.position + Vector2((slot_rect.size.x - TILE.x) / 2.0, 20)
		tile.set_meta("locked", true)
		target["tile"] = tile
		_lock_visual(tile)
		_check_win()
	else:
		# wrong / missed — return home
		_return_home(tile)

func _lock_visual(tile: Control) -> void:
	AudioManager.sfx("lock")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.28, 0.16, 0.98)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.4, 1.0, 0.6)
	tile.add_theme_stylebox_override("panel", sb)

func _return_home(tile: Control) -> void:
	AudioManager.sfx("wrong")
	var t := create_tween()
	t.tween_property(tile, "position", tile.get_meta("home"), 0.18).set_trans(Tween.TRANS_BACK)

func _check_win() -> void:
	var ok := 0
	for s in slots:
		if s["tile"] != null:
			ok += 1
	_solved = ok
	if ok == ORDER.size():
		_done = true
		banner.text = "mRNA assembled! Cap · UTR · Start · ORF · Stop · UTR · Poly(A)"
		var t := create_tween()
		t.tween_interval(1.6)
		t.tween_callback(func(): _finish(true))

func _finish(success: bool) -> void:
	if success:
		GameState.set_flag("mrna_assembled")
	get_tree().paused = false
	finished.emit(success)
	queue_free()
