## AbilitySystem.gd — Autoload singleton
## Manages player abilities/spells: definitions, stamina, cooldowns, unlocking, use.
##
## Usage from Player.gd (or anywhere):
##   AbilitySystem.use_ability("shadow_dash", self)
##   AbilitySystem.unlock_ability("blade_storm")
##   AbilitySystem.equipped_abilities = ["shadow_dash", "heal_pulse"]
##
## Player node must expose:
##   var health: float
##   var max_health: float
##   var velocity: Vector2          (CharacterBody2D)
##   func take_damage(amount: float) -> void
##   var _attack_cooldown: float    (set to 0 to clear melee lockout during blade_storm)

extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal ability_used(id: String)
signal ability_unlocked(id: String)
signal stamina_changed(current: float, max_stamina: float)

# ---------------------------------------------------------------------------
# Stamina
# ---------------------------------------------------------------------------
var stamina: float     = 100.0
var max_stamina: float = 100.0

const STAMINA_REGEN: float = 5.0   # per second when not mid-ability

# Small cooldown after spending stamina before regen resumes (prevents spam).
var _regen_pause: float = 0.0

# ---------------------------------------------------------------------------
# Ability slots & unlock state
# ---------------------------------------------------------------------------
## Up to 4 abilities the player has assigned to quick-use slots.
var equipped_abilities: Array = []

## IDs the player has earned. Only these can be used.
var unlocked_abilities: Array = ["shadow_dash"]

# ---------------------------------------------------------------------------
# Per-ability cooldown tracking  { id: seconds_remaining }
# ---------------------------------------------------------------------------
var _cooldowns: Dictionary = {}

# ---------------------------------------------------------------------------
# Ability definitions
# ---------------------------------------------------------------------------
## Each entry:
##   cost      — stamina consumed on use
##   cooldown  — seconds before re-use
##   duration  — seconds the buff/effect lasts (0 = instant)
const ABILITIES: Dictionary = {
	"shadow_dash": {
		"name":        "Shadow Dash",
		"cost":        20.0,
		"cooldown":    6.0,
		"duration":    0.0,
		"description": "Teleport-dash forward 3 tiles, brief invincibility frames.",
	},
	"berserker_rage": {
		"name":        "Berserker Rage",
		"cost":        30.0,
		"cooldown":    20.0,
		"duration":    10.0,
		"description": "+50% damage, -20% defense for 10 s.",
	},
	"stone_skin": {
		"name":        "Stone Skin",
		"cost":        25.0,
		"cooldown":    18.0,
		"duration":    8.0,
		"description": "Take 50% less damage for 8 s.",
	},
	"blade_storm": {
		"name":        "Blade Storm",
		"cost":        35.0,
		"cooldown":    14.0,
		"duration":    2.0,
		"description": "Spin attack — damages all nearby enemies for 2 s.",
	},
	"heal_pulse": {
		"name":        "Heal Pulse",
		"cost":        40.0,
		"cooldown":    12.0,
		"duration":    0.0,
		"description": "Instantly restore 30 HP.",
	},
	"earthquake": {
		"name":        "Earthquake",
		"cost":        50.0,
		"cooldown":    25.0,
		"duration":    0.0,
		"description": "Shockwave breaks tiles in a 3-tile radius and knocks back enemies.",
	},
}

# ---------------------------------------------------------------------------
# Active buff state
# ---------------------------------------------------------------------------
# Each key is an ability id; value is remaining seconds.
var _active_buffs: Dictionary = {}

# Earthquake tile-break radius in world pixels (3 tiles × 16 px).
const EARTHQUAKE_RADIUS_PX: float = 48.0
# Blade storm enemy-hit radius (px).
const BLADE_STORM_RADIUS_PX: float = 80.0
# Shadow dash distance (3 tiles × 16 px).
const SHADOW_DASH_DIST_PX: float   = 48.0
# I-frame duration granted by shadow dash (seconds).
const SHADOW_DASH_IFRAMES: float   = 0.5

# ---------------------------------------------------------------------------
# _process — stamina regen + cooldown/buff ticking
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	# Tick cooldowns.
	for id in _cooldowns.keys():
		_cooldowns[id] = max(0.0, _cooldowns[id] - delta)
		if _cooldowns[id] == 0.0:
			_cooldowns.erase(id)

	# Tick active buffs, expire them when done.
	for id in _active_buffs.keys():
		_active_buffs[id] = max(0.0, _active_buffs[id] - delta)
		if _active_buffs[id] == 0.0:
			_expire_buff(id)
			_active_buffs.erase(id)

	# Regen stamina (paused briefly after spending).
	if _regen_pause > 0.0:
		_regen_pause -= delta
	else:
		if stamina < max_stamina:
			stamina = min(max_stamina, stamina + STAMINA_REGEN * delta)
			stamina_changed.emit(stamina, max_stamina)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Permanently unlock an ability so it can be used.
func unlock_ability(id: String) -> void:
	if id not in ABILITIES:
		push_warning("AbilitySystem.unlock_ability: unknown id '%s'" % id)
		return
	if id not in unlocked_abilities:
		unlocked_abilities.append(id)
		ability_unlocked.emit(id)

## Try to use an ability on `player`.
## Returns true on success, false if locked / on cooldown / not enough stamina.
func use_ability(id: String, player: Node) -> bool:
	if id not in ABILITIES:
		push_warning("AbilitySystem.use_ability: unknown id '%s'" % id)
		return false
	if id not in unlocked_abilities:
		return false
	if _cooldowns.get(id, 0.0) > 0.0:
		return false
	var def: Dictionary = ABILITIES[id]
	if stamina < def["cost"]:
		return false

	# Spend stamina.
	stamina = max(0.0, stamina - def["cost"])
	_regen_pause = 1.5
	stamina_changed.emit(stamina, max_stamina)

	# Start cooldown.
	_cooldowns[id] = def["cooldown"]

	# Apply effect.
	_apply_ability(id, player, def)

	ability_used.emit(id)
	return true

## Returns seconds remaining on cooldown (0 = ready).
func get_cooldown(id: String) -> float:
	return _cooldowns.get(id, 0.0)

## True if a buff is currently active on the player.
func has_buff(id: String) -> bool:
	return _active_buffs.has(id)

# ---------------------------------------------------------------------------
# Internal: apply ability effects directly to the player node
# ---------------------------------------------------------------------------
func _apply_ability(id: String, player: Node, def: Dictionary) -> void:
	match id:
		"shadow_dash":
			_do_shadow_dash(player)

		"berserker_rage":
			# +50% damage multiplier applied via GameData (same pattern as difficulty).
			if has_node("/root/GameData"):
				GameData.player_damage_mult *= 1.5
			# Reduce defense: buff system will restore on expire.
			_active_buffs[id] = def["duration"]

		"stone_skin":
			# Halve incoming damage — store original; Player.take_damage checks this flag.
			# We set a property directly if it exists, otherwise use a meta key.
			if player.has_method("set_damage_reduction"):
				player.set_damage_reduction(0.5)
			else:
				player.set_meta("damage_reduction", 0.5)
			_active_buffs[id] = def["duration"]

		"blade_storm":
			_active_buffs[id] = def["duration"]
			# Kick off repeating hits during the spin window.
			_blade_storm_tick(player, def["duration"])

		"heal_pulse":
			var heal_amount: float = 30.0
			if player.has_method("heal"):
				player.heal(heal_amount)
			else:
				player.health = min(player.health + heal_amount, player.max_health)
				if player.has_signal("health_changed"):
					player.health_changed.emit(player.health, player.max_health)

		"earthquake":
			_do_earthquake(player)

func _do_shadow_dash(player: Node) -> void:
	# Move 3 tiles in the direction the player is facing.
	var facing: float = 1.0
	if player.has_method("get_facing"):
		facing = player.get_facing()
	elif player.get("scale") != null:
		facing = sign(player.scale.x) if player.scale.x != 0.0 else 1.0

	player.global_position.x += SHADOW_DASH_DIST_PX * facing

	# Grant brief invincibility by manipulating the HurtTimer if it exists.
	var hurt_timer: Node = player.get_node_or_null("HurtTimer")
	if hurt_timer:
		hurt_timer.start(SHADOW_DASH_IFRAMES)
	else:
		# Fallback: use a meta flag that Player.take_damage can check.
		player.set_meta("invincible_until", Time.get_ticks_msec() / 1000.0 + SHADOW_DASH_IFRAMES)

func _do_earthquake(player: Node) -> void:
	var origin: Vector2 = player.global_position

	# Break nearby tiles via the World autoload if available.
	var world: Node = _find_world(player)
	if world and world.has_method("mine_block"):
		var tile_size: int = 16
		var radius_tiles: int = 3
		for dx in range(-radius_tiles, radius_tiles + 1):
			for dy in range(-radius_tiles, radius_tiles + 1):
				if dx * dx + dy * dy <= radius_tiles * radius_tiles:
					var tile_pos: Vector2i = Vector2i(
						int(origin.x / tile_size) + dx,
						int(origin.y / tile_size) + dy
					)
					world.mine_block(tile_pos, 99, false)  # mine_level 99 = break anything

	# Knock back nearby enemies.
	_knock_back_enemies(player, origin, EARTHQUAKE_RADIUS_PX, 400.0, 20.0)

func _blade_storm_tick(player: Node, duration: float) -> void:
	# Hit all enemies in radius every 0.25 s for the buff duration.
	var hits: int = int(duration / 0.25)
	var t: SceneTreeTimer
	for i in range(hits):
		t = get_tree().create_timer(i * 0.25 + 0.01)
		t.timeout.connect(func():
			if not is_instance_valid(player):
				return
			_knock_back_enemies(player, player.global_position, BLADE_STORM_RADIUS_PX, 150.0, 12.0)
		)

func _knock_back_enemies(
		player: Node,
		origin: Vector2,
		radius: float,
		kb_force: float,
		damage: float
) -> void:
	# Walk the scene tree looking for nodes in the "enemies" group.
	var enemies: Array = player.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = (enemy.global_position - origin).length()
		if dist <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			if enemy.get("velocity") != null:
				var dir: Vector2 = (enemy.global_position - origin).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.RIGHT
				enemy.velocity += dir * kb_force

# ---------------------------------------------------------------------------
# Internal: expire buff side-effects
# ---------------------------------------------------------------------------
func _expire_buff(id: String) -> void:
	var player: Node = _get_active_player()
	match id:
		"berserker_rage":
			if has_node("/root/GameData"):
				GameData.player_damage_mult /= 1.5
		"stone_skin":
			if player:
				if player.has_method("set_damage_reduction"):
					player.set_damage_reduction(0.0)
				elif player.has_meta("damage_reduction"):
					player.remove_meta("damage_reduction")
		"blade_storm":
			pass  # ticks were already scheduled; nothing to clean up

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _get_active_player() -> Node:
	# Try the "player" group first (Player.gd adds itself to this group).
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _find_world(from_node: Node) -> Node:
	# The World node is typically a direct child of the scene root.
	var root: Node = from_node.get_tree().current_scene
	if root == null:
		return null
	# Try common names.
	for name in ["World", "WorldNode", "world"]:
		var n: Node = root.get_node_or_null(name)
		if n:
			return n
	# Check autoloads.
	if has_node("/root/World"):
		return get_node("/root/World")
	return null
