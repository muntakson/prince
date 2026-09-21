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

	vb.add_child(_spacer(20))
	vb.add_child(_button("New Game", _new_game))
	if SaveManager.has_save():
		vb.add_child(_button("Continue", _continue))
	vb.add_child(_button("Help", _help))
	vb.add_child(_button("Chapter Select", _chapter_select))
	if not _is_web():
		vb.add_child(_button("Quit", func(): get_tree().quit()))

	var credit := Label.new()
	credit.text = "Educational game · Godot 4"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 15)
	credit.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8, 0.7))
	credit.anchor_left = 0.0
	credit.anchor_right = 1.0
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_top = -40
	add_child(credit)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _help() -> void:
	HelpScreen.open(get_tree())

func _new_game() -> void:
	GameState.reset()
	Inventory.clear()
	SceneManager.goto_chapter("cave")

func _continue() -> void:
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
			# grant flags needed to make later chapters traversable in debug
			_grant_debug_flags(id)
			SceneManager.goto_chapter(id)))
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
