# World.gd
# Main world scene — manages chunk streaming, day/night cycle, and enemy spawning.
# Attach to the root Node2D of your main world scene.
#
# ============================================================
# HOW TO ADD NEW SPAWN RULES
# ============================================================
# All spawn logic lives in spawn_enemies() and the _spawn_rules Array at the top
# of that function. Each rule is a Dictionary with these keys:
#
#   "scene"      : String  — path to the PackedScene to instantiate
#   "group"      : String  — node group name (used for counting active enemies)
#   "condition"  : Callable — func(player_pos: Vector2) -> bool
#                   Return true when this enemy type is allowed to spawn.
#   "offset_range": Vector2 — (min_tiles, max_tiles) horizontal distance from player
#
# Example — add a slime that spawns underground, day or night:
#
#   {
#     "scene": "res://scenes/enemies/Slime.tscn",
#     "group": "enemy",
#     "condition": func(p): return p.y > _get_surface_y(p.x) + TILE_SIZE * 20,
#     "offset_range": Vector2(20, 60),
#   }
#
# Steps:
# 1. Create the enemy scene (see EnemyBase.gd for how to set it up).
# 2. Add a rule Dictionary to the _spawn_rules array inside spawn_enemies().
# 3. Make sure the enemy scene's root node is in the "enemy" group
#    (call add_to_group("enemy") in its _ready()).
# 4. Tune offset_range and the condition lambda as needed.
# 5. Adjust MAX_ENEMIES if your new enemy is common.
# ============================================================

extends Node2D

# ------------------------------------------------------------------
# CONSTANTS
# ------------------------------------------------------------------
## Width and height of a single tile in pixels.
const TILE_SIZE: int = 16
## Width of one chunk in tiles.
const CHUNK_WIDTH: int = 32
## Height of a chunk in tiles (world is much taller than the screen).
const CHUNK_HEIGHT: int = 128
## Chunk width in pixels.
const CHUNK_PIXEL_WIDTH: int = CHUNK_WIDTH * TILE_SIZE

## Maximum active enemies allowed near the player.
const MAX_ENEMIES: int = 12
## How often (seconds) the spawn check runs.
const SPAWN_INTERVAL: float = 1.5

# Sky colours for different times of day.
const SKY_DAY: Color    = Color(0.40, 0.65, 0.95)
const SKY_DAWN: Color   = Color(0.85, 0.50, 0.30)
const SKY_NIGHT: Color  = Color(0.04, 0.04, 0.12)
const SKY_DUSK: Color   = Color(0.70, 0.35, 0.20)

# ------------------------------------------------------------------
# EXPORTED / PUBLIC PROPERTIES
# ------------------------------------------------------------------
## How many chunks to keep loaded on each side of the player.
@export var RENDER_DISTANCE: int = 5

## Vertical tile-cull window — underground only.
## We NEVER cull sky rows (0..SURFACE_ROW) since the sky is mostly air and
## contains floating islands/castles the player should always be able to see.
## Only underground rows more than VERT_ROWS_BELOW below the player are culled.
const SURFACE_ROW: int = 90        ## row below which underground culling kicks in
const VERT_ROWS_BELOW: int = 60    ## underground rows below player to keep rendered

## Max new chunks applied per _update_chunks call.
## 2 chunks per frame: world appears in ~half the frames.
## Collision is built immediately (reuse body fix), so 2 per frame is safe.
const MAX_LOADS_PER_FRAME: int = 2

## All currently loaded Chunk nodes, keyed by chunk_x (integer column index).
var active_chunks: Dictionary = {}
## Tracks chunk indices that had edits and were unloaded (or were loaded from a save).
## Used so get_modified_chunks() can include them even when they're no longer active.
var _unloaded_dirty_cx: Dictionary = {}   # chunk_x (int) -> true

## Reference to the player node (found via group "player" in _ready).
var player: Node2D = null

# Vertical cull tracking — only recompute when player row changes enough.
var _last_cull_row: int = -9999

# Internal colour rect that fills the screen as the sky background.
var _sky_rect: ColorRect = null
# Sun node — same upper-right position as TitleBackground so it matches the menu.
var _sun_node: Panel = null

# CraftingUI instance — created on first open, reused after that.
var _crafting_ui: Node = null

# InventoryUI instance — created on first open, reused after that.
var _inventory_ui: Node = null

# FurnaceUI instance — created on first furnace open, reused after.
var _furnace_ui: Node = null

# CanvasLayer that hosts all screen-space UI (inventory, crafting).
var _ui_layer: CanvasLayer = null

# Plant growth: tracks world-tile positions of placed saplings.
# Key: Vector2i world tile pos.  Value: float seconds until growth.
var _plant_data: Dictionary = {}

# Camera shake state.
var _shake_time: float = 0.0
var _shake_mag: float = 0.0

# Tile cracking overlay state.
var _crack_tile: Vector2i = Vector2i(-9999, -9999)
var _crack_progress: float = 0.0
var _crack_overlay: Node2D = null

# Lighting.
var _canvas_modulate: CanvasModulate = null
var _placed_lights: Dictionary = {}       # "x,y" -> PointLight2D
var _ember_nodes:   Dictionary = {}       # "x,y" -> CPUParticles2D
var _light_texture: Texture2D = null
const _BASE_LIGHT_ENERGY: float = 1.2
var _weather_system: Node = null
var _quest_system: Node = null   # cached once in _ready — avoids per-frame path lookup
var _biome_check_cd: float = 0.0
var _depth_check_cd: float = 0.0   # throttles the per-frame _get_surface_y call
var _flicker_tick: float = 0.0

# Water simulation.
var _water_tick: float = 0.0
const WATER_TICK_RATE: float = 0.3
const WATER_MAX_SPREAD: int = 5
# Source water tiles placed by the player — these never disappear on their own.
var _water_sources: Dictionary = {}  # Vector2i -> true

# Accumulates delta for the plant growth tick (runs every 20 seconds).
var _plant_tick: float = 0.0
const PLANT_GROW_INTERVAL: float = 20.0   # seconds until sapling grows into tree

# ------------------------------------------------------------------
# SAVE / LOAD PROPERTIES
# These computed properties are read by SaveLoad.save_game() via .get().
# They delegate directly to the GameData autoload so there's no duplication.
# ------------------------------------------------------------------

## The seed used to generate this world. Matches GameData.world_seed.
var world_seed: int:
	get: return GameData.world_seed

## Current in-game day number. Matches GameData.day_number.
var current_day: int:
	get: return GameData.day_number

## Normalised time of day (0.0 = midnight, 0.5 = noon). Matches GameData.time_of_day.
var time_of_day: float:
	get: return GameData.time_of_day

## Seconds since last enemy spawn check.
var _spawn_timer: float = 0.0

## Autosave interval in seconds. 60 = 1 min, 300 = 5 min, 600 = 10 min,
## 900 = 15 min, 1800 = 30 min. Change in-game via PauseMenu settings.
var autosave_interval: float = 300.0   # default 5 minutes
var _autosave_timer: float = 0.0

## Shared TileSet resource used by all chunk TileMapLayers.
## Built once at startup from the procedurally-generated atlas texture.
var _shared_tileset: TileSet = null

# ------------------------------------------------------------------
# ASYNC CHUNK LOADING
# Chunk data (generation or save load) happens on WorkerThreadPool threads.
# The main thread only does scene-tree operations (add_child, set_cell, etc.)
# ------------------------------------------------------------------
## Pre-loaded chunk scene — avoids repeated disk reads on every chunk load.
var _chunk_scene: PackedScene = null
## Mutex protecting _pending_chunk_data and _chunks_queued.
var _chunk_gen_mutex: Mutex = Mutex.new()
## Pending chunk payloads ready to apply on the main thread.
## chunk_x -> {"tiles": Dictionary, "strips": Array}
var _pending_chunk_data: Dictionary = {}

## Passable tiles that get no collision shape. Must stay in sync with Chunk.gd.
const _STRIP_PASSABLE: Dictionary = {
	"water": true, "lava": true,
	"leaves_oak": true, "leaves_birch": true, "leaves_pine": true, "leaves_jungle": true,
	"torch": true, "torch_wall": true, "campfire": true, "tall_grass": true,
	"sapling_oak": true, "sapling_birch": true, "sapling_pine": true,
	"wheat_seeds": true, "wheat_crop": true,
	"vines": true, "mushroom_red": true, "mushroom_brown": true,
}
## Chunk indices currently being generated/loaded on a background thread.
var _chunks_queued: Dictionary = {}
## True once the spawn-area chunks are loaded and the player can move.
var _player_world_ready: bool = false

# ------------------------------------------------------------------
# SCENES — adjust paths to match your project layout.
# ------------------------------------------------------------------
const CHUNK_SCENE_PATH    := "res://scenes/Chunk.tscn"
const PLAYER_SCENE_PATH   := "res://scenes/Player.tscn"

# Enemy scene paths — add more here as you create them.
# HOW TO ADD A NEW ENEMY: create its scene then add a path constant here.
const ZOMBIE_SCENE_PATH        := "res://scenes/EnemyZombie.tscn"
const SKELETON_SCENE_PATH      := "res://scenes/EnemySkeleton.tscn"
const ELITE_ZOMBIE_SCENE_PATH  := "res://scenes/EnemyEliteZombie.tscn"
const ELITE_SKELETON_SCENE_PATH := "res://scenes/EnemyEliteSkeleton.tscn"
const BOSS_SCENE_PATH          := "res://scenes/EnemyBoss.tscn"
const CAVE_SPIDER_SCENE_PATH   := "res://scenes/EnemySpider.tscn"
const CAVE_SLIME_SCENE_PATH    := "res://scenes/EnemySlime.tscn"
const SHEEP_SCENE_PATH         := "res://scenes/AnimalSheep.tscn"
const COW_SCENE_PATH           := "res://scenes/AnimalCow.tscn"
const PIG_SCENE_PATH           := "res://scenes/AnimalPig.tscn"
const CHICKEN_SCENE_PATH       := "res://scenes/AnimalChicken.tscn"

const MAX_ANIMALS: int = 8

## Preloaded scene cache — populated in _ready() so spawn ticks never hit disk.
var _scene_cache: Dictionary = {}

# ------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------

func _ready() -> void:
	# Register in group so PauseMenu can find the camera for zoom adjustment.
	add_to_group("world")
	# Pre-load chunk scene once so _load_chunk never hits disk on each call.
	_chunk_scene = load(CHUNK_SCENE_PATH)
	# Preload all spawnable scenes so spawn ticks don't call load() (disk I/O).
	for path: String in [
		ZOMBIE_SCENE_PATH, SKELETON_SCENE_PATH, ELITE_ZOMBIE_SCENE_PATH,
		ELITE_SKELETON_SCENE_PATH, BOSS_SCENE_PATH, CAVE_SPIDER_SCENE_PATH,
		CAVE_SLIME_SCENE_PATH, SHEEP_SCENE_PATH, COW_SCENE_PATH,
		PIG_SCENE_PATH, CHICKEN_SCENE_PATH,
	]:
		_scene_cache[path] = load(path)
	_build_shared_tileset()
	_setup_sky()
	_spawn_player()

	# Restore save BEFORE generating initial chunks so world_seed and player
	# position are correct — chunks are generated with the right seed and
	# around the player's actual saved location.
	if SaveLoad.has_save():
		var save_data: Dictionary = SaveLoad.load_game()
		if not save_data.is_empty():
			_apply_save_data(save_data)
	else:
		# New game — guarantee clean state regardless of how we got here.
		GameData.reset_for_new_game()

	_generate_initial_chunks()

	# Auto-save when the scene tree is about to exit (app closed, scene changed, etc.)
	get_tree().root.tree_exiting.connect(_on_tree_exiting)

	# Connect the player's inventory toggle so we can show/hide the CraftingUI.
	if player != null and player.has_signal("inventory_toggled"):
		player.inventory_toggled.connect(_on_player_inventory_toggled)

	# InventoryUI "Open Crafting" button routes through this signal.
	GameData.open_crafting_requested.connect(_on_open_crafting_requested)

	# Create a dedicated CanvasLayer so inventory/crafting UIs stay in screen space
	# even when the game camera moves.
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	# Cache autoload singletons that are accessed in hot loops.
	_quest_system = get_node_or_null("/root/QuestSystem")

	# QuestHUD — quest tracker overlay (top-right corner).
	var qhud_scene: PackedScene = load("res://scenes/QuestHUD.tscn")
	if qhud_scene != null:
		var qhud := qhud_scene.instantiate()
		add_child(qhud)

	# Crack overlay draws crack lines over the block currently being mined.
	_crack_overlay = Node2D.new()
	_crack_overlay.name = "CrackOverlay"
	_crack_overlay.z_index = 10
	_crack_overlay.draw.connect(_on_crack_overlay_draw)
	add_child(_crack_overlay)


# ------------------------------------------------------------------
# PLANT GROWTH
# ------------------------------------------------------------------

## Ticks all registered plants and grows those that are ready.
func _grow_all_plants() -> void:
	var to_grow: Array = _plant_data.keys()
	for tile_pos in to_grow:
		var type: String = _plant_data.get(tile_pos, "")
		var world_px := Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
		var current: String = get_tile_at_world_pos(world_px)
		_plant_data.erase(tile_pos)

		if current in ["sapling_oak", "sapling_birch", "sapling_pine"]:
			_grow_sapling(tile_pos, type if type != "" else current)
		elif current == "wheat_seeds":
			# Wheat seeds mature into a crop block.
			set_tile_at_world_pos(world_px, "wheat_crop")


## Grows a sapling at world_tile_pos into a small tree.
func _grow_sapling(world_tile_pos: Vector2i, sapling_id: String) -> void:
	var world_px := Vector2(world_tile_pos.x * TILE_SIZE, world_tile_pos.y * TILE_SIZE)
	# Remove the sapling block.
	set_tile_at_world_pos(world_px, "")

	# Choose log and leaf types from sapling id.
	var log_id := "log_oak"
	var leaf_id := "leaves_oak"
	if "birch" in sapling_id:
		log_id = "log_birch"; leaf_id = "leaves_birch"
	elif "pine" in sapling_id:
		log_id = "log_pine"; leaf_id = "leaves_pine"

	var tx: int = world_tile_pos.x
	var ty: int = world_tile_pos.y
	var trunk_height: int = randi_range(4, 6)

	# Place trunk upward.
	for i in range(trunk_height):
		var px := Vector2((tx) * TILE_SIZE, (ty - i) * TILE_SIZE)
		if get_tile_at_world_pos(px) == "":
			set_tile_at_world_pos(px, log_id)

	# Place leaf canopy around the top 2 trunk blocks.
	var canopy_y: int = ty - trunk_height + 1
	for dy in range(-2, 2):
		for dx in range(-2, 3):
			if abs(dx) == 2 and abs(dy) == 1:
				continue  # trim corners
			var leaf_tile := Vector2i(tx + dx, canopy_y + dy)
			var lpx := Vector2(leaf_tile.x * TILE_SIZE, leaf_tile.y * TILE_SIZE)
			if get_tile_at_world_pos(lpx) == "":
				set_tile_at_world_pos(lpx, leaf_id)


## InventoryUI "Open Crafting" button → close inventory, open crafting.
func _on_open_crafting_requested() -> void:
	_close_inventory_ui()

	if _crafting_ui == null:
		var scene: PackedScene = load("res://scenes/CraftingUI.tscn")
		if scene == null:
			push_error("World: CraftingUI.tscn not found.")
			return
		_crafting_ui = scene.instantiate()
		_ui_layer.add_child(_crafting_ui)

	if _crafting_ui.has_method("open"):
		_crafting_ui.open(player, self)


## Applies a save dictionary (returned by SaveLoad.load_game()) to the world and player.
func _apply_save_data(data: Dictionary) -> void:
	# Restore world time / day
	if data.has("world_seed"):
		GameData.world_seed = int(data["world_seed"])
	if data.has("day"):
		GameData.day_number = int(data["day"])
	if data.has("time_of_day"):
		GameData.time_of_day = float(data["time_of_day"])

	# Pre-populate the SaveLoad chunk cache so chunks load modified tiles on spawn.
	# Also mark every saved chunk as "dirty-unloaded" so they survive the next save
	# even if the player never visits that area in this session.
	var chunks_data: Dictionary = data.get("chunks", {})
	for chunk_key in chunks_data.keys():
		var cx: int = int(chunk_key)
		SaveLoad.store_chunk_data(cx, chunks_data[chunk_key])
		_unloaded_dirty_cx[cx] = true

	# Restore player position, health, hunger, inventory.
	var player_data: Dictionary = data.get("player", {})
	if not player_data.is_empty() and player != null:
		if player.has_method("apply_save_data"):
			player.apply_save_data(player_data)

func _process(delta: float) -> void:
	# Reset the one-frame "a UI just closed" flag so Player.gd's guard doesn't
	# persist across frames — it only needs to fire for the single physics tick
	# that runs right after a UI closes itself via E/B/close-button.
	UIManager.ui_just_closed = false

	# Tick the global day/night clock.
	GameData.tick_time(delta)

	_update_sky_color()
	_update_chunks()
	_follow_player_with_camera()

	# Quest depth tracking — throttled to 2×/s (surface scan is expensive).
	_depth_check_cd -= delta
	if _depth_check_cd <= 0.0 and player != null and _quest_system != null:
		_depth_check_cd = 0.5
		var sy: float = _get_surface_y(player.global_position.x)
		if sy == 0.0:
			sy = player.global_position.y
		var depth_tiles: int = int((player.global_position.y - sy) / TILE_SIZE)
		if depth_tiles > 0:
			_quest_system.on_depth_updated(depth_tiles)

	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		spawn_enemies()

	# Autosave tick.
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		if player != null:
			SaveLoad.save_game(self, player)

	# Plant growth tick.
	_plant_tick += delta
	if _plant_tick >= PLANT_GROW_INTERVAL:
		_plant_tick = 0.0
		_grow_all_plants()

	_apply_shake(delta)

	_water_tick += delta
	if _water_tick >= WATER_TICK_RATE:
		_water_tick = 0.0
		_tick_water()

	# Light visibility + flicker — throttled to 10 fps (every 0.1 s).
	# Off-screen lights are hidden entirely so they cost zero render passes.
	_flicker_tick += delta
	if _flicker_tick >= 0.10 and not _placed_lights.is_empty():
		_flicker_tick = 0.0
		var vp := get_viewport()
		var vp_rect: Rect2 = vp.get_visible_rect()
		var cam_offset: Vector2 = vp.get_canvas_transform().origin
		# Grow slightly so lights at screen edge fade in before they're fully on-screen.
		var screen_rect: Rect2 = Rect2(-cam_offset, vp_rect.size).grow(TILE_SIZE * 3)
		var do_flicker: bool = GameData.fx.get("enabled", true) and GameData.fx.get("flicker", true)
		var t: float = Time.get_ticks_msec() / 1000.0
		for lkey: String in _placed_lights:
			var lnode: PointLight2D = _placed_lights[lkey]
			if not is_instance_valid(lnode):
				continue
			var in_view: bool = screen_rect.has_point(lnode.global_position)
			# Toggle visibility — hidden lights cost nothing in the renderer.
			if lnode.visible != in_view:
				lnode.visible = in_view
			if in_view and do_flicker:
				var sx: float = lnode.global_position.x * 0.09
				var sy: float = lnode.global_position.y * 0.07
				lnode.energy = _BASE_LIGHT_ENERGY * (1.0 + 0.13 * sin(t * 6.7 + sx) + 0.07 * sin(t * 12.4 + sy))

	# Weather biome update (every 4 s to avoid constant checks)
	if _weather_system != null:
		_biome_check_cd -= delta
		if _biome_check_cd <= 0.0:
			_biome_check_cd = 4.0
			if player != null and _weather_system.has_method("update_biome"):
				_weather_system.update_biome(get_biome_at_world_x(player.global_position.x))

# ------------------------------------------------------------------
# SETUP
# ------------------------------------------------------------------

## Build the shared TileSet resource that every chunk's TileMapLayer will use.
## Generates a procedural atlas texture, creates a TileSetAtlasSource from it,
## and assigns full-square collision shapes to all solid (non-passable) tiles.
func _build_shared_tileset() -> void:
	# Generate the 256×256 atlas image containing all block textures.
	var atlas_tex: ImageTexture = TileTextureGenerator.generate_atlas()

	# TileSet is used for RENDERING only.
	# Collision is handled by per-chunk StaticBody2D nodes (see Chunk._build_collision_body).
	_shared_tileset = TileSet.new()
	_shared_tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Register every atlas tile + a flip-H alternative (alt id 1) for each.
	for entry in TileTextureGenerator.ATLAS_LAYOUT:
		var ax: int = entry[1]
		var ay: int = entry[2]
		var ac := Vector2i(ax, ay)
		source.create_tile(ac)
		source.create_alternative_tile(ac, 1)           # alt 1 = flip horizontal
		var alt_data: TileData = source.get_tile_data(ac, 1)
		if alt_data != null:
			alt_data.flip_h = true

	# source_id 0 — Chunk.gd calls set_cell(..., 0, atlas_coords, alt).
	_shared_tileset.add_source(source, 0)

func _setup_sky() -> void:
	# Use a CanvasLayer so the ColorRect sits in screen space, not world space.
	# Layer -100 renders behind everything (chunks, player, enemies, HUD).
	var sky_canvas := CanvasLayer.new()
	sky_canvas.name = "SkyCanvas"
	sky_canvas.layer = -100
	add_child(sky_canvas)

	_sky_rect = ColorRect.new()
	_sky_rect.name = "SkyRect"
	# Anchor to fill the full viewport inside the CanvasLayer.
	_sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_canvas.add_child(_sky_rect)

	# Sun — same upper-right position as the title screen background
	# (vp * 0.82, vp.y * 0.10).  Hidden at night.
	var vp_size := get_viewport().get_visible_rect().size
	_sun_node = Panel.new()
	_sun_node.name = "Sun"
	_sun_node.size = Vector2(44, 44)
	_sun_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sun_style := StyleBoxFlat.new()
	sun_style.bg_color = Color(1.00, 0.97, 0.78, 1.0)
	sun_style.set_corner_radius_all(22)
	sun_style.set_border_width_all(0)
	_sun_node.add_theme_stylebox_override("panel", sun_style)
	_sun_node.position = Vector2(
		vp_size.x * 0.82 - 22.0,
		vp_size.y * 0.10 - 22.0)
	sky_canvas.add_child(_sun_node)

	# CanvasModulate globally tints all world CanvasItems (darkens at night).
	# HUD is in its own CanvasLayer so it is unaffected.
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "WorldLight"
	_canvas_modulate.color = Color.WHITE
	add_child(_canvas_modulate)

	_light_texture = _build_light_texture(32)

	# Weather / particle effects system
	var ws_script := load("res://scripts/WeatherSystem.gd")
	if ws_script:
		_weather_system = ws_script.new()
		add_child(_weather_system)

	_update_sky_color()

func _build_light_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - half, y - half).length() / half
			var a: float = clamp(1.0 - d * d, 0.0, 1.0)
			img.set_pixel(x, y, Color(a, a, a, 1.0))  # falloff in RGB — Godot 4 PointLight2D reads RGB not alpha
	return ImageTexture.create_from_image(img)

func _spawn_player() -> void:
	# If a player already exists (e.g. placed in editor), just find it.
	var existing := get_tree().get_nodes_in_group("player")
	if not existing.is_empty():
		player = existing[0] as Node2D
		return

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	if player_scene == null:
		push_error("World: Player scene not found at %s" % PLAYER_SCENE_PATH)
		return

	player = player_scene.instantiate() as Node2D
	# Surface is at tile row SURFACE_HEIGHT (80). Pixel Y = row * TILE_SIZE.
	# Spawn a few tiles above so gravity settles the player onto the ground.
	var surface_px_y: float = (GameData.SURFACE_HEIGHT - 3) * GameData.TILE_SIZE
	player.global_position = Vector2(0.0, surface_px_y)
	add_child(player)
	# Freeze player until spawn-area chunks are loaded so they don't fall through.
	player.set_physics_process(false)
	player.set_process(false)
	if not GameData.player_died.is_connected(_on_player_died):
		GameData.player_died.connect(_on_player_died)

func _generate_initial_chunks() -> void:
	# Load chunks around the player's actual position (may differ from 0 when loading a save).
	var pcx: int = 0
	if player != null:
		pcx = _get_chunk_x(player.global_position.x)
	for cx in range(pcx - RENDER_DISTANCE, pcx + RENDER_DISTANCE + 1):
		_load_chunk(cx)

## Moves the GameCamera to track the player each frame.
func _follow_player_with_camera() -> void:
	var camera: Camera2D = get_node_or_null("GameCamera")
	if camera == null or player == null:
		return
	camera.global_position = player.global_position

func camera_shake(magnitude: float, duration: float) -> void:
	_shake_mag = magnitude
	_shake_time = duration

func _apply_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time -= delta
	var cam: Camera2D = get_node_or_null("GameCamera")
	if cam:
		cam.offset = Vector2(randf_range(-_shake_mag, _shake_mag), randf_range(-_shake_mag, _shake_mag))
		if _shake_time <= 0.0:
			cam.offset = Vector2.ZERO

## Called by the player to update crack state each frame while mining.
func update_crack(tile_pos: Vector2i, progress: float) -> void:
	if tile_pos != _crack_tile or abs(progress - _crack_progress) > 0.01:
		_crack_tile = tile_pos
		_crack_progress = progress
		if _crack_overlay:
			_crack_overlay.queue_redraw()

## Clear the crack overlay (mining stopped or block broke).
func clear_crack() -> void:
	if _crack_tile == Vector2i(-9999, -9999):
		return
	_crack_tile = Vector2i(-9999, -9999)
	_crack_progress = 0.0
	if _crack_overlay:
		_crack_overlay.queue_redraw()

## Place a water source tile (called by bucket interaction in Player.gd).
func place_water_source(world_tile_pos: Vector2i) -> void:
	var px := Vector2(world_tile_pos.x * TILE_SIZE, world_tile_pos.y * TILE_SIZE)
	set_tile_at_world_pos(px, "water")
	_water_sources[world_tile_pos] = true

## Remove a water tile (called by bucket interaction in Player.gd).
func remove_water_tile(world_tile_pos: Vector2i) -> void:
	var px := Vector2(world_tile_pos.x * TILE_SIZE, world_tile_pos.y * TILE_SIZE)
	set_tile_at_world_pos(px, "")
	_water_sources.erase(world_tile_pos)

func _tick_water() -> void:
	# Only simulate player-placed water sources — world-gen water is static lakes
	# and does not need to flow (they are already in their final resting position).
	# Scanning every tile near the player was O(5000+) tile reads per tick → lag.
	if _water_sources.is_empty():
		return

	# Apply player-slow: if the player is standing in or adjacent to water, slow them.
	if player != null:
		var pp := Vector2i(int(player.global_position.x / TILE_SIZE),
				int(player.global_position.y / TILE_SIZE))
		var feet_px := Vector2(pp.x * TILE_SIZE, (pp.y + 1) * TILE_SIZE)
		var now_in_water: bool = get_tile_at_world_pos(feet_px) == "water"
		var was_in_water: bool = player.get_meta("in_water", false)
		if now_in_water and not was_in_water:
			AudioManager.play_splash()
		player.set_meta("in_water", now_in_water)

	# Simulate only the active source tiles (player-placed buckets).
	var sources_snapshot := _water_sources.keys()
	for src: Vector2i in sources_snapshot:
		var src_px := Vector2(src.x * TILE_SIZE, src.y * TILE_SIZE)
		# Spread down first, then sideways up to WATER_MAX_SPREAD.
		var below := Vector2i(src.x, src.y + 1)
		var below_px := Vector2(below.x * TILE_SIZE, below.y * TILE_SIZE)
		if get_tile_at_world_pos(below_px) in ["", "air"]:
			set_tile_at_world_pos(below_px, "water")
			_water_sources[below] = true
		else:
			for dir in [-1, 1]:
				for dist in range(1, WATER_MAX_SPREAD + 1):
					var side := Vector2i(src.x + dir * dist, src.y)
					var side_px := Vector2(side.x * TILE_SIZE, side.y * TILE_SIZE)
					var side_id := get_tile_at_world_pos(side_px)
					if side_id in ["", "air"]:
						set_tile_at_world_pos(side_px, "water")
						_water_sources[side] = true
						break
					elif side_id != "water":
						break

func _on_crack_overlay_draw() -> void:
	if _crack_tile == Vector2i(-9999, -9999) or _crack_progress < 0.3:
		return
	var ox: float = _crack_tile.x * TILE_SIZE
	var oy: float = _crack_tile.y * TILE_SIZE
	var s: float = TILE_SIZE
	var col := Color(0, 0, 0, 0.7)
	# Stage 1: one diagonal crack
	_crack_overlay.draw_line(Vector2(ox + 2, oy + 2), Vector2(ox + s - 2, oy + s - 2), col, 1.5)
	if _crack_progress > 0.6:
		# Stage 2: X pattern
		_crack_overlay.draw_line(Vector2(ox + s - 2, oy + 2), Vector2(ox + 2, oy + s - 2), col, 1.5)
	if _crack_progress > 0.85:
		# Stage 3: horizontal + vertical lines
		_crack_overlay.draw_line(Vector2(ox + s * 0.5, oy + 1), Vector2(ox + s * 0.5, oy + s - 1), col, 1.5)
		_crack_overlay.draw_line(Vector2(ox + 1, oy + s * 0.5), Vector2(ox + s - 1, oy + s * 0.5), col, 1.5)

# ------------------------------------------------------------------
# CHUNK MANAGEMENT
# ------------------------------------------------------------------

func _update_chunks() -> void:
	if player == null:
		return

	var center_cx: int = _get_chunk_x(player.global_position.x)

	# Apply completed background loads — capped per frame to spread main-thread work.
	_chunk_gen_mutex.lock()
	var pending_keys: Array = _pending_chunk_data.keys().duplicate()
	_chunk_gen_mutex.unlock()

	var applied: int = 0
	for cx in pending_keys:
		if applied >= MAX_LOADS_PER_FRAME:
			break
		if active_chunks.has(cx):
			_chunk_gen_mutex.lock()
			_pending_chunk_data.erase(cx)
			_chunk_gen_mutex.unlock()
			continue
		# Discard if player has moved away.
		if absi(cx - center_cx) > RENDER_DISTANCE + 1:
			_chunk_gen_mutex.lock()
			_pending_chunk_data.erase(cx)
			_chunk_gen_mutex.unlock()
			continue
		_chunk_gen_mutex.lock()
		var payload = _pending_chunk_data.get(cx, null)
		if payload != null:
			_pending_chunk_data.erase(cx)
		_chunk_gen_mutex.unlock()
		if payload != null:
			_apply_chunk(cx, payload["tiles"], payload["strips"])
			applied += 1

	# Queue background loads for any missing chunks in render range.
	for cx in range(center_cx - RENDER_DISTANCE, center_cx + RENDER_DISTANCE + 1):
		_load_chunk(cx)

	# Directional look-ahead: pre-load 1 extra chunk in the player's movement
	# direction so it arrives in _pending_chunk_data before the player reaches it.
	if player != null and "velocity" in player:
		if player.velocity.x > 50.0:
			_load_chunk(center_cx + RENDER_DISTANCE + 1)
		elif player.velocity.x < -50.0:
			_load_chunk(center_cx - RENDER_DISTANCE - 1)

	# Unload chunks outside render distance.
	var to_unload: Array = []
	for cx in active_chunks.keys():
		if absi(cx - center_cx) > RENDER_DISTANCE + 1:
			to_unload.append(cx)
	for cx in to_unload:
		_unload_chunk(cx)

	# Vertical tile culling — underground only, never hides sky structures.
	# Only update when player moves more than 6 rows vertically.
	var player_row: int = int(player.global_position.y / TILE_SIZE)
	if absi(player_row - _last_cull_row) >= 6:
		_last_cull_row = player_row
		# Sky (rows 0..SURFACE_ROW) is always fully rendered — mostly air + sky structures.
		# Underground: show from surface up to VERT_ROWS_BELOW below the player.
		var cull_max: int = maxi(player_row + VERT_ROWS_BELOW, SURFACE_ROW + 10)
		for chunk in active_chunks.values():
			if chunk.has_method("set_vertical_cull"):
				chunk.set_vertical_cull(0, cull_max)


## Computes horizontal collision run-data from tile_data with NO Godot objects.
## Safe to call from a WorkerThreadPool thread. Returns Array of [x0, x1, tile_y].
static func _compute_collision_strips(tile_data: Dictionary) -> Array:
	var strips: Array = []
	for tile_y in range(GameData.CHUNK_HEIGHT):
		var run_start: int = -1
		for tile_x in range(GameData.CHUNK_WIDTH):
			var raw: String = tile_data.get(Vector2i(tile_x, tile_y), "")
			var id: String = raw.get_slice("|", 0)
			var solid: bool = id != "" and not _STRIP_PASSABLE.has(id)
			if solid:
				if run_start < 0:
					run_start = tile_x
			else:
				if run_start >= 0:
					strips.append([run_start, tile_x - 1, tile_y])
					run_start = -1
		if run_start >= 0:
			strips.append([run_start, GameData.CHUNK_WIDTH - 1, tile_y])
	return strips


## Submits a chunk for background loading/generation if it isn't already in flight.
## Returns immediately — the result will appear in _pending_chunk_data when ready.
func _load_chunk(chunk_x: int) -> void:
	if active_chunks.has(chunk_x):
		return

	_chunk_gen_mutex.lock()
	var already: bool = _chunks_queued.has(chunk_x) or _pending_chunk_data.has(chunk_x)
	_chunk_gen_mutex.unlock()
	if already:
		return

	_chunk_gen_mutex.lock()
	_chunks_queued[chunk_x] = true
	_chunk_gen_mutex.unlock()

	# Capture values for the lambda (no closures over mutable state).
	var cx: int = chunk_x
	var seed: int = GameData.world_seed

	WorkerThreadPool.add_task(func() -> void:
		# All work here is pure data — no scene tree access.
		var saved = _get_saved_chunk_data(cx)
		var data: Dictionary = saved if saved != null else WorldGenerator.generate_chunk(cx, seed)
		# Pre-compute collision strips off the main thread so _apply_chunk can
		# build collision shapes immediately without iterating tiles on main thread.
		var strips: Array = _compute_collision_strips(data)
		_chunk_gen_mutex.lock()
		_pending_chunk_data[cx] = {"tiles": data, "strips": strips}
		_chunks_queued.erase(cx)
		_chunk_gen_mutex.unlock()
	)


## Applies pre-generated tile data to a new chunk node on the main thread.
## Kept to one call per frame (via MAX_LOADS_PER_FRAME) to avoid frame spikes.
## precomputed_strips — collision run data calculated on the worker thread.
func _apply_chunk(chunk_x: int, tile_data: Dictionary, precomputed_strips: Array) -> void:
	if active_chunks.has(chunk_x):
		return

	if _chunk_scene == null:
		push_error("World: _chunk_scene is null — was _ready() called?")
		return

	var chunk = _chunk_scene.instantiate()
	chunk.name = "Chunk_%d" % chunk_x

	# Set chunk_x and tileset BEFORE add_child so Chunk._ready() has correct values.
	chunk.chunk_x = chunk_x
	chunk.external_tileset = _shared_tileset
	# Mark initialized so _ready() skips _generate() — we supply tile data below.
	# Without this, _ready() runs WorldGenerator on the main thread, causing stutter.
	chunk._is_initialized = true

	add_child(chunk)
	active_chunks[chunk_x] = chunk

	# Set the cull range directly (bypasses the collision rebuild that set_vertical_cull
	# would schedule, since we're about to build collision from precomputed data).
	var cull_max: int = GameData.CHUNK_HEIGHT - 1
	if player != null:
		var pr: int = int(player.global_position.y / TILE_SIZE)
		cull_max = maxi(pr + VERT_ROWS_BELOW, SURFACE_ROW + 10)
		_last_cull_row = pr
	chunk._cull_min_row = 0
	chunk._cull_max_row = cull_max

	# Build collision immediately from precomputed strips — player has solid ground
	# in the very same frame this chunk appears, before tile sync even starts.
	chunk.build_collision_from_strips(precomputed_strips, 0, cull_max)

	if chunk.has_method("load_from_save"):
		chunk.load_from_save(tile_data)

	# Unfreeze player once the 3 chunks surrounding their spawn position are loaded.
	if not _player_world_ready and player != null:
		var pcx: int = _get_chunk_x(player.global_position.x)
		if active_chunks.has(pcx - 1) and active_chunks.has(pcx) and active_chunks.has(pcx + 1):
			_player_world_ready = true
			player.set_physics_process(true)
			player.set_process(true)

	# Defer water registration and light spawning to the next frame so the
	# current frame only bears the cost of add_child + the first tile-sync batch.
	call_deferred("_post_chunk_init", chunk_x, chunk, tile_data)


## Called the frame after _apply_chunk so water/light scanning doesn't share
## a frame with add_child + the first tile-sync batch.
func _post_chunk_init(chunk_x: int, chunk: Node, tile_data: Dictionary) -> void:
	if not is_instance_valid(chunk):
		return
	# Register water tiles for the physics simulation.
	var x_off: int = chunk_x * GameData.CHUNK_WIDTH
	for local_pos: Vector2i in tile_data:
		if tile_data[local_pos] == "water":
			_water_sources[Vector2i(x_off + local_pos.x, local_pos.y)] = true
	# Spawn lights for any torch/campfire tiles placed by WorldGenerator.
	_spawn_chunk_lights(chunk_x, chunk)


func _spawn_chunk_lights(chunk_x: int, chunk: Node) -> void:
	if not chunk.has_method("to_save_data"):
		return
	var tile_dict: Dictionary = chunk.to_save_data()
	var x_offset: int = chunk_x * GameData.CHUNK_WIDTH
	for local_pos: Vector2i in tile_dict:
		var raw_id: String = str(tile_dict.get(local_pos, ""))
		var base_id: String = raw_id.split("|")[0] if "|" in raw_id else raw_id
		var data: Dictionary = ItemDB.get_item(base_id)
		var light_r: float = data.get("light_radius", 0.0)
		if light_r > 0.0:
			var world_tile := Vector2i(x_offset + local_pos.x, local_pos.y)
			var world_px   := Vector2(world_tile.x * TILE_SIZE, world_tile.y * TILE_SIZE)
			_spawn_block_light(world_tile, world_px, light_r,
					data.get("light_color", Color(1.0, 0.85, 0.5)))


func _unload_chunk(chunk_x: int) -> void:
	if not active_chunks.has(chunk_x):
		return

	var chunk = active_chunks[chunk_x]

	# Call to_save_data() once and reuse — avoids duplicating the dict twice.
	var tile_data: Dictionary = chunk.to_save_data() if chunk.has_method("to_save_data") else {}

	# Persist tile data to the in-memory cache for fast reload.
	_store_chunk_data(chunk_x, tile_data)

	# If this chunk was modified, mark it so get_modified_chunks() includes it on save.
	if chunk.get("is_dirty"):
		_unloaded_dirty_cx[chunk_x] = true

	# Remove water tiles from the simulation.
	var x_off: int = chunk_x * GameData.CHUNK_WIDTH
	for local_pos: Vector2i in tile_data:
		if tile_data[local_pos] == "water":
			_water_sources.erase(Vector2i(x_off + local_pos.x, local_pos.y))

	# Clean up lights/embers for this chunk's tiles.
	for local_pos: Vector2i in tile_data:
		var lkey: String = "%d,%d" % [x_off + local_pos.x, local_pos.y]
		if _placed_lights.has(lkey):
			_placed_lights[lkey].queue_free()
			_placed_lights.erase(lkey)
		if _ember_nodes.has(lkey):
			_ember_nodes[lkey].queue_free()
			_ember_nodes.erase(lkey)

	chunk.queue_free()
	active_chunks.erase(chunk_x)

# ------------------------------------------------------------------
# TILE ACCESS (world-space pixel coordinates)
# ------------------------------------------------------------------

## Returns the item_id string of the tile at the given world pixel position,
## or an empty string if the chunk isn't loaded or no tile exists.
func get_tile_at_world_pos(world_pos: Vector2) -> String:
	var cx: int = _get_chunk_x(world_pos.x)
	if not active_chunks.has(cx):
		return ""

	var chunk = active_chunks[cx]
	var local_tile: Vector2i = _get_local_tile(world_pos)

	if chunk.has_method("get_tile"):
		return chunk.get_tile(local_tile)
	return ""

## Sets the tile at the given world pixel position to item_id.
## Pass an empty string to remove the tile.
func set_tile_at_world_pos(world_pos: Vector2, item_id: String) -> void:
	var cx: int = _get_chunk_x(world_pos.x)
	if not active_chunks.has(cx):
		return   # chunk not loaded — silently ignore (normal at world edges)

	var chunk = active_chunks[cx]
	var local_tile: Vector2i = _get_local_tile(world_pos)

	if chunk.has_method("set_tile"):
		chunk.set_tile(local_tile, item_id)

## Returns a Dictionary of { chunk_x -> save_data } for all currently loaded chunks
## that carry unsaved modifications. Pass this to SaveLoad to persist the world.
func get_modified_chunks() -> Dictionary:
	var result: Dictionary = {}

	# Active dirty chunks — most up-to-date data.
	for cx in active_chunks.keys():
		var chunk = active_chunks[cx]
		if chunk.has_method("to_save_data") and chunk.get("is_dirty"):
			result[cx] = chunk.to_save_data()

	# Unloaded dirty chunks — previously edited and cached; include anything
	# not already covered by an active chunk above.
	for cx in _unloaded_dirty_cx.keys():
		if result.has(cx):
			continue  # active chunk data is fresher
		var cached = SaveLoad.get_chunk_data(cx)
		if cached != null:
			result[cx] = cached

	return result

# ------------------------------------------------------------------
# COORDINATE HELPERS
# ------------------------------------------------------------------

## Converts a world pixel X coordinate to the chunk column index.
func _get_chunk_x(world_x: float) -> int:
	return floori(world_x / CHUNK_PIXEL_WIDTH)

## Returns the tile coordinate (column, row) within its chunk for a world pixel position.
func _get_local_tile(world_pos: Vector2) -> Vector2i:
	var cx: int = _get_chunk_x(world_pos.x)
	var local_x: int = floori((world_pos.x - cx * CHUNK_PIXEL_WIDTH) / TILE_SIZE)
	var local_y: int = floori(world_pos.y / TILE_SIZE)
	return Vector2i(local_x, local_y)

## Estimates the world Y pixel coordinate of the surface directly above world_x.
## Uses get_tile_at_world_pos — scan downward until we hit a solid tile.
func _get_surface_y(world_x: float) -> float:
	for row in range(0, CHUNK_HEIGHT):
		var test_pos := Vector2(world_x, row * TILE_SIZE)
		var tile := get_tile_at_world_pos(test_pos)
		if tile != "" and tile != "air":
			return test_pos.y
	return 0.0  # Fallback if no tile found.

# ------------------------------------------------------------------
# DAY / NIGHT SKY
# ------------------------------------------------------------------

func _update_sky_color() -> void:
	if _sky_rect == null:
		return

	# GameData.time_of_day is expected to be a float in [0.0, 1.0)
	# representing fraction of the 24-hour day (0 = midnight, 0.5 = noon).
	var t: float = GameData.time_of_day  # 0.0 – 1.0

	# Map time to a sky colour using key points:
	#   0.00  = midnight (night)
	#   0.20  = dawn
	#   0.25  = sunrise (day starts)
	#   0.50  = noon
	#   0.75  = sunset (day ends)
	#   0.80  = dusk
	#   1.00  = midnight again
	var sky_color: Color
	if t < 0.20:
		sky_color = SKY_NIGHT
	elif t < 0.25:
		sky_color = SKY_NIGHT.lerp(SKY_DAWN, (t - 0.20) / 0.05)
	elif t < 0.30:
		sky_color = SKY_DAWN.lerp(SKY_DAY, (t - 0.25) / 0.05)
	elif t < 0.70:
		sky_color = SKY_DAY
	elif t < 0.75:
		sky_color = SKY_DAY.lerp(SKY_DUSK, (t - 0.70) / 0.05)
	elif t < 0.80:
		sky_color = SKY_DUSK.lerp(SKY_NIGHT, (t - 0.75) / 0.05)
	else:
		sky_color = SKY_NIGHT

	_sky_rect.color = sky_color

	# Show sun during day, hide at night.
	if _sun_node != null:
		_sun_node.visible = (t >= 0.22 and t < 0.78)

	# Drive world darkness: full bright at noon, dark at night.
	if _canvas_modulate != null:
		var brightness: float
		if t < 0.20:
			brightness = 0.15
		elif t < 0.30:
			brightness = lerp(0.15, 1.0, (t - 0.20) / 0.10)
		elif t < 0.70:
			brightness = 1.0
		elif t < 0.80:
			brightness = lerp(1.0, 0.15, (t - 0.70) / 0.10)
		else:
			brightness = 0.15
		_canvas_modulate.color = Color(brightness, brightness, brightness + 0.05)

## Returns true when it is currently night time (enemies spawn on surface).
func _is_night() -> bool:
	var t: float = GameData.time_of_day
	return t < 0.25 or t >= 0.75

# ------------------------------------------------------------------
# PLAYER-FACING WORLD API  (called by Player.gd)
# ------------------------------------------------------------------

## Returns the block data dictionary for the tile at world-pixel position,
## including hardness and mine_level. Used by Player mining logic.
## Strips the flip suffix ("|h") from a stored tile id so ItemDB lookups work.
static func _base_id(id: String) -> String:
	var idx := id.find("|")
	return id.left(idx) if idx >= 0 else id

func get_block_data(world_tile_pos: Vector2i) -> Dictionary:
	var world_px := Vector2(world_tile_pos.x * TILE_SIZE, world_tile_pos.y * TILE_SIZE)
	var raw: String = get_tile_at_world_pos(world_px)
	if raw == "":
		return {}
	var id := _base_id(raw)
	var item := ItemDB.get_item(id)
	return {
		"id": id,
		"hardness": _get_hardness(id),
		"mine_level": item.get("mine_level", 0),
	}

## Returns true if a solid non-air tile exists at the world tile coordinate.
## Water is treated as non-solid so mining/building can target through it.
func has_block(world_tile_pos: Vector2i) -> bool:
	var world_px := Vector2(world_tile_pos.x * TILE_SIZE, world_tile_pos.y * TILE_SIZE)
	var id: String = get_tile_at_world_pos(world_px)
	return id != "" and id != "air" and id != "water"

## Removes the tile at world_tile_pos and returns an Array of drop dicts.
## Called by Player when mining progress completes.
func mine_block(world_tile_pos: Vector2i) -> Array:
	var world_px := Vector2(world_tile_pos.x * TILE_SIZE, world_tile_pos.y * TILE_SIZE)
	var raw: String = get_tile_at_world_pos(world_px)
	var id := _base_id(raw)
	if id == "" or id == "air" or id == "bedrock":
		return []
	set_tile_at_world_pos(world_px, "")

	# Remove any light node placed by this tile.
	var lkey: String = "%d,%d" % [world_tile_pos.x, world_tile_pos.y]
	if _placed_lights.has(lkey):
		_placed_lights[lkey].queue_free()
		_placed_lights.erase(lkey)
	if _ember_nodes.has(lkey):
		_ember_nodes[lkey].queue_free()
		_ember_nodes.erase(lkey)

	# Wheat crop yields wheat + seeds so the crop system is self-sustaining.
	if id == "wheat_crop":
		return [
			{"id": "wheat",       "count": 1},
			{"id": "wheat_seeds", "count": randi_range(1, 2)},
		]

	var drop := ItemDB.get_drop(id)
	var results: Array = []
	if drop[0] != "" and drop[1] > 0:
		results.append({"id": drop[0], "count": drop[1]})
	# Bonus drop (e.g. apples from oak leaves)
	var bonus := ItemDB._pending_bonus_drop
	if bonus.size() == 2 and bonus[0] != "" and bonus[1] > 0:
		results.append({"id": bonus[0], "count": bonus[1]})
	return results

## Places item_id block at world_tile_pos if the tile is empty.
## Returns true on success, false if tile already occupied or item not placeable.
## Place item_id at world_tile_pos. item_id may include a flip suffix (e.g. "stairs_stone|h").
func place_block(world_tile_pos: Vector2i, item_id: String) -> bool:
	var base_id := _base_id(item_id)
	if not ItemDB.is_placeable(base_id):
		return false
	var world_px := Vector2(world_tile_pos.x * TILE_SIZE, world_tile_pos.y * TILE_SIZE)
	var existing: String = get_tile_at_world_pos(world_px)
	if existing == "water":
		# Placing a block displaces water — remove the water source first.
		remove_water_tile(world_tile_pos)
	elif existing != "" and existing != "air":
		return false  # something already there

	# Wheat seeds must be planted on top of a dirt or grass block.
	if base_id == "wheat_seeds":
		var below_px := Vector2(world_px.x, world_px.y + TILE_SIZE)
		var below: String = get_tile_at_world_pos(below_px)
		if below not in ["dirt", "grass", "snow_grass"]:
			return false

	set_tile_at_world_pos(world_px, item_id)  # store full id (with |h flip suffix if present)

	# Register saplings and wheat seeds for automatic growth.
	if base_id in ["sapling_oak", "sapling_birch", "sapling_pine", "wheat_seeds"]:
		_plant_data[world_tile_pos] = base_id

	# Spawn a PointLight2D for light-emitting blocks (torch, campfire, etc.)
	var item_data: Dictionary = ItemDB.get_item(base_id)
	var light_r: float = item_data.get("light_radius", 0.0)
	if light_r > 0.0:
		_spawn_block_light(world_tile_pos, world_px, light_r, item_data.get("light_color", Color(1.0, 0.85, 0.5)))

	return true

## Returns true if the player is within 3 tiles of any crafting_table block.
## Called by CraftingUI to unlock table-only recipes.
## Scans tiles around the player position directly (no node group needed).
func is_player_near_crafting_table() -> bool:
	if player == null:
		return false
	var player_tile := Vector2i(
		int(player.global_position.x / TILE_SIZE),
		int(player.global_position.y / TILE_SIZE)
	)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var check := player_tile + Vector2i(dx, dy)
			var world_px := Vector2(check.x * TILE_SIZE, check.y * TILE_SIZE)
			if get_tile_at_world_pos(world_px) == "crafting_table":
				return true
	return false

## Returns true if the player is within 3 tiles of any furnace block.
## Called by FurnaceUI and Player.gd to allow furnace interaction.
func is_player_near_furnace() -> bool:
	if player == null:
		return false
	var player_tile := Vector2i(
		int(player.global_position.x / TILE_SIZE),
		int(player.global_position.y / TILE_SIZE)
	)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var check := player_tile + Vector2i(dx, dy)
			var world_px := Vector2(check.x * TILE_SIZE, check.y * TILE_SIZE)
			if get_tile_at_world_pos(world_px) == "furnace":
				return true
	return false


## Opens the FurnaceUI for `player`.
## Called from Player.gd's interact handler when the player faces a furnace tile.
func open_furnace_ui() -> void:
	if not is_player_near_furnace():
		return
	# Close any other open UIs first.
	_close_inventory_ui()

	if _furnace_ui == null:
		var scene: PackedScene = load("res://scenes/FurnaceUI.tscn")
		if scene == null:
			push_error("World: FurnaceUI.tscn not found.")
			return
		_furnace_ui = scene.instantiate()
		_ui_layer.add_child(_furnace_ui)
		if _furnace_ui.has_signal("closed"):
			_furnace_ui.closed.connect(func() -> void: UIManager.force_close())

	if _furnace_ui.has_method("open"):
		_furnace_ui.open(player)


## Returns mining hardness for a given item id.
## Returns the biome name ("plains","forest","snow","desert") at a world pixel X.
## Mirrors WorldGenerator._get_biome() logic.
func get_biome_at_world_x(world_px_x: float) -> String:
	var world_tile_x: int = int(world_px_x / GameData.TILE_SIZE)
	var pos: int = posmod(world_tile_x, 512)
	if pos < 100:   return "plains"
	elif pos < 200: return "forest"
	elif pos < 280: return "snow"
	elif pos < 400: return "desert"
	else:           return "plains"


func _spawn_block_light(tile_pos: Vector2i, world_px: Vector2, radius: float, col: Color) -> void:
	var lkey: String = "%d,%d" % [tile_pos.x, tile_pos.y]
	if _placed_lights.has(lkey):
		return  # already lit
	var light := PointLight2D.new()
	light.texture       = _light_texture
	light.color         = col
	light.energy        = 1.2
	light.texture_scale = radius  # 32px texture, half=16 = TILE_SIZE, so scale = radius_tiles
	light.shadow_enabled = false
	light.global_position = world_px + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	add_child(light)
	_placed_lights[lkey] = light

	# Ember particles for fire/campfire sources
	if GameData.fx.get("enabled", true) and GameData.fx.get("embers", true):
		var is_big: bool = radius >= 9.0   # campfire vs torch
		var ep := CPUParticles2D.new()
		ep.emitting               = true
		ep.amount                 = GameData.fx_particles(12 if is_big else 4)
		ep.lifetime               = 2.5
		ep.emission_shape         = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		ep.emission_rect_extents  = Vector2(4.0, 2.0)
		ep.direction              = Vector2(0.0, -1.0)
		ep.spread                 = 22.0
		ep.initial_velocity_min   = 12.0 if is_big else 6.0
		ep.initial_velocity_max   = 30.0 if is_big else 15.0
		ep.gravity                = Vector2(3.0, -4.0)
		ep.scale_amount_min       = 1.0
		ep.scale_amount_max       = 2.5
		ep.color                  = Color(1.0, 0.50, 0.08, 0.90)
		ep.global_position        = world_px + Vector2(GameData.TILE_SIZE * 0.5, 2.0)
		add_child(ep)
		_ember_nodes[lkey] = ep

## Lower = faster to mine. Adjust these values to change how long blocks take.
## HOW TO CHANGE BLOCK HARDNESS: edit the match statement below.
func _get_hardness(id: String) -> float:
	match id:
		"grass", "dirt", "sand", "gravel", "snow", "snow_grass", "tall_grass":
			return 0.5
		"stone", "cobblestone", "clay":
			return 1.5
		"coal_ore":
			return 2.0
		"iron_ore":
			return 3.0
		"gold_ore":
			return 4.0
		"diamond_ore", "emerald_ore", "ruby_ore":
			return 6.0
		"log_oak", "log_birch", "log_pine", "planks_oak", "planks_birch":
			return 1.0
		"leaves_oak", "leaves_birch", "leaves_pine":
			return 0.2
		"ice":
			return 0.5
		"bedrock":
			return 9999.0
		_:
			return 1.0

# ------------------------------------------------------------------
# ENEMY SPAWNING
# ------------------------------------------------------------------

## Called every SPAWN_INTERVAL seconds.
## Checks each spawn rule and instantiates enemies as needed.
func spawn_enemies() -> void:
	if player == null:
		return

	var player_pos: Vector2 = player.global_position

	# Despawn entities that are beyond the loaded world — keeps the pool fresh
	# and prevents stale enemies/animals accumulating far from the player.
	var DESPAWN_DIST: float = CHUNK_PIXEL_WIDTH * (RENDER_DISTANCE + 2)  # ~3584 px
	for entity in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(entity) and not entity.get("_death_triggered"):
			if absf(entity.global_position.x - player_pos.x) > DESPAWN_DIST:
				entity.queue_free()
	for entity in get_tree().get_nodes_in_group("animals"):
		if is_instance_valid(entity) and not entity.get("_dead"):
			if absf(entity.global_position.x - player_pos.x) > DESPAWN_DIST:
				entity.queue_free()

	# surface_y: try the dynamic scan; fall back to player's own Y so surface
	# checks never reject a player who IS on the surface.
	var surface_y: float = _get_surface_y(player_pos.x)
	if surface_y == 0.0:
		surface_y = player_pos.y  # fallback: treat player's Y as the surface

	# "near surface" = player within 25 tiles of the reference surface line
	var near_surface: bool = absf(player_pos.y - surface_y) <= TILE_SIZE * 25

	# "underground" = player more than 15 tiles below the surface
	var underground: bool = player_pos.y > surface_y + TILE_SIZE * 15

	# "in sky" = player above the surface by at least 8 tiles (inside floating island/castle region)
	var in_sky: bool = player_pos.y < surface_y - TILE_SIZE * 8

	# Count all active enemies — cache both group queries here so the lambdas
	# below reference the local var instead of scanning the tree again each time.
	var active_enemy_count: int = get_tree().get_nodes_in_group("enemy").size()
	var active_boss_count: int  = get_tree().get_nodes_in_group("boss_enemy").size()
	if active_enemy_count >= MAX_ENEMIES:
		return

	# ----------------------------------------------------------------
	# SPAWN RULES
	# ----------------------------------------------------------------
	var _spawn_rules: Array = [
		# ── Spiders — surface day AND night (always present for daytime combat) ──
		{
			"scene": CAVE_SPIDER_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return near_surface and randf() < (0.80 if _is_night() else 0.65),
			"offset_range": Vector2(14, 45),
		},
		{
			"scene": CAVE_SPIDER_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return near_surface and randf() < (0.65 if _is_night() else 0.45),
			"offset_range": Vector2(22, 60),
		},
		# ── Zombies — night + surface ───────────────────────────────────────────
		{
			"scene": ZOMBIE_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return _is_night() and near_surface and randf() < 0.80,
			"offset_range": Vector2(16, 55),
		},
		{
			"scene": ZOMBIE_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return _is_night() and near_surface and randf() < 0.60,
			"offset_range": Vector2(28, 70),
		},
		# ── Skeletons — night + surface ─────────────────────────────────────────
		{
			"scene": SKELETON_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return _is_night() and near_surface and randf() < 0.75,
			"offset_range": Vector2(20, 52),
		},
		# ── Underground spiders ─────────────────────────────────────────────────
		{
			"scene": CAVE_SPIDER_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return underground and randf() < 0.70,
			"offset_range": Vector2(12, 45),
		},
		# ── Underground slimes ──────────────────────────────────────────────────
		{
			"scene": CAVE_SLIME_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return underground and randf() < 0.55,
			"offset_range": Vector2(10, 40),
		},
		# ── Pack zombies — extra night zombie so mobs arrive in small groups ────
		# Fires in the same tick as the main zombie rule → natural grouping.
		{
			"scene": ZOMBIE_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return _is_night() and near_surface and randf() < 0.50,
			"offset_range": Vector2(18, 48),
		},
		{
			"scene": ZOMBIE_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return _is_night() and near_surface and randf() < 0.30,
			"offset_range": Vector2(14, 36),
		},
		# ── Elite Zombies — night, after 3 kills (earlier pressure) ─────────────
		{
			"scene": ELITE_ZOMBIE_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return _is_night() and near_surface \
					and GameData.total_enemy_kills >= 3 and randf() < 0.40,
			"offset_range": Vector2(20, 55),
		},
		# ── Elite Skeletons — night, after 5 kills ──────────────────────────────
		{
			"scene": ELITE_SKELETON_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return _is_night() and near_surface \
					and GameData.total_enemy_kills >= 5 and randf() < 0.40,
			"offset_range": Vector2(25, 60),
		},
		# ── Elite underground spiders — appear after 8 kills ────────────────────
		{
			"scene": CAVE_SPIDER_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return underground \
					and GameData.total_enemy_kills >= 8 and randf() < 0.45,
			"offset_range": Vector2(15, 50),
		},
		# ── Elite slime pack underground — after 12 kills ────────────────────────
		{
			"scene": CAVE_SLIME_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return underground \
					and GameData.total_enemy_kills >= 12 and randf() < 0.40,
			"offset_range": Vector2(10, 35),
		},
		# ── Boss — deep underground, after 15 kills (was 20), up to 3 at once ───
		{
			"scene": BOSS_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return underground \
					and GameData.total_enemy_kills >= 15 \
					and active_boss_count < 3 \
					and randf() < 0.14,
			"offset_range": Vector2(12, 38),
		},
		# ── Sky Castle Elites — spawn when player is in sky (floating castle region) ──
		{
			"scene": ELITE_ZOMBIE_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return in_sky and GameData.total_enemy_kills >= 3 and randf() < 0.65,
			"offset_range": Vector2(8, 30),
		},
		{
			"scene": ELITE_SKELETON_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return in_sky and GameData.total_enemy_kills >= 3 and randf() < 0.55,
			"offset_range": Vector2(8, 28),
		},
		# ── Sky Boss — rare boss inside sky castles, after 12 kills ─────────────
		{
			"scene": BOSS_SCENE_PATH, "group": "enemy",
			"condition": func(_p: Vector2) -> bool:
				return in_sky \
					and GameData.total_enemy_kills >= 12 \
					and active_boss_count < 3 \
					and randf() < 0.10,
			"offset_range": Vector2(6, 20),
		},
		# ---- ADD NEW RULES ABOVE THIS LINE ----
	]

	# ── Animal spawning (separate cap) ──────────────────────────────────────
	# Animals only roam during the day. Spawn at varied distances so herds
	# aren't always bunched directly beside the player.
	var active_animal_count: int = get_tree().get_nodes_in_group("animals").size()
	if not _is_night() and active_animal_count < MAX_ANIMALS:
		var spawns_this_tick: int = 2 if active_animal_count < MAX_ANIMALS / 2 else 1
		var animal_paths: Array = [SHEEP_SCENE_PATH, COW_SCENE_PATH, PIG_SCENE_PATH, CHICKEN_SCENE_PATH]
		for _i in range(spawns_this_tick):
			if active_animal_count >= MAX_ANIMALS:
				break
			var chosen_path: String = animal_paths[randi() % animal_paths.size()]
			var animal_scene := _scene_cache.get(chosen_path) as PackedScene
			if animal_scene:
				var offset_x: float = randf_range(30.0, 150.0) * (1.0 if randf() > 0.5 else -1.0)
				var spawn_x: float = player_pos.x + offset_x * TILE_SIZE
				var sy: float = _get_surface_y(spawn_x)
				if sy <= 0.0:
					continue
				var animal: Node2D = animal_scene.instantiate() as Node2D
				animal.global_position = Vector2(spawn_x, sy - TILE_SIZE)
				add_child(animal)
				active_animal_count += 1

	# ── Enemy container (shared parent to keep the tree tidy) ───────────────
	var enemy_container: Node = get_node_or_null("EnemyContainer")

	# Attempt to spawn one enemy per passing rule (capped by MAX_ENEMIES).
	for rule: Dictionary in _spawn_rules:
		if active_enemy_count >= MAX_ENEMIES:
			break
		if not rule["condition"].call(player_pos):
			continue
		var min_t: float = rule["offset_range"].x
		var max_t: float = rule["offset_range"].y
		var off: float = randf_range(min_t, max_t) * (1.0 if randi() % 2 == 0 else -1.0)
		var sx: float = player_pos.x + off * TILE_SIZE
		if not active_chunks.has(_get_chunk_x(sx)):
			continue
		var escene: PackedScene = _scene_cache.get(rule["scene"]) as PackedScene
		if escene == null:
			push_warning("World.spawn_enemies: scene not found: %s" % rule["scene"])
			continue
		var sy_surf: float = _get_surface_y(sx)
		var sy: float
		if underground:
			sy = player_pos.y
		elif sy_surf > 0.0:
			sy = sy_surf - TILE_SIZE
		else:
			sy = player_pos.y
		var enemy = escene.instantiate()
		enemy.global_position = Vector2(sx, sy)
		if enemy_container:
			enemy_container.add_child(enemy)
		else:
			add_child(enemy)
		active_enemy_count += 1

	# ── Ambient far-range spawning ──────────────────────────────────────────
	if randf() < 0.30 and active_enemy_count < MAX_ENEMIES:
		var far_scene_path: String = ""
		var far_min: float = 90.0
		var far_max: float = 220.0
		if near_surface and _is_night():
			far_scene_path = ZOMBIE_SCENE_PATH if randf() > 0.5 else SKELETON_SCENE_PATH
		elif near_surface:
			far_scene_path = CAVE_SPIDER_SCENE_PATH
		elif underground:
			far_scene_path = CAVE_SPIDER_SCENE_PATH if randf() > 0.5 else CAVE_SLIME_SCENE_PATH
			far_min = 80.0; far_max = 180.0
		if far_scene_path != "":
			var foff: float = randf_range(far_min, far_max) * (1.0 if randi() % 2 == 0 else -1.0)
			var fsx: float = player_pos.x + foff * TILE_SIZE
			if active_chunks.has(_get_chunk_x(fsx)):
				var fscene: PackedScene = _scene_cache.get(far_scene_path) as PackedScene
				if fscene != null:
					var fsy_surf: float = _get_surface_y(fsx)
					var fsy: float = player_pos.y if (underground or fsy_surf <= 0.0) \
						else fsy_surf - TILE_SIZE
					var fenemy = fscene.instantiate()
					fenemy.global_position = Vector2(fsx, fsy)
					if enemy_container:
						enemy_container.add_child(fenemy)
					else:
						add_child(fenemy)
					active_enemy_count += 1

# ------------------------------------------------------------------
# SAVE / LOAD INTEGRATION
# ------------------------------------------------------------------
# These stubs delegate to a SaveLoad autoload (not included here).
# Replace the bodies with your actual persistence calls.

func _get_saved_chunk_data(chunk_x: int):
	return SaveLoad.get_chunk_data(chunk_x)

func _store_chunk_data(chunk_x: int, data) -> void:
	SaveLoad.store_chunk_data(chunk_x, data)

# ------------------------------------------------------------------
# AUTO-SAVE
# ------------------------------------------------------------------

## Triggered when the game is about to quit or the scene exits.
## Writes the current world and player state to disk automatically.
func _on_tree_exiting() -> void:
	SaveLoad.save_game(self, player)

# ------------------------------------------------------------------
# INVENTORY UI & CRAFTING UI
# ------------------------------------------------------------------

## Called when the player presses E.  Opens InventoryUI; closes it when toggling off.
func _on_player_inventory_toggled(open: bool) -> void:
	if open:
		_open_inventory_ui()
	else:
		_close_inventory_ui()


func _open_inventory_ui() -> void:
	# Close any other open UI first (one panel at a time).
	if _crafting_ui != null and _crafting_ui.has_method("close"):
		_crafting_ui.close()
	if _furnace_ui != null and is_instance_valid(_furnace_ui) and _furnace_ui.has_method("close"):
		_furnace_ui.close()

	if _inventory_ui == null:
		var scene: PackedScene = load("res://scenes/InventoryUI.tscn")
		if scene == null:
			push_error("World: InventoryUI.tscn not found.")
			return
		_inventory_ui = scene.instantiate()
		_ui_layer.add_child(_inventory_ui)

	if _inventory_ui.has_method("open"):
		_inventory_ui.open(player)
	AudioManager.play_inventory_open()


func _close_inventory_ui() -> void:
	if _inventory_ui != null and is_instance_valid(_inventory_ui) and _inventory_ui.has_method("close"):
		_inventory_ui.close()
	AudioManager.play_inventory_close()


## Returns true if any inventory or crafting UI panel is currently visible.
## Also calls UIManager.force_close() when all panels are hidden to clear any stuck state.
func is_any_ui_open() -> bool:
	if _inventory_ui != null and is_instance_valid(_inventory_ui) and _inventory_ui.visible:
		return true
	if _crafting_ui != null and is_instance_valid(_crafting_ui) and _crafting_ui.visible:
		return true
	if _furnace_ui != null and is_instance_valid(_furnace_ui) and _furnace_ui.visible:
		return true
	UIManager.force_close()
	return false


## Closes whatever UI is currently open.
func close_active_ui() -> void:
	_close_inventory_ui()
	if _crafting_ui != null and is_instance_valid(_crafting_ui) and _crafting_ui.has_method("close"):
		_crafting_ui.close()
	if _furnace_ui != null and is_instance_valid(_furnace_ui) and _furnace_ui.has_method("close"):
		_furnace_ui.close()


## Opens a chest's inventory. chest_key is "x,y" tile position string.
func open_chest(chest_key: String, p: Node) -> void:
	if _crafting_ui != null and is_instance_valid(_crafting_ui) and _crafting_ui.has_method("close"):
		_crafting_ui.close()
	if _furnace_ui != null and is_instance_valid(_furnace_ui) and _furnace_ui.has_method("close"):
		_furnace_ui.close()
	if _inventory_ui == null or not is_instance_valid(_inventory_ui):
		var scene: PackedScene = load("res://scenes/InventoryUI.tscn")
		if scene == null:
			return
		_inventory_ui = scene.instantiate()
		_ui_layer.add_child(_inventory_ui)
	if _inventory_ui.has_method("open_chest"):
		_inventory_ui.open_chest(p, chest_key)
	elif _inventory_ui.has_method("open"):
		_inventory_ui.open(p)  # fallback
	AudioManager.play_chest_open()


func get_tile_pos_at_world_pos(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))


## Called when the player dies — waits for death animation then respawns.
func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	if player == null or not is_instance_valid(player):
		return
	# Reset player state
	player.set("is_dead", false)
	player.set("health", player.get("max_health"))
	player.set("hunger", player.get("max_hunger"))
	# Respawn at bed spawn point or world surface
	var sp: Vector2 = GameData.spawn_point
	if sp == Vector2.ZERO:
		sp = Vector2(0, (_get_surface_y(0) - TILE_SIZE * 2))
	player.global_position = sp
	player.set("velocity", Vector2.ZERO)
	if player.has_method("_generate_sprites"):
		pass  # sprites already loaded
	# Play idle so the character is visible again
	var spr = player.get("sprite")
	if spr and spr.has_method("play"):
		spr.play("idle")


## Shows a brief floating message on screen (HUD).
func show_message(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.5))
	lbl.position = Vector2(get_viewport().get_visible_rect().size / 2) + Vector2(-80, -60)
	lbl.z_index = 999
	if _ui_layer:
		_ui_layer.add_child(lbl)
	else:
		add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 40, 1.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.tween_callback(lbl.queue_free)


## Opens the Crystal Gate portal selection menu.
func open_gate_menu(gate_pos: Vector2, p: Node) -> void:
	# Register this gate with a name if it has none yet.
	var gate_name := ""
	for gname: String in GameData.crystal_gates:
		if GameData.crystal_gates[gname].distance_to(gate_pos) < TILE_SIZE * 2:
			gate_name = gname
			break

	if gate_name == "":
		# Prompt for name via a simple dialog.
		_open_gate_name_dialog(gate_pos, p)
		return

	_open_gate_teleport_menu(gate_name, gate_pos, p)


func _open_gate_name_dialog(gate_pos: Vector2, p: Node) -> void:
	var panel := Panel.new()
	panel.size = Vector2(320, 130)
	panel.position = get_viewport().get_visible_rect().size / 2 - panel.size / 2
	panel.z_index = 500

	var lbl := Label.new()
	lbl.text = "Name this Crystal Gate:"
	lbl.position = Vector2(12, 10)
	panel.add_child(lbl)

	var edit := LineEdit.new()
	edit.name = "GateEdit"
	edit.size = Vector2(296, 34)
	edit.position = Vector2(12, 36)
	edit.placeholder_text = "Enter gate name..."
	edit.focus_mode = Control.FOCUS_ALL
	panel.add_child(edit)

	var btn := Button.new()
	btn.name = "GateConfirm"
	btn.text = "Confirm"
	btn.size = Vector2(136, 36)
	btn.position = Vector2(12, 82)
	btn.focus_mode = Control.FOCUS_ALL
	panel.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "GateCancel"
	cancel_btn.text = "Cancel"
	cancel_btn.size = Vector2(120, 36)
	cancel_btn.position = Vector2(160, 82)
	cancel_btn.focus_mode = Control.FOCUS_ALL
	panel.add_child(cancel_btn)

	var layer: Node = _ui_layer if _ui_layer else self
	layer.add_child(panel)

	# Wire D-pad focus chain after nodes are in tree (get_path_to requires tree membership).
	# Chain: edit ↕ confirm ↔ cancel, all loop back to edit.
	edit.focus_neighbor_bottom       = edit.get_path_to(btn)
	btn.focus_neighbor_top           = btn.get_path_to(edit)
	btn.focus_neighbor_right         = btn.get_path_to(cancel_btn)
	btn.focus_neighbor_bottom        = btn.get_path_to(cancel_btn)
	cancel_btn.focus_neighbor_left   = cancel_btn.get_path_to(btn)
	cancel_btn.focus_neighbor_top    = cancel_btn.get_path_to(edit)
	cancel_btn.focus_neighbor_bottom = cancel_btn.get_path_to(edit)

	var _do_close := func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
		panel.queue_free()

	# Pre-fill a default name so controller/touch users can confirm without typing.
	var default_name: String = "Gate %d" % (GameData.crystal_gates.size() + 1)
	edit.text = default_name

	if InputManager.using_kbm():
		# KBM: focus text field so they can type a custom name.
		edit.grab_focus()
	else:
		# Controller/touch: focus Confirm directly — the default name is pre-filled.
		# They can press A/Cross to save, or navigate up to edit the name first.
		btn.grab_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_show(edit.text)

	cancel_btn.pressed.connect(_do_close)

	btn.pressed.connect(func():
		var name_val: String = edit.text.strip_edges()
		if name_val != "":
			GameData.crystal_gates[name_val] = gate_pos
			show_message("Gate '%s' registered!" % name_val)
		_do_close.call())

	edit.text_submitted.connect(func(_t): btn.emit_signal("pressed"))


func _open_gate_teleport_menu(current_gate: String, gate_pos: Vector2, p: Node) -> void:
	var others: Array = []
	for gname: String in GameData.crystal_gates:
		if gname != current_gate:
			others.append(gname)

	if others.is_empty():
		show_message("No other gates registered yet.")
		return

	var panel := Panel.new()
	panel.size = Vector2(260, 52 + others.size() * 44 + 44)
	panel.position = get_viewport().get_visible_rect().size / 2 - panel.size / 2
	panel.z_index = 500

	var lbl := Label.new()
	lbl.text = "Travel to:"
	lbl.position = Vector2(12, 10)
	lbl.add_theme_font_size_override("font_size", 16)
	panel.add_child(lbl)

	var layer: Node = _ui_layer if _ui_layer else self
	layer.add_child(panel)

	# Build destination buttons and collect them for focus chain.
	var dest_buttons: Array = []
	for i in others.size():
		var gname: String = others[i]
		var dest_btn := Button.new()
		dest_btn.text = gname
		dest_btn.size = Vector2(236, 36)
		dest_btn.position = Vector2(12, 40 + i * 44)
		dest_btn.focus_mode = Control.FOCUS_ALL
		panel.add_child(dest_btn)
		dest_buttons.append(dest_btn)
		dest_btn.pressed.connect(func():
			var dest: Vector2 = GameData.crystal_gates[gname]
			# Pre-load chunks around destination so the player lands on solid ground.
			var dcx: int = _get_chunk_x(dest.x)
			for _cx in range(dcx - 2, dcx + 3):
				_load_chunk(_cx)
			# Place player 2 tiles above the gate so they land on top of it.
			p.global_position = dest + Vector2(TILE_SIZE * 0.5, -TILE_SIZE * 2)
			show_message("Teleported to '%s'" % gname)
			panel.queue_free())

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size = Vector2(236, 36)
	close_btn.position = Vector2(12, 40 + others.size() * 44 + 4)
	close_btn.focus_mode = Control.FOCUS_ALL
	panel.add_child(close_btn)
	close_btn.pressed.connect(panel.queue_free)

	# Wire D-pad focus chain after nodes are in tree (get_path_to requires tree membership).
	for i in dest_buttons.size():
		var cur: Button = dest_buttons[i]
		var nxt: Button = dest_buttons[i + 1] if i + 1 < dest_buttons.size() else close_btn
		var prv: Button = dest_buttons[i - 1] if i > 0 else close_btn
		cur.focus_neighbor_bottom = cur.get_path_to(nxt)
		cur.focus_neighbor_top    = cur.get_path_to(prv)
	if dest_buttons.size() > 0:
		close_btn.focus_neighbor_top    = close_btn.get_path_to(dest_buttons[-1])
		close_btn.focus_neighbor_bottom = close_btn.get_path_to(dest_buttons[0])

	# Auto-focus first destination button so controller can navigate immediately.
	if dest_buttons.size() > 0:
		dest_buttons[0].grab_focus()
