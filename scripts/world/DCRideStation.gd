extends MinigameStation
## Chapter 5 — station 1: ride the dendritic cell along the CCL19 gradient.

func _configure() -> void:
	station_name = "Lymph Vessel"
	texture_path = "res://assets/env/vessel_mouth.png"
	sprite_max_dim = 190.0
	required_flag = "antigen_presented"
	done_flag = "dc_migrated"
	minigame_script = preload("res://scripts/minigames/ChemokineNav.gd")
	prompt_offset = Vector2(0, -130)
	interact_radius = 120.0
	hint_lines = [
		["Scroll", "The Scout Cell has nothing to show yet. It must first put the Enemy's Face in its Display Window."],
	]
	intro_lines = [
		["Scroll", "The Scout Cell wears the Enemy's Face. Now it must reach the Training Camp, where the Knights wait."],
		Glossary.card("lymph_node"),
		["Arin", "How does it know the way?"],
		["Scroll", "It follows its nose! The Training Camp gives off a Scent Trail, and the Scout Cell sniffs it out with its antennae."],
		Glossary.card("chemokine"),
		Glossary.card("ccr7"),
		["Arin", "Then I'll steer it. Onward!"],
	]
	finish_lines = [
		["Scroll", "The lymph carries the Scout Cell into the Training Camp. Thousands of young Knights wait inside, each with a differently shaped lock."],
		Glossary.card("tcell"),
		["Arin", "One of them must fit the Enemy's Face. Let's find it."],
	]
	replay_lines = [
		["Scroll", "The Scout Cell has already reached the Training Camp. Enter the Knights' Hall to the north."],
	]
	fail_lines = [
		["Scroll", "The Scout Cell is lost in the tissue. Follow the Scent Trail to reach the vessel."],
	]
