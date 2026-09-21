extends MinigameStation
## Chapter 5 — station 2: the T-cell chamber (TCR screening, synapse, clones).

func _configure() -> void:
	station_name = "T-Cell Chamber"
	texture_path = "res://assets/env/tcell_naive.png"
	sprite_max_dim = 120.0
	required_flag = "dc_migrated"
	done_flag = "tcell_activated"
	minigame_script = preload("res://scripts/minigames/TCellChamber.gd")
	prompt_offset = Vector2(0, -100)
	interact_radius = 110.0
	hint_lines = [
		["Scroll", "The T-cell zone is sealed. The dendritic cell must first arrive through the lymphatic vessel."],
	]
	intro_lines = [
		["Scroll", "Naive T-cells. Each carries one unique T-cell receptor, a TCR. Only a receptor shaped to fit our antigen on MHC can recognise it."],
		["Arin", "Like a key and a lock. Let the dendritic cell show the antigen, and we test them one by one."],
	]
	finish_lines = [
		["Scroll", "The matching T-cell locked onto the antigen, received its three signals, and multiplied into an army of identical fighters."],
		["Arin", "Every one of them knows the face of Mira's cancer."],
		["Mira", "Arin... I can feel my strength returning. The message you delivered has become an army. Thank you."],
	]
	replay_lines = [
		["Scroll", "The T-cell army is on the march. Follow them north, out through the efferent lymph toward the tumor."],
	]
	fail_lines = [
		["Scroll", "No T-cell was activated. Compare each TCR's notches with the antigen key and test the one that fits."],
	]
