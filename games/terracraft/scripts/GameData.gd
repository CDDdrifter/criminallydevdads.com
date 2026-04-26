## GameData.gd — Global singleton (Autoload)
## Holds shared game state accessible from any script.
## Think of this as the "memory" of the game.
extends Node

# ─────────────────────────────────────────────
#  SIGNALS  (broadcast events to any listener)
# ─────────────────────────────────────────────
signal day_changed(day_number: int)
signal time_of_day_changed(normalized: float)   # 0.0 = midnight, 0.5 = noon
signal player_died
signal item_picked_up(item_id: String, count: int)
signal open_crafting_requested

# ─────────────────────────────────────────────
#  TIME / DAY CYCLE
# ─────────────────────────────────────────────
const DAY_LENGTH_SECONDS := 480.0   # how long one full day lasts (8 minutes)
var time_of_day: float = 0.25       # start at dawn (0.25 = 6am, 0.75 = 6pm)
var day_number: int = 1
var is_daytime: bool = true

# ─────────────────────────────────────────────
#  WORLD SETTINGS
# ─────────────────────────────────────────────
const TILE_SIZE := 16               # pixels per tile — change this if you resize your tiles
const CHUNK_WIDTH := 32             # tiles wide per chunk
const CHUNK_HEIGHT := 256           # tiles tall per chunk (underground depth)
const WORLD_WIDTH_CHUNKS := 32      # total world width in chunks (32 chunks × 32 tiles = 1024 tiles wide)
const SURFACE_HEIGHT := 80          # tile row where the ground surface appears (from top)

# ─────────────────────────────────────────────
#  PLAYER STATS  (also stored in save file)
# ─────────────────────────────────────────────
var player_health: float = 100.0
var player_max_health: float = 100.0
var player_hunger: float = 100.0
var player_max_hunger: float = 100.0
var player_position: Vector2 = Vector2.ZERO
var spawn_point: Vector2 = Vector2.ZERO    ## Set by sleeping in a bed.
var crystal_gates: Dictionary = {}          ## name -> Vector2 world position.
## Per-chest inventories keyed by "x,y" tile position string. Each value is Array of item Dicts.
var chest_inventories: Dictionary = {}

# ─────────────────────────────────────────────
#  WORLD SEED
# ─────────────────────────────────────────────
var world_seed: int = 0             # set before generating world; 0 = random

## Active skin resource — set from the main menu skin picker.
## Persists across scene changes (autoload).
var selected_skin: PlayerSkin = null

# ─────────────────────────────────────────────
#  PLAYER CLASSES — color + stat variants
#  Colors go from dark (weak) to bright (strong). No black or grey allowed.
#  Each class has a color modulate applied to the player sprite, plus
#  multipliers for health, speed, damage, and hunger drain rate.
#  unlock_kills / unlock_elites / unlock_bosses: cumulative kill thresholds
#  needed to unlock that class (tracked persistently across all worlds).
# ─────────────────────────────────────────────
const PLAYER_CLASSES: Array = [
	# ── 0 — Base dark classes (always unlocked) ──────────────────────────────
	{
		"id": "deep_violet",  "name": "Shadow Walker",
		"color": Color(0.30, 0.08, 0.45),
		"health_mult": 0.70,  "speed_mult": 0.78,  "damage_mult": 0.70,  "hunger_mult": 0.80,
		"unlock_kills": 0,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "A warrior cloaked in violet shadow. Weakest form."
	},
	{
		"id": "dark_mahogany",  "name": "Ember Soul",
		"color": Color(0.42, 0.10, 0.06),
		"health_mult": 0.78,  "speed_mult": 0.83,  "damage_mult": 0.78,  "hunger_mult": 0.85,
		"unlock_kills": 0,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "Tempered by fire. A darker second beginning."
	},
	# ── Tier 1 — Early unlocks (common kills) ────────────────────────────────
	{
		"id": "navy_blue",  "name": "Deep Blue",
		"color": Color(0.05, 0.12, 0.55),
		"health_mult": 0.82,  "speed_mult": 0.87,  "damage_mult": 0.82,  "hunger_mult": 0.87,
		"unlock_kills": 10,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "Steady as deep water. Unlocked with 10 kills."
	},
	{
		"id": "forest_green",  "name": "Forest Guardian",
		"color": Color(0.06, 0.32, 0.10),
		"health_mult": 0.85,  "speed_mult": 0.90,  "damage_mult": 0.85,  "hunger_mult": 0.88,
		"unlock_kills": 25,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "One with nature. Unlocked with 25 kills."
	},
	{
		"id": "dark_crimson",  "name": "Blood Knight",
		"color": Color(0.55, 0.04, 0.04),
		"health_mult": 0.88,  "speed_mult": 0.90,  "damage_mult": 0.92,  "hunger_mult": 0.90,
		"unlock_kills": 0,  "unlock_elites": 10,  "unlock_bosses": 0,
		"description": "Hardened by elite battles. Unlocked with 10 elite kills."
	},
	# ── Tier 2 — Mid unlocks ─────────────────────────────────────────────────
	{
		"id": "dark_teal",  "name": "Sea Warden",
		"color": Color(0.04, 0.38, 0.40),
		"health_mult": 0.90,  "speed_mult": 0.93,  "damage_mult": 0.90,  "hunger_mult": 0.92,
		"unlock_kills": 50,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "Calm and relentless. Unlocked with 50 kills."
	},
	{
		"id": "plum_purple",  "name": "Arcane Monk",
		"color": Color(0.45, 0.08, 0.55),
		"health_mult": 0.92,  "speed_mult": 0.96,  "damage_mult": 0.92,  "hunger_mult": 0.93,
		"unlock_kills": 0,  "unlock_elites": 0,  "unlock_bosses": 1,
		"description": "Blessed by defeating a Boss. Unlocked with 1 boss kill."
	},
	{
		"id": "deep_orange",  "name": "Flame Striker",
		"color": Color(0.75, 0.28, 0.02),
		"health_mult": 0.95,  "speed_mult": 0.97,  "damage_mult": 0.97,  "hunger_mult": 0.95,
		"unlock_kills": 100,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "A warrior of fire. Unlocked with 100 kills."
	},
	{
		"id": "olive_green",  "name": "Veteran Scout",
		"color": Color(0.42, 0.50, 0.04),
		"health_mult": 0.97,  "speed_mult": 1.00,  "damage_mult": 0.96,  "hunger_mult": 0.96,
		"unlock_kills": 0,  "unlock_elites": 30,  "unlock_bosses": 0,
		"description": "A seasoned scout. Unlocked with 30 elite kills."
	},
	# ── Tier 3 — Advanced unlocks ────────────────────────────────────────────
	{
		"id": "rust_orange",  "name": "Iron Wanderer",
		"color": Color(0.80, 0.35, 0.08),
		"health_mult": 1.00,  "speed_mult": 1.02,  "damage_mult": 1.00,  "hunger_mult": 1.00,
		"unlock_kills": 0,  "unlock_elites": 0,  "unlock_bosses": 3,
		"description": "Standard power level. Unlocked with 3 boss kills."
	},
	{
		"id": "cobalt_blue",  "name": "Cobalt Champion",
		"color": Color(0.08, 0.38, 0.90),
		"health_mult": 1.05,  "speed_mult": 1.05,  "damage_mult": 1.05,  "hunger_mult": 1.02,
		"unlock_kills": 200,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "A true champion. Unlocked with 200 kills."
	},
	{
		"id": "emerald_green",  "name": "Emerald Warrior",
		"color": Color(0.04, 0.75, 0.20),
		"health_mult": 1.08,  "speed_mult": 1.07,  "damage_mult": 1.08,  "hunger_mult": 1.03,
		"unlock_kills": 0,  "unlock_elites": 75,  "unlock_bosses": 0,
		"description": "Shining bright. Unlocked with 75 elite kills."
	},
	{
		"id": "magenta",  "name": "Chaos Mage",
		"color": Color(0.88, 0.05, 0.70),
		"health_mult": 1.12,  "speed_mult": 1.10,  "damage_mult": 1.12,  "hunger_mult": 1.05,
		"unlock_kills": 0,  "unlock_elites": 0,  "unlock_bosses": 5,
		"description": "Chaos incarnate. Unlocked with 5 boss kills."
	},
	# ── Tier 4 — Elite unlocks ───────────────────────────────────────────────
	{
		"id": "bright_orange",  "name": "Solar Knight",
		"color": Color(1.00, 0.52, 0.04),
		"health_mult": 1.16,  "speed_mult": 1.12,  "damage_mult": 1.16,  "hunger_mult": 1.07,
		"unlock_kills": 350,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "Radiant as the sun. Unlocked with 350 kills."
	},
	{
		"id": "sky_blue",  "name": "Sky Sentinel",
		"color": Color(0.22, 0.70, 1.00),
		"health_mult": 1.20,  "speed_mult": 1.15,  "damage_mult": 1.18,  "hunger_mult": 1.08,
		"unlock_kills": 0,  "unlock_elites": 100,  "unlock_bosses": 0,
		"description": "Born of the sky. Unlocked with 100 elite kills."
	},
	{
		"id": "coral_red",  "name": "Inferno Lord",
		"color": Color(1.00, 0.30, 0.18),
		"health_mult": 1.25,  "speed_mult": 1.17,  "damage_mult": 1.25,  "hunger_mult": 1.10,
		"unlock_kills": 0,  "unlock_elites": 0,  "unlock_bosses": 10,
		"description": "Master of inferno. Unlocked with 10 boss kills."
	},
	{
		"id": "bright_violet",  "name": "Void Sage",
		"color": Color(0.65, 0.15, 1.00),
		"health_mult": 1.32,  "speed_mult": 1.20,  "damage_mult": 1.30,  "hunger_mult": 1.12,
		"unlock_kills": 500,  "unlock_elites": 0,  "unlock_bosses": 0,
		"description": "A sage of the void. Unlocked with 500 kills."
	},
	# ── Tier 5 — Legendary unlocks ───────────────────────────────────────────
	{
		"id": "gold",  "name": "Golden God",
		"color": Color(1.00, 0.82, 0.04),
		"health_mult": 1.40,  "speed_mult": 1.25,  "damage_mult": 1.40,  "hunger_mult": 1.15,
		"unlock_kills": 0,  "unlock_elites": 200,  "unlock_bosses": 0,
		"description": "Forged in gold. Unlocked with 200 elite kills."
	},
	{
		"id": "bright_cyan",  "name": "Crystal Storm",
		"color": Color(0.10, 0.95, 0.95),
		"health_mult": 1.55,  "speed_mult": 1.30,  "damage_mult": 1.50,  "hunger_mult": 1.18,
		"unlock_kills": 0,  "unlock_elites": 0,  "unlock_bosses": 20,
		"description": "Pure crystal energy. Unlocked with 20 boss kills."
	},
	{
		"id": "ivory_white",  "name": "Ascended",
		"color": Color(1.00, 0.96, 0.88),
		"health_mult": 1.75,  "speed_mult": 1.40,  "damage_mult": 1.75,  "hunger_mult": 1.25,
		"unlock_kills": 1000,  "unlock_elites": 50,  "unlock_bosses": 25,
		"description": "Transcended mortality. The ultimate form. Unlocked with 1000 kills, 50 elite kills, and 25 boss kills."
	},
]

## Currently selected player class index (0-based into PLAYER_CLASSES).
var player_class_index: int = 0

# ─────────────────────────────────────────────
#  PERSISTENT KILL STATISTICS
#  These track across ALL worlds and all saves.
#  Stored in user://player_stats.json separately from world saves.
# ─────────────────────────────────────────────
const STATS_PATH: String = "user://player_stats.json"
var total_enemy_kills: int = 0   ## All enemy kills (all tiers)
var elite_kills: int = 0          ## Elite-tier enemy kills only
var boss_kills: int = 0           ## Boss-tier enemy kills only
## Which class indices are currently unlocked (true = available to select).
var unlocked_classes: Array = []  ## Array[bool], indexed by PLAYER_CLASSES

# World generation settings (chosen in MainMenu world settings panel)
var creative_mode: bool = false     # true = god/fly mode; double-jump to toggle in-game
var admin_mode_unlocked: bool = false  ## Set true by tapping the sun 3× on the title screen.
var world_type: String = "normal"   # normal / flat / island / underground
var world_size: String = "infinite" # small / medium / large / infinite
var structures_enabled: Dictionary = {
	"villages":         true,
	"temples":          true,
	"towns":            true,
	"towers":           true,
	"ruins":            true,
	"blacksmith":       true,
	"library":          true,
	"bunker":           true,
	"watchtower":       true,
	"market_stall":     true,
	"graveyard":        true,
	"snow_cabin":       true,
	"desert_outpost":   true,
	"mine_entrance":    true,
	"abandoned_farm":   true,
	"dungeon":          true,
	"castle":           true,
	"city":             true,
	"floating_islands": true,
	"floating_castle":  true,
}

## Difficulty: "easy" | "normal" | "hard" — set from world settings before generation.
var difficulty: String = "normal"

# ─────────────────────────────────────────────
#  DIFFICULTY / BALANCE SETTINGS
# ─────────────────────────────────────────────
## Difficulty damage multiplier applied to every player melee hit.
## Set from World Settings (easy=0.5, normal=1.0, hard=2.0).
## Stack with class_damage_mult for final output.
var player_damage_mult: float = 1.0

## Per-class damage multiplier set from PLAYER_CLASSES[player_class_index].damage_mult.
## Applied in Player._apply_class_stats() and stacked with player_damage_mult in melee.
var class_damage_mult: float = 1.0

## Sensitivity for gamepad / touch aim stick (1.0 = default, higher = more responsive).
var aim_sensitivity: float = 2.5

## Aim / mining settings — adjustable in Options.
## Deadzone for the right stick / touch aim analogue (0.05–0.50).
var aim_deadzone: float = 0.20
## 0 = "Last Aimed"  — mines in the direction the stick was last pushed (latch).
## 1 = "Auto-target" — when stick is at rest, auto-targets the nearest block ahead.
var aim_style: int = 0
## When true, pressing Crouch toggles crouching on/off instead of hold-to-crouch.
var crouch_toggle: bool = false
## When true, axes only auto-target wood/leaves, pickaxes only stone/ores, shovels only dirt types.
var tool_focus: bool = false

## True once a joypad has been seen — HTML5 sets this on first button press.
var joypad_active: bool = false

# ── Visual effects settings (persisted in save) ──────────────────────────────
var fx: Dictionary = {
	"enabled":       true,  # master kill switch
	"flicker":       true,  # torch/fire light flicker
	"embers":        true,  # floating ember particles on fires
	"landing_dust":  true,  # dust puff on player landing
	"leaves":        true,  # falling leaves in forest biome
	"weather":       true,  # rain / snow
	"lightning":     true,  # lightning strikes during storms
	"carried_torch": true,  # held torch lights up area
	"quality":       1,     # 0=off 1=low 2=med 3=high
	"brightness":    1.0,   # world brightness multiplier (0.2–2.0)
	"hud_opacity":   1.0,   # HUD transparency (0.2–1.0)
	"damage_numbers": true, # show floating damage numbers
	"controller_vibration": true,  # gamepad rumble on hit
	"show_coords": false,  # coordinate + biome display under food bar
}

## Scale a base particle count by quality setting.  Returns 0 when disabled.
func fx_particles(base: int) -> int:
	if not fx.get("enabled", true) or fx.get("quality", 2) == 0:
		return 0
	var scale: float = [0.0, 0.35, 0.65, 1.0][fx.get("quality", 2)]
	return maxi(1, int(base * scale))

## Resets all per-world mutable state so a new game never inherits values from
## a previous session.  Call this before generating a new world.
func reset_for_new_game() -> void:
	time_of_day    = 0.25   # dawn
	day_number     = 1
	is_daytime     = true
	player_health  = 100.0
	player_hunger  = 100.0
	player_position = Vector2.ZERO
	spawn_point    = Vector2.ZERO
	crystal_gates  = {}
	chest_inventories = {}


func _ready() -> void:
	# Generate a random seed if none provided
	if world_seed == 0:
		world_seed = randi()
	# Track joypad connection globally so HTML5 builds pick it up reactively.
	Input.joy_connection_changed.connect(_on_joy_changed)
	joypad_active = Input.get_connected_joypads().size() > 0
	# Load persistent stats (kill counts + unlocked classes) from disk.
	load_persistent_stats()


## Returns the Dictionary for the currently selected player class.
func get_class_data() -> Dictionary:
	var idx := clampi(player_class_index, 0, PLAYER_CLASSES.size() - 1)
	return PLAYER_CLASSES[idx]


## Call this every time an enemy dies.
## tier: 0 = basic, 1 = elite, 2 = boss
func record_kill(tier: int) -> void:
	total_enemy_kills += 1
	if tier == 1:
		elite_kills += 1
	elif tier == 2:
		boss_kills += 1
	check_class_unlocks()
	save_persistent_stats()


## Checks every class and marks it unlocked if kill thresholds are met.
## Also always ensures indices 0 and 1 (base classes) are unlocked.
func check_class_unlocks() -> void:
	# Resize the array to cover all classes.
	while unlocked_classes.size() < PLAYER_CLASSES.size():
		unlocked_classes.append(false)
	for i in PLAYER_CLASSES.size():
		var cls: Dictionary = PLAYER_CLASSES[i]
		if i < 2:
			unlocked_classes[i] = true   # base classes always unlocked
			continue
		var kk: int = int(cls.get("unlock_kills",  0))
		var ek: int = int(cls.get("unlock_elites", 0))
		var bk: int = int(cls.get("unlock_bosses", 0))
		unlocked_classes[i] = (total_enemy_kills >= kk and elite_kills >= ek and boss_kills >= bk)


## Saves kill stats and unlock flags to user://player_stats.json.
## This file persists independently of any world save slot.
func save_persistent_stats() -> void:
	var data: Dictionary = {
		"total_enemy_kills": total_enemy_kills,
		"elite_kills":       elite_kills,
		"boss_kills":        boss_kills,
		"unlocked_classes":  unlocked_classes,
		"player_class_index": player_class_index,
	}
	var file := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


## Loads kill stats and unlock flags from user://player_stats.json.
## Called once in _ready() so stats are available immediately on launch.
func load_persistent_stats() -> void:
	if not FileAccess.file_exists(STATS_PATH):
		# First run — seed with base classes unlocked.
		unlocked_classes = []
		for i in PLAYER_CLASSES.size():
			unlocked_classes.append(i < 2)
		return
	var file := FileAccess.open(STATS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	total_enemy_kills = int(d.get("total_enemy_kills", 0))
	elite_kills       = int(d.get("elite_kills",       0))
	boss_kills        = int(d.get("boss_kills",        0))
	player_class_index = int(d.get("player_class_index", 0))
	var saved_unlocks = d.get("unlocked_classes", [])
	unlocked_classes = []
	for i in PLAYER_CLASSES.size():
		if i < saved_unlocks.size():
			unlocked_classes.append(bool(saved_unlocks[i]))
		else:
			unlocked_classes.append(i < 2)
	# Re-run unlock check in case kills were accumulated from an older version.
	check_class_unlocks()

func _on_joy_changed(_device: int, connected: bool) -> void:
	if connected:
		joypad_active = true
	else:
		joypad_active = Input.get_connected_joypads().size() > 0

func tick_time(delta: float) -> void:
	## Call this once per frame from the World node.
	## Updates the time of day and fires signals.
	time_of_day += delta / DAY_LENGTH_SECONDS
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day_number += 1
		day_changed.emit(day_number)

	var was_day := is_daytime
	is_daytime = (time_of_day >= 0.2 and time_of_day < 0.8)  # daytime = 20%–80% of cycle
	time_of_day_changed.emit(time_of_day)

	if was_day != is_daytime:
		if is_daytime and not was_day:  # just became day = survived the night
			var qs := get_node_or_null("/root/QuestSystem")
			if qs != null:
				qs.on_night_survived()

## Attaches a drag-to-scroll overlay to a ScrollContainer so it can be
## scrolled by click-dragging the content (not just the scroll bar).
## Call immediately after creating a ScrollContainer.
## Clicks shorter than DRAG_THRESHOLD pixels pass through to child controls.
static func make_scroll_draggable(sc: ScrollContainer) -> void:
	var overlay := _DragScrollOverlay.new()
	overlay.scroll_target = sc
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	sc.add_child(overlay)


## Inner node that intercepts mouse events on a ScrollContainer and converts
## click-drags into scroll movement.  Taps (< DRAG_THRESHOLD px) are forwarded
## to child controls so buttons/checkboxes still work normally.
class _DragScrollOverlay:
	extends Control

	const DRAG_THRESHOLD := 6.0   # pixels of movement before we treat it as a drag

	var scroll_target: ScrollContainer = null
	var _pressing: bool = false
	var _drag_started: bool = false
	var _press_pos: Vector2 = Vector2.ZERO
	var _last_pos: Vector2 = Vector2.ZERO
	var _scroll_start: Vector2 = Vector2.ZERO

	func _gui_input(event: InputEvent) -> void:
		if scroll_target == null:
			return

		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_pressing      = true
					_drag_started  = false
					_press_pos     = event.position
					_last_pos      = event.position
					_scroll_start  = Vector2(
						scroll_target.scroll_horizontal,
						scroll_target.scroll_vertical
					)
				else:
					if not _drag_started:
						# Short tap — pass the click through to children underneath.
						mouse_filter = Control.MOUSE_FILTER_PASS
						var click_ev := InputEventMouseButton.new()
						click_ev.button_index  = MOUSE_BUTTON_LEFT
						click_ev.pressed       = true
						click_ev.position      = event.global_position
						click_ev.global_position = event.global_position
						get_viewport().push_input(click_ev)
						await get_tree().process_frame
						mouse_filter = Control.MOUSE_FILTER_STOP
					_pressing     = false
					_drag_started = false
				accept_event()

		elif event is InputEventMouseMotion and _pressing:
			var delta: Vector2 = event.position - _last_pos
			var total: Vector2 = event.position - _press_pos
			if not _drag_started and total.length() > DRAG_THRESHOLD:
				_drag_started = true
			if _drag_started:
				scroll_target.scroll_horizontal -= int(delta.x)
				scroll_target.scroll_vertical   -= int(delta.y)
				accept_event()
			_last_pos = event.position

		elif event is InputEventScreenTouch:
			if event.pressed:
				_pressing     = true
				_drag_started = false
				_press_pos    = event.position
				_last_pos     = event.position
				_scroll_start = Vector2(
					scroll_target.scroll_horizontal,
					scroll_target.scroll_vertical
				)
			else:
				if not _drag_started:
					mouse_filter = Control.MOUSE_FILTER_PASS
					var tap_ev := InputEventScreenTouch.new()
					tap_ev.pressed  = true
					tap_ev.position = event.position
					get_viewport().push_input(tap_ev)
					await get_tree().process_frame
					mouse_filter = Control.MOUSE_FILTER_STOP
				_pressing     = false
				_drag_started = false
			accept_event()

		elif event is InputEventScreenDrag:
			if _pressing:
				if not _drag_started:
					var total: float = (event.position - _press_pos).length()
					if total > DRAG_THRESHOLD:
						_drag_started = true
				if _drag_started:
					scroll_target.scroll_horizontal -= int(event.relative.x)
					scroll_target.scroll_vertical   -= int(event.relative.y)
					accept_event()


func get_sky_color() -> Color:
	## Returns the background sky color blended for current time of day.
	## Called by the World background rect every frame.
	var t := time_of_day
	if t < 0.2:       # night → dawn
		return Color(0.05, 0.05, 0.15).lerp(Color(0.9, 0.5, 0.2), t / 0.2)
	elif t < 0.3:     # dawn → day
		return Color(0.9, 0.5, 0.2).lerp(Color(0.5, 0.7, 1.0), (t - 0.2) / 0.1)
	elif t < 0.7:     # daytime
		return Color(0.5, 0.7, 1.0)
	elif t < 0.8:     # day → dusk
		return Color(0.5, 0.7, 1.0).lerp(Color(0.9, 0.4, 0.1), (t - 0.7) / 0.1)
	else:             # night
		return Color(0.05, 0.05, 0.15)
