## QuestHUD.gd — CanvasLayer overlay showing active quest + achievement popups.
## Add as a CanvasLayer child of World scene (layer = 5).
## Will auto-connect to QuestSystem autoload.

extends CanvasLayer

const POPUP_DURATION := 4.0   # seconds achievement popup stays visible

var _quest_panel: Panel = null
var _quest_title: Label = null
var _quest_desc:  Label = null
var _quest_prog:  Label = null
var _toggle_btn:  Button = null
var _panel_visible: bool = true

var _popup_panel: Panel = null
var _popup_label: Label = null
var _popup_timer: float = 0.0

func _ready() -> void:
	_build_quest_panel()
	_build_popup()
	_connect_signals()


func _build_quest_panel() -> void:
	var vp := get_viewport().get_visible_rect().size

	_quest_panel = Panel.new()
	_quest_panel.size = Vector2(240, 90)
	_quest_panel.position = Vector2(vp.x - 252, 60)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.04, 0.09, 0.88)
	s.set_border_width_all(1)
	s.border_color = Color(0.7, 0.65, 0.2)
	s.corner_radius_top_left    = 5
	s.corner_radius_top_right   = 5
	s.corner_radius_bottom_left = 5
	s.corner_radius_bottom_right = 5
	_quest_panel.add_theme_stylebox_override("panel", s)
	add_child(_quest_panel)

	# Toggle button (top-right corner)
	_toggle_btn = Button.new()
	_toggle_btn.text = "-"
	_toggle_btn.size = Vector2(20, 20)
	_toggle_btn.position = Vector2(218, 2)
	_toggle_btn.flat = true
	_toggle_btn.add_theme_font_size_override("font_size", 12)
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	_quest_panel.add_child(_toggle_btn)

	# "OBJECTIVE" header tag
	var header := Label.new()
	header.text = ">> OBJECTIVE"
	header.position = Vector2(8, 4)
	header.add_theme_color_override("font_color", Color(1.0, 0.82, 0.15))
	header.add_theme_font_size_override("font_size", 10)
	_quest_panel.add_child(header)

	# Quest title (current quest name)
	_quest_title = Label.new()
	_quest_title.position = Vector2(8, 18)
	_quest_title.size = Vector2(224, 20)
	_quest_title.add_theme_color_override("font_color", Color(1.0, 1.0, 0.92))
	_quest_title.add_theme_font_size_override("font_size", 13)
	_quest_panel.add_child(_quest_title)

	# Current objective line (first incomplete)
	_quest_desc = Label.new()
	_quest_desc.position = Vector2(8, 38)
	_quest_desc.size = Vector2(224, 18)
	_quest_desc.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	_quest_desc.add_theme_font_size_override("font_size", 11)
	_quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_panel.add_child(_quest_desc)

	# Progress line (e.g. "Mine Cobblestone: 12 / 30")
	_quest_prog = Label.new()
	_quest_prog.position = Vector2(8, 60)
	_quest_prog.size = Vector2(224, 26)
	_quest_prog.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	_quest_prog.add_theme_font_size_override("font_size", 11)
	_quest_prog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_panel.add_child(_quest_prog)

	_refresh_quest_display()


func _build_popup() -> void:
	_popup_panel = Panel.new()
	_popup_panel.size = Vector2(300, 60)
	var vp := get_viewport().get_visible_rect().size
	_popup_panel.position = Vector2((vp.x - 300) * 0.5, 120)
	_popup_panel.visible = false
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	s.set_border_width_all(2)
	s.border_color = Color(1.0, 0.85, 0.2)
	s.corner_radius_top_left    = 6
	s.corner_radius_top_right   = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	_popup_panel.add_theme_stylebox_override("panel", s)
	add_child(_popup_panel)

	_popup_label = Label.new()
	_popup_label.size = Vector2(290, 54)
	_popup_label.position = Vector2(5, 3)
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_popup_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_popup_label.add_theme_font_size_override("font_size", 14)
	_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_panel.add_child(_popup_label)


func _connect_signals() -> void:
	var qs: Node = get_node_or_null("/root/QuestSystem")
	if qs == null:
		return
	if not qs.quest_completed.is_connected(_on_quest_completed):
		qs.quest_completed.connect(_on_quest_completed)
	if not qs.objective_updated.is_connected(_on_objective_updated):
		qs.objective_updated.connect(_on_objective_updated)
	if not qs.achievement_unlocked.is_connected(_on_achievement_unlocked):
		qs.achievement_unlocked.connect(_on_achievement_unlocked)


func _process(delta: float) -> void:
	if _popup_panel and _popup_panel.visible:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_popup_panel.visible = false


func _refresh_quest_display() -> void:
	var qs: Node = get_node_or_null("/root/QuestSystem")
	if qs == null:
		return
	var quest: Dictionary = qs.get_active_quest()
	if quest.is_empty():
		_quest_title.text = "All Quests Complete!"
		_quest_desc.text  = "You are a TerraCraft legend."
		_quest_prog.text  = ""
		return
	_quest_title.text = quest.get("title", "")
	# Show the quest description as subtitle
	_quest_desc.text  = quest.get("desc", "")
	# Show only the current (first incomplete) objective progress
	_quest_prog.text  = qs.get_progress_text()


func _on_quest_completed(quest_id: String) -> void:
	var qs: Node = get_node_or_null("/root/QuestSystem")
	if qs == null:
		return
	var quests: Array = qs.QUESTS
	for q in quests:
		if q["id"] == quest_id:
			_show_popup("Quest Complete!\n%s\n%s" % [q["title"], q.get("reward_text", "")])
			break
	_refresh_quest_display()


func _on_objective_updated(_quest_id: String) -> void:
	_refresh_quest_display()


func _on_achievement_unlocked(ach_id: String) -> void:
	var qs: Node = get_node_or_null("/root/QuestSystem")
	if qs == null:
		return
	var achievements: Array = qs.ACHIEVEMENTS
	for a in achievements:
		if a["id"] == ach_id:
			_show_popup("Achievement Unlocked!\n%s - %s" % [a["name"], a["desc"]])
			return


func _show_popup(text: String) -> void:
	if _popup_label == null:
		return
	_popup_label.text = text
	_popup_panel.visible = true
	_popup_timer = POPUP_DURATION
	_popup_panel.size = Vector2(300, 70)


func _on_toggle_pressed() -> void:
	_panel_visible = not _panel_visible
	_quest_title.visible = _panel_visible
	_quest_desc.visible  = _panel_visible
	_quest_prog.visible  = _panel_visible
	_toggle_btn.text = "-" if _panel_visible else "+"
	_quest_panel.size.y = 90.0 if _panel_visible else 26.0
