extends CanvasLayer

# HUD.gd
# Always-visible overlay: health, hunger, hotbar, day/night label, mine progress.
# Connects to Player, InputManager, and GameData signals in _ready().

const HOTBAR_SLOT_COUNT := 9
const SLOT_SIZE := 72
const SLOT_PADDING := 4

# --- Internal node references ---
var health_bar: ProgressBar
var hunger_bar: ProgressBar
var hotbar_container: HBoxContainer
var hotbar_slots: Array[Panel] = []
var hotbar_icons: Array = []
var hotbar_labels: Array[Label] = []
var day_night_label: Label
var mine_progress_bar: ProgressBar
var _tile_name_label: Label
var touch_controls_node  # TouchControls (CanvasLayer)

# Tracked state
var _selected_slot: int = 0
var _current_day: int = 1
var _current_time: float = 0.0  # 0.0–1.0 normalized day cycle
var _hud_tooltip: Label = null  # floating tooltip label shown over hovered hotbar slot
var _hud_tooltip_slot: int = -1  # which slot is hovered (-1 = none)
var _hotbar_name_label: Label = null  # item name shown briefly on slot selection
var _hotbar_name_tween: Tween = null
var _coords_label: Label = null
var _world_node_cache: Node = null

# Item icon color fallback palette (used when no texture is available)
const ITEM_COLORS := {
	"empty":   Color(0.15, 0.15, 0.15),
	"default": Color(0.55, 0.55, 0.75),
}


func _ready() -> void:
	_build_ui()
	# Defer signal connection: HUD._ready() runs before World._ready() spawns the player.
	# call_deferred ensures the whole scene tree is fully initialised first.
	call_deferred("_connect_signals")


# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# --- Health Bar ---
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.size = Vector2(200, 20)
	health_bar.position = Vector2(16, 16)
	health_bar.show_percentage = false
	var health_style := StyleBoxFlat.new()
	health_style.bg_color = Color(0.8, 0.1, 0.1)
	health_bar.add_theme_stylebox_override("fill", health_style)
	add_child(health_bar)

	# Heart icon label next to bar
	var health_icon := Label.new()
	health_icon.text = "HP"
	health_icon.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	health_icon.position = Vector2(220, 14)
	add_child(health_icon)

	# --- Hunger Bar ---
	hunger_bar = ProgressBar.new()
	hunger_bar.name = "HungerBar"
	hunger_bar.min_value = 0
	hunger_bar.max_value = 100
	hunger_bar.value = 100
	hunger_bar.size = Vector2(200, 20)
	hunger_bar.position = Vector2(16, 44)
	hunger_bar.show_percentage = false
	var hunger_style := StyleBoxFlat.new()
	hunger_style.bg_color = Color(0.9, 0.6, 0.1)
	hunger_bar.add_theme_stylebox_override("fill", hunger_style)
	add_child(hunger_bar)

	var hunger_icon := Label.new()
	hunger_icon.text = "FOOD"
	hunger_icon.position = Vector2(220, 42)
	add_child(hunger_icon)

	# --- Coordinates Label (below hunger bar) ---
	_coords_label = Label.new()
	_coords_label.name = "CoordsLabel"
	_coords_label.position = Vector2(16, 70)
	_coords_label.add_theme_font_size_override("font_size", 12)
	_coords_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_coords_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_coords_label.add_theme_constant_override("shadow_offset_x", 1)
	_coords_label.add_theme_constant_override("shadow_offset_y", 1)
	_coords_label.visible = false
	add_child(_coords_label)

	# --- Day/Night Label ---
	day_night_label = Label.new()
	day_night_label.name = "DayNightLabel"
	day_night_label.text = "Day 1 - Dawn"
	day_night_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	# Centered at top
	day_night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_night_label.size = Vector2(300, 28)
	day_night_label.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 300) / 2.0,
		10
	)
	add_child(day_night_label)

	# --- Mine Progress Bar ---
	# Tile name label — shown above the hotbar when aiming at a block.
	var vp_h := get_viewport().get_visible_rect().size.y
	_tile_name_label = Label.new()
	_tile_name_label.name = "TileNameLabel"
	_tile_name_label.add_theme_font_size_override("font_size", 14)
	_tile_name_label.add_theme_color_override("font_color", Color(1, 1, 0.9))
	_tile_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_tile_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_tile_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_tile_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tile_name_label.size = Vector2(300, 26)
	_tile_name_label.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 300) / 2.0,
		vp_h - SLOT_SIZE - 46)  # just above the hotbar
	_tile_name_label.visible = false
	add_child(_tile_name_label)

	mine_progress_bar = ProgressBar.new()
	mine_progress_bar.name = "MineProgressBar"
	mine_progress_bar.min_value = 0
	mine_progress_bar.max_value = 100
	mine_progress_bar.value = 0
	mine_progress_bar.size = Vector2(200, 14)
	mine_progress_bar.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 200) / 2.0,
		vp_h - SLOT_SIZE - 64  # above the tile name label
	)
	mine_progress_bar.show_percentage = false
	mine_progress_bar.visible = false
	var mine_style := StyleBoxFlat.new()
	mine_style.bg_color = Color(0.6, 0.4, 0.1)
	mine_progress_bar.add_theme_stylebox_override("fill", mine_style)
	add_child(mine_progress_bar)

	# --- Pause button (touch only, top-right) ---
	var vp_w := get_viewport().get_visible_rect().size.x
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.size = Vector2(52, 52)
	pause_btn.position = Vector2(vp_w - 60, 10)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(func(): _fire_pause())
	add_child(pause_btn)

	# --- Hotbar ---
	_build_hotbar()

	# --- Admin overlay (tap sun 3× on title screen OR in-game to unlock) ---
	var admin_script: GDScript = load("res://scripts/AdminSystem.gd") as GDScript
	if admin_script:
		var admin: Node = admin_script.new() as Node
		admin.name = "AdminSystem"
		add_child(admin)


func _build_hotbar() -> void:
	hotbar_container = HBoxContainer.new()
	hotbar_container.name = "Hotbar"
	hotbar_container.add_theme_constant_override("separation", SLOT_PADDING)

	var vp_size := get_viewport().get_visible_rect().size
	var total_width := HOTBAR_SLOT_COUNT * (SLOT_SIZE + SLOT_PADDING)
	hotbar_container.position = Vector2(
		(vp_size.x - total_width) / 2.0,
		vp_size.y - SLOT_SIZE - 12
	)
	hotbar_container.size = Vector2(total_width, SLOT_SIZE)
	add_child(hotbar_container)

	for i in HOTBAR_SLOT_COUNT:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.name = "Slot%d" % i

		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		slot_style.border_color = Color(0.5, 0.5, 0.5)
		slot_style.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel", slot_style)

		# Item icon (TextureRect, swapped out per item)
		var icon := TextureRect.new()
		icon.texture = null
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(SLOT_SIZE - 16, SLOT_SIZE - 16)
		icon.position = Vector2(8, 4)
		icon.name = "Icon"
		slot.add_child(icon)

		# Stack count label (bottom-right of slot)
		var count_lbl := Label.new()
		count_lbl.name = "Count"
		count_lbl.text = ""
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_lbl.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
		count_lbl.position = Vector2(2, 2)
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		slot.add_child(count_lbl)

		# Touch/click to select this hotbar slot
		var slot_index := i
		slot.gui_input.connect(func(ev: InputEvent):
			# Don't change hotbar selection while any game UI panel is open — prevents
			# accidental slot swaps when the user taps near the bottom of the inventory.
			if UIManager.ui_open:
				return
			if ev is InputEventScreenTouch and ev.pressed:
				var player := _find_player()
				if player and player.has_method("select_slot"):
					player.select_slot(slot_index)
				elif player:
					player.set("selected_slot", slot_index)
					set_selected_slot(slot_index)
			elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				var player := _find_player()
				if player:
					player.set("selected_slot", slot_index)
					set_selected_slot(slot_index)
		)
		slot.mouse_entered.connect(_on_hotbar_slot_hovered.bind(i))
		slot.mouse_exited.connect(_on_hotbar_slot_unhovered.bind(i))

		hotbar_container.add_child(slot)
		hotbar_slots.append(slot)
		hotbar_icons.append(icon)
		hotbar_labels.append(count_lbl)

	# Highlight slot 0 by default
	set_selected_slot(0)

	# Item name label — shown briefly above the hotbar when selection changes
	_hotbar_name_label = Label.new()
	_hotbar_name_label.name = "HotbarNameLabel"
	_hotbar_name_label.visible = false
	_hotbar_name_label.z_index = 10
	_hotbar_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_name_label.size = Vector2(300, 26)
	_hotbar_name_label.add_theme_font_size_override("font_size", 14)
	_hotbar_name_label.add_theme_color_override("font_color", Color(1, 1, 0.85))
	_hotbar_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hotbar_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_hotbar_name_label.add_theme_constant_override("shadow_offset_y", 1)
	var vp_size2 := get_viewport().get_visible_rect().size
	_hotbar_name_label.position = Vector2(
		(vp_size2.x - 300) / 2.0,
		vp_size2.y - SLOT_SIZE - 46
	)
	add_child(_hotbar_name_label)

	# Floating tooltip label — sits above the hotbar, hidden until hover
	_hud_tooltip = Label.new()
	_hud_tooltip.name = "HotbarTooltip"
	_hud_tooltip.visible = false
	_hud_tooltip.z_index = 10
	var tt_style := StyleBoxFlat.new()
	tt_style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	tt_style.set_content_margin_all(6)
	tt_style.set_border_width_all(1)
	tt_style.border_color = Color(0.5, 0.5, 0.6)
	_hud_tooltip.add_theme_stylebox_override("normal", tt_style)
	_hud_tooltip.add_theme_color_override("font_color", Color(1, 1, 0.85))
	_hud_tooltip.add_theme_font_size_override("font_size", 14)
	add_child(_hud_tooltip)


# ---------------------------------------------------------------------------
# Signal Connections
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	# Player signals — guard with has_signal so we don't crash if Player
	# hasn't registered yet. GameData / InputManager are autoloads.
	var player := _find_player()
	if player:
		_connect_player_signals(player)

	if has_node("/root/InputManager"):
		var im := get_node("/root/InputManager")
		if im.has_signal("input_mode_changed"):
			im.input_mode_changed.connect(_on_input_mode_changed)

	if has_node("/root/GameData"):
		var gd := get_node("/root/GameData")
		if gd.has_signal("time_of_day_changed"):
			gd.time_of_day_changed.connect(_on_time_of_day_changed)
		if gd.has_signal("day_changed"):
			gd.day_changed.connect(_on_day_changed)


func _connect_player_signals(player: Node) -> void:
	if player.has_signal("health_changed"):
		player.health_changed.connect(update_health)
	if player.has_signal("hunger_changed"):
		player.hunger_changed.connect(update_hunger)
	# hotbar_changed fires with (slot_index, item_dict) — use _on_hotbar_slot_changed
	if player.has_signal("hotbar_changed"):
		player.hotbar_changed.connect(_on_hotbar_slot_changed)
	# inventory_changed fires with no args — pull the full hotbar from player
	if player.has_signal("inventory_changed"):
		player.inventory_changed.connect(_on_inventory_changed)
	if player.has_signal("selected_slot_changed"):
		player.selected_slot_changed.connect(set_selected_slot)
	if player.has_signal("mine_progress_changed"):
		player.mine_progress_changed.connect(show_mine_progress)
	if player.has_signal("aimed_tile_changed"):
		player.aimed_tile_changed.connect(_on_aimed_tile_changed)

	# Immediately populate the HUD with whatever the player already has.
	# This handles the case where Player._ready() emitted signals before HUD connected.
	_on_inventory_changed()
	# Restore the selected slot highlight too.
	var sel: int = player.get("selected_slot") if player.get("selected_slot") != null else 0
	set_selected_slot(sel)


func _process(_delta: float) -> void:
	if _coords_label == null:
		return
	var show: bool = GameData.fx.get("show_coords", false)
	if not show:
		_coords_label.visible = false
		return
	var player := _find_player()
	if player == null:
		_coords_label.visible = false
		return
	var ts: int = GameData.TILE_SIZE
	var tile_x: int = int(player.global_position.x / ts)
	var tile_y: int = int(player.global_position.y / ts)
	# Y+ above sea level, Y- below. Sea level = SURFACE_HEIGHT tile row.
	var display_y: int = GameData.SURFACE_HEIGHT - tile_y
	var biome: String = ""
	if not is_instance_valid(_world_node_cache):
		_world_node_cache = get_tree().get_first_node_in_group("world")
	if _world_node_cache and _world_node_cache.has_method("get_biome_at_world_x"):
		biome = _world_node_cache.get_biome_at_world_x(player.global_position.x).capitalize()
	_coords_label.text = "X: %d  Y: %d  %s" % [tile_x, display_y, biome]
	_coords_label.visible = true


func _find_player() -> Node:
	# Try common autoload name first, then scene tree search.
	if has_node("/root/Player"):
		return get_node("/root/Player")
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Redraws all 9 hotbar slots from an inventory array.
## inventory_array: Array of Dictionaries with keys "id", "count", "color" (optional).
func update_hotbar(inventory_array: Array) -> void:
	for i in HOTBAR_SLOT_COUNT:
		if i >= inventory_array.size():
			_clear_slot(i)
			continue

		var item: Dictionary = inventory_array[i]
		if item.is_empty() or not item.has("id") or item["id"] == "":
			_clear_slot(i)
		else:
			# Look up the icon from ItemDB using the item's string id
			var item_data: Dictionary = ItemDB.get_item(item["id"])
			hotbar_icons[i].texture = TileTextureGenerator.get_icon(item["id"], item_data)
			var cnt: int = item.get("count", 1)
			hotbar_labels[i].text = "" if cnt <= 1 else str(cnt)

	# Re-apply selection highlight
	set_selected_slot(_selected_slot)


func _clear_slot(index: int) -> void:
	hotbar_icons[index].texture = null
	hotbar_labels[index].text = ""


## Animates the health bar toward new_value. max_value updates the bar range.
func update_health(new_value: float, max_value: float = 100.0) -> void:
	health_bar.max_value = max_value
	var tween := create_tween()
	tween.tween_property(health_bar, "value", new_value, 0.2)


## Animates the hunger bar toward new_value.
func update_hunger(new_value: float, max_value: float = 100.0) -> void:
	hunger_bar.max_value = max_value
	var tween := create_tween()
	tween.tween_property(hunger_bar, "value", new_value, 0.2)


## Highlights the selected hotbar slot with a bright border; others are dimmed.
func set_selected_slot(index: int) -> void:
	_selected_slot = clamp(index, 0, HOTBAR_SLOT_COUNT - 1)
	for i in hotbar_slots.size():
		var style := StyleBoxFlat.new()
		style.set_border_width_all(2)
		if i == _selected_slot:
			style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
			style.border_color = Color(1.0, 0.9, 0.2)  # Gold highlight
		else:
			style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			style.border_color = Color(0.5, 0.5, 0.5)
		hotbar_slots[i].add_theme_stylebox_override("panel", style)
	_show_hotbar_item_name(_selected_slot)


func _show_hotbar_item_name(slot: int) -> void:
	if _hotbar_name_label == null:
		return
	var player := _find_player()
	var item_name := ""
	if player != null:
		var hb: Array = player.get("hotbar")
		if hb != null and slot < hb.size():
			var item: Dictionary = hb[slot]
			var id: String = item.get("id", "")
			if id != "":
				var item_data: Dictionary = ItemDB.get_item(id)
				item_name = item_data.get("name", id.replace("_", " ").capitalize())
	if item_name == "":
		_hotbar_name_label.visible = false
		return
	_hotbar_name_label.text = item_name
	_hotbar_name_label.modulate.a = 1.0
	_hotbar_name_label.visible = true
	if _hotbar_name_tween:
		_hotbar_name_tween.kill()
	_hotbar_name_tween = create_tween()
	_hotbar_name_tween.tween_interval(1.2)
	_hotbar_name_tween.tween_property(_hotbar_name_label, "modulate:a", 0.0, 0.4)


## Shows or hides the mining progress bar.
## progress: 0.0 = empty / hidden, 1.0 = full. Matches Player.mine_progress_changed signal.
func show_mine_progress(progress: float) -> void:
	mine_progress_bar.visible = progress > 0.0
	mine_progress_bar.value   = progress * 100.0


## Shows the tile name above the crosshair when aiming at a block.
func _on_aimed_tile_changed(tile_name: String) -> void:
	if _tile_name_label == null:
		return
	if tile_name == "":
		_tile_name_label.visible = false
	else:
		_tile_name_label.text = tile_name
		_tile_name_label.visible = true


## Returns a human-readable time-of-day string.
## time_normalized: 0.0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk, 1.0 = midnight.
func _get_time_label(day: int, time_normalized: float) -> String:
	var phase: String
	if time_normalized < 0.05 or time_normalized >= 0.95:
		phase = "Night"
	elif time_normalized < 0.25:
		phase = "Dawn"
	elif time_normalized < 0.42:
		phase = "Morning"
	elif time_normalized < 0.58:
		phase = "Noon"
	elif time_normalized < 0.75:
		phase = "Evening"
	elif time_normalized < 0.88:
		phase = "Dusk"
	else:
		phase = "Night"
	return "Day %d - %s" % [day, phase]


# ---------------------------------------------------------------------------
# Signal Handlers
# ---------------------------------------------------------------------------

## InputManager emits InputMode (int enum), not a bool.
## Use InputManager.using_touch() for the actual check.
func _on_input_mode_changed(_mode) -> void:
	if touch_controls_node:
		touch_controls_node.visible = InputManager.using_touch()


func _on_time_of_day_changed(normalized_time: float) -> void:
	_current_time = normalized_time
	day_night_label.text = _get_time_label(_current_day, _current_time)


func _on_day_changed(new_day: int) -> void:
	_current_day = new_day
	day_night_label.text = _get_time_label(_current_day, _current_time)


## Called when a single hotbar slot changes. Updates just that slot.
func _on_hotbar_slot_changed(slot: int, item: Dictionary) -> void:
	if slot < 0 or slot >= HOTBAR_SLOT_COUNT:
		return
	if item.is_empty() or not item.has("id") or item["id"] == "":
		_clear_slot(slot)
	else:
		var item_data: Dictionary = ItemDB.get_item(item["id"])
		hotbar_icons[slot].texture = TileTextureGenerator.get_icon(item["id"], item_data)
		var cnt: int = item.get("count", 1)
		hotbar_labels[slot].text = "" if cnt <= 1 else str(cnt)
	set_selected_slot(_selected_slot)


## Called when inventory changes (no args). Re-reads player's full hotbar array.
func _on_inventory_changed() -> void:
	# Pull the current hotbar from the player node and refresh all slots.
	var player := _find_player()
	if player == null:
		return
	var hb: Array = player.get("hotbar")
	if hb == null:
		return
	update_hotbar(hb)


func _fire_pause() -> void:
	var ev := InputEventAction.new()
	ev.action  = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)


# ---------------------------------------------------------------------------
# Hotbar tooltip (mouse hover over HUD hotbar slots)
# ---------------------------------------------------------------------------

func _on_hotbar_slot_hovered(slot_index: int) -> void:
	_hud_tooltip_slot = slot_index
	_update_hud_tooltip(slot_index)


func _on_hotbar_slot_unhovered(slot_index: int) -> void:
	if _hud_tooltip_slot == slot_index:
		_hud_tooltip_slot = -1
	if _hud_tooltip != null:
		_hud_tooltip.visible = false


func _update_hud_tooltip(slot_index: int) -> void:
	if _hud_tooltip == null:
		return
	var player := _find_player()
	if player == null:
		return
	var hb: Array = player.get("hotbar")
	if hb == null or slot_index >= hb.size():
		_hud_tooltip.visible = false
		return
	var item: Dictionary = hb[slot_index]
	if item.is_empty() or item.get("id", "") == "":
		_hud_tooltip.visible = false
		return
	var item_data: Dictionary = ItemDB.get_item(item.get("id", ""))
	var name_str: String = item_data.get("name", item.get("id", "").replace("_", " ").capitalize())
	var cnt: int = item.get("count", 1)
	if cnt > 1:
		name_str += "  ×%d" % cnt
	var desc_str: String = item_data.get("description", "")
	_hud_tooltip.text = name_str + ("\n" + desc_str if desc_str != "" else "")
	_hud_tooltip.reset_size()
	# Position just above the hovered slot
	if slot_index < hotbar_slots.size():
		var slot_pos: Vector2 = hotbar_slots[slot_index].global_position
		var vp := get_viewport().get_visible_rect().size
		var tx: float = slot_pos.x + (SLOT_SIZE - _hud_tooltip.size.x) * 0.5
		tx = clampf(tx, 4, vp.x - _hud_tooltip.size.x - 4)
		_hud_tooltip.position = Vector2(tx, slot_pos.y - _hud_tooltip.size.y - 6)
	_hud_tooltip.visible = true
