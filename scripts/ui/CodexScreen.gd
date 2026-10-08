extends CanvasLayer
class_name CodexScreen
## Science Words: the collection of Word Cards the player has earned
## (Glossary). Learned words show "nickname = science name" and the plain
## explanation; words not met yet stay hidden as "???", so the list doubles as
## a progress tracker. Opened from the pause menu; works while paused.

var _font: Font = null
var _root: Control
var _title: Label
var _scroll: ScrollContainer
var _list: VBoxContainer

static func open(tree: SceneTree) -> CodexScreen:
	var existing = tree.get_first_node_in_group("codex_screen")
	if existing:
		return existing
	var c := CodexScreen.new()
	tree.root.add_child(c)
	return c

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("codex_screen")
	_font = GameState.ui_font()
	_build()
	_fill()

func _ko() -> bool:
	return GameState.lang == "ko"

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

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vw: float = get_viewport().get_visible_rect().size.x
	var half: float = minf(460.0, vw / 2.0 - 16.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -half
	panel.offset_right = half
	panel.offset_top = 16
	panel.offset_bottom = -16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.12, 0.97)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.35, 0.8)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	_title = _label("", 26, Color(1.0, 0.88, 0.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
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
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # text is already localized here
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if _font:
		l.add_theme_font_override("font", _font)
	return l

func _gap(h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	_list.add_child(g)

func _fill() -> void:
	var ko := _ko()
	_title.text = ("과학 단어  %d / %d" if ko else "Science Words  %d / %d") % [Glossary.learned_count(), Glossary.total()]
	_list.add_child(_label("이야기 속 별명을 만날 때마다 진짜 과학 이름을 얻는다. 모두 모아 보자!" if ko
		else "Every nickname you meet in the story earns you its real science name. Collect them all!",
		17, Color(0.75, 0.78, 0.88)))
	_gap(8)
	for sec in Glossary.SECTIONS:
		var ids: Array = sec["ids"]
		var got := 0
		for id in ids:
			if Glossary.knows(id):
				got += 1
		_list.add_child(_label("%s   %d/%d" % [sec["ko" if ko else "en"], got, ids.size()], 22, Color(0.6, 0.85, 1.0)))
		for id in ids:
			if Glossary.knows(id):
				_list.add_child(_label("%s  =  %s" % [Glossary.nick(id), Glossary.sci(id)], 19, Color(1.0, 0.9, 0.6)))
				_list.add_child(_label(Glossary.what(id), 16, Color(0.9, 0.91, 0.96)))
			else:
				_list.add_child(_label("???  " + ("(아직 만나지 못한 단어)" if ko else "(not met yet)"), 19, Color(0.45, 0.47, 0.55)))
			_gap(4)
		_gap(10)
	_list.add_child(_label("진짜 세상에서는" if ko else "In the real world", 22, Color(0.6, 0.85, 1.0)))
	for fact in Glossary.REAL_WORLD:
		_list.add_child(_label("·  " + fact[1 if ko else 0], 16, Color(0.9, 0.91, 0.96)))
		_gap(4)
	_scroll.scroll_vertical = 0

func _close() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
