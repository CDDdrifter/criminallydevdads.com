## InputManager.gd — Global singleton (Autoload)
## Detects whether the player is using touch, keyboard+mouse, or a gamepad.
## Other nodes listen to the `input_mode_changed` signal to show/hide on-screen buttons.
extends Node

# ─────────────────────────────────────────────
#  SIGNALS
# ─────────────────────────────────────────────
signal input_mode_changed(mode: InputMode)

# ─────────────────────────────────────────────
#  INPUT MODES
# ─────────────────────────────────────────────
enum InputMode {
	TOUCH,      # on-screen buttons visible (phone / tablet without peripherals)
	KBM,        # keyboard + mouse — hide on-screen buttons
	GAMEPAD,    # controller connected — hide on-screen buttons
}

var current_mode: InputMode = InputMode.TOUCH
var _gamepad_connected: bool = false

# ─────────────────────────────────────────────
#  VIRTUAL JOYSTICK STATE  (used by TouchControls.gd)
# ─────────────────────────────────────────────
var touch_move_axis: Vector2 = Vector2.ZERO   # -1..1 on X, set by TouchControls
var touch_jump: bool = false
var touch_attack: bool = false
var touch_mine: bool = false
var touch_place: bool = false
var touch_crouch: bool = false               # held while the crouch/down button is pressed
var open_inventory: bool = false              # pulsed true by TouchControls inventory button; cleared by Player
var touch_aim_axis: Vector2 = Vector2.ZERO   # aim direction from touch aim joystick (-1..1)
var touch_sprint: bool = false               # true while swipe-dash is active
## Screen-space position of the last world-tap on the right half of the screen.
## Player.gd converts this to world coords for direct block targeting.
var touch_tap_screen: Vector2 = Vector2(-9999.0, -9999.0)
var touch_has_tap: bool = false              # true once the player has tapped the world once
var touch_flip: bool = false                 # pulsed true by the FLIP button; cleared by Player
var touch_dash: bool = false                 # pulsed true by the DASH button; cleared by Player
var touch_run: bool = false                  # true while joystick pushed beyond run threshold
var touch_quick_move: bool = false           # pulsed by MOVE button; consumed by InventoryUI
var touch_block: bool = false                # held while BLOCK/PARRY button pressed
var touch_combat_dash: bool = false          # pulsed true by COMBAT DASH button; cleared by Player

# Web/itch.io: browsers don't always fire joy_connection_changed,
# so we poll every 2 seconds as a fallback.
var _web_poll_timer: float = 0.0

func _ready() -> void:
	# Listen for controllers being plugged in or removed
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# Check if a gamepad is already connected at startup
	for joy in Input.get_connected_joypads():
		_gamepad_connected = true

	_detect_mode()

func _process(delta: float) -> void:
	# Web/itch.io gamepad polling — the Gamepad API requires a button press
	# before the browser reports the device, so we poll regularly.
	if OS.has_feature("web"):
		_web_poll_timer += delta
		if _web_poll_timer >= 2.0:
			_web_poll_timer = 0.0
			var pads := Input.get_connected_joypads()
			var was_connected := _gamepad_connected
			_gamepad_connected = pads.size() > 0
			if _gamepad_connected and not was_connected:
				_set_mode(InputMode.GAMEPAD)
			elif not _gamepad_connected and was_connected:
				_detect_mode()

func _input(event: InputEvent) -> void:
	## Every raw input event passes through here.
	## We use it to automatically switch modes.

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# Touch screen used — switch to touch mode if not already
		if current_mode != InputMode.TOUCH and not _gamepad_connected:
			_set_mode(InputMode.TOUCH)

	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		# On touch screens, every finger tap also fires an emulated mouse event.
		# If touch is already active, ignore the emulated mouse — it's the same finger.
		# Only a physical keyboard key press should pull us out of TOUCH mode.
		if current_mode == InputMode.TOUCH:
			if event is InputEventMouseButton or event is InputEventMouseMotion:
				return   # emulated from touch — ignore
		if current_mode != InputMode.KBM:
			_set_mode(InputMode.KBM)

	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Gamepad button pressed — switch to gamepad mode
		if current_mode != InputMode.GAMEPAD:
			_set_mode(InputMode.GAMEPAD)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_gamepad_connected = connected
	if connected:
		_set_mode(InputMode.GAMEPAD)
	else:
		# No gamepad — fall back to touch if on mobile, else KBM
		_detect_mode()

func _detect_mode() -> void:
	if _gamepad_connected:
		_set_mode(InputMode.GAMEPAD)
	elif OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("web"):
		_set_mode(InputMode.TOUCH)
	else:
		_set_mode(InputMode.KBM)

func _set_mode(mode: InputMode) -> void:
	if current_mode == mode:
		return
	current_mode = mode
	input_mode_changed.emit(mode)

func using_touch() -> bool:
	return current_mode == InputMode.TOUCH

func using_hardware() -> bool:
	## Returns true when physical buttons/controller are active (hide on-screen buttons)
	return current_mode == InputMode.KBM or current_mode == InputMode.GAMEPAD

func using_kbm() -> bool:
	## Returns true when keyboard + mouse is the active input method.
	return current_mode == InputMode.KBM

func using_gamepad() -> bool:
	## Returns true when a gamepad is the active input method.
	return current_mode == InputMode.GAMEPAD
