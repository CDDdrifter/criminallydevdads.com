## Chunk.gd
## ─────────────────────────────────────────────────────────────────────────────
## Attached to a Node2D scene node that represents one horizontal slice of the
## world (CHUNK_WIDTH × CHUNK_HEIGHT tiles).
##
## SCENE STRUCTURE expected:
##   ChunkNode  (Node2D — this script)
##   └── TileLayer  (TileMapLayer — for rendering tiles)
##
## RESPONSIBILITIES:
##   • Store all tile data for one chunk in a Dictionary.
##   • Delegate rendering to the TileMapLayer child node.
##   • Expose helper methods so other systems can read/write individual tiles.
##   • Generate its own data via WorldGenerator on first load (_ready).
##   • Track whether any tile has changed ("dirty" flag) so the save system
##     knows which chunks need to be written to disk.
##
## HOW IT FITS IN THE WORLD:
##   The world is composed of many Chunk nodes placed side by side.
##   chunk_x = 0 sits at world pixel X = 0.
##   chunk_x = 1 sits at world pixel X = CHUNK_WIDTH × TILE_SIZE = 512, etc.
##   Each chunk manages its own TileMapLayer, so only loaded chunks consume
##   memory and draw calls.
##
## NOTE ON TileMapLayer:
##   Godot 4.3 deprecated the old TileMap node in favour of TileMapLayer.
##   Each TileMapLayer renders one "layer" of tiles (e.g. background, midground).
##   Here we use a single layer for all solid blocks and water.
##   The TileMapLayer must share a TileSet resource with every other chunk's
##   TileMapLayer so tile IDs stay consistent across chunks.
## ─────────────────────────────────────────────────────────────────────────────

class_name Chunk
extends Node2D


# ─────────────────────────────────────────────
#  EXPORTED / EDITABLE PROPERTIES
# ─────────────────────────────────────────────

## The chunk's X index in the world grid.
## Set this before the node enters the scene tree (or right after adding it).
## World pixel X = chunk_x * GameData.CHUNK_WIDTH * GameData.TILE_SIZE
@export var chunk_x: int = 0

## Reference to the TileMapLayer child node used for rendering.
## Assign in the Godot editor or via $TileLayer in code.
## The TileMapLayer must have a TileSet assigned that contains all block tile IDs.
@export var tile_layer: TileMapLayer

## Set this BEFORE add_child() so _ready() can apply the shared TileSet.
## World.gd builds one TileSet (with atlas + collision) and shares it across
## all chunk TileMapLayers so tile IDs stay consistent.
var external_tileset: TileSet = null


# ─────────────────────────────────────────────
#  INTERNAL STATE
# ─────────────────────────────────────────────

## The actual tile data store.
## Key:   Vector2i(local_x, tile_y)  — local means 0-based within this chunk.
## Value: String item_id             — e.g. "grass", "stone", "coal_ore".
## Tiles that are AIR are simply absent (no key in the dictionary).
var _tile_data: Dictionary = {}

## Dirty flag — set to true whenever a tile is modified after initial generation.
## The save system checks this flag and only serialises chunks that changed.
## Reset to false after the chunk has been saved.
var is_dirty: bool = false

## True once generate/load has completed.  Prevents double-generation.
var _is_initialized: bool = false

## Batched tilemap-sync state — tiles are pushed to the TileMapLayer in small
## groups across multiple frames so no single frame does all the set_cell work.
var _sync_queue: Array = []
var _sync_pos: int = 0
const SYNC_BATCH_SIZE: int = 300   # set_cell calls per frame

## When true a collision rebuild has been scheduled.
var _collision_rebuild_pending: bool = false

## Vertical cull range — only rows in [_cull_min_row, _cull_max_row] are
## rendered in the TileMapLayer and have collision shapes built.
## Defaults to the full chunk height (no culling) until World.gd sets it.
var _cull_min_row: int = 0
var _cull_max_row: int = 99999   # unclamped until first set_vertical_cull call

## Tiles the player/enemies can pass through — no collision shape needed.
const PASSABLE_TILES: Dictionary = {
	"water": true, "lava": true,
	"leaves_oak": true, "leaves_birch": true, "leaves_pine": true, "leaves_jungle": true,
	"torch": true, "torch_wall": true, "campfire": true, "tall_grass": true,
	"sapling_oak": true, "sapling_birch": true, "sapling_pine": true,
	"wheat_seeds": true, "wheat_crop": true,
	"vines": true, "mushroom_red": true, "mushroom_brown": true,
}


# ─────────────────────────────────────────────
#  LIFECYCLE
# ─────────────────────────────────────────────

func _ready() -> void:
	## Called automatically by Godot when this node enters the scene tree.
	## Position the chunk in world space, then generate or load tile data.

	# ── Position this node in world space ─────────────────────────────────────
	# Each chunk is CHUNK_WIDTH tiles wide; each tile is TILE_SIZE pixels.
	# Multiplying gives the pixel X offset for this chunk's left edge.
	position = Vector2(
		chunk_x * GameData.CHUNK_WIDTH * GameData.TILE_SIZE,
		0.0
	)

	# ── Locate TileMapLayer child if not set in the editor ────────────────────
	if tile_layer == null:
		tile_layer = $TileLayer  # assumes the child is named "TileLayer" in the scene
		if tile_layer == null:
			push_error("Chunk: no TileMapLayer found. Add a TileMapLayer child named 'TileLayer'.")
			return

	# ── Apply the shared TileSet provided by World.gd ─────────────────────────
	# This replaces the empty TileSet from the .tscn with one that has the atlas
	# texture and collision shapes already configured.  Must happen before any
	# set_cell() calls (i.e. before _generate() or _sync_all_tiles_to_tilemap()).
	if external_tileset != null:
		tile_layer.tile_set = external_tileset

	# ── Generate data if not already loaded from a save file ──────────────────
	if not _is_initialized:
		_generate()


# ─────────────────────────────────────────────
#  DATA GENERATION
# ─────────────────────────────────────────────

## _generate() — internal.
## Calls WorldGenerator to fill _tile_data, then syncs the TileMapLayer.
## Do not call this directly; it is called from _ready() when there is no
## save data, or from load_from_save() after populating _tile_data.
func _generate() -> void:
	# WorldGenerator.generate_chunk returns a Dictionary{ Vector2i → String }.
	# GameData.world_seed is the global seed set when the world was created.
	_tile_data = WorldGenerator.generate_chunk(chunk_x, GameData.world_seed)

	_is_initialized = true
	is_dirty = false   # fresh generation is not "dirty" — nothing needs saving yet

	# Batched sync — tiles pushed to TileMapLayer across multiple frames,
	# collision built automatically once the last batch finishes.
	_sync_all_tiles_to_tilemap()


# ─────────────────────────────────────────────
#  PUBLIC TILE API
# ─────────────────────────────────────────────

## set_tile(local_pos, item_id) — place or replace a tile.
##
## local_pos : Vector2i with x in [0, CHUNK_WIDTH) and y in [0, CHUNK_HEIGHT)
## item_id   : A tile ID string from ItemDB.gd, e.g. "dirt", "torch".
##             Pass "" (empty string) to remove a tile (same as clear_tile).
##
## This is the primary write method used by player digging, building, and
## world events (lava spreading, water flowing, etc.).
func set_tile(local_pos: Vector2i, item_id: String) -> void:
	if not _is_valid_local_pos(local_pos):
		push_warning("Chunk %d: set_tile called with out-of-bounds pos %s" % [chunk_x, local_pos])
		return

	if item_id == "":
		# Treat empty string as "remove this tile".
		clear_tile(local_pos)
		return

	# Update the data dictionary.
	_tile_data[local_pos] = item_id

	# Update the rendered TileMapLayer cell to match.
	_set_tilemap_cell(local_pos, item_id)

	# Mark this chunk as changed so the save system will persist it.
	is_dirty = true
	_schedule_collision_rebuild()


## get_tile(local_pos) → String
## Returns the item_id string at the given local position, or "" for air.
## Use this for collision checks, inventory queries, etc.
func get_tile(local_pos: Vector2i) -> String:
	if not _is_valid_local_pos(local_pos):
		return ""
	return _tile_data.get(local_pos, "")   # returns "" if the key is absent (air tile)


## clear_tile(local_pos) → String
## Removes the tile at local_pos (making it air) and returns the item_id that
## was there, or "" if it was already empty.
## Used by the player's digging/mining action to remove a block and yield its
## item drop.
func clear_tile(local_pos: Vector2i) -> String:
	if not _is_valid_local_pos(local_pos):
		return ""

	# Grab the old ID before removing it (caller may need it for item drops).
	var removed_id: String = _tile_data.get(local_pos, "")

	if removed_id != "":
		_tile_data.erase(local_pos)

		# Tell the TileMapLayer to remove that cell (use invalid source_id -1).
		tile_layer.erase_cell(local_pos)

		is_dirty = true
		_schedule_collision_rebuild()

	return removed_id


## has_tile(local_pos) → bool
## Quick existence check — returns true if there is any solid tile at local_pos.
func has_tile(local_pos: Vector2i) -> bool:
	return _tile_data.has(local_pos)


# ─────────────────────────────────────────────
#  SAVE / LOAD SUPPORT
# ─────────────────────────────────────────────

## load_from_save(data: Dictionary) → void
## Replaces _tile_data with data loaded from disk and re-renders the tilemap.
## Called by the save/load manager instead of letting _ready() call _generate().
##
## data: A Dictionary{ Vector2i → String } previously returned by to_save_data().
func load_from_save(data: Dictionary) -> void:
	_tile_data = data
	_is_initialized = true
	is_dirty = false   # freshly loaded — no unsaved changes yet
	# Batched sync — collision is scheduled automatically at end of sync.
	_sync_all_tiles_to_tilemap()


## to_save_data() → Dictionary
## Returns a copy of _tile_data suitable for serialisation.
## The save system calls this when writing the chunk to disk.
## After saving, is_dirty should be reset to false by the save system.
func to_save_data() -> Dictionary:
	return _tile_data.duplicate()


## mark_clean() → void
## Called by the save system after successfully writing this chunk to disk.
## Resets is_dirty so we don't save it again until another tile changes.
func mark_clean() -> void:
	is_dirty = false


## set_vertical_cull(min_row, max_row) → void
## Restricts rendering and collision to tile rows in [min_row, max_row].
## Rows outside this window are removed from the TileMapLayer and excluded
## from the collision body, reducing draw calls and physics shapes.
## Called by World.gd whenever the player moves more than ~6 rows vertically.
func set_vertical_cull(min_row: int, max_row: int) -> void:
	var new_min: int = clampi(min_row, 0, GameData.CHUNK_HEIGHT - 1)
	var new_max: int = clampi(max_row, 0, GameData.CHUNK_HEIGHT - 1)

	# Skip if the range hasn't changed meaningfully (avoid redundant rebuilds).
	if new_min == _cull_min_row and new_max == _cull_max_row:
		return

	var old_min: int = _cull_min_row
	var old_max: int = _cull_max_row
	_cull_min_row = new_min
	_cull_max_row = new_max

	if tile_layer == null or not _is_initialized:
		return

	# Add newly visible rows.
	for row in range(new_min, new_max + 1):
		if row < old_min or row > old_max:
			for col in range(GameData.CHUNK_WIDTH):
				var pos := Vector2i(col, row)
				var id: String = _tile_data.get(pos, "")
				if id != "":
					_set_tilemap_cell(pos, id)

	# Remove rows that scrolled out of the visible window.
	for row in range(old_min, old_max + 1):
		if row < new_min or row > new_max:
			for col in range(GameData.CHUNK_WIDTH):
				tile_layer.erase_cell(Vector2i(col, row))

	# Rebuild collision for the updated visible band.
	_schedule_collision_rebuild()


# ─────────────────────────────────────────────
#  COORDINATE UTILITIES
# ─────────────────────────────────────────────

## world_to_local(world_tile_pos) → Vector2i
## Converts a world-space tile coordinate (e.g. Vector2i(64, 90)) into the
## chunk-local coordinate (e.g. Vector2i(0, 90) if chunk_x == 2).
## Returns Vector2i(-1, -1) if the position is not inside this chunk.
func world_to_local(world_tile_pos: Vector2i) -> Vector2i:
	var lx: int = world_tile_pos.x - chunk_x * GameData.CHUNK_WIDTH
	if lx < 0 or lx >= GameData.CHUNK_WIDTH:
		return Vector2i(-1, -1)   # not in this chunk
	return Vector2i(lx, world_tile_pos.y)


## local_to_world(local_pos) → Vector2i
## Converts a local chunk position back to world-space tile coordinates.
func local_to_world(local_pos: Vector2i) -> Vector2i:
	return Vector2i(local_pos.x + chunk_x * GameData.CHUNK_WIDTH, local_pos.y)


## local_to_pixel(local_pos) → Vector2
## Converts a local tile position to the pixel position of the tile's top-left
## corner in the CHUNK's local coordinate space (not global world space).
## Use position + local_to_pixel() for global pixel coordinates.
func local_to_pixel(local_pos: Vector2i) -> Vector2:
	return Vector2(local_pos.x * GameData.TILE_SIZE, local_pos.y * GameData.TILE_SIZE)


# ─────────────────────────────────────────────
#  PRIVATE HELPERS
# ─────────────────────────────────────────────

## _is_valid_local_pos(pos) → bool
## Checks that pos is within the chunk's tile bounds.
func _is_valid_local_pos(pos: Vector2i) -> bool:
	return (
		pos.x >= 0 and pos.x < GameData.CHUNK_WIDTH and
		pos.y >= 0 and pos.y < GameData.CHUNK_HEIGHT
	)


## _sync_all_tiles_to_tilemap() — starts a batched sync.
## Tiles are pushed in groups of SYNC_BATCH_SIZE per frame so no single frame
## spikes from thousands of set_cell calls. The FIRST batch is deferred to the
## NEXT frame so the frame that calls add_child() + collision build stays light.
func _sync_all_tiles_to_tilemap() -> void:
	if tile_layer == null:
		return
	tile_layer.clear()
	# Collect the tiles that fall inside the current cull window.
	_sync_queue = []
	for pos: Vector2i in _tile_data:
		if pos.y >= _cull_min_row and pos.y <= _cull_max_row:
			_sync_queue.append(pos)
	_sync_pos = 0
	# Defer the first batch — keeps the add_child frame nearly spike-free.
	get_tree().process_frame.connect(_run_sync_batch, CONNECT_ONE_SHOT)


## _run_sync_batch() — called each frame until the sync queue is drained.
func _run_sync_batch() -> void:
	if not is_inside_tree() or tile_layer == null:
		_sync_queue = []
		return
	var end: int = mini(_sync_pos + SYNC_BATCH_SIZE, _sync_queue.size())
	for i in range(_sync_pos, end):
		var pos: Vector2i = _sync_queue[i]
		var id: String = _tile_data.get(pos, "")
		if id != "":
			_set_tilemap_cell(pos, id)
	_sync_pos = end
	if _sync_pos < _sync_queue.size():
		# More tiles remain — continue next frame.
		get_tree().process_frame.connect(_run_sync_batch, CONNECT_ONE_SHOT)
	else:
		# All tiles synced — now build collision (deferred to end of this frame).
		_sync_queue = []
		_sync_pos = 0
		_schedule_collision_rebuild()


## Builds the collision body from pre-computed strip data.
## Called by World._apply_chunk() so the player has solid ground immediately.
## strips  — Array of [x0, x1, tile_y] computed on the worker thread.
## cull_min/max — the current render window; shapes outside are skipped.
func build_collision_from_strips(strips: Array, cull_min: int, cull_max: int) -> void:
	_build_physics_body(strips, cull_min, cull_max)


## Schedules _build_collision_body() for end of the current frame.
## Multiple calls in the same frame collapse into one rebuild.
func _schedule_collision_rebuild() -> void:
	if _collision_rebuild_pending:
		return
	_collision_rebuild_pending = true
	call_deferred("_deferred_rebuild_collision")

func _deferred_rebuild_collision() -> void:
	_collision_rebuild_pending = false
	_build_collision_body()


## Rebuilds collision from _tile_data (called after individual tile changes).
## Computes strips locally then delegates to _build_physics_body.
func _build_collision_body() -> void:
	# Buffer of 20 rows (~320 px) ensures collision is always present even if
	# the camera cull lags or the player falls quickly near chunk boundaries.
	const COLL_BUFFER: int = 20
	var coll_min: int = clampi(_cull_min_row - COLL_BUFFER, 0, GameData.CHUNK_HEIGHT - 1)
	var coll_max: int = clampi(_cull_max_row + COLL_BUFFER, 0, GameData.CHUNK_HEIGHT - 1)
	var strips: Array = _compute_strips_local(coll_min, coll_max)
	_build_physics_body(strips, _cull_min_row, _cull_max_row)


## Computes horizontal solid-tile run data from _tile_data.
## Returns Array of [x0, x1, tile_y].
func _compute_strips_local(coll_min: int, coll_max: int) -> Array:
	var strips: Array = []
	for tile_y in range(coll_min, coll_max + 1):
		var run_start: int = -1
		for tile_x in range(GameData.CHUNK_WIDTH):
			var raw: String = _tile_data.get(Vector2i(tile_x, tile_y), "")
			var id: String = raw.get_slice("|", 0)
			var solid: bool = id != "" and not PASSABLE_TILES.has(id)
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


## Core collision builder.
## KEY OPTIMISATION vs. old code: all CollisionShape2D children are added to the
## StaticBody2D BEFORE the body is added to the scene tree.  This means only ONE
## scene-tree notification event fires (for the whole body + all its children at
## once) rather than one per shape — reducing the spike from ~600 events to 1.
func _build_physics_body(strips: Array, cull_min: int, cull_max: int) -> void:
	# Reuse the same StaticBody2D to avoid the 1-2 frame window where a
	# queue_free'd body still has active collision shapes for mined tiles.
	var body: StaticBody2D = get_node_or_null("ChunkCollision")
	if body == null:
		body = StaticBody2D.new()
		body.name = "ChunkCollision"
		body.collision_layer = 1
		body.collision_mask  = 0
		add_child(body)

	# Immediately free all existing shapes (no queue_free — instant removal).
	for child in body.get_children():
		body.remove_child(child)
		child.free()

	var ts: int = GameData.TILE_SIZE
	const COLL_BUFFER: int = 20
	var coll_min_f: int = clampi(cull_min - COLL_BUFFER, 0, GameData.CHUNK_HEIGHT - 1)
	var coll_max_f: int = clampi(cull_max + COLL_BUFFER, 0, GameData.CHUNK_HEIGHT - 1)

	for strip in strips:
		var tile_y: int = strip[2]
		if tile_y < coll_min_f or tile_y > coll_max_f:
			continue
		var x0: int  = strip[0]
		var x1: int  = strip[1]
		var w: float = float((x1 - x0 + 1) * ts)
		var rect    := RectangleShape2D.new()
		rect.size    = Vector2(w, float(ts))
		var snode   := CollisionShape2D.new()
		snode.shape  = rect
		snode.position = Vector2(float(x0 * ts) + w * 0.5, float(tile_y * ts) + float(ts) * 0.5)
		body.add_child(snode)


## _set_tilemap_cell(local_pos, item_id) → void
## Updates a single cell in the TileMapLayer to display the correct tile graphic.
##
## HOW TileMapLayer CELL PLACEMENT WORKS:
##   tile_layer.set_cell(coords, source_id, atlas_coords, alternative_tile)
##     coords        — the tile position in the TileMapLayer grid (Vector2i)
##     source_id     — which TileSetSource within the TileSet to use (usually 0)
##     atlas_coords  — the column/row of the tile inside the atlas texture
##     alternative_tile — variant index (0 = default; used for rotations etc.)
##
## We look up the atlas coordinates via ItemDatabase so this script does not
## need a hard-coded atlas mapping.  ItemDB.get_tile_atlas_coords(id)
## should return a Vector2i matching the tile's position in the atlas texture.
##
## If ItemDatabase is not yet set up, you can hard-code a fallback:
##   tile_layer.set_cell(local_pos, 0, Vector2i(0, 0))
func _set_tilemap_cell(local_pos: Vector2i, item_id: String) -> void:
	if tile_layer == null:
		return

	# ── Parse optional flip suffix: "stairs_stone|h" → base_id + alt=1 ───────
	var base_id := item_id
	var alt := 0
	if "|" in item_id:
		var parts := item_id.split("|", false, 1)
		base_id = parts[0]
		if parts.size() > 1 and parts[1] == "h":
			alt = 1   # alternative tile 1 = flip_h (created in World._build_shared_tileset)

	# ── Look up atlas coordinates from ItemDatabase ───────────────────────────
	# ItemDatabase should expose a method that maps a string item_id to the
	# atlas grid position of its tile graphic.
	# If ItemDatabase is not yet implemented, replace this block with a
	# hard-coded Vector2i, e.g. Vector2i(0, 0) for all tiles during prototyping.
	if not ItemDB.has_tile(base_id):
		push_warning("Chunk: unknown tile id '%s' at %s — add it to ItemDB." % [base_id, local_pos])
		return

	var atlas_coords: Vector2i = ItemDB.get_tile_atlas_coords(base_id)
	tile_layer.set_cell(local_pos, 0, atlas_coords, alt)
