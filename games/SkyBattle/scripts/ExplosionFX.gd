extends Node2D

var _radius: float = 0.0
var _alpha: float  = 1.0

func play(max_radius: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_set_radius, 0.0, max_radius, 0.30)
	tw.tween_method(_set_alpha, 1.0, 0.0, 0.35)
	tw.chain().tween_callback(queue_free)

func _set_radius(v: float) -> void:
	_radius = v
	queue_redraw()

func _set_alpha(v: float) -> void:
	_alpha = v

func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.55, 0.08, _alpha * 0.75))
	draw_circle(Vector2.ZERO, _radius * 0.55, Color(1.0, 0.85, 0.30, _alpha * 0.65))
	draw_circle(Vector2.ZERO, _radius * 0.25, Color(1.0, 1.0, 0.90, _alpha * 0.55))
