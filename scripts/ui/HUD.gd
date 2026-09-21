extends CanvasLayer
## The single in-game HUD, built in code for reliability across devices.
## Handles: inventory bar, dialogue box (typewriter), chapter title cards,
## touch controls (joystick + interact button), and the pause menu.

const VirtualJoystickScript = preload("res://scripts/ui/VirtualJoystick.gd")

var root: Control
var inventory_bar: HBoxContainer
var slot_by_id: Dictionary = {}

# dialogue
var dialogue_box: PanelContainer
var speaker_label: Label
var text_label: RichTextLabel
var continue_hint: Label
var _full_text: String = ""
var _typed: float = 0.0
var _typing: bool = false

# chapter title
var title_card: Label

# touch
var touch_layer: Control
var joystick: Control
var interact_btn: Button

# pause
var pause_menu: PanelContainer
var _paused_by_menu: bool = false

func _ready() -> void:
	layer = 20
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	Inventory.inventory_changed.connect(_refresh_inventory)
	_refresh_inventory()

# --------------------------------------------------------------------------
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_inventory_bar()
	_build_top_bar()
	_build_title_card()
	_build_dialogue()
	_build_touch()
	_build_pause_menu()

func _build_inventory_bar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_panel(panel, Color(0.05, 0.07, 0.14, 0.75))
	root.add_child(panel)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 8)
	panel.add_child(margin)
	inventory_bar = HBoxContainer.new()
	inventory_bar.add_theme_constant_override("separation", 6)
	margin.add_child(inventory_bar)
	for id in Inventory.MRNA_ORDER:
		var slot := TextureRect.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_path := Inventory.sprite_path(id)
		if ResourceLoader.exists(tex_path):
			slot.texture = load(tex_path)
		slot.modulate = Color(0.25, 0.25, 0.3, 0.6)
		slot.tooltip_text = Inventory.component_name(id)
		inventory_bar.add_child(slot)
		slot_by_id[id] = slot

func _build_top_bar() -> void:
	var pause := Button.new()
	pause.text = "II"
	pause.custom_minimum_size = Vector2(52, 52)
	pause.anchor_left = 1.0
	pause.anchor_right = 1.0
	pause.position = Vector2(-64, 12)
	pause.mouse_filter = Control.MOUSE_FILTER_STOP
	pause.pressed.connect(_toggle_pause)
	root.add_child(pause)

func _build_title_card() -> void:
	title_card = Label.new()
	title_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_card.anchor_left = 0.0
	title_card.anchor_right = 1.0
	title_card.offset_top = 120
	title_card.offset_left = 20
	title_card.offset_right = -20
	title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_card.add_theme_font_size_override("font_size", 38)
	title_card.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	title_card.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_card.add_theme_constant_override("outline_size", 8)
	title_card.modulate.a = 0.0
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_card)

func _build_dialogue() -> void:
	dialogue_box = PanelContainer.new()
	dialogue_box.anchor_left = 0.0
	dialogue_box.anchor_right = 1.0
	dialogue_box.anchor_top = 1.0
	dialogue_box.anchor_bottom = 1.0
	dialogue_box.offset_left = 24
	dialogue_box.offset_right = -24
	dialogue_box.offset_top = -220
	dialogue_box.offset_bottom = -140
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(dialogue_box, Color(0.06, 0.08, 0.16, 0.94), Color(0.4, 0.6, 0.9, 0.7))
	dialogue_box.visible = false
	dialogue_box.gui_input.connect(_on_dialogue_click)
	root.add_child(dialogue_box)

	var vb := VBoxContainer.new()
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 16)
	dialogue_box.add_child(m)
	m.add_child(vb)

	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 22)
	speaker_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(speaker_label)

	text_label = RichTextLabel.new()
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.custom_minimum_size = Vector2(0, 60)
	text_label.add_theme_font_size_override("normal_font_size", 22)
	text_label.add_theme_color_override("default_color", Color(0.95, 0.96, 1.0))
	vb.add_child(text_label)

	continue_hint = Label.new()
	continue_hint.text = "▼  tap / press E"
	continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_hint.add_theme_font_size_override("font_size", 16)
	continue_hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.8))
	vb.add_child(continue_hint)

func _build_touch() -> void:
	touch_layer = Control.new()
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)

	joystick = VirtualJoystickScript.new()
	joystick.anchor_right = 0.5
	joystick.anchor_bottom = 1.0
	joystick.offset_top = -360
	joystick.mouse_filter = Control.MOUSE_FILTER_PASS
	touch_layer.add_child(joystick)

	interact_btn = Button.new()
	interact_btn.text = "✋"
	interact_btn.custom_minimum_size = Vector2(96, 96)
	interact_btn.anchor_left = 1.0
	interact_btn.anchor_right = 1.0
	interact_btn.anchor_top = 1.0
	interact_btn.anchor_bottom = 1.0
	interact_btn.offset_left = -120
	interact_btn.offset_top = -180
	interact_btn.offset_right = -24
	interact_btn.offset_bottom = -84
	interact_btn.add_theme_font_size_override("font_size", 40)
	interact_btn.button_down.connect(func(): Input.action_press("interact"))
	interact_btn.button_up.connect(func(): Input.action_release("interact"))
	touch_layer.add_child(interact_btn)

	# only show touch controls on touch-capable devices (FORCE_TOUCH overrides for testing)
	var touch := DisplayServer.is_touchscreen_available() or OS.has_environment("FORCE_TOUCH")
	touch_layer.visible = touch

func _build_pause_menu() -> void:
	pause_menu = PanelContainer.new()
	pause_menu.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu.custom_minimum_size = Vector2(360, 360)
	pause_menu.position = Vector2(-180, -180)
	pause_menu.anchor_left = 0.5
	pause_menu.anchor_top = 0.5
	pause_menu.offset_left = -180
	pause_menu.offset_top = -180
	pause_menu.offset_right = 180
	pause_menu.offset_bottom = 180
	_style_panel(pause_menu, Color(0.06, 0.08, 0.16, 0.97), Color(0.4, 0.6, 0.9, 0.8))
	pause_menu.visible = false
	root.add_child(pause_menu)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 24)
	pause_menu.add_child(m)
	m.add_child(vb)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vb.add_child(title)
	vb.add_child(_menu_button("Resume", _toggle_pause))
	vb.add_child(_menu_button("Save Game", func():
		SaveManager.save_game()
		_flash_hint("Saved!")))
	vb.add_child(_menu_button("Main Menu", func():
		get_tree().paused = false
		SceneManager.change_scene("res://scenes/MainMenu.tscn")))

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b

# --------------------------------------------------------------------------
# dialogue flow
var _touch_was_visible := false
func _on_dialogue_started() -> void:
	dialogue_box.visible = true
	dialogue_box.modulate.a = 0.0
	create_tween().tween_property(dialogue_box, "modulate:a", 1.0, 0.2)
	# keep the dialogue box clear of the movement controls
	if touch_layer:
		_touch_was_visible = touch_layer.visible
		touch_layer.visible = false

func _on_line_shown(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	_full_text = text
	text_label.text = text
	text_label.visible_ratio = 0.0
	_typed = 0.0
	_typing = true

var _dialogue_hiding := false
func _on_dialogue_finished() -> void:
	# Fade the box with a property-only tween; hide it in _process once faded.
	# (tween_callback / lambda Callables crash the Godot 4.3 web export —
	#  "function signature mismatch" — killing the main loop.)
	_dialogue_hiding = true
	var t := create_tween()
	t.tween_property(dialogue_box, "modulate:a", 0.0, 0.2)
	if touch_layer and _touch_was_visible:
		touch_layer.visible = true

func _process(delta: float) -> void:
	if _typing:
		_typed += delta * 42.0
		var total := float(max(1, _full_text.length()))
		text_label.visible_ratio = clampf(_typed / total, 0.0, 1.0)
		if text_label.visible_ratio >= 1.0:
			_typing = false
	continue_hint.visible = DialogueManager.is_active() and not _typing
	if _dialogue_hiding and dialogue_box.visible and dialogue_box.modulate.a <= 0.03:
		dialogue_box.visible = false
		_dialogue_hiding = false

func _on_dialogue_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_dialogue()
	elif event is InputEventScreenTouch and event.pressed:
		_advance_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and DialogueManager.is_active():
		_advance_dialogue()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_toggle_pause()

func _advance_dialogue() -> void:
	if _typing:
		_typing = false
		text_label.visible_ratio = 1.0
		return
	DialogueManager.advance()

# --------------------------------------------------------------------------
func show_chapter_title(text: String) -> void:
	title_card.text = text
	var t := create_tween()
	t.tween_property(title_card, "modulate:a", 1.0, 0.6)
	t.tween_interval(1.8)
	t.tween_property(title_card, "modulate:a", 0.0, 0.8)

func _refresh_inventory() -> void:
	for id in slot_by_id:
		var slot: TextureRect = slot_by_id[id]
		if Inventory.has(id):
			slot.modulate = Color(1, 1, 1, 1)
		else:
			slot.modulate = Color(0.22, 0.24, 0.3, 0.7)

func _toggle_pause() -> void:
	if DialogueManager.is_active():
		return
	_paused_by_menu = not _paused_by_menu
	pause_menu.visible = _paused_by_menu
	get_tree().paused = _paused_by_menu

func _flash_hint(msg: String) -> void:
	title_card.text = msg
	title_card.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_property(title_card, "modulate:a", 0.0, 0.5)

# --------------------------------------------------------------------------
func _style_panel(p: Control, bg: Color, border: Color = Color(0.3, 0.4, 0.7, 0.5)) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", sb)
