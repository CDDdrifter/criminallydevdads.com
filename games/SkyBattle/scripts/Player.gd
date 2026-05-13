extends CharacterBody2D
class_name Player

signal died
signal hp_changed(hp: int, shield: int)
signal ammo_changed(ammo: int, reserve: int, weapon: Dictionary)
signal loot_prompt(text: String)

# Identity
var player_name: String = "Player"
var is_local: bool      = false
var is_alive_check: bool = true

# Stats
var hp: int     = Constants.PLAYER_MAX_HP
var shield: int = 0

# Weapon
var weapon_data: Dictionary = {}
var ammo: int    = 0
var reserve: int = 90
var fire_timer: float   = 0.0
var is_reloading: bool  = false
var reload_timer: float = 0.0

# Jetpack
var has_jetpack: bool   = false
var jetpack_fuel: float = 0.0
var _jetpack_on: bool   = false

# Movement
var _coyote_timer: float    = 0.0
var _jump_buffer: float     = 0.0
var _double_jump_used: bool = false
var aim_angle: float        = 0.0
var facing_right: bool      = true
var _melee_timer: float     = 0.0
var _aim_hold_timer: float  = 0.0
var _aim_lock_angle: float  = 0.0
var _auto_fire: bool        = false
var _touch_aim_vec: Vector2 = Vector2.ZERO

# State
enum State { ONPLANE, FREEFALL, PARACHUTE, ALIVE, DEAD }
var state: State = State.ONPLANE

# References
var world_ref: IslandWorld = null
var terrain_ref: Terrain   = null

# Loot
var _nearby_loot: Array = []

const GRENADE_SCENE = preload("res://scenes/projectiles/Grenade.tscn")

func _ready() -> void:
	collision_layer = Constants.LAYER_PLAYER
	collision_mask  = Constants.LAYER_TERRAIN | Constants.LAYER_BOT

	weapon_data  = Constants.WEAPON_DATA[0].duplicate()
	ammo         = weapon_data.get("mag", 12)
	reserve      = ammo * 3

	has_jetpack  = true
	jetpack_fuel = Constants.JETPACK_FUEL_MAX

	add_to_group("players")

	var area := Area2D.new()
	area.name            = "LootArea"
	area.collision_layer = 0
	area.collision_mask  = Constants.LAYER_LOOT
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 55.0
	cs.shape = circle
	area.add_child(cs)
	add_child(area)
	area.area_entered.connect(_on_loot_entered)
	area.area_exited.connect(_on_loot_exited)

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	match state:
		State.ONPLANE:   _do_onplane(delta)
		State.FREEFALL:  _do_freefall(delta)
		State.PARACHUTE: _do_parachute(delta)
		State.ALIVE:     _do_alive(delta)

func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	if state == State.ALIVE:
		_tick_timers(delta)
		if is_local:
			_handle_shoot(delta)
			_handle_interact()
	if is_local:
		_update_camera_zoom(delta)
	queue_redraw()

func _tick_timers(delta: float) -> void:
	fire_timer   = maxf(fire_timer - delta, 0.0)
	_melee_timer = maxf(_melee_timer - delta, 0.0)
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()
	if has_jetpack and is_on_floor() and abs(velocity.x) > 20.0:
		jetpack_fuel = minf(jetpack_fuel + Constants.JETPACK_REFUEL_RATE * delta, Constants.JETPACK_FUEL_MAX)

# ── On Plane ──────────────────────────────────────────────────────────────────
func _do_onplane(_delta: float) -> void:
	var px: float = GameManager.plane_x
	position = Vector2(px, Constants.PLANE_HEIGHT)
	velocity  = Vector2.ZERO
	if is_local and Input.is_action_just_pressed("jump"):
		_drop_from_plane()

func force_drop() -> void:
	if state == State.ONPLANE:
		_drop_from_plane()

func _drop_from_plane() -> void:
	state      = State.FREEFALL
	velocity   = Vector2(0.0, 150.0)

# ── Freefall ──────────────────────────────────────────────────────────────────
func _do_freefall(delta: float) -> void:
	velocity.x = _get_move_x() * 100.0
	velocity.y = minf(velocity.y + Constants.GRAVITY * delta, Constants.FREEFALL_SPEED)
	move_and_slide()
	if is_local and Input.is_action_just_pressed("jump"):
		_deploy_parachute()
	elif velocity.y >= 400.0 and _is_solid_below(160.0):
		_deploy_parachute()
	elif position.y > Constants.WORLD_TOP + 3600.0 and state == State.FREEFALL:
		_deploy_parachute()

func _is_solid_below(offset: float) -> bool:
	var cx := position.x
	var cy := position.y + offset
	if world_ref != null and world_ref.is_solid_at(cx, cy):
		return true
	if terrain_ref != null and terrain_ref.is_solid_at(cx, cy):
		return true
	return false

func _deploy_parachute() -> void:
	state      = State.PARACHUTE
	velocity.y = Constants.PARACHUTE_FALL_SPEED

func _do_parachute(delta: float) -> void:
	velocity.x = lerpf(velocity.x, _get_move_x() * Constants.PARACHUTE_HORIZ_SPEED, delta * 3.0)
	velocity.y = Constants.PARACHUTE_FALL_SPEED
	move_and_slide()
	if is_on_floor():
		_land()

func _land() -> void:
	state = State.ALIVE

# ── Alive movement ────────────────────────────────────────────────────────────
func _do_alive(delta: float) -> void:
	var on_floor := is_on_floor()
	var dir_x: float = _get_move_x() if is_local else _bot_move_x()

	if on_floor:
		_coyote_timer = Constants.COYOTE_TIME
		_double_jump_used = false
	else:
		_coyote_timer -= delta

	if _wants_jump():
		_jump_buffer = Constants.JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta

	_jetpack_on = false
	if has_jetpack and _holding_jump() and not on_floor and jetpack_fuel > 0.0:
		velocity.y    = lerpf(velocity.y, Constants.JETPACK_FORCE, delta * 6.0)
		jetpack_fuel -= Constants.JETPACK_BURN_RATE * delta
		jetpack_fuel  = maxf(jetpack_fuel, 0.0)
		_jetpack_on   = true
	elif _jump_buffer > 0.0 and _coyote_timer > 0.0:
		velocity.y    = Constants.PLAYER_JUMP_VELOCITY
		_jump_buffer  = 0.0
		_coyote_timer = 0.0
	elif _wants_jump() and not _double_jump_used and not on_floor:
		velocity.y        = Constants.PLAYER_DOUBLE_JUMP
		_double_jump_used = true

	if dir_x != 0.0:
		facing_right = dir_x > 0.0
		velocity.x   = lerpf(velocity.x, dir_x * Constants.PLAYER_SPEED, delta * 14.0)
	else:
		velocity.x   = lerpf(velocity.x, 0.0, delta * 12.0)

	if not on_floor and not _jetpack_on:
		velocity.y = minf(velocity.y + Constants.GRAVITY * delta, 1400.0)

	move_and_slide()

	if is_local:
		_update_aim(delta)

	if position.y > Constants.WORLD_BOTTOM + 150.0:
		_die(null)

# ── Aim system ───────────────────────────────────────────────────────────────
func _update_aim(delta: float) -> void:
	# Build input vector from touch stick first, then physical right stick
	var input_vec := Vector2.ZERO
	if _touch_aim_vec.length() > 0.15:
		input_vec = _touch_aim_vec
	elif GameManager.controller_connected:
		var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if Vector2(rx, ry).length() > 0.2:
			input_vec = Vector2(rx, ry)

	if input_vec.length() > 0.15:
		# Active stick input — aim follows, reset hold timer
		aim_angle       = input_vec.angle()
		facing_right    = input_vec.x >= 0.0
		_aim_lock_angle = aim_angle
		_aim_hold_timer = 3.0
	elif _aim_hold_timer > 0.0:
		# Hold the last aim direction for 3 seconds after releasing
		_aim_hold_timer -= delta
		aim_angle = _aim_lock_angle
	elif GameManager.controller_connected or _touch_aim_vec != Vector2.ZERO:
		# Controller session active but no stick input and hold expired — aim forward
		aim_angle = 0.0 if facing_right else PI
	else:
		# Mouse fallback (keyboard + mouse players)
		var mouse_world := get_global_mouse_position()
		aim_angle    = (mouse_world - position).angle()
		facing_right = mouse_world.x >= position.x

	_do_auto_aim()

func _do_auto_aim() -> void:
	_auto_fire = false
	if weapon_data.is_empty() or weapon_data.get("melee", false) or weapon_data.get("explosive", false):
		return
	var range_px := float(weapon_data.get("range", 900.0))
	# 40-degree half-cone in front of the current aim direction
	const CONE: float = 0.70
	var best: Node     = null
	var best_dist: float = range_px

	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not is_instance_valid(p) or not p.is_alive():
			continue
		var p_pos: Vector2  = p.get("position")
		var to_enemy: Vector2 = p_pos - position
		var dist: float     = to_enemy.length()
		if dist > range_px:
			continue
		var angle_to: float = to_enemy.angle()
		var diff: float     = absf(wrapf(angle_to - aim_angle, -PI, PI))
		if diff < CONE and dist < best_dist:
			best_dist = dist
			best      = p

	if best == null:
		return

	var best_pos: Vector2 = best.get("position")
	var tvel = best.get("velocity")
	var lead := Vector2.ZERO
	if tvel != null:
		var spd: float   = maxf(float(weapon_data.get("speed", 1400)), 400.0)
		var ttime: float = best_dist / spd
		lead              = (tvel as Vector2) * ttime * 0.45

	var snap_angle: float = (best_pos + lead - position).angle()
	aim_angle      = lerpf(aim_angle, snap_angle, 0.30)
	facing_right   = cos(aim_angle) >= 0.0
	# Only auto-fire when player is actively aiming: stick/touch was recently pushed,
	# OR they're on mouse+keyboard (always aiming via cursor)
	var stick_active := _aim_hold_timer > 0.0
	# Touch-primary devices should not get "mouse" auto-fire when sticks are idle.
	var using_mouse := not GameManager.controller_connected and _touch_aim_vec.length() < 0.15 \
		and not DisplayServer.is_touchscreen_available()
	_auto_fire = stick_active or using_mouse

# ── Input helpers (override in Bot) ───────────────────────────────────────────
func _get_move_x() -> float:
	if not is_local:
		return 0.0
	var x := 0.0
	if Input.is_action_pressed("move_right"): x += 1.0
	if Input.is_action_pressed("move_left"):  x -= 1.0
	return x

func _bot_move_x() -> float:
	return 0.0

func _wants_jump() -> bool:
	return is_local and Input.is_action_just_pressed("jump")

func _holding_jump() -> bool:
	return is_local and Input.is_action_pressed("jump")

# ── Camera ────────────────────────────────────────────────────────────────────
func _update_camera_zoom(delta: float) -> void:
	var cam := get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return
	var target: float
	match state:
		State.ONPLANE:   target = Constants.ZOOM_PLANE
		State.FREEFALL:  target = Constants.ZOOM_FREEFALL
		State.PARACHUTE: target = Constants.ZOOM_FREEFALL
		_:               target = Constants.ZOOM_GAMEPLAY
	# Clamp lerp weight: large deltas (common on Web after load / tab focus) would
	# overshoot lerpf and explode zoom (e.g. 0.18 → 4+) — looks "zoomed into" terrain.
	var w: float = minf(delta * Constants.ZOOM_LERP, 1.0)
	var nz: float = clampf(lerpf(cam.zoom.x, target, w), Constants.ZOOM_PLANE * 0.5, 2.5)
	cam.zoom = Vector2(nz, nz)

# ── Shooting ──────────────────────────────────────────────────────────────────
func _handle_shoot(_delta: float) -> void:
	if weapon_data.is_empty():
		return

	var shoot: bool = Input.is_action_pressed("shoot") or _auto_fire

	if weapon_data.get("melee", false):
		if shoot and fire_timer <= 0.0:
			_do_melee()
	elif not is_reloading and fire_timer <= 0.0 and shoot:
		if weapon_data.get("explosive", false):
			_throw_grenade()
			fire_timer = weapon_data.get("fire_rate", 0.9)
		else:
			_fire_hitscan()

	if Input.is_action_just_pressed("throw_grenade"):
		_throw_grenade()
	if not weapon_data.get("melee", false) and Input.is_action_just_pressed("reload"):
		_start_reload()

func _fire_hitscan() -> void:
	if ammo <= 0:
		_start_reload()
		return
	var pellets: int = weapon_data.get("pellets", 1)
	for _p in range(pellets):
		_cast_bullet()
	ammo -= 1
	fire_timer = weapon_data.get("fire_rate", 0.4)
	ammo_changed.emit(ammo, reserve, weapon_data)

func _cast_bullet() -> void:
	var damage: int    = weapon_data.get("damage", 20)
	var spread: float  = weapon_data.get("spread", 0.04)
	var range_px: float = weapon_data.get("range", 900.0)

	var origin: Vector2 = position + Vector2(14.0 if facing_right else -14.0, -8.0)
	var dir: Vector2    = Vector2(cos(aim_angle), sin(aim_angle)).rotated(randf_range(-spread, spread))

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, origin + dir * range_px)
	query.collision_mask = Constants.LAYER_TERRAIN | Constants.LAYER_PLAYER | Constants.LAYER_BOT
	query.exclude        = [get_rid()]
	var result           := space.intersect_ray(query)

	var end_pos: Vector2 = origin + dir * range_px
	if not result.is_empty():
		end_pos = result.position
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(damage, self)
		else:
			var tp := Vector2i(
				int(floor(result.position.x / float(Constants.TILE_SIZE))),
				int(floor(result.position.y / float(Constants.TILE_SIZE)))
			)
			_damage_terrain_at(tp, int(float(damage) * 0.25))

	_spawn_trail(origin, end_pos)

func _damage_terrain_at(tp: Vector2i, dmg: int) -> void:
	if world_ref != null and world_ref.tile_data.has(tp):
		world_ref.damage_tile(tp, dmg)
	elif terrain_ref != null and terrain_ref.tile_data.has(tp):
		terrain_ref.damage_tile(tp, dmg)

func _spawn_trail(from: Vector2, to: Vector2) -> void:
	var match_node := get_node_or_null("/root/Match")
	if not match_node:
		return
	var line := Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width         = 3.0
	line.default_color = Color(1.0, 0.95, 0.6, 1.0)
	match_node.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.35)
	tw.tween_callback(line.queue_free)

func _throw_grenade() -> void:
	var match_node := get_node_or_null("/root/Match")
	if not match_node:
		return
	var g = GRENADE_SCENE.instantiate()
	g.position = position + Vector2(0.0, -10.0)
	g.thrower  = self
	match_node.add_child(g)
	var aim_pos: Vector2
	if is_local:
		var rx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var ry: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		aim_pos = position + Vector2(rx, ry) * 200.0 if Vector2(rx, ry).length() > 0.2 \
			else get_global_mouse_position()
	else:
		aim_pos = position + Vector2(200.0 if facing_right else -200.0, -80.0)
	var dir: Vector2  = (aim_pos - position).normalized()
	g.linear_velocity = dir * 580.0 + Vector2(0.0, -120.0)

func _do_melee() -> void:
	if weapon_data.is_empty():
		return
	_melee_timer = 0.3
	fire_timer   = weapon_data.get("fire_rate", 0.55)
	var melee_range: float = weapon_data.get("range", 75.0)
	var damage: int        = weapon_data.get("damage", 45)
	var arm_dir := Vector2(cos(aim_angle), sin(aim_angle))
	var hit_center := position + arm_dir * melee_range * 0.6 + Vector2(0.0, -6.0)
	for p in get_tree().get_nodes_in_group("players"):
		if p == self or not is_instance_valid(p):
			continue
		if not p.is_alive():
			continue
		if hit_center.distance_to(p.position) < melee_range:
			p.take_damage(damage, self)

func _start_reload() -> void:
	if is_reloading or weapon_data.get("melee", false) or reserve <= 0 or ammo >= weapon_data.get("mag", 12):
		return
	is_reloading = true
	reload_timer = weapon_data.get("reload", 2.0)

func _finish_reload() -> void:
	is_reloading = false
	var needed: int = weapon_data.get("mag", 12) - ammo
	var take: int   = mini(needed, reserve)
	ammo    += take
	reserve -= take
	ammo_changed.emit(ammo, reserve, weapon_data)

# ── Loot interaction ──────────────────────────────────────────────────────────
func _handle_interact() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	for loot in _nearby_loot:
		if is_instance_valid(loot) and loot.has_method("collect"):
			loot.collect(self)
			break

func _on_loot_entered(other: Area2D) -> void:
	if not _nearby_loot.has(other):
		_nearby_loot.append(other)
	if is_local:
		var n: String = other.get("display_name") if other.get("display_name") != null else "Item"
		loot_prompt.emit("[ E ]  " + n)

func _on_loot_exited(other: Area2D) -> void:
	_nearby_loot.erase(other)
	if is_local and _nearby_loot.is_empty():
		loot_prompt.emit("")

# ── Damage / Pickup ───────────────────────────────────────────────────────────
func take_damage(amount: int, source: Node = null) -> void:
	if state == State.DEAD:
		return
	if shield > 0:
		var absorbed: int = mini(shield, amount)
		shield  -= absorbed
		amount  -= absorbed
	hp -= amount
	hp  = maxi(hp, 0)
	hp_changed.emit(hp, shield)
	if hp <= 0:
		_die(source)

func heal(amount: int) -> void:
	hp = mini(hp + amount, Constants.PLAYER_MAX_HP)
	hp_changed.emit(hp, shield)

func add_shield(amount: int) -> void:
	shield = mini(shield + amount, Constants.PLAYER_MAX_SHIELD)
	hp_changed.emit(hp, shield)

func pickup_weapon(data: Dictionary) -> void:
	weapon_data  = data.duplicate()
	is_reloading = false
	fire_timer   = 0.0
	if weapon_data.get("melee", false):
		ammo    = -1
		reserve = -1
	else:
		ammo    = weapon_data.get("mag", 12)
		reserve = ammo * 3
	ammo_changed.emit(ammo, reserve, weapon_data)

func pickup_jetpack() -> void:
	has_jetpack  = true
	jetpack_fuel = Constants.JETPACK_FUEL_MAX

func refuel_jetpack() -> void:
	jetpack_fuel = Constants.JETPACK_FUEL_MAX

func _die(killer: Node) -> void:
	if state == State.DEAD:
		return
	state          = State.DEAD
	is_alive_check = false
	var killer_name := ""
	if killer != null and killer.get("player_name") != null:
		killer_name = killer.player_name
	GameManager.on_player_died(self, killer_name)
	died.emit()
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)

func is_alive() -> bool:
	return state != State.DEAD

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	if state == State.DEAD:
		return
	var col: Color = Color(0.25, 0.65, 1.0) if is_local else Color(1.0, 0.3, 0.35)
	if shield > 0:
		col = col.lightened(0.15)
	match state:
		State.ONPLANE:   _draw_body(col, false)
		State.FREEFALL:  _draw_body(col, false)
		State.PARACHUTE: _draw_parachute_canopy(col)
		State.ALIVE:     _draw_body(col, true)

func _draw_body(col: Color, show_weapon: bool) -> void:
	draw_circle(Vector2(0.0, -22.0), 8.0, col)
	draw_line(Vector2(0.0, -14.0), Vector2(0.0, 10.0), col, 3.0)
	var t: float  = float(Time.get_ticks_msec()) / 1000.0
	var moving: bool = abs(velocity.x) > 25.0
	if show_weapon:
		var arm_dir := Vector2(cos(aim_angle), sin(aim_angle))
		var is_melee: bool = not weapon_data.is_empty() and weapon_data.get("melee", false)
		draw_line(Vector2(0.0, -6.0), arm_dir * 16.0 + Vector2(0.0, -6.0), col, 2.0)
		draw_line(Vector2(0.0, -6.0), -arm_dir * 10.0 + Vector2(0.0, -4.0), col, 2.0)
		var wc: Color = weapon_data.get("color", Color.GRAY) if not weapon_data.is_empty() else Color.GRAY
		draw_line(arm_dir * 5.0 + Vector2(0.0, -6.0), arm_dir * 22.0 + Vector2(0.0, -6.0), wc, 4.0)
		if is_melee:
			# Melee swing arc animation
			if _melee_timer > 0.0:
				var swing_pct: float = 1.0 - (_melee_timer / 0.3)
				var sweep := lerpf(-1.2, 1.2, swing_pct)
				var swing_dir := arm_dir.rotated(sweep)
				var r: float = weapon_data.get("range", 75.0)
				draw_line(Vector2(0.0, -6.0), swing_dir * r + Vector2(0.0, -6.0), Color(0.95, 0.95, 0.5, 0.85), 3.5)
		else:
			# Laser sight — dashed red line
			var laser_range: float = minf(weapon_data.get("range", 900.0), 650.0)
			var laser_start := arm_dir * 22.0 + Vector2(0.0, -6.0)
			var seg: float = laser_range / 20.0
			for i in range(10):
				var s := laser_start + arm_dir * float(i) * seg * 2.0
				var e := s + arm_dir * seg
				draw_line(s, e, Color(1.0, 0.1, 0.1, 0.55), 1.5)
	else:
		draw_line(Vector2(0.0, -6.0), Vector2(-10.0, 2.0), col, 2.0)
		draw_line(Vector2(0.0, -6.0), Vector2(10.0, 2.0), col, 2.0)
	var lleg: float = sin(t * 10.0) * 5.0 if moving else 0.0
	draw_line(Vector2(0.0, 10.0), Vector2(-6.0, 28.0 + lleg), col, 2.0)
	draw_line(Vector2(0.0, 10.0), Vector2(6.0, 28.0 - lleg), col, 2.0)
	if has_jetpack:
		draw_rect(Rect2(-12.0, -8.0, 6.0, 14.0), Color(0.5, 0.5, 0.6))
		if _jetpack_on:
			draw_circle(Vector2(-9.0, 8.0), 5.0, Color(1.0, 0.5, 0.1, 0.9))
	var bw: float = 30.0
	draw_rect(Rect2(-bw * 0.5, -38.0, bw, 4.0), Color(0.15, 0.15, 0.15, 0.9))
	var hp_pct: float = float(hp) / float(Constants.PLAYER_MAX_HP)
	var hp_col: Color = Color(0.2, 0.9, 0.2) if hp_pct > 0.4 else Color(0.9, 0.5, 0.1) if hp_pct > 0.2 else Color(0.9, 0.15, 0.1)
	draw_rect(Rect2(-bw * 0.5, -38.0, bw * hp_pct, 4.0), hp_col)
	if shield > 0:
		draw_rect(Rect2(-bw * 0.5, -43.0, bw * float(shield) / float(Constants.PLAYER_MAX_SHIELD), 3.0), Color(0.3, 0.6, 1.0))
	if not is_local:
		draw_string(ThemeDB.fallback_font, Vector2(-25.0, -50.0), player_name,
					HORIZONTAL_ALIGNMENT_LEFT, 50, 10, Color(1.0, 0.6, 0.6, 0.85))

func _draw_parachute_canopy(col: Color) -> void:
	_draw_body(col, false)
	draw_arc(Vector2(0.0, -52.0), 30.0, 0.0, PI, 18, Color(0.95, 0.78, 0.2), 3.0)
	draw_line(Vector2(-30.0, -52.0), Vector2(0.0, -14.0), Color(0.85, 0.7, 0.25), 1.0)
	draw_line(Vector2(30.0, -52.0),  Vector2(0.0, -14.0), Color(0.85, 0.7, 0.25), 1.0)
	draw_line(Vector2(0.0, -52.0),   Vector2(0.0, -14.0), Color(0.85, 0.7, 0.25), 1.0)
