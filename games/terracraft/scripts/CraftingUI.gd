## CraftingUI — simple scrollable recipe list. Click a recipe to craft it.
extends Control

var _player: Node = null
var _world:  Node = null
var _bg: ColorRect = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _status: Label = null


func _ready() -> void:
	visible = false


func open(player: Node, world: Node = null) -> void:
	_player = player
	_world  = world
	UIManager.open()
	if _bg == null:
		_build_ui()
	_refresh()
	visible = true


func close() -> void:
	visible = false
	UIManager.close()
	_player = null
	_world  = null


func refresh() -> void:
	if visible:
		_refresh()

# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.72)
	_bg.anchor_right  = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var panel := Panel.new()
	panel.size = Vector2(360, vp.y * 0.80)
	panel.position = ((vp - panel.size) / 2.0).floor()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.12, 0.16, 0.97)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.4, 0.4, 0.5)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var title := Label.new()
	title.text = "Crafting"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	title.position = Vector2(10, 8)
	panel.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(36, 28)
	close_btn.position = Vector2(panel.size.x - 44, 6)
	close_btn.pressed.connect(close)
	panel.add_child(close_btn)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_status.position = Vector2(10, panel.size.y - 28)
	_status.size = Vector2(panel.size.x - 20, 22)
	panel.add_child(_status)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(6, 42)
	_scroll.size = Vector2(panel.size.x - 12, panel.size.y - 76)
	panel.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func _refresh() -> void:
	if _list == null or _player == null:
		return
	for c in _list.get_children():
		c.queue_free()

	var all_items: Array = _player.get_all_items() if _player.has_method("get_all_items") else []
	var near_table: bool = _world.has_method("is_player_near_crafting_table") and _world.is_player_near_crafting_table() if _world else false

	for recipe in CraftingSystem.get_all_recipes():
		if recipe.get("requires_furnace", false):
			continue  # furnace recipes shown in FurnaceUI

		var can: bool = CraftingSystem.can_craft(recipe["id"], all_items, near_table)

		var row := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.20, 0.28, 0.20, 0.9) if can else Color(0.20, 0.20, 0.20, 0.7)
		rs.set_border_width_all(1)
		rs.border_color = Color(0.5, 0.8, 0.4) if can else Color(0.35, 0.35, 0.4)
		row.add_theme_stylebox_override("panel", rs)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		row.add_child(vbox)

		var item_data: Dictionary = ItemDB.get_item(recipe["id"])
		var name_lbl := Label.new()
		name_lbl.text = "→ " + item_data.get("name", recipe["id"].capitalize()) + "  ×" + str(recipe.get("count", 1))
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 1.0, 0.85) if can else Color(0.55, 0.55, 0.55))
		vbox.add_child(name_lbl)

		var ing_parts: Array = []
		for ing in recipe.get("ingredients", []):
			var have: int = CraftingSystem._count_item(all_items, ing["id"])
			var need: int = int(ing["count"])
			var iname: String = ItemDB.get_item(ing["id"]).get("name", ing["id"].capitalize())
			ing_parts.append("%s (%d/%d)" % [iname, have, need])

		var ing_lbl := Label.new()
		ing_lbl.text = "  " + ", ".join(ing_parts)
		ing_lbl.add_theme_font_size_override("font_size", 11)
		ing_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.65) if can else Color(0.4, 0.4, 0.4))
		vbox.add_child(ing_lbl)

		if can:
			var rid : String = str(recipe["id"])
			row.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventScreenTouch and ev.pressed:
					_do_craft(rid)
				elif ev is InputEventMouseButton and ev.pressed \
						and ev.button_index == MOUSE_BUTTON_LEFT \
						and not InputManager.using_touch():
					_do_craft(rid)
			)

		_list.add_child(row)


func _do_craft(recipe_id: String) -> void:
	if _player == null:
		return
	var all_items: Array = _player.get_all_items() if _player.has_method("get_all_items") else []
	var near_table: bool = _world.has_method("is_player_near_crafting_table") and _world.is_player_near_crafting_table() if _world else false

	if not CraftingSystem.can_craft(recipe_id, all_items, near_table):
		_status.text = "Not enough materials"
		return

	# Build combined array, craft into it, then split back
	var hotbar_copy: Array = _player.hotbar.duplicate(true)
	var inv_copy: Array    = _player.inventory.duplicate(true)
	var combined: Array    = []
	combined.append_array(hotbar_copy)
	combined.append_array(inv_copy)

	if CraftingSystem.craft(recipe_id, combined):
		# Split combined back into hotbar + inventory
		var new_hotbar: Array = combined.slice(0, _player.hotbar.size())
		var new_inv: Array    = combined.slice(_player.hotbar.size())
		_player.set_hotbar(new_hotbar)
		_player.set_inventory(new_inv)

		var iname: String = ItemDB.get_item(recipe_id).get("name", recipe_id.capitalize())
		_status.text = "Crafted: " + iname
		_refresh()
	else:
		_status.text = "Craft failed"


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
