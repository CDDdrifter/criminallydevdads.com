extends Control

const WORLD_SCENE := "res://scenes/World.tscn"

@onready var _vbox: VBoxContainer       = $VBoxContainer
@onready var new_game_button: Button    = $VBoxContainer/NewGameButton
@onready var continue_button: Button    = $VBoxContainer/ContinueButton
@onready var quit_button: Button        = $VBoxContainer/QuitButton
@onready var _bg_texture: TextureRect   = $Background


var _first_play_btn: Button = null
var _settings_panel: PanelContainer = null
var _class_panel: Control = null

# ── Admin unlock: tap the sun 3× within 2.5 s on the title screen ──────────
const _ADMIN_TAPS_NEEDED : int   = 3
const _ADMIN_TAP_WINDOW  : float = 2.5
const _ADMIN_SUN_X_FRAC  : float = 0.82
const _ADMIN_SUN_Y_FRAC  : float = 0.10
const _ADMIN_SUN_RADIUS  : float = 48.0
var _admin_taps  : int   = 0
var _admin_timer : float = 0.0

func _ready() -> void:
	continue_button.visible = false
	new_game_button.visible = false

	# Replace the static screenshot with the animated background.
	_bg_texture.visible = false
	var bg := TitleBackground.new()
	bg.z_index = -1
	add_child(bg)
	move_child(bg, 0)

	# Semi-transparent dark panel behind the menu buttons so they're legible
	# over the animated scene.  Anchored to match the VBoxContainer layout.
	var menu_panel := Panel.new()
	var mp_style := StyleBoxFlat.new()
	mp_style.bg_color = Color(0.04, 0.04, 0.08, 0.72)
	mp_style.corner_radius_top_left     = 10
	mp_style.corner_radius_top_right    = 10
	mp_style.corner_radius_bottom_left  = 10
	mp_style.corner_radius_bottom_right = 10
	mp_style.border_color = Color(0.55, 0.60, 0.70, 0.50)
	mp_style.set_border_width_all(1)
	menu_panel.add_theme_stylebox_override("panel", mp_style)
	# Centre the panel to match the VBox (offsets ±190 / ±240 give a small margin)
	menu_panel.anchor_left   = 0.5
	menu_panel.anchor_top    = 0.5
	menu_panel.anchor_right  = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left   = -190
	menu_panel.offset_top    = -240
	menu_panel.offset_right  =  190
	menu_panel.offset_bottom =  240
	add_child(menu_panel)
	move_child(menu_panel, get_child_count() - 2)  # draw just before _vbox

	for slot in SaveLoad.MAX_SLOTS:
		_build_slot_row(slot)

	# "Select Character" button — lets the player choose their class/color.
	var class_btn := Button.new()
	class_btn.text = "Select Character"
	class_btn.focus_mode = Control.FOCUS_ALL
	class_btn.pressed.connect(_show_class_picker)
	_vbox.add_child(class_btn)
	_vbox.move_child(class_btn, _vbox.get_child_count() - 2)

	quit_button.pressed.connect(_on_quit_pressed)

	if _first_play_btn != null:
		_first_play_btn.grab_focus()
	else:
		quit_button.grab_focus()

	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	if _admin_taps > 0:
		_admin_timer -= delta
		if _admin_timer <= 0.0:
			_admin_taps = 0


func _input(ev: InputEvent) -> void:
	# Only handle taps while no sub-panel is open (settings / class picker)
	if _settings_panel != null or _class_panel != null:
		return

	var is_tap := false
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		is_tap = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif ev is InputEventScreenTouch:
		is_tap = (ev as InputEventScreenTouch).pressed
	if not is_tap:
		return

	var pos: Vector2
	if ev is InputEventScreenTouch:
		pos = (ev as InputEventScreenTouch).position
	else:
		pos = (ev as InputEventMouseButton).position

	var vp := get_viewport().get_visible_rect().size
	var sun_center := Vector2(vp.x * _ADMIN_SUN_X_FRAC, vp.y * _ADMIN_SUN_Y_FRAC)
	if pos.distance_to(sun_center) > _ADMIN_SUN_RADIUS:
		return

	_admin_taps += 1
	_admin_timer = _ADMIN_TAP_WINDOW

	if _admin_taps >= _ADMIN_TAPS_NEEDED:
		_admin_taps = 0
		GameData.admin_mode_unlocked = true
		# Brief visual flash to confirm unlock
		var flash := ColorRect.new()
		flash.color = Color(0.7, 0.4, 1.0, 0.35)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tween := create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.4)
		tween.tween_callback(flash.queue_free)


# ---------------------------------------------------------------------------
# Slot row builder
# ---------------------------------------------------------------------------

func _build_slot_row(slot: int) -> void:
	var summary: Dictionary = SaveLoad.get_slot_summary(slot)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Play / New button
	var play_btn := Button.new()
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if summary.get("exists", false):
		play_btn.text = "[PLAY]  Slot %d  -  Day %d" % [slot + 1, summary.get("day", 1)]
	else:
		play_btn.text = "[NEW]  Slot %d  -  New World" % (slot + 1)
	play_btn.pressed.connect(_on_slot_play.bind(slot))
	play_btn.focus_mode = Control.FOCUS_ALL
	hbox.add_child(play_btn)
	if _first_play_btn == null:
		_first_play_btn = play_btn

	# Delete button (only shown when save exists)
	if summary.get("exists", false):
		var del_btn := Button.new()
		del_btn.text = "DEL"
		del_btn.custom_minimum_size = Vector2(50, 0)
		del_btn.tooltip_text = "Delete Slot %d" % (slot + 1)
		del_btn.pressed.connect(_on_slot_delete.bind(slot, hbox, play_btn, del_btn))
		hbox.add_child(del_btn)

	# Insert before Quit button
	_vbox.add_child(hbox)
	_vbox.move_child(hbox, _vbox.get_child_count() - 2)


func _on_slot_play(slot: int) -> void:
	SaveLoad.current_slot = slot
	if not SaveLoad.has_save(slot):
		# New world — reset all per-world state so nothing leaks from a previous session.
		GameData.reset_for_new_game()
		SaveLoad.clear_chunk_cache()
		GameData.world_seed = randi()
		_show_world_settings()
	else:
		# Continuing an existing save — go straight to world.
		_go_to_world()


func _on_slot_delete(slot: int, hbox: HBoxContainer, play_btn: Button, del_btn: Button) -> void:
	SaveLoad.delete_save(slot)
	play_btn.text = "[NEW]  Slot %d  -  New World" % (slot + 1)
	del_btn.queue_free()
	# Restore controller focus so the cursor doesn't disappear.
	play_btn.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


# ---------------------------------------------------------------------------
# World Settings panel
# ---------------------------------------------------------------------------

func _show_world_settings() -> void:
	_vbox.visible = false

	var vp := get_viewport().get_visible_rect().size
	var panel_w: float = min(460.0, vp.x * 0.92)
	var panel_h: float = min(vp.y * 0.88, 540.0)

	# Outer panel — fixed size, centered on screen.
	_settings_panel = PanelContainer.new()
	_settings_panel.size = Vector2(panel_w, panel_h)
	_settings_panel.position = (vp - Vector2(panel_w, panel_h)) * 0.5
	add_child(_settings_panel)

	# Outer VBox splits into: scroll area (grows) + button row (fixed).
	var outer_vb := VBoxContainer.new()
	outer_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_vb.add_theme_constant_override("separation", 0)
	_settings_panel.add_child(outer_vb)

	# ── Scrollable options ────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vb.add_child(scroll)
	GameData.make_scroll_draggable(scroll)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	vb.add_theme_constant_override("margin_left", 12)
	vb.add_theme_constant_override("margin_right", 12)
	scroll.add_child(vb)

	var title := Label.new()
	title.text = "World Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	vb.add_child(HSeparator.new())

	# ── Game description ──────────────────────────────────────────────────────
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 70)
	desc.text = (
		"[b]TerraCraft[/b] — every world hides something worth digging for. "
		+ "Punch trees, forge iron, hunt monsters, and build a home before the sun sets. "
		+ "Explore [color=88cc44]ancient forests[/color], [color=dddd44]scorched deserts[/color], "
		+ "[color=88ccff]frozen tundras[/color], and [color=44bb44]dense jungles[/color]. "
		+ "Delve into caves for ore — or stumble upon a dungeon and find out what lurks at the bottom. "
		+ "How far you go is entirely up to you."
	)
	vb.add_child(desc)
	vb.add_child(HSeparator.new())

	var wt_label := Label.new()
	wt_label.text = "World Type"
	vb.add_child(wt_label)
	var wt_opt := OptionButton.new()
	wt_opt.focus_mode = Control.FOCUS_ALL
	for t in ["Normal", "Flat", "Island", "Underground"]:
		wt_opt.add_item(t)
	vb.add_child(wt_opt)

	var ws_label := Label.new()
	ws_label.text = "World Size"
	vb.add_child(ws_label)
	var ws_opt := OptionButton.new()
	ws_opt.focus_mode = Control.FOCUS_ALL
	for s in ["Small", "Medium", "Large", "Infinite"]:
		ws_opt.add_item(s)
	ws_opt.selected = 3
	vb.add_child(ws_opt)

	# ── Creative Mode ────────────────────────────────────────────────────────
	vb.add_child(HSeparator.new())
	var cm_cb := CheckButton.new()
	cm_cb.text = "Creative Mode  (double-jump to fly, all blocks available)"
	cm_cb.button_pressed = false
	cm_cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm_cb.focus_mode = Control.FOCUS_ALL
	vb.add_child(cm_cb)
	vb.add_child(HSeparator.new())

	var st_label := Label.new()
	st_label.text = "Structures"
	vb.add_child(st_label)

	var struct_checks: Dictionary = {}
	var last_cb: CheckButton = null
	var struct_keys: Array = [
		["villages",      "Villages"],
		["towers",        "Stone Towers"],
		["temples",       "Desert Temples"],
		["ruins",         "Forest Ruins"],
		["towns",         "Town Buildings"],
		["blacksmith",    "Blacksmiths"],
		["library",       "Libraries"],
		["bunker",        "Underground Bunkers"],
		["watchtower",    "Watchtowers"],
		["market_stall",  "Market Stalls"],
		["graveyard",     "Graveyards"],
		["snow_cabin",    "Snow Cabins"],
		["desert_outpost","Desert Outposts"],
		["mine_entrance", "Mine Entrances"],
		["abandoned_farm","Abandoned Farms"],
		["dungeon",       "Dungeons"],
		["castle",        "Castles"],
	]
	for pair in struct_keys:
		var cb := CheckButton.new()
		cb.button_pressed = true
		cb.text = pair[1]
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.focus_mode = Control.FOCUS_ALL
		vb.add_child(cb)
		struct_checks[pair[0]] = cb
		last_cb = cb

	# ── Difficulty selector ──────────────────────────────────────────────
	vb.add_child(HSeparator.new())
	var diff_label := Label.new()
	diff_label.text = "Difficulty"
	vb.add_child(diff_label)
	var diff_opt := OptionButton.new()
	diff_opt.focus_mode = Control.FOCUS_ALL
	for d in ["Easy", "Normal", "Hard"]:
		diff_opt.add_item(d)
	diff_opt.selected = 1  # Normal by default
	vb.add_child(diff_opt)

	# ── Pinned button row — always visible at the bottom ─────────────────
	var sep := HSeparator.new()
	outer_vb.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.custom_minimum_size = Vector2(0, 48)
	outer_vb.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.focus_mode = Control.FOCUS_ALL
	btn_row.add_child(back_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Create World"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.focus_mode = Control.FOCUS_ALL
	btn_row.add_child(confirm_btn)

	# Controller focus chain: wt_opt → ws_opt → checkboxes → back/confirm
	wt_opt.focus_neighbor_bottom = ws_opt.get_path() if ws_opt.is_inside_tree() else ^""
	back_btn.focus_neighbor_right = confirm_btn.get_path() if confirm_btn.is_inside_tree() else ^""
	confirm_btn.focus_neighbor_left = back_btn.get_path() if back_btn.is_inside_tree() else ^""

	back_btn.pressed.connect(_on_settings_back)
	confirm_btn.pressed.connect(_on_settings_confirm.bind(wt_opt, ws_opt, struct_checks, cm_cb, diff_opt))

	# Start focus on Create World so controller can press it immediately.
	confirm_btn.grab_focus()


func _on_settings_back() -> void:
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null
	_vbox.visible = true
	if _first_play_btn != null:
		_first_play_btn.grab_focus()


func _on_settings_confirm(wt_opt: OptionButton, ws_opt: OptionButton,
		struct_checks: Dictionary, cm_cb: CheckButton,
		diff_opt: OptionButton) -> void:
	# Save settings into GameData.
	var type_map := {0: "normal", 1: "flat", 2: "island", 3: "underground"}
	GameData.world_type = type_map.get(wt_opt.selected, "normal")

	var size_map := {0: "small", 1: "medium", 2: "large", 3: "infinite"}
	GameData.world_size = size_map.get(ws_opt.selected, "infinite")

	GameData.creative_mode = cm_cb.button_pressed

	var diff_map := {0: "easy", 1: "normal", 2: "hard"}
	GameData.difficulty = diff_map.get(diff_opt.selected, "normal")
	# Scale damage multiplier: easy=0.5×, normal=1.0×, hard=2.0×
	match GameData.difficulty:
		"easy":   GameData.player_damage_mult = 0.5
		"normal": GameData.player_damage_mult = 1.0
		"hard":   GameData.player_damage_mult = 2.0

	for key in struct_checks:
		GameData.structures_enabled[key] = struct_checks[key].button_pressed

	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null

	_go_to_world()


func _go_to_world() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


# ---------------------------------------------------------------------------
# Character / Class Picker
# Shows all 20 player classes.  Locked classes show unlock requirements.
# Selecting an unlocked class writes GameData.player_class_index.
# ---------------------------------------------------------------------------

func _show_class_picker() -> void:
	_vbox.visible = false
	var vp := get_viewport().get_visible_rect().size

	_class_panel = Control.new()
	_class_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Stop all input here so touches can't bleed through to the buttons behind the panel.
	_class_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_class_panel)

	# Dark backdrop.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.80)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_class_panel.add_child(bg)

	# Centered panel.
	var panel_w := minf(580.0, vp.x * 0.96)
	var panel_h := minf(540.0, vp.y * 0.92)
	var panel := PanelContainer.new()
	panel.size = Vector2(panel_w, panel_h)
	panel.position = (vp - panel.size) * 0.5
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	ps.corner_radius_top_left = 10; ps.corner_radius_top_right = 10
	ps.corner_radius_bottom_left = 10; ps.corner_radius_bottom_right = 10
	ps.border_color = Color(0.5, 0.5, 0.8); ps.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", ps)
	_class_panel.add_child(panel)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	# Title row.
	var margin_top := MarginContainer.new()
	margin_top.add_theme_constant_override("margin_left", 12)
	margin_top.add_theme_constant_override("margin_right", 12)
	margin_top.add_theme_constant_override("margin_top", 10)
	outer.add_child(margin_top)
	var title := Label.new()
	title.text = "Select Character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	margin_top.add_child(title)

	# Kill stats row.
	var stats_lbl := Label.new()
	stats_lbl.text = "Kills: %d   Elite Kills: %d   Boss Kills: %d" % [
		GameData.total_enemy_kills,
		GameData.elite_kills,
		GameData.boss_kills
	]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	outer.add_child(stats_lbl)

	outer.add_child(HSeparator.new())

	# Scrollable class card grid.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	GameData.make_scroll_draggable(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var grid_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		grid_margin.add_theme_constant_override("margin_" + side, 8)
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.add_child(grid)
	scroll.add_child(grid_margin)

	var first_btn: Button = null
	var cards: Array = []   # all card buttons, parallel to PLAYER_CLASSES

	for i in range(GameData.PLAYER_CLASSES.size()):
		var cls: Dictionary = GameData.PLAYER_CLASSES[i]
		var is_unlocked: bool = GameData.unlocked_classes.size() > i and GameData.unlocked_classes[i]

		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 72)
		card.focus_mode = Control.FOCUS_ALL
		card.disabled = not is_unlocked

		# Build label text.
		var card_text := "[%s]\n%s\n" % [cls["name"], cls["id"].replace("_", " ").capitalize()]
		if is_unlocked:
			card_text += "HP %.0f%%  SPD %.0f%%  DMG %.0f%%" % [
				cls["health_mult"] * 100.0,
				cls["speed_mult"] * 100.0,
				cls["damage_mult"] * 100.0
			]
		else:
			# Show unlock requirements.
			var req_parts: Array = []
			if int(cls["unlock_kills"]) > 0:
				req_parts.append("%d kills" % cls["unlock_kills"])
			if int(cls["unlock_elites"]) > 0:
				req_parts.append("%d elite kills" % cls["unlock_elites"])
			if int(cls["unlock_bosses"]) > 0:
				req_parts.append("%d boss kills" % cls["unlock_bosses"])
			card_text += "LOCKED — " + ", ".join(req_parts)

		card.text = card_text
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT

		cards.append(card)
		grid.add_child(card)
		if first_btn == null and is_unlocked:
			first_btn = card

	# Apply initial color tints and connect press signals now that all cards exist.
	for i in cards.size():
		var cls: Dictionary = GameData.PLAYER_CLASSES[i]
		var is_unlocked: bool = GameData.unlocked_classes.size() > i and GameData.unlocked_classes[i]
		_tint_class_card(cards[i], cls, is_unlocked, i == GameData.player_class_index)
		if is_unlocked:
			var idx: int = i
			cards[i].pressed.connect(func() -> void: _on_class_selected(idx, cards))

	# Close button.
	outer.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "Done"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.pressed.connect(_close_class_picker)
	outer.add_child(close_btn)

	if first_btn != null:
		first_btn.grab_focus()
	else:
		close_btn.grab_focus()


## Highlight the chosen card without closing the panel — "Done" closes it.
func _on_class_selected(index: int, cards: Array) -> void:
	GameData.player_class_index = index
	for i in cards.size():
		if i >= GameData.PLAYER_CLASSES.size():
			break
		var cls: Dictionary = GameData.PLAYER_CLASSES[i]
		var is_unlocked: bool = GameData.unlocked_classes.size() > i and GameData.unlocked_classes[i]
		_tint_class_card(cards[i], cls, is_unlocked, i == index)


func _tint_class_card(card: Button, cls: Dictionary, is_unlocked: bool, selected: bool) -> void:
	if not is_unlocked:
		card.modulate = Color(0.45, 0.45, 0.50)
	elif selected:
		card.modulate = cls["color"].lightened(0.4)
	else:
		card.modulate = cls["color"].lerp(Color.WHITE, 0.55)


func _close_class_picker() -> void:
	if _class_panel != null:
		_class_panel.queue_free()
		_class_panel = null
	# Defer showing the main vbox so the touch that closed this panel
	# doesn't bleed into the newly-visible main menu buttons.
	call_deferred("_restore_main_menu")


func _restore_main_menu() -> void:
	_vbox.visible = true
	if _first_play_btn != null:
		_first_play_btn.grab_focus()
