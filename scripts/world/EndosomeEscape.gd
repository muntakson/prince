extends CutsceneStation
## Chapter 4 — the endosome. Once the dendritic cell has taken up the LNP,
## interacting here opens the pH-timing mini-game (break out when the
## ionizable lipids are charged but before the lysosome fuses). On success the
## rupture / release frames of the escape cutscene play and the flag is set.

const DONE_FLAG := "endosome_escape_done"
const TIMING_MG = preload("res://scripts/minigames/EndosomeTiming.gd")

var fail_lines: Array = []
var _mg: Node = null
var _pending_fail := false

func _configure() -> void:
	station_name = "Swallow Bubble (acidic)"
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
		"Pumps fill the Swallow Bubble with acid (pH drops)",
		"In acid, the Magnet Fat turns positive and clings to the wall",
		"The wall weakens... and tears!",
		"The letter slips out through the tear...",
		"Free in the cell fluid: escape complete!",
	]
	hint_lines = [
		["Scroll", "This Swallow Bubble is empty. The Scout Cell to the south must swallow the bubble first."],
	]
	finish_lines = [
		["Scroll", "The acid switched on the Magnet Fat. It turned positive, tore the Swallow Bubble's wall, and burst it open."],
		Glossary.card("ionizable"),
		["Arin", "The letter slips out through the tear. Free at last!"],
		["Scroll", "Now the Printing Press can read it. Head north, but hurry: the cell is full of letter-eating enzymes."],
	]
	replay_lines = [
		["Scroll", "The letter has already escaped. The Printing Press to the north is waiting to read it."],
	]
	fail_lines = [
		["Scroll", "The letter was digested! Wait until the acid is strong enough (pH below 6.6), but break out before pH 5, when the Digesting Sack arrives."],
		Glossary.card("lysosome"),
		["Arin", "The cell is taking in more particles. Let me try again."],
	]

func _process(delta: float) -> void:
	super._process(delta)
	if _pending_fail and not DialogueManager.is_active():
		_pending_fail = false
		DialogueManager.start(fail_lines)

## Instead of playing the frames right away, run the timing mini-game first.
func _start_cutscene() -> void:
	if _mg != null and is_instance_valid(_mg):
		return
	DialogueManager.start([
		["Scroll", "The Swallow Bubble is turning acidic. Below pH 6.6 the Magnet Fat switches on; below pH 5 the Digesting Sack arrives. Tap or press SPACE in between!"],
	])
	_mg = TIMING_MG.new()
	_mg.finished.connect(_on_timing_finished)
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	# the mini-game mounts once the intro line closes (polled in _process of the mini-game host)
	_mount_after_dialogue(host)

var _host: Node = null
func _mount_after_dialogue(host: Node) -> void:
	_host = host
	set_process(true)
	_state = State.INTRO

func _process_intro(_delta: float, _bob: float) -> void:
	if _host != null and _mg != null and _mg.get_parent() == null and not DialogueManager.is_active():
		_host.add_child(_mg)
		_host = null

func _on_timing_finished(success: bool) -> void:
	_mg = null
	if success:
		_begin_frames(3)
	else:
		_state = State.IDLE
		GameState.cutscene_active = false
		_pending_fail = true
