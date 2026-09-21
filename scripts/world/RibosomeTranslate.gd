extends CutsceneStation
## Chapter 4 — the ribosome. Once the mRNA has escaped the endosome,
## interacting here plays the translation cutscene: the mRNA threads into
## the ribosome, amino acids are chained together codon by codon, and the
## chain folds into the finished tumor-antigen protein.

const DONE_FLAG := "translation_done"

func _configure() -> void:
	station_name = "Ribosome"
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
		"The free mRNA threads into the ribosome",
		"Reading the start codon: the first amino acids are joined",
		"Codon by codon, the chain grows...",
		"The chain folds as the ribosome nears the stop codon",
		"Translation complete: a tumor-antigen protein!",
	]
	hint_lines = [
		["Ribosome", "I am a ribosome, but I have nothing to read. The mRNA is still trapped inside the endosome to the south."],
	]
	finish_lines = [
		["Ribosome", "I read the message three letters at a time — each codon calls for one amino acid — and linked them into a chain."],
		["Scroll", "The chain folds into the tumor antigen: a harmless copy of a protein found on Mira's cancer cells. Now the cell can show it to the immune system."],
		["Arin", "So the body learns the enemy's face without ever meeting the enemy. On to the surface!"],
	]
	replay_lines = [
		["Ribosome", "The antigen is made. Carry on north — the cell is presenting it on its surface now."],
	]
