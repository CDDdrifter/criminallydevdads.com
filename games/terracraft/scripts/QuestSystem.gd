## QuestSystem.gd — Autoload singleton
## Linear quest chain that guides new players through TerraCraft.
## Register as autoload "QuestSystem" in Project Settings.
##
## Quest structure:
##   id: String          — unique identifier
##   title: String       — short display title
##   desc: String        — one-line objective description
##   reward_text: String — what the player gets/unlocks
##   objectives: Array   — list of {type, target, current, goal} dicts
##   completed: bool
##
## Objective types:
##   "collect"   — have `goal` of item `target` in inventory at any time
##   "craft"     — craft item `target` at least `goal` times
##   "kill"      — kill `goal` enemies of group `target` ("any"=any enemy)
##   "reach_depth" — reach Y depth >= goal (in tiles below surface)
##   "survive_night" — survive `goal` nights
##   "place"     — place item `target` at least `goal` times
##   "smelt"     — smelt item `target` at least `goal` times

extends Node

signal quest_completed(quest_id: String)
signal objective_updated(quest_id: String)
signal achievement_unlocked(achievement_id: String)

# Active quest index (points into QUESTS)
var _active_idx: int = 0

# Per-quest completion flag array — persists between sessions
var _completed: Array = []

# Achievement completion dict
var _achievements_done: Dictionary = {}

# Runtime counters (reset each session, persisted via save/load)
var crafted: Dictionary = {}      # id → count
var killed: Dictionary = {}       # group → count
var smelted: Dictionary = {}      # id → count
var placed: Dictionary = {}       # id → count
var nights_survived: int = 0
var max_depth_tiles: int = 0      # deepest tile row reached below surface

# ── Quest chain ──────────────────────────────────────────────────────────────

const QUESTS: Array = [
	{
		"id": "first_wood",
		"title": "First Steps",
		"desc": "Punch trees to collect 10 Wood",
		"reward_text": "You can now craft basic tools!",
		"objectives": [{"type": "collect", "target": "log_oak", "goal": 10}],
	},
	{
		"id": "basic_tools",
		"title": "Carpenter",
		"desc": "Craft 4 Sticks and a Wooden Pickaxe",
		"reward_text": "Mine stone much faster now.",
		"objectives": [
			{"type": "craft", "target": "stick",    "goal": 4},
			{"type": "craft", "target": "wood_pick","goal": 1},
		],
	},
	{
		"id": "mine_stone",
		"title": "Stone Gathering",
		"desc": "Mine 30 Cobblestone",
		"reward_text": "Stone tools unlocked!",
		"objectives": [{"type": "collect", "target": "cobblestone", "goal": 30}],
	},
	{
		"id": "stone_tools",
		"title": "Stonesmith",
		"desc": "Craft a Stone Pickaxe and Stone Sword",
		"reward_text": "Ready to fight and mine iron!",
		"objectives": [
			{"type": "craft", "target": "stone_pick",  "goal": 1},
			{"type": "craft", "target": "stone_sword", "goal": 1},
		],
	},
	{
		"id": "first_night",
		"title": "First Night",
		"desc": "Survive until the next dawn",
		"reward_text": "Darkness holds no fear for you now.",
		"objectives": [{"type": "survive_night", "target": "", "goal": 1}],
	},
	{
		"id": "build_shelter",
		"title": "Home Builder",
		"desc": "Place 20 blocks to build a shelter",
		"reward_text": "A safe place to sleep!",
		"objectives": [{"type": "place", "target": "any_block", "goal": 20}],
	},
	{
		"id": "first_kill",
		"title": "First Blood",
		"desc": "Kill 3 enemies",
		"reward_text": "Combat experience gained!",
		"objectives": [{"type": "kill", "target": "any", "goal": 3}],
	},
	{
		"id": "build_bed",
		"title": "Sweet Dreams",
		"desc": "Craft and place a Bed",
		"reward_text": "Skip the night and set your spawn!",
		"objectives": [
			{"type": "craft", "target": "bed", "goal": 1},
			{"type": "place", "target": "bed",  "goal": 1},
		],
	},
	{
		"id": "make_furnace",
		"title": "Metallurgist",
		"desc": "Craft a Furnace and smelt 5 Iron Ingots",
		"reward_text": "Iron tools and weapons await!",
		"objectives": [
			{"type": "craft",  "target": "furnace",    "goal": 1},
			{"type": "smelt",  "target": "iron_ingot", "goal": 5},
		],
	},
	{
		"id": "iron_gear",
		"title": "Iron Age",
		"desc": "Craft an Iron Sword and Iron Pickaxe",
		"reward_text": "The real adventure begins.",
		"objectives": [
			{"type": "craft", "target": "iron_sword", "goal": 1},
			{"type": "craft", "target": "iron_pick",  "goal": 1},
		],
	},
	{
		"id": "go_deeper",
		"title": "Deep Explorer",
		"desc": "Reach 60 tiles underground",
		"reward_text": "Ores await in the darkness!",
		"objectives": [{"type": "reach_depth", "target": "", "goal": 60}],
	},
	{
		"id": "find_diamonds",
		"title": "Diamond Seeker",
		"desc": "Collect 5 Diamonds",
		"reward_text": "The finest gear is within reach!",
		"objectives": [{"type": "collect", "target": "diamond", "goal": 5}],
	},
	{
		"id": "diamond_gear",
		"title": "Diamond Knight",
		"desc": "Craft a Diamond Sword and Diamond Pickaxe",
		"reward_text": "Near the pinnacle of power!",
		"objectives": [
			{"type": "craft", "target": "diamond_sword", "goal": 1},
			{"type": "craft", "target": "diamond_pick",  "goal": 1},
		],
	},
	{
		"id": "kill_elites",
		"title": "Elite Hunter",
		"desc": "Kill 5 Elite enemies",
		"reward_text": "You are battle-hardened!",
		"objectives": [{"type": "kill", "target": "elite_enemy", "goal": 5}],
	},
	{
		"id": "kill_boss",
		"title": "Boss Slayer",
		"desc": "Defeat a Boss",
		"reward_text": "You are a legend of TerraCraft!",
		"objectives": [{"type": "kill", "target": "boss_enemy", "goal": 1}],
	},
]

# ── Achievement definitions ──────────────────────────────────────────────────

const ACHIEVEMENTS: Array = [
	{"id": "woodcutter",    "name": "Woodcutter",     "desc": "Collect 100 wood",          "check": "collect_log_oak_100"},
	{"id": "miner",         "name": "Deep Miner",     "desc": "Mine 500 stone blocks",     "check": "collect_cobblestone_500"},
	{"id": "first_kill",    "name": "Warrior",        "desc": "Kill your first enemy",     "check": "kill_any_1"},
	{"id": "ten_kills",     "name": "Slayer",         "desc": "Kill 10 enemies",           "check": "kill_any_10"},
	{"id": "fifty_kills",   "name": "Mass Slayer",    "desc": "Kill 50 enemies",           "check": "kill_any_50"},
	{"id": "boss_killer",   "name": "Boss Slayer",    "desc": "Defeat a boss",             "check": "kill_boss_enemy_1"},
	{"id": "five_nights",   "name": "Night Owl",      "desc": "Survive 5 nights",          "check": "nights_5"},
	{"id": "deep_100",      "name": "Spelunker",      "desc": "Reach 100 tiles deep",      "check": "depth_100"},
	{"id": "iron_age",      "name": "Iron Age",       "desc": "Smelt 10 iron ingots",      "check": "smelt_iron_ingot_10"},
	{"id": "creative_god",  "name": "Creative God",   "desc": "Enter creative mode",       "check": "creative_mode"},
]

# ── Collected-item totals for achievements ───────────────────────────────────
var _collected_totals: Dictionary = {}  # item_id → lifetime count

# ── Runtime init ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_completed.resize(QUESTS.size())
	for i in QUESTS.size():
		_completed[i] = false

## Returns the currently active quest dict, or null if all done.
func get_active_quest() -> Dictionary:
	if _active_idx >= QUESTS.size():
		return {}
	return QUESTS[_active_idx]

## Returns true if quest with given id is complete.
func is_complete(quest_id: String) -> bool:
	for i in QUESTS.size():
		if QUESTS[i]["id"] == quest_id:
			return _completed[i]
	return false

# ── Event hooks — called from Player.gd, EnemyBase.gd, etc. ─────────────────

## Call when the player collects an item (any source: mining, looting, crafting output).
func on_item_collected(item_id: String, count: int = 1) -> void:
	_collected_totals[item_id] = _collected_totals.get(item_id, 0) + count
	_check_active_objectives()
	_check_achievements()

## Call when the player crafts an item.
func on_item_crafted(item_id: String, count: int = 1) -> void:
	crafted[item_id] = crafted.get(item_id, 0) + count
	_check_active_objectives()

## Call when the player smelts an item.
func on_item_smelted(item_id: String, count: int = 1) -> void:
	smelted[item_id] = smelted.get(item_id, 0) + count
	_check_active_objectives()

## Call when the player places a block.
func on_block_placed(item_id: String) -> void:
	placed[item_id] = placed.get(item_id, 0) + 1
	placed["any_block"] = placed.get("any_block", 0) + 1
	_check_active_objectives()

## Call when an enemy of a given group dies (from EnemyBase.gd).
func on_enemy_killed(group: String) -> void:
	killed[group] = killed.get(group, 0) + 1
	killed["any"] = killed.get("any", 0) + 1
	_check_active_objectives()
	_check_achievements()

## Call once per night survived (from World.gd on dawn transition).
func on_night_survived() -> void:
	nights_survived += 1
	_check_active_objectives()
	_check_achievements()

## Call when the player's depth is updated (from World.gd).
func on_depth_updated(depth_tiles: int) -> void:
	if depth_tiles > max_depth_tiles:
		max_depth_tiles = depth_tiles
		_check_active_objectives()
		_check_achievements()

## Call when creative mode is entered.
func on_creative_mode_entered() -> void:
	_try_unlock_achievement("creative_god")

# ── Internal check logic ─────────────────────────────────────────────────────

func _check_active_objectives() -> void:
	if _active_idx >= QUESTS.size():
		return
	var quest: Dictionary = QUESTS[_active_idx]
	var all_done: bool = true
	for obj in quest["objectives"]:
		if not _objective_met(obj):
			all_done = false
			break
	objective_updated.emit(quest["id"])
	if all_done:
		_complete_quest(_active_idx)

func _objective_met(obj: Dictionary) -> bool:
	match obj["type"]:
		"collect":
			return _collected_totals.get(obj["target"], 0) >= int(obj["goal"])
		"craft":
			return crafted.get(obj["target"], 0) >= int(obj["goal"])
		"smelt":
			return smelted.get(obj["target"], 0) >= int(obj["goal"])
		"kill":
			return killed.get(obj["target"], 0) >= int(obj["goal"])
		"place":
			return placed.get(obj["target"], 0) >= int(obj["goal"])
		"survive_night":
			return nights_survived >= int(obj["goal"])
		"reach_depth":
			return max_depth_tiles >= int(obj["goal"])
	return false

func _complete_quest(idx: int) -> void:
	if _completed[idx]:
		return
	_completed[idx] = true
	var quest_id: String = str(QUESTS[idx].get("id", ""))
	quest_completed.emit(quest_id)
	# Advance to next incomplete quest
	_active_idx = idx + 1
	while _active_idx < QUESTS.size() and _completed[_active_idx]:
		_active_idx += 1

func _check_achievements() -> void:
	var total_kills: int = killed.get("any", 0)
	var boss_kills: int  = killed.get("boss_enemy", 0)
	if total_kills >= 1:   _try_unlock_achievement("first_kill")
	if total_kills >= 10:  _try_unlock_achievement("ten_kills")
	if total_kills >= 50:  _try_unlock_achievement("fifty_kills")
	if boss_kills >= 1:    _try_unlock_achievement("boss_killer")
	if nights_survived >= 5: _try_unlock_achievement("five_nights")
	if max_depth_tiles >= 100: _try_unlock_achievement("deep_100")
	if smelted.get("iron_ingot", 0) >= 10: _try_unlock_achievement("iron_age")
	if _collected_totals.get("log_oak", 0) >= 100: _try_unlock_achievement("woodcutter")
	if _collected_totals.get("cobblestone", 0) >= 500: _try_unlock_achievement("miner")

func _try_unlock_achievement(ach_id: String) -> void:
	if _achievements_done.get(ach_id, false):
		return
	_achievements_done[ach_id] = true
	achievement_unlocked.emit(ach_id)

## Returns the FIRST incomplete objective text — keeps the HUD focused.
func get_progress_text() -> String:
	var quest := get_active_quest()
	if quest.is_empty():
		return "All quests complete!"
	# Show first incomplete objective; if all done, show last one
	var last_line: String = ""
	for obj in quest["objectives"]:
		var cur: int = _get_current(obj)
		var goal: int = int(obj["goal"])
		var line: String = "%s: %d / %d" % [_obj_label(obj), cur, goal]
		last_line = line
		if cur < goal:
			return line
	return last_line

func _get_current(obj: Dictionary) -> int:
	match obj["type"]:
		"collect":    return _collected_totals.get(obj["target"], 0)
		"craft":      return crafted.get(obj["target"], 0)
		"smelt":      return smelted.get(obj["target"], 0)
		"kill":       return killed.get(obj["target"], 0)
		"place":      return placed.get(obj["target"], 0)
		"survive_night": return nights_survived
		"reach_depth":   return max_depth_tiles
	return 0

func _obj_label(obj: Dictionary) -> String:
	var otype: String = str(obj.get("type", ""))
	var target: String = str(obj.get("target", "")).replace("_", " ").capitalize()
	match otype:
		"collect":      return "Collect " + target
		"craft":        return "Craft "   + target
		"smelt":        return "Smelt "   + target
		"kill":
			if obj.get("target", "") == "any": return "Kill enemies"
			return "Kill " + target
		"place":
			if obj.get("target", "") == "any_block": return "Place blocks"
			return "Place " + target
		"survive_night": return "Survive nights"
		"reach_depth":   return "Reach depth (tiles)"
	return otype

# ── Save / Load ───────────────────────────────────────────────────────────────

func to_save_dict() -> Dictionary:
	return {
		"completed": _completed.duplicate(),
		"active_idx": _active_idx,
		"crafted": crafted.duplicate(),
		"killed": killed.duplicate(),
		"smelted": smelted.duplicate(),
		"placed": placed.duplicate(),
		"nights": nights_survived,
		"depth": max_depth_tiles,
		"collected": _collected_totals.duplicate(),
		"achievements": _achievements_done.duplicate(),
	}

func from_save_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	var comp: Array = d.get("completed", [])
	for i in min(comp.size(), _completed.size()):
		_completed[i] = bool(comp[i])
	_active_idx    = int(d.get("active_idx", 0))
	crafted        = d.get("crafted",  {})
	killed         = d.get("killed",   {})
	smelted        = d.get("smelted",  {})
	placed         = d.get("placed",   {})
	nights_survived = int(d.get("nights", 0))
	max_depth_tiles = int(d.get("depth", 0))
	_collected_totals = d.get("collected", {})
	_achievements_done = d.get("achievements", {})
