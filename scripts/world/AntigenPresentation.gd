extends CutsceneStation
## Chapter 4 — antigen presentation. After translation, interacting here plays
## the MHC cutscene: the antigen peptide loads onto an MHC molecule on the cell
## surface, a T-cell docks its receptor onto it, and the activated T-cell
## multiplies — the immune system has learned the cancer's face.

const DONE_FLAG := "antigen_presented"

func _configure() -> void:
	station_name = "Display Window"
	frame_dir = "res://assets/env/mhc_anim/"
	frame_prefix = "mhc_"
	frame_count = 6
	sprite_scale = 0.6
	done_flag = DONE_FLAG
	required_flag = "translation_done"
	hold_time = 1.4
	interact_radius = 130.0
	caption_offset = Vector2(0, -190)
	prompt_offset = Vector2(0, -155)
	captions = [
		"",
		"A piece of the Enemy's Face travels to the surface",
		"It slots into a Display Window (MHC)",
		"A Knight (T-cell) arrives to inspect it",
		"The Knight's Lock fits the face",
		"Match! The Knights multiply, ready to hunt the cancer",
	]
	hint_lines = [
		["Scroll", "The Display Windows are empty. First the Printing Press to the south must build the Enemy's Face."],
	]
	finish_lines = [
		["Scroll", "The Enemy's Face now sits in a Display Window on the cell's surface. Knights who recognise it will multiply and hunt every cell that wears it."],
		Glossary.card("mhc"),
		["Arin", "But the Knights who must learn this face train somewhere else... at the Training Camp. Let's go."],
	]
	replay_lines = [
		["Scroll", "The Enemy's Face is on display. Now the Scout Cell must carry it to the Training Camp. The way lies north."],
	]
