extends Node2D

# Enemy-side slingshot visual — placed as a scene child after castles so it
# draws in front of castle blocks (same z_index, later tree order).

func _draw() -> void:
	var fork_l := Vector2(-28, -55)
	var fork_r := Vector2( 28, -55)
	var wood_dark := Color(0.28, 0.16, 0.06)
	var wood_mid  := Color(0.42, 0.26, 0.10)
	var wood_lite := Color(0.58, 0.38, 0.16)

	# Base stake
	draw_rect(Rect2(-6, 0, 12, 22), wood_dark)
	draw_rect(Rect2(-4, 0,  6, 22), wood_mid)

	# Shaft arms — 3-layer shading
	draw_line(Vector2.ZERO, fork_l, wood_dark, 10)
	draw_line(Vector2.ZERO, fork_l, wood_mid,   7)
	draw_line(Vector2(1, 0), fork_l + Vector2(2, 0), wood_lite, 3)

	draw_line(Vector2.ZERO, fork_r, wood_dark, 10)
	draw_line(Vector2.ZERO, fork_r, wood_mid,   7)
	draw_line(Vector2(-1, 0), fork_r + Vector2(-2, 0), wood_lite, 3)

	# Cross brace
	draw_line(Vector2(-14, -30), Vector2(14, -30), wood_dark, 6)
	draw_line(Vector2(-14, -30), Vector2(14, -30), wood_mid,  4)

	# Base knob
	draw_circle(Vector2.ZERO, 10, wood_dark)
	draw_circle(Vector2.ZERO,  7, wood_mid)
	draw_circle(Vector2(-2, -3), 3, wood_lite)

	# Metal-bound fork tips
	draw_circle(fork_l, 7, Color(0.28, 0.26, 0.22))
	draw_circle(fork_l, 5, Color(0.50, 0.46, 0.38))
	draw_circle(fork_l + Vector2(-1, -1), 2, Color(0.70, 0.65, 0.50))
	draw_circle(fork_r, 7, Color(0.28, 0.26, 0.22))
	draw_circle(fork_r, 5, Color(0.50, 0.46, 0.38))
	draw_circle(fork_r + Vector2(-1, -1), 2, Color(0.70, 0.65, 0.50))

	# Resting elastic bands
	var band_col := Color(0.30, 0.22, 0.14, 0.9)
	draw_line(fork_l, Vector2.ZERO, Color(0, 0, 0, 0.40), 6)
	draw_line(fork_l, Vector2.ZERO, band_col, 4)
	draw_line(fork_r, Vector2.ZERO, Color(0, 0, 0, 0.40), 6)
	draw_line(fork_r, Vector2.ZERO, band_col, 4)
