extends Player
class_name Bot

enum BotState { ROAM, HUNT, ENGAGE, FLEE, LOOT }

var bot_state: BotState = BotState.ROAM
var target: Node        = null

# ── Skill (0 = novice, 1 = expert) ───────────────────────────────────────────
var skill: float        = 0.5   # randomised per bot in _ready

# Derived from skill — set once by _apply_skill()
var _sight_range: float = 600.0
var _aim_error:   float = 0.12   # extra spread added on top of weapon spread
var _react_min:   float = 0.20   # min extra delay between shots
var _react_max:   float = 0.65   # max extra delay between shots
var _aggression:  float = 0.5    # 0 = passive, 1 = relentless

# ── Movement ─────────────────────────────────────────────────────────────────
var _move_dir:   float = 0.0
var _jump_flag:  bool  = false
var _strafe_dir: float = 0.0
var _strafe_timer: float = 0.0

# ── Timers ───────────────────────────────────────────────────────────────────
var _shoot_cd:         float = 0.0
var _roam_timer:       float = 0.0
var _roam_dir:         float = 1.0
var _grenade_cd:       float = 0.0
var _loot_collect_cd:  float = 0.0
var _plane_drop_timer: float = 0.0

# ── Hunt state ────────────────────────────────────────────────────────────────
var _last_known_pos: Vector2 = Vector2.ZERO
var _hunt_timer:     float   = 0.0

# ── Loot need tracking ────────────────────────────────────────────────────────
var _loot_seek_timer: float = 0.0

func _ready() -> void:
	super._ready()
	is_local        = false
	collision_layer = Constants.LAYER_BOT
	collision_mask  = Constants.LAYER_TERRAIN | Constants.LAYER_PLAYER | Constants.LAYER_BOT

	skill = randf()
	_apply_skill()

	var idx: int = randi() % Constants.WEAPON_DATA.size()
	weapon_data  = Constants.WEAPON_DATA[idx].duplicate()
	if weapon_data.get("melee", false):
		ammo    = -1
		reserve = -1
	else:
		ammo    = weapon_data.get("mag", 12)
		reserve = ammo * 4

	_plane_drop_timer = randf_range(3.0, 18.0)
	_strafe_dir       = 1.0 if randf() > 0.5 else -1.0

func _apply_skill() -> void:
	_sight_range = lerpf(350.0, 820.0, skill)
	_aim_error   = lerpf(0.22, 0.02, skill)
	_react_min   = lerpf(0.40, 0.04, skill)
	_react_max   = lerpf(0.90, 0.18, skill)
	_aggression  = lerpf(0.15, 0.92, skill)

# ── Main process ──────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state == State.DEAD:
		return

	if state == State.ONPLANE:
		_plane_drop_timer -= delta
		if _plane_drop_timer <= 0.0 or not GameManager.plane_phase_active:
			force_drop()
		queue_redraw()
		return

	if state == State.ALIVE:
		_tick_timers(delta)
		_shoot_cd        -= delta
		_grenade_cd      -= delta
		_loot_collect_cd -= delta
		_strafe_timer    -= delta
		_hunt_timer       = maxf(_hunt_timer - delta, 0.0)
		_loot_seek_timer  = maxf(_loot_seek_timer - delta, 0.0)
		_ai_tick(delta)

	queue_redraw()

# ── AI tick ───────────────────────────────────────────────────────────────────
func _ai_tick(delta: float) -> void:
	_auto_collect_loot()

	var alive_count: int  = GameManager.get_alive_count()
	var late_game: bool   = alive_count <= 6
	var eff_sight: float  = _sight_range * (1.6 if late_game else 1.0)

	_find_target(eff_sight)

	var hp_pct: float    = float(hp) / float(Constants.PLAYER_MAX_HP)
	var low_ammo: bool   = ammo >= 0 and ammo <= maxi(weapon_data.get("mag", 12) / 4, 1)
	var low_hp: bool     = hp_pct < 0.4
	var low_shield: bool = shield == 0 and hp_pct < 0.7
	var wants_loot: bool = low_ammo or low_hp or low_shield

	if target != null and is_instance_valid(target) and target.is_alive():
		_last_known_pos = target.position
		_hunt_timer     = randf_range(4.0, 9.0)
		var flee_chance := lerpf(0.55, 0.08, _aggression)  # novice flees more
		if low_hp and randf() < flee_chance:
			bot_state = BotState.FLEE
		else:
			bot_state = BotState.ENGAGE
	elif wants_loot and not _nearby_loot.is_empty():
		bot_state = BotState.LOOT
	elif _hunt_timer > 0.0 and _last_known_pos != Vector2.ZERO:
		bot_state = BotState.HUNT
	else:
		bot_state = BotState.ROAM

	match bot_state:
		BotState.ENGAGE: _do_engage(delta)
		BotState.FLEE:   _do_flee(delta)
		BotState.ROAM:   _do_roam(delta)
		BotState.HUNT:   _do_hunt(delta)
		BotState.LOOT:   _do_loot_seek(delta)

	# Zone pressure overrides movement if taking damage
	var zone: ZoneSystem = _get_zone()
	if zone != null:
		var dmg := zone.get_zone_damage(position.x)
		if dmg > 0.0:
			_move_dir  = 1.0 if zone.get_zone_center() > position.x else -1.0
			_jump_flag = _jump_flag or (randf() < 0.015)

# ── Loot collection ───────────────────────────────────────────────────────────
func _auto_collect_loot() -> void:
	if _loot_collect_cd > 0.0 or _nearby_loot.is_empty():
		return
	var hp_pct := float(hp) / float(Constants.PLAYER_MAX_HP)
	for loot in _nearby_loot:
		if not is_instance_valid(loot):
			continue
		var lt   = loot.get("loot_type")
		var want := false
		match lt:
			0:  # WEAPON
				want = ammo == 0 or (ammo >= 0 and ammo < 3)
			1:  # JETPACK
				want = jetpack_fuel < Constants.JETPACK_FUEL_MAX * 0.6
			2:  # MEDKIT
				want = hp_pct < 0.92
			3:  # SHIELD
				want = shield < Constants.PLAYER_MAX_SHIELD
		if want:
			loot.call("collect", self)
			_loot_collect_cd = 0.8
			return

# ── Target finding ────────────────────────────────────────────────────────────
func _find_target(sight: float) -> void:
	if target != null and is_instance_valid(target) and target.is_alive():
		if position.distance_to(target.position) < sight * 1.4:
			return
	target    = null
	var best: float = sight
	var local_p: Node = GameManager.local_player
	if local_p != null and is_instance_valid(local_p) and local_p.is_alive():
		var d := position.distance_to(local_p.position)
		if d < best:
			best   = d
			target = local_p
	for bot in get_tree().get_nodes_in_group("players"):
		if bot == self or not is_instance_valid(bot) or not bot.is_alive():
			continue
		if bot == GameManager.local_player:
			continue
		var d := position.distance_to(bot.position)
		if d < best * 0.75:
			best   = d
			target = bot

# ── Engage ────────────────────────────────────────────────────────────────────
func _do_engage(_delta: float) -> void:
	if not target:
		return
	var dist: float = position.distance_to(target.position)
	var dx:   float = target.position.x - position.x

	# Preferred combat distance scales with skill — experts stay further back
	var pref: float = lerpf(180.0, 420.0, skill)
	if dist > pref * 1.3:
		_move_toward_x(target.position)
	elif dist < pref * 0.55:
		_move_dir    = -sign(dx)
		facing_right = dx > 0.0
	else:
		# Strafe sideways in combat
		if _strafe_timer <= 0.0:
			_strafe_dir   = -_strafe_dir
			_strafe_timer = randf_range(0.6, 1.8)
		_move_dir    = _strafe_dir
		facing_right = dx > 0.0

	# Imperfect aim — aim toward target with error + optional bullet lead
	var lead     := Vector2.ZERO
	var tgt_vel   = target.get("velocity")
	if tgt_vel != null and skill > 0.35:
		var spd   := maxf(float(weapon_data.get("speed", 1400)), 400.0)
		var ttime := dist / spd
		lead       = (tgt_vel as Vector2) * ttime * lerpf(0.0, 0.65, skill)
	var true_angle: float = ((target.get("position") as Vector2 + lead) - position).angle()
	aim_angle       = true_angle + randf_range(-_aim_error, _aim_error)
	facing_right    = dx > 0.0

	# Shoot
	if _shoot_cd <= 0.0:
		_bot_shoot()
		_shoot_cd = weapon_data.get("fire_rate", 0.4) + randf_range(_react_min, _react_max)

	# Grenade — low-skill bots barely use them
	if _grenade_cd <= 0.0 and dist < 360.0 and randf() < 0.003 * _aggression:
		_throw_grenade()
		_grenade_cd = randf_range(5.0, 12.0)

	# Random dodge jump
	if randf() < 0.006 * _aggression:
		_jump_flag = true

# ── Flee ──────────────────────────────────────────────────────────────────────
func _do_flee(_delta: float) -> void:
	if target:
		_move_dir    = -sign(target.position.x - position.x)
		facing_right = _move_dir > 0.0
	else:
		_move_dir = _roam_dir
	if is_on_floor() and randf() < 0.08:
		_jump_flag = true

# ── Roam ──────────────────────────────────────────────────────────────────────
func _do_roam(delta: float) -> void:
	_roam_timer -= delta
	if _roam_timer <= 0.0:
		_roam_dir   = 1.0 if randf() > 0.5 else -1.0
		_roam_timer = randf_range(0.7, 2.2)
		if randf() < 0.2 + _aggression * 0.15:
			_jump_flag = true
	_move_dir = _roam_dir
	if position.x < Constants.WORLD_LEFT + 200.0:
		_roam_dir = 1.0
	elif position.x > Constants.WORLD_RIGHT - 200.0:
		_roam_dir = -1.0

	# Late game: drift toward zone center instead of wandering aimlessly
	var alive_count := GameManager.get_alive_count()
	if alive_count <= 8:
		var zone: ZoneSystem = _get_zone()
		if zone != null:
			var center := zone.get_zone_center()
			if abs(position.x - center) > 400.0:
				_move_dir = sign(center - position.x)

# ── Hunt ──────────────────────────────────────────────────────────────────────
func _do_hunt(_delta: float) -> void:
	if _last_known_pos == Vector2.ZERO:
		bot_state = BotState.ROAM
		return
	_move_toward_x(_last_known_pos)
	if position.distance_to(_last_known_pos) < 100.0:
		_last_known_pos = Vector2.ZERO
		_hunt_timer     = 0.0

# ── Loot seek ─────────────────────────────────────────────────────────────────
func _do_loot_seek(delta: float) -> void:
	_do_roam(delta)  # Move around; _auto_collect_loot handles actual pickup
	# Give up after a while
	if _loot_seek_timer <= 0.0:
		bot_state        = BotState.ROAM
		_loot_seek_timer = randf_range(3.0, 7.0)

# ── Shoot ─────────────────────────────────────────────────────────────────────
func _bot_shoot() -> void:
	if not target or weapon_data.is_empty():
		return
	if weapon_data.get("melee", false):
		if position.distance_to(target.position) < weapon_data.get("range", 75.0) * 1.3:
			_do_melee()
		return
	if ammo == 0:
		_start_reload()
		return
	if weapon_data.get("explosive", false):
		_throw_grenade()
		_grenade_cd = randf_range(3.5, 7.0)
		return

	var damage: int     = weapon_data.get("damage", 20)
	var spread: float   = weapon_data.get("spread", 0.04) + _aim_error
	var range_px: float = weapon_data.get("range", 800.0)
	var origin: Vector2 = position + Vector2(14.0 if facing_right else -14.0, -8.0)
	var dir: Vector2    = Vector2(cos(aim_angle), sin(aim_angle)).rotated(randf_range(-spread, spread))
	var space           := get_world_2d().direct_space_state
	var query           := PhysicsRayQueryParameters2D.create(origin, origin + dir * range_px)
	query.collision_mask = Constants.LAYER_TERRAIN | Constants.LAYER_PLAYER | Constants.LAYER_BOT
	query.exclude        = [get_rid()]
	var result           := space.intersect_ray(query)
	if not result.is_empty():
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(damage, self)
		else:
			var tp := Vector2i(
				int(floor(result.position.x / float(Constants.TILE_SIZE))),
				int(floor(result.position.y / float(Constants.TILE_SIZE)))
			)
			_damage_terrain_at(tp, int(float(damage) * 0.2))
		_spawn_trail(origin, result.position)
	else:
		_spawn_trail(origin, origin + dir * range_px)
	ammo      -= 1
	fire_timer = weapon_data.get("fire_rate", 0.4)

# ── Movement helpers ──────────────────────────────────────────────────────────
func _move_toward_x(dest: Vector2) -> void:
	_move_dir    = sign(dest.x - position.x)
	facing_right = _move_dir > 0.0
	if is_on_floor() and abs(velocity.x) < 30.0:
		var check_x := position.x + _move_dir * 35.0
		var check_y := position.y - 5.0
		var blocked := false
		if world_ref   != null: blocked = world_ref.is_solid_at(check_x, check_y)
		if not blocked and terrain_ref != null: blocked = terrain_ref.is_solid_at(check_x, check_y)
		if blocked: _jump_flag = true

func _bot_move_x() -> float:
	return clampf(_move_dir, -1.0, 1.0)

func _wants_jump() -> bool:
	if _jump_flag:
		_jump_flag = false
		return true
	return false

func _holding_jump() -> bool:
	return has_jetpack and _jetpack_on_desire()

func _jetpack_on_desire() -> bool:
	return velocity.y > 150.0 and has_jetpack and jetpack_fuel > 0.5

# ── Zone helper ───────────────────────────────────────────────────────────────
func _get_zone() -> ZoneSystem:
	return get_node_or_null("/root/Match/Zone") as ZoneSystem
