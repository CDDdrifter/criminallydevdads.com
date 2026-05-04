extends Node2D

var biome: String = "grassland"
var world_width: float = 1920.0

func setup(b: String, ww: float) -> void:
	biome = b
	world_width = ww
	queue_redraw()

func _draw() -> void:
	var vw := world_width
	var vh := 1080.0
	match biome:
		"grassland": _draw_grassland(vw, vh)
		"village":   _draw_village(vw, vh)
		"forest":    _draw_forest(vw, vh)
		"desert":    _draw_desert(vw, vh)
		"mountain":  _draw_mountain(vw, vh)
		"arctic":    _draw_arctic(vw, vh)
		"apocalypse":_draw_apocalypse(vw, vh)
		_:           _draw_grassland(vw, vh)

func _draw_grassland(vw: float, vh: float) -> void:
	var m := 800.0
	# Sky gradient — extended to cover camera zoom-out margins
	draw_rect(Rect2(-m, -m, vw + m*2, vh * 0.25 + m), Color(0.28, 0.52, 0.88))
	draw_rect(Rect2(-m, vh * 0.25, vw + m*2, vh * 0.20), Color(0.38, 0.65, 0.92))
	draw_rect(Rect2(-m, vh * 0.45, vw + m*2, vh * 0.20), Color(0.55, 0.78, 0.96))
	draw_rect(Rect2(-m, vh * 0.65, vw + m*2, vh * 0.35 + m), Color(0.26, 0.55, 0.18))

	# Sun with glow
	var sun := Vector2(vw * 0.82, vh * 0.10)
	draw_circle(sun, 90, Color(1.0, 0.97, 0.70, 0.18))
	draw_circle(sun, 68, Color(1.0, 0.96, 0.65, 0.35))
	draw_circle(sun, 52, Color(1.0, 0.97, 0.72))

	# Distant haze
	draw_rect(Rect2(-m, vh * 0.58, vw + m*2, 28), Color(0.80, 0.90, 1.0, 0.22))

	# Clouds
	_draw_cloud(Vector2(vw * 0.12, vh * 0.13), 100, Color(1, 1, 1, 0.92))
	_draw_cloud(Vector2(vw * 0.34, vh * 0.08), 78, Color(1, 1, 1, 0.88))
	_draw_cloud(Vector2(vw * 0.55, vh * 0.17), 90, Color(0.95, 0.97, 1.0, 0.82))
	_draw_cloud(Vector2(vw * 0.73, vh * 0.10), 65, Color(1, 1, 1, 0.78))

	# Distant tree silhouettes
	for i in 14:
		var tx := vw * 0.04 + i * (vw * 0.068)
		var th := 55.0 + fmod(float(i) * 37.3, 40.0)
		_draw_tree_silhouette(tx, vh * 0.65, th, Color(0.18, 0.42, 0.12, 0.55))

	# Rolling hill foreground
	var hill: PackedVector2Array = [Vector2(-m, vh * 0.68)]
	for i in 22:
		var x := vw * i / 21.0
		var y := vh * 0.68 + sin(x * 0.0028) * 55 + cos(x * 0.0065 + 0.8) * 28
		hill.append(Vector2(x, y))
	hill.append(Vector2(vw + m, vh + m))
	hill.append(Vector2(-m, vh + m))
	draw_colored_polygon(hill, Color(0.22, 0.50, 0.14))

	draw_rect(Rect2(-m, vh * 0.70, vw + m*2, 8), Color(0.30, 0.58, 0.20, 0.55))
	draw_rect(Rect2(-m, vh * 0.76, vw + m*2, 5), Color(0.18, 0.42, 0.12, 0.35))

func _draw_village(vw: float, vh: float) -> void:
	var m := 800.0
	draw_rect(Rect2(-m, -m, vw + m*2, vh * 0.30 + m), Color(0.45, 0.58, 0.78))
	draw_rect(Rect2(-m, vh * 0.30, vw + m*2, vh * 0.35), Color(0.60, 0.72, 0.88))
	_draw_cloud(Vector2(vw * 0.18, vh * 0.10), 95, Color(0.95, 0.95, 1.0, 0.80))
	_draw_cloud(Vector2(vw * 0.52, vh * 0.06), 115, Color(0.92, 0.92, 0.98, 0.72))
	_draw_cloud(Vector2(vw * 0.80, vh * 0.15), 80, Color(1, 1, 1, 0.68))

	var bx_offsets: Array[float] = [0.06, 0.16, 0.27, 0.38, 0.50, 0.61, 0.72, 0.84]
	for i in bx_offsets.size():
		var bx: float = vw * bx_offsets[i]
		var bh: float = 55.0 + fmod(float(i) * 43.7, 80.0)
		var bw: float = 42.0 + fmod(float(i) * 17.3, 26.0)
		var bc := Color(0.22, 0.19, 0.15, 0.75)
		draw_rect(Rect2(bx, vh * 0.65 - bh, bw, bh), bc)
		var roof: PackedVector2Array = [
			Vector2(bx - 6, vh * 0.65 - bh),
			Vector2(bx + bw * 0.5, vh * 0.65 - bh - 22),
			Vector2(bx + bw + 6, vh * 0.65 - bh)
		]
		draw_colored_polygon(roof, Color(0.50, 0.18, 0.12, 0.80))
		draw_rect(Rect2(bx + bw * 0.25, vh * 0.65 - bh * 0.55, bw * 0.25, bh * 0.22), Color(1.0, 0.90, 0.50, 0.55))

	draw_rect(Rect2(-m, vh * 0.65, vw + m*2, vh * 0.35 + m), Color(0.28, 0.52, 0.20))
	draw_rect(Rect2(-m, vh * 0.67, vw + m*2, 6), Color(0.35, 0.60, 0.24, 0.60))

func _draw_forest(vw: float, vh: float) -> void:
	var m := 800.0
	draw_rect(Rect2(-m, -m, vw + m*2, vh * 0.45 + m), Color(0.20, 0.42, 0.22))
	draw_rect(Rect2(-m, vh * 0.45, vw + m*2, vh * 0.20), Color(0.28, 0.55, 0.25))
	draw_rect(Rect2(-m, vh * 0.65, vw + m*2, vh * 0.35 + m), Color(0.14, 0.36, 0.10))

	for i in 20:
		var tx := vw * i / 19.0 + fmod(float(i) * 31.7, 35.0) - 17.0
		var th := 120.0 + fmod(float(i) * 53.2, 90.0)
		_draw_tree_silhouette(tx, vh * 0.65, th, Color(0.08, 0.30, 0.08, 0.85))

	for i in 9:
		var tx := vw * 0.05 + i * (vw * 0.11)
		var th := 160.0 + fmod(float(i) * 41.9, 60.0)
		_draw_tree_silhouette(tx, vh * 0.65, th, Color(0.06, 0.22, 0.06, 0.95))

func _draw_desert(vw: float, vh: float) -> void:
	var m := 800.0
	draw_rect(Rect2(-m, -m, vw + m*2, vh * 0.22 + m), Color(0.85, 0.42, 0.10))
	draw_rect(Rect2(-m, vh * 0.22, vw + m*2, vh * 0.22), Color(0.96, 0.62, 0.18))
	draw_rect(Rect2(-m, vh * 0.44, vw + m*2, vh * 0.21), Color(1.0, 0.82, 0.40))
	draw_rect(Rect2(-m, vh * 0.65, vw + m*2, vh * 0.35 + m), Color(0.88, 0.75, 0.45))

	var sun := Vector2(vw * 0.50, vh * 0.08)
	draw_circle(sun, 95, Color(1.0, 0.98, 0.55, 0.20))
	draw_circle(sun, 72, Color(1.0, 0.96, 0.50, 0.45))
	draw_circle(sun, 55, Color(1.0, 0.98, 0.70))

	draw_rect(Rect2(-m, vh * 0.60, vw + m*2, 20), Color(1.0, 0.90, 0.65, 0.30))

	var dune1: PackedVector2Array = [Vector2(-m, vh * 0.72)]
	for i in 28:
		var x := vw * i / 27.0
		var y := vh * 0.70 + sin(x * 0.0018) * 70 + sin(x * 0.0048 + 1.2) * 38
		dune1.append(Vector2(x, y))
	dune1.append(Vector2(vw + m, vh + m))
	dune1.append(Vector2(-m, vh + m))
	draw_colored_polygon(dune1, Color(0.80, 0.65, 0.32))

	var ridge: PackedVector2Array = [Vector2(-m, vh * 0.69)]
	for i in 28:
		var x := vw * i / 27.0
		var y := vh * 0.67 + sin(x * 0.0018) * 70 + sin(x * 0.0048 + 1.2) * 38
		ridge.append(Vector2(x, y))
	ridge.append(Vector2(vw + m, vh * 0.75))
	draw_colored_polygon(ridge, Color(0.92, 0.78, 0.48, 0.5))

func _draw_mountain(vw: float, vh: float) -> void:
	var m := 800.0
	draw_rect(Rect2(-m, -m, vw + m*2, vh * 0.30 + m), Color(0.22, 0.35, 0.58))
	draw_rect(Rect2(-m, vh * 0.30, vw + m*2, vh * 0.35), Color(0.38, 0.52, 0.72))
	draw_rect(Rect2(-m, vh * 0.65, vw + m*2, vh * 0.35 + m), Color(0.30, 0.35, 0.28))

	for i in 4:
		var mx := vw * 0.08 + i * (vw * 0.24)
		var mh := 240.0 + fmod(float(i) * 67.3, 120.0)
		var mw := 260.0 + fmod(float(i) * 43.1, 100.0)
		var pts: PackedVector2Array = [Vector2(mx - mw * 0.9, vh * 0.65), Vector2(mx, vh * 0.65 - mh * 0.6), Vector2(mx + mw * 0.9, vh * 0.65)]
		draw_colored_polygon(pts, Color(0.38, 0.44, 0.55, 0.65))

	for i in 5:
		var mx := vw * 0.05 + i * (vw * 0.22)
		var mh := 280.0 + fmod(float(i) * 71.9, 130.0)
		var mw := 220.0 + fmod(float(i) * 39.7, 90.0)
		var pts: PackedVector2Array = [Vector2(mx - mw, vh * 0.65), Vector2(mx, vh * 0.65 - mh), Vector2(mx + mw, vh * 0.65)]
		draw_colored_polygon(pts, Color(0.35, 0.38, 0.42))
		var snow: PackedVector2Array = [
			Vector2(mx - mw * 0.28, vh * 0.65 - mh * 0.58),
			Vector2(mx, vh * 0.65 - mh),
			Vector2(mx + mw * 0.28, vh * 0.65 - mh * 0.58)
		]
		draw_colored_polygon(snow, Color(0.93, 0.95, 1.0))
		var snow_shd: PackedVector2Array = [
			Vector2(mx, vh * 0.65 - mh),
			Vector2(mx + mw * 0.28, vh * 0.65 - mh * 0.58),
			Vector2(mx + mw * 0.08, vh * 0.65 - mh * 0.65)
		]
		draw_colored_polygon(snow_shd, Color(0.75, 0.82, 0.92))

func _draw_arctic(vw: float, vh: float) -> void:
	var m := 800.0
	draw_rect(Rect2(-m, -m, vw + m*2, vh * 0.50 + m), Color(0.60, 0.80, 0.96))
	draw_rect(Rect2(-m, vh * 0.50, vw + m*2, vh * 0.15), Color(0.72, 0.88, 1.0))
	draw_rect(Rect2(-m, vh * 0.65, vw + m*2, vh * 0.35 + m), Color(0.85, 0.93, 1.0))

	for i in 3:
		var ax := vw * (0.15 + i * 0.30)
		var acol: Color = [Color(0.30, 0.92, 0.58, 0.18), Color(0.50, 0.80, 1.0, 0.15), Color(0.70, 0.90, 0.50, 0.14)][i]
		for band in 4:
			var bw := 80.0 - band * 16.0
			draw_line(Vector2(ax - bw + band * 8, 0), Vector2(ax + 50 + band * 10, vh * 0.52), acol, bw)

	for i in 55:
		var sx := fmod(float(i) * 137.5 + 20, vw)
		var sy := fmod(float(i) * 97.3 + 15, vh * 0.62)
		var ss := 1.8 + fmod(float(i) * 0.37, 2.2)
		draw_circle(Vector2(sx, sy), ss, Color(1, 1, 1, 0.55 + fmod(float(i) * 0.13, 0.35)))

	var ice_col := Color(0.70, 0.88, 1.0, 0.85)
	draw_rect(Rect2(-m, vh * 0.62, vw + m*2, 22), ice_col)
	draw_rect(Rect2(-m, vh * 0.62, vw + m*2, 4), Color(1, 1, 1, 0.55))
	for i in 7:
		var cx := vw * 0.06 + i * (vw * 0.13)
		draw_line(Vector2(cx, vh * 0.62), Vector2(cx + 40, vh * 0.66), Color(0.55, 0.78, 0.95, 0.45), 1.5)
		draw_line(Vector2(cx + 20, vh * 0.62), Vector2(cx - 20, vh * 0.67), Color(0.55, 0.78, 0.95, 0.30), 1.0)

func _draw_apocalypse(vw: float, vh: float) -> void:
	var m := 800.0
	draw_rect(Rect2(-m, -m, vw + m*2, vh * 0.35 + m), Color(0.08, 0.05, 0.04))
	draw_rect(Rect2(-m, vh * 0.35, vw + m*2, vh * 0.30), Color(0.18, 0.10, 0.06))
	draw_rect(Rect2(-m, vh * 0.65, vw + m*2, vh * 0.35 + m), Color(0.18, 0.10, 0.06))

	var moon := Vector2(vw * 0.76, vh * 0.11)
	draw_circle(moon, 80, Color(0.65, 0.08, 0.04, 0.25))
	draw_circle(moon, 60, Color(0.75, 0.10, 0.05, 0.55))
	draw_circle(moon, 44, Color(0.82, 0.15, 0.06))

	for i in 6:
		var sx := vw * 0.06 + i * (vw * 0.175)
		var col_a := 0.28 + fmod(float(i) * 0.12, 0.18)
		draw_line(Vector2(sx, vh * 0.65), Vector2(sx - 25, 0), Color(0.12, 0.09, 0.07, col_a), 45)
		draw_line(Vector2(sx + 15, vh * 0.65), Vector2(sx + 5, 0), Color(0.15, 0.11, 0.08, col_a * 0.6), 28)

	for i in 10:
		var fx := vw * 0.04 + i * (vw * 0.10)
		draw_circle(Vector2(fx, vh * 0.655), 30, Color(0.90, 0.32, 0.04, 0.55))
		draw_circle(Vector2(fx, vh * 0.655), 18, Color(1.0, 0.60, 0.08, 0.45))

	for i in 40:
		var ex := fmod(float(i) * 213.7, vw)
		var ey := fmod(float(i) * 157.3, vh * 0.62)
		draw_circle(Vector2(ex, ey), 2.2, Color(0.95, 0.42, 0.04, 0.55 + fmod(float(i) * 0.19, 0.35)))

	draw_rect(Rect2(-m, vh * 0.64, vw + m*2, 8), Color(0.35, 0.10, 0.02, 0.65))

# ── Helpers ───────────────────────────────────────────────────────────────────

func _draw_cloud(pos: Vector2, r: float, col: Color) -> void:
	draw_circle(pos, r * 1.1, Color(col.r, col.g, col.b, col.a * 0.35))
	draw_circle(pos, r, col)
	draw_circle(pos + Vector2(r * 0.65, r * 0.05), r * 0.78, col)
	draw_circle(pos - Vector2(r * 0.60, r * 0.04), r * 0.68, col)
	draw_circle(pos + Vector2(r * 0.22, -r * 0.38), r * 0.62, col)
	draw_circle(pos - Vector2(r * 0.18, -r * 0.30), r * 0.55, Color(1, 1, 1, col.a * 0.45))

func _draw_tree_silhouette(x: float, ground_y: float, h: float, col: Color) -> void:
	var w := h * 0.48
	draw_rect(Rect2(x - 4, ground_y - h * 0.38, 8, h * 0.38), col)
	var canopy: PackedVector2Array = [
		Vector2(x, ground_y - h),
		Vector2(x - w, ground_y - h * 0.32),
		Vector2(x + w, ground_y - h * 0.32)
	]
	draw_colored_polygon(canopy, col)
	var canopy2: PackedVector2Array = [
		Vector2(x, ground_y - h * 0.80),
		Vector2(x - w * 0.75, ground_y - h * 0.22),
		Vector2(x + w * 0.75, ground_y - h * 0.22)
	]
	draw_colored_polygon(canopy2, col.lightened(0.06))
