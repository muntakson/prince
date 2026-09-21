extends Node
## Boot entry point (main scene). Warms up, then hands off to the main menu.

func _ready() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
