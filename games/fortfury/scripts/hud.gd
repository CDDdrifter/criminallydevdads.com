extends CanvasLayer

const BOMB_COLORS: Dictionary = {
	"standard": Color(0.35, 0.35, 0.35), "heavy": Color(0.25, 0.22, 0.18),
	"splitter": Color(0.80, 0.45, 0.10), "bouncer": Color(0.15, 0.70, 0.20),
	"driller": Color(0.60, 0.55, 0.40),  "shockwave": Color(0.10, 0.60, 0.90),
	"cluster": Color(0.80, 0.20, 0.15),  "freeze": Color(0.55, 0.85, 1.00),
	"laser": Color(0.90, 0.10, 0.80),    "fire": Color(0.95, 0.40, 0.05),
	"lightning": Color(0.95, 0.95, 0.20),"nuke": Color(0.30, 0.85, 0.20),
	"magnet": Color(0.70, 0.15, 0.80),   "ghost": Color(0.80, 0.85, 1.00),
	"sticky": Color(0.55, 0.40, 0.10),   "vortex": Color(0.40, 0.10, 0.90),
}

var _root: Control
var _player_bar: ProgressBar
var _enemy_bar: ProgressBar
var _player_hp_label: Label
var _enemy_hp_label: Label
var _turn_label: Label
var _score_label: Label
var _bombs_left_label: Label
var _status_label: Label
var _bomb_scroll: ScrollContainer
var _bomb_panel: HBoxContainer
var _pause_btn: Button
var _spec_btn: Button
var _pause_overlay: Control
var _wind_label: Label
var _selected_bomb_highlight: int = 0

var _scroll_drag_active: bool = false
var _scroll_drag_start_x: float = 0.0
var _scroll_drag_base: int = 0
var _scroll_dragging: bool = false

signal bomb_selected(index: int)
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal quit_to_menu_pressed
signal special_pressed

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# ── Top bar ───────────────────────────────────────────────────────────────
	var top_bg: ColorRect = ColorRect.new()
	top_bg.position = Vector2.ZERO
	top_bg.size = Vector2(1920, 78)
	top_bg.color = Color(0.04, 0.05, 0.10, 0.94)
	_root.add_child(top_bg)

	var top_line: ColorRect = ColorRect.new()
	top_line.position = Vector2(0, 75)
	top_line.size = Vector2(1920, 3)
	top_line.color = Color(0.28, 0.48, 0.80, 0.65)
	_root.add_child(top_line)

	# Player HP (left)
	_player_hp_label = _label("YOUR CASTLE  100%", 12, Rect2(12, 6, 370, 18), Color(0.72, 0.90, 1.0))
	_root.add_child(_player_hp_label)

	var p_bar_bg: Panel = _make_panel(Color(0.06, 0.07, 0.12, 1.0), Rect2(12, 26, 370, 28), 5)
	_root.add_child(p_bar_bg)
	_player_bar = _progress_bar(Rect2(14, 28, 366, 24), Color(0.22, 0.88, 0.28), 4)
	_root.add_child(_player_bar)

	# Enemy HP (right)
	_enemy_hp_label = _label("ENEMY CASTLE  100%", 12, Rect2(1538, 6, 370, 18), Color(1.0, 0.75, 0.75))
	_enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_enemy_hp_label)

	var e_bar_bg: Panel = _make_panel(Color(0.06, 0.07, 0.12, 1.0), Rect2(1538, 26, 370, 28), 5)
	_root.add_child(e_bar_bg)
	_enemy_bar = _progress_bar(Rect2(1540, 28, 366, 24), Color(0.92, 0.18, 0.18), 4)
	_root.add_child(_enemy_bar)

	# Center: turn badge
	var turn_bg: Panel = _make_panel(Color(0.10, 0.13, 0.22, 0.96), Rect2(810, 5, 300, 38), 10)
	_root.add_child(turn_bg)
	_turn_label = _label("YOUR TURN", 20, Rect2(810, 9, 300, 30), Color(0.32, 1.0, 0.44))
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_turn_label)

	_score_label = _label("Score: 0", 14, Rect2(840, 46, 240, 20), Color(1.0, 0.88, 0.35))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_score_label)

	_wind_label = _label(">> 0%", 12, Rect2(880, 63, 160, 16), Color(0.60, 0.88, 1.0))
	_wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_wind_label)

	# Pause button
	_pause_btn = Button.new()
	_pause_btn.text = "||"
	_pause_btn.position = Vector2(1868, 14)
	_pause_btn.size = Vector2(40, 44)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_style_button(_pause_btn, Color(0.14, 0.18, 0.30), Color(0.35, 0.50, 0.82), Color(0.82, 0.90, 1.0), 6)
	_pause_btn.add_theme_font_size_override("font_size", 14)
	_root.add_child(_pause_btn)

	# Status message (center screen)
	_status_label = _label("", 46, Rect2(460, 420, 1000, 90), Color.WHITE)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(0, 0, 0, 0)
	_root.add_child(_status_label)

	# ── Bottom bar ────────────────────────────────────────────────────────────
	var bot_bg: ColorRect = ColorRect.new()
	bot_bg.position = Vector2(0, 1002)
	bot_bg.size = Vector2(1920, 78)
	bot_bg.color = Color(0.04, 0.05, 0.10, 0.94)
	_root.add_child(bot_bg)

	var bot_line: ColorRect = ColorRect.new()
	bot_line.position = Vector2(0, 1002)
	bot_line.size = Vector2(1920, 3)
	bot_line.color = Color(0.28, 0.48, 0.80, 0.55)
	_root.add_child(bot_line)

	_bombs_left_label = _label("BOMBS: 10", 14, Rect2(14, 1018, 180, 44), Color(1.0, 0.88, 0.35))
	_bombs_left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_bombs_left_label)

	_bomb_scroll = ScrollContainer.new()
	_bomb_scroll.position = Vector2(208, 1008)
	_bomb_scroll.size = Vector2(1470, 64)
	_bomb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_bomb_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bomb_scroll.gui_input.connect(_on_bomb_scroll_input)
	_root.add_child(_bomb_scroll)

	_bomb_panel = HBoxContainer.new()
	_bomb_panel.add_theme_constant_override("separation", 5)
	_bomb_scroll.add_child(_bomb_panel)

	_spec_btn = Button.new()
	_spec_btn.text = "* SPECIAL"
	_spec_btn.position = Vector2(1712, 1011)
	_spec_btn.size = Vector2(182, 54)
	_spec_btn.pressed.connect(func(): special_pressed.emit())
	_style_button(_spec_btn, Color(0.42, 0.20, 0.04), Color(0.95, 0.60, 0.10), Color(1.0, 0.84, 0.28), 8)
	_spec_btn.add_theme_font_size_override("font_size", 15)
	_root.add_child(_spec_btn)

	# ── Pause overlay ─────────────────────────────────────────────────────────
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_pause_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.08, 0.80)
	_pause_overlay.add_child(dim)

	var card: Panel = _make_panel(Color(0.07, 0.10, 0.18, 0.98), Rect2(710, 278, 500, 488), 16)
	_pause_overlay.add_child(card)

	var card_border: Panel = _make_panel_border(Color(0.28, 0.45, 0.80, 0.55), Rect2(710, 278, 500, 488), 16)
	_pause_overlay.add_child(card_border)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(760, 318)
	vbox.size = Vector2(400, 430)
	vbox.add_theme_constant_override("separation", 18)
	_pause_overlay.add_child(vbox)

	var pause_title: Label = Label.new()
	pause_title.text = "-- PAUSED --"
	pause_title.add_theme_font_size_override("font_size", 38)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	vbox.add_child(pause_title)

	var resume_btn: Button = _make_menu_btn("> RESUME", Color(0.12, 0.34, 0.12), Color(0.28, 0.82, 0.32))
	resume_btn.pressed.connect(func(): resume_pressed.emit())
	vbox.add_child(resume_btn)

	var restart_btn: Button = _make_menu_btn("~ RESTART LEVEL", Color(0.12, 0.24, 0.42), Color(0.38, 0.65, 1.0))
	restart_btn.pressed.connect(func(): restart_pressed.emit())
	vbox.add_child(restart_btn)

	var menu_btn: Button = _make_menu_btn("X QUIT TO MENU", Color(0.36, 0.10, 0.10), Color(0.92, 0.22, 0.18))
	menu_btn.pressed.connect(func(): quit_to_menu_pressed.emit())
	vbox.add_child(menu_btn)

func build_bomb_selector(bombs: Array, selected_idx: int) -> void:
	for c in _bomb_panel.get_children():
		c.queue_free()

	for i in bombs.size():
		var b: String = bombs[i]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(78, 58)

		var parts: PackedStringArray = b.split("_")
		var display: String = ""
		for part: String in parts:
			if part.length() > 0:
				display += part[0].to_upper() + part.substr(1) + "\n"
		btn.text = display.strip_edges()
		btn.add_theme_font_size_override("font_size", 10)

		var col: Color = BOMB_COLORS.get(b, Color(0.5, 0.5, 0.5))
		var is_sel: bool = (i == selected_idx)

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = col.darkened(0.15) if is_sel else col.darkened(0.50)
		style.corner_radius_top_left = 7
		style.corner_radius_top_right = 7
		style.corner_radius_bottom_left = 7
		style.corner_radius_bottom_right = 7
		if is_sel:
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_color = col.lightened(0.35)
			style.shadow_color = Color(col.r, col.g, col.b, 0.55)
			style.shadow_size = 7
		else:
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.28, 0.30, 0.36)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9) if is_sel else Color(0.72, 0.72, 0.72))

		var idx: int = i
		btn.pressed.connect(func(): bomb_selected.emit(idx))
		_bomb_panel.add_child(btn)

func set_player_hp(ratio: float) -> void:
	_player_bar.value = ratio * 100.0
	_player_hp_label.text = "YOUR CASTLE  %d%%" % int(ratio * 100)
	if ratio > 0.5:
		_player_bar.modulate = Color(0.22, 0.90, 0.26)
	elif ratio > 0.25:
		_player_bar.modulate = Color(0.95, 0.62, 0.05)
	else:
		_player_bar.modulate = Color(0.95, 0.12, 0.12)

func set_enemy_hp(ratio: float) -> void:
	_enemy_bar.value = ratio * 100.0
	_enemy_hp_label.text = "ENEMY CASTLE  %d%%" % int(ratio * 100)

func set_turn(is_player: bool) -> void:
	if is_player:
		_turn_label.text = "YOUR TURN"
		_turn_label.modulate = Color(0.3, 1.0, 0.4)
	else:
		_turn_label.text = "ENEMY TURN"
		_turn_label.modulate = Color(1.0, 0.3, 0.3)

func set_score(s: int) -> void:
	_score_label.text = "Score: %d" % s

func set_bombs_left(n: int) -> void:
	_bombs_left_label.text = "BOMBS: %d" % n

func set_wind(wind: float) -> void:
	var dir: String = ">>" if wind >= 0 else "<<"
	_wind_label.text = "%s  %d%%" % [dir, int(abs(wind) * 100)]

func show_status(msg: String, col: Color = Color.WHITE) -> void:
	_status_label.text = msg
	_status_label.modulate = col
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(_status_label, "modulate", Color(col.r, col.g, col.b, 0), 2.5)

func show_pause(show: bool) -> void:
	_pause_overlay.visible = show

func flash_special() -> void:
	var t: Tween = get_tree().create_tween()
	t.tween_property(_spec_btn, "modulate", Color(2.2, 1.6, 0.4), 0.08)
	t.tween_property(_spec_btn, "modulate", Color(1.0, 1.0, 1.0), 0.35)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_panel(col: Color, rect: Rect2, radius: int) -> Panel:
	var p: Panel = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_panel_border(col: Color, rect: Rect2, radius: int) -> Panel:
	var p: Panel = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = col
	p.add_theme_stylebox_override("panel", style)
	return p

func _make_menu_btn(txt: String, bg: Color, border: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(400, 58)
	btn.add_theme_font_size_override("font_size", 18)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", border.lightened(0.2))
	return btn

func _style_button(btn: Button, bg: Color, border: Color, font_col: Color, radius: int) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", font_col)

func _progress_bar(rect: Rect2, col: Color, radius: int) -> ProgressBar:
	var pb: ProgressBar = ProgressBar.new()
	pb.position = rect.position
	pb.size = rect.size
	pb.max_value = 100.0
	pb.value = 100.0
	pb.show_percentage = false
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = col
	fill.corner_radius_top_left = radius
	fill.corner_radius_top_right = radius
	fill.corner_radius_bottom_left = radius
	fill.corner_radius_bottom_right = radius
	pb.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.10)
	bg.corner_radius_top_left = radius
	bg.corner_radius_top_right = radius
	bg.corner_radius_bottom_left = radius
	bg.corner_radius_bottom_right = radius
	pb.add_theme_stylebox_override("background", bg)
	return pb

func _on_bomb_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_scroll_drag_active = true
			_scroll_drag_start_x = event.global_position.x
			_scroll_drag_base = _bomb_scroll.scroll_horizontal
			_scroll_dragging = false
		else:
			_scroll_drag_active = false
			_scroll_dragging = false
	elif event is InputEventMouseMotion and _scroll_drag_active:
		var delta: float = _scroll_drag_start_x - event.global_position.x
		if not _scroll_dragging and abs(delta) > 8.0:
			_scroll_dragging = true
		if _scroll_dragging:
			_bomb_scroll.scroll_horizontal = int(_scroll_drag_base + delta)

func _label(txt: String, size: int, rect: Rect2, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = rect.position
	l.size = rect.size
	return l
