extends Area2D
## A doorway between chapters. Interact to travel (or walk into it).

var target_chapter: String = ""
var target_spawn: Vector2 = Vector2.INF
var label_text: String = ""
var auto: bool = false            # travel on touch instead of on interact
var required_flag: String = ""    # only usable if this GameState flag is set

var _label: Label
var _poly: Polygon2D
var _outline: Line2D
var _glow: float = 0.0
var _highlighted: bool = false

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 2
	monitorable = true
	monitoring = true
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90, 120)
	cs.shape = shape
	add_child(cs)
	# visual: a glowing arch (color reflects locked/unlocked in _process)
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([Vector2(-45,60), Vector2(-45,-20), Vector2(0,-60), Vector2(45,-20), Vector2(45,60)])
	_poly.color = Color(0.25, 0.5, 0.9, 0.35)
	add_child(_poly)
	_outline = Line2D.new()
	_outline.points = _poly.polygon
	_outline.closed = true
	_outline.width = 4.0
	_outline.default_color = Color(0.5, 0.8, 1.0, 0.8)
	add_child(_outline)
	_label = Label.new()
	_label.text = label_text if label_text != "" else "→"
	_label.position = Vector2(-60, -110)
	_label.size = Vector2(120, 30)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TextStyle.apply(_label, 24, Color(0.9, 0.95, 1.0), true)
	_label.modulate.a = 0.0
	add_child(_label)
	if auto:
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_glow += delta
	var locked := not GameState.unlocked(required_flag)
	var pulse := sin(_glow * 3.0) * 0.5 + 0.5
	if locked:
		_poly.color = Color(0.45, 0.35, 0.12, 0.30)
		_outline.default_color = Color(0.8, 0.6, 0.2, 0.7)
		_label.text = "" + (label_text if label_text != "" else "Locked")
	else:
		_poly.color = Color(0.2, 0.6, 0.35, 0.25 + pulse * 0.2)
		_outline.default_color = Color(0.4, 1.0, 0.6, 0.9)
		_label.text = label_text if label_text != "" else "→"
	# an unlocked door invites attention even when the player is not adjacent
	var base_a := 0.85 if (not locked) else 0.5
	_label.modulate.a = move_toward(_label.modulate.a, 1.0 if _highlighted else base_a, delta * 4.0)

func set_highlight(on: bool) -> void:
	_highlighted = on

func interact() -> void:
	_travel()

func _on_body_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_travel()

func _travel() -> void:
	if not GameState.unlocked(required_flag):
		var hint := "The gate is sealed. Collect all 7 components and operate the Synthesizer first." if required_flag == "mrna_assembled" else "The way is not open yet."
		AudioManager.sfx("deny")
		DialogueManager.start([{"speaker": "", "text": hint}])
		return
	if target_chapter != "":
		AudioManager.sfx("portal")
		SceneManager.goto_chapter(target_chapter, target_spawn)
