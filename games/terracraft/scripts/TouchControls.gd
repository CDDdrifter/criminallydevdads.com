extends CanvasLayer

# TouchControls.gd — Mobile virtual gamepad.
#
# LAYOUT
# ─────────────────────────────────────────────────────────────────────────────
# LEFT HALF  : Floating analog joystick — touch anywhere to spawn it.
#              Horizontal axis drives left/right movement.
#              Flick UP (normalised y < -0.55) triggers jump.
#
# RIGHT SIDE : Fixed action buttons
#              JUMP — large green button, bottom-right
#              ATK  — attack / mine (held = continuous mine)
#              USE  — place block
#              INT  — interact (E key equivalent, fire-once)
#              INV  — toggle inventory
#              < >  — hotbar prev / next
# ─────────────────────────────────────────────────────────────────────────────

const MOVE_RADIUS    := 70.0
const KNOB_R         := 28.0
const DEAD_ZONE      := 0.12
const JUMP_THRESH    := -0.50
const BTN_ALPHA      := 0.60
const BTN_HELD_ALPHA := 0.92
const MARGIN         := 20.0

# Swipe-to-dash
const SWIPE_SPEED_THRESH := 420.0
const DASH_DURATION      := 0.35

# Auto-sprint: push joystick past RUN_THRESH for AUTO_SPRINT_DELAY seconds → sprint
const RUN_THRESH        := 0.55   # normalised joystick magnitude for running vs walking
const AUTO_SPRINT_DELAY := 2.0    # seconds of continuous run before sprint auto-activates

var _btn_jump:     Panel = null
var _btn_attack:   Panel = null
var _btn_dash:     Panel = null   # dash — only way to cancel an attack
var _btn_place:    Panel = null
var _btn_interact: Panel = null
var _btn_inv:      Panel = null
var _btn_hb_prev:  Panel = null
var _btn_hb_next:  Panel = null
var _btn_flip:     Panel = null   # flip/mirror placed block
var _btn_move:     Panel = null   # quick-move inventory item to hotbar
var _btn_block:    Panel = null   # parry / block
var _btn_cdash:    Panel = null   # combat dash (backward)

var _move_base: Panel = null
var _move_knob: Panel = null
var _move_fid:    int     = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_cur:    Vector2 = Vector2.ZERO

var _finger_map: Dictionary = {}
var _held: Array[Panel] = []
var _jump_fired: bool = false

var _prev_drag_pos:  Vector2 = Vector2.ZERO
var _prev_drag_time: float   = 0.0
var _dash_timer:     float   = 0.0
var _run_timer:      float   = 0.0   # seconds joystick held past RUN_THRESH
var _auto_sprint:    bool    = false  # true once auto-sprint activates

var _vp: Vector2 = Vector2.ZERO
var _buttons_built: bool = false

# Cached autoload reference — looked up once in _deferred_init, never again per frame.
var _im: Node = null
# Per-button StyleBox cache: [normal_style, held_style] — avoids duplicate() every tap.
var _btn_styles: Dictionary = {}


func _ready() -> void:
	_connect_signals()
	# Defer all UI construction — on HTML5 the viewport size is 0 until frame 1.
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	_vp = get_viewport().get_visible_rect().size
	# Final fallback if viewport rect still reports zero (some web environments).
	if _vp.x < 10.0 or _vp.y < 10.0:
		_vp = Vector2(DisplayServer.window_get_size())
	# Cache InputManager once — it's an autoload, always present after _ready.
	_im = get_node_or_null("/root/InputManager")
	_build_stick()
	_build_buttons()
	_buttons_built = true
	get_viewport().size_changed.connect(_on_viewport_resized)
	_refresh_visibility()


func _refresh_visibility() -> void:
	var on_touch_platform: bool = (
		OS.has_feature("mobile") or
		OS.has_feature("web_android") or
		OS.has_feature("web_ios") or
		OS.has_feature("web")
	)
	if on_touch_platform:
		visible = true
		return
	var im: Node = get_node_or_null("/root/InputManager")
	if im != null and im.has_method("using_touch"):
		visible = im.using_touch()
	else:
		visible = false


func _on_viewport_resized() -> void:
	var new_vp: Vector2 = get_viewport().get_visible_rect().size
	if new_vp.x < 10.0 or new_vp.y < 10.0:
		return
	_vp = new_vp
	# Rebuild buttons at new screen size.
	for btn: Panel in [_btn_jump, _btn_attack, _btn_dash, _btn_place, _btn_interact,
			_btn_inv, _btn_hb_prev, _btn_hb_next, _btn_flip, _btn_move,
			_btn_block, _btn_cdash]:
		if btn != null:
			btn.queue_free()
	_build_buttons()


func _build_stick() -> void:
	var diam := MOVE_RADIUS * 2.0
	_move_base = Panel.new()
	_move_base.size = Vector2(diam, diam)
	_move_base.visible = false
	_move_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color     = Color(0.5, 0.7, 1.0, 0.15)
	bs.border_color = Color(0.7, 0.85, 1.0, 0.55)
	bs.set_border_width_all(3)
	for c in range(4): bs.set_corner_radius(c, int(MOVE_RADIUS))
	_move_base.add_theme_stylebox_override("panel", bs)
	add_child(_move_base)

	_move_knob = Panel.new()
	_move_knob.size = Vector2(KNOB_R * 2.0, KNOB_R * 2.0)
	_move_knob.visible = false
	_move_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0.85, 0.92, 1.0, 0.80)
	for c in range(4): ks.set_corner_radius(c, int(KNOB_R))
	_move_knob.add_theme_stylebox_override("panel", ks)
	add_child(_move_knob)


func _build_buttons() -> void:
	# ── Right-side action buttons ───────────────────────────────────────────
	# Layout (bottom-right quadrant, thumb-friendly for portrait and landscape):
	#
	#   [INT]  [USE]
	#   [DASH] [JUMP]
	#   [ATK]
	#
	# JUMP  — bottom-right, big
	# ATK   — left of JUMP, same row, medium (red)
	# DASH  — above ATK, medium (cyan) — cancels attacks
	# USE   — above JUMP, medium (amber)
	# INT   — above DASH, small (purple)
	# INV   — top-right, small
	# < >   — hotbar prev/next flanking the hotbar
	# FLIP  — top-left utility

	var big   := Vector2(88, 88)
	var med   := Vector2(76, 76)
	var small := Vector2(60, 54)
	var arr   := Vector2(50, 50)

	var bx := _vp.x - MARGIN
	var by := _vp.y - MARGIN

	# JUMP — bottom-right corner
	_btn_jump = _make_btn("JUMP",
		Rect2(Vector2(bx - big.x, by - big.y), big),
		Color(0.15, 0.75, 0.25))

	# ATK — left of JUMP, same vertical position
	_btn_attack = _make_btn("ATK",
		Rect2(Vector2(bx - big.x - med.x - 12.0, by - med.y), med),
		Color(0.85, 0.20, 0.20))

	# DASH — above ATK (cancels any ongoing attack)
	_btn_dash = _make_btn("DASH",
		Rect2(Vector2(bx - big.x - med.x - 12.0, by - med.y - med.y - 10.0), med),
		Color(0.10, 0.65, 0.85))

	# USE — above JUMP
	_btn_place = _make_btn("USE",
		Rect2(Vector2(bx - big.x, by - big.y - med.y - 10.0), med),
		Color(0.75, 0.55, 0.10))

	# INT — above DASH
	_btn_interact = _make_btn("INT",
		Rect2(Vector2(bx - big.x - med.x - 12.0, by - med.y - med.y - 10.0 - small.y - 8.0), small),
		Color(0.40, 0.20, 0.75))

	# INV — top-right
	_btn_inv = _make_btn("INV",
		Rect2(Vector2(_vp.x - small.x - MARGIN, MARGIN + 120.0), small),
		Color(0.25, 0.35, 0.70))

	# Hotbar prev / next — flanking the hotbar bar
	var hb_y  := _vp.y - 80.0 - arr.y * 0.5
	var hb_cx := _vp.x * 0.5
	_btn_hb_prev = _make_btn("<", Rect2(Vector2(hb_cx - 310.0, hb_y), arr), Color(0.3, 0.3, 0.35))
	_btn_hb_next = _make_btn(">", Rect2(Vector2(hb_cx + 264.0, hb_y), arr), Color(0.3, 0.3, 0.35))

	# FLIP — top-left, mirrors placed blocks
	_btn_flip = _make_btn("FLIP", Rect2(Vector2(MARGIN, MARGIN + 70.0), Vector2(56, 44)), Color(0.30, 0.55, 0.75))

	# MOVE — quick-move selected inventory item to hotbar (near INV, top-right)
	_btn_move = _make_btn("MOVE",
		Rect2(Vector2(_vp.x - (small.x + 8.0) * 2.0 - MARGIN, MARGIN + 120.0), small),
		Color(0.70, 0.40, 0.10))

	# BLOCK — parry/block; placed above INT on the left action column
	_btn_block = _make_btn("BLK",
		Rect2(Vector2(bx - big.x - med.x - 12.0, by - med.y - med.y - 10.0 - small.y - 8.0 - small.y - 8.0), small),
		Color(0.20, 0.60, 0.55))

	# CDASH — combat dash backward; placed to the left of DASH
	_btn_cdash = _make_btn("CDSH",
		Rect2(Vector2(bx - big.x - med.x - 12.0 - small.x - 8.0, by - med.y - med.y - 10.0), small),
		Color(0.65, 0.20, 0.65))


func _make_btn(label: String, rect: Rect2, col: Color) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size     = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE  # We handle all input ourselves
	var st := StyleBoxFlat.new()
	st.bg_color     = Color(col.r, col.g, col.b, BTN_ALPHA)
	st.border_color = Color(1.0, 1.0, 1.0, 0.45)
	st.set_border_width_all(2)
	for c in range(4): st.set_corner_radius(c, 14)
	p.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = label
	lbl.size = rect.size
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	p.add_child(lbl)
	add_child(p)
	# Pre-build normal + held StyleBoxes so _set_held never calls duplicate().
	_cache_btn_styles(p)
	return p


func _input(event: InputEvent) -> void:
	# Block most touch processing while any game UI is open, but still allow:
	#   MOVE  — so the player can quick-move inventory items on mobile
	#   INV   — so the player can tap INV again to close the inventory
	if _im != null and (_im.open_inventory or UIManager.ui_open):
		if event is InputEventScreenTouch and event.pressed and _buttons_built:
			var _tp: Vector2 = (event as InputEventScreenTouch).position
			if _btn_move != null and Rect2(_btn_move.position, _btn_move.size).has_point(_tp):
				_im.touch_quick_move = true
			elif _btn_inv != null and Rect2(_btn_inv.position, _btn_inv.size).has_point(_tp):
				_im.open_inventory = true   # pulsed → Player.gd closes active UI
		return

	if not visible or not _buttons_built:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	# Web fallback: some browsers only fire mouse events even on touchscreens.
	elif event is InputEventMouseButton and OS.has_feature("web"):
		_handle_mouse_as_touch(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var btn := _btn_at(event.position)
		if btn != null:
			_finger_map[event.index] = btn
			_held.append(btn)
			_set_held(btn, true)
			_on_pressed(btn)
		elif _move_fid < 0 and _in_move_zone(event.position):
			_move_fid       = event.index
			_move_origin    = event.position
			_move_cur       = event.position
			_prev_drag_pos  = event.position
			_prev_drag_time = Time.get_ticks_msec() / 1000.0
			_show_stick(event.position)
		else:
			# Tap on the world (anywhere not a button or joystick)
			if _im != null:
				_im.touch_tap_screen = event.position
				_im.touch_has_tap    = true
	else:
		if _finger_map.has(event.index):
			var rel: Panel = _finger_map[event.index]
			_finger_map.erase(event.index)
			_held.erase(rel)
			_set_held(rel, false)
			_on_released(rel)
		if event.index == _move_fid:
			_move_fid       = -1
			_jump_fired      = false
			_prev_drag_time = 0.0
			_hide_stick()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_fid:
		var now: float = Time.get_ticks_msec() / 1000.0
		var dt: float  = now - _prev_drag_time
		if dt > 0.0 and dt < 0.12:
			var dx: float = abs(event.position.x - _prev_drag_pos.x)
			var vx: float = dx / dt
			if vx > SWIPE_SPEED_THRESH:
				_dash_timer = DASH_DURATION
		_prev_drag_pos  = event.position
		_prev_drag_time = now
		_move_cur = event.position
		_update_stick()
		return

	if _finger_map.has(event.index):
		var prev: Panel = _finger_map[event.index]
		var now_btn: Panel = _btn_at(event.position)
		if now_btn != prev:
			_held.erase(prev)
			_set_held(prev, false)
			_on_released(prev)
			if now_btn != null:
				_finger_map[event.index] = now_btn
				_held.append(now_btn)
				_set_held(now_btn, true)
				_on_pressed(now_btn)
			else:
				_finger_map.erase(event.index)
	elif _move_fid < 0 and _in_move_zone(event.position):
		_move_fid       = event.index
		_move_origin    = event.position
		_move_cur       = event.position
		_prev_drag_pos  = event.position
		_prev_drag_time = Time.get_ticks_msec() / 1000.0
		_show_stick(event.position)


# Web fallback: handle mouse-button events as single-touch when no ScreenTouch fires.
var _mouse_as_touch_active: bool = false

func _handle_mouse_as_touch(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Synthesise a fake finger index (99) so it doesn't clash with real touches.
	const FAKE_FID: int = 99
	if event.pressed:
		var btn := _btn_at(event.position)
		if btn != null:
			_finger_map[FAKE_FID] = btn
			_held.append(btn)
			_set_held(btn, true)
			_on_pressed(btn)
			_mouse_as_touch_active = true
		elif _move_fid < 0 and _in_move_zone(event.position):
			_move_fid       = FAKE_FID
			_move_origin    = event.position
			_move_cur       = event.position
			_prev_drag_pos  = event.position
			_prev_drag_time = Time.get_ticks_msec() / 1000.0
			_show_stick(event.position)
			_mouse_as_touch_active = true
		else:
			# World tap (web fallback) — any screen area not a button or stick.
			if _im != null:
				_im.touch_tap_screen = event.position
				_im.touch_has_tap    = true
	else:
		_mouse_as_touch_active = false
		if _finger_map.has(FAKE_FID):
			var rel: Panel = _finger_map[FAKE_FID]
			_finger_map.erase(FAKE_FID)
			_held.erase(rel)
			_set_held(rel, false)
			_on_released(rel)
		if _move_fid == FAKE_FID:
			_move_fid       = -1
			_jump_fired      = false
			_prev_drag_time = 0.0
			_hide_stick()


func _process(delta: float) -> void:
	if not visible or not _buttons_built:
		return

	# Handle mouse motion as joystick drag on web fallback
	if _mouse_as_touch_active and _move_fid == 99:
		var mpos: Vector2 = get_viewport().get_mouse_position()
		_move_cur = mpos
		_update_stick()

	if _im == null:
		return

	_im.touch_move_axis = Vector2.ZERO
	_im.touch_aim_axis  = Vector2.ZERO
	_im.touch_jump      = false
	_im.touch_attack    = false
	_im.touch_mine      = false
	_im.touch_place     = false
	_im.touch_crouch    = false
	_im.touch_run       = false   # reset each frame; set below if joystick active

	if _dash_timer > 0.0:
		_dash_timer -= delta
	_im.touch_sprint = _dash_timer > 0.0 or _auto_sprint

	# UI open — release joystick so player doesn't drift, then skip all button polling.
	if _im.open_inventory or UIManager.ui_open:
		if _move_fid >= 0:
			_move_fid    = -1
			_jump_fired  = false
			_run_timer   = 0.0
			_auto_sprint = false
			_hide_stick()
		return

	if _move_fid >= 0:
		var norm := (_move_cur - _move_origin) / MOVE_RADIUS
		var cl   := norm.limit_length(1.0)
		var mag  := cl.length()

		if abs(cl.x) > DEAD_ZONE:
			_im.touch_move_axis.x = cl.x

		if mag >= RUN_THRESH:
			_im.touch_run = true
			_run_timer += delta
			if _run_timer >= AUTO_SPRINT_DELAY:
				_auto_sprint = true
		else:
			_run_timer   = 0.0
			_auto_sprint = false

		# Flick UP → jump
		if cl.y < JUMP_THRESH and not _jump_fired:
			_im.touch_jump = true
			_jump_fired    = true
		elif cl.y >= JUMP_THRESH:
			_jump_fired = false
		# Push DOWN → crouch
		_im.touch_crouch = cl.y > 0.55
		if mag > DEAD_ZONE:
			_im.touch_aim_axis = cl.normalized()
	else:
		_run_timer   = 0.0
		_auto_sprint = false

	for btn in _held:
		_apply_held(btn)


func _in_move_zone(pos: Vector2) -> bool:
	return pos.x < _vp.x * 0.48 and pos.y > _vp.y * 0.18


func _show_stick(origin: Vector2) -> void:
	_move_base.position = origin - Vector2(MOVE_RADIUS, MOVE_RADIUS)
	_move_knob.position = origin - Vector2(KNOB_R, KNOB_R)
	_move_base.visible  = true
	_move_knob.visible  = true


func _hide_stick() -> void:
	if _move_base != null:
		_move_base.visible = false
	if _move_knob != null:
		_move_knob.visible = false
	if _im != null:
		_im.touch_move_axis = Vector2.ZERO


func _update_stick() -> void:
	var cl := (_move_cur - _move_origin).limit_length(MOVE_RADIUS)
	_move_knob.position = (_move_origin + cl) - Vector2(KNOB_R, KNOB_R)


func _on_pressed(btn: Panel) -> void:
	if _im == null:
		return
	if btn == _btn_inv:
		_im.open_inventory = true
	elif btn == _btn_interact:
		_fire("interact", true)
	elif btn == _btn_hb_prev:
		_fire("hotbar_prev", true)
	elif btn == _btn_hb_next:
		_fire("hotbar_next", true)
	elif btn == _btn_flip:
		_im.touch_flip = true
	elif btn == _btn_dash:
		_im.touch_dash = true
	elif btn == _btn_move:
		_im.touch_quick_move = true
	elif btn == _btn_block:
		_im.touch_block = true
	elif btn == _btn_cdash:
		_im.touch_combat_dash = true


func _on_released(btn: Panel) -> void:
	if _im == null:
		return
	if btn == _btn_inv:
		await get_tree().process_frame
		_im.open_inventory = false
	elif btn == _btn_attack:
		# Clear immediately so _physics_process doesn't read a stale true
		# on the frame after the finger lifts (process runs after physics).
		_im.touch_attack = false
		_im.touch_mine   = false
	elif btn == _btn_place:
		_im.touch_place = false
	elif btn == _btn_jump:
		_im.touch_jump  = false
	elif btn == _btn_block:
		_im.touch_block = false
	elif btn == _btn_cdash:
		_im.touch_combat_dash = false
	elif btn == _btn_hb_prev:
		_fire("hotbar_prev", false)
	elif btn == _btn_hb_next:
		_fire("hotbar_next", false)


func _apply_held(btn: Panel) -> void:
	if btn == _btn_jump:
		_im.touch_jump = true
	elif btn == _btn_attack:
		_im.touch_attack = true
		_im.touch_mine   = true
	elif btn == _btn_place:
		_im.touch_place = true
	elif btn == _btn_block:
		_im.touch_block = true


func _fire(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action  = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _btn_at(pos: Vector2) -> Panel:
	for btn: Panel in [_btn_jump, _btn_attack, _btn_dash, _btn_place, _btn_interact,
			_btn_inv, _btn_hb_prev, _btn_hb_next, _btn_flip, _btn_move,
			_btn_block, _btn_cdash]:
		if btn != null and Rect2(btn.position, btn.size).has_point(pos):
			return btn
	return null


func _set_held(btn: Panel, held: bool) -> void:
	# Use pre-cached styles — avoid StyleBoxFlat.duplicate() every tap.
	var styles: Array = _btn_styles.get(btn, [])
	if styles.is_empty():
		return
	btn.add_theme_stylebox_override("panel", styles[1] if held else styles[0])


func _cache_btn_styles(btn: Panel) -> void:
	var base := btn.get_theme_stylebox("panel") as StyleBoxFlat
	if base == null:
		return
	var held_st := base.duplicate() as StyleBoxFlat
	held_st.bg_color.a   = BTN_HELD_ALPHA
	held_st.border_color = Color(1.0, 1.0, 0.4, 0.95)
	_btn_styles[btn] = [base, held_st]


func _connect_signals() -> void:
	if has_node("/root/InputManager"):
		var im := get_node("/root/InputManager")
		if im.has_signal("input_mode_changed"):
			im.input_mode_changed.connect(_on_mode_changed)


func _on_mode_changed(_mode) -> void:
	_refresh_visibility()
	if not visible:
		if _im != null:
			_im.touch_move_axis  = Vector2.ZERO
			_im.touch_jump       = false
			_im.touch_attack     = false
			_im.touch_mine       = false
			_im.touch_place      = false
			_im.touch_crouch     = false
			_im.touch_sprint     = false
			_im.touch_dash        = false
			_im.touch_has_tap     = false
			_im.touch_run         = false
			_im.touch_block       = false
			_im.touch_combat_dash = false
		_finger_map.clear()
		_held.clear()
		_move_fid              = -1
		_jump_fired            = false
		_dash_timer            = 0.0
		_run_timer             = 0.0
		_auto_sprint           = false
		_prev_drag_time        = 0.0
		_mouse_as_touch_active = false
		_hide_stick()
