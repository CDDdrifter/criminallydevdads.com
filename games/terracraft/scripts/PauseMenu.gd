extends CanvasLayer

# PauseMenu.gd
# Full pause menu: Resume, How To Play, Options (volume + controls), Main Menu, Quit.
# Add as a CanvasLayer child of World. Opens with Escape / gamepad Start.
#
# HOW TO ADD A NEW OPTIONS FIELD:
#   1. Create a Control in _build_options_panel().
#   2. Read/write the value from GameData or a ProjectSettings key.
#   3. Add a "reset to defaults" case in _on_reset_defaults().
#
# HOW TO ADD A NEW PAGE:
#   1. Build it in a new _build_XYZ_panel() function.
#   2. Add a button in _build_main_buttons() that calls _show_page(xyz_panel).

# ── Constants ──────────────────────────────────────────────────────────────
const PANEL_W   := 520.0
const PANEL_H   := 560.0
const BTN_H     := 48.0
const BTN_GAP   := 10.0

# Background dim overlay
var _dim: ColorRect

# Pages — only one visible at a time
var _main_panel: Panel
var _options_panel: Panel
var _how_panel: Panel

# Options references we need later
var _volume_slider: HSlider
var _zoom_slider: HSlider
var _fps_check: CheckButton
var _autosave_btn: OptionButton
var _controls_tabs: TabContainer

# Current active page (used by Back button)
var _active_page: Panel = null

# Controller focus — first focusable control on each page
var _main_first_btn: Button
var _opts_first_ctrl: Control
var _how_back_btn: Button

# ── Key rebinding state ─────────────────────────────────────────────────────
# action_id → current KeyboardKey constant (or -1 = use default)
var _custom_binds: Dictionary = {}
var _rebind_action: String = ""       # action being rebound ("" = none)
var _rebind_timer: float   = 0.0     # countdown seconds
var _rebind_prompt_lbl: Label = null  # overlay label showing "Press a key…"
var _rebind_row_btns: Dictionary = {} # action_id → Button (so we can update label)

# Actions exposed for rebinding: [action_id, display_name, default_key_label]
const REBINDABLE_ACTIONS: Array = [
	["move_left",     "Move Left",          "A"],
	["move_right",    "Move Right",         "D"],
	["jump",          "Jump",               "Space"],
	["sprint",        "Sprint",             "Shift"],
	["dash",          "Dash",               "Z"],
	["block",         "Block / Parry",      "Q"],
	["combat_dash",   "Combat Dash",        "X"],
	["mine",          "Mine / Attack",      "LClick"],
	["place_block",   "Place Block",        "RClick"],
	["flip_block",    "Flip Block",         "R"],
	["interact",      "Interact",           "F"],
	["ui_open",       "Open Inventory",     "E"],
	["hotbar_prev",   "Hotbar Prev",        "WheelUp"],
	["hotbar_next",   "Hotbar Next",        "WheelDown"],
]


# ═══════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Layer above HUD (5) and touch controls (6) so menu is always on top.
	layer = 20
	# PROCESS_MODE_ALWAYS so the menu can receive "pause" input even while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_dim()
	_build_main_panel()
	_build_options_panel()
	_build_how_panel()

	visible = false


func _process(delta: float) -> void:
	if _rebind_action == "":
		return
	_rebind_timer -= delta
	if _rebind_prompt_lbl:
		_rebind_prompt_lbl.text = "Press a key for  \"%s\"\n%.0f seconds…" % [_rebind_action.replace("_", " ").capitalize(), maxf(_rebind_timer, 0.0)]
		_rebind_prompt_lbl.reset_size()
		var vp := get_viewport().get_visible_rect().size
		_rebind_prompt_lbl.position = (vp - _rebind_prompt_lbl.size) / 2.0
	if _rebind_timer <= 0.0:
		_cancel_rebind()


func _input(event: InputEvent) -> void:
	# Capture key/mouse-button presses while waiting for a rebind
	if _rebind_action != "":
		# Cancel on Escape
		if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
			return
		# Accept any key or mouse button press (not release, not echo)
		if event is InputEventKey and event.pressed and not event.is_echo():
			var ev := InputEventKey.new()
			ev.physical_keycode = event.physical_keycode
			ev.pressed = true
			_finish_rebind(ev)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			var ev := InputEventMouseButton.new()
			ev.button_index = event.button_index
			ev.pressed = true
			_finish_rebind(ev)
			get_viewport().set_input_as_handled()
			return
		# Swallow all other input while waiting
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	# InputEvent has is_action_pressed(), NOT is_action_just_pressed() (that's Input singleton only).
	# is_echo() filters out key-repeat events so holding Escape doesn't toggle repeatedly.
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	if visible:
		# Only ESC from the main page actually closes; sub-pages go back.
		if _active_page == _main_panel:
			_close()
		else:
			_show_main()
	else:
		_open()
	get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════

func _open() -> void:
	visible = true
	get_tree().paused = true
	_show_main()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _show_main() -> void:
	_set_page(_main_panel)
	if _main_first_btn:
		_main_first_btn.grab_focus()

func _show_options() -> void:
	_set_page(_options_panel)
	if _opts_first_ctrl:
		_opts_first_ctrl.grab_focus()

func _show_how_to_play() -> void:
	_set_page(_how_panel)
	if _how_back_btn:
		_how_back_btn.grab_focus()

func _set_page(page: Panel) -> void:
	for p in [_main_panel, _options_panel, _how_panel]:
		if p:
			p.visible = (p == page)
	_active_page = page


# ═══════════════════════════════════════════════════════════════════════════
# UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════

func _build_dim() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)


func _panel_base() -> Panel:
	# Returns a centered, styled Panel and adds it as a child.
	var vp := get_viewport().get_visible_rect().size
	var p := Panel.new()
	p.size = Vector2(PANEL_W, PANEL_H)
	p.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	st.corner_radius_top_left    = 10
	st.corner_radius_top_right   = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.border_color = Color(0.4, 0.4, 0.55, 1.0)
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	add_child(p)
	return p


func _title_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(PANEL_W, 40)
	lbl.position = Vector2(0, 12)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.7))
	parent.add_child(lbl)


func _big_button(parent: Control, label: String, y: float, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size = Vector2(PANEL_W - 80, BTN_H)
	btn.position = Vector2(40, y)
	btn.add_theme_font_size_override("font_size", 17)
	btn.focus_mode = Control.FOCUS_ALL   # controller can tab/D-pad to this button

	var st := StyleBoxFlat.new()
	st.bg_color = Color(color.r, color.g, color.b, 0.85)
	st.corner_radius_top_left    = 6
	st.corner_radius_top_right   = 6
	st.corner_radius_bottom_left = 6
	st.corner_radius_bottom_right = 6
	st.border_color = Color(1, 1, 1, 0.25)
	st.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", st)

	var st_hov := st.duplicate() as StyleBoxFlat
	st_hov.bg_color = Color(color.r + 0.1, color.g + 0.1, color.b + 0.1, 0.95)
	btn.add_theme_stylebox_override("hover", st_hov)

	# Bright yellow border so the controller user can see which button is focused.
	var st_focus := st.duplicate() as StyleBoxFlat
	st_focus.border_color = Color(1.0, 0.95, 0.2, 1.0)
	st_focus.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", st_focus)

	parent.add_child(btn)
	return btn


# ─── MAIN PAGE ──────────────────────────────────────────────────────────────

func _build_main_panel() -> void:
	_main_panel = _panel_base()
	_title_label(_main_panel, "PAUSED")

	var y := 62.0
	var resume_btn := _big_button(_main_panel, "Resume",        y, Color(0.15, 0.50, 0.20)); y += BTN_H + BTN_GAP
	var how_btn    := _big_button(_main_panel, "How to Play",   y, Color(0.15, 0.30, 0.60)); y += BTN_H + BTN_GAP
	var opt_btn    := _big_button(_main_panel, "Options",       y, Color(0.35, 0.25, 0.55)); y += BTN_H + BTN_GAP
	var menu_btn   := _big_button(_main_panel, "Main Menu",     y, Color(0.45, 0.30, 0.10)); y += BTN_H + BTN_GAP
	var quit_btn   := _big_button(_main_panel, "Quit Game",     y, Color(0.55, 0.10, 0.10))

	resume_btn.pressed.connect(_close)
	how_btn.pressed.connect(_show_how_to_play)
	opt_btn.pressed.connect(_show_options)
	menu_btn.pressed.connect(_go_main_menu)
	quit_btn.pressed.connect(_quit_game)

	# Chain D-pad up/down navigation between buttons.
	var btns: Array[Button] = [resume_btn, how_btn, opt_btn, menu_btn, quit_btn]
	for i in btns.size():
		var prev := btns[(i - 1 + btns.size()) % btns.size()]
		var next := btns[(i + 1) % btns.size()]
		btns[i].focus_neighbor_top    = prev.get_path()
		btns[i].focus_neighbor_bottom = next.get_path()

	_main_first_btn = resume_btn


# ─── OPTIONS PAGE ───────────────────────────────────────────────────────────

func _build_options_panel() -> void:
	_options_panel = _panel_base()
	_options_panel.visible = false
	_title_label(_options_panel, "Options")

	# --- Game settings section ---
	var section_lbl := Label.new()
	section_lbl.text = "Game Settings"
	section_lbl.position = Vector2(24, 58)
	section_lbl.add_theme_font_size_override("font_size", 14)
	section_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_options_panel.add_child(section_lbl)

	# Volume
	var vol_lbl := Label.new()
	vol_lbl.text = "Master Volume"
	vol_lbl.position = Vector2(24, 86)
	_options_panel.add_child(vol_lbl)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.value = _get_volume()
	_volume_slider.size = Vector2(260, 24)
	_volume_slider.position = Vector2(170, 88)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_options_panel.add_child(_volume_slider)

	var vol_val := Label.new()
	vol_val.name = "VolumeVal"
	vol_val.text = "%d%%" % int(_volume_slider.value)
	vol_val.position = Vector2(442, 86)
	_options_panel.add_child(vol_val)
	_volume_slider.value_changed.connect(func(v): vol_val.text = "%d%%" % int(v))

	# Camera zoom
	var zoom_lbl := Label.new()
	zoom_lbl.text = "Camera Zoom"
	zoom_lbl.position = Vector2(24, 124)
	_options_panel.add_child(zoom_lbl)

	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 0.15
	_zoom_slider.max_value = 4.0
	_zoom_slider.step = 0.05
	_zoom_slider.value = _get_zoom()
	_zoom_slider.size = Vector2(260, 24)
	_zoom_slider.position = Vector2(170, 126)
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	_options_panel.add_child(_zoom_slider)

	var zoom_val := Label.new()
	zoom_val.name = "ZoomVal"
	zoom_val.text = "%.2fx" % _zoom_slider.value
	zoom_val.position = Vector2(442, 124)
	_options_panel.add_child(zoom_val)
	_zoom_slider.value_changed.connect(func(v): zoom_val.text = "%.2fx" % v)

	# Show FPS toggle
	var fps_lbl := Label.new()
	fps_lbl.text = "Show FPS"
	fps_lbl.position = Vector2(24, 162)
	_options_panel.add_child(fps_lbl)

	_fps_check = CheckButton.new()
	_fps_check.button_pressed = false
	_fps_check.position = Vector2(170, 158)
	_fps_check.toggled.connect(_on_fps_toggled)
	_options_panel.add_child(_fps_check)

	# Autosave interval
	var as_lbl := Label.new()
	as_lbl.text = "Autosave"
	as_lbl.position = Vector2(24, 200)
	_options_panel.add_child(as_lbl)

	_autosave_btn = OptionButton.new()
	_autosave_btn.position = Vector2(170, 196)
	_autosave_btn.size = Vector2(160, 28)
	for entry in [["1 min", 60], ["5 min", 300], ["10 min", 600], ["15 min", 900], ["30 min", 1800]]:
		_autosave_btn.add_item(entry[0], entry[1])
	# Set current selection to match world
	var world := get_tree().get_first_node_in_group("world") as Node
	var cur_interval: float = 300.0
	if world and world.has_method("get") and "autosave_interval" in world:
		cur_interval = float(world.get("autosave_interval"))
	for i in _autosave_btn.item_count:
		if _autosave_btn.get_item_id(i) == int(cur_interval):
			_autosave_btn.select(i)
			break
	_autosave_btn.item_selected.connect(func(idx):
		var interval := float(_autosave_btn.get_item_id(idx))
		if world and "autosave_interval" in world:
			world.set("autosave_interval", interval))
	_options_panel.add_child(_autosave_btn)

	# Separator
	var sep := HSeparator.new()
	sep.position = Vector2(16, 236)
	sep.size = Vector2(PANEL_W - 32, 4)
	_options_panel.add_child(sep)

	# --- Controls section ---
	var ctrl_lbl := Label.new()
	ctrl_lbl.text = "Controls"
	ctrl_lbl.position = Vector2(24, 246)
	ctrl_lbl.add_theme_font_size_override("font_size", 14)
	ctrl_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_options_panel.add_child(ctrl_lbl)

	_controls_tabs = TabContainer.new()
	_controls_tabs.position = Vector2(12, 270)
	_controls_tabs.size = Vector2(PANEL_W - 24, 240)
	_options_panel.add_child(_controls_tabs)

	_controls_tabs.add_child(_build_controls_tab("Gamepad",          _gamepad_controls()))
	_controls_tabs.add_child(_build_controls_tab("Touch",            _touch_controls()))
	_controls_tabs.add_child(_build_controls_tab("Keyboard + Mouse", _keyboard_controls()))
	_controls_tabs.add_child(_build_rebind_tab())
	_controls_tabs.add_child(_build_effects_tab())
	_controls_tabs.add_child(_build_display_tab())
	_controls_tabs.add_child(_build_aim_tab())

	# Back button
	var back := _big_button(_options_panel, "Back", PANEL_H - BTN_H - 14, Color(0.25, 0.25, 0.35))
	back.pressed.connect(_show_main)

	# For controller focus: start at volume slider, end at Back.
	_volume_slider.focus_mode = Control.FOCUS_ALL
	_zoom_slider.focus_mode   = Control.FOCUS_ALL
	_fps_check.focus_mode     = Control.FOCUS_ALL
	_volume_slider.focus_neighbor_bottom = _zoom_slider.get_path()
	_zoom_slider.focus_neighbor_top      = _volume_slider.get_path()
	_zoom_slider.focus_neighbor_bottom   = _fps_check.get_path()
	_fps_check.focus_neighbor_top        = _zoom_slider.get_path()
	_fps_check.focus_neighbor_bottom     = back.get_path()
	back.focus_neighbor_top              = _fps_check.get_path()
	_opts_first_ctrl = _volume_slider


func _build_controls_tab(tab_name: String, rows: Array) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameData.make_scroll_draggable(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var key_lbl := Label.new()
		key_lbl.text = row[0]   # key/button name
		key_lbl.custom_minimum_size = Vector2(150, 0)
		key_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		key_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(key_lbl)

		var act_lbl := Label.new()
		act_lbl.text = row[1]   # action description
		act_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		act_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(act_lbl)

		vbox.add_child(hbox)

	return scroll


func _build_rebind_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Rebind Keys"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameData.make_scroll_draggable(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header hint
	var hint := Label.new()
	hint.text = "Click a button to rebind that key.  You have 5 seconds to press a new key."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hint)
	vbox.add_child(HSeparator.new())

	for entry in REBINDABLE_ACTIONS:
		var action_id: String = entry[0]
		var display: String   = entry[1]
		var default_lbl: String = entry[2]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = display
		name_lbl.custom_minimum_size = Vector2(140, 0)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		name_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(name_lbl)

		var btn := Button.new()
		btn.text = _get_bind_label(action_id, default_lbl)
		btn.custom_minimum_size = Vector2(110, 0)
		btn.focus_mode = Control.FOCUS_ALL
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.18, 0.22, 0.28, 0.9)
		btn_style.border_color = Color(0.4, 0.55, 0.7)
		btn_style.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", btn_style)
		row.add_child(btn)
		_rebind_row_btns[action_id] = btn
		btn.pressed.connect(_start_rebind.bind(action_id))

		# Reset button (×)
		var rst := Button.new()
		rst.text = "×"
		rst.custom_minimum_size = Vector2(28, 0)
		rst.focus_mode = Control.FOCUS_NONE
		rst.pressed.connect(_reset_bind.bind(action_id, default_lbl))
		row.add_child(rst)

		vbox.add_child(row)

	# Rebind prompt overlay — hidden until a rebind is active
	_rebind_prompt_lbl = Label.new()
	_rebind_prompt_lbl.visible = false
	_rebind_prompt_lbl.z_index = 50
	_rebind_prompt_lbl.add_theme_font_size_override("font_size", 16)
	_rebind_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	var pr_style := StyleBoxFlat.new()
	pr_style.bg_color = Color(0.05, 0.05, 0.1, 0.96)
	pr_style.set_content_margin_all(12)
	pr_style.set_border_width_all(2)
	pr_style.border_color = Color(0.6, 0.6, 0.8)
	_rebind_prompt_lbl.add_theme_stylebox_override("normal", pr_style)
	# Position it over the rebind tab — add to the CanvasLayer so it floats above everything
	_rebind_prompt_lbl.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_rebind_prompt_lbl)

	return scroll


## Returns the human-readable label for the currently bound key of action_id.
func _get_bind_label(action_id: String, fallback: String) -> String:
	if not InputMap.has_action(action_id):
		return fallback
	for ev: InputEvent in InputMap.action_get_events(action_id):
		if ev is InputEventKey:
			return ev.as_text_physical_keycode()
		if ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT:  return "LClick"
				MOUSE_BUTTON_RIGHT: return "RClick"
				MOUSE_BUTTON_WHEEL_UP:   return "WheelUp"
				MOUSE_BUTTON_WHEEL_DOWN: return "WheelDown"
	return fallback


func _start_rebind(action_id: String) -> void:
	if _rebind_action != "":
		return  # already rebinding
	_rebind_action = action_id
	_rebind_timer  = 5.0
	if _rebind_prompt_lbl:
		_rebind_prompt_lbl.text = "Press a key for  \"%s\"\n%.0f seconds…" % [action_id.replace("_", " ").capitalize(), _rebind_timer]
		_rebind_prompt_lbl.reset_size()
		var vp := get_viewport().get_visible_rect().size
		_rebind_prompt_lbl.position = (vp - _rebind_prompt_lbl.size) / 2.0
		_rebind_prompt_lbl.visible = true
	# Highlight the button being rebound
	if _rebind_row_btns.has(action_id):
		var btn: Button = _rebind_row_btns[action_id]
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.3, 0.15, 0.05, 0.95)
		s.border_color = Color(1.0, 0.7, 0.1)
		s.set_border_width_all(3)
		btn.add_theme_stylebox_override("normal", s)


func _finish_rebind(new_event: InputEvent) -> void:
	var action_id := _rebind_action
	_rebind_action = ""
	_rebind_timer  = 0.0
	if _rebind_prompt_lbl:
		_rebind_prompt_lbl.visible = false

	# Remove existing keyboard/mouse events for this action, keep joypad events
	if InputMap.has_action(action_id):
		var keep: Array[InputEvent] = []
		for ev: InputEvent in InputMap.action_get_events(action_id):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				keep.append(ev)
		InputMap.action_erase_events(action_id)
		for ev in keep:
			InputMap.action_add_event(action_id, ev)
	else:
		InputMap.add_action(action_id)

	InputMap.action_add_event(action_id, new_event)
	_custom_binds[action_id] = new_event

	# Update row button label
	var label: String = ""
	if new_event is InputEventKey:
		label = new_event.as_text_physical_keycode()
	elif new_event is InputEventMouseButton:
		match new_event.button_index:
			MOUSE_BUTTON_LEFT:  label = "LClick"
			MOUSE_BUTTON_RIGHT: label = "RClick"
			MOUSE_BUTTON_WHEEL_UP:   label = "WheelUp"
			MOUSE_BUTTON_WHEEL_DOWN: label = "WheelDown"
			_: label = "Mouse%d" % new_event.button_index
	if _rebind_row_btns.has(action_id):
		var btn: Button = _rebind_row_btns[action_id]
		btn.text = label
		# Restore normal style
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.22, 0.28, 0.9)
		s.border_color = Color(0.3, 0.7, 0.3)
		s.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", s)


func _cancel_rebind() -> void:
	if _rebind_action == "":
		return
	var action_id := _rebind_action
	_rebind_action = ""
	_rebind_timer  = 0.0
	if _rebind_prompt_lbl:
		_rebind_prompt_lbl.visible = false
	if _rebind_row_btns.has(action_id):
		var btn: Button = _rebind_row_btns[action_id]
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.22, 0.28, 0.9)
		s.border_color = Color(0.4, 0.55, 0.7)
		s.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", s)


func _reset_bind(action_id: String, default_lbl: String) -> void:
	_cancel_rebind()
	_custom_binds.erase(action_id)
	# Reload from project defaults — erase runtime overrides by re-loading from project map
	InputMap.load_from_project_settings()
	# Re-apply all other custom binds that are still stored
	for aid in _custom_binds:
		var ev: InputEvent = _custom_binds[aid]
		if InputMap.has_action(aid):
			var keep: Array[InputEvent] = []
			for e: InputEvent in InputMap.action_get_events(aid):
				if e is InputEventJoypadButton or e is InputEventJoypadMotion:
					keep.append(e)
			InputMap.action_erase_events(aid)
			for e in keep:
				InputMap.action_add_event(aid, e)
			InputMap.action_add_event(aid, ev)
	if _rebind_row_btns.has(action_id):
		_rebind_row_btns[action_id].text = _get_bind_label(action_id, default_lbl)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.22, 0.28, 0.9)
		s.border_color = Color(0.4, 0.55, 0.7)
		s.set_border_width_all(2)
		_rebind_row_btns[action_id].add_theme_stylebox_override("normal", s)


func _build_effects_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Effects"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameData.make_scroll_draggable(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Quality row
	var q_hbox := HBoxContainer.new()
	var q_lbl := Label.new(); q_lbl.text = "Quality"
	q_lbl.custom_minimum_size = Vector2(120, 0)
	q_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	q_hbox.add_child(q_lbl)
	var q_btn := OptionButton.new()
	for entry in ["Off", "Low", "Med", "High"]:
		q_btn.add_item(entry)
	q_btn.selected = GameData.fx.get("quality", 2)
	q_btn.focus_mode = Control.FOCUS_ALL
	q_btn.item_selected.connect(func(idx): GameData.fx["quality"] = idx)
	q_hbox.add_child(q_btn)
	vbox.add_child(q_hbox)

	# Toggle rows
	var toggles: Array = [
		["All Effects",     "enabled"],
		["Flicker",         "flicker"],
		["Embers",          "embers"],
		["Weather",         "weather"],
		["Lightning",       "lightning"],
		["Falling Leaves",  "leaves"],
		["Landing Dust",    "landing_dust"],
		["Carried Torch",   "carried_torch"],
	]
	for row in toggles:
		var hbox := HBoxContainer.new()
		var lbl := Label.new(); lbl.text = row[0]
		lbl.custom_minimum_size = Vector2(140, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lbl)
		var key: String = row[1]
		var chk := CheckButton.new()
		chk.button_pressed = GameData.fx.get(key, true)
		chk.focus_mode = Control.FOCUS_ALL
		chk.toggled.connect(func(on): GameData.fx[key] = on)
		hbox.add_child(chk)
		vbox.add_child(hbox)

	return scroll


func _build_display_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Display"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameData.make_scroll_draggable(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Brightness
	var b_hbox := HBoxContainer.new(); b_hbox.add_theme_constant_override("separation", 8)
	var b_lbl := Label.new(); b_lbl.text = "Brightness"
	b_lbl.custom_minimum_size = Vector2(140, 0)
	b_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	b_lbl.add_theme_font_size_override("font_size", 13)
	b_hbox.add_child(b_lbl)
	var b_slider := HSlider.new()
	b_slider.min_value = 0.2; b_slider.max_value = 2.0; b_slider.step = 0.05
	b_slider.value = GameData.fx.get("brightness", 1.0)
	b_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_slider.focus_mode = Control.FOCUS_ALL
	b_hbox.add_child(b_slider)
	var b_val := Label.new(); b_val.text = "%.2f" % b_slider.value
	b_val.custom_minimum_size = Vector2(38, 0)
	b_hbox.add_child(b_val)
	b_slider.value_changed.connect(func(v: float):
		GameData.fx["brightness"] = v
		b_val.text = "%.2f" % v
		_apply_brightness(v))
	vbox.add_child(b_hbox)

	# HUD Opacity
	var h_hbox := HBoxContainer.new(); h_hbox.add_theme_constant_override("separation", 8)
	var h_lbl := Label.new(); h_lbl.text = "HUD Opacity"
	h_lbl.custom_minimum_size = Vector2(140, 0)
	h_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	h_lbl.add_theme_font_size_override("font_size", 13)
	h_hbox.add_child(h_lbl)
	var h_slider := HSlider.new()
	h_slider.min_value = 0.2; h_slider.max_value = 1.0; h_slider.step = 0.05
	h_slider.value = GameData.fx.get("hud_opacity", 1.0)
	h_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_slider.focus_mode = Control.FOCUS_ALL
	h_hbox.add_child(h_slider)
	var h_val := Label.new(); h_val.text = "%d%%" % int(h_slider.value * 100)
	h_val.custom_minimum_size = Vector2(38, 0)
	h_hbox.add_child(h_val)
	h_slider.value_changed.connect(func(v: float):
		GameData.fx["hud_opacity"] = v
		h_val.text = "%d%%" % int(v * 100)
		_apply_hud_opacity(v))
	vbox.add_child(h_hbox)

	vbox.add_child(HSeparator.new())

	# Toggle rows
	var vis_toggles: Array = [
		["Show Coordinates", "show_coords"],
		["Damage Numbers", "damage_numbers"],
		["Controller Vibration", "controller_vibration"],
	]
	for row in vis_toggles:
		var hbox := HBoxContainer.new()
		var lbl := Label.new(); lbl.text = row[0]
		lbl.custom_minimum_size = Vector2(160, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lbl)
		var key: String = row[1]
		var chk := CheckButton.new()
		chk.button_pressed = GameData.fx.get(key, true)
		chk.focus_mode = Control.FOCUS_ALL
		chk.toggled.connect(func(on: bool): GameData.fx[key] = on)
		hbox.add_child(chk)
		vbox.add_child(hbox)

	vbox.add_child(HSeparator.new())

	# Fullscreen toggle
	var fs_hbox := HBoxContainer.new()
	var fs_lbl := Label.new(); fs_lbl.text = "Fullscreen"
	fs_lbl.custom_minimum_size = Vector2(160, 0)
	fs_lbl.add_theme_font_size_override("font_size", 13)
	fs_hbox.add_child(fs_lbl)
	var fs_chk := CheckButton.new()
	fs_chk.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_chk.focus_mode = Control.FOCUS_ALL
	fs_chk.toggled.connect(func(on: bool):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED))
	fs_hbox.add_child(fs_chk)
	vbox.add_child(fs_hbox)

	return scroll


func _apply_brightness(value: float) -> void:
	var world := get_tree().get_first_node_in_group("world") as Node
	if world == null:
		return
	var mod: CanvasModulate = world.get_node_or_null("CanvasModulate")
	if mod == null:
		return
	mod.color = Color(value, value, value, 1.0)


func _apply_hud_opacity(value: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as CanvasLayer
	if hud == null:
		return
	hud.layer  # access to ensure valid
	for child in hud.get_children():
		if child is Control:
			child.modulate.a = value


func _build_aim_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Aim & Mining"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameData.make_scroll_draggable(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Aim Style ────────────────────────────────────────────────────────────
	var style_hbox := HBoxContainer.new()
	style_hbox.add_theme_constant_override("separation", 12)
	var style_lbl := Label.new()
	style_lbl.text = "Aim Style"
	style_lbl.custom_minimum_size = Vector2(140, 0)
	style_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	style_lbl.add_theme_font_size_override("font_size", 13)
	style_hbox.add_child(style_lbl)
	var style_btn := OptionButton.new()
	style_btn.add_item("Last Aimed  (hold direction)")
	style_btn.add_item("Auto-target  (nearest block ahead)")
	style_btn.selected = GameData.aim_style
	style_btn.focus_mode = Control.FOCUS_ALL
	style_btn.item_selected.connect(func(idx: int): GameData.aim_style = idx)
	style_hbox.add_child(style_btn)
	vbox.add_child(style_hbox)

	# Style description
	var style_desc := Label.new()
	style_desc.text = "Last Aimed: mines where the stick was last pointing.\nAuto-target: mines the nearest block in front when stick is at rest."
	style_desc.add_theme_font_size_override("font_size", 11)
	style_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	style_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(style_desc)

	vbox.add_child(HSeparator.new())

	# ── Deadzone ─────────────────────────────────────────────────────────────
	var dz_hbox := HBoxContainer.new()
	dz_hbox.add_theme_constant_override("separation", 12)
	var dz_lbl := Label.new()
	dz_lbl.text = "Stick Deadzone"
	dz_lbl.custom_minimum_size = Vector2(140, 0)
	dz_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	dz_lbl.add_theme_font_size_override("font_size", 13)
	dz_hbox.add_child(dz_lbl)
	var dz_slider := HSlider.new()
	dz_slider.min_value = 0.05
	dz_slider.max_value = 0.50
	dz_slider.step      = 0.01
	dz_slider.value     = GameData.aim_deadzone
	dz_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dz_slider.focus_mode = Control.FOCUS_ALL
	dz_hbox.add_child(dz_slider)
	var dz_val := Label.new()
	dz_val.text = "%.2f" % GameData.aim_deadzone
	dz_val.custom_minimum_size = Vector2(36, 0)
	dz_hbox.add_child(dz_val)
	dz_slider.value_changed.connect(func(v: float):
		GameData.aim_deadzone = v
		dz_val.text = "%.2f" % v)
	vbox.add_child(dz_hbox)

	var dz_desc := Label.new()
	dz_desc.text = "Lower = more responsive stick.  Higher = less accidental input."
	dz_desc.add_theme_font_size_override("font_size", 11)
	dz_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(dz_desc)

	vbox.add_child(HSeparator.new())

	# ── Aim Sensitivity ───────────────────────────────────────────────────────
	var sens_hbox := HBoxContainer.new()
	sens_hbox.add_theme_constant_override("separation", 12)
	var sens_lbl := Label.new()
	sens_lbl.text = "Aim Sensitivity"
	sens_lbl.custom_minimum_size = Vector2(140, 0)
	sens_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	sens_lbl.add_theme_font_size_override("font_size", 13)
	sens_hbox.add_child(sens_lbl)
	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.5
	sens_slider.max_value = 5.0
	sens_slider.step      = 0.1
	sens_slider.value     = GameData.aim_sensitivity
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_slider.focus_mode = Control.FOCUS_ALL
	sens_hbox.add_child(sens_slider)
	var sens_val := Label.new()
	sens_val.text = "%.1f" % GameData.aim_sensitivity
	sens_val.custom_minimum_size = Vector2(36, 0)
	sens_hbox.add_child(sens_val)
	sens_slider.value_changed.connect(func(v: float):
		GameData.aim_sensitivity = v
		sens_val.text = "%.1f" % v)
	vbox.add_child(sens_hbox)

	var sens_desc := Label.new()
	sens_desc.text = "How quickly the aim snaps to a new direction when pushing the stick."
	sens_desc.add_theme_font_size_override("font_size", 11)
	sens_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(sens_desc)

	vbox.add_child(HSeparator.new())

	# ── Crouch Toggle ─────────────────────────────────────────────────────────
	var ct_hbox := HBoxContainer.new()
	ct_hbox.add_theme_constant_override("separation", 12)
	var ct_lbl := Label.new()
	ct_lbl.text = "Crouch Toggle"
	ct_lbl.custom_minimum_size = Vector2(140, 0)
	ct_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	ct_lbl.add_theme_font_size_override("font_size", 13)
	ct_hbox.add_child(ct_lbl)
	var ct_check := CheckButton.new()
	ct_check.button_pressed = GameData.crouch_toggle
	ct_check.focus_mode = Control.FOCUS_ALL
	ct_check.toggled.connect(func(on: bool): GameData.crouch_toggle = on)
	ct_hbox.add_child(ct_check)
	vbox.add_child(ct_hbox)

	var ct_desc := Label.new()
	ct_desc.text = "ON: press once to crouch, press again to stand.\nOFF: hold to crouch (default)."
	ct_desc.add_theme_font_size_override("font_size", 11)
	ct_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(ct_desc)

	vbox.add_child(HSeparator.new())

	# ── Tool Focus ────────────────────────────────────────────────────────────
	var tf_hbox := HBoxContainer.new()
	tf_hbox.add_theme_constant_override("separation", 12)
	var tf_lbl := Label.new()
	tf_lbl.text = "Tool Focus"
	tf_lbl.custom_minimum_size = Vector2(140, 0)
	tf_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	tf_lbl.add_theme_font_size_override("font_size", 13)
	tf_hbox.add_child(tf_lbl)
	var tf_check := CheckButton.new()
	tf_check.button_pressed = GameData.tool_focus
	tf_check.focus_mode = Control.FOCUS_ALL
	tf_check.toggled.connect(func(on: bool): GameData.tool_focus = on)
	tf_hbox.add_child(tf_check)
	vbox.add_child(tf_hbox)

	var tf_desc := Label.new()
	tf_desc.text = "ON: axe targets wood/leaves, pickaxe targets stone/ores, shovel targets dirt.\nOFF: tools mine any block (default)."
	tf_desc.add_theme_font_size_override("font_size", 11)
	tf_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	tf_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tf_desc)

	return scroll


func _keyboard_controls() -> Array:
	return [
		["A / Left Arrow",   "Move left"],
		["D / Right Arrow",  "Move right"],
		["Space / W",        "Jump  (double-jump allowed)"],
		["Left Shift",       "Sprint"],
		["Z",                "Dash  (movement burst, cancels attacks)"],
		["Q",                "Block / Parry  (0.22 s perfect window blocks damage)"],
		["X",                "Combat Dash  (backward dodge away from enemies)"],
		["Left Click (hold)","Mine block  /  Attack enemy"],
		["Right Click",      "Place selected block"],
		["R",                "Flip block before placing"],
		["E",                "Open Inventory / Crafting"],
		["F",                "Interact  (chests, signs…)"],
		["H",                "Quick-Move item  (inventory ↔ hotbar)"],
		["1 – 9",            "Select hotbar slot directly"],
		["Scroll Wheel",     "Cycle hotbar slots"],
		["Escape",           "Pause menu"],
	]


func _gamepad_controls() -> Array:
	return [
		["Left Stick",        "Move left / right"],
		["Right Stick",       "Aim the laser — controls BOTH dig target and block placement preview"],
		["A",                 "Jump  (double-jump allowed)"],
		["B",                 "Interact / Close menu"],
		["X  (hold)",         "Mine block  /  Attack  (hold to mine, tap to swing)"],
		["RT (right trigger)","Mine / Attack  (trigger alternative to X)"],
		["LT (left trigger)", "Place selected block at the white ghost preview position"],
		["LB",                "Previous hotbar slot"],
		["RB",                "Next hotbar slot"],
		["Y",                 "Combat Dash  (backward dodge away from enemies)"],
		["L3 (stick click)",  "Block / Parry  (0.22 s window deflects damage)"],
		["R3 (stick click)",  "Dash  (movement burst, cancels attacks)"],
		["D-Pad Down (hold)", "Crouch  —  hold RT while crouching to mine straight down"],
		["D-Pad Left/Right",  "Move  (alternative to left stick)"],
		["D-Pad (in menus)",  "Navigate inventory / chest slots"],
		["Back / View",       "Open Inventory"],
		["Start / Menu",      "Pause menu"],
		["Tip:",              "Select a block in your hotbar → aim Right Stick → press LT to place"],
	]


func _touch_controls() -> Array:
	return [
		["Left zone (drag)", "Move — floating analog stick"],
		["Flick up on stick","Jump"],
		["JUMP button",      "Jump"],
		["ATK button (hold)","Mine or Attack  (hold to mine, tap to swing)"],
		["Right zone (drag)","Aim laser — controls BOTH dig target and block placement"],
		["USE button",       "Place selected block at the aim-joystick target position"],
		["Tap world (empty)","Place selected block directly at tapped position"],
		["BLK button",       "Block / Parry  (hold for 0.22 s perfect window)"],
		["DASH button",      "Movement dash — repositions, cancels any attack"],
		["CDSH button",      "Combat Dash — backward dodge away from enemies"],
		["INT button",       "Interact  (chests, signs…)"],
		["INV button",       "Open Inventory / Crafting"],
		["< >  buttons",     "Cycle hotbar slots"],
		["FLIP button",      "Mirror block before placing"],
		["[MOVE ↕] button",  "Quick-Move selected item between inventory and hotbar"],
		["Tip:",             "Select a block in hotbar → drag aim joystick → tap USE to place"],
	]


# ─── HOW TO PLAY PAGE ───────────────────────────────────────────────────────

func _build_how_panel() -> void:
	_how_panel = _panel_base()
	_how_panel.visible = false
	_title_label(_how_panel, "How to Play — TerraCraft")

	# Scrollable text block
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 56)
	scroll.size = Vector2(PANEL_W - 24, PANEL_H - 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GameData.make_scroll_draggable(scroll)
	_how_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Each entry: [heading_color, text]
	var sections: Array = [
		[Color(1.0, 0.85, 0.3), "What Is TerraCraft?"],
		[Color(0.9, 0.9, 0.9),  "A 2D side-scrolling survival world with no rules and no ceiling.  Dig for ores, build a shelter before nightfall, forge weapons, slay monsters, and carve your own legend underground.  Every world is unique — what you find depends entirely on how deep you dare to go."],

		[Color(1.0, 0.85, 0.3), "Moving Around"],
		[Color(0.9, 0.9, 0.9),  "Walk with A/D or Left/Right arrows (left stick on gamepad).  Jump with Space — double-jump while airborne for extra height.  Hold Shift to sprint.  Slide along walls while falling and tap jump to wall-kick off them."],

		[Color(1.0, 0.85, 0.3), "Mining Blocks"],
		[Color(0.9, 0.9, 0.9),  "Hold Left Click (keyboard/mouse), RT (gamepad), or ATK (touch) near any block.  A progress bar fills — when full the block breaks and drops loot.  The right tool matters:  axe for wood,  pickaxe for stone and ore,  shovel for dirt and sand.\n\nGamepad: hold D-Pad Down to crouch, then hold RT to mine straight down.  Keyboard: hold S then left-click."],

		[Color(1.0, 0.85, 0.3), "Placing Blocks"],
		[Color(0.9, 0.9, 0.9),  "Select a block in your hotbar first.  Controller: push the Right Stick to aim the laser — a white ghost block shows exactly where it will land — then press LT to place.  Touch: drag the aim joystick to aim, then tap USE; or just tap any empty spot in the world.  Keyboard/Mouse: Right Click where you want to place.  Press R (or FLIP on touch) to mirror the block before placing."],

		[Color(1.0, 0.85, 0.3), "Combat"],
		[Color(0.9, 0.9, 0.9),  "Tap Left Click / X / ATK to swing your weapon.  Hold the button to charge a heavy hit — a gold flash indicates full charge.  Chain attacks with dashes for fluid combos.\n\n• Dash (Z / R3 / DASH): burst in your movement direction, instantly cancels mid-swing.\n• Combat Dash (X key / Y button / CDSH): dodge backward away from an enemy.\n• Block / Parry (Q / L3 / BLK): hold to absorb 60 % of incoming damage; press in the first 0.22 s for a perfect parry that reflects the hit entirely."],

		[Color(1.0, 0.85, 0.3), "Hotbar & Inventory"],
		[Color(0.9, 0.9, 0.9),  "9 hotbar slots sit at the bottom of the screen.  Press 1–9 or scroll the wheel to select (LB/RB on gamepad).  Press E / Back to open your full 36-slot inventory.\n\nQuick-Move (H key / Y button / [MOVE ↕] button): instantly sends the highlighted item to the first open slot in the other zone — inventory to hotbar, or hotbar to inventory.\n\nShift+Click (or drag) to manually move stacks."],

		[Color(1.0, 0.85, 0.3), "Crafting"],
		[Color(0.9, 0.9, 0.9),  "Open inventory (E) and tap any recipe — green = craftable now.  Basic items need only your hands.  Advanced tools require a Crafting Table: place one and stand near it before opening inventory.  Smelt ores in a Furnace to unlock iron, gold, and diamond gear."],

		[Color(1.0, 0.85, 0.3), "Crafting Progression"],
		[Color(0.9, 0.9, 0.9),  "Fists  →  Wood tools  →  mine stone  →  Stone tools  →  smelt iron  →  Iron tools  →  mine gold/diamond  →  Diamond tools.  Each tier unlocks harder materials and deals more combat damage."],

		[Color(1.0, 0.85, 0.3), "Hunger & Health"],
		[Color(0.9, 0.9, 0.9),  "The orange bar is hunger.  Above 50 % hunger your health slowly regenerates.  At zero hunger you take starvation damage.  Hunt animals, cook food at a Furnace, and keep your hunger topped up before diving deep."],

		[Color(1.0, 0.85, 0.3), "Day / Night Cycle"],
		[Color(0.9, 0.9, 0.9),  "A full day lasts 8 minutes.  At dusk the sky turns red — Zombies and Skeletons flood the surface.  Underground, Cave Spiders and Slimes lurk at all hours.  Build a shelter, light your base with torches, and stay alive until dawn."],

		[Color(1.0, 0.85, 0.3), "Saving"],
		[Color(0.9, 0.9, 0.9),  "Your world saves automatically when you return to the main menu or quit.  Only modified chunks are written to disk so large worlds stay compact.  Resume any time from the main menu."],
	]

	for i in range(0, sections.size(), 2):
		var heading := Label.new()
		heading.text = sections[i][1]
		heading.add_theme_color_override("font_color", sections[i][0])
		heading.add_theme_font_size_override("font_size", 14)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(heading)

		if i + 1 < sections.size():
			var body := Label.new()
			body.text = sections[i + 1][1]
			body.add_theme_color_override("font_color", sections[i + 1][0])
			body.add_theme_font_size_override("font_size", 12)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.add_child(body)

			# Small spacer between sections
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 4)
			vbox.add_child(spacer)

	var back := _big_button(_how_panel, "Back", PANEL_H - BTN_H - 14, Color(0.25, 0.25, 0.35))
	back.pressed.connect(_show_main)
	_how_back_btn = back


# ═══════════════════════════════════════════════════════════════════════════
# OPTIONS HANDLERS
# ═══════════════════════════════════════════════════════════════════════════

func _get_volume() -> float:
	# AudioServer.get_bus_volume_db returns dB; convert to 0-100.
	var db: float = AudioServer.get_bus_volume_db(0)
	if db <= -40.0:
		return 0.0
	return clamp((db + 40.0) * 2.5, 0.0, 100.0)

func _get_zoom() -> float:
	# Try to read from the World camera.
	var camera: Camera2D = _find_camera()
	if camera:
		return camera.zoom.x
	return 2.0

func _find_camera() -> Camera2D:
	# Walk up to World and find GameCamera.
	var worlds: Array[Node] = get_tree().get_nodes_in_group("world")
	if not worlds.is_empty():
		return worlds[0].get_node_or_null("GameCamera")
	return null

func _on_volume_changed(value: float) -> void:
	# Convert 0-100 to -40 dB … 0 dB range.
	if value <= 0.0:
		AudioServer.set_bus_volume_db(0, -80.0)   # effectively muted
	else:
		AudioServer.set_bus_volume_db(0, (value / 2.5) - 40.0)

func _on_zoom_changed(value: float) -> void:
	var camera: Camera2D = _find_camera()
	if camera:
		camera.zoom = Vector2(value, value)

func _on_fps_toggled(on: bool) -> void:
	Engine.max_fps = 0   # uncap
	# Godot 4 has no built-in FPS overlay via code; use the Godot debugger or
	# add a Label in HUD that reads Engine.get_frames_per_second() each second.
	# This toggle is a placeholder — wire it to that label if you add one.


# ═══════════════════════════════════════════════════════════════════════════
# NAVIGATION BUTTONS
# ═══════════════════════════════════════════════════════════════════════════

func _go_main_menu() -> void:
	get_tree().paused = false
	_force_save()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _quit_game() -> void:
	_force_save()
	get_tree().quit()

func _force_save() -> void:
	var world := get_tree().get_first_node_in_group("world")
	var player := get_tree().get_first_node_in_group("player")
	if world != null and player != null:
		SaveLoad.save_game(world, player)
