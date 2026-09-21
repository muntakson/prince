extends Area2D
## A collectible mRNA component. Place in a level, set `component_id` to one of
## Inventory.COMPONENTS keys. Floats, glows, shows its name when the player is
## near, and is collected on the "interact" action.

@export_enum("cap5", "utr5", "start_codon", "orf", "stop_codon", "utr3", "polya", "lnp", "antibody", "ribosome")
var component_id: String = "cap5"
@export var auto_collect: bool = false   # collect on touch instead of on interact

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var _t: float = 0.0
var _base_y: float = 0.0
var _highlighted: bool = false
var _collecting: bool = false
var _collect_t: float = 0.0
var _collect_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	var tex_path := Inventory.sprite_path(component_id)
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	# scale the (large) molecule art down to a pickup size
	_fit_sprite(96.0)
	label.text = Inventory.component_name(component_id)
	label.modulate.a = 0.0
	_base_y = sprite.position.y
	if Inventory.has(component_id):
		queue_free()
	if auto_collect:
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if _collecting:
		# Fade + shrink out, then free — driven here (not via a tween callback),
		# because tween Callables are fragile in the Godot web export.
		_collect_t += delta
		sprite.scale = _collect_scale * (1.0 + _collect_t * 1.5)
		sprite.modulate.a = maxf(0.0, 1.0 - _collect_t * 4.0)
		label.modulate.a = 0.0
		if _collect_t >= 0.3:
			queue_free()
		return
	_t += delta
	sprite.position.y = _base_y + sin(_t * 2.0) * 6.0
	sprite.rotation = sin(_t * 1.3) * 0.06
	var target_a := 1.0 if _highlighted else 0.0
	label.modulate.a = move_toward(label.modulate.a, target_a, delta * 6.0)
	sprite.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.4, 1.4), (sin(_t * 3.0) * 0.5 + 0.5) if _highlighted else 0.0)

func _fit_sprite(max_dim: float) -> void:
	if sprite.texture == null:
		return
	var s := sprite.texture.get_size()
	var f: float = max_dim / max(s.x, s.y)
	sprite.scale = Vector2(f, f)

func set_highlight(on: bool) -> void:
	_highlighted = on

func interact() -> void:
	_collect()

func _on_body_entered(_b: Node) -> void:
	if _b.is_in_group("player"):
		_collect()

func _on_area_entered(_a: Node) -> void:
	_collect()

func _collect() -> void:
	DebugConsole.dlog("pickup collect: %s" % component_id)
	if Inventory.collect(component_id):
		AudioManager.play_sfx("res://assets/audio/pickup.wav")
		# Stop being interactable immediately, then fade out via _process.
		monitoring = false
		set_deferred("monitorable", false)
		_collect_scale = sprite.scale
		_collecting = true
		DialogueManager.start([
			{"speaker": "Arin", "text": "The %s!" % Inventory.component_name(component_id)},
			{"speaker": "Scroll", "text": Inventory.component_blurb(component_id)},
		])
