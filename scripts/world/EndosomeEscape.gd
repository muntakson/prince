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
		["Scroll", "Now the ribosomes can read it. Head north — but hurry, the cytoplasm is full of nucleases."],
	]
	replay_lines = [
		["Scroll", "The mRNA has already escaped this endosome. The ribosome to the north is waiting to translate it."],
	]
	fail_lines = [
		["Scroll", "The mRNA was digested. Endosomal escape is a race: wait for the lipids to charge (pH below 6.6), but break out before pH 5, when the lysosome fuses."],
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
		["Scroll", "The endosome is acidifying. Watch the pH: the lipids only charge below pH 6.6, and below pH 5 the lysosome arrives. Tap or press SPACE at the right moment to break out."],
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
