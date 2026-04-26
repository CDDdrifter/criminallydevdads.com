## AdminSystem.gd
## Secret admin overlay -- attach as a child of the HUD CanvasLayer.
##
## HOW TO OPEN ADMIN MODE
##   Tap / click the invisible trigger zone in the top-right of the screen
##   THREE TIMES within 2.5 seconds.  A small white dot pulses with each tap.
##   The admin panel opens on the third tap.
##
##   To CLOSE the panel (but stay in admin mode): tap X or press Escape.
##   To DISABLE admin mode entirely: tap "DISABLE ADMIN MODE" inside the panel.
##
## COMMANDS (type in the console, with or without a leading /)
##   day / night / dawn / dusk     Set time of day
##   time <0.0-1.0>                Exact time (0=midnight, 0.5=noon)
##   give <item_id> [count]        Give item (e.g. give diamond_sword 5)
##   allitems                      Give one stack of every item
##   clear                         Clear entire inventory
##   heal                          Restore full health
##   feed                          Restore full hunger
##   god                           Toggle invincibility
##   fly                           Toggle creative fly
##   tp <x> <y>                    Teleport to world pixel coords
##   kill                          Kill all enemies and animals
##   creative / survival           Toggle creative mode
##   unlock                        Unlock all 20 character classes
##   save                          Force-save the game
##   help                          Print this list in the console

extends Control

const TRIGGER_TAPS   : int   = 3
const TRIGGER_WINDOW : float = 2.5
# Sun sits at (vp.x * 0.82, vp.y * 0.10) -- matches TitleBackground and World sky.
const SUN_X_FRAC : float = 0.82
const SUN_Y_FRAC : float = 0.10
const SUN_RADIUS : float = 48.0   # tap radius in pixels (sun visual is 22px, give generous margin)

var _admin_active       : bool  = false
var _permanently_locked : bool  = false   ## true after "DISABLE ADMIN MODE" — sun taps ignored
var _tap_count          : int   = 0
var _tap_timer          : float = 0.0

var _dot          : ColorRect       = null
var _panel        : Panel           = null
var _status_lbl   : Label           = null
var _output_vbox  : VBoxContainer   = null
var _cmd_input    : LineEdit        = null
var _scroll       : ScrollContainer = null


func _ready() -> void:
	set_process(true)
	set_process_input(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_dot()
	_build_panel()
	# If admin mode was unlocked on the title screen, open the panel automatically.
	var gd := get_node_or_null("/root/GameData")
	if gd != null and gd.get("admin_mode_unlocked"):
		call_deferred("_open_panel")


func _process(delta: float) -> void:
	if _tap_count > 0 and not _admin_active:
		_tap_timer -= delta
		if _tap_timer <= 0.0:
			_tap_count   = 0
			_dot.visible = false
	if _panel.visible and Input.is_action_just_pressed("ui_cancel"):
		_close_panel()


func _input(ev: InputEvent) -> void:
	# Once the player has explicitly disabled admin mode, refuse all sun taps.
	if _permanently_locked:
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
	var sun_center := Vector2(vp.x * SUN_X_FRAC, vp.y * SUN_Y_FRAC)
	if pos.distance_to(sun_center) > SUN_RADIUS:
		return

	if _admin_active:
		if not _panel.visible:
			_open_panel()
		return

	_tap_count += 1
	_tap_timer  = TRIGGER_WINDOW

	var pct      := float(_tap_count) / float(TRIGGER_TAPS)
	var dot_size := 5.0 + 5.0 * pct
	_dot.size     = Vector2(dot_size, dot_size)
	_dot.color    = Color(1.0, 1.0, 1.0, 0.25 + 0.55 * pct)
	_dot.position = Vector2(
		sun_center.x - dot_size * 0.5,
		sun_center.y - dot_size * 0.5)
	_dot.visible = true

	if _tap_count >= TRIGGER_TAPS:
		_tap_count   = 0
		_dot.visible = false
		_open_panel()


func _build_dot() -> void:
	var vp := get_viewport().get_visible_rect().size
	_dot          = ColorRect.new()
	_dot.name     = "AdminDot"
	_dot.color    = Color(1, 1, 1, 0.3)
	_dot.size     = Vector2(6, 6)
	_dot.position = Vector2(vp.x * SUN_X_FRAC - 3.0, vp.y * SUN_Y_FRAC - 3.0)
	_dot.visible  = false
	add_child(_dot)


func _build_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	var pw := minf(560.0, vp.x - 24.0)
	var ph := minf(700.0, vp.y - 24.0)

	_panel             = Panel.new()
	_panel.name        = "AdminPanel"
	_panel.visible     = false
	_panel.size        = Vector2(pw, ph)
	_panel.position    = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.04, 0.04, 0.10, 0.96)
	bg.border_color               = Color(0.7, 0.4, 1.0, 0.85)
	bg.corner_radius_top_left     = 8
	bg.corner_radius_top_right    = 8
	bg.corner_radius_bottom_left  = 8
	bg.corner_radius_bottom_right = 8
	bg.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "ADMIN MODE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.75, 0.45, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_x := Button.new()
	close_x.text = "X"
	close_x.custom_minimum_size = Vector2(32, 32)
	close_x.add_theme_font_size_override("font_size", 15)
	close_x.pressed.connect(_close_panel)
	title_row.add_child(close_x)

	vbox.add_child(_sep())

	_status_lbl = Label.new()
	_status_lbl.text = "Admin active"
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_lbl)

	vbox.add_child(_sep())

	_section_label(vbox, "Quick Actions")

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	vbox.add_child(row1)
	_action_btn(row1, "Unlock All Classes", _unlock_all_classes)
	_action_btn(row1, "Give All Items",     _give_all_items)
	_action_btn(row1, "Creative Mode",      _enable_creative)
	_action_btn(row1, "Reset Stats",        _reset_stats)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 5)
	vbox.add_child(row2)
	_action_btn(row2, "Set Day",   func(): _exec("day"))
	_action_btn(row2, "Set Night", func(): _exec("night"))
	_action_btn(row2, "Full Heal", func(): _exec("heal"))
	_action_btn(row2, "God Mode",  func(): _exec("god"))
	_action_btn(row2, "Kill All",  func(): _exec("kill"))

	vbox.add_child(_sep())

	_section_label(vbox, "Command Console")

	var cmd_row := HBoxContainer.new()
	cmd_row.add_theme_constant_override("separation", 6)
	vbox.add_child(cmd_row)

	_cmd_input = LineEdit.new()
	_cmd_input.placeholder_text = "give diamond_sword  |  tp 512 1280  |  time 0.5"
	_cmd_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cmd_input.text_submitted.connect(_on_cmd_submitted)
	cmd_row.add_child(_cmd_input)

	var run_btn := Button.new()
	run_btn.text = "Run"
	run_btn.custom_minimum_size = Vector2(50, 0)
	run_btn.pressed.connect(_on_run_pressed)
	cmd_row.add_child(run_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 90)
	vbox.add_child(_scroll)

	_output_vbox = VBoxContainer.new()
	_output_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_vbox.add_theme_constant_override("separation", 2)
	_scroll.add_child(_output_vbox)

	vbox.add_child(_sep())

	_section_label(vbox, "Commands (with or without leading /)")
	var help_scroll := ScrollContainer.new()
	help_scroll.custom_minimum_size = Vector2(0, 95)
	vbox.add_child(help_scroll)
	var help_lbl := Label.new()
	help_lbl.text = _help_text()
	help_lbl.add_theme_font_size_override("font_size", 11)
	help_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.80))
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_scroll.add_child(help_lbl)

	vbox.add_child(_sep())

	var disable_btn := Button.new()
	disable_btn.text = "DISABLE ADMIN MODE"
	disable_btn.add_theme_font_size_override("font_size", 14)
	disable_btn.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
	disable_btn.pressed.connect(_disable_admin)
	vbox.add_child(disable_btn)


func _on_cmd_submitted(t: String) -> void:
	_exec(t)
	_cmd_input.text = ""


func _on_run_pressed() -> void:
	_exec(_cmd_input.text)
	_cmd_input.text = ""


func _sep() -> HSeparator:
	return HSeparator.new()


func _section_label(parent: Control, txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55))
	parent.add_child(lbl)


func _action_btn(parent: Control, txt: String, fn: Callable) -> void:
	var btn := Button.new()
	btn.text = txt
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(fn)
	parent.add_child(btn)


func _open_panel() -> void:
	_admin_active  = true
	_panel.visible = true
	_update_status()
	_log("Admin panel opened. Type 'help' for commands.")


func _close_panel() -> void:
	_panel.visible = false


func _disable_admin() -> void:
	_admin_active        = false
	_permanently_locked  = true   # prevents re-opening via sun taps this session
	_panel.visible       = false
	_tap_count           = 0
	_dot.visible         = false
	var gd := _gd()
	if gd != null:
		gd.set("admin_mode_unlocked", false)


func _reset_stats() -> void:
	var gd := _gd()
	if gd == null:
		_log("ERROR: GameData not found.")
		return
	gd.total_enemy_kills = 0
	gd.elite_kills       = 0
	gd.boss_kills        = 0
	gd.save_persistent_stats()
	_log("All kill stats reset to 0.")
	_update_status()


func _unlock_all_classes() -> void:
	var gd := _gd()
	if gd == null:
		_log("ERROR: GameData not found.")
		return
	while gd.unlocked_classes.size() < gd.PLAYER_CLASSES.size():
		gd.unlocked_classes.append(true)
	for i in gd.unlocked_classes.size():
		gd.unlocked_classes[i] = true
	gd.save_persistent_stats()
	_log("Unlocked %d character classes." % gd.PLAYER_CLASSES.size())
	_update_status()


func _give_all_items() -> void:
	var player := _player()
	if player == null:
		_log("ERROR: Player not found.")
		return
	var count := 0
	for id in ItemDB.items.keys():
		var data: Dictionary = ItemDB.items[id]
		if data.get("max_stack", 0) <= 0:
			continue
		if player.has_method("add_item"):
			player.add_item(id, data.get("max_stack", 1))
			count += 1
	_log("Gave %d item types to player." % count)


func _enable_creative() -> void:
	var gd := _gd()
	if gd:
		gd.creative_mode = true
	var player := _player()
	if player and player.has_method("_populate_creative_inventory"):
		player._populate_creative_inventory()
	_log("Creative mode enabled.")
	_update_status()


func _exec(raw: String) -> void:
	var text := raw.strip_edges()
	if text == "":
		return
	_log("> " + text)
	if text.begins_with("/"):
		text = text.substr(1)
	var parts := text.split(" ", false)
	if parts.is_empty():
		return
	var cmd  := parts[0].to_lower()
	var args := parts.slice(1)

	match cmd:
		"day":
			GameData.time_of_day = 0.50
			GameData.is_daytime  = true
			_log("Time set to noon.")
		"night":
			GameData.time_of_day = 0.01
			GameData.is_daytime  = false
			_log("Time set to midnight.")
		"dawn":
			GameData.time_of_day = 0.22
			GameData.is_daytime  = true
			_log("Time set to dawn.")
		"dusk":
			GameData.time_of_day = 0.77
			GameData.is_daytime  = false
			_log("Time set to dusk.")
		"time":
			if args.is_empty():
				_log("Usage: time <0.0-1.0>  (0=midnight, 0.5=noon)")
				return
			var t := clampf(float(args[0]), 0.0, 1.0)
			GameData.time_of_day = t
			GameData.is_daytime  = t >= 0.20 and t < 0.80
			_log("Time set to %.3f." % t)
		"give":
			if args.is_empty():
				_log("Usage: give <item_id> [count]")
				return
			var id  := args[0]
			var cnt := int(args[1]) if args.size() > 1 else 1
			if not ItemDB.items.has(id):
				_log("ERROR: Unknown item '%s'." % id)
				return
			var p := _player()
			if p == null:
				_log("ERROR: Player not found.")
				return
			if p.has_method("add_item"):
				p.add_item(id, cnt)
			var item_name: String = ItemDB.get_item(id).get("name", id)
			_log("Gave %d x %s." % [cnt, item_name])
		"allitems":
			_give_all_items()
		"clear":
			var p := _player()
			if p == null:
				_log("ERROR: Player not found.")
				return
			var hb  = p.get("hotbar")
			var inv = p.get("inventory")
			if hb  is Array:
				hb.clear()
			if inv is Array:
				inv.clear()
			if p.has_signal("inventory_changed"):
				p.inventory_changed.emit()
			_log("Inventory cleared.")
		"heal":
			var p := _player()
			if p == null:
				_log("ERROR: Player not found.")
				return
			p.set("health", p.get("max_health"))
			if p.has_signal("health_changed"):
				p.health_changed.emit(p.get("health"), p.get("max_health"))
			_log("Health restored to full.")
		"feed":
			var p := _player()
			if p == null:
				_log("ERROR: Player not found.")
				return
			p.set("hunger", p.get("max_hunger"))
			if p.has_signal("hunger_changed"):
				p.hunger_changed.emit(p.get("hunger"), p.get("max_hunger"))
			_log("Hunger restored to full.")
		"god":
			var p := _player()
			if p == null:
				_log("ERROR: Player not found.")
				return
			var was: bool = p.get("_invincible") if p.get("_invincible") != null else false
			p.set("_invincible", not was)
			_log("God mode %s." % ("ON" if not was else "OFF"))
			_update_status()
		"fly":
			var gd := _gd()
			if gd:
				gd.creative_mode = true
			var p := _player()
			if p == null:
				_log("ERROR: Player not found.")
				return
			var was: bool = p.get("_creative_flying") if p.get("_creative_flying") != null else false
			p.set("_creative_flying", not was)
			_log("Fly mode %s." % ("ON" if not was else "OFF"))
		"tp":
			if args.size() < 2:
				_log("Usage: tp <x> <y>  (world pixel coords)")
				return
			var p := _player()
			if p == null:
				_log("ERROR: Player not found.")
				return
			p.global_position = Vector2(float(args[0]), float(args[1]))
			_log("Teleported to (%s, %s)." % [args[0], args[1]])
		"kill":
			var n := 0
			for grp in ["enemy", "animals"]:
				for node in get_tree().get_nodes_in_group(grp):
					if node.has_method("take_damage"):
						node.take_damage(99999.0)
					else:
						node.queue_free()
					n += 1
			_log("Killed %d entities." % n)
		"creative":
			_enable_creative()
		"survival":
			var gd := _gd()
			if gd:
				gd.creative_mode = false
			_log("Survival mode enabled.")
			_update_status()
		"unlock", "unlockall", "xp":
			_unlock_all_classes()
		"resetstats", "reset_stats":
			_reset_stats()
		"save":
			var saved := false
			if has_node("/root/SaveLoad"):
				var sl := get_node("/root/SaveLoad")
				if sl.has_method("save_game"):
					sl.save_game()
					saved = true
			if not saved:
				for node in get_tree().get_nodes_in_group("world"):
					if node.has_method("save_game"):
						node.save_game()
						saved = true
						break
			_log("Game saved." if saved else "ERROR: No save method found.")
		"help":
			_log(_help_text())
		_:
			_log("Unknown command '%s'. Type 'help' for list." % cmd)


func _log(msg: String) -> void:
	if _output_vbox == null:
		return
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 12)
	var col: Color
	if msg.begins_with("ERROR"):
		col = Color(1.00, 0.35, 0.35)
	elif msg.begins_with(">"):
		col = Color(1.00, 0.85, 0.40)
	else:
		col = Color(0.78, 0.78, 0.90)
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_vbox.add_child(lbl)
	while _output_vbox.get_child_count() > 35:
		_output_vbox.get_child(0).queue_free()
	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value


func _update_status() -> void:
	if _status_lbl == null:
		return
	var parts: Array[String] = ["Admin active"]
	var gd := _gd()
	if gd and gd.get("creative_mode"):
		parts.append("Creative ON")
	var p := _player()
	if p and p.get("_invincible"):
		parts.append("God mode ON")
	_status_lbl.text = "  -  ".join(parts)


func _player() -> Node:
	if has_node("/root/Player"):
		return get_node("/root/Player")
	var arr := get_tree().get_nodes_in_group("player")
	return arr[0] if arr.size() > 0 else null


func _gd() -> Node:
	return get_node_or_null("/root/GameData")


func _help_text() -> String:
	var lines: Array[String] = [
		"day / night / dawn / dusk      Set time of day",
		"time <0.0-1.0>                 Exact time (0=midnight 0.5=noon)",
		"give <item_id> [count]         Give item (e.g. give katana 1)",
		"allitems                       Give 1 stack of every item",
		"clear                          Wipe entire inventory",
		"heal                           Full health",
		"feed                           Full hunger",
		"god                            Toggle invincibility",
		"fly                            Toggle fly (enables creative)",
		"tp <x> <y>                     Teleport to world pixel coords",
		"kill                           Kill all enemies and animals",
		"creative / survival            Toggle creative mode",
		"unlock                         Unlock all 20 character classes",
		"save                           Force save the game",
		"resetstats                     Reset all kill / boss / elite counts",
		"help                           Show this list",
	]
	return "\n".join(lines)
