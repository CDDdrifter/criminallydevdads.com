# FurnaceUI.gd
# Smelting furnace interface.
# Open by calling open(player_node) from World.gd when the player interacts
# with a furnace tile.  The UI handles its own timer, progress bar, and
# inventory handoff.
#
# ============================================================
# HOW TO ADD A NEW SMELTING RECIPE
# ============================================================
# 1. Open CraftingSystem.gd → RECIPES array.
# 2. Add a new entry with "requires_furnace": true.
#    Example:
#      {
#        "id": "steel_ingot",
#        "count": 1,
#        "requires_table": false,
#        "requires_furnace": true,
#        "smelt_time": 5.0,
#        "ingredients": [{"id": "iron_ingot", "count": 2}, {"id": "coal", "count": 1}],
#      }
# 3. Make sure the output item id exists in ItemDatabase.gd.
# 4. That's it — FurnaceUI.gd calls CraftingSystem.get_furnace_recipes()
#    at open-time so your new recipe appears automatically.
# ============================================================

extends CanvasLayer

# ------------------------------------------------------------------
# CONSTANTS
# ------------------------------------------------------------------
## Default smelt time in seconds used when a recipe has no "smelt_time" key.
const DEFAULT_SMELT_TIME: float = 3.0
## Name of the fuel item currently accepted as furnace fuel.
## Add more fuel types to the FUEL_BURN_TIMES dictionary below.
const FUEL_SLOT_SIZE: int = 1

## How many seconds each fuel item provides.
## HOW TO ADD NEW FUEL: append an entry here.
const FUEL_BURN_TIMES: Dictionary = {
	# Refined fuels
	"coal":           10.0,
	"charcoal":        8.0,
	# Logs
	"log_oak":         4.0,
	"log_birch":       4.0,
	"log_jungle":      4.0,
	"log_dark":        4.0,
	"log_pine":        4.0,
	# Planks
	"planks_oak":      2.0,
	"planks_birch":    2.0,
	"planks_jungle":   2.0,
	"planks_dark":     2.0,
	"planks_pine":     2.0,
	# Other wood items
	"stick":           1.0,
	"wood_beam":       3.0,
	# Wood tools (used/broken gear as fuel)
	"wood_pick":       2.5,
	"wood_axe":        2.5,
	"wood_sword":      2.5,
	"wood_shovel":     2.0,
	"wood_pick_inf":   2.5,
	"wood_axe_inf":    2.5,
	"wood_sword_inf":  2.5,
	"wood_shovel_inf": 2.0,
	# Crafting components
	"chest":           2.0,
	"workbench":       3.0,
	"bed":             2.0,
	"fence":           1.0,
	"trapdoor":        1.0,
	"wooden_door":     1.5,
	"bookshelf":       2.0,
	"ladder":          0.5,
	"sign":            0.5,
}

# ------------------------------------------------------------------
# SIGNALS
# ------------------------------------------------------------------
## Emitted when the UI closes so callers can re-enable player input.
signal closed

# ------------------------------------------------------------------
# INTERNAL STATE
# ------------------------------------------------------------------
var _player: Node = null           # reference to the Player node
var _selected_recipe: Dictionary = {}
var _smelt_timer: float = 0.0      # seconds remaining on current smelt
var _smelt_total: float = 0.0      # duration of current smelt operation
var _is_smelting: bool = false
var _fuel_remaining: float = 0.0   # seconds of fuel left
var _fuel_item: Dictionary = {}    # item in the fuel slot

# UI nodes built in _build_ui().
var _root_panel: Panel = null
var _recipe_list: VBoxContainer = null
var _progress_bar: ProgressBar = null
var _fuel_bar: ProgressBar = null
var _fuel_label: Label = null
var _output_label: Label = null
var _smelt_button: Button = null
var _close_button: Button = null
var _status_label: Label = null


func _ready() -> void:
	_build_ui()
	visible = false


## Opens the furnace UI for `player`.
func open(player: Node) -> void:
	_player = player
	_refresh_recipe_list()
	# PROCESS_MODE_ALWAYS so _process (smelting timer) and Button gui_input both
	# keep working even if the world tree is somehow paused elsewhere.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	UIManager.open()


## Closes the UI and clears the UI-open flag.
func close() -> void:
	visible = false
	UIManager.close()
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return

	if _is_smelting:
		# Consume fuel.
		_fuel_remaining -= delta
		if _fuel_remaining <= 0.0:
			_fuel_remaining = 0.0
			_is_smelting = false
			_status_label.text = "Out of fuel!"
			_progress_bar.value = 0.0
			_fuel_bar.value = 0.0
			return

		_smelt_timer -= delta
		_progress_bar.value = 1.0 - (_smelt_timer / _smelt_total)
		_fuel_bar.value = _fuel_remaining

		if _smelt_timer <= 0.0:
			_finish_smelt()


# ------------------------------------------------------------------
# PRIVATE — smelting logic
# ------------------------------------------------------------------

func _start_smelt() -> void:
	if _selected_recipe.is_empty():
		_status_label.text = "Select a recipe first."
		return

	if _player == null:
		return

	# Check ingredients.
	var combined: Array = _get_combined_inventory()
	if not CraftingSystem.can_craft(_selected_recipe["id"], combined, false, true):
		_status_label.text = "Missing ingredients!"
		return

	# Need fuel if not already burning.
	if _fuel_remaining <= 0.0:
		_consume_fuel()
		if _fuel_remaining <= 0.0:
			_status_label.text = "No fuel! Add coal, charcoal, or wood."
			return

	# Consume ingredients immediately (remove from player inventory).
	for ingredient in _selected_recipe["ingredients"]:
		_remove_from_player(ingredient["id"], int(ingredient["count"]))

	_smelt_total = float(_selected_recipe.get("smelt_time", DEFAULT_SMELT_TIME))
	_smelt_timer = _smelt_total
	_is_smelting = true
	_status_label.text = "Smelting: %s" % _selected_recipe["id"].replace("_", " ").capitalize()
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_fuel_bar.max_value = _fuel_remaining


func _finish_smelt() -> void:
	_is_smelting = false
	_progress_bar.value = 1.0
	# Give the output item to the player.
	var out_id: String = str(_selected_recipe.get("id", ""))
	var out_count: int = int(_selected_recipe.get("count", 1))
	_add_to_player(out_id, out_count)
	_status_label.text = "Done! Got: %s x%d" % [out_id.replace("_", " ").capitalize(), out_count]
	# Notify quest system.
	var qs := get_node_or_null("/root/QuestSystem")
	if qs != null:
		qs.on_item_smelted(out_id, out_count)
	_refresh_recipe_list()


func _consume_fuel() -> void:
	# Look for a valid fuel item in the player's inventory and hotbar.
	if _player == null:
		return
	for fuel_id in FUEL_BURN_TIMES.keys():
		var found: bool = false
		# Check hotbar.
		for i in range(_player.hotbar.size()):
			var slot: Dictionary = _player.hotbar[i]
			if slot.get("id", "") == fuel_id:
				_player.hotbar[i]["count"] = int(slot["count"]) - 1
				if int(_player.hotbar[i]["count"]) <= 0:
					_player.hotbar[i] = {}
				_fuel_remaining += FUEL_BURN_TIMES[fuel_id]
				found = true
				break
		if found:
			break
		# Check main inventory.
		for i in range(_player.inventory.size()):
			var slot: Dictionary = _player.inventory[i]
			if slot.get("id", "") == fuel_id:
				_player.inventory[i]["count"] = int(slot["count"]) - 1
				if int(_player.inventory[i]["count"]) <= 0:
					_player.inventory[i] = {}
				_fuel_remaining += FUEL_BURN_TIMES[fuel_id]
				found = true
				break
		if found:
			break


# ------------------------------------------------------------------
# PRIVATE — inventory helpers
# ------------------------------------------------------------------

## Combined flat Array of { "id", "count" } from hotbar + inventory.
func _get_combined_inventory() -> Array:
	var result: Array = []
	if _player == null:
		return result
	for slot in _player.hotbar:
		if not slot.is_empty():
			result.append(slot)
	for slot in _player.inventory:
		if not slot.is_empty():
			result.append(slot)
	return result


func _remove_from_player(item_id: String, amount: int) -> void:
	if _player == null:
		return
	var remaining: int = amount
	# Try hotbar first.
	for i in range(_player.hotbar.size()):
		if remaining <= 0:
			break
		var slot: Dictionary = _player.hotbar[i]
		if slot.get("id", "") == item_id:
			var take: int = mini(remaining, int(slot["count"]))
			_player.hotbar[i]["count"] = int(slot["count"]) - take
			if int(_player.hotbar[i]["count"]) <= 0:
				_player.hotbar[i] = {}
			remaining -= take
	# Then inventory.
	for i in range(_player.inventory.size()):
		if remaining <= 0:
			break
		var slot: Dictionary = _player.inventory[i]
		if slot.get("id", "") == item_id:
			var take: int = mini(remaining, int(slot["count"]))
			_player.inventory[i]["count"] = int(slot["count"]) - take
			if int(_player.inventory[i]["count"]) <= 0:
				_player.inventory[i] = {}
			remaining -= take


func _add_to_player(item_id: String, amount: int) -> void:
	if _player == null:
		return
	var remaining: int = amount
	# Stack into existing hotbar slots first.
	for i in range(_player.hotbar.size()):
		if remaining <= 0:
			break
		var slot: Dictionary = _player.hotbar[i]
		if slot.get("id", "") == item_id:
			_player.hotbar[i]["count"] = int(slot["count"]) + remaining
			remaining = 0
	# Then existing inventory slots.
	for i in range(_player.inventory.size()):
		if remaining <= 0:
			break
		var slot: Dictionary = _player.inventory[i]
		if slot.get("id", "") == item_id:
			_player.inventory[i]["count"] = int(slot["count"]) + remaining
			remaining = 0
	# Empty hotbar slots.
	for i in range(_player.hotbar.size()):
		if remaining <= 0:
			break
		if _player.hotbar[i].is_empty():
			_player.hotbar[i] = {"id": item_id, "count": remaining, "durability": -1}
			remaining = 0
	# Empty inventory slots.
	for i in range(_player.inventory.size()):
		if remaining <= 0:
			break
		if _player.inventory[i].is_empty():
			_player.inventory[i] = {"id": item_id, "count": remaining, "durability": -1}
			remaining = 0
	# Emit signals so HUD updates.
	if _player.has_signal("hotbar_changed"):
		for i in range(_player.hotbar.size()):
			_player.hotbar_changed.emit(i, _player.hotbar[i])
	if _player.has_signal("inventory_changed"):
		_player.inventory_changed.emit()


# ------------------------------------------------------------------
# PRIVATE — UI construction
# ------------------------------------------------------------------

func _build_ui() -> void:
	# Semi-transparent dark overlay behind the panel.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_root_panel = Panel.new()
	_root_panel.set_anchors_preset(Control.PRESET_CENTER)
	_root_panel.custom_minimum_size = Vector2(400, 480)
	_root_panel.position = Vector2(-200, -240)
	add_child(_root_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_child(vbox)
	_root_panel.add_child(margin)

	# Title.
	var title := Label.new()
	title.text = "Furnace"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Fuel progress bar.
	var fuel_row := HBoxContainer.new()
	_fuel_label = Label.new()
	_fuel_label.text = "Fuel:"
	_fuel_label.custom_minimum_size.x = 60
	fuel_row.add_child(_fuel_label)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.min_value = 0.0
	_fuel_bar.max_value = 10.0
	_fuel_bar.value = 0.0
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuel_row.add_child(_fuel_bar)
	vbox.add_child(fuel_row)

	# Smelt progress bar.
	var prog_row := HBoxContainer.new()
	var prog_label := Label.new()
	prog_label.text = "Progress:"
	prog_label.custom_minimum_size.x = 60
	prog_row.add_child(prog_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_row.add_child(_progress_bar)
	vbox.add_child(prog_row)

	# Status label.
	_status_label = Label.new()
	_status_label.text = "Select a recipe and press Smelt."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	# Separator.
	vbox.add_child(HSeparator.new())

	# Recipe scroll list.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_list)
	vbox.add_child(scroll)

	# Bottom buttons.
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	_smelt_button = Button.new()
	_smelt_button.text = "Smelt"
	_smelt_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_smelt_button.pressed.connect(_on_smelt_pressed)
	btn_row.add_child(_smelt_button)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.pressed.connect(close)
	btn_row.add_child(_close_button)

	vbox.add_child(btn_row)


func _refresh_recipe_list() -> void:
	for child in _recipe_list.get_children():
		child.queue_free()

	var recipes: Array = CraftingSystem.get_furnace_recipes()
	var combined: Array = _get_combined_inventory()

	for recipe in recipes:
		var btn := Button.new()
		var _rid: String = str(recipe.get("id", ""))
		var can: bool = CraftingSystem.can_craft(_rid, combined, false, true)
		var label_text: String = _rid.replace("_", " ").capitalize()

		# Show ingredient summary.
		var ingredient_parts: Array = []
		for ing in recipe["ingredients"]:
			ingredient_parts.append("%s x%d" % [ing["id"].replace("_"," ").capitalize(), ing["count"]])
		label_text += "\n  (%s)" % ", ".join(ingredient_parts)

		btn.text = label_text
		btn.disabled = not can
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Capture recipe in closure.
		var r: Dictionary = recipe
		btn.pressed.connect(func() -> void: _on_recipe_selected(r))

		if _selected_recipe.get("id", "") == recipe["id"]:
			btn.modulate = Color(1.0, 0.9, 0.4)

		_recipe_list.add_child(btn)


func _on_recipe_selected(recipe: Dictionary) -> void:
	_selected_recipe = recipe
	_status_label.text = "Selected: %s (%.1f s)" % [
		recipe["id"].replace("_", " ").capitalize(),
		float(recipe.get("smelt_time", DEFAULT_SMELT_TIME))
	]
	_refresh_recipe_list()


func _on_smelt_pressed() -> void:
	if _is_smelting:
		_status_label.text = "Already smelting…"
		return
	_start_smelt()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
