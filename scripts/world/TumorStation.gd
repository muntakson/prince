extends MinigameStation
## Chapter 6 — the tumor: the effector T-cell army hunts tumor cells.

func _configure() -> void:
	station_name = "The Tumor"
	texture_path = "res://assets/env/tumor_cell.png"
	sprite_max_dim = 170.0
	required_flag = "tcells_herded"
	done_flag = "tumor_cleared"
	minigame_script = preload("res://scripts/minigames/TumorHunt.gd")
	prompt_offset = Vector2(0, -120)
	interact_radius = 120.0
	hint_lines = [
		["Scroll", "The Knights are still in the blood. First lead them out of the vessel to the south and through the walls."],
	]
	intro_lines = [
		["Scroll", "The Knights that made it through the walls are inside the tumor now."],
		["Arin", "So many cells... how will they know which ones to strike?"],
		["Scroll", "Every cell shows bits of its insides in its Display Window. Tumor cells show the Enemy's Face; healthy cells show their own. Check each window before you strike!"],
		["Scroll", "Beware: some tumor cells carry a Fake Pass that switches Knights off. Grab the Pass Blocker to cancel it."],
		Glossary.card("pdl1"),
		Glossary.card("antibody"),
		["Arin", "Then let the hunt begin!"],
	]
	finish_lines = [
		["Scroll", "The tumor is gone! The Knights punched holes in each tumor cell and slipped in a poison that made it self-destruct. Healthy cells were untouched."],
		Glossary.card("perforin"),
		Glossary.card("apoptosis"),
		["Scroll", "Some Knights become Veteran Knights. If the cancer ever returns, they will remember its face."],
		Glossary.card("memory"),
		["Arin", "Mira... it is over. Let's go home."],
	]
	replay_lines = [
		["Scroll", "The tumor has been destroyed. Mira waits to the north."],
	]
	fail_lines = [
		["Scroll", "The tumor still grows. Check each Display Window: strike the Enemy's Face, spare healthy cells, and grab the Pass Blocker to beat the Fake Pass."],
	]

func _on_success() -> void:
	GameState.set_flag("story_complete")
