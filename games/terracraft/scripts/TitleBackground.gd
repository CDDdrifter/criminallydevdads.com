## TitleBackground.gd
## Animated title-screen backdrop: spring/summer day, castle showcase,
## drifting clouds, falling leaves, slow camera pan.
## Add as a child of MainMenu (z_index = -1) to render behind the UI.
class_name TitleBackground
extends Node2D

const T := 16.0  # pixels per tile

# ── Colour palette ────────────────────────────────────────────────────────
const P := {
	"sky_top":  Color(0.18, 0.40, 0.88),
	"sky_mid":  Color(0.42, 0.68, 1.00),
	"sky_hor":  Color(0.68, 0.86, 1.00),
	"sun":      Color(1.00, 0.97, 0.78),
	"sun_h":    Color(1.00, 0.94, 0.55, 0.18),
	"cloud":    Color(0.98, 0.98, 1.00, 0.92),
	"wall":     Color(0.40, 0.39, 0.37),
	"wall_l":   Color(0.52, 0.51, 0.49),
	"wall_d":   Color(0.26, 0.25, 0.23),
	"mortar":   Color(0.22, 0.21, 0.20),
	"window":   Color(0.05, 0.05, 0.09),
	"win_lit":  Color(0.82, 0.72, 0.18, 0.55),
	"gate":     Color(0.04, 0.03, 0.03),
	"door_frm": Color(0.32, 0.20, 0.08),
	"torch":    Color(1.00, 0.70, 0.16),
	"torch_g":  Color(1.00, 0.58, 0.08, 0.30),
	"log":      Color(0.43, 0.32, 0.17),
	"leaves":   Color(0.16, 0.50, 0.07),
	"leaves2":  Color(0.22, 0.63, 0.10),
	"grass":    Color(0.30, 0.68, 0.10),
	"grass_d":  Color(0.20, 0.50, 0.06),
	"dirt":     Color(0.55, 0.35, 0.17),
	"water":    Color(0.22, 0.38, 0.82, 0.78),
	"water_l":  Color(0.50, 0.68, 0.98, 0.55),
	"banner_r": Color(0.72, 0.08, 0.08),
	"banner_g": Color(0.08, 0.08, 0.08),
}

# ── Pan / cloud state ─────────────────────────────────────────────────────
var _pan:     float = 0.0
var _pandir:  float = 1.0
var _cloud_x: float = 0.0

const PAN_SPEED := 8.0    # pixels per second
const PAN_RANGE := 45.0   # max pan offset
const CLOUD_SPEED := 6.0  # pixels per second

# ── Leaf particles ────────────────────────────────────────────────────────
var _leaves: CPUParticles2D


func _ready() -> void:
	_setup_particles()


func _setup_particles() -> void:
	var vp := _vp()
	_leaves = CPUParticles2D.new()
	_leaves.emitting = true
	_leaves.amount = 55
	_leaves.lifetime = 7.0
	_leaves.speed_scale = 0.55
	_leaves.direction = Vector2(0.25, 1.0)
	_leaves.spread = 45.0
	_leaves.gravity = Vector2(10, 14)
	_leaves.initial_velocity_min = 18.0
	_leaves.initial_velocity_max = 45.0
	_leaves.angular_velocity_min = -90.0
	_leaves.angular_velocity_max = 90.0
	_leaves.scale_amount_min = 3.0
	_leaves.scale_amount_max = 7.0
	_leaves.color = Color(0.22, 0.62, 0.10, 0.80)
	_leaves.position = Vector2(vp.x * 0.5, -8.0)
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.emission_rect_extents = Vector2(vp.x * 0.55, 4.0)
	add_child(_leaves)


func _process(delta: float) -> void:
	_pan += PAN_SPEED * _pandir * delta
	if _pan > PAN_RANGE:
		_pan = PAN_RANGE
		_pandir = -1.0
	elif _pan < -PAN_RANGE:
		_pan = -PAN_RANGE
		_pandir = 1.0
	_cloud_x += CLOUD_SPEED * delta
	queue_redraw()


func _draw() -> void:
	var vp  := _vp()
	var gnd := vp.y * 0.64          # y of ground surface
	var cx  := vp.x * 0.5 + _pan   # castle horizontal centre (pans slowly)

	_draw_sky(vp, gnd)
	_draw_sun(vp)
	_draw_clouds(vp)
	_draw_bg_trees(cx, gnd)
	_draw_castle(cx, gnd)
	_draw_ground(vp, gnd)
	_draw_moat(cx, gnd)
	_draw_fg_trees(cx, gnd)


# ── Sky gradient ──────────────────────────────────────────────────────────

func _draw_sky(vp: Vector2, gnd: float) -> void:
	var bands := 20
	for i in bands:
		var t  := float(i) / float(bands - 1)
		# tri-stop gradient: deep blue → mid blue → light horizon
		var c  := P.sky_top.lerp(P.sky_mid, minf(t * 1.6, 1.0))
		c = c.lerp(P.sky_hor, maxf((t - 0.5) * 2.0, 0.0))
		var y  := t * gnd
		draw_rect(Rect2(0.0, y, vp.x, gnd / float(bands) + 1.5), c)


# ── Sun ───────────────────────────────────────────────────────────────────

func _draw_sun(vp: Vector2) -> void:
	var sx := vp.x * 0.82 + _pan * 0.12
	var sy := vp.y * 0.10
	for r: float in [58.0, 46.0, 34.0]:
		draw_circle(Vector2(sx, sy), r, P.sun_h)
	draw_circle(Vector2(sx, sy), 22.0, P.sun)


# ── Clouds ────────────────────────────────────────────────────────────────

func _draw_clouds(vp: Vector2) -> void:
	# [base_x_fraction, y_fraction, width, height, drift_multiplier]
	var defs: Array = [
		[0.08, 0.06, 110.0, 32.0, 1.00],
		[0.35, 0.03,  95.0, 26.0, 0.60],
		[0.58, 0.08, 130.0, 36.0, 0.42],
		[0.78, 0.05,  80.0, 22.0, 0.75],
		[0.90, 0.12,  70.0, 20.0, 0.30],
	]
	for d in defs:
		var bx: float = fmod(d[0] * vp.x + _cloud_x * d[4], vp.x + 180.0) - 90.0
		var by: float = d[1] * vp.y
		_cloud_puff(bx, by, d[2], d[3])


func _cloud_puff(x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(x,             y,            w,           h          ), P.cloud)
	draw_rect(Rect2(x + w * 0.12, y - h * 0.55, w * 0.55,   h * 0.65   ), P.cloud)
	draw_rect(Rect2(x + w * 0.40, y - h * 0.88, w * 0.38,   h * 0.58   ), P.cloud)


# ── Background trees (behind castle) ─────────────────────────────────────

func _draw_bg_trees(cx: float, gnd: float) -> void:
	for xoff: float in [-280.0, -220.0, -340.0, 200.0, 270.0, 370.0]:
		_tree(cx + xoff * 0.9, gnd, 5, 10, 0.65)


# ── Castle ────────────────────────────────────────────────────────────────
# All tile coordinates: col = horizontal (negative = left of centre),
# row = height above ground (0 = ground row).

func _draw_castle(cx: float, gnd: float) -> void:
	# ── Castle base platform ───────────────────────────────────────────────
	_solid(cx, gnd, -14.0, 0.0, 28.0, 1.0, P.wall_d)   # foundation

	# ── Left corner tower  (cols -14..-10, rows 1-14) ─────────────────────
	_solid(cx, gnd, -14.0, 1.0, 4.0, 13.0, P.wall)
	_solid(cx, gnd, -14.0, 1.0, 1.0, 13.0, P.wall_l)   # lit left edge
	_solid(cx, gnd, -10.0, 1.0, 1.0, 13.0, P.wall_d)   # shadow right edge
	# battlements
	for bx: float in [-14.0, -12.0]:
		_solid(cx, gnd, bx, 14.0, 1.0, 2.0, P.wall)
	# tower window
	_solid(cx, gnd, -13.0, 7.0, 2.0, 3.0, P.window)
	_solid(cx, gnd, -13.0, 8.0, 2.0, 1.0, P.win_lit)   # lit interior

	# ── Right corner tower (cols 10..14, rows 1-14) ───────────────────────
	_solid(cx, gnd, 10.0, 1.0, 4.0, 13.0, P.wall)
	_solid(cx, gnd, 10.0, 1.0, 1.0, 13.0, P.wall_l)
	_solid(cx, gnd, 13.0, 1.0, 1.0, 13.0, P.wall_d)
	for bx: float in [10.0, 12.0]:
		_solid(cx, gnd, bx, 14.0, 1.0, 2.0, P.wall)
	_solid(cx, gnd, 11.0, 7.0, 2.0, 3.0, P.window)
	_solid(cx, gnd, 11.0, 8.0, 2.0, 1.0, P.win_lit)

	# ── Left curtain wall (cols -10..-4, rows 1-9) ────────────────────────
	_solid(cx, gnd, -10.0, 1.0, 6.0, 8.0, P.wall)
	_solid(cx, gnd, -10.0, 1.0, 1.0, 8.0, P.wall_l)
	for bx: float in [-10.0, -8.0, -6.0]:
		_solid(cx, gnd, bx, 9.0, 1.0, 2.0, P.wall)

	# ── Right curtain wall (cols 4..10, rows 1-9) ─────────────────────────
	_solid(cx, gnd, 4.0, 1.0, 6.0, 8.0, P.wall)
	_solid(cx, gnd, 4.0, 1.0, 1.0, 8.0, P.wall_l)
	for bx: float in [4.0, 6.0, 8.0]:
		_solid(cx, gnd, bx, 9.0, 1.0, 2.0, P.wall)

	# ── Central keep (cols -4..4, rows 1-15, taller) ──────────────────────
	_solid(cx, gnd, -4.0, 1.0, 8.0, 14.0, P.wall)
	_solid(cx, gnd, -4.0, 1.0, 1.0, 14.0, P.wall_l)   # lit edge
	_solid(cx, gnd,  3.0, 1.0, 1.0, 14.0, P.wall_d)   # shadow edge
	# keep battlements
	for bx: float in [-4.0, -2.0, 0.0, 2.0]:
		_solid(cx, gnd, bx, 15.0, 1.0, 2.0, P.wall)
	# keep windows (two rows)
	_solid(cx, gnd, -3.0, 6.0, 2.0, 3.0, P.window)
	_solid(cx, gnd, -3.0, 7.0, 2.0, 1.0, P.win_lit)
	_solid(cx, gnd,  1.0, 6.0, 2.0, 3.0, P.window)
	_solid(cx, gnd,  1.0, 7.0, 2.0, 1.0, P.win_lit)
	_solid(cx, gnd, -1.0, 10.0, 2.0, 3.0, P.window)
	_solid(cx, gnd, -1.0, 11.0, 2.0, 1.0, P.win_lit)

	# ── Gate arch (keep base, cols -2..2, rows 1-5) ───────────────────────
	_solid(cx, gnd, -2.0, 1.0, 4.0, 5.0, P.gate)       # opening
	_solid(cx, gnd, -3.0, 1.0, 1.0, 6.0, P.door_frm)   # left pillar trim
	_solid(cx, gnd,  2.0, 1.0, 1.0, 6.0, P.door_frm)   # right pillar trim
	# arch keystone
	_solid(cx, gnd, -2.0, 5.0, 4.0, 1.0, P.door_frm)

	# ── Decorative banners on keep ─────────────────────────────────────────
	_solid(cx, gnd, -4.5, 13.0, 1.0, 5.0, P.banner_r)   # left banner pole
	_solid(cx, gnd,  3.5, 13.0, 1.0, 5.0, P.banner_r)   # right banner pole

	# ── Torches flanking the gate ──────────────────────────────────────────
	_torch(cx, gnd, -3.0, 7.0)
	_torch(cx, gnd,  3.0, 7.0)

	# ── Mortar lines on keep face (horizontal detail) ─────────────────────
	for row: float in [4.0, 8.0, 12.0]:
		_solid(cx, gnd, -4.0, row, 8.0, 0.12, P.mortar)


# ── Ground ────────────────────────────────────────────────────────────────

func _draw_ground(vp: Vector2, gnd: float) -> void:
	# Two grass rows then dirt below
	draw_rect(Rect2(0.0, gnd,          vp.x, T * 2.5), P.grass)
	draw_rect(Rect2(0.0, gnd + T * 2.5, vp.x, vp.y),   P.dirt)
	# Darker grass edge
	draw_rect(Rect2(0.0, gnd + T * 1.8, vp.x, T * 0.4), P.grass_d)


# ── Moat in front of castle ───────────────────────────────────────────────

func _draw_moat(cx: float, gnd: float) -> void:
	draw_rect(Rect2(cx - 14.0 * T, gnd, 28.0 * T, T * 1.0), P.water)
	draw_rect(Rect2(cx - 13.5 * T, gnd, 27.0 * T, T * 0.28), P.water_l)


# ── Foreground trees ──────────────────────────────────────────────────────

func _draw_fg_trees(cx: float, gnd: float) -> void:
	for xoff: float in [-460.0, -400.0, 360.0, 430.0]:
		_tree(cx + xoff, gnd, 7, 13, 1.0)


# ── Helpers ───────────────────────────────────────────────────────────────

## Draw a solid rectangle.  col/row in tile units, row 0 = ground surface.
## Positive row = above ground, positive col = right of centre (cx).
func _solid(cx: float, gnd: float, col: float, row: float,
			w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(cx + col * T, gnd - (row + h) * T, w * T, h * T), color)


## Draw a glowing torch at tile position (tx, ty).
func _torch(cx: float, gnd: float, tx: float, ty: float) -> void:
	var px := cx + tx * T
	var py := gnd - (ty + 0.5) * T
	draw_circle(Vector2(px, py), 16.0, P.torch_g)
	draw_circle(Vector2(px, py), 8.0,  Color(P.torch.r, P.torch.g, P.torch.b, 0.55))
	draw_circle(Vector2(px, py), 3.5,  P.torch)


## Draw a tree. trunk_h = trunk height in tiles, canopy_r = canopy size in tiles.
func _tree(x: float, gnd: float, trunk_h: int, canopy_r: int, scale: float) -> void:
	var tw := T * scale
	var th := T * scale
	draw_rect(Rect2(x - tw, gnd - trunk_h * th, tw * 2.0, trunk_h * th), P.log)
	var cy := gnd - trunk_h * th
	var cw := canopy_r * tw
	var ch := canopy_r * th
	# Three canopy tiers
	draw_rect(Rect2(x - cw * 0.5, cy - ch * 0.6, cw, ch * 0.65), P.leaves)
	draw_rect(Rect2(x - cw * 0.35, cy - ch * 1.0, cw * 0.7, ch * 0.5), P.leaves2)
	draw_rect(Rect2(x - cw * 0.20, cy - ch * 1.35, cw * 0.4, ch * 0.42), P.leaves2)


## Viewport size (safe fallback).
func _vp() -> Vector2:
	if get_viewport():
		return get_viewport().get_visible_rect().size
	return Vector2(1280.0, 720.0)
