class_name CluePanel
extends Panel
## Reusable clue popup for the mini-games. The owner calls `toggle(text)` (or
## lets `handle_input` react to the "hint" action = F1 / H and Esc). The panel
## fits itself to the wrapped text a frame after opening, plays the open/close
## sounds and reads the clue aloud in the Scroll's voice when voice mode is on.
## While open it sits over the mini-game (mouse_filter STOP) so drags under it
## are blocked; the owner should also skip its own input while `is_open`.

signal changed(open: bool)

const TOP := 132.0
const MIN_H := 320.0
const MAX_H := 950.0

var is_open := false
var body: Label
var ok_btn: Button
var _w := 680.0
var _fit := 0

static func create(parent: Control, frame_width: float, title: String) -> CluePanel:
	var cp := CluePanel.new()
	cp._w = frame_width - 40.0
	cp.position = Vector2(20, TOP)
	cp.custom_minimum_size = Vector2(cp._w, MIN_H)
	cp.size = Vector2(cp._w, MAX_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.14, 0.985)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.85, 0.4)
	cp.add_theme_stylebox_override("panel", sb)
	cp.visible = false
	cp.z_index = 20
	cp.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(cp)
	cp._label(Vector2(18, 14), title, 27, Color(1, 0.95, 0.75))
	cp.body = cp._label(Vector2(18, 62), "", 19, Color(0.93, 0.94, 0.98))
	cp.ok_btn = Button.new()
	cp.ok_btn.text = "Got it  (F1)"
	cp.ok_btn.custom_minimum_size = Vector2(220, 54)
	cp.ok_btn.position = Vector2(cp._w / 2.0 - 110, MAX_H - 72)
	cp.ok_btn.add_theme_font_size_override("font_size", 22)
	cp.ok_btn.pressed.connect(cp.close)
	cp.add_child(cp.ok_btn)
	return cp

## The on-screen "? Clue (F1)" button for touch players.
static func add_button(parent: Control, frame_width: float, y: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "? Clue (F1)"
	b.custom_minimum_size = Vector2(180, 50)
	b.position = Vector2(frame_width / 2.0 - 90, y)
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _label(pos: Vector2, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(_w - 36, 0)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func open(text: String) -> void:
	var loc: Array = GameState.localize("Scroll", text)
	var f: Font = GameState.ui_font()
	if f:
		body.add_theme_font_override("font", f)
		ok_btn.add_theme_font_override("font", f)
	else:
		body.remove_theme_font_override("font")
	body.text = loc[1]
	_fit = 2
	if is_open:
		return
	is_open = true
	visible = true
	AudioManager.sfx("dlg_open")
	if AudioManager.voice_enabled:
		AudioManager.speak("Scroll", text)
	changed.emit(true)

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	AudioManager.stop_voice()
	AudioManager.sfx("ui_click")
	changed.emit(false)

func toggle(text: String) -> void:
	if is_open:
		close()
	else:
		open(text)

## Call first thing from the owner's _input. Returns true when the event was
## the hint key (F1 / H) or Esc-while-open and has been consumed.
func handle_input(event: InputEvent, text_cb: Callable) -> bool:
	if event.is_action_pressed("hint") and not event.is_echo():
		toggle(str(text_cb.call()))
		return true
	if is_open and event.is_action_pressed("pause"):
		close()
		return true
	return false

## Centre of the "Got it" button in the parent's coordinates (browser tests).
func ok_center() -> Vector2:
	return position + ok_btn.position + Vector2(110, 27)

func _process(_delta: float) -> void:
	if _fit > 0:
		_fit -= 1
		if _fit == 0:
			var h: float = clampf(body.position.y + body.get_minimum_size().y + 96.0, MIN_H, MAX_H)
			custom_minimum_size = Vector2(_w, h)   # lower the minimum first: size is clamped to it
			size = Vector2(_w, h)
			ok_btn.position = Vector2(_w / 2.0 - 110, h - 72)
