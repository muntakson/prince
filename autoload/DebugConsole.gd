extends CanvasLayer
## On-screen debug console (bottom-left). Shows live game state + an event log,
## so freezes can be diagnosed on-device. Autoloaded as "DebugConsole".
## Runs even while the tree is paused (PROCESS_MODE_ALWAYS), so a stuck-pause is
## distinguishable from a real hang: if the frame counter keeps rising but
## paused=true, it's a stuck dialogue/pause; if the counter freezes, it's a hang.

var enabled := false
var _label: Label
var _log: Array[String] = []
var _frame := 0
var _is_web := OS.has_feature("web")
var url_flags: Array = []     # web: ?flags=a,b grants story flags from the chapter-select (debug) menu
var url_chapter := ""         # web: ?chapter=<id> jumps straight into that chapter (test aid)

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 6
	panel.offset_top = -300
	panel.offset_bottom = -6
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)
	dlog("DebugConsole ready")
	# The overlay is hidden by default. Opt in with "?debug" in the web URL or
	# the "--debug-console" command-line argument. Logging (dlog/print) and the
	# window.__ss state mirror for browser automation keep running regardless.
	var want := false
	if _is_web:
		var q = JavaScriptBridge.eval("String(window.location.search)", true)
		want = str(q).contains("debug")
	elif OS.get_cmdline_user_args().has("--debug-console") or OS.get_cmdline_args().has("--debug-console"):
		want = true
	set_enabled(want)
	if _is_web:
		var q2 = JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('flags') || ''", true)
		for f in str(q2).split(","):
			if f.strip_edges() != "":
				url_flags.append(f.strip_edges())
		var q3 = JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('chapter') || ''", true)
		url_chapter = str(q3).strip_edges()

func dlog(msg: String) -> void:
	_log.append("%d| %s" % [_frame, msg])
	if _log.size() > 10:
		_log.pop_front()
	print("[DBG] ", msg)

func set_enabled(on: bool) -> void:
	enabled = on
	visible = on

func _process(_delta: float) -> void:
	_frame += 1
	if _is_web and _frame % 6 == 0:
		_export_state_to_js()
	if not enabled or _label == null:
		return
	var tree := get_tree()
	var paused := tree.paused if tree else false
	var dlg_active := DialogueManager.is_active()
	var dlg_q := DialogueManager.queue_size() if DialogueManager.has_method("queue_size") else -1
	var player = tree.get_first_node_in_group("player") if tree else null
	var pinfo := "no player"
	if player and is_instance_valid(player):
		var inter = player.get("_current_interactable") if player.has_method("get") else null
		var iname := "none"
		if inter != null and is_instance_valid(inter):
			iname = str(inter.name)
		pinfo = "pos=(%d,%d) inter=%s vel=%d" % [
			player.global_position.x, player.global_position.y, iname,
			int(player.velocity.length()) if "velocity" in player else 0]
	var head := "f=%d fps=%d paused=%s\nDLG active=%s q=%d\nchap=%s inv=%d/7\n%s" % [
		_frame, Engine.get_frames_per_second(), paused,
		dlg_active, dlg_q,
		GameState.current_chapter, Inventory.count_mrna(), pinfo]
	_label.text = head + "\n----\n" + "\n".join(_log)

## Web only: mirror live game state into `window.__ss` so browser automation
## (Playwright) can wait on real state instead of guessing with timers.
func _export_state_to_js() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var hud = tree.get_first_node_in_group("hud")
	var player = tree.get_first_node_in_group("player")
	var st := {
		"frame": _frame,
		"paused": tree.paused,
		"dlg": DialogueManager.is_active(),
		"dlg_q": DialogueManager.queue_size(),
		"typing": bool(hud.get("_typing")) if hud and is_instance_valid(hud) else false,
		"cutscene": GameState.cutscene_active,
		"chapter": GameState.current_chapter,
		"flags": GameState.flags.keys(),
		"inv": Inventory.count_mrna(),
		"log": _log.back() if not _log.is_empty() else "",
	}
	if player and is_instance_valid(player):
		st["px"] = int(player.global_position.x)
		st["py"] = int(player.global_position.y)
		var inter = player.get("_current_interactable")
		st["inter"] = str(inter.name) if inter != null and is_instance_valid(inter) else ""
	var scene = tree.current_scene
	if scene and is_instance_valid(scene) and "integrity" in scene:
		st["meter"] = {"on": scene.meter_on, "v": scene.integrity, "label": scene.meter_label, "respawning": scene._respawn_t >= 0.0}
	if player and is_instance_valid(player) and player.has_method("is_airborne"):
		st["air"] = player.is_airborne()
	var help = tree.get_first_node_in_group("help_screen")
	st["help"] = help.lang if help and is_instance_valid(help) else ""
	var hz := []
	for h in tree.get_nodes_in_group("hazard"):
		if h.is_active():
			hz.append([int(h.global_position.x), int(h.global_position.y), h.is_shielded()])
	st["hazards"] = hz
	var stations := []
	for n in tree.get_nodes_in_group("cutscene_station"):
		stations.append({"name": n.station_name, "state": n._state, "x": int(n.global_position.x), "y": int(n.global_position.y)})
	st["stations"] = stations
	var mg = tree.get_first_node_in_group("minigame")
	if mg and is_instance_valid(mg) and mg.has_method("debug_state"):
		st["mg"] = mg.debug_state()
	var css := tree.root.content_scale_size
	var win := DisplayServer.window_get_size()
	st["scale"] = minf(float(win.x) / float(css.x), float(win.y) / float(css.y)) if css.x > 0 and css.y > 0 else 1.0
	JavaScriptBridge.eval("window.__ss=%s;" % JSON.stringify(st), true)
