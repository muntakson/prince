extends CanvasLayer
class_name HelpScreen
## In-game help: a scrollable walkthrough of the prince's journey (controls +
## every chapter's goal and hazard), in English or Korean. Opened from the
## main menu and the pause menu; works while the tree is paused.
## Content lives in res://assets/help/help.json; the Korean font is a subset
## of Noto Sans CJK KR at res://assets/fonts/help_ko.otf (covers both languages).

const DATA_PATH := "res://assets/help/help.json"
const FONT_PATH := "res://assets/fonts/help_ko.otf"

static var lang := "en"          # remembered between openings

var _data: Dictionary = {}
var _font: Font = null
var _root: Control
var _panel: PanelContainer
var _title: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _lang_btn: Button
var _copy_btn: Button
var _copy_t := 0.0

static func open(tree: SceneTree) -> HelpScreen:
	var existing = tree.get_first_node_in_group("help_screen")
	if existing:
		return existing
	var h := HelpScreen.new()
	tree.root.add_child(h)
	return h

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("help_screen")
	_load()
	_build()
	_fill()

func _load() -> void:
	if FileAccess.file_exists(DATA_PATH):
		var txt := FileAccess.get_file_as_string(DATA_PATH)
		var parsed = JSON.parse_string(txt)
		if parsed is Dictionary:
			_data = parsed
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

func _t(d: Variant) -> String:
	if d is Dictionary:
		return str(d.get(lang, d.get("en", "")))
	return str(d)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# keep the text column readable on wide screens: at most 920 px, centred
	var vw: float = get_viewport().get_visible_rect().size.x
	var half: float = minf(460.0, vw / 2.0 - 16.0)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -half
	_panel.offset_right = half
	_panel.offset_top = 16
	_panel.offset_bottom = -16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.97)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.6, 0.9, 0.8)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	if _font:
		_title.add_theme_font_override("font", _font)
	head.add_child(_title)
	_lang_btn = Button.new()
	_lang_btn.custom_minimum_size = Vector2(96, 48)
	_lang_btn.add_theme_font_size_override("font_size", 20)
	if _font:
		_lang_btn.add_theme_font_override("font", _font)
	_lang_btn.pressed.connect(_toggle_lang)
	head.add_child(_lang_btn)
	_copy_btn = Button.new()
	_copy_btn.custom_minimum_size = Vector2(96, 48)
	_copy_btn.add_theme_font_size_override("font_size", 20)
	if _font:
		_copy_btn.add_theme_font_override("font", _font)
	_copy_btn.pressed.connect(_copy_all)
	head.add_child(_copy_btn)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(48, 48)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(_close)
	head.add_child(close)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	_title.text = _t(_data.get("title", "Help"))
	_lang_btn.text = "한국어" if lang == "en" else "English"
	if _font == null and lang == "en":
		_lang_btn.text = "KO"
	_copy_btn.text = "Copy" if lang == "en" else "복사"
	for sec in _data.get("sections", []):
		var h := Label.new()
		h.text = _t(sec.get("title", ""))
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_theme_font_size_override("font_size", 22)
		h.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		if _font:
			h.add_theme_font_override("font", _font)
		_list.add_child(h)
		var b := RichTextLabel.new()
		b.text = _t(sec.get("body", ""))
		b.fit_content = true
		b.scroll_active = false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.selection_enabled = true          # drag-select + Ctrl+C
		b.context_menu_enabled = true
		b.add_theme_font_size_override("normal_font_size", 18)
		b.add_theme_color_override("default_color", Color(0.93, 0.94, 0.98))
		if _font:
			b.add_theme_font_override("normal_font", _font)
		_list.add_child(b)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10)
		_list.add_child(gap)
	_scroll.scroll_vertical = 0

## Plain-text version of the whole help in the current language.
func full_text() -> String:
	var out: Array = [_t(_data.get("title", "Help")), ""]
	for sec in _data.get("sections", []):
		out.append("== " + _t(sec.get("title", "")) + " ==")
		out.append(_t(sec.get("body", "")))
		out.append("")
	return "\n".join(out)

func _copy_all() -> void:
	var txt := full_text()
	DisplayServer.clipboard_set(txt)
	if OS.has_feature("web"):
		# navigator.clipboard needs a user gesture (we are inside a button press);
		# fall back to a hidden textarea + execCommand for older browsers.
		var js := "(function(t){try{if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(t);}else{var a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();document.execCommand('copy');document.body.removeChild(a);}}catch(e){console.log('copy failed',e);}})(%s);" % JSON.stringify(txt)
		JavaScriptBridge.eval(js, true)
	_copy_t = 1.6
	_copy_btn.text = "Copied!" if lang == "en" else "복사됨!"
	DebugConsole.dlog("help copied %d chars" % txt.length())

func _process(delta: float) -> void:
	if _copy_t > 0.0:
		_copy_t -= delta
		if _copy_t <= 0.0:
			_copy_btn.text = "Copy" if lang == "en" else "복사"

func _toggle_lang() -> void:
	lang = "ko" if lang == "en" else "en"
	_fill()

func _close() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
