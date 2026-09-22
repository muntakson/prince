extends CanvasLayer
## On-screen debug console (bottom-left). Shows live game state + an event log,
## so freezes can be diagnosed on-device. Autoloaded as "DebugConsole".
## Runs even while the tree is paused (PROCESS_MODE_ALWAYS), so a stuck-pause is
## distinguishable from a real hang: if the frame counter keeps rising but
## paused=true, it's a stuck dialogue/pause; if the counter freezes, it's a hang.

var enabled := false          # debug mode opted in: toggle button shown, state mirrored
var show_panel := false       # the overlay panel itself (toggle with the DBG button or F4)
var _label: Label
var _panel: PanelContainer
var _toggle: Button
var _log: Array[String] = []
var _frame := 0
var _is_web := OS.has_feature("web")
var url_flags: Array = []     # web: ?flags=a,b grants story flags from the chapter-select (debug) menu
var url_chapter := ""         # web: ?chapter=<id> jumps straight into that chapter (test aid)

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	_panel = panel
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
	# Small "DBG" button (left of the HUD pause button) that shows/hides the
	# panel, so it can be moved out of the way of dialogue boxes. F4 also
	# toggles it on desktop.
	_toggle = Button.new()
	_toggle.text = "DBG"
	_toggle.custom_minimum_size = Vector2(52, 52)
	_toggle.anchor_left = 1.0
	_toggle.anchor_right = 1.0
	_toggle.position = Vector2(-124, 12)
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.add_theme_font_size_override("font_size", 14)
	_toggle.pressed.connect(func(): set_panel_visible(not show_panel))
	add_child(_toggle)
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
	_build_badge()
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

## Debug mode on/off: shows the DBG toggle button and (initially) the panel.
func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	set_panel_visible(on)

## Show or hide just the overlay panel; the DBG button stays.
func set_panel_visible(on: bool) -> void:
	show_panel = on
	_panel.visible = on
	_toggle.modulate = Color(1, 1, 1, 1.0 if on else 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F4:
		set_panel_visible(not show_panel)
	if event.is_action_pressed("debug_toggle") and not event.is_echo():
		GameState.set_debug_mode(not GameState.debug_mode)
		AudioManager.sfx("voice_on" if GameState.debug_mode else "voice_off")
		AudioManager.show_toast("Debug mode: ON - all stations open" if GameState.debug_mode else "Debug mode: OFF")
		dlog("debug mode %s" % ("on" if GameState.debug_mode else "off"))
		get_viewport().set_input_as_handled()

## Small persistent badge while debug mode is on (F2), independent of the overlay.
var _badge: Label
func _build_badge() -> void:
	_badge = Label.new()
	_badge.text = "DEBUG (F2)"
	_badge.anchor_left = 0.5
	_badge.anchor_right = 0.5
	_badge.offset_left = -70
	_badge.offset_right = 70
	_badge.offset_top = 6
	_badge.offset_bottom = 30
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 15)
	_badge.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.1, 0.1, 0.85)
	sb.border_color = Color(1, 0.7, 0.3, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(3)
	_badge.add_theme_stylebox_override("normal", sb)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = GameState.debug_mode
	# own layer under the tree root: this console's layer is hidden unless the overlay is opted in
	var cl := CanvasLayer.new()
	cl.layer = 199
	cl.add_child(_badge)
	get_tree().root.call_deferred("add_child", cl)
	GameState.debug_mode_changed.connect(func(on: bool): _badge.visible = on)

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
		pinfo = "pos=(%d,%d) inter=%s vel=%d st=%s" % [
			player.global_position.x, player.global_position.y, iname,
			int(player.velocity.length()) if "velocity" in player else 0,
			player.state_name() if player.has_method("state_name") else "?"]
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
	if player and is_instance_valid(player) and player.has_method("state_name"):
		st["state"] = player.state_name()
		st["mounted"] = player.mounted
		st["vel"] = int(player.velocity.length())
		st["ledge"] = player.ledge_kind() if player.has_method("ledge_kind") else ""
	var help = tree.get_first_node_in_group("help_screen")
	st["help"] = help.lang if help and is_instance_valid(help) else ""
	st["debug_mode"] = GameState.debug_mode
	st["lang"] = GameState.lang
	st["voice"] = AudioManager.voice_enabled
	st["voice_playing"] = AudioManager.is_voice_playing()
	st["sfx"] = AudioManager.last_sfx
	st["dbg_panel"] = show_panel
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
