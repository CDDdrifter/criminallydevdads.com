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
var daily_challenge_progress: Dictionary = {}  # {date_str: [0/1/2, 0/1/2, 0/1/2]}  0=pending 1=done 2=claimed
var win_streak: int = 0

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
	return int(Time.get_unix_time_from_system()) - last_hourly_ts >= 3600

func seconds_until_daily() -> int:
	return max(0, 86400 - (int(Time.get_unix_time_from_system()) - last_daily_ts))

func seconds_until_hourly() -> int:
	return max(0, 3600 - (int(Time.get_unix_time_from_system()) - last_hourly_ts))

func claim_daily() -> Dictionary:
	if not can_claim_daily():
		return {}
	var now := int(Time.get_unix_time_from_system())
	if now - last_daily_ts > 172800:
		daily_streak = 0
	daily_streak = min(daily_streak + 1, 7)
	last_daily_ts = now
	var rewards := [
		{"gold": 500,  "gems": 10},
		{"gold": 150,  "gems": 20},
		{"gold": 250,  "gems": 30},
		{"gold": 400,  "gems": 40},
		{"gold": 550,  "gems": 50},
		{"gold": 700,  "gems": 75},
		{"gold": 1000, "gems": 100, "xp": 1000},
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
{"desc": "Destroy 15 blocks with one bomb", "type": "blocks_15", "reward_gold": 400},
		{"desc": "Win 2 levels with 3 stars", "type": "stars_2", "reward_gold": 600},
		{"desc": "Spend 250 gold in the shop", "type": "shop_250", "reward_gold": 300},
		{"desc": "Use 5 heavy bombs in total", "type": "heavy_5", "reward_gold": 350},
		{"desc": "Destroy 30 enemy blocks", "type": "blocks_30", "reward_gold": 450},
		{"desc": "Win a level using only Heavy bombs", "type": "only_heavy", "reward_gold": 450},
		{"desc": "Win a level with 100% Castle HP", "type": "no_damage", "reward_gold": 500},
		{"desc": "Destroy 10 blocks with one Shockwave", "type": "shock_10", "reward_gold": 300},
		{"desc": "Win a level on Hard difficulty", "type": "hard_win", "reward_gold": 500},
		{"desc": "Win a level in under 45 seconds", "type": "speed_run", "reward_gold": 350},
		{"desc": "Use 4 different bomb types in one level", "type": "variety", "reward_gold": 400},
		{"desc": "Hit the enemy castle with a Bouncer", "type": "bounce_hit", "reward_gold": 300},
		{"desc": "Win 3 levels in a single session", "type": "marathon", "reward_gold": 600},
		{"desc": "Earn 1,000 total gold today", "type": "gold_hunter", "reward_gold": 400},
		{"desc": "Win without using any special bombs", "type": "pure_skill", "reward_gold": 500},
		{"desc": "Destroy a base block with a Driller", "type": "drill_deep", "reward_gold": 300},
		{"desc": "Gain enough XP to Rank Up", "type": "rank_up", "reward_gold": 500},
		{"desc": "Win with exactly 1 bomb remaining", "type": "clutch", "reward_gold": 450},
		{"desc": "Use a Cluster bomb to hit 5+ objects", "type": "cluster_hit", "reward_gold": 300},
		{"desc": "Change your Castle Skin and win", "type": "fashion_war", "reward_gold": 200},
		{"desc": "Get a 3-star on a level above 20", "type": "high_tier_pro", "reward_gold": 600},
		{"desc": "Spend any amount of gold in the Shop", "type": "any_purchase", "reward_gold": 250},
		{"desc": "Win a level with 5+ bombs remaining", "type": "overkill", "reward_gold": 300},
		{"desc": "Destroy 80+ blocks in one level", "type": "demolitionist", "reward_gold": 400},
		{"desc": "Play the game 2 days in a row", "type": "loyal_player", "reward_gold": 300}	]
	var picks: Array = []
	var used: Array = []
	while picks.size() < 3:
		var idx := rng.randi_range(0, pool.size() - 1)
		if idx not in used:
			used.append(idx)
			picks.append(pool[idx])
	return picks

func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%d-%02d-%02d" % [d.year, d.month, d.day]

func get_challenge_progress() -> Array:
	return _parse_progress(daily_challenge_progress.get(today_key(), [0, 0, 0]))

func _parse_progress(raw: Variant) -> Array:
	if not (raw is Array) or (raw as Array).size() != 3:
		return [0, 0, 0]
	var out: Array = [0, 0, 0]
	for i in 3:
		var v: Variant = (raw as Array)[i]
		out[i] = (2 if bool(v) else 0) if v is bool else int(v)
	return out

func check_and_complete_challenges(stats: Dictionary) -> void:
	if not stats.get("won", false):
		win_streak = 0
		save_game()
		return
	win_streak += 1
	var key := today_key()
	var progress := _parse_progress(daily_challenge_progress.get(key, [0, 0, 0]))
	var challenges := get_todays_challenges()
	var changed := false
	for i in challenges.size():
		if progress[i] != 0:
			continue
		if _challenge_met(challenges[i], stats):
			progress[i] = 1
			changed = true
	if changed:
		daily_challenge_progress[key] = progress
	save_game()

func _challenge_met(ch: Dictionary, stats: Dictionary) -> bool:
	match ch.get("type", ""):
		"blocks_15":     return stats.get("blocks_damaged", 0) >= 15
		"blocks_30":     return stats.get("blocks_damaged", 0) >= 30
		"demolitionist": return stats.get("blocks_damaged", 0) >= 80
		"shock_10":      return stats.get("blocks_damaged", 0) >= 10
		"no_damage":     return stats.get("player_hp_ratio", 0.0) >= 1.0
		"only_heavy":    return stats.get("used_bomb_types", []) == ["heavy"]
		"pure_skill":    return stats.get("used_bomb_types", []) == ["standard"]
		"hard_win":      return difficulty == "hard"
		"overkill":      return stats.get("bombs_remaining", 0) >= 5
		"clutch":        return stats.get("bombs_remaining", 0) == 1
		"variety":       return (stats.get("used_bomb_types", []) as Array).size() >= 4
		"marathon":      return win_streak >= 3
		"speed_run":     return stats.get("level_time", 999.0) <= 45.0
		"heavy_5":       return stats.get("heavy_bombs_used", 0) >= 5
		"loyal_player":  return daily_streak >= 2
		"any_purchase":  return stats.get("any_purchase", false)
	return false

func claim_daily_challenge(idx: int) -> int:
	var key := today_key()
	var progress := _parse_progress(daily_challenge_progress.get(key, [0, 0, 0]))
	if progress[idx] != 1:
		return 0
	var reward: int = get_todays_challenges()[idx].get("reward_gold", 0)
	progress[idx] = 2
	daily_challenge_progress[key] = progress
	gold += reward
	gold_changed.emit()
	save_game()
	return reward

func mark_any_purchase_challenge() -> void:
	var key := today_key()
	var progress := _parse_progress(daily_challenge_progress.get(key, [0, 0, 0]))
	var challenges := get_todays_challenges()
	var changed := false
	for i in challenges.size():
		if progress[i] == 0 and challenges[i].get("type", "") == "any_purchase":
			progress[i] = 1
			changed = true
	if changed:
		daily_challenge_progress[key] = progress
		save_game()

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
		mark_any_purchase_challenge()
		save_game()
		return true
	if cost.get("gems", 0) > 0 and gems >= cost["gems"]:
		gems -= cost["gems"]
		unlocked_bombs.append(bomb_id)
		bomb_unlocked.emit(bomb_id)
		mark_any_purchase_challenge()
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
	mark_any_purchase_challenge()
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
		"challenge_progress": daily_challenge_progress, "win_streak": win_streak,
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
	win_streak = int(raw.get("win_streak", 0))
	_reapply_all_upgrades()
