extends Node2D
class_name IslandWorld

var tile_data: Dictionary = {}    # Vector2i -> tile_type int
var tile_hp: Dictionary   = {}    # Vector2i -> hp int
var tile_shapes: Dictionary = {}  # Vector2i -> CollisionShape2D

var _body: StaticBody2D
var _island_spawns: Array = []    # Array of float (x pixel centers)

# Building templates — row 0 = roof, last row = just above ground
# W=wood  B=stone  M=metal  F=wood_plank  .=clear
const T_SMALL_HOUSE: Array = [
	"WWWWWWWWWW",
	"W........W",
	"W........W",
	"WFFFFF...W",
	"W........W",
	"..........",
	"..........",
]
const T_WATCHTOWER: Array = [
	"BBBB",
	"B..B",
	"B..B",
	"BFFB",
	"B..B",
	"B..B",
	"....",
	"....",
]
const T_BUNKER: Array = [
	"MMMMMMMMMM",
	"M........M",
	"M......FFFM",
	"M........M",
	"..........",
	"..........",
]
const T_SKYSCRAPER: Array = [
	"BBBBBBBB",
	"B......B",
	"B......B",
	"BFFFFF..",
	"B......B",
	"B......B",
	"..FFFFFB",
	"B......B",
	"B......B",
	"BFFFFF..",
	"........",
	"........",
	"........",
]
const T_RUIN: Array = [
	"WWWWWWWWWW..........",
	"W........W..........",
	"W........W..........",
	"W.....FFFFW.........",
	"..........W.........",
	"...........W........",
	"....................",
	"....................",
]

const TEMPLATES: Array = [
	T_SMALL_HOUSE, T_WATCHTOWER, T_BUNKER,
	T_SKYSCRAPER, T_SKYSCRAPER,
	T_RUIN,
]

const CHAR_TILE: Dictionary = {
	"W": Constants.TILE_WOOD,
	"B": Constants.TILE_STONE,
	"M": Constants.TILE_METAL,
	"F": Constants.TILE_WOOD,
	"P": Constants.TILE_WOOD,
}

func _ready() -> void:
	_body = StaticBody2D.new()
	_body.name = "TerrainBody"
	_body.collision_layer = Constants.LAYER_TERRAIN
	_body.collision_mask = 0
	add_child(_body)

func generate(seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	tile_data.clear()
	tile_hp.clear()
	tile_shapes.clear()
	_island_spawns.clear()

	for ch in _body.get_children():
		ch.queue_free()

	_gen_islands(rng)
	_gen_mini_platforms(rng)
	_build_collision()
	queue_redraw()

# ── Island generation ─────────────────────────────────────────────────────────
func _gen_islands(rng: RandomNumberGenerator) -> void:
	var count: int = Constants.ISLAND_COUNT
	var span: float = Constants.WORLD_RIGHT - Constants.WORLD_LEFT

	for i in range(count):
		var cx: float = Constants.WORLD_LEFT + span / count * i + rng.randf_range(span / count * 0.1, span / count * 0.85)
		# Islands range from y=-3500 to y=-300 in pixel space
		var py: float = rng.randf_range(-3500.0, -300.0)
		var w: int = rng.randi_range(8, 28)
		var depth: int = rng.randi_range(3, 5)
		var base: int = Constants.TILE_STONE if rng.randf() > 0.3 else Constants.TILE_DIRT

		var ox: int = int(cx / Constants.TILE_SIZE) - w / 2
		var oy: int = int(py / Constants.TILE_SIZE)

		_place_platform(ox, oy, w, depth, base)
		_island_spawns.append(cx)

		# Structure on top
		if rng.randf() < 0.6 and w >= 8:
			var tmpl: Array = TEMPLATES[rng.randi() % TEMPLATES.size()]
			var tw: int = (tmpl[0] as String).length()
			if tw <= w - 2:
				var offset: int = rng.randi_range(1, maxi(1, w - tw - 1))
				_stamp_template(tmpl, ox + offset, oy)

# ── Mini floating platforms ───────────────────────────────────────────────────
func _gen_mini_platforms(rng: RandomNumberGenerator) -> void:
	var count: int = 30
	for _i in range(count):
		var px: float = rng.randf_range(Constants.WORLD_LEFT + 100, Constants.WORLD_RIGHT - 100)
		var py: float = rng.randf_range(-3200.0, -200.0)
		var w: int = rng.randi_range(2, 8)
		var ox: int = int(px / Constants.TILE_SIZE) - w / 2
		var oy: int = int(py / Constants.TILE_SIZE)
		_place_platform(ox, oy, w, 2, Constants.TILE_STONE)

# ── Tile placement ────────────────────────────────────────────────────────────
func _place_platform(ox: int, oy: int, width: int, depth: int, base: int) -> void:
	for x in range(width):
		for y in range(depth):
			var tp := Vector2i(ox + x, oy + y)
			var t: int = Constants.TILE_GRASS if y == 0 else base
			tile_data[tp] = t
			tile_hp[tp] = Constants.TILE_HP[t]

func _stamp_template(tmpl: Array, ox: int, island_top_y: int) -> void:
	var rows: int = tmpl.size()
	for row in range(rows):
		var line: String = str(tmpl[row])
		for col in range(line.length()):
			var ch: String = line[col]
			var tp := Vector2i(ox + col, island_top_y - rows + row)
			if ch == ".":
				tile_data.erase(tp)
				tile_hp.erase(tp)
			elif CHAR_TILE.has(ch):
				var t: int = CHAR_TILE[ch]
				tile_data[tp] = t
				tile_hp[tp] = Constants.TILE_HP[t]

# ── Collision ─────────────────────────────────────────────────────────────────
func _build_collision() -> void:
	tile_shapes.clear()
	var half := float(Constants.TILE_SIZE) * 0.5
	for tp in tile_data:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
		shape.shape = rect
		shape.position = Vector2(float(tp.x) * Constants.TILE_SIZE + half,
								 float(tp.y) * Constants.TILE_SIZE + half)
		_body.add_child(shape)
		tile_shapes[tp] = shape

# ── Destruction ───────────────────────────────────────────────────────────────
func apply_explosion(center_px: Vector2, radius_px: float) -> void:
	var ct := Vector2i(int(floor(center_px.x / Constants.TILE_SIZE)),
					   int(floor(center_px.y / Constants.TILE_SIZE)))
	var tr: int = int(radius_px / Constants.TILE_SIZE) + 1
	for dx in range(-tr, tr + 1):
		for dy in range(-tr, tr + 1):
			var tp := ct + Vector2i(dx, dy)
			if not tile_data.has(tp):
				continue
			var dist: float = Vector2(float(dx), float(dy)).length() * Constants.TILE_SIZE
			if dist <= radius_px:
				_destroy_tile(tp)
	queue_redraw()

func damage_tile(tp: Vector2i, dmg: int) -> void:
	if not tile_hp.has(tp):
		return
	tile_hp[tp] -= dmg
	if tile_hp[tp] <= 0:
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

# ── Queries ───────────────────────────────────────────────────────────────────
func is_solid_at(px: float, py: float) -> bool:
	var tp := Vector2i(int(floor(px / Constants.TILE_SIZE)),
					   int(floor(py / Constants.TILE_SIZE)))
	return tile_data.has(tp)

func get_spawn_positions(count: int) -> Array:
	var positions: Array = []
	var shuffled: Array = _island_spawns.duplicate()
	shuffled.shuffle()
	for i in range(mini(count, shuffled.size())):
		positions.append(Vector2(float(shuffled[i]), Constants.WORLD_TOP - 300.0))
	while positions.size() < count:
		var rx := randf_range(Constants.WORLD_LEFT + 300.0, Constants.WORLD_RIGHT - 300.0)
		positions.append(Vector2(rx, Constants.WORLD_TOP - 300.0))
	return positions

func spawn_loot(match_node: Node, loot_scene: PackedScene, rng: RandomNumberGenerator) -> void:
	# Spawn loot on top of each island surface tile in the topmost row
	var tops: Dictionary = {}  # x -> min_y (topmost tile per column)
	for tp in tile_data:
		var tx: int = tp.x
		if not tops.has(tx) or tp.y < tops[tx]:
			tops[tx] = tp.y
	var columns: Array = tops.keys()
	columns.shuffle()
	var spawn_count: int = mini(columns.size(), 60)
	for i in range(spawn_count):
		if rng.randf() > 0.25:
			continue
		var tx: int = columns[i]
		var ty: int = tops[tx]
		var loot = loot_scene.instantiate()
		loot.position = Vector2(float(tx * Constants.TILE_SIZE) + Constants.TILE_SIZE * 0.5,
								float(ty * Constants.TILE_SIZE) - 20.0)
		loot.randomize_loot(rng)
		match_node.add_child(loot)

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	# Stars
	var sr := RandomNumberGenerator.new()
	sr.seed = 77777
	for _i in range(250):
		var sx: float = sr.randf_range(Constants.WORLD_LEFT, Constants.WORLD_RIGHT)
		var sy: float = sr.randf_range(Constants.WORLD_TOP - 100.0, -100.0)
		var br: float = sr.randf_range(0.3, 0.9)
		draw_circle(Vector2(sx, sy), 1.5, Color(br, br, 1.0, br))

	# Tiles
	for tp in tile_data:
		var t: int = tile_data.get(tp, 0)
		var col: Color = Constants.TILE_COLORS.get(t, Color.MAGENTA)
		var px: float = float(tp.x) * Constants.TILE_SIZE
		var py: float = float(tp.y) * Constants.TILE_SIZE
		var sz: float = float(Constants.TILE_SIZE)
		draw_rect(Rect2(px, py, sz, sz), col)
		draw_rect(Rect2(px, py, sz, sz), col.darkened(0.35), false, 0.5)

	# Death void warning
	draw_rect(Rect2(Constants.WORLD_LEFT - 600.0, Constants.WORLD_BOTTOM,
					Constants.WORLD_RIGHT - Constants.WORLD_LEFT + 1200.0, 600.0),
			  Color(0.7, 0.05, 0.05, 0.40))
