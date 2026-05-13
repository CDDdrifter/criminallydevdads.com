extends Control

# Virtual joystick + action buttons for touch input.
# Left stick  → move_left / move_right / jump actions
# Right stick → sets player aim_angle directly and fires when pushed far enough

var player_ref: Node = null

# Touch slot tracking
var _left_touch:  int     = -1
var _right_touch: int     = -1
var _left_origin: Vector2 = Vector2.ZERO
var _right_origin: Vector2 = Vector2.ZERO
var _left_pos:    Vector2 = Vector2.ZERO
var _right_pos:   Vector2 = Vector2.ZERO

const STICK_RADIUS: float = 60.0
const DEAD_ZONE:    float = 0.2
const AUTO_FIRE_THRESH: float = 0.7  # right stick push ratio to auto-fire

# Button touch slots
var _btn_touches: Dictionary = {}  # touch_id → action string

# Button layout (action → Rect2 in screen coords)
var _btn_rects: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_process_unhandled_input(true)

func setup(p: Node) -> void:
	player_ref = p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(ev: InputEventScreenTouch) -> void:
	var pos: Vector2 = ev.position
	if ev.pressed:
		# Check action buttons first
		for action in _btn_rects:
			if _btn_rects[action].has_point(pos):
				_btn_touches[ev.index] = action
				Input.action_press(action)
				return
		# Left half → left stick
		if pos.x < get_viewport().get_visible_rect().size.x * 0.5:
			if _left_touch == -1:
				_left_touch  = ev.index
				_left_origin = pos
				_left_pos    = pos
		else:
			if _right_touch == -1:
				_right_touch  = ev.index
				_right_origin = pos
				_right_pos    = pos
	else:
		# Release button
		if _btn_touches.has(ev.index):
			Input.action_release(_btn_touches[ev.index])
			_btn_touches.erase(ev.index)
			return
		if ev.index == _left_touch:
			_release_left()
		elif ev.index == _right_touch:
			_release_right()

func _on_drag(ev: InputEventScreenDrag) -> void:
	if ev.index == _left_touch:
		_left_pos = ev.position
		_apply_left_stick()
	elif ev.index == _right_touch:
		_right_pos = ev.position
		_apply_right_stick()

func _apply_left_stick() -> void:
	var delta: Vector2 = (_left_pos - _left_origin).limit_length(STICK_RADIUS)
	var ratio: Vector2 = delta / STICK_RADIUS

	if ratio.x < -DEAD_ZONE:
		Input.action_press("move_left")
		Input.action_release("move_right")
	elif ratio.x > DEAD_ZONE:
		Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	if ratio.y < -0.6:
		Input.action_press("jump")
	else:
		Input.action_release("jump")

func _apply_right_stick() -> void:
	var delta: Vector2 = (_right_pos - _right_origin).limit_length(STICK_RADIUS)
	var ratio: Vector2 = delta / STICK_RADIUS
	if ratio.length() > DEAD_ZONE and player_ref != null and is_instance_valid(player_ref):
		# Pass raw direction vector to player — aim hold + auto-aim handled there
		player_ref.set("_touch_aim_vec", ratio)
		if ratio.length() > AUTO_FIRE_THRESH:
			Input.action_press("shoot")
		else:
			Input.action_release("shoot")
	else:
		if player_ref != null and is_instance_valid(player_ref):
			player_ref.set("_touch_aim_vec", Vector2.ZERO)
		Input.action_release("shoot")

func _release_left() -> void:
	_left_touch = -1
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")

func _release_right() -> void:
	_right_touch = -1
	if player_ref != null and is_instance_valid(player_ref):
		player_ref.set("_touch_aim_vec", Vector2.ZERO)
	Input.action_release("shoot")

# ── Drawing ───────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not _is_touch_device():
		return
	_build_button_rects()
	queue_redraw()

func _is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available()

func _build_button_rects() -> void:
	if not _btn_rects.is_empty():
		return
	var vp := get_viewport().get_visible_rect().size
	var bw: float = 70.0
	var bh: float = 70.0
	var pad: float = 12.0
	# Top-right cluster
	var base_x: float = vp.x - bw - pad
	var base_y: float = pad
	_btn_rects = {
		"interact":      Rect2(base_x,            base_y,           bw, bh),
		"throw_grenade": Rect2(base_x - bw - pad, base_y,           bw, bh),
		"reload":        Rect2(base_x,            base_y + bh + pad, bw, bh),
	}

func _draw() -> void:
	if not _is_touch_device():
		return
	var vp := get_viewport().get_visible_rect().size

	# Left joystick
	var lo: Vector2 = _left_origin if _left_touch != -1 else Vector2(120.0, vp.y - 140.0)
	var lp: Vector2 = _left_pos if _left_touch != -1 else lo
	_draw_stick(lo, lp)

	# Right joystick
	var ro: Vector2 = _right_origin if _right_touch != -1 else Vector2(vp.x - 120.0, vp.y - 140.0)
	var rp: Vector2 = _right_pos if _right_touch != -1 else ro
	_draw_stick(ro, rp)

	# Action buttons
	_build_button_rects()
	var labels: Dictionary = {"interact": "E", "throw_grenade": "G", "reload": "R"}
	for action in _btn_rects:
		var r: Rect2 = _btn_rects[action]
		draw_rect(r, Color(0.1, 0.1, 0.1, 0.45), true)
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.35), false, 2.0)
		var lbl: String = labels.get(action, "?")
		draw_string(ThemeDB.fallback_font, r.get_center() + Vector2(-10.0, 8.0),
					lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 1.0, 1.0, 0.9))

func _draw_stick(origin: Vector2, current: Vector2) -> void:
	draw_circle(origin, STICK_RADIUS, Color(1.0, 1.0, 1.0, 0.12))
	draw_arc(origin, STICK_RADIUS, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.30), 2.0)
	var knob: Vector2 = (current - origin).limit_length(STICK_RADIUS) + origin
	draw_circle(knob, 28.0, Color(1.0, 1.0, 1.0, 0.25))
	draw_arc(knob, 28.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.55), 2.0)
