extends CharacterBody2D
## Prince Arin — top-down movement for keyboard and touch.
## Touch input is fed through the same input actions by TouchControls, so this
## script only reads the "move_*" actions and works identically on all devices.

@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var friction: float = 2000.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_area: Area2D = $InteractArea

const FRAME_DIR := "res://assets/characters/prince_hd/"

var _facing: int = 1
var _current_interactable: Node = null

# Event-tracked key state. We drive movement from events because polled
# Input.is_action_pressed() is unreliable for keyboard in the web export
# (keydown reaches _input, but the Input singleton's held-state doesn't update).
var _k_left := false
var _k_right := false
var _k_up := false
var _k_down := false

func _ready() -> void:
	add_to_group("player")
	_build_frames()
	sprite.scale = Vector2(0.63, 0.63)   # 99x160 HD frames -> ~96px tall in-game (1.5x)
	sprite.play("idle")

## Build the SpriteFrames (original prince art) in code so no .tres is needed.
func _build_frames() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_anim(sf, "idle", ["idle_0", "idle_1"], 3.0, true)
	_add_anim(sf, "walk", ["walk_0", "walk_1", "walk_2", "walk_3", "walk_4", "walk_5"], 10.0, true)
	sprite.sprite_frames = sf

func _add_anim(sf: SpriteFrames, name: String, frames: Array, fps: float, loop: bool) -> void:
	sf.add_animation(name)
	sf.set_animation_speed(name, fps)
	sf.set_animation_loop(name, loop)
	for f in frames:
		var p: String = FRAME_DIR + f + ".png"
		if ResourceLoader.exists(p):
			sf.add_frame(name, load(p))

func _notification(what: int) -> void:
	# Releasing focus (tab-out) should clear held keys so we don't "stick".
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_k_left = false; _k_right = false; _k_up = false; _k_down = false

func _key_vector() -> Vector2:
	var v := Vector2(
		(1.0 if _k_right else 0.0) - (1.0 if _k_left else 0.0),
		(1.0 if _k_down else 0.0) - (1.0 if _k_up else 0.0))
	# Fold in touch/other sources that feed the Input actions directly.
	v += Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return v.limit_length(1.0)

func _physics_process(delta: float) -> void:
	if DialogueManager.is_active() or GameState.cutscene_active:
		velocity = Vector2.ZERO
		if sprite.animation != "idle":
			sprite.play("idle")
		return
	var dir := _key_vector()
	if dir.length() > 0.05:
		velocity = velocity.move_toward(dir * speed, acceleration * delta)
		if abs(dir.x) > 0.1:
			_facing = 1 if dir.x > 0.0 else -1
			sprite.flip_h = _facing < 0
		if sprite.animation != "walk":
			sprite.play("walk")
		# animation speed tracks how fast we're actually moving
		sprite.speed_scale = clampf(velocity.length() / speed, 0.4, 1.6)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if sprite.animation != "idle":
			sprite.play("idle")
		sprite.speed_scale = 1.0
	move_and_slide()
	_update_interactable()

func _unhandled_input(event: InputEvent) -> void:
	# Track movement keys from events (robust across desktop/web).
	if event is InputEventKey and not event.echo:
		if event.is_action("move_left"): _k_left = event.is_pressed()
		if event.is_action("move_right"): _k_right = event.is_pressed()
		if event.is_action("move_up"): _k_up = event.is_pressed()
		if event.is_action("move_down"): _k_down = event.is_pressed()
	if event.is_action_pressed("interact") and is_instance_valid(_current_interactable) and not DialogueManager.is_active() and not GameState.cutscene_active:
		if _current_interactable.has_method("interact"):
			_current_interactable.interact()


## --- interaction detection: nearest overlapping "interactable" ---
func _update_interactable() -> void:
	var nearest: Node = null
	var best := INF
	for body in interact_area.get_overlapping_areas():
		if body.is_in_group("interactable"):
			var d := global_position.distance_to(body.global_position)
			if d < best:
				best = d
				nearest = body
	if nearest != _current_interactable:
		if is_instance_valid(_current_interactable) and _current_interactable.has_method("set_highlight"):
			_current_interactable.set_highlight(false)
		_current_interactable = nearest
		if is_instance_valid(_current_interactable) and _current_interactable.has_method("set_highlight"):
			_current_interactable.set_highlight(true)
