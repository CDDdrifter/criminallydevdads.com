# settings.gd — Settings screen (attach to Control root)
extends Control

const VIEWPORT_W := 720.0
const VIEWPORT_H := 1280.0

var _stars: Array = []

func _ready() -> void:
	_build_stars()
	_build_ui()

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 70:
		_stars.append({
			"pos": Vector2(rng.randf_range(0, VIEWPORT_W), rng.randf_range(0, VIEWPORT_H)),
			"size": rng.randf_range(0.8, 2.0),
			"alpha": rng.randf_range(0.3, 0.9),
			"twinkle": rng.randf_range(0.6, 2.0),
			"phase": rng.randf_range(0.0, TAU),
		})

func _build_ui() -> void:
	var hdr := ColorRect.new()
	hdr.size = Vector2(VIEWPORT_W, 120)
	hdr.color = Color(0.04, 0.04, 0.16)
	add_child(hdr)

	var title := Label.new()
	title.position = Vector2(0, 32)
	title.size = Vector2(VIEWPORT_W, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)

	var panel := PanelContainer.new()
	panel.position = Vector2(40, 150)
	panel.size = Vector2(640, 700)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.18)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	var settings := [
		{"key": "sfx",        "label": "Sound Effects",  "icon": "res://assets/icons/sound.svg", "color": Color(0.2, 0.85, 1.0)},
		{"key": "music",      "label": "Music",           "icon": "res://assets/icons/music.svg", "color": Color(0.8, 0.4, 1.0)},
		{"key": "vibration",  "label": "Vibration",       "icon": "res://assets/icons/vibration.svg", "color": Color(1.0, 0.7, 0.2)},
		{"key": "particles",  "label": "Particles & FX",  "icon": "res://assets/icons/fx.svg", "color": Color(0.3, 1.0, 0.5)},
	]

	for i in settings.size():
		var s: Dictionary = settings[i]
		var row := _make_toggle_row(s["key"], s["label"], s["icon"], s["color"])
		vbox.add_child(row)
		if i < settings.size() - 1:
			var sep := HSeparator.new()
			sep.add_theme_color_override("color", Color(1, 1, 1, 0.07))
			vbox.add_child(sep)

	# Stats section
	var stats_sep := HSeparator.new()
	stats_sep.position = Vector2(40, 875)
	stats_sep.size = Vector2(640, 2)
	stats_sep.add_theme_color_override("color", Color(1, 1, 1, 0.1))
	add_child(stats_sep)

	var stats_title := Label.new()
	stats_title.position = Vector2(0, 890)
	stats_title.size = Vector2(VIEWPORT_W, 36)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.text = "LIFETIME STATS"
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	add_child(stats_title)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.position = Vector2(80, 934)
	stats_grid.size = Vector2(560, 120)
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 10)
	add_child(stats_grid)

	var stat_items := [
		["Best Score", str(SaveManager.get_best_score())],
		["Total Runs",  str(SaveManager.get_total_runs())],
		["All-time Coins", str(SaveManager.get_coins())],
		["Gems", str(SaveManager.get_gems())],
	]
	for si in stat_items:
		var sk := Label.new()
		sk.text = si[0]
		sk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sk.add_theme_font_size_override("font_size", 16)
		sk.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		stats_grid.add_child(sk)
		var sv := Label.new()
		sv.text = si[1]
		sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sv.add_theme_font_size_override("font_size", 18)
		sv.add_theme_color_override("font_color", Color.WHITE)
		stats_grid.add_child(sv)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.position = Vector2(VIEWPORT_W / 2.0 - 130, 1070)
	reset_btn.size = Vector2(260, 50)
	reset_btn.text = "RESET ALL DATA"
	reset_btn.add_theme_font_size_override("font_size", 18)
	_style_btn(reset_btn, Color(1.0, 0.3, 0.2))
	reset_btn.pressed.connect(_on_reset_pressed)
	add_child(reset_btn)

	# Back button
	var back_btn := Button.new()
	back_btn.position = Vector2(20, VIEWPORT_H - 90)
	back_btn.size = Vector2(160, 54)
	back_btn.text = "BACK"
	back_btn.add_theme_font_size_override("font_size", 24)
	_style_btn(back_btn, Color(0.6, 0.6, 0.9))
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _make_toggle_row(key: String, label: String, icon_path: String, col: Color) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(640, 90)

	var icon_rect := TextureRect.new()
	icon_rect.position = Vector2(20, 20)
	icon_rect.size = Vector2(48, 48)
	icon_rect.texture = load(icon_path)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = col
	row.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.position = Vector2(86, 30)
	name_lbl.size = Vector2(340, 36)
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_lbl)

	var toggle_btn := Button.new()
	toggle_btn.position = Vector2(486, 26)
	toggle_btn.size = Vector2(128, 42)
	toggle_btn.name = "Toggle_" + key
	var current_val := SaveManager.get_setting(key)
	_update_toggle_style(toggle_btn, current_val, col)
	toggle_btn.pressed.connect(_on_toggle.bind(key, toggle_btn, col))
	row.add_child(toggle_btn)

	return row

func _update_toggle_style(btn: Button, active: bool, col: Color) -> void:
	btn.text = "ON" if active else "OFF"
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.5 if active else 0.1)
	s.border_color = col if active else Color(1, 1, 1, 0.2)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color.WHITE if active else Color(1, 1, 1, 0.35))
	btn.add_theme_font_size_override("font_size", 20)

func _on_toggle(key: String, btn: Button, col: Color) -> void:
	var new_val := not SaveManager.get_setting(key)
	SaveManager.set_setting(key, new_val)
	_update_toggle_style(btn, new_val, col)
	AudioManager.play_sfx("ui_click")
	match key:
		"sfx":   AudioManager.set_sfx_enabled(new_val)
		"music": AudioManager.set_music_enabled(new_val)

func _style_btn(btn: Button, col: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.2)
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color.WHITE)

var _confirm_reset: bool = false
var _confirm_lbl: Label

func _on_reset_pressed() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		if _confirm_lbl == null:
			_confirm_lbl = Label.new()
			_confirm_lbl.position = Vector2(0, 1126)
			_confirm_lbl.size = Vector2(VIEWPORT_W, 36)
			_confirm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_confirm_lbl.text = "Press again to confirm — this cannot be undone!"
			_confirm_lbl.add_theme_font_size_override("font_size", 16)
			_confirm_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			add_child(_confirm_lbl)
		return
	# Actually reset
	DirAccess.remove_absolute("user://save_data.cfg")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_back() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _process(delta: float) -> void:
	for s in _stars:
		s["phase"] += s["twinkle"] * delta
		s["alpha"] = 0.3 + 0.7 * (0.5 + 0.5 * sin(s["phase"]))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.03, 0.03, 0.12))
	for s in _stars:
		draw_circle(s["pos"], s["size"], Color(s["alpha"], s["alpha"], s["alpha"] * 0.95))
