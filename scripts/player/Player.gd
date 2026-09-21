extends CharacterBody2D
## Prince Arin — top-down movement for keyboard and touch, plus jump / leap
## (hazards on the ground can't touch him while airborne) and a hurt state.
## Touch input is fed through the same input actions by the HUD (joystick +
## buttons), so this script reads the "move_*" / "jump" actions and works
## identically on all devices.

@export var speed: float = 260.0
@export var acceleration: float = 1800.0
@export var friction: float = 2000.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_area: Area2D = $InteractArea

const FRAME_DIR := "res://assets/characters/prince_hd/"
const JUMP_TIME := 0.5        # standing hop
const JUMP_HEIGHT := 58.0
const LEAP_TIME := 0.55       # running leap (long jump)
const LEAP_HEIGHT := 46.0
const LEAP_SPEED := 2.1       # x walking speed while leaping
const HURT_TIME := 0.45
const INVULN_TIME := 1.1

var _facing: int = 1
var _current_interactable: Node = null

# Event-tracked key state. We drive movement from events because polled
# Input.is_action_pressed() is unreliable for keyboard in the web export
# (keydown reaches _input, but the Input singleton's held-state doesn't update).
var _k_left := false
var _k_right := false
var _k_up := false
var _k_down := false
var _jump_queued := false

# jump / leap
var _air_t := -1.0            # < 0 = on the ground
var _air_dur := 0.0
var _air_height := 0.0
var _leaping := false
var _leap_vel := Vector2.ZERO
var _jump_cool := 0.0
# hurt
var _hurt_t := 0.0
var _invuln_t := 0.0
var _shadow: Polygon2D
var _sprite_base_y := -2.0

func _ready() -> void:
	add_to_group("player")
	_build_frames()
	sprite.scale = Vector2(0.63, 0.63)   # 99x160 HD frames -> ~96px tall in-game (1.5x)
	_sprite_base_y = sprite.position.y
	sprite.play("idle")
	_build_shadow()

func _build_shadow() -> void:
	_shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(Vector2(cos(TAU * i / 20.0) * 26.0, sin(TAU * i / 20.0) * 9.0))
	_shadow.polygon = pts
	_shadow.color = Color(0, 0, 0, 0.28)
	_shadow.position = Vector2(0, 46)
	_shadow.z_index = -1
	add_child(_shadow)

## Build the SpriteFrames (original prince art) in code so no .tres is needed.
func _build_frames() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_anim(sf, "idle", ["idle_0", "idle_1"], 3.0, true)
	_add_anim(sf, "walk", ["walk_0", "walk_1", "walk_2", "walk_3", "walk_4", "walk_5"], 10.0, true)
	# action frames fall back to walk frames if the art is missing
	_add_anim(sf, "jump", ["jump_0", "jump_1", "jump_2"], 6.0, false, ["walk_1", "walk_2", "walk_4"])
	_add_anim(sf, "leap", ["leap_0"], 1.0, false, ["walk_2"])
	_add_anim(sf, "hurt", ["hurt_0"], 1.0, false, ["idle_1"])
	sprite.sprite_frames = sf

func _add_anim(sf: SpriteFrames, name: String, frames: Array, fps: float, loop: bool, fallback: Array = []) -> void:
	sf.add_animation(name)
	sf.set_animation_speed(name, fps)
	sf.set_animation_loop(name, loop)
	var any := false
	for f in frames:
		var p: String = FRAME_DIR + f + ".png"
		if ResourceLoader.exists(p):
			sf.add_frame(name, load(p))
			any = true
	if not any:
		for f in fallback:
			var p2: String = FRAME_DIR + f + ".png"
			if ResourceLoader.exists(p2):
				sf.add_frame(name, load(p2))

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

# --------------------------------------------------------------------------
# public state queries (used by hazards / pits / levels)
func is_airborne() -> bool:
	return _air_t >= 0.0

func is_invulnerable() -> bool:
	return _invuln_t > 0.0 or _hurt_t > 0.0

## Knock the player back and play the hurt pose; grants brief invulnerability.
func hurt(knock: Vector2) -> void:
	_hurt_t = HURT_TIME
	_invuln_t = INVULN_TIME
	_air_t = -1.0
	_leaping = false
	velocity = knock
	sprite.play("hurt")
	sprite.speed_scale = 1.0

## Harmless shove (e.g. bouncing off a shielded hazard).
func bounce(knock: Vector2) -> void:
	velocity = knock

## Cancel any jump (used when the level respawns the player).
func reset_state() -> void:
	_air_t = -1.0
	_leaping = false
	_hurt_t = 0.0
	_invuln_t = 0.0
	velocity = Vector2.ZERO
	sprite.position.y = _sprite_base_y
	sprite.modulate.a = 1.0
	sprite.play("idle")

# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_jump_cool = maxf(0.0, _jump_cool - delta)
	if DialogueManager.is_active() or GameState.cutscene_active:
		velocity = Vector2.ZERO
		_jump_queued = false
		if not is_airborne() and sprite.animation != "idle":
			sprite.play("idle")
		return
	var dir := _key_vector()
	if _hurt_t > 0.0:
		_hurt_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, friction * 0.8 * delta)
		move_and_slide()
		_blink(delta)
		return
	if _invuln_t > 0.0:
		_invuln_t -= delta
		_blink(delta)
		if _invuln_t <= 0.0:
			sprite.modulate.a = 1.0
	# jump / leap start
	if _jump_queued and not is_airborne() and _jump_cool <= 0.0:
		_jump_queued = false
		_start_jump(dir)
	_jump_queued = false
	if is_airborne():
		_air_t += delta
		var f: float = clampf(_air_t / _air_dur, 0.0, 1.0)
		var h: float = sin(f * PI) * _air_height
		sprite.position.y = _sprite_base_y - h
		_shadow.scale = Vector2.ONE * (1.0 - 0.45 * (h / maxf(1.0, _air_height)))
		_shadow.color.a = 0.28 - 0.14 * (h / maxf(1.0, _air_height))
		if _leaping:
			velocity = _leap_vel
			sprite.play("leap")
		else:
			# a hop keeps some steering, but slower
			velocity = velocity.move_toward(dir * speed * 0.9, acceleration * 0.5 * delta)
			sprite.play("jump")
			var n := sprite.sprite_frames.get_frame_count("jump")
			if n >= 3:
				sprite.frame = 0 if f < 0.18 else (1 if f < 0.8 else 2)
		if abs(velocity.x) > 5.0:
			_facing = 1 if velocity.x > 0.0 else -1
			sprite.flip_h = _facing < 0
		move_and_slide()
		if f >= 1.0:
			_land()
		_update_interactable()
		return
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

func _blink(delta: float) -> void:
	sprite.modulate.a = 0.45 if fmod(_invuln_t, 0.16) < 0.08 else 1.0

func _start_jump(dir: Vector2) -> void:
	_air_t = 0.0
	if dir.length() > 0.2:
		_leaping = true
		_air_dur = LEAP_TIME
		_air_height = LEAP_HEIGHT
		_leap_vel = dir.normalized() * speed * LEAP_SPEED
		velocity = _leap_vel
		sprite.play("leap")
	else:
		_leaping = false
		_air_dur = JUMP_TIME
		_air_height = JUMP_HEIGHT
		sprite.play("jump")
	sprite.speed_scale = 1.0
	DebugConsole.dlog("jump leap=%s" % _leaping)

func _land() -> void:
	_air_t = -1.0
	_leaping = false
	_jump_cool = 0.12
	sprite.position.y = _sprite_base_y
	_shadow.scale = Vector2.ONE
	_shadow.color.a = 0.28
	velocity *= 0.5
	sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	# Track movement keys from events (robust across desktop/web).
	if event is InputEventKey and not event.echo:
		if event.is_action("move_left"): _k_left = event.is_pressed()
		if event.is_action("move_right"): _k_right = event.is_pressed()
		if event.is_action("move_up"): _k_up = event.is_pressed()
		if event.is_action("move_down"): _k_down = event.is_pressed()
	if event.is_action_pressed("jump") and not DialogueManager.is_active() and not GameState.cutscene_active:
		_jump_queued = true
	if event.is_action_pressed("interact") and is_instance_valid(_current_interactable) and not DialogueManager.is_active() and not GameState.cutscene_active and not is_airborne():
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
