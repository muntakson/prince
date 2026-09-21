extends Node
## Handles scene transitions with a fade, spawn positioning, and checkpoints.
## Autoloaded as "SceneManager".

signal transition_started(target_scene: String)
signal transition_finished(target_scene: String)

var _fade: ColorRect
var _canvas: CanvasLayer
var _busy: bool = false

## Where the player should spawn in the next level (set before change_scene).
var pending_spawn: Vector2 = Vector2.ZERO
var has_pending_spawn: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = CanvasLayer.new()
	_canvas.layer = 128
	add_child(_canvas)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_fade)

func goto_chapter(chapter_id: String, spawn: Vector2 = Vector2.INF) -> void:
	var path := GameState.chapter_scene(chapter_id)
	if path == "":
		push_warning("SceneManager: no scene for chapter %s" % chapter_id)
		return
	GameState.set_chapter(chapter_id)
	change_scene(path, spawn)

func change_scene(path: String, spawn: Vector2 = Vector2.INF) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneManager: scene not found: %s" % path)
		return
	if spawn != Vector2.INF:
		pending_spawn = spawn
		has_pending_spawn = true
	else:
		has_pending_spawn = false
	_busy = true
	transition_started.emit(path)
	await _fade_to(1.0, 0.35)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade_to(0.0, 0.35)
	_busy = false
	transition_finished.emit(path)

func consume_spawn(default_pos: Vector2) -> Vector2:
	if has_pending_spawn:
		has_pending_spawn = false
		return pending_spawn
	return default_pos

func _fade_to(target_alpha: float, duration: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", target_alpha, duration)
	await t.finished
