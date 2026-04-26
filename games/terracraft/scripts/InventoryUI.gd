extends Control

## InventoryUI -- the single place managing the player's bag.
##
## CLICK RULES
##   * Click a filled slot  -> select (gold border)
##   * Click a different slot -> move / swap
##   * Click the same slot  -> cancel
##   * E / Escape           -> close
##
## MODES
##   Normal   -- one centred panel (inventory + hotbar)
##   Chest    -- player panel LEFT, chest panel RIGHT (side-by-side)
##   Creative -- inventory section replaced by scrollable item palette
##
## QUICK TWEAKS
##   Slot dimensions -> SLOT_SIZE, SLOT_PAD
##   Chest capacity  -> CHEST_COLS x CHEST_ROWS (default 9x3 = 27)
##   Footer buttons  -> _build_footer()

# -- Layout -------------------------------------------------------------------
const SLOT_SIZE  := 56
const SLOT_PAD   := 4
const INV_COLS   := 9
const INV_ROWS   := 4
const CHEST_COLS := 9
const CHEST_ROWS := 3
const P          := 8    # panel inner margin
const GAP        := 14   # gap between player panel and chest panel

# -- Flat-index key -----------------------------------------------------------
#   0 - 8   hotbar
#   9 - 44  player inventory
#  45 - 71  chest (chest mode only)
const HOT_S := 0;  const HOT_E := 8
const INV_S := 9;  const INV_E := 44
const CHT_S := 45; const CHT_E := 71

# -- Runtime state ------------------------------------------------------------
var _player    : Node   = null
var _chest_key : String = ""
var _selected  : int    = -1    # flat index; -1 = nothing selected
var _cr_ids    : Array[String] = []
var _cr_scroll : ScrollContainer = null

# Parallel slot arrays -- same index = same slot.
var _panels : Array[Panel]       = []
var _icons  : Array[TextureRect] = []
var _counts : Array[Label]       = []
var _fmap   : Array[int]         = []   # _fmap[panel_idx] = flat_idx

# Creative palette
var _cr_panels : Array[Panel]  = []

var _sel_lbl     : Label = null
var _gp_tooltip  : Label = null  # hover tooltip for gamepad
var _slot_sz     : int   = SLOT_SIZE   # computed each rebuild based on viewport width
var _gp_pi       : int   = -1          # panel index under gamepad D-pad cursor; -1 = none
var _gp_in_cr    : bool  = false       # true when cursor is in the creative palette section
var _cr_selected : int   = -1          # index into _cr_panels/-ids for creative selection; -1 = none


# -- PUBLIC API ---------------------------------------------------------------

func _ready() -> void:
	visible      = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(player: Node) -> void:
	_player    = player
	_chest_key = ""
	InputManager.touch_quick_move = false
	_rebuild()


func open_chest(player: Node, chest_key: String) -> void:
	_player    = player
	_chest_key = chest_key
	InputManager.touch_quick_move = false
	_rebuild()


func close() -> void:
	if not visible:
		return
	_sig_disconnect()
	visible      = false
	_selected    = -1
	_cr_selected = -1
	InputManager.touch_quick_move = false
	UIManager.close()
	if _player and "inventory_open" in _player:
		_player.inventory_open = false
	_player    = null
	_chest_key = ""


func refresh() -> void:
	if visible and _player != null:
		_draw_slots()


# -- BUILD --------------------------------------------------------------------

func _rebuild() -> void:
	for c in get_children(): c.queue_free()
	_panels.clear(); _icons.clear(); _counts.clear(); _fmap.clear()
	_cr_panels.clear(); _cr_ids.clear()
	_selected = -1; _sel_lbl = null; _gp_pi = -1; _gp_in_cr = false; _cr_selected = -1

	UIManager.open()
	if _player and "inventory_open" in _player:
		_player.inventory_open = true

	_build_ui()
	_draw_slots()
	_sig_connect()
	visible = true


func _build_ui() -> void:
	var vp      : Vector2 = get_viewport().get_visible_rect().size
	var creative: bool    = GameData.creative_mode
	var chest   : bool    = _chest_key != ""

	# Responsive: shrink slots to fit the viewport width (minimum 32 px on small phones).
	var panels_count : float = 2.0 if chest else 1.0
	var avail_w      : float = (vp.x - 40.0 - (float(GAP) if chest else 0.0)) / panels_count
	_slot_sz = clampi(int((avail_w - 2.0 * P) / INV_COLS) - SLOT_PAD, 32, SLOT_SIZE)

	# Shared row height
	var rh := _slot_sz + SLOT_PAD

	# Player panel size
	var ppw := P + INV_COLS * rh + P
	var pph := P + 18 + INV_ROWS * rh + P
	pph    += P + 18 + rh + P
	if creative: pph += 18 + 300 + P
	pph    += 36

	# Dim background
	var bg          := ColorRect.new()
	bg.color         = Color(0, 0, 0, 0.70)
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Positioning
	var total_w : int = ppw + (GAP + ppw if chest else 0)
	var start_x : int = int((vp.x - total_w) * 0.5)
	var start_y : int = int((vp.y - pph)     * 0.5)

	_build_player_panel(start_x, start_y, ppw, pph, creative)

	if chest:
		_build_chest_panel(start_x + ppw + GAP, start_y, ppw, pph)

	# Gamepad hover tooltip (top layer)
	_gp_tooltip = Label.new()
	_gp_tooltip.visible = false
	_gp_tooltip.z_index = 100
	_gp_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gp_tooltip.add_theme_font_size_override("font_size", 13)
	_gp_tooltip.add_theme_color_override("font_color", Color(1, 1, 1))
	_gp_tooltip.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_gp_tooltip.add_theme_constant_override("outline_size", 4)
	
	# Give it a small dark background
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.8)
	st.set_content_margin_all(6)
	st.set_corner_radius_all(4)
	_gp_tooltip.add_theme_stylebox_override("normal", st)
	
	add_child(_gp_tooltip)


func _build_player_panel(ox: int, oy: int, pw: int, ph: int, creative: bool) -> void:
	var panel : Panel = _make_panel(ox, oy, pw, ph)
	add_child(panel)

	var cy : int = P

	cy = _header(panel, pw, cy, "Creative" if creative else "Inventory")

	if creative:
		cy = _creative_section(panel, cy)
	else:
		cy = _section_label(panel, cy, "Inventory")
		cy = _slot_grid(panel, cy, INV_ROWS, INV_COLS, INV_S)

	cy = _section_label(panel, cy, "Hotbar")
	_slot_grid(panel, cy, 1, INV_COLS, HOT_S)

	_build_footer(panel, pw, ph)


func _build_chest_panel(ox: int, oy: int, pw: int, ph: int) -> void:
	var panel : Panel = _make_panel(ox, oy, pw, ph)
	add_child(panel)

	var cy : int = P
	cy = _header(panel, pw, cy, "Chest")
	cy = _section_label(panel, cy, "Contents")
	_slot_grid(panel, cy, CHEST_ROWS, CHEST_COLS, CHT_S)


# -- Helpers ------------------------------------------------------------------

func _make_panel(ox: int, oy: int, pw: int, ph: int) -> Panel:
	var p : Panel = Panel.new()
	p.position = Vector2(ox, oy)
	p.size     = Vector2(pw, ph)
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color     = Color(0.11, 0.11, 0.15, 0.97)
	s.border_color = Color(0.38, 0.38, 0.50)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", s)
	return p


func _header(parent: Control, pw: int, cy: int, title: String) -> int:
	var lbl : Label = Label.new()
	lbl.text     = title
	lbl.position = Vector2(P, cy)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 1.0))
	parent.add_child(lbl)

	var btn : Button = Button.new()
	btn.text     = "X"
	btn.size     = Vector2(30, 26)
	btn.position = Vector2(pw - 36, cy)
	btn.pressed.connect(close)
	parent.add_child(btn)
	return cy + 30


func _section_label(parent: Control, cy: int, txt: String) -> int:
	var lbl : Label = Label.new()
	lbl.text     = txt
	lbl.position = Vector2(P, cy)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.70))
	parent.add_child(lbl)
	return cy + 16


func _slot_grid(parent: Control, cy: int, rows: int, cols: int, flat_start: int) -> int:
	var rh     : int = _slot_sz + SLOT_PAD
	var flat_i : int = flat_start
	for r in rows:
		for c in cols:
			var px : int = P + c * rh
			var py : int = cy + r * rh
			var sp : Panel = _make_slot(parent, px, py, flat_i)
			_panels.append(sp)
			_icons.append(sp.get_child(0) as TextureRect)
			_counts.append(sp.get_child(1) as Label)
			_fmap.append(flat_i)
			flat_i += 1
	return cy + rows * rh + SLOT_PAD


func _make_slot(parent: Control, px: int, py: int, flat: int) -> Panel:
	var p : Panel = Panel.new()
	p.size     = Vector2(_slot_sz, _slot_sz)
	p.position = Vector2(px, py)
	_slot_style(p, false)

	var icon : TextureRect = TextureRect.new()
	icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size         = Vector2(_slot_sz - 10, _slot_sz - 10)
	icon.position     = Vector2(5, 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)

	var cnt : Label = Label.new()
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	cnt.size         = Vector2(_slot_sz - 4, _slot_sz - 4)
	cnt.position     = Vector2(2, 2)
	cnt.add_theme_font_size_override("font_size", 11)
	cnt.add_theme_color_override("font_color", Color.WHITE)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cnt)

	p.gui_input.connect(_on_slot_input.bind(flat))
	parent.add_child(p)
	return p


func _build_footer(parent: Control, pw: int, ph: int) -> void:
	_sel_lbl          = Label.new()
	_sel_lbl.position = Vector2(P, ph - 34)
	_sel_lbl.size     = Vector2(pw - 110, 22)
	_sel_lbl.add_theme_font_size_override("font_size", 12)
	_sel_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	parent.add_child(_sel_lbl)

	var cb : Button = Button.new()
	cb.text     = "Craft"
	cb.size     = Vector2(72, 26)
	cb.position = Vector2(pw - 82, ph - 36)
	cb.pressed.connect(func(): GameData.open_crafting_requested.emit())
	parent.add_child(cb)


func _creative_section(parent: Control, cy: int) -> int:
	cy = _section_label(parent, cy, "All Items  (click to equip)")

	var scroll : ScrollContainer = ScrollContainer.new()
	_cr_scroll = scroll
	scroll.position = Vector2(P, cy)
	scroll.size     = Vector2(INV_COLS * (_slot_sz + SLOT_PAD), 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var grid : GridContainer = GridContainer.new()
	grid.columns = INV_COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	scroll.add_child(grid)

	_cr_ids.clear()
	for id: String in ItemDB.items.keys():
		if ItemDB.get_item(id).get("max_stack", 0) > 0:
			_cr_ids.append(id)

	var pad_to : int = _cr_ids.size() + (INV_COLS - _cr_ids.size() % INV_COLS) % INV_COLS + INV_COLS * 2
	while _cr_ids.size() < pad_to:
		_cr_ids.append("")

	for ci in _cr_ids.size():
		var sp : Panel = Panel.new()
		sp.custom_minimum_size = Vector2(_slot_sz, _slot_sz)
		_slot_style(sp, false)

		var icon : TextureRect = TextureRect.new()
		icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size         = Vector2(_slot_sz - 10, _slot_sz - 10)
		icon.position     = Vector2(5, 4)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var id_str : String = _cr_ids[ci]
		if id_str != "":
			icon.texture = TileTextureGenerator.get_icon(id_str, ItemDB.get_item(id_str))
			sp.gui_input.connect(_on_creative_input.bind(ci))
		sp.add_child(icon)
		grid.add_child(sp)
		_cr_panels.append(sp)

	return cy + 300 + SLOT_PAD


# -- INTERACTION --------------------------------------------------------------

func _on_slot_clicked(flat: int) -> void:
	# A creative palette item is selected — place it here.
	if _cr_selected >= 0:
		var id : String = _cr_ids[_cr_selected]
		if id != "":
			_write_item(flat, {"id": id, "count": 999, "durability": -1})
			_sync_player()
			_draw_slots()
		_cr_highlight(_cr_selected, false)
		_cr_selected = -1
		if _sel_lbl: _sel_lbl.text = ""
		return

	# Normal 2-click: select → swap/deselect.
	if _selected == -1:
		if _item_at(flat).get("id", "") == "":
			return
		_selected = flat
		_highlight(_selected, true)
		if _sel_lbl:
			_sel_lbl.text = _item_name(_item_at(flat))
	elif _selected == flat:
		_highlight(_selected, false)
		_selected = -1
		if _sel_lbl: _sel_lbl.text = ""
	else:
		var a : Dictionary = _item_at(_selected)
		var b : Dictionary = _item_at(flat)
		_write_item(_selected, b)
		_write_item(flat, a)
		_sync_player()
		_highlight(_selected, false)
		_selected = -1
		if _sel_lbl: _sel_lbl.text = ""
		_draw_slots()


func _on_creative_clicked(ci: int) -> void:
	var id : String = _cr_ids[ci]
	if id == "": return

	# A regular slot is already selected — place the creative item there.
	if _selected >= 0:
		_write_item(_selected, {"id": id, "count": 999, "durability": -1})
		_sync_player()
		_highlight(_selected, false)
		_selected = -1
		if _sel_lbl: _sel_lbl.text = ""
		_draw_slots()
		return

	# 2-click on the creative palette: select or deselect.
	if _cr_selected == ci:
		_cr_highlight(ci, false)
		_cr_selected = -1
		if _sel_lbl: _sel_lbl.text = ""
	else:
		if _cr_selected >= 0:
			_cr_highlight(_cr_selected, false)
		_cr_selected = ci
		_cr_highlight(ci, true)
		if _sel_lbl: _sel_lbl.text = ItemDB.get_item(id).get("name", id.replace("_", " ").capitalize())


func _cr_highlight(ci: int, on: bool) -> void:
	if ci < 0 or ci >= _cr_panels.size():
		return
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.set_border_width_all(2)
	if on:
		s.bg_color     = Color(0.28, 0.26, 0.10, 0.96)
		s.border_color = Color(1.00, 0.85, 0.10)
	else:
		s.bg_color     = Color(0.17, 0.17, 0.21, 0.90)
		s.border_color = Color(0.32, 0.32, 0.42)
	_cr_panels[ci].add_theme_stylebox_override("panel", s)


# -- DATA ---------------------------------------------------------------------

func _item_at(flat: int) -> Dictionary:
	if _player == null: return {}
	if flat <= HOT_E:
		return _player.hotbar[flat].duplicate() if flat < _player.hotbar.size() else {}
	if flat <= INV_E:
		var i : int = flat - INV_S
		return _player.inventory[i].duplicate() if i < _player.inventory.size() else {}
	if flat <= CHT_E:
		var chest : Array = _chest_data()
		var i     : int   = flat - CHT_S
		return chest[i].duplicate() if i < chest.size() else {}
	return {}


func _write_item(flat: int, item: Dictionary) -> void:
	if _player == null: return
	if flat <= HOT_E:
		_player.hotbar[flat] = item
	elif flat <= INV_E:
		_player.inventory[flat - INV_S] = item
	elif flat <= CHT_E:
		var chest : Array = _chest_data()
		var i     : int   = flat - CHT_S
		while chest.size() <= i: chest.append({})
		chest[i] = item
		GameData.chest_inventories[_chest_key] = chest


func _sync_player() -> void:
	if _player == null: return
	_player.set_hotbar(_player.hotbar.duplicate(true))
	_player.set_inventory(_player.inventory.duplicate(true))


func _chest_data() -> Array:
	if _chest_key == "":
		return []
	if not GameData.chest_inventories.has(_chest_key):
		var blank : Array = []
		for _i in CHEST_COLS * CHEST_ROWS: blank.append({})
		GameData.chest_inventories[_chest_key] = blank
	return GameData.chest_inventories[_chest_key]


func _free_hotbar() -> int:
	if _player == null: return -1
	for i in _player.hotbar.size():
		if _player.hotbar[i].get("id", "") == "": return i
	return -1


# -- VISUALS ------------------------------------------------------------------

func _draw_slots() -> void:
	for pi in _panels.size():
		var flat : int        = _fmap[pi]
		var item : Dictionary = _item_at(flat)
		var id   : String     = item.get("id", "")
		if id == "":
			_icons[pi].texture = null
			_counts[pi].text   = ""
		else:
			_icons[pi].texture = TileTextureGenerator.get_icon(id, ItemDB.get_item(id))
			var c : int = item.get("count", 1)
			_counts[pi].text = "" if c <= 1 else str(c)
		var is_sel : bool = (flat == _selected)
		var is_hot : bool = (_player != null and flat == int(_player.get("selected_slot")))
		_slot_style(_panels[pi], is_sel, is_hot)
	_gp_reapply()


func _highlight(flat: int, on: bool) -> void:
	var pi : int = _fmap.find(flat)
	if pi >= 0: _slot_style(_panels[pi], on)


func _slot_style(p: Panel, selected: bool, active_hot: bool = false) -> void:
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.set_border_width_all(2)
	if selected:
		s.bg_color     = Color(0.28, 0.26, 0.10, 0.96)
		s.border_color = Color(1.00, 0.85, 0.10)
	elif active_hot:
		s.bg_color     = Color(0.15, 0.22, 0.30, 0.96)
		s.border_color = Color(0.40, 0.70, 1.00)
	else:
		s.bg_color     = Color(0.17, 0.17, 0.21, 0.90)
		s.border_color = Color(0.32, 0.32, 0.42)
	p.add_theme_stylebox_override("panel", s)


func _item_name(item: Dictionary) -> String:
	var id : String = item.get("id", "")
	var n  : String = ItemDB.get_item(id).get("name") if ItemDB.get_item(id).get("name") else id.capitalize()
	var c  : int    = item.get("count", 1)
	return n + ("  x" + str(c) if c > 1 else "")


# -- SIGNALS ------------------------------------------------------------------

func _sig_connect() -> void:
	if _player == null: return
	_safe_connect(_player, "inventory_changed",      _draw_slots)
	_safe_connect(_player, "hotbar_changed",         _on_hotbar_sig)
	_safe_connect(_player, "selected_slot_changed",  _draw_slots)


func _sig_disconnect() -> void:
	if _player == null: return
	_safe_disconnect(_player, "inventory_changed",     _draw_slots)
	_safe_disconnect(_player, "hotbar_changed",        _on_hotbar_sig)
	_safe_disconnect(_player, "selected_slot_changed", _draw_slots)


func _safe_connect(node: Node, sig: String, cb: Callable) -> void:
	if node.has_signal(sig) and not node.is_connected(sig, cb):
		node.connect(sig, cb)


func _safe_disconnect(node: Node, sig: String, cb: Callable) -> void:
	if node.has_signal(sig) and node.is_connected(sig, cb):
		node.disconnect(sig, cb)


func _on_hotbar_sig(_slot: int, _item: Dictionary) -> void:
	_draw_slots()


# -- INPUT --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()
		return

	# ── Gamepad D-pad navigation ──────────────────────────────────────────────
	if InputManager.using_gamepad():
		if event.is_action_pressed("ui_right"):
			_gp_move(1, 0);  get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			_gp_move(-1, 0); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			_gp_move(0, 1);  get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up"):
			_gp_move(0, -1); get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			if _gp_in_cr:
				if _gp_pi >= 0 and _gp_pi < _cr_panels.size():
					_on_creative_clicked(_gp_pi)
			else:
				if _gp_pi >= 0 and _gp_pi < _fmap.size():
					_on_slot_clicked(_fmap[_gp_pi])
			get_viewport().set_input_as_handled()


func _on_slot_input(ev: InputEvent, flat: int) -> void:
	if _is_click(ev):
		_on_slot_clicked(flat)


func _on_creative_input(ev: InputEvent, ci: int) -> void:
	if _is_click(ev): _on_creative_clicked(ci)


# -- GAMEPAD D-PAD NAVIGATION -------------------------------------------------

## Move the gamepad cursor by (dc cols, dr rows). Handles both normal and creative layouts.
func _gp_move(dc: int, dr: int) -> void:
	if _panels.is_empty():
		return
	# Initialise: place cursor on first hotbar slot.
	if _gp_pi < 0:
		_gp_set(0, false)
		return

	var creative : bool = not _cr_panels.is_empty()

	if creative:
		# Layout: creative palette (cr_rows × 9) sits above hotbar (1 row × 9).
		var cr_count : int = _cr_panels.size()
		var cr_rows  : int = cr_count / INV_COLS

		if _gp_in_cr:
			var row : int = _gp_pi / INV_COLS
			var col : int = (_gp_pi % INV_COLS + dc + INV_COLS) % INV_COLS
			row += dr
			if row < 0:
				# Off the top of the creative palette — go to hotbar.
				_gp_set(clampi(col, 0, _panels.size() - 1), false)
			elif row >= cr_rows:
				# Off the bottom — wrap back to row 0 of creative.
				_gp_set(clampi(col, 0, cr_count - 1), true)
			else:
				_gp_set(clampi(row * INV_COLS + col, 0, cr_count - 1), true)
		else:
			# On hotbar.
			var col : int = (_gp_pi + dc + INV_COLS) % INV_COLS
			if dr < 0:
				# Up from hotbar → last row of creative palette.
				var last_row : int = cr_rows - 1
				_gp_set(clampi(last_row * INV_COLS + col, 0, cr_count - 1), true)
			elif dr > 0:
				# Down from hotbar → first row of creative palette.
				_gp_set(clampi(col, 0, cr_count - 1), true)
			else:
				_gp_set(clampi(col, 0, _panels.size() - 1), false)
	else:
		# Normal mode: _panels[0..total_inv-1] = inventory rows, [total_inv..total_player-1] = hotbar,
		# [total_player..] = chest (chest mode only).
		var chest_open   : bool = _chest_key != ""
		var total_inv    : int  = INV_ROWS * INV_COLS   # 36
		var total_player : int  = total_inv + INV_COLS  # 45

		if chest_open and _gp_pi >= total_player:
			# ── In chest panel ──
			var ci  : int = _gp_pi - total_player
			var row : int = ci / CHEST_COLS
			var col : int = ci % CHEST_COLS + dc
			row = (row + dr + CHEST_ROWS) % CHEST_ROWS
			if col < 0:
				# Left edge of chest → jump to player panel, rightmost column, same row clamped.
				var prow : int = clampi(row, 0, INV_ROWS)
				var new_pi : int = (total_inv + 8) if prow == INV_ROWS else (prow * INV_COLS + 8)
				_gp_set(clampi(new_pi, 0, _panels.size() - 1), false)
			else:
				col = col % CHEST_COLS
				_gp_set(clampi(total_player + row * CHEST_COLS + col, 0, _panels.size() - 1), false)
		else:
			# ── In player panel ──
			var pi  : int = _gp_pi
			var row : int = pi / INV_COLS if pi < total_inv else INV_ROWS
			var col : int = pi % INV_COLS + dc
			row += dr
			if row < 0:
				row = INV_ROWS
			elif row > INV_ROWS:
				row = 0
			if chest_open and col >= INV_COLS:
				# Right edge of player → jump to chest, leftmost column, same row clamped.
				var crow : int = clampi(row if row < INV_ROWS else INV_ROWS - 1, 0, CHEST_ROWS - 1)
				_gp_set(clampi(total_player + crow * CHEST_COLS, 0, _panels.size() - 1), false)
			else:
				col = (col + INV_COLS) % INV_COLS
				var new_pi : int = (total_inv + col) if row == INV_ROWS else (row * INV_COLS + col)
				_gp_set(clampi(new_pi, 0, _panels.size() - 1), false)


## Move the cursor to panel index `pi` in the given section, restoring the old cursor style.
func _gp_set(pi: int, in_cr: bool) -> void:
	# Restore old cursor position to its normal style.
	if _gp_pi >= 0:
		if _gp_in_cr:
			if _gp_pi < _cr_panels.size():
				_cr_highlight(_gp_pi, _gp_pi == _cr_selected)
		else:
			if _gp_pi < _panels.size():
				var old_flat : int = _fmap[_gp_pi]
				_slot_style(_panels[_gp_pi],
					old_flat == _selected,
					_player != null and old_flat == int(_player.get("selected_slot")))
	_gp_pi    = pi
	_gp_in_cr = in_cr
	_gp_reapply()


## Re-apply the green cursor highlight after a _draw_slots redraw.
func _gp_reapply() -> void:
	if _gp_pi < 0:
		if _gp_tooltip: _gp_tooltip.visible = false
		return
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.set_border_width_all(3)
	s.bg_color     = Color(0.06, 0.20, 0.06, 0.96)
	s.border_color = Color(0.25, 1.00, 0.25)
	s.set_corner_radius_all(4)
	
	var target_panel : Panel = null
	var item_id      : String = ""
	
	if _gp_in_cr:
		if _gp_pi < _cr_panels.size():
			target_panel = _cr_panels[_gp_pi]
			item_id      = _cr_ids[_gp_pi]
	else:
		if _gp_pi < _panels.size():
			target_panel = _panels[_gp_pi]
			var flat : int = _fmap[_gp_pi]
			item_id = _item_at(flat).get("id", "")

	if target_panel:
		target_panel.add_theme_stylebox_override("panel", s)
		
		# Tooltip update
		if _gp_tooltip:
			if item_id != "":
				var data := ItemDB.get_item(item_id)
				var iname : String = data.get("name") if data.get("name") else item_id.capitalize()
				_gp_tooltip.text = iname
				_gp_tooltip.visible = true
				_gp_tooltip.reset_size()
				
				# Position right of the slot
				var gp : Vector2 = target_panel.global_position
				var sz : Vector2 = target_panel.size
				_gp_tooltip.global_position = gp + Vector2(sz.x + 10, (sz.y - _gp_tooltip.size.y) * 0.5)
				
				# Flip to left if it would go off-screen
				var vp_w : float = get_viewport_rect().size.x
				if _gp_tooltip.global_position.x + _gp_tooltip.size.x > vp_w - 20:
					_gp_tooltip.global_position.x = gp.x - _gp_tooltip.size.x - 10
			else:
				_gp_tooltip.visible = false


func _is_click(ev: InputEvent) -> bool:
	if ev is InputEventScreenTouch:
		return ev.pressed
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# On touch platforms, browsers fire emulated mouse events after every real touch.
		# Ignore them — the ScreenTouch already fired and we'd double-act on the same tap.
		return not InputManager.using_touch()
	return false

# -- ANALOG SCROLLING ---------------------------------------------------------

func _process(delta: float) -> void:
	# Only scroll if the UI is visible, the scroll container exists, and a gamepad is active
	if not visible or _cr_scroll == null or not InputManager.using_gamepad():
		return

	var deadzone : float = 0.2
	var sensitivity : float = 1200.0 # Adjust this value for faster/slower scrolling
	var axis_y : float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

	if abs(axis_y) > deadzone:
		_cr_scroll.scroll_vertical += axis_y * sensitivity * delta
		
