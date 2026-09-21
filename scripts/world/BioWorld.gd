extends LevelBase
## Chapter 4 — Inside the Cell. The LNP is taken up by a dendritic cell, escapes
## the acidifying endosome (pH-timing mini-game), and ribosomes translate the
## mRNA into tumor antigen presented to the immune system.
## Hazards: extracellular RNases (bounce off the LNP shield) on the way to the
## cell, and after the endosome escape a race against deadenylation: the
## poly(A) tail is chewed away in the cytoplasm while exonucleases patrol a
## winding path of organelles between the endosome and the ribosome.

const DC_SCRIPT = preload("res://scripts/world/DendriticCell.gd")
const ENDO_SCRIPT = preload("res://scripts/world/EndosomeEscape.gd")
const RIBO_SCRIPT = preload("res://scripts/world/RibosomeTranslate.gd")
const MHC_SCRIPT = preload("res://scripts/world/AntigenPresentation.gd")
const RNASE_TEX := "res://assets/env/rnase.png"
const NUCLEASE_TEX := "res://assets/env/nuclease.png"
const RUSH_SECONDS := 32.0

var _rush := false
var _rush_warned := false

func _ready() -> void:
	chapter_id = "bioworld"
	room_size = Vector2(1400, 2800)
	floor_texture = preload("res://assets/env/cytoplasm_bg.png")
	floor_stretch = true
	wall_texture = preload("res://assets/env/wall_bio.png")
	default_spawn = Vector2(700, 2650)
	super._ready()

func build_content() -> void:
	add_label(Vector2(400, 2555), "Guide the message through the living cell.", 26, 600)

	# Station 1: the lipid nanoparticle (the shielded mRNA) — already carried
	# if it was made in the Chapter 3 mixer.
	if not Inventory.has("lnp"):
		add_pickup("lnp", Vector2(700, 2420))

	# Extracellular RNases in the tissue: the LNP shield makes them harmless.
	var rn := {
		"hazard_name": "RNase", "texture_path": RNASE_TEX, "sprite_max_dim": 120.0,
		"mode": "chase", "speed": 100.0, "chase_speed": 140.0, "chase_range": 260.0,
		"hit_radius": 34.0, "damage": 0.34, "shield_item": "lnp",
		"shield_text": "The lipid shell repels the RNase!", "bounds": Rect2(60, 2150, 1280, 560),
	}
	var r1 := rn.duplicate(); r1["points"] = [Vector2(250, 2250), Vector2(1150, 2250), Vector2(1150, 2350), Vector2(250, 2350)]
	add_hazard(Vector2(250, 2250), r1)
	var r2 := rn.duplicate(); r2["points"] = [Vector2(1150, 2550), Vector2(300, 2550), Vector2(300, 2480), Vector2(1150, 2480)]
	add_hazard(Vector2(1150, 2550), r2)

	# Station 2: the dendritic cell — animated LNP uptake (endocytosis) cutscene.
	var dc := Area2D.new()
	dc.set_script(DC_SCRIPT)
	dc.name = "DendriticCell"
	dc.position = Vector2(700, 2000)
	content_root.add_child(dc)

	# Station 3: the endosome — pH-timing mini-game + escape cutscene.
	var endo := Area2D.new()
	endo.set_script(ENDO_SCRIPT)
	endo.name = "Endosome"
	endo.position = Vector2(700, 1550)
	content_root.add_child(endo)

	# The cytoplasm between endosome and ribosome: organelle walls form a
	# winding path, and exonucleases patrol it. The poly(A) tail is the timer.
	add_wall_rect(Rect2(0, 1330, 1000, 40))
	add_wall_rect(Rect2(400, 1180, 1000, 40))
	add_wall_rect(Rect2(0, 1030, 1000, 40))
	add_label(Vector2(50, 1400), "Cytoplasm — exonucleases hunt free mRNA here", 26, 290)
	var nu := {
		"hazard_name": "Exonuclease", "texture_path": NUCLEASE_TEX, "sprite_max_dim": 88.0,
		"mode": "patrol", "speed": 150.0, "hit_radius": 36.0, "damage": 0.2,
		"active_flag": "endosome_escape_done", "inactive_flag": "translation_done",
		"bounds": Rect2(60, 1000, 1280, 400),
	}
	var n1 := nu.duplicate(); n1["points"] = [Vector2(200, 1270), Vector2(1250, 1270)]
	add_hazard(Vector2(200, 1270), n1)
	var n2 := nu.duplicate(); n2["points"] = [Vector2(1250, 1120), Vector2(150, 1120)]; n2["speed"] = 160.0
	add_hazard(Vector2(1250, 1120), n2)
	var n3 := nu.duplicate(); n3["mode"] = "chase"; n3["chase_range"] = 240.0; n3["chase_speed"] = 120.0
	n3["points"] = [Vector2(1100, 1410), Vector2(1300, 1410)]; n3["bounds"] = Rect2(760, 1380, 600, 100)
	add_hazard(Vector2(1100, 1410), n3)

	# Station 4: the ribosome — animated translation cutscene.
	var ribo := Area2D.new()
	ribo.set_script(RIBO_SCRIPT)
	ribo.name = "Ribosome"
	ribo.position = Vector2(700, 830)
	content_root.add_child(ribo)

	# Station 5: antigen presentation — animated MHC / T-cell cutscene (sets antigen_presented).
	var mhc := Area2D.new()
	mhc.set_script(MHC_SCRIPT)
	mhc.name = "AntigenPresentation"
	mhc.position = Vector2(700, 440)
	content_root.add_child(mhc)

	# Exit to Chapter 5: the dendritic cell leaves for the lymph node.
	var door := add_portal(Vector2(700, 120), "lymph", "To the Lymph Node", Vector2(700, 2250))
	door.required_flag = "antigen_presented"

func _process(delta: float) -> void:
	super._process(delta)
	var escaped := GameState.has_flag("endosome_escape_done")
	var translated := GameState.has_flag("translation_done")
	if escaped and not translated:
		if not _rush:
			_rush = true
			set_meter("Poly(A) tail", 1.0)
			respawn_point = Vector2(700, 1720)
		if not _rush_warned and not DialogueManager.is_active() and not GameState.cutscene_active and _respawn_t < 0.0:
			_rush_warned = true
			if not GameState.has_flag("polya_warned"):
				GameState.set_flag("polya_warned")
				DialogueManager.start([
					["Scroll", "Hurry! In the cytoplasm, deadenylases nibble the poly(A) tail from the 3' end. When the tail is gone the mRNA loses its cap and is destroyed."],
					["Scroll", "Reach the ribosome before the tail runs out. Exonucleases patrol the path — leap over them!"],
				])
		# the tail only shrinks while the player is actually running the gauntlet
		if _rush_warned and not DialogueManager.is_active() and not GameState.cutscene_active and _respawn_t < 0.0:
			integrity = maxf(0.0, integrity - delta / RUSH_SECONDS)
			if integrity <= 0.0:
				defeat("The poly(A) tail is gone - the mRNA decayed!", [
					["Scroll", "Without its tail the mRNA was decapped and destroyed. Another copy escapes the endosome — run straight for the ribosome and leap over the exonucleases!"],
				])
	elif _rush:
		_rush = false
		hide_meter()

func on_respawn() -> void:
	integrity = 1.0

func defeat_message(_source: String) -> String:
	return "The exonuclease ate the whole tail!"

func defeat_lines(_source: String) -> Array:
	return [
		["Scroll", "The exonucleases chewed the mRNA to pieces. Another copy escapes the endosome — this time, leap over them!"],
	]
