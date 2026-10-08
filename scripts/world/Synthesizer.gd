extends Area2D
## The Vaccine Synthesizer station. Gives clear, dynamic feedback:
##  - dim/inactive until all 7 mRNA components are collected
##  - pulsing gold "ready" glow once all 7 are held
##  - on operate (all 7): plays the assembly dialogue, then sets "mrna_assembled"
##    which unlocks the "Encapsulate & Inject" door
##  - green "✓ Assembled" done-state afterwards
## Flag is set from _process (not a signal/tween callback) to stay web-safe.

var _sprite: Sprite2D
var _label: Label
var _highlighted := false
var _t := 0.0
var _assembling := false

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 58.0
	cs.shape = sh
	add_child(cs)
	_sprite = Sprite2D.new()
	var tex_path := "res://assets/env/synthesizer.png"
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/env/station.png"
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
		var s := _sprite.texture.get_size()
		var f: float = 150.0 / max(s.x, s.y)
		_sprite.scale = Vector2(f, f)
	add_child(_sprite)
	_label = Label.new()
	_label.position = Vector2(-110, -96)
	_label.size = Vector2(220, 26)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-150, -100)
	_label.size = Vector2(300, 0)
	TextStyle.apply(_label, 24, Color(1, 0.95, 0.7))
	add_child(_label)

func _process(delta: float) -> void:
	_t += delta
	# finish assembly once the dialogue closes
	if _assembling and not DialogueManager.is_active():
		_assembling = false
		GameState.set_flag("mrna_assembled")
	var assembled := GameState.has_flag("mrna_assembled")
	var ready := Inventory.has_all_mrna() and not assembled
	# sprite state
	_sprite.position.y = sin(_t * 2.0) * 4.0
	if assembled:
		_sprite.modulate = Color(0.72, 1.0, 0.78)          # soft green "done"
	elif ready:
		var pulse := sin(_t * 5.0) * 0.5 + 0.5
		_sprite.modulate = Color(1, 1, 1).lerp(Color(1.35, 1.25, 0.85), pulse)  # gentle gold pulse
	else:
		_sprite.modulate = Color(0.82, 0.84, 0.9)          # slightly dimmed / idle
	# label state
	if assembled:
		_label.text = "mRNA Assembled"
		_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	elif ready:
		_label.text = "Synthesizer — READY!"
		_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	else:
		_label.text = tr("Vaccine Synthesizer (%d/7)") % Inventory.count_mrna()
		_label.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	var vis := 1.0 if (_highlighted or ready or assembled) else 0.0
	_label.modulate.a = move_toward(_label.modulate.a, vis, delta * 6.0)

func set_highlight(on: bool) -> void:
	_highlighted = on

func interact() -> void:
	if GameState.has_flag("mrna_assembled"):
		DialogueManager.start([["Synthesizer", "The letter is written! Take it to the Bubble Maker to wrap it in a Bubble Shield."]])
		return
	if GameState.debug_mode and not Inventory.has_all_mrna():
		for id in Inventory.MRNA_ORDER:   # debug mode: load all seven parts
			Inventory.collect(id)
	if not Inventory.has_all_mrna():
		var n := Inventory.count_mrna()
		var missing := ", ".join(_missing_names())
		DialogueManager.start([
			["Synthesizer", tr("Letter parts loaded: %d of 7.") % n],
			["Synthesizer", tr("Still needed: %s. Gather them, then operate me.") % missing],
		])
		return
	# All seven — launch the assembly mini-game (it sets "mrna_assembled" on success).
	var mg = preload("res://scripts/minigames/AssembleMRNA.gd").new()
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(mg)

func _missing_names() -> Array:
	var out: Array = []
	for id in Inventory.MRNA_ORDER:
		if not Inventory.has(id):
			out.append(tr(Inventory.component_name(id)))
	return out
