# mini_game.gd — Daily mini-games: Precision Tap, Speed Burst, Orbit Challenge.
extends Control

const VIEWPORT_W    := 720.0
const VIEWPORT_H    := 1280.0
const CENTER        := Vector2(360.0, 660.0)

# Orbit Challenge tuning
const OC_RADIUS         := 200.0
const OC_PLANET_R       := 38.0
const OC_GATE_LIFETIME  := 4.2
const OC_SCORE_ANGLE    := 0.38   # ~21.8 deg angular tolerance
const OC_DURATION       := 22.0
const OC_SPEED_BASE     := 2.2    # rad/s

# Precision Tap tuning
const PT_MAX_ROUNDS     := 5
const PT_TOTAL_TIME     := 35.0   # single continuous timer for all 5 rounds

# Speed Burst tuning
const SB_DURATION       := 6.0
const SB_COUNTDOWN_SEC  := 3.0

enum MiniGameState { SELECT, PLAYING, RESULT }
enum GameType { PRECISION_TAP, SPEED_BURST, ORBIT_CHALLENGE }

var _state: MiniGameState = MiniGameState.SELECT
var _game_type: GameType  = GameType.PRECISION_TAP
var _stars: Array         = []

# ── Precision Tap ─────────────────────────────────────────────────────────────
var _pt_target_angle:     float = 0.0
var _pt_needle_angle:     float = 0.0
var _pt_needle_speed:     float = 2.5
var _pt_needle_dir:       float = 1.0   # +1 or -1 (reversible)
var _pt_zone_size:        float = deg_to_rad(30.0)
var _pt_round:            int   = 0
var _pt_hits:             int   = 0    # successful hits (0 to PT_MAX_ROUNDS)
var _pt_score:            int   = 0    # accumulated points
var _pt_flash:            Color = Color.TRANSPARENT
var _pt_flash_timer:      float = 0.0
var _pt_total_timer:      float = PT_TOTAL_TIME   # counts down, never resets
var _pt_round_start_time: float = 0.0
var _pt_feedback_text:    String = ""
var _pt_feedback_timer:   float = 0.0

# ── Speed Burst ───────────────────────────────────────────────────────────────
var _sb_taps:      int   = 0
var _sb_time_left: float = SB_DURATION
var _sb_running:   bool  = false
var _sb_countdown: float = SB_COUNTDOWN_SEC
var _sb_particles: Array = []
var _sb_rings:     Array = []

# ── Orbit Challenge ───────────────────────────────────────────────────────────
var _oc_player_angle:     float = 0.0
var _oc_player_dir:       float = 1.0
var _oc_gates:            Array = []
var _oc_gate_spawn_timer: float = 0.8
var _oc_gates_passed:     int   = 0
var _oc_time_left:        float = OC_DURATION
var _oc_lives:            int   = 3
var _oc_finished:         bool  = false
var _oc_miss_flash:       float = 0.0
var _oc_score_flash:      float = 0.0
var _oc_dir_flash:        float = 0.0
var _oc_cached_ship:      Texture2D = null
var _oc_planet_pulse:     float = 0.0
var _oc_planet_rot:       float = 0.0

# ── Shared ────────────────────────────────────────────────────────────────────
var _result_gems:  int = 0
var _result_score: int = 0
var _particles:    Array = []
var _game_countdown: float = 0.0   # shared 3-second pre-game countdown for PT and OC

# ── Node refs ─────────────────────────────────────────────────────────────────
var _score_lbl:          Label
var _timer_lbl:          Label
var _tap_prompt_lbl:     Label
var _center_overlay_lbl: Label

# ─── SETUP ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stars()
	_show_select_screen()

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in 90:
		_stars.append({
			"pos":     Vector2(rng.randf_range(0, VIEWPORT_W), rng.randf_range(0, VIEWPORT_H)),
			"size":    rng.randf_range(0.7, 2.4),
			"alpha":   rng.randf_range(0.25, 0.9),
			"twinkle": rng.randf_range(0.4, 2.6),
			"phase":   rng.randf_range(0.0, TAU),
		})

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_score_lbl = null
	_timer_lbl = null
	_tap_prompt_lbl = null
	_center_overlay_lbl = null

# ─── SELECT SCREEN ────────────────────────────────────────────────────────────
func _show_select_screen() -> void:
	_state = MiniGameState.SELECT
	await get_tree().process_frame
	_clear_children()
	await get_tree().process_frame

	var hdr_bg := ColorRect.new()
	hdr_bg.size = Vector2(VIEWPORT_W, 124)
	hdr_bg.color = Color(0.04, 0.04, 0.16)
	hdr_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hdr_bg)

	var title := Label.new()
	title.position = Vector2(0, 28)
	title.size = Vector2(VIEWPORT_W, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "MINI GAMES"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)

	var sub := Label.new()
	sub.position = Vector2(0, 132)
	sub.size = Vector2(VIEWPORT_W, 32)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.text = "Complete challenges — earn Gems"
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	add_child(sub)

	var games := [
		{
			"type": GameType.PRECISION_TAP,
			"name": "PRECISION TAP",
			"desc": "Stop the needle in the green zone.\n5 rounds — single timer — tap fast!",
			"icon": "res://assets/icons/target.svg",
			"color": Color(0.05, 0.2, 0.35), # Dark Blue
			"gem_max": 5,
		},
		{
			"type": GameType.SPEED_BURST,
			"name": "SPEED BURST",
			"desc": "Tap as fast as possible in 6 seconds.\nPure reaction speed.",
			"icon": "res://assets/icons/speed.svg",
			"color": Color(0.4, 0.4, 0.05), # Dark Yellow
			"gem_max": 5,
		},
		{
			"type": GameType.ORBIT_CHALLENGE,
			"name": "ORBIT CHALLENGE",
			"desc": "TAP the screen to score a gate.\nUse ↺ button to flip orbit direction.",
			"icon": "res://assets/icons/spiral.svg",
			"color": Color(0.4, 0.1, 0.4),  # Dark Magenta
			"gem_max": 8,
		},
	]

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 172)
	scroll.size = Vector2(VIEWPORT_W, VIEWPORT_H - 268)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18)
	scroll.add_child(vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	for g in games:
		vbox.add_child(_make_game_card(g))

	var back_btn := Button.new()
	back_btn.position = Vector2(20, VIEWPORT_H - 90)
	back_btn.size = Vector2(160, 54)
	back_btn.text = "BACK"
	back_btn.add_theme_font_size_override("font_size", 24)
	_style_btn(back_btn, Color(0.6, 0.6, 0.9))
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _make_game_card(g: Dictionary) -> Control:
	var col: Color = g["color"]
	var card := Control.new()
	card.custom_minimum_size = Vector2(VIEWPORT_W, 240)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 0)
	panel.size = Vector2(VIEWPORT_W - 32, 232)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.18)
	style.border_color = Color(col.r, col.g, col.b, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	card.add_child(panel)

	var bar := ColorRect.new()
	bar.size = Vector2(6, 232)
	bar.color = col
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)

	var inner := Control.new()
	inner.position = Vector2(6, 0)
	inner.size = Vector2(VIEWPORT_W - 38, 232)
	panel.add_child(inner)

	var icon_r := TextureRect.new()
	icon_r.position = Vector2(14, 24)
	icon_r.size = Vector2(58, 58)
	var icon_path: String = g.get("icon", "")
	if icon_path != "":
		icon_r.texture = load(icon_path)
	icon_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_r.modulate = col
	inner.add_child(icon_r)

	var name_lbl := Label.new()
	name_lbl.position = Vector2(84, 24)
	name_lbl.size = Vector2(370, 40)
	name_lbl.text = g["name"]
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.position = Vector2(84, 70)
	desc_lbl.size = Vector2(370, 90)
	desc_lbl.text = g["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)

	var rwd_row := HBoxContainer.new()
	rwd_row.position = Vector2(84, 172)
	rwd_row.add_theme_constant_override("separation", 5)
	inner.add_child(rwd_row)

	var gem_icon := TextureRect.new()
	gem_icon.texture = load("res://assets/icons/gem.svg")
	gem_icon.custom_minimum_size = Vector2(20, 20)
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.modulate = Color(0.85, 0.5, 1.0)
	rwd_row.add_child(gem_icon)

	var gem_max: int = g["gem_max"]
	var rwd_txt := Label.new()
	rwd_txt.text = "Up to %d Gems" % gem_max
	rwd_txt.add_theme_font_size_override("font_size", 18)
	rwd_txt.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))
	rwd_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rwd_row.add_child(rwd_txt)

	var play_btn := Button.new()
	play_btn.position = Vector2(inner.size.x - 140, 80)
	play_btn.size = Vector2(124, 72)
	play_btn.text = "PLAY"
	play_btn.add_theme_font_size_override("font_size", 26)
	_style_btn(play_btn, col)
	var gtype: int = g["type"]
	play_btn.pressed.connect(func(): _start_game(gtype))
	inner.add_child(play_btn)

	return card

func _style_btn(btn: Button, col: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.22)
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("normal", s)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(col.r, col.g, col.b, 0.45)
	sh.border_color = col.lightened(0.2)
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("hover", sh)
	var sp := StyleBoxFlat.new()
	sp.bg_color = Color(col.r, col.g, col.b, 0.62)
	sp.border_color = col.lightened(0.35)
	sp.set_border_width_all(2)
	sp.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_color_override("font_color", Color.WHITE)

# ─── START / INIT ─────────────────────────────────────────────────────────────
func _start_game(type: int) -> void:
	_game_type = type as GameType
	_state = MiniGameState.PLAYING
	_game_countdown = 0.0
	_particles.clear()
	_clear_children()
	await get_tree().process_frame
	_build_game_hud()
	match _game_type:
		GameType.PRECISION_TAP:   _init_precision_tap()
		GameType.SPEED_BURST:     _init_speed_burst()
		GameType.ORBIT_CHALLENGE: _init_orbit_challenge()
	AudioManager.play_sfx("ui_click")

func _build_game_hud() -> void:
	var ac := _get_game_color()

	var hdr := ColorRect.new()
	hdr.size = Vector2(VIEWPORT_W, 136)
	hdr.color = Color(0.03, 0.03, 0.13, 0.97)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hdr)

	var accent_bar := ColorRect.new()
	accent_bar.position = Vector2(0, 133)
	accent_bar.size = Vector2(VIEWPORT_W, 3)
	accent_bar.color = ac
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent_bar)

	var mode_name_lbl := Label.new()
	mode_name_lbl.position = Vector2(0, 10)
	mode_name_lbl.size = Vector2(VIEWPORT_W, 26)
	mode_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_name_lbl.text = _get_game_name()
	mode_name_lbl.add_theme_font_size_override("font_size", 16)
	mode_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	mode_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mode_name_lbl)

	_score_lbl = Label.new()
	_score_lbl.position = Vector2(0, 30)
	_score_lbl.size = Vector2(VIEWPORT_W, 68)
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_lbl.text = "0"
	_score_lbl.add_theme_font_size_override("font_size", 60)
	_score_lbl.add_theme_color_override("font_color", Color.WHITE)
	_score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_score_lbl)

	_timer_lbl = Label.new()
	_timer_lbl.position = Vector2(0, 100)
	_timer_lbl.size = Vector2(VIEWPORT_W, 30)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.add_theme_font_size_override("font_size", 22)
	_timer_lbl.add_theme_color_override("font_color", Color.WHITE)
	_timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_lbl)

	# Bottom instruction bar
	var prompt_bar := ColorRect.new()
	prompt_bar.position = Vector2(0, VIEWPORT_H - 100)
	prompt_bar.size = Vector2(VIEWPORT_W, 100)
	prompt_bar.color = Color(0.03, 0.03, 0.13, 0.94)
	prompt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_bar)

	var prompt_top_line := ColorRect.new()
	prompt_top_line.position = Vector2(0, VIEWPORT_H - 101)
	prompt_top_line.size = Vector2(VIEWPORT_W, 2)
	prompt_top_line.color = Color(ac.r, ac.g, ac.b, 0.55)
	prompt_top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_top_line)

	_tap_prompt_lbl = Label.new()
	_tap_prompt_lbl.position = Vector2(16, VIEWPORT_H - 94)
	_tap_prompt_lbl.size = Vector2(VIEWPORT_W - 32, 88)
	_tap_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tap_prompt_lbl.add_theme_font_size_override("font_size", 22)
	_tap_prompt_lbl.add_theme_color_override("font_color", Color.WHITE)
	_tap_prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tap_prompt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tap_prompt_lbl)

	# Transparent tap zone — reliable mobile touch; added before UI buttons so
	# QUIT and ↺ sit on top in Z-order and consume their own input first.
	var tap_zone := Button.new()
	tap_zone.position = Vector2(0.0, 54.0)
	tap_zone.size = Vector2(VIEWPORT_W, VIEWPORT_H - 54.0 - 101.0)
	tap_zone.flat = true
	tap_zone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tap_zone.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	tap_zone.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	tap_zone.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tap_zone.focus_mode = Control.FOCUS_NONE
	tap_zone.mouse_default_cursor_shape = Control.CURSOR_ARROW
	tap_zone.pressed.connect(_on_tap_zone_pressed)
	add_child(tap_zone)

	# Reverse direction button — above the bottom bar
	var show_reverse := _game_type != GameType.SPEED_BURST
	if show_reverse:
		var rev_btn := Button.new()
		rev_btn.position = Vector2(VIEWPORT_W / 2.0 - 45, VIEWPORT_H - 156)
		rev_btn.size = Vector2(90, 50)
		rev_btn.text = "↺"
		rev_btn.add_theme_font_size_override("font_size", 28)
		_style_btn(rev_btn, ac)
		rev_btn.pressed.connect(_on_reverse)
		add_child(rev_btn)

	_center_overlay_lbl = Label.new()
	_center_overlay_lbl.position = Vector2(0, CENTER.y - 110.0)
	_center_overlay_lbl.size = Vector2(VIEWPORT_W, 220)
	_center_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_overlay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_overlay_lbl.add_theme_font_size_override("font_size", 160)
	_center_overlay_lbl.add_theme_color_override("font_color", Color.WHITE)
	_center_overlay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_overlay_lbl.visible = false
	add_child(_center_overlay_lbl)

	var quit_btn := Button.new()
	quit_btn.position = Vector2(8, 8)
	quit_btn.size = Vector2(76, 38)
	quit_btn.text = "QUIT"
	quit_btn.add_theme_font_size_override("font_size", 15)
	_style_btn(quit_btn, Color(0.85, 0.22, 0.22))
	quit_btn.pressed.connect(_show_select_screen)
	add_child(quit_btn)

func _on_reverse() -> void:
	match _game_type:
		GameType.PRECISION_TAP:
			_pt_needle_dir *= -1.0
			AudioManager.play_sfx("tap")
		GameType.ORBIT_CHALLENGE:
			_oc_player_dir *= -1.0
			_oc_dir_flash = 0.7
			AudioManager.play_sfx("tap")

func _on_tap_zone_pressed() -> void:
	if _state != MiniGameState.PLAYING:
		return
	match _game_type:
		GameType.PRECISION_TAP:
			_tap_precision()
		GameType.SPEED_BURST:
			if _sb_running:
				_tap_speed_burst()
		GameType.ORBIT_CHALLENGE:
			_tap_orbit_challenge()

func _get_game_color() -> Color:
	match _game_type:
		GameType.PRECISION_TAP:   return Color(0.2, 0.85, 1.0)
		GameType.SPEED_BURST:     return Color(1.0, 0.7, 0.1)
		GameType.ORBIT_CHALLENGE: return Color(0.8, 0.4, 1.0)
	return Color.WHITE

func _get_game_name() -> String:
	match _game_type:
		GameType.PRECISION_TAP:   return "PRECISION TAP"
		GameType.SPEED_BURST:     return "SPEED BURST"
		GameType.ORBIT_CHALLENGE: return "ORBIT CHALLENGE"
	return ""

# ── PRECISION TAP INIT ────────────────────────────────────────────────────────
func _init_precision_tap() -> void:
	_pt_round = 0
	_pt_hits = 0
	_pt_score = 0
	_pt_needle_angle = 0.0
	_pt_needle_dir = 1.0
	_pt_needle_speed = 2.5
	_pt_zone_size = deg_to_rad(30.0)
	_pt_target_angle = randf() * TAU
	_pt_total_timer = PT_TOTAL_TIME      # continuous — never resets
	_pt_round_start_time = PT_TOTAL_TIME
	_pt_flash = Color.TRANSPARENT
	_pt_flash_timer = 0.0
	_pt_feedback_timer = 0.0
	_game_countdown = 3.0
	if _score_lbl: _score_lbl.text = "0 / %d" % PT_MAX_ROUNDS
	if _timer_lbl: _timer_lbl.text = "%.0fs" % PT_TOTAL_TIME
	if _tap_prompt_lbl: _tap_prompt_lbl.text = "TAP when the needle hits the green zone!"
	if _center_overlay_lbl:
		_center_overlay_lbl.text = "3"
		_center_overlay_lbl.add_theme_color_override("font_color", _get_game_color())
		_center_overlay_lbl.visible = true

# ── SPEED BURST INIT ──────────────────────────────────────────────────────────
func _init_speed_burst() -> void:
	_sb_taps = 0
	_sb_running = false
	_sb_countdown = SB_COUNTDOWN_SEC
	_sb_time_left = SB_DURATION
	_sb_particles.clear()
	_sb_rings.clear()
	if _score_lbl: _score_lbl.text = "0"
	if _timer_lbl: _timer_lbl.text = "Get ready..."
	if _tap_prompt_lbl: _tap_prompt_lbl.text = "TAP AS FAST AS YOU CAN!"

# ── ORBIT CHALLENGE INIT ──────────────────────────────────────────────────────
func _init_orbit_challenge() -> void:
	_oc_player_angle = 0.0
	_oc_player_dir = 1.0
	_oc_gates.clear()
	_oc_gate_spawn_timer = 1.0
	_oc_gates_passed = 0
	_oc_time_left = OC_DURATION
	_oc_lives = 3
	_oc_finished = false
	_oc_miss_flash = 0.0
	_oc_score_flash = 0.0
	_oc_dir_flash = 0.0
	_oc_planet_pulse = 0.0
	_oc_planet_rot = 0.0
	_oc_cached_ship = load("res://assets/ships/ship_classic.svg")
	_game_countdown = 3.0
	if _score_lbl: _score_lbl.text = "0"
	if _timer_lbl: _timer_lbl.text = "%.0f s  —  3 lives" % OC_DURATION
	if _tap_prompt_lbl: _tap_prompt_lbl.text = "TAP near a gate to score it!  Use ↺ to flip direction."
	if _center_overlay_lbl:
		_center_overlay_lbl.text = "3"
		_center_overlay_lbl.add_theme_color_override("font_color", _get_game_color())
		_center_overlay_lbl.visible = true

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	for s in _stars:
		s["phase"] += s["twinkle"] * delta
		s["alpha"] = 0.3 + 0.7 * (0.5 + 0.5 * sin(s["phase"]))

	var pi := _particles.size() - 1
	while pi >= 0:
		var p: Dictionary = _particles[pi]
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.87
		p["life"] -= delta
		if p["life"] <= 0.0:
			_particles.remove_at(pi)
		pi -= 1

	if _state == MiniGameState.PLAYING:
		match _game_type:
			GameType.PRECISION_TAP:   _process_precision_tap(delta)
			GameType.SPEED_BURST:     _process_speed_burst(delta)
			GameType.ORBIT_CHALLENGE: _process_orbit_challenge(delta)

	queue_redraw()

# ── PRECISION TAP PROCESS ─────────────────────────────────────────────────────
func _process_precision_tap(delta: float) -> void:
	if _game_countdown > 0.0:
		_game_countdown -= delta
		var num := ceili(_game_countdown)
		if _center_overlay_lbl:
			if _game_countdown <= 0.0:
				_center_overlay_lbl.visible = false
			else:
				_center_overlay_lbl.text = str(num)
				_center_overlay_lbl.visible = true
		return

	# Needle rotates continuously — direction reversible
	_pt_needle_angle += _pt_needle_speed * _pt_needle_dir * delta
	_pt_needle_angle = wrapf(_pt_needle_angle, 0.0, TAU)

	if _pt_flash_timer > 0.0:
		_pt_flash_timer -= delta
	if _pt_feedback_timer > 0.0:
		_pt_feedback_timer -= delta

	# Single continuous timer — never resets
	_pt_total_timer -= delta

	# Update HUD: show total time remaining
	if _pt_feedback_timer <= 0.0:
		if is_instance_valid(_timer_lbl):
			_timer_lbl.text = "%.1fs" % maxf(_pt_total_timer, 0.0)

	# Overall time expired → finish with current hits
	if _pt_total_timer <= 0.0:
		_finish_precision_tap()
		return

# ── SPEED BURST PROCESS ───────────────────────────────────────────────────────
func _process_speed_burst(delta: float) -> void:
	if _sb_countdown > 0.0:
		_sb_countdown -= delta
		if _sb_countdown <= 0.0:
			_sb_running = true
			_sb_time_left = SB_DURATION
			if _score_lbl: _score_lbl.text = "0"
			if _timer_lbl: _timer_lbl.text = "6.0 s"
			if _tap_prompt_lbl: _tap_prompt_lbl.text = "TAP AS FAST AS YOU CAN!"
			if _center_overlay_lbl:
				_center_overlay_lbl.text = "GO!"
				_center_overlay_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
				_center_overlay_lbl.visible = true
			AudioManager.play_sfx("ring_pass")
		else:
			var cur_num: int = maxi(int(ceil(_sb_countdown)), 1)
			if _score_lbl: _score_lbl.text = ""
			if _timer_lbl: _timer_lbl.text = "GET READY..."
			if _center_overlay_lbl:
				_center_overlay_lbl.text = str(cur_num)
				_center_overlay_lbl.add_theme_color_override("font_color", _get_game_color())
				_center_overlay_lbl.visible = true
		return

	if _center_overlay_lbl and _center_overlay_lbl.visible:
		if _sb_time_left < SB_DURATION - 0.4:
			_center_overlay_lbl.visible = false

	if not _sb_running:
		return

	_sb_time_left -= delta
	if _sb_time_left <= 0.0:
		_sb_time_left = 0.0
		_sb_running = false
		_finish_speed_burst()
		return

	if _timer_lbl:
		_timer_lbl.text = "%.1f s remaining" % _sb_time_left

	var i := _sb_particles.size() - 1
	while i >= 0:
		var p: Dictionary = _sb_particles[i]
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.88
		p["life"] -= delta
		if p["life"] <= 0.0:
			_sb_particles.remove_at(i)
		i -= 1

	i = _sb_rings.size() - 1
	while i >= 0:
		var r: Dictionary = _sb_rings[i]
		r["r"] += 200.0 * delta
		r["alpha"] -= 2.8 * delta
		if r["alpha"] <= 0.0:
			_sb_rings.remove_at(i)
		i -= 1

# ── ORBIT CHALLENGE PROCESS ───────────────────────────────────────────────────
func _process_orbit_challenge(delta: float) -> void:
	if _oc_finished:
		return

	if _game_countdown > 0.0:
		_game_countdown -= delta
		var num := ceili(_game_countdown)
		if _center_overlay_lbl:
			if _game_countdown <= 0.0:
				_center_overlay_lbl.visible = false
			else:
				_center_overlay_lbl.text = str(num)
				_center_overlay_lbl.visible = true
		return

	_oc_player_angle += OC_SPEED_BASE * _oc_player_dir * delta
	_oc_time_left -= delta
	_oc_planet_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0015)
	_oc_planet_rot += delta * 0.25
	_oc_miss_flash  = maxf(0.0, _oc_miss_flash - delta * 2.5)
	_oc_score_flash = maxf(0.0, _oc_score_flash - delta * 3.0)
	_oc_dir_flash   = maxf(0.0, _oc_dir_flash - delta * 4.0)

	if _timer_lbl:
		var t := maxf(_oc_time_left, 0.0)
		_timer_lbl.text = "%.0f s  —  %d lives" % [t, _oc_lives]
		if _oc_time_left < 6.0:
			_timer_lbl.add_theme_color_override("font_color",
				Color(1.0, 0.35, 0.2, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)))
		else:
			_timer_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0, 0.9))

	_oc_gate_spawn_timer -= delta
	if _oc_gate_spawn_timer <= 0.0:
		_oc_gate_spawn_timer = randf_range(1.3, 2.4)
		_spawn_oc_gate()

	# Gates expire — miss life if not tapped in time
	var to_remove := []
	for gate in _oc_gates:
		gate["time_alive"] += delta
		if gate["time_alive"] >= OC_GATE_LIFETIME and not gate["hit"] and not gate["scored"]:
			gate["hit"] = true
			_oc_lives -= 1
			_oc_miss_flash = 0.6
			AudioManager.play_sfx("shield_hit")
			_spawn_burst(CENTER + Vector2(cos(gate["angle"]), sin(gate["angle"])) * OC_RADIUS,
				Color(1.0, 0.3, 0.2), 6)
		if gate["time_alive"] >= OC_GATE_LIFETIME + 0.4:
			to_remove.append(gate)

	for r in to_remove:
		_oc_gates.erase(r)

	if _oc_lives <= 0 or _oc_time_left <= 0.0:
		if not _oc_finished:
			_oc_finished = true
			_finish_orbit_challenge()

func _spawn_oc_gate() -> void:
	var player_a := wrapf(_oc_player_angle, 0.0, TAU)
	var offset := randf_range(deg_to_rad(40.0), deg_to_rad(180.0))
	if randf() > 0.5:
		offset = -offset
	var angle := wrapf(player_a + offset, 0.0, TAU)
	_oc_gates.append({
		"angle":      angle,
		"time_alive": 0.0,
		"scored":     false,
		"hit":        false,
	})

# ─── INPUT ────────────────────────────────────────────────────────────────────
# All game taps handled by tap_zone Button (_on_tap_zone_pressed).
# ↺ and QUIT buttons are added after tap_zone in the scene tree (higher Z),
# so they receive input before tap_zone and consume their own presses.

func _tap_precision() -> void:
	if _game_countdown > 0.0 or _pt_round >= PT_MAX_ROUNDS:
		return
	var diff := absf(wrapf(_pt_needle_angle - _pt_target_angle, -PI, PI))
	var half := _pt_zone_size * 0.5
	if diff <= half:
		var accuracy := 1.0 - (diff / half)
		var pts := int(accuracy * 100.0) + 50
		# Quick-tap bonus: extra points if tap comes fast after round started
		var time_since_start := _pt_round_start_time - _pt_total_timer
		if time_since_start < 1.0:
			pts += 30
			_pt_feedback_text = "QUICK! +%d" % pts if accuracy > 0.5 else "OK +%d" % pts
		elif accuracy > 0.8:
			_pt_feedback_text = "PERFECT! +%d" % pts
		elif accuracy > 0.45:
			_pt_feedback_text = "GREAT! +%d" % pts
		else:
			_pt_feedback_text = "OK +%d" % pts
		_pt_score += pts
		_pt_hits += 1
		_pt_flash = Color(0.2, 1.0, 0.4)
		_pt_flash_timer = 0.45
		_pt_feedback_timer = 0.9
		if is_instance_valid(_timer_lbl): _timer_lbl.text = _pt_feedback_text
		AudioManager.play_sfx("ring_pass")
		_spawn_burst(CENTER, Color(0.2, 1.0, 0.4), 10)
	else:
		_pt_flash = Color(1.0, 0.3, 0.2)
		_pt_flash_timer = 0.45
		_pt_feedback_text = "MISS!"
		_pt_feedback_timer = 0.9
		if is_instance_valid(_timer_lbl): _timer_lbl.text = "MISS!"
		AudioManager.play_sfx("shield_hit")
	_advance_pt_round()

func _advance_pt_round() -> void:
	_pt_round += 1
	if _pt_round >= PT_MAX_ROUNDS:
		_finish_precision_tap()
		return
	_pt_target_angle  = randf() * TAU
	_pt_needle_speed  = 2.5 + _pt_round * 0.55
	_pt_zone_size     = maxf(deg_to_rad(30.0) - _pt_round * deg_to_rad(4.0), deg_to_rad(11.0))
	_pt_needle_angle  = 0.0
	_pt_round_start_time = _pt_total_timer
	_pt_flash_timer   = 0.0
	# Update hits display
	if is_instance_valid(_score_lbl):
		_score_lbl.text = "%d / %d" % [_pt_hits, PT_MAX_ROUNDS]

func _tap_speed_burst() -> void:
	_sb_taps += 1
	AudioManager.play_sfx("tap")
	if is_instance_valid(_score_lbl): _score_lbl.text = str(_sb_taps)

	_sb_rings.append({"r": 16.0, "alpha": 1.0, "col": Color.from_hsv(randf(), 0.7, 1.0)})

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in 5:
		var angle := rng.randf() * TAU
		_sb_particles.append({
			"pos": CENTER,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(35.0, 110.0),
			"life": 0.35, "max_life": 0.35,
			"col": Color.from_hsv(rng.randf(), 0.8, 1.0),
		})

func _tap_orbit_challenge() -> void:
	if _oc_finished or _game_countdown > 0.0:
		return

	# Screen tap = score a nearby gate only. Use ↺ button to flip direction.
	var player_a := wrapf(_oc_player_angle, 0.0, TAU)
	for gate in _oc_gates:
		if gate["scored"] or gate["hit"]:
			continue
		var diff := absf(wrapf(player_a - gate["angle"], -PI, PI))
		if diff < OC_SCORE_ANGLE:
			gate["scored"] = true
			_oc_gates_passed += 1
			_oc_score_flash = 0.45
			AudioManager.play_sfx("coin")
			_spawn_burst(CENTER + Vector2(cos(gate["angle"]), sin(gate["angle"])) * OC_RADIUS,
				Color(0.2, 1.0, 0.4), 8)
			if is_instance_valid(_score_lbl): _score_lbl.text = str(_oc_gates_passed)
			break

# ─── FINISH ───────────────────────────────────────────────────────────────────
func _finish_precision_tap() -> void:
	# Reward based on hits (0-5)
	var gems := 0
	if _pt_hits >= 5:   gems = 5
	elif _pt_hits >= 4: gems = 3
	elif _pt_hits >= 2: gems = 1
	_show_result(_pt_hits, gems, "PRECISION TAP", Color(0.2, 0.85, 1.0))

func _finish_speed_burst() -> void:
	var gems := 0
	if _sb_taps >= 60:   gems = 5
	elif _sb_taps >= 40: gems = 3
	elif _sb_taps >= 20: gems = 1
	_show_result(_sb_taps, gems, "SPEED BURST", Color(1.0, 0.7, 0.1))

func _finish_orbit_challenge() -> void:
	var gems := 0
	if _oc_gates_passed >= 10: gems = 8
	elif _oc_gates_passed >= 6: gems = 5
	elif _oc_gates_passed >= 3: gems = 2
	_show_result(_oc_gates_passed, gems, "ORBIT CHALLENGE", Color(0.8, 0.4, 1.0))

# ─── RESULT SCREEN ────────────────────────────────────────────────────────────
func _show_result(score: int, gems: int, game_name: String, col: Color) -> void:
	_state = MiniGameState.RESULT

	# Hide HUD labels so they don't bleed through the result panel
	if is_instance_valid(_score_lbl):     _score_lbl.visible = false
	if is_instance_valid(_timer_lbl):     _timer_lbl.visible = false
	if is_instance_valid(_tap_prompt_lbl): _tap_prompt_lbl.visible = false

	_result_score = score
	_result_gems  = gems
	if gems > 0:
		SaveManager.add_gems(gems)
		AudioManager.play_sfx("reward")
	else:
		AudioManager.play_sfx("game_over")

	var stars := 0
	if gems >= 5:   stars = 3
	elif gems >= 2: stars = 2
	elif gems >= 1: stars = 1

	var panel := PanelContainer.new()
	panel.position = Vector2(60, 300)
	panel.size = Vector2(600, 460)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.18, 0.97)
	style.border_color = Color(col.r, col.g, col.b, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var h1 := Label.new()
	h1.text = game_name
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h1.add_theme_font_size_override("font_size", 22)
	h1.add_theme_color_override("font_color", Color.WHITE)
	h1.add_theme_constant_override("margin_top", 28)
	vbox.add_child(h1)

	# Show score label — for PT it's "X / 5 hits"
	var score_txt := str(score)
	if game_name == "PRECISION TAP":
		score_txt = "%d / %d" % [score, PT_MAX_ROUNDS]
	var score_lbl := Label.new()
	score_lbl.text = score_txt
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 64)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(score_lbl)

	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 6)
	vbox.add_child(star_row)
	for si in 3:
		var st := TextureRect.new()
		st.texture = load("res://assets/icons/star.svg")
		st.custom_minimum_size = Vector2(36, 36)
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.modulate = Color(1.0, 0.9, 0.2) if si < stars else Color(1, 1, 1, 0.18)
		star_row.add_child(st)

	var gem_row := HBoxContainer.new()
	gem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_row.add_theme_constant_override("separation", 6)
	vbox.add_child(gem_row)
	if gems > 0:
		var gem_icon := TextureRect.new()
		gem_icon.texture = load("res://assets/icons/gem.svg")
		gem_icon.custom_minimum_size = Vector2(32, 32)
		gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gem_icon.modulate = Color(0.85, 0.5, 1.0)
		gem_row.add_child(gem_icon)
		var gem_lbl := Label.new()
		gem_lbl.text = " +%d Gems!" % gems
		gem_lbl.add_theme_font_size_override("font_size", 32)
		gem_lbl.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))
		gem_row.add_child(gem_lbl)
	else:
		var gem_lbl := Label.new()
		gem_lbl.text = "No gems — keep practicing!"
		gem_lbl.add_theme_font_size_override("font_size", 22)
		gem_lbl.add_theme_color_override("font_color", Color.WHITE)
		gem_row.add_child(gem_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var retry_btn := Button.new()
	retry_btn.text = "RETRY"
	retry_btn.custom_minimum_size = Vector2(160, 56)
	retry_btn.add_theme_font_size_override("font_size", 22)
	_style_btn(retry_btn, col)
	retry_btn.pressed.connect(_on_retry)
	btn_row.add_child(retry_btn)

	var select_btn := Button.new()
	select_btn.text = "GAMES"
	select_btn.custom_minimum_size = Vector2(160, 56)
	select_btn.add_theme_font_size_override("font_size", 22)
	_style_btn(select_btn, Color(0.6, 0.6, 0.9))
	select_btn.pressed.connect(_show_select_screen)
	btn_row.add_child(select_btn)

	panel.scale = Vector2(0.82, 0.82)
	panel.pivot_offset = Vector2(300, 230)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)

func _on_retry() -> void:
	_start_game(_game_type)

func _on_back() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ─── PARTICLES ────────────────────────────────────────────────────────────────
func _spawn_burst(pos: Vector2, col: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in count:
		var angle := rng.randf() * TAU
		_particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(40.0, 130.0),
			"life": rng.randf_range(0.3, 0.55),
			"max_life": 0.55,
			"col": col,
			"size": rng.randf_range(3.0, 6.5),
		})

# ─── DRAW ─────────────────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.03, 0.03, 0.12))
	var bg_inner := Color(0.05, 0.05, 0.17)
	var bg_outer := Color(0.02, 0.02, 0.08)
	for i in range(20, -1, -1):
		var t := float(i) / 20.0
		var r := VIEWPORT_H * 0.90 * t
		draw_circle(CENTER, r, bg_inner.lerp(bg_outer, 1.0 - t))

	for s in _stars:
		draw_circle(s["pos"], s["size"], Color(s["alpha"], s["alpha"], s["alpha"] * 0.92))

	if _state != MiniGameState.PLAYING:
		return

	for p in _particles:
		var t: float = p["life"] / p["max_life"]
		var col: Color = p["col"]
		col.a = t * t
		draw_circle(p["pos"], p["size"] * t, col)

	match _game_type:
		GameType.PRECISION_TAP:   _draw_precision_tap()
		GameType.SPEED_BURST:     _draw_speed_burst()
		GameType.ORBIT_CHALLENGE: _draw_orbit_challenge()

func _draw_precision_tap() -> void:
	var r := 210.0
	draw_arc(CENTER, r, 0, TAU, 96, Color(1, 1, 1, 0.07), 22.0)

	# Continuous game timer arc (never resets)
	var t_frac := clampf(_pt_total_timer / PT_TOTAL_TIME, 0.0, 1.0)
	var timer_col := Color(0.2, 1.0, 0.4, 0.55).lerp(Color(1.0, 0.3, 0.2, 0.7), 1.0 - t_frac)
	draw_arc(CENTER, r + 18.0, -PI * 0.5, -PI * 0.5 + TAU * t_frac, 64, timer_col, 8.0)

	# Safe zone (glowing green arc)
	var zone_start := _pt_target_angle - _pt_zone_size * 0.5
	var zone_pulse := 0.55 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
	draw_arc(CENTER, r, zone_start, zone_start + _pt_zone_size, 24,
		Color(0.2, 1.0, 0.4, 0.25), 30.0)
	draw_arc(CENTER, r, zone_start, zone_start + _pt_zone_size, 24,
		Color(0.2, 1.0, 0.4, zone_pulse), 22.0)

	# Flash ring on tap result
	if _pt_flash_timer > 0.0:
		var fa := (_pt_flash_timer / 0.45) * 0.45
		draw_circle(CENTER, r + 38.0, Color(_pt_flash.r, _pt_flash.g, _pt_flash.b, fa))
		draw_arc(CENTER, r, 0, TAU, 64,
			Color(_pt_flash.r, _pt_flash.g, _pt_flash.b, fa * 1.2), 24.0)

	# Needle
	var na := _pt_needle_angle
	var nx := CENTER + Vector2(cos(na), sin(na)) * r
	draw_line(CENTER, nx, Color(1.0, 0.35, 0.2, 0.85), 5.0, true)
	draw_circle(nx, 13.0, Color(1.0, 0.4, 0.2))
	draw_circle(nx, 8.0, Color(1.0, 0.8, 0.6))

	draw_circle(CENTER, 9.0, Color(1, 1, 1, 0.25))
	draw_circle(CENTER, 5.0, Color(1, 1, 1, 0.5))

	# Hit dots at bottom (filled = hit, empty = miss/pending)
	var dot_y := VIEWPORT_H - 72.0
	var dot_gap := 28.0
	var total_w := (PT_MAX_ROUNDS - 1) * dot_gap
	var start_x := (VIEWPORT_W - total_w) * 0.5
	for di in PT_MAX_ROUNDS:
		var dx := start_x + di * dot_gap
		if di < _pt_round:
			# Completed round
			if di < _pt_hits:
				draw_circle(Vector2(dx, dot_y), 9.0, Color(0.2, 1.0, 0.4))
			else:
				draw_circle(Vector2(dx, dot_y), 9.0, Color(1.0, 0.3, 0.2))
		elif di == _pt_round:
			# Current round — pulsing
			var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
			draw_arc(Vector2(dx, dot_y), 9.0, 0, TAU, 16, Color(1, 1, 0.3, pulse), 2.5)
		else:
			draw_arc(Vector2(dx, dot_y), 9.0, 0, TAU, 16, Color(1, 1, 1, 0.25), 2.5)

func _draw_speed_burst() -> void:
	var tap_scale := minf(float(_sb_taps) / 60.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)

	var time_left_frac := clampf(_sb_time_left / SB_DURATION, 0.0, 1.0)
	draw_arc(CENTER, 155, 0, TAU, 96, Color(1.0, 0.7, 0.1, 0.12), 20.0)
	if _sb_running:
		var arc_col := Color(1.0, 0.7, 0.1, 0.65)
		if time_left_frac < 0.3:
			arc_col = Color(1.0, 0.3, 0.2, 0.8)
		draw_arc(CENTER, 155, -PI * 0.5, -PI * 0.5 + TAU * time_left_frac, 96, arc_col, 20.0)

	draw_circle(CENTER, 24.0 + tap_scale * 88.0, Color(1.0, 0.8, 0.2, 0.1 * pulse))
	draw_circle(CENTER, 20.0 + tap_scale * 50.0, Color(1.0, 0.8, 0.2, 0.22))
	draw_circle(CENTER, 18.0, Color(1.0, 0.85, 0.3))

	for rg in _sb_rings:
		var col: Color = rg["col"]
		col.a = rg["alpha"] * 0.85
		draw_arc(CENTER, rg["r"], 0, TAU, 32, col, maxf(4.0 - rg["r"] * 0.015, 1.0))

	for p in _sb_particles:
		var a: float = p["life"] / p["max_life"]
		var pc: Color = p["col"]
		pc.a = a * a
		draw_circle(p["pos"], 5.0 * a, pc)

	if _sb_countdown > 0.0:
		var cn := int(ceil(_sb_countdown))
		var cnt_alpha := clampf(_sb_countdown - float(cn - 1), 0.0, 1.0)
		var cnt_scale := 1.0 + (1.0 - cnt_alpha) * 0.5
		draw_circle(CENTER, 50.0 * cnt_scale, Color(1.0, 0.7, 0.1, cnt_alpha * 0.3))
		draw_arc(CENTER, 55.0 * cnt_scale, 0, TAU, 32,
			Color(1.0, 0.7, 0.1, cnt_alpha * 0.7), 5.0)

func _draw_orbit_challenge() -> void:
	var planet_col := Color(0.15, 0.45, 0.9)

	if _oc_miss_flash > 0.0:
		draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H),
			Color(1.0, 0.2, 0.1, _oc_miss_flash * 0.28))
	if _oc_score_flash > 0.0:
		draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H),
			Color(1.0, 1.0, 1.0, _oc_score_flash * 0.12))

	var glow_r := OC_PLANET_R + 14.0 + _oc_planet_pulse * 5.0
	draw_circle(CENTER, glow_r, Color(planet_col.r, planet_col.g, planet_col.b, 0.12))
	draw_circle(CENTER, glow_r * 0.82, Color(planet_col.r, planet_col.g, planet_col.b, 0.18))
	draw_circle(CENTER, OC_PLANET_R, planet_col.darkened(0.3))
	draw_circle(CENTER, OC_PLANET_R * 0.93, planet_col)

	for li in 2:
		var y_off := (float(li) * 0.5 - 0.2) * OC_PLANET_R * 0.7
		var lat_r := sqrt(maxf(OC_PLANET_R * OC_PLANET_R - y_off * y_off, 0.0)) * 0.88
		draw_arc(CENTER + Vector2(0, y_off), lat_r, 0, TAU, 32, Color(1, 1, 1, 0.1), 1.2)

	draw_arc(CENTER, OC_PLANET_R + 10.0, _oc_planet_rot,
		_oc_planet_rot + deg_to_rad(210.0), 32,
		Color(planet_col.lightened(0.5).r, planet_col.lightened(0.5).g,
			planet_col.lightened(0.5).b, 0.45), 3.5)
	draw_circle(CENTER + Vector2(-OC_PLANET_R * 0.3, -OC_PLANET_R * 0.32),
		OC_PLANET_R * 0.2, Color(1, 1, 1, 0.22))

	# Orbit path
	draw_arc(CENTER, OC_RADIUS, 0, TAU, 128, Color(1, 1, 1, 0.09), 3.0)
	draw_arc(CENTER, OC_RADIUS - 22.0, 0, TAU, 64, Color(1.0, 0.3, 0.2, 0.08), 8.0)
	draw_arc(CENTER, OC_RADIUS + 22.0, 0, TAU, 64, Color(1.0, 0.3, 0.2, 0.06), 8.0)

	# Gates
	for gate in _oc_gates:
		var ga: float   = gate["angle"]
		var age_frac    := clampf(gate["time_alive"] / OC_GATE_LIFETIME, 0.0, 1.0)
		var gate_col: Color
		if gate["hit"]:
			gate_col = Color(1.0, 0.3, 0.2, 0.3)
		elif gate["scored"]:
			gate_col = Color(1.0, 1.0, 1.0, 0.25)
		else:
			gate_col = Color(0.2, 1.0, 0.4, 0.85).lerp(Color(1.0, 0.3, 0.2, 0.95), age_frac)
			if age_frac > 0.7:
				var urgency_pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
				gate_col.a *= urgency_pulse

		var half := OC_SCORE_ANGLE
		draw_arc(CENTER, OC_RADIUS, ga - half, ga + half, 16,
			Color(gate_col.r, gate_col.g, gate_col.b, gate_col.a * 0.25), 28.0)
		draw_arc(CENTER, OC_RADIUS, ga - half, ga + half, 16, gate_col, 14.0)
		var gp := CENTER + Vector2(cos(ga), sin(ga)) * OC_RADIUS
		draw_circle(gp, 8.0, Color(gate_col.r, gate_col.g, gate_col.b, gate_col.a))

	# Direction indicator arrow
	var dir_col := Color(0.8, 0.4, 1.0, 0.55)
	if _oc_dir_flash > 0.0:
		dir_col = Color(1.0, 1.0, 1.0, _oc_dir_flash * 0.9)
	var dir_arc_len := deg_to_rad(55.0) * _oc_player_dir
	var dir_start   := _oc_player_angle + _oc_player_dir * deg_to_rad(40.0)
	draw_arc(CENTER, OC_RADIUS + 36.0, dir_start,
		dir_start + dir_arc_len, 16, dir_col, 4.5)
	var arrow_end := dir_start + dir_arc_len
	var ae_dir    := Vector2(cos(arrow_end), sin(arrow_end))
	var ae_perp   := Vector2(-ae_dir.y, ae_dir.x) * _oc_player_dir
	var ae_center := CENTER + ae_dir * (OC_RADIUS + 36.0)
	var arrow_pts := PackedVector2Array([
		ae_center + ae_dir * 10.0,
		ae_center + ae_perp * 7.0 - ae_dir * 6.0,
		ae_center - ae_perp * 7.0 - ae_dir * 6.0,
	])
	draw_polygon(arrow_pts, PackedColorArray([dir_col, dir_col, dir_col]))

	# Player ship
	var pp := CENTER + Vector2(cos(_oc_player_angle), sin(_oc_player_angle)) * OC_RADIUS
	var ship_col := Color(1.0, 1.0, 1.0)
	draw_circle(pp, 18.0, Color(0.8, 0.4, 1.0, 0.25))
	draw_circle(pp, 12.0, Color(0.8, 0.4, 1.0, 0.15))
	if _oc_cached_ship:
		var draw_size := Vector2(28.0, 28.0)
		var ship_rot  := _oc_player_angle + (PI * 0.5 if _oc_player_dir > 0.0 else -PI * 0.5)
		draw_set_transform(pp, ship_rot, Vector2.ONE)
		draw_texture_rect(_oc_cached_ship, Rect2(-draw_size * 0.5, draw_size), false, ship_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(pp, 10.0, Color(0.8, 0.4, 1.0))

	var engine_dir := Vector2(cos(_oc_player_angle), sin(_oc_player_angle)) * _oc_player_dir * -1.0
	var engine_pos := pp + engine_dir * 9.0
	draw_circle(engine_pos, 4.5 + 2.0 * sin(Time.get_ticks_msec() * 0.022),
		Color(1.0, 0.6, 0.2, 0.8))

	# Lives display
	var life_y := VIEWPORT_H - 58.0
	for li in 3:
		var lx := VIEWPORT_W - 60.0 - li * 32.0
		if li < _oc_lives:
			var hcol := Color(1.0, 0.25, 0.35)
			draw_circle(Vector2(lx - 4.0, life_y - 2.0), 7.0, hcol)
			draw_circle(Vector2(lx + 4.0, life_y - 2.0), 7.0, hcol)
			var tri_pts := PackedVector2Array([
				Vector2(lx - 11.0, life_y - 1.0),
				Vector2(lx + 11.0, life_y - 1.0),
				Vector2(lx, life_y + 9.0),
			])
			draw_polygon(tri_pts, PackedColorArray([hcol, hcol, hcol]))
		else:
			draw_arc(Vector2(lx, life_y), 8.0, 0, TAU, 16, Color(1, 1, 1, 0.2), 2.0)

	if _oc_lives == 1 and not _oc_finished:
		var warn := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.007)
		draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(1.0, 0.1, 0.1, warn * 0.06))
