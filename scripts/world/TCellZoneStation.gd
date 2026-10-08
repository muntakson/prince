extends MinigameStation
## Chapter 5 — station 2: the T-cell chamber (TCR screening, synapse, clones).

func _configure() -> void:
	station_name = "Knights' Hall"
	texture_path = "res://assets/env/tcell_naive.png"
	sprite_max_dim = 120.0
	required_flag = "dc_migrated"
	done_flag = "tcell_activated"
	minigame_script = preload("res://scripts/minigames/TCellChamber.gd")
	prompt_offset = Vector2(0, -100)
	interact_radius = 110.0
	hint_lines = [
		["Scroll", "The Knights' Hall is sealed. The Scout Cell must first arrive through the lymph vessel."],
	]
	intro_lines = [
		["Scroll", "Young Knights. Each one has a lock of its very own shape. Only one lock here fits the Enemy's Face."],
		Glossary.card("tcr"),
		["Arin", "Like a key and a lock! Let the Scout Cell show the face, and we test them one by one."],
	]
	finish_lines = [
		["Scroll", "The matching Knight locked on, got all three handshakes, and copied itself into a whole army."],
		Glossary.card("three_signals"),
		Glossary.card("clonal"),
		["Arin", "Every one of them knows the face of Mira's cancer."],
		["Mira", "Arin... I can feel my strength returning. The message you delivered has become an army. Thank you."],
	]
	replay_lines = [
		["Scroll", "The Knight army is on the march. Follow them north, out of the camp and toward the tumor."],
	]
	fail_lines = [
		["Scroll", "No Knight woke up. Compare each lock's notches with the face's bumps, and test the one that fits."],
	]
