extends LevelBase
## Chapter 1 — The Cave. Arin descends through the cave to reach Mira's chamber.
## A crevasse across the path teaches the jump / leap move.

func _ready() -> void:
	chapter_id = "cave"
	room_size = Vector2(1400, 2200)
	floor_texture = preload("res://assets/env/floor_cave.png")
	wall_texture = preload("res://assets/env/wall_cave.png")
	default_spawn = Vector2(700, 2050)
	super._ready()

func build_content() -> void:
	# Simple cave obstacles forming a path upward toward the chamber exit.
	add_wall_rect(Rect2(0, 1650, 900, 40))
	add_wall_rect(Rect2(500, 1150, 900, 40))
	add_wall_rect(Rect2(0, 650, 900, 40))
	add_wall_rect(Rect2(300, 300, 40, 360))

	add_label(Vector2(440, 1830), "Use the joystick or WASD / arrows to move. Press E or the hand button to interact.", 24, 520)

	# A crevasse across the whole corridor: the player must leap it.
	add_pit(Rect2(0, 1390, 1400, 72), "You fell into the crevasse! Leap across it.")
	add_label(Vector2(440, 1500), "A crevasse! Run at it and press SPACE (or the JUMP button) to leap across.", 22, 520)

	# The scroll's first whisper — a glowing hint object.
	add_npc(Vector2(1100, 1550), "Ancient Scroll",
		[["Scroll", "A voice echoes: 'Brave Arin... the Princess waits beyond. Hurry.'"]],
		"res://assets/env/scroll.png", "cave_scroll_seen")

	# Exit to the Princess's chamber.
	add_portal(Vector2(700, 120), "palace", "To the Chamber", Vector2(700, 1750))
