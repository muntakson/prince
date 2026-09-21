extends Node
## Dev-only screenshot runner. Usage:
##   godot --path . tools/ShotRunner.tscn -- scene=res://... out=/abs/path.png wait=90
## Loads the target scene, waits N frames, saves a viewport screenshot, quits.

var target_scene := ""
var out_path := "/tmp/shot.png"
var wait_frames := 90
var trigger_dialogue := false
var trigger_dc := false      # dc=1: give LNP, walk player near the dendritic cell, start uptake
var trigger_station := ""    # station=<name substring>: satisfy prereqs, walk player there, start cutscene
var burst := 1               # shots=N: take N screenshots
var burst_step := 30         # step=M: frames between burst shots
var trigger_mg := ""         # mg=<station name prefix>: open a MinigameStation's mini-game (autoplay)
var mg_skip_intro := true

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): target_scene = a.substr(6)
		elif a.begins_with("out="): out_path = a.substr(4)
		elif a.begins_with("wait="): wait_frames = int(a.substr(5))
		elif a.begins_with("dialogue="): trigger_dialogue = a.substr(9) == "1"
		elif a.begins_with("dc="): trigger_dc = a.substr(3) == "1"
		elif a.begins_with("station="): trigger_station = a.substr(8)
		elif a.begins_with("shots="): burst = int(a.substr(6))
		elif a.begins_with("step="): burst_step = int(a.substr(5))
		elif a.begins_with("mg="): trigger_mg = a.substr(3)
	if target_scene == "":
		push_error("ShotRunner: no scene= provided")
		get_tree().quit(1)
		return
	var ps = load(target_scene)
	if ps == null:
		push_error("ShotRunner: cannot load %s" % target_scene)
		get_tree().quit(1)
		return
	var inst = ps.instantiate()
	add_child(inst)
	_run(inst)

func _run(_inst) -> void:
	for i in wait_frames:
		await get_tree().process_frame
	if trigger_dialogue:
		DialogueManager.start([
			{"speaker": "Mira", "text": "Arin... you came. But I am gravely ill. The healers call it cancer."},
		])
		for i in 60:
			await get_tree().process_frame
	if trigger_dc and trigger_station == "":
		trigger_station = "dend"
	if trigger_station != "":
		Inventory.collect("lnp")
		GameState.set_flag("lnp_uptake_done")
		GameState.set_flag("endosome_escape_done")
		GameState.set_flag("translation_done")
		var pl = get_tree().get_first_node_in_group("player")
		for st in get_tree().get_nodes_in_group("cutscene_station"):
			if st.station_name.to_lower().begins_with(trigger_station.to_lower()) and pl:
				pl.global_position = st.global_position + Vector2(0, 230)
				await get_tree().process_frame
				st.interact()
				break
	if trigger_mg != "":
		GameState.set_flag("quest_started")
		GameState.set_flag("mrna_assembled")
		if not trigger_mg.to_lower().begins_with("mi"):
			Inventory.collect("lnp")
		for f in ["lnp_uptake_done", "endosome_escape_done", "translation_done", "antigen_presented"]:
			GameState.set_flag(f)
		if not trigger_mg.to_lower().begins_with("d"):
			GameState.set_flag("dc_migrated")
			GameState.set_flag("tcell_activated")
		var pl = get_tree().get_first_node_in_group("player")
		for st in get_tree().get_nodes_in_group("minigame_station"):
			if st.station_name.to_lower().begins_with(trigger_mg.to_lower()):
				if pl:
					pl.global_position = st.global_position + Vector2(0, 160)
				await get_tree().process_frame
				st.intro_lines = []
				st.interact()
				await get_tree().process_frame
				if st._mg != null and is_instance_valid(st._mg):
					st._mg.debug_autoplay = true
				break
	for i in burst:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := out_path
		if burst > 1:
			path = out_path.get_basename() + "_%02d." % i + out_path.get_extension()
		var err := img.save_png(path)
		if err != OK:
			push_error("ShotRunner: save failed %d" % err)
		print("SHOT_SAVED %s %dx%d" % [path, img.get_width(), img.get_height()])
		for j in burst_step:
			await get_tree().process_frame
	get_tree().quit(0)
