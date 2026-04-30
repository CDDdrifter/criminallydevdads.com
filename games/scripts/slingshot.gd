extends Node2D

# Player slingshot — drag to aim, release to fire.
# For the enemy side, this node is hidden; ai_brain.gd fires programmatically.

const MAX_PULL := 155.0
const POWER := 14.5
const FORK_HEIGHT := 55.0
const FORK_SPREAD := 28.0

var base_pos: Vector2 = Vector2.ZERO
var pull_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var active: bool = false
var current_bomb: Node = null
var preview_steps: int = 40

# For trajectory preview
var _preview_points: Array = []

signal bomb_launched(velocity: Vector2, position: Vector2)

func setup(pos: Vector2) -> void:
	base_pos = pos
	position = pos

func set_active(a: bool) -> void:
	active = a
	if not a:
		pull_offset = Vector2.ZERO
		_preview_points = []
	queue_redraw()

func place_bomb(bomb: Node) -> void:
	current_bomb = bomb
	if current_bomb:
		current_bomb.position = to_global(Vector2.ZERO)
		current_bomb.launched = false

func _input(event: InputEvent) -> void:
	if not active or current_bomb == null:
		return

	var local_pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		local_pos = to_local(get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and local_pos.length() < 80:
				is_dragging = true
			elif not event.pressed and is_dragging:
				is_dragging = false
				_fire()
	elif event is InputEventMouseMotion and is_dragging:
		local_pos = to_local(get_global_mouse_position())
		pull_offset = local_pos.limit_length(MAX_PULL)
		_calc_preview()
		queue_redraw()

	# Touch input
	if event is InputEventScreenTouch:
		local_pos = to_local(event.position)
		if event.pressed and local_pos.length() < 80:
			is_dragging = true
		elif not event.pressed and is_dragging:
			is_dragging = false
			_fire()
	elif event is InputEventScreenDrag and is_dragging:
		pull_offset = to_local(event.position).limit_length(MAX_PULL)
		_calc_preview()
		queue_redraw()

func _fire() -> void:
	if pull_offset.length() < 10:
		return
	var launch_vel := -pull_offset * POWER
	set_active(false)
	bomb_launched.emit(launch_vel, to_global(Vector2.ZERO))

func _calc_preview() -> void:
	_preview_points.clear()
	if pull_offset.length() < 5:
		return
	var vel := -pull_offset * POWER
	var pos := to_global(Vector2.ZERO)
	var gravity := Vector2(0, 980.0)
	var dt := 0.04
	for i in preview_steps:
		_preview_points.append(pos)
		vel += gravity * dt
		pos += vel * dt
		if pos.y > 1100:
			break

func _draw() -> void:
	var fork_l := Vector2(-FORK_SPREAD, -FORK_HEIGHT)
	var fork_r := Vector2(FORK_SPREAD, -FORK_HEIGHT)
	var wood_dark := Color(0.28, 0.16, 0.06)
	var wood_mid  := Color(0.42, 0.26, 0.10)
	var wood_lite := Color(0.58, 0.38, 0.16)

	# Base stake in ground
	draw_rect(Rect2(-6, 0, 12, 22), wood_dark)
	draw_rect(Rect2(-4, 0, 6, 22), wood_mid)

	# Main shaft — thick with highlight
	draw_line(Vector2.ZERO, fork_l, wood_dark, 10)
	draw_line(Vector2.ZERO, fork_l, wood_mid, 7)
	draw_line(Vector2(1, 0), fork_l + Vector2(2, 0), wood_lite, 3)

	draw_line(Vector2.ZERO, fork_r, wood_dark, 10)
	draw_line(Vector2.ZERO, fork_r, wood_mid, 7)
	draw_line(Vector2(-1, 0), fork_r + Vector2(-2, 0), wood_lite, 3)

	# Cross brace for structure
	draw_line(Vector2(-FORK_SPREAD * 0.5, -FORK_HEIGHT * 0.55),
			  Vector2(FORK_SPREAD * 0.5, -FORK_HEIGHT * 0.55), wood_dark, 6)
	draw_line(Vector2(-FORK_SPREAD * 0.5, -FORK_HEIGHT * 0.55),
			  Vector2(FORK_SPREAD * 0.5, -FORK_HEIGHT * 0.55), wood_mid, 4)

	# Base knob
	draw_circle(Vector2.ZERO, 10, wood_dark)
	draw_circle(Vector2.ZERO, 7, wood_mid)
	draw_circle(Vector2(-2, -3), 3, wood_lite)

	# Fork tips — metal-bound
	draw_circle(fork_l, 7, Color(0.28, 0.26, 0.22))
	draw_circle(fork_l, 5, Color(0.50, 0.46, 0.38))
	draw_circle(fork_l + Vector2(-1, -1), 2, Color(0.70, 0.65, 0.50))
	draw_circle(fork_r, 7, Color(0.28, 0.26, 0.22))
	draw_circle(fork_r, 5, Color(0.50, 0.46, 0.38))
	draw_circle(fork_r + Vector2(-1, -1), 2, Color(0.70, 0.65, 0.50))

	var bomb_pos := pull_offset if is_dragging else Vector2.ZERO

	# Elastic bands — two-tone for thickness
	var band_tense := pull_offset.length() / MAX_PULL
	var band_col := Color(0.18, 0.14, 0.10, 0.9).lerp(Color(0.55, 0.10, 0.05, 0.9), band_tense)
	draw_line(fork_l, bomb_pos, Color(0, 0, 0, 0.4), 6)
	draw_line(fork_l, bomb_pos, band_col, 4)
	draw_line(fork_r, bomb_pos, Color(0, 0, 0, 0.4), 6)
	draw_line(fork_r, bomb_pos, band_col, 4)

	# Leather pouch when dragging
	if is_dragging:
		draw_circle(bomb_pos, 11, Color(0.35, 0.22, 0.10))
		draw_circle(bomb_pos, 8, Color(0.48, 0.32, 0.15))

	# Trajectory dots — glowing arc
	if active and _preview_points.size() > 1:
		for i in range(0, _preview_points.size(), 2):
			var alpha := (1.0 - float(i) / _preview_points.size()) * 0.65
			var dot_sz := 3.5 * (1.0 - float(i) / _preview_points.size()) + 1.5
			draw_circle(to_local(_preview_points[i]), dot_sz + 1.5, Color(1, 1, 0.5, alpha * 0.35))
			draw_circle(to_local(_preview_points[i]), dot_sz, Color(1, 1, 0.8, alpha))

	# Pull strength arc
	if is_dragging:
		var pct := pull_offset.length() / MAX_PULL
		var ring_col: Color
		if pct < 0.45:
			ring_col = Color(0.25, 0.95, 0.35)
		elif pct < 0.78:
			ring_col = Color(0.95, 0.65, 0.10)
		else:
			ring_col = Color(0.95, 0.18, 0.12)
		draw_arc(Vector2.ZERO, MAX_PULL, 0, TAU, 64, Color(ring_col.r, ring_col.g, ring_col.b, 0.18), 2.5)
		draw_arc(Vector2.ZERO, MAX_PULL * pct, 0, TAU, 48, Color(ring_col.r, ring_col.g, ring_col.b, 0.45), 2.0)
