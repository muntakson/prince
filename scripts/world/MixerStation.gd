extends MinigameStation
## Chapter 3 — the microfluidic mixer: encapsulate the mRNA in an LNP.

func _configure() -> void:
	station_name = "Bubble Maker"
	texture_path = "res://assets/env/mixer_chip.png"
	sprite_max_dim = 170.0
	required_flag = "mrna_assembled"
	done_flag = "lnp_made"
	minigame_script = preload("res://scripts/minigames/MicrofluidicMixer.gd")
	prompt_offset = Vector2(0, -105)
	interact_radius = 110.0
	hint_lines = [
		["Bubble Maker", "Nothing to wrap yet. Write the letter at the Synthesizer first."],
	]
	intro_lines = [
		["Scroll", "An unprotected letter would be shredded in the blood within minutes. It needs a Bubble Shield."],
		Glossary.card("lnp"),
		["Bubble Maker", "I am the Bubble Maker. Pour the fats into one inlet and the letter into the other. My zig-zag channel folds them into bubbles in a blink."],
		Glossary.card("mixer"),
		["Arin", "Then let's wrap the message."],
	]
	finish_lines = [
		["Bubble Maker", "Done! Thousands of tiny, even bubbles, each with a letter safely inside."],
		["Scroll", "The shielded letter is ready. Take it to the injection gate. Mira's body awaits."],
	]
	replay_lines = [
		["Bubble Maker", "The Bubble Shields are ready. Head to the injection gate on the right."],
	]
	fail_lines = [
		["Bubble Maker", "No bubbles yet. Load both inlets, set the ratio to 3 : 1 with a fast flow, run, then exchange the buffer."],
	]
