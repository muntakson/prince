extends LevelBase
## Chapter 6 — The Tumor. The T-cell army follows the blood to the tumor,
## reads MHC class I on every cell, kills the tumor cells and spares the
## healthy ones; Mira is cured.

const TUMOR_STATION := preload("res://scripts/world/TumorStation.gd")
const HERD_STATION := preload("res://scripts/world/HerdStation.gd")

var _gate_body: StaticBody2D
var _gate_label: Label
var _tumor_sprites: Array = []
var _t := 0.0
var _cleared_applied := false

func _ready() -> void:
	chapter_id = "tumor"
	room_size = Vector2(1400, 2400)
	var bgp := "res://assets/env/tumor_bg.png"
	floor_texture = load(bgp) if ResourceLoader.exists(bgp) else preload("res://assets/env/cytoplasm_bg.png")
	floor_stretch = true
	wall_texture = preload("res://assets/env/wall_bio.png")
	default_spawn = Vector2(700, 2250)
	super._ready()

func build_content() -> void:
	add_label(Vector2(440, 2130), "The Knight army rides the blood to the tumor.", 24)

	# Station 0: leave the blood vessel and herd the T-cells through the stroma.
	var herd := Area2D.new()
	herd.set_script(HERD_STATION)
	herd.name = "HerdStation"
	herd.position = Vector2(700, 2000)
	content_root.add_child(herd)

	# Decorative tumor cells crowding the middle of the room.
	var tp := "res://assets/env/tumor_cell.png"
	if ResourceLoader.exists(tp):
		var tex: Texture2D = load(tp)
		var f: float = 110.0 / max(tex.get_size().x, tex.get_size().y)
		for p in [Vector2(300, 1750), Vector2(1100, 1800), Vector2(250, 1500), Vector2(1150, 1450), Vector2(450, 1300), Vector2(950, 1250), Vector2(700, 1400)]:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2.ONE * f
			spr.position = p
			spr.set_meta("home", p)
			spr.set_meta("ph", randf() * TAU)
			content_root.add_child(spr)
			_tumor_sprites.append(spr)

	# Station: the tumor hunt mini-game.
	var st := Area2D.new()
	st.set_script(TUMOR_STATION)
	st.name = "TumorStation"
	st.position = Vector2(700, 1650)
	content_root.add_child(st)

	# Wall of tumor tissue blocking Mira's chamber until the tumor is cleared.
	add_wall_rect(Rect2(0, 1040, 560, 44))
	add_wall_rect(Rect2(840, 1040, 560, 44))
	_gate_body = StaticBody2D.new()
	_gate_body.collision_layer = TALL_WALL_LAYERS
	_gate_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(300, 60)
	cs.shape = sh
	_gate_body.add_child(cs)
	_gate_body.position = Vector2(700, 1062)
	content_root.add_child(_gate_body)
	_gate_label = add_label(Vector2(440, 1120), "The tumor mass blocks the way to Mira.", 20)

	# Mira, cured.
	add_npc(Vector2(700, 600), "Princess Mira",
		[
			["Mira", "Arin! The fever is gone... I can stand again. The healers say the growth has vanished."],
			["Arin", "Your own body did it, Mira. We only taught it the enemy's face — with a message written in mRNA."],
			["Mira", "A message of life. Then let the whole kingdom learn to read it."],
			["Scroll", "Colour returns to the princess's face. The prince steps out of her body at last... and the two of them kiss."],
			["Scroll", "Some Knights stay behind as Veteran Knights: if the illness ever returns, they will remember its face. And so the secret of the scroll was shared. THE END."],
			["Scroll", "Open Science Words in the pause menu to see every word you earned on the journey."],
		],
		"res://assets/characters/mira_hd.png", "mira_cured", 150.0)
	add_label(Vector2(440, 720), "Mira's chamber", 22)

	var door := add_portal(Vector2(700, 120), "cave", "The End — Play Again", Vector2(700, 2050))
	door.required_flag = "story_complete"

func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	var cleared := GameState.unlocked("tumor_cleared")
	for spr in _tumor_sprites:
		var home: Vector2 = spr.get_meta("home")
		var ph: float = spr.get_meta("ph")
		spr.position = home + Vector2(sin(_t * 0.8 + ph) * 8.0, cos(_t * 1.0 + ph) * 6.0)
	if cleared and not _cleared_applied:
		_cleared_applied = true
		var dp := "res://assets/env/tumor_dead.png"
		if ResourceLoader.exists(dp):
			var dtex: Texture2D = load(dp)
			var f: float = 110.0 / max(dtex.get_size().x, dtex.get_size().y)
			for spr in _tumor_sprites:
				spr.texture = dtex
				spr.scale = Vector2.ONE * f
				spr.modulate = Color(1, 1, 1, 0.7)
		if _gate_body != null:
			_gate_body.queue_free()
			_gate_body = null
		_gate_label.text = "The tumor has crumbled away — Mira's chamber is open."
