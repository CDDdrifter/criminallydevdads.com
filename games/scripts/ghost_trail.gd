extends Node2D

# Draws a ghostly arc of the most recently completed shot.
# Points are world-space Vector2 values recorded by game.gd.

var _points: Array = []

func set_trail(points: Array) -> void:
	_points = points.duplicate()
	queue_redraw()

func _draw() -> void:
	var count: int = _points.size()
	if count < 2:
		return

	# Dots grow larger and more opaque toward the impact point
	for i in range(0, count - 1, 2):
		var frac: float = float(i) / float(count - 1)
		var alpha: float = 0.08 + 0.50 * frac
		var sz: float = 1.6 + 2.8 * frac
		var pt: Vector2 = _points[i]
		# Soft outer glow
		draw_circle(pt, sz + 2.5, Color(0.55, 0.82, 1.0, alpha * 0.30))
		# Core ghost dot
		draw_circle(pt, sz, Color(0.90, 0.96, 1.0, alpha * 0.72))

	# Impact marker — distinct ring at landing point
	var last: Vector2 = _points[count - 1]
	draw_circle(last, 10.0, Color(0.55, 0.82, 1.0, 0.20))
	draw_circle(last, 6.5,  Color(0.85, 0.95, 1.0, 0.42))
	draw_circle(last, 3.5,  Color(1.00, 1.00, 1.00, 0.65))
	draw_arc(last, 13.0, 0.0, TAU, 32, Color(0.62, 0.88, 1.0, 0.35), 1.5)
