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
		["Scroll", "The T-cells are still in the blood. Lead them out of the vessel to the south and through the stroma first."],
	]
	intro_lines = [
		["Scroll", "The T-cells that made it through the stroma are inside the tumor now."],
		["Arin", "So many cells... how will they know which ones to strike?"],
		["Scroll", "Every cell shows pieces of its inner proteins on MHC class I. Tumor cells show the vaccine antigen; healthy cells show only self. The T-cell reads each one before it strikes."],
		["Scroll", "Beware: some tumor cells wear PD-L1, a checkpoint that switches T-cells off. A checkpoint-inhibitor antibody can remove that disguise."],
		["Arin", "Then let the hunt begin!"],
	]
	finish_lines = [
		["Scroll", "The tumor is gone. Perforin opened the way, granzymes did the work, and every tumor cell died by apoptosis — while the healthy cells were untouched."],
		["Scroll", "Some of the T-cells become memory cells. If the cancer ever returns, they will remember its face."],
		["Arin", "Mira... it is over. Let's go home."],
	]
	replay_lines = [
		["Scroll", "The tumor has been destroyed. Mira waits to the north."],
	]
	fail_lines = [
		["Scroll", "The tumor still grows. Read each cell's MHC-I peptide: strike the vaccine antigen, spare self — and grab the antibody to beat PD-L1."],
	]

func _on_success() -> void:
	GameState.set_flag("story_complete")
