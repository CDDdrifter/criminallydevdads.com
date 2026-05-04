extends Node2D

# ── Turn states ───────────────────────────────────────────────────────────────
enum State { PLAYER_SELECT, PLAYER_AIM, PLAYER_RESOLVE, AI_THINKING, AI_FIRE, AI_RESOLVE, GAME_OVER }

const VW := 1920.0
const VH := 1080.0
const GROUND_Y := 964.0
const SLING_X := 200.0

var state: State = State.PLAYER_SELECT
var level_cfg: Dictionary = {}

var _camera: Camera2D
var _background: Node2D
var _ground: StaticBody2D
var _player_castle: Node
var _enemy_castle: Node
var _slingshot: Node
var _bomb_container: Node2D
var _effect_container: Node2D
var _hud: CanvasLayer
var _ai_brain: Node
var _ai_catapult_pos: Vector2 = Vector2.ZERO
var _ai_cat_draw: Node2D = null

var _score: int = 0
var _player_bombs_left: int = 10
var _ai_bombs_left: int = 8
var _selected_bomb_idx: int = 0
var _available_bombs: Array = ["standard"]
var _ai_bomb_types: Array = ["standard"]
var _wind: float = 0.0
var _world_width: float = 1920.0
var _ai_think_timer: float = 0.0
var _active_bomb: Node = null
var _cam_target: Vector2 = Vector2.ZERO
var _cam_idle_pos: Vector2 = Vector2.ZERO
var _turn_count: int = 0
var _fire_zones: Array = []
var _fallback_timer: float = 0.0  # guards against bombs that never land
var _ghost_trail_node: Node2D = null
var _recording_trail: Array = []
var _trail_tick: float = 0.0
var _ghost_trail_enabled: bool = true
var _trail_sample_rate: float = 0.04

var _blocks_damaged: int = 0
var _heavy_bombs_used: int = 0
var _used_bomb_types: Array = []
var _current_bomb_type: String = "standard"
var _level_start_time: float = 0.0
var _special_used_this_level: bool = false
var _desired_time_scale: float = 1.0

func _ready() -> void:
	level_cfg = LevelData.get_level(GameState.current_level)
	if level_cfg.is_empty():
		level_cfg = LevelData.get_level(1)
	_level_start_time = Time.get_unix_time_from_system()
	_setup_scene()
	_start_player_turn()

func _setup_scene() -> void:
	_world_width = float(level_cfg.get("world_width", 1920))
	var zoom := float(level_cfg.get("cam_zoom", 0.78))
	_wind = float(level_cfg.get("wind", 0.0)) * (1 if randf() > 0.5 else -1)
	_available_bombs = GameState.unlocked_bombs.duplicate()
	if _available_bombs.is_empty():
		_available_bombs = ["standard"]
	_ai_bomb_types = level_cfg.get("ai_bombs", ["standard"])
	_player_bombs_left = level_cfg.get("player_bomb_count", 10)
	_ai_bombs_left = level_cfg.get("ai_bomb_count", 8)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(zoom, zoom)
	add_child(_camera)
	_cam_idle_pos = Vector2(_world_width * 0.5, VH * 0.5)
	_camera.position = _cam_idle_pos
	_camera.limit_left = 0
	_camera.limit_right = int(_world_width)
	_camera.limit_top = 0
	_camera.limit_bottom = int(VH + 300)

	_background = preload("res://scripts/background.gd").new()
	_background.setup(level_cfg.get("biome", "grassland"), _world_width)
	add_child(_background)

	# Ground visual + physics
	var gv := ColorRect.new()
	gv.color = Color(0.22, 0.18, 0.12)
	gv.position = Vector2(0, GROUND_Y)
	gv.size = Vector2(_world_width, VH - GROUND_Y + 300)
	add_child(gv)

	# Ground line accent
	var gl := ColorRect.new()
	gl.color = Color(0.35, 0.28, 0.18)
	gl.position = Vector2(0, GROUND_Y)
	gl.size = Vector2(_world_width, 6)
	add_child(gl)

	_ground = StaticBody2D.new()
	_ground.add_to_group("ground")
	_ground.collision_layer = 1
	_ground.collision_mask = 0
	var gs := CollisionShape2D.new()
	var gr := RectangleShape2D.new()
	gr.size = Vector2(_world_width + 600, 100)
	gs.shape = gr
	_ground.add_child(gs)
	_ground.position = Vector2(_world_width * 0.5, GROUND_Y + 50)
	add_child(_ground)

	_bomb_container = Node2D.new()
	add_child(_bomb_container)
	_effect_container = Node2D.new()
	add_child(_effect_container)

	# Ghost trail sits above ground/effects but below castles/slingshot
	_ghost_trail_node = preload("res://scripts/ghost_trail.gd").new()
	add_child(_ghost_trail_node)

	# Castles
	var pc_cfg: Dictionary = level_cfg.get("player_castle", {"layout":"wall","w":4,"h":4,"mats":["wood"],"hp_mult":1.0})
	var ec_cfg: Dictionary = level_cfg.get("enemy_castle", {"layout":"wall","w":5,"h":5,"mats":["stone"],"hp_mult":1.0})
	var pc_w := float(pc_cfg.get("w", 4)) * 64.0
	var ec_w := float(ec_cfg.get("w", 5)) * 64.0

	var player_anchor := SLING_X + 220.0
	var enemy_anchor := _world_width - SLING_X - 220.0 - ec_w
	_ai_catapult_pos = Vector2(_world_width - SLING_X, GROUND_Y - 10)

	_player_castle = preload("res://scripts/castle.gd").new()
	_player_castle.castle_damaged.connect(_on_castle_damaged)
	_player_castle.castle_destroyed.connect(_on_castle_destroyed)
	_player_castle.build(pc_cfg, "player", player_anchor)
	add_child(_player_castle)

	_enemy_castle = preload("res://scripts/castle.gd").new()
	_enemy_castle.castle_damaged.connect(_on_castle_damaged)
	_enemy_castle.castle_destroyed.connect(_on_castle_destroyed)
	_enemy_castle.build(ec_cfg, "enemy", enemy_anchor)
	add_child(_enemy_castle)

	# Slingshot — added after castles so it renders in front
	_slingshot = preload("res://scripts/slingshot.gd").new()
	_slingshot.setup(Vector2(SLING_X, GROUND_Y - 10))
	_slingshot.bomb_launched.connect(_on_player_launched)
	_slingshot.z_index = 2
	add_child(_slingshot)

	# AI catapult visual — separate node added after castles for correct draw order
	_ai_cat_draw = preload("res://scripts/ai_catapult.gd").new()
	_ai_cat_draw.position = _ai_catapult_pos
	_ai_cat_draw.z_index = 2
	add_child(_ai_cat_draw)

	# AI brain
	_ai_brain = preload("res://scripts/ai_brain.gd").new()
	_ai_brain.setup(float(level_cfg.get("ai_difficulty", 0.5)))
	add_child(_ai_brain)

	# Apply difficulty settings
	match GameState.difficulty:
		"easy":
			_ai_brain.set("difficulty", minf(float(_ai_brain.get("difficulty")), 0.20))
			_slingshot.set("preview_steps", 60)
			_trail_sample_rate = 0.025
		"hard":
			_slingshot.set("preview_steps", 20)
			_ghost_trail_enabled = false

	# HUD
	_hud = preload("res://scripts/hud.gd").new()
	_hud.bomb_selected.connect(_on_bomb_selected)
	_hud.pause_pressed.connect(_on_pause)
	_hud.resume_pressed.connect(_on_resume)
	_hud.restart_pressed.connect(_on_restart)
	_hud.quit_to_menu_pressed.connect(_quit_to_menu)
	_hud.special_pressed.connect(_on_special_pressed)
	_hud.detonate_pressed.connect(_on_detonate_pressed)
	_hud.speed_changed.connect(_on_speed_changed)
	GameState.challenge_completed.connect(_on_challenge_completed)
	add_child(_hud)
	_hud.build_bomb_selector(_available_bombs, _selected_bomb_idx)
	_hud.set_wind(_wind)
	_hud.set_bombs_left(_player_bombs_left)
	_hud.set_score(0)
	_hud.set_player_hp(1.0)
	_hud.set_enemy_hp(1.0)

	# Level name display
	var lvl_label := Label.new()
	lvl_label.text = "Level %d: %s" % [level_cfg.get("id", 1), level_cfg.get("name", "")]
	lvl_label.position = Vector2(760, 75)
	lvl_label.add_theme_font_size_override("font_size", 16)
	lvl_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_label.size = Vector2(400, 24)
	_hud.add_child(lvl_label)

func _filter_bombs(wanted: Array) -> Array:
	var result: Array = []
	for b in wanted:
		if b in GameState.unlocked_bombs:
			result.append(b)
	if result.is_empty():
		result = ["standard"]
	return result

# ── Player Turn ───────────────────────────────────────────────────────────────

func _start_player_turn() -> void:
	_turn_count += 1
	if _player_bombs_left <= 0:
		if not _enemy_castle.is_destroyed():
			_game_over(false, "Out of bombs!")
		return
	state = State.PLAYER_SELECT
	_hud.set_turn(true)
	_hud.set_bombs_left(_player_bombs_left)
	_hud.build_bomb_selector(_available_bombs, _selected_bomb_idx)
	_cam_target = _cam_idle_pos
	_slingshot.set_active(false)
	get_tree().create_timer(0.4).timeout.connect(_enter_aim_state)

func _enter_aim_state() -> void:
	if state != State.PLAYER_SELECT:
		return
	state = State.PLAYER_AIM
	_cam_target = Vector2(SLING_X + 420, GROUND_Y - 300)
	_current_bomb_type = _available_bombs[_selected_bomb_idx]
	var bomb := _spawn_bomb(_current_bomb_type, "player", Vector2(SLING_X, GROUND_Y - 80))
	# Keep frozen until slingshot releases
	bomb.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	bomb.freeze = true
	_active_bomb = bomb
	_slingshot.place_bomb(bomb)
	_slingshot.set_active(true)

func _on_player_launched(launch_vel: Vector2, launch_pos: Vector2) -> void:
	if state != State.PLAYER_AIM or _active_bomb == null:
		return
	state = State.PLAYER_RESOLVE
	_player_bombs_left -= 1
	if _current_bomb_type not in _used_bomb_types:
		_used_bomb_types.append(_current_bomb_type)
	if _current_bomb_type == "heavy":
		_heavy_bombs_used += 1
	_slingshot.set_active(false)
	_hud.set_bombs_left(_player_bombs_left)

	_active_bomb.position = launch_pos
	# Ensure the bomb starts above the ground surface to prevent instant detonation
	if _active_bomb.position.y > GROUND_Y - 22:
		_active_bomb.position.y = GROUND_Y - 22
	_active_bomb.launched = true
	_active_bomb.freeze = false
	_active_bomb.linear_velocity = launch_vel
	_fallback_timer = 7.0
	_hud.set_detonate_visible(true)

func _on_bomb_selected(idx: int) -> void:
	_selected_bomb_idx = clamp(idx, 0, _available_bombs.size() - 1)
	_hud.build_bomb_selector(_available_bombs, _selected_bomb_idx)
	if state == State.PLAYER_AIM and _active_bomb != null and is_instance_valid(_active_bomb):
		_active_bomb.queue_free()
		_active_bomb = null
		_current_bomb_type = _available_bombs[_selected_bomb_idx]
		var bomb := _spawn_bomb(_current_bomb_type, "player", Vector2(SLING_X, GROUND_Y - 80))
		bomb.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		bomb.freeze = true
		_active_bomb = bomb
		_slingshot.place_bomb(bomb)

func _on_special_pressed() -> void:
	if _special_used_this_level:
		_hud.show_status("Special already used!", Color(0.75, 0.55, 0.45))
		return
	if _active_bomb == null or not is_instance_valid(_active_bomb) or not _active_bomb.launched:
		_hud.show_status("Fire a bomb first!", Color(0.75, 0.55, 0.45))
		return
	_special_used_this_level = true
	_hud.set_special_used(true)
	_hud.flash_special()
	_active_bomb.activate_special()
	_hud.show_status("SPECIAL!", Color(1.0, 0.88, 0.22))

# ── Explosion ─────────────────────────────────────────────────────────────────

func _on_bomb_exploded(pos: Vector2, radius: float, force: float, damage: float, special: String) -> void:
	_do_explosion(pos, radius, force, damage, special)

func _do_explosion(pos: Vector2, radius: float, force: float, damage: float, special: String) -> void:
	_fallback_timer = 0.0
	if state == State.PLAYER_RESOLVE:
		_hud.set_detonate_visible(false)
	# Save player shot trail only
	if state == State.PLAYER_RESOLVE and _ghost_trail_enabled:
		_recording_trail.append(pos)
		if _recording_trail.size() > 2:
			_ghost_trail_node.call("set_trail", _recording_trail.duplicate())
	_recording_trail.clear()
	_trail_tick = 0.0
	var exp_col := Color(1.0, 0.6, 0.1) if special != "freeze" else Color(0.5, 0.8, 1.0)
	preload("res://scripts/explosion.gd").spawn(_effect_container, pos, radius, exp_col)
	_shake(radius / 90.0)

	var space := get_world_2d().direct_space_state
	var circle := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	circle.shape = shape
	circle.transform = Transform2D(0, pos)
	circle.collision_mask = 2
	var hits := space.intersect_shape(circle, 64)

	var score_gain := 0
	for hit in hits:
		var body: Variant = hit.get("collider")
		if body == null or not is_instance_valid(body):
			continue
		var dist: float = ((body as Node2D).global_position - pos).length()
		var dmg_ratio: float = 1.0 - clamp(dist / max(radius, 1.0), 0.0, 1.0)
		var dmg: float = damage * dmg_ratio

		match special:
			"freeze":
				if body.has_method("freeze_block"):
					body.freeze_block(3.8)
			"magnet":
				if body is RigidBody2D:
					var dir: Vector2 = (pos - (body as Node2D).global_position).normalized()
					(body as RigidBody2D).apply_central_impulse(dir * force * dmg_ratio)
				if body.has_method("take_damage"):
					body.take_damage(dmg * 0.4)
			_:
				if body.has_method("take_damage"):
					body.take_damage(dmg)
					score_gain += 5
				if body is RigidBody2D and not (body as RigidBody2D).freeze:
					var dir: Vector2 = ((body as Node2D).global_position - pos).normalized()
					(body as RigidBody2D).apply_central_impulse(dir * force * dmg_ratio)

	_score += score_gain
	if state == State.PLAYER_RESOLVE:
		_blocks_damaged += score_gain / 5
	_hud.set_score(_score)
	_player_castle.update_hp()
	_enemy_castle.update_hp()
	_hud.set_player_hp(_player_castle.get_hp_ratio())
	_hud.set_enemy_hp(_enemy_castle.get_hp_ratio())

	# After-explosion transition — use current state to decide what's next
	var resolve_delay := 1.8
	var current_state := state
	get_tree().create_timer(resolve_delay).timeout.connect(func(): _after_resolve(current_state))

func _after_resolve(from_state: State) -> void:
	if state == State.GAME_OVER:
		return
	if _enemy_castle.is_destroyed():
		_game_over(true, "VICTORY!")
		return
	if _player_castle.is_destroyed():
		_game_over(false, "DEFEATED!")
		return
	match from_state:
		State.PLAYER_RESOLVE:
			_start_ai_turn()
		State.AI_RESOLVE:
			_start_player_turn()
		_:
			_start_player_turn()

# ── AI Turn ───────────────────────────────────────────────────────────────────

func _start_ai_turn() -> void:
	if state == State.GAME_OVER:
		return
	if _ai_bombs_left <= 0:
		_start_player_turn()
		return
	state = State.AI_THINKING
	_hud.set_turn(false)
	_hud.show_status("Enemy Aiming...", Color(1.0, 0.4, 0.4))
	_ai_think_timer = randf_range(1.3, 2.5)

func _ai_fire() -> void:
	if state == State.GAME_OVER:
		return
	state = State.AI_FIRE
	_hud.show_status("", Color.WHITE)

	var ai_pos := _ai_catapult_pos + Vector2(0, -70)
	var target: Vector2 = _player_castle.get_center()
	var bomb_type: String = _ai_brain.pick_bomb(_ai_bomb_types, GameState.unlocked_bombs, _turn_count)
	var vel: Vector2 = _ai_brain.calculate_shot(ai_pos, target)
	if vel == Vector2.ZERO:
		vel = Vector2(-900, -1000)

	_ai_bombs_left -= 1
	var bomb := _spawn_bomb(bomb_type, "ai", ai_pos)
	bomb.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	bomb.freeze = false
	bomb.launched = true
	bomb.linear_velocity = vel
	_active_bomb = bomb
	state = State.AI_RESOLVE
	_fallback_timer = 8.0

# ── Bomb factory ──────────────────────────────────────────────────────────────

func _spawn_bomb(type: String, side: String, pos: Vector2) -> RigidBody2D:
	var bomb := preload("res://scripts/bomb.gd").new()
	var col := CollisionShape2D.new()
	var cshape := CircleShape2D.new()
	cshape.radius = float(bomb.TYPES.get(type, bomb.TYPES["standard"]).get("size", 14))
	col.shape = cshape
	bomb.add_child(col)
	bomb.position = pos
	bomb.setup(type, side, _wind)
	bomb.exploded.connect(_on_bomb_exploded)
	bomb.split_bomb.connect(_on_split_bomb)
	bomb.request_lightning.connect(_on_lightning)
	bomb.request_fire_zone.connect(_on_fire_zone)
	_bomb_container.add_child(bomb)
	return bomb

func _on_split_bomb(pos: Vector2, vel: Vector2, type: String, side: String) -> void:
	var b := _spawn_bomb(type, side, pos)
	b.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	b.freeze = false
	b.launched = true
	b.linear_velocity = vel

func _on_lightning(pos: Vector2, radius: float, damage: float) -> void:
	var space := get_world_2d().direct_space_state
	var circle := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	circle.shape = shape
	circle.transform = Transform2D(0, pos)
	circle.collision_mask = 2
	var hits := space.intersect_shape(circle, 12)
	for hit in hits:
		var body: Variant = hit.get("collider")
		if body and body.has_method("take_damage"):
			body.take_damage(damage)
	preload("res://scripts/explosion.gd").spawn(_effect_container, pos, radius * 0.4, Color(1.0, 1.0, 0.3))

func _on_fire_zone(pos: Vector2) -> void:
	_fire_zones.append({"pos": pos, "radius": 90.0, "timer": 4.0, "tick": 0.5})

# ── Process / Camera / Timers ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Camera smooth follow
	_camera.position = _camera.position.lerp(_cam_target, 3.4 * delta)

	# Follow active bomb; record positions only for player shots
	if _active_bomb != null and is_instance_valid(_active_bomb) and _active_bomb.launched:
		_cam_target = _active_bomb.global_position
		if state == State.PLAYER_RESOLVE and _ghost_trail_enabled:
			_trail_tick -= delta
			if _trail_tick <= 0.0:
				_trail_tick = _trail_sample_rate
				_recording_trail.append(_active_bomb.global_position)

	# AI think timer
	if state == State.AI_THINKING:
		_ai_think_timer -= delta
		if _ai_think_timer <= 0:
			_ai_fire()

	# Fallback: force-detonate if bomb never lands
	if _fallback_timer > 0 and (state == State.PLAYER_RESOLVE or state == State.AI_RESOLVE):
		_fallback_timer -= delta
		if _fallback_timer <= 0:
			_recording_trail.clear()
			_trail_tick = 0.0
			if _active_bomb != null and is_instance_valid(_active_bomb):
				_active_bomb.call("_detonate")
			else:
				var s := state
				_after_resolve(s)

	# Fire zones DoT
	var to_remove: Array = []
	for fz in _fire_zones:
		fz["timer"] -= delta
		fz["tick"] -= delta
		if fz["tick"] <= 0:
			fz["tick"] = 0.5
			_apply_fire_zone(fz["pos"], fz["radius"])
		if fz["timer"] <= 0:
			to_remove.append(fz)
	for fz in to_remove:
		_fire_zones.erase(fz)

func _apply_fire_zone(pos: Vector2, radius: float) -> void:
	var space := get_world_2d().direct_space_state
	var circle := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	circle.shape = shape
	circle.transform = Transform2D(0, pos)
	circle.collision_mask = 2
	for hit in space.intersect_shape(circle, 32):
		var body: Variant = hit.get("collider")
		if body and body.has_method("take_fire_damage"):
			body.take_fire_damage(8.0, 1.0)

# ── Castle events ─────────────────────────────────────────────────────────────

func _on_castle_damaged(s: String, current: float, max_hp: float) -> void:
	var ratio: float = current / max(max_hp, 1.0)
	if s == "player":
		_hud.set_player_hp(ratio)
	else:
		_hud.set_enemy_hp(ratio)
		_score += 8
		_hud.set_score(_score)

func _on_castle_destroyed(s: String) -> void:
	if s == "enemy":
		_game_over(true, "VICTORY!")
	else:
		_game_over(false, "DEFEATED!")

# ── Win / Lose ────────────────────────────────────────────────────────────────

func _game_over(player_won: bool, msg: String) -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	Engine.time_scale = 1.0
	_hud.reset_speed()
	_slingshot.set_active(false)
	_fallback_timer = 0.0

	var col := Color(0.3, 1.0, 0.4) if player_won else Color(1.0, 0.3, 0.3)
	_hud.show_status(msg, col)

	if player_won:
		# 1. Base win logic & stars
		var stars := _calculate_stars()
		var level_id: int = level_cfg.get("id", 1)
		var old_rank: int = GameState.player_rank
		var rewards := GameState.complete_level(level_id, stars, _score)

		# 2. Achievements
		GameState.check_achievement_direct("first_blood")
		if stars == 3:
			GameState.check_achievement_direct("three_star_10")

		# 3. Daily challenges
		GameState.check_and_complete_challenges({
			"won": true,
			"stars": stars,
			"level_id": level_id,
			"bombs_remaining": _player_bombs_left,
			"blocks_damaged": _blocks_damaged,
			"heavy_bombs_used": _heavy_bombs_used,
			"used_bomb_types": _used_bomb_types,
			"player_hp_ratio": _player_castle.get_hp_ratio(),
			"level_time": Time.get_unix_time_from_system() - _level_start_time,
			"ranked_up": GameState.player_rank > old_rank,
		})

		# 4. Show win screen
		get_tree().create_timer(2.5).timeout.connect(func(): _show_results(stars, rewards))

	else:
		GameState.check_and_complete_challenges({"won": false})
		get_tree().create_timer(2.5).timeout.connect(_show_defeat)


# This must be its own function so _game_over can call it
func _calculate_stars() -> int:
	var total := float(level_cfg.get("player_bomb_count", 10))
	var used := total - float(_player_bombs_left)
	var ratio: float = used / max(total, 1.0)
	if ratio <= 0.4:
		return 3
	elif ratio <= 0.75:
		return 2
	return 1


func _show_results(stars: int, rewards: Dictionary) -> void:
	add_child(_make_result_overlay(true, stars, rewards))
	

func _show_defeat() -> void:
	add_child(_make_result_overlay(false, 0, {}))

func _make_result_overlay(won: bool, stars: int, rewards: Dictionary) -> CanvasLayer:
	var canvas := CanvasLayer.new()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.80)
	canvas.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(660, 230)
	vbox.custom_minimum_size = Vector2(600, 0)
	vbox.add_theme_constant_override("separation", 20)
	canvas.add_child(vbox)

	var title := Label.new()
	title.text = "VICTORY!" if won else "DEFEATED"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if won else Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if won:
		var star_row := HBoxContainer.new()
		star_row.alignment = BoxContainer.ALIGNMENT_CENTER
		star_row.add_theme_constant_override("separation", 14)
		vbox.add_child(star_row)
		for i in 3:
			var sl := Label.new()
			sl.text = "★" if i < stars else "☆"
			sl.add_theme_font_size_override("font_size", 56)
			sl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1) if i < stars else Color(0.35, 0.35, 0.35))
			star_row.add_child(sl)

		var sl := Label.new()
		sl.text = "Score: %d" % _score
		sl.add_theme_font_size_override("font_size", 28)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sl)

		var rl := Label.new()
		rl.text = "+%d XP   +%d Gold" % [rewards.get("xp", 0), rewards.get("gold", 0)]
		rl.add_theme_font_size_override("font_size", 24)
		rl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rl)

		if rewards.get("first_clear", false):
			var fc := Label.new()
			fc.text = "✦ FIRST CLEAR BONUS!"
			fc.add_theme_font_size_override("font_size", 18)
			fc.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
			fc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(fc)

	var current_id: int = level_cfg.get("id", 1)

	if won and GameState.is_level_unlocked(current_id + 1):
		var nb := Button.new()
		nb.text = "NEXT LEVEL →"
		nb.custom_minimum_size = Vector2(560, 68)
		nb.add_theme_font_size_override("font_size", 26)
		nb.pressed.connect(func():
			GameState.current_level = current_id + 1
			get_tree().reload_current_scene())
		vbox.add_child(nb)

	var rb := Button.new()
	rb.text = "RETRY" if not won else "REPLAY"
	rb.custom_minimum_size = Vector2(560, 58)
	rb.add_theme_font_size_override("font_size", 22)
	rb.pressed.connect(func():
		GameState.current_level = current_id
		get_tree().reload_current_scene())
	vbox.add_child(rb)

	var mb := Button.new()
	mb.text = "LEVEL SELECT"
	mb.custom_minimum_size = Vector2(560, 52)
	mb.add_theme_font_size_override("font_size", 20)
	mb.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	vbox.add_child(mb)

	return canvas

# ── Camera shake ──────────────────────────────────────────────────────────────

func _shake(intensity: float) -> void:
	intensity = clamp(intensity, 0.5, 5.0)
	var tween := get_tree().create_tween()
	for i in 7:
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity * 9.0
		tween.tween_property(_camera, "offset", offset, 0.048)
	tween.tween_property(_camera, "offset", Vector2.ZERO, 0.12)

# ── Pause ─────────────────────────────────────────────────────────────────────

func _on_speed_changed(mult: float) -> void:
	_desired_time_scale = mult
	Engine.time_scale = mult

func _on_detonate_pressed() -> void:
	if state != State.PLAYER_RESOLVE or _active_bomb == null or not is_instance_valid(_active_bomb):
		return
	if not _active_bomb.launched:
		return
	_fallback_timer = 0.0
	_hud.set_detonate_visible(false)
	_active_bomb.call("_detonate")

func _on_challenge_completed(desc: String, reward: int) -> void:
	_hud.show_challenge_toast(desc, reward)

func _on_pause() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = true
	_hud.show_pause(true)

func _on_resume() -> void:
	get_tree().paused = false
	_hud.show_pause(false)
	Engine.time_scale = _desired_time_scale

func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		Engine.time_scale = 1.0
