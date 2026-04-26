## WorldGenerator.gd
## ─────────────────────────────────────────────────────────────────────────────
## Static utility class — no node needed, no instancing required.
## Call WorldGenerator.generate_chunk(chunk_x, seed) to get a full tile map
## for one chunk of the world.
##
## HOW IT WORKS (big picture):
##   1.  A "noise" function takes an (x, y) position and returns a smooth
##       random number between -1 and 1. Same seed → same numbers every time.
##   2.  We sample that noise at each tile's X coordinate to decide how tall
##       the terrain should be at that column (the "heightmap").
##   3.  We fill tiles below the surface with dirt, stone, and ores.
##   4.  A second noise pass carves out cave-shaped empty spaces underground.
##   5.  We look at the world X position to decide the biome (forest/snow/
##       desert/plains) and place surface decorations (trees, cactus, snow).
##   6.  Low-lying columns near the surface that sit below WATER_LEVEL get
##       filled with water tiles.
##   7.  The bottom three rows are always bedrock so players can never fall
##       through the world floor.
##
## ADDING A NEW BIOME:
##   • Add a new value to the _BiomeType enum below.
##   • Add its world-X range inside _get_biome().
##   • Add surface block logic inside _place_surface_and_decor().
##   • Optionally add unique tree/decoration shapes in _place_tree().
##
## ADDING A NEW ORE:
##   • Add an entry to the ORE_RULES constant below (copy the existing format).
##   • That's it — the ore-scatter loop reads from that array automatically.
## ─────────────────────────────────────────────────────────────────────────────

class_name WorldGenerator


# ─────────────────────────────────────────────
#  CONSTANTS
# ─────────────────────────────────────────────

## How far below SURFACE_HEIGHT a column can sit before we fill it with water.
## A value of 5 means any column whose top soil is 5+ tiles below the surface
## level is considered a "lake / ocean" and gets flooded up to WATER_LEVEL.
const WATER_DEPTH_THRESHOLD: int = 4

## The surface height in tile rows — must match GameData.SURFACE_HEIGHT.
## We duplicate it here because const values cannot reference autoload singletons
## at parse time. If you change GameData.SURFACE_HEIGHT, change this too.
const SURFACE_HEIGHT: int = 80

## The Y row (in tile space) up to which water fills low areas.
const WATER_LEVEL: int = SURFACE_HEIGHT + WATER_DEPTH_THRESHOLD

## How many tiles deep the dirt/grass layer extends before transitioning to stone.
## e.g. 6 means rows SURFACE_HEIGHT to SURFACE_HEIGHT+6 are dirt/grass.
const DIRT_DEPTH: int = 6

## Ore definitions.  Each Dictionary entry has:
##   id        — the item_id string that must match ItemDatabase.gd
##   min_depth — shallowest tile row (relative to SURFACE_HEIGHT) it can appear
##   max_depth — deepest tile row it can appear
##   rarity    — probability (0–1) of spawning at any eligible stone tile
##               Lower = rarer.  0.08 ≈ 1 in 12 stone tiles within depth range.
const ORE_RULES: Array[Dictionary] = [
	# Coal is the most common ore; found close to the surface.
	{ "id": "coal_ore",    "min_depth":   5, "max_depth":  20, "rarity": 0.528  },
	# Copper — shallow, fairly common (early game resource).
	{ "id": "copper_ore",  "min_depth":   10, "max_depth":  100, "rarity": 0.418  },
	# Iron appears a little deeper and is moderately common.
	{ "id": "iron_ore",    "min_depth":  10, "max_depth":  75, "rarity": 0.321  },
	# Silver — mid-depth, moderate rarity.
	{ "id": "silver_ore",  "min_depth":  20, "max_depth": 160, "rarity": 0.312  },
	# Gold is rare and found in the mid-underground.
	{ "id": "gold_ore",    "min_depth":  30, "max_depth": 220, "rarity": 0.21  },
	# Diamond is very rare and only found deep underground.
	{ "id": "diamond_ore", "min_depth": 40, "max_depth": 250, "rarity": 0.15  },
	# Ruby and Emerald are the deepest and rarest ores.
	{ "id": "ruby_ore",    "min_depth": 50, "max_depth": 255, "rarity": 0.18  },
	{ "id": "emerald_ore", "min_depth": 50, "max_depth": 240, "rarity": 0.18  },
]

## Biome type identifiers used internally.
enum _BiomeType {
	PLAINS,    # gentle rolling hills, sparse trees
	FOREST,    # denser trees (oak and birch), lush grass
	SNOW,      # pine trees, snow blocks on surface
	DESERT,    # sand surface, no grass, cactus instead of trees
	JUNGLE,    # very tall jungle trees, dense vines, emerald ore bias
	MUSHROOM,  # flat terrain, giant mushrooms, mycelium ground
}

## Width of the transition zone between biomes, in world-tile-X units.
## The noise is blended across this many tiles so biomes don't snap abruptly.
const BIOME_BLEND_WIDTH: int = 30

## Sky region: tiles above this row index are considered "sky" (above ground).
## Floating islands and castles are placed within rows SKY_TOP_ROW..SKY_BOTTOM_ROW.
const SKY_TOP_ROW: int = 5
## Minimum gap between the bottom of a sky structure and the terrain surface.
const SKY_MIN_CLEARANCE: int = 12
## No block may be placed above this row. Enforced during tile generation and in Player.gd.
const HEIGHT_LIMIT_ROW: int = 3


# ─────────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────────

## generate_chunk(chunk_x, seed) → Dictionary{ Vector2i → String }
##
## chunk_x : The chunk's index along the X axis (0 = leftmost chunk).
##            Multiply by CHUNK_WIDTH to get the world-tile X of the left edge.
## seed    : An integer that controls all randomness.  Same seed always
##            produces the same world.
##
## Returns a Dictionary keyed by Vector2i(local_x, tile_y) where local_x runs
## 0 … CHUNK_WIDTH-1 and tile_y runs 0 … CHUNK_HEIGHT-1.
## Each value is a String item_id such as "grass", "stone", "coal_ore", etc.
## Empty tiles (air) are simply absent from the dictionary.
static func generate_chunk(chunk_x: int, seed: int) -> Dictionary:

	# ── 1.  Set up noise generators ──────────────────────────────────────────
	#
	# PRIMARY NOISE — used to sculpt the terrain heightmap.
	# FastNoiseLite generates smooth, layered (fractal) noise.
	# Think of it as a fancy random number generator that produces smooth hills
	# and valleys instead of jagged spikes.
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed              = seed
	terrain_noise.noise_type        = FastNoiseLite.TYPE_PERLIN
	terrain_noise.fractal_type      = FastNoiseLite.FRACTAL_FBM
	# FBM (Fractional Brownian Motion) stacks multiple "octaves" of noise on top
	# of each other — coarse mountains + medium hills + fine bumps.
	terrain_noise.fractal_octaves   = 5
	terrain_noise.fractal_lacunarity = 2.0   # each octave doubles in frequency
	terrain_noise.fractal_gain      = 0.5    # each octave halves in amplitude
	terrain_noise.frequency         = 0.003  # how "zoomed in" the noise is
											 # Lower = broader mountains

	# CAVE NOISE — a second, independent noise pass used to decide which
	# underground tiles should be hollow (caves).  We use a higher frequency
	# so caves are narrow and winding rather than huge open chambers.
	var cave_noise := FastNoiseLite.new()
	cave_noise.seed      = seed + 1          # offset seed so it differs from terrain
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave_noise.frequency  = 0.045

	# ORE NOISE — determines where ore veins spawn.  Using a different seed
	# keeps ores from aligning with cave openings.
	var ore_noise := FastNoiseLite.new()
	ore_noise.seed       = seed + 2
	ore_noise.noise_type = FastNoiseLite.TYPE_VALUE
	ore_noise.frequency  = 0.05

	# ── 2.  Pre-compute the heightmap for this chunk's columns ───────────────
	#
	# For each tile column (local_x = 0…CHUNK_WIDTH-1) we sample terrain_noise
	# at the world X coordinate and convert the −1…1 noise value into a tile Y
	# row.  The result tells us "the surface is at row Y for this column".
	var world_x_offset: int = chunk_x * GameData.CHUNK_WIDTH  # left edge of chunk in world tiles

	# heightmap[local_x] = tile_y of the surface for that column
	var heightmap: Array[int] = []
	heightmap.resize(GameData.CHUNK_WIDTH)

	for local_x in range(GameData.CHUNK_WIDTH):
		var world_x: int = world_x_offset + local_x

		# get_noise_1d returns a float in [-1, 1].
		# We map that range to a vertical deviation (in tiles) around SURFACE_HEIGHT.
		var raw: float = terrain_noise.get_noise_1d(float(world_x))

		# "amplitude" controls how tall the mountains can be (in tiles).
		# Raising this value makes more dramatic terrain.
		var amplitude: float = 100.0

		# raw is −1…1, so raw * amplitude gives −40…+40 tile offset.
		# Adding SURFACE_HEIGHT anchors the average surface around row 80.
		var surface_y: int = SURFACE_HEIGHT + int(raw * amplitude)

		# Clamp so the surface never goes above row 5 (would be off-screen)
		# or below CHUNK_HEIGHT - DIRT_DEPTH - 5 (too close to bedrock).
		surface_y = clampi(surface_y, 5, GameData.CHUNK_HEIGHT - DIRT_DEPTH - 5)

		heightmap[local_x] = surface_y

	# ── 3.  Fill every tile column from top to bottom ────────────────────────
	var tiles: Dictionary = {}   # our output: Vector2i → String

	for local_x in range(GameData.CHUNK_WIDTH):
		var world_x: int   = world_x_offset + local_x
		var surface_y: int = heightmap[local_x]

		# Decide the biome at this world X column.
		var biome: _BiomeType = _get_biome(world_x, seed)

		for tile_y in range(surface_y, GameData.CHUNK_HEIGHT):
			# ── Bedrock layer (bottom 3 rows) ─────────────────────────────────
			# Bedrock is indestructible and prevents the player from falling out
			# of the world.  It is placed first and never overwritten.
			if tile_y >= GameData.CHUNK_HEIGHT - 3:
				tiles[Vector2i(local_x, tile_y)] = "bedrock"
				continue

			# ── Air above the surface ─────────────────────────────────────────
			# Everything above the heightmap is empty (air = absent from dict).
			if tile_y < surface_y:
				continue  # no tile placed — tile is air

			# ── Depth-based layer selection ───────────────────────────────────
			# depth = how many tiles below the surface this tile is.
			# depth 0 = surface, depth 1 = one below surface, etc.
			var depth: int = tile_y - surface_y

			var tile_id: String = ""

			if depth == 0:
				# ── Surface tile — depends on biome ───────────────────────────
				match biome:
					_BiomeType.DESERT:
						tile_id = "sand"
					_BiomeType.SNOW:
						tile_id = "snow"
					_BiomeType.MUSHROOM:
						tile_id = "mycelium"  # purple/grey spore-covered ground
					_BiomeType.FOREST, _BiomeType.PLAINS, _BiomeType.JUNGLE:
						tile_id = "grass"
					_:
						tile_id = "grass"

			elif depth <= DIRT_DEPTH:
				# ── Shallow sub-surface — dirt layer ──────────────────────────
				match biome:
					_BiomeType.DESERT:
						tile_id = "sand" if depth <= 3 else "dirt"
					_BiomeType.SNOW:
						tile_id = "dirt"
					_:
						tile_id = "dirt"

			else:
				# ── Deep underground — stone by default ───────────────────────
				# We will attempt to replace some stone tiles with ores below.
				tile_id = "stone"

			# ── Cave carving ──────────────────────────────────────────────────
			# We carve caves only in the underground (depth > DIRT_DEPTH + 2).
			# The cave_noise value at (world_x, tile_y) tells us if this location
			# is inside a cave.  Values above CAVE_THRESHOLD are hollow.
			if depth > DIRT_DEPTH + 2:
				var cave_value: float = cave_noise.get_noise_2d(float(world_x), float(tile_y))
				# CAVE_THRESHOLD controls how wide / frequent caves are.
				# 0.25 → fairly common winding tunnels.  Raise to 0.35 for rarer caves.
				var cave_threshold: float = 0.13
				if cave_value > cave_threshold:
					# This tile is inside a cave — leave it as air.
					continue   # skip placing the tile (no key in dict = air)

			# ── Ore replacement ───────────────────────────────────────────────
			# Only stone tiles deep enough can become ores.
			# We check every ore rule and pick the first one that matches this
			# depth AND passes a noise-based probability test.
			if tile_id == "stone":
				tile_id = _pick_ore(depth, world_x, tile_y, ore_noise, tile_id)

			# Write the final tile.
			if tile_id != "":
				tiles[Vector2i(local_x, tile_y)] = tile_id

	# ── 4.  Place water in low-lying columns ─────────────────────────────────
	# After filling, check each column.  If its surface is below WATER_LEVEL,
	# fill from the surface up to WATER_LEVEL with "water" tiles.
	_fill_water(tiles, heightmap)

	# ── 5.  Place surface decorations (trees, cactus, snow caps, etc.) ───────
	# We pass the RNG seeded per chunk so decorations are deterministic.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(chunk_x, seed))   # unique but reproducible seed per chunk

	_place_surface_decor(tiles, heightmap, world_x_offset, rng)

	# ── 6.  Villages — span 3 chunks: left homes | town center | right homes ──
	const VILLAGE_INTERVAL: int = 512
	var village_anchor_world: int = roundi(float(world_x_offset) / VILLAGE_INTERVAL) * VILLAGE_INTERVAL
	var village_center_chunk: int = village_anchor_world / GameData.CHUNK_WIDTH
	# Village occupies chunks: center-1, center, center+1
	var v_slot: int = chunk_x - (village_center_chunk - 1)
	# Skip village if its anchor is within 200 tiles of world spawn.
	if v_slot >= 0 and v_slot <= 2 and abs(village_anchor_world) > 200:
		var biome_at_anchor := _get_biome(village_anchor_world, seed)
		if biome_at_anchor == _BiomeType.PLAINS or biome_at_anchor == _BiomeType.FOREST:
			_place_village(tiles, heightmap, v_slot, rng)

	# ── 7.  Additional structures (towers, temples, ruins, towns) ─────────
	_place_structures(chunk_x, tiles, heightmap, seed)

	# ── 8.  Floating sky features (islands and sky castles) ────────────────
	_place_floating_features(chunk_x, tiles, heightmap, seed)

	return tiles


# ─────────────────────────────────────────────
#  PRIVATE HELPERS
# ─────────────────────────────────────────────

## _get_biome(world_x, seed) → _BiomeType
## Determines the biome at a given world X coordinate.
##
## Biome regions are arranged in a repeating pattern along the X axis.
## The transition between biomes is not a hard cut — we use world_x modulo
## arithmetic so the pattern repeats every BIOME_CYCLE tiles.
##
## HOW TO ADD A BIOME:
##   1. Add your biome to the _BiomeType enum above.
##   2. Add an elif branch here that returns it for a specific X range.
##   3. Adjust the BIOME_CYCLE size if needed so all biomes fit.
static func _get_biome(world_x: int, _seed: int) -> _BiomeType:
	# How many world tiles before the biome pattern repeats.
	# Expanded to 768 to fit two new biomes without shrinking existing ones.
	const BIOME_CYCLE: int = 768

	# Map world_x into a 0…BIOME_CYCLE-1 range.
	# We use posmod (positive modulo) so negative X coordinates (left of spawn)
	# still get valid biomes.
	var pos: int = posmod(world_x, BIOME_CYCLE)

	# Each biome occupies a slice of the cycle.
	if pos < 100:
		return _BiomeType.PLAINS       # 0   – 99   → plains
	elif pos < 200:
		return _BiomeType.FOREST       # 100 – 199  → forest
	elif pos < 280:
		return _BiomeType.SNOW         # 200 – 279  → snow
	elif pos < 400:
		return _BiomeType.DESERT       # 280 – 399  → desert
	elif pos < 540:
		return _BiomeType.JUNGLE       # 400 – 539  → jungle (new)
	elif pos < 660:
		return _BiomeType.MUSHROOM     # 540 – 659  → mushroom island (new)
	else:
		return _BiomeType.PLAINS       # 660 – 767  → plains wrap buffer


## _pick_ore(depth, world_x, tile_y, noise, default_id) → String
## Given a stone tile at [depth] tiles below the surface, check each ore rule
## and return the ore id if the conditions are met, otherwise return default_id.
static func _pick_ore(depth: int, world_x: int, tile_y: int,
		noise: FastNoiseLite, default_id: String) -> String:

	for rule: Dictionary in ORE_RULES:
		# Check depth range first (cheap).
		if depth < rule["min_depth"] or depth > rule["max_depth"]:
			continue

		# Use noise to decide if this specific tile spawns ore.
		# get_noise_2d returns −1…1; we remap to 0…1 for a cleaner probability.
		var n: float = (noise.get_noise_2d(float(world_x), float(tile_y)) + 1.0) * 0.5

		# If the noise value is below the rarity threshold, place the ore.
		# Lower rarity → smaller threshold → fewer ores spawned.
		if n < rule["rarity"]:
			return rule["id"]

	# No ore rule matched — keep the default tile (stone).
	return default_id


## _fill_water(tiles, heightmap) → void
## Fills columns whose surface tile is below WATER_LEVEL with water,
## creating lakes and shallow ocean areas.
static func _fill_water(tiles: Dictionary, heightmap: Array[int]) -> void:
	for local_x in range(GameData.CHUNK_WIDTH):
		var surface_y: int = heightmap[local_x]

		# Only flood columns whose surface is at or below WATER_LEVEL.
		if surface_y > WATER_LEVEL:
			# Fill from just above the surface up to (but not including) WATER_LEVEL.
			# We fill from WATER_LEVEL - 1 down to surface_y (moving downward in Y).
			for fill_y in range(WATER_LEVEL, surface_y, 1):
				# Only place water where there is no solid tile already.
				var pos := Vector2i(local_x, fill_y)
				if not tiles.has(pos):
					tiles[pos] = "water"


## _place_surface_decor(tiles, heightmap, world_x_offset, rng) → void
## Iterates over every column in the chunk and decides whether to place
## decorations: trees (forest/plains), pine trees (snow), or cactus (desert).
## Decorations are only placed on dry surface tiles (not on water-covered cols).
static func _place_surface_decor(tiles: Dictionary, heightmap: Array[int],
		world_x_offset: int, rng: RandomNumberGenerator) -> void:

	for local_x in range(GameData.CHUNK_WIDTH):
		var world_x: int   = world_x_offset + local_x
		var surface_y: int = heightmap[local_x]
		var biome: _BiomeType = _get_biome(world_x, 0)  # seed not needed for biome lookup

		# Skip water columns — don't put trees in the lake.
		if surface_y > WATER_LEVEL:
			continue

		# The tile directly above the surface must be air for a decoration.
		# surface_y is the first solid row; surface_y - 1 is the tile above it.
		var above := Vector2i(local_x, surface_y - 1)
		if tiles.has(above):
			continue   # something already occupies the space above (shouldn't happen, but safe)

		# Surface must be the right block type for decoration.
		var surface_tile: String = tiles.get(Vector2i(local_x, surface_y), "")

		match biome:
			_BiomeType.FOREST:
				# Forest: oak and birch trees, ~25% chance per column.
				if rng.randf() < 0.25:
					var tree_type: String = "oak" if rng.randf() < 0.6 else "birch"
					_place_tree(tiles, local_x, surface_y, tree_type, rng)

			_BiomeType.PLAINS:
				# Plains: sparse trees, ~8% chance per column.
				if rng.randf() < 0.08:
					_place_tree(tiles, local_x, surface_y, "oak", rng)
				# Tall grass on remaining plains surface tiles (40% of grass tiles).
				elif surface_tile == "grass" and rng.randf() < 0.40:
					tiles[Vector2i(local_x, surface_y - 1)] = "tall_grass"

			_BiomeType.SNOW:
				# Snow: pine trees, ~20% chance, and snow-cap on surface.
				# First, replace the top soil with snowy grass if not already snow_block.
				if surface_tile == "grass":
					tiles[Vector2i(local_x, surface_y)] = "snow_grass"

				if rng.randf() < 0.20:
					_place_pine_tree(tiles, local_x, surface_y, rng)

			_BiomeType.DESERT:
				# Desert: cactus on sand, ~6% chance per column.
				if surface_tile == "sand" and rng.randf() < 0.06:
					_place_cactus(tiles, local_x, surface_y, rng)

			_BiomeType.JUNGLE:
				# Jungle: very dense tall trees (45%), occasional ground vines (15%).
				if rng.randf() < 0.45:
					_place_tree(tiles, local_x, surface_y, "jungle", rng)
				elif rng.randf() < 0.15:
					tiles[Vector2i(local_x, surface_y - 1)] = "vines"

			_BiomeType.MUSHROOM:
				# Mushroom island: giant mushrooms (15%), small mushrooms (25%).
				if rng.randf() < 0.15:
					_place_giant_mushroom(tiles, local_x, surface_y, rng)
				elif rng.randf() < 0.25:
					var m: String = "mushroom_red" if rng.randf() < 0.5 else "mushroom_brown"
					tiles[Vector2i(local_x, surface_y - 1)] = m


## _place_tree(tiles, local_x, surface_y, tree_type, rng) → void
## Plants a broadleaf tree (oak or birch) with a trunk of variable height
## (4–8 tiles) and a roughly round leaf cluster on top.
##
## Tree coordinate reference:
##   surface_y         = the ground tile row
##   surface_y - 1     = base of trunk (above ground)
##   surface_y - trunk_h = top of trunk
##   leaves wrap around the top of the trunk in a 3-wide, 3–4 tall cluster
static func _place_tree(tiles: Dictionary, local_x: int, surface_y: int,
		tree_type: String, rng: RandomNumberGenerator) -> void:

	# Choose which log/leaf tile IDs to use based on tree type.
	var log_id:  String = "log_oak"
	var leaf_id: String = "leaves_oak"
	if tree_type == "birch":
		log_id = "log_birch";  leaf_id = "leaves_birch"
	elif tree_type == "jungle":
		log_id = "log_jungle"; leaf_id = "leaves_jungle"

	# Jungle trees grow taller (7–14 tiles); others 4–8.
	var trunk_h: int = rng.randi_range(7, 14) if tree_type == "jungle" else rng.randi_range(4, 8)

	# Place the trunk going upward from just above the ground.
	for i in range(trunk_h):
		var ty: int = surface_y - 1 - i   # tile row for this trunk segment
		if ty < 0:
			break  # don't go off the top of the chunk
		tiles[Vector2i(local_x, ty)] = log_id

	# Top of trunk tile row.
	var trunk_top_y: int = surface_y - trunk_h

	# ── Leaf cluster ──────────────────────────────────────────────────────────
	# We place leaves in a roughly oval pattern around the trunk top.
	# The cluster is 3 columns wide and 3–4 rows tall.
	# Corners are left empty so it looks natural.
	#
	# Pattern (T = trunk, L = leaf, _ = air):
	#   Row -3:   _ L _
	#   Row -2:   L L L
	#   Row -1:   L T L
	#   Row  0:   _ L _   ← trunk_top_y  (the "bottom" of the canopy)
	var leaf_offsets: Array[Vector2i] = [
		Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2),          # bottom wide row
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),          # mid row
		Vector2i(-1,  0), Vector2i(0,  0), Vector2i(1,  0),          # top-mid row
						  Vector2i(0,  1),                            # tip
	]
	# The leaf rows sit above trunk_top_y, so we offset by trunk_top_y.
	for offset: Vector2i in leaf_offsets:
		var lx: int = local_x  + offset.x
		var ly: int = trunk_top_y + offset.y

		# Stay within chunk horizontal bounds and don't overwrite existing tiles.
		if lx < 0 or lx >= GameData.CHUNK_WIDTH:
			continue
		if ly < 0:
			continue
		var lpos := Vector2i(lx, ly)
		if not tiles.has(lpos):
			tiles[lpos] = leaf_id


## _place_pine_tree(tiles, local_x, surface_y, rng) → void
## Plants a triangular pine/spruce tree typical of snow biomes.
## The silhouette narrows toward the top (wider base, single tip).
static func _place_pine_tree(tiles: Dictionary, local_x: int, surface_y: int,
		rng: RandomNumberGenerator) -> void:

	var log_id:  String = "log_pine"
	var leaf_id: String = "leaves_pine"

	# Pine trunks are a bit taller on average: 5–9 tiles.
	var trunk_h: int = rng.randi_range(5, 9)

	# Place trunk.
	for i in range(trunk_h):
		var ty: int = surface_y - 1 - i
		if ty < 0:
			break
		tiles[Vector2i(local_x, ty)] = log_id

	var trunk_top_y: int = surface_y - trunk_h

	# ── Triangular canopy ─────────────────────────────────────────────────────
	# Layer 0 (bottom): 5 wide  (offsets -2 to +2)
	# Layer 1         : 3 wide  (offsets -1 to +1)
	# Layer 2 (tip)   : 1 wide  (just center)
	var canopy_layers: Array[Array] = [
		[-2, -1, 0, 1, 2],   # wide bottom layer (sits at trunk_top_y)
		[-1,  0, 1     ],    # mid layer
		[    0         ],    # tip
	]

	for layer_idx in range(canopy_layers.size()):
		var row_y: int = trunk_top_y - layer_idx   # higher layers are lower Y values
		for x_off: int in canopy_layers[layer_idx]:
			var lx: int = local_x + x_off
			if lx < 0 or lx >= GameData.CHUNK_WIDTH:
				continue
			if row_y < 0:
				continue
			var lpos := Vector2i(lx, row_y)
			if not tiles.has(lpos):
				tiles[lpos] = leaf_id


## _place_cactus(tiles, local_x, surface_y, rng) → void
## Places a cactus 1–3 tiles tall on a sand surface tile.
## Cactus does not have leaves — it's just a column of "cactus" blocks.
static func _place_cactus(tiles: Dictionary, local_x: int, surface_y: int,
		rng: RandomNumberGenerator) -> void:

	var height: int = rng.randi_range(1, 3)

	for i in range(height):
		var ty: int = surface_y - 1 - i
		if ty < 0:
			break
		tiles[Vector2i(local_x, ty)] = "cactus"


## _place_village — generates a small settlement around local_anchor column.
##
## A village contains:
##   • 1–2 simple plank houses (walls + roof, open interior, chest + crafting table inside)
##   • Torches outside each house entrance
##   • A small fenced path between buildings (optional tall_grass decorations)
##
## All coordinates are in LOCAL tile space (0…CHUNK_WIDTH-1 for X, tile_y for Y).
static func _place_village(tiles: Dictionary, heightmap: Array[int],
		slot: int, rng: RandomNumberGenerator) -> void:

	var cw: int = GameData.CHUNK_WIDTH

	# Helpers: set/erase a tile with bounds check
	var _s := func(x: int, y: int, id: String) -> void:
		if x >= 0 and x < cw and y >= 0 and y < GameData.CHUNK_HEIGHT:
			tiles[Vector2i(x, y)] = id
	var _e := func(x: int, y: int) -> void:
		if x >= 0 and x < cw: tiles.erase(Vector2i(x, y))

	# Flatten x0..x1 to the minimum height in that range; returns that height.
	var _flatten := func(x0: int, x1: int) -> int:
		var best_y: int = 999999
		for dx in range(x0, x1 + 1):
			var col: int = clampi(dx, 0, cw - 1)
			if heightmap[col] < best_y: best_y = heightmap[col]
		if best_y == 999999: return 90
		for dx in range(x0, x1 + 1):
			var col: int = clampi(dx, 0, cw - 1)
			if heightmap[col] > best_y:
				for fy in range(best_y + 1, heightmap[col] + 1):
					tiles[Vector2i(col, fy)] = "dirt"
				tiles[Vector2i(col, best_y)] = "grass"
				heightmap[col] = best_y
		return best_y

	# Build a detailed 2-story home at hx (9 tiles wide, 11 tiles tall).
	# variant 0 = oak/spruce,  variant 1 = brick/dark_oak
	var _home := func(hx: int, variant: int) -> void:
		var gy: int = _flatten.call(hx, hx + 8)
		var wall_lo: String  = "planks_oak"      if variant == 0 else "brick"
		var wall_hi: String  = "planks_spruce"   if variant == 0 else "planks_dark_oak"
		var roof_id: String  = "planks_dark_oak" if variant == 0 else "stone_brick"
		# Floor
		for dx in range(9): _s.call(hx + dx, gy - 1, wall_lo)
		# Ground floor walls (rows 2-5)
		for row in range(2, 6):
			var ty: int = gy - row
			if ty < 0: break
			for dx in range(9):
				if dx == 0 or dx == 8 or row == 5:
					_s.call(hx + dx, ty, wall_lo)
				else:
					_e.call(hx + dx, ty)
		# Ground floor windows
		for row in [3, 4]:
			for dx in [1, 2, 6, 7]: _s.call(hx + dx, gy - row, "window_glass")
		# Door gap (dx 3-4, rows 2-3)
		for row in [2, 3]:
			_e.call(hx + 3, gy - row)
			_e.call(hx + 4, gy - row)
		# Ground floor furniture
		_s.call(hx + 1, gy - 2, "crafting_table")
		_s.call(hx + 5, gy - 2, "furnace")
		_s.call(hx + 7, gy - 2, "chest")
		# Torches beside door
		_s.call(hx + 2, gy - 3, "torch_wall"); _s.call(hx + 5, gy - 3, "torch_wall")
		# Mid-floor planks (row 6)
		for dx in range(1, 8): _s.call(hx + dx, gy - 6, wall_lo)
		# Upper floor walls (rows 7-9)
		for row in range(7, 10):
			var ty: int = gy - row
			if ty < 0: break
			for dx in range(9):
				if dx == 0 or dx == 8 or row == 9:
					_s.call(hx + dx, ty, wall_hi)
				else:
					_e.call(hx + dx, ty)
		# Upper floor windows
		for row in [7, 8]:
			_s.call(hx + 2, gy - row, "window_glass"); _s.call(hx + 6, gy - row, "window_glass")
		# Upper floor furniture
		_s.call(hx + 2, gy - 7, "bed"); _s.call(hx + 5, gy - 7, "bed"); _s.call(hx + 7, gy - 7, "chest")
		# Roof (row 10)
		for dx in range(9): _s.call(hx + dx, gy - 10, roof_id)
		# Stone chimney (dx 7, rows 10-12)
		for r in [10, 11, 12]: _s.call(hx + 7, gy - r, "stone_brick")
		# Fence posts on sides
		_s.call(hx,     gy - 1, "fence_wood"); _s.call(hx + 8, gy - 1, "fence_wood")

	var _lamp := func(x: int, gy: int) -> void:
		_s.call(x, gy - 2, "fence_wood"); _s.call(x, gy - 3, "fence_wood"); _s.call(x, gy - 4, "torch")

	match slot:
		0:  # Left village chunk: home at x=1 and x=21
			var gy0: int = _flatten.call(0, cw - 1)
			_home.call(1,  0)
			_home.call(21, 1)
			# Cobblestone path between homes
			for dx in range(10, 21):
				if not tiles.has(Vector2i(dx, gy0 - 1)):
					_s.call(dx, gy0 - 1, "cobblestone")
			_lamp.call(11, gy0)
			_lamp.call(19, gy0)

		1:  # Center chunk: Inn + Well + Blacksmith + cobblestone road
			var gy1: int = _flatten.call(0, cw - 1)
			# Full-width cobblestone road at ground level
			for dx in range(cw): _s.call(dx, gy1 - 1, "cobblestone")

			# INN (x=0..16, 17 wide, 3 stories, 14 tall)
			var iw: int = 17; var ih: int = 14
			for dx in range(iw): _s.call(dx, gy1 - 2, "planks_dark_oak")
			for row in range(1, ih + 1):
				var ty: int = gy1 - 2 - row
				if ty < 0: break
				for dx in range(iw):
					if dx == 0 or dx == iw - 1 or row == ih:
						_s.call(dx, ty, "brick")
					elif row == 5 or row == 10:
						_s.call(dx, ty, "planks_dark_oak")
					else:
						_e.call(dx, ty)
			for fr in [2, 3, 7, 8, 12, 13]:
				var ty: int = gy1 - 2 - fr
				if ty < 0: continue
				for dx in [2, 3, 13, 14]: _s.call(dx, ty, "window_glass")
			# Clear door opening including floor level so player can enter
			_e.call(7, gy1 - 2); _e.call(8, gy1 - 2)
			for row in [1, 2, 3]:
				_e.call(7, gy1 - 2 - row)
				_e.call(8, gy1 - 2 - row)
			_s.call(6, gy1 - 4, "torch_wall"); _s.call(9, gy1 - 4, "torch_wall")
			_s.call(1, gy1 - 3, "barrel"); _s.call(3, gy1 - 3, "chest")
			_s.call(12, gy1 - 3, "bookshelf"); _s.call(15, gy1 - 3, "barrel")
			_s.call(2, gy1 - 8, "bed"); _s.call(4, gy1 - 8, "bed")
			_s.call(11, gy1 - 8, "bed"); _s.call(13, gy1 - 8, "bed"); _s.call(15, gy1 - 8, "chest")
			for r in range(ih, ih + 4): _s.call(15, gy1 - 2 - r, "stone_brick")

			# WELL (x=17..18)
			for dy in range(2, 7):
				var ty: int = gy1 - dy
				if ty < 0: break
				_s.call(17, ty, "cobblestone")
				_s.call(18, ty, "cobblestone" if dy != 3 else "water")
			_s.call(16, gy1 - 7, "planks_oak"); _s.call(19, gy1 - 7, "planks_oak")
			_s.call(17, gy1 - 7, "planks_oak"); _s.call(18, gy1 - 7, "planks_oak")
			_s.call(16, gy1 - 5, "fence_wood"); _s.call(19, gy1 - 5, "fence_wood")
			_s.call(17, gy1 - 8, "torch")

			# BLACKSMITH (x=19..31, 13 wide, 9 tall)
			var bx: int = 19; var bw: int = mini(cw - bx, 13); var bh: int = 9
			for dx in range(bw): _s.call(bx + dx, gy1 - 2, "cobblestone")
			for row in range(1, bh + 1):
				var ty: int = gy1 - 2 - row
				if ty < 0: break
				for dx in range(bw):
					if dx == 0 or dx == bw - 1 or row == bh:
						_s.call(bx + dx, ty, "stone_brick")
					else: _e.call(bx + dx, ty)
			# Clear door + floor at door position
			_e.call(bx + 4, gy1 - 2); _e.call(bx + 5, gy1 - 2)
			for row in [1, 2, 3]:
				_e.call(bx + 4, gy1 - 2 - row)
				_e.call(bx + 5, gy1 - 2 - row)
			for row in [4, 5]: _s.call(bx + 9, gy1 - 2 - row, "window_glass")
			_s.call(bx + 1, gy1 - 3, "anvil"); _s.call(bx + 2, gy1 - 3, "furnace")
			_s.call(bx + 3, gy1 - 3, "furnace"); _s.call(bx + 7, gy1 - 3, "chest")
			_s.call(bx + 8, gy1 - 3, "chest"); _s.call(bx + 9, gy1 - 3, "crafting_table")
			_s.call(bx + 3, gy1 - 4, "torch_wall"); _s.call(bx + 6, gy1 - 4, "torch_wall")
			for r in range(bh, bh + 3): _s.call(bx + 10, gy1 - 2 - r, "stone_brick")

		2:  # Right village chunk: 2 homes + wheat garden
			var gy2: int = _flatten.call(0, cw - 1)
			_home.call(1,  1)
			_home.call(21, 0)
			for dx in range(10, 21):
				if not tiles.has(Vector2i(dx, gy2 - 1)):
					_s.call(dx, gy2 - 1, "cobblestone")
			for dx in range(11, 19): _s.call(dx, gy2 - 1, "wheat_crop")
			_s.call(10, gy2 - 2, "fence_wood"); _s.call(19, gy2 - 2, "fence_wood")
			_lamp.call(10, gy2); _lamp.call(20, gy2)


# ---------------------------------------------------------------------------
#  _place_structures — additional seeded structures per chunk
# ---------------------------------------------------------------------------

## _struct_phase(chunk_x, period, gap, uid, seed) → int
## Returns a seeded random phase in [gap, period-gap) for a period-based structure.
## Each "window" of `period` chunks gets a different random offset so structures
## appear at varied distances rather than fixed intervals.
static func _struct_phase(chunk_x: int, period: int, gap: int, uid: int, seed: int) -> int:
	var pnum: int = floori(float(chunk_x) / float(period))
	return gap + absi(pnum * 7369 + uid * 1013 + seed * 31) % (period - 2 * gap)


## _place_structures(chunk_x, tiles, heightmap, seed)
## Uses a deterministic per-chunk RNG to place at most ONE structure per chunk.
## Period-based structures use seeded random offsets for varied spacing.
## No structures are placed within 200 tiles of the world spawn (x=0).
static func _place_structures(chunk_x: int, tiles: Dictionary,
		heightmap: Array[int], seed: int) -> void:

	# ── Spawn exclusion zone: no structures within 200 tiles of x=0 ──────────
	# A chunk spans CHUNK_WIDTH tiles; protect any chunk whose range overlaps [-200, 200].
	if abs(chunk_x) * GameData.CHUNK_WIDTH <= 200:
		return

	var world_x_offset: int = chunk_x * GameData.CHUNK_WIDTH
	var rng_seed: int = (chunk_x * 7919 + seed) % 99991
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var biome := _get_biome(world_x_offset + GameData.CHUNK_WIDTH / 2, seed)

	# Stone Tower — ~every 50 chunks (randomised offset per window), any biome except desert.
	if GameData.structures_enabled.get("towers", true):
		if posmod(chunk_x, 50) == _struct_phase(chunk_x, 50, 5, 1, seed) and biome != _BiomeType.DESERT:
			var anchor := GameData.CHUNK_WIDTH / 2
			if anchor >= 0 and anchor < GameData.CHUNK_WIDTH:
				_place_stone_tower(tiles, heightmap, anchor, rng)
			return

	# Desert Temple — ~every 40 chunks in desert biome.
	if GameData.structures_enabled.get("temples", true):
		if posmod(chunk_x, 40) == _struct_phase(chunk_x, 40, 4, 2, seed) and biome == _BiomeType.DESERT:
			var anchor := GameData.CHUNK_WIDTH / 2
			_place_desert_temple(tiles, heightmap, anchor)
			return

	# Forest Ruins — ~2% random chance in forest/plains biome.
	if GameData.structures_enabled.get("ruins", true):
		if rng.randf() < 0.02 and (biome == _BiomeType.FOREST or biome == _BiomeType.PLAINS):
			var anchor := 4 + (rng.randi() % (GameData.CHUNK_WIDTH - 12))
			_place_forest_ruins(tiles, heightmap, anchor, rng)
			return

	# Town Building — ~every 60 chunks in plains.
	if GameData.structures_enabled.get("towns", true):
		if posmod(chunk_x, 60) == _struct_phase(chunk_x, 60, 6, 3, seed) and biome == _BiomeType.PLAINS:
			var anchor := GameData.CHUNK_WIDTH / 2 - 6
			if anchor >= 0 and anchor + 12 < GameData.CHUNK_WIDTH:
				_place_town_building(tiles, heightmap, anchor, rng)
			return

	# Blacksmith — ~every 45 chunks, plains or forest.
	if GameData.structures_enabled.get("blacksmith", true):
		if posmod(chunk_x, 45) == _struct_phase(chunk_x, 45, 5, 4, seed) and (biome == _BiomeType.PLAINS or biome == _BiomeType.FOREST):
			var anchor := GameData.CHUNK_WIDTH / 2 - 5
			if anchor >= 0 and anchor + 10 < GameData.CHUNK_WIDTH:
				_place_blacksmith(tiles, heightmap, anchor, rng)
			return

	# Library — ~every 55 chunks, plains.
	if GameData.structures_enabled.get("library", true):
		if posmod(chunk_x, 55) == _struct_phase(chunk_x, 55, 5, 5, seed) and biome == _BiomeType.PLAINS:
			var anchor := GameData.CHUNK_WIDTH / 2 - 6
			if anchor >= 0 and anchor + 12 < GameData.CHUNK_WIDTH:
				_place_library(tiles, heightmap, anchor, rng)
			return

	# Underground Bunker — ~3% random chance, any biome.
	if GameData.structures_enabled.get("bunker", true):
		if rng.randf() < 0.03:
			var anchor := 8 + (rng.randi() % (GameData.CHUNK_WIDTH - 20))
			_place_underground_bunker(tiles, heightmap, anchor, rng)
			return

	# Watchtower — ~every 35 chunks, plains or snow.
	if GameData.structures_enabled.get("watchtower", true):
		if posmod(chunk_x, 35) == _struct_phase(chunk_x, 35, 4, 6, seed) and (biome == _BiomeType.PLAINS or biome == _BiomeType.SNOW):
			var anchor := GameData.CHUNK_WIDTH / 2 - 1
			if anchor >= 0 and anchor + 3 < GameData.CHUNK_WIDTH:
				_place_watchtower(tiles, heightmap, anchor, rng)
			return

	# Market Stall — ~4% random chance, plains.
	if GameData.structures_enabled.get("market_stall", true):
		if rng.randf() < 0.04 and biome == _BiomeType.PLAINS:
			var anchor := 4 + (rng.randi() % (GameData.CHUNK_WIDTH - 12))
			_place_market_stall(tiles, heightmap, anchor, rng)
			return

	# Graveyard — ~2% random chance, forest or plains.
	if GameData.structures_enabled.get("graveyard", true):
		if rng.randf() < 0.02 and (biome == _BiomeType.FOREST or biome == _BiomeType.PLAINS):
			var anchor := 4 + (rng.randi() % (GameData.CHUNK_WIDTH - 20))
			_place_graveyard(tiles, heightmap, anchor, rng)
			return

	# Snow Cabin — ~every 30 chunks, snow biome.
	if GameData.structures_enabled.get("snow_cabin", true):
		if posmod(chunk_x, 30) == _struct_phase(chunk_x, 30, 3, 7, seed) and biome == _BiomeType.SNOW:
			var anchor := GameData.CHUNK_WIDTH / 2 - 5
			if anchor >= 0 and anchor + 10 < GameData.CHUNK_WIDTH:
				_place_snow_cabin(tiles, heightmap, anchor, rng)
			return

	# Desert Outpost — ~3% random chance, desert biome.
	if GameData.structures_enabled.get("desert_outpost", true):
		if rng.randf() < 0.03 and biome == _BiomeType.DESERT:
			var anchor := 4 + (rng.randi() % (GameData.CHUNK_WIDTH - 12))
			_place_desert_outpost(tiles, heightmap, anchor, rng)
			return

	# Mine Entrance — ~2% random chance, any biome.
	if GameData.structures_enabled.get("mine_entrance", true):
		if rng.randf() < 0.02:
			var anchor := 4 + (rng.randi() % (GameData.CHUNK_WIDTH - 10))
			_place_mine_entrance(tiles, heightmap, anchor, rng)
			return

	# City — rare (~every 200 chunks), plains biome only, spans 3 chunks.
	if GameData.structures_enabled.get("city", true):
		var nearest_city: int = roundi(float(chunk_x) / 200.0) * 200
		var city_slot: int = chunk_x - (nearest_city - 1)
		if city_slot >= 0 and city_slot <= 2 and biome == _BiomeType.PLAINS:
			_place_city(tiles, heightmap, city_slot, rng)
			return

	# Abandoned Farm — ~3% random chance, plains or forest.
	if GameData.structures_enabled.get("abandoned_farm", true):
		if rng.randf() < 0.03 and (biome == _BiomeType.PLAINS or biome == _BiomeType.FOREST):
			var anchor := 4 + (rng.randi() % (GameData.CHUNK_WIDTH - 22))
			_place_abandoned_farm(tiles, heightmap, anchor, rng)
			return  # one structure per chunk — prevent stacking with dungeon/castle

	# Dungeon — ~2% random chance, underground, any biome.
	if GameData.structures_enabled.get("dungeon", true):
		if rng.randf() < 0.02:
			var anchor := 4 + (rng.randi() % (GameData.CHUNK_WIDTH - 16))
			_place_dungeon(tiles, heightmap, anchor, rng)
			return  # one structure per chunk — prevent stacking with castle

	# Castle — ~every 80 chunks (randomised offset), plains biome only.
	if GameData.structures_enabled.get("castle", true):
		if posmod(chunk_x, 80) == _struct_phase(chunk_x, 80, 8, 8, seed) and biome == _BiomeType.PLAINS:
			_place_castle(tiles, heightmap, rng)


## _place_floating_features — decides whether to place floating islands or a
## sky castle in this chunk's sky space. Called once per chunk.
static func _place_floating_features(chunk_x: int, tiles: Dictionary,
		heightmap: Array[int], seed: int) -> void:

	# No sky features within the spawn exclusion zone.
	if abs(chunk_x) * GameData.CHUNK_WIDTH <= 200:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = (chunk_x * 13337 + seed * 31) % 999983

	# ── Floating islands (appear roughly every 10 chunks, can have 1-2 per chunk)
	if GameData.structures_enabled.get("floating_islands", true):
		var island_chance: float = 0.12  # ~12% per chunk = ~1 island per 8 chunks
		var num_islands: int = 0
		if rng.randf() < island_chance:
			num_islands = 1
		if rng.randf() < island_chance * 0.5:
			num_islands += 1
		for _i in num_islands:
			_place_floating_island(chunk_x, tiles, heightmap, rng, seed)

	# ── Floating sky castles — every ~35 chunks; offset 8 so first one is ~8 chunks from spawn
	if GameData.structures_enabled.get("floating_castle", true):
		if (chunk_x % 35) == 8 or (chunk_x % 35) == (35 - 8):
			_place_sky_castle(chunk_x, tiles, heightmap, rng, seed)


## _place_floating_island — places a small sky island with grass/dirt/stone
## layers, topped with trees and surface decor.  The island hovers at a
## seeded height in the sky, well above the terrain below it.
static func _place_floating_island(chunk_x: int, tiles: Dictionary,
		heightmap: Array[int], rng: RandomNumberGenerator, seed: int) -> void:

	# Island horizontal size: 12–35 tiles wide.
	var width: int = 12 + rng.randi() % 24
	# Left edge within chunk (keep fully inside).
	var local_x0: int = 2 + rng.randi() % maxi(1, GameData.CHUNK_WIDTH - width - 4)

	# Find min terrain height in the island's column range.
	var min_terrain_y: int = GameData.CHUNK_HEIGHT
	for cx in range(local_x0, mini(local_x0 + width, GameData.CHUNK_WIDTH)):
		if cx < heightmap.size():
			min_terrain_y = mini(min_terrain_y, heightmap[cx])

	# Island base row: must be above terrain by at least SKY_MIN_CLEARANCE,
	# and above SKY_TOP_ROW.
	var sky_bottom: int = min_terrain_y - SKY_MIN_CLEARANCE
	if sky_bottom < SKY_TOP_ROW + 8:
		return  # no room in the sky for this chunk

	var island_top_y: int = SKY_TOP_ROW + rng.randi() % maxi(1, sky_bottom - SKY_TOP_ROW - 6)
	island_top_y = clampi(island_top_y, SKY_TOP_ROW, sky_bottom - 6)

	# Island is 3-6 tiles thick (top=grass, 1-3 dirt, 1-2 stone).
	var dirt_depth: int = 1 + rng.randi() % 3
	var stone_depth: int = 1 + rng.randi() % 2
	var island_height: int = 1 + dirt_depth + stone_depth

	# Elliptical shape: taper left/right edges.
	for col in range(width):
		var lx: int = local_x0 + col
		if lx >= GameData.CHUNK_WIDTH:
			break
		# Taper: skip outermost 1-2 tiles on each side for a more natural shape.
		var taper: int = 0
		if col == 0 or col == width - 1:
			taper = 2
		elif col == 1 or col == width - 2:
			taper = 1
		var col_top: int = island_top_y + taper
		var col_bot: int = island_top_y + island_height - taper

		for row in range(col_top, col_bot):
			if row < HEIGHT_LIMIT_ROW or row >= GameData.CHUNK_HEIGHT:
				continue
			var depth_in_island: int = row - col_top
			var tile_id: String
			if depth_in_island == 0:
				tile_id = "grass"
			elif depth_in_island <= dirt_depth:
				tile_id = "dirt"
			else:
				tile_id = "stone"
			tiles[Vector2i(lx, row)] = tile_id

	# Surface decorations: trees on top of the island.
	var biome := _get_biome(chunk_x * GameData.CHUNK_WIDTH + local_x0 + width / 2, seed)
	var tree_type: String = "birch" if rng.randf() < 0.4 else "oak"
	if biome == _BiomeType.JUNGLE: tree_type = "jungle"
	for col in range(1, width - 1):
		var lx: int = local_x0 + col
		if lx >= GameData.CHUNK_WIDTH:
			break
		# Check the grass tile actually exists.
		if not tiles.has(Vector2i(lx, island_top_y)):
			continue
		# ~20% chance of a tree.
		if rng.randf() < 0.20:
			_place_tree(tiles, lx, island_top_y, tree_type, rng)
		# ~10% chance of a flower/grass decor.
		elif rng.randf() < 0.10:
			tiles[Vector2i(lx, island_top_y - 1)] = "tall_grass"


## _place_sky_castle — Epic floating sky fortress.
## Spans the full chunk width.  Two wing sections flank a grand courtyard.
## Four corner towers + one massive central keep rise above the main walls.
## Spawns on every eligible chunk (handled by caller).
static func _place_sky_castle(_chunk_x: int, tiles: Dictionary,
		heightmap: Array[int], rng: RandomNumberGenerator, _seed: int) -> void:

	# ── Dimensions ────────────────────────────────────────────────────────
	const W: int  = 30   # main castle body width (per wing)
	const H: int  = 18   # main wall height (floor to top of parapet)
	const WALL: int = 2  # wall thickness in tiles

	# Castle occupies columns 1..CHUNK_WIDTH-2 (leave 1 tile gap each side).
	var x0: int = 1
	var total_w: int = GameData.CHUNK_WIDTH - 2

	# ── Sky placement ──────────────────────────────────────────────────────
	var min_terrain: int = GameData.CHUNK_HEIGHT
	for cx in range(0, GameData.CHUNK_WIDTH):
		if cx < heightmap.size():
			min_terrain = mini(min_terrain, heightmap[cx])

	var sky_floor: int = min_terrain - SKY_MIN_CLEARANCE - 6
	if sky_floor < SKY_TOP_ROW + 50:
		return  # not enough vertical sky

	# Base of the castle sits at sky_floor; structure rises upward.
	var base_y: int   = sky_floor            # bottommost foundation row
	var floor_y: int  = base_y - 1           # main interior floor (planks)
	var wall_top: int = base_y - H           # top of the outer wall

	# ── Helpers ────────────────────────────────────────────────────────────
	var cw: int = GameData.CHUNK_WIDTH

	# Place a tile only if row is in valid bounds.
	var _set := func(lx: int, row: int, id: String) -> void:
		if lx >= 0 and lx < cw and row >= HEIGHT_LIMIT_ROW and row < GameData.CHUNK_HEIGHT:
			tiles[Vector2i(lx, row)] = id

	var _clear := func(lx: int, row: int) -> void:
		if lx >= 0 and lx < cw:
			tiles.erase(Vector2i(lx, row))

	# Fill a column range with a tile ID.
	var _col := func(lx: int, r0: int, r1: int, id: String) -> void:
		for r in range(r0, r1 + 1):
			_set.call(lx, r, id)

	# Fill a row range with a tile ID.
	var _row_fill := func(r: int, x_a: int, x_b: int, id: String) -> void:
		for lx in range(x_a, x_b + 1):
			_set.call(lx, r, id)

	# ── 1.  ISLAND FOUNDATION (gives the castle something to sit on) ───────
	# A large floating island of stone + dirt + grass.
	for col in range(x0, x0 + total_w):
		_set.call(col, base_y,     "grass")
		_set.call(col, base_y + 1, "dirt")
		_set.call(col, base_y + 2, "stone")
		_set.call(col, base_y + 3, "stone")
		_set.call(col, base_y + 4, "stone")

	# ── 2.  OUTER WALLS (perimeter) ────────────────────────────────────────
	# Left wall
	for r in range(wall_top, base_y):
		for t in range(WALL):
			_set.call(x0 + t, r, "stone_brick")
	# Right wall
	for r in range(wall_top, base_y):
		for t in range(WALL):
			_set.call(x0 + total_w - 1 - t, r, "stone_brick")
	# Top (ceiling) of outer wall
	_row_fill.call(wall_top, x0, x0 + total_w - 1, "stone_brick")
	# Bottom floor row (planks over island)
	_row_fill.call(floor_y, x0 + WALL, x0 + total_w - WALL - 1, "planks_oak")

	# ── 3.  INNER DIVIDING WALLS + ROOMS ───────────────────────────────────
	# Split the interior into three sections: left wing | courtyard | right wing.
	var mid: int      = x0 + total_w / 2
	var wing_w: int   = total_w / 4

	# Left divider (left wing right wall).
	for r in range(wall_top, floor_y + 1):
		for t in range(WALL):
			_set.call(x0 + wing_w + t, r, "stone_brick")
	# Right divider (right wing left wall).
	for r in range(wall_top, floor_y + 1):
		for t in range(WALL):
			_set.call(x0 + total_w - wing_w - t, r, "stone_brick")

	# Inner floors for the two wings.
	var mid_floor_y: int = wall_top + (H / 2)
	_row_fill.call(mid_floor_y, x0 + WALL, x0 + wing_w - 1, "planks_oak")
	_row_fill.call(mid_floor_y, x0 + total_w - wing_w + WALL, x0 + total_w - WALL - 1, "planks_oak")

	# ── 4.  BATTLEMENTS (crenelations) along the top ───────────────────────
	# Every other tile on the top row becomes a merlon.
	for col in range(x0, x0 + total_w):
		if (col - x0) % 2 == 0:
			for r in range(wall_top - 3, wall_top):
				_set.call(col, r, "stone_brick")

	# ── 5.  CORNER TOWERS (four, one at each corner) ───────────────────────
	const TW: int = 5    # tower width
	const TH: int = 14   # tower height above the wall top
	var tower_cols: Array[int] = [x0, x0 + total_w - TW]
	for tx in tower_cols:
		# Tower walls
		for r in range(wall_top - TH, base_y):
			_set.call(tx,          r, "stone_brick")
			_set.call(tx + TW - 1, r, "stone_brick")
		# Tower top + battlements
		for col in range(tx, tx + TW):
			_set.call(col, wall_top - TH, "stone_brick")
			if (col - tx) % 2 == 0:
				for r in range(wall_top - TH - 3, wall_top - TH):
					_set.call(col, r, "stone_brick")
		# Tower floor
		_row_fill.call(base_y - 2, tx + 1, tx + TW - 2, "planks_oak")
		# Window openings
		var win_r: int = wall_top - TH / 2
		_clear.call(tx,          win_r)
		_clear.call(tx,          win_r - 1)
		_clear.call(tx + TW - 1, win_r)
		_clear.call(tx + TW - 1, win_r - 1)
		# Torch on tower top (use chest as loot marker)
		_set.call(tx + TW / 2, base_y - 3, "chest")

	# ── 6.  CENTRAL KEEP (the most epic part — tall spire in the middle) ────
	const KW: int = 10   # keep width
	const KH: int = 28   # keep height above wall top
	var kx: int   = mid - KW / 2

	# Keep outer walls
	for r in range(wall_top - KH, base_y):
		for t in range(WALL):
			_set.call(kx + t,           r, "stone_brick")
			_set.call(kx + KW - 1 - t, r, "stone_brick")
	# Keep roof
	_row_fill.call(wall_top - KH, kx, kx + KW - 1, "stone_brick")
	# Keep floors (three levels)
	for lvl in [base_y - 2, base_y - 9, wall_top - KH + 3]:
		_row_fill.call(lvl, kx + WALL, kx + KW - WALL - 1, "planks_oak")
	# Keep battlements
	for col in range(kx, kx + KW):
		if (col - kx) % 2 == 0:
			for r in range(wall_top - KH - 4, wall_top - KH):
				_set.call(col, r, "stone_brick")
	# Keep windows (pairs on each side)
	for win_r in [wall_top - KH + 7, wall_top - KH + 14]:
		_clear.call(kx,           win_r)
		_clear.call(kx,           win_r + 1)
		_clear.call(kx + KW - 1,  win_r)
		_clear.call(kx + KW - 1,  win_r + 1)
	# Gate into the keep from the courtyard (bottom centre).
	var gate_cx: int = kx + KW / 2 - 1
	for col in [gate_cx, gate_cx + 1, gate_cx + 2]:
		_clear.call(col, floor_y)
		_clear.call(col, floor_y - 1)
		_clear.call(col, floor_y - 2)
	# Boss chest inside the keep throne room (top floor).
	_set.call(mid, wall_top - KH + 2, "chest")
	_set.call(mid - 1, wall_top - KH + 2, "chest")

	# ── 7.  SPIRE on top of the keep ──────────────────────────────────────
	const SP_W: int = 4
	const SP_H: int = 12
	var sx: int = mid - SP_W / 2
	for r in range(wall_top - KH - SP_H, wall_top - KH):
		var progress: float = float(r - (wall_top - KH - SP_H)) / float(SP_H)
		var half: int = maxi(1, int((1.0 - progress) * SP_W / 2))
		for col in range(sx, sx + SP_W):
			var dist: int = absi(col - (sx + SP_W / 2 - 1))
			if dist <= half:
				_set.call(col, r, "stone_brick")

	# ── 8.  GATE in outer wall (bottom centre, enters the courtyard) ───────
	var outer_gate: int = mid - 2
	for col in range(outer_gate, outer_gate + 4):
		_clear.call(col, base_y)
		_clear.call(col, base_y - 1)
		_clear.call(col, base_y - 2)
		_clear.call(col, base_y - 3)
		_clear.call(col, wall_top)

	# ── 9.  COURTYARD features ─────────────────────────────────────────────
	# Mossy cobblestone floor across the courtyard.
	for col in range(x0 + wing_w + WALL, x0 + total_w - wing_w - WALL):
		_set.call(col, floor_y, "cobblestone")
	# Two additional chests flanking the keep gate.
	_set.call(gate_cx - 2, floor_y - 1, "chest")
	_set.call(gate_cx + 4, floor_y - 1, "chest")


## _place_stone_tower — impressive 7-wide, 28-tall multi-floor stone tower.
## Variant 0: standard fortified tower with 3 interior floors, ladder, battlements.
## Variant 1: ruined tower — crumbling top, mossy lower half, vines, loot chest.
static func _place_stone_tower(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	var cw: int = GameData.CHUNK_WIDTH
	if local_anchor < 0 or local_anchor + 7 >= cw:
		return

	var ground_y: int = heightmap[local_anchor + 3]
	var variant: int = rng.randi() % 2
	var tower_h: int = 26
	var tw: int = 7  # tower width

	# Flatten base
	for dx in range(tw):
		var col: int = local_anchor + dx
		if col >= 0 and col < cw:
			if heightmap[col] > ground_y:
				for fy in range(ground_y, heightmap[col]):
					tiles[Vector2i(col, fy)] = "stone_brick"
				heightmap[col] = ground_y

	var wall_id: String
	var floor_id: String = "planks_dark_oak"

	if variant == 0:
		wall_id = "stone_brick"
	else:
		wall_id = "mossy_stone_brick"

	# Main tower walls + interior (3 floors at rows 6, 13, 20)
	for row in range(tower_h):
		var ty: int = ground_y - 1 - row
		if ty < 0: break
		var is_floor: bool = row == 6 or row == 13 or row == 20
		var ruined: bool = variant == 1 and row >= 20 and rng.randf() < 0.25
		for dx in range(tw):
			var col: int = local_anchor + dx
			if col < 0 or col >= cw: continue
			var wid: String = "cracked_stone_brick" if variant == 1 and row >= 13 else wall_id
			if ruined and (dx == 0 or dx == tw - 1):
				tiles.erase(Vector2i(col, ty))
			elif dx == 0 or dx == tw - 1 or row == 0:
				tiles[Vector2i(col, ty)] = wid
			elif is_floor:
				tiles[Vector2i(col, ty)] = floor_id
			else:
				tiles.erase(Vector2i(col, ty))

	# Battlements at top (alternating merlons 2 rows above tower top)
	for brow in range(3):
		var ty: int = ground_y - tower_h - brow
		if ty < 0: break
		for dx in range(tw):
			var col: int = local_anchor + dx
			if col < 0 or col >= cw: continue
			if brow < 2 and dx % 2 == 0:
				tiles[Vector2i(col, ty)] = wall_id
			elif brow == 0 and dx % 2 == 1:
				tiles[Vector2i(col, ty)] = wall_id

	# Interior ladder (center column, all floors)
	var ladder_col: int = local_anchor + 3
	if ladder_col >= 0 and ladder_col < cw:
		for row in range(1, tower_h):
			var ty: int = ground_y - 1 - row
			if ty < 0: break
			tiles[Vector2i(ladder_col, ty)] = "ladder"

	# Arrow slits (windows on each side, each floor)
	for floor_row in [3, 10, 17]:
		var ty: int = ground_y - 1 - floor_row
		if ty < 0: continue
		for dx in [0, tw - 1]:
			var col: int = local_anchor + dx
			if col >= 0 and col < cw:
				tiles.erase(Vector2i(col, ty))

	# Interior furnishings per floor
	var floor_rows: Array = [5, 12, 19]
	for i in floor_rows.size():
		var frow: int = floor_rows[i]
		var ty: int = ground_y - 1 - frow
		if ty < 0: continue
		if i == 0:
			# Ground floor: chest + torch
			var col: int = local_anchor + 1
			if col < cw: tiles[Vector2i(col, ty)] = "chest"
			col = local_anchor + 5
			if col < cw: tiles[Vector2i(col, ty)] = "torch_wall"
		elif i == 1:
			# Mid floor: barrel + torch
			var col: int = local_anchor + 5
			if col < cw: tiles[Vector2i(col, ty)] = "barrel"
			col = local_anchor + 1
			if col < cw: tiles[Vector2i(col, ty)] = "torch_wall"
		else:
			# Top floor: chest
			var col: int = local_anchor + 1
			if col < cw: tiles[Vector2i(col, ty)] = "chest"

	# Variant 1 extra: vines on exterior walls
	if variant == 1:
		for dx in [0, tw - 1]:
			var col: int = local_anchor + dx
			if col < 0 or col >= cw: continue
			for row in [8, 10, 14, 16]:
				var ty: int = ground_y - 1 - row
				if ty >= 0: tiles[Vector2i(col, ty)] = "vines"


## _place_desert_temple — 15 wide, 12 tall sandstone temple.
static func _place_desert_temple(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int) -> void:

	if local_anchor < 2 or local_anchor + 15 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 7]

	# Base platform (2 rows thick)
	for row in range(2):
		var ty: int = ground_y + row
		for dx in range(15):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ty)] = "sandstone"

	# Walls
	for row in range(1, 12):
		var ty: int = ground_y - row
		if ty < 0:
			break
		for dx in range(15):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			if dx == 0 or dx == 14:
				# Pillar columns at entrance corners
				tiles[Vector2i(col, ty)] = "pillar"
			elif dx == 1 or dx == 13 or row == 11:
				tiles[Vector2i(col, ty)] = "sandstone_smooth"
			elif dx == 7 and row == 6:
				tiles[Vector2i(col, ty)] = "chiseled_stone"
			elif dx == 0 or dx == 14 or row == 1:
				tiles[Vector2i(col, ty)] = "sandstone"
			else:
				tiles.erase(Vector2i(col, ty))

	# Doorway opening
	for row in [1, 2, 3]:
		var ty: int = ground_y - row
		if ty < 0:
			continue
		for dx in [6, 7, 8]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles.erase(Vector2i(col, ty))

	# Decorative chiseled_stone accents at mid height
	var mid_y: int = ground_y - 6
	if mid_y >= 0:
		for col_off in [3, 11]:
			var col: int = local_anchor + col_off
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, mid_y)] = "sandstone_chiseled"


## _place_forest_ruins — mossy ruin with 3 layout variants.
## Variant 0: original two partial walls + mossy floor.
## Variant 1: L-shaped ruin, 12 wide, overgrown with vines/mushrooms.
## Variant 2: ruined arch — two pillar stubs with arch_stone on top, collapsed walls.
static func _place_forest_ruins(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	var variant: int = rng.randi() % 3

	if variant == 0:
		# Variant 0: original
		if local_anchor < 0 or local_anchor + 8 >= GameData.CHUNK_WIDTH:
			return
		var ground_y: int = heightmap[local_anchor + 4]

		for dx in range(8):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ground_y - 1)] = "cobblestone"

		for row in range(1, 6):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			for dx in [0, 7]:
				var col: int = local_anchor + dx
				if col < 0 or col >= GameData.CHUNK_WIDTH:
					continue
				if rng.randf() > 0.30:
					var wall_id: String = "mossy_stone_brick" if rng.randf() < 0.6 else "stone_brick"
					tiles[Vector2i(col, ty)] = wall_id

		for row in range(1, 4):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			for dx in [1, 6]:
				var col: int = local_anchor + dx
				if col >= 0 and col < GameData.CHUNK_WIDTH:
					if not tiles.has(Vector2i(col, ty)) and rng.randf() < 0.5:
						tiles[Vector2i(col, ty)] = "vines"

	elif variant == 1:
		# Variant 1: L-shaped ruin, 12 wide, one wall collapsed, overgrown
		if local_anchor < 0 or local_anchor + 12 >= GameData.CHUNK_WIDTH:
			return
		var ground_y: int = heightmap[local_anchor + 6]

		# Cobblestone floor (full 12 wide)
		for dx in range(12):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ground_y - 1)] = "cobblestone"

		# Left vertical wall (full height 5)
		for row in range(1, 6):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			var col: int = local_anchor
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				if rng.randf() > 0.20:
					tiles[Vector2i(col, ty)] = "mossy_stone_brick"

		# Bottom horizontal wall (only left half, dx 0..5 — "L" shape)
		for dx in range(1, 6):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			for row in range(1, 4):
				var ty: int = ground_y - 1 - row
				if ty < 0:
					break
				if rng.randf() > 0.25:
					tiles[Vector2i(col, ty)] = "mossy_stone_brick"

		# Right wall stub (partial, dx 11, only lower 3 rows)
		for row in range(1, 3):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			var col: int = local_anchor + 11
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				if rng.randf() > 0.35:
					tiles[Vector2i(col, ty)] = "stone_brick"

		# Vines and mushrooms scattered inside
		for dx in range(1, 11):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			if rng.randf() < 0.20:
				tiles[Vector2i(col, ground_y - 2)] = "vines"
			if rng.randf() < 0.12:
				var shroom: String = "mushroom_red" if rng.randf() < 0.5 else "mushroom_brown"
				tiles[Vector2i(col, ground_y - 2)] = shroom

	else:
		# Variant 2: ruined arch — two pillar stubs + arch_stone on top, collapsed cobblestone
		if local_anchor < 0 or local_anchor + 8 >= GameData.CHUNK_WIDTH:
			return
		var ground_y: int = heightmap[local_anchor + 4]

		# Cobblestone rubble on floor
		for dx in range(8):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ground_y - 1)] = "cobblestone"

		# Left pillar stub (3 tall)
		for row in range(1, 4):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			var col: int = local_anchor + 1
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "pillar"

		# Right pillar stub (3 tall)
		for row in range(1, 4):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			var col: int = local_anchor + 6
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "pillar"

		# Arch stone across the top of the two pillars
		var arch_y: int = ground_y - 4
		if arch_y >= 0:
			for dx in range(1, 7):
				var col: int = local_anchor + dx
				if col >= 0 and col < GameData.CHUNK_WIDTH:
					tiles[Vector2i(col, arch_y)] = "arch_stone"

		# Collapsed cobblestone walls to the sides (scattered, low)
		for dx in [0, 7]:
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			for row in range(1, 3):
				var ty: int = ground_y - 1 - row
				if ty < 0:
					break
				if rng.randf() > 0.40:
					tiles[Vector2i(col, ty)] = "cobblestone"

		# Vines hanging from arch
		for dx in [2, 3, 4, 5]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				if rng.randf() < 0.50:
					tiles[Vector2i(col, ground_y - 3)] = "vines"


## _place_town_building — brick building with glass windows.
## Variant 0: original 12 wide × 10 tall. Variant 1: 16-wide inn, 2-story, planks_oak walls.
static func _place_town_building(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	var variant: int = rng.randi() % 2

	if variant == 0:
		# Variant 0: original 12 wide × 10 tall brick building
		if local_anchor < 0 or local_anchor + 12 >= GameData.CHUNK_WIDTH:
			return

		var ground_y: int = heightmap[local_anchor + 6]

		# Flatten ground
		for dx in range(12):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			var col_y := heightmap[col]
			while col_y > ground_y:
				tiles[Vector2i(col, col_y - 1)] = "dirt"
				col_y -= 1

		# Plank floor
		for dx in range(12):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ground_y - 1)] = "planks_oak"

		# Brick walls + roof
		for row in range(1, 10):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			for dx in range(12):
				var col: int = local_anchor + dx
				if col < 0 or col >= GameData.CHUNK_WIDTH:
					continue
				if row == 9:
					tiles[Vector2i(col, ty)] = "stone_brick"
				elif dx == 0 or dx == 11:
					tiles[Vector2i(col, ty)] = "brick"
				else:
					tiles.erase(Vector2i(col, ty))

		# Glass windows (two windows each side)
		for row in [3, 4]:
			var ty: int = ground_y - 1 - row
			if ty < 0:
				continue
			for win_dx in [2, 3, 8, 9]:
				var col: int = local_anchor + win_dx
				if col >= 0 and col < GameData.CHUNK_WIDTH:
					tiles[Vector2i(col, ty)] = "window_glass"

		# Door opening
		for row in [1, 2, 3]:
			var ty: int = ground_y - 1 - row
			if ty < 0:
				continue
			for dx in [5, 6]:
				var col: int = local_anchor + dx
				if col >= 0 and col < GameData.CHUNK_WIDTH:
					tiles.erase(Vector2i(col, ty))

		# Stone brick chimney (right side, 3 blocks above roof)
		for row in range(9, 13):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			var col: int = local_anchor + 10
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "stone_brick"

	else:
		# Variant 1: 16-wide inn — planks_oak walls, 2-story (14 tall), glass windows both floors,
		# barrel + bookshelf inside, torch_wall on outer wall.
		if local_anchor < 0 or local_anchor + 16 >= GameData.CHUNK_WIDTH:
			return

		var ground_y: int = heightmap[local_anchor + 8]

		# Flatten ground
		for dx in range(16):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			var col_y := heightmap[col]
			while col_y > ground_y:
				tiles[Vector2i(col, col_y - 1)] = "dirt"
				col_y -= 1

		# Plank floor
		for dx in range(16):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ground_y - 1)] = "planks_oak"

		# Mid-floor (between stories) at row 7
		for dx in range(16):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ground_y - 8)] = "planks_oak"

		# Walls + roof (14 rows tall)
		for row in range(1, 14):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			for dx in range(16):
				var col: int = local_anchor + dx
				if col < 0 or col >= GameData.CHUNK_WIDTH:
					continue
				if row == 13:
					# Roof
					tiles[Vector2i(col, ty)] = "planks_dark_oak"
				elif dx == 0 or dx == 15:
					tiles[Vector2i(col, ty)] = "planks_oak"
				elif row == 7:
					pass  # mid-floor already placed above
				else:
					tiles.erase(Vector2i(col, ty))

		# Ground floor windows
		for row in [3, 4]:
			var ty: int = ground_y - 1 - row
			if ty < 0:
				continue
			for win_dx in [2, 3, 12, 13]:
				var col: int = local_anchor + win_dx
				if col >= 0 and col < GameData.CHUNK_WIDTH:
					tiles[Vector2i(col, ty)] = "window_glass"

		# Second floor windows
		for row in [10, 11]:
			var ty: int = ground_y - 1 - row
			if ty < 0:
				continue
			for win_dx in [2, 3, 12, 13]:
				var col: int = local_anchor + win_dx
				if col >= 0 and col < GameData.CHUNK_WIDTH:
					tiles[Vector2i(col, ty)] = "window_glass"

		# Door opening (ground floor, 2-wide, 3-tall)
		for row in [1, 2, 3]:
			var ty: int = ground_y - 1 - row
			if ty < 0:
				continue
			for dx in [7, 8]:
				var col: int = local_anchor + dx
				if col >= 0 and col < GameData.CHUNK_WIDTH:
					tiles.erase(Vector2i(col, ty))

		# Interior furniture
		var barrel_col: int = local_anchor + 2
		var bookshelf_col: int = local_anchor + 13
		if barrel_col >= 0 and barrel_col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(barrel_col, ground_y - 2)] = "barrel"
		if bookshelf_col >= 0 and bookshelf_col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(bookshelf_col, ground_y - 2)] = "bookshelf"

		# torch_wall sign on outer wall beside door
		for dx in [6, 9]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ground_y - 4)] = "torch_wall"

		# Chimney (right side)
		for row in range(13, 17):
			var ty: int = ground_y - 1 - row
			if ty < 0:
				break
			var col: int = local_anchor + 14
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "stone_brick"


## _place_blacksmith — 10 wide × 8 tall stone_brick smithy with anvil, furnace, chest.
## Stone chimney 3 blocks above roof on right side.
static func _place_blacksmith(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 10 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 5]

	# Flatten ground
	for dx in range(10):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		var col_y := heightmap[col]
		while col_y > ground_y:
			tiles[Vector2i(col, col_y - 1)] = "dirt"
			col_y -= 1

	# Cobblestone floor
	for dx in range(10):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		tiles[Vector2i(col, ground_y - 1)] = "cobblestone"

	# Walls + roof (8 rows)
	for row in range(1, 8):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		for dx in range(10):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			if row == 7:
				tiles[Vector2i(col, ty)] = "planks_spruce"
			elif dx == 0 or dx == 9:
				tiles[Vector2i(col, ty)] = "stone_brick"
			else:
				tiles.erase(Vector2i(col, ty))

	# Back wall (dx 0..9 at row 1..6, back = top row of interior area — close it)
	for row in range(1, 7):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		# Back wall is implied by left/right walls; add top/bottom back rail
		# Nothing extra needed — open front

	# Door opening: 2-wide gap in front (row 1 and 2, dx 4 and 5)
	for row in [1, 2]:
		var ty: int = ground_y - 1 - row
		if ty < 0:
			continue
		for dx in [4, 5]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles.erase(Vector2i(col, ty))

	# torch_wall on each side of door
	for dx in [3, 6]:
		var col: int = local_anchor + dx
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ground_y - 3)] = "torch_wall"

	# Interior: anvil, furnace, crafting_table, 2 chests on back wall (dx 1, 2, 6, 8)
	var items: Array = [
		[1, "anvil"], [3, "furnace"], [6, "crafting_table"], [7, "chest"], [8, "chest"]
	]
	for item in items:
		var col: int = local_anchor + item[0]
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ground_y - 2)] = item[1]

	# Stone chimney above roof right side (dx 8, rows 7..9)
	for row in range(7, 10):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		var col: int = local_anchor + 8
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ty)] = "stone_brick"


## _place_library — 12 wide × 10 tall brick building lined with bookshelves.
static func _place_library(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 12 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 6]

	# Flatten ground
	for dx in range(12):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		var col_y := heightmap[col]
		while col_y > ground_y:
			tiles[Vector2i(col, col_y - 1)] = "dirt"
			col_y -= 1

	# Plank floor
	for dx in range(12):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		tiles[Vector2i(col, ground_y - 1)] = "planks_oak"

	# Brick walls + planks_dark_oak roof
	for row in range(1, 10):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		for dx in range(12):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			if row == 9:
				tiles[Vector2i(col, ty)] = "planks_dark_oak"
			elif dx == 0 or dx == 11:
				tiles[Vector2i(col, ty)] = "brick"
			else:
				tiles.erase(Vector2i(col, ty))

	# Bookshelf lining on interior walls (rows 2..7 at dx 1 and dx 10)
	for row in range(2, 8):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		for dx in [1, 10]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "bookshelf"

	# 4 glass windows per side (rows 4,5 at dx 2,3,8,9)
	for row in [4, 5]:
		var ty: int = ground_y - 1 - row
		if ty < 0:
			continue
		for win_dx in [2, 3, 8, 9]:
			var col: int = local_anchor + win_dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "window_glass"

	# Door opening (rows 1,2,3 at dx 5,6)
	for row in [1, 2, 3]:
		var ty: int = ground_y - 1 - row
		if ty < 0:
			continue
		for dx in [5, 6]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles.erase(Vector2i(col, ty))

	# Crafting table center
	var ct_col: int = local_anchor + 6
	if ct_col >= 0 and ct_col < GameData.CHUNK_WIDTH:
		tiles[Vector2i(ct_col, ground_y - 2)] = "crafting_table"

	# Torch on ceiling beam (row 8)
	var torch_col: int = local_anchor + 5
	var torch_ty: int = ground_y - 9
	if torch_ty >= 0 and torch_col >= 0 and torch_col < GameData.CHUNK_WIDTH:
		tiles[Vector2i(torch_col, torch_ty)] = "torch"


## _place_underground_bunker — 14 wide × 6 tall stone_brick bunker buried 3 tiles below surface.
## Visible entry is a 2-wide shaft from the surface down to the structure.
static func _place_underground_bunker(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 14 >= GameData.CHUNK_WIDTH:
		return

	var surface_y: int = heightmap[local_anchor + 7]
	# Bunker top starts 3 tiles below surface
	var bunker_top_y: int = surface_y + 3
	var bunker_bot_y: int = bunker_top_y + 6

	# Build bunker shell: ceiling + floor + side walls
	for row in range(7):
		var ty: int = bunker_top_y + row
		if ty < 0:
			continue
		for dx in range(14):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			if row == 0 or row == 6:
				# Ceiling and floor: cobblestone
				tiles[Vector2i(col, ty)] = "cobblestone"
			elif dx == 0 or dx == 13:
				# Side walls: stone_brick
				tiles[Vector2i(col, ty)] = "stone_brick"
			else:
				# Interior: clear air
				tiles.erase(Vector2i(col, ty))

	# Interior items: chest, barrel, crafting_table, campfire
	var interior_items: Array = [
		[2, "chest"], [4, "barrel"], [7, "crafting_table"], [10, "campfire"]
	]
	for item in interior_items:
		var col: int = local_anchor + item[0]
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, bunker_top_y + 5)] = item[1]

	# Entrance shaft: 2-wide (dx 6,7) from surface down to bunker top
	var shaft_left: int = local_anchor + 6
	var shaft_right: int = local_anchor + 7
	for ty in range(surface_y - 1, bunker_top_y + 1):
		if ty < 0:
			continue
		for col in [shaft_left, shaft_right]:
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles.erase(Vector2i(col, ty))

	# Torch inside, on bunker ceiling near entrance
	var torch_col: int = local_anchor + 8
	if torch_col >= 0 and torch_col < GameData.CHUNK_WIDTH:
		tiles[Vector2i(torch_col, bunker_top_y + 1)] = "torch"


## _place_watchtower — 3 wide × 20 tall stone_brick tower, open at base.
## Battlements at top, torch at top level, chest at mid-level.
static func _place_watchtower(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 3 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 1]

	# Walls (20 rows, only left and right columns — open interior)
	for row in range(20):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		for dx in [0, 2]:
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, ty)] = "stone_brick"
		# Clear interior column
		var interior: int = local_anchor + 1
		if interior >= 0 and interior < GameData.CHUNK_WIDTH:
			tiles.erase(Vector2i(interior, ty))

	# Battlements at top (alternating on top row)
	var top_y: int = ground_y - 21
	if top_y >= 0:
		for dx in [0, 2]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, top_y)] = "stone_brick"

	# Torch at top level
	var torch_ty: int = ground_y - 20
	var torch_col: int = local_anchor + 1
	if torch_ty >= 0 and torch_col >= 0 and torch_col < GameData.CHUNK_WIDTH:
		tiles[Vector2i(torch_col, torch_ty)] = "torch"

	# Chest at mid-level (row 10)
	var chest_ty: int = ground_y - 10
	if chest_ty >= 0 and torch_col >= 0 and torch_col < GameData.CHUNK_WIDTH:
		tiles[Vector2i(torch_col, chest_ty)] = "chest"


## _place_market_stall — 6 wide × 3 tall open-air stall with corner posts and roof.
static func _place_market_stall(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 6 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 3]

	# Roof row (planks_birch across all 6 columns)
	var roof_y: int = ground_y - 3
	if roof_y >= 0:
		for dx in range(6):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			tiles[Vector2i(col, roof_y)] = "planks_birch"

	# Corner posts (planks_oak): dx 0 and dx 5, rows 1 and 2
	for row in [1, 2]:
		var ty: int = ground_y - row
		if ty < 0:
			continue
		for dx in [0, 5]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "planks_oak"
		# Clear interior
		for dx in range(1, 5):
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles.erase(Vector2i(col, ty))

	# Interior items on ground level (row 0 = ground_y - 1)
	var stall_items: Array = [[1, "barrel"], [3, "chest"], [4, "hay_bale"]]
	for item in stall_items:
		var col: int = local_anchor + item[0]
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ground_y - 1)] = item[1]

	# Torch on each corner post (top of post, at roof level)
	if roof_y >= 0:
		for dx in [0, 5]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, roof_y - 1)] = "torch"


## _place_graveyard — 16 wide fenced area with headstones, mushrooms, campfire.
static func _place_graveyard(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 16 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 8]

	# Outer fence ring (fence_stone_wall), 2-wide entrance gap at dx 7,8
	for dx in range(16):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		if dx == 7 or dx == 8:
			# Entrance gap — clear any existing tile
			tiles.erase(Vector2i(col, ground_y - 1))
		else:
			tiles[Vector2i(col, ground_y - 1)] = "fence_stone_wall"

	# 4–6 fence_wood "headstones" placed randomly inside (dx 2..13)
	var headstone_count: int = rng.randi_range(4, 6)
	for _i in range(headstone_count):
		var hx: int = local_anchor + 2 + (rng.randi() % 12)
		if hx >= 0 and hx < GameData.CHUNK_WIDTH:
			tiles[Vector2i(hx, ground_y - 2)] = "fence_wood"

	# Mushrooms scattered inside
	for dx in range(2, 14):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		if rng.randf() < 0.15:
			var shroom: String = "mushroom_red" if rng.randf() < 0.5 else "mushroom_brown"
			tiles[Vector2i(col, ground_y - 2)] = shroom

	# Campfire in center
	var center_col: int = local_anchor + 8
	if center_col >= 0 and center_col < GameData.CHUNK_WIDTH:
		tiles[Vector2i(center_col, ground_y - 2)] = "campfire"

	# Cobblestone path from entrance (dx 7,8) going inward 4 tiles
	for depth in range(1, 5):
		for dx in [7, 8]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ground_y - 1 - depth)] = "cobblestone"


## _place_snow_cabin — 10 wide × 7 tall log_pine cabin with snow on roof.
static func _place_snow_cabin(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 10 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 5]

	# Flatten ground
	for dx in range(10):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		var col_y := heightmap[col]
		while col_y > ground_y:
			tiles[Vector2i(col, col_y - 1)] = "dirt"
			col_y -= 1

	# Spruce floor
	for dx in range(10):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		tiles[Vector2i(col, ground_y - 1)] = "planks_spruce"

	# Log_pine walls + planks_spruce roof (7 rows)
	for row in range(1, 7):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		for dx in range(10):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			if row == 6:
				tiles[Vector2i(col, ty)] = "planks_spruce"
			elif dx == 0 or dx == 9:
				tiles[Vector2i(col, ty)] = "log_pine"
			else:
				tiles.erase(Vector2i(col, ty))

	# Snow row on top of roof
	var snow_y: int = ground_y - 8
	if snow_y >= 0:
		for dx in range(10):
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, snow_y)] = "snow"

	# Door opening (rows 1,2 at dx 4,5)
	for row in [1, 2]:
		var ty: int = ground_y - 1 - row
		if ty < 0:
			continue
		for dx in [4, 5]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles.erase(Vector2i(col, ty))

	# Interior: bed, furnace, chest, torch
	var cabin_items: Array = [[2, "bed"], [7, "furnace"], [8, "chest"]]
	for item in cabin_items:
		var col: int = local_anchor + item[0]
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ground_y - 2)] = item[1]

	var torch_col: int = local_anchor + 5
	var torch_ty: int = ground_y - 5
	if torch_ty >= 0 and torch_col >= 0 and torch_col < GameData.CHUNK_WIDTH:
		tiles[Vector2i(torch_col, torch_ty)] = "torch"


## _place_desert_outpost — 8 wide × 6 tall sandstone outpost with pillars at door.
static func _place_desert_outpost(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 8 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 4]

	# Sand floor
	for dx in range(8):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		tiles[Vector2i(col, ground_y - 1)] = "sandstone"

	# Sandstone walls + sandstone_smooth roof (6 rows)
	for row in range(1, 6):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		for dx in range(8):
			var col: int = local_anchor + dx
			if col < 0 or col >= GameData.CHUNK_WIDTH:
				continue
			if row == 5:
				tiles[Vector2i(col, ty)] = "sandstone_smooth"
			elif dx == 0 or dx == 7:
				tiles[Vector2i(col, ty)] = "sandstone"
			else:
				tiles.erase(Vector2i(col, ty))

	# sandstone_chiseled decorations on walls (mid height, rows 3)
	var deco_ty: int = ground_y - 4
	if deco_ty >= 0:
		for dx in [2, 5]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, deco_ty)] = "sandstone_chiseled"

	# Door opening (rows 1,2,3 at dx 3,4)
	for row in [1, 2, 3]:
		var ty: int = ground_y - 1 - row
		if ty < 0:
			continue
		for dx in [3, 4]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles.erase(Vector2i(col, ty))

	# Pillar columns flanking doorway (dx 2 and dx 5, rows 1..4)
	for row in range(1, 5):
		var ty: int = ground_y - 1 - row
		if ty < 0:
			break
		for dx in [2, 5]:
			var col: int = local_anchor + dx
			if col >= 0 and col < GameData.CHUNK_WIDTH:
				tiles[Vector2i(col, ty)] = "pillar"

	# Interior: chest, barrel, campfire
	var outpost_items: Array = [[1, "chest"], [6, "barrel"], [4, "campfire"]]
	for item in outpost_items:
		var col: int = local_anchor + item[0]
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ground_y - 2)] = item[1]


## _place_mine_entrance — full abandoned mine with shaft, tunnels, supports, loot.
## Entrance frame at surface; main shaft goes ~40 tiles deep;
## horizontal tunnels branch at depths 12 and 28; a lower chamber at depth 38.
## "Rails" are represented as slab_stone on tunnel floors.
static func _place_mine_entrance(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	var cw: int = GameData.CHUNK_WIDTH
	if local_anchor < 2 or local_anchor + 8 >= cw:
		return

	var ground_y: int = heightmap[local_anchor + 3]

	# Helper lambdas
	var _s := func(x: int, y: int, id: String) -> void:
		if x >= 0 and x < cw and y >= 0 and y < GameData.CHUNK_HEIGHT:
			tiles[Vector2i(x, y)] = id
	var _e := func(x: int, y: int) -> void:
		if x >= 0 and x < cw: tiles.erase(Vector2i(x, y))

	# Surface structure: mine office shack (8 wide, 5 tall) left of entrance
	var shack_x: int = local_anchor - 2
	if shack_x >= 0:
		for dx in range(8):
			_s.call(shack_x + dx, ground_y - 1, "planks_dark_oak")
		for row in range(1, 5):
			var ty: int = ground_y - 1 - row
			if ty < 0: break
			for dx in range(8):
				if dx == 0 or dx == 7 or row == 4:
					_s.call(shack_x + dx, ty, "planks_dark_oak")
				else:
					_e.call(shack_x + dx, ty)
		# Shack door + window
		_e.call(shack_x + 3, ground_y - 2); _e.call(shack_x + 3, ground_y - 3)
		_s.call(shack_x + 5, ground_y - 3, "window_glass")
		# Interior items
		_s.call(shack_x + 1, ground_y - 2, "chest")
		_s.call(shack_x + 2, ground_y - 2, "barrel")
		_s.call(shack_x + 5, ground_y - 2, "crafting_table")
		_s.call(shack_x + 6, ground_y - 2, "furnace")
		_s.call(shack_x + 4, ground_y - 3, "torch_wall")

	# Entrance frame: 4-wide log arch with torch_wall
	var ex: int = local_anchor + 2
	for row in range(1, 4):
		var ty: int = ground_y - row
		if ty < 0: break
		_s.call(ex, ty, "log_oak"); _s.call(ex + 3, ty, "log_oak")
	var arch_ty: int = ground_y - 3
	if arch_ty >= 0:
		for dx in range(4): _s.call(ex + dx, arch_ty, "log_oak")
	_s.call(ex + 1, ground_y - 2, "torch_wall")
	_s.call(ex + 2, ground_y - 2, "torch_wall")

	# Main vertical shaft (4 wide: ex..ex+3, going 42 tiles down)
	var shaft_depth: int = 42
	var sl: int = ex + 1; var sr: int = ex + 2
	for depth in range(shaft_depth):
		var ty: int = ground_y + depth
		if ty < 0: continue
		_e.call(sl, ty); _e.call(sr, ty)
		# Shaft walls reinforced
		_s.call(ex, ty, "stone_brick"); _s.call(ex + 3, ty, "stone_brick")
		# Support beams every 6 rows
		if depth > 0 and depth % 6 == 0:
			_s.call(sl, ty, "planks_dark_oak")
			_s.call(sr, ty, "planks_dark_oak")
		# Ladder on left wall
		if depth % 6 != 0:
			_s.call(ex, ty, "ladder")

	# Torches every 10 rows
	for depth in [8, 18, 28, 38]:
		var ty: int = ground_y + depth
		_s.call(ex, ty, "torch_wall")

	# LEFT TUNNEL at depth 12 (goes 10 tiles left, 3 wide)
	var lt_y: int = ground_y + 12
	for tdx in range(1, 11):
		var tx: int = ex - tdx
		if tx < 0: break
		_e.call(tx, lt_y); _e.call(tx, lt_y + 1)
		_s.call(tx, lt_y - 1, "stone")  # ceiling
		_s.call(tx, lt_y + 2, "stone")  # floor
		# Rails (slab_stone on floor)
		_s.call(tx, lt_y + 2, "slab_stone")
		# Support beams every 4 tiles
		if tdx % 4 == 0:
			_s.call(tx, lt_y - 1, "planks_dark_oak")
			_s.call(tx, lt_y + 1, "planks_dark_oak")
		# Ore veins on walls
		if rng.randf() < 0.25:
			_s.call(tx, lt_y + 2, "iron_ore")
	# Chest at end of left tunnel
	var lt_end: int = ex - 10
	if lt_end >= 0: _s.call(lt_end, lt_y, "chest")
	# Torch
	if ex - 5 >= 0: _s.call(ex - 5, lt_y, "torch_wall")
	# Cave-in (gravel collapse) at end
	for cix in [lt_end + 1, lt_end + 2]:
		if cix >= 0:
			_s.call(cix, lt_y - 1, "gravel")
			_s.call(cix, lt_y, "gravel")

	# RIGHT TUNNEL at depth 28 (goes 10 tiles right, 3 wide)
	var rt_y: int = ground_y + 28
	for tdx in range(1, 11):
		var tx: int = ex + 4 + tdx - 1
		if tx >= cw: break
		_e.call(tx, rt_y); _e.call(tx, rt_y + 1)
		_s.call(tx, rt_y - 1, "stone")
		_s.call(tx, rt_y + 2, "stone")
		_s.call(tx, rt_y + 2, "slab_stone")
		if tdx % 4 == 0:
			_s.call(tx, rt_y - 1, "planks_dark_oak")
		if rng.randf() < 0.30:
			var ore_id: String = "coal_ore" if rng.randf() < 0.5 else "copper_ore"
			_s.call(tx, rt_y + 2, ore_id)
	# Chest + torch in right tunnel
	var rt_mid: int = ex + 7
	if rt_mid < cw:
		_s.call(rt_mid, rt_y, "chest")
		_s.call(rt_mid - 2, rt_y, "torch_wall")
	# Minecart "derailed" at tunnel end
	var rt_end: int = ex + 13
	if rt_end < cw:
		_s.call(rt_end, rt_y + 1, "slab_stone")
		_s.call(rt_end, rt_y,     "gravel")

	# LOWER CHAMBER at depth 38 (8 wide × 4 tall)
	var lc_y: int = ground_y + 38
	var lc_x: int = ex - 3
	for dx in range(8):
		var tx: int = lc_x + dx
		if tx < 0 or tx >= cw: continue
		for dy in range(4):
			var ty: int = lc_y + dy
			if ty < 0: continue
			var is_wall: bool = (dy == 0 or dy == 3 or dx == 0 or dx == 7)
			if is_wall:
				_s.call(tx, ty, "stone_brick")
			else:
				_e.call(tx, ty)
	# Lower chamber loot: 3 chests + glowstone lights
	_s.call(lc_x + 1, lc_y + 2, "chest")
	_s.call(lc_x + 3, lc_y + 2, "chest")
	_s.call(lc_x + 6, lc_y + 2, "chest")
	_s.call(lc_x + 4, lc_y + 1, "glowstone")
	_s.call(lc_x + 2, lc_y + 1, "torch_wall")


## _place_abandoned_farm — 18 wide surface farm with partial fence, hay, collapsed barn section.
static func _place_abandoned_farm(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:

	if local_anchor < 0 or local_anchor + 18 >= GameData.CHUNK_WIDTH:
		return

	var ground_y: int = heightmap[local_anchor + 9]

	# Partial fence border (50% chance each post exists — abandoned look)
	for dx in range(18):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		# Only place fence on perimeter positions
		if dx == 0 or dx == 17:
			if rng.randf() < 0.60:
				tiles[Vector2i(col, ground_y - 1)] = "fence_wood"
		elif dx % 3 == 0:
			if rng.randf() < 0.50:
				tiles[Vector2i(col, ground_y - 1)] = "fence_wood"

	# Hay bale clusters (3–5 hay bales scattered in left half)
	var hay_count: int = rng.randi_range(3, 5)
	for _i in range(hay_count):
		var hx: int = local_anchor + 2 + (rng.randi() % 8)
		if hx >= 0 and hx < GameData.CHUNK_WIDTH:
			tiles[Vector2i(hx, ground_y - 1)] = "hay_bale"

	# Tall grass scattered around
	for dx in range(1, 17):
		var col: int = local_anchor + dx
		if col < 0 or col >= GameData.CHUNK_WIDTH:
			continue
		if rng.randf() < 0.25:
			if not tiles.has(Vector2i(col, ground_y - 1)):
				tiles[Vector2i(col, ground_y - 1)] = "tall_grass"

	# Collapsed barn section (right side): horizontal line of 4 log_oak starting at dx 12
	for dx in range(4):
		var col: int = local_anchor + 12 + dx
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ground_y - 1)] = "log_oak"
	# A couple logs tilted — one row up
	for dx in [12, 13]:
		var col: int = local_anchor + dx
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			tiles[Vector2i(col, ground_y - 2)] = "log_oak"

	# Barrel and chest inside (near right side)
	for pair in [[10, "barrel"], [15, "chest"]]:
		var col: int = local_anchor + pair[0]
		if col >= 0 and col < GameData.CHUNK_WIDTH:
			if not tiles.has(Vector2i(col, ground_y - 1)):
				tiles[Vector2i(col, ground_y - 1)] = pair[1]


## _place_giant_mushroom — mushroom stem + wide cap for MUSHROOM biome decoration.
static func _place_giant_mushroom(tiles: Dictionary, local_x: int, surface_y: int,
		rng: RandomNumberGenerator) -> void:
	var trunk_h: int = rng.randi_range(4, 7)
	var cap_id: String = "mushroom_red" if rng.randf() < 0.5 else "mushroom_brown"
	# Stem (reuse log_oak tile as mushroom stem)
	for i in range(trunk_h):
		var ty: int = surface_y - 1 - i
		if ty < 0: break
		tiles[Vector2i(local_x, ty)] = "log_oak"
	# Wide flat cap (5 tiles wide, 2 rows tall) at top of stem
	var cap_y: int = surface_y - trunk_h
	for dy in range(2):
		for dx in range(-2, 3):
			var lx: int = local_x + dx
			if lx < 0 or lx >= GameData.CHUNK_WIDTH: continue
			var ly: int = cap_y - dy
			if ly < 0: continue
			if not tiles.has(Vector2i(lx, ly)):
				tiles[Vector2i(lx, ly)] = cap_id


## _place_dungeon — multi-room underground dungeon with corridors, prison, loot.
## Main hall 20×8, left corridor → prison cells, right corridor → treasure vault.
## All rooms are 15+ tiles underground.
static func _place_dungeon(tiles: Dictionary, heightmap: Array[int],
		local_anchor: int, rng: RandomNumberGenerator) -> void:
	var cw: int = GameData.CHUNK_WIDTH
	if local_anchor < 2 or local_anchor + 20 >= cw:
		return
	var ground_y: int = heightmap[clampi(local_anchor + 10, 0, cw - 1)]
	var top_y: int = ground_y + 15  # 15 tiles below surface

	var _s := func(x: int, y: int, id: String) -> void:
		if x >= 0 and x < cw and y >= 0 and y < GameData.CHUNK_HEIGHT:
			tiles[Vector2i(x, y)] = id
	var _e := func(x: int, y: int) -> void:
		if x >= 0 and x < cw: tiles.erase(Vector2i(x, y))
	var _room := func(rx: int, ry: int, rw: int, rh: int, wall_id: String, floor_id: String) -> void:
		for row in range(rh):
			for dx in range(rw):
				var col: int = rx + dx; var ty: int = ry + row
				if col < 0 or col >= cw or ty < 0: continue
				if row == 0 or row == rh - 1 or dx == 0 or dx == rw - 1:
					tiles[Vector2i(col, ty)] = wall_id
				elif row == rh - 2:
					tiles[Vector2i(col, ty)] = floor_id
				else:
					tiles.erase(Vector2i(col, ty))

	# Main hall (20 wide × 8 tall)
	_room.call(local_anchor, top_y, 20, 8, "stone_brick", "mossy_stone_brick")
	# Glowstone lights on ceiling
	for lx in [local_anchor + 4, local_anchor + 10, local_anchor + 15]:
		_s.call(lx, top_y + 1, "glowstone")
	# Main hall: tables, barrels, chests
	_s.call(local_anchor + 2, top_y + 5, "chest")
	_s.call(local_anchor + 8, top_y + 5, "crafting_table")
	_s.call(local_anchor + 12, top_y + 5, "chest")
	_s.call(local_anchor + 17, top_y + 5, "barrel")
	# Torches on walls
	for tx in [local_anchor + 3, local_anchor + 16]:
		_s.call(tx, top_y + 2, "torch_wall")

	# LEFT CORRIDOR → Prison (descends 6 tiles left)
	var lc_x: int = local_anchor - 1
	var lc_y: int = top_y
	for dx in range(8):
		var cx: int = lc_x - dx
		if cx < 0 or cx >= cw: break
		_e.call(cx, lc_y + 2); _e.call(cx, lc_y + 3)
		_s.call(cx, lc_y + 1, "stone_brick")
		_s.call(cx, lc_y + 4, "cobblestone")
	# Prison cells (3×4 each with iron_bars door)
	for cell in range(2):
		var cx: int = local_anchor - 3 - cell * 4
		if cx < 2 or cx + 3 >= cw: continue
		_room.call(cx - 3, lc_y, 4, 6, "stone_brick", "cobblestone")
		_s.call(cx - 1, lc_y + 3, "iron_bars")  # cell door
		_s.call(cx - 1, lc_y + 4, "iron_bars")
		# Prisoner loot
		_s.call(cx - 2, lc_y + 4, "chest")
		_s.call(cx - 3, lc_y + 2, "torch_wall")

	# RIGHT CORRIDOR → Treasure vault
	var rc_x: int = local_anchor + 20
	var rc_y: int = top_y
	for dx in range(8):
		var cx: int = rc_x + dx
		if cx < 0 or cx >= cw: break
		_e.call(cx, rc_y + 2); _e.call(cx, rc_y + 3)
		_s.call(cx, rc_y + 1, "stone_brick")
		_s.call(cx, rc_y + 4, "stone_brick")
	# Treasure vault at end (8×6)
	var vx: int = local_anchor + 22
	if vx + 8 < cw:
		_room.call(vx, rc_y, 8, 6, "stone_brick", "mossy_stone_brick")
		# Multiple chests with loot
		for ci in range(4):
			_s.call(vx + 1 + ci * 2, rc_y + 4, "chest")
		# Boss loot chest in center
		_s.call(vx + 3, rc_y + 4, "chest")
		_s.call(vx + 4, rc_y + 4, "chest")
		# Glowstone + campfire (atmosphere)
		_s.call(vx + 3, rc_y + 1, "glowstone")
		_s.call(vx + 3, rc_y + 3, "campfire")
		# Iron bars on entrance
		_s.call(vx,     rc_y + 2, "iron_bars")
		_s.call(vx,     rc_y + 3, "iron_bars")

	# Entry shaft from surface (2-wide, descending to main hall)
	var sx: int = local_anchor + 9
	for d in range(ground_y, top_y + 1):
		_e.call(sx, d)
		_e.call(sx + 1, d)
	# Ladder down one side
	for d in range(ground_y, top_y + 1):
		_s.call(sx, d, "ladder")


## _place_castle — full-chunk epic ground castle. Outer walls span whole chunk width.
## 4 corner towers, central keep with throne room, courtyard, underground dungeon.
static func _place_castle(tiles: Dictionary, heightmap: Array[int],
		rng: RandomNumberGenerator) -> void:
	var cw: int = GameData.CHUNK_WIDTH
	var ground_y: int = heightmap[cw / 2]
	# Flatten base
	for dx in range(cw):
		if heightmap[dx] > ground_y:
			for fy in range(ground_y, heightmap[dx]):
				tiles[Vector2i(dx, fy)] = "stone_brick"
			heightmap[dx] = ground_y

	var _s := func(x: int, y: int, id: String) -> void:
		if x >= 0 and x < cw and y >= 0 and y < GameData.CHUNK_HEIGHT:
			tiles[Vector2i(x, y)] = id
	var _e := func(x: int, y: int) -> void:
		if x >= 0 and x < cw: tiles.erase(Vector2i(x, y))
	var _row := func(r: int, x0: int, x1: int, id: String) -> void:
		for x in range(x0, x1 + 1):
			if x >= 0 and x < cw: tiles[Vector2i(x, r)] = id

	const WALL_H: int = 16
	const WALL_T: int = 2  # wall thickness

	# ── OUTER WALLS ─────────────────────────────────────────────────────────────
	for row in range(WALL_H):
		var ty: int = ground_y - 1 - row
		if ty < 0: break
		for t in range(WALL_T):
			_s.call(t,          ty, "stone_brick")
			_s.call(cw - 1 - t, ty, "stone_brick")
	# Top of outer wall
	_row.call(ground_y - WALL_H - 1, 0, cw - 1, "stone_brick")
	# Battlements on outer wall
	for dx in range(0, cw):
		if dx % 2 == 0:
			for br in [0, 1]:
				_s.call(dx, ground_y - WALL_H - 2 - br, "stone_brick")
	# Iron portcullis gate (centre 4 wide, 5 tall)
	var gate_x: int = cw / 2 - 2
	for row in range(5):
		for dx in range(4):
			_e.call(gate_x + dx, ground_y - 1 - row)
	# Portcullis iron bars
	for row in [3, 4]:
		for dx in range(4):
			_s.call(gate_x + dx, ground_y - 1 - row, "iron_bars")

	# ── CORNER TOWERS (4, each 6 wide × 24 tall) ─────────────────────────────
	const TW: int = 6
	const TH: int = 24
	var tower_xs: Array[int] = [0, cw - TW]
	for tx in tower_xs:
		for row in range(TH):
			var ty: int = ground_y - 1 - row
			if ty < 0: break
			for dx in range(TW):
				var col: int = tx + dx
				if col < 0 or col >= cw: continue
				if dx == 0 or dx == TW - 1 or row == 0:
					tiles[Vector2i(col, ty)] = "stone_brick"
				else:
					tiles.erase(Vector2i(col, ty))
		# Tower floor (planks) at rows 8 and 16
		for floor_row in [7, 15]:
			var ty: int = ground_y - 1 - floor_row
			if ty < 0: continue
			_row.call(ty, tx + 1, tx + TW - 2, "planks_dark_oak")
		# Tower battlements
		for dx in range(TW):
			if dx % 2 == 0:
				var col: int = tx + dx
				if col >= 0 and col < cw:
					for br in range(3):
						_s.call(col, ground_y - TH - 1 - br, "stone_brick")
		# Tower windows (arrow slits)
		for win_row in [4, 12, 20]:
			var ty: int = ground_y - 1 - win_row
			if ty < 0: continue
			_e.call(tx,          ty); _e.call(tx + TW - 1, ty)
		# Tower chest on floor 2
		var ty: int = ground_y - 1 - 15
		if ty >= 0: _s.call(tx + 2, ty, "chest")
		# Tower torch
		for tr in [6, 14]:
			var tty: int = ground_y - 1 - tr
			if tty >= 0: _s.call(tx + 2, tty, "torch_wall")

	# ── INNER WALLS (divide courtyard from wings) ─────────────────────────────
	var inner_x0: int = TW
	var inner_x1: int = cw - TW - 1
	for row in range(WALL_H - 2):
		var ty: int = ground_y - 1 - row
		if ty < 0: break
		for t in range(WALL_T):
			_s.call(inner_x0 + t, ty, "stone_brick")
			_s.call(inner_x1 - t, ty, "stone_brick")
	# Inner wall gates (2-wide, 4-tall, one each side)
	for ix in [inner_x0, inner_x1 - 1]:
		for row in range(1, 5):
			_e.call(ix, ground_y - 1 - row)
			_e.call(ix + 1, ground_y - 1 - row)

	# Cobblestone courtyard floor
	var cy_x0: int = inner_x0 + WALL_T
	var cy_x1: int = inner_x1 - WALL_T - 1
	_row.call(ground_y - 1, cy_x0, cy_x1, "cobblestone")

	# Courtyard decorations
	var mid_x: int = cw / 2
	_s.call(mid_x - 1, ground_y - 2, "campfire")
	_s.call(mid_x + 1, ground_y - 2, "barrel")
	_s.call(cy_x0 + 1, ground_y - 2, "torch_wall")
	_s.call(cy_x1 - 1, ground_y - 2, "torch_wall")

	# ── CENTRAL KEEP (10 wide × 32 tall, centred) ────────────────────────────
	const KW: int = 10
	const KH: int = 30
	var kx: int = mid_x - KW / 2
	for row in range(KH):
		var ty: int = ground_y - 1 - row
		if ty < 0: break
		for dx in range(KW):
			var col: int = kx + dx
			if col < 0 or col >= cw: continue
			if dx == 0 or dx == KW - 1 or row == 0:
				tiles[Vector2i(col, ty)] = "stone_brick"
			else:
				tiles.erase(Vector2i(col, ty))
	# Keep floors (at rows 8, 16, 24)
	for fr in [7, 15, 23]:
		var ty: int = ground_y - 1 - fr
		if ty < 0: continue
		_row.call(ty, kx + 1, kx + KW - 2, "planks_dark_oak")
	# Keep windows
	for wr in [4, 12, 20]:
		var ty: int = ground_y - 1 - wr
		if ty < 0: continue
		_e.call(kx, ty); _e.call(kx, ty - 1)
		_e.call(kx + KW - 1, ty); _e.call(kx + KW - 1, ty - 1)
	# Keep battlements + spire base
	for dx in range(KW):
		var col: int = kx + dx
		if col < 0 or col >= cw: continue
		if dx % 2 == 0:
			for br in range(4):
				_s.call(col, ground_y - KH - 1 - br, "stone_brick")
	# Spire (4 wide × 10 tall, tapering)
	var spx: int = mid_x - 2
	for sr in range(10):
		var ty: int = ground_y - KH - 5 - sr
		if ty < 0: break
		var half: int = maxi(1, 2 - sr / 3)
		for dx in range(-half, half + 1):
			_s.call(spx + 2 + dx, ty, "stone_brick")

	# Keep interior: throne room (ground floor)
	_s.call(mid_x, ground_y - 2, "chest"); _s.call(mid_x - 1, ground_y - 2, "chest")
	_s.call(kx + 1, ground_y - 2, "torch_wall"); _s.call(kx + KW - 2, ground_y - 2, "torch_wall")
	_s.call(mid_x - 1, ground_y - 8, "bookshelf"); _s.call(mid_x + 1, ground_y - 8, "bookshelf")
	_s.call(mid_x, ground_y - 16, "chest")  # second floor storage

	# Keep gate from courtyard (3-wide, 4-tall at base centre)
	var kg: int = mid_x - 1
	for row in range(1, 5):
		for dx in range(3): _e.call(kg + dx, ground_y - 1 - row)

	# ── UNDERGROUND DUNGEON (below castle, 4 rooms) ──────────────────────────
	var dun_y: int = ground_y + 8
	# Main dungeon hall (full width, 5 tall)
	_row.call(dun_y,     0, cw - 1, "stone_brick")
	_row.call(dun_y + 4, 0, cw - 1, "mossy_stone_brick")
	for row in range(1, 4):
		_row.call(dun_y + row, 0, cw - 1, "stone_brick")
		for dx in range(2, cw - 2):
			_e.call(dx, dun_y + row)
	# Side cells (iron bars)
	for cx in [4, 12, 20, 28]:
		if cx + 3 >= cw: continue
		for row in [1, 2]: _s.call(cx, dun_y + row, "iron_bars")
		_s.call(cx, dun_y + 3, "chest")
	# Dungeon torches
	for tx in [2, 10, 18, 26]:
		if tx < cw: _s.call(tx, dun_y + 1, "torch_wall")
	# Staircase shaft down to dungeon (from keep)
	for d in range(ground_y, dun_y + 1):
		_e.call(mid_x, d); _e.call(mid_x + 1, d)
	# Ladder
	for d in range(ground_y, dun_y + 4):
		_s.call(mid_x, d, "ladder")


## _place_city — rare massive multi-building settlement, spanning 3 chunks.
## slot 0 = left district (market, inn, homes), slot 1 = town square + hall + church,
## slot 2 = right district (library, blacksmith, houses).
## Called every ~200 chunks for plains biome chunks.
static func _place_city(tiles: Dictionary, heightmap: Array[int],
		slot: int, rng: RandomNumberGenerator) -> void:
	var cw: int = GameData.CHUNK_WIDTH

	var _s := func(x: int, y: int, id: String) -> void:
		if x >= 0 and x < cw and y >= 0 and y < GameData.CHUNK_HEIGHT:
			tiles[Vector2i(x, y)] = id
	var _e := func(x: int, y: int) -> void:
		if x >= 0 and x < cw: tiles.erase(Vector2i(x, y))

	# Flatten entire chunk to min height
	var ground_y: int = 999999
	for i in cw:
		if heightmap[i] < ground_y: ground_y = heightmap[i]
	if ground_y == 999999: ground_y = 90
	for dx in range(cw):
		if heightmap[dx] > ground_y:
			for fy in range(ground_y, heightmap[dx]):
				tiles[Vector2i(dx, fy)] = "stone_brick"
			heightmap[dx] = ground_y

	# City-wide cobblestone road + stone wall border
	for dx in range(cw):
		_s.call(dx, ground_y - 1, "cobblestone")
		_s.call(dx, ground_y - 18, "stone_brick")  # city wall top
	# City wall sides
	for row in range(1, 18):
		var ty: int = ground_y - row
		if ty < 0: break
		_s.call(0,      ty, "stone_brick")
		_s.call(cw - 1, ty, "stone_brick")

	# Helper: build a large brick 3-story building
	# bx=left edge, bw=width, bh=height (including roof)
	var _building := func(bx: int, bw: int, bh: int, wall: String, roof: String) -> void:
		var gy: int = ground_y
		# Floor
		for dx in range(bw): _s.call(bx + dx, gy - 2, wall)
		# Walls + floors
		for row in range(1, bh + 1):
			var ty: int = gy - 2 - row
			if ty < 0: break
			for dx in range(bw):
				if dx == 0 or dx == bw - 1 or row == bh:
					_s.call(bx + dx, ty, wall if row != bh else roof)
				elif row == bh / 3 or row == (bh * 2) / 3:
					_s.call(bx + dx, ty, "planks_dark_oak")
				else:
					_e.call(bx + dx, ty)
		# Windows (2 per floor per side)
		for fr in [2, 3, int(bh/3 + 2), int(bh/3 + 3), int(bh*2/3 + 2), int(bh*2/3 + 3)]:
			var ty: int = gy - 2 - fr
			if ty < 0: continue
			for dx in [2, 3, bw - 4, bw - 3]: _s.call(bx + dx, ty, "window_glass")
		# Door (center, 2 wide, 3 tall)
		var dox: int = bx + bw / 2 - 1
		for row in [1, 2, 3]:
			_e.call(dox, gy - 2 - row); _e.call(dox + 1, gy - 2 - row)
		# Torches
		_s.call(dox - 1, gy - 4, "torch_wall"); _s.call(dox + 2, gy - 4, "torch_wall")

	# Lamp post
	var _lamp := func(x: int) -> void:
		_s.call(x, ground_y - 2, "fence_wood"); _s.call(x, ground_y - 3, "fence_wood")
		_s.call(x, ground_y - 4, "torch")

	match slot:
		0:  # Left district: large inn + 2 homes
			# Large inn (full left side, 18 wide × 16 tall)
			_building.call(1, 18, 16, "brick", "planks_dark_oak")
			# Inn interior ground
			_s.call(2, ground_y - 3, "barrel"); _s.call(4, ground_y - 3, "chest")
			_s.call(14, ground_y - 3, "bookshelf"); _s.call(16, ground_y - 3, "barrel")
			# Beds upstairs
			for bxi in [2, 4, 13, 15]:
				_s.call(bxi, ground_y - 2 - int(16 / 3) - 1, "bed")
			# Chimney
			for r in range(16, 20): _s.call(16, ground_y - 2 - r, "stone_brick")
			# Market stall area (x=20..30)
			_building.call(20, 10, 5, "planks_oak", "planks_birch")
			_s.call(20, ground_y - 3, "barrel"); _s.call(22, ground_y - 3, "chest")
			_s.call(26, ground_y - 3, "anvil"); _s.call(28, ground_y - 3, "chest")
			# Lamp posts on road
			_lamp.call(19)

		1:  # Center: grand town hall + church spire
			# Town hall (full chunk, 28 wide × 18 tall, centred)
			var thx: int = 2; var thw: int = 28; var thh: int = 18
			_building.call(thx, thw, thh, "stone_brick", "planks_dark_oak")
			# Town hall: columns on facade
			for col_dx in [2, 3, thw - 4, thw - 3]:
				for row in range(1, thh):
					_s.call(thx + col_dx, ground_y - 2 - row, "pillar")
			# Town hall interior
			_s.call(thx + 4, ground_y - 3, "crafting_table"); _s.call(thx + 6, ground_y - 3, "chest")
			_s.call(thx + thw - 7, ground_y - 3, "bookshelf"); _s.call(thx + thw - 5, ground_y - 3, "chest")
			_s.call(thx + thw/2, ground_y - 3, "anvil")  # central workbench
			# Church spire above town hall centre
			var spx: int = thx + thw / 2 - 2
			for sr in range(12):
				var ty: int = ground_y - thh - 3 - sr
				if ty < 0: break
				var hw: int = maxi(1, 3 - sr / 3)
				for dx in range(-hw, hw + 1): _s.call(spx + 3 + dx, ty, "stone_brick")
			# Large windows in church section
			for row in [8, 9]:
				for dx in [5, 6, thw - 7, thw - 6]:
					_s.call(thx + dx, ground_y - 2 - row, "window_glass")
			# Torch poles in courtyard
			_lamp.call(0); _lamp.call(cw - 1)
			# Chests in upper chambers
			for ci in [thx + 5, thx + thw - 6]:
				_s.call(ci, ground_y - 2 - thh / 3 - 1, "chest")

		2:  # Right district: library + blacksmith + homes
			# Library (left side, 14 wide × 14 tall)
			_building.call(1, 14, 14, "brick", "planks_dark_oak")
			# Bookshelves inside
			for row in range(2, 12):
				_s.call(2, ground_y - 2 - row, "bookshelf")
				_s.call(12, ground_y - 2 - row, "bookshelf")
			_s.call(6, ground_y - 3, "crafting_table"); _s.call(8, ground_y - 3, "chest")
			# Blacksmith shop (right side, 12 wide × 10 tall)
			_building.call(17, 12, 10, "stone_brick", "planks_spruce")
			_s.call(18, ground_y - 3, "anvil"); _s.call(19, ground_y - 3, "furnace")
			_s.call(20, ground_y - 3, "furnace"); _s.call(24, ground_y - 3, "chest")
			_s.call(25, ground_y - 3, "chest"); _s.call(26, ground_y - 3, "crafting_table")
			# Blacksmith chimney
			for r in range(10, 14): _s.call(26, ground_y - 2 - r, "stone_brick")
			# Lamp posts
			_lamp.call(15); _lamp.call(16)
