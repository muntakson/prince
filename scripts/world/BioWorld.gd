extends LevelBase
## Chapter 4 — Inside the Cell. The LNP is taken up by a dendritic cell, escapes
## the acidifying endosome, and ribosomes translate the mRNA into tumor antigen
## presented to the immune system. Placeholder stations mark each mini-game.

const DC_SCRIPT = preload("res://scripts/world/DendriticCell.gd")
const ENDO_SCRIPT = preload("res://scripts/world/EndosomeEscape.gd")
const RIBO_SCRIPT = preload("res://scripts/world/RibosomeTranslate.gd")
const MHC_SCRIPT = preload("res://scripts/world/AntigenPresentation.gd")

func _ready() -> void:
	chapter_id = "bioworld"
	room_size = Vector2(1400, 2400)
	floor_texture = preload("res://assets/env/cytoplasm_bg.png")
	floor_stretch = true
	wall_texture = preload("res://assets/env/wall_bio.png")
	default_spawn = Vector2(700, 2250)
	super._ready()

func build_content() -> void:
	add_label(Vector2(430, 2160), "Guide the message through the living cell.", 24)

	# Station 1: the lipid nanoparticle (the shielded mRNA) — already carried
	# if it was made in the Chapter 3 mixer.
	if not Inventory.has("lnp"):
		add_pickup("lnp", Vector2(700, 2000))

	# Station 2: the dendritic cell — animated LNP uptake (endocytosis) cutscene.
	var dc := Area2D.new()
	dc.set_script(DC_SCRIPT)
	dc.position = Vector2(700, 1600)
	content_root.add_child(dc)

	# Station 3: the endosome — animated endosomal-escape cutscene.
	var endo := Area2D.new()
	endo.set_script(ENDO_SCRIPT)
	endo.position = Vector2(700, 1150)
	content_root.add_child(endo)

	# Station 4: the ribosome — animated translation cutscene.
	var ribo := Area2D.new()
	ribo.set_script(RIBO_SCRIPT)
	ribo.position = Vector2(700, 700)
	content_root.add_child(ribo)

	# Station 5: antigen presentation — animated MHC / T-cell cutscene (sets antigen_presented).
	var mhc := Area2D.new()
	mhc.set_script(MHC_SCRIPT)
	mhc.position = Vector2(700, 400)
	content_root.add_child(mhc)

	# Exit to Chapter 5: the dendritic cell leaves for the lymph node.
	var door := add_portal(Vector2(700, 120), "lymph", "To the Lymph Node", Vector2(700, 2250))
	door.required_flag = "antigen_presented"
