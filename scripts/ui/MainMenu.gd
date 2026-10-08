extends Control
## Title screen: New Game, Continue, chapter select (debug), Quit.

func _ready() -> void:
	_build()
	# web test aid: ?chapter=<id> starts that chapter directly (with ?flags=... granted)
	if DebugConsole.url_chapter != "" and GameState.CHAPTERS.has(DebugConsole.url_chapter):
		var id: String = DebugConsole.url_chapter
		DebugConsole.url_chapter = ""
		GameState.reset()
		Inventory.clear()
		Classroom.practice = true   # URL jumps never count for the class competition
		_grant_debug_flags(id)
		SceneManager.goto_chapter.call_deferred(id)

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.05, 0.12)
	add_child(bg)

	# decorative mRNA icon
	var icon := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/icon.png"):
		icon.texture = load("res://assets/ui/icon.png")
	icon.custom_minimum_size = Vector2(140, 140)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.offset_left = -70
	icon.offset_right = 70
	icon.offset_top = 120
	add_child(icon)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.0
	vb.offset_left = -170
	vb.offset_right = 170
	vb.offset_top = 300
	add_child(vb)

	var title := Label.new()
	title.text = "Prince of mRNA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "An mRNA Adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(subtitle)

	# class competition: who is playing (or a Class Login button)
	_login_box = VBoxContainer.new()
	_login_box.add_theme_constant_override("separation", 8)
	vb.add_child(_login_box)
	_refresh_login()
	Classroom.login_changed.connect(_on_login_changed)

	vb.add_child(_spacer(8))
	vb.add_child(_button("New Game", _new_game))
	if SaveManager.has_save():
		vb.add_child(_button("Continue", _continue))
	vb.add_child(_button("Help", _help))
	vb.add_child(_button("Chapter Select", _chapter_select))
	_voice_btn = _button(_voice_label(), AudioManager.toggle_voice)
	AudioManager.voice_toggled.connect(_on_voice_toggled)
	vb.add_child(_voice_btn)
	_lang_btn = _button(_lang_label(), AudioManager.toggle_lang)
	var cjk: Font = load(GameState.CJK_FONT_PATH) if ResourceLoader.exists(GameState.CJK_FONT_PATH) else null
	if cjk:
		_lang_btn.add_theme_font_override("font", cjk)   # covers Latin + Hangul
	GameState.lang_changed.connect(_on_lang_changed)
	vb.add_child(_lang_btn)
	if not _is_web():
		vb.add_child(_button("Quit", func(): get_tree().quit()))

	var credit := Label.new()
	credit.text = "제작 : 손문탁 박사, 사단법인 나눔과기술\n2026년 9월 19일"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 30)
	credit.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98, 0.95))
	if cjk:
		credit.add_theme_font_override("font", cjk)
	credit.anchor_left = 0.0
	credit.anchor_right = 1.0
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_top = -140
	credit.offset_bottom = -50
	add_child(credit)

	var credit2 := Label.new()
	credit2.text = "Educational game · Godot 4"
	credit2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit2.add_theme_font_size_override("font_size", 18)
	credit2.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8, 0.7))
	credit2.anchor_left = 0.0
	credit2.anchor_right = 1.0
	credit2.anchor_top = 1.0
	credit2.anchor_bottom = 1.0
	credit2.offset_top = -42
	credit2.offset_bottom = -16
	add_child(credit2)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(AudioManager.sfx.bind("ui_click"))
	b.pressed.connect(cb)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

var _voice_btn: Button
var _lang_btn: Button
func _lang_label() -> String:
	return "언어: 한국어  (F3)" if GameState.lang == "ko" else "Language: English  (F3)"

func _on_lang_changed(_l: String) -> void:
	if _lang_btn and is_instance_valid(_lang_btn):
		_lang_btn.text = _lang_label()

func _voice_label() -> String:
	return "Voice: ON  (V)" if AudioManager.voice_enabled else "Voice: OFF  (V)"

func _on_voice_toggled(_on: bool) -> void:
	if _voice_btn and is_instance_valid(_voice_btn):
		_voice_btn.text = _voice_label()

func _help() -> void:
	HelpScreen.open(get_tree())

func _new_game() -> void:
	Classroom.practice = false
	GameState.reset()
	Inventory.clear()
	SceneManager.goto_chapter("cave")

func _continue() -> void:
	Classroom.practice = false
	if SaveManager.load_game():
		SceneManager.goto_chapter(GameState.current_chapter)
	else:
		_new_game()

func _chapter_select() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.offset_left = -160
	panel.offset_top = -180
	panel.offset_right = 160
	panel.offset_bottom = 180
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.98)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.6, 0.9)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 20)
	panel.add_child(m)
	m.add_child(vb)
	for id in GameState.CHAPTERS.keys():
		vb.add_child(_button(GameState.chapter_title(id), func():
			GameState.reset()
			Inventory.clear()
			Classroom.practice = true   # Chapter Select is practice: it does not count
			# grant flags needed to make later chapters traversable in debug
			_grant_debug_flags(id)
			SceneManager.goto_chapter(id)))
	if Classroom.logged_in():
		var note := Label.new()
		note.text = "Practice mode: Chapter Select does not count for the class competition."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(280, 0)
		note.add_theme_font_size_override("font_size", 16)
		note.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		vb.add_child(note)
		panel.offset_top = -230
		panel.offset_bottom = 230
	vb.add_child(_button("Back", func(): panel.queue_free()))

func _grant_debug_flags(id: String) -> void:
	for f in DebugConsole.url_flags:
		GameState.set_flag(f)
	if id == "laboratory" or id == "bioworld" or id == "lymph" or id == "tumor":
		GameState.set_flag("quest_started")
	if id == "bioworld" or id == "lymph" or id == "tumor":
		GameState.set_flag("mrna_assembled")
		GameState.set_flag("lnp_made")
		Inventory.collect("lnp")
		for c in Inventory.MRNA_ORDER:
			Inventory.collect(c)
	if id == "lymph" or id == "tumor":
		Inventory.collect("lnp")
		for f in ["lnp_uptake_done", "endosome_escape_done", "translation_done", "antigen_presented"]:
			GameState.set_flag(f)
	if id == "tumor":
		for f in ["dc_migrated", "tcell_activated"]:
			GameState.set_flag(f)

func _is_web() -> bool:
	return OS.has_feature("web")

# ------------------------------------------------------------------ class login
var _login_box: VBoxContainer
var _login_panel: PanelContainer
var _login_dim: ColorRect
var _code_edit: LineEdit
var _no_edit: LineEdit
var _pin_edit: LineEdit
var _login_msg: Label
var _login_btn: Button

func _on_login_changed(_on: bool) -> void:
	_refresh_login()

func _refresh_login() -> void:
	for c in _login_box.get_children():
		c.queue_free()
	if Classroom.logged_in():
		var who := Label.new()
		who.text = tr("Playing as %s") % Classroom.who()
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		who.add_theme_font_size_override("font_size", 20)
		who.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		_login_box.add_child(who)
		var out := _button("Log out", Classroom.logout)
		out.custom_minimum_size = Vector2(300, 44)
		out.add_theme_font_size_override("font_size", 18)
		_login_box.add_child(out)
	else:
		_login_box.add_child(_button("Class Login", _open_login))

func _field(parent: Control, label: String, placeholder: String, secret: bool, numeric: bool) -> LineEdit:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	parent.add_child(l)
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 52)
	e.add_theme_font_size_override("font_size", 24)
	if numeric:
		e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	e.text_submitted.connect(_on_field_submitted)
	parent.add_child(e)
	return e

func _on_field_submitted(_t: String) -> void:
	_submit_login()

func _open_login() -> void:
	if _login_panel and is_instance_valid(_login_panel):
		return
	_login_dim = ColorRect.new()   # hides the menu behind the panel and blocks clicks on it
	_login_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_login_dim.color = Color(0.02, 0.03, 0.07, 0.94)
	_login_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_login_dim)
	_login_panel = PanelContainer.new()
	_login_panel.anchor_left = 0.5
	_login_panel.anchor_right = 0.5
	_login_panel.anchor_top = 0.5
	_login_panel.anchor_bottom = 0.5
	_login_panel.offset_left = -190
	_login_panel.offset_right = 190
	_login_panel.offset_top = -300
	_login_panel.offset_bottom = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.99)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.35)
	sb.set_content_margin_all(22)
	_login_panel.add_theme_stylebox_override("panel", sb)
	add_child(_login_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_login_panel.add_child(vb)
	var t := Label.new()
	t.text = "Class Login"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	vb.add_child(t)
	var hint := Label.new()
	hint.text = "Use the login card from your teacher."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.88))
	vb.add_child(hint)
	_code_edit = _field(vb, "Class code", "BIO-2A", false, false)
	_code_edit.text = Classroom.class_code
	_no_edit = _field(vb, "Student number", "7", false, true)
	_pin_edit = _field(vb, "PIN", "4 digits", true, true)
	_login_msg = Label.new()
	_login_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_login_msg.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_login_msg.add_theme_font_size_override("font_size", 17)
	_login_msg.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	vb.add_child(_login_msg)
	_login_btn = _button("Log in", _submit_login)
	vb.add_child(_login_btn)
	vb.add_child(_button("Cancel", _close_login))
	if not Classroom.login_result.is_connected(_on_login_result):
		Classroom.login_result.connect(_on_login_result)
	(_code_edit if _code_edit.text == "" else _no_edit).grab_focus()

func _submit_login() -> void:
	if not (_login_panel and is_instance_valid(_login_panel)):
		return
	if _code_edit.text.strip_edges() == "" or not _no_edit.text.strip_edges().is_valid_int() or _pin_edit.text.strip_edges() == "":
		_login_msg.text = tr("Fill in the class code, your number and your PIN.")
		return
	_login_msg.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_login_msg.text = tr("Logging in...")
	_login_btn.disabled = true
	Classroom.login(_code_edit.text, int(_no_edit.text.strip_edges()), _pin_edit.text)

func _on_login_result(ok: bool, message: String) -> void:
	if not (_login_panel and is_instance_valid(_login_panel)):
		return
	_login_btn.disabled = false
	if ok:
		AudioManager.sfx("mg_win")
		_close_login()
	else:
		AudioManager.sfx("deny")
		_login_msg.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		_login_msg.text = tr(message)

func _close_login() -> void:
	if _login_panel and is_instance_valid(_login_panel):
		_login_panel.queue_free()
	if _login_dim and is_instance_valid(_login_dim):
		_login_dim.queue_free()
	_login_panel = null
	_login_dim = null
