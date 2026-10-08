extends MinigameStation
## Chapter 6 — station 1: herd the activated T-cells from the blood vessel
## through the tumor stroma (Tregs, fibroblast walls, hypoxia) to the tumor.

func _configure() -> void:
	station_name = "Blood Vessel Exit"
	texture_path = "res://assets/env/vessel_mouth.png"
	sprite_max_dim = 150.0
	required_flag = "tcell_activated"
	done_flag = "tcells_herded"
	minigame_script = preload("res://scripts/minigames/TCellHerd.gd")
	prompt_offset = Vector2(0, -110)
	interact_radius = 110.0
	hint_lines = [
		["Scroll", "No army has been raised yet. The Knights must first wake up at the Training Camp."],
	]
	intro_lines = [
		["Scroll", "The Knights ride the blood and squeeze out of the vessel here, following the tumor's scent. But the tumor fights back."],
		["Scroll", "Peacekeepers breathe out calm-down chemicals that switch Knights off. Stay out of their purple fog!"],
		Glossary.card("treg"),
		["Scroll", "Wall Builders surround the tumor with thick fibre walls, and pockets of Thin Air sap the Knights' strength."],
		Glossary.card("caf"),
		Glossary.card("hypoxia"),
		["Arin", "Then I'll lead them myself. Stay close, all of you!"],
	]
	finish_lines = [
		["Scroll", "The Knights are inside the tumor. Now each one must check the cells around it and choose its target."],
	]
	replay_lines = [
		["Scroll", "The army is inside the tumor. Head north and begin the hunt."],
	]
	fail_lines = [
		["Scroll", "Too few Knights reached the tumor. Keep the herd close, steer around the purple Peacekeeper fog, and find the gaps in the walls."],
	]
