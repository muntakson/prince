extends CutsceneStation
## Chapter 4 — antigen presentation. After translation, interacting here plays
## the MHC cutscene: the antigen peptide loads onto an MHC molecule on the cell
## surface, a T-cell docks its receptor onto it, and the activated T-cell
## multiplies — the immune system has learned the cancer's face.

const DONE_FLAG := "antigen_presented"

func _configure() -> void:
	station_name = "Antigen Presentation"
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
		"A piece of the antigen is carried to the cell surface",
		"The peptide loads into the groove of an MHC molecule",
		"A T-cell arrives to inspect what the cell is showing",
		"Its receptor locks onto the antigen–MHC complex",
		"Activated! T-cells multiply, trained to hunt the cancer",
	]
	hint_lines = [
		["Scroll", "The MHC molecules wait empty. First the ribosome to the south must build the antigen protein."],
	]
	finish_lines = [
		["Scroll", "The tumor antigen is displayed on the cell surface by an MHC molecule. T-cells inspect it, recognize it, and multiply into an army that hunts any cell wearing the same antigen."],
		["Arin", "But the T-cells that must learn this face gather elsewhere... in the lymph nodes. Let's go."],
	]
	replay_lines = [
		["Scroll", "The antigen is displayed on the cell surface. Now the dendritic cell must carry it to a lymph node — the way lies north."],
	]
