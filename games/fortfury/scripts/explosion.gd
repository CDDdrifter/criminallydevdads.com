extends Node2D

var _radius: float = 100.0
var _t: float = 0.0
var _duration: float = 0.55
var _color: Color = Color(1.0, 0.6, 0.1)
var _rings: int = 3

static func spawn(parent: Node, pos: Vector2, radius: float, col: Color = Color(1.0, 0.6, 0.1)) -> void:
	var e := preload("res://scripts/explosion.gd").new()
	e._radius = radius
	e._color = col
	e._rings = clamp(int(radius / 55), 1, 6)
	parent.add_child(e)
	e.global_position = pos

func _process(delta: float) -> void:
	_t += delta / _duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var ease_out := 1.0 - pow(1.0 - _t, 2.5)
	var inv := 1.0 - _t

	# Outer shockwave ring
	var sw_r := _radius * ease_out * 1.35
	var sw_a := inv * 0.55 * (1.0 - ease_out * 0.6)
	draw_arc(Vector2.ZERO, sw_r, 0.0, TAU, 48, Color(1.0, 0.85, 0.4, sw_a), 3.5 * inv)

	# Expanding fire rings
	for i in _rings:
		var r_frac := float(i + 1) / float(_rings)
		var r := _radius * ease_out * r_frac
		var heat := 1.0 - r_frac * 0.55
		var ring_col := Color(
			_color.r * heat + 1.0 * (1.0 - heat),
			_color.g * heat,
			_color.b * 0.2,
			inv * (1.0 - _t * 1.2) * (1.0 - r_frac * 0.4)
		)
		ring_col.a = max(0.0, ring_col.a)
		draw_circle(Vector2.ZERO, r, ring_col)

	# Bright white-yellow core flash
	var core_r: float = _radius * 0.32 * max(0.0, 1.0 - _t * 2.8)
	if core_r > 1.0:
		draw_circle(Vector2.ZERO, core_r * 1.4, Color(1.0, 0.95, 0.6, float(max(0.0, 1.0 - _t * 3.5)) * 0.4))
		draw_circle(Vector2.ZERO, core_r, Color(1.0, 1.0, 0.9, float(max(0.0, 1.0 - _t * 4.0))))

	# Debris sparks fanning outward
	var spark_count := _rings * 6 + 6
	for i in spark_count:
		var base_angle := (TAU / spark_count) * i
		# Offset angle slightly for variety (deterministic)
		var angle := base_angle + sin(float(i) * 1.618) * 0.4
		var spd_var := 0.6 + fmod(float(i) * 0.37, 0.7)
		var dist := _radius * ease_out * spd_var
		var spark_pos := Vector2(cos(angle), sin(angle)) * dist
		var spark_a: float = float(max(0.0, inv * 1.8 - _t * 1.2))
		var spark_r: float = float(max(0.5, 4.5 * inv * spd_var))
		var spark_col := Color(1.0, 0.75 - _t * 0.5, 0.1, spark_a)
		draw_circle(spark_pos, spark_r, spark_col)

	# Smoke wisps (late phase)
	if _t > 0.3:
		var smoke_t := (_t - 0.3) / 0.7
		var smoke_count := _rings * 3
		for i in smoke_count:
			var sa := (TAU / smoke_count) * i + float(i) * 0.8
			var sd := _radius * (0.5 + smoke_t * 0.8) * (0.4 + fmod(float(i) * 0.41, 0.6))
			var sp := Vector2(cos(sa), sin(sa)) * sd
			var smoke_a: float = float(max(0.0, smoke_t * 0.35 * (1.0 - smoke_t * 0.9)))
			var smoke_r := _radius * 0.18 * (1.0 + smoke_t)
			draw_circle(sp, smoke_r, Color(0.25, 0.20, 0.18, smoke_a))
