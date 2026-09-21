extends Area2D
class_name MinigameStation
## Interactable station that launches a mini-game (a CanvasLayer script with a
## `finished(success)` signal). Handles prerequisites, an optional intro
## dialogue, the done-state and follow-up dialogue. Subclasses fill _configure().
## All sequencing is polled from _process (no tween callbacks) — web-safe.

var station_name := "Station"
var texture_path := ""
var sprite_max_dim := 150.0
var required_flag := ""
var required_item := ""
var done_flag := ""
var minigame_script: GDScript = null
var hint_lines: Array = []      # requirement not met
var intro_lines: Array = []     # before the mini-game starts
var finish_lines: Array = []    # after success
var replay_lines: Array = []    # when done
var fail_lines: Array = []      # when the mini-game was closed without success
var prompt_offset := Vector2(0, -110)
var interact_radius := 90.0
var bob_amp := 4.0

var _sprite: Sprite2D
var _prompt: Label
var _highlighted := false
var _t := 0.0
var _pending_launch := false
var _pending_finish := false
var _pending_fail := false
var _mg: Node = null

func _configure() -> void:
	pass

func _ready() -> void:
	_configure()
	add_to_group("interactable")
	add_to_group("minigame_station")
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = interact_radius
	cs.shape = sh
	add_child(cs)
	_sprite = Sprite2D.new()
	if texture_path != "" and ResourceLoader.exists(texture_path):
		_sprite.texture = load(texture_path)
		var s := _sprite.texture.get_size()
		var f: float = sprite_max_dim / max(s.x, s.y)
		_sprite.scale = Vector2(f, f)
	add_child(_sprite)
	_prompt = Label.new()
	_prompt.text = station_name
	_prompt.position = prompt_offset + Vector2(-140, 0)
	_prompt.size = Vector2(280, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TextStyle.apply(_prompt, 24, Color(1, 0.95, 0.7), true)
	_prompt.modulate.a = 0.0
	add_child(_prompt)
	_setup_extra()

func _setup_extra() -> void:
	pass

func is_done() -> bool:
	return done_flag != "" and GameState.has_flag(done_flag)

func requirement_met() -> bool:
	if required_flag != "" and not GameState.has_flag(required_flag):
		return false
	if required_item != "" and not Inventory.has(required_item):
		return false
	return true

func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = sin(_t * 1.6) * bob_amp
	var done := is_done()
	if done:
		_sprite.modulate = Color(0.8, 1.0, 0.85)
	elif requirement_met():
		var pulse := sin(_t * 4.0) * 0.5 + 0.5
		_sprite.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 0.95), pulse)
	else:
		_sprite.modulate = Color(0.85, 0.86, 0.92)
	_prompt.text = (station_name + " (done)") if done else station_name
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if _highlighted else 0.0, delta * 6.0)
	if _pending_launch and not DialogueManager.is_active():
		_pending_launch = false
		_launch()
	if _pending_finish and not DialogueManager.is_active():
		_pending_finish = false
		if not finish_lines.is_empty():
			DialogueManager.start(finish_lines)
	if _pending_fail and not DialogueManager.is_active():
		_pending_fail = false
		if not fail_lines.is_empty():
			DialogueManager.start(fail_lines)

func set_highlight(on: bool) -> void:
	_highlighted = on

func interact() -> void:
	if _mg != null and is_instance_valid(_mg):
		return
	if is_done():
		if not replay_lines.is_empty():
			DialogueManager.start(replay_lines)
		return
	if not requirement_met():
		if not hint_lines.is_empty():
			DialogueManager.start(hint_lines)
		return
	if intro_lines.is_empty():
		_launch()
	else:
		DialogueManager.start(intro_lines)
		_pending_launch = true

func _launch() -> void:
	if minigame_script == null:
		push_warning("MinigameStation %s: no minigame_script" % station_name)
		return
	DebugConsole.dlog("%s minigame start" % station_name)
	_mg = minigame_script.new()
	_mg.finished.connect(_on_minigame_finished)
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(_mg)

func _on_minigame_finished(success: bool) -> void:
	DebugConsole.dlog("%s minigame done ok=%s" % [station_name, success])
	_mg = null
	if success:
		if done_flag != "":
			GameState.set_flag(done_flag)
		_on_success()
		_pending_finish = true
	else:
		_pending_fail = true

func _on_success() -> void:
	pass
