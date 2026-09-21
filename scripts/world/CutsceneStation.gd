extends Area2D
class_name CutsceneStation
## Generic interactable station that plays a sequence of sprite frames as a
## short cutscene (crossfade between frames, a caption per stage), then runs a
## dialogue and sets a story flag. Subclasses configure the frames/captions and
## may override `_start_cutscene()` for a custom intro (see DendriticCell).
##
## All timing is driven from _process (no tween callbacks) — safer on web.

# ---- configuration (set by subclass in _configure()) ----
var station_name := "Station"
var frame_dir := ""              # e.g. "res://assets/env/dc_anim/"
var frame_prefix := "frame_"     # files are <prefix><i>.png
var frame_count := 1
var sprite_scale := 0.72
var captions: Array = []         # one String per frame
var done_flag := ""              # GameState flag set when the cutscene finishes
var required_flag := ""          # story flag needed before the cutscene can start
var required_item := ""          # Inventory id needed before the cutscene can start
var hint_lines: Array = []       # dialogue when the requirement is not met
var finish_lines: Array = []     # dialogue after the cutscene
var replay_lines: Array = []     # dialogue when talking again afterwards
var caption_offset := Vector2(0, -230)
var prompt_offset := Vector2(0, -190)
var interact_radius := 150.0
var fade_time := 0.45
var hold_time := 1.2
var bob_amp := 4.0

enum State { IDLE, INTRO, PLAYING, DONE }
var _state: int = State.IDLE
var _frames: Array = []
var _spr_a: Sprite2D
var _spr_b: Sprite2D
var _prompt: Label
var _caption: Label
var _highlighted := false
var _t := 0.0
var _stage := 0
var _stage_t := 0.0

func _configure() -> void:
	pass  # override

func _ready() -> void:
	_configure()
	add_to_group("interactable")
	add_to_group("cutscene_station")
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	for i in frame_count:
		var p := frame_dir + frame_prefix + "%d.png" % i
		_frames.append(load(p) if ResourceLoader.exists(p) else null)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = interact_radius
	cs.shape = shape
	add_child(cs)

	_spr_a = Sprite2D.new()
	_spr_a.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_spr_a)
	_spr_b = Sprite2D.new()
	_spr_b.scale = _spr_a.scale
	_spr_b.modulate.a = 0.0
	add_child(_spr_b)

	_prompt = _make_label(station_name, 24, Color(1, 0.95, 0.7))
	_prompt.position = prompt_offset + Vector2(-120, 0)
	_prompt.size = Vector2(240, 26)
	TextStyle.apply(_prompt, 24, Color(1, 0.95, 0.7), true)
	add_child(_prompt)

	_caption = _make_label("", 26, Color(0.9, 0.96, 1.0))
	_caption.position = caption_offset + Vector2(-270, 0)
	_caption.size = Vector2(540, 0)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.visible = false
	add_child(_caption)

	var done := done_flag != "" and GameState.has_flag(done_flag)
	_stage = frame_count - 1 if done else 0
	_state = State.DONE if done else State.IDLE
	_spr_a.texture = _frames[_stage]
	_setup_extra()

func _setup_extra() -> void:
	pass  # override for extra child nodes

func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TextStyle.apply(l, size, color)
	l.modulate.a = 0.0
	return l

func _process(delta: float) -> void:
	_t += delta
	var bob := sin(_t * 1.6) * bob_amp
	_spr_a.position.y = bob
	_spr_b.position.y = bob
	var busy := _state == State.INTRO or _state == State.PLAYING
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if (_highlighted and not busy) else 0.0, delta * 6.0)
	match _state:
		State.INTRO:
			_process_intro(delta, bob)
		State.PLAYING:
			_stage_t += delta
			var f: float = clampf(_stage_t / fade_time, 0.0, 1.0)
			_spr_b.modulate.a = f
			if f >= 1.0 and _spr_b.texture != null and _spr_a.texture != _spr_b.texture:
				_spr_a.texture = _spr_b.texture
				_spr_b.modulate.a = 0.0
			_process_stage(delta)
			if _stage_t >= fade_time + hold_time:
				if _stage < frame_count - 1:
					_set_stage(_stage + 1, false)
				else:
					_finish()
		_:
			_caption.modulate.a = move_toward(_caption.modulate.a, 0.0, delta * 2.0)

func _process_intro(_delta: float, _bob: float) -> void:
	pass  # override; call _begin_frames(idx) when the intro is done

func _process_stage(_delta: float) -> void:
	pass  # override for per-stage effects

func _begin_frames(first_stage: int) -> void:
	_set_stage(first_stage, true)
	_state = State.PLAYING

func _set_stage(idx: int, instant: bool) -> void:
	_stage = idx
	_stage_t = 0.0
	_caption.text = captions[idx] if idx < captions.size() else ""
	_caption.visible = _caption.text != ""
	_caption.modulate.a = 1.0
	if instant:
		_spr_a.texture = _frames[idx]
		_spr_b.texture = _frames[idx]
		_spr_b.modulate.a = 0.0
	else:
		_spr_b.texture = _frames[idx]
		_spr_b.modulate.a = 0.0
	DebugConsole.dlog("%s stage %d" % [station_name, idx])

func _finish() -> void:
	_state = State.DONE
	GameState.cutscene_active = false
	if done_flag != "":
		GameState.set_flag(done_flag)
	if not finish_lines.is_empty():
		DialogueManager.start(finish_lines)

func set_highlight(on: bool) -> void:
	_highlighted = on

func requirement_met() -> bool:
	if required_flag != "" and not GameState.has_flag(required_flag):
		return false
	if required_item != "" and not Inventory.has(required_item):
		return false
	return true

func interact() -> void:
	if _state == State.INTRO or _state == State.PLAYING:
		return
	if _state == State.DONE:
		if not replay_lines.is_empty():
			DialogueManager.start(replay_lines)
		return
	if not requirement_met():
		if not hint_lines.is_empty():
			DialogueManager.start(hint_lines)
		return
	GameState.cutscene_active = true
	DebugConsole.dlog("%s cutscene start" % station_name)
	_start_cutscene()

## Default: go straight into the frame sequence from frame 1 (frame 0 = idle).
func _start_cutscene() -> void:
	_begin_frames(1 if frame_count > 1 else 0)
