extends LevelBase
## Chapter 3 — The Molecular Kingdom. Collect the seven mRNA components, then
## reach the vaccine synthesizer to assemble them (mini-game hook), and on to
## the microfluidic mixer. Once the naked mRNA is assembled, RNases prowl the
## kingdom: they shred unprotected RNA on contact, so the prince must leap
## over them to get the message to the mixer. The finished LNP shields it.

const RNASE_TEX := "res://assets/env/rnase.png"

var _rnase_warned := false

func _ready() -> void:
	chapter_id = "laboratory"
	room_size = Vector2(1600, 1400)
	floor_texture = preload("res://assets/env/floor_lab.png")
	wall_texture = preload("res://assets/env/wall_lab.png")
	default_spawn = Vector2(800, 1250)
	super._ready()

func build_content() -> void:
	add_label(Vector2(540, 1050), "Collect all 7 mRNA components, assemble them at the Synthesizer, then wrap the mRNA at the Mixer.", 24, 520)

	# Lab benches that break up the room (and give the RNases corners to lurk in).
	add_wall_rect(Rect2(450, 480, 300, 36), true)   # benches: leap at one to vault it
	add_wall_rect(Rect2(950, 780, 300, 36), true)

	# Seven components scattered around the kingdom.
	add_pickup("cap5",        Vector2(250, 300))
	add_pickup("utr5",        Vector2(600, 250))
	add_pickup("start_codon", Vector2(1000, 300))
	add_pickup("orf",         Vector2(1350, 400))
	add_pickup("stop_codon",  Vector2(1300, 900))
	add_pickup("utr3",        Vector2(350, 900))
	add_pickup("polya",       Vector2(800, 700))

	# The vaccine synthesizer — shows live state (X/7 → READY → ✓ Assembled) and
	# unlocks the door once operated with all seven components.
	var synth := preload("res://scripts/world/Synthesizer.gd").new()
	synth.position = Vector2(800, 250)
	content_root.add_child(synth)

	# The microfluidic mixer — encapsulates the assembled mRNA into an LNP (mini-game).
	var mixer := Area2D.new()
	mixer.set_script(preload("res://scripts/world/MixerStation.gd"))
	mixer.name = "MixerStation"
	mixer.position = Vector2(1150, 620)
	content_root.add_child(mixer)

	# RNases: dormant until the naked mRNA exists; harmless once it is inside an LNP.
	var rn := {
		"hazard_name": "RNase", "texture_path": RNASE_TEX, "sprite_max_dim": 130.0,
		"mode": "chase", "speed": 110.0, "chase_speed": 150.0, "chase_range": 300.0,
		"hit_radius": 36.0, "damage": 0.34, "active_flag": "mrna_assembled",
		"shield_flag": "lnp_made", "shield_text": "The lipid shell repels the RNase!",
		"bounds": Rect2(60, 60, 1480, 1280),
	}
	var a := rn.duplicate(); a["points"] = [Vector2(500, 420), Vector2(1100, 420), Vector2(1100, 560), Vector2(500, 560)]
	add_hazard(Vector2(500, 420), a)
	var b := rn.duplicate(); b["points"] = [Vector2(1350, 700), Vector2(950, 720), Vector2(950, 1000), Vector2(1350, 1000)]
	add_hazard(Vector2(1350, 700), b)
	var c := rn.duplicate(); c["points"] = [Vector2(250, 650), Vector2(650, 650), Vector2(650, 1100), Vector2(250, 1100)]
	add_hazard(Vector2(250, 650), c)

	# Portal to the biological world: inject the LNP.
	var door := add_portal(Vector2(1450, 200), "bioworld", "Inject the LNP", Vector2(700, 1350))
	door.required_flag = "lnp_made"

func _process(delta: float) -> void:
	super._process(delta)
	var assembled := GameState.has_flag("mrna_assembled")
	var shielded := GameState.has_flag("lnp_made")
	if assembled and not shielded:
		if not meter_on:
			set_meter("mRNA integrity", 1.0)
			respawn_point = Vector2(800, 360)
		if not _rnase_warned and not DialogueManager.is_active() and not GameState.cutscene_active and not GameState.has_flag("rnase_warned"):
			_rnase_warned = true
			GameState.set_flag("rnase_warned")
			DialogueManager.start([
				["Scroll", "Beware! The naked mRNA is out, and RNases — enzymes that shred unprotected RNA — are prowling the kingdom."],
				["Scroll", "Three bites and the message is gone. Leap over them with SPACE or the JUMP button, and get the mRNA to the mixer!"],
				["Arin", "Then I'll be quick on my feet."],
			])
	elif meter_on:
		hide_meter()

func defeat_message(_source: String) -> String:
	return "The RNase shredded the mRNA!"

func defeat_lines(_source: String) -> Array:
	return [
		["Synthesizer", "The message was destroyed by RNase. Here is a fresh copy — this time, leap over them!"],
	]
