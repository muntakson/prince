extends CutsceneStation
## Chapter 4 — the dendritic cell. When the player brings the Lipid
## Nanoparticle it plays an uptake cutscene from Gemini-generated frames:
## the LNP flies from the prince to the cell, a dendrite touches it, the
## membrane wraps it (endocytosis), and it ends up in an endosome by the nucleus.

const LNP_TEXTURE := "res://assets/molecules/lnp.png"
const LNP_LOCAL := Vector2(139, -2)   # where the LNP sits in frame 1 (cell-local px)
const LNP_SCALE := 0.18
const FLY_TIME := 1.1
const DONE_FLAG := "lnp_uptake_done"

var _lnp: Sprite2D
var _fly_t := 0.0
var _fly_from := Vector2.ZERO

func _configure() -> void:
	station_name = "Dendritic Cell"
	frame_dir = "res://assets/env/dc_anim/"
	frame_prefix = "uptake_"
	frame_count = 7
	sprite_scale = 0.72
	done_flag = DONE_FLAG
	required_item = "lnp"
	captions = [
		"",
		"The nanoparticle drifts toward the cell...",
		"A dendrite reaches out and touches the LNP",
		"The membrane bends inward — endocytosis begins",
		"The membrane wraps around the particle",
		"It pinches off inside: an endosome forms",
		"The endosome carries the mRNA deep into the cell",
	]
	hint_lines = [
		["Cell", "I am a dendritic cell. I reach out with my branches and capture particles... but you carry nothing for me yet."],
		["Arin", "The Lipid Nanoparticle — I must bring it here first."],
	]
	finish_lines = [
		["Cell", "I am a dendritic cell — a sentinel of the immune system. I captured your nanoparticle and drew it inside an endosome."],
		["Scroll", "This is endocytosis: the membrane folds around the particle and pinches off as a vesicle. The mRNA is now inside the cell, but still trapped in the endosome."],
		["Arin", "Then the next step is to break free. Onward, to the endosome!"],
	]
	replay_lines = [
		["Cell", "The nanoparticle is already inside me, sealed in an endosome. Follow it north — the endosome is turning acidic."],
	]

func _setup_extra() -> void:
	_lnp = Sprite2D.new()
	if ResourceLoader.exists(LNP_TEXTURE):
		_lnp.texture = load(LNP_TEXTURE)
	_lnp.scale = Vector2(LNP_SCALE, LNP_SCALE)
	_lnp.visible = false
	_lnp.z_index = 2
	add_child(_lnp)

func _start_cutscene() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	_fly_from = pl.global_position + Vector2(0, -40) if pl else global_position + Vector2(0, 260)
	_lnp.global_position = _fly_from
	_lnp.visible = true
	_fly_t = 0.0
	_caption.text = captions[1]
	_caption.modulate.a = 0.0
	_state = State.INTRO

func _process_intro(delta: float, bob: float) -> void:
	_fly_t += delta
	var k: float = clampf(_fly_t / FLY_TIME, 0.0, 1.0)
	var e: float = 1.0 - pow(1.0 - k, 3)   # ease-out cubic
	var target := global_position + LNP_LOCAL + Vector2(0, bob)
	_lnp.global_position = _fly_from.lerp(target, e) + Vector2(0, -60.0 * sin(k * PI))
	_lnp.rotation = k * TAU
	_caption.modulate.a = move_toward(_caption.modulate.a, 1.0, delta * 3.0)
	if k >= 1.0:
		_lnp.visible = false
		_begin_frames(1)
