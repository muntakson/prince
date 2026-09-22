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
const GRAB_REACH := 48.0   # how far past the rim he can still catch it

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
	if player.has_method("is_hanging") and player.is_hanging():
		return
	if "state" in player and player.state == player.State.FALL:
		return
	# feet point of the player
	var feet: Vector2 = player.global_position + Vector2(0, 22)
	var inner := Rect2(global_position, rect.size).grow(-10)
	if not inner.has_point(feet):
		return
	# A careful walk (or a short hop) onto the rim catches the ledge; a run
	# carries him over the edge and he falls.
	if player.has_method("can_grab_ledge") and player.can_grab_ledge():
		var edges := [
			[feet.y - inner.position.y, Vector2(feet.x, inner.position.y), Vector2.DOWN],
			[inner.end.y - feet.y, Vector2(feet.x, inner.end.y), Vector2.UP],
			[feet.x - inner.position.x, Vector2(inner.position.x, feet.y), Vector2.RIGHT],
			[inner.end.x - feet.x, Vector2(inner.end.x, feet.y), Vector2.LEFT],
		]
		var best: Array = edges[0]
		for e in edges:
			if e[0] < best[0]:
				best = e
		if best[0] <= GRAB_REACH:
			_cool = 0.4
			player.ledge_grab(self, best[1], best[2])
			DebugConsole.dlog("ledge grab d=%d" % int(best[0]))
			return
	_cool = 2.0
	if player.has_method("fall_into"):
		player.fall_into(self)
	else:
		player_fell()

## The player let go of (or ran over) the rim: the level fades and respawns.
func player_fell() -> void:
	_cool = 2.0
	var level := _level()
	if level:
		level.fall(fall_text)

## The owning level (walks up the tree so it also works when the level is
## embedded, e.g. under tools/ShotRunner).
func _level() -> Node:
	var n := get_parent()
	while n and not n.has_method("fall"):
		n = n.get_parent()
	return n
