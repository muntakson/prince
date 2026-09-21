extends Area2D
class_name Hazard
## A roaming enemy that hurts the player on contact (unless the player is
## airborne from a jump/leap, or a shield flag/item makes it harmless).
## Movement modes: "patrol" (loop through `points`), "chase" (patrol, but home
## in on the player within `chase_range`), "drift" (wander inside `bounds`).
## Activation: only active while `active_flag` is set (if given) and until
## `inactive_flag` is set (if given). Damage goes through the level's
## `damage(amount, source)`; contact also knocks the player back.
## All motion is polled in _process (no physics, no tweens) — web-safe.

var hazard_name := "Hazard"
var texture_path := ""
var sprite_max_dim := 96.0
var mode := "patrol"
var points: Array = []            # patrol waypoints (world coords)
var bounds := Rect2()             # drift/chase clamp area
var speed := 120.0
var chase_range := 320.0
var chase_speed := 170.0
var hit_radius := 40.0
var damage := 0.34
var knockback := 420.0
var hit_cooldown := 0.9
var ground_only := true           # a jumping player passes over it
var active_flag := ""
var inactive_flag := ""
var shield_flag := ""             # once set, contact is harmless (bounce)
var shield_item := ""             # inventory item that makes contact harmless
var shield_text := "The lipid shell repels it!"
var aura_color := Color(0, 0, 0, 0)   # optional soft halo (radius = hit_radius*1.6)
var flip_with_motion := true
var bob_amp := 5.0

var _sprite: Sprite2D
var _aura: Polygon2D
var _t := 0.0
var _cool := 0.0
var _wp := 0
var _dir := Vector2.RIGHT
var _rng := RandomNumberGenerator.new()
var _drift_target := Vector2.ZERO
var _bounce_t := 0.0
var _home := Vector2.ZERO

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 8
	collision_mask = 0
	monitorable = false
	monitoring = false
	_home = position
	_rng.seed = int(position.x * 7 + position.y * 13)
	_sprite = Sprite2D.new()
	if texture_path != "" and ResourceLoader.exists(texture_path):
		_sprite.texture = load(texture_path)
		var s := _sprite.texture.get_size()
		var f: float = sprite_max_dim / max(s.x, s.y)
		_sprite.scale = Vector2(f, f)
	_sprite.z_index = 5
	add_child(_sprite)
	if aura_color.a > 0.0:
		_aura = Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 28:
			pts.append(Vector2.from_angle(TAU * i / 28.0) * hit_radius * 1.6)
		_aura.polygon = pts
		_aura.color = aura_color
		_aura.z_index = 4
		add_child(_aura)
	if bounds.size == Vector2.ZERO:
		bounds = Rect2(position - Vector2(300, 300), Vector2(600, 600))
	if mode == "drift":
		_pick_drift_target()

func is_active() -> bool:
	if active_flag != "" and not GameState.has_flag(active_flag):
		return false
	if inactive_flag != "" and GameState.has_flag(inactive_flag):
		return false
	return true

func is_shielded() -> bool:
	if shield_flag != "" and GameState.has_flag(shield_flag):
		return true
	if shield_item != "" and Inventory.has(shield_item):
		return true
	return false

func _pick_drift_target() -> void:
	_drift_target = Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), _rng.randf_range(bounds.position.y, bounds.end.y))

func _process(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	_bounce_t = maxf(0.0, _bounce_t - delta)
	var active := is_active()
	# dormant hazards fade out and stop
	_sprite.modulate.a = move_toward(_sprite.modulate.a, 1.0 if active else 0.0, delta * 2.0)
	if _aura:
		_aura.modulate.a = move_toward(_aura.modulate.a, 1.0 if active else 0.0, delta * 2.0)
	_sprite.position.y = sin(_t * 3.0) * bob_amp
	if not active:
		return
	if DialogueManager.is_active() or GameState.cutscene_active:
		return
	var player = get_tree().get_first_node_in_group("player")
	var moved := Vector2.ZERO
	match mode:
		"patrol":
			moved = _step_patrol(delta, speed)
		"chase":
			if player and is_instance_valid(player) and position.distance_to(player.global_position) < chase_range and not is_shielded():
				var d: Vector2 = (player.global_position - position)
				if d.length() > 4.0:
					moved = d.normalized() * chase_speed * delta
					position += moved
					position.x = clampf(position.x, bounds.position.x, bounds.end.x)
					position.y = clampf(position.y, bounds.position.y, bounds.end.y)
			else:
				moved = _step_patrol(delta, speed)
		"drift":
			var d2 := _drift_target - position
			if d2.length() < 10.0:
				_pick_drift_target()
			else:
				moved = d2.normalized() * speed * delta
				position += moved
	if flip_with_motion and absf(moved.x) > 0.01:
		_sprite.flip_h = moved.x < 0.0
	# contact
	if player == null or not is_instance_valid(player):
		return
	if _cool > 0.0:
		return
	var pr: float = 26.0
	if position.distance_to(player.global_position + Vector2(0, 10)) > hit_radius + pr:
		return
	if ground_only and player.has_method("is_airborne") and player.is_airborne():
		return
	if player.has_method("is_invulnerable") and player.is_invulnerable():
		return
	_cool = hit_cooldown
	var away: Vector2 = (player.global_position - position)
	away = away.normalized() if away.length() > 1.0 else Vector2.DOWN
	if is_shielded():
		# harmless: the player bounces off, the hazard recoils
		_bounce_t = 0.5
		_cool = hit_cooldown * 1.6
		position -= away * 70.0
		if player.has_method("bounce"):
			player.bounce(away * knockback * 0.5)
		var lvl = get_tree().current_scene
		if lvl and lvl.has_method("flash_text"):
			lvl.flash_text(shield_text)
		DebugConsole.dlog("%s bounced (shield)" % hazard_name)
		return
	if player.has_method("hurt"):
		player.hurt(away * knockback)
	var level = get_tree().current_scene
	if level and level.has_method("damage"):
		level.damage(damage, hazard_name)
	DebugConsole.dlog("%s hit player" % hazard_name)

func _step_patrol(delta: float, spd: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var target: Vector2 = points[_wp]
	var d := target - position
	if d.length() < 6.0:
		_wp = (_wp + 1) % points.size()
		return Vector2.ZERO
	var step := d.normalized() * minf(spd * delta, d.length())
	position += step
	return step
