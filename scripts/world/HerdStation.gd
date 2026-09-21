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
		["Scroll", "No army has been raised yet. The T-cells must first be activated in the lymph node."],
	]
	intro_lines = [
		["Scroll", "The activated T-cells ride the blood and squeeze out of the vessel here, drawn by the tumor's chemokines. But the tumor defends itself."],
		["Scroll", "Regulatory T-cells breathe out IL-10 and TGF-beta that switch fighters off. Cancer-associated fibroblasts wall the tumor in with dense collagen. Hypoxic pockets sap their strength."],
		["Arin", "Then I'll lead them myself. Stay close, all of you!"],
	]
	finish_lines = [
		["Scroll", "The T-cells have infiltrated the tumor. Now each one must read the cells around it and choose its target."],
	]
	replay_lines = [
		["Scroll", "The army is inside the tumor. Head north and begin the hunt."],
	]
	fail_lines = [
		["Scroll", "Too few T-cells reached the tumor. Keep the herd close, steer them around the purple Treg fog, and find the gaps in the stroma."],
	]
