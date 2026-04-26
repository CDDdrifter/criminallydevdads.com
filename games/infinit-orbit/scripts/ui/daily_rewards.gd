# daily_rewards.gd — Daily login reward + mystery crate screen (28-day cycle)
extends Control

const VIEWPORT_W := 720.0
const VIEWPORT_H := 1280.0

var _stars: Array = []
var _crate_spinning: bool = false
var _crate_spin_angle: float = 0.0
var _claim_btn: Button
var _claim_timer_lbl: Label
var _crate_btn: Button
var _crate_timer_lbl: Label
var _reward_popup: Control

const WEEK_COLORS: Array = [
	Color(0.2, 0.85, 1.0),   # Week 1 — cyan
	Color(1.0, 0.75, 0.1),   # Week 2 — gold
	Color(0.75, 0.35, 1.0),  # Week 3 — purple
	Color(1.0, 0.4, 0.15),   # Week 4 — orange-red
]

func _ready() -> void:
	_build_stars()
	_build_ui()

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 80:
		_stars.append({
			"pos": Vector2(rng.randf_range(0, VIEWPORT_W), rng.randf_range(0, VIEWPORT_H)),
			"size": rng.randf_range(0.8, 2.2),
			"alpha": rng.randf_range(0.3, 0.9),
			"twinkle": rng.randf_range(0.5, 2.0),
			"phase": rng.randf_range(0.0, TAU),
		})

func _build_ui() -> void:
	# ── Header ──
	var hdr := ColorRect.new()
	hdr.size = Vector2(VIEWPORT_W, 110)
	hdr.color = Color(0.04, 0.04, 0.16)
	add_child(hdr)

	var title := Label.new()
	title.position = Vector2(0, 26)
	title.size = Vector2(VIEWPORT_W, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "DAILY REWARDS"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)

	# ── Streak bar ──
	var streak_box := HBoxContainer.new()
	streak_box.position = Vector2(0, 116)
	streak_box.size = Vector2(VIEWPORT_W, 40)
	streak_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(streak_box)

	var fire_icon := TextureRect.new()
	fire_icon.texture = load("res://assets/icons/fire.svg")
	fire_icon.custom_minimum_size = Vector2(26, 26)
	fire_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fire_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fire_icon.modulate = Color(1.0, 0.65, 0.1)
	streak_box.add_child(fire_icon)

	var cur_streak := SaveManager.get_daily_streak()
	var cycle_day := cur_streak % SaveManager.DAILY_CYCLE  # 0-27 position in cycle
	var streak_txt: String
	if cur_streak == 0:
		streak_txt = "  Start your streak!"
	elif not SaveManager.can_claim_daily():
		streak_txt = "  Day %d claimed — come back tomorrow!" % (cycle_day if cycle_day > 0 else SaveManager.DAILY_CYCLE)
	else:
		streak_txt = "  %d day streak — Day %d ready!" % [cur_streak, (cycle_day + 1)]
	var streak_lbl := Label.new()
	streak_lbl.text = streak_txt
	streak_lbl.add_theme_font_size_override("font_size", 19)
	streak_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	streak_box.add_child(streak_lbl)

	# ── 28-day calendar (scrollable) ──
	var cal_scroll := ScrollContainer.new()
	cal_scroll.position = Vector2(16, 164)
	cal_scroll.size = Vector2(VIEWPORT_W - 32, 448)
	add_child(cal_scroll)

	var cal_vbox := VBoxContainer.new()
	cal_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cal_vbox.add_theme_constant_override("separation", 4)
	cal_scroll.add_child(cal_vbox)

	# Build 4 weeks
	for week_idx in 4:
		var week_col: Color = WEEK_COLORS[week_idx]

		var week_hdr := Label.new()
		week_hdr.text = "WEEK %d" % (week_idx + 1)
		week_hdr.add_theme_font_size_override("font_size", 14)
		week_hdr.add_theme_color_override("font_color", Color(week_col.r, week_col.g, week_col.b, 0.75))
		week_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var hdr_margin := MarginContainer.new()
		hdr_margin.add_theme_constant_override("margin_left", 2)
		hdr_margin.add_theme_constant_override("margin_top", 6 if week_idx > 0 else 2)
		hdr_margin.add_child(week_hdr)
		cal_vbox.add_child(hdr_margin)

		var week_row := HBoxContainer.new()
		week_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		week_row.add_theme_constant_override("separation", 5)
		cal_vbox.add_child(week_row)

		for day_in_week in 7:
			var day_idx: int = week_idx * 7 + day_in_week
			week_row.add_child(_make_day_card(day_idx, week_col))

	# ── Claim button ──
	_claim_btn = Button.new()
	_claim_btn.position = Vector2(VIEWPORT_W / 2.0 - 155, 626)
	_claim_btn.size = Vector2(310, 62)
	_claim_btn.add_theme_font_size_override("font_size", 26)
	_update_claim_btn()
	_claim_btn.pressed.connect(_on_claim)
	add_child(_claim_btn)

	_claim_timer_lbl = Label.new()
	_claim_timer_lbl.position = Vector2(0, 694)
	_claim_timer_lbl.size = Vector2(VIEWPORT_W, 28)
	_claim_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_claim_timer_lbl.add_theme_font_size_override("font_size", 16)
	_claim_timer_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	add_child(_claim_timer_lbl)

	# ── Mystery Crate ──
	var crate_panel := PanelContainer.new()
	crate_panel.position = Vector2(16, 730)
	crate_panel.size = Vector2(VIEWPORT_W - 32, 290)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.06, 0.04, 0.18)
	cs.border_color = Color(0.8, 0.5, 1.0, 0.35)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(16)
	crate_panel.add_theme_stylebox_override("panel", cs)
	add_child(crate_panel)

	var crate_inner := Control.new()
	crate_inner.size = Vector2(VIEWPORT_W - 32, 290)
	crate_panel.add_child(crate_inner)

	var crate_title := Label.new()
	crate_title.position = Vector2(0, 18)
	crate_title.size = Vector2(VIEWPORT_W - 32, 42)
	crate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_title.text = "MYSTERY CRATE"
	crate_title.add_theme_font_size_override("font_size", 26)
	crate_title.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))
	crate_inner.add_child(crate_title)

	var crate_desc := Label.new()
	crate_desc.position = Vector2(30, 62)
	crate_desc.size = Vector2(VIEWPORT_W - 92, 36)
	crate_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_desc.text = "Free every 4 hours — Common to Legendary!"
	crate_desc.add_theme_font_size_override("font_size", 15)
	crate_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	crate_inner.add_child(crate_desc)

	_crate_timer_lbl = Label.new()
	_crate_timer_lbl.position = Vector2(0, 196)
	_crate_timer_lbl.size = Vector2(VIEWPORT_W - 32, 32)
	_crate_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crate_timer_lbl.add_theme_font_size_override("font_size", 16)
	_crate_timer_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	crate_inner.add_child(_crate_timer_lbl)

	_crate_btn = Button.new()
	_crate_btn.position = Vector2((VIEWPORT_W - 32) / 2.0 - 130, 234)
	_crate_btn.size = Vector2(260, 52)
	_crate_btn.add_theme_font_size_override("font_size", 22)
	_update_crate_btn()
	_crate_btn.pressed.connect(_on_open_crate)
	crate_inner.add_child(_crate_btn)

	# ── Reward popup ──
	_reward_popup = _make_reward_popup()
	_reward_popup.visible = false
	add_child(_reward_popup)

	# ── Back button ──
	var back_btn := Button.new()
	back_btn.position = Vector2(20, VIEWPORT_H - 84)
	back_btn.size = Vector2(160, 52)
	back_btn.text = "← BACK"
	back_btn.add_theme_font_size_override("font_size", 22)
	_style_btn(back_btn, Color(0.6, 0.6, 0.9))
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

# ─── DAY CARD ─────────────────────────────────────────────────────────────────
func _make_day_card(day_idx: int, week_col: Color) -> Control:
	var cur_streak := SaveManager.get_daily_streak()
	var can_claim := SaveManager.can_claim_daily()

	# Which day (0-27) is the active one right now
	var active_idx: int
	if can_claim:
		active_idx = cur_streak % SaveManager.DAILY_CYCLE
	else:
		active_idx = (cur_streak - 1 + SaveManager.DAILY_CYCLE) % SaveManager.DAILY_CYCLE

	var is_today := day_idx == active_idx
	var is_claimed: bool
	if can_claim:
		is_claimed = day_idx < (cur_streak % SaveManager.DAILY_CYCLE) and cur_streak > 0
	else:
		is_claimed = day_idx <= active_idx
	var is_future := not is_claimed and not is_today

	var reward_info: Dictionary = SaveManager.DAILY_REWARDS[day_idx]

	var card := Control.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 95)

	var style := StyleBoxFlat.new()
	if is_claimed:
		style.bg_color = Color(0.06, 0.25, 0.08)
		style.border_color = Color(0.2, 0.9, 0.35, 0.55)
		style.set_border_width_all(1)
	elif is_today:
		style.bg_color = Color(0.12, 0.1, 0.28)
		style.border_color = week_col
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.04, 0.04, 0.12)
		style.border_color = Color(1, 1, 1, 0.1)
		style.set_border_width_all(1)
	style.set_corner_radius_all(8)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 93)
	panel.add_theme_stylebox_override("panel", style)
	card.add_child(panel)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 1)
	panel.add_child(inner)

	# Day number
	var day_lbl := Label.new()
	day_lbl.text = "%d" % (day_idx + 1)
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_lbl.add_theme_font_size_override("font_size", 13)
	day_lbl.add_theme_color_override("font_color",
		week_col if is_today else (Color(0.4, 0.9, 0.4) if is_claimed else Color(1, 1, 1, 0.35)))
	day_lbl.add_theme_constant_override("margin_top", 6)
	inner.add_child(day_lbl)

	# Icon / check
	if is_claimed:
		var check := Label.new()
		check.text = "✓"
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 22)
		check.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45))
		inner.add_child(check)
	else:
		var icon_r := TextureRect.new()
		icon_r.custom_minimum_size = Vector2(22, 22)
		icon_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if reward_info["gems"] > 0:
			icon_r.texture = load("res://assets/icons/gem.svg")
			icon_r.modulate = week_col if is_today else Color(0.6, 0.9, 1.0, 0.5 if is_future else 1.0)
		else:
			icon_r.texture = load("res://assets/icons/coin.svg")
			icon_r.modulate = week_col if is_today else Color(1.0, 0.9, 0.2, 0.5 if is_future else 1.0)
		inner.add_child(icon_r)

	# Reward amount
	var reward_txt: String = ""
	if reward_info["gems"] > 0 and reward_info["coins"] > 0:
		reward_txt = "+%d\n+%dg" % [reward_info["coins"], reward_info["gems"]]
	elif reward_info["gems"] > 0:
		reward_txt = "+%d\ngem" % reward_info["gems"]
	else:
		reward_txt = "+%d" % reward_info["coins"]

	var rwd_lbl := Label.new()
	rwd_lbl.text = reward_txt
	rwd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rwd_lbl.add_theme_font_size_override("font_size", 11)
	rwd_lbl.add_theme_color_override("font_color",
		Color.WHITE if is_today else Color(1, 1, 1, 0.6 if is_claimed else (0.3 if is_future else 0.9)))
	rwd_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	inner.add_child(rwd_lbl)

	return card

# ─── REWARD POPUP ─────────────────────────────────────────────────────────────
func _make_reward_popup() -> Control:
	var popup := PanelContainer.new()
	popup.position = Vector2(90, 370)
	popup.size = Vector2(540, 310)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.18, 0.97)
	style.border_color = Color(1.0, 0.9, 0.2, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	popup.add_child(vbox)

	var header := Label.new()
	header.name = "PopupHeader"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.text = "REWARD!"
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	header.add_theme_constant_override("margin_top", 22)
	vbox.add_child(header)

	var body := Label.new()
	body.name = "PopupBody"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.text = ""
	body.add_theme_font_size_override("font_size", 26)
	body.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(body)

	var rarity_lbl := Label.new()
	rarity_lbl.name = "PopupRarity"
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.text = ""
	rarity_lbl.add_theme_font_size_override("font_size", 18)
	rarity_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	vbox.add_child(rarity_lbl)

	var ok_btn := Button.new()
	ok_btn.text = "COLLECT!"
	ok_btn.custom_minimum_size = Vector2(200, 52)
	ok_btn.add_theme_font_size_override("font_size", 22)
	_style_btn(ok_btn, Color(0.2, 1.0, 0.5))
	ok_btn.pressed.connect(_on_popup_ok)
	vbox.add_child(ok_btn)

	return popup

# ─── BUTTON HELPERS ───────────────────────────────────────────────────────────
func _style_btn(btn: Button, col: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.22)
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("normal", s)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(col.r, col.g, col.b, 0.42)
	sh.border_color = col.lightened(0.2)
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _update_claim_btn() -> void:
	if SaveManager.can_claim_daily():
		_claim_btn.text = "CLAIM TODAY'S REWARD"
		_claim_btn.disabled = false
		_style_btn(_claim_btn, Color(1.0, 0.9, 0.2))
	else:
		_claim_btn.text = "CLAIMED ✓"
		_claim_btn.disabled = true
		_style_btn(_claim_btn, Color(0.3, 0.3, 0.3))

func _update_crate_btn() -> void:
	if SaveManager.can_claim_crate():
		_crate_btn.text = "OPEN CRATE"
		_crate_btn.disabled = false
		_style_btn(_crate_btn, Color(0.85, 0.5, 1.0))
		if is_instance_valid(_crate_timer_lbl): _crate_timer_lbl.text = ""
	else:
		_crate_btn.text = "LOCKED"
		_crate_btn.disabled = true
		_style_btn(_crate_btn, Color(0.3, 0.3, 0.3))

# ─── EVENTS ───────────────────────────────────────────────────────────────────
func _on_claim() -> void:
	var reward := SaveManager.claim_daily_reward()
	if reward.is_empty():
		return
	AudioManager.play_sfx("reward")
	_update_claim_btn()
	var popup_body   := _reward_popup.find_child("PopupBody",   true, false) as Label
	var popup_rarity := _reward_popup.find_child("PopupRarity", true, false) as Label
	var popup_header := _reward_popup.find_child("PopupHeader", true, false) as Label
	popup_header.text = "DAILY REWARD!"
	var body_text := ""
	if reward["coins"] > 0:
		body_text += "◆ +%d Coins\n" % reward["coins"]
	if reward["gems"] > 0:
		body_text += "+%d Gems" % reward["gems"]
	popup_body.text = body_text.strip_edges()
	popup_rarity.text = reward.get("label", "")
	_reward_popup.visible = true
	_reward_popup.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_reward_popup, "modulate:a", 1.0, 0.35)

func _on_open_crate() -> void:
	if _crate_spinning:
		return
	var reward := SaveManager.claim_crate()
	if reward.is_empty():
		return
	_crate_spinning = true
	AudioManager.play_sfx("crate_open")
	var tw := create_tween()
	tw.tween_property(self, "_crate_spin_angle", TAU * 3.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	_crate_spinning = false
	_update_crate_btn()
	var rarity_colors := {
		"common": Color(0.8, 0.8, 0.8),
		"rare": Color(0.3, 0.5, 1.0),
		"epic": Color(0.7, 0.3, 1.0),
		"legendary": Color(1.0, 0.7, 0.1),
	}
	var popup_header := _reward_popup.find_child("PopupHeader", true, false) as Label
	var popup_body   := _reward_popup.find_child("PopupBody",   true, false) as Label
	var popup_rarity := _reward_popup.find_child("PopupRarity", true, false) as Label
	popup_header.text = "CRATE OPENED!"
	popup_header.add_theme_color_override("font_color", rarity_colors.get(reward["type"], Color.WHITE))
	var body_text := ""
	if reward["coins"] > 0:
		body_text += "◆ +%d Coins\n" % reward["coins"]
	if reward["gems"] > 0:
		body_text += "+%d Gems" % reward["gems"]
	popup_body.text = body_text.strip_edges()
	popup_rarity.text = reward["rarity"]
	popup_rarity.add_theme_color_override("font_color", rarity_colors.get(reward["type"], Color.WHITE))
	_reward_popup.visible = true
	_reward_popup.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(_reward_popup, "modulate:a", 1.0, 0.35)

func _on_popup_ok() -> void:
	_reward_popup.visible = false
	AudioManager.play_sfx("ui_click")

func _on_back() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	for s in _stars:
		s["phase"] += s["twinkle"] * delta
		s["alpha"] = 0.3 + 0.7 * (0.5 + 0.5 * sin(s["phase"]))

	# Daily cooldown countdown
	if is_instance_valid(_claim_timer_lbl):
		var remaining := SaveManager.get_daily_cooldown_remaining()
		if remaining > 0:
			var h := remaining / 3600
			var m := (remaining % 3600) / 60
			var s := remaining % 60
			_claim_timer_lbl.text = "Next reward in %02d:%02d:%02d" % [h, m, s]
		else:
			_claim_timer_lbl.text = ""

	# Crate countdown
	if is_instance_valid(_crate_timer_lbl):
		var remaining := SaveManager.get_crate_cooldown_remaining()
		if remaining > 0:
			var h := remaining / 3600
			var m := (remaining % 3600) / 60
			var s := remaining % 60
			_crate_timer_lbl.text = "Next crate in %02d:%02d:%02d" % [h, m, s]
		elif not SaveManager.can_claim_crate():
			_update_crate_btn()

	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, VIEWPORT_W, VIEWPORT_H), Color(0.03, 0.03, 0.12))
	for s in _stars:
		draw_circle(s["pos"], s["size"], Color(s["alpha"], s["alpha"], s["alpha"] * 0.95))
	# Crate spinner
	var crate_center := Vector2(360, 860)
	var r := 36.0
	draw_circle(crate_center, r + 8, Color(0.7, 0.4, 1.0, 0.1))
	draw_circle(crate_center, r, Color(0.3, 0.1, 0.6))
	draw_arc(crate_center, r - 4, _crate_spin_angle, _crate_spin_angle + deg_to_rad(270), 32,
		Color(0.85, 0.5, 1.0, 0.8), 5.0)
	draw_circle(crate_center, 7, Color(1.0, 0.9, 0.2))
