extends Control
class_name VirtualJoystick
## A touch/mouse virtual joystick that feeds the move_* input actions.
## Appears where the user first touches within its rect (dynamic origin).

@export var radius: float = 90.0
@export var deadzone: float = 0.15

var _active: bool = false
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _value: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_active = true
			_touch_index = event.index
			_origin = event.position
			_knob = event.position
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag and _active and event.index == _touch_index:
		_knob = event.position
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _active:
				_active = true
				_touch_index = -2
				_origin = event.position
				_knob = event.position
				accept_event()
			elif not event.pressed and _touch_index == -2:
				_release()
				accept_event()
	elif event is InputEventMouseMotion and _active and _touch_index == -2:
		_knob = event.position
		accept_event()

func _process(_delta: float) -> void:
	if _active:
		var offset := _knob - _origin
		if offset.length() > radius:
			offset = offset.normalized() * radius
			_knob = _origin + offset
		_value = offset / radius
		if _value.length() < deadzone:
			_value = Vector2.ZERO
	else:
		_value = _value.move_toward(Vector2.ZERO, 8.0 * _delta)
	_apply_input()
	queue_redraw()

func _apply_input() -> void:
	_set_axis("move_left", "move_right", _value.x)
	_set_axis("move_up", "move_down", _value.y)

func _set_axis(neg: String, pos: String, v: float) -> void:
	if v < -0.01:
		Input.action_press(neg, -v)
		Input.action_release(pos)
	elif v > 0.01:
		Input.action_press(pos, v)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)

func _release() -> void:
	_active = false
	_touch_index = -1
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

func _draw() -> void:
	if not _active:
		# resting hint ring, bottom-left
		var c := Vector2(radius + 30, size.y - radius - 30)
		draw_circle(c, radius, Color(1, 1, 1, 0.06))
		draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.16), 3.0)
		draw_circle(c, radius * 0.45, Color(1, 1, 1, 0.10))
		return
	draw_circle(_origin, radius, Color(0.3, 0.6, 0.9, 0.15))
	draw_arc(_origin, radius, 0, TAU, 48, Color(0.5, 0.8, 1.0, 0.5), 4.0)
	draw_circle(_knob, radius * 0.42, Color(0.6, 0.85, 1.0, 0.7))
