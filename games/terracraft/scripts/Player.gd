## Player.gd
## Complete player controller for a Terraria-style 2D side-scrolling survival game.
## Attach to a CharacterBody2D node.
##
## Node structure expected:
##   Player (CharacterBody2D)
##     AnimatedSprite2D       <- handles all visual frames
##     CollisionShape2D       <- player hitbox
##     MineRaycast (RayCast2D) <- optional, for precise block targeting
##     AttackArea (Area2D)    <- melee hitbox in front of player
##       CollisionShape2D
##     HurtTimer (Timer)      <- counts down invincibility after being hit
##     CoyoteTimer (Timer)    <- coyote-time window
##     JumpBufferTimer (Timer)<- pre-land jump buffer
##     HungerTimer (Timer)    <- ticks hunger drain
##
## ===========================================================================
## HOW TO CHANGE STATS:
##   Adjust the @export variables below. They are exposed in the Godot editor.
##   - move_speed / run_speed : horizontal movement in px/s
##   - jump_velocity          : negative value; bigger magnitude = higher jump
##   - gravity                : px/s² downward acceleration
##   - max_health / max_hunger: starting caps
##   - hunger_drain_rate      : hunger lost per second (default 0.1 = 1/10s)
##   - health_regen_rate      : health gained per second when hunger > 50
##   - starve_damage_rate     : health lost per second when hunger = 0
##   - mine_reach             : tile radius the player can mine from
##   - tool_speed             : base mining speed multiplier
##
## HOW TO ADD NEW INTERACTIONS (e.g. NPC dialogue, lever):
##   1. Add an InputEvent check in _handle_interact() below.
##   2. Cast an Area2D or use a RayCast2D to detect the object.
##   3. Call a method on the detected node (e.g. node.interact(self)).
##   4. Register any new Input actions in Project > Input Map.
## ===========================================================================

class_name Player
extends CharacterBody2D

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal health_changed(new_health: float, max_health: float)
signal hunger_changed(new_hunger: float, max_hunger: float)
## Emitted whenever a hotbar slot's contents change.
signal hotbar_changed(slot: int, item: Dictionary)
## Emitted whenever the full inventory changes (sort, add, remove).
signal inventory_changed
## Emitted when selected_slot changes — HUD highlights the new slot.
signal selected_slot_changed(slot: int)
## Emitted every frame while mining — value 0.0–1.0, HUD shows progress bar.
signal mine_progress_changed(progress: float)
signal aimed_tile_changed(tile_name: String)
## Emitted when player opens or closes the inventory / crafting screen.
signal inventory_toggled(open: bool)

# ---------------------------------------------------------------------------
# Movement constants – tweak freely
# ---------------------------------------------------------------------------
@export var move_speed: float = 180.0       ## Normal horizontal speed (px/s)
@export var run_speed: float = 280.0        ## Sprint speed when holding Shift
@export var jump_velocity: float = -520.0   ## Upward impulse on jump (negative = up)
@export var gravity: float = 980.0          ## px/s²; fallback if GameData not present
@export var wall_slide_gravity_mult: float = 0.3  ## Fraction of gravity during wall-slide
## Hold-jump: while jump is held within this window after jumping, extra upward force is applied.
@export var jump_hold_time: float = 0.18    ## seconds the hold-boost lasts
@export var jump_hold_force: float = 260.0  ## extra upward force (px/s²) while holding

# Coyote time: lets the player jump a tiny moment after walking off a ledge.
@export var coyote_time: float = 0.12       ## seconds
# Jump buffer: if jump is pressed just before landing, the jump fires on touch.
@export var jump_buffer_time: float = 0.1   ## seconds

# ---------------------------------------------------------------------------
# Survival stats – tweak freely
# ---------------------------------------------------------------------------
@export var max_health: float = 100.0
@export var max_hunger: float = 100.0
@export var hunger_drain_rate: float = 0.1         ## hunger units lost per second (1 per 10s)
@export var health_regen_rate: float = 0.5         ## health gained per second when hunger > 50
@export var starve_damage_rate: float = 0.2        ## health lost per second when hunger == 0
@export var invincibility_duration: float = 1.5    ## seconds of i-frames after being hit

# ---------------------------------------------------------------------------
# Mining / interaction
# ---------------------------------------------------------------------------
const TILE_SIZE: int = 16                          ## pixels per tile; must match WorldGenerator
@export var mine_reach: int = 10                   ## reach in tiles (10 * 16 = 160 px)
@export var tool_speed: float = 1.0               ## multiplier applied to mining progress per second
## HOW TO ADD A NEW TOOL TYPE:
##   Add an entry to the item database (ItemDB autoload) with a "mine_level" and "speed" field.
##   get_selected_item() returns that dictionary; _handle_mining() reads it automatically.

# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------
const HOTBAR_SIZE: int = 9
const INVENTORY_SIZE: int = 36

## Each slot is a Dictionary: { "id": String, "count": int, "durability": int }
## Empty slots are represented as {}.
var hotbar: Array = []
var inventory: Array = []
var selected_slot: int = 0          ## 0–8
var inventory_open: bool = false

# ---------------------------------------------------------------------------
# Runtime state (internal)
# ---------------------------------------------------------------------------
var health: float
var hunger: float
var is_dead: bool = false

var _facing_right: bool = true      ## Used to flip sprite and attack hitbox
var _can_double_jump: bool = true   ## Reset when player lands
var _jump_held: bool = false        ## True while jump is being held after a jump
var _jump_hold_timer: float = 0.0   ## Elapsed seconds since jump fired
var _coyote_active: bool = false    ## True during coyote window
var _jump_buffered: bool = false    ## True during jump buffer window
var _was_on_floor: bool = false     ## Tracks last-frame floor state

var _mining_target: Vector2i = Vector2i(-9999, -9999)   ## Tile being mined
var _mining_progress: float = 0.0                        ## 0.0–1.0
var _attack_cooldown: float = 0.0                        ## seconds remaining
## Weapon skin tracking — detect held-item changes and apply anim overrides.
var _last_held_item_id: String = ""
var _skin_overrides_active: bool = false

var _last_aim_dir: Vector2 = Vector2.ZERO  ## Last non-zero aim direction (controller right stick / touch aim)
var _mine_sound_timer: float  = 0.0   ## Throttles mine-hit sounds to ~3 per second
var _lock_scan_cd: float = 0.0          ## Countdown before next lock-on group scan
var _lock_target_cached: Node2D = null  ## Cached lock target (refreshed every 100 ms)
var _footstep_timer: float    = 0.0   ## Throttles footstep sounds
var _aimed_tile: Vector2i = Vector2i(-9999, -9999)  ## Currently highlighted tile
var _mine_highlight: ColorRect = null  ## Visual block-target overlay
var _place_highlight: ColorRect = null  ## Ghost preview of the block about to be placed.
var _enemy_highlight: ColorRect = null  ## Red indicator over targeted enemy.
var _place_target: Vector2i = Vector2i(-9999, -9999)  ## Computed placement tile.
var _place_flip: bool = false  ## When true, the next placed block is flipped horizontally (R key / FLIP button).

var _carried_light: PointLight2D = null    ## Light emitted when holding a torch/lantern.
var _land_particles: CPUParticles2D = null ## Landing dust burst.

## Aim laser — red Line2D drawn from player centre in the stick/aim direction.
## Visible only when the analog stick is actively pushed (or touch aim axis is live).
var _aim_laser: Line2D = null
var _aim_laser_active: bool = false  ## True this frame if stick/aim has input

## Drag a PlayerSkin .tres resource here in the Inspector to apply a custom skin.
## Leave null to use the base character sprites as-is.
@export var skin: PlayerSkin = null

## Solid-color shader applied to sprite + shadow per skin.
const SKIN_COLORS: Dictionary = {
	"":            Color(0.08, 0.08, 0.10),   # Default — near black
	"dark_knight": Color(0.18, 0.10, 0.28),   # Dark Knight — deep purple-black
	"ranger":      Color(0.10, 0.28, 0.12),   # Ranger — dark forest green
}

## Internal skin layer nodes (unused in folder-based skin system; kept for future overlay support).
var _skin_layers: Dictionary = {}

## Equipment slots. Key = slot name, value = equipped item_id ("" = empty).
var equipment: Dictionary = {"head": "", "chest": "", "arms": "", "legs": ""}

## Overlay AnimatedSprite2D for each equipment slot (created in _ready).
var _eq_layers: Dictionary = {}
var _eq_last_flip: bool = false        ## cached sprite state to skip redundant layer updates
var _eq_last_anim: StringName = &""

var _world_node: Node = null  ## cached get_parent() — world reference

## UV regions (x0,y0,x1,y1) of each body-part in the 48×48 sprite sheet frame.
const _SLOT_UV: Dictionary = {
	"head":  Vector4(0.17, 0.00, 0.83, 0.30),
	"chest": Vector4(0.13, 0.25, 0.88, 0.60),
	"arms":  Vector4(0.00, 0.21, 1.00, 0.63),
	"legs":  Vector4(0.17, 0.58, 0.83, 1.00),
}

## Tint colours per equipment material tier.
const _TIER_TINT: Dictionary = {
	"wood":    Color(0.55, 0.37, 0.18, 0.80),
	"stone":   Color(0.65, 0.65, 0.65, 0.80),
	"iron":    Color(0.78, 0.82, 0.88, 0.85),
	"gold":    Color(1.00, 0.85, 0.10, 0.90),
	"diamond": Color(0.30, 0.85, 0.95, 0.90),
}

## Air remaining before drowning. Drains when head is in water.
var _air_timer: float = 10.0
const _MAX_AIR: float = 10.0

var _invincible: bool = false       ## True while i-frames active

## Creative mode fly state — toggled by double-jump when GameData.creative_mode is true.
var _creative_flying: bool = false
const CREATIVE_FLY_SPEED: float = 320.0

## Red silhouette rendered behind the player sprite.
var _shadow_sprite: AnimatedSprite2D = null
## Cached reference to HandItem Sprite2D — looked up once in _setup_hand_item.
var _hand_item: Sprite2D = null

## True while the crouch button is held (S / Down Arrow / D-Pad Down).
## On gamepad: also redirects mining straight down instead of forward.
var is_crouching: bool = false

## Previous frame's touch_jump state — used to detect just-pressed edge on touch.
var _prev_touch_jump: bool = false
## Previous frame's touch_place state — used to detect just-pressed edge on touch.
var _prev_touch_place: bool = false
## Previous frame's touch_dash state — used to detect just-pressed edge on touch.
var _prev_touch_dash: bool = false
## Toggles between punch and punch_jab for a combo feel.
var _punch_alt: bool = false

# ---------------------------------------------------------------------------
# Dash
# ---------------------------------------------------------------------------
const DASH_SPEED    : float = 820.0  ## Horizontal velocity burst (px/s)
const DASH_DURATION : float = 0.15   ## Seconds the burst lasts
const DASH_COOLDOWN : float = 0.55   ## Seconds before another dash is allowed

var _is_dashing          : bool  = false
var _dash_dir            : float = 0.0   ## +1 = right, -1 = left

# ---------------------------------------------------------------------------
# Charge attack
# ---------------------------------------------------------------------------
const CHARGE_HOLD_TIME   : float = 0.6   ## Seconds to hold attack for a heavy hit
const CHARGE_DMG_MULT    : float = 2.5   ## Damage multiplier on heavy release
var _charge_timer        : float = 0.0   ## Accumulates while attack held
var _charge_ready        : bool  = false ## True once fully charged
var _charge_flash_node   : Polygon2D = null ## Created in _ready for the flash VFX

# ---------------------------------------------------------------------------
# Parry / Block
# ---------------------------------------------------------------------------
const PARRY_WINDOW       : float = 0.22  ## Perfect block window after pressing block
const PARRY_COOLDOWN     : float = 0.9   ## Recharge between parry attempts
var _parry_timer         : float = 0.0   ## Counts down during active parry window
var _parry_cooldown      : float = 0.0   ## Counts down after a parry attempt
var _is_blocking         : bool  = false ## True while block held (after window expires = just absorb)
var _parry_success       : bool  = false ## Set true for 1 frame on perfect parry
var _prev_touch_block    : bool  = false

# ---------------------------------------------------------------------------
# Combat dash (backward)
# ---------------------------------------------------------------------------
const COMBAT_DASH_SPEED    : float = 700.0
const COMBAT_DASH_DURATION : float = 0.12
const COMBAT_DASH_COOLDOWN : float = 0.7
var _combat_dashing        : bool  = false
var _combat_dash_timer     : float = 0.0
var _combat_dash_cd        : float = 0.0
var _prev_touch_combat_dash: bool  = false
var _dash_timer          : float = 0.0   ## Counts down while dashing
var _dash_cooldown_timer : float = 0.0   ## Counts down between dashes

# ---------------------------------------------------------------------------
# Node references – assigned in _ready
# ---------------------------------------------------------------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var hurt_timer: Timer = $HurtTimer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var hunger_timer: Timer = $HungerTimer

# ===========================================================================
# _ready – initialise everything
# ===========================================================================
func _ready() -> void:
	# Register in group so World.gd and enemies can find us with get_nodes_in_group("player").
	add_to_group("player")

	# Register flip_block action if it isn't in the project Input Map already.
	if not InputMap.has_action("flip_block"):
		InputMap.add_action("flip_block")
		var ev := InputEventKey.new()
		ev.keycode = KEY_R
		InputMap.action_add_event("flip_block", ev)

	# Register dash action — keyboard Z, gamepad R3 (right stick click).
	# Shift is already sprint; LB is already hotbar_prev.
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var dash_kb := InputEventKey.new()
		dash_kb.keycode = KEY_Z
		InputMap.action_add_event("dash", dash_kb)
		var dash_joy := InputEventJoypadButton.new()
		dash_joy.button_index = JOY_BUTTON_RIGHT_STICK   # R3 — right stick click
		InputMap.action_add_event("dash", dash_joy)

	# Ensure gamepad B button (index 1) is registered as ui_cancel so the
	# close-UI check works even if the project.godot doesn't map it.
	var b_already_mapped := false
	for ev: InputEvent in InputMap.action_get_events("ui_cancel"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_B:
			b_already_mapped = true
			break
	if not b_already_mapped:
		var joy_ev := InputEventJoypadButton.new()
		joy_ev.button_index = JOY_BUTTON_B
		InputMap.action_add_event("ui_cancel", joy_ev)

	# Register block/parry action — keyboard Q, gamepad LB (already hotbar_prev uses LB,
	# so use L3 / left stick click instead to avoid conflict).
	if not InputMap.has_action("block"):
		InputMap.add_action("block")
		var blk_kb := InputEventKey.new()
		blk_kb.keycode = KEY_Q
		InputMap.action_add_event("block", blk_kb)
		var blk_joy := InputEventJoypadButton.new()
		blk_joy.button_index = JOY_BUTTON_LEFT_STICK   # L3
		InputMap.action_add_event("block", blk_joy)

	# Register combat_dash action — backward dodge. Keyboard X, gamepad Y button.
	# Y button was previously place_block; place is now on LT (left trigger axis 4).
	if not InputMap.has_action("combat_dash"):
		InputMap.add_action("combat_dash")
		var cd_kb := InputEventKey.new()
		cd_kb.keycode = KEY_X
		InputMap.action_add_event("combat_dash", cd_kb)
		var cd_joy := InputEventJoypadButton.new()
		cd_joy.button_index = JOY_BUTTON_Y  # Y button — freed up since place moved to LT
		InputMap.action_add_event("combat_dash", cd_joy)

	# Charge flash VFX — diamond shape over the weapon hand, visible when fully charged.
	_charge_flash_node = Polygon2D.new()
	_charge_flash_node.polygon = PackedVector2Array([
		Vector2(0.0, -10.0), Vector2(7.0, 0.0), Vector2(0.0, 10.0), Vector2(-7.0, 0.0)
	])
	_charge_flash_node.color = Color(1.0, 0.85, 0.1, 0.85)
	_charge_flash_node.position = Vector2(8.0, -18.0)
	_charge_flash_node.visible = false
	_charge_flash_node.z_index = 5
	add_child(_charge_flash_node)

	# Initialise stat values from their maximums.
	health = max_health
	hunger = max_hunger

	# Pre-fill hotbar and inventory arrays with empty-slot dictionaries.
	hotbar.resize(HOTBAR_SIZE)
	inventory.resize(INVENTORY_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar[i] = {}
	for i in range(INVENTORY_SIZE):
		inventory[i] = {}

	# Starting gear — gives the player something to work with immediately.
	# Durability -1 = unbreakable (tools have positive durability and wear down).
	# HOW TO CHANGE STARTING ITEMS: edit the item ids and counts below.
	hotbar[0] = {"id": "wood_axe",   "count": 1,  "durability": 80}
	hotbar[1] = {"id": "wood_pick",  "count": 1,  "durability": 80}
	hotbar[2] = {"id": "planks_oak", "count": 10, "durability": -1}

	# Emit signals so the HUD hotbar is populated immediately.
	for i in range(HOTBAR_SIZE):
		hotbar_changed.emit(i, hotbar[i])
	inventory_changed.emit()
	selected_slot_changed.emit(selected_slot)

	# Configure timers.  They must exist as child Timer nodes.
	# If you rename timers in the scene, update the @onready lines above.
	hurt_timer.wait_time = invincibility_duration
	hurt_timer.one_shot = true
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)

	coyote_timer.wait_time = coyote_time
	coyote_timer.one_shot = true
	coyote_timer.timeout.connect(_on_coyote_timer_timeout)

	jump_buffer_timer.wait_time = jump_buffer_time
	jump_buffer_timer.one_shot = true
	jump_buffer_timer.timeout.connect(_on_jump_buffer_timer_timeout)

	# Hunger drains 1 unit every 10 seconds = 0.1 per second.
	# We tick manually in _physics_process using delta for smooth drain.
	# HungerTimer is kept as an optional periodic signal if you prefer event-based UI.
	hunger_timer.wait_time = 10.0
	hunger_timer.autostart = true
	hunger_timer.timeout.connect(_on_hunger_timer_timeout)

	# Generate placeholder sprites so the character is always visible.
	_generate_sprites()

	# Build the hand-item node so the player appears to hold their hotbar item.
	_setup_hand_item()

	_setup_equipment_layers()

	# Block-target highlight — yellow semi-transparent overlay on the aimed tile.
	_mine_highlight = ColorRect.new()
	_mine_highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
	_mine_highlight.color = Color(1.0, 1.0, 0.0, 0.28)
	_mine_highlight.z_index = 5
	_mine_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mine_highlight.visible = false
	# Add to parent (world) so it renders in world space.
	call_deferred("_add_highlight_to_parent")

	# Apply the selected player class — scales stats and sets sprite color.
	# Must happen before the first health_changed/hunger_changed emit below.
	_apply_class_stats()

	# Class color is the primary visual — skin folder overrides only when explicitly set.
	# Clear any stale skin reference so it doesn't accidentally override class color.
	skin = null
	_apply_skin_to_sprite()

	# Enemy target indicator — red border shown over the nearest enemy in attack range.
	_enemy_highlight = ColorRect.new()
	_enemy_highlight.size = Vector2(TILE_SIZE * 2, TILE_SIZE * 2)
	_enemy_highlight.color = Color(1.0, 0.1, 0.1, 0.0)  # transparent fill
	_enemy_highlight.z_index = 6
	_enemy_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_highlight.visible = false
	var _eh_style := StyleBoxFlat.new()
	_eh_style.bg_color = Color(0, 0, 0, 0)
	_eh_style.border_color = Color(1.0, 0.1, 0.1, 0.85)
	_eh_style.set_border_width_all(2)
	add_child(_enemy_highlight)

	# Aim laser — red Line2D from player centre toward aimed tile.
	# Visible only when an analog stick / touch aim axis is actively pushed.
	_aim_laser = Line2D.new()
	_aim_laser.width = 2.0
	_aim_laser.default_color = Color(1.0, 0.15, 0.15, 0.85)
	_aim_laser.z_index = 10
	_aim_laser.visible = false
	# Gradient: bright red at origin, fades at the tip.
	var lg := Gradient.new()
	lg.set_color(0, Color(1.0, 0.2, 0.2, 0.9))
	lg.set_color(1, Color(1.0, 0.5, 0.5, 0.2))
	_aim_laser.gradient = lg
	add_child(_aim_laser)

	# Block-placement ghost — tinted with the selected block's colour at 50 % opacity.
	_place_highlight = ColorRect.new()
	_place_highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
	_place_highlight.color = Color(1.0, 1.0, 1.0, 0.5)
	_place_highlight.z_index = 4   # just below the mine highlight (z 5)
	_place_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_highlight.visible = false

	# Carried torch light — shown when holding a torch/lantern in the hotbar.
	var lt := PointLight2D.new()
	lt.texture       = _get_world_light_texture()
	lt.color         = Color(1.0, 0.78, 0.42)
	lt.energy        = 0.0
	lt.texture_scale = 7.0   # 7-tile radius with 32px texture at TILE_SIZE=16
	lt.shadow_enabled = false
	lt.z_index       = 5
	add_child(lt)
	_carried_light = lt

	# Landing dust — one-shot burst when player hits the ground.
	var ld := CPUParticles2D.new()
	ld.emitting              = false
	ld.one_shot              = true
	ld.explosiveness         = 0.95
	ld.amount                = 10
	ld.lifetime              = 0.55
	ld.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ld.emission_rect_extents = Vector2(6.0, 1.0)
	ld.direction             = Vector2(0.0, -1.0)
	ld.spread                = 70.0
	ld.initial_velocity_min  = 18.0
	ld.initial_velocity_max  = 45.0
	ld.gravity               = Vector2(0.0, 80.0)
	ld.scale_amount_min      = 1.5
	ld.scale_amount_max      = 3.0
	ld.color                 = Color(0.65, 0.52, 0.38, 0.70)
	ld.z_index               = 5
	add_child(ld)
	_land_particles = ld

	# Emit initial values so any connected UI is immediately up-to-date.
	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)

	# (Red shadow silhouette removed — no longer used.)

	# Cache parent (World node) once so _physics_process never calls get_parent().
	_world_node = get_parent()

	# Creative mode: fill inventory with every placeable block.
	if GameData.creative_mode:
		_populate_creative_inventory()
		var _qs := get_node_or_null("/root/QuestSystem")
		if _qs != null:
			_qs.on_creative_mode_entered()

# ===========================================================================
# _physics_process – main update loop (runs every physics tick)
# ===========================================================================
func _physics_process(delta: float) -> void:
	if not _eq_layers.is_empty() and (sprite.flip_h != _eq_last_flip or sprite.animation != _eq_last_anim):
		_eq_last_flip = sprite.flip_h
		_eq_last_anim = sprite.animation
		for _eq_overlay: AnimatedSprite2D in _eq_layers.values():
			if _eq_overlay.visible:
				_eq_overlay.flip_h = sprite.flip_h
				if _eq_overlay.animation != sprite.animation:
					_eq_overlay.play(sprite.animation)

	# --- Carried torch light -----------------------------------------------
	if _carried_light != null and GameData.fx.get("enabled", true) and GameData.fx.get("carried_torch", true):
		var sel_item: Dictionary = hotbar[selected_slot] if hotbar.size() > selected_slot else {}
		var item_id: String = sel_item.get("id", "")
		var is_light_item: bool = item_id in ["torch", "torch_wall", "campfire", "lantern", "glowstone"]
		if is_light_item:
			var t: float = Time.get_ticks_msec() / 1000.0
			var flicker: float = 1.0 + 0.10 * sin(t * 7.1) + 0.05 * sin(t * 13.8)
			_carried_light.energy = 1.0 * flicker
		else:
			_carried_light.energy = 0.0
	elif _carried_light != null:
		_carried_light.energy = 0.0

	if is_dead:
		return

	# ── Creative fly mode ─────────────────────────────────────────────────
	if _creative_flying:
		if not UIManager.ui_open:
			# No gravity — move freely in any direction using the analog/keyboard input.
			var fly_x: float = _get_move_input()
			var fly_y: float = 0.0
			if InputManager.using_touch():
				# Touch floating joystick: X = horizontal, Y = vertical.
				fly_y = InputManager.touch_move_axis.y
			elif InputManager.using_gamepad():
				# Left stick Y axis (axis 1): negative = up, positive = down.
				var joypads := Input.get_connected_joypads()
				if joypads.size() > 0:
					fly_y = Input.get_joy_axis(joypads[0], JOY_AXIS_LEFT_Y)
					if absf(fly_y) < 0.2:
						fly_y = 0.0
			else:
				# KBM: hold jump/W to fly up, hold crouch/S to fly down.
				fly_y = float(Input.is_action_pressed("crouch")) - float(Input.is_action_pressed("jump"))

			velocity = Vector2(fly_x, fly_y) * CREATIVE_FLY_SPEED
			# No-clip: move position directly so we pass through blocks.
			global_position += velocity * delta
			# Enforce sky ceiling even in creative fly.
			const _FLY_HEIGHT_LIMIT: float = WorldGenerator.HEIGHT_LIMIT_ROW * GameData.TILE_SIZE
			if global_position.y < _FLY_HEIGHT_LIMIT:
				global_position.y = _FLY_HEIGHT_LIMIT

			# Sprite direction.
			if fly_x > 0.0:
				_facing_right = true
			elif fly_x < 0.0:
				_facing_right = false
			sprite.flip_h = not _facing_right
			sprite.play("jump")  # use jump frame as "flying" visual

			# Double-jump exits fly mode; toggle handled in _try_jump already.
			if _is_jump_just_pressed():
				_try_jump()

			_handle_mining_and_combat(delta)

		_tick_survival(delta)
		if _attack_cooldown > 0.0:
			_attack_cooldown -= delta
		if _dash_cooldown_timer > 0.0:
			_dash_cooldown_timer -= delta
		if _dash_timer > 0.0:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_is_dashing = false
				_dash_cooldown_timer = DASH_COOLDOWN
		# skip move_and_slide and normal gravity below, fall through to UI/hotbar
	else:
	# --- Gravity -----------------------------------------------------------
	# Apply gravity every frame. When the player is on the floor the engine
	# zeroes out the vertical velocity automatically after move_and_slide().
		var applied_gravity: float = _get_gravity()

		if not is_on_floor():
			# Wall slide: if the player presses into a wall in mid-air, reduce gravity.
			if _is_wall_sliding():
				velocity.y += applied_gravity * wall_slide_gravity_mult * delta
			else:
				velocity.y += applied_gravity * delta
			# Variable jump height: while jump is held within the boost window,
			# apply upward force to counteract gravity — gives a floaty hold feel.
			if _jump_held:
				_jump_hold_timer += delta
				var jump_still_held: bool = Input.is_action_pressed("jump") or \
					(InputManager.using_touch() and InputManager.touch_jump)
				if _jump_hold_timer < jump_hold_time and jump_still_held:
					velocity.y -= jump_hold_force * delta
				else:
					_jump_held = false  # window expired or key released
			# Cap terminal velocity below 1 tile per physics step (16 px at 60 fps
			# = 960 px/s). Exceeding this risks tunnelling through solid floors.
			velocity.y = min(velocity.y, 900.0)

		# --- Coyote time bookkeeping -------------------------------------------
		if _was_on_floor and not is_on_floor() and velocity.y >= 0.0:
			_coyote_active = true
			coyote_timer.start()

		_was_on_floor = is_on_floor()

		# Landing: reset double-jump and consume buffered jump if any.
		if is_on_floor():
			_can_double_jump = true
			_coyote_active = false
			_creative_flying = false  # landing disables fly if somehow triggered
			_jump_held = false        # clear hold-boost on landing
			coyote_timer.stop()

			if not _was_on_floor and _land_particles != null and abs(velocity.y) > 80.0:
				if GameData.fx.get("enabled", true) and GameData.fx.get("landing_dust", true):
					_land_particles.amount = GameData.fx_particles(10)
					_land_particles.restart()

			if _jump_buffered:
				_jump_buffered = false
				_do_jump()

		# --- Read input --------------------------------------------------------
		# Block all gameplay input while any UI panel is open.
		var _any_ui: bool = UIManager.ui_open
		var move_input: float = _get_move_input() if not _any_ui else 0.0
		var is_running: bool = _is_running() if not _any_ui else false

		if _any_ui:
			is_crouching = false
		elif InputManager.using_touch():
			is_crouching = InputManager.touch_crouch
		elif GameData.crouch_toggle:
			# Toggle mode: press once to crouch, press again to stand.
			# Automatically uncrouch when leaving the floor (jumping).
			if Input.is_action_just_pressed("crouch"):
				is_crouching = not is_crouching
			if not is_on_floor():
				is_crouching = false
		else:
			is_crouching = Input.is_action_pressed("crouch")

		var speed: float
		if is_crouching:
			speed = move_speed * 0.5
		elif is_running:
			speed = run_speed
		else:
			speed = move_speed
		if get_meta("in_water", false):
			speed *= 0.45
		velocity.x = move_input * speed

		# Crouch ledge prevention: when crouching on the floor, stop before walking off edges.
		if is_crouching and is_on_floor() and abs(velocity.x) > 0.0:
			var ptile := _world_to_tile(global_position)
			var dir_sign := 1 if velocity.x > 0.0 else -1
			# If there is no solid tile below the player's next step, it's a ledge — stop.
			if not _tile_exists(ptile + Vector2i(dir_sign, 1)):
				velocity.x = 0.0

		if move_input > 0.0:
			_facing_right = true
		elif move_input < 0.0:
			_facing_right = false
		sprite.flip_h = not _facing_right
		_reposition_attack_area()
		if _hand_item != null and _hand_item.visible:
			_hand_item.position.x = 8.0 if _facing_right else -8.0
			_hand_item.flip_h     = not _facing_right

		if not _any_ui:
			if _is_jump_just_pressed():
				_try_jump()

			# ── Forward dash (toward facing direction) ──────────────────────────
			if _is_dash_just_pressed() and not _is_dashing and _dash_cooldown_timer <= 0.0:
				_do_dash()

			# ── Combat dash (backward — always away from facing direction) ───────
			if _is_combat_dash_just_pressed() and not _combat_dashing and not _is_dashing and _combat_dash_cd <= 0.0:
				_do_combat_dash()

		# Velocity override while dashing / combat dashing — stop if UI opens mid-dash.
		if _is_dashing and not _any_ui:
			velocity.x = _dash_dir * DASH_SPEED
		elif _combat_dashing and not _any_ui:
			velocity.x = (-1.0 if _facing_right else 1.0) * COMBAT_DASH_SPEED

		_tick_survival(delta)

		if _attack_cooldown > 0.0:
			_attack_cooldown -= delta
		if _dash_cooldown_timer > 0.0:
			_dash_cooldown_timer -= delta
		if _dash_timer > 0.0:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_is_dashing = false
				_dash_cooldown_timer = DASH_COOLDOWN
		if _combat_dash_timer > 0.0:
			_combat_dash_timer -= delta
			if _combat_dash_timer <= 0.0:
				_combat_dashing = false
				_combat_dash_cd = COMBAT_DASH_COOLDOWN
		if _combat_dash_cd > 0.0:
			_combat_dash_cd -= delta

		if not UIManager.ui_open:
			# ── Parry / block ─────────────────────────────────────────────────
			_tick_parry(delta)
			# ── Charge attack tick ────────────────────────────────────────────
			_tick_charge_attack(delta)
			_handle_mining_and_combat(delta)

	# --- Auto-sync: if a UI closed via its own button (not via B/Escape) ------
	# This catches FurnaceUI, CraftingUI, etc. closing themselves.
	# Runs only while inventory_open is true to avoid the get_parent() cost at idle.
	if inventory_open:
		if _world_node != null and _world_node.has_method("is_any_ui_open") and not _world_node.is_any_ui_open():
			inventory_open = false

	# --- Close any open UI (Escape / B / INV-touch-button) -------------------
	var _wants_close: bool = (
		Input.is_action_just_pressed("ui_cancel") or
		InputManager.open_inventory
	)
	if _wants_close:
		if _world_node and _world_node.has_method("is_any_ui_open") and _world_node.is_any_ui_open():
			_world_node.close_active_ui()
			inventory_open = false
			InputManager.open_inventory = false
			return   # swallow this frame — don't open on same press

	# --- Open inventory (E key / INV touch button) ----------------------------
	# Guard: if a UI closed itself this frame via its own handler (e.g. the player
	# pressed E while inventory was open and InventoryUI.close() already ran in
	# _input()), skip the open path — ui_just_closed is true for exactly this frame.
	var _open_inv_touch: bool = InputManager.open_inventory
	if _open_inv_touch:
		InputManager.open_inventory = false
	if (Input.is_action_just_pressed("interact") or _open_inv_touch) \
			and not UIManager.ui_just_closed \
			and not UIManager.ui_open:
		_handle_interact()

	# --- Hotbar selection --------------------------------------------------
	_handle_hotbar_input()

	# --- Apply movement (normal mode only; creative fly moves position directly) ---
	if not _creative_flying:
		move_and_slide()

		# --- Sky height limit: clamp above the world ceiling ─────────────────
		const _HEIGHT_LIMIT_Y: float = WorldGenerator.HEIGHT_LIMIT_ROW * GameData.TILE_SIZE
		if global_position.y < _HEIGHT_LIMIT_Y:
			global_position.y = _HEIGHT_LIMIT_Y
			velocity.y = maxf(velocity.y, 0.0)

		# --- Footstep sounds ---------------------------------------------------
		if is_on_floor() and abs(velocity.x) > 20.0:
			_footstep_timer -= delta
			if _footstep_timer <= 0.0:
				AudioManager.play_footstep()
				_footstep_timer = 0.32
		else:
			_footstep_timer = 0.0

		# --- Animations --------------------------------------------------------
		_check_weapon_skin()
		var _cur_move: float = velocity.x / max(move_speed, 1.0)
		_update_animation(_cur_move, abs(velocity.x) >= run_speed * 0.9)

# ===========================================================================
# Input helpers
# ===========================================================================

## Returns horizontal movement axis: -1.0, 0.0, or 1.0.
## Reads from TouchControls (via InputManager) on touch, keyboard/gamepad otherwise.
func _get_move_input() -> float:
	if InputManager.using_touch():
		return InputManager.touch_move_axis.x
	return Input.get_axis("move_left", "move_right")

## True when the player holds the sprint modifier (Shift key / gamepad left stick click / swipe dash).
## On touch: sprint activates from swipe-dash OR after 2 s of holding the joystick past run threshold.
## touch_run (joystick > RUN_THRESH) selects run_speed; touch_sprint further boosts to sprint.
func _is_running() -> bool:
	if InputManager.using_touch():
		return InputManager.touch_sprint or InputManager.touch_run
	return Input.is_action_pressed("sprint")

## True on the frame jump was pressed (KBM, gamepad, or touch).
func _is_jump_just_pressed() -> bool:
	if InputManager.using_touch():
		# Detect rising edge: button just became held this frame.
		var just_pressed: bool = InputManager.touch_jump and not _prev_touch_jump
		_prev_touch_jump = InputManager.touch_jump
		return just_pressed
	return Input.is_action_just_pressed("jump")

## True while the mine/attack button is held.
## Checks both "mine" and "attack" actions so gamepad X/Square (attack) and
## R2 trigger (mine) both work — on KBM they share the same key so no double-trigger.
func _is_mine_held() -> bool:
	if InputManager.using_touch():
		return InputManager.touch_mine
	return Input.is_action_pressed("mine") or Input.is_action_pressed("attack")

## True on the frame the place button was pressed (right click or touch place).
func _is_place_just_pressed() -> bool:
	if InputManager.using_touch():
		var just_pressed: bool = InputManager.touch_place and not _prev_touch_place
		_prev_touch_place = InputManager.touch_place
		return just_pressed
	return Input.is_action_just_pressed("place_block")

## True on the frame the dash button was pressed (touch DASH button, KBM Shift, gamepad L1).
func _is_dash_just_pressed() -> bool:
	if InputManager.using_touch():
		var just_pressed: bool = InputManager.touch_dash and not _prev_touch_dash
		_prev_touch_dash = InputManager.touch_dash
		InputManager.touch_dash = false   # consume pulse so it doesn't persist
		return just_pressed
	return Input.is_action_just_pressed("dash")

## Starts a dash in the current facing / input direction.
## Cancels any active attack — dash is the only way to break out of an attack animation.
func _do_dash() -> void:
	# Direction: prefer current move input, fall back to facing direction.
	var input_dir: float = _get_move_input()
	_dash_dir   = input_dir if absf(input_dir) > 0.1 else (1.0 if _facing_right else -1.0)
	_facing_right = _dash_dir > 0.0
	sprite.flip_h = not _facing_right

	_is_dashing  = true
	_dash_timer  = DASH_DURATION

	# Cancel any ongoing attack — dash is the only interrupt.
	_attack_cooldown = 0.0

	# Play dash animation; _update_animation won't override it while it plays.
	var sf: SpriteFrames = sprite.sprite_frames
	if sf != null and sf.has_animation("dash"):
		sprite.play("dash")

	AudioManager.play_jump()   # reuse jump sound as a satisfying dash whoosh

# ---------------------------------------------------------------------------
# Combat dash — always dashes BACKWARD (opposite of facing direction)
# ---------------------------------------------------------------------------
func _is_combat_dash_just_pressed() -> bool:
	if InputManager.using_touch():
		var jp: bool = InputManager.touch_combat_dash and not _prev_touch_combat_dash
		_prev_touch_combat_dash = InputManager.touch_combat_dash
		InputManager.touch_combat_dash = false
		return jp
	return Input.is_action_just_pressed("combat_dash")

func _do_combat_dash() -> void:
	_combat_dashing    = true
	_combat_dash_timer = COMBAT_DASH_DURATION
	_attack_cooldown   = 0.0    # cancel current swing
	var sf: SpriteFrames = sprite.sprite_frames
	if sf != null and sf.has_animation("roll"):
		sprite.play("roll")
	elif sf != null and sf.has_animation("dash"):
		sprite.play("dash")
	AudioManager.play_jump()

# ---------------------------------------------------------------------------
# Parry / block
# ---------------------------------------------------------------------------
func _is_block_just_pressed() -> bool:
	if InputManager.using_touch():
		var jp: bool = InputManager.touch_block and not _prev_touch_block
		_prev_touch_block = InputManager.touch_block
		InputManager.touch_block = false
		return jp
	return Input.is_action_just_pressed("block")

func _is_block_held() -> bool:
	if InputManager.using_touch():
		return InputManager.touch_block
	return Input.is_action_pressed("block")

func _tick_parry(delta: float) -> void:
	_parry_success = false
	if _parry_cooldown > 0.0:
		_parry_cooldown -= delta
		_is_blocking = false
		return
	if _is_block_just_pressed() and _parry_cooldown <= 0.0:
		_parry_timer  = PARRY_WINDOW
		_is_blocking  = true
		var sf: SpriteFrames = sprite.sprite_frames
		# Reuse wall_land as a brief block pose if available.
		if sf != null and sf.has_animation("wall_land"):
			sprite.play("wall_land")
	if _parry_timer > 0.0:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			_parry_timer = 0.0
			# Window expired — still blocking but no longer a perfect parry.
	if not _is_block_held():
		if _is_blocking:
			_parry_cooldown = PARRY_COOLDOWN
		_is_blocking = false
		_parry_timer = 0.0

## Called by damage sources to check if the hit should be parried.
## Returns true and triggers counter if within the parry window.
func try_parry(attacker: Node2D) -> bool:
	if not _is_blocking:
		return false
	if _parry_timer > 0.0:
		# Perfect parry — stagger attacker and give player brief i-frames.
		_parry_success = true
		_parry_timer   = 0.0
		_parry_cooldown = PARRY_COOLDOWN
		_is_blocking   = false
		# Brief invincibility flash.
		if not _invincible:
			_invincible = true
			hurt_timer.start(0.4)
		# Stagger attacker if it supports it.
		if attacker != null and attacker.has_method("take_damage"):
			attacker.take_damage(5.0)  # small counter-hit
		AudioManager.play_jump()  # placeholder parry sound
		return true
	# Regular block: absorb 60% of damage (handled by take_damage override).
	return false

# ---------------------------------------------------------------------------
# Charge attack
# ---------------------------------------------------------------------------
func _tick_charge_attack(delta: float) -> void:
	# Reset when button released or interrupted.
	if not _is_mine_held() or _is_dashing or _combat_dashing:
		_charge_timer = 0.0
		_charge_ready = false
		if _charge_flash_node != null:
			_charge_flash_node.visible = false
		return

	var item_data: Dictionary = ItemDB.get_item(get_selected_item().get("id", ""))
	var style: String = _get_weapon_style()

	# Only melee weapons with damage participate in charging; guns fire via normal path.
	if style == "shoot" or item_data.get("damage", 0.0) <= 0.0:
		return

	_charge_timer += delta

	if _charge_timer >= CHARGE_HOLD_TIME:
		if not _charge_ready:
			_charge_ready = true
		# Pulse flash indicator while charged.
		if _charge_flash_node != null:
			_charge_flash_node.visible = true
			_charge_flash_node.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
			_charge_flash_node.position.x = 7.0 if _facing_right else -21.0

	# Fire heavy attack the moment charge is ready AND cooldown has cleared.
	# Fires while button is HELD — no release required.
	if _charge_ready and _attack_cooldown <= 0.0:
		_do_heavy_attack()
		_charge_timer = 0.0
		_charge_ready = false
		if _charge_flash_node != null:
			_charge_flash_node.visible = false

func _do_heavy_attack() -> void:
	if _attack_cooldown > 0.0:
		return
	var selected: Dictionary = get_selected_item()
	var item_data: Dictionary = ItemDB.get_item(selected.get("id", ""))
	var attack_speed: float = item_data.get("attack_speed", 1.5)
	_attack_cooldown = (1.0 / max(attack_speed, 0.1)) * 1.4  # slightly longer cooldown

	var base_dmg: float = item_data.get("damage", 5.0)
	var damage: float = base_dmg * CHARGE_DMG_MULT * GameData.player_damage_mult * GameData.class_damage_mult

	# Play the strongest available attack animation.
	var sf: SpriteFrames = sprite.sprite_frames
	match _get_weapon_style():
		"katana":
			sprite.play("katana_attack" if sf != null and sf.has_animation("katana_attack") else "attack")
		"sword":
			sprite.play("sword_attack" if sf != null and sf.has_animation("sword_attack") else "attack")
		_:
			sprite.play("punch_cross" if sf != null and sf.has_animation("punch_cross") else "attack")

	# Hit all enemies within 1.5× normal melee range.
	var hit_range: float = MELEE_SCAN_RANGE * 1.5
	for grp in ["enemy", "animals"]:
		for node: Node in get_tree().get_nodes_in_group(grp):
			if node.has_method("take_damage"):
				if global_position.distance_to((node as Node2D).global_position) <= hit_range:
					node.take_damage(damage)
					var kb_dir: Vector2 = ((node as Node2D).global_position - global_position).normalized()
					if node is CharacterBody2D:
						(node as CharacterBody2D).velocity += kb_dir * 380.0

# ===========================================================================
# Jump logic
# ===========================================================================

## Attempts a jump, respecting coyote time and double-jump rules.
func _try_jump() -> void:
	if is_on_floor() or _coyote_active:
		# Normal jump from ground or from coyote window.
		_coyote_active = false
		coyote_timer.stop()
		_do_jump()
	elif GameData.creative_mode:
		# Creative mode: double-jump in the air toggles fly.
		_creative_flying = not _creative_flying
		if _creative_flying:
			velocity = Vector2.ZERO  # stop falling immediately
	elif _can_double_jump:
		# Survival double jump in mid-air.
		_can_double_jump = false
		_do_jump()
	else:
		_jump_buffered = true
		jump_buffer_timer.start()

## Applies the upward velocity impulse and plays the jump animation.
func _do_jump() -> void:
	velocity.y = jump_velocity
	_jump_held = true        # begin variable-height hold window
	_jump_hold_timer = 0.0
	sprite.play("jump")
	AudioManager.play_jump()

# ===========================================================================
# Wall slide
# ===========================================================================

## Returns true when the player is in the air, pressing into a wall.
func _is_wall_sliding() -> bool:
	if is_on_floor():
		return false
	if not is_on_wall():
		return false
	var move: float = _get_move_input()
	# Pressing toward the wall (wall_normal.x is opposite to move direction).
	var wall_normal: Vector2 = get_wall_normal()
	return (move > 0.0 and wall_normal.x < 0.0) or (move < 0.0 and wall_normal.x > 0.0)

# ===========================================================================
# Gravity helper
# ===========================================================================

## Returns the effective gravity value.
## Checks GameData autoload first; falls back to the exported variable.
func _get_gravity() -> float:
	# HOW TO USE PROJECT SETTINGS GRAVITY:
	#   return ProjectSettings.get_setting("physics/2d/default_gravity")
	# HOW TO USE GAMEDATA AUTOLOAD:
	#   if Engine.has_singleton("GameData"): return GameData.gravity
	return gravity

# ===========================================================================
# Survival stats
# ===========================================================================

## Deferred so get_parent() is valid by the time this is called.
func _add_highlight_to_parent() -> void:
	if get_parent() == null:
		return
	if _mine_highlight != null:
		get_parent().add_child(_mine_highlight)
	if _place_highlight != null:
		get_parent().add_child(_place_highlight)


## Called every physics frame. Drains hunger and applies health effects.
func _tick_survival(delta: float) -> void:
	if GameData.creative_mode:
		return  # No hunger/starvation in creative mode.
	# Drain hunger at a constant rate.
	hunger -= hunger_drain_rate * delta
	hunger = max(hunger, 0.0)

	if hunger == 0.0:
		# Starvation: slowly remove health without triggering hurt animation.
		_take_environmental_damage(starve_damage_rate * delta)
	elif hunger > 50.0:
		# Well-fed regeneration.
		_heal(health_regen_rate * delta)

	hunger_changed.emit(hunger, max_hunger)

	# --- Water drowning ---
	# If the player's head is submerged, drain air; take damage when air runs out.
	if get_parent() != null and get_parent().has_method("get_tile_at_world_pos"):
		var head_tile: String = get_parent().get_tile_at_world_pos(global_position)
		if head_tile == "water":
			_air_timer -= delta
			if _air_timer <= 0.0:
				_take_environmental_damage(2.0 * delta)  # 2 HP/s while drowning
		else:
			_air_timer = minf(_air_timer + delta * 2.0, _MAX_AIR)  # refill at 2× rate

## Called every 10 seconds by HungerTimer (optional event-based notification).
func _on_hunger_timer_timeout() -> void:
	# This timer fires for any coarser game systems that prefer event-based updates.
	# Actual drain happens in _tick_survival() using delta time.
	pass

## Apply healing without exceeding max_health.
func _heal(amount: float) -> void:
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)

## Public: deal damage to the player.
## Respects invincibility frames.  Called by enemies, hazards, starvation, etc.
func take_damage(amount: float, attacker: Node2D = null) -> void:
	if GameData.creative_mode:
		return
	if _invincible or is_dead:
		return

	# Parry check — perfect parry negates + counters; regular block absorbs 60%.
	if _is_blocking:
		if try_parry(attacker):
			return   # perfect parry: fully negated
		amount *= 0.40   # regular block: 60% reduction

	var armor_reduction := clampf(get_equipment_bonus("armor"), 0.0, 0.75)
	health -= amount * (1.0 - armor_reduction)
	health = max(health, 0.0)
	health_changed.emit(health, max_health)

	if health <= 0.0:
		_die()
		return

	if get_parent().has_method("camera_shake"):
		get_parent().camera_shake(4.0, 0.15)

	# Start invincibility window and flash the hurt animation.
	_invincible = true
	hurt_timer.start()
	sprite.play("hurt")
	AudioManager.play_hurt()

func _on_hurt_timer_timeout() -> void:
	_invincible = false

## Player death: play animation and emit global signal.
func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	sprite.play("die")
	AudioManager.play_death()

	# GameData is expected to be an autoload singleton with a player_died signal.
	# HOW TO CHANGE DEATH BEHAVIOUR:
	#   Replace the line below with your own respawn / game-over logic.
	# GameData is an autoload (always available). Emit player_died signal.
	GameData.player_died.emit()

# ===========================================================================
# Mining & Combat
# ===========================================================================

## Decides whether to mine, attack, or place depending on context.
## Returns the current aim direction as a normalised Vector2.
## Priority: right stick / mouse direction → latched last direction → player facing.
## Always returns a valid non-zero vector so digging never stalls.
func _get_aim_direction() -> Vector2:
	if InputManager.using_kbm():
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			return to_mouse.normalized()
	elif InputManager.using_touch():
		var ax := InputManager.touch_aim_axis
		if ax.length() >= GameData.aim_deadzone:
			_last_aim_dir = ax.normalized()
			return _last_aim_dir
	else:
		var ax := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
						  Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if ax.length() >= GameData.aim_deadzone:
			_last_aim_dir = ax.normalized()
			return _last_aim_dir

	# Fall back to latched direction, else facing direction.
	if _last_aim_dir != Vector2.ZERO:
		return _last_aim_dir
	return Vector2(1.0 if _facing_right else -1.0, 0.0)


## Returns the best minable tile in `aim` direction within mine_reach.
## Uses Chebyshev ring scan so orthogonal tiles are always reachable.
func _get_tile_in_direction(aim: Vector2) -> Vector2i:
	var player_tile := _world_to_tile(global_position)
	for dist in range(1, mine_reach + 1):
		var best := Vector2i(-9999, -9999)
		var best_dot := -2.0
		for dx in range(-dist, dist + 1):
			for dy in range(-dist, dist + 1):
				if maxi(absi(dx), absi(dy)) != dist:
					continue
				var off_f := Vector2(float(dx), float(dy))
				var d: float = off_f.normalized().dot(aim) if off_f.length() > 0.0 else 0.0
				if d > best_dot:
					best_dot = d
					best = player_tile + Vector2i(dx, dy)
		if best != Vector2i(-9999, -9999) and _tile_exists(best):
			return best
	# Nothing found — return one tile in aim direction so highlight appears
	var step := Vector2i(int(round(aim.x)), int(round(aim.y)))
	return player_tile + step


## Returns true when the selected hotbar item is a combat weapon.
## Tools (pick, axe, shovel) and bare fists return false and can dig.
func _is_weapon_selected() -> bool:
	var id: String = get_selected_item().get("id", "")
	if id.is_empty():
		return false
	var tt = ItemDB.get_item(id).get("tool_type", "")
	return tt is String and tt in ["sword", "katana", "gun"]


## Returns the nearest enemy/animal within px_range pixels, or null.
## Used by weapon auto-lock (wider scan than the melee MELEE_SCAN_RANGE).
func _get_nearest_target_in_range(px_range: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = px_range
	for grp in ["enemy", "animals"]:
		for node: Node in get_tree().get_nodes_in_group(grp):
			if not node.has_method("take_damage"):
				continue
			var d: float = global_position.distance_to((node as Node2D).global_position)
			if d < best_dist:
				best_dist = d
				best = node as Node2D
	return best


func _handle_mining_and_combat(delta: float) -> void:
	if UIManager.ui_open:
		_reset_mining()
		if _aim_laser != null and is_instance_valid(_aim_laser):
			_aim_laser.visible = false
		return

	# ── 1. Aim direction (unified across KBM / gamepad / touch) ────────────
	var aim_dir: Vector2 = _get_aim_direction()

	# ── 2. Tile target ──────────────────────────────────────────────────────
	# LASER AIM (touch / gamepad): when analog stick is pushed, the red laser
	# draws toward the aimed tile and that tile becomes the dig target.
	# KBM: mouse position is used as usual.
	# Fallback / auto-target lines are preserved below (commented) for reference.
	var tile_pos: Vector2i
	if InputManager.using_kbm():
		tile_pos = _world_to_tile(get_global_mouse_position())
	elif InputManager.using_touch():
		var ax: Vector2 = InputManager.touch_aim_axis
		if ax.length() >= GameData.aim_deadzone:
			# Aim stick pushed — mine exactly where it points.
			tile_pos = _get_gamepad_mine_tile()
		elif absf(velocity.x) > 15.0 or is_crouching:
			# Auto-target only while the player is actually moving or crouching.
			tile_pos = _get_auto_target_tile(_world_to_tile(global_position))
		else:
			tile_pos = Vector2i(-9999, -9999)   # standing still, no aim → no dig
	elif InputManager.using_gamepad():
		var ax := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
						  Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if ax.length() >= GameData.aim_deadzone:
			tile_pos = _get_gamepad_mine_tile()
		elif absf(velocity.x) > 15.0 or is_crouching:
			tile_pos = _get_auto_target_tile(_world_to_tile(global_position))
		else:
			tile_pos = Vector2i(-9999, -9999)   # standing still, no aim → no dig
	else:
		# (original: tile_pos = _get_tile_in_direction(aim_dir))
		tile_pos = _get_tile_in_direction(aim_dir)

	# Compute place target first so the laser can reference it.
	_place_target = _get_place_tile()
	_update_place_highlight()

	# Only show block highlight when a weapon is NOT selected.
	var weapon_out: bool = _is_weapon_selected()
	if not weapon_out:
		_aimed_tile = tile_pos
		_update_highlight()
		# Build mode: aim laser shows the placement ghost position when the
		# analog stick (or touch aim axis) is live so mid-air placement is clear.
		# Dig mode: laser shows the dig target as usual.
		var _held_item := get_selected_item()
		var _held_data := ItemDB.get_item(_held_item.get("id", ""))
		if _held_data.get("placeable", false) and _place_target != Vector2i(-9999, -9999):
			_update_aim_laser(_place_target)
		else:
			_update_aim_laser(tile_pos)
	else:
		if _mine_highlight != null and is_instance_valid(_mine_highlight):
			_mine_highlight.visible = false
		if _aim_laser != null and is_instance_valid(_aim_laser):
			_aim_laser.visible = false
		_aimed_tile = Vector2i(-9999, -9999)

	# ── 3. Enemy / target scan ──────────────────────────────────────────────
	var style: String = _get_weapon_style()
	# Guns scan the full weapon range; melee scans a close radius.
	var scan_range: float
	if style == "shoot":
		scan_range = mine_reach * TILE_SIZE * 1.5   # full gun range
	else:
		scan_range = MELEE_SCAN_RANGE * 2.5          # a few tiles

	# Throttle: re-scan at most 10 times/s (every 100 ms) instead of every physics frame.
	# Invalidate cache if the node was freed since last scan.
	_lock_scan_cd -= delta
	if _lock_target_cached != null and not is_instance_valid(_lock_target_cached):
		_lock_target_cached = null
	if _lock_scan_cd <= 0.0:
		_lock_scan_cd = 0.10
		_lock_target_cached = _get_nearest_target_in_range(scan_range)
	var lock_target: Node2D = _lock_target_cached

	# Update enemy highlight.
	if lock_target != null and is_instance_valid(lock_target):
		_enemy_highlight.visible = true
		_enemy_highlight.global_position = lock_target.global_position - Vector2(TILE_SIZE, TILE_SIZE)
	else:
		_enemy_highlight.visible = false

	# ── 4. ACTION ───────────────────────────────────────────────────────────
	if _is_mine_held():
		if weapon_out:
			# ── WEAPON MODE: NEVER touches blocks ───────────────────────────
			_reset_mining()
			if lock_target != null:
				# Auto-face toward the locked target.
				_facing_right = lock_target.global_position.x >= global_position.x
				sprite.flip_h = not _facing_right
				# Override aim toward target so guns fire accurately.
				_last_aim_dir = (lock_target.global_position - global_position).normalized()
			# Charge attack accumulates while held; light attacks fire on first press.
			if _attack_cooldown <= 0.0 and not _charge_ready:
				_do_melee_attack()
		else:
			# ── TOOL / BARE FIST MODE: enemies first, then dig ──────────────
			# Use the close-range nearest enemy for tool swings.
			var nearest_melee: Node2D = _get_nearest_enemy()
			if nearest_melee != null and _attack_cooldown <= 0.0:
				_reset_mining()
				_do_melee_attack()
			elif _tile_exists(tile_pos):
				_do_mine(tile_pos, delta)
			else:
				# KBM: mouse on air → stop mining; no auto-grab.
				# Touch/Gamepad: fallback only if already moving (handled upstream by tile_pos = -9999).
				_reset_mining()
	else:
		_reset_mining()

	# ── 5. Place button ─────────────────────────────────────────────────────
	if _is_place_just_pressed():
		# _place_target already follows the aim laser (right stick / touch aim joystick).
		# tile_pos is the solid dig target — passing it to _do_place always fails.
		if _place_target != Vector2i(-9999, -9999):
			_do_place(_place_target)

	# ── 5b. Tap-to-place (touch only) ───────────────────────────────────────
	# When the player taps an empty spot in the world on mobile, place the
	# selected block there.  Tapping an occupied tile is safely ignored by _do_place.
	if InputManager.using_touch() and InputManager.touch_has_tap:
		InputManager.touch_has_tap = false
		var tap_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * InputManager.touch_tap_screen
		var tap_tile := _world_to_tile(tap_world)
		_do_place(tap_tile)


## Updates the red aim laser.
## Shows a Line2D from the player centre to the aimed tile centre
## only when analog stick / touch aim axis is actively pushed this frame.
func _update_aim_laser(aimed: Vector2i) -> void:
	if _aim_laser == null or not is_instance_valid(_aim_laser):
		return

	# Determine whether any analog aim input is live right now.
	var stick_live: bool = false
	if InputManager.using_touch():
		stick_live = InputManager.touch_aim_axis.length() >= GameData.aim_deadzone
	elif InputManager.using_gamepad():
		var ax := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
						  Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		stick_live = ax.length() >= GameData.aim_deadzone

	# KBM: laser is not shown (mouse cursor already acts as the aim indicator)
	if InputManager.using_kbm():
		_aim_laser.visible = false
		return

	if not stick_live:
		_aim_laser.visible = false
		return

	# Draw from local origin (player centre) to the aimed tile centre.
	var target_world: Vector2 = _tile_to_world(aimed) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	var local_target: Vector2 = target_world - global_position
	_aim_laser.clear_points()
	_aim_laser.add_point(Vector2(0 , -12))
	_aim_laser.add_point(local_target)
	_aim_laser.visible = true


## Show / hide the block-target highlight at the current aimed tile.
func _update_highlight() -> void:
	if _mine_highlight == null or not is_instance_valid(_mine_highlight):
		return
	if _tile_exists(_aimed_tile):
		_mine_highlight.global_position = _tile_to_world(_aimed_tile)
		_mine_highlight.visible = true
		_mine_highlight.color = Color(1.0, 1.0, 0.0, 0.28) if _is_mine_held() else Color(1.0, 1.0, 1.0, 0.18)
		# Emit tile name for HUD label
		var world: Node = get_parent()
		var raw_id: String = world.get_tile_at_world_pos(_tile_to_world(_aimed_tile)) if world and world.has_method("get_tile_at_world_pos") else ""
		var display: String = raw_id.replace("_", " ").capitalize() if raw_id != "" else ""
		aimed_tile_changed.emit(display)
	else:
		_mine_highlight.visible = false
		aimed_tile_changed.emit("")


## Shows or hides the block-placement ghost depending on whether a placeable
## block is selected and a valid placement spot is available.
func _update_place_highlight() -> void:
	if _place_highlight == null or not is_instance_valid(_place_highlight):
		return

	var selected := get_selected_item()
	if selected.is_empty():
		_place_highlight.visible = false
		return

	var item_data := ItemDB.get_item(selected.get("id", ""))
	if not item_data.get("placeable", false):
		_place_highlight.visible = false
		return

	if _place_target == Vector2i(-9999, -9999):
		_place_highlight.visible = false
		return

	# Tint the ghost with the block's icon colour at 50 % opacity.
	var c: Color = item_data.get("icon_color", Color(0.8, 0.8, 0.8))
	c.a = 0.5
	_place_highlight.color = c
	_place_highlight.global_position = _tile_to_world(_place_target)
	_place_highlight.visible = true


func _get_world_light_texture() -> Texture2D:
	var world: Node = get_tree().get_first_node_in_group("world")
	if world and "_light_texture" in world and world._light_texture != null:
		return world._light_texture
	# Fallback: build a 32x32 gradient matching World's texture (RGB falloff, alpha=1).
	var sz: int = 32
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var half: float = sz * 0.5
	for y in sz:
		for x in sz:
			var d: float = Vector2(x - half, y - half).length() / half
			var a: float = clamp(1.0 - d * d, 0.0, 1.0)
			img.set_pixel(x, y, Color(a, a, a, 1.0))
	return ImageTexture.create_from_image(img)


## Touch smart-targeting: if crouching mine directly below, otherwise scan nearby
## tiles and auto-select the nearest one with a bias toward the facing direction.
## Result is cached for 0.12 s to avoid 121 tile-checks every physics frame.
var _touch_mine_cache: Vector2i = Vector2i(-9999, -9999)
var _touch_mine_cache_cd: float = 0.0

## Auto-target style: scans nearby tiles and returns the nearest solid block,
## biased toward the facing direction and the block directly above if in the walk path.
func _get_auto_target_tile(player_tile: Vector2i) -> Vector2i:
	var equipped_type: String = _get_equipped_tool_type()
	var facing_sign: int = 1 if _facing_right else -1
	# Scan order: closest column first, then step outward.
	# Height is capped to 3 rows (head / torso / feet = -1, 0, +1 relative to player tile).
	# This ensures the block immediately beside the player is never skipped.
	var offsets: Array[Vector2i] = [
		# ── Column 1 (directly adjacent) — highest priority ──
		Vector2i(facing_sign, -1),   # adjacent upper
		Vector2i(facing_sign,  0),   # adjacent middle  ← most common wall hit
		Vector2i(facing_sign,  1),   # adjacent lower
		# ── Column 0 (same X as player — directly above/below) ──
		Vector2i(0, -1),             # directly above
		Vector2i(0,  1),             # directly below
		# ── Column 2 (one further) ──
		Vector2i(facing_sign * 2, -1),
		Vector2i(facing_sign * 2,  0),
		Vector2i(facing_sign * 2,  1),
		# ── Column -1 (behind player, last resort) ──
		Vector2i(-facing_sign, -1),
		Vector2i(-facing_sign,  0),
		Vector2i(-facing_sign,  1),
	]
	for off: Vector2i in offsets:
		var check: Vector2i = player_tile + off
		if _tile_exists(check) and _tile_matches_tool(check, equipped_type):
			return check
	if GameData.tool_focus and equipped_type in ["axe", "pick", "shovel"]:
		return Vector2i(-9999, -9999)
	return Vector2i(player_tile.x + facing_sign, player_tile.y)


func _get_touch_mine_tile() -> Vector2i:
	var player_tile := _world_to_tile(global_position)

	# Crouch → mine the block directly below the player's feet (no cache needed).
	if is_crouching:
		for d in range(1, 3):
			var check := Vector2i(player_tile.x, player_tile.y + d)
			if _tile_exists(check):
				return check
		return Vector2i(player_tile.x, player_tile.y + 1)

	# Return cached result when still fresh.
	_touch_mine_cache_cd -= get_physics_process_delta_time()
	if _touch_mine_cache_cd > 0.0 and _touch_mine_cache != Vector2i(-9999, -9999):
		return _touch_mine_cache

	_touch_mine_cache_cd = 0.12

	# Latch aim direction from the touch aim axis when actively pushed.
	var DEADZONE: float = GameData.aim_deadzone
	var aim_axis: Vector2 = InputManager.touch_aim_axis
	var raw_len := aim_axis.length()
	if raw_len >= DEADZONE:
		_last_aim_dir = aim_axis.normalized()

	# Auto-target style: when stick at rest, use proximity scan.
	if raw_len < DEADZONE and GameData.aim_style == 1:
		return _get_auto_target_tile(player_tile)

	var aim: Vector2
	if _last_aim_dir != Vector2.ZERO:
		aim = _last_aim_dir
	else:
		aim = Vector2(1.0 if _facing_right else -1.0, 0.0)

	# Scale reach by how far the touch aim stick is pushed.
	var effective_reach: int
	if raw_len >= DEADZONE:
		var t: float = clamp((raw_len - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		effective_reach = max(1, int(round(1.0 + t * float(mine_reach - 1))))
	else:
		effective_reach = mine_reach

	var equipped_type: String = _get_equipped_tool_type()
	# Alignment-based scan: nearest ring first, pick best-aligned valid+matching tile per ring.
	for dist in range(1, effective_reach + 1):
		var best_check := Vector2i(-9999, -9999)
		var best_dot   := -2.0
		for dx in range(-dist, dist + 1):
			for dy in range(-dist, dist + 1):
				if maxi(absi(dx), absi(dy)) != dist:
					continue
				var candidate := player_tile + Vector2i(dx, dy)
				if not _tile_exists(candidate) or not _tile_matches_tool(candidate, equipped_type):
					continue
				var off_f := Vector2(float(dx), float(dy))
				var d: float = off_f.normalized().dot(aim) if off_f.length() > 0.0 else 0.0
				if d > best_dot:
					best_dot   = d
					best_check = candidate
		if best_check != Vector2i(-9999, -9999):
			_touch_mine_cache = best_check
			return best_check

	var fallback := player_tile + Vector2i(int(round(aim.x)), int(round(aim.y)))
	if not _tile_matches_tool(fallback, equipped_type):
		_touch_mine_cache = Vector2i(-9999, -9999)
		return Vector2i(-9999, -9999)
	_touch_mine_cache = fallback
	return fallback


## Returns the tile to target on gamepad.
## Uses the right analogue stick to pick direction.
## Falls back to facing direction when the stick is at rest.
func _get_gamepad_mine_tile() -> Vector2i:
	var player_tile := _world_to_tile(global_position)

	# Crouch override: always mine downward.
	if is_crouching:
		for d in range(1, 3):
			var check := Vector2i(player_tile.x, player_tile.y + d)
			if _tile_exists(check):
				return check
		return Vector2i(player_tile.x, player_tile.y + 1)

	# --- Collect raw aim (keep magnitude for reach scaling) ---
	var aim_raw := Vector2.ZERO
	if InputManager.using_touch():
		aim_raw = InputManager.touch_aim_axis
	elif InputManager.using_gamepad():
		aim_raw = Vector2(
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		)

	# Latch: remember last pushed direction so releasing the stick keeps mining
	# in the same direction rather than snapping to facing.
	var DEADZONE: float = GameData.aim_deadzone
	var raw_len := aim_raw.length()
	var stick_active := raw_len >= DEADZONE

	var aim: Vector2
	if stick_active:
		_last_aim_dir = aim_raw.normalized()
		aim = _last_aim_dir
	elif GameData.aim_style == 1:
		# Auto-target style: fall back to proximity scan when stick is at rest.
		return _get_auto_target_tile(player_tile)
	elif _last_aim_dir != Vector2.ZERO:
		aim = _last_aim_dir
	else:
		aim = Vector2(1.0 if _facing_right else -1.0, 0.0)

	# --- Scale reach by how far the stick is pushed ---
	# Light push → only immediate tiles; full push → mine_reach.
	# When stick is released (latched), keep full reach so held-mine still works.
	var effective_reach: int
	if stick_active:
		var t: float = clamp((raw_len - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		effective_reach = max(1, int(round(1.0 + t * float(mine_reach - 1))))
	else:
		effective_reach = mine_reach

	var equipped_type: String = _get_equipped_tool_type()
	# --- Alignment-based scan: nearest ring first, pick best-aligned valid+matching tile per ring. ---
	for dist in range(1, effective_reach + 1):
		var best_check := Vector2i(-9999, -9999)
		var best_dot   := -2.0
		for dx in range(-dist, dist + 1):
			for dy in range(-dist, dist + 1):
				if maxi(absi(dx), absi(dy)) != dist:
					continue
				var candidate := player_tile + Vector2i(dx, dy)
				if not _tile_exists(candidate) or not _tile_matches_tool(candidate, equipped_type):
					continue
				var off_f := Vector2(float(dx), float(dy))
				var d: float = off_f.normalized().dot(aim) if off_f.length() > 0.0 else 0.0
				if d > best_dot:
					best_dot   = d
					best_check = candidate
		if best_check != Vector2i(-9999, -9999):
			return best_check

	var fallback := player_tile + Vector2i(int(round(aim.x)), int(round(aim.y)))
	if not _tile_matches_tool(fallback, equipped_type):
		return Vector2i(-9999, -9999)
	return fallback

## Finds the best empty tile to place a block in.
## Casts a ray in the aim direction; returns the last empty tile before the first
## solid tile (i.e. the face of whatever we're pointing at).
## Returns Vector2i(-9999,-9999) when no valid spot is found.
func _get_place_tile() -> Vector2i:
	var player_tile := _world_to_tile(global_position)

	# --- Collect aim direction ---
	var aim: Vector2
	if InputManager.using_kbm():
		var to_mouse := get_global_mouse_position() - global_position
		aim = to_mouse.normalized() if to_mouse.length() > 4.0 else Vector2(1.0 if _facing_right else -1.0, 0.0)
	elif InputManager.using_touch():
		# Use the same laser aim axis as digging so block placement follows the laser.
		var ax: Vector2 = InputManager.touch_aim_axis
		if ax.length() >= GameData.aim_deadzone:
			aim = ax.normalized()
		elif is_crouching:
			aim = Vector2(0.0, 1.0)
		else:
			aim = Vector2(1.0 if _facing_right else -1.0, 0.0)
	else:
		aim = Vector2(
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		)
		if aim.length() < 0.25:
			aim = Vector2(1.0 if _facing_right else -1.0, 0.0)
		else:
			aim = aim.normalized()

	# --- Raycast: last empty tile before first solid ---
	var last_air := Vector2i(-9999, -9999)
	for dist in range(1, mine_reach + 1):
		var check := Vector2i(
			player_tile.x + int(round(aim.x * dist)),
			player_tile.y + int(round(aim.y * dist))
		)
		if _tile_exists(check):
			# Solid tile found — the placement spot is the tile just before it.
			return last_air
		# Don't allow placing inside the player's own tile.
		if check != player_tile:
			last_air = check

	return last_air   # All air in range — place at furthest reachable empty tile.

## Advances mining progress for the tile at tile_pos.
func _do_mine(tile_pos: Vector2i, delta: float) -> void:
	var selected: Dictionary = get_selected_item()

	# Check mine level requirement.
	# HOW TO ADD NEW TOOLS:
	#   Give your item a "mine_level" int and "speed" float in ItemDB.
	#   The check below will respect them automatically.
	# Look up the tool stats from ItemDB — the hotbar slot only stores id/count/durability.
	var item_data: Dictionary = ItemDB.get_item(selected.get("id", ""))
	var item_mine_level: int = item_data.get("mine_level", 0)
	var item_speed: float = item_data.get("tool_speed", 1.0)

	# Ask the world node for block data (hardness and required mine_level).
	# HOW TO INTEGRATE WITH YOUR WORLD:
	#   Replace get_parent().get_block_data(tile_pos) with your own WorldGenerator call.
	var block_data: Dictionary = {}
	if get_parent().has_method("get_block_data"):
		block_data = get_parent().get_block_data(tile_pos)

	var block_hardness: float = block_data.get("hardness", 1.0)
	var required_level: int = block_data.get("mine_level", 0)

	# Creative mode bypasses all mine-level requirements.
	if not GameData.creative_mode and item_mine_level < required_level:
		_reset_mining()
		return

	# Tool focus: skip blocks that don't match the equipped tool's category.
	var equipped_type: String = item_data.get("tool_type", "")
	if GameData.tool_focus and equipped_type in ["axe", "pick", "shovel"]:
		var block_type: String = ItemDB.get_item(block_data.get("id", "")).get("tool_type", "")
		if block_type != equipped_type:
			_reset_mining()
			return

	# If cursor moved to a different tile, reset progress and crack.
	if tile_pos != _mining_target:
		if _mining_progress > 0.0 and get_parent().has_method("clear_crack"):
			get_parent().clear_crack()
		_mining_target = tile_pos
		_mining_progress = 0.0

	var effective_speed: float = tool_speed * item_speed
	if GameData.creative_mode:
		# Creative: always fast regardless of tool (bare hand = same speed as best tool).
		effective_speed = maxf(effective_speed, tool_speed * 3.0)
		if InputManager.using_gamepad():
			effective_speed *= 12.0
	# Advance progress.
	_mining_progress += (effective_speed / block_hardness) * delta
	mine_progress_changed.emit(_mining_progress)

	if get_parent().has_method("update_crack"):
		get_parent().update_crack(tile_pos, _mining_progress)

	sprite.play("mine")

	# Play periodic impact sound while mining (throttled to ~3 per second).
	_mine_sound_timer -= delta
	if _mine_sound_timer <= 0.0:
		AudioManager.play_mine_hit()
		_mine_sound_timer = 0.32
		if get_parent().has_method("camera_shake"):
			get_parent().camera_shake(2.0, 0.08)

	if _mining_progress >= 1.0:
		# Block is fully mined.
		_mining_progress = 0.0
		_mining_target = Vector2i(-9999, -9999)
		AudioManager.play_mine_complete()
		if get_parent().has_method("clear_crack"):
			get_parent().clear_crack()

		# Tell the world to remove the tile and return drops.
		if get_parent().has_method("mine_block"):
			var drops: Array = get_parent().mine_block(tile_pos)
			for drop in drops:
				var drop_id: String = str(drop.get("id", ""))
				var drop_count: int = drop.get("count", 1)
				add_item(drop_id, drop_count)
				# Notify quest system of collected items
				var qs := get_node_or_null("/root/QuestSystem")
				if qs != null:
					qs.on_item_collected(drop_id, drop_count)

		# Reduce tool durability.
		_damage_selected_item(1)

## Resets mining state (e.g. when button released or cursor moved away).
func _reset_mining() -> void:
	if _mining_progress > 0.0:
		_mining_progress = 0.0
		_mining_target = Vector2i(-9999, -9999)
		mine_progress_changed.emit(0.0)
		if get_parent().has_method("clear_crack"):
			get_parent().clear_crack()
	_mine_sound_timer = 0.0
	# Mine animation loops — stop it so _update_animation can take over.
	if sprite.animation == "mine":
		sprite.play("idle")

## Returns the nearest enemy within MELEE_SCAN_RANGE px, or null if none.
## Scans the scene tree directly so enemies standing ON the player are detected
## even when they haven't entered the AttackArea physics overlap yet.
## Close-range scan used by tool/fist mode (≤ MELEE_SCAN_RANGE px).
const MELEE_SCAN_RANGE: float = 64.0   # pixels — roughly 4 tiles
func _get_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist: float = MELEE_SCAN_RANGE
	# AttackArea first (fast physics query).
	for body in attack_area.get_overlapping_bodies():
		if body == self or not body.has_method("take_damage"):
			continue
		var d: float = global_position.distance_to(body.global_position)
		if d < best_dist:
			best_dist = d
			best = body
	# Full group scan — catches enemies sitting on top of player.
	for grp in ["enemy", "animals"]:
		for node: Node in get_tree().get_nodes_in_group(grp):
			if node == self or not node.has_method("take_damage"):
				continue
			var d: float = global_position.distance_to((node as Node2D).global_position)
			if d < best_dist:
				best_dist = d
				best = node as Node2D
	return best

## Performs a melee attack.
func _do_melee_attack() -> void:
	var selected: Dictionary = get_selected_item()
	var item_data: Dictionary = ItemDB.get_item(selected.get("id", ""))
	var attack_speed: float = item_data.get("attack_speed", 1.5)
	_attack_cooldown = 1.0 / max(attack_speed, 0.1)

	# Pick the attack animation for the currently held weapon type.
	var sf: SpriteFrames = sprite.sprite_frames
	var _ha := func(n: String) -> bool: return sf != null and sf.has_animation(n)
	match _get_weapon_style():
		"katana":
			# In air: air attack. Running: run attack. Grounded idle: normal attack.
			if not is_on_floor() and _ha.call("katana_air_attack"):
				sprite.play("katana_air_attack")
			elif absf(velocity.x) > move_speed * 0.5 and _ha.call("katana_run_attack"):
				sprite.play("katana_run_attack")
			elif _ha.call("katana_attack"):
				sprite.play("katana_attack")
			else:
				sprite.play("attack")
		"sword":
			# Stab vs swing: use stab when crouching / forward motion, swing otherwise.
			if is_crouching and _ha.call("sword_stab"):
				sprite.play("sword_stab")
			elif _ha.call("sword_attack"):
				sprite.play("sword_attack")
			else:
				sprite.play("attack")
		"shoot":
			sprite.play("shoot_fire" if _ha.call("shoot_fire") else "attack")
		"punch":
			# Alternate punch / punch_jab each hit for a natural combo feel.
			_punch_alt = not _punch_alt
			if _punch_alt and _ha.call("punch_jab"):
				sprite.play("punch_jab")
			elif _ha.call("punch"):
				sprite.play("punch")
			else:
				sprite.play("attack")
		_:
			# Default: punch for bare hands / tools, generic attack for anything else.
			sprite.play("punch" if _ha.call("punch") else "attack")

	var base_dmg: float = item_data.get("damage", 5.0)
	var damage: float = base_dmg * GameData.player_damage_mult * GameData.class_damage_mult

	var style: String = _get_weapon_style()
	var hit_targets: Array = []

	if style == "shoot":
		# Gun: spawn a visual Projectile that travels in the aim direction.
		# _last_aim_dir was updated toward any lock-target before this call.
		var aim: Vector2 = _get_aim_direction()
		_spawn_projectile(aim, damage)
		return   # Projectile handles the hit — skip the hit_targets loop below
	else:
		# Melee: AttackArea bodies + scene-tree scan within MELEE_SCAN_RANGE.
		for body in attack_area.get_overlapping_bodies():
			if body != self and body.has_method("take_damage"):
				hit_targets.append(body)
		for grp in ["enemy", "animals"]:
			for node: Node in get_tree().get_nodes_in_group(grp):
				if node not in hit_targets and node.has_method("take_damage"):
					if global_position.distance_to((node as Node2D).global_position) <= MELEE_SCAN_RANGE:
						hit_targets.append(node)

	for body: Node2D in hit_targets:
		body.take_damage(damage)
		var kb_dir: Vector2 = (body.global_position - global_position).normalized()
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity += kb_dir * 220.0

## Spawns a Projectile node that travels in aim_dir and deals proj_damage on first hit.
## Called from _do_melee_attack() when a gun weapon is active.
## The Projectile class (Projectile.gd) handles collision, visual, and damage.
func _spawn_projectile(aim_dir: Vector2, proj_damage: float) -> void:
	var item_data: Dictionary = ItemDB.get_item(get_selected_item().get("id", ""))
	var gun_range: float = mine_reach * TILE_SIZE * 1.5

	var proj := Projectile.new()
	proj.direction  = aim_dir.normalized()
	proj.damage     = proj_damage
	proj.max_range  = gun_range
	proj.owner_node = self
	# Per-gun speed: add "projectile_speed" to ItemDatabase entry to customise.
	# Defaults: pistol / rifle / shotgun use 900 px/s unless overridden.
	proj.speed = float(item_data.get("projectile_speed", 900))

	# Spawn slightly in front of the player so the bullet doesn't immediately
	# collide with the player's own physics body.
	var spawn_offset := aim_dir.normalized() * 24.0
	get_parent().add_child(proj)
	proj.global_position = global_position + spawn_offset


## Place the selected hotbar item at tile_pos, or eat it if it's food.
func _do_place(tile_pos: Vector2i) -> void:
	var selected: Dictionary = get_selected_item()
	if selected.is_empty():
		return

	var item_id: String = selected.get("id", "")
	var item_data: Dictionary = ItemDB.get_item(item_id)

	# Bucket interactions.
	if item_id == "bucket_empty":
		var world: Node = get_parent()
		if world and world.has_method("get_tile_at_world_pos"):
			var world_px := Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
			var tile: String = world.get_tile_at_world_pos(world_px)
			if tile == "water":
				if world.has_method("remove_water_tile"):
					world.remove_water_tile(tile_pos)
				hotbar[selected_slot] = {"id": "bucket_water", "count": 1}
				hotbar_changed.emit(selected_slot, hotbar[selected_slot])
				return
		return

	if item_id == "bucket_water":
		var world: Node = get_parent()
		if world and world.has_method("get_tile_at_world_pos"):
			var world_px := Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
			var tile: String = world.get_tile_at_world_pos(world_px)
			if tile == "" or tile == "air":
				if world.has_method("place_water_source"):
					world.place_water_source(tile_pos)
				hotbar[selected_slot] = {"id": "bucket_empty", "count": 1}
				hotbar_changed.emit(selected_slot, hotbar[selected_slot])
				return
		return

	# Right-click / place on a food item: eat it.
	if item_data.get("edible", false):
		_eat_selected(item_data)
		return

	if not item_data.get("placeable", false):
		return

	var dist: float = global_position.distance_to(_tile_to_world(tile_pos))
	if dist > mine_reach * TILE_SIZE:
		return

	if get_parent().has_method("place_block"):
		var _sid: String = str(selected.get("id", ""))
		var place_id: String = _sid + ("|h" if _place_flip else "")
		var placed: bool = get_parent().place_block(tile_pos, place_id)
		if placed:
			# Creative mode: don't consume items.
			if not GameData.creative_mode:
				remove_item(selected_slot, 1)
			AudioManager.play_place()
			var qs := get_node_or_null("/root/QuestSystem")
			if qs != null:
				qs.on_block_placed(_sid)


## Eat the selected food item: restore hunger, consume one item.
func _eat_selected(item_data: Dictionary = {}) -> void:
	if item_data.is_empty():
		var selected: Dictionary = get_selected_item()
		item_data = ItemDB.get_item(selected.get("id", ""))
	if not item_data.get("edible", false):
		return
	var restore: float = float(item_data.get("food_value", 0))
	hunger = minf(hunger + restore, max_hunger)
	hunger_changed.emit(hunger, max_hunger)
	remove_item(selected_slot, 1)
	AudioManager.play_eat()

# ===========================================================================
# Interact (E key / gamepad Y)
# ===========================================================================

## Called when the player presses the interact button.
## HOW TO ADD NEW INTERACTIONS:
##   Add an elif block below that checks for your new node type.
##   Use an Area2D (InteractArea child) to detect nearby interactables,
##   or a RayCast2D pointing forward.
func _handle_interact() -> void:
	var world: Node = get_parent()
	if world and world.has_method("get_tile_at_world_pos"):
		# Scan a 3×3 area around the player for interactable tiles.
		# Also check the aimed tile first so direct tap/mouse targeting works.
		var player_tile := _world_to_tile(global_position)
		var candidates: Array[Vector2i] = []
		if _aimed_tile != Vector2i(-9999, -9999):
			candidates.append(_aimed_tile)
		for dy in range(-1, 3):   # slightly biased downward (chests are usually on floor)
			for dx in range(-2, 3):
				var c := Vector2i(player_tile.x + dx, player_tile.y + dy)
				if not candidates.has(c):
					candidates.append(c)

		for tile_pos: Vector2i in candidates:
			var world_px := Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
			var raw_id: String = world.get_tile_at_world_pos(world_px)
			var tile_id: String = raw_id.split("|")[0] if "|" in raw_id else raw_id

			if tile_id == "chest":
				var key := "%d,%d" % [tile_pos.x, tile_pos.y]
				if not GameData.chest_inventories.has(key):
					GameData.chest_inventories[key] = []
					for _s in range(54): GameData.chest_inventories[key].append({})
				if world.has_method("open_chest"):
					world.open_chest(key, self)
				return

			if tile_id == "furnace":
				if world.has_method("open_furnace_ui"):
					world.open_furnace_ui()
				return

			if tile_id == "bed":
				GameData.spawn_point = global_position
				if world.has_method("show_message"):
					world.show_message("Spawn point set!")
				return

			if tile_id == "crystal_gate":
				if world.has_method("open_gate_menu"):
					world.open_gate_menu(world_px, self)
				return

	# Default: open inventory (close path already handled at the top of this function).
	inventory_open = true
	inventory_toggled.emit(true)

# ===========================================================================
# Hotbar / inventory input
# ===========================================================================

## Handles scroll wheel, number keys 1–9, and gamepad bumpers for slot selection.
func _handle_hotbar_input() -> void:
	if inventory_open:
		return  # inventory panel owns all input while open; avoid double-firing
	var prev_slot := selected_slot

	# R key (or touch FLIP button via InputManager) toggles horizontal flip for placement.
	if Input.is_action_just_pressed("flip_block") or InputManager.touch_flip:
		_place_flip = not _place_flip
		InputManager.touch_flip = false   # consume the touch pulse

	# Number row keys 1–9 map directly to slots 0–8.
	for i in range(HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_" + str(i + 1)):
			selected_slot = i
			if selected_slot != prev_slot:
				_place_flip = false   # reset flip on slot switch
				selected_slot_changed.emit(selected_slot)
				_update_hand_item()
			return

	# Scroll wheel / gamepad bumpers cycle through slots.
	if Input.is_action_just_pressed("hotbar_next"):
		selected_slot = (selected_slot + 1) % HOTBAR_SIZE
		_place_flip = false
	elif Input.is_action_just_pressed("hotbar_prev"):
		selected_slot = (selected_slot - 1 + HOTBAR_SIZE) % HOTBAR_SIZE
		_place_flip = false

	if selected_slot != prev_slot:
		selected_slot_changed.emit(selected_slot)
		_update_hand_item()

# ===========================================================================
# Inventory API – used by loot, crafting, and SaveLoad
# ===========================================================================

## Tries to add count of item_id to the hotbar/inventory.
## Stacks with existing slots first, then fills empty slots.
## Returns true if all items were added, false if inventory is full.
func add_item(item_id: String, count: int) -> bool:
	var remaining: int = count

	# Pass 1: stack onto existing matching slots (hotbar, then inventory).
	remaining = _stack_into_array(hotbar, item_id, remaining, true)
	if remaining > 0:
		remaining = _stack_into_array(inventory, item_id, remaining, false)

	# Pass 2: fill empty slots.
	if remaining > 0:
		remaining = _fill_empty_in_array(hotbar, item_id, remaining, true)
	if remaining > 0:
		remaining = _fill_empty_in_array(inventory, item_id, remaining, false)

	inventory_changed.emit()
	return remaining == 0

## Internal: attempts to stack item_id onto existing slots in arr.
## is_hotbar controls which signal is emitted.
func _stack_into_array(arr: Array, item_id: String, remaining: int, is_hotbar: bool) -> int:
	var max_stack: int = ItemDB.get_item(item_id).get("max_stack", 99)
	if max_stack <= 0:
		return remaining  # non-stackable (e.g. unique items with max_stack 0)
	for i in range(arr.size()):
		if arr[i].get("id", "") == item_id:
			var space: int = max_stack - arr[i].get("count", 0)
			var add: int = min(remaining, space)
			arr[i]["count"] += add
			remaining -= add
			if is_hotbar:
				hotbar_changed.emit(i, arr[i])
			if remaining == 0:
				break
	return remaining

## Internal: fills the first empty slot in arr with item_id.
func _fill_empty_in_array(arr: Array, item_id: String, remaining: int, is_hotbar: bool) -> int:
	var max_stack: int = ItemDB.get_item(item_id).get("max_stack", 99)
	if max_stack <= 0:
		max_stack = 1  # fallback: at least allow 1 in an empty slot
	for i in range(arr.size()):
		if arr[i].is_empty():
			var add: int = min(remaining, max_stack)
			arr[i] = {"id": item_id, "count": add, "durability": -1}
			remaining -= add
			if is_hotbar:
				hotbar_changed.emit(i, arr[i])
			if remaining == 0:
				break
	return remaining

## Remove count items from a specific hotbar slot (by index).
## Pass a slot index into hotbar (0–8).  For inventory slots use remove_inventory_item().
func remove_item(slot: int, count: int) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
	if hotbar[slot].is_empty():
		return
	hotbar[slot]["count"] -= count
	if hotbar[slot]["count"] <= 0:
		hotbar[slot] = {}
	hotbar_changed.emit(slot, hotbar[slot])
	inventory_changed.emit()

## Remove count items from a full-inventory slot index (0–35).
func remove_inventory_item(slot: int, count: int) -> void:
	if slot < 0 or slot >= INVENTORY_SIZE:
		return
	if inventory[slot].is_empty():
		return
	inventory[slot]["count"] -= count
	if inventory[slot]["count"] <= 0:
		inventory[slot] = {}
	inventory_changed.emit()

## Returns a copy of the currently selected hotbar slot dictionary.
## Returns {} if slot is empty.
func get_selected_item() -> Dictionary:
	return hotbar[selected_slot].duplicate()

## Reduces the durability of the selected item by amount.
## Destroys the item when durability reaches 0 (if it has a durability track).
func _damage_selected_item(amount: int) -> void:
	var slot: Dictionary = hotbar[selected_slot]
	if slot.is_empty():
		return
	if slot.get("durability", -1) < 0:
		return  # -1 means unbreakable / no durability

	slot["durability"] -= amount
	if slot["durability"] <= 0:
		hotbar[selected_slot] = {}
		hotbar_changed.emit(selected_slot, {})
	else:
		hotbar_changed.emit(selected_slot, slot)

# ===========================================================================
# Animation
# ===========================================================================

## Returns the weapon "style" key for the currently held hotbar item.
## Used by _update_animation to pick the right idle/run/attack animation set.
## Add new weapon types here by checking item tags or id prefixes.
## Call each frame (or on slot change) to detect a held-item switch and apply
## its anim_skin overrides if present, or restore defaults if it has none.
func _check_weapon_skin() -> void:
	var id: String = get_selected_item().get("id", "")
	if id == _last_held_item_id:
		return
	_last_held_item_id = id
	var item_data: Dictionary = ItemDB.get_item(id)
	var skin: Dictionary = item_data.get("anim_skin", {})
	if skin.is_empty():
		if _skin_overrides_active:
			_generate_sprites()           # restore base sheets (cached, fast)
			_skin_overrides_active = false
		return
	_skin_overrides_active = true
	_apply_weapon_skin(skin)


## Applies per-animation sprite-sheet overrides for a weapon.
## Each entry in anim_skin can be:
##   String  — just a different texture path (same frame layout as the default)
##   Dict    — full spec: {"path","frame_w","frame_h","count","fps","loop","start"}
##
## Example ItemDatabase entry for a flaming sword:
##   "anim_skin": {
##     "katana_attack": "res://assets/sprites/weapons/flaming_sword/attack.png",
##     "katana_idle":   {"path": "...", "frame_w": 80, "frame_h": 64, "count": 10,
##                       "fps": 14.0, "loop": true, "start": 0}
##   }
func _apply_weapon_skin(anim_skin: Dictionary) -> void:
	_generate_sprites()   # start from a clean base (textures are cached, no disk I/O)
	var sf: SpriteFrames = sprite.sprite_frames
	if sf == null:
		return
	# Default frame params per animation — used when the override is just a path.
	var _defaults: Dictionary = {
		"katana_idle":        [48, 48, 10,  8.0, true,  0],
		"katana_run":         [48, 48,  8, 12.0, true,  0],
		"katana_attack":      [80, 64, 10, 14.0, false, 0],
		"katana_attack_cont": [80, 64,  9, 16.0, true,  0],
		"katana_air_attack":  [80, 64,  9, 14.0, false, 0],
		"katana_run_attack":  [80, 64,  8, 14.0, false, 0],
		"shoot_idle":         [48, 48, 10,  8.0, true,  0],
		"shoot_run":          [48, 48,  8, 12.0, true,  0],
		"shoot_fire":         [48, 48,  8, 14.0, false, 0],
		"sword_idle":         [48, 48, 10,  8.0, true,  0],
		"sword_run":          [48, 48,  8, 12.0, true,  0],
		"sword_attack":       [64, 64,  6, 14.0, false, 0],
	}
	for anim_name in anim_skin:
		var spec = anim_skin[anim_name]
		var path: String; var fw: int; var fh: int; var count: int
		var fps: float; var loop: bool; var start_f: int
		if spec is String:
			path = spec
			var d: Array = _defaults.get(anim_name, [64, 64, 6, 14.0, false, 0])
			fw = d[0]; fh = d[1]; count = d[2]; fps = d[3]; loop = d[4]; start_f = d[5]
		elif spec is Dictionary:
			path    = spec.get("path", "")
			fw      = spec.get("frame_w", 64);  fh    = spec.get("frame_h", 64)
			count   = spec.get("count", 6);     fps   = spec.get("fps", 14.0)
			loop    = spec.get("loop", false);  start_f = spec.get("start", 0)
		else:
			continue
		if path == "" or not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		if sf.has_animation(anim_name):
			sf.clear(anim_name)
		else:
			sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas  = tex
			atlas.region = Rect2((start_f + i) * fw, 0, fw, fh)
			sf.add_frame(anim_name, atlas)


func _get_weapon_style() -> String:
	var item: Dictionary = get_selected_item()
	var id: String = item.get("id", "")
	var data: Dictionary = ItemDB.get_item(id)
	var _tt = data.get("tool_type", "")
	var tool_type: String = _tt if _tt is String else ""
	if tool_type == "gun":
		return "shoot"
	# Katana uses its own dedicated animation set.
	if tool_type == "katana" or id == "katana":
		return "katana"
	# Regular swords use the sword animation set.
	if tool_type == "sword" or id.ends_with("_sword"):
		return "sword"
	# Bare fists / any non-weapon tool → punch style.
	if item.is_empty() or id == "" or data.get("placeable", false):
		return "punch"
	return "default"


## Chooses the correct animation based on current movement/weapon state.
## One-shot anims (hurt, die, attack, mine, roll, dash, slide) are never interrupted.
func _update_animation(move_input: float, is_running: bool) -> void:
	var current: String = sprite.animation
	# Never interrupt these until they finish.
	if current in ["hurt", "die", "roll", "dash", "slide", "ledge_climb",
			"sword_attack", "sword_stab",
			"katana_attack", "katana_attack_cont",
			"katana_air_attack", "katana_run_attack",
			"punch", "punch_cross", "punch_jab", "shoot_fire"]:
		if sprite.is_playing():
			return
	if current in ["attack", "mine"] and sprite.is_playing():
		return

	var style: String = _get_weapon_style()
	var has_anim := func(n: String) -> bool: return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(n)

	if not is_on_floor():
		# In-air katana gets a dedicated air animation.
		if style == "katana" and has_anim.call("katana_air_attack") and current == "katana_attack":
			return   # keep katana air attack running
		sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif is_crouching:
		if abs(move_input) > 0.01:
			sprite.play("crouch_walk" if has_anim.call("crouch_walk") else "walk")
		else:
			sprite.play("crouch" if has_anim.call("crouch") else "idle")
	elif abs(move_input) > 0.01:
		match style:
			"katana":
				sprite.play("katana_run" if has_anim.call("katana_run") else "run")
			"sword":
				sprite.play("sword_run" if has_anim.call("sword_run") else "run")
			"shoot":
				sprite.play("shoot_run" if has_anim.call("shoot_run") else "run")
			_:
				sprite.play("run" if is_running else "walk")
	else:
		match style:
			"katana":
				sprite.play("katana_idle" if has_anim.call("katana_idle") else "idle")
			"sword":
				sprite.play("sword_idle" if has_anim.call("sword_idle") else "idle")
			"shoot":
				sprite.play("shoot_idle" if has_anim.call("shoot_idle") else "idle")
			_:
				sprite.play("idle")

# ===========================================================================
# Utility helpers
# ===========================================================================

## Converts a world-space position to tile coordinates.
func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

## Converts tile coordinates back to the top-left corner in world space.
func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE)

## Returns true if a solid block occupies tile_pos.
## Delegates to the world node; returns false if method not found.
func _tile_exists(tile_pos: Vector2i) -> bool:
	if _world_node != null and _world_node.has_method("has_block"):
		return _world_node.has_block(tile_pos)
	return false

## Returns the tool_type of the currently equipped item ("axe", "pick", "shovel", etc.).
func _get_equipped_tool_type() -> String:
	return ItemDB.get_item(get_selected_item().get("id", "")).get("tool_type", "")

## Returns true when the block at tile_pos is a valid target for the equipped tool type.
## When tool_focus is off, or the tool isn't axe/pick/shovel, all solid blocks pass.
func _tile_matches_tool(tile_pos: Vector2i, equipped_type: String) -> bool:
	if not GameData.tool_focus or equipped_type not in ["axe", "pick", "shovel"]:
		return true
	if _world_node == null or not _world_node.has_method("get_block_data"):
		return true
	var block_data: Dictionary = _world_node.get_block_data(tile_pos)
	if block_data.is_empty():
		return false
	return ItemDB.get_item(block_data.get("id", "")).get("tool_type", "") == equipped_type

## Repositions the AttackArea in front of the player based on facing direction.
func _reposition_attack_area() -> void:
	if not is_instance_valid(attack_area):
		return
	var offset_x: float = 20.0 if _facing_right else -20.0
	attack_area.position.x = offset_x

# ===========================================================================
# Timer callbacks
# ===========================================================================

func _on_coyote_timer_timeout() -> void:
	_coyote_active = false

func _on_jump_buffer_timer_timeout() -> void:
	_jump_buffered = false

# ===========================================================================
# Public API used by SaveLoad.gd
# ===========================================================================

## Returns a plain-data dictionary suitable for JSON serialisation.
func get_save_data() -> Dictionary:
	return {
		"position":      {"x": global_position.x, "y": global_position.y},
		"health":        health,
		"hunger":        hunger,
		"hotbar":        hotbar.duplicate(true),
		"inventory":     inventory.duplicate(true),
		"selected_slot": selected_slot,
	}

## Restores player state from a previously saved dictionary.
func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = Vector2(data["position"]["x"], data["position"]["y"])
	health  = data.get("health",  max_health)
	hunger  = data.get("hunger",  max_hunger)

	var saved_hotbar: Array = data.get("hotbar", [])
	for i in range(min(saved_hotbar.size(), HOTBAR_SIZE)):
		hotbar[i] = saved_hotbar[i]

	var saved_inv: Array = data.get("inventory", [])
	for i in range(min(saved_inv.size(), INVENTORY_SIZE)):
		inventory[i] = saved_inv[i]

	selected_slot = data.get("selected_slot", 0)

	health_changed.emit(health, max_health)
	hunger_changed.emit(hunger, max_hunger)
	inventory_changed.emit()
	selected_slot_changed.emit(selected_slot)

# ===========================================================================
# Hand-item visual
# ===========================================================================

## Creates the small colored rectangle that appears in the player's hand.
## Called once from _ready(). The node is updated by _update_hand_item().
func _setup_hand_item() -> void:
	var hand := Sprite2D.new()
	hand.name            = "HandItem"
	hand.position        = Vector2(8.0, -4.0)
	hand.scale           = Vector2(0.55, 0.55)
	hand.centered        = true
	hand.visible         = false   # hidden until an item is held
	add_child(hand)
	_hand_item = hand


## Refreshes the hand-item sprite to match the currently selected hotbar slot.
## Automatically uses whatever texture is registered for the item in ItemDB /
## TileTextureGenerator — so swapping an asset image updates both the UI icon
## AND what the player holds without any extra steps.
func _update_hand_item() -> void:
	var hand: Sprite2D = _hand_item
	if hand == null:
		return

	var item: Dictionary = get_selected_item()
	if item.is_empty() or item.get("id", "") == "":
		hand.visible = false
		return

	var item_id: String = item.get("id", "")
	var data: Dictionary = ItemDB.get_item(item_id)

	# Use the same icon source as the inventory UI so asset swaps are automatic.
	var tex: Texture2D = TileTextureGenerator.get_icon(item_id, data)
	if tex == null:
		hand.visible = false
		return

	hand.texture = tex
	hand.visible = true

	# Mirror position when the player faces left.
	if sprite != null:
		hand.position.x    =  8.0 if not sprite.flip_h else -8.0
		hand.flip_h        = sprite.flip_h


# ===========================================================================
# Inventory helpers
# ===========================================================================

## Returns the hotbar array (9 slots).
func get_hotbar() -> Array:
	return hotbar.duplicate(true)

## Creative mode inventory — all placeable blocks, each at 999 count.
## Size = 2 × number of placeables (extra slots are empty, for player organisation).
## Hotbar is left untouched so the player controls it freely.
var creative_inv: Array = []

func _populate_creative_inventory() -> void:
	# Collect every usable item — tools, weapons, food, materials, blocks, ammo, armor, etc.
	# Skip air (max_stack 0) and anything with no stack size.
	var all_ids: Array[String] = []
	for id: String in ItemDB.items.keys():
		var data: Dictionary = ItemDB.items[id]
		if data.get("max_stack", 0) == 0:
			continue  # air / uncollectable sentinel
		all_ids.append(id)
	all_ids.sort()  # stable alphabetical order

	creative_inv.clear()
	for id in all_ids:
		var stack: int = ItemDB.items[id].get("max_stack", 1)
		creative_inv.append({"id": id, "count": stack, "durability": -1})
	# Pad to a multiple of 9 for clean row layout.
	while creative_inv.size() % 9 != 0:
		creative_inv.append({})

	inventory_changed.emit()

## Replaces the full inventory array (36 slots) and emits the changed signal.
func set_inventory(new_inventory: Array) -> void:
	for i in range(min(new_inventory.size(), INVENTORY_SIZE)):
		inventory[i] = new_inventory[i]
	inventory_changed.emit()

## Replaces the hotbar array (9 slots) and emits the changed signal for each slot.
func set_hotbar(new_hotbar: Array) -> void:
	for i in range(min(new_hotbar.size(), HOTBAR_SIZE)):
		hotbar[i] = new_hotbar[i]
		hotbar_changed.emit(i, hotbar[i])
	inventory_changed.emit()

## Returns a copy of the 36-slot main inventory (not hotbar).
## InventoryUI calls this to display the player's bags.
func get_inventory() -> Array:
	return inventory.duplicate(true)

## Returns hotbar + full inventory combined — used by CraftingSystem to count ingredients.
func get_all_items() -> Array:
	var combined: Array = []
	combined.append_array(hotbar)
	combined.append_array(inventory)
	return combined

# ===========================================================================
# Sprite-sheet animation loading
# Loads PNG sprite sheets from assets/sprites/player/.
# Falls back to a solid-colour placeholder if sheets are not yet imported.
# ===========================================================================

## Loads sprite-sheet animations.
## If a skin folder is active it loads sheets from there first,
## falling back to the base path when a sheet is missing.
## Shared SpriteFrames cache — built once per skin key, reused by every Player instance.
static var _frames_cache: Dictionary = {}

func _generate_sprites() -> void:
	if sprite == null:
		return

	var skin_dir: String = ""
	if skin != null and skin.skin_folder != "":
		skin_dir = skin.skin_folder.rstrip("/") + "/"

	# Return cached frames for this skin so we don't reload 30+ PNGs every spawn.
	var cache_key: String = skin_dir
	if _frames_cache.has(cache_key):
		sprite.sprite_frames = _frames_cache[cache_key]
		return

	# [anim_name, file_path_or_stem, frame_w, frame_h, frame_count, fps, loop, start_frame]
	# Stems with no "/" are looked up under BASE (and skin folder fallback).
	# Full paths starting with "res://" skip the skin fallback.
	var BASE := "res://assets/sprites/player/"
	var PACK := "res://assets/sprites/player/pack/"

	# [anim_name, file_stem_or_path, frame_w, frame_h, frame_count, fps, loop, start_frame]
	# Stems (no slash) are resolved under BASE (with optional skin-folder override).
	# PACK-prefixed entries point to the copied 2D Pixel Art Character Template sprites.
	# Frame counts verified against actual PNG pixel widths.
	var sheet_data: Array = [
		# ── Core locomotion ──────────────────────────────────────────────────
		["idle",        "idle",        48, 48, 10, 8.0,  true,  0],
		["walk",        "walk",        48, 48,  8, 10.0, true,  0],
		["run",         "run",         48, 48,  8, 12.0, true,  0],
		["jump",        "jump",        48, 48,  3, 10.0, false, 0],
		["fall",        "jump",        48, 48,  1, 4.0,  true,  2],
		["land",        "land",        48, 48,  9, 16.0, false, 0],
		["crouch",      "crouch_idle", 48, 48, 10, 8.0,  true,  0],
		["crouch_walk", "crouch_walk", 48, 48, 10, 8.0,  true,  0],
		["wall_slide",  "wall_slide",  48, 48,  3, 8.0,  true,  0],
		# ── Combat / tools ───────────────────────────────────────────────────
		["hurt",        "hurt",        48, 48,  4, 12.0, false, 0],
		["die",         "death",       48, 48, 10, 8.0,  false, 0],
		["mine",        "mine",        64, 64,  8, 14.0, true,  0],
		["attack",      "attack",      64, 64,  6, 12.0, false, 0],
		# ── Pack: movement extras ─────────────────────────────────────────────
		# Format: [anim_name, path, fw, fh, frames, fps, loop, start_frame]
		# Frame counts verified against actual PNG pixel widths.
		["air_spin",      PACK + "air_spin.png",      48, 48,  6, 10.0, false, 0],
		["climb",         PACK + "climb.png",         48, 48,  4,  8.0, true,  0],
		["dash",          PACK + "dash.png",          48, 48,  9, 16.0, false, 0],
		["roll",          PACK + "roll.png",          48, 48,  7, 14.0, false, 0],
		["slide",         PACK + "slide.png",         48, 48,  8, 14.0, false, 0],
		["ledge_climb",   PACK + "ledge_climb.png",   48, 48,  5, 10.0, false, 0],
		["pull",          PACK + "pull.png",          48, 48,  6,  8.0, true,  0],
		["push",          PACK + "push.png",          48, 48, 10,  8.0, true,  0],
		["push_idle",     PACK + "push_idle.png",     48, 48,  8,  8.0, true,  0],
		["wall_land",     PACK + "wall_land.png",     48, 48,  6, 12.0, false, 0],
		# ── Pack: punch / bare-hand attacks ───────────────────────────────────
		["punch",         PACK + "punch.png",         64, 64,  8, 14.0, false, 0],
		["punch_cross",   PACK + "punch_cross.png",   64, 64,  7, 14.0, false, 0],
		["punch_jab",     PACK + "punch_jab.png",     48, 48, 10, 14.0, false, 0],
		# ── Pack: sword ───────────────────────────────────────────────────────
		["sword_idle",    PACK + "sword_idle.png",    48, 48, 10,  8.0, true,  0],
		["sword_run",     PACK + "sword_run.png",     48, 48,  8, 12.0, true,  0],
		["sword_attack",  PACK + "sword_attack.png",  64, 64,  6, 14.0, false, 0],
		["sword_stab",    PACK + "sword_stab.png",    96, 48,  7, 14.0, false, 0],
		# ── Pack: katana ──────────────────────────────────────────────────────
		["katana_idle",        PACK + "katana_idle.png",        48, 48, 10,  8.0, true,  0],
		["katana_run",         PACK + "katana_run.png",         48, 48,  8, 12.0, true,  0],
		["katana_attack",      PACK + "katana_attack.png",      80, 64, 10, 14.0, false, 0],
		["katana_attack_cont", PACK + "katana_attack_cont.png", 80, 64,  9, 16.0, true,  0],
		["katana_air_attack",  PACK + "katana_air_attack.png",  80, 64,  9, 14.0, false, 0],
		["katana_run_attack",  PACK + "katana_run_attack.png",  80, 64,  8, 14.0, false, 0],
		# ── Pack: shooting ────────────────────────────────────────────────────
		["shoot_idle",    PACK + "shoot_idle.png",    48, 48, 10,  8.0, true,  0],
		["shoot_run",     PACK + "shoot_run.png",     48, 48,  8, 12.0, true,  0],
		["shoot_fire",    PACK + "shoot_fire.png",    48, 48,  8, 14.0, false, 0],
	]

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var loaded_any := false

	for entry in sheet_data:
		var anim:    String = entry[0]
		var stem:    String = entry[1]
		var fw:      int    = entry[2]
		var fh:      int    = entry[3]
		var count:   int    = entry[4]
		var fps:     float  = entry[5]
		var loop:    bool   = entry[6]
		var start_f: int    = entry[7]

		# Full res:// paths (template assets) load directly — no skin fallback.
		# Short stems (base player sprites) check the skin folder first.
		var path: String
		if stem.begins_with("res://"):
			path = stem
		else:
			path = BASE + stem + ".png"
			if skin_dir != "":
				var skin_path: String = skin_dir + stem + ".png"
				if ResourceLoader.exists(skin_path):
					path = skin_path

		var tex := load(path) as Texture2D
		if tex == null:
			continue

		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, loop)
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas   = tex
			atlas.region  = Rect2((start_f + i) * fw, 0, fw, fh)
			frames.add_frame(anim, atlas)
		loaded_any = true

	if not loaded_any:
		_generate_placeholder_frames(frames)

	# Store in cache so future calls skip disk I/O entirely.
	_frames_cache[cache_key] = frames
	sprite.sprite_frames = frames
	sprite.modulate = Color.WHITE
	sprite.play("idle")


## Applies the PLAYER_CLASSES entry at GameData.player_class_index.
## Scales max_health, move_speed, run_speed, hunger_drain_rate, and
## player_damage_mult; sets the sprite modulate to the class color.
## Called once in _ready() after stat exports are set.
func _apply_class_stats() -> void:
	var idx: int = clamp(GameData.player_class_index, 0, GameData.PLAYER_CLASSES.size() - 1)
	var cls: Dictionary = GameData.PLAYER_CLASSES[idx]

	# Scale base stats by class multipliers.
	max_health         *= cls.get("health_mult", 1.0)
	move_speed         *= cls.get("speed_mult", 1.0)
	run_speed          *= cls.get("speed_mult", 1.0)
	hunger_drain_rate  *= cls.get("hunger_mult", 1.0)
	# The class damage_mult stacks on top of the difficulty player_damage_mult.
	# Store the class factor in GameData so _do_melee_attack can apply it.
	GameData.class_damage_mult = cls.get("damage_mult", 1.0)

	# Re-init health/hunger to the newly scaled max.
	health = max_health
	hunger = max_hunger

	# Store the class color so _apply_skin_to_sprite() can apply it after
	# _generate_sprites() resets modulate to WHITE.
	# The shader path ignores modulate, so this only shows on the no-skin path.
	set_meta("_class_color", cls.get("color", Color.WHITE))


## Reloads the sprite using the current `skin` folder (or base path if null).
func _apply_skin_to_sprite() -> void:
	_generate_sprites()
	# Rebuild equipment layers since SpriteFrames changed.
	_setup_equipment_layers()

	# Always use the solid_color shader — it replaces every non-transparent pixel
	# with one flat color, so the whole body reads as the class color regardless
	# of what the original sprite art looks like.
	var class_color: Color = get_meta("_class_color", Color.WHITE)
	var col: Color = class_color
	if skin != null and skin.skin_folder != "":
		var skin_key: String = skin.skin_folder.get_file()
		col = SKIN_COLORS.get(skin_key, class_color)

	var shader_res := load("res://assets/shaders/solid_color.gdshader") as Shader
	if shader_res != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		mat.set_shader_parameter("solid_color", col)
		sprite.material = mat
		sprite.modulate = Color.WHITE
	else:
		sprite.material = null
		sprite.modulate = col


## Public API — swap skin at runtime (called from skin picker or GameData).
func apply_skin(new_skin: PlayerSkin) -> void:
	skin = new_skin
	GameData.selected_skin = new_skin
	_apply_skin_to_sprite()


func _generate_placeholder_frames(frames: SpriteFrames) -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.2))
	var tex := ImageTexture.create_from_image(img)
	for a in ["idle","walk","run","jump","fall","land","crouch","crouch_walk",
			  "hurt","die","mine","attack","wall_slide"]:
		frames.add_animation(a)
		frames.set_animation_speed(a, 8.0)
		frames.set_animation_loop(a, true)
		frames.add_frame(a, tex)


## Damage from environment (starvation, drowning) — no hurt animation, no i-frames.
func _take_environmental_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	health = max(health, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


## Equip an item into its slot. Pass "" to unequip.
func equip(slot: String, item_id: String) -> void:
	if not equipment.has(slot):
		return
	equipment[slot] = item_id
	var overlay: AnimatedSprite2D = _eq_layers.get(slot)
	if overlay == null:
		return
	if item_id == "":
		overlay.visible = false
		return
	var _tier_raw = ItemDB.get_item(item_id).get("tier", "wood")
	var tier: String = _tier_raw if _tier_raw is String else "wood"
	var tint: Color = _TIER_TINT.get(tier, Color.WHITE)
	(overlay.material as ShaderMaterial).set_shader_parameter("tint", tint)
	overlay.visible = true
	overlay.play(sprite.animation)


## Unequip the item in a slot, returning its item_id (or "" if nothing was there).
func unequip(slot: String) -> String:
	var old: String = equipment.get(slot, "")
	equip(slot, "")
	return old


## Sum a named bonus (e.g. "armor", "max_health", "speed") across all equipped items.
func get_equipment_bonus(stat: String) -> float:
	var total := 0.0
	for item_id: String in equipment.values():
		if item_id != "":
			total += float(ItemDB.get_item(item_id).get("bonus_" + stat, 0.0))
	return total


## Creates layered AnimatedSprite2D overlays for each equipment slot.
func _setup_equipment_layers() -> void:
	var shader := load("res://shaders/body_part_overlay.gdshader") as Shader
	if shader == null:
		push_warning("PlayerEquipment: body_part_overlay.gdshader not found — overlays disabled.")
		return
	for slot: String in ["head", "chest", "arms", "legs"]:
		var overlay := AnimatedSprite2D.new()
		overlay.sprite_frames = sprite.sprite_frames
		overlay.z_index = 1
		overlay.visible = false
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("region", _SLOT_UV[slot])
		overlay.material = mat
		add_child(overlay)
		_eq_layers[slot] = overlay
