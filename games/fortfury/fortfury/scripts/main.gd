extends Node2D

# ── Screen IDs ────────────────────────────────────────────────────────────────
enum Screen { TITLE, WORLD_MAP, LEVEL_SELECT, SHOP, SETTINGS, ACHIEVEMENTS, DAILY, HOW_TO_PLAY }

const VW := 1920.0
const VH := 1080.0
const ZONE_COLORS: Array = [
	Color(0.30, 0.70, 0.25),  # 1 Grassland
	Color(0.55, 0.52, 0.28),  # 2 Village
	Color(0.28, 0.55, 0.30),  # 3 Forest
	Color(0.40, 0.40, 0.50),  # 4 Mountain
	Color(0.72, 0.58, 0.22),  # 5 Desert
	Color(0.22, 0.48, 0.22),  # 6 Forest Siege
	Color(0.50, 0.72, 0.88),  # 7 Arctic
	Color(0.40, 0.40, 0.45),  # 8 Industrial
	Color(0.40, 0.10, 0.08),  # 9 Apocalypse
	Color(0.55, 0.18, 0.52),  # 10 Legendary
]
const ZONE_NAMES: Array = [
	"Training Grounds","Village Wars","Border Conflict","Mountain Pass",
	"Desert Siege","Forest Siege","Arctic Assault","Industrial War",
	"Apocalypse","Legendary"
]

var _current_screen: Screen = Screen.TITLE
var _ui: CanvasLayer
var _root: Control
var _selected_zone: int = 1
var _daily_popup_shown: bool = false

func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_root)

	# Background gradient
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.06, 0.12)
	_root.add_child(bg)

	_show_screen(Screen.TITLE)

	# Check daily reward popup
	if GameState.can_claim_daily() and not _daily_popup_shown:
		get_tree().create_timer(0.5).timeout.connect(_show_daily_popup)

func _show_screen(s: Screen) -> void:
	_current_screen = s
	for c in _root.get_children():
		if c is ColorRect:
			continue  # keep bg
		c.queue_free()

	match s:
		Screen.TITLE:       _build_title()
		Screen.WORLD_MAP:   _build_world_map()
		Screen.LEVEL_SELECT: _build_level_select(_selected_zone)
		Screen.SHOP:        _build_shop()
		Screen.SETTINGS:    _build_settings()
		Screen.ACHIEVEMENTS:_build_achievements()
		Screen.DAILY:       _build_daily()
		Screen.HOW_TO_PLAY: _build_how_to_play()

# ─────────────────────────────────────────────────────────────────────────────
# TITLE SCREEN
# ─────────────────────────────────────────────────────────────────────────────

func _build_title() -> void:
	# ── Left column: logo + stats ─────────────────────────────────────────────
	var logo_card: Panel = Panel.new()
	logo_card.position = Vector2(160, 80)
	logo_card.size = Vector2(640, 920)
	var lc_style: StyleBoxFlat = StyleBoxFlat.new()
	lc_style.bg_color = Color(0.07, 0.09, 0.17, 0.88)
	lc_style.border_color = Color(0.28, 0.44, 0.82, 0.55)
	lc_style.set_border_width_all(1)
	lc_style.set_corner_radius_all(20)
	lc_style.shadow_color = Color(0.10, 0.20, 0.60, 0.30)
	lc_style.shadow_size = 12
	logo_card.add_theme_stylebox_override("panel", lc_style)
	logo_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(logo_card)

	# Gold accent bar at top of logo card
	var accent: Panel = Panel.new()
	accent.position = Vector2(160, 80)
	accent.size = Vector2(640, 5)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var acc_style: StyleBoxFlat = StyleBoxFlat.new()
	acc_style.bg_color = Color(0.95, 0.72, 0.18, 0.80)
	accent.add_theme_stylebox_override("panel", acc_style)
	_root.add_child(accent)

	# Logo text
	var logo: Label = Label.new()
	logo.text = "FORT\nFURY"
	logo.add_theme_font_size_override("font_size", 110)
	logo.add_theme_color_override("font_color", Color(0.98, 0.78, 0.18))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.position = Vector2(160, 110)
	logo.size = Vector2(640, 280)
	_root.add_child(logo)

	# Subtitle
	var sub: Label = Label.new()
	sub.text = "Turn-Based Siege Combat"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.62, 0.72, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(160, 390)
	sub.size = Vector2(640, 30)
	_root.add_child(sub)

	# Divider
	var div: Panel = Panel.new()
	div.position = Vector2(240, 432)
	div.size = Vector2(480, 1)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var div_style: StyleBoxFlat = StyleBoxFlat.new()
	div_style.bg_color = Color(0.28, 0.44, 0.82, 0.40)
	div.add_theme_stylebox_override("panel", div_style)
	_root.add_child(div)

	# Stats row inside card
	var stats_items: Array = [
		["RANK", "%d" % GameState.player_rank],
		["GOLD", "%d" % GameState.gold],
		["STARS", "%d" % GameState.get_total_stars()],
	]
	for si: int in stats_items.size():
		var item: Array = stats_items[si]
		var sx: float = 200.0 + si * 200.0
		var lbl_key: Label = Label.new()
		lbl_key.text = str(item[0])
		lbl_key.add_theme_font_size_override("font_size", 13)
		lbl_key.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85))
		lbl_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_key.position = Vector2(sx, 444)
		lbl_key.size = Vector2(160, 18)
		_root.add_child(lbl_key)
		var lbl_val: Label = Label.new()
		lbl_val.text = str(item[1])
		lbl_val.add_theme_font_size_override("font_size", 22)
		lbl_val.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_val.position = Vector2(sx, 462)
		lbl_val.size = Vector2(160, 30)
		_root.add_child(lbl_val)

	# Event banner
	if GameState.active_event.get("label", "") != "":
		var event_l: Label = Label.new()
		event_l.text = "EVENT: " + str(GameState.active_event.get("label", ""))
		event_l.add_theme_font_size_override("font_size", 17)
		event_l.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		event_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_l.position = Vector2(160, 500)
		event_l.size = Vector2(640, 24)
		_root.add_child(event_l)

	# Hourly chest
	var hourly_sec: int = GameState.seconds_until_hourly()
	var chest_label: Label = Label.new()
	if hourly_sec == 0:
		chest_label.text = "Hourly Chest READY!"
		chest_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	else:
		chest_label.text = "Next chest: %02d:%02d" % [hourly_sec / 60, hourly_sec % 60]
		chest_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	chest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_label.add_theme_font_size_override("font_size", 16)
	chest_label.position = Vector2(160, 960)
	chest_label.size = Vector2(640, 24)
	_root.add_child(chest_label)

	# ── Right column: menu buttons ────────────────────────────────────────────
	var btn_card: Panel = Panel.new()
	btn_card.position = Vector2(860, 80)
	btn_card.size = Vector2(900, 920)
	var bc_style: StyleBoxFlat = StyleBoxFlat.new()
	bc_style.bg_color = Color(0.06, 0.08, 0.15, 0.80)
	bc_style.border_color = Color(0.22, 0.36, 0.72, 0.45)
	bc_style.set_border_width_all(1)
	bc_style.set_corner_radius_all(20)
	btn_card.add_theme_stylebox_override("panel", bc_style)
	btn_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(btn_card)

	var vbox: VBoxContainer = _vbox(Vector2(920, 140), 780, 18)
	_root.add_child(vbox)

	_add_btn(vbox, "PLAY", 80, func(): _show_screen(Screen.WORLD_MAP))
	_add_btn(vbox, "DAILY REWARDS", 58, func(): _show_screen(Screen.DAILY))
	_add_btn(vbox, "SHOP", 58, func(): _show_screen(Screen.SHOP))
	_add_btn(vbox, "ACHIEVEMENTS", 58, func(): _show_screen(Screen.ACHIEVEMENTS))
	_add_btn(vbox, "HOW TO PLAY", 58, func(): _show_screen(Screen.HOW_TO_PLAY))
	_add_btn(vbox, "SETTINGS", 58, func(): _show_screen(Screen.SETTINGS))

# ─────────────────────────────────────────────────────────────────────────────
# WORLD MAP
# ─────────────────────────────────────────────────────────────────────────────

func _build_world_map() -> void:
	_back_btn(func(): _show_screen(Screen.TITLE))

	var title := _header("SELECT ZONE", VW * 0.5 - 150, 20)
	_root.add_child(title)

	# Zone grid — 2 rows of 5
	var container := GridContainer.new()
	container.columns = 5
	container.position = Vector2(200, 120)
	container.size = Vector2(1520, 820)
	container.add_theme_constant_override("h_separation", 20)
	container.add_theme_constant_override("v_separation", 20)
	_root.add_child(container)

	var total_stars := GameState.get_total_stars()

	for zone_id in range(1, 11):
		var first_level := (zone_id - 1) * 10 + 1
		var unlocked := GameState.is_level_unlocked(first_level)
		var zone_stars := 0
		for l in range(first_level, first_level + 10):
			zone_stars += GameState.get_level_stars(l)

		var card := _zone_card(zone_id, ZONE_NAMES[zone_id - 1], ZONE_COLORS[zone_id - 1], unlocked, zone_stars)
		card.custom_minimum_size = Vector2(270, 380)
		if unlocked:
			card.gui_input.connect(func(e): _on_zone_clicked(e, zone_id))
		container.add_child(card)

func _on_zone_clicked(event: InputEvent, zone_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_zone = zone_id
		_show_screen(Screen.LEVEL_SELECT)

func _zone_card(zone_id: int, name: String, col: Color, unlocked: bool, stars: int) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = col.darkened(0.52) if unlocked else Color(0.10, 0.10, 0.13)
	style.border_color = col.lightened(0.10) if unlocked else Color(0.22, 0.22, 0.26)
	style.border_width_top = 5
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(16)
	style.shadow_color = Color(col.r * 0.4, col.g * 0.4, col.b * 0.4, 0.45) if unlocked else Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var zone_num: Label = Label.new()
	zone_num.text = "ZONE %d" % zone_id
	zone_num.add_theme_font_size_override("font_size", 13)
	zone_num.add_theme_color_override("font_color", col.lightened(0.35) if unlocked else Color(0.4, 0.4, 0.4))
	zone_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(zone_num)

	var icon: Label = Label.new()
	icon.text = "🔒" if not unlocked else _zone_icon(zone_id)
	icon.add_theme_font_size_override("font_size", 62)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(0, 90)
	vb.add_child(icon)

	var zone_name: Label = Label.new()
	zone_name.text = name
	zone_name.add_theme_font_size_override("font_size", 18)
	zone_name.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95) if unlocked else Color(0.35, 0.35, 0.38))
	zone_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(zone_name)

	var star_row: HBoxContainer = HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 2)
	vb.add_child(star_row)
	for i: int in 10:
		var sd: Label = Label.new()
		sd.text = "★" if i < (stars / 3) else "☆"
		sd.add_theme_font_size_override("font_size", 12)
		sd.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1) if i < (stars / 3) else Color(0.28, 0.28, 0.30))
		star_row.add_child(sd)

	if not unlocked:
		var prev_zone_last: int = (zone_id - 2) * 10 + 10 if zone_id > 1 else 0
		var lock_l: Label = Label.new()
		lock_l.text = "Clear Lv %d" % prev_zone_last
		lock_l.add_theme_font_size_override("font_size", 12)
		lock_l.add_theme_color_override("font_color", Color(0.42, 0.42, 0.45))
		lock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lock_l)

	return panel

func _zone_icon(zone_id: int) -> String:
	var icons := ["🌿","🏘️","⚔️","⛰️","🏜️","🌲","❄️","⚙️","☄️","💀"]
	return icons[zone_id - 1]

# ─────────────────────────────────────────────────────────────────────────────
# LEVEL SELECT
# ─────────────────────────────────────────────────────────────────────────────

func _build_level_select(zone_id: int) -> void:
	_back_btn(func(): _show_screen(Screen.WORLD_MAP))

	var zone_name: String = ZONE_NAMES[zone_id - 1]
	var title := _header("ZONE %d: %s" % [zone_id, zone_name.to_upper()], VW * 0.5 - 250, 20)
	_root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(300, 120)
	grid.size = Vector2(1320, 800)
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	_root.add_child(grid)

	var zone_col: Color = ZONE_COLORS[zone_id - 1]

	for i in range(10):
		var level_id := (zone_id - 1) * 10 + i + 1
		var lvl := LevelData.get_level(level_id)
		var unlocked := GameState.is_level_unlocked(level_id)
		var stars := GameState.get_level_stars(level_id)
		var completed := GameState.is_level_completed(level_id)
		var card := _level_card(level_id, lvl.get("name", "Level %d" % level_id), unlocked, stars, completed, zone_col)
		card.custom_minimum_size = Vector2(235, 210)
		if unlocked:
			card.gui_input.connect(func(e): _on_level_clicked(e, level_id))
		grid.add_child(card)

func _level_card(level_id: int, name: String, unlocked: bool, stars: int, completed: bool, zone_col: Color) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = zone_col.darkened(0.50) if unlocked else Color(0.10, 0.10, 0.12)
	if completed:
		style.border_color = Color(1.0, 0.85, 0.15)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 2
		style.border_width_bottom = 2
	elif unlocked:
		style.border_color = zone_col.lightened(0.15)
		style.set_border_width_all(2)
	else:
		style.border_color = Color(0.20, 0.20, 0.22)
		style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)

	var num_l: Label = Label.new()
	num_l.text = "%d" % level_id
	num_l.add_theme_font_size_override("font_size", 38)
	num_l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if unlocked else Color(0.28, 0.28, 0.30))
	num_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(num_l)

	var name_l: Label = Label.new()
	name_l.text = name
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82) if unlocked else Color(0.28, 0.28, 0.30))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(name_l)

	var stars_row: HBoxContainer = HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 3)
	vb.add_child(stars_row)
	for i: int in 3:
		var sl: Label = Label.new()
		sl.text = "★" if i < stars else "☆"
		sl.add_theme_font_size_override("font_size", 24)
		sl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.12) if i < stars else Color(0.25, 0.25, 0.27))
		stars_row.add_child(sl)

	if not unlocked:
		var lock: Label = Label.new()
		lock.text = "LOCKED"
		lock.add_theme_font_size_override("font_size", 11)
		lock.add_theme_color_override("font_color", Color(0.40, 0.40, 0.44))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lock)

	return panel

func _on_level_clicked(event: InputEvent, level_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.current_level = level_id
		get_tree().change_scene_to_file("res://scenes/Game.tscn")

# ─────────────────────────────────────────────────────────────────────────────
# SHOP
# ─────────────────────────────────────────────────────────────────────────────

func _build_shop() -> void:
	_back_btn(func(): _show_screen(Screen.TITLE))
	var title := _header("SHOP", VW * 0.5 - 80, 20)
	_root.add_child(title)

	var currency_l := Label.new()
	currency_l.text = "Gold: %d    Gems: 💎 %d" % [GameState.gold, GameState.gems]
	currency_l.position = Vector2(1400, 30)
	currency_l.add_theme_font_size_override("font_size", 22)
	currency_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_root.add_child(currency_l)

	# Tabs
	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(200, 100)
	tab_bar.add_theme_constant_override("separation", 10)
	_root.add_child(tab_bar)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(200, 160)
	scroll.size = Vector2(1520, 800)
	_root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	# Bomb section
	var bomb_header := _section_header("BOMBS")
	content.add_child(bomb_header)

	var bomb_grid := GridContainer.new()
	bomb_grid.columns = 4
	bomb_grid.add_theme_constant_override("h_separation", 12)
	bomb_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(bomb_grid)

	for bomb_id in GameState.SHOP_BOMBS:
		var card := _shop_item_card(bomb_id, GameState.SHOP_BOMBS[bomb_id], bomb_id in GameState.unlocked_bombs)
		bomb_grid.add_child(card)

	# Upgrades section
	var upg_header := _section_header("CASTLE UPGRADES")
	content.add_child(upg_header)

	var upg_grid := GridContainer.new()
	upg_grid.columns = 3
	upg_grid.add_theme_constant_override("h_separation", 12)
	upg_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(upg_grid)

	for upg_id in GameState.SHOP_UPGRADES:
		var upg_data: Dictionary = GameState.SHOP_UPGRADES[upg_id]
		var owned: bool = upg_id in GameState.purchased_upgrades
		var upg_card := _shop_upgrade_card(upg_id, upg_data, owned)
		upg_grid.add_child(upg_card)

func _shop_item_card(id: String, cost: Dictionary, owned: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 130)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.28, 0.15) if owned else Color(0.18, 0.16, 0.12)
	style.border_color = Color(0.3, 0.8, 0.3) if owned else Color(0.4, 0.4, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var name_l := Label.new()
	name_l.text = id.capitalize()
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.custom_minimum_size = Vector2(140, 0)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_l)

	if owned:
		var own_l := Label.new()
		own_l.text = "✓ OWNED"
		own_l.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		own_l.add_theme_font_size_override("font_size", 16)
		own_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(own_l)
	else:
		var btn := Button.new()
		var price := ""
		if cost.get("gold", 0) > 0:
			price = "%d Gold" % cost["gold"]
		else:
			price = "💎 %d" % cost.get("gems", 0)
		btn.text = price
		btn.custom_minimum_size = Vector2(140, 40)
		btn.pressed.connect(func():
			if GameState.buy_bomb(id):
				_show_screen(Screen.SHOP)
		)
		hbox.add_child(btn)

	return panel

func _shop_upgrade_card(id: String, data: Dictionary, owned: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 110)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.28) if owned else Color(0.15, 0.13, 0.18)
	style.border_color = Color(0.3, 0.5, 0.9) if owned else Color(0.4, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	panel.add_child(vb)

	var name_l := Label.new()
	name_l.text = id.capitalize().replace("_", " ")
	name_l.add_theme_font_size_override("font_size", 17)
	vb.add_child(name_l)

	var desc_l := Label.new()
	desc_l.text = data.get("desc", "")
	desc_l.add_theme_font_size_override("font_size", 13)
	desc_l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vb.add_child(desc_l)

	if owned:
		var own_l := Label.new()
		own_l.text = "✓ PURCHASED"
		own_l.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		own_l.add_theme_font_size_override("font_size", 14)
		vb.add_child(own_l)
	else:
		var btn := Button.new()
		var price := "%d Gold" % data.get("gold", 0) if data.get("gold", 0) > 0 else "💎 %d" % data.get("gems", 0)
		btn.text = "Buy: " + price
		btn.custom_minimum_size = Vector2(200, 38)
		btn.pressed.connect(func():
			if GameState.buy_upgrade(id):
				_show_screen(Screen.SHOP)
		)
		vb.add_child(btn)

	return panel

# ─────────────────────────────────────────────────────────────────────────────
# DAILY REWARDS
# ─────────────────────────────────────────────────────────────────────────────

func _build_daily() -> void:
	_back_btn(func(): _show_screen(Screen.TITLE))
	var title := _header("DAILY REWARDS", VW * 0.5 - 150, 20)
	_root.add_child(title)

	var vbox := _vbox(Vector2(600, 110), 720, 22)
	_root.add_child(vbox)

	# 7-day streak display
	var streak_row := HBoxContainer.new()
	streak_row.alignment = BoxContainer.ALIGNMENT_CENTER
	streak_row.add_theme_constant_override("separation", 12)
	vbox.add_child(streak_row)

	var daily_rewards := [
		{"gold": 150, "gems": 5}, {"gold": 225, "gems": 10}, {"gold": 300, "gems": 15},
		{"gold": 400, "gems": 20}, {"gold": 550, "gems": 30}, {"gold": 700, "gems": 40},
		{"gold": 1000, "gems": 60, "xp": 200},
	]

	for i in 7:
		var day_card := _day_card(i + 1, daily_rewards[i], GameState.daily_streak, i < GameState.daily_streak)
		streak_row.add_child(day_card)

	_spacer(vbox, 20)

	# Daily claim button
	var daily_btn := Button.new()
	daily_btn.custom_minimum_size = Vector2(400, 65)
	daily_btn.add_theme_font_size_override("font_size", 24)
	if GameState.can_claim_daily():
		daily_btn.text = "CLAIM DAILY REWARD"
		daily_btn.pressed.connect(func():
			var r := GameState.claim_daily()
			_show_reward_popup(r)
			_show_screen(Screen.DAILY)
		)
	else:
		var secs := GameState.seconds_until_daily()
		daily_btn.text = "Next: %02d:%02d:%02d" % [secs/3600, (secs%3600)/60, secs%60]
		daily_btn.disabled = true
	vbox.add_child(daily_btn)

	_spacer(vbox, 30)

	# Hourly chest
	var chest_header := _section_header("HOURLY CHEST")
	vbox.add_child(chest_header)

	var hourly_btn := Button.new()
	hourly_btn.custom_minimum_size = Vector2(400, 60)
	hourly_btn.add_theme_font_size_override("font_size", 20)
	if GameState.can_claim_hourly():
		hourly_btn.text = "📦 OPEN HOURLY CHEST"
		hourly_btn.pressed.connect(func():
			var r := GameState.claim_hourly()
			_show_reward_popup(r)
			_show_screen(Screen.DAILY)
		)
	else:
		var secs := GameState.seconds_until_hourly()
		hourly_btn.text = "Next chest: %02d:%02d" % [secs / 60, secs % 60]
		hourly_btn.disabled = true
	vbox.add_child(hourly_btn)

	_spacer(vbox, 30)

	# Daily challenges
	var chal_header := _section_header("DAILY CHALLENGES")
	vbox.add_child(chal_header)

	var challenges := GameState.get_todays_challenges()
	var chal_progress := GameState.get_challenge_progress()
	for i in challenges.size():
		var ch: Dictionary = challenges[i]
		var prog: int = chal_progress[i]  # 0=pending 1=done 2=claimed
		vbox.add_child(_challenge_row(i, ch, prog))

func _challenge_row(idx: int, ch: Dictionary, prog: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 68)
	var style := StyleBoxFlat.new()
	match prog:
		1: style.bg_color = Color(0.12, 0.30, 0.12)
		2: style.bg_color = Color(0.10, 0.14, 0.10)
		_: style.bg_color = Color(0.14, 0.14, 0.20)
	style.border_color = Color(0.28, 0.82, 0.30) if prog == 1 else (Color(0.25, 0.42, 0.25) if prog == 2 else Color(0.32, 0.32, 0.48))
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 26)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.custom_minimum_size = Vector2(36, 0)
	match prog:
		1: status.text = "✓"; status.add_theme_color_override("font_color", Color(0.28, 1.0, 0.32))
		2: status.text = "✓"; status.add_theme_color_override("font_color", Color(0.38, 0.55, 0.38))
		_: status.text = "○"; status.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	hbox.add_child(status)

	var desc := Label.new()
	desc.text = ch.get("desc", "")
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90) if prog == 0 else (Color(0.65, 0.80, 0.65) if prog == 2 else Color.WHITE))
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(desc)

	if prog == 2:
		var claimed_l := Label.new()
		claimed_l.text = "CLAIMED"
		claimed_l.add_theme_font_size_override("font_size", 14)
		claimed_l.add_theme_color_override("font_color", Color(0.40, 0.60, 0.40))
		claimed_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		claimed_l.custom_minimum_size = Vector2(120, 0)
		claimed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(claimed_l)
	elif prog == 1:
		var claim_btn := Button.new()
		claim_btn.text = "+%d Gold" % ch.get("reward_gold", 0)
		claim_btn.custom_minimum_size = Vector2(120, 44)
		claim_btn.add_theme_font_size_override("font_size", 15)
		claim_btn.pressed.connect(func():
			GameState.claim_daily_challenge(idx)
			_show_screen(Screen.DAILY)
		)
		hbox.add_child(claim_btn)
	else:
		var reward_l := Label.new()
		reward_l.text = "%d Gold" % ch.get("reward_gold", 0)
		reward_l.add_theme_font_size_override("font_size", 14)
		reward_l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.40))
		reward_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reward_l.custom_minimum_size = Vector2(120, 0)
		reward_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(reward_l)

	return panel

func _day_card(day: int, reward: Dictionary, streak: int, claimed: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(90, 130)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.55, 0.22) if claimed else (Color(0.30, 0.28, 0.10) if day == streak + 1 else Color(0.15, 0.15, 0.15))
	style.border_color = Color(1.0, 0.85, 0.1) if day == streak + 1 else (Color(0.3, 0.8, 0.3) if claimed else Color(0.3, 0.3, 0.3))
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var day_l := Label.new()
	day_l.text = "Day %d" % day
	day_l.add_theme_font_size_override("font_size", 13)
	day_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(day_l)

	var gold_l := Label.new()
	gold_l.text = "+%d\nGold" % reward.get("gold", 0)
	gold_l.add_theme_font_size_override("font_size", 14)
	gold_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(gold_l)

	var gem_l := Label.new()
	gem_l.text = "💎 %d" % reward.get("gems", 0)
	gem_l.add_theme_font_size_override("font_size", 13)
	gem_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(gem_l)

	if claimed:
		var ck := Label.new()
		ck.text = "✓"
		ck.add_theme_font_size_override("font_size", 22)
		ck.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		ck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ck)

	return panel

func _show_daily_popup() -> void:
	_daily_popup_shown = true
	if not GameState.can_claim_daily():
		return
	# Show gentle popup on title
	var popup := PanelContainer.new()
	popup.position = Vector2(700, 350)
	popup.size = Vector2(520, 280)
	_root.add_child(popup)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	popup.add_child(vb)

	var l := Label.new()
	l.text = "🎁 Daily Reward Available!\n Day %d of 7" % (GameState.daily_streak + 1)
	l.add_theme_font_size_override("font_size", 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)

	var btn := Button.new()
	btn.text = "CLAIM NOW"
	btn.custom_minimum_size = Vector2(400, 60)
	btn.pressed.connect(func():
		popup.queue_free()
		_show_screen(Screen.DAILY)
	)
	vb.add_child(btn)

	var skip := Button.new()
	skip.text = "Later"
	skip.pressed.connect(func(): popup.queue_free())
	vb.add_child(skip)

func _show_reward_popup(reward: Dictionary) -> void:
	var popup := _overlay_popup("REWARD CLAIMED!", Color(0.25, 0.22, 0.08, 0.95))
	var parts: Array = []
	if reward.get("gold", 0) > 0: parts.append("+%d Gold" % reward["gold"])
	if reward.get("gems", 0) > 0: parts.append("+%d 💎 Gems" % reward["gems"])
	if reward.get("xp", 0) > 0:   parts.append("+%d XP" % reward["xp"])

	var detail := Label.new()
	detail.text = "\n".join(parts)
	detail.add_theme_font_size_override("font_size", 28)
	detail.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.get_child(1).add_child(detail)

	get_tree().create_timer(2.5).timeout.connect(func(): popup.queue_free())

# ─────────────────────────────────────────────────────────────────────────────
# ACHIEVEMENTS
# ─────────────────────────────────────────────────────────────────────────────

func _build_achievements() -> void:
	_back_btn(func(): _show_screen(Screen.TITLE))
	var title := _header("ACHIEVEMENTS", VW * 0.5 - 140, 20)
	_root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(200, 110)
	scroll.size = Vector2(1520, 860)
	_root.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	scroll.add_child(vb)

	for ach_id in GameState.ACHIEVEMENTS:
		var ach: Dictionary = GameState.ACHIEVEMENTS[ach_id]
		var unlocked: bool = ach_id in GameState.unlocked_achievements
		var row := _achievement_row(ach["title"], ach["desc"], ach["xp"], unlocked)
		vb.add_child(row)

func _achievement_row(title: String, desc: String, xp: int, unlocked: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.28, 0.18) if unlocked else Color(0.15, 0.15, 0.15)
	style.border_color = Color(0.3, 0.8, 0.3) if unlocked else Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	var icon := Label.new()
	icon.text = "🏆" if unlocked else "🔒"
	icon.add_theme_font_size_override("font_size", 36)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var t_l := Label.new()
	t_l.text = title
	t_l.add_theme_font_size_override("font_size", 20)
	t_l.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.5, 0.5, 0.5))
	info.add_child(t_l)

	var d_l := Label.new()
	d_l.text = desc
	d_l.add_theme_font_size_override("font_size", 14)
	d_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(d_l)

	var xp_l := Label.new()
	xp_l.text = "+%d XP" % xp
	xp_l.add_theme_font_size_override("font_size", 14)
	xp_l.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	xp_l.custom_minimum_size = Vector2(100, 0)
	xp_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(xp_l)

	return panel

# ─────────────────────────────────────────────────────────────────────────────
# SETTINGS
# ─────────────────────────────────────────────────────────────────────────────

func _build_settings() -> void:
	_back_btn(func(): _show_screen(Screen.TITLE))
	var title := _header("SETTINGS", VW * 0.5 - 80, 20)
	_root.add_child(title)

	var vbox := _vbox(Vector2(710, 120), 500, 22)
	_root.add_child(vbox)

	_setting_toggle(vbox, "Sound Effects", GameState.sfx_on, func(v): GameState.sfx_on = v; GameState.save_game())
	_setting_toggle(vbox, "Music", GameState.music_on, func(v): GameState.music_on = v; GameState.save_game())
	_setting_toggle(vbox, "Haptics", GameState.haptics_on, func(v): GameState.haptics_on = v; GameState.save_game())

	_spacer(vbox, 24)

	var diff_lbl: Label = Label.new()
	diff_lbl.text = "DIFFICULTY"
	diff_lbl.add_theme_font_size_override("font_size", 22)
	diff_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.90))
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(diff_lbl)

	var diff_row: HBoxContainer = HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 14)
	vbox.add_child(diff_row)

	var diff_opts: Array = [
		["EASY",   "easy",   "Dumb AI, longer trail & preview"],
		["NORMAL", "normal", "Balanced — the default experience"],
		["HARD",   "hard",   "Short preview, no ghost trail"],
	]
	for opt in diff_opts:
		var d_label: String = str(opt[0])
		var d_key: String = str(opt[1])
		var d_tip: String = str(opt[2])
		var is_sel: bool = GameState.difficulty == d_key
		var db: Button = Button.new()
		db.text = d_label
		db.tooltip_text = d_tip
		db.custom_minimum_size = Vector2(152, 56)
		db.add_theme_font_size_override("font_size", 21)
		var ns: StyleBoxFlat = StyleBoxFlat.new()
		ns.bg_color = Color(0.20, 0.42, 0.20) if is_sel else Color(0.09, 0.13, 0.23)
		ns.border_color = Color(0.28, 0.90, 0.28) if is_sel else Color(0.30, 0.48, 0.88)
		ns.set_border_width_all(2)
		ns.set_corner_radius_all(10)
		ns.shadow_color = Color(0.28, 0.80, 0.28, 0.30) if is_sel else Color(0.18, 0.35, 0.80, 0.20)
		ns.shadow_size = 6 if is_sel else 4
		var hs: StyleBoxFlat = StyleBoxFlat.new()
		hs.bg_color = Color(0.16, 0.24, 0.42)
		hs.border_color = Color(0.55, 0.72, 1.0)
		hs.set_border_width_all(2)
		hs.set_corner_radius_all(10)
		db.add_theme_stylebox_override("normal", ns)
		db.add_theme_stylebox_override("hover", hs)
		db.add_theme_stylebox_override("focus", ns)
		db.add_theme_color_override("font_color", Color(0.70, 1.0, 0.70) if is_sel else Color(0.82, 0.90, 1.0))
		db.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		db.pressed.connect(func():
			GameState.difficulty = d_key
			GameState.save_game()
			_show_screen(Screen.SETTINGS)
		)
		diff_row.add_child(db)

	var diff_desc: Label = Label.new()
	var _di: int = maxi(0, ["easy", "normal", "hard"].find(GameState.difficulty))
	diff_desc.text = str(diff_opts[_di][2])
	diff_desc.add_theme_font_size_override("font_size", 15)
	diff_desc.add_theme_color_override("font_color", Color(0.60, 0.68, 0.80))
	diff_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(diff_desc)

	_spacer(vbox, 30)

	var rank_l := Label.new()
	rank_l.text = "Rank: %d   XP: %d" % [GameState.player_rank, GameState.xp]
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_l.add_theme_font_size_override("font_size", 20)
	vbox.add_child(rank_l)

	var prog := ProgressBar.new()
	prog.custom_minimum_size = Vector2(500, 30)
	prog.value = GameState.xp_progress_in_rank() * 100
	prog.max_value = 100
	prog.show_percentage = false
	vbox.add_child(prog)

	_spacer(vbox, 30)

	var reset_btn := Button.new()
	reset_btn.text = "RESET PROGRESS (Hold 3s)"
	reset_btn.custom_minimum_size = Vector2(500, 55)
	reset_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	var hold_timer := 0.0
	reset_btn.button_down.connect(func(): hold_timer = 0.0)
	vbox.add_child(reset_btn)

func _setting_toggle(parent: Control, label_text: String, current: bool, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(l)

	var btn := CheckButton.new()
	btn.button_pressed = current
	btn.toggled.connect(callback)
	hbox.add_child(btn)

# ─────────────────────────────────────────────────────────────────────────────
# UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# HOW TO PLAY
# ─────────────────────────────────────────────────────────────────────────────

func _build_how_to_play() -> void:
	_back_btn(func(): _show_screen(Screen.TITLE))
	var title := _header("HOW TO PLAY", VW * 0.5 - 200, 20)
	_root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(280, 105)
	scroll.size = Vector2(1360, 880)
	_root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	_htp_section(content, "OBJECTIVE", [
		"Destroy the enemy castle before it destroys yours!",
		"Each player fires one bomb per turn. The AI fires back — play smart.",
	])
	_htp_section(content, "CONTROLS", [
		"Drag from the slingshot to aim. Pull further for more power.",
		"A yellow dotted arc previews your trajectory.",
		"The ring at the base shows pull strength: green / orange / red.",
		"Release to fire. Tap SPECIAL mid-flight to trigger a bomb's ability.",
	])
	_htp_section(content, "BOMB TYPES", [
		"Standard     — Reliable all-round explosion.",
		"Heavy          — Slow but deals massive damage and knockback.",
		"Splitter        — Splits into 3 bombs on contact (or use SPECIAL).",
		"Cluster         — Bursts into 8 mini-bombs on impact.",
		"Shockwave  — Huge blast radius, great for spreading damage.",
		"Freeze          — Encases blocks in ice, stopping them briefly.",
		"Fire               — Leaves a burning zone that ignites wood blocks.",
		"Laser            — Fires a horizontal beam piercing multiple blocks.",
		"Bouncer       — Bounces up to 6 times before exploding.",
		"Driller          — Drills through up to 8 blocks before detonating.",
		"Lightning       — Chains electric damage to nearby blocks.",
		"Magnet        — Pulls all nearby blocks toward the blast point.",
		"Ghost           — Phases through blocks; only detonates on ground.",
		"Sticky           — Sticks on first contact, explodes after 2.5 sec.",
		"Vortex           — Stops mid-air and sucks blocks inward (SPECIAL).",
		"Nuke             — Devastating wide-area destruction. Use wisely.",
	])
	_htp_section(content, "BLOCK TYPES", [
		"Wood          — Common, can catch fire.",
		"Stone          — Tough and fire-resistant.",
		"Glass           — Fragile — one good hit shatters it.",
		"Metal           — Very hard to destroy. Use heavy bombs.",
		"Barrel          — Explodes in a chain when destroyed!",
		"Explosive Crate — Big blast that chains to nearby blocks.",
		"Ice Block      — Slides when hit. Shatters with an ice burst.",
		"Sandbag      — Extremely dense, absorbs huge impact.",
		"Reinforced   — Near-indestructible. Reserved for boss levels.",
	])
	_htp_section(content, "STARS & SCORING", [
		"Destroy the enemy castle to win the level.",
		"3 Stars — Use 40% or fewer of your available bombs.",
		"2 Stars — Use 75% or fewer bombs.",
		"1 Star  — Any victory.",
		"Earn Gold and XP for completing levels. Gold unlocks new bombs in the Shop.",
	])
	_htp_section(content, "TIPS", [
		"Target Barrels and Explosive Crates for chain reactions!",
		"Wind shifts your arc left or right — check the HUD indicator.",
		"Buy upgrades in the Shop to strengthen your castle's materials.",
		"Metal and Reinforced blocks require Heavy, Nuke, or Laser bombs.",
		"Stars unlock higher zones. Aim for 3-star clears early on.",
	])

func _htp_section(parent: Control, heading: String, lines: Array) -> void:
	var hdr: Label = Label.new()
	hdr.text = heading
	hdr.add_theme_font_size_override("font_size", 24)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	parent.add_child(hdr)

	for line in lines:
		var lbl: Label = Label.new()
		lbl.text = "  " + str(line)
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(0.84, 0.84, 0.90))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(lbl)

	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	parent.add_child(sp)

func _show_daily_popup_check() -> void:
	if GameState.can_claim_daily():
		_show_daily_popup()

func _vbox(pos: Vector2, width: float, sep: int) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.position = pos
	vb.custom_minimum_size = Vector2(width, 0)
	vb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_theme_constant_override("separation", sep)
	return vb

func _header(text: String, x: float, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", 42)
	l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.50))
	return l

func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.8, 0.75, 0.45))
	return l

func _label_row(items: Array) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	for item in items:
		var l := Label.new()
		l.text = str(item)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.65))
		hbox.add_child(l)
	return hbox

func _add_btn(parent: Control, text: String, height: int, cb: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(520, height)
	btn.add_theme_font_size_override("font_size", int(height * 0.46))

	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = Color(0.09, 0.13, 0.23)
	n.border_color = Color(0.30, 0.48, 0.88)
	n.set_border_width_all(2)
	n.set_corner_radius_all(12)
	n.shadow_color = Color(0.18, 0.35, 0.80, 0.28)
	n.shadow_size = 5

	var h: StyleBoxFlat = StyleBoxFlat.new()
	h.bg_color = Color(0.16, 0.24, 0.42)
	h.border_color = Color(0.55, 0.72, 1.0)
	h.set_border_width_all(2)
	h.set_corner_radius_all(12)
	h.shadow_color = Color(0.30, 0.55, 1.0, 0.42)
	h.shadow_size = 8

	var p: StyleBoxFlat = StyleBoxFlat.new()
	p.bg_color = Color(0.22, 0.32, 0.55)
	p.border_color = Color(0.65, 0.82, 1.0)
	p.set_border_width_all(2)
	p.set_corner_radius_all(12)

	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("focus", n)
	btn.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.72, 0.88, 1.0))
	btn.pressed.connect(cb)
	parent.add_child(btn)

func _spacer(parent: Control, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

func _back_btn(cb: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = "< BACK"
	btn.position = Vector2(18, 18)
	btn.size = Vector2(130, 50)

	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = Color(0.09, 0.11, 0.20)
	n.border_color = Color(0.28, 0.42, 0.72)
	n.set_border_width_all(2)
	n.set_corner_radius_all(10)

	var h: StyleBoxFlat = StyleBoxFlat.new()
	h.bg_color = Color(0.14, 0.20, 0.36)
	h.border_color = Color(0.50, 0.68, 1.0)
	h.set_border_width_all(2)
	h.set_corner_radius_all(10)

	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("focus", n)
	btn.add_theme_color_override("font_color", Color(0.70, 0.82, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(cb)
	_root.add_child(btn)

func _overlay_popup(title_text: String, bg_col: Color) -> CanvasLayer:
	var canvas := CanvasLayer.new()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = bg_col
	canvas.add_child(bg)
	var vb := VBoxContainer.new()
	vb.position = Vector2(760, 380)
	vb.size = Vector2(400, 300)
	vb.add_theme_constant_override("separation", 20)
	canvas.add_child(vb)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	add_child(canvas)
	return canvas
