extends MinigameStation
## Chapter 5 — station 1: ride the dendritic cell along the CCL19 gradient.

func _configure() -> void:
	station_name = "Dendritic Cell"
	texture_path = "res://assets/env/dc_rider.png"
	sprite_max_dim = 190.0
	required_flag = "antigen_presented"
	done_flag = "dc_migrated"
	minigame_script = preload("res://scripts/minigames/ChemokineNav.gd")
	prompt_offset = Vector2(0, -130)
	interact_radius = 120.0
	hint_lines = [
		["Scroll", "The dendritic cell has nothing to show yet. It must first present the antigen on MHC."],
	]
	intro_lines = [
		["Scroll", "The dendritic cell carries the antigen on its surface. Now it must travel to a lymph node, where the T-cells gather."],
		["Arin", "How does it know the way?"],
		["Scroll", "It smells its way. The lymph node releases a chemokine, CCL19. The cell raises CCR7 antennae and crawls toward the stronger scent."],
		["Arin", "Then I'll steer it. Onward!"],
	]
	finish_lines = [
		["Scroll", "Carried by the lymph, the dendritic cell reaches the lymph node. Inside, thousands of naive T-cells wait, each with a different receptor."],
		["Arin", "One of them must fit our antigen. Let's find it."],
	]
	replay_lines = [
		["Scroll", "The dendritic cell has already reached the lymph node. Enter the T-cell zone to the north."],
	]
	fail_lines = [
		["Scroll", "The dendritic cell drifts in the tissue. Follow the CCL19 scent with the CCR7 antennae to reach the vessel."],
	]
