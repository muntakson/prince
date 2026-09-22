extends Node2D
class_name LevelBase
## Base for all chapters. Builds a walled room + tiled floor, spawns the player,
## mounts the HUD, sets a checkpoint, and exposes helpers so each chapter script
## only has to place content in `build_content()`.

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PORTAL_SCRIPT = preload("res://scripts/world/Portal.gd")
const NPC_SCRIPT = preload("res://scripts/world/StoryNPC.gd")
const PICKUP_SCENE := preload("res://scenes/pickups/MoleculePickup.tscn")
const HAZARD_SCRIPT = preload("res://scripts/world/Hazard.gd")
const PIT_SCRIPT = preload("res://scripts/world/Pit.gd")

@export var chapter_id: String = "cave"
@export var room_size: Vector2 = Vector2(1400, 2000)
@export var floor_texture: Texture2D
@export var wall_texture: Texture2D
@export var music_path: String = ""
@export var default_spawn: Vector2 = Vector2(700, 1800)
@export var floor_stretch: bool = false  # true = stretch one image over the room (organic bg); false = tile

var player: CharacterBody2D
var hud: CanvasLayer
var content_root: Node2D
var _wall_body: StaticBody2D      # tall walls: layer 1 (physics) + 16 (blocks the player's high ray)
var _low_wall_body: StaticBody2D  # climbable walls: layer 1 only, so the high ray passes over them

# --- hazard / integrity system ---
var integrity := 1.0              # 0..1, shown by the HUD meter while meter_on
var meter_on := false
var meter_label := ""
var respawn_point := Vector2.INF  # where a defeated player reappears (INF = chapter spawn)
var _pos_history: Array = []      # recent ground positions (for pit falls)
var _hist_t := 0.0
var _respawn_t := -1.0            # > 0 while the defeat fade plays
var _respawn_text := ""
var _respawn_lines: Array = []
var _fade: ColorRect

const TALL_WALL_LAYERS := 1 | 16   # physics + "too tall to climb" (Player RayHigh mask)
const WALL_THICKNESS := 40.0

func _ready() -> void:
	GameState.set_chapter(chapter_id)
	_build_backdrop()
	content_root = Node2D.new()
	content_root.name = "Content"
	add_child(content_root)
	_build_floor()
	_build_room_walls()
	_spawn_player()
	_mount_hud()
	if music_path != "":
		AudioManager.play_music(music_path)
	build_content()
	GameState.set_checkpoint(chapter_id, player.global_position)
	_build_fade()
	await get_tree().process_frame
	if hud and hud.has_method("show_chapter_title"):
		hud.show_chapter_title(GameState.chapter_title(chapter_id))

## Override in chapter scripts to place pickups, NPCs, portals, hazards.
func build_content() -> void:
	pass

## Called after a defeat/fall respawn (override to reset chapter state).
func on_respawn() -> void:
	pass

func _process(delta: float) -> void:
	# ground-position history (1 s) so a pit fall can put the player back on solid ground
	if player and is_instance_valid(player) and _respawn_t < 0.0:
		_hist_t += delta
		if _hist_t >= 0.1 and not player.is_airborne() and not _in_any_pit(player.global_position + Vector2(0, 22)):
			_hist_t = 0.0
			_pos_history.append(player.global_position)
			if _pos_history.size() > 12:
				_pos_history.pop_front()
	if _respawn_t >= 0.0:
		_respawn_t += delta
		if _fade:
			_fade.color.a = clampf(_respawn_t / 0.35, 0.0, 1.0) if _respawn_t < 0.9 else clampf(1.0 - (_respawn_t - 0.9) / 0.4, 0.0, 1.0)
		if _respawn_t >= 0.9 and player and is_instance_valid(player) and player.get_meta("respawned", false) == false:
			player.set_meta("respawned", true)
			AudioManager.sfx("respawn")
			player.global_position = _respawn_target()
			player.reset_state()
			_pos_history.clear()
			integrity = 1.0
			on_respawn()
		if _respawn_t >= 1.3:
			_respawn_t = -1.0
			if player and is_instance_valid(player):
				player.set_meta("respawned", false)
			if _fade:
				_fade.color.a = 0.0
			if not _respawn_lines.is_empty():
				DialogueManager.start(_respawn_lines)
				_respawn_lines = []
	_update_meter()

func _in_any_pit(p: Vector2) -> bool:
	for pit in get_tree().get_nodes_in_group("pit"):
		if pit.contains(p):
			return true
	return false

var _fall_target := Vector2.INF

func _respawn_target() -> Vector2:
	if _fall_target != Vector2.INF:
		var t := _fall_target
		_fall_target = Vector2.INF
		return t
	if respawn_point != Vector2.INF:
		return respawn_point
	return default_spawn

# --------------------------------------------------------------------------
# hazard API (called by Hazard / Pit / chapter scripts)
func set_meter(label: String, value: float = 1.0) -> void:
	meter_label = label
	integrity = clampf(value, 0.0, 1.0)
	meter_on = true
	_update_meter()

func hide_meter() -> void:
	meter_on = false
	_update_meter()

func _update_meter() -> void:
	if hud and hud.has_method("set_meter"):
		hud.set_meter(meter_label, integrity, meter_on)

func flash_text(text: String) -> void:
	if hud and hud.has_method("flash_hint"):
		hud.flash_hint(text)

## Reduce integrity; at zero the player is defeated and respawns.
func damage(amount: float, source: String = "") -> void:
	if _respawn_t >= 0.0:
		return
	integrity = clampf(integrity - amount, 0.0, 1.0)
	_update_meter()
	if integrity <= 0.0:
		defeat(defeat_message(source), defeat_lines(source))
	elif source != "":
		flash_text("%s! %s %d%%" % [source, meter_label, int(round(integrity * 100.0))])

## Override: HUD text shown when integrity hits zero.
func defeat_message(_source: String) -> String:
	return "Lost!"

## Override: dialogue shown after the respawn.
func defeat_lines(_source: String) -> Array:
	return []

func defeat(text: String, lines: Array = []) -> void:
	if _respawn_t >= 0.0:
		return
	_respawn_t = 0.0
	_respawn_lines = lines
	flash_text(text)
	AudioManager.sfx("defeat")
	DebugConsole.dlog("defeat: %s" % text)

## A pit fall: fade out, put the player back where they stood a second ago.
func fall(text: String) -> void:
	if _respawn_t >= 0.0:
		return
	var back: Vector2 = _pos_history[0] if not _pos_history.is_empty() else default_spawn
	_fall_target = back
	_respawn_t = 0.0
	_respawn_lines = []
	flash_text(text)
	DebugConsole.dlog("fall -> (%d,%d)" % [back.x, back.y])

func _build_fade() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 60
	add_child(cl)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)

## Spawn a Hazard configured from a Dictionary of its properties.
func add_hazard(pos: Vector2, props: Dictionary) -> Node:
	var h := Area2D.new()
	h.set_script(HAZARD_SCRIPT)
	h.position = pos
	for k in props.keys():
		h.set(k, props[k])
	content_root.add_child(h)
	return h

## Spawn a chasm; `rect` is in world coords.
func add_pit(rect: Rect2, text: String = "You fell into the crevasse!") -> Node:
	var p := Node2D.new()
	p.set_script(PIT_SCRIPT)
	p.position = rect.position
	p.rect = Rect2(Vector2.ZERO, rect.size)
	p.fall_text = text
	content_root.add_child(p)
	return p

# --------------------------------------------------------------------------
func _build_backdrop() -> void:
	# Full-screen dark backdrop behind the world so any area outside the room
	# reads as an intentional void rather than raw black tile edges.
	var cl := CanvasLayer.new()
	cl.layer = -100
	add_child(cl)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.06, 0.12))
	grad.set_color(1, Color(0.01, 0.02, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)

func _build_floor() -> void:
	var spr := Sprite2D.new()
	spr.texture = floor_texture
	spr.centered = false
	spr.position = Vector2.ZERO
	spr.z_index = -100
	if floor_stretch and floor_texture != null:
		# Stretch one image over the whole room (for organic backgrounds that would
		# show seams if tiled).
		var ts := floor_texture.get_size()
		spr.scale = Vector2(room_size.x / ts.x, room_size.y / ts.y)
	else:
		# Tile the floor texture across the room in world space via a region'd Sprite2D.
		spr.region_enabled = true
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_rect = Rect2(0, 0, room_size.x, room_size.y)
	add_child(spr)

func _build_room_walls() -> void:
	_wall_body = StaticBody2D.new()
	_wall_body.collision_layer = TALL_WALL_LAYERS
	_wall_body.collision_mask = 0
	add_child(_wall_body)
	_low_wall_body = StaticBody2D.new()
	_low_wall_body.collision_layer = 1
	_low_wall_body.collision_mask = 0
	_low_wall_body.add_to_group("climbable_wall")
	add_child(_low_wall_body)
	var t := WALL_THICKNESS
	# four borders (collision + visual)
	_add_wall_rect(Rect2(-t, -t, room_size.x + 2 * t, t))                       # top
	_add_wall_rect(Rect2(-t, room_size.y, room_size.x + 2 * t, t))              # bottom
	_add_wall_rect(Rect2(-t, 0, t, room_size.y))                               # left
	_add_wall_rect(Rect2(room_size.x, 0, t, room_size.y))                      # right

## Public: add a rectangular wall/obstacle (world coords). A `climbable`
## wall is a low ledge: the prince can jump at it, catch the top edge and
## pull himself over (Player.gd ledge grab). Gates and borders are tall.
func add_wall_rect(rect: Rect2, climbable: bool = false) -> void:
	_add_wall_rect(rect, climbable)

func _add_wall_rect(rect: Rect2, climbable: bool = false) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.position + rect.size / 2.0
	cs.set_meta("rect", rect)
	if climbable:
		_low_wall_body.add_child(cs)
	else:
		_wall_body.add_child(cs)
	# visual
	var spr := Sprite2D.new()
	if wall_texture:
		spr.texture = wall_texture
		spr.region_enabled = true
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.region_rect = Rect2(0, 0, rect.size.x, rect.size.y)
	spr.centered = false
	spr.position = rect.position
	spr.z_index = -50
	if wall_texture == null:
		var cr := ColorRect.new()
		cr.color = Color(0.12, 0.12, 0.2)
		cr.size = rect.size
		cr.position = rect.position
		cr.z_index = -50
		add_child(cr)
	else:
		add_child(spr)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.global_position = SceneManager.consume_spawn(default_spawn)
	add_child(player)
	# Bound the camera to the room so it never scrolls past the walls.
	var cam := player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(room_size.x)
		cam.limit_bottom = int(room_size.y)

func _mount_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)

# --------------------------------------------------------------------------
# content helpers (call from build_content)
func add_pickup(id: String, pos: Vector2) -> Node:
	var p := PICKUP_SCENE.instantiate()
	p.component_id = id
	p.position = pos
	content_root.add_child(p)
	return p

func add_portal(pos: Vector2, target_chapter: String, label: String = "", spawn: Vector2 = Vector2.INF) -> Node:
	var portal := Area2D.new()
	portal.set_script(PORTAL_SCRIPT)
	portal.position = pos
	portal.target_chapter = target_chapter
	portal.label_text = label
	portal.target_spawn = spawn
	content_root.add_child(portal)
	return portal

func add_npc(pos: Vector2, npc_name: String, lines: Array, texture_path: String = "", once_flag: String = "", sprite_max_dim: float = 96.0) -> Node:
	var npc := Area2D.new()
	npc.set_script(NPC_SCRIPT)
	npc.position = pos
	npc.npc_name = npc_name
	npc.lines = lines
	npc.texture_path = texture_path
	npc.once_flag = once_flag
	npc.sprite_max_dim = sprite_max_dim
	content_root.add_child(npc)
	return npc

func add_label(pos: Vector2, text: String, size: int = 26, width: float = 520.0) -> Label:
	var l := Label.new()
	# autowrap first, size last: a Label sized while its text is unwrapped
	# keeps that wider size and the box overflows the intended width
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# never smaller than 26 px: hints must stay readable on bright backdrops
	TextStyle.apply(l, maxi(size, 26), Color(0.88, 0.94, 1.0))
	l.text = text
	l.position = pos
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 0)
	content_root.add_child(l)
	return l
