@tool
class_name TileTextureGenerator
extends Node

# Tile atlas: 256x256 image, each tile is 16x16 pixels
# Atlas is 16 columns x 16 rows (only rows 0-2 used)
const TILE_SIZE := 16
const ATLAS_WIDTH := 256
const ATLAS_HEIGHT := 256

# Base colors keyed by tile id string
static var TILE_COLORS: Dictionary = {
	"dirt":            Color(0.545, 0.353, 0.169),
	"grass":           Color(0.545, 0.353, 0.169),
	"stone":           Color(0.502, 0.502, 0.502),
	"cobblestone":     Color(0.420, 0.420, 0.420),
	"sand":            Color(0.937, 0.855, 0.557),
	"gravel":          Color(0.588, 0.565, 0.533),
	"water":           Color(0.255, 0.412, 0.882),
	"lava":            Color(0.878, 0.345, 0.039),
	"bedrock":         Color(0.180, 0.180, 0.180),
	"snow":            Color(0.941, 0.973, 0.988),
	"ice":             Color(0.678, 0.847, 0.902),
	"clay":            Color(0.620, 0.631, 0.671),
	"log_oak":         Color(0.427, 0.318, 0.173),
	"log_birch":       Color(0.737, 0.706, 0.588),
	"log_pine":        Color(0.314, 0.220, 0.102),
	"leaves_oak":      Color(0.165, 0.506, 0.067),
	"leaves_birch":    Color(0.502, 0.686, 0.165),
	"leaves_pine":     Color(0.067, 0.337, 0.098),
	"planks_oak":      Color(0.698, 0.565, 0.325),
	"planks_birch":    Color(0.859, 0.808, 0.600),
	"wool":            Color(0.937, 0.937, 0.937),
	"torch":           Color(0.502, 0.322, 0.098),
	"campfire":        Color(0.400, 0.220, 0.071),
	"chest":           Color(0.588, 0.435, 0.188),
	"crafting_table":  Color(0.502, 0.357, 0.161),
	"furnace":         Color(0.420, 0.420, 0.420),
	"coal_ore":        Color(0.502, 0.502, 0.502),
	"iron_ore":        Color(0.502, 0.502, 0.502),
	"gold_ore":        Color(0.502, 0.502, 0.502),
	"diamond_ore":     Color(0.502, 0.502, 0.502),
	"emerald_ore":     Color(0.502, 0.502, 0.502),
	"ruby_ore":        Color(0.502, 0.502, 0.502),
	"snow_grass":      Color(0.545, 0.353, 0.169),
	"tall_grass":      Color(0.165, 0.506, 0.067),
	"cactus":          Color(0.173, 0.502, 0.102),
	"sapling_oak":     Color(0.180, 0.680, 0.180),
	"sapling_birch":   Color(0.600, 0.800, 0.280),
	"sapling_pine":    Color(0.100, 0.400, 0.120),
	"wheat_seeds":     Color(0.300, 0.700, 0.200),
	"wheat_crop":      Color(0.880, 0.750, 0.180),
	"bed":             Color(0.85, 0.20, 0.20),
	"crystal_gate":    Color(0.70, 0.95, 1.00),
	# new wood variants
	"log_spruce":      Color(0.220, 0.145, 0.065),
	"log_jungle":      Color(0.380, 0.290, 0.130),
	"leaves_spruce":   Color(0.090, 0.310, 0.080),
	"leaves_jungle":   Color(0.200, 0.600, 0.080),
	"planks_spruce":   Color(0.408, 0.290, 0.141),
	"planks_jungle":   Color(0.647, 0.459, 0.259),
	"planks_dark_oak": Color(0.259, 0.161, 0.071),
	# new utility blocks
	"torch_wall":      Color(0.502, 0.322, 0.098),
	"anvil":           Color(0.280, 0.280, 0.280),
	"workbench_stone": Color(0.502, 0.502, 0.502),
	"bookshelf":       Color(0.608, 0.490, 0.298),
	"barrel":          Color(0.510, 0.357, 0.180),
	"hay_bale":        Color(0.820, 0.710, 0.200),
	# new ores/resources
	"copper_ore":      Color(0.502, 0.502, 0.502),
	"tin_ore":         Color(0.502, 0.502, 0.502),
	"silver_ore":      Color(0.502, 0.502, 0.502),
	"copper_ingot":    Color(0.804, 0.498, 0.196),
	"silver_ingot":    Color(0.752, 0.752, 0.800),
	"quartz":          Color(0.941, 0.906, 0.878),
	"quartz_block":    Color(0.941, 0.906, 0.878),
	"obsidian":        Color(0.098, 0.055, 0.180),
	# stone/brick variants
	"stone_brick":          Color(0.420, 0.420, 0.420),
	"mossy_stone_brick":    Color(0.310, 0.420, 0.290),
	"cracked_stone_brick":  Color(0.380, 0.380, 0.380),
	"chiseled_stone":       Color(0.502, 0.502, 0.502),
	"sandstone":            Color(0.882, 0.812, 0.620),
	"sandstone_smooth":     Color(0.910, 0.847, 0.659),
	"sandstone_chiseled":   Color(0.882, 0.812, 0.620),
	"brick":                Color(0.698, 0.298, 0.200),
	"mud_brick":            Color(0.549, 0.408, 0.259),
	# structural/decorative
	"pillar":          Color(0.820, 0.820, 0.820),
	"arch_stone":      Color(0.502, 0.502, 0.502),
	"window_glass":    Color(0.780, 0.910, 0.980),
	"fence_wood":      Color(0.698, 0.565, 0.325),
	"fence_stone_wall": Color(0.420, 0.420, 0.420),
	"stairs_stone":    Color(0.502, 0.502, 0.502),
	"stairs_wood":     Color(0.698, 0.565, 0.325),
	"slab_stone":      Color(0.502, 0.502, 0.502),
	"slab_wood":       Color(0.698, 0.565, 0.325),
	# nature
	"mushroom_red":    Color(0.820, 0.100, 0.100),
	"mushroom_brown":  Color(0.510, 0.357, 0.180),
	"vines":           Color(0.200, 0.502, 0.100),
	"lily_pad":        Color(0.180, 0.502, 0.100),
	# colored concrete
	"concrete_white":  Color(0.920, 0.920, 0.920),
	"concrete_red":    Color(0.720, 0.100, 0.100),
	"concrete_orange": Color(0.880, 0.460, 0.080),
	"concrete_yellow": Color(0.920, 0.840, 0.080),
	"concrete_green":  Color(0.120, 0.560, 0.120),
	"concrete_blue":   Color(0.100, 0.260, 0.800),
	"concrete_purple": Color(0.450, 0.100, 0.700),
	"concrete_black":  Color(0.100, 0.100, 0.100),
	# decorative stone
	"polished_stone":  Color(0.580, 0.580, 0.600),
	"granite":         Color(0.680, 0.440, 0.360),
	"diorite":         Color(0.800, 0.780, 0.760),
	"andesite":        Color(0.450, 0.440, 0.420),
	"terracotta":      Color(0.720, 0.420, 0.280),
	"marble":          Color(0.940, 0.920, 0.900),
	# functional blocks
	"iron_bars":       Color(0.540, 0.540, 0.570),
	"glass_pane":      Color(0.760, 0.900, 0.960),
	"ladder":          Color(0.680, 0.560, 0.300),
	"trapdoor":        Color(0.620, 0.480, 0.240),
	"glowstone":       Color(1.000, 0.880, 0.480),
	"nether_brick":    Color(0.280, 0.080, 0.080),
	"end_stone":       Color(0.880, 0.880, 0.660),
	"mycelium":        Color(0.480, 0.360, 0.480),
	# new ores
	"mithril_ore":     Color(0.502, 0.502, 0.502),
	"topaz_ore":       Color(0.502, 0.502, 0.502),
	"sapphire_ore":    Color(0.502, 0.502, 0.502),
	# building & decorative blocks
	"brick_wall":      Color(0.698, 0.298, 0.200),
	"wood_plank_wall": Color(0.698, 0.565, 0.325),
	"cobblestone_wall":Color(0.420, 0.420, 0.420),
	"mossy_cobblestone":Color(0.310, 0.420, 0.290),
	"dark_stone":      Color(0.180, 0.180, 0.200),
	"iron_block":      Color(0.780, 0.800, 0.820),
	"gold_block":      Color(0.950, 0.820, 0.100),
	"clay_brick":      Color(0.780, 0.500, 0.380),
	"wood_beam":       Color(0.600, 0.450, 0.220),
}

# Ore inclusion colors
static var ORE_COLORS: Dictionary = {
	"coal_ore":    Color(0.071, 0.071, 0.071),
	"iron_ore":    Color(0.816, 0.659, 0.518),
	"gold_ore":    Color(1.000, 0.843, 0.000),
	"diamond_ore": Color(0.392, 0.941, 0.941),
	"emerald_ore": Color(0.118, 0.824, 0.290),
	"ruby_ore":    Color(0.878, 0.118, 0.220),
	"copper_ore":  Color(0.804, 0.400, 0.150),
	"tin_ore":     Color(0.700, 0.750, 0.780),
	"silver_ore":  Color(0.820, 0.840, 0.900),
	"mithril_ore": Color(0.380, 0.700, 0.900),
	"topaz_ore":   Color(1.000, 0.680, 0.160),
	"sapphire_ore":Color(0.100, 0.280, 0.900),
}

# Atlas layout: [tile_id, atlas_x, atlas_y, style]
static var ATLAS_LAYOUT: Array = [
	# Row 0
	["dirt",           0,  0, "solid"],
	["grass",          1,  0, "grass"],
	["stone",          2,  0, "stone"],
	["cobblestone",    3,  0, "cobble"],
	["sand",           4,  0, "solid"],
	["gravel",         5,  0, "gravel"],
	["water",          6,  0, "water"],
	["lava",           7,  0, "lava"],
	["bedrock",        8,  0, "bedrock"],
	["snow",           9,  0, "solid"],
	["ice",           10,  0, "ice"],
	["clay",          11,  0, "solid"],
	# Row 1
	["log_oak",        0,  1, "log"],
	["log_birch",      1,  1, "log"],
	["log_pine",       2,  1, "log"],
	["leaves_oak",     3,  1, "leaves"],
	["leaves_birch",   4,  1, "leaves"],
	["leaves_pine",    5,  1, "leaves"],
	["planks_oak",     6,  1, "planks"],
	["planks_birch",   7,  1, "planks"],
	["wool",           8,  1, "solid"],
	["torch",          9,  1, "torch"],
	["campfire",      10,  1, "campfire"],
	["chest",         11,  1, "chest"],
	["crafting_table",12,  1, "crafting_table"],
	["furnace",       13,  1, "furnace"],
	# Row 2
	["coal_ore",       0,  2, "ore"],
	["iron_ore",       1,  2, "ore"],
	["gold_ore",       2,  2, "ore"],
	["diamond_ore",    3,  2, "ore"],
	["emerald_ore",    4,  2, "ore"],
	["ruby_ore",       5,  2, "ore"],
	# Row 3 — biome decorations + saplings
	["snow_grass",     0,  3, "snow_grass"],
	["tall_grass",     1,  3, "tall_grass"],
	["cactus",         2,  3, "solid"],
	["sapling_oak",    3,  3, "sapling"],
	["sapling_birch",  4,  3, "sapling"],
	["sapling_pine",   5,  3, "sapling"],
	["wheat_seeds",    6,  3, "wheat_sprout"],
	["wheat_crop",     7,  3, "wheat_full"],
	["bed",            8,  3, "bed"],
	["crystal_gate",   9,  3, "crystal_gate"],
	# Row 4 — stone/brick variants
	["stone_brick",         0, 4, "stone_brick"],
	["mossy_stone_brick",   1, 4, "mossy_stone_brick"],
	["cracked_stone_brick", 2, 4, "cracked_stone_brick"],
	["chiseled_stone",      3, 4, "chiseled_stone"],
	["sandstone",           4, 4, "sandstone"],
	["sandstone_smooth",    5, 4, "sandstone_smooth"],
	["sandstone_chiseled",  6, 4, "sandstone_chiseled"],
	["brick",               7, 4, "brick_block"],
	["mud_brick",           8, 4, "mud_brick"],
	# Row 5 — wood variants
	["planks_spruce",   0, 5, "planks"],
	["planks_jungle",   1, 5, "planks"],
	["planks_dark_oak", 2, 5, "planks"],
	["log_spruce",      3, 5, "log"],
	["log_jungle",      4, 5, "log"],
	["leaves_spruce",   5, 5, "leaves"],
	["leaves_jungle",   6, 5, "leaves"],
	# Row 6 — structure/decorative
	["pillar",          0, 6, "pillar"],
	["arch_stone",      1, 6, "arch_stone"],
	["window_glass",    2, 6, "window_glass"],
	["fence_wood",      3, 6, "fence_wood"],
	["fence_stone_wall",4, 6, "fence_stone_wall"],
	["bookshelf",       5, 6, "bookshelf"],
	["hay_bale",        6, 6, "hay_bale"],
	["barrel",          7, 6, "barrel"],
	["stairs_stone",    8, 6, "stairs_stone"],
	["stairs_wood",     9, 6, "stairs_wood"],
	["slab_stone",     10, 6, "slab_stone"],
	["slab_wood",      11, 6, "slab_wood"],
	["anvil",          12, 6, "anvil"],
	["workbench_stone",13, 6, "workbench_stone"],
	["torch_wall",     14, 6, "torch"],
	# Row 7 — ores/resources
	["copper_ore",      0, 7, "ore"],
	["tin_ore",         1, 7, "ore"],
	["silver_ore",      2, 7, "ore"],
	["quartz_block",    3, 7, "quartz_block"],
	["obsidian",        4, 7, "obsidian"],
	# Row 8 — nature
	["mushroom_red",    0, 8, "mushroom_red"],
	["mushroom_brown",  1, 8, "mushroom_brown"],
	["vines",           2, 8, "vines"],
	["lily_pad",        3, 8, "lily_pad"],
	# Row 9 — colored concrete + stone variants + functional blocks
	["concrete_white",  0, 9, "solid"],
	["concrete_red",    1, 9, "solid"],
	["concrete_orange", 2, 9, "solid"],
	["concrete_yellow", 3, 9, "solid"],
	["concrete_green",  4, 9, "solid"],
	["concrete_blue",   5, 9, "solid"],
	["concrete_purple", 6, 9, "solid"],
	["concrete_black",  7, 9, "solid"],
	["polished_stone",  8, 9, "stone_brick"],
	["granite",         9, 9, "stone"],
	["diorite",        10, 9, "stone"],
	["andesite",       11, 9, "stone"],
	["terracotta",     12, 9, "solid"],
	["marble",         13, 9, "stone"],
	["iron_bars",      14, 9, "fence_stone_wall"],
	["glass_pane",     15, 9, "window_glass"],
	# Row 10 — extra blocks + new ores
	["ladder",          0, 10, "planks"],
	["trapdoor",        1, 10, "planks"],
	["glowstone",       2, 10, "solid"],
	["nether_brick",    3, 10, "brick_block"],
	["end_stone",       4, 10, "stone"],
	["mycelium",        5, 10, "solid"],
	["mithril_ore",     6, 10, "ore"],
	["topaz_ore",       7, 10, "ore"],
	["sapphire_ore",    8, 10, "ore"],
	# Row 11 — building & decorative blocks
	["brick_wall",      0, 11, "brick_block"],
	["wood_plank_wall", 1, 11, "planks"],
	["cobblestone_wall",2, 11, "cobble"],
	["mossy_cobblestone",3,11, "mossy_stone_brick"],
	["dark_stone",      4, 11, "stone"],
	["iron_block",      5, 11, "solid"],
	["gold_block",      6, 11, "solid"],
	["clay_brick",      7, 11, "brick_block"],
	["wood_beam",       8, 11, "log"],
]


## Generates the full 256×256 tile atlas used by every chunk's TileMapLayer.
##
## CUSTOM TILE TEXTURES:
##   Drop a 16×16 PNG at  res://assets/tiles/{tile_id}.png
##   (e.g. res://assets/tiles/grass.png)
##   It will be used instead of the procedurally generated tile.
##   Any tile without a PNG falls back to the built-in procedural drawing.
##   Re-export or re-run the game after adding a PNG for it to take effect.
## Path where the baked atlas PNG is stored between sessions.
const _ATLAS_CACHE_PATH: String = "user://tile_atlas_cache.png"

## Returns the atlas texture, loading from disk cache if available.
## Only regenerates (slow pixel draw) when no cache exists — typically once per install.
static func generate_atlas() -> ImageTexture:
	# ── Fast path: load the cached PNG from disk ──────────────────────────────
	if FileAccess.file_exists(_ATLAS_CACHE_PATH):
		var cached_img := Image.load_from_file(_ATLAS_CACHE_PATH)
		if cached_img != null:
			return ImageTexture.create_from_image(cached_img)

	# ── Slow path: generate procedurally and save for next time ───────────────
	var img := Image.create(ATLAS_WIDTH, ATLAS_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for entry in ATLAS_LAYOUT:
		var tile_id: String = entry[0]
		var ax: int = entry[1]
		var ay: int = entry[2]
		var style: String = entry[3]
		var dest_x: int = ax * TILE_SIZE
		var dest_y: int = ay * TILE_SIZE

		# ── Try loading a custom PNG override first ────────────────────────────
		var png_path: String = "res://assets/tiles/%s.png" % tile_id
		if ResourceLoader.exists(png_path):
			var tex: Texture2D = ResourceLoader.load(png_path, "Texture2D")
			if tex != null:
				var tile_img: Image = tex.get_image()
				if tile_img.get_width() != TILE_SIZE or tile_img.get_height() != TILE_SIZE:
					tile_img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
				tile_img.convert(Image.FORMAT_RGBA8)
				img.blit_rect(tile_img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(dest_x, dest_y))
				continue

		# ── No PNG found — draw procedurally ──────────────────────────────────
		var base_color: Color = TILE_COLORS.get(tile_id, Color(1, 0, 1))
		_draw_tile(img, ax, ay, base_color, style, tile_id)

	# Save to disk so next startup skips all the pixel work.
	img.save_png(_ATLAS_CACHE_PATH)

	var tex := ImageTexture.create_from_image(img)
	return tex

## Call this from the admin panel or after adding new tiles to force a cache rebuild.
static func invalidate_atlas_cache() -> void:
	if FileAccess.file_exists(_ATLAS_CACHE_PATH):
		DirAccess.remove_absolute(_ATLAS_CACHE_PATH)


## Returns a cached 16×16 ImageTexture for the given item_id.
##
## ─────────────────────────────────────────────────────────────────────────────
## ICON PRIORITY ORDER
##   1. res://assets/items/{item_id}.png       ← individual PNG (highest priority)
##   2. Sprite-atlas crop  (atlas_id + atlas_coords fields in ItemDB)
##   3. Block-tile atlas crop  (tile_id field in ItemDB, for placeable blocks)
##   4. Procedural shape drawing               ← built-in fallback
##
## HOW TO USE SPRITE ATLASES
##   • Register the sheet once in SPRITE_ATLASES (below).
##   • In ItemDatabase.gd, add to each item:
##       "atlas_id": "weapons",
##       "atlas_coords": Vector2i(col, row),
##   • The engine crops the correct cell and scales it to 16×16.
##
## HOW TO ADD A NEW ATLAS (e.g. for a new biome)
##   1. Drop your PNG anywhere under  res://assets/items/  (or a subfolder).
##   2. Add an entry to SPRITE_ATLASES:
##        "my_biome_items": { "path": "res://assets/items/my_biome.png", "cell_w": 32, "cell_h": 32 }
##   3. In ItemDatabase.gd set "atlas_id": "my_biome_items" and "atlas_coords": Vector2i(col, row)
##      on every item that lives in that sheet.
##   4. Done — no other files need touching.  The atlas image is loaded and cached
##      on first use, so adding more items to the same sheet is free.
## ─────────────────────────────────────────────────────────────────────────────

## Registry of sprite atlases used for item icons.
## Key   = atlas_id string (used in ItemDatabase atlas_id field)
## Value = { "path": String, "cell_w": int, "cell_h": int }
##
## cell_w / cell_h are the pixel dimensions of one cell in the sheet.
## The cell at atlas_coords Vector2i(col, row) starts at pixel (col*cell_w, row*cell_h).
static var SPRITE_ATLASES: Dictionary = {
	# master_weapon.png — weapons and tools spritesheet.
	# Each cell is 32×32 px.  Add more sheets below for new biomes/expansions.
	"weapons": {
		"path":   "res://assets/items/master_weapon.png",
		"cell_w": 32,
		"cell_h": 32,
	},
}

static var _icon_cache: Dictionary = {}
static var _atlas_img: Image = null           # cached block tile atlas image
static var _sprite_atlas_cache: Dictionary = {}  # atlas_id -> Image
static var _atlas_map_script = null

static func get_icon(item_id: String, item_data: Dictionary = {}) -> ImageTexture:
	if item_id in _icon_cache:
		return _icon_cache[item_id]

	# ── 1. Individual PNG override ─────────────────────────────────────────────
	# Check subdirectory first (assets/items/<id>/<id>.png), then flat file.
	var png_path: String = "res://assets/items/%s/%s.png" % [item_id, item_id]
	if not ResourceLoader.exists(png_path):
		png_path = "res://assets/items/%s.png" % item_id
	if ResourceLoader.exists(png_path):
		var tex: Texture2D = ResourceLoader.load(png_path, "Texture2D")
		if tex != null:
			var icon_img: Image = tex.get_image()
			if icon_img.get_width() != TILE_SIZE or icon_img.get_height() != TILE_SIZE:
				icon_img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
			icon_img.convert(Image.FORMAT_RGBA8)
			var out_tex := ImageTexture.create_from_image(icon_img)
			_icon_cache[item_id] = out_tex
			return out_tex

	# ── 2. Sprite-atlas crop (atlas_id / atlas_coords fields) ─────────────────
	# Higher priority than generated atlas because these are manually assigned.
	var atlas_id: String = item_data.get("atlas_id", "")
	if atlas_id != "" and SPRITE_ATLASES.has(atlas_id):
		var coords: Vector2i = item_data.get("atlas_coords", Vector2i(0, 0))
		var tex := _crop_sprite_atlas(atlas_id, coords)
		if tex != null:
			_icon_cache[item_id] = tex
			return tex

	# ── 3. Generated Atlas Lookup (atlas_map.gd) ──────────────────────────────
	# This uses the pre-baked icons from assets/atlas/*.png
	if _atlas_map_script == null:
		if FileAccess.file_exists("res://assets/atlas/atlas_map.gd"):
			_atlas_map_script = load("res://assets/atlas/atlas_map.gd")
	
	if _atlas_map_script != null and _atlas_map_script.ATLAS_MAP.has(item_id):
		var entry: Array = _atlas_map_script.ATLAS_MAP[item_id]
		var sheet_idx: int = entry[0]
		var col: int = entry[1]
		var row: int = entry[2]
		
		var sheet_names = ["blocks", "tools", "weapons", "materials", "armor_food"]
		var sheet_id = "generated_" + sheet_names[sheet_idx]
		
		if not SPRITE_ATLASES.has(sheet_id):
			SPRITE_ATLASES[sheet_id] = {
				"path": "res://assets/atlas/%s.png" % sheet_names[sheet_idx],
				"cell_w": 16,
				"cell_h": 16
			}
		
		var tex := _crop_sprite_atlas(sheet_id, Vector2i(col, row))
		if tex != null:
			_icon_cache[item_id] = tex
			return tex

	# ── 4. Block-tile atlas crop (placeable blocks, tile_id field) ────────────
	var tile_id_vec: Vector2i = item_data.get("tile_id", Vector2i(-1, -1))
	if tile_id_vec.x >= 0 and tile_id_vec.y >= 0:
		var tex := _crop_atlas_icon(tile_id_vec.x, tile_id_vec.y)
		_icon_cache[item_id] = tex
		return tex

	# ── 5. Procedural icon fallback (tools, weapons, food, etc.) ──────────────
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = item_data.get("icon_color", Color(0.8, 0.8, 0.8))
	_draw_item_icon(img, item_id, col, item_data)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[item_id] = tex
	return tex


## Crops one cell from a registered sprite atlas and returns it scaled to 16×16.
static func _crop_sprite_atlas(atlas_id: String, cell: Vector2i) -> ImageTexture:
	if not _sprite_atlas_cache.has(atlas_id):
		var info: Dictionary = SPRITE_ATLASES[atlas_id]
		var tex: Texture2D = ResourceLoader.load(info["path"], "Texture2D")
		if tex == null:
			return null
		_sprite_atlas_cache[atlas_id] = tex.get_image()
	var src: Image = _sprite_atlas_cache[atlas_id]
	var info: Dictionary = SPRITE_ATLASES[atlas_id]
	var cw: int = info["cell_w"]
	var ch: int = info["cell_h"]
	var region := Rect2i(cell.x * cw, cell.y * ch, cw, ch)
	var cropped := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(src, region, Vector2i.ZERO)
	if cw != TILE_SIZE or ch != TILE_SIZE:
		cropped.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
	cropped.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(cropped)


static func _crop_atlas_icon(ax: int, ay: int) -> ImageTexture:
	# Build block tile atlas image if not cached
	if _atlas_img == null:
		var atlas_tex := generate_atlas()
		_atlas_img = atlas_tex.get_image()
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.blit_rect(_atlas_img, Rect2i(ax * TILE_SIZE, ay * TILE_SIZE, TILE_SIZE, TILE_SIZE), Vector2i.ZERO)
	return ImageTexture.create_from_image(img)


static func _draw_item_icon(img: Image, item_id: String, col: Color, item_data: Dictionary) -> void:
	var dark  := col.darkened(0.4)
	var light := col.lightened(0.3)
	var handle := Color(0.45, 0.30, 0.15)  # clean rich wood brown
	var wood_light := handle.lightened(0.2)
	var wood_dark  := handle.darkened(0.3)
	var metal := col
	var metal_dark := dark
	var outline := Color(0, 0, 0, 0.7)

	# Determine shape by icon_shape field (set in ItemDatabase), falling back to item_id
	var _shape: String = item_data.get("icon_shape", "")
	if _shape == "" and (item_id.ends_with("_sword") or "blade" in item_id or "dagger" in item_id or item_id == "katana"):
		_shape = "sword"
	elif _shape == "" and (item_id.ends_with("_pick") or item_id.ends_with("_pickaxe") or "pick" in item_id):
		_shape = "pick"
	elif _shape == "" and (item_id.ends_with("_axe") or "axe" in item_id):
		_shape = "axe"
	elif _shape == "" and (item_id.ends_with("_shovel") or "shovel" in item_id):
		_shape = "shovel"
	elif _shape == "" and item_id.ends_with("_hoe"):
		_shape = "hoe"
	elif _shape == "" and ("spear" in item_id or "halberd" in item_id):
		_shape = "spear"
	elif _shape == "" and ("hammer" in item_id or "mace" in item_id or "flail" in item_id):
		_shape = "hammer"

	if _shape == "sword":
		# Clean Sword: 2px wide blade, distinct guard, wood handle
		# Blade
		_fill_rect(img, 7, 1, 2, 10, metal)
		_fill_rect(img, 7, 1, 1, 10, light) # highlight
		# Guard
		_fill_rect(img, 4, 10, 8, 2, metal_dark)
		_fill_rect(img, 5, 10, 6, 1, metal)
		# Handle
		_fill_rect(img, 7, 12, 2, 3, handle)
		# Pommel
		_fill_rect(img, 6, 14, 4, 1, metal_dark)
		# Outlines
		_draw_border_img(img, 7, 1, 2, 10, outline)
		_draw_border_img(img, 4, 10, 8, 2, outline)

	elif _shape == "pick":
		# Clean Pickaxe: Curved head, diagonal handle
		# Handle
		for i in range(8):
			img.set_pixel(2 + i, 14 - i, handle)
			img.set_pixel(3 + i, 14 - i, wood_dark)
		# Head (arc)
		_fill_rect(img, 2, 2, 12, 3, metal)
		_fill_rect(img, 2, 2, 3, 4, metal)
		_fill_rect(img, 11, 2, 3, 4, metal)
		_fill_rect(img, 3, 3, 10, 1, light) # highlight
		# Outlines for head
		_draw_border_img(img, 2, 2, 12, 3, outline)

	elif _shape == "axe":
		# Clean Axe: Heavy head on wood handle
		# Handle
		_fill_rect(img, 7, 6, 2, 9, handle)
		_fill_rect(img, 8, 6, 1, 9, wood_dark)
		# Head
		_fill_rect(img, 3, 2, 6, 6, metal)
		_fill_rect(img, 2, 3, 2, 4, metal_dark) # cutting edge
		_fill_rect(img, 4, 3, 4, 1, light) # top light
		# Connector
		_fill_rect(img, 6, 4, 4, 2, metal_dark)
		# Outlines
		_draw_border_img(img, 3, 2, 6, 6, outline)

	elif _shape == "shovel":
		# Clean Shovel: Round head, long handle
		# Handle
		_fill_rect(img, 7, 0, 2, 11, handle)
		_fill_rect(img, 8, 0, 1, 11, wood_dark)
		# Head
		_fill_rect(img, 4, 11, 8, 4, metal)
		_fill_rect(img, 5, 10, 6, 2, metal)
		img.set_pixel(7, 14, metal_dark)
		img.set_pixel(8, 14, metal_dark)
		_fill_rect(img, 5, 11, 1, 3, light) # highlight
		# Outlines
		_draw_border_img(img, 4, 11, 8, 4, outline)

	elif _shape == "hoe":
		# Handle
		_fill_rect(img, 7, 5, 2, 10, handle)
		# Blade
		_fill_rect(img, 3, 2, 8, 3, metal)
		_fill_rect(img, 3, 2, 1, 3, light)
		_draw_border_img(img, 3, 2, 8, 3, outline)

	elif _shape == "spear":
		# Long wood shaft, sharp metal tip
		_fill_rect(img, 7, 4, 2, 12, handle)
		# Tip
		_fill_rect(img, 7, 0, 2, 4, metal)
		img.set_pixel(7, 0, Color(0,0,0,0))
		img.set_pixel(8, 0, light)
		_draw_border_img(img, 7, 0, 2, 4, outline)

	elif _shape == "hammer":
		# Heavy head, reinforced wood handle
		_fill_rect(img, 7, 7, 2, 9, handle)
		# Head
		_fill_rect(img, 3, 1, 10, 7, metal)
		_fill_rect(img, 4, 2, 8, 5, light)
		_fill_rect(img, 3, 1, 10, 1, metal_dark)
		_draw_border_img(img, 3, 1, 10, 7, outline)

	elif item_id == "bow" or "bow" in item_id:
		# Polished wood arc
		for i in range(5):
			_fill_rect(img, 2, 2 + i * 2, 2 + i, 2, handle)
			_fill_rect(img, 2, 12 - i * 2, 2 + i, 2, handle)
		_fill_rect(img, 13, 3, 1, 10, Color(0.9, 0.9, 0.9, 0.8)) # string
		_draw_border_img(img, 2, 2, 6, 12, outline)

	elif item_id == "arrow":
		# Wood shaft, flint tip, feather fletching
		_fill_rect(img, 7, 4, 1, 8, handle)
		# Tip
		_fill_rect(img, 6, 1, 3, 3, metal_dark)
		# Fletching
		_fill_rect(img, 6, 13, 3, 2, Color(0.9, 0.9, 0.9))
		_draw_border_img(img, 6, 1, 3, 3, outline)

	elif item_id == "stick":
		for i in range(13):
			img.set_pixel(3 + i, 13 - i, handle)
			img.set_pixel(4 + i, 13 - i, wood_dark)

	elif item_id == "apple":
		# Polished fruit
		_fill_rect(img, 4, 3, 8, 10, col)
		_fill_rect(img, 3, 5, 10, 6, col)
		_fill_rect(img, 5, 2, 6, 2, col)
		# stem
		_fill_rect(img, 8, 1, 1, 2, wood_dark)
		img.set_pixel(5, 5, light) # gleam

	elif item_id == "bread":
		# Textured loaf
		_fill_rect(img, 2, 7, 12, 6, col)
		_fill_rect(img, 3, 5, 10, 3, light)
		_fill_rect(img, 2, 7, 12, 1, dark) # crust

	elif item_id in ["cooked_meat", "raw_meat", "meat_cooked", "meat_raw"]:
		var meat_col := col if item_id.begins_with("cooked") or item_id.ends_with("cooked") else Color(0.8, 0.3, 0.3)
		_fill_rect(img, 3, 5, 10, 6, meat_col)
		_fill_rect(img, 1, 4, 3, 3, Color(0.95,0.9,0.85)) # bone

	elif item_id.ends_with("_ingot"):
		# Shiny beveled ingot
		_fill_rect(img, 3, 4, 10, 8, col)
		_fill_rect(img, 4, 3, 8, 2, light)
		_fill_rect(img, 3, 11, 10, 1, dark)
		_draw_border_img(img, 3, 3, 10, 9, outline)

	elif item_id in ["diamond", "emerald", "ruby", "quartz"]:
		# Faceted gem
		_fill_rect(img, 5, 4, 6, 8, col)
		_fill_rect(img, 3, 6, 10, 4, col)
		_fill_rect(img, 6, 5, 4, 2, light) # sparkle
		_draw_border_img(img, 3, 4, 10, 8, outline)

	elif item_id == "coal":
		_fill_rect(img, 3, 3, 10, 10, col)
		_draw_border_img(img, 3, 3, 10, 10, outline)

	elif item_id == "bone" or item_id == "bone_meal":
		# Polished bone
		var bc := Color(0.95, 0.93, 0.85)
		_fill_rect(img, 7, 2, 2, 12, bc)
		_fill_rect(img, 5, 1, 6, 3, bc)
		_fill_rect(img, 5, 12, 6, 3, bc)
		_draw_border_img(img, 7, 2, 2, 12, outline)

	elif item_id == "string":
		for i in range(12):
			img.set_pixel(2 + i, 2 + (i * 7 % 12), col)

	elif item_id == "wheat":
		var stalk_c := Color(0.68, 0.58, 0.18)
		for bx in [5, 8, 11]:
			_fill_rect(img, bx, 4, 2, 10, stalk_c)
			_fill_rect(img, bx - 1, 2, 4, 5, col)

	elif item_data.get("type", "") == "armor" or _shape == "armor":
		var slot_name: String = item_data.get("slot", "chest")
		match slot_name:
			"head":   # helmet
				_fill_rect(img, 3, 4, 10, 9, col)
				_fill_rect(img, 5, 3, 6, 2, light)
				_fill_rect(img, 4, 12, 8, 1, dark)
				_draw_border_img(img, 3, 4, 10, 9, outline)
			"chest":  # chestplate
				_fill_rect(img, 2, 2, 12, 12, col)
				_fill_rect(img, 6, 2, 4, 12, dark) # trim
				_fill_rect(img, 3, 3, 2, 10, light)
				_draw_border_img(img, 2, 2, 12, 12, outline)
			"arms":   # gauntlets
				_fill_rect(img, 3, 3, 10, 10, col)
				_draw_border_img(img, 3, 3, 10, 10, outline)
			"legs":   # leggings
				_fill_rect(img, 2, 1, 12, 7, col)
				_fill_rect(img, 2, 8, 5, 7, col)
				_fill_rect(img, 9, 8, 5, 7, col)
				_draw_border_img(img, 2, 1, 12, 14, outline)
			"feet":   # boots
				_fill_rect(img, 2, 10, 5, 5, col)
				_fill_rect(img, 9, 10, 5, 5, col)
				_fill_rect(img, 2, 14, 5, 1, dark)
				_fill_rect(img, 9, 14, 5, 1, dark)
				_draw_border_img(img, 2, 10, 12, 5, outline)
	else:
		# Default: colored square with border
		_fill_rect(img, 1, 1, 14, 14, col)
		_draw_border_img(img, 1, 1, 14, 14, outline)


static func _draw_border_img(img: Image, ox: int, oy: int, w: int, h: int, color: Color = Color(0, 0, 0, 0.6)) -> void:
	for x in range(w):
		img.set_pixel(ox + x, oy, color)
		img.set_pixel(ox + x, oy + h - 1, color)
	for y in range(h):
		img.set_pixel(ox, oy + y, color)
		img.set_pixel(ox + w - 1, oy + y, color)


static func _draw_tile(img: Image, atlas_x: int, atlas_y: int, color: Color, style: String, tile_id: String = "") -> void:
	var ox := atlas_x * TILE_SIZE
	var oy := atlas_y * TILE_SIZE

	match style:
		"solid":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"grass":
			# Bottom 13 rows: dirt brown
			var dirt := Color(0.545, 0.353, 0.169)
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, dirt)
			# Top 3 rows: bright green
			var green := Color(0.302, 0.686, 0.098)
			_fill_rect(img, ox, oy, TILE_SIZE, 3, green)
			# Blend row at y+3
			var blend := green.lerp(dirt, 0.5)
			_fill_rect(img, ox, oy + 3, TILE_SIZE, 1, blend)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"stone":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Subtle texture: scatter slightly lighter/darker pixels
			var rng := _seeded_rng(atlas_x * 100 + atlas_y * 10 + 1)
			for i in 20:
				var px := ox + (rng.randi() % (TILE_SIZE - 2)) + 1
				var py := oy + (rng.randi() % (TILE_SIZE - 2)) + 1
				var variation := (rng.randf() - 0.5) * 0.12
				var c := Color(color.r + variation, color.g + variation, color.b + variation, 1.0)
				img.set_pixel(px, py, c)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"cobble":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Draw cobblestone mortar lines
			var mortar := color.darkened(0.25)
			var stone_light := color.lightened(0.1)
			# Horizontal mortar lines
			for mx in [4, 9]:
				_fill_rect(img, ox + 1, oy + mx, TILE_SIZE - 2, 1, mortar)
			# Vertical mortar lines (offset per row)
			for py2 in range(1, 4):
				img.set_pixel(ox + 7, oy + py2, mortar)
			for py2 in range(5, 9):
				img.set_pixel(ox + 3, oy + py2, mortar)
				img.set_pixel(ox + 11, oy + py2, mortar)
			for py2 in range(10, TILE_SIZE - 1):
				img.set_pixel(ox + 6, oy + py2, mortar)
			# Light stones
			_fill_rect(img, ox + 1, oy + 1, 6, 3, stone_light)
			_fill_rect(img, ox + 8, oy + 1, 7, 3, stone_light)
			_fill_rect(img, ox + 1, oy + 5, 2, 4, stone_light)
			_fill_rect(img, ox + 4, oy + 5, 7, 4, stone_light)
			_fill_rect(img, ox + 12, oy + 5, 3, 4, stone_light)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"gravel":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var rng2 := _seeded_rng(atlas_x * 77 + atlas_y * 13 + 2)
			for i in 14:
				var px := ox + (rng2.randi() % (TILE_SIZE - 2)) + 1
				var py := oy + (rng2.randi() % (TILE_SIZE - 2)) + 1
				var sz := 1 + (rng2.randi() % 2)
				var bright := rng2.randf() > 0.5
				var gc := color.lightened(0.2) if bright else color.darkened(0.2)
				_fill_rect(img, px, py, sz, sz, gc)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"water":
			var water_deep := Color(0.157, 0.310, 0.741, 0.85)
			var water_light := Color(0.400, 0.600, 0.980, 0.75)
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, water_deep)
			# Wave lines
			for wave_y in [3, 8, 13]:
				for wave_x in range(1, TILE_SIZE - 1, 2):
					img.set_pixel(ox + wave_x, oy + wave_y, water_light)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"lava":
			var lava_base := Color(0.780, 0.200, 0.020, 0.95)
			var lava_bright := Color(1.000, 0.620, 0.000, 1.0)
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, lava_base)
			# Bright blob patches
			var rng3 := _seeded_rng(atlas_x * 33 + atlas_y * 17 + 3)
			for i in 8:
				var px := ox + (rng3.randi() % (TILE_SIZE - 4)) + 2
				var py := oy + (rng3.randi() % (TILE_SIZE - 4)) + 2
				_fill_rect(img, px, py, 2, 2, lava_bright)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"bedrock":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var rng4 := _seeded_rng(atlas_x * 55 + atlas_y * 21 + 4)
			for i in 18:
				var px := ox + (rng4.randi() % (TILE_SIZE - 2)) + 1
				var py := oy + (rng4.randi() % (TILE_SIZE - 2)) + 1
				var vc := rng4.randf() * 0.08
				var bc := Color(color.r + vc, color.g + vc, color.b + vc)
				img.set_pixel(px, py, bc)
			# Extra dark cracks
			for i in 3:
				var cx := ox + 2 + (rng4.randi() % 10)
				var cy := oy + 2 + (rng4.randi() % 10)
				img.set_pixel(cx, cy, Color(0.05, 0.05, 0.05))
				img.set_pixel(cx + 1, cy + 1, Color(0.05, 0.05, 0.05))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"ice":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Shiny diagonal highlights
			var highlight := Color(1.0, 1.0, 1.0, 0.5)
			for d in range(1, 5):
				img.set_pixel(ox + d, oy + d, highlight)
			for d in range(8, 12):
				img.set_pixel(ox + d, oy + d - 6, highlight)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"log":
			# Ring pattern: lighter bark edges, darker heartwood center
			var bark := color
			var heartwood := color.darkened(0.30)
			var ring := color.lightened(0.20)
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, bark)
			# Inner ring (lighter)
			_fill_rect(img, ox + 3, oy + 3, TILE_SIZE - 6, TILE_SIZE - 6, ring)
			# Center heartwood
			_fill_rect(img, ox + 5, oy + 5, TILE_SIZE - 10, TILE_SIZE - 10, heartwood)
			# Bark grain lines
			var grain := bark.darkened(0.15)
			for gx in [1, 14]:
				_fill_rect(img, ox + gx, oy + 2, 1, TILE_SIZE - 4, grain)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"leaves":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Random green variations
			var rng5 := _seeded_rng(atlas_x * 11 + atlas_y * 7 + 5)
			for i in 24:
				var px := ox + (rng5.randi() % (TILE_SIZE - 2)) + 1
				var py := oy + (rng5.randi() % (TILE_SIZE - 2)) + 1
				var vary := (rng5.randf() - 0.5) * 0.18
				var lc := Color(
					clampf(color.r + vary * 0.3, 0, 1),
					clampf(color.g + vary, 0, 1),
					clampf(color.b + vary * 0.2, 0, 1)
				)
				img.set_pixel(px, py, lc)
			# Transparent holes to look leafy
			for i in 8:
				var px := ox + (rng5.randi() % (TILE_SIZE - 2)) + 1
				var py := oy + (rng5.randi() % (TILE_SIZE - 2)) + 1
				img.set_pixel(px, py, Color(0, 0, 0, 0))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"planks":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Horizontal plank lines
			var dark_line := color.darkened(0.25)
			var light_grain := color.lightened(0.10)
			for line_y in [4, 8, 12]:
				_fill_rect(img, ox, oy + line_y, TILE_SIZE, 1, dark_line)
			# Grain
			for gx in range(2, TILE_SIZE - 2, 5):
				for gy in range(1, 4):
					img.set_pixel(ox + gx, oy + gy, light_grain)
				for gy in range(5, 8):
					img.set_pixel(ox + gx + 2, oy + gy, light_grain)
				for gy in range(9, 12):
					img.set_pixel(ox + gx + 1, oy + gy, light_grain)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"torch":
			# Transparent background
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			# Stick: brown 2px wide, center, rows 5-14
			var stick_color := Color(0.502, 0.322, 0.098)
			_fill_rect(img, ox + 7, oy + 5, 2, 10, stick_color)
			# Flame base: orange, rows 3-5, 3px wide
			var flame_base := Color(1.0, 0.5, 0.0)
			_fill_rect(img, ox + 6, oy + 3, 4, 3, flame_base)
			# Flame tip: yellow, 2px, rows 1-3
			var flame_tip := Color(1.0, 0.95, 0.2)
			_fill_rect(img, ox + 7, oy + 1, 2, 3, flame_tip)
			# Glow pixel
			img.set_pixel(ox + 7, oy + 1, Color(1.0, 1.0, 0.8))

		"campfire":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Log base: two crossed logs at bottom
			var log_c := Color(0.400, 0.250, 0.071)
			_fill_rect(img, ox + 1, oy + 11, 14, 2, log_c)
			_fill_rect(img, ox + 5, oy + 9, 6, 6, log_c)
			# Flames
			var f1 := Color(1.0, 0.5, 0.0)
			var f2 := Color(1.0, 0.9, 0.1)
			_fill_rect(img, ox + 4, oy + 5, 8, 6, f1)
			_fill_rect(img, ox + 6, oy + 2, 4, 5, f2)
			_fill_rect(img, ox + 7, oy + 1, 2, 3, Color(1.0, 1.0, 0.6))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"chest":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Lid (top half slightly lighter)
			var lid := color.lightened(0.15)
			_fill_rect(img, ox + 1, oy + 1, TILE_SIZE - 2, 6, lid)
			# Latch
			var latch := Color(0.780, 0.620, 0.120)
			_fill_rect(img, ox + 6, oy + 6, 4, 3, latch)
			# Horizontal band
			var band := color.darkened(0.20)
			_fill_rect(img, ox + 1, oy + 7, TILE_SIZE - 2, 2, band)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"crafting_table":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Grid lines to show crafting grid
			var grid := color.darkened(0.25)
			_fill_rect(img, ox + 5, oy + 1, 1, TILE_SIZE - 2, grid)
			_fill_rect(img, ox + 10, oy + 1, 1, TILE_SIZE - 2, grid)
			_fill_rect(img, ox + 1, oy + 5, TILE_SIZE - 2, 1, grid)
			_fill_rect(img, ox + 1, oy + 10, TILE_SIZE - 2, 1, grid)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"furnace":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# Door opening (dark rectangle, center)
			_fill_rect(img, ox + 4, oy + 4, 8, 8, Color(0.12, 0.12, 0.12))
			# Fire glow inside
			_fill_rect(img, ox + 5, oy + 8, 6, 3, Color(1.0, 0.5, 0.0, 0.8))
			# Door frame
			var frame := color.lightened(0.2)
			_fill_rect(img, ox + 4, oy + 4, 8, 1, frame)
			_fill_rect(img, ox + 4, oy + 11, 8, 1, frame)
			_fill_rect(img, ox + 4, oy + 4, 1, 8, frame)
			_fill_rect(img, ox + 11, oy + 4, 1, 8, frame)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"ore":
			# Stone base
			var stone_base := Color(0.502, 0.502, 0.502)
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, stone_base)
			# Stone texture
			var rng6 := _seeded_rng(atlas_x * 41 + atlas_y * 19 + 6)
			for i in 10:
				var px := ox + (rng6.randi() % (TILE_SIZE - 2)) + 1
				var py := oy + (rng6.randi() % (TILE_SIZE - 2)) + 1
				var variation := (rng6.randf() - 0.5) * 0.10
				img.set_pixel(px, py, Color(
					stone_base.r + variation,
					stone_base.g + variation,
					stone_base.b + variation
				))
			# Ore inclusion dots
			var ore_color: Color = ORE_COLORS.get(tile_id, Color(1, 0, 1))
			var dot_positions := [
				Vector2i(3, 3), Vector2i(11, 4),
				Vector2i(5, 10), Vector2i(12, 11),
			]
			for dp in dot_positions:
				_fill_rect(img, ox + dp.x, oy + dp.y, 2, 2, ore_color)
				img.set_pixel(ox + dp.x + 1, oy + dp.y + 1, ore_color.lightened(0.3))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"snow_grass":
			# Dirt base with white snow cap on top 3 rows.
			var dirt2 := Color(0.545, 0.353, 0.169)
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, dirt2)
			var snow_c := Color(0.941, 0.973, 0.988)
			_fill_rect(img, ox, oy, TILE_SIZE, 3, snow_c)
			_fill_rect(img, ox, oy + 3, TILE_SIZE, 1, snow_c.lerp(dirt2, 0.5))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"tall_grass":
			# Transparent background with green blades.
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var g1 := Color(0.302, 0.686, 0.098)
			var g2 := Color(0.200, 0.550, 0.060)
			# Several vertical blades of varying height.
			for bx in [2, 5, 8, 11, 14]:
				var blade_h: int = 8 + (bx % 3) * 2
				_fill_rect(img, ox + bx, oy + (TILE_SIZE - blade_h), 2, blade_h, g1 if bx % 2 == 0 else g2)

		"sapling":
			# Transparent background, small trunk with two leaf tufts.
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var trunk_c := Color(0.427, 0.318, 0.173)
			var leaf_c  := color
			# Trunk (thin, bottom half)
			_fill_rect(img, ox + 7, oy + 8, 2, 8, trunk_c)
			# Left leaf
			_fill_rect(img, ox + 3, oy + 2, 5, 5, leaf_c)
			# Right leaf
			_fill_rect(img, ox + 8, oy + 2, 5, 5, leaf_c)
			# Top leaf
			_fill_rect(img, ox + 5, oy + 1, 6, 4, leaf_c)

		"wheat_sprout":
			# Young wheat seedling — small green shoots on transparent background.
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var sc := color   # green
			for bx in [3, 7, 11]:
				_fill_rect(img, ox + bx, oy + 10, 2, 6, sc)
				_fill_rect(img, ox + bx - 1, oy + 8, 2, 3, sc)

		"wheat_full":
			# Mature wheat — golden stalks with grain heads.
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var stalk_c := Color(0.68, 0.58, 0.18)
			var head_c  := color   # golden
			for bx in [3, 7, 11]:
				# Stalk
				_fill_rect(img, ox + bx, oy + 7, 2, 9, stalk_c)
				# Grain head (slightly offset per stalk for variety)
				var hx: int = bx + (1 if bx == 7 else 0)
				_fill_rect(img, ox + hx - 1, oy + 2, 4, 6, head_c)

		"bed":
			# Frame/base
			_fill_rect(img, ox, oy + 8, TILE_SIZE, 8, color)
			_fill_rect(img, ox, oy, TILE_SIZE, 8, color.lightened(0.3))
			# Pillow
			_fill_rect(img, ox + 2, oy + 1, 5, 5, Color(0.95, 0.95, 0.95))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"crystal_gate":
			# Cyan crystal portal frame
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0.10, 0.12, 0.18))
			# Glowing portal interior
			_fill_rect(img, ox + 3, oy + 1, 10, 14, color.darkened(0.2))
			# Bright center
			_fill_rect(img, ox + 5, oy + 3, 6, 10, Color(0.85, 1.0, 1.0, 0.9))
			# Frame pillars
			_fill_rect(img, ox + 1, oy + 1, 2, 14, color)
			_fill_rect(img, ox + 13, oy + 1, 2, 14, color)
			_fill_rect(img, ox + 3, oy, 10, 2, color)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"stone_brick":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var sb_mortar := color.darkened(0.30)
			var sb_light  := color.lightened(0.08)
			_fill_rect(img, ox + 1, oy + 1, 6, 6, sb_light)
			_fill_rect(img, ox + 9, oy + 1, 6, 6, sb_light)
			_fill_rect(img, ox + 1, oy + 9, 14, 6, sb_light)
			_fill_rect(img, ox, oy + 8, TILE_SIZE, 1, sb_mortar)
			_fill_rect(img, ox + 8, oy + 1, 1, 7, sb_mortar)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"mossy_stone_brick":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var msb_mortar := color.darkened(0.30)
			var msb_moss   := Color(0.200, 0.502, 0.150)
			_fill_rect(img, ox, oy + 8, TILE_SIZE, 1, msb_mortar)
			_fill_rect(img, ox + 8, oy + 1, 1, 7, msb_mortar)
			_fill_rect(img, ox + 1, oy + 1, 6, 6, color.lightened(0.06))
			_fill_rect(img, ox + 2, oy + 2, 2, 2, msb_moss)
			_fill_rect(img, ox + 10, oy + 9, 2, 2, msb_moss)
			_fill_rect(img, ox + 4, oy + 10, 2, 2, msb_moss)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"cracked_stone_brick":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var csb_dark := color.darkened(0.35)
			_fill_rect(img, ox, oy + 8, TILE_SIZE, 1, csb_dark)
			_fill_rect(img, ox + 8, oy + 1, 1, 7, csb_dark)
			# diagonal cracks
			for ci in range(3):
				img.set_pixel(ox + 2 + ci, oy + 2 + ci, csb_dark)
			for ci in range(4):
				img.set_pixel(ox + 10 + ci, oy + 9 + ci, csb_dark)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"chiseled_stone":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var cs_dark := color.darkened(0.25)
			var cs_light := color.lightened(0.12)
			# carved diamond/lozenge shape in center
			_fill_rect(img, ox + 5, oy + 1, 6, 1, cs_dark)
			_fill_rect(img, ox + 3, oy + 3, 10, 1, cs_dark)
			_fill_rect(img, ox + 3, oy + 11, 10, 1, cs_dark)
			_fill_rect(img, ox + 5, oy + 13, 6, 1, cs_dark)
			_fill_rect(img, ox + 6, oy + 6, 4, 4, cs_light)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"sandstone":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var ss_line := color.darkened(0.15)
			for ly in [4, 8, 12]:
				_fill_rect(img, ox + 1, oy + ly, TILE_SIZE - 2, 1, ss_line)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"sandstone_smooth":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			_fill_rect(img, ox + 1, oy + 1, TILE_SIZE - 2, 2, color.lightened(0.10))
			_fill_rect(img, ox + 1, oy + 13, TILE_SIZE - 2, 2, color.darkened(0.08))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"sandstone_chiseled":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var sc_dark := color.darkened(0.20)
			# horizontal carved lines
			_fill_rect(img, ox + 1, oy + 5, TILE_SIZE - 2, 1, sc_dark)
			_fill_rect(img, ox + 1, oy + 9, TILE_SIZE - 2, 1, sc_dark)
			# center diamond motif
			_fill_rect(img, ox + 6, oy + 6, 4, 4, color.lightened(0.10))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"brick_block":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var bk_mortar := Color(0.75, 0.70, 0.65)
			var bk_dark   := color.darkened(0.12)
			# mortar rows
			for my in [4, 8, 12]:
				_fill_rect(img, ox, oy + my, TILE_SIZE, 1, bk_mortar)
			# mortar columns offset per row
			for by2 in range(1, 4):
				img.set_pixel(ox + 8, oy + by2, bk_mortar)
			for by2 in range(5, 8):
				img.set_pixel(ox + 4, oy + by2, bk_mortar)
				img.set_pixel(ox + 12, oy + by2, bk_mortar)
			for by2 in range(9, 12):
				img.set_pixel(ox + 8, oy + by2, bk_mortar)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"mud_brick":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var mb_mortar := color.darkened(0.25)
			_fill_rect(img, ox, oy + 6, TILE_SIZE, 1, mb_mortar)
			_fill_rect(img, ox, oy + 12, TILE_SIZE, 1, mb_mortar)
			img.set_pixel(ox + 8, oy + 2, mb_mortar)
			img.set_pixel(ox + 8, oy + 3, mb_mortar)
			img.set_pixel(ox + 8, oy + 4, mb_mortar)
			img.set_pixel(ox + 4, oy + 8, mb_mortar)
			img.set_pixel(ox + 4, oy + 9, mb_mortar)
			img.set_pixel(ox + 4, oy + 10, mb_mortar)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"pillar":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var pl_dark  := color.darkened(0.20)
			var pl_light := color.lightened(0.15)
			# vertical flute lines
			for fx in [3, 7, 11]:
				_fill_rect(img, ox + fx, oy + 1, 1, TILE_SIZE - 2, pl_dark)
			# top and bottom cap bands
			_fill_rect(img, ox + 1, oy + 1, TILE_SIZE - 2, 2, pl_light)
			_fill_rect(img, ox + 1, oy + 13, TILE_SIZE - 2, 2, pl_light)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"arch_stone":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var as_dark := color.darkened(0.30)
			# arch opening (dark interior arch shape)
			_fill_rect(img, ox + 4, oy + 4, 8, 10, Color(0.05, 0.05, 0.05, 0.9))
			# arch curve (top of opening)
			_fill_rect(img, ox + 3, oy + 3, 10, 2, Color(0.05, 0.05, 0.05, 0.9))
			_fill_rect(img, ox + 5, oy + 2, 6, 1, Color(0.05, 0.05, 0.05, 0.9))
			# keystone
			_fill_rect(img, ox + 6, oy + 1, 4, 2, color.lightened(0.15))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"window_glass":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var gl_c := Color(0.780, 0.910, 0.980, 0.55)
			_fill_rect(img, ox + 1, oy + 1, TILE_SIZE - 2, TILE_SIZE - 2, gl_c)
			# cross-frame
			var fr := Color(0.600, 0.700, 0.750, 0.9)
			_fill_rect(img, ox + 7, oy + 1, 2, TILE_SIZE - 2, fr)
			_fill_rect(img, ox + 1, oy + 7, TILE_SIZE - 2, 2, fr)
			# highlight glint
			img.set_pixel(ox + 3, oy + 3, Color(1.0, 1.0, 1.0, 0.7))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"fence_wood":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var fw_c := color
			# two vertical posts
			_fill_rect(img, ox + 2, oy, 3, TILE_SIZE, fw_c)
			_fill_rect(img, ox + 11, oy, 3, TILE_SIZE, fw_c)
			# two horizontal rails
			_fill_rect(img, ox + 2, oy + 3, TILE_SIZE - 4, 3, fw_c)
			_fill_rect(img, ox + 2, oy + 10, TILE_SIZE - 4, 3, fw_c)

		"fence_stone_wall":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var fsw_c := color
			# thick central post
			_fill_rect(img, ox + 5, oy, 6, TILE_SIZE, fsw_c)
			# two arms extending sideways
			_fill_rect(img, ox, oy + 5, TILE_SIZE, 5, fsw_c)
			_draw_border(img, ox + 5, oy, 6, TILE_SIZE)

		"bookshelf":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			# plank top/bottom strips
			var bs_plank := Color(0.698, 0.565, 0.325)
			_fill_rect(img, ox, oy, TILE_SIZE, 2, bs_plank)
			_fill_rect(img, ox, oy + 7, TILE_SIZE, 2, bs_plank)
			_fill_rect(img, ox, oy + 14, TILE_SIZE, 2, bs_plank)
			# colored book spines
			var book_colors := [
				Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.8), Color(0.2, 0.7, 0.3),
				Color(0.8, 0.7, 0.2), Color(0.6, 0.2, 0.7), Color(0.8, 0.4, 0.1),
			]
			for bi in range(6):
				var bx := ox + 1 + bi * 2 + (bi / 3) * 1
				var by_row := oy + 2 if bi < 3 else oy + 9
				_fill_rect(img, bx, by_row, 2, 5, book_colors[bi])
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"hay_bale":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var hb_dark := color.darkened(0.25)
			var hb_light := color.lightened(0.12)
			# horizontal straw lines
			for hy2 in [2, 5, 8, 11, 14]:
				_fill_rect(img, ox + 1, oy + hy2, TILE_SIZE - 2, 1, hb_dark)
			# binding straps (vertical bands)
			_fill_rect(img, ox + 4, oy, 2, TILE_SIZE, hb_dark)
			_fill_rect(img, ox + 10, oy, 2, TILE_SIZE, hb_dark)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"barrel":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var ba_dark := color.darkened(0.25)
			var ba_light := color.lightened(0.10)
			# stave lines (vertical)
			for bx2 in [4, 8, 12]:
				_fill_rect(img, ox + bx2, oy + 2, 1, TILE_SIZE - 4, ba_dark)
			# top/bottom caps
			_fill_rect(img, ox + 1, oy + 1, TILE_SIZE - 2, 2, ba_light)
			_fill_rect(img, ox + 1, oy + 13, TILE_SIZE - 2, 2, ba_light)
			# metal hoops
			var ba_metal := Color(0.400, 0.350, 0.300)
			_fill_rect(img, ox + 1, oy + 4, TILE_SIZE - 2, 1, ba_metal)
			_fill_rect(img, ox + 1, oy + 10, TILE_SIZE - 2, 1, ba_metal)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"stairs_stone":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var sts_dark := color.darkened(0.20)
			# step silhouette: 3 steps from bottom-left to top-right
			_fill_rect(img, ox, oy + 10, TILE_SIZE, 6, color)
			_fill_rect(img, ox + 5, oy + 5, 11, 5, color)
			_fill_rect(img, ox + 10, oy, 6, 5, color)
			# darken the background
			_fill_rect(img, ox, oy, 10, 5, sts_dark.darkened(0.3))
			_fill_rect(img, ox, oy + 5, 5, 5, sts_dark.darkened(0.3))
			# step edges
			_fill_rect(img, ox + 10, oy + 5, 6, 1, sts_dark)
			_fill_rect(img, ox + 5, oy + 10, 11, 1, sts_dark)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"stairs_wood":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var stw_dark := color.darkened(0.20)
			_fill_rect(img, ox, oy + 10, TILE_SIZE, 6, color)
			_fill_rect(img, ox + 5, oy + 5, 11, 5, color)
			_fill_rect(img, ox + 10, oy, 6, 5, color)
			_fill_rect(img, ox, oy, 10, 5, stw_dark.darkened(0.3))
			_fill_rect(img, ox, oy + 5, 5, 5, stw_dark.darkened(0.3))
			_fill_rect(img, ox + 10, oy + 5, 6, 1, stw_dark)
			_fill_rect(img, ox + 5, oy + 10, 11, 1, stw_dark)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"slab_stone":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			_fill_rect(img, ox, oy + 8, TILE_SIZE, 8, color)
			_draw_border(img, ox, oy + 8, TILE_SIZE, 8)

		"slab_wood":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			_fill_rect(img, ox, oy + 8, TILE_SIZE, 8, color)
			var slw_dark := color.darkened(0.25)
			_fill_rect(img, ox, oy + 11, TILE_SIZE, 1, slw_dark)
			_draw_border(img, ox, oy + 8, TILE_SIZE, 8)

		"anvil":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var an_light := color.lightened(0.15)
			# base (wide bottom block)
			_fill_rect(img, ox + 1, oy + 11, 14, 5, color)
			# middle stem
			_fill_rect(img, ox + 4, oy + 8, 8, 3, color.darkened(0.15))
			# top anvil head (trapezoidal — wider at top)
			_fill_rect(img, ox + 2, oy + 3, 12, 5, color)
			_fill_rect(img, ox + 3, oy + 2, 10, 2, an_light)
			_draw_border(img, ox + 1, oy + 11, 14, 5)
			_draw_border(img, ox + 2, oy + 3, 12, 5)

		"workbench_stone":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var ws_dark := color.darkened(0.20)
			# stone slab look with a V-chisel groove
			_fill_rect(img, ox + 1, oy + 7, TILE_SIZE - 2, 2, ws_dark)
			_fill_rect(img, ox + 7, oy + 1, 2, TILE_SIZE - 2, ws_dark)
			_fill_rect(img, ox + 2, oy + 2, 4, 4, color.lightened(0.10))
			_fill_rect(img, ox + 10, oy + 2, 4, 4, color.lightened(0.10))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"quartz_block":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var qb_line := color.darkened(0.12)
			var qb_high := color.lightened(0.15)
			# subtle vertical pillar lines
			_fill_rect(img, ox + 5, oy + 1, 1, TILE_SIZE - 2, qb_line)
			_fill_rect(img, ox + 10, oy + 1, 1, TILE_SIZE - 2, qb_line)
			# top highlight
			_fill_rect(img, ox + 1, oy + 1, TILE_SIZE - 2, 2, qb_high)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"obsidian":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			var ob_purple := Color(0.250, 0.100, 0.450, 0.7)
			var rng_ob := _seeded_rng(42 + 99)
			for i in 8:
				var px := ox + (rng_ob.randi() % (TILE_SIZE - 2)) + 1
				var py := oy + (rng_ob.randi() % (TILE_SIZE - 2)) + 1
				img.set_pixel(px, py, ob_purple)
			for d in range(2, 5):
				img.set_pixel(ox + d, oy + d, Color(0.500, 0.200, 0.800, 0.6))
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)

		"mushroom_red":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			# stem
			var mr_stem := Color(0.900, 0.880, 0.820)
			_fill_rect(img, ox + 6, oy + 8, 4, 8, mr_stem)
			# cap (red with white spots)
			_fill_rect(img, ox + 2, oy + 2, 12, 8, color)
			_fill_rect(img, ox + 1, oy + 4, 14, 4, color)
			# white spots
			_fill_rect(img, ox + 4, oy + 3, 2, 2, Color(1.0, 1.0, 1.0))
			_fill_rect(img, ox + 10, oy + 3, 2, 2, Color(1.0, 1.0, 1.0))
			_fill_rect(img, ox + 7, oy + 5, 2, 2, Color(1.0, 1.0, 1.0))

		"mushroom_brown":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var mbn_stem := Color(0.900, 0.880, 0.820)
			_fill_rect(img, ox + 6, oy + 8, 4, 8, mbn_stem)
			# wider flat cap
			_fill_rect(img, ox + 1, oy + 4, 14, 5, color)
			_fill_rect(img, ox + 3, oy + 3, 10, 2, color)
			_fill_rect(img, ox + 2, oy + 9, 12, 1, color.darkened(0.20))

		"vines":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var v_c := color
			var v_leaf := color.lightened(0.15)
			# hanging vine strands
			for vx in [2, 6, 10, 14]:
				var strand_h: int = 10 + (vx % 4)
				_fill_rect(img, ox + vx, oy, 1, strand_h, v_c)
			# small leaves along strands
			for vx in [2, 6, 10]:
				_fill_rect(img, ox + vx - 1, oy + 3, 3, 2, v_leaf)
				_fill_rect(img, ox + vx, oy + 7, 3, 2, v_leaf)

		"lily_pad":
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, Color(0, 0, 0, 0))
			var lp_c := color
			var lp_dark := color.darkened(0.25)
			# oval pad shape
			_fill_rect(img, ox + 3, oy + 5, 10, 6, lp_c)
			_fill_rect(img, ox + 1, oy + 7, 14, 2, lp_c)
			_fill_rect(img, ox + 2, oy + 6, 12, 4, lp_c)
			# vein lines
			_fill_rect(img, ox + 8, oy + 5, 1, 6, lp_dark)
			_fill_rect(img, ox + 3, oy + 8, 10, 1, lp_dark)
			# notch (lily pads have a slit)
			img.set_pixel(ox + 8, oy + 5, Color(0, 0, 0, 0))
			img.set_pixel(ox + 8, oy + 6, Color(0, 0, 0, 0))

		_:
			_fill_rect(img, ox, oy, TILE_SIZE, TILE_SIZE, color)
			_draw_border(img, ox, oy, TILE_SIZE, TILE_SIZE)


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)


static func _draw_border(img: Image, ox: int, oy: int, w: int, h: int) -> void:
	var border := Color(0, 0, 0, 0.55)
	for bx in range(ox, ox + w):
		img.set_pixel(bx, oy, border)
		img.set_pixel(bx, oy + h - 1, border)
	for by in range(oy, oy + h):
		img.set_pixel(ox, by, border)
		img.set_pixel(ox + w - 1, by, border)


static func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng
