# game_manager.gd — Global game state singleton (AutoLoad)
# Tracks live session data: score, level, lives, active boosters, shield state.
extends Node

# ─── ENUMS ───────────────────────────────────────────────────────────────────
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, TRANSITION }

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal coins_changed(new_count: int)
signal shield_activated()
signal shield_hit()
signal shield_depleted()
signal booster_activated(type: String, duration: float)
signal game_over_triggered(final_score: int, coins_earned: int)
signal palette_changed(palette_index: int)

# ─── CONSTANTS ───────────────────────────────────────────────────────────────
const RINGS_PER_LEVEL := 10
const BASE_RING_SPEED := 130.0
const RING_SPEED_PER_LEVEL := 9.0
const BASE_PLAYER_SPEED := 2.2      # radians/sec
const PLAYER_SPEED_PER_UPGRADE := 0.18
const HANDLING_BASE := 1.0
const HANDLING_PER_UPGRADE := 0.25
const MAGNET_BASE_RADIUS := 60.0
const MAGNET_PER_UPGRADE := 30.0
const SHIELD_BASE_DURATION := 4.0
const SHIELD_PER_UPGRADE := 1.5
const BOSS_INTERVAL := 10            # boss ring every 10 levels

# ─── LIVE SESSION STATE ───────────────────────────────────────────────────────
var state: GameState = GameState.MENU
var score: int = 0
var level: int = 1
var rings_cleared: int = 0
var coins_this_run: int = 0

# Shield
var shield_active: bool = false
var shield_timer: float = 0.0
var shield_grace_timer: float = 0.0   # brief invincibility after shield breaks

# XP Booster
var xp_booster_active: bool = false
var xp_booster_timer: float = 0.0
var xp_booster_multiplier: float = 2.0

# Coin Booster
var coin_booster_active: bool = false
var coin_booster_timer: float = 0.0
var coin_booster_multiplier: float = 2.0

# ─── PALETTE CYCLING ─────────────────────────────────────────────────────────
# 5 palettes; cycles every 5 levels
const PALETTES: Array = [
	# [ring_color, player_color, planet_color, bg_color_inner, bg_color_outer, coin_color]
	[Color(0.20, 0.85, 1.00), Color(1.00, 1.00, 1.00), Color(0.10, 0.40, 0.80), Color(0.04, 0.04, 0.15), Color(0.02, 0.02, 0.08), Color(1.00, 0.90, 0.20)],
	[Color(0.90, 0.20, 1.00), Color(1.00, 0.80, 1.00), Color(0.50, 0.00, 0.80), Color(0.10, 0.02, 0.18), Color(0.04, 0.01, 0.10), Color(1.00, 0.60, 0.20)],
	[Color(0.20, 1.00, 0.45), Color(0.80, 1.00, 0.80), Color(0.00, 0.55, 0.30), Color(0.02, 0.12, 0.04), Color(0.01, 0.06, 0.02), Color(1.00, 1.00, 0.20)],
	[Color(1.00, 0.55, 0.10), Color(1.00, 0.90, 0.70), Color(0.70, 0.20, 0.00), Color(0.15, 0.06, 0.01), Color(0.08, 0.03, 0.01), Color(1.00, 0.95, 0.30)],
	[Color(1.00, 0.20, 0.30), Color(1.00, 0.70, 0.70), Color(0.80, 0.00, 0.20), Color(0.15, 0.02, 0.04), Color(0.08, 0.01, 0.02), Color(1.00, 0.80, 0.20)],
]
var current_palette_index: int = 0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return

	if shield_active:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shield_active = false
			shield_depleted.emit()

	if shield_grace_timer > 0.0:
		shield_grace_timer -= delta

	if xp_booster_active:
		xp_booster_timer -= delta
		if xp_booster_timer <= 0.0:
			xp_booster_active = false

	if coin_booster_active:
		coin_booster_timer -= delta
		if coin_booster_timer <= 0.0:
			coin_booster_active = false

# ─── GAME FLOW ────────────────────────────────────────────────────────────────
func start_game() -> void:
	score = 0
	level = 1
	rings_cleared = 0
	coins_this_run = 0
	shield_active = false
	shield_timer = 0.0
	shield_grace_timer = 0.0
	xp_booster_active = false
	coin_booster_active = false
	current_palette_index = 0
	state = GameState.PLAYING
	SaveManager.increment_runs()

func trigger_game_over() -> void:
	if state == GameState.GAME_OVER:
		return
	state = GameState.GAME_OVER
	var actual_coins := coins_this_run
	if coin_booster_active:
		actual_coins = int(actual_coins * coin_booster_multiplier)
	SaveManager.add_coins(actual_coins)
	if score > SaveManager.get_best_score():
		SaveManager.set_best_score(score)
	game_over_triggered.emit(score, actual_coins)

# ─── SCORE & LEVEL ───────────────────────────────────────────────────────────
func add_score(points: int) -> void:
	var multiplied := points
	if xp_booster_active:
		multiplied = int(points * xp_booster_multiplier)
	score += multiplied
	score_changed.emit(score)

func ring_passed() -> void:
	rings_cleared += 1
	var new_level := (rings_cleared / RINGS_PER_LEVEL) + 1
	if new_level != level:
		level = new_level
		level_changed.emit(level)
		_check_palette_change()
	var base_points := 50 + (level - 1) * 5
	add_score(base_points)

func _check_palette_change() -> void:
	var new_idx := mini((level - 1) / 5, PALETTES.size() - 1)
	if new_idx != current_palette_index:
		current_palette_index = new_idx
		palette_changed.emit(current_palette_index)

func collect_coin() -> void:
	coins_this_run += 10
	coins_changed.emit(coins_this_run)
	add_score(10)

# ─── SHIELD ───────────────────────────────────────────────────────────────────
func try_take_hit() -> bool:
	# Returns true if game should end, false if blocked by shield/grace
	if shield_grace_timer > 0.0:
		return false
	if shield_active:
		shield_active = false
		shield_grace_timer = 1.5
		shield_hit.emit()
		return false
	return true

func activate_shield() -> void:
	var duration := SHIELD_BASE_DURATION + SaveManager.get_upgrade_level("shield") * SHIELD_PER_UPGRADE
	shield_active = true
	shield_timer = duration
	shield_activated.emit()

# ─── STATS GETTERS ────────────────────────────────────────────────────────────
func get_ring_speed() -> float:
	return BASE_RING_SPEED + (level - 1) * RING_SPEED_PER_LEVEL

func get_player_angular_speed() -> float:
	return BASE_PLAYER_SPEED + SaveManager.get_upgrade_level("handling") * PLAYER_SPEED_PER_UPGRADE

func get_coin_magnet_radius() -> float:
	return MAGNET_BASE_RADIUS + SaveManager.get_upgrade_level("coin_magnet") * MAGNET_PER_UPGRADE

func get_ring_gap_size() -> float:
	# Gap shrinks as level increases; min 45 deg
	var base_gap := deg_to_rad(80.0)
	var reduction := (level - 1) * deg_to_rad(2.0)
	return maxf(base_gap - reduction, deg_to_rad(45.0))

func is_boss_level() -> bool:
	return level > 0 and level % BOSS_INTERVAL == 0

func get_palette() -> Array:
	return PALETTES[current_palette_index]

func get_ring_spawn_interval() -> float:
	# Time between ring spawns; decreases with level
	var base_interval := 2.8
	var reduction := (level - 1) * 0.07
	return maxf(base_interval - reduction, 1.1)

# ─── BOOSTERS ─────────────────────────────────────────────────────────────────
func activate_xp_booster(duration: float, multiplier: float) -> void:
	xp_booster_active = true
	xp_booster_timer = duration
	xp_booster_multiplier = multiplier
	booster_activated.emit("xp", duration)

func activate_coin_booster(duration: float, multiplier: float) -> void:
	coin_booster_active = true
	coin_booster_timer = duration
	coin_booster_multiplier = multiplier
	booster_activated.emit("coin", duration)
