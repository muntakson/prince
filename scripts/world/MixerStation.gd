extends MinigameStation
## Chapter 3 — the microfluidic mixer: encapsulate the mRNA in an LNP.

func _configure() -> void:
	station_name = "Microfluidic Mixer"
	texture_path = "res://assets/env/mixer_chip.png"
	sprite_max_dim = 170.0
	required_flag = "mrna_assembled"
	done_flag = "lnp_made"
	minigame_script = preload("res://scripts/minigames/MicrofluidicMixer.gd")
	prompt_offset = Vector2(0, -105)
	interact_radius = 110.0
	hint_lines = [
		["Mixer", "Nothing to encapsulate yet. Assemble the mRNA at the synthesizer first."],
	]
	intro_lines = [
		["Scroll", "Naked mRNA would be shredded in the blood within minutes. It needs a shield: a lipid nanoparticle."],
		["Mixer", "I am a microfluidic mixer. Feed lipids in ethanol into one inlet and the mRNA in acidic buffer into the other, and my herringbone channel folds them together in milliseconds."],
		["Arin", "Then let's wrap the message."],
	]
	finish_lines = [
		["Mixer", "Batch complete: small, uniform nanoparticles with the mRNA safely inside, now at neutral pH."],
		["Scroll", "The shielded message is ready. Take it to the injection gate — Mira's body awaits."],
	]
	replay_lines = [
		["Mixer", "The LNP batch is ready. Head to the injection gate on the right."],
	]
	fail_lines = [
		["Mixer", "No batch yet. Load both inlets, set the flow ratio to 3:1 with a fast total flow, run, then exchange the buffer."],
	]
