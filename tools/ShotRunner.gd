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
var mg_autoplay := true      # autoplay=0 to leave a station's mini-game idle for a still shot
var hazard_flags := ""       # flags=a,b : extra story flags to grant before the shot
var act := ""                # act=jump|leap|walkup : player action right before the burst
var player_at := ""          # at=x,y : teleport the player before the shot
var show_help := ""          # help=en|ko : open the Help screen in that language
var dump_labels := false     # labels=1 : print every in-world Label's position/size before the shot

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
		elif a.begins_with("autoplay="): mg_autoplay = a.substr(9) == "1"
		elif a.begins_with("flags="): hazard_flags = a.substr(6)
		elif a.begins_with("act="): act = a.substr(4)
		elif a.begins_with("at="): player_at = a.substr(3)
		elif a.begins_with("help="): show_help = a.substr(5)
		elif a.begins_with("labels="): dump_labels = a.substr(7) == "1"
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
	for f in hazard_flags.split(","):
		if f.strip_edges() != "":
			GameState.set_flag(f.strip_edges())
	if player_at != "":
		var xy := player_at.split(",")
		var pl0 = get_tree().get_first_node_in_group("player")
		if pl0 and xy.size() == 2:
			pl0.global_position = Vector2(float(xy[0]), float(xy[1]))
	for i in wait_frames:
		await get_tree().process_frame
	if dump_labels:
		_dump_labels_of(get_tree().root)
	if show_help != "":
		GameState.lang = show_help   # HelpScreen opens in the shared F3 language
		HelpScreen.lang = show_help
		HelpScreen.open(get_tree())
		for k in 10:
			await get_tree().process_frame
	if act != "":
		var pl1 = get_tree().get_first_node_in_group("player")
		if pl1:
			if act == "walkup" or act == "leap" or act.begins_with("vault"):
				pl1._k_up = true
			if act.begins_with("walkdown") or act.begins_with("hang"):
				pl1._k_down = true
			if act == "jump" or act == "leap" or act.begins_with("vault"):
				# a leap needs a run-up: hold the direction until WALK -> RUN
				for k in (120 if act != "jump" else 6):
					await get_tree().process_frame
					if act != "jump" and pl1.has_method("is_running") and pl1.is_running():
						break
				pl1._jump_queued = true
			if act.begins_with("vault"):
				# leap up at a low wall; wait for the wall grab, then keep pushing in
				# (climb over) or push away (vaultdrop)
				for k in 120:
					await get_tree().process_frame
					if pl1.is_hanging():
						break
				if act == "vaultdrop":
					pl1._k_up = false
					for k in 15:
						await get_tree().process_frame
					pl1._k_down = true
				elif act == "vaulthang":
					pl1._k_up = false
			if act.begins_with("hang"):
				# walk onto the rim, wait for the grab, then climb (hangclimb) or let go (hangdrop)
				for k in 90:
					await get_tree().process_frame
					if pl1.has_method("is_hanging") and pl1.is_hanging():
						break
				pl1._k_down = false
				for k in 20:
					await get_tree().process_frame
				if act == "hangclimb":
					pl1._k_up = true
				elif act == "hangdrop":
					pl1._k_down = true
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
				if trigger_station.to_lower().begins_with("endo"):
					# skip the intro line, then autoplay the timing mini-game
					for k in 3:
						await get_tree().process_frame
					DialogueManager.advance()
					for k in 3:
						await get_tree().process_frame
					var mg = get_tree().get_first_node_in_group("minigame")
					if mg and mg_autoplay:
						mg.debug_autoplay = true
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
		if trigger_mg.to_lower().begins_with("the") or trigger_mg.to_lower().begins_with("tumor"):
			GameState.set_flag("tcells_herded")
		var pl = get_tree().get_first_node_in_group("player")
		for st in get_tree().get_nodes_in_group("minigame_station"):
			if st.station_name.to_lower().begins_with(trigger_mg.to_lower()):
				if pl:
					pl.global_position = st.global_position + Vector2(0, 160)
				await get_tree().process_frame
				st.intro_lines = []
				st.interact()
				await get_tree().process_frame
				if st._mg != null and is_instance_valid(st._mg) and mg_autoplay:
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

func _dump_labels_of(n: Node) -> void:
	if n is Label and n.text != "":
		print("LABEL '%s' pos=%s size=%s min=%s" % [n.text.left(28), n.global_position, n.size, n.get_combined_minimum_size()])
	for c in n.get_children():
		_dump_labels_of(c)
