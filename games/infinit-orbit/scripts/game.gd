# game.gd — Main gameplay scene
extends Node2D

const VIEWPORT_W   := 720.0
const VIEWPORT_H   := 1280.0
const CENTER       := Vector2(360.0, 680.0)
const PLANET_BASE_RADIUS := 72.0
const ORBIT_RADIUS_START := 250.0
const ORBIT_RADIUS_MIN   := 90.0
const ORBIT_RADIUS_MAX   := 1501.0
const GRAVITY      := 999.0
const BOOST_POWER  := 199.0
const RING_THICKNESS := 15.0
const RING_FLASH_DURATION := 0.12
const STAR_COUNT   := 220
const TRAIL_LENGTH := 38
const TRAIL_WIDTH  := 8.0
const COIN_RADIUS  := 15.0
const COIN_ORBIT_MIN := 150.0
const COIN_ORBIT_MAX := 1500.0
const COIN_DRIFT_SPEED := 0.7
const PLAYER_SIZE  := 18.0
const BOSS_RING_COLOR := Color(1.0, 0.3, 0.1)
const ORBIT_LINE_ALPHA := 0.12

# Camera zoom range
const ZOOM_NEAR := 1.0
const ZOOM_FAR  := 0.18

class OrbitRing:
	var radius: float = 0.0
	var gap_angle: float = 0.0
	var gap_size: float = 0.0
	var color: Color = Color.WHITE
	var speed: float = 130.0
	var is_boss: bool = false
	var passed: bool = false
	var flash_timer: float = 0.0
	var spawn_burst_done: bool = false
	var extra_gap_angle: float = 0.0
	var has_extra_gap: bool = false
	var age: float = 0.0

class CoinNode:
	var angle: float = 0.0
	var orbit_r: float = 330.0
	var drift: float = 0.3
	var collected: bool = false
	var anim_timer: float = 0.0
	var spawn_scale: float = 0.0

class Star:
	var pos: Vector2 = Vector2.ZERO
	var size: float = 1.0
	var alpha: float = 1.0
	var twinkle_speed: float = 1.0
	var twinkle_phase: float = 0.0

var rings: Array = []
var coins: Array = []
var stars: Array = []

# Player state
var player_angle: float = 0.0
var player_radius: float = ORBIT_RADIUS_START
var player_radial_vel: float = 0.0
var player_dir: float = 1.0    # +1 clockwise, -1 counter-clockwise
var trail_positions: Array = []
var player_dead: bool = false
var death_anim_timer: float = 0.0
var death_particles: Array = []

var planet_pulse: float = 0.0
var planet_rotation: float = 0.0
var planet_rings_angle: float = 0.0

var shake_trauma: float = 0.0
var shake_max_offset := Vector2(12.0, 12.0)
var _shake_time: float = 0.0

var ring_spawn_timer: float = 0.0
var ring_spawn_interval: float = 2.5
var coin_spawn_timer: float = 0.0
var coin_spawn_interval: float = 1.8
var level_up_flash: float = 0.0
var shield_pulse_phase: float = 0.0

# HUD
var _hud: CanvasLayer
var _score_label: Label
var _level_label: Label
var _coins_label: Label
var _pause_btn: Button
var _reverse_btn: Button
var _shield_icon: Control
var _booster_panel: PanelContainer
var _booster_label: Label
var _speed_label: Label
var _edge_warning_label: Label

var _camera: Camera2D

var _bg_color_inner: Color = Color(0.04, 0.04, 0.15)
var _bg_color_outer: Color = Color(0.02, 0.02, 0.08)
var _ring_color: Color = Color(0.2, 0.85, 1.0)
var _player_color: Color = Color(1.0, 1.0, 1.0)
var _planet_color: Color = Color(0.1, 0.4, 0.8)
var _coin_color: Color = Color(1.0, 0.9, 0.2)
var _palette_tween: Tween

var _cached_ship_tex: Texture2D
var _cached_skin_id: int = -1
var _coin_tex: Texture2D

var _paused: bool = false

# Countdown before play
var _countdown_active: bool = true
var _game_countdown: float = 3.0
var _countdown_label: Label

# Tutorial
var _tutorial_active: bool = false
var _tutorial_overlay: Control

func _ready() -> void:
	player_radius = ORBIT_RADIUS_START
	player_radial_vel = 0.0
	player_dir = 1.0
	_build_stars()
	_build_camera()
	_build_hud()
	_coin_tex = load("res://assets/icons/coin.svg")
	_apply_palette(0, false)
	_connect_signals()
	GameManager.start_game()
	ring_spawn_interval = GameManager.get_ring_spawn_interval()
	# Grace period before first ring
	ring_spawn_timer = ring_spawn_interval + 1.5
	AudioManager.play_music_track(1)
	for i in 5:
		_spawn_coin()
	# Show tutorial on first play
	if not SaveManager.is_tutorial_seen():
		call_deferred("_show_tutorial")

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spread := ORBIT_RADIUS_MAX + 600.0
	for i in STAR_COUNT:
		var s := Star.new()
		s.pos = CENTER + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
		s.size = rng.randf_range(0.8, 2.5)
		s.alpha = rng.randf_range(0.3, 1.0)
		s.twinkle_speed = rng.randf_range(0.5, 2.5)
		s.twinkle_phase = rng.randf_range(0.0, TAU)
		stars.append(s)

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = CENTER
	_camera.zoom = Vector2(ZOOM_NEAR, ZOOM_NEAR)
	add_child(_camera)
	_camera.make_current()

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	_score_label = Label.new()
	_score_label.position = Vector2(0, 60)
	_score_label.size = Vector2(VIEWPORT_W, 80)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.text = "0"
	_score_label.add_theme_font_size_override("font_size", 54)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_child(_score_label)

	_level_label = Label.new()
	_level_label.position = Vector2(0, 140)
	_level_label.size = Vector2(VIEWPORT_W, 40)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.text = "LEVEL 1"
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_hud.add_child(_level_label)

	# Speed display (bottom-left)
	_speed_label = Label.new()
	_speed_label.position = Vector2(16, VIEWPORT_H - 220)
	_speed_label.size = Vector2(160, 36)
	_speed_label.add_theme_font_size_override("font_size", 16)
	_speed_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hud.add_child(_speed_label)

	# Edge warning
	_edge_warning_label = Label.new()
	_edge_warning_label.position = Vector2(0, VIEWPORT_H / 2.0 - 80)
	_edge_warning_label.size = Vector2(VIEWPORT_W, 50)
	_edge_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edge_warning_label.add_theme_font_size_override("font_size", 28)
	_edge_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_edge_warning_label.visible = false
	_hud.add_child(_edge_warning_label)

	# Coin counter (top-right)
	var coin_box := HBoxContainer.new()
	coin_box.position = Vector2(VIEWPORT_W - 220, 60)
	coin_box.size = Vector2(200, 50)
	coin_box.alignment = BoxContainer.ALIGNMENT_END
	_hud.add_child(coin_box)

	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/icons/coin.svg")
	coin_icon.custom_minimum_size = Vector2(28, 28)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = Color(1.0, 0.9, 0.2)
	coin_box.add_child(coin_icon)

	_coins_label = Label.new()
	_coins_label.text = " 0"
	_coins_label.add_theme_font_size_override("font_size", 28)
	_coins_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	coin_box.add_child(_coins_label)

	# Pause button
	_pause_btn = Button.new()
	_pause_btn.position = Vector2(20, 56)
	_pause_btn.size = Vector2(54, 54)
	_pause_btn.text = "II"
	_pause_btn.add_theme_font_size_override("font_size", 18)
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color(0.1, 0.1, 0.3, 0.75)
	pb_style.border_color = Color(0.4, 0.6, 1.0, 0.5)
	pb_style.set_border_width_all(2)
	pb_style.set_corner_radius_all(10)
	_pause_btn.add_theme_stylebox_override("normal", pb_style)
	_pause_btn.add_theme_color_override("font_color", Color.WHITE)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_hud.add_child(_pause_btn)

	# Reverse direction button (↺) — above bottom
	_reverse_btn = Button.new()
	_reverse_btn.position = Vector2(VIEWPORT_W / 2.0 - 50, VIEWPORT_H - 170)
	_reverse_btn.size = Vector2(100, 58)
	_reverse_btn.text = "↺"
	_reverse_btn.add_theme_font_size_override("font_size", 32)
	var rb_style := StyleBoxFlat.new()
	rb_style.bg_color = Color(0.2, 0.5, 1.0, 0.25)
	rb_style.border_color = Color(0.2, 0.7, 1.0, 0.8)
	rb_style.set_border_width_all(2)
	rb_style.set_corner_radius_all(29)
	_reverse_btn.add_theme_stylebox_override("normal", rb_style)
	var rb_hover := StyleBoxFlat.new()
	rb_hover.bg_color = Color(0.2, 0.5, 1.0, 0.45)
	rb_hover.border_color = Color(0.4, 0.85, 1.0)
	rb_hover.set_border_width_all(2)
	rb_hover.set_corner_radius_all(29)
	_reverse_btn.add_theme_stylebox_override("hover", rb_hover)
	_reverse_btn.add_theme_color_override("font_color", Color.WHITE)
	_reverse_btn.pressed.connect(_on_reverse_pressed)
	_hud.add_child(_reverse_btn)

	# Shield icon
	_shield_icon = Control.new()
	_shield_icon.position = Vector2(VIEWPORT_W / 2 - 30, VIEWPORT_H - 290)
	_shield_icon.size = Vector2(60, 60)
	_shield_icon.visible = false
	_hud.add_child(_shield_icon)

	var si_rect := TextureRect.new()
	si_rect.texture = load("res://assets/icons/shield.svg")
	si_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	si_rect.size = Vector2(60, 60)
	si_rect.modulate = Color(0.4, 0.8, 1.0)
	_shield_icon.add_child(si_rect)

	# Booster panel
	_booster_panel = PanelContainer.new()
	_booster_panel.position = Vector2(20, VIEWPORT_H - 240)
	_booster_panel.size = Vector2(200, 60)
	_booster_panel.visible = false
	_hud.add_child(_booster_panel)
	_booster_label = Label.new()
	_booster_label.add_theme_font_size_override("font_size", 16)
	_booster_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_booster_panel.add_child(_booster_label)

	# Countdown label
	_countdown_label = Label.new()
	_countdown_label.position = Vector2(0, VIEWPORT_H / 2.0 - 110)
	_countdown_label.size = Vector2(VIEWPORT_W, 200)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 160)
	_countdown_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	_countdown_label.text = "3"
	_hud.add_child(_countdown_label)

func _connect_signals() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.shield_activated.connect(_on_shield_activated)
	GameManager.shield_hit.connect(_on_shield_hit)
	GameManager.shield_depleted.connect(_on_shield_depleted)
	GameManager.palette_changed.connect(_on_palette_changed)
	GameManager.game_over_triggered.connect(_on_game_over)

# ─── TUTORIAL ─────────────────────────────────────────────────────────────────
func _show_tutorial() -> void:
	_tutorial_active = true
	get_tree().paused = true

	_tutorial_overlay = Control.new()
	_tutorial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.z_index = 100
	_tutorial_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.add_child(_tutorial_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.08, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_overlay.add_child(bg)

	var title := Label.new()
	title.position = Vector2(0, 180)
	title.size = Vector2(VIEWPORT_W, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	_tutorial_overlay.add_child(title)

	var instructions := [
		"TAP the screen to boost OUTWARD",
		"Survive rings by passing the GAP",
		"Collect COINS — spend on upgrades",
		"Tap ↺ to REVERSE orbit direction",
		"Don't hit the planet or drift too far!",
	]
	for i in instructions.size():
		var lbl := Label.new()
		lbl.position = Vector2(60, 290 + i * 78)
		lbl.size = Vector2(VIEWPORT_W - 120, 68)
		lbl.text = "• " + instructions[i]
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tutorial_overlay.add_child(lbl)

	var start_btn := Button.new()
	start_btn.position = Vector2(VIEWPORT_W / 2.0 - 120, 740)
	start_btn.size = Vector2(240, 70)
	start_btn.text = "GOT IT — LET'S GO!"
	start_btn.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.85, 1.0, 0.3)
	sb.border_color = Color(0.2, 0.85, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	start_btn.add_theme_stylebox_override("normal", sb)
	var sbh := StyleBoxFlat.new()
	sbh.bg_color = Color(0.2, 0.85, 1.0, 0.55)
	sbh.border_color = Color(0.5, 1.0, 1.0)
	sbh.set_border_width_all(2)
	sbh.set_corner_radius_all(14)
	start_btn.add_theme_stylebox_override("hover", sbh)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	start_btn.pressed.connect(_dismiss_tutorial)
	_tutorial_overlay.add_child(start_btn)

func _dismiss_tutorial() -> void:
	_tutorial_active = false
	if is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
	get_tree().paused = false
	SaveManager.mark_tutorial_seen()

# ─── INPUT ────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if _paused or player_dead or _tutorial_active or _countdown_active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_do_boost()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_do_boost()

func _do_boost() -> void:
	player_radial_vel = BOOST_POWER
	AudioManager.play_sfx("tap")
	_add_tap_burst()

func _on_reverse_pressed() -> void:
	player_dir *= -1.0
	AudioManager.play_sfx("tap")
	add_trauma(0.15)

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if GameManager.state == GameManager.GameState.GAME_OVER:
		_update_death_anim(delta)
		queue_redraw()
		return

	if _paused or _tutorial_active:
		return

	if _countdown_active:
		_game_countdown -= delta
		var num := ceili(_game_countdown)
		if is_instance_valid(_countdown_label):
			if _game_countdown <= 0.0:
				_countdown_label.visible = false
				_countdown_active = false
			else:
				_countdown_label.text = str(num)
				var alpha := clampf(_game_countdown - float(num - 1), 0.0, 1.0)
				_countdown_label.modulate.a = alpha
				_countdown_label.visible = true
		elif _game_countdown <= 0.0:
			_countdown_active = false
		_update_stars(delta)
		_update_planet(delta)
		queue_redraw()
		return

	_update_stars(delta)
	_update_player(delta)
	_update_rings(delta)
	_update_coins(delta)
	_update_planet(delta)
	_update_screen_shake(delta)
	_update_timers(delta)
	_update_hud_boosters(delta)
	_update_particles(delta)
	_update_camera_zoom(delta)
	_update_hud_speed()
	_update_edge_warning()

	ring_spawn_timer -= delta
	if ring_spawn_timer <= 0.0:
		_spawn_ring()
		ring_spawn_interval = GameManager.get_ring_spawn_interval()
		ring_spawn_timer = ring_spawn_interval

	coin_spawn_timer -= delta
	if coin_spawn_timer <= 0.0:
		_spawn_coin()
		coin_spawn_timer = coin_spawn_interval

	queue_redraw()

func _update_stars(delta: float) -> void:
	for s in stars:
		s.twinkle_phase += s.twinkle_speed * delta
		s.alpha = 0.3 + 0.7 * (0.5 + 0.5 * sin(s.twinkle_phase))

func _update_player(delta: float) -> void:
	player_radial_vel -= GRAVITY * delta
	player_radius += player_radial_vel * delta
	player_angle += GameManager.get_player_angular_speed() * player_dir * delta

	if player_radius <= ORBIT_RADIUS_MIN:
		player_radius = ORBIT_RADIUS_MIN
		if not player_dead:
			_trigger_death()
		return

	if player_radius >= ORBIT_RADIUS_MAX:
		player_radius = ORBIT_RADIUS_MAX
		if not player_dead:
			_trigger_death()
		return

	var player_pos := CENTER + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	trail_positions.append(player_pos)
	if trail_positions.size() > TRAIL_LENGTH:
		trail_positions.pop_front()
	_apply_coin_magnet(player_pos, delta)
	_check_coin_collect(player_pos)

func _update_camera_zoom(delta: float) -> void:
	var r_frac := clampf((player_radius - ORBIT_RADIUS_MIN) / (ORBIT_RADIUS_MAX - ORBIT_RADIUS_MIN), 0.0, 1.0)
	var target_zoom := lerpf(ZOOM_NEAR, ZOOM_FAR, r_frac)
	var cur := _camera.zoom.x
	var new_z := lerpf(cur, target_zoom, delta * 5.5)
	# Hard guarantee: player never off-screen regardless of lerp lag.
	# 310 = viewport half-width (360) minus a 50px safety margin.
	var max_allowed := 310.0 / maxf(player_radius, 1.0)
	new_z = minf(new_z, max_allowed)
	_camera.zoom = Vector2(new_z, new_z)

func _update_hud_speed() -> void:
	if not is_instance_valid(_speed_label):
		return
	var spd_deg := rad_to_deg(GameManager.get_player_angular_speed())
	var dir_txt := "CW" if player_dir > 0 else "CCW"
	_speed_label.text = "%.0f°/s  %s" % [spd_deg, dir_txt]

func _update_edge_warning() -> void:
	if not is_instance_valid(_edge_warning_label):
		return
	var near_outer := player_radius > ORBIT_RADIUS_MAX - 70.0
	var near_inner := player_radius < ORBIT_RADIUS_MIN + 55.0
	if near_outer:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		_edge_warning_label.text = "⚠ DRIFT LIMIT!"
		_edge_warning_label.modulate.a = 0.5 + 0.5 * pulse
		_edge_warning_label.visible = true
	elif near_inner:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
		_edge_warning_label.text = "⚠ TOO CLOSE!"
		_edge_warning_label.modulate.a = 0.5 + 0.5 * pulse
		_edge_warning_label.visible = true
	else:
		_edge_warning_label.visible = false

func _apply_coin_magnet(player_pos: Vector2, delta: float) -> void:
	var magnet_r := GameManager.get_coin_magnet_radius()
	for coin in coins:
		if coin.collected:
			continue
		var coin_pos: Vector2 = CENTER + Vector2(cos(coin.angle), sin(coin.angle)) * coin.orbit_r
		if coin_pos.distance_to(player_pos) < magnet_r:
			var diff := wrapf(player_angle - coin.angle, -PI, PI)
			coin.angle += diff * delta * 8.0
			coin.orbit_r = lerpf(coin.orbit_r, player_radius, delta * 5.0)

func _check_coin_collect(player_pos: Vector2) -> void:
	for coin in coins:
		if coin.collected:
			continue
		var coin_pos: Vector2 = CENTER + Vector2(cos(coin.angle), sin(coin.angle)) * coin.orbit_r
		if coin_pos.distance_to(player_pos) < COIN_RADIUS + PLAYER_SIZE:
			coin.collected = true
			GameManager.collect_coin()
			AudioManager.play_sfx("coin")
			_spawn_coin_burst(coin_pos, _coin_color)

func _update_rings(delta: float) -> void:
	var to_remove: Array = []
	for ring in rings:
		ring.radius += ring.speed * delta
		ring.age += delta
		if ring.flash_timer > 0.0:
			ring.flash_timer -= delta
		if not ring.spawn_burst_done and ring.radius > 5.0:
			ring.spawn_burst_done = true
			_spawn_ring_burst(ring)

		var dist_to_orbit := absf(ring.radius - player_radius)
		if dist_to_orbit < RING_THICKNESS * 0.6 and not ring.passed:
			_check_ring_collision(ring)

		if ring.radius > player_radius + RING_THICKNESS and not ring.passed:
			ring.passed = true
			GameManager.ring_passed()
			SaveManager.increment_rings_cleared()
			AudioManager.play_sfx("ring_pass")
			_spawn_ring_clear_burst(ring)

		if ring.radius > ORBIT_RADIUS_MAX + 300.0:
			to_remove.append(ring)

	for r in to_remove:
		rings.erase(r)

func _check_ring_collision(ring: OrbitRing) -> void:
	var in_gap := _angle_in_gap(player_angle, ring.gap_angle, ring.gap_size)
	var in_extra_gap := ring.has_extra_gap and _angle_in_gap(player_angle, ring.extra_gap_angle, ring.gap_size)
	if in_gap or in_extra_gap:
		return
	ring.passed = true
	var fatal := GameManager.try_take_hit()
	if fatal:
		_trigger_death()
	else:
		add_trauma(0.5)
		AudioManager.play_sfx("shield_hit")
		_spawn_shield_burst()

func _angle_in_gap(angle: float, gap_center: float, gap_size: float) -> bool:
	var diff := absf(wrapf(angle - gap_center, -PI, PI))
	return diff <= gap_size * 0.5

func _trigger_death() -> void:
	player_dead = true
	death_anim_timer = 0.0
	add_trauma(1.0)
	AudioManager.play_sfx("game_over")
	_spawn_death_explosion()
	await get_tree().create_timer(1.4).timeout
	GameManager.trigger_game_over()

func _update_coins(delta: float) -> void:
	var i := coins.size() - 1
	while i >= 0:
		if coins[i].collected:
			coins.remove_at(i)
		i -= 1
	for coin in coins:
		coin.angle += coin.drift * delta
		if coin.spawn_scale < 1.0:
			coin.spawn_scale = minf(coin.spawn_scale + delta * 6.0, 1.0)
		if coin.anim_timer > 0.0:
			coin.anim_timer -= delta

func _update_planet(delta: float) -> void:
	planet_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0012)
	planet_rotation += delta * 0.3
	planet_rings_angle += delta * 0.6

func _update_screen_shake(delta: float) -> void:
	if shake_trauma > 0.0:
		shake_trauma = maxf(0.0, shake_trauma - delta * 1.6)
		_shake_time += delta * 60.0
		var amt := shake_trauma * shake_trauma
		_camera.offset = Vector2(
			sin(_shake_time * 1.1) * shake_max_offset.x * amt,
			cos(_shake_time * 1.3) * shake_max_offset.y * amt
		)
	else:
		_camera.offset = _camera.offset.lerp(Vector2.ZERO, delta * 10.0)

func _update_timers(delta: float) -> void:
	level_up_flash = maxf(0.0, level_up_flash - delta * 3.0)
	shield_pulse_phase += delta * 4.0

func _update_hud_boosters(_delta: float) -> void:
	if GameManager.xp_booster_active or GameManager.coin_booster_active:
		_booster_panel.visible = true
		var txt := ""
		if GameManager.xp_booster_active:
			txt += "x%.0f XP  %.1fs\n" % [GameManager.xp_booster_multiplier, GameManager.xp_booster_timer]
		if GameManager.coin_booster_active:
			txt += "x%.0f Coins  %.1fs" % [GameManager.coin_booster_multiplier, GameManager.coin_booster_timer]
		_booster_label.text = txt.strip_edges()
	else:
		_booster_panel.visible = false

# ─── SPAWN ────────────────────────────────────────────────────────────────────
func _spawn_ring() -> void:
	var ring := OrbitRing.new()
	ring.radius = 0.0
	ring.age = 0.0
	ring.flash_timer = RING_FLASH_DURATION

	var is_boss := GameManager.is_boss_level() and rings_cleared_in_boss() < 3
	ring.is_boss = is_boss

	if is_boss:
		ring.speed = GameManager.get_ring_speed() * 1.3
		ring.gap_size = GameManager.get_ring_gap_size() * 0.75
		ring.color = BOSS_RING_COLOR
		ring.has_extra_gap = true
		AudioManager.play_sfx("boss_ring")
	else:
		ring.speed = GameManager.get_ring_speed()
		ring.gap_size = GameManager.get_ring_gap_size()
		ring.color = _ring_color

	var time_to_player := player_radius / ring.speed
	var angular_speed := GameManager.get_player_angular_speed() * player_dir
	var future_angle := player_angle + angular_speed * time_to_player
	ring.gap_angle = wrapf(future_angle + randf_range(-deg_to_rad(25.0), deg_to_rad(25.0)), 0.0, TAU)

	if is_boss:
		ring.extra_gap_angle = wrapf(ring.gap_angle + PI + randf_range(-0.4, 0.4), 0.0, TAU)

	rings.append(ring)

func rings_cleared_in_boss() -> int:
	return 0

func _spawn_coin() -> void:
	if coins.size() >= 12:
		return
	var coin := CoinNode.new()
	coin.angle = randf() * TAU
	coin.orbit_r = randf_range(COIN_ORBIT_MIN, COIN_ORBIT_MAX)
	coin.drift = (randf() * 0.5 + 0.1) * (1.0 if randf() > 0.5 else -1.0)
	coin.collected = false
	coin.spawn_scale = 0.0
	coins.append(coin)

# ─── PARTICLES ────────────────────────────────────────────────────────────────
var _particles: Array = []

func _spawn_ring_burst(ring: OrbitRing) -> void:
	if not SaveManager.get_setting("particles"):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 8:
		var angle := rng.randf() * TAU
		_particles.append({
			"pos": CENTER + Vector2(cos(angle), sin(angle)) * ring.radius,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(40.0, 120.0),
			"life": 0.5, "max_life": 0.5,
			"color": ring.color, "size": rng.randf_range(2.0, 5.0),
		})

func _spawn_ring_clear_burst(ring: OrbitRing) -> void:
	if not SaveManager.get_setting("particles"):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 14:
		var angle := ring.gap_angle + rng.randf_range(-ring.gap_size * 0.5, ring.gap_size * 0.5)
		var speed := rng.randf_range(60.0, 180.0)
		var dir := Vector2(cos(angle), sin(angle))
		_particles.append({
			"pos": CENTER + dir * ring.radius,
			"vel": dir * speed + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)),
			"life": 0.7, "max_life": 0.7,
			"color": ring.color, "size": rng.randf_range(3.0, 6.0),
		})

func _spawn_coin_burst(pos: Vector2, col: Color) -> void:
	if not SaveManager.get_setting("particles"):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 6:
		var angle := rng.randf() * TAU
		_particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(50.0, 140.0),
			"life": 0.4, "max_life": 0.4,
			"color": col, "size": rng.randf_range(2.0, 4.0),
		})

func _spawn_shield_burst() -> void:
	if not SaveManager.get_setting("particles"):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var player_pos := CENTER + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	for i in 20:
		var angle := rng.randf() * TAU
		_particles.append({
			"pos": player_pos,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(80.0, 200.0),
			"life": 0.6, "max_life": 0.6,
			"color": Color(0.4, 0.8, 1.0), "size": rng.randf_range(3.0, 7.0),
		})

func _spawn_death_explosion() -> void:
	if not SaveManager.get_setting("particles"):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var player_pos := CENTER + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	for i in 40:
		var angle := rng.randf() * TAU
		_particles.append({
			"pos": player_pos,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(60.0, 280.0),
			"life": rng.randf_range(0.6, 1.2), "max_life": 1.2,
			"color": _player_color, "size": rng.randf_range(3.0, 9.0),
		})
	for i in 14:
		var angle := rng.randf() * TAU
		_particles.append({
			"pos": player_pos,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(30.0, 150.0),
			"life": rng.randf_range(0.4, 0.8), "max_life": 0.8,
			"color": _ring_color, "size": rng.randf_range(2.0, 5.0),
		})

func _add_tap_burst() -> void:
	if not SaveManager.get_setting("particles"):
		return
	var player_pos := CENTER + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 5:
		var inward := -(CENTER - player_pos).normalized()
		var angle := atan2(inward.y, inward.x) + rng.randf_range(-0.8, 0.8)
		_particles.append({
			"pos": player_pos,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(30.0, 90.0),
			"life": 0.3, "max_life": 0.3,
			"color": _player_color.lerp(Color.WHITE, 0.5), "size": rng.randf_range(2.0, 4.0),
		})

func _update_particles(delta: float) -> void:
	var to_remove: Array = []
	for i in _particles.size():
		var p: Dictionary = _particles[i]
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.88
		p["life"] -= delta
		if p["life"] <= 0.0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		_particles.remove_at(to_remove[i])

func _update_death_anim(delta: float) -> void:
	death_anim_timer += delta
	_update_particles(delta)
	_update_screen_shake(delta)

# ─── DRAWING ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_background()
	_draw_stars()
	_draw_orbit_circle()
	_draw_particles()
	_draw_rings()
	_draw_planet()
	_draw_coins()
	if not player_dead:
		_draw_trail()
		_draw_player()
		_draw_shield()
	_draw_level_flash()

func _draw_background() -> void:
	# Must cover the full visible world at max zoom-out.
	# Worst case: vertical half = VIEWPORT_H/2 / ZOOM_FAR = 640/0.18 ≈ 3555 units from CENTER.
	var world_r := maxf(VIEWPORT_H / ZOOM_FAR, VIEWPORT_W / ZOOM_FAR) + 500.0
	draw_rect(Rect2(CENTER.x - world_r, CENTER.y - world_r, world_r * 2.0, world_r * 2.0), _bg_color_outer)
	var steps := 32
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		var r := world_r * t
		draw_circle(CENTER, r, _bg_color_inner.lerp(_bg_color_outer, 1.0 - t))

func _draw_stars() -> void:
	for s in stars:
		draw_circle(s.pos, s.size, Color(s.alpha, s.alpha, s.alpha * 0.95))

func _draw_orbit_circle() -> void:
	draw_arc(CENTER, ORBIT_RADIUS_MIN + 16.0, 0, TAU, 128,
		Color(1.0, 0.3, 0.2, 0.12), 10.0)
	draw_arc(CENTER, player_radius, 0, TAU, 128,
		Color(_ring_color.r, _ring_color.g, _ring_color.b, ORBIT_LINE_ALPHA), 2.0)
	draw_arc(CENTER, ORBIT_RADIUS_MAX - 16.0, 0, TAU, 256,
		Color(1.0, 0.3, 0.2, 0.08), 8.0)

func _draw_rings() -> void:
	for ring in rings:
		var col: Color = ring.color
		if ring.flash_timer > 0.0:
			col = col.lerp(Color.WHITE, ring.flash_timer / RING_FLASH_DURATION)

		var alpha := 1.0
		if ring.radius < 20.0:
			alpha = ring.radius / 20.0
		var fade_start := ORBIT_RADIUS_MAX + 80.0
		if ring.radius > fade_start:
			alpha = 1.0 - (ring.radius - fade_start) / 220.0
		alpha = clampf(alpha, 0.0, 1.0)
		col.a = alpha

		if ring.is_boss:
			_draw_ring_with_gap(CENTER, ring.radius, ring.gap_angle, ring.gap_size,
				col * Color(1, 1, 1, 0.25), RING_THICKNESS * 2.4)
			_draw_ring_with_gap(CENTER, ring.radius, ring.gap_angle, ring.gap_size,
				col, RING_THICKNESS * 1.5)
		else:
			_draw_ring_with_gap(CENTER, ring.radius, ring.gap_angle, ring.gap_size,
				Color(col.r, col.g, col.b, alpha * 0.18), RING_THICKNESS + 10.0)
			_draw_ring_with_gap(CENTER, ring.radius, ring.gap_angle, ring.gap_size,
				col, RING_THICKNESS)

	for ring in rings:
		if not ring.is_boss:
			continue
		_draw_gap_arrow(ring.gap_angle, ring.radius, ring.color)
		if ring.has_extra_gap:
			_draw_gap_arrow(ring.extra_gap_angle, ring.radius, ring.color)

func _draw_ring_with_gap(center: Vector2, radius: float, gap_angle: float,
		gap_size: float, color: Color, thickness: float) -> void:
	if thickness <= 0.0:
		return
	var arc_start := gap_angle + gap_size * 0.5
	var arc_length := TAU - gap_size
	draw_arc(center, radius, arc_start, arc_start + arc_length, 96, color, thickness)

func _draw_gap_arrow(gap_angle: float, ring_radius: float, col: Color) -> void:
	var dir := Vector2(cos(gap_angle), sin(gap_angle))
	var center_pt := CENTER + dir * ring_radius
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		center_pt + dir * 16.0,
		center_pt - dir * 8.0 + perp * 8.0,
		center_pt - dir * 8.0 - perp * 8.0,
	])
	draw_polygon(pts, PackedColorArray([col, col, col]))

func _draw_planet() -> void:
	var active_planet := SaveManager.get_active_planet()
	var planet_data: Dictionary = SaveManager.PLANET_DATA[active_planet]
	var planet_col: Color = planet_data.get("color", Color(0.1, 0.4, 0.8))
	var pattern: String = planet_data.get("pattern", "earth")

	var glow_r := PLANET_BASE_RADIUS + 18.0 + planet_pulse * 6.0
	draw_circle(CENTER, glow_r, Color(planet_col.r, planet_col.g, planet_col.b, 0.12))
	draw_circle(CENTER, glow_r * 0.85, Color(planet_col.r, planet_col.g, planet_col.b, 0.15))
	draw_circle(CENTER, PLANET_BASE_RADIUS, planet_col.darkened(0.3))

	match pattern:
		"earth":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, planet_col)
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			for i in 6:
				var pos := CENTER + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
				draw_circle(pos, rng.randf_range(15, 30), planet_col.lightened(0.2).darkened(0.1))
		"lava":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, planet_col.darkened(0.2))
			for i in 8:
				var a := planet_rotation + i * TAU / 8.0
				var p1 := CENTER + Vector2(cos(a), sin(a)) * PLANET_BASE_RADIUS * 0.4
				var p2 := CENTER + Vector2(cos(a + 0.5), sin(a + 0.5)) * PLANET_BASE_RADIUS * 0.9
				draw_line(p1, p2, planet_col.lightened(0.4), 4.0)
		"toxic":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, planet_col)
			for i in 5:
				var a := planet_rotation * 0.5 + i * TAU / 5.0
				var p := CENTER + Vector2(cos(a), sin(a)) * PLANET_BASE_RADIUS * 0.6
				draw_circle(p, 10.0 + 4.0 * sin(Time.get_ticks_msec() * 0.002 + i), planet_col.darkened(0.2))
		"ice":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, planet_col)
			for i in 12:
				var a := i * TAU / 12.0
				var p1 := CENTER + Vector2(cos(a), sin(a)) * PLANET_BASE_RADIUS * 0.7
				var p2 := CENTER + Vector2(cos(a), sin(a)) * PLANET_BASE_RADIUS * 0.95
				draw_line(p1, p2, Color.WHITE, 1.0)
		"void":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, Color(0, 0, 0))
			draw_arc(CENTER, PLANET_BASE_RADIUS * 0.8, 0, TAU, 64, planet_col, 2.0)
		"pulsar":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, planet_col)
			var s := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.005)
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.4 * s, Color.WHITE)
		"grid":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, Color(0.05, 0.05, 0.1))
			for i in range(-5, 6):
				var x := i * 14.0
				draw_line(CENTER + Vector2(x, -PLANET_BASE_RADIUS), CENTER + Vector2(x, PLANET_BASE_RADIUS), planet_col, 1.0)
				draw_line(CENTER + Vector2(-PLANET_BASE_RADIUS, x), CENTER + Vector2(PLANET_BASE_RADIUS, x), planet_col, 1.0)
		"sand":
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, planet_col)
			for i in 4:
				var y := -40 + i * 25
				draw_arc(CENTER + Vector2(0, y), PLANET_BASE_RADIUS * 0.8, 0, PI, 32, planet_col.darkened(0.15), 3.0)
		_:
			draw_circle(CENTER, PLANET_BASE_RADIUS * 0.95, planet_col)

	var line_col := Color(planet_col.lightened(0.4).r, planet_col.lightened(0.4).g,
		planet_col.lightened(0.4).b, 0.15)
	for i in 3:
		var t := float(i + 1) / 4.0
		var y_off := (t * 2.0 - 1.0) * PLANET_BASE_RADIUS * 0.7
		var lat_r := sqrt(maxf(PLANET_BASE_RADIUS * PLANET_BASE_RADIUS - y_off * y_off, 0))
		if lat_r > 2.0:
			draw_arc(CENTER + Vector2(0, y_off), lat_r * 0.9, 0, TAU, 48, line_col, 1.0)

	draw_arc(CENTER, PLANET_BASE_RADIUS + 20.0, planet_rings_angle,
		planet_rings_angle + deg_to_rad(200.0), 48,
		Color(planet_col.lightened(0.5).r, planet_col.lightened(0.5).g,
			planet_col.lightened(0.5).b, 0.5), 4.0)
	draw_circle(CENTER + Vector2(-PLANET_BASE_RADIUS * 0.3, -PLANET_BASE_RADIUS * 0.3),
		PLANET_BASE_RADIUS * 0.22, Color(1, 1, 1, 0.2))

func _draw_coins() -> void:
	for coin in coins:
		if coin.collected:
			continue
		var coin_pos: Vector2 = CENTER + Vector2(cos(coin.angle), sin(coin.angle)) * coin.orbit_r
		var sc: float = coin.spawn_scale
		var r: float = COIN_RADIUS * sc
		if r < 0.5:
			continue
		
		# Glow
		draw_circle(coin_pos, r + 5.0, Color(_coin_color.r, _coin_color.g, _coin_color.b, 0.15))
		
		# Real Coin Image
		if _coin_tex:
			var tex_size := Vector2(r * 2.5, r * 2.5)
			var rect := Rect2(coin_pos - tex_size / 2.0, tex_size)
			draw_texture_rect(_coin_tex, rect, false, _coin_color)
		else:
			# Fallback if texture fails
			var pts := PackedVector2Array()
			for i in 6:
				var a := float(i) / 6.0 * TAU
				pts.append(coin_pos + Vector2(cos(a), sin(a)) * r)
			draw_polygon(pts, PackedColorArray([_coin_color, _coin_color, _coin_color,
				_coin_color, _coin_color, _coin_color]))

func _draw_trail() -> void:
	if trail_positions.size() < 2:
		return
	var trail_id := SaveManager.get_active_trail()
	for i in range(1, trail_positions.size()):
		var t := float(i) / trail_positions.size()
		var alpha := t * t
		var width := TRAIL_WIDTH * t
		if width < 0.5:
			continue
		var col: Color
		match trail_id:
			0:
				col = Color(_player_color.r, _player_color.g, _player_color.b, alpha * 0.5)
			1:
				col = Color(1.0, 1.0, 1.0, alpha).lerp(Color(0.3, 0.7, 1.0, 0.0), 1.0 - t)
			2:
				var flicker := 0.7 + 0.3 * sin(i * 2.1)
				col = Color(1.0, 0.8 * flicker, 0.1, alpha * flicker)
			3:
				col = Color(0.9, 0.2, 1.0, alpha)
			4:
				var hue := wrapf(float(i) / trail_positions.size() + Time.get_ticks_msec() * 0.0003, 0.0, 1.0)
				col = Color.from_hsv(hue, 1.0, 1.0, alpha)
			5:
				col = Color(0.05, 0.05, 0.1, alpha * 0.7) if t < 0.8 else Color(0.8, 0.9, 1.0, alpha)
			_:
				col = Color(_player_color.r, _player_color.g, _player_color.b, alpha * 0.6)
		draw_line(trail_positions[i - 1], trail_positions[i], col, width, true)

func _draw_player() -> void:
	var player_pos := CENTER + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	var active_skin := SaveManager.get_active_skin()
	var skin_data: Dictionary = SaveManager.SKIN_DATA[active_skin]
	var skin_col: Color = skin_data.get("color", Color.WHITE)

	if active_skin != _cached_skin_id:
		_cached_skin_id = active_skin
		var skin_icon: String = skin_data.get("icon", "res://assets/ships/ship_classic.svg")
		_cached_ship_tex = load(skin_icon) if skin_icon != "" else null

	draw_circle(player_pos, PLAYER_SIZE + 8.0, Color(skin_col.r, skin_col.g, skin_col.b, 0.25))

	if _cached_ship_tex:
		var draw_size := Vector2(PLAYER_SIZE * 2.8, PLAYER_SIZE * 2.8)
		var angle := player_angle + PI / 2.0 * player_dir
		draw_set_transform(player_pos, angle, Vector2.ONE)
		draw_texture_rect(_cached_ship_tex, Rect2(-draw_size / 2.0, draw_size), false, skin_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Fallback triangle
		var fwd := Vector2(cos(player_angle), sin(player_angle)) * player_dir
		var pts := PackedVector2Array([
			player_pos + fwd * PLAYER_SIZE,
			player_pos + Vector2(-fwd.y, fwd.x) * PLAYER_SIZE * 0.6 - fwd * PLAYER_SIZE * 0.5,
			player_pos - Vector2(-fwd.y, fwd.x) * PLAYER_SIZE * 0.6 - fwd * PLAYER_SIZE * 0.5,
		])
		draw_polygon(pts, PackedColorArray([skin_col, skin_col, skin_col]))

	var engine_pos := player_pos - Vector2(cos(player_angle), sin(player_angle)) * 10.0
	draw_circle(engine_pos, 4.0 + 2.0 * sin(Time.get_ticks_msec() * 0.02), Color(1, 0.6, 0.2, 0.8))

func _draw_shield() -> void:
	if not GameManager.shield_active and GameManager.shield_grace_timer <= 0.0:
		return
	var player_pos := CENTER + Vector2(cos(player_angle), sin(player_angle)) * player_radius
	var pulse := 0.5 + 0.5 * sin(shield_pulse_phase)
	var alpha := 0.5 + 0.3 * pulse
	if GameManager.shield_grace_timer > 0.0:
		alpha = GameManager.shield_grace_timer / 1.5 * 0.6
	var shield_col := Color(0.4, 0.8, 1.0, alpha)
	draw_arc(player_pos, PLAYER_SIZE + 8.0 + pulse * 3.0, 0, TAU, 48, shield_col, 3.0)
	draw_circle(player_pos, PLAYER_SIZE + 10.0, Color(0.4, 0.8, 1.0, alpha * 0.15))

func _draw_particles() -> void:
	for p in _particles:
		var t: float = p["life"] / p["max_life"]
		var col: Color = p["color"]
		col.a = t * t
		draw_circle(p["pos"], p["size"] * t, col)

func _draw_level_flash() -> void:
	if level_up_flash > 0.0:
		draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(1, 1, 1, level_up_flash * 0.4))

# ─── PALETTE ──────────────────────────────────────────────────────────────────
func _apply_palette(index: int, animated: bool) -> void:
	var pal: Array = GameManager.PALETTES[index]
	if not animated:
		_ring_color     = pal[0]
		_player_color   = pal[1]
		_planet_color   = pal[2]
		_bg_color_inner = pal[3]
		_bg_color_outer = pal[4]
		_coin_color     = pal[5]
		return
	if _palette_tween:
		_palette_tween.kill()
	_palette_tween = create_tween().set_parallel(true)
	_palette_tween.tween_method(func(c): _ring_color = c,     _ring_color,     pal[0], 1.5)
	_palette_tween.tween_method(func(c): _player_color = c,   _player_color,   pal[1], 1.5)
	_palette_tween.tween_method(func(c): _planet_color = c,   _planet_color,   pal[2], 1.5)
	_palette_tween.tween_method(func(c): _bg_color_inner = c, _bg_color_inner, pal[3], 1.5)
	_palette_tween.tween_method(func(c): _bg_color_outer = c, _bg_color_outer, pal[4], 1.5)
	_palette_tween.tween_method(func(c): _coin_color = c,     _coin_color,     pal[5], 1.5)

# ─── SIGNAL HANDLERS ──────────────────────────────────────────────────────────
func _on_score_changed(new_score: int) -> void:
	if is_instance_valid(_score_label):
		_score_label.text = str(new_score)

func _on_level_changed(new_level: int) -> void:
	if is_instance_valid(_level_label):
		_level_label.text = "LEVEL %d" % new_level
	level_up_flash = 0.7
	AudioManager.play_sfx("level_up")
	add_trauma(0.35)
	ring_spawn_interval = GameManager.get_ring_spawn_interval()

func _on_coins_changed(new_count: int) -> void:
	if is_instance_valid(_coins_label):
		_coins_label.text = " %d" % new_count

func _on_shield_activated() -> void:
	_shield_icon.visible = true

func _on_shield_hit() -> void:
	add_trauma(0.6)

func _on_shield_depleted() -> void:
	_shield_icon.visible = false

func _on_palette_changed(idx: int) -> void:
	_apply_palette(idx, true)

func _on_game_over(_final_score: int, _coins_earned: int) -> void:
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _on_pause_pressed() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_btn.text = "PLAY" if _paused else "II"

func add_trauma(amount: float) -> void:
	shake_trauma = minf(shake_trauma + amount, 1.0)
