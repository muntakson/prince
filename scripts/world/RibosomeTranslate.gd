extends CutsceneStation
## Chapter 4 — the ribosome. Once the mRNA has escaped the endosome,
## interacting here plays the translation cutscene: the mRNA threads into
## the ribosome, amino acids are chained together codon by codon, and the
## chain folds into the finished tumor-antigen protein.

const DONE_FLAG := "translation_done"

func _configure() -> void:
	station_name = "Printing Press"
	frame_dir = "res://assets/env/ribo_anim/"
	frame_prefix = "translate_"
	frame_count = 6
	sprite_scale = 0.62
	done_flag = DONE_FLAG
	required_flag = "endosome_escape_done"
	hold_time = 1.4
	interact_radius = 130.0
	caption_offset = Vector2(0, -175)
	prompt_offset = Vector2(0, -140)
	captions = [
		"",
		"The letter threads into the Printing Press",
		"BEGIN found: the first beads are joined",
		"Three letters at a time, the bead chain grows...",
		"The chain folds as the press nears THE END",
		"Done: a copy of the Enemy's Face!",
	]
	hint_lines = [
		["Printing Press", "I am the Printing Press, but I have nothing to read. The letter is still trapped in the Swallow Bubble to the south."],
	]
	finish_lines = [
		["Printing Press", "I read your letter three letters at a time. Each three-letter word adds one bead to a chain."],
		Glossary.card("ribosome"),
		Glossary.card("codon"),
		["Scroll", "The chain folds into the Enemy's Face: a harmless copy of a piece of Mira's cancer. Now the cell can show it to the immune army."],
		Glossary.card("antigen"),
		["Arin", "So the body learns the enemy's face without ever meeting the enemy. On to the surface!"],
	]
	replay_lines = [
		["Printing Press", "The Enemy's Face is built. Carry on north: the cell is showing it on its surface."],
	]
