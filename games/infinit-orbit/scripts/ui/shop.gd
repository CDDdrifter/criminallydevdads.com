# shop.gd — Upgrade Shop
extends Control

const VIEWPORT_W := 720.0
const VIEWPORT_H := 1280.0

const UPGRADES: Array = [
	{
		"id": "speed",
		"name": "ENGINE BOOST",
		"desc": "Increases orbit speed — reach gaps faster.",
		"icon": "res://assets/icons/speed.svg",
		"color": Color(0.2, 0.85, 1.0),
	},
	{
		"id": "handling",
		"name": "AGILITY",
		"desc": "Faster direction switch response.",
		"icon": "res://assets/icons/handling.svg",
		"color": Color(0.8, 0.4, 1.0),
	},
	{
		"id": "coin_magnet",
		"name": "COIN MAGNET",
		"desc": "Attracts coins from greater distance.",
		"icon": "res://assets/icons/coin.svg",
		"color": Color(1.0, 0.85, 0.15),
	},
	{
		"id": "shield",
		"name": "SHIELD CORE",
		"desc": "Extends shield duration on activation.",
		"icon": "res://assets/icons/shield.svg",
		"color": Color(0.3, 1.0, 0.5),
	},
]

var _upgrade_cards: Array = []
var _coin_label: Label
var _flash_overlay: ColorRect
var _reset_btn: Button
var _status_lbl: Label

func _ready() -> void:
	_build_ui()
	SaveManager.coins_updated.connect(_on_coins_updated)

func _build_ui() -> void:
	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(1, 1, 1, 0.0)
	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_overlay)

	var header := _make_header()
	add_child(header)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 150)
	scroll.size = Vector2(VIEWPORT_W, VIEWPORT_H - 280)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer_top)

	for upg in UPGRADES:
		var card := _make_upgrade_card(upg)
		vbox.add_child(card)
		_upgrade_cards.append(card)

	# Status label
	_status_lbl = Label.new()
	_status_lbl.position = Vector2(0, VIEWPORT_H - 200)
	_status_lbl.size = Vector2(VIEWPORT_W, 36)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	_status_lbl.modulate.a = 0.0
	add_child(_status_lbl)

	# Reset upgrades button (50% refund)
	_reset_btn = Button.new()
	_reset_btn.position = Vector2(20, VIEWPORT_H - 160)
	_reset_btn.size = Vector2(VIEWPORT_W - 40, 52)
	_reset_btn.text = "RESET ALL UPGRADES  (50%% refund: %d Coins)" % (SaveManager.get_total_upgrade_spend() / 2)
	_reset_btn.add_theme_font_size_override("font_size", 17)
	_style_btn(_reset_btn, Color(1.0, 0.55, 0.1))
	_reset_btn.pressed.connect(_on_reset_upgrades)
	add_child(_reset_btn)

	var back_btn := Button.new()
	back_btn.position = Vector2(20, VIEWPORT_H - 96)
	back_btn.size = Vector2(160, 54)
	back_btn.text = "← BACK"
	back_btn.add_theme_font_size_override("font_size", 24)
	_style_btn(back_btn, Color(0.6, 0.6, 0.9))
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _make_header() -> Control:
	var hdr := Control.new()
	hdr.size = Vector2(VIEWPORT_W, 140)

	var bg := ColorRect.new()
	bg.size = Vector2(VIEWPORT_W, 140)
	bg.color = Color(0.04, 0.04, 0.16)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(bg)

	var title := Label.new()
	title.position = Vector2(0, 30)
	title.size = Vector2(VIEWPORT_W, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "UPGRADE SHOP"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	hdr.add_child(title)

	var coin_box := HBoxContainer.new()
	coin_box.position = Vector2(0, 90)
	coin_box.size = Vector2(VIEWPORT_W, 36)
	coin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_child(coin_box)

	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/icons/coin.svg")
	coin_icon.custom_minimum_size = Vector2(28, 28)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.modulate = Color(1.0, 0.9, 0.2)
	coin_box.add_child(coin_icon)

	_coin_label = Label.new()
	_coin_label.text = " %d" % SaveManager.get_coins()
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	coin_box.add_child(_coin_label)

	return hdr

func _make_upgrade_card(upg: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(VIEWPORT_W - 40, 160)
	card.name = "Card_" + upg["id"]

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.18)
	bg.border_color = (upg["color"] as Color) * Color(1, 1, 1, 0.35)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(14)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 0)
	panel.size = Vector2(VIEWPORT_W - 40, 155)
	panel.add_theme_stylebox_override("panel", bg)
	card.add_child(panel)

	var inner := Control.new()
	inner.size = Vector2(VIEWPORT_W - 40, 155)
	panel.add_child(inner)

	var icon_rect := TextureRect.new()
	icon_rect.position = Vector2(12, 12)
	icon_rect.size = Vector2(52, 52)
	icon_rect.texture = load(upg["icon"])
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = upg["color"]
	inner.add_child(icon_rect)

	var name_lbl := Label.new()
	name_lbl.position = Vector2(76, 14)
	name_lbl.size = Vector2(350, 38)
	name_lbl.text = upg["name"]
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", upg["color"])
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.position = Vector2(70, 50)
	desc_lbl.size = Vector2(360, 36)
	desc_lbl.text = upg["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	inner.add_child(desc_lbl)

	var pip_row := _make_pip_row(upg["id"], upg["color"])
	pip_row.position = Vector2(70, 94)
	inner.add_child(pip_row)
	pip_row.name = "Pips"

	var lvl: int = SaveManager.get_upgrade_level(upg["id"])
	var max_lvl: int = SaveManager.UPGRADE_MAX_LEVELS[upg["id"]]
	var level_lbl := Label.new()
	level_lbl.position = Vector2(16, 56)
	level_lbl.size = Vector2(46, 30)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.text = "%d/%d" % [lvl, max_lvl]
	level_lbl.add_theme_font_size_override("font_size", 14)
	level_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	level_lbl.name = "LevelLabel"
	inner.add_child(level_lbl)

	var buy_btn := Button.new()
	buy_btn.position = Vector2(panel.size.x - 130, 50)
	buy_btn.size = Vector2(112, 56)
	buy_btn.name = "BuyBtn"
	_update_buy_button(buy_btn, upg["id"], upg["color"])
	buy_btn.pressed.connect(_on_buy.bind(upg["id"], card))
	inner.add_child(buy_btn)

	return card

func _make_pip_row(upg_id: String, col: Color) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(340, 22)
	var lvl := SaveManager.get_upgrade_level(upg_id)
	var max_lvl: int = SaveManager.UPGRADE_MAX_LEVELS[upg_id]
	var pip_w := minf(28.0, 320.0 / max_lvl - 3.0)
	for i in max_lvl:
		var pip := ColorRect.new()
		pip.position = Vector2(i * (pip_w + 3), 0)
		pip.size = Vector2(pip_w, 14)
		pip.color = col if i < lvl else Color(col.r, col.g, col.b, 0.18)
		row.add_child(pip)
	return row

func _update_buy_button(btn: Button, upg_id: String, col: Color) -> void:
	var cost := SaveManager.get_upgrade_cost(upg_id)
	if cost == -1:
		btn.text = "MAX"
		btn.disabled = true
		_style_btn(btn, Color(0.4, 0.4, 0.4))
	else:
		var can_afford := SaveManager.get_coins() >= cost
		btn.text = str(cost)
		btn.disabled = not can_afford
		_style_btn(btn, col if can_afford else Color(0.4, 0.4, 0.4))
	btn.add_theme_font_size_override("font_size", 18)

func _style_btn(btn: Button, col: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.25)
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", s)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(col.r, col.g, col.b, 0.45)
	sh.border_color = col.lightened(0.3)
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var sd := StyleBoxFlat.new()
	sd.bg_color = Color(col.r, col.g, col.b, 0.1)
	sd.border_color = Color(col.r, col.g, col.b, 0.3)
	sd.set_border_width_all(2)
	sd.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))

func _on_buy(upg_id: String, card: Control) -> void:
	var success := SaveManager.buy_upgrade(upg_id)
	if not success:
		var tw := create_tween()
		tw.tween_property(card, "position:x", card.position.x - 8.0, 0.05)
		tw.tween_property(card, "position:x", card.position.x + 8.0, 0.05)
		tw.tween_property(card, "position:x", card.position.x - 4.0, 0.05)
		tw.tween_property(card, "position:x", card.position.x, 0.05)
		AudioManager.play_sfx("shield_hit")
		return
	AudioManager.play_sfx("shop_buy")
	var tw := create_tween()
	tw.tween_property(_flash_overlay, "color:a", 0.35, 0.1)
	tw.tween_property(_flash_overlay, "color:a", 0.0, 0.2)
	_refresh_card(card, upg_id)
	_refresh_reset_btn()

func _on_reset_upgrades() -> void:
	var spent := SaveManager.get_total_upgrade_spend()
	if spent == 0:
		_show_status("No upgrades to reset.")
		return
	var refund := SaveManager.reset_upgrades()
	AudioManager.play_sfx("reward")
	_show_status("Upgrades reset! +%d Coins refunded." % refund)
	# Rebuild all cards
	for i in UPGRADES.size():
		_refresh_card(_upgrade_cards[i], UPGRADES[i]["id"])
	_refresh_reset_btn()

func _refresh_reset_btn() -> void:
	if is_instance_valid(_reset_btn):
		_reset_btn.text = "RESET ALL UPGRADES  (50%% refund: %d Coins)" % (SaveManager.get_total_upgrade_spend() / 2)

func _show_status(text: String) -> void:
	if not is_instance_valid(_status_lbl):
		return
	_status_lbl.text = text
	var tw := create_tween()
	tw.tween_property(_status_lbl, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(_status_lbl, "modulate:a", 0.0, 0.4)

func _refresh_card(card: Control, upg_id: String) -> void:
	var upg_info: Dictionary = {}
	for u in UPGRADES:
		if u["id"] == upg_id:
			upg_info = u
			break
	var panel := card.get_child(0) as PanelContainer
	var inner := panel.get_child(0) as Control

	var old_pips := inner.find_child("Pips", false, false)
	if old_pips:
		old_pips.queue_free()
	var new_pips := _make_pip_row(upg_id, upg_info["color"])
	new_pips.position = Vector2(70, 94)
	new_pips.name = "Pips"
	inner.add_child(new_pips)

	var lvl := SaveManager.get_upgrade_level(upg_id)
	var max_lvl: int = SaveManager.UPGRADE_MAX_LEVELS[upg_id]
	var level_lbl := inner.find_child("LevelLabel", false, false) as Label
	if level_lbl:
		level_lbl.text = "%d/%d" % [lvl, max_lvl]

	var buy_btn := inner.find_child("BuyBtn", false, false) as Button
	if buy_btn:
		_update_buy_button(buy_btn, upg_id, upg_info["color"])

func _on_coins_updated(new_val: int) -> void:
	if _coin_label:
		_coin_label.text = " %d" % new_val
	for i in UPGRADES.size():
		var upg: Dictionary = UPGRADES[i]
		var card: Control = _upgrade_cards[i]
		if not is_instance_valid(card):
			continue
		var panel := card.get_child(0) as PanelContainer
		if not panel:
			continue
		var inner := panel.get_child(0) as Control
		if not inner:
			continue
		var buy_btn := inner.find_child("BuyBtn", false, false) as Button
		if buy_btn:
			_update_buy_button(buy_btn, upg["id"], upg["color"])

func _on_back() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.03, 0.03, 0.12))
