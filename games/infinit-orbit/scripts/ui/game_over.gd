# game_over.gd — Game over screen (attach to Control root)
# Shows final score, best score, coins earned, and options to retry or go home.
extends Control

const VIEWPORT_W := 720.0
const VIEWPORT_H := 1280.0

var _final_score: int = 0
var _coins_earned: int = 0
var _is_new_best: bool = false
var _stars: Array = []
var _anim_score: float = 0.0   # Animated counter
var _anim_speed: float = 0.0

func _ready() -> void:
	_final_score = GameManager.score
	_coins_earned = GameManager.coins_this_run
	_is_new_best = _final_score >= SaveManager.get_best_score()
	_anim_score = 0.0
	_anim_speed = maxf(_final_score / 1.5, 50.0)
	_build_stars()
	_build_ui()
	AudioManager.play_music_track(0)

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 80:
		_stars.append({
			"pos": Vector2(rng.randf_range(0, VIEWPORT_W), rng.randf_range(0, VIEWPORT_H)),
			"size": rng.randf_range(0.8, 2.2),
			"alpha": rng.randf_range(0.25, 0.9),
			"twinkle": rng.randf_range(0.5, 2.2),
			"phase": rng.randf_range(0.0, TAU),
		})

func _build_ui() -> void:
	# ── Panel background ──
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 340)
	panel.size = Vector2(600, 620)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.15, 0.9)
	panel_style.border_color = Color(0.2, 0.85, 1.0, 0.4)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(0, 0)
	vbox.size = Vector2(600, 620)
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	# ── GAME OVER title ──
	var go_lbl := _make_label("GAME OVER", 52, Color(1.0, 0.3, 0.2))
	go_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_lbl.add_theme_constant_override("margin_top", 36)
	vbox.add_child(go_lbl)

	# ── Score ──
	var score_title := _make_label("SCORE", 18, Color(1, 1, 1, 0.5))
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_title)

	var score_lbl := _make_label("0", 72, Color.WHITE)
	score_lbl.name = "ScoreLabel"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)

	# ── NEW BEST badge ──
	if _is_new_best and _final_score > 0:
		var best_badge := _make_label("NEW BEST!", 28, Color(1.0, 0.9, 0.2))
		best_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(best_badge)
		var tw := create_tween().set_loops()
		tw.tween_property(best_badge, "modulate:a", 0.4, 0.6)
		tw.tween_property(best_badge, "modulate:a", 1.0, 0.6)
	else:
		var best_lbl := _make_label("Best: %d" % SaveManager.get_best_score(), 22, Color(1, 1, 1, 0.4))
		best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(best_lbl)

	# ── Stats row ──
	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(stats_hbox)

	var level_box := _make_stat_box("LEVEL", str(GameManager.level))
	var rings_box := _make_stat_box("RINGS", str(GameManager.rings_cleared))
	
	var coins_box := Control.new()
	coins_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins_box.custom_minimum_size = Vector2(0, 80)
	var c_vbox := VBoxContainer.new()
	c_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	c_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_box.add_child(c_vbox)
	
	var c_title := _make_label("COINS", 14, Color(1, 1, 1, 0.4))
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_vbox.add_child(c_title)
	
	var c_hbox := HBoxContainer.new()
	c_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	c_vbox.add_child(c_hbox)
	
	var c_icon := TextureRect.new()
	c_icon.texture = load("res://assets/icons/coin.svg")
	c_icon.custom_minimum_size = Vector2(20, 20)
	c_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c_icon.modulate = Color(1.0, 0.9, 0.2)
	c_hbox.add_child(c_icon)
	
	var c_val := _make_label(str(_coins_earned), 24, Color.WHITE)
	c_hbox.add_child(c_val)
	
	stats_hbox.add_child(level_box)
	stats_hbox.add_child(rings_box)
	stats_hbox.add_child(coins_box)

	# ── Separator ──
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.1))
	vbox.add_child(sep)

	# ── Buttons ──
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_vbox)
	# Center buttons with a margin
	btn_vbox.add_theme_constant_override("margin_left", 60)
	btn_vbox.add_theme_constant_override("margin_right", 60)

	var retry_btn := _make_btn("PLAY AGAIN", Color(0.2, 0.85, 1.0), 30)
	retry_btn.pressed.connect(_on_retry)
	btn_vbox.add_child(retry_btn)

	var menu_btn := _make_btn("MAIN MENU", Color(0.6, 0.6, 0.9), 26)
	menu_btn.pressed.connect(_on_menu)
	btn_vbox.add_child(menu_btn)

	var shop_btn := _make_btn("UPGRADES", Color(1.0, 0.8, 0.2), 26)
	shop_btn.pressed.connect(_on_shop)
	btn_vbox.add_child(shop_btn)

	# ── Booster offer (if not active) ──
	if not GameManager.xp_booster_active:
		var booster_row := HBoxContainer.new()
		booster_row.add_theme_constant_override("separation", 10)
		vbox.add_child(booster_row)

		var xp_boost_btn := _make_btn("2× XP (3 Gems)", Color(1.0, 0.7, 0.1), 20)
		xp_boost_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_boost_btn.pressed.connect(_on_buy_xp_booster)
		booster_row.add_child(xp_boost_btn)

		var coin_boost_btn := _make_btn("2× Coins (3 Gems)", Color(1.0, 0.9, 0.2), 20)
		coin_boost_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		coin_boost_btn.pressed.connect(_on_buy_coin_booster)
		booster_row.add_child(coin_boost_btn)

	# Animate panel in
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(300, 310)
	panel.modulate.a = 0.0
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw2.tween_property(panel, "modulate:a", 1.0, 0.35)

func _make_label(text: String, font_size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl

func _make_stat_box(title: String, value: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 32)
	val_lbl.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(val_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	box.add_child(title_lbl)

	return box

func _make_btn(label_text: String, col: Color, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 58)
	btn.add_theme_font_size_override("font_size", font_size)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(col.r, col.g, col.b, 0.18)
	normal_style.border_color = col
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover",
		_make_hover_style(col))
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

func _make_hover_style(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.35)
	s.border_color = col.lightened(0.3)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	return s

func _process(delta: float) -> void:
	# Animate score counter
	if _anim_score < _final_score:
		_anim_score = minf(_anim_score + _anim_speed * delta, float(_final_score))
		var score_lbl := find_child("ScoreLabel", true, false) as Label
		if score_lbl:
			score_lbl.text = str(int(_anim_score))
	for s in _stars:
		s["phase"] += s["twinkle"] * delta
		s["alpha"] = 0.3 + 0.7 * (0.5 + 0.5 * sin(s["phase"]))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.03, 0.03, 0.12))
	for s in _stars:
		draw_circle(s["pos"], s["size"], Color(s["alpha"], s["alpha"], s["alpha"] * 0.95))

# ─── ACTIONS ──────────────────────────────────────────────────────────────────
func _on_retry() -> void:
	AudioManager.play_sfx("ui_click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_menu() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_shop() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_buy_xp_booster() -> void:
	if SaveManager.spend_gems(3):
		GameManager.activate_xp_booster(120.0, 2.0)
		AudioManager.play_sfx("shop_buy")

func _on_buy_coin_booster() -> void:
	if SaveManager.spend_gems(3):
		GameManager.activate_coin_booster(120.0, 2.0)
		AudioManager.play_sfx("shop_buy")
