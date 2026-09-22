extends CharacterBody2D
## Prince Arin — top-down movement for keyboard and touch, driven by an
## explicit Prince-of-Persia style state machine:
##
##   IDLE -> WALK (hold a direction) -> RUN (keep holding ~0.35 s)
##   RUN releases into a short slide (momentum) before IDLE
##   JUMP  = standing / walking hop        LEAP = running long jump
##   LEDGE_GRAB = (a) walked (or hopped short) onto a pit edge: hang, then
##                climb back up (push away / JUMP) or let go (push in / grip
##                fails); (b) jumped at a low wall: RayLow (feet) hits the wall
##                while RayHigh (hands) passes over its top -> that is the
##                ledge; hang from it, push in / JUMP to pull himself over,
##                push away to drop back down
##   FALL  = dropped into a pit (level fades out and respawns)
##   HURT  = knocked back by a hazard (brief invulnerability)
##
## Touch input is fed through the same input actions by the HUD (joystick +
## buttons), so this script reads the "move_*" / "jump" actions and works
## identically on all devices.

enum State { IDLE, WALK, RUN, JUMP, LEAP, FALL, LEDGE_GRAB, HURT }

@export var walk_speed: float = 190.0
@export var speed: float = 320.0          # run speed
@export var acceleration: float = 1800.0  # walk accel (snappy)
@export var run_acceleration: float = 900.0 # building up to a run takes a moment
@export var friction: float = 2000.0      # stopping from a walk
@export var slide_friction: float = 900.0 # stopping from a run: he skids

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interact_area: Area2D = $InteractArea

const FRAME_DIR := "res://assets/characters/prince_hd/"
const RUN_AFTER := 0.5        # seconds of held direction before WALK -> RUN (~95 px of walking)
const JUMP_TIME := 0.5        # standing hop
const JUMP_HEIGHT := 58.0
const LEAP_TIME := 0.55       # running leap (long jump)
const LEAP_HEIGHT := 46.0
const LEAP_SPEED := 1.7       # x run speed while leaping (~300 px)
const HURT_TIME := 0.45
const INVULN_TIME := 1.1
const GRIP_TIME := 3.0        # how long he can hang before his grip fails
const CLIMB_TIME := 0.4
const CLIMB_DIST := 34.0
const FEET_OFFSET := Vector2(0, 22)
const BODY_OFFSET := Vector2(0, 10)   # capsule centre (see Player.tscn)
const BODY_RADIUS := 12.0
const RAY_LEN := 30.0                 # forward reach of the two ledge rays
const TALL_WALL_LAYER := 16           # walls too tall to climb carry this layer bit
const WALL_CLIMB_TIME := 0.55
const WALL_GRAB_MIN_H := 12.0         # must be well off the ground to catch a wall top
const WALL_HANG_MIN := 0.35           # he hangs at least this long before input decides climb / drop

var state: int = State.IDLE
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

# walk / run
var _hold_t := 0.0            # how long a direction has been held continuously
# jump / leap
var _air_t := -1.0            # < 0 = on the ground
var _air_dur := 0.0
var _air_height := 0.0
var _leap_vel := Vector2.ZERO
var _jump_cool := 0.0
# ledge grab
var _ledge_kind := "pit"      # "pit" (hanging over a chasm) or "wall" (hanging from a wall top)
var _ledge_pit: Node = null
var _ledge_dir := Vector2.DOWN  # unit vector from the edge INTO the pit / wall
var _ledge_anchor := Vector2.ZERO
var _ledge_exit := Vector2.ZERO # where a wall climb ends (the far side of the wall)
var _hang_t := 0.0              # time spent hanging (wall ledge)
var _ray_low: RayCast2D         # feet: hits any wall
var _ray_high: RayCast2D        # hands: hits only tall walls, passes over climbable ones
var _grip_t := 0.0
var _climb_t := -1.0          # >= 0 while pulling himself up
var _release_armed := false   # pushing INTO the pit only lets go after the stick was released once
# fall
var _fall_t := 0.0
# hurt
var _hurt_t := 0.0
var _invuln_t := 0.0
var _shadow: Polygon2D
var _sprite_base_y := -2.0
var _sprite_base_scale := Vector2(0.63, 0.63)
var mounted := false          # riding a cell: one still image, no jumping

func _ready() -> void:
	add_to_group("player")
	_build_frames()
	sprite.scale = _sprite_base_scale   # 99x160 HD frames -> ~96px tall in-game (1.5x)
	_sprite_base_y = sprite.position.y
	sprite.play("idle")
	_build_shadow()
	_build_ledge_rays()

## Two forward sensors (Prince of Persia style): the low one at the feet hits
## every wall, the high one only walls carrying the "tall" layer. Low hit +
## high miss while airborne = a wall top the prince can catch.
func _build_ledge_rays() -> void:
	_ray_low = RayCast2D.new()
	_ray_low.name = "RayLow"
	_ray_low.position = BODY_OFFSET
	_ray_low.collision_mask = 1
	_ray_low.enabled = false
	_ray_low.collide_with_areas = false
	add_child(_ray_low)
	_ray_high = RayCast2D.new()
	_ray_high.name = "RayHigh"
	_ray_high.position = BODY_OFFSET
	_ray_high.collision_mask = TALL_WALL_LAYER
	_ray_high.enabled = false
	_ray_high.collide_with_areas = false
	add_child(_ray_high)

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

## Ride a cell (Chapter 5: the dendritic cell with the prince aboard). The
## prince frames are replaced by one still image scaled to `height` px, the
## shadow widens, and jumping is disabled; movement/interaction stay the same.
func mount(texture_path: String, height: float = 170.0) -> void:
	if not ResourceLoader.exists(texture_path):
		return
	var tex: Texture2D = load(texture_path)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in ["idle", "walk", "jump", "leap", "hurt", "hang"]:
		sf.add_animation(a)
		sf.set_animation_loop(a, false)
		sf.add_frame(a, tex)
	sprite.sprite_frames = sf
	var s := tex.get_size()
	_sprite_base_scale = Vector2.ONE * (height / max(s.x, s.y))
	sprite.scale = _sprite_base_scale
	_sprite_base_y = 48.0 - height / 2.0   # keep the image's bottom at the prince's feet
	sprite.position = Vector2(0, _sprite_base_y)
	var pts := PackedVector2Array()
	for i in 20:
		pts.append(Vector2(cos(TAU * i / 20.0) * 46.0, sin(TAU * i / 20.0) * 14.0))
	_shadow.polygon = pts
	mounted = true
	sprite.play("idle")

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
	_add_anim(sf, "hang", ["jump_0"], 1.0, false, ["idle_1"])   # crouched grip pose
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

func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)

func _set_state(s: int) -> void:
	if s == state:
		return
	DebugConsole.dlog("player %s -> %s" % [state_name(), State.keys()[s]])
	state = s

# --------------------------------------------------------------------------
# public state queries (used by hazards / pits / levels / debug mirror)
func state_name() -> String:
	return State.keys()[state]

func is_airborne() -> bool:
	return state == State.JUMP or state == State.LEAP

func is_running() -> bool:
	return state == State.RUN

func is_hanging() -> bool:
	return state == State.LEDGE_GRAB

func ledge_kind() -> String:
	return _ledge_kind if state == State.LEDGE_GRAB else ""

func is_invulnerable() -> bool:
	return _invuln_t > 0.0 or state == State.HURT or state == State.LEDGE_GRAB or state == State.FALL

## A pit asks this before deciding between "catch the edge" and "fall":
## a careful walk (or a short hop) catches the ledge, a run carries him over.
func can_grab_ledge() -> bool:
	return state == State.IDLE or state == State.WALK

## Catch the edge of `pit`. `edge_point` is the feet position on the rim,
## `into_dir` the unit direction from the rim into the chasm.
func ledge_grab(pit: Node, edge_point: Vector2, into_dir: Vector2) -> void:
	_ledge_kind = "pit"
	_ledge_pit = pit
	_ledge_dir = into_dir
	_ledge_anchor = edge_point - FEET_OFFSET - into_dir * 2.0
	global_position = _ledge_anchor
	velocity = Vector2.ZERO
	_grip_t = GRIP_TIME
	_climb_t = -1.0
	_release_armed = false
	_hold_t = 0.0
	_jump_queued = false
	_set_state(State.LEDGE_GRAB)
	if abs(into_dir.x) > 0.5:
		_facing = 1 if into_dir.x > 0.0 else -1
		sprite.flip_h = _facing < 0
	sprite.play("hang")
	sprite.speed_scale = 1.0
	_shadow.color.a = 0.0
	AudioManager.sfx("grab")
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_hint"):
		hud.flash_hint("Ledge! Push away or JUMP to climb up")

## Mid-jump ledge check (the pasted PoP rule): RayLow hits a wall and RayHigh
## passes over it. Returns true when the prince caught a wall top.
func _try_wall_grab(dir: Vector2, h: float) -> bool:
	if dir.length() < 0.2 or h < WALL_GRAB_MIN_H:
		return false
	var d := dir.normalized()
	_ray_low.target_position = d * RAY_LEN
	_ray_high.target_position = d * RAY_LEN
	_ray_low.force_raycast_update()
	_ray_high.force_raycast_update()
	if not _ray_low.is_colliding() or _ray_high.is_colliding():
		return false
	var body := _ray_low.get_collider()
	if body == null or not (body is StaticBody2D):
		return false
	var owner_id: int = body.shape_find_owner(_ray_low.get_collider_shape())
	var cs: Object = body.shape_owner_get_owner(owner_id)
	if cs == null or not cs.has_meta("rect"):
		return false
	var rect: Rect2 = cs.get_meta("rect")
	var into: Vector2 = -_ray_low.get_collision_normal()
	# axis-aligned walls: snap the direction so the climb goes straight across
	into = Vector2(signf(into.x), 0.0) if abs(into.x) >= abs(into.y) else Vector2(0.0, signf(into.y))
	var point: Vector2 = _ray_low.get_collision_point()
	var thickness: float = rect.size.x if into.x != 0.0 else rect.size.y
	_ledge_kind = "wall"
	_ledge_pit = null
	_ledge_dir = into
	_ledge_anchor = point - into * (BODY_RADIUS + 2.0) - BODY_OFFSET
	_ledge_exit = _ledge_anchor + into * (BODY_RADIUS + 2.0 + thickness + BODY_RADIUS + 14.0)
	global_position = _ledge_anchor
	velocity = Vector2.ZERO
	_air_t = -1.0
	_hang_t = 0.0
	_grip_t = GRIP_TIME
	_climb_t = -1.0
	_release_armed = true
	_hold_t = 0.0
	_jump_queued = false
	_set_state(State.LEDGE_GRAB)
	if into.x != 0.0:
		_facing = int(into.x)
		sprite.flip_h = _facing < 0
	sprite.play("hang")
	sprite.speed_scale = 1.0
	_shadow.scale = Vector2.ONE
	_shadow.color.a = 0.18
	DebugConsole.dlog("wall grab into=(%d,%d) thick=%d" % [into.x, into.y, thickness])
	AudioManager.sfx("grab")
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_hint"):
		hud.flash_hint("Ledge! Push in or JUMP to climb over")
	return true

## Drop into a pit (called by Pit when a run carries him over the edge).
func fall_into(pit: Node) -> void:
	_ledge_pit = pit
	_start_fall()

## Knock the player back and play the hurt pose; grants brief invulnerability.
func hurt(knock: Vector2) -> void:
	if state == State.FALL:
		return
	collision_mask = 1
	_hurt_t = HURT_TIME
	_invuln_t = INVULN_TIME
	_air_t = -1.0
	_hold_t = 0.0
	_ledge_pit = null
	_restore_sprite()
	velocity = knock
	_set_state(State.HURT)
	sprite.play("hurt")
	AudioManager.sfx("hurt")
	sprite.speed_scale = 1.0

## Harmless shove (e.g. bouncing off a shielded hazard).
func bounce(knock: Vector2) -> void:
	if state == State.LEDGE_GRAB or state == State.FALL:
		return
	velocity = knock
	AudioManager.sfx("bounce")

## Cancel any jump / hang / fall (used when the level respawns the player).
func reset_state() -> void:
	collision_mask = 1
	_air_t = -1.0
	_hurt_t = 0.0
	_invuln_t = 0.0
	_hold_t = 0.0
	_ledge_pit = null
	_climb_t = -1.0
	velocity = Vector2.ZERO
	_restore_sprite()
	sprite.modulate = Color.WHITE
	_set_state(State.IDLE)
	sprite.play("idle")

func _restore_sprite() -> void:
	sprite.position.y = _sprite_base_y
	sprite.position.x = 0.0
	sprite.scale = _sprite_base_scale
	sprite.rotation = 0.0
	_shadow.scale = Vector2.ONE
	_shadow.color.a = 0.28

# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_jump_cool = maxf(0.0, _jump_cool - delta)
	if _invuln_t > 0.0 and state != State.HURT:
		_invuln_t -= delta
		_blink()
		if _invuln_t <= 0.0:
			sprite.modulate.a = 1.0
	if state == State.FALL:
		_jump_queued = false
		_process_fall(delta)
		return
	if DialogueManager.is_active() or GameState.cutscene_active:
		velocity = Vector2.ZERO
		_jump_queued = false
		_hold_t = 0.0
		if state == State.LEDGE_GRAB:
			_process_ledge(delta, Vector2.ZERO)
		elif not is_airborne():
			_set_state(State.IDLE)
			_play("idle")
		return
	var dir := _key_vector()
	match state:
		State.HURT:
			_process_hurt(delta)
		State.LEDGE_GRAB:
			_process_ledge(delta, dir)
		State.JUMP, State.LEAP:
			_process_air(delta, dir)
		_:
			_process_ground(delta, dir)
	_jump_queued = false

	if mounted and state != State.HURT and state != State.FALL:
		# the ridden cell crawls: a gentle bob and lean while moving
		var moving: bool = velocity.length() > 20.0
		sprite.position.y = _sprite_base_y + (sin(Time.get_ticks_msec() / 90.0) * 3.0 if moving else 0.0)
		sprite.rotation = (velocity.x / maxf(speed, 1.0)) * 0.06 if moving else 0.0

func _process_hurt(delta: float) -> void:
	_hurt_t -= delta
	velocity = velocity.move_toward(Vector2.ZERO, friction * 0.8 * delta)
	move_and_slide()
	_blink()
	if _hurt_t <= 0.0:
		_set_state(State.IDLE)
		sprite.play("idle")

func _process_ground(delta: float, dir: Vector2) -> void:
	# jump / leap start
	if _jump_queued and _jump_cool <= 0.0:
		_jump_queued = false
		_start_jump(dir)
		return
	var moving := dir.length() > 0.05
	if moving:
		_hold_t += delta
		if abs(dir.x) > 0.1:
			_facing = 1 if dir.x > 0.0 else -1
			sprite.flip_h = _facing < 0
		var reversing := velocity.length() > 40.0 and dir.dot(velocity.normalized()) < -0.3
		if state == State.RUN and reversing:
			# turning around at speed costs the run: skid, then walk the new way
			_hold_t = 0.0
			_set_state(State.WALK)
		if state == State.RUN or (state == State.WALK and _hold_t >= RUN_AFTER):
			_set_state(State.RUN)
			velocity = velocity.move_toward(dir * speed, run_acceleration * delta)
		else:
			_set_state(State.WALK)
			velocity = velocity.move_toward(dir * walk_speed, acceleration * delta)
		_play("walk")
		# animation speed tracks how fast we're actually moving
		sprite.speed_scale = clampf(velocity.length() / walk_speed, 0.4, 1.8)
	else:
		_hold_t = 0.0
		if state == State.RUN or velocity.length() > walk_speed * 1.05:
			# momentum: skid to a stop
			velocity = velocity.move_toward(Vector2.ZERO, slide_friction * delta)
			if velocity.length() > walk_speed * 0.5:
				_set_state(State.RUN)
				_play("walk")
				sprite.speed_scale = 0.5
			else:
				_set_state(State.IDLE)
				_play("idle")
				sprite.speed_scale = 1.0
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			_set_state(State.IDLE)
			_play("idle")
			sprite.speed_scale = 1.0
	move_and_slide()
	_update_interactable()

func _process_air(delta: float, dir: Vector2) -> void:
	_air_t += delta
	var f: float = clampf(_air_t / _air_dur, 0.0, 1.0)
	var h: float = sin(f * PI) * _air_height
	sprite.position.y = _sprite_base_y - h
	_shadow.scale = Vector2.ONE * (1.0 - 0.45 * (h / maxf(1.0, _air_height)))
	_shadow.color.a = 0.28 - 0.14 * (h / maxf(1.0, _air_height))
	if state == State.LEAP:
		velocity = _leap_vel
		_play("leap")
	else:
		# a hop keeps some steering, but slower
		velocity = velocity.move_toward(dir * walk_speed * 0.9, acceleration * 0.5 * delta)
		_play("jump")
		var n := sprite.sprite_frames.get_frame_count("jump")
		if n >= 3:
			sprite.frame = 0 if f < 0.18 else (1 if f < 0.8 else 2)
	if abs(velocity.x) > 5.0:
		_facing = 1 if velocity.x > 0.0 else -1
		sprite.flip_h = _facing < 0
	move_and_slide()
	# use the intended direction (not the post-collision velocity, which is zero
	# when he is already pressed against the wall)
	if _try_wall_grab(_leap_vel if state == State.LEAP else dir, h):
		return
	if f >= 1.0:
		_land()
	_update_interactable()

func _process_ledge(delta: float, dir: Vector2) -> void:
	velocity = Vector2.ZERO
	if _ledge_kind == "wall":
		_process_wall_ledge(delta, dir)
		return
	if _climb_t >= 0.0:
		_climb_t += delta
		var f: float = clampf(_climb_t / CLIMB_TIME, 0.0, 1.0)
		var e: float = 1.0 - (1.0 - f) * (1.0 - f)
		global_position = _ledge_anchor - _ledge_dir * CLIMB_DIST * e
		var hang_off := Vector2(_ledge_dir.x * 16.0, _sprite_base_y + 6.0 + _ledge_dir.y * 16.0)
		sprite.position = hang_off.lerp(Vector2(0.0, _sprite_base_y), f)
		sprite.rotation = _ledge_dir.x * 0.18 * (1.0 - f)
		if f >= 1.0:
			_restore_sprite()
			_ledge_pit = null
			_jump_cool = 0.15
			_set_state(State.IDLE)
			sprite.play("idle")
		return
	_grip_t -= delta
	# hang: crouched pose hanging over the rim, a slow strain-sway
	var sway: float = sin(Time.get_ticks_msec() / 220.0) * 1.5
	sprite.position = Vector2(_ledge_dir.x * 16.0 + sway * _ledge_dir.y, _sprite_base_y + 6.0 + _ledge_dir.y * 16.0 + sway * _ledge_dir.x)
	sprite.rotation = _ledge_dir.x * 0.18
	sprite.play("hang")
	var along: float = dir.dot(_ledge_dir)
	if dir.length() < 0.3:
		_release_armed = true   # the push that carried him onto the rim no longer counts
	if _jump_queued or (dir.length() > 0.3 and along < -0.5):
		_jump_queued = false
		_climb_t = 0.0
		AudioManager.sfx("climb")
		sprite.play("jump")
		sprite.frame = 1
		DebugConsole.dlog("ledge climb")
	elif _grip_t <= 0.0 or (_release_armed and dir.length() > 0.3 and along > 0.5):
		DebugConsole.dlog("ledge let go (%s)" % ("grip failed" if _grip_t <= 0.0 else "pushed"))
		_start_fall()

## Hanging from a wall top. Push in (the "up key" of the pasted design) or
## JUMP pulls him over to the far side; push away or a failed grip drops him
## back where he jumped from (no fall damage: it is only a low wall).
func _process_wall_ledge(delta: float, dir: Vector2) -> void:
	if _climb_t >= 0.0:
		_climb_t += delta
		var f: float = clampf(_climb_t / WALL_CLIMB_TIME, 0.0, 1.0)
		var e: float = f * f * (3.0 - 2.0 * f)   # smoothstep
		global_position = _ledge_anchor.lerp(_ledge_exit, e)
		# he rises over the top and drops down the other side
		var lift: float = sin(f * PI) * 30.0
		sprite.position = Vector2(0.0, _sprite_base_y - lift)
		sprite.rotation = 0.0
		_shadow.scale = Vector2.ONE * (1.0 - 0.3 * (lift / 30.0))
		if f >= 1.0:
			collision_mask = 1
			_restore_sprite()
			_jump_cool = 0.15
			_set_state(State.IDLE)
			sprite.play("idle")
			DebugConsole.dlog("wall climbed -> (%d,%d)" % [global_position.x, global_position.y])
		return
	_grip_t -= delta
	_hang_t += delta
	var sway: float = sin(Time.get_ticks_msec() / 200.0) * 1.2
	sprite.position = Vector2(_ledge_dir.x * 10.0 + sway * _ledge_dir.y, _sprite_base_y - 18.0 + _ledge_dir.y * 6.0 + sway * _ledge_dir.x)
	sprite.rotation = 0.0
	sprite.play("hang")
	if _hang_t < WALL_HANG_MIN:
		_jump_queued = false   # let the grab register before the stick decides anything
		return
	var along: float = dir.dot(_ledge_dir)
	if _jump_queued or (dir.length() > 0.3 and along > 0.5):
		_jump_queued = false
		_climb_t = 0.0
		AudioManager.sfx("climb")
		collision_mask = 0          # pass through the wall while pulling over it
		sprite.play("jump")
		sprite.frame = 1
		DebugConsole.dlog("wall climb")
	elif _grip_t <= 0.0 or (dir.length() > 0.3 and along < -0.5):
		DebugConsole.dlog("wall drop (%s)" % ("grip failed" if _grip_t <= 0.0 else "pushed away"))
		_restore_sprite()
		_jump_cool = 0.15
		_set_state(State.IDLE)
		sprite.play("idle")

func _start_fall() -> void:
	AudioManager.sfx("fall")
	_set_state(State.FALL)
	_fall_t = 0.0
	velocity = Vector2.ZERO
	_hold_t = 0.0
	_climb_t = -1.0
	sprite.play("hang")
	sprite.rotation = 0.0
	_shadow.color.a = 0.0
	if _ledge_pit and is_instance_valid(_ledge_pit) and _ledge_pit.has_method("player_fell"):
		_ledge_pit.player_fell()
	else:
		var level := get_parent()
		while level and not level.has_method("fall"):
			level = level.get_parent()
		if level:
			level.fall("You fell!")

func _process_fall(delta: float) -> void:
	# shrink and sink into the dark while the level fades out; reset_state()
	# (called by the level on respawn) restores the sprite
	_fall_t += delta
	var f: float = clampf(_fall_t / 0.55, 0.0, 1.0)
	sprite.scale = _sprite_base_scale * (1.0 - 0.7 * f)
	sprite.position = Vector2(_ledge_dir.x * 18.0 * f, _sprite_base_y + 8.0 + 26.0 * f)
	sprite.modulate = Color(1.0 - 0.6 * f, 1.0 - 0.6 * f, 1.0 - 0.6 * f, 1.0 - 0.5 * f)

func _blink() -> void:
	sprite.modulate.a = 0.45 if fmod(_invuln_t, 0.16) < 0.08 else 1.0

func _start_jump(dir: Vector2) -> void:
	_air_t = 0.0
	if state == State.RUN and dir.length() > 0.2:
		_set_state(State.LEAP)
		_air_dur = LEAP_TIME
		_air_height = LEAP_HEIGHT
		_leap_vel = dir.normalized() * speed * LEAP_SPEED
		velocity = _leap_vel
		sprite.play("leap")
		AudioManager.sfx("leap")
	else:
		_set_state(State.JUMP)
		_air_dur = JUMP_TIME
		_air_height = JUMP_HEIGHT
		sprite.play("jump")
		AudioManager.sfx("jump")
	_hold_t = 0.0
	sprite.speed_scale = 1.0

func _land() -> void:
	AudioManager.sfx("land")
	_air_t = -1.0
	_jump_cool = 0.12
	_hold_t = 0.0
	sprite.position.y = _sprite_base_y
	_shadow.scale = Vector2.ONE
	_shadow.color.a = 0.28
	velocity *= 0.5
	_set_state(State.IDLE)
	sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	# Track movement keys from events (robust across desktop/web).
	if event is InputEventKey and not event.echo:
		if event.is_action("move_left"): _k_left = event.is_pressed()
		if event.is_action("move_right"): _k_right = event.is_pressed()
		if event.is_action("move_up"): _k_up = event.is_pressed()
		if event.is_action("move_down"): _k_down = event.is_pressed()
	if event.is_action_pressed("jump") and not DialogueManager.is_active() and not GameState.cutscene_active:
		if not mounted:
			_jump_queued = true
	if event.is_action_pressed("interact") and is_instance_valid(_current_interactable) and not DialogueManager.is_active() and not GameState.cutscene_active and not is_airborne() and not is_hanging() and state != State.FALL:
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
