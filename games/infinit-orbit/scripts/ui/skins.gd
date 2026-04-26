# skins.gd — Personalization screen (attach to Control root)
# Ships, trails, and planet styles — preview + purchase.
extends Control

const VIEWPORT_W := 720.0
const VIEWPORT_H := 1280.0

enum Tab { SHIPS, TRAILS, PLANETS }
var _current_tab: Tab = Tab.SHIPS

# Preview animation state
var _preview_angle: float = 0.0
var _preview_trail: Array = []
var _preview_trail_max := 30
var _preview_planet_col: Color = Color(0.1, 0.4, 0.8)
var _preview_planet_pulse: float = 0.0
var _stars: Array = []

var _coin_label: Label
var _gem_label: Label
var _tab_btns: Array = []
var _card_container: Control
var _status_label: Label

var _cached_preview_tex: Texture2D
var _cached_preview_skin_id: int = -1

func _ready() -> void:
	_build_stars()
	_build_ui()
	SaveManager.coins_updated.connect(func(c: int):
		if is_instance_valid(_coin_label): _coin_label.text = " %d" % c)
	SaveManager.gems_updated.connect(func(g: int):
		if is_instance_valid(_gem_label): _gem_label.text = " %d" % g)

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 70:
		_stars.append({
			"pos": Vector2(rng.randf_range(0, VIEWPORT_W), rng.randf_range(0, VIEWPORT_H)),
			"size": rng.randf_range(0.8, 2.2),
			"alpha": rng.randf_range(0.3, 0.9),
			"twinkle": rng.randf_range(0.5, 2.0),
			"phase": rng.randf_range(0.0, TAU),
		})

func _build_ui() -> void:
	# ── Header ──
	var hdr_bg := ColorRect.new()
	hdr_bg.size = Vector2(VIEWPORT_W, 130)
	hdr_bg.color = Color(0.04, 0.04, 0.16)
	add_child(hdr_bg)

	var title_lbl := Label.new()
	title_lbl.position = Vector2(0, 30)
	title_lbl.size = Vector2(VIEWPORT_W, 50)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.text = "PERSONALIZE"
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(title_lbl)

	# Currency Row
	var cur_row := HBoxContainer.new()
	cur_row.position = Vector2(20, 88)
	cur_row.size = Vector2(400, 36)
	cur_row.add_theme_constant_override("separation", 20)
	add_child(cur_row)

	# Coins
	var coin_box := HBoxContainer.new()
	cur_row.add_child(coin_box)
	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/icons/coin.svg")
	coin_icon.custom_minimum_size = Vector2(24, 24)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = Color(1.0, 0.9, 0.2)
	coin_box.add_child(coin_icon)
	_coin_label = Label.new()
	_coin_label.text = " %d" % SaveManager.get_coins()
	_coin_label.add_theme_font_size_override("font_size", 22)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	coin_box.add_child(_coin_label)

	# Gems
	var gem_box := HBoxContainer.new()
	cur_row.add_child(gem_box)
	var gem_icon := TextureRect.new()
	gem_icon.texture = load("res://assets/icons/gem.svg")
	gem_icon.custom_minimum_size = Vector2(24, 24)
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon.modulate = Color(0.6, 0.9, 1.0)
	gem_box.add_child(gem_icon)
	_gem_label = Label.new()
	_gem_label.text = " %d" % SaveManager.get_gems()
	_gem_label.add_theme_font_size_override("font_size", 22)
	_gem_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	gem_box.add_child(_gem_label)

	# ── Tab buttons ──
	var tab_labels := ["SHIPS", "TRAILS", "PLANETS"]
	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(20, 136)
	tab_row.size = Vector2(VIEWPORT_W - 40, 52)
	tab_row.add_theme_constant_override("separation", 10)
	add_child(tab_row)
	for i in tab_labels.size():
		var tb := Button.new()
		tb.text = tab_labels[i]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 50)
		tb.add_theme_font_size_override("font_size", 20)
		_style_tab_btn(tb, i == 0)
		var idx := i
		tb.pressed.connect(func(): _switch_tab(idx))
		tab_row.add_child(tb)
		_tab_btns.append(tb)

	# ── Preview area ──
	var preview_bg := PanelContainer.new()
	preview_bg.position = Vector2(VIEWPORT_W / 2.0 - 110, 200)
	preview_bg.size = Vector2(220, 220)
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color(0.06, 0.06, 0.18)
	pb_style.border_color = Color(1, 1, 1, 0.12)
	pb_style.set_border_width_all(1)
	pb_style.set_corner_radius_all(110)
	preview_bg.add_theme_stylebox_override("panel", pb_style)
	add_child(preview_bg)

	var preview_lbl := Label.new()
	preview_lbl.name = "PreviewLabel"
	preview_lbl.position = Vector2(VIEWPORT_W / 2.0 - 80, 436)
	preview_lbl.size = Vector2(160, 30)
	preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_lbl.add_theme_font_size_override("font_size", 16)
	preview_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(preview_lbl)

	# ── Card scroll area ──
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 475)
	scroll.size = Vector2(VIEWPORT_W, VIEWPORT_H - 560)
	add_child(scroll)

	_card_container = HBoxContainer.new()
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_container.add_theme_constant_override("separation", 12)
	scroll.add_child(_card_container)

	# Padding
	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(10, 0)
	_card_container.add_child(pad_l)

	# ── Status label ──
	_status_label = Label.new()
	_status_label.position = Vector2(0, VIEWPORT_H - 130)
	_status_label.size = Vector2(VIEWPORT_W, 40)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	_status_label.modulate.a = 0.0
	add_child(_status_label)

	# ── Back button ──
	var back_btn := Button.new()
	back_btn.position = Vector2(20, VIEWPORT_H - 90)
	back_btn.size = Vector2(160, 54)
	back_btn.text = "← BACK"
	back_btn.add_theme_font_size_override("font_size", 24)
	_style_action_btn(back_btn, Color(0.6, 0.6, 0.9))
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	_populate_tab(Tab.SHIPS)

func _style_tab_btn(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.85, 1.0, 0.5 if active else 0.12)
	s.border_color = Color(0.2, 0.85, 1.0, 1.0 if active else 0.3)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color.WHITE if active else Color(1, 1, 1, 0.55))

func _style_action_btn(btn: Button, col: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.2)
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _switch_tab(idx: int) -> void:
	_current_tab = idx as Tab
	for i in _tab_btns.size():
		_style_tab_btn(_tab_btns[i], i == idx)
	_populate_tab(_current_tab)
	AudioManager.play_sfx("ui_click")

func _populate_tab(tab: Tab) -> void:
	var to_remove := _card_container.get_children().slice(1)
	for child in to_remove:
		_card_container.remove_child(child)
		child.queue_free()

	match tab:
		Tab.SHIPS:
			for skin in SaveManager.SKIN_DATA:
				_card_container.add_child(_make_item_card(skin, "skin"))
		Tab.TRAILS:
			for trail in SaveManager.TRAIL_DATA:
				_card_container.add_child(_make_item_card(trail, "trail"))
		Tab.PLANETS:
			for planet in SaveManager.PLANET_DATA:
				_card_container.add_child(_make_item_card(planet, "planet"))

func _make_item_card(item: Dictionary, item_type: String) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(148, 200)

	var unlocked := _is_unlocked(item, item_type)
	var active := _is_active(item, item_type)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.22) if unlocked else Color(0.04, 0.04, 0.12)
	var border_col := Color.WHITE * Color(1,1,1, 0.7) if active else Color(1,1,1,0.2)
	bg.border_color = border_col
	bg.set_border_width_all(3 if active else 1)
	bg.set_corner_radius_all(12)

	var panel := PanelContainer.new()
	panel.size = Vector2(148, 196)
	panel.add_theme_stylebox_override("panel", bg)
	card.add_child(panel)

	var inner := Control.new()
	inner.size = Vector2(148, 196)
	panel.add_child(inner)

	# Preview circle — drawn via draw signal, no load() inside
	var preview_rect := Control.new()
	preview_rect.name = "PreviewRect"
	preview_rect.position = Vector2(24, 20)
	preview_rect.size = Vector2(100, 100)
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Capture values to avoid capturing the loop variable by reference
	var captured_item := item
	var captured_type := item_type
	preview_rect.draw.connect(func():
		_draw_item_preview(preview_rect, captured_item, captured_type)
	)
	inner.add_child(preview_rect)

	if active:
		var active_badge := Label.new()
		active_badge.position = Vector2(0, 0)
		active_badge.size = Vector2(148, 22)
		active_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_badge.text = "● EQUIPPED"
		active_badge.add_theme_font_size_override("font_size", 12)
		active_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		inner.add_child(active_badge)

	# Name label
	var name_lbl := Label.new()
	name_lbl.position = Vector2(0, 126)
	name_lbl.size = Vector2(148, 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.text = item["name"]
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(1,1,1,0.4))
	inner.add_child(name_lbl)

	# Cost / action button
	var action_btn := Button.new()
	action_btn.position = Vector2(12, 158)
	action_btn.size = Vector2(124, 36)
	action_btn.add_theme_font_size_override("font_size", 14)

	if active:
		action_btn.text = "EQUIPPED"
		action_btn.disabled = true
		_style_action_btn(action_btn, Color(0.2, 1.0, 0.5))
	elif unlocked:
		action_btn.text = "EQUIP"
		_style_action_btn(action_btn, Color(0.2, 0.85, 1.0))
		action_btn.pressed.connect(_on_equip.bind(item, item_type))
	else:
		var cost_text := "GEM %d" % item["cost"] if item["gems"] else "◆%d" % item["cost"]
		action_btn.text = cost_text
		var can_buy := _can_afford(item)
		_style_action_btn(action_btn, Color(1.0, 0.85, 0.15) if can_buy else Color(0.4, 0.4, 0.4))
		action_btn.disabled = not can_buy
		action_btn.pressed.connect(_on_buy_item.bind(item, item_type))
		# Lock overlay
		var lock_lbl := Label.new()
		lock_lbl.position = Vector2(0, 20)
		lock_lbl.size = Vector2(148, 100)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.text = "LOCK"
		lock_lbl.add_theme_font_size_override("font_size", 18)
		lock_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		inner.add_child(lock_lbl)

	inner.add_child(action_btn)
	return card

func _draw_item_preview(ctrl: Control, item: Dictionary, item_type: String) -> void:
	if not is_instance_valid(ctrl):
		return
	var center := Vector2(ctrl.size.x / 2.0, ctrl.size.y / 2.0)
	ctrl.draw_circle(center, 48, Color(0.04, 0.04, 0.15))

	match item_type:
		"skin":
			var col: Color = item.get("color", Color.WHITE)
			var skin_icon: String = item.get("icon", "res://assets/ships/ship_classic.svg")
			ctrl.draw_circle(center, 48, Color(col.r, col.g, col.b, 0.1))
			var tex: Texture2D = load(skin_icon) if skin_icon != "" else null
			if tex:
				var draw_size := Vector2(36, 36)
				ctrl.draw_texture_rect(tex, Rect2(center - draw_size/2.0, draw_size), false, col)
			else:
				var pts := PackedVector2Array([
					center + Vector2(0, -18), center + Vector2(12, 14), center + Vector2(-12, 14)
				])
				ctrl.draw_polygon(pts, PackedColorArray([col, col, col]))
			ctrl.draw_arc(center, 44, 0, TAU, 48, Color(col.r, col.g, col.b, 0.3), 2.0)

		"trail":
			var tl: Array[Color] = [Color.WHITE, Color(0.3, 0.7, 1), Color(1, 0.8, 0.1),
				Color(0.9, 0.2, 1), Color(0.2, 1, 0.5), Color(0.05, 0.05, 0.2)]
			var trail_id: int = item.get("id", 0)
			for i in 8:
				var t := float(i + 1) / 9.0
				var x := 20.0 + i * 7.5
				var col: Color = tl[trail_id % tl.size()]
				var a := t * t
				ctrl.draw_circle(Vector2(x, 50.0 - sin(t * PI * 1.5) * 15.0), 4.0 * t, Color(col.r, col.g, col.b, a))

		"planet":
			var pc: Color = item.get("color", Color(0.1, 0.4, 0.8))
			var pat: String = item.get("pattern", "default")
			ctrl.draw_circle(center, 36, pc.darkened(0.3))
			ctrl.draw_circle(center, 32, pc)
			
			if pat == "grid":
				for i in range(-3, 4):
					ctrl.draw_line(center + Vector2(i*8, -25), center + Vector2(i*8, 25), pc.lightened(0.3), 1.0)
					ctrl.draw_line(center + Vector2(-25, i*8), center + Vector2(25, i*8), pc.lightened(0.3), 1.0)
			elif pat == "lava":
				for i in 4:
					ctrl.draw_circle(center + Vector2(sin(i)*15, cos(i)*15), 10, pc.lightened(0.2))
			elif pat == "ice":
				for i in 8:
					ctrl.draw_line(center, center + Vector2(cos(i)*30, sin(i)*30), Color.WHITE, 1.0)
			
			ctrl.draw_arc(center, 42, deg_to_rad(30), deg_to_rad(210), 40, Color(pc.lightened(0.4).r, pc.lightened(0.4).g, pc.lightened(0.4).b, 0.5), 3.0)
			ctrl.draw_circle(center + Vector2(-10, -10), 8, Color(1, 1, 1, 0.15))

func _is_unlocked(item: Dictionary, item_type: String) -> bool:
	match item_type:
		"skin":    return SaveManager.is_skin_unlocked(item["id"])
		"trail":   return SaveManager.is_trail_unlocked(item["id"])
		"planet":  return SaveManager.is_planet_unlocked(item["id"])
	return false

func _is_active(item: Dictionary, item_type: String) -> bool:
	match item_type:
		"skin":    return SaveManager.get_active_skin() == item["id"]
		"trail":   return SaveManager.get_active_trail() == item["id"]
		"planet":  return SaveManager.get_active_planet() == item["id"]
	return false

func _can_afford(item: Dictionary) -> bool:
	if item["gems"]:
		return SaveManager.get_gems() >= item["cost"]
	return SaveManager.get_coins() >= item["cost"]

func _on_equip(item: Dictionary, item_type: String) -> void:
	match item_type:
		"skin":   SaveManager.set_active_skin(item["id"])
		"trail":  SaveManager.set_active_trail(item["id"])
		"planet": SaveManager.set_active_planet(item["id"])
	_show_status("Equipped %s!" % item["name"])
	AudioManager.play_sfx("ui_click")
	# Deferred so we don't free this button's parent card during its own pressed signal
	call_deferred("_populate_tab", _current_tab)

func _on_buy_item(item: Dictionary, item_type: String) -> void:
	var success := false
	match item_type:
		"skin":   success = SaveManager.buy_skin(item["id"])
		"trail":  success = SaveManager.buy_trail(item["id"])
		"planet": success = SaveManager.buy_planet(item["id"])
	if success:
		AudioManager.play_sfx("reward")
		_show_status("Unlocked %s!" % item["name"])
		call_deferred("_populate_tab", _current_tab)
	else:
		_show_status("Not enough currency!")
		AudioManager.play_sfx("shield_hit")

func _show_status(text: String) -> void:
	_status_label.text = text
	var tw := create_tween()
	tw.tween_property(_status_label, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.5)
	tw.tween_property(_status_label, "modulate:a", 0.0, 0.3)

func _on_back() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _process(delta: float) -> void:
	_preview_angle += delta * 1.5
	_preview_planet_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0012)
	for s in _stars:
		s["phase"] += s["twinkle"] * delta
		s["alpha"] = 0.3 + 0.7 * (0.5 + 0.5 * sin(s["phase"]))
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.03, 0.03, 0.12))
	for s in _stars:
		draw_circle(s["pos"], s["size"], Color(s["alpha"], s["alpha"], s["alpha"] * 0.95))
	
	# Preview panel animation
	var pv_center := Vector2(VIEWPORT_W / 2.0, 310.0)
	draw_circle(pv_center, 96, Color(0.04, 0.04, 0.16))
	
	# Draw current active items preview
	var skin_idx := SaveManager.get_active_skin()
	var skin_data: Dictionary = SaveManager.SKIN_DATA[skin_idx]
	var skin_col: Color = skin_data.get("color", Color.WHITE)
	var skin_icon: String = skin_data.get("icon", "res://assets/ships/ship_classic.svg")
	var planet_idx := SaveManager.get_active_planet()
	var planet_col: Color = SaveManager.PLANET_DATA[planet_idx].get("color", Color(0.1, 0.4, 0.8))
	
	# Mini planet
	draw_circle(pv_center, 28, planet_col.darkened(0.3))
	draw_circle(pv_center, 22, planet_col)
	draw_circle(pv_center, 12, planet_col.lightened(0.2))
	
	# Orbit path
	draw_arc(pv_center, 68, 0, TAU, 64, Color(skin_col.r, skin_col.g, skin_col.b, 0.2), 2.0)
	
	# Update preview texture cache only when skin changes
	if skin_idx != _cached_preview_skin_id:
		_cached_preview_skin_id = skin_idx
		_cached_preview_tex = load(skin_icon) if skin_icon != "" else null

	# Player on orbit
	var pp := pv_center + Vector2(cos(_preview_angle), sin(_preview_angle)) * 68.0
	if _cached_preview_tex:
		var draw_size := Vector2(28, 28)
		draw_set_transform(pp, _preview_angle + PI / 2.0, Vector2.ONE)
		draw_texture_rect(_cached_preview_tex, Rect2(-draw_size / 2.0, draw_size), false, skin_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
