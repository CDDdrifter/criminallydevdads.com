## SaveLoad.gd
## Autoload singleton — add to Project > AutoLoad as "SaveLoad".
##
## Handles saving and loading the full game state to/from a single JSON file
## stored at user://savefile.json (platform-specific user data directory).
##
## Usage:
##   SaveLoad.save_game(world_node, player_node)
##   var data = SaveLoad.load_game()
##   if SaveLoad.has_save(): ...
##   SaveLoad.delete_save()
##
## ===========================================================================
## SAVE FILE STRUCTURE (version 1):
## {
##   "version": 1,
##   "world_seed": int,
##   "day": int,
##   "time_of_day": float,
##   "player": {
##     "position":  { "x": float, "y": float },
##     "health":    float,
##     "hunger":    float,
##     "inventory": [ {id, count, durability}, ... ],
##     "hotbar":    [ {id, count, durability}, ... ]
##   },
##   "chunks": {
##     "0":  { "tile_x,tile_y": block_id, ... },   <- only modified tiles
##     "5":  { ... },
##     ...
##   }
## }
##
## Only chunks that were changed from world-gen defaults are stored.
## This keeps save files small even for large worlds.
##
## ===========================================================================
## HOW TO CHANGE THE SAVE LOCATION:
##   Replace SAVE_PATH below with any valid Godot path:
##   "user://saves/slot1.json", "res://debug_save.json", etc.
##
## HOW TO ADD A NEW TOP-LEVEL FIELD:
##   1. Add the field to the dictionary in save_game().
##   2. Read it back in load_game() (it will already be in the parsed dict).
##   3. Increment SAVE_VERSION and add a migration block in _migrate() if
##      older saves need to be upgraded gracefully.
##
## HOW TO ADD PER-PLAYER DATA (e.g. skill points):
##   Add the field inside the "player" sub-dictionary in _build_player_data()
##   and read it in apply_save_data() on the Player node.
## ===========================================================================

extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
## Legacy single-save path — kept for migration only.
const _LEGACY_SAVE_PATH: String = "user://savefile.json"
const SAVE_VERSION: int = 1
const MAX_SLOTS: int = 3

## Active save slot (0-based).  Set before calling save/load.
var current_slot: int = 0

func get_save_path(slot: int = -1) -> String:
	var s := current_slot if slot < 0 else slot
	return "user://save_slot_%d.json" % s

# ---------------------------------------------------------------------------
# save_game
# ---------------------------------------------------------------------------
## Serialises the world and player state to SAVE_PATH.
##
## Parameters:
##   world_node  — the root World node; must expose:
##                   world_seed: int
##                   current_day: int
##                   time_of_day: float
##                   get_modified_chunks() -> Dictionary
##                     returns { chunk_index: { Vector2i: block_id } }
##   player_node — a Player node that has get_save_data() -> Dictionary
func save_game(world_node: Node, player_node: Node) -> void:
	var qs: Node = get_node_or_null("/root/QuestSystem")
	var save_data: Dictionary = {
		"version":     SAVE_VERSION,
		"slot":        current_slot,
		"world_seed":  world_node.get("world_seed") if world_node else 0,
		"day":         world_node.get("current_day") if world_node else 0,
		"time_of_day": world_node.get("time_of_day") if world_node else 0.0,
		"player":      _build_player_data(player_node),
		"chunks":      _build_chunk_data(world_node),
		"spawn_point":        [GameData.spawn_point.x, GameData.spawn_point.y],
		"crystal_gates":      _gates_to_array(),
		"chest_inventories":  GameData.chest_inventories,
		"fx":                 GameData.fx,
		"quests":             qs.to_save_dict() if qs != null and qs.has_method("to_save_dict") else {},
		"creative_mode":      GameData.creative_mode,
		"difficulty":         GameData.difficulty,
	}

	var json_string: String = JSON.stringify(save_data, "\t")
	var path := get_save_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveLoad: Could not open save file for writing. Error: %d" \
				% FileAccess.get_open_error())
		return
	file.store_string(json_string)
	file.close()
	print("SaveLoad: Game saved to ", path)

# ---------------------------------------------------------------------------
# load_game
# ---------------------------------------------------------------------------
## Reads and parses SAVE_PATH.
## Returns the parsed save Dictionary, or {} if the file does not exist
## or cannot be parsed.
## The caller is responsible for applying the data to world and player nodes.
func load_game() -> Dictionary:
	# Migrate legacy single-save to slot 0 if it exists.
	if FileAccess.file_exists(_LEGACY_SAVE_PATH) and not has_save(0):
		var legacy_file := FileAccess.open(_LEGACY_SAVE_PATH, FileAccess.READ)
		if legacy_file != null:
			var slot0_file := FileAccess.open(get_save_path(0), FileAccess.WRITE)
			if slot0_file != null:
				slot0_file.store_string(legacy_file.get_as_text())
				slot0_file.close()
			legacy_file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_LEGACY_SAVE_PATH))

	if not has_save():
		return {}

	var path := get_save_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveLoad: Could not open save file for reading. Error: %d" \
				% FileAccess.get_open_error())
		return {}

	var raw: String = file.get_as_text()
	file.close()

	# Parse JSON.  JSON.parse_string() returns null on failure.
	var parsed = JSON.parse_string(raw)
	if parsed == null:
		push_error("SaveLoad: Save file is corrupt or not valid JSON.")
		return {}

	# Ensure the parsed value is a Dictionary.
	if not parsed is Dictionary:
		push_error("SaveLoad: Save file root is not a JSON object.")
		return {}

	var data: Dictionary = parsed as Dictionary

	# Migrate older save versions if necessary.
	data = _migrate(data)

	# Convert chunk tile keys back from "x,y" strings to Vector2i.
	# (They were stringified before saving because JSON only supports string keys.)
	data["chunks"] = _deserialise_chunks(data.get("chunks", {}))

	if data.has("spawn_point"):
		var sp = data["spawn_point"]
		GameData.spawn_point = Vector2(float(sp[0]), float(sp[1]))
	if data.has("crystal_gates"):
		GameData.crystal_gates = _gates_from_array(data["crystal_gates"])
	if data.has("chest_inventories"):
		GameData.chest_inventories = data["chest_inventories"]
	if data.has("fx"):
		for k: String in data["fx"]:
			GameData.fx[k] = data["fx"][k]

	if data.has("quests"):
		var qs_node: Node = get_node_or_null("/root/QuestSystem")
		if qs_node != null and qs_node.has_method("from_save_dict"):
			qs_node.from_save_dict(data["quests"])

	if data.has("creative_mode"):
		GameData.creative_mode = bool(data["creative_mode"])
	if data.has("difficulty"):
		GameData.difficulty = str(data["difficulty"])

	return data

# ---------------------------------------------------------------------------
# has_save
# ---------------------------------------------------------------------------
## Returns true if a save exists for the given slot (defaults to current_slot).
func has_save(slot: int = -1) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

## Returns a brief summary dict for a slot: {exists, day, world_seed}.
## Used by MainMenu to label save slots.
func get_slot_summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {"exists": false, "day": 0, "world_seed": 0}
	var file := FileAccess.open(get_save_path(slot), FileAccess.READ)
	if file == null:
		return {"exists": false, "day": 0, "world_seed": 0}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"exists": false, "day": 0, "world_seed": 0}
	return {
		"exists":     true,
		"day":        int(parsed.get("day", 1)),
		"world_seed": int(parsed.get("world_seed", 0)),
	}

## Deletes the current slot's save file.
func delete_save(slot: int = -1) -> void:
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SaveLoad: Slot %d deleted." % (current_slot if slot < 0 else slot))

# ===========================================================================
# Internal helpers
# ===========================================================================

# ---------------------------------------------------------------------------
# _build_player_data
# ---------------------------------------------------------------------------
## Collects all player state into a plain Dictionary.
## If the player node exposes get_save_data(), we use that directly.
## Otherwise we build a minimal record manually.
##
## HOW TO ADD A NEW PLAYER FIELD:
##   Add it inside player_node.get_save_data() (in Player.gd) and it will
##   automatically appear here.  No changes needed in this file.
func _build_player_data(player_node: Node) -> Dictionary:
	if player_node == null:
		return {}

	# Prefer the Player's own serialisation method for clean separation of concerns.
	if player_node.has_method("get_save_data"):
		return player_node.get_save_data()

	# Fallback: build a basic record from known properties.
	return {
		"position": {
			"x": player_node.global_position.x,
			"y": player_node.global_position.y,
		},
		"health":    player_node.get("health") if player_node.get("health") != null else 100.0,
		"hunger":    player_node.get("hunger") if player_node.get("hunger") != null else 100.0,
		"hotbar":    player_node.get("hotbar")    if player_node.get("hotbar")    != null else [],
		"inventory": player_node.get("inventory") if player_node.get("inventory") != null else [],
	}

# ---------------------------------------------------------------------------
# _build_chunk_data
# ---------------------------------------------------------------------------
## Serialises only the chunks that were modified since world generation.
## Tile positions (Vector2i keys) cannot be stored directly in JSON because
## JSON only supports string keys.  We convert them to "x,y" strings.
##
## Expected world_node API:
##   get_modified_chunks() -> Dictionary
##     { chunk_index (int): { Vector2i: block_id (String) } }
##
## HOW TO CHANGE CHUNK FORMAT:
##   Modify the inner loop below.  The key format ("x,y") must match
##   _deserialise_chunks() so that loading restores the correct Vector2i.
func _build_chunk_data(world_node: Node) -> Dictionary:
	var chunks_out: Dictionary = {}

	if world_node == null:
		return chunks_out
	if not world_node.has_method("get_modified_chunks"):
		return chunks_out

	var modified: Dictionary = world_node.get_modified_chunks()
	# modified = { 0: { Vector2i(3,5): "stone", Vector2i(4,5): "air" }, ... }

	for chunk_index in modified.keys():
		var tile_map: Dictionary = modified[chunk_index]
		var serialised_tiles: Dictionary = {}

		for tile_pos in tile_map.keys():
			# Vector2i cannot be a JSON key; convert to "x,y" string.
			var key: String = "%d,%d" % [tile_pos.x, tile_pos.y]
			serialised_tiles[key] = tile_map[tile_pos]

		# Store with the chunk index as a string (JSON requires string keys).
		chunks_out[str(chunk_index)] = serialised_tiles

	return chunks_out

# ---------------------------------------------------------------------------
# _deserialise_chunks
# ---------------------------------------------------------------------------
## Reverses _build_chunk_data: converts "x,y" string keys back to Vector2i.
## Returns a Dictionary with the same structure expected by the world node:
##   { chunk_index (int): { Vector2i: block_id (String) } }
func _deserialise_chunks(raw_chunks: Dictionary) -> Dictionary:
	var chunks_out: Dictionary = {}

	for chunk_key in raw_chunks.keys():
		# Chunk index was stored as a string key; restore to int.
		var chunk_index: int = int(chunk_key)
		var tile_map: Dictionary = {}

		var raw_tiles: Dictionary = raw_chunks[chunk_key]
		for tile_key in raw_tiles.keys():
			# "x,y" → Vector2i(x, y)
			var parts: PackedStringArray = tile_key.split(",")
			if parts.size() == 2:
				var tile_pos: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
				tile_map[tile_pos] = raw_tiles[tile_key]
			else:
				push_warning("SaveLoad: Unexpected tile key format: '%s'" % tile_key)

		chunks_out[chunk_index] = tile_map

	return chunks_out

# ---------------------------------------------------------------------------
# _migrate
# ---------------------------------------------------------------------------
## Upgrades save data from older versions to the current SAVE_VERSION.
##
## HOW TO ADD A MIGRATION:
##   1. Increment SAVE_VERSION at the top of this file.
##   2. Add an elif block:
##        elif version == <old_version>:
##            data["new_field"] = default_value
##            data["version"]   = <old_version + 1>
##   3. Let it fall through so multiple migrations chain automatically.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("version", 0)

	if version == SAVE_VERSION:
		# Already current; nothing to do.
		return data

	# Example future migration (version 1 → 2):
	# if version == 1:
	#     data["new_field"] = default_value
	#     data["version"]   = 2
	#     version = 2

	if version == 0:
		# Version 0 had no version field at all; treat it as version 1.
		push_warning("SaveLoad: Save file has no version field; assuming version 1.")
		data["version"] = 1

	return data

# ---------------------------------------------------------------------------
# Chunk streaming API (called by World.gd)
# ---------------------------------------------------------------------------
## In-memory chunk cache — stores chunk tile data between load/unload cycles
## so chunks don't regenerate when the player moves away and back.
## Per-slot chunk caches — indexed by slot then chunk_x.
var _chunk_caches: Dictionary = {}  # slot_int -> { chunk_x: data }

func _get_cache() -> Dictionary:
	if not _chunk_caches.has(current_slot):
		_chunk_caches[current_slot] = {}
	return _chunk_caches[current_slot]

## Clears in-memory chunk cache for the current slot (call on new game).
func clear_chunk_cache() -> void:
	_chunk_caches[current_slot] = {}

## Called by World._get_saved_chunk_data() — returns previously stored data or null.
func get_chunk_data(chunk_x: int):
	return _get_cache().get(chunk_x, null)

## Called by World._store_chunk_data() — stores chunk data in memory.
func store_chunk_data(chunk_x: int, data: Dictionary) -> void:
	_get_cache()[chunk_x] = data


func _gates_to_array() -> Array:
	var result := []
	for gname: String in GameData.crystal_gates:
		var pos: Vector2 = GameData.crystal_gates[gname]
		result.append({"name": gname, "x": pos.x, "y": pos.y})
	return result

func _gates_from_array(arr: Array) -> Dictionary:
	var result := {}
	for entry in arr:
		result[str(entry.get("name", ""))] = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
	return result
