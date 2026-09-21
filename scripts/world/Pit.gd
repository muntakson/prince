extends Node2D
class_name Pit
## A chasm the player must leap across. Walking into it (not airborne) makes
## the player fall: the level respawns them a second back along their path.
## Drawn in code: dark crevasse with a lighter cracked rim.

var rect := Rect2(0, 0, 400, 70)     # local rect (node position = top-left)
var rim_color := Color(0.35, 0.3, 0.25)
var depth_color := Color(0.02, 0.02, 0.04)
var fall_text := "You fell into the crevasse!"

var _cool := 0.0

func _ready() -> void:
	add_to_group("pit")
	z_index = -40

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, rect.size)
	draw_rect(r.grow(6), rim_color)
	draw_rect(r, depth_color)
	# jagged inner shading
	var pts := PackedVector2Array()
	var n := int(rect.size.x / 40.0) + 1
	for i in n + 1:
		var x := rect.size.x * i / float(n)
		pts.append(Vector2(x, 8.0 + (6.0 if i % 2 == 0 else 18.0)))
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(0.18, 0.16, 0.14), 3.0)
	var pts2 := PackedVector2Array()
	for i in n + 1:
		var x := rect.size.x * i / float(n)
		pts2.append(Vector2(x, rect.size.y - 8.0 - (6.0 if i % 2 == 1 else 18.0)))
	for i in range(pts2.size() - 1):
		draw_line(pts2[i], pts2[i + 1], Color(0.18, 0.16, 0.14), 3.0)

func contains(world_pos: Vector2) -> bool:
	return Rect2(global_position, rect.size).has_point(world_pos)

func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if _cool > 0.0 or DialogueManager.is_active() or GameState.cutscene_active:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("is_airborne") and player.is_airborne():
		return
	# feet point of the player
	var feet: Vector2 = player.global_position + Vector2(0, 22)
	var inner := Rect2(global_position, rect.size).grow(-10)
	if inner.has_point(feet):
		_cool = 2.0
		var level = get_tree().current_scene
		if level and level.has_method("fall"):
			level.fall(fall_text)
