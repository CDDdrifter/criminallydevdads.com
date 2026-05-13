extends Node2D
class_name Terrain

var height_map: Array[int] = []
var tile_data: Dictionary  = {}
var tile_hp: Dictionary    = {}
var tile_shapes: Dictionary = {}

var _ground_body: StaticBody2D = null
var _noise: FastNoiseLite
var _detail_noise: FastNoiseLite

func generate(seed_val: int) -> void:
	_setup_noise(seed_val)
	_generate_height_map()
	_fill_terrain()
	_build_collision()
	queue_redraw()

func _setup_noise(seed_val: int) -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed_val
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.005
	_noise.fractal_octaves = 4

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = seed_val + 777
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.018
	_detail_noise.fractal_octaves = 2

func _generate_height_map() -> void:
	height_map.resize(Constants.MAP_WIDTH)
	for i in range(Constants.MAP_WIDTH):
		var n := (_noise.get_noise_1d(float(i)) + 1.0) * 0.5
		var d := (_detail_noise.get_noise_1d(float(i)) + 1.0) * 0.25
		var raw := int((n * 0.7 + d * 0.3) * float(Constants.GROUND_SURFACE_AMP))
		height_map[i] = clampi(Constants.GROUND_SURFACE_BASE + raw, 0, Constants.MAP_HEIGHT - 6)

func _fill_terrain() -> void:
	tile_data.clear()
	tile_hp.clear()
	for i in range(Constants.MAP_WIDTH):
		var tx: int = i + Constants.GROUND_TILE_X_OFFSET
		var surf: int = height_map[i]
		for ty in range(surf, Constants.MAP_HEIGHT):
			var key := Vector2i(tx, ty)
			var t: int
			if ty == surf:
				t = Constants.TILE_GRASS
			elif ty <= surf + 3:
				t = Constants.TILE_DIRT
			else:
				var v := _detail_noise.get_noise_2d(float(i), float(ty))
				t = Constants.TILE_STONE if v > 0.1 else Constants.TILE_DIRT
			tile_data[key] = t
			tile_hp[key] = Constants.TILE_HP[t]

func _build_collision() -> void:
	if _ground_body:
		_ground_body.queue_free()
	_ground_body = StaticBody2D.new()
	_ground_body.name = "GroundBody"
	_ground_body.collision_layer = Constants.LAYER_TERRAIN
	_ground_body.collision_mask = 0
	add_child(_ground_body)

	var half := float(Constants.TILE_SIZE) * 0.5
	for key in tile_data:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		shape.position = Vector2(
			float(key.x) * Constants.TILE_SIZE + half,
			float(key.y) * Constants.TILE_SIZE + half
		)
		shape.shape = rect
		_ground_body.add_child(shape)
		tile_shapes[key] = shape

# ── World-space queries ───────────────────────────────────────────────────────
func is_solid_at(world_x: float, world_y: float) -> bool:
	var tx := int(floor(world_x / float(Constants.TILE_SIZE)))
	var ty := int(floor(world_y / float(Constants.TILE_SIZE)))
	return tile_data.has(Vector2i(tx, ty))

func get_surface_y_at_world_x(world_x: float) -> float:
	var i := int(floor(world_x / float(Constants.TILE_SIZE))) - Constants.GROUND_TILE_X_OFFSET
	i = clampi(i, 0, Constants.MAP_WIDTH - 1)
	return float(height_map[i] * Constants.TILE_SIZE)

func damage_tile(tp: Vector2i, dmg: int) -> void:
	if not tile_hp.has(tp):
		return
	tile_hp[tp] -= dmg
	if tile_hp[tp] <= 0:
		_destroy_tile(tp)
		queue_redraw()

func apply_explosion(center_px: Vector2, radius_px: float) -> void:
	var ct := Vector2i(
		int(floor(center_px.x / float(Constants.TILE_SIZE))),
		int(floor(center_px.y / float(Constants.TILE_SIZE)))
	)
	var tr := int(radius_px / float(Constants.TILE_SIZE)) + 1
	for dx in range(-tr, tr + 1):
		for dy in range(-tr, tr + 1):
			var tp := ct + Vector2i(dx, dy)
			if not tile_data.has(tp):
				continue
			var dist := Vector2(float(dx), float(dy)).length() * float(Constants.TILE_SIZE)
			if dist <= radius_px:
				_destroy_tile(tp)
	queue_redraw()

func _destroy_tile(tp: Vector2i) -> void:
	tile_data.erase(tp)
	tile_hp.erase(tp)
	if tile_shapes.has(tp):
		var s: CollisionShape2D = tile_shapes[tp]
		if is_instance_valid(s):
			s.disabled = true
			s.queue_free()
		tile_shapes.erase(tp)

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	var sz := float(Constants.TILE_SIZE)
	for key in tile_data:
		var t: int = tile_data.get(key, 0)
		var col: Color = Constants.TILE_COLORS.get(t, Color.MAGENTA)
		var px := float(key.x) * sz
		var py := float(key.y) * sz
		draw_rect(Rect2(px, py, sz, sz), col)
		draw_rect(Rect2(px, py, sz, sz), col.darkened(0.3), false, 0.6)
