extends Node2D
class_name ZoneSystem

signal zone_warning(seconds_left: float)
signal zone_shrunk(phase: int)

var current_left:  float
var current_right: float
var target_left:   float
var target_right:  float
var phase: int = 0

var _phase_timer: float  = 0.0
var _shrinking: bool     = false
var _shrink_timer: float = 0.0
var _warned: bool        = false

const MAX_PHASES: int = 6
const ZONE_COLOR := Color(0.12, 0.75, 0.12, 0.30)
const WALL_COLOR := Color(0.10, 0.95, 0.10, 0.85)
const WALL_WIDTH: float = 8.0

func setup(world_left: float, world_right: float) -> void:
	current_left  = world_left
	current_right = world_right
	target_left   = world_left
	target_right  = world_right
	_phase_timer  = Constants.ZONE_START_DELAY

func _process(delta: float) -> void:
	if _shrinking:
		_shrink_timer -= delta
		current_left  = lerpf(current_left,  target_left,  delta * 1.5)
		current_right = lerpf(current_right, target_right, delta * 1.5)
		if _shrink_timer <= 0.0:
			_shrinking    = false
			current_left  = target_left
			current_right = target_right
			zone_shrunk.emit(phase)
		queue_redraw()
	else:
		_phase_timer -= delta
		if not _warned and _phase_timer <= 10.0:
			_warned = true
			zone_warning.emit(_phase_timer)
		if _phase_timer <= 0.0:
			_start_shrink()

func _start_shrink() -> void:
	if phase >= MAX_PHASES:
		return
	phase += 1
	_shrinking    = true
	_shrink_timer = Constants.ZONE_SHRINK_DURATION
	_phase_timer  = Constants.ZONE_PHASE_DURATION
	_warned       = false

	var center := (current_left + current_right) * 0.5
	var half   := (current_right - current_left) * 0.5
	var shrink := 0.65 - float(phase) * 0.04
	var new_half := half * shrink
	var drift := randf_range(-new_half * 0.2, new_half * 0.2)
	var wl := Constants.WORLD_LEFT
	var wr := Constants.WORLD_RIGHT
	target_left  = clampf(center - new_half + drift, wl, (wl + wr) * 0.5 - 50.0)
	target_right = clampf(center + new_half + drift, (wl + wr) * 0.5 + 50.0, wr)

func get_zone_damage(px: float) -> float:
	if px >= current_left and px <= current_right:
		return 0.0
	var overshoot := absf(px - (current_left if px < current_left else current_right))
	var base := Constants.ZONE_DMG_PER_SEC * (1.0 + float(phase) * 1.0)
	return base * clampf(overshoot / 80.0, 0.5, 3.0)

func is_in_zone(px: float) -> bool:
	return px >= current_left and px <= current_right

func get_zone_center() -> float:
	return (current_left + current_right) * 0.5

func get_time_to_shrink() -> float:
	return _phase_timer

func _draw() -> void:
	var top: float    = Constants.WORLD_TOP - 600.0
	var bottom: float = Constants.WORLD_BOTTOM + 600.0
	var h: float      = bottom - top

	# Left danger zone
	var left_w: float = current_left - Constants.WORLD_LEFT
	if left_w > 0.0:
		draw_rect(Rect2(Constants.WORLD_LEFT - 600.0, top, left_w + 600.0, h), ZONE_COLOR)
	draw_line(Vector2(current_left, top), Vector2(current_left, bottom), WALL_COLOR, WALL_WIDTH)

	# Right danger zone
	var right_w: float = Constants.WORLD_RIGHT - current_right
	if right_w > 0.0:
		draw_rect(Rect2(current_right, top, right_w + 600.0, h), ZONE_COLOR)
	draw_line(Vector2(current_right, top), Vector2(current_right, bottom), WALL_COLOR, WALL_WIDTH)
