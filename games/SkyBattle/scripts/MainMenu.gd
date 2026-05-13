extends Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Sky gradient panel
	var sky := ColorRect.new()
	sky.color = Color(0.07, 0.12, 0.30, 0.7)
	sky.position = Vector2(0, 0)
	sky.size     = Vector2(1920, 540)
	add_child(sky)

	# Title
	var title := Label.new()
	title.text = "SKY BATTLE"
	title.position = Vector2(0, 160)
	title.size     = Vector2(1920, 120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.18))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "2D Battle Royale  ·  Floating Islands  ·  Destructible Terrain  ·  Jetpacks"
	sub.position = Vector2(0, 280)
	sub.size     = Vector2(1920, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	add_child(sub)

	# Play button
	var play := _make_btn("▶  PLAY", Vector2(760, 380), Vector2(400, 80), Color(0.12, 0.38, 0.88))
	play.pressed.connect(GameManager.go_to_match)
	add_child(play)

	# Controls guide
	var ctrl := Label.new()
	ctrl.text = "A / D  or  ← →  =  Move        Space  =  Jump / Hold = Jetpack        LMB  =  Shoot        G / RMB  =  Grenade        E  =  Pick up        R  =  Reload"
	ctrl.position = Vector2(0, 540)
	ctrl.size     = Vector2(1920, 36)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl.add_theme_font_size_override("font_size", 16)
	ctrl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	add_child(ctrl)

	# Tips
	var tips := Label.new()
	tips.text = "Bombs blow chunks out of islands — players fall through the map!\nDrop in from the sky · Loot weapons & jetpacks · Last one alive wins!"
	tips.position = Vector2(0, 600)
	tips.size     = Vector2(1920, 80)
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tips.add_theme_font_size_override("font_size", 18)
	tips.add_theme_color_override("font_color", Color(0.70, 0.78, 0.92))
	add_child(tips)

func _make_btn(text: String, pos: Vector2, sz: Vector2, bg_col: Color) -> Button:
	var btn := Button.new()
	btn.text     = text
	btn.position = pos
	btn.size     = sz

	var norm := StyleBoxFlat.new()
	norm.bg_color = bg_col
	norm.border_width_bottom = 4
	norm.border_color = bg_col.lightened(0.3)
	norm.corner_radius_top_left     = 10
	norm.corner_radius_top_right    = 10
	norm.corner_radius_bottom_left  = 10
	norm.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", norm)

	var hov := norm.duplicate() as StyleBoxFlat
	hov.bg_color = bg_col.lightened(0.18)
	btn.add_theme_stylebox_override("hover", hov)

	var prs := norm.duplicate() as StyleBoxFlat
	prs.bg_color = bg_col.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", prs)

	btn.add_theme_font_size_override("font_size", 34)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn
