extends LevelBase
## Chapter 5 — The Lymph Node. Prince Arin rides the antigen-presenting
## dendritic cell along the CCL19 chemokine gradient (CCR7) into a lymphatic
## vessel, arrives at the lymph node, enters the T-cell zone and screens naive
## T-cells until one TCR fits the antigen; the immunological synapse forms,
## the T-cell activates and clones — the immune army is born.

const NAV_STATION := preload("res://scripts/world/DCRideStation.gd")
const TC_STATION := preload("res://scripts/world/TCellZoneStation.gd")

var _gate_body: StaticBody2D
var _gate_sprite: Sprite2D
var _gate_label: Label
var _tcells: Array = []
var _t := 0.0

func _ready() -> void:
	chapter_id = "lymph"
	room_size = Vector2(1400, 2400)
	var bgp := "res://assets/env/lymph_bg.png"
	floor_texture = load(bgp) if ResourceLoader.exists(bgp) else preload("res://assets/env/cytoplasm_bg.png")
	floor_stretch = true
	wall_texture = preload("res://assets/env/wall_bio.png")
	default_spawn = Vector2(700, 2250)
	super._ready()

func build_content() -> void:
	# The prince is aboard the dendritic cell for this whole chapter: the
	# player avatar becomes the mounted DC (no separate walking prince).
	if player:
		player.call_deferred("mount", "res://assets/env/dc_rider.png", 170.0)   # deferred: the player's @onready sprite must exist
	add_label(Vector2(440, 2130), "You ride the Scout Cell. Steer it into the lymph vessel.", 24)

	# Station 1: ride the DC along the chemokine gradient (mini-game).
	var nav := Area2D.new()
	nav.set_script(NAV_STATION)
	nav.name = "DCRide"
	nav.position = Vector2(700, 1900)
	content_root.add_child(nav)

	# The lymph node capsule: a wall across the room with a gate that opens
	# once the DC has migrated through the lymphatic vessel.
	add_wall_rect(Rect2(0, 1440, 560, 44))
	add_wall_rect(Rect2(840, 1440, 560, 44))
	_gate_body = StaticBody2D.new()
	_gate_body.collision_layer = TALL_WALL_LAYERS
	_gate_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(300, 60)
	cs.shape = sh
	_gate_body.add_child(cs)
	_gate_body.position = Vector2(700, 1462)
	content_root.add_child(_gate_body)
	_gate_sprite = Sprite2D.new()
	var lp := "res://assets/env/lymph_node.png"
	if ResourceLoader.exists(lp):
		_gate_sprite.texture = load(lp)
		var s := _gate_sprite.texture.get_size()
		_gate_sprite.scale = Vector2.ONE * (300.0 / max(s.x, s.y))
	_gate_sprite.position = Vector2(700, 1440)
	content_root.add_child(_gate_sprite)
	_gate_label = add_label(Vector2(440, 1590), "Training Camp (lymph node): enter through the lymph vessel only.", 20)

	# Decorative naive T-cells drifting in the T-cell zone.
	var tp := "res://assets/env/tcell_naive.png"
	if ResourceLoader.exists(tp):
		var tex: Texture2D = load(tp)
		var s2 := tex.get_size()
		var f: float = 80.0 / max(s2.x, s2.y)
		for p in [Vector2(300, 1150), Vector2(1050, 1080), Vector2(420, 700), Vector2(1100, 760), Vector2(250, 420), Vector2(1150, 380), Vector2(900, 1250)]:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2.ONE * f
			spr.position = p
			spr.set_meta("home", p)
			spr.set_meta("ph", randf() * TAU)
			content_root.add_child(spr)
			_tcells.append(spr)

	# Station 2: the T-cell chamber (mini-game: TCR screening, synapse, clonal expansion).
	var tz := Area2D.new()
	tz.set_script(TC_STATION)
	tz.name = "TCellZone"
	tz.position = Vector2(700, 900)
	content_root.add_child(tz)
	add_label(Vector2(440, 1030), "Knights' Hall (T-cell zone)", 22)

	# Exit: the immune army leaves the node for the tumor (Chapter 6).
	var door := add_portal(Vector2(700, 120), "tumor", "To the Tumor", Vector2(700, 2250))
	door.required_flag = "tcell_activated"
	add_label(Vector2(440, 230), "Exit vessel: the army marches out", 20)

func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	for spr in _tcells:
		var home: Vector2 = spr.get_meta("home")
		var ph: float = spr.get_meta("ph")
		spr.position = home + Vector2(sin(_t * 0.7 + ph) * 22.0, cos(_t * 0.9 + ph) * 14.0)
	if _gate_body != null and GameState.unlocked("dc_migrated"):
		_gate_body.queue_free()
		_gate_body = null
		_gate_label.text = "The Training Camp opens: the Knights' Hall lies ahead."
		_gate_sprite.modulate = Color(1.0, 1.0, 1.0, 0.55)
