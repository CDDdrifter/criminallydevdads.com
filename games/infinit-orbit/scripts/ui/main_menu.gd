# main_menu.gd — Main menu scene (attach to Control root)
# Builds the animated start screen with all navigation options.
extends Control

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const VIEWPORT_W := 720.0
const VIEWPORT_H := 1280.0
const CENTER     := Vector2(360.0, 400.0)   # Demo planet position in menu

# ─── LIVE STATE ───────────────────────────────────────────────────────────────
var _planet_pulse: float = 0.0
var _planet_rotation: float = 0.0
var _rings_angle: Array = [0.0, 1.2, 2.8]
var _stars: Array = []
var _bg_inner  := Color(0.04, 0.04, 0.15)
var _bg_outer  := Color(0.02, 0.02, 0.08)
var _ring_col  := Color(0.20, 0.85, 1.00)
var _demo_player_angle: float = 0.0
var _notification_label: Label
var _notification_timer: float = 0.0
var _daily_dot: Control  # Red dot indicator

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_stars()
	_build_ui()
	_check_daily_notification()
	AudioManager.play_music_track(0)

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 100:
		_stars.append({
			"pos": Vector2(rng.randf_range(0, VIEWPORT_W), rng.randf_range(0, VIEWPORT_H)),
			"size": rng.randf_range(0.8, 2.4),
			"alpha": rng.randf_range(0.3, 1.0),
			"twinkle": rng.randf_range(0.5, 2.5),
			"phase": rng.randf_range(0.0, TAU),
		})

func _build_ui() -> void:
	# ── Best score ──
	var best_label := Label.new()
	best_label.position = Vector2(0, 56)
	best_label.size = Vector2(VIEWPORT_W, 40)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.text = "BEST  %d" % SaveManager.get_best_score()
	best_label.add_theme_font_size_override("font_size", 24)
	best_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(best_label)

	# ── Title ──
	var title := Label.new()
	title.position = Vector2(0, 680)
	title.size = Vector2(VIEWPORT_W, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "INFINITE\nORBIT"
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)

	# Animate title scale in
	title.scale = Vector2(0.5, 0.5)
	title.pivot_offset = Vector2(VIEWPORT_W / 2.0, 55.0)
	var tw := create_tween()
	tw.tween_property(title, "scale", Vector2(1.0, 1.0), 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# ── Tagline ──
	var tag := Label.new()
	tag.position = Vector2(0, 800)
	tag.size = Vector2(VIEWPORT_W, 40)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.text = "Orbit. Dodge. Ascend."
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	add_child(tag)

	# ── Play button ──
	var play_btn := _make_btn("PLAY", Vector2(VIEWPORT_W / 2.0 - 130, 870), Vector2(260, 72),
		Color(0.2, 0.85, 1.0), 36)
	play_btn.pressed.connect(_on_play)
	add_child(play_btn)

	# ── Bottom row buttons ──
	var btn_data := [
		["SHOP",    Color(1.0, 0.8, 0.2), _on_shop],
		["SKINS",   Color(0.8, 0.4, 1.0), _on_skins],
		["REWARDS", Color(0.2, 1.0, 0.5), _on_rewards],
	]
	var row_y := 970.0
	var btn_w := 190.0
	var spacing := 14.0
	var row_start := (VIEWPORT_W - (btn_data.size() * btn_w + (btn_data.size() - 1) * spacing)) / 2.0
	for i in btn_data.size():
		var bd: Array = btn_data[i]
		var bx := row_start + i * (btn_w + spacing)
		var btn := _make_btn(bd[0] as String, Vector2(bx, row_y), Vector2(btn_w, 58),
			bd[1] as Color, 22)
		btn.pressed.connect(bd[2] as Callable)
		add_child(btn)

	# ── Settings & Mini-game buttons ──
	var settings_btn := Button.new()
	settings_btn.position = Vector2(VIEWPORT_W - 80, 56)
	settings_btn.size = Vector2(54, 54)
	var settings_icon := TextureRect.new()
	settings_icon.texture = load("res://assets/icons/settings.svg")
	settings_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	settings_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	settings_icon.size = Vector2(34, 34)
	settings_icon.position = Vector2(10, 10)
	settings_btn.add_child(settings_icon)
	_style_btn(settings_btn, Color(0.6, 0.6, 0.9))
	settings_btn.pressed.connect(_on_settings)
	add_child(settings_btn)

	var mg_btn := _make_btn("MINI GAMES", Vector2(VIEWPORT_W / 2.0 - 110, 1055), Vector2(220, 52),
		Color(0.85, 0.5, 1.0), 20)
	mg_btn.pressed.connect(_on_mini_game)
	add_child(mg_btn)

	var how_btn := _make_btn("? HOW TO PLAY", Vector2(VIEWPORT_W / 2.0 - 96, 1122), Vector2(192, 44),
		Color(0.55, 0.7, 1.0), 17)
	how_btn.pressed.connect(_show_how_to_play)
	add_child(how_btn)


	# ── Coins / Gems display ──
	var currency_panel := _make_currency_panel()
	add_child(currency_panel)

	# ── Daily reward dot ──
	if SaveManager.can_claim_daily():
		_daily_dot = _make_dot(Color(1.0, 0.3, 0.2))
		_daily_dot.position = Vector2(row_start + 2 * (btn_w + spacing) + btn_w - 12, row_y - 10)
		add_child(_daily_dot)

	# ── Notification label ──
	_notification_label = Label.new()
	_notification_label.position = Vector2(0, VIEWPORT_H - 80)
	_notification_label.size = Vector2(VIEWPORT_W, 50)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.add_theme_font_size_override("font_size", 20)
	_notification_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	_notification_label.modulate.a = 0.0
	add_child(_notification_label)

	# Crate countdown label
	var crate_timer_lbl := Label.new()
	crate_timer_lbl.name = "CrateTimerLabel"
	crate_timer_lbl.position = Vector2(0, VIEWPORT_H - 48)
	crate_timer_lbl.size = Vector2(VIEWPORT_W, 40)
	crate_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_timer_lbl.add_theme_font_size_override("font_size", 16)
	crate_timer_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	add_child(crate_timer_lbl)

func _make_btn(label_text: String, pos: Vector2, sz: Vector2,
		col: Color, font_size: int) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size = sz
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", font_size)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(col.r, col.g, col.b, 0.18)
	normal_style.border_color = col
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(10)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(col.r, col.g, col.b, 0.35)
	hover_style.border_color = col.lightened(0.3)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(10)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(col.r, col.g, col.b, 0.55)
	pressed_style.border_color = col
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	return btn

func _style_btn(btn: Button, col: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.18)
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", s)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(col.r, col.g, col.b, 0.35)
	sh.border_color = col.lightened(0.3)
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _make_currency_panel() -> Control:
	var panel := Control.new()
	panel.position = Vector2(20, 56)
	panel.size = Vector2(220, 50)

	var hbox := HBoxContainer.new()
	hbox.size = Vector2(220, 50)
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)

	# Coins
	var coin_box := HBoxContainer.new()
	hbox.add_child(coin_box)
	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/icons/coin.svg")
	coin_icon.custom_minimum_size = Vector2(24, 24)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = Color(1.0, 0.9, 0.2)
	coin_box.add_child(coin_icon)
	var coin_lbl := Label.new()
	coin_lbl.text = " %d" % SaveManager.get_coins()
	coin_lbl.add_theme_font_size_override("font_size", 24)
	coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	coin_box.add_child(coin_lbl)

	# Gems
	var gem_box := HBoxContainer.new()
	hbox.add_child(gem_box)
	var gem_icon := TextureRect.new()
	gem_icon.texture = load("res://assets/icons/gem.svg")
	gem_icon.custom_minimum_size = Vector2(24, 24)
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.modulate = Color(0.6, 0.9, 1.0)
	gem_box.add_child(gem_icon)
	var gem_lbl := Label.new()
	gem_lbl.text = " %d" % SaveManager.get_gems()
	gem_lbl.add_theme_font_size_override("font_size", 24)
	gem_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	gem_box.add_child(gem_lbl)

	SaveManager.coins_updated.connect(func(c: int):
		if is_instance_valid(coin_lbl): coin_lbl.text = " %d" % c)
	SaveManager.gems_updated.connect(func(g: int):
		if is_instance_valid(gem_lbl): gem_lbl.text = " %d" % g)
	return panel

func _make_dot(col: Color) -> Control:
	var dot := Control.new()
	dot.size = Vector2(16, 16)
	dot.draw.connect(func():
		dot.draw_circle(Vector2(8, 8), 7, col)
		dot.draw_arc(Vector2(8, 8), 7, 0, TAU, 24, Color.WHITE * Color(1,1,1,0.4), 2)
	)
	return dot

func _check_daily_notification() -> void:
	if SaveManager.can_claim_daily():
		_show_notification("Daily reward ready!")

func _show_notification(text: String) -> void:
	if _notification_label == null:
		return
	_notification_label.text = text
	_notification_timer = 3.0
	var tw := create_tween()
	tw.tween_property(_notification_label, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.4)
	tw.tween_property(_notification_label, "modulate:a", 0.0, 0.3)

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_planet_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0012)
	_planet_rotation += delta * 0.25
	for i in _rings_angle.size():
		_rings_angle[i] += delta * (0.8 + i * 0.3)
	for s in _stars:
		s["phase"] += s["twinkle"] * delta
		s["alpha"] = 0.3 + 0.7 * (0.5 + 0.5 * sin(s["phase"]))
	_demo_player_angle += delta * 1.4
	# Update crate countdown
	var crate_lbl := get_node_or_null("CrateTimerLabel")
	if crate_lbl:
		var remaining := SaveManager.get_crate_cooldown_remaining()
		if remaining > 0:
			var h := remaining / 3600
			var m := (remaining % 3600) / 60
			var s := remaining % 60
			(crate_lbl as Label).text = "Crate in %02d:%02d:%02d" % [h, m, s]
		else:
			(crate_lbl as Label).text = "Crate ready! (Rewards menu)"
	queue_redraw()

func _draw() -> void:
	_draw_bg()
	_draw_stars()
	_draw_demo_planet()
	_draw_demo_player()

func _draw_bg() -> void:
	var steps := 14
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), _bg_outer)
	for i in steps:
		var t := float(i) / steps
		var r := VIEWPORT_H * 0.75 * (1.0 - t)
		var col := _bg_inner.lerp(_bg_outer, t)
		draw_circle(CENTER, r, col)

func _draw_stars() -> void:
	for s in _stars:
		draw_circle(s["pos"], s["size"], Color(s["alpha"], s["alpha"], s["alpha"] * 0.95))

func _draw_demo_planet() -> void:
	var pc := Color(0.1, 0.4, 0.8)
	var pr := 55.0
	draw_circle(CENTER, pr + 12.0 + _planet_pulse * 5.0, Color(pc.r, pc.g, pc.b, 0.1))
	draw_circle(CENTER, pr, pc.darkened(0.3))
	draw_circle(CENTER, pr * 0.95, pc)
	
	# Small continents
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 4:
		var a := i * TAU / 4.0
		var p := CENTER + Vector2(cos(a), sin(a)) * 20.0
		draw_circle(p, 14.0, pc.lightened(0.2).darkened(0.1))

	draw_arc(CENTER, pr + 16, _planet_rings_angle_val(), _planet_rings_angle_val() + deg_to_rad(180), 36,
		Color(0.5, 0.8, 1.0, 0.45), 4.0)
	draw_circle(CENTER + Vector2(-pr * 0.28, -pr * 0.28), pr * 0.18, Color(1, 1, 1, 0.18))
	# Decorative orbit rings
	for i in 3:
		var r := 90.0 + i * 38.0
		var start: float = _rings_angle[i]
		draw_arc(CENTER, r, start, start + deg_to_rad(270.0), 60,
			Color(_ring_col.r, _ring_col.g, _ring_col.b, 0.18 - i * 0.04), 5.0 - i * 0.5)

func _planet_rings_angle_val() -> float:
	return _planet_rotation * 1.2

func _draw_demo_player() -> void:
	var pos := CENTER + Vector2(cos(_demo_player_angle), sin(_demo_player_angle)) * 128.0
	var col := Color(1, 1, 1, 0.9)
	
	# Draw SVG Sprite
	var tex: Texture2D = load("res://assets/ships/ship_classic.svg")
	if tex:
		var draw_size := Vector2(32, 32)
		# SVG points UP, so we add PI/2 to rotation
		draw_set_transform(pos, _demo_player_angle + PI/2.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-draw_size/2.0, draw_size), false, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		
	draw_circle(pos, 16.0, Color(1, 1, 1, 0.1))

# ─── HOW TO PLAY ──────────────────────────────────────────────────────────────
func _show_how_to_play() -> void:
	AudioManager.play_sfx("ui_click")
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200
	add_child(overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.08, 0.93)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(28, 100)
	panel.size = Vector2(VIEWPORT_W - 56, 1050)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.04, 0.16, 0.98)
	ps.border_color = Color(0.2, 0.85, 1.0, 0.5)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size = Vector2(VIEWPORT_W - 56, 1050)
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(vbox)

	var _add_gap := func(h: int) -> void:
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, h)
		vbox.add_child(sp)

	var _add_heading := func(text: String, col: Color) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", col)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	var _add_line := func(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 19)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 22)
		margin.add_theme_constant_override("margin_right", 22)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.add_child(lbl)
		vbox.add_child(margin)

	_add_gap.call(20)
	_add_heading.call("INFINITE ORBIT", Color(0.2, 0.85, 1.0))
	_add_gap.call(8)
	_add_heading.call("─── MAIN GAME ───", Color(0.2, 0.85, 1.0))
	_add_gap.call(6)
	_add_line.call("• Tap the screen to BOOST outward from the planet")
	_add_line.call("• Fly through the GAP in each ring to pass it")
	_add_line.call("• Tap ↺ at any time to REVERSE orbit direction")
	_add_line.call("• Collect COINS — spend them in the Shop on upgrades")
	_add_line.call("• Don't crash into the planet or drift too far away!")
	_add_line.call("• Rings get faster every 10 levels — BOSS rings at every 10th!")
	_add_line.call("• Colors cycle every 5 levels")
	_add_gap.call(16)
	_add_heading.call("─── MINI GAMES ───", Color(0.85, 0.5, 1.0))
	_add_gap.call(6)
	_add_heading.call("PRECISION TAP  (5 rounds)", Color(0.2, 0.85, 1.0))
	_add_line.call("• Watch the spinning needle and tap when it lines up inside the GREEN zone")
	_add_line.call("• 5 rounds, single shared timer — don't run out of time!")
	_add_line.call("• Tap ↺ to flip needle direction. More hits = more Gems")
	_add_gap.call(8)
	_add_heading.call("SPEED BURST", Color(1.0, 0.7, 0.1))
	_add_line.call("• Tap as fast as you can in 6 seconds — pure speed!")
	_add_line.call("• 60+ taps = max 5 Gems. No buttons, just tap!")
	_add_gap.call(8)
	_add_heading.call("ORBIT CHALLENGE", Color(0.8, 0.4, 1.0))
	_add_line.call("• Your ship orbits a planet. Green GATES appear on the orbit ring")
	_add_line.call("• TAP when near a gate to SCORE it — earn Gems!")
	_add_line.call("• Tap anywhere AWAY from a gate to FLIP orbit direction")
	_add_line.call("• Or use ↺ to flip direction. 3 lives — miss 3 gates and it ends!")
	_add_gap.call(16)
	_add_heading.call("─── CUSTOMIZATION ───", Color(0.8, 0.4, 1.0))
	_add_gap.call(6)
	_add_line.call("• SKINS: swap your ship shape and color (8 ships)")
	_add_line.call("• TRAILS: change the trail left behind (6 styles)")
	_add_line.call("• PLANETS: change the planet you orbit (8 planets)")
	_add_line.call("• Unlock with Coins or Gems — visit the SKINS menu!")
	_add_gap.call(24)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(200, 58)
	close_btn.text = "GOT IT!"
	close_btn.add_theme_font_size_override("font_size", 24)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.2, 0.85, 1.0, 0.28)
	cs.border_color = Color(0.2, 0.85, 1.0)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(12)
	close_btn.add_theme_stylebox_override("normal", cs)
	var csh := StyleBoxFlat.new()
	csh.bg_color = Color(0.2, 0.85, 1.0, 0.55)
	csh.border_color = Color(0.5, 1.0, 1.0)
	csh.set_border_width_all(2)
	csh.set_corner_radius_all(12)
	close_btn.add_theme_stylebox_override("hover", csh)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.pressed.connect(overlay.queue_free)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(close_btn)
	vbox.add_child(btn_row)
	_add_gap.call(20)

# ─── NAVIGATION ───────────────────────────────────────────────────────────────
func _on_play() -> void:
	AudioManager.play_sfx("ui_click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_shop() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_skins() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/skins.tscn")

func _on_settings() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_rewards() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/daily_rewards.tscn")

func _on_mini_game() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/mini_game.tscn")
