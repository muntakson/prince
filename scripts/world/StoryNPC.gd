extends Area2D
## An interactable character or object that speaks dialogue.
## `lines` is an Array of {"speaker","text"} dicts or [speaker,text] pairs.

var npc_name: String = ""
var lines: Array = []
var texture_path: String = ""
var once_flag: String = ""        # if set, only triggers once (stores a GameState flag)
var on_finished_flag: String = "" # optional flag to set when dialogue completes
var sprite_max_dim: float = 96.0  # on-screen size of the sprite (longest side)

var _sprite: Sprite2D
var _prompt: Label
var _highlighted: bool = false
var _t: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 48.0
	cs.shape = shape
	add_child(cs)
	_sprite = Sprite2D.new()
	var path := texture_path
	if path == "" or not ResourceLoader.exists(path):
		path = "res://assets/env/glow_token.png"   # soft glowing default
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	_fit_sprite(sprite_max_dim)
	# widen the interact area to match larger sprites
	shape.radius = maxf(48.0, sprite_max_dim * 0.4)
	add_child(_sprite)
	_prompt = Label.new()
	_prompt.text = npc_name
	_prompt.position = Vector2(-70, -80)
	_prompt.size = Vector2(140, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TextStyle.apply(_prompt, 24, Color(1, 0.95, 0.7), true)
	_prompt.modulate.a = 0.0
	add_child(_prompt)

func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = sin(_t * 2.0) * 4.0
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if _highlighted else 0.0, delta * 6.0)

func _fit_sprite(max_dim: float) -> void:
	if _sprite.texture == null:
		return
	var sz := _sprite.texture.get_size()
	var f: float = max_dim / max(sz.x, sz.y)
	_sprite.scale = Vector2(f, f)

func set_highlight(on: bool) -> void:
	_highlighted = on

func interact() -> void:
	if once_flag != "" and GameState.has_flag(once_flag):
		return
	DialogueManager.start(lines)
	if once_flag != "":
		GameState.set_flag(once_flag)
	if on_finished_flag != "":
		if not DialogueManager.dialogue_finished.is_connected(_on_done):
			DialogueManager.dialogue_finished.connect(_on_done, CONNECT_ONE_SHOT)

func _on_done() -> void:
	GameState.set_flag(on_finished_flag)
