# save_manager.gd — Persistent data singleton (AutoLoad)
extends Node

signal coins_updated(new_total: int)
signal gems_updated(new_total: int)

const SAVE_PATH := "user://save_data.cfg"

const UPGRADE_MAX_LEVELS := {
	"speed": 10,
	"handling": 10,
	"coin_magnet": 8,
	"shield": 8,
}

# Costs raised ~5x — meaningful progression grind
const UPGRADE_COSTS := {
	"speed":       [400, 900, 1600, 2500, 3600, 5000, 7000, 9500, 12500, 16000],
	"handling":    [500, 1100, 1900, 2900, 4300, 5900, 8000, 11000, 14500, 18000],
	"coin_magnet": [600, 1200, 2000, 3200, 4800, 7000, 10000, 14000],
	"shield":      [800, 1600, 2800, 4200, 6000, 8500, 11500, 15000],
}

const SKIN_DATA: Array = [
	{"id": 0, "name": "Classic",   "cost": 0,     "gems": false, "color": Color(1.0, 1.0, 1.0),        "icon": "res://assets/ships/ship_classic.svg"},
	{"id": 1, "name": "Crimson",   "cost": 1200,  "gems": false, "color": Color(1.0, 0.2, 0.2),        "icon": "res://assets/ships/ship_classic.svg"},
	{"id": 2, "name": "Emerald",   "cost": 1200,  "gems": false, "color": Color(0.2, 1.0, 0.4),        "icon": "res://assets/ships/ship_classic.svg"},
	{"id": 3, "name": "Stinger",   "cost": 2000,  "gems": false, "color": Color(1.0, 0.85, 0.1),       "icon": "res://assets/ships/ship_stinger.svg"},
	{"id": 4, "name": "Violet",    "cost": 2000,  "gems": false, "color": Color(0.7, 0.2, 1.0),        "icon": "res://assets/ships/ship_classic.svg"},
	{"id": 5, "name": "Obsidian",  "cost": 3500,  "gems": false, "color": Color(0.15, 0.15, 0.25),     "icon": "res://assets/ships/ship_tank.svg"},
	{"id": 6, "name": "Aurora",    "cost": 20,    "gems": true,  "color": Color(0.4, 1.0, 0.9),        "icon": "res://assets/ships/ship_classic.svg"},
	{"id": 7, "name": "Supernova", "cost": 40,    "gems": true,  "color": Color(1.0, 0.5, 0.1),        "icon": "res://assets/ships/ship_alien.svg"},
	{"id": 8, "name": "Phantom",   "cost": 60,    "gems": true,  "color": Color(0.6, 0.6, 0.7, 0.7),  "icon": "res://assets/ships/ship_stinger.svg"},
	{"id": 9, "name": "Titan",     "cost": 5000,  "gems": false, "color": Color(0.4, 0.4, 0.5),        "icon": "res://assets/ships/ship_tank.svg"},
]

const TRAIL_DATA: Array = [
	{"id": 0, "name": "None",    "cost": 0,    "gems": false},
	{"id": 1, "name": "Comet",   "cost": 1000, "gems": false},
	{"id": 2, "name": "Spark",   "cost": 1000, "gems": false},
	{"id": 3, "name": "Plasma",  "cost": 1800, "gems": false},
	{"id": 4, "name": "Rainbow", "cost": 30,   "gems": true},
	{"id": 5, "name": "Eclipse", "cost": 50,   "gems": true},
]

const PLANET_DATA: Array = [
	{"id": 0, "name": "Terran", "cost": 0,     "gems": false, "color": Color(0.1, 0.4, 0.8),  "pattern": "earth"},
	{"id": 1, "name": "Lava",   "cost": 1600,  "gems": false, "color": Color(0.8, 0.2, 0.0),  "pattern": "lava"},
	{"id": 2, "name": "Toxic",  "cost": 1600,  "gems": false, "color": Color(0.2, 0.8, 0.1),  "pattern": "toxic"},
	{"id": 3, "name": "Ice",    "cost": 2400,  "gems": false, "color": Color(0.6, 0.9, 1.0),  "pattern": "ice"},
	{"id": 4, "name": "Void",   "cost": 30,    "gems": true,  "color": Color(0.1, 0.0, 0.2),  "pattern": "void"},
	{"id": 5, "name": "Pulsar", "cost": 60,    "gems": true,  "color": Color(0.9, 0.8, 0.1),  "pattern": "pulsar"},
	{"id": 6, "name": "Cyber",  "cost": 80,    "gems": true,  "color": Color(0.0, 1.0, 0.5),  "pattern": "grid"},
	{"id": 7, "name": "Desert", "cost": 3200,  "gems": false, "color": Color(0.9, 0.7, 0.3),  "pattern": "sand"},
]

var _data: Dictionary = {}

func _get_defaults() -> Dictionary:
	return {
		"coins": 50,
		"gems": 2,
		"best_score": 0,
		"total_runs": 0,
		"total_coins_ever": 0,
		"total_rings_cleared": 0,
		"upgrades": {
			"speed": 0,
			"handling": 0,
			"coin_magnet": 0,
			"shield": 0,
		},
		"unlocked_skins": [0],
		"unlocked_trails": [0],
		"unlocked_planets": [0],
		"active_skin": 0,
		"active_trail": 0,
		"active_planet": 0,
		"daily_reward_streak": 0,
		"last_reward_unix": 0,
		"last_crate_unix": 0,
		"settings_sfx": true,
		"settings_music": true,
		"settings_vibration": true,
		"settings_particles": true,
		"tutorial_seen": false,
	}

func _ready() -> void:
	_load()

func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	var defaults := _get_defaults()
	_data = {}
	for key in defaults.keys():
		if err == OK and cfg.has_section_key("data", key):
			_data[key] = cfg.get_value("data", key)
		else:
			_data[key] = defaults[key]

func _save() -> void:
	var cfg := ConfigFile.new()
	for key in _data.keys():
		cfg.set_value("data", key, _data[key])
	cfg.save(SAVE_PATH)

# ─── CURRENCY ─────────────────────────────────────────────────────────────────
func get_coins() -> int:
	return _data.get("coins", 0)

func add_coins(amount: int) -> void:
	_data["coins"] = get_coins() + amount
	_data["total_coins_ever"] = _data.get("total_coins_ever", 0) + amount
	_save()
	coins_updated.emit(_data["coins"])

func spend_coins(amount: int) -> bool:
	if get_coins() < amount:
		return false
	_data["coins"] -= amount
	_save()
	coins_updated.emit(_data["coins"])
	return true

func get_gems() -> int:
	return _data.get("gems", 0)

func add_gems(amount: int) -> void:
	_data["gems"] = get_gems() + amount
	_save()
	gems_updated.emit(_data["gems"])

func spend_gems(amount: int) -> bool:
	if get_gems() < amount:
		return false
	_data["gems"] -= amount
	_save()
	gems_updated.emit(_data["gems"])
	return true

# ─── SCORES ───────────────────────────────────────────────────────────────────
func get_best_score() -> int:
	return _data.get("best_score", 0)

func set_best_score(score: int) -> void:
	if score > get_best_score():
		_data["best_score"] = score
		_save()

func get_total_runs() -> int:
	return _data.get("total_runs", 0)

func increment_runs() -> void:
	_data["total_runs"] = get_total_runs() + 1
	_save()

func get_total_rings_cleared() -> int:
	return _data.get("total_rings_cleared", 0)

func increment_rings_cleared() -> void:
	_data["total_rings_cleared"] = get_total_rings_cleared() + 1

# ─── UPGRADES ─────────────────────────────────────────────────────────────────
func get_upgrade_level(name: String) -> int:
	var upgrades: Dictionary = _data.get("upgrades", {})
	return upgrades.get(name, 0)

func get_upgrade_cost(name: String) -> int:
	var level := get_upgrade_level(name)
	if level >= UPGRADE_MAX_LEVELS.get(name, 0):
		return -1
	var costs: Array = UPGRADE_COSTS.get(name, [])
	if level < costs.size():
		return costs[level]
	return -1

func buy_upgrade(name: String) -> bool:
	var cost := get_upgrade_cost(name)
	if cost == -1:
		return false
	if not spend_coins(cost):
		return false
	var upgrades: Dictionary = _data.get("upgrades", {})
	upgrades[name] = upgrades.get(name, 0) + 1
	_data["upgrades"] = upgrades
	_save()
	return true

func get_total_upgrade_spend() -> int:
	var total := 0
	for upg_id in UPGRADE_COSTS.keys():
		var level := get_upgrade_level(upg_id)
		var costs: Array = UPGRADE_COSTS[upg_id]
		for i in mini(level, costs.size()):
			total += costs[i]
	return total

func reset_upgrades() -> int:
	var spent := get_total_upgrade_spend()
	var refund := spent / 2
	_data["upgrades"] = {"speed": 0, "handling": 0, "coin_magnet": 0, "shield": 0}
	if refund > 0:
		add_coins(refund)
	else:
		_save()
	return refund

# ─── SKINS ────────────────────────────────────────────────────────────────────
func get_unlocked_skins() -> Array:
	var skins: Array = _data.get("unlocked_skins", [0])
	if not (0 in skins):
		skins.append(0)
	return skins

func is_skin_unlocked(skin_id: int) -> bool:
	return skin_id in get_unlocked_skins()

func buy_skin(skin_id: int) -> bool:
	if is_skin_unlocked(skin_id):
		return false
	if skin_id < 0 or skin_id >= SKIN_DATA.size():
		return false
	var info: Dictionary = SKIN_DATA[skin_id]
	if info["gems"]:
		if not spend_gems(info["cost"]):
			return false
	else:
		if not spend_coins(info["cost"]):
			return false
	var skins := get_unlocked_skins()
	skins.append(skin_id)
	_data["unlocked_skins"] = skins
	_save()
	return true

func get_active_skin() -> int:
	var id: int = _data.get("active_skin", 0)
	if id < 0 or id >= SKIN_DATA.size():
		id = 0
	if not is_skin_unlocked(id):
		id = 0
	return id

func set_active_skin(skin_id: int) -> void:
	_data["active_skin"] = skin_id
	_save()

# ─── TRAILS ───────────────────────────────────────────────────────────────────
func get_unlocked_trails() -> Array:
	var trails: Array = _data.get("unlocked_trails", [0])
	if not (0 in trails):
		trails.append(0)
	return trails

func is_trail_unlocked(trail_id: int) -> bool:
	return trail_id in get_unlocked_trails()

func buy_trail(trail_id: int) -> bool:
	if is_trail_unlocked(trail_id):
		return false
	if trail_id < 0 or trail_id >= TRAIL_DATA.size():
		return false
	var info: Dictionary = TRAIL_DATA[trail_id]
	if info["gems"]:
		if not spend_gems(info["cost"]):
			return false
	else:
		if not spend_coins(info["cost"]):
			return false
	var trails := get_unlocked_trails()
	trails.append(trail_id)
	_data["unlocked_trails"] = trails
	_save()
	return true

func get_active_trail() -> int:
	var id: int = _data.get("active_trail", 0)
	if id < 0 or id >= TRAIL_DATA.size():
		id = 0
	if not is_trail_unlocked(id):
		id = 0
	return id

func set_active_trail(trail_id: int) -> void:
	_data["active_trail"] = trail_id
	_save()

# ─── PLANETS ──────────────────────────────────────────────────────────────────
func get_unlocked_planets() -> Array:
	var planets: Array = _data.get("unlocked_planets", [0])
	if not (0 in planets):
		planets.append(0)
	return planets

func is_planet_unlocked(planet_id: int) -> bool:
	return planet_id in get_unlocked_planets()

func buy_planet(planet_id: int) -> bool:
	if is_planet_unlocked(planet_id):
		return false
	if planet_id < 0 or planet_id >= PLANET_DATA.size():
		return false
	var info: Dictionary = PLANET_DATA[planet_id]
	if info["gems"]:
		if not spend_gems(info["cost"]):
			return false
	else:
		if not spend_coins(info["cost"]):
			return false
	var planets := get_unlocked_planets()
	planets.append(planet_id)
	_data["unlocked_planets"] = planets
	_save()
	return true

func get_active_planet() -> int:
	var id: int = _data.get("active_planet", 0)
	if id < 0 or id >= PLANET_DATA.size():
		id = 0
	if not is_planet_unlocked(id):
		id = 0
	return id

func set_active_planet(planet_id: int) -> void:
	_data["active_planet"] = planet_id
	_save()

# ─── SETTINGS ─────────────────────────────────────────────────────────────────
func get_setting(key: String) -> bool:
	return _data.get("settings_" + key, true)

func set_setting(key: String, value: bool) -> void:
	_data["settings_" + key] = value
	_save()

func is_tutorial_seen() -> bool:
	return _data.get("tutorial_seen", false)

func mark_tutorial_seen() -> void:
	_data["tutorial_seen"] = true
	_save()

# ─── DAILY REWARDS (28-day cycle, 4 weeks, resets after day 28) ───────────────
const DAILY_REWARDS: Array = [
	# Week 1
	{"coins": 60,   "gems": 0,  "label": "Day 1"},
	{"coins": 80,   "gems": 0,  "label": "Day 2"},
	{"coins": 100,  "gems": 0,  "label": "Day 3"},
	{"coins": 150,  "gems": 0,  "label": "Day 4"},
	{"coins": 200,  "gems": 0,  "label": "Day 5"},
	{"coins": 250,  "gems": 1,  "label": "Day 6"},
	{"coins": 400,  "gems": 2,  "label": "Day 7 ★"},
	# Week 2
	{"coins": 100,  "gems": 0,  "label": "Day 8"},
	{"coins": 160,  "gems": 0,  "label": "Day 9"},
	{"coins": 220,  "gems": 1,  "label": "Day 10"},
	{"coins": 320,  "gems": 1,  "label": "Day 11"},
	{"coins": 450,  "gems": 2,  "label": "Day 12"},
	{"coins": 550,  "gems": 2,  "label": "Day 13"},
	{"coins": 900,  "gems": 4,  "label": "Day 14 ★★"},
	# Week 3
	{"coins": 200,  "gems": 1,  "label": "Day 15"},
	{"coins": 350,  "gems": 2,  "label": "Day 16"},
	{"coins": 500,  "gems": 2,  "label": "Day 17"},
	{"coins": 700,  "gems": 3,  "label": "Day 18"},
	{"coins": 900,  "gems": 3,  "label": "Day 19"},
	{"coins": 1100, "gems": 4,  "label": "Day 20"},
	{"coins": 1600, "gems": 6,  "label": "Day 21 ★★★"},
	# Week 4
	{"coins": 600,  "gems": 3,  "label": "Day 22"},
	{"coins": 800,  "gems": 4,  "label": "Day 23"},
	{"coins": 1100, "gems": 5,  "label": "Day 24"},
	{"coins": 1500, "gems": 6,  "label": "Day 25"},
	{"coins": 2000, "gems": 8,  "label": "Day 26"},
	{"coins": 2500, "gems": 10, "label": "Day 27"},
	{"coins": 3500, "gems": 15, "label": "Day 28 🏆"},
]
const DAILY_CYCLE := 28

func get_daily_streak() -> int:
	return _data.get("daily_reward_streak", 0)

func get_last_reward_unix() -> int:
	return _data.get("last_reward_unix", 0)

# Returns seconds remaining until next claim (0 = can claim now)
func get_daily_cooldown_remaining() -> int:
	var last := get_last_reward_unix()
	if last == 0:
		return 0
	var elapsed := int(Time.get_unix_time_from_system()) - last
	return maxi(86400 - elapsed, 0)

func can_claim_daily() -> bool:
	return get_daily_cooldown_remaining() == 0

func claim_daily_reward() -> Dictionary:
	if not can_claim_daily():
		return {}
	var now_unix := int(Time.get_unix_time_from_system())
	var streak := get_daily_streak()

	# Streak breaks if more than 48 h have passed since the last claim
	var last := get_last_reward_unix()
	if last > 0 and (now_unix - last) > 172800:
		streak = 0

	var reward: Dictionary = DAILY_REWARDS[streak % DAILY_CYCLE]
	streak += 1
	_data["daily_reward_streak"] = streak
	_data["last_reward_unix"] = now_unix
	if reward["coins"] > 0:
		add_coins(reward["coins"])
	if reward["gems"] > 0:
		add_gems(reward["gems"])
	_save()
	return reward

# ─── MYSTERY CRATE ────────────────────────────────────────────────────────────
const CRATE_COOLDOWN := 14400  # 4 hours

func get_crate_cooldown_remaining() -> int:
	var last_unix: int = _data.get("last_crate_unix", 0)
	if last_unix == 0:
		return 0
	var elapsed := int(Time.get_unix_time_from_system()) - last_unix
	return maxi(CRATE_COOLDOWN - elapsed, 0)

func can_claim_crate() -> bool:
	return get_crate_cooldown_remaining() == 0

func claim_crate() -> Dictionary:
	if not can_claim_crate():
		return {}
	_data["last_crate_unix"] = int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randf()
	var reward: Dictionary
	# Reduced rewards ~60%
	if roll < 0.50:
		reward = {"type": "common",    "rarity": "Common",    "coins": rng.randi_range(20, 60),    "gems": 0}
	elif roll < 0.78:
		reward = {"type": "rare",      "rarity": "Rare",      "coins": rng.randi_range(80, 180),   "gems": 0}
	elif roll < 0.93:
		reward = {"type": "epic",      "rarity": "Epic",      "coins": rng.randi_range(240, 400),  "gems": 1}
	else:
		reward = {"type": "legendary", "rarity": "Legendary", "coins": 480,                        "gems": 4}
	if reward["coins"] > 0:
		add_coins(reward["coins"])
	if reward["gems"] > 0:
		add_gems(reward["gems"])
	_save()
	return reward
