extends LevelBase
## Chapter 3 — The Molecular Kingdom. Collect the seven mRNA components, then
## reach the vaccine synthesizer to assemble them (mini-game hook), and on to
## the microfluidic mixer.

func _ready() -> void:
	chapter_id = "laboratory"
	room_size = Vector2(1600, 1400)
	floor_texture = preload("res://assets/env/floor_lab.png")
	wall_texture = preload("res://assets/env/wall_lab.png")
	default_spawn = Vector2(800, 1250)
	super._ready()

func build_content() -> void:
	add_label(Vector2(540, 1050), "Collect all 7 mRNA components, assemble them at the Synthesizer, then wrap the mRNA at the Mixer.", 24, 520)

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

	# Portal to the biological world: inject the LNP.
	var door := add_portal(Vector2(1450, 200), "bioworld", "Inject the LNP", Vector2(700, 1350))
	door.required_flag = "lnp_made"
