extends Node

const SAVE_FILE := "user://fortfury.dat"
const VERSION := 2

# ── Session (not saved) ───────────────────────────────────────────────────────
var current_level: int = 1

# ── Currency & Rank ──────────────────────────────────────────────────────────
var gold: int = 500
var gems: int = 20
var xp: int = 0
var player_rank: int = 1

# ── Level Progress  key = str(level_id) ──────────────────────────────────────
var level_progress: Dictionary = {}

# ── Unlocks ───────────────────────────────────────────────────────────────────
var unlocked_bombs: Array = ["standard"]
var castle_hp_bonus: float = 0.0       # from purchased upgrades
var castle_material_tier: int = 0      # 0=wood, 1=stone, 2=metal override
var unlocked_skins: Array = ["default"]
var active_skin: String = "default"

# ── Daily / Hourly ────────────────────────────────────────────────────────────
var last_daily_ts: int = 0
var daily_streak: int = 0
var last_hourly_ts: int = 0
var daily_challenge_progress: Dictionary = {}  # {date_str: [bool,bool,bool]}

# ── Settings ──────────────────────────────────────────────────────────────────
var sfx_on: bool = true
var music_on: bool = true
var haptics_on: bool = true
var difficulty: String = "normal"

# ── Bomb unlock XP thresholds ─────────────────────────────────────────────────
const BOMB_UNLOCK_XP: Dictionary = {
	"standard": 0, "heavy": 80, "splitter": 180, "bouncer": 300,
	"driller": 450, "shockwave": 620, "cluster": 820, "freeze": 1050,
	"laser": 1310, "fire": 1600, "lightning": 1920, "nuke": 2270,
	"magnet": 2650, "ghost": 3060, "sticky": 3500, "vortex": 3980,
}

# ── Shop items ────────────────────────────────────────────────────────────────
const SHOP_BOMBS: Dictionary = {
	"heavy":      {"gold": 300,  "gems": 0},
	"splitter":   {"gold": 600,  "gems": 0},
	"bouncer":    {"gold": 900,  "gems": 0},
	"driller":    {"gold": 1400, "gems": 0},
	"shockwave":  {"gold": 2000, "gems": 0},
	"cluster":    {"gold": 2800, "gems": 0},
	"freeze":     {"gold": 3800, "gems": 0},
	"laser":      {"gold": 5000, "gems": 10},
	"fire":       {"gold": 0,    "gems": 15},
	"lightning":  {"gold": 0,    "gems": 20},
	"nuke":       {"gold": 0,    "gems": 30},
	"magnet":     {"gold": 0,    "gems": 25},
	"ghost":      {"gold": 0,    "gems": 35},
	"sticky":     {"gold": 0,    "gems": 40},
	"vortex":     {"gold": 0,    "gems": 50},
}
const SHOP_UPGRADES: Dictionary = {
	"castle_wall_stone": {"gold": 1500, "gems": 0,  "desc": "+Stone base for your castle"},
	"castle_wall_metal": {"gold": 0,    "gems": 40, "desc": "+Metal reinforcement"},
	"castle_hp_10":      {"gold": 800,  "gems": 0,  "desc": "+10% castle HP"},
	"castle_hp_25":      {"gold": 2500, "gems": 0,  "desc": "+25% castle HP"},
	"castle_hp_50":      {"gold": 0,    "gems": 60, "desc": "+50% castle HP"},
}
var purchased_upgrades: Array = []

# ── Achievements ──────────────────────────────────────────────────────────────
const ACHIEVEMENTS: Dictionary = {
	"first_blood":    {"title": "First Blood",     "desc": "Win your first level",          "xp": 50},
	"sharpshooter":   {"title": "Sharpshooter",    "desc": "Win with 3+ bombs remaining",   "xp": 100},
	"bomb_collector": {"title": "Bomb Collector",  "desc": "Unlock 8 bomb types",           "xp": 200},
	"centurion":      {"title": "Centurion",        "desc": "Complete level 100",            "xp": 1000},
	"three_star_10":  {"title": "Perfectionist I",  "desc": "3-star the first 10 levels",   "xp": 300},
	"three_star_50":  {"title": "Perfectionist II", "desc": "3-star 50 levels",              "xp": 600},
	"streak_7":       {"title": "Loyal Warrior",   "desc": "7-day login streak",            "xp": 200},
	"nuke_user":      {"title": "Overkill",         "desc": "Use the Nuke bomb",             "xp": 150},
}
var unlocked_achievements: Array = []

# ── Events ────────────────────────────────────────────────────────────────────
var active_event: Dictionary = {}  # populated at runtime if date matches

signal xp_changed
signal gold_changed
signal bomb_unlocked(id: String)
signal achievement_unlocked(id: String)

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	load_game()
	_refresh_unlocks()
	_check_event()

func _refresh_unlocks() -> void:
	for bomb_id in BOMB_UNLOCK_XP:
		if bomb_id not in unlocked_bombs and xp >= BOMB_UNLOCK_XP[bomb_id]:
			unlocked_bombs.append(bomb_id)
			bomb_unlocked.emit(bomb_id)

func _check_event() -> void:
	var now := Time.get_date_dict_from_system()
	# Weekend double-XP event
	if now.weekday in [0, 6]:
		active_event = {"type": "double_xp", "label": "Weekend Double XP!", "mult": 2.0}
	else:
		active_event = {}

# ── XP & Rank ─────────────────────────────────────────────────────────────────

func xp_needed_for_rank(r: int) -> int:
	var base := 200
	var total := 0
	for i in range(1, r):
		total += int(base * pow(1.12, i - 1))
	return total

func rank_from_xp(total_xp: int) -> int:
	var r := 1
	while r < 100 and total_xp >= xp_needed_for_rank(r + 1):
		r += 1
	return r

func xp_progress_in_rank() -> float:
	var base_xp := xp_needed_for_rank(player_rank)
	var next_xp := xp_needed_for_rank(player_rank + 1)
	if next_xp <= base_xp:
		return 1.0
	return float(xp - base_xp) / float(next_xp - base_xp)

func add_xp(amount: int) -> void:
	var mult: float = float(active_event.get("mult", 1.0)) if active_event.get("type") == "double_xp" else 1.0
	xp += int(amount * mult)
	var new_rank := rank_from_xp(xp)
	player_rank = new_rank
	_refresh_unlocks()
	xp_changed.emit()
	save_game()

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit()
	save_game()

# ── Level Completion ──────────────────────────────────────────────────────────

func complete_level(level_id: int, stars: int, score: int) -> Dictionary:
	var key := str(level_id)
	var prev: Dictionary = level_progress.get(key, {})
	var first_clear: bool = not bool(prev.get("completed", false))
	var new_stars: int = max(int(prev.get("stars", 0)), stars)
	var new_score: int = max(int(prev.get("score", 0)), score)
	level_progress[key] = {"stars": new_stars, "score": new_score, "completed": true}

	var xp_earn := stars * 60 + (150 if first_clear else 0)
	var gold_earn := stars * 30 + score / 120
	add_xp(xp_earn)
	add_gold(gold_earn)

	_check_achievements(level_id, stars)
	save_game()
	return {"xp": xp_earn, "gold": gold_earn, "first_clear": first_clear}

func get_level_stars(level_id: int) -> int:
	return level_progress.get(str(level_id), {}).get("stars", 0)

func is_level_completed(level_id: int) -> bool:
	return level_progress.get(str(level_id), {}).get("completed", false)

func is_level_unlocked(level_id: int) -> bool:
	if level_id <= 1:
		return true
	return is_level_completed(level_id - 1)

func get_total_stars() -> int:
	var t := 0
	for k in level_progress:
		t += level_progress[k].get("stars", 0)
	return t

func highest_unlocked_level() -> int:
	for i in range(100, 0, -1):
		if is_level_unlocked(i):
			return i
	return 1

# ── Daily / Hourly Rewards ────────────────────────────────────────────────────

func can_claim_daily() -> bool:
	return int(Time.get_unix_time_from_system()) - last_daily_ts >= 86400

func can_claim_hourly() -> bool:
	return int(Time.get_unix_time_from_system()) - last_hourly_ts >= 14400

func seconds_until_daily() -> int:
	return max(0, 86400 - (int(Time.get_unix_time_from_system()) - last_daily_ts))

func seconds_until_hourly() -> int:
	return max(0, 14400 - (int(Time.get_unix_time_from_system()) - last_hourly_ts))

func claim_daily() -> Dictionary:
	if not can_claim_daily():
		return {}
	var now := int(Time.get_unix_time_from_system())
	if now - last_daily_ts > 172800:
		daily_streak = 0
	daily_streak = min(daily_streak + 1, 7)
	last_daily_ts = now
	var rewards := [
		{"gold": 150,  "gems": 5},
		{"gold": 225,  "gems": 10},
		{"gold": 300,  "gems": 15},
		{"gold": 400,  "gems": 20},
		{"gold": 550,  "gems": 30},
		{"gold": 700,  "gems": 40},
		{"gold": 1000, "gems": 60, "xp": 200},
	]
	var r: Dictionary = rewards[daily_streak - 1]
	gold += r.get("gold", 0)
	gems += r.get("gems", 0)
	gold_changed.emit()
	if r.has("xp"):
		add_xp(r["xp"])
	if daily_streak == 7:
		_check_achievement("streak_7")
	save_game()
	return r

func claim_hourly() -> Dictionary:
	if not can_claim_hourly():
		return {}
	last_hourly_ts = int(Time.get_unix_time_from_system())
	var g := randi_range(40, 100)
	gold += g
	gold_changed.emit()
	save_game()
	return {"gold": g}

# ── Daily Challenges ──────────────────────────────────────────────────────────

func get_todays_challenges() -> Array:
	var d := Time.get_date_dict_from_system()
	var key := "%d-%02d-%02d" % [d.year, d.month, d.day]
	# Seeded random so challenges are same for the whole day
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var pool := [
		{"desc": "Win a level without using Nuke", "type": "no_nuke",      "reward_gold": 200},
		{"desc": "Win 2 levels in a row",           "type": "win_streak_2", "reward_gold": 300},
		{"desc": "Destroy 50+ blocks in one level", "type": "blocks_50",   "reward_gold": 250},
		{"desc": "Win using only Standard bombs",   "type": "only_std",    "reward_gold": 350},
		{"desc": "Get a 3-star on any level",       "type": "three_star",  "reward_gold": 400},
		{"desc": "Win with 4+ bombs remaining",     "type": "bombs_left_4","reward_gold": 300},
	]
	var picks: Array = []
	var used: Array = []
	while picks.size() < 3:
		var idx := rng.randi_range(0, pool.size() - 1)
		if idx not in used:
			used.append(idx)
			picks.append(pool[idx])
	return picks

# ── Shop ──────────────────────────────────────────────────────────────────────

func buy_bomb(bomb_id: String) -> bool:
	if bomb_id in unlocked_bombs:
		return false
	var cost: Dictionary = SHOP_BOMBS.get(bomb_id, {})
	if cost.get("gold", 0) > 0 and gold >= cost["gold"]:
		gold -= cost["gold"]
		unlocked_bombs.append(bomb_id)
		bomb_unlocked.emit(bomb_id)
		gold_changed.emit()
		save_game()
		return true
	if cost.get("gems", 0) > 0 and gems >= cost["gems"]:
		gems -= cost["gems"]
		unlocked_bombs.append(bomb_id)
		bomb_unlocked.emit(bomb_id)
		save_game()
		return true
	return false

func buy_upgrade(upg_id: String) -> bool:
	if upg_id in purchased_upgrades:
		return false
	var cost: Dictionary = SHOP_UPGRADES.get(upg_id, {})
	if cost.get("gold", 0) > 0 and gold >= cost["gold"]:
		gold -= cost["gold"]
		gold_changed.emit()
	elif cost.get("gems", 0) > 0 and gems >= cost["gems"]:
		gems -= cost["gems"]
	else:
		return false
	purchased_upgrades.append(upg_id)
	_apply_upgrade(upg_id)
	save_game()
	return true

func _apply_upgrade(upg_id: String) -> void:
	match upg_id:
		"castle_wall_stone":  castle_material_tier = max(castle_material_tier, 1)
		"castle_wall_metal":  castle_material_tier = max(castle_material_tier, 2)
		"castle_hp_10":       castle_hp_bonus += 0.10
		"castle_hp_25":       castle_hp_bonus += 0.25
		"castle_hp_50":       castle_hp_bonus += 0.50

func _reapply_all_upgrades() -> void:
	castle_hp_bonus = 0.0
	castle_material_tier = 0
	for upg in purchased_upgrades:
		_apply_upgrade(upg)

# ── Achievements ──────────────────────────────────────────────────────────────

func _check_achievements(level_id: int, stars: int) -> void:
	if is_level_completed(1):
		_check_achievement("first_blood")
	if level_id == 100:
		_check_achievement("centurion")
	if stars == 3:
		if _stars_in_range(1, 10) == 30:
			_check_achievement("three_star_10")
		if _stars_in_range(1, 50) == 150:
			_check_achievement("three_star_50")

func _stars_in_range(from_id: int, to_id: int) -> int:
	var total := 0
	for i in range(from_id, to_id + 1):
		total += get_level_stars(i)
	return total

func _check_achievement(id: String) -> void:
	if id in unlocked_achievements:
		return
	unlocked_achievements.append(id)
	if ACHIEVEMENTS.has(id):
		add_xp(ACHIEVEMENTS[id]["xp"])
	achievement_unlocked.emit(id)
	save_game()

func check_achievement_direct(id: String) -> void:
	_check_achievement(id)

# ── Save / Load ───────────────────────────────────────────────────────────────

func save_game() -> void:
	var data := {
		"v": VERSION, "gold": gold, "gems": gems, "xp": xp, "rank": player_rank,
		"progress": level_progress, "bombs": unlocked_bombs, "skins": unlocked_skins,
		"skin": active_skin, "upgrades": purchased_upgrades,
		"hp_bonus": castle_hp_bonus, "mat_tier": castle_material_tier,
		"daily_ts": last_daily_ts, "streak": daily_streak,
		"hourly_ts": last_hourly_ts, "achievements": unlocked_achievements,
		"sfx": sfx_on, "music": music_on, "difficulty": difficulty,
		"challenge_progress": daily_challenge_progress,
	}
	var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		save_game()
		return
	var f := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not f:
		return
	var raw: Variant = JSON.parse_string(f.get_as_text())
	if typeof(raw) != TYPE_DICTIONARY:
		return
	gold = int(raw.get("gold", 500))
	gems = int(raw.get("gems", 20))
	xp = int(raw.get("xp", 0))
	player_rank = int(raw.get("rank", 1))
	level_progress = raw.get("progress", {})
	unlocked_bombs = raw.get("bombs", ["standard"])
	unlocked_skins = raw.get("skins", ["default"])
	active_skin = raw.get("skin", "default")
	purchased_upgrades = raw.get("upgrades", [])
	castle_hp_bonus = float(raw.get("hp_bonus", 0.0))
	castle_material_tier = int(raw.get("mat_tier", 0))
	last_daily_ts = int(raw.get("daily_ts", 0))
	daily_streak = int(raw.get("streak", 0))
	last_hourly_ts = int(raw.get("hourly_ts", 0))
	unlocked_achievements = raw.get("achievements", [])
	sfx_on = raw.get("sfx", true)
	music_on = raw.get("music", true)
	difficulty = raw.get("difficulty", "normal")
	daily_challenge_progress = raw.get("challenge_progress", {})
	_reapply_all_upgrades()
