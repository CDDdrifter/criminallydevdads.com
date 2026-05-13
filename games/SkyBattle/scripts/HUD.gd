extends CanvasLayer

var _player: Player
var _zone: ZoneSystem

var _hp_bar: ProgressBar
var _sh_bar: ProgressBar
var _jp_bar: ProgressBar
var _ammo_lbl: Label
var _weapon_lbl: Label
var _zone_lbl: Label
var _count_lbl: Label
var _feed_box: VBoxContainer
var _prompt_lbl: Label
var _reload_lbl: Label
var _winner_panel: Panel
var _winner_lbl: Label
var _damage_overlay: ColorRect
var _death_panel: Panel
var _pause_panel: Panel
var _paused: bool = false

func _ready() -> void:
	_build_ui()

func setup(player: Player, zone: ZoneSystem) -> void:
	_player      = player
	_zone        = zone
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.hp_changed.connect(_on_hp_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.loot_prompt.connect(_on_loot_prompt)
	player.died.connect(_on_player_died)
	_on_hp_changed(player.hp, player.shield)
	_on_ammo_changed(player.ammo, player.reserve, player.weapon_data)
	update_count(GameManager.get_alive_count())
	_setup_controller_prompt()

# ── Helpers (defined first so _build_ui can call them) ────────────────────────
func _make_label(text: String, rect: Rect2, size: int) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = rect.position
	lbl.size     = rect.size
	lbl.add_theme_font_size_override("font_size", size)
	return lbl

func _make_bar(color: Color, rect: Rect2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position    = rect.position
	bar.size        = rect.size
	bar.min_value   = 0.0
	bar.max_value   = 100.0
	bar.value       = 100.0
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left     = 3
	fill.corner_radius_top_right    = 3
	fill.corner_radius_bottom_left  = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	bg_s.corner_radius_top_left     = 3
	bg_s.corner_radius_top_right    = 3
	bg_s.corner_radius_bottom_left  = 3
	bg_s.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_s)
	return bar

func _make_overlay_panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size     = rect.size
	var s := StyleBoxFlat.new()
	s.bg_color            = Color(0.04, 0.06, 0.14, 0.94)
	s.border_width_top    = 2
	s.border_width_bottom = 2
	s.border_width_left   = 2
	s.border_width_right  = 2
	s.border_color        = Color(0.5, 0.55, 0.7, 0.8)
	s.corner_radius_top_left     = 12
	s.corner_radius_top_right    = 12
	s.corner_radius_bottom_left  = 12
	s.corner_radius_bottom_right = 12
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_hud_btn(text: String, rect: Rect2, col: Color) -> Button:
	var btn := Button.new()
	btn.text     = text
	btn.position = rect.position
	btn.size     = rect.size
	var norm := StyleBoxFlat.new()
	norm.bg_color            = col
	norm.border_width_bottom = 3
	norm.border_color        = col.lightened(0.3)
	norm.corner_radius_top_left     = 8
	norm.corner_radius_top_right    = 8
	norm.corner_radius_bottom_left  = 8
	norm.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", norm)
	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = col.lightened(0.18)
	btn.add_theme_stylebox_override("hover", hov)
	var prs := norm.duplicate() as StyleBoxFlat
	prs.bg_color = col.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

# ── Pause / Death handlers ────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and event.is_pressed() and not event.is_echo():
		if _death_panel.visible or _winner_panel.visible:
			return
		_toggle_pause()

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_pause_panel.visible = _paused

func _exit_to_menu() -> void:
	get_tree().paused = false
	GameManager.go_to_menu()

func _on_watch_pressed() -> void:
	_death_panel.visible = false

# ── Build UI ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Damage overlay
	_damage_overlay              = ColorRect.new()
	_damage_overlay.color        = Color(0.0, 0.0, 0.0, 0.0)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_damage_overlay)

	# Shield bar
	_sh_bar           = _make_bar(Color(0.25, 0.55, 1.0), Rect2(20, 20, 220, 10))
	_sh_bar.max_value = Constants.PLAYER_MAX_SHIELD
	_sh_bar.value     = 0.0
	add_child(_sh_bar)

	# HP bar
	_hp_bar           = _make_bar(Color(0.20, 0.88, 0.20), Rect2(20, 34, 220, 18))
	_hp_bar.max_value = Constants.PLAYER_MAX_HP
	_hp_bar.value     = Constants.PLAYER_MAX_HP
	add_child(_hp_bar)

	var hp_lbl := _make_label("100 HP", Rect2(20, 34, 220, 18), 12)
	hp_lbl.name = "HPLabel"
	add_child(hp_lbl)

	# Jetpack bar
	_jp_bar           = _make_bar(Color(1.0, 0.55, 0.10), Rect2(20, 56, 120, 8))
	_jp_bar.max_value = Constants.JETPACK_FUEL_MAX
	_jp_bar.value     = Constants.JETPACK_FUEL_MAX
	add_child(_jp_bar)

	# Weapon + ammo (top-right)
	_weapon_lbl            = _make_label("Pistol", Rect2(1640, 12, 260, 28), 18)
	_weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_weapon_lbl)

	_ammo_lbl              = _make_label("12 / 36", Rect2(1640, 44, 260, 32), 26)
	_ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_ammo_lbl)

	_reload_lbl              = _make_label("RELOADING...", Rect2(760, 880, 400, 40), 22)
	_reload_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reload_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_reload_lbl.visible = false
	add_child(_reload_lbl)

	# Zone timer (top center)
	_zone_lbl = _make_label("Zone safe", Rect2(660, 12, 600, 28), 16)
	_zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_zone_lbl)

	# Player count (below weapon, top-right)
	_count_lbl = _make_label("12 alive", Rect2(1640, 80, 260, 28), 16)
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_count_lbl)

	# Kill feed (right side, below count)
	_feed_box          = VBoxContainer.new()
	_feed_box.position = Vector2(1500.0, 120.0)
	_feed_box.size     = Vector2(410.0, 300.0)
	add_child(_feed_box)

	# Loot prompt (bottom center)
	_prompt_lbl = _make_label("", Rect2(660, 940, 600, 32), 18)
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	add_child(_prompt_lbl)

	# ── Death panel ───────────────────────────────────────────────────────────
	_death_panel         = _make_overlay_panel(Rect2(560, 360, 800, 300))
	_death_panel.visible = false
	add_child(_death_panel)

	var elim_lbl := Label.new()
	elim_lbl.text     = "YOU WERE ELIMINATED"
	elim_lbl.position = Vector2(0, 40)
	elim_lbl.size     = Vector2(800, 50)
	elim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elim_lbl.add_theme_font_size_override("font_size", 32)
	elim_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_death_panel.add_child(elim_lbl)

	var watch_btn := _make_hud_btn("Watch Game Play Out", Rect2(60, 130, 300, 64), Color(0.12, 0.35, 0.70))
	watch_btn.pressed.connect(_on_watch_pressed)
	_death_panel.add_child(watch_btn)

	var death_menu_btn := _make_hud_btn("Main Menu", Rect2(440, 130, 300, 64), Color(0.45, 0.12, 0.12))
	death_menu_btn.pressed.connect(GameManager.go_to_menu)
	_death_panel.add_child(death_menu_btn)

	# ── Pause panel ───────────────────────────────────────────────────────────
	_pause_panel              = _make_overlay_panel(Rect2(660, 340, 600, 340))
	_pause_panel.visible      = false
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_panel)

	var pause_title := Label.new()
	pause_title.text     = "PAUSED"
	pause_title.position = Vector2(0, 36)
	pause_title.size     = Vector2(600, 50)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 38)
	pause_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_pause_panel.add_child(pause_title)

	var resume_btn := _make_hud_btn("Resume", Rect2(70, 120, 200, 64), Color(0.12, 0.45, 0.12))
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_toggle_pause)
	_pause_panel.add_child(resume_btn)

	var pmenu_btn := _make_hud_btn("Main Menu", Rect2(330, 120, 200, 64), Color(0.45, 0.12, 0.12))
	pmenu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pmenu_btn.pressed.connect(_exit_to_menu)
	_pause_panel.add_child(pmenu_btn)

	var pause_hint := Label.new()
	pause_hint.text     = "Press  ESC  to resume"
	pause_hint.position = Vector2(0, 220)
	pause_hint.size     = Vector2(600, 32)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.add_theme_font_size_override("font_size", 16)
	pause_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_pause_panel.add_child(pause_hint)

	# ── Winner panel ──────────────────────────────────────────────────────────
	_winner_panel          = _make_overlay_panel(Rect2(560, 380, 800, 260))
	_winner_panel.visible  = false
	var ws := StyleBoxFlat.new()
	ws.bg_color            = Color(0.04, 0.06, 0.14, 0.92)
	ws.border_width_top    = 3
	ws.border_width_bottom = 3
	ws.border_width_left   = 3
	ws.border_width_right  = 3
	ws.border_color        = Color(1.0, 0.8, 0.1)
	ws.corner_radius_top_left     = 12
	ws.corner_radius_top_right    = 12
	ws.corner_radius_bottom_left  = 12
	ws.corner_radius_bottom_right = 12
	_winner_panel.add_theme_stylebox_override("panel", ws)
	add_child(_winner_panel)

	_winner_lbl          = Label.new()
	_winner_lbl.position = Vector2(40.0, 60.0)
	_winner_lbl.size     = Vector2(720.0, 140.0)
	_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_winner_lbl.add_theme_font_size_override("font_size", 42)
	_winner_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	_winner_panel.add_child(_winner_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text     = "Returning to menu in 6 seconds..."
	sub_lbl.position = Vector2(40.0, 190.0)
	sub_lbl.size     = Vector2(720.0, 40.0)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_winner_panel.add_child(sub_lbl)

# ── Per-frame ─────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	if _player.state == Player.State.ONPLANE:
		_prompt_lbl.text = "SPACE  /  Jump button  —  drop from plane!"
		_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
		_zone_lbl.text = "Riding the plane... jump to drop!"
		_zone_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		return

	# Jetpack bar
	_jp_bar.visible = _player.has_jetpack
	if _player.has_jetpack:
		_jp_bar.value = _player.jetpack_fuel

	# Reload label
	_reload_lbl.visible = _player.is_reloading

	# Zone label
	if is_instance_valid(_zone):
		var t := _zone.get_time_to_shrink()
		if not _zone.is_in_zone(_player.position.x):
			_zone_lbl.text = "OUTSIDE ZONE — TAKE DAMAGE"
			_zone_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			_damage_overlay.color = Color(0.6, 0.0, 0.0, 0.12 + sin(float(Time.get_ticks_msec()) / 300.0) * 0.06)
		else:
			_damage_overlay.color = Color.TRANSPARENT
			if t > 0.0:
				_zone_lbl.text = "Zone closes in: %.0f s  (Phase %d)" % [t, _zone.phase + 1]
				_zone_lbl.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8) if t > 10.0 else Color(1.0, 0.85, 0.1))
			else:
				_zone_lbl.text = "Zone shrinking!"
				_zone_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))

# ── Signal handlers ───────────────────────────────────────────────────────────
func _on_hp_changed(hp: int, shield: int) -> void:
	_hp_bar.value = float(hp)
	_sh_bar.value = float(shield)
	var hp_lbl := get_node_or_null("HPLabel")
	if hp_lbl:
		hp_lbl.text = "%d HP" % hp
	_damage_overlay.color = Color(0.8, 0.0, 0.0, 0.22)
	var tw := create_tween()
	tw.tween_property(_damage_overlay, "color", Color.TRANSPARENT, 0.4)

func _on_ammo_changed(ammo: int, reserve: int, weapon: Dictionary) -> void:
	if weapon.get("melee", false):
		_ammo_lbl.text = "MELEE"
		_ammo_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
	else:
		_ammo_lbl.text = "%d / %d" % [ammo, reserve]
		var wc: Color  = weapon.get("color", Color.GRAY)
		_ammo_lbl.add_theme_color_override("font_color", wc)
	_weapon_lbl.text = weapon.get("name", "")

func _on_loot_prompt(text: String) -> void:
	_prompt_lbl.text = text

func _on_player_died() -> void:
	_damage_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	var t := get_tree().create_timer(1.8)
	t.timeout.connect(func() -> void:
		if not _winner_panel.visible:
			_death_panel.visible = true
	)

func add_kill_feed(killer: String, victim: String) -> void:
	var lbl := Label.new()
	lbl.text = "%s  ✕  %s" % [killer, victim]
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35, 0.9))
	_feed_box.add_child(lbl)
	while _feed_box.get_child_count() > 6:
		_feed_box.get_child(0).queue_free()
	var tw := lbl.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)

func update_count(count: int) -> void:
	_count_lbl.text = "%d alive" % count

func show_winner(winner: String) -> void:
	_death_panel.visible  = false
	_winner_panel.visible = true
	if winner == "You" or winner == _player.player_name:
		_winner_lbl.text = "VICTORY!\nYou win!"
		_winner_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	elif winner.is_empty():
		_winner_lbl.text = "DRAW\nNo survivors."
		_winner_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	else:
		_winner_lbl.text = "DEFEATED\n%s wins!" % winner
		_winner_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

# ── Web controller prompt ─────────────────────────────────────────────────────
var _ctrl_prompt_lbl:   Label = null
var _ctrl_prompt_panel: Panel = null

func _setup_controller_prompt() -> void:
	if not OS.has_feature("web"):
		return
	if GameManager.controller_connected:
		return

	_ctrl_prompt_panel              = Panel.new()
	_ctrl_prompt_panel.position     = Vector2(360.0, 12.0)
	_ctrl_prompt_panel.size         = Vector2(1200.0, 56.0)
	_ctrl_prompt_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb                          := StyleBoxFlat.new()
	sb.bg_color                     = Color(0.0, 0.0, 0.0, 0.70)
	sb.corner_radius_top_left       = 8
	sb.corner_radius_top_right      = 8
	sb.corner_radius_bottom_left    = 8
	sb.corner_radius_bottom_right   = 8
	_ctrl_prompt_panel.add_theme_stylebox_override("panel", sb)
	add_child(_ctrl_prompt_panel)

	_ctrl_prompt_lbl                      = Label.new()
	_ctrl_prompt_lbl.text                 = "Using a controller?  Press any gamepad button to activate it."
	_ctrl_prompt_lbl.position             = Vector2(360.0, 12.0)
	_ctrl_prompt_lbl.size                 = Vector2(1200.0, 56.0)
	_ctrl_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ctrl_prompt_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_ctrl_prompt_lbl.add_theme_font_size_override("font_size", 20)
	_ctrl_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_ctrl_prompt_lbl.process_mode         = Node.PROCESS_MODE_ALWAYS
	add_child(_ctrl_prompt_lbl)

	var tw := _ctrl_prompt_lbl.create_tween().set_loops()
	tw.tween_property(_ctrl_prompt_lbl, "modulate:a", 0.35, 0.75)
	tw.tween_property(_ctrl_prompt_lbl, "modulate:a", 1.00, 0.75)

	Input.joy_connection_changed.connect(_on_joy_connected_hud)

func _on_joy_connected_hud(_device: int, _connected: bool) -> void:
	if Input.get_connected_joypads().size() > 0:
		if is_instance_valid(_ctrl_prompt_panel): _ctrl_prompt_panel.queue_free()
		if is_instance_valid(_ctrl_prompt_lbl):   _ctrl_prompt_lbl.queue_free()
		_ctrl_prompt_panel = null
		_ctrl_prompt_lbl   = null
