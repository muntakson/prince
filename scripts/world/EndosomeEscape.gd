extends CutsceneStation
## Chapter 4 — the endosome. Once the dendritic cell has taken up the LNP,
## interacting here plays the endosomal-escape cutscene: the endosome
## acidifies, the ionizable lipids gain charge and fuse with the membrane,
## the membrane ruptures, and the mRNA slips out into the cytoplasm.

const DONE_FLAG := "endosome_escape_done"

var _proton_t := 0.0

func _configure() -> void:
	station_name = "Endosome (acidic)"
	frame_dir = "res://assets/env/endo_anim/"
	frame_prefix = "escape_"
	frame_count = 6
	sprite_scale = 0.62
	done_flag = DONE_FLAG
	required_flag = "lnp_uptake_done"
	hold_time = 1.4
	caption_offset = Vector2(0, -200)
	prompt_offset = Vector2(0, -165)
	captions = [
		"",
		"Protons pump in — the endosome turns acidic (pH drops)",
		"The ionizable lipids gain positive charge and fuse with the membrane",
		"The membrane destabilizes and ruptures!",
		"The mRNA slips out through the tear...",
		"Free in the cytoplasm — endosomal escape complete",
	]
	hint_lines = [
		["Scroll", "This endosome is empty. The nanoparticle must first be captured by the dendritic cell to the south."],
	]
	finish_lines = [
		["Scroll", "Inside the endosome the pH dropped. The ionizable lipids became positively charged, disrupted the membrane, and the vesicle burst open."],
		["Arin", "The mRNA escapes through the torn membrane into the cytoplasm — free at last!"],
		["Scroll", "Now the ribosomes can read it. Head north."],
	]
	replay_lines = [
		["Scroll", "The mRNA has already escaped this endosome. The ribosome to the north is waiting to translate it."],
	]
