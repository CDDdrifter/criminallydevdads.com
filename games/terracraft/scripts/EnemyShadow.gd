## EnemyShadow.gd
## Dark Souls-style shadow entity — a dark mirror of the player.
## Immune to projectiles/explosions; only melee can harm it.
## Two-phase AI: Phase 1 (HP > 50%) aggressive, Phase 2 (HP ≤ 50%) berserk.

class_name EnemyShadow
extends EnemyBase

# ──────────────────────────────────────────────
#  SHADOW-SPECIFIC CONSTANTS
# ──────────────────────────────────────────────

const SHADOW_COLOR:       Color = Color(0.05, 0.05, 0.08, 1.0)   # near-black, slight blue tint
const SHADOW_FLASH_COLOR: Color = Color(0.40, 0.00, 0.60, 1.0)   # purple flash on hit
const PARRY_WINDOW:       float = 0.18   # seconds at attack start where Shadow can reflect melee
const PARRY_REFLECT_MULT: float = 1.2    # damage multiplier when reflected back at player
const COUNTER_DIST:       float = 52.0   # px — how close player must be to trigger a counter
const DODGE_IMPULSE:      float = 320.0  # px/s horizontal dodge velocity
const DASH_IMPULSE:       float = 500.0  # px/s dash-attack velocity
const PHASE2_THRESHOLD:   float = 0.50   # fraction of max_health below which phase 2 triggers
const KATANA_SPAM_CHANCE: float = 0.40   # phase 2: probability of katana_attack_cont per attack cycle

# ──────────────────────────────────────────────
#  ATTACK TYPES
# ──────────────────────────────────────────────

enum AttackType {
	NONE,
	PUNCH_COMBO,    # punch → punch_jab → punch_cross
	SWORD_SLASH,    # sword_attack
	KATANA_ASSAULT, # katana_attack
	KATANA_CONT,    # katana_attack_cont (phase 2 spam)
	DASH_ATTACK,    # dash toward player then strike
	DODGE_ROLL,     # roll away from incoming attack
	COUNTER,        # triggered when player attacks nearby
}

# ──────────────────────────────────────────────
#  SHADOW STATE
# ──────────────────────────────────────────────

var _in_phase2:              bool        = false
var _current_attack:         AttackType  = AttackType.NONE
var _attack_step:            int         = 0     # which step of a combo we're on
var _attack_anim_timer:      float       = 0.0   # how long current attack anim has been running
var _parry_active:           bool        = false  # true during parry window
var _parry_timer:            float       = 0.0
var _dodge_timer:            float       = 0.0
var _dodge_direction:        float       = 0.0
var _counter_cooldown:       float       = 0.0   # prevent counter spam
var _approach_style:         int         = 0     # 0=walk, 1=dash, 2=roll-approach; changes every cycle
var _approach_timer:         float       = 0.0
var _katana_cont_count:      int         = 0     # how many katana_cont hits done this spam
var _phase2_entered:         bool        = false # one-shot flag for phase2 transition
var _base_damage:            float       = 0.0   # stored on ready before phase mods
var _base_cooldown:          float       = 0.0

# Shadow duplicates all animations so we can play player pack anims
# without touching the base idle/walk/attack/hurt/die that EnemyBase expects.
# The _sprite reference comes from EnemyBase via @onready var _sprite.

# ──────────────────────────────────────────────
#  LIFECYCLE
# ──────────────────────────────────────────────

func _ready() -> void:
	# Set exported stats before calling super so _apply_tier_modifiers sees them.
	max_health      = 180.0
	move_speed      = 110.0
	attack_damage   = 22.0
	attack_range    = 38.0
	detection_range = 360.0
	attack_cooldown = 0.4
	knockback_resistance = 0.25
	enemy_tier      = 0   # tier modifiers skipped — Shadow uses its own stat system

	drop_table = [
		{"item_id": "shadow_essence", "min_count": 1, "max_count": 2, "chance": 1.0},
	]

	super._ready()   # calls _apply_tier_modifiers(), sets current_health, _generate_sprites()

	# Store base stats (super may have scaled them, but enemy_tier=0 means no change).
	_base_damage   = attack_damage
	_base_cooldown = attack_cooldown

	# Force the correct dark tint — override whatever _apply_tier_modifiers set.
	if _sprite != null:
		_sprite.modulate = SHADOW_COLOR

	# Ensure extra shadow animations exist in sprite_frames (added by _generate_sprites override).
	# _generate_sprites is called inside super._ready().


## EnemyBase._generate_sprites() dispatches on name; we override it to build shadow frames.
func _generate_sprites() -> void:
	if _sprite == null:
		return
	_build_shadow_sprite_frames()


func _build_shadow_sprite_frames() -> void:
	var sf: SpriteFrames = _sprite.sprite_frames
	if sf == null:
		# Create a new SpriteFrames resource at runtime.
		sf = SpriteFrames.new()
		_sprite.sprite_frames = sf

	# ── Generate a generic humanoid shadow texture for each pose ──────────────
	# Base colour: near-black with very slight purple tint.
	var skin   := Color(0.05, 0.04, 0.09)
	var dark   := Color(0.03, 0.02, 0.06)
	var mid    := Color(0.07, 0.05, 0.12)
	var hurt_c := Color(0.35, 0.00, 0.50)

	var t_idle  := _shadow_humanoid(skin, dark, mid, mid, dark, 0)
	var t_walk1 := _shadow_humanoid(skin, dark, mid, mid, dark, 1)
	var t_walk2 := _shadow_humanoid(skin, dark, mid, mid, dark, 2)
	var t_atk   := _shadow_humanoid(skin, dark, mid, mid, dark, 3)
	var t_hurt  := _shadow_humanoid(hurt_c, dark, mid, mid, dark, 0)
	var t_die   := _shadow_humanoid(hurt_c, dark, Color(0.10, 0.05, 0.20), mid, dark, 4)
	var t_dash  := _shadow_humanoid(skin, dark, mid, mid, dark, 3)  # reuse attack pose for dash
	var t_roll  := _shadow_humanoid(skin, dark, mid, mid, dark, 4)  # crouched for roll

	_ensure_anim(sf, "idle",               true,  5.0)
	_ensure_anim(sf, "walk",               true,  7.0)
	_ensure_anim(sf, "run",                true,  10.0)
	_ensure_anim(sf, "attack",             false, 10.0)
	_ensure_anim(sf, "hurt",               false, 6.0)
	_ensure_anim(sf, "die",                false, 4.0)
	_ensure_anim(sf, "punch",              false, 12.0)
	_ensure_anim(sf, "punch_jab",          false, 12.0)
	_ensure_anim(sf, "punch_cross",        false, 12.0)
	_ensure_anim(sf, "sword_attack",       false, 10.0)
	_ensure_anim(sf, "katana_attack",      false, 12.0)
	_ensure_anim(sf, "katana_attack_cont", false, 14.0)
	_ensure_anim(sf, "katana_air_attack",  false, 12.0)
	_ensure_anim(sf, "dash",               false, 10.0)
	_ensure_anim(sf, "roll",               false, 8.0)

	# Populate frames.
	_set_anim_frames(sf, "idle",               [t_idle])
	_set_anim_frames(sf, "walk",               [t_idle, t_walk1, t_idle, t_walk2])
	_set_anim_frames(sf, "run",                [t_walk1, t_walk2, t_walk1, t_walk2])
	_set_anim_frames(sf, "attack",             [t_atk, t_idle, t_atk])
	_set_anim_frames(sf, "hurt",               [t_hurt])
	_set_anim_frames(sf, "die",                [t_hurt, t_die])
	_set_anim_frames(sf, "punch",              [t_atk, t_idle])
	_set_anim_frames(sf, "punch_jab",          [t_idle, t_atk])
	_set_anim_frames(sf, "punch_cross",        [t_atk, t_atk, t_idle])
	_set_anim_frames(sf, "sword_attack",       [t_atk, t_idle, t_atk, t_idle])
	_set_anim_frames(sf, "katana_attack",      [t_atk, t_idle, t_atk])
	_set_anim_frames(sf, "katana_attack_cont", [t_atk, t_idle, t_atk, t_idle, t_atk])
	_set_anim_frames(sf, "katana_air_attack",  [t_dash, t_atk, t_idle])
	_set_anim_frames(sf, "dash",               [t_dash, t_dash])
	_set_anim_frames(sf, "roll",               [t_roll, t_roll])

	_sprite.sprite_frames = sf
	_sprite.play("idle")


func _ensure_anim(sf: SpriteFrames, anim: StringName, loop: bool, speed: float) -> void:
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, speed)


## 10×20 shadow humanoid texture — reuses _img_rect from EnemyBase via inheritance.
func _shadow_humanoid(sk: Color, hr: Color, sh: Color, pn: Color, sv: Color, pose: int) -> ImageTexture:
	return _humanoid_tex(sk, hr, sh, pn, sv, pose)


# ──────────────────────────────────────────────
#  PHYSICS PROCESS — override to add Shadow AI
# ──────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	# Phase check — always runs regardless of AI state.
	_check_phase_transition()

	# Always face the player even when idle/patrolling.
	_face_player()

	# Decrement counter cooldown.
	if _counter_cooldown > 0.0:
		_counter_cooldown -= delta

	# Parry window countdown.
	if _parry_active:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			_parry_active = false

	# Mid-attack handling runs inside the active AI path, but we need the
	# dodge motion to apply its impulse every frame — so handle it before super.
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity.x = _dodge_direction * DODGE_IMPULSE

	# Delegate the bulk of physics to EnemyBase.
	super._physics_process(delta)


# ──────────────────────────────────────────────
#  PHASE SYSTEM
# ──────────────────────────────────────────────

func _check_phase_transition() -> void:
	if _phase2_entered:
		return
	if current_health <= max_health * PHASE2_THRESHOLD and current_health > 0.0:
		_phase2_entered = true
		_in_phase2      = true
		_enter_phase2()


func _enter_phase2() -> void:
	attack_damage   = _base_damage * 1.5
	attack_cooldown = 0.3
	move_speed      = 140.0

	# Brief visual flash — deep purple flicker.
	if _sprite != null:
		_sprite.modulate = Color(0.50, 0.00, 0.80, 1.0)
		var t := get_tree().create_timer(0.25)
		t.timeout.connect(func() -> void:
			if is_instance_valid(_sprite):
				_sprite.modulate = SHADOW_COLOR
		)


# ──────────────────────────────────────────────
#  FACING
# ──────────────────────────────────────────────

func _face_player() -> void:
	var player: Node2D = get_player() as Node2D
	if player == null or _sprite == null:
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		_sprite.flip_h = dx < 0.0
		_facing = -1 if dx < 0.0 else 1


# ──────────────────────────────────────────────
#  PROJECTILE IMMUNITY
# ──────────────────────────────────────────────

## Overrides EnemyBase.take_damage().
## Checks if the hit came from a Projectile (Area2D) by scanning nearby Projectile nodes.
## If a Projectile is found within 30 px, the hit is discarded (immunity).
## Parry window: if _parry_active, reflect damage back at the player instead of absorbing it.
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD:
		return

	# ── Projectile / explosion immunity ──────────────────────────────────────
	# Projectile.gd calls take_damage then immediately queue_free(), so the node
	# still exists at the moment this function runs.  We scan for live Projectile
	# nodes within a generous proximity (40 px) to detect a projectile hit.
	if _is_projectile_source():
		# Absorbed — no effect.  Play a subtle visual cue.
		_flash_absorb()
		return

	# ── Parry window — reflect back at player ────────────────────────────────
	if _parry_active:
		var player: Node = get_player()
		if player != null and player.has_method("take_damage"):
			player.take_damage(amount * PARRY_REFLECT_MULT)
		_parry_active = false
		_flash_parry()
		# Shadow takes no damage during a successful parry.
		return

	# ── Counter-attack trigger ────────────────────────────────────────────────
	# If the player hits us while we are idle/chasing and counter is off cooldown,
	# immediately queue a counter-attack on the next frame.
	if _counter_cooldown <= 0.0 and current_state != State.ATTACK and current_state != State.DEAD:
		var player: Node2D = get_player() as Node2D
		if player != null and global_position.distance_to(player.global_position) <= COUNTER_DIST:
			_counter_cooldown = 3.0
			_queue_counter_attack()

	# ── Normal damage ─────────────────────────────────────────────────────────
	super.take_damage(amount, knockback)

	# Restore shadow colour after EnemyBase white-flash.
	var t := get_tree().create_timer(0.14)
	t.timeout.connect(func() -> void:
		if is_instance_valid(_sprite) and current_state != State.DEAD:
			_sprite.modulate = SHADOW_COLOR
	)


## Returns true if a Projectile node is alive and within 40 px of this enemy.
## Relies on Projectile extending Area2D (class_name Projectile is declared in Projectile.gd).
func _is_projectile_source() -> bool:
	# Scan all Area2D nodes in the scene that have the Projectile script.
	# get_tree().get_nodes_in_group() would be fastest but Projectile uses no group.
	# Fallback: iterate immediate children of the root World node.
	var root: Node = get_tree().get_root()
	if root == null:
		return false
	for child in root.get_children():
		# World node typically holds the gameplay scene.
		if _scan_node_for_projectile(child):
			return true
	return false


func _scan_node_for_projectile(node: Node) -> bool:
	for child in node.get_children():
		if child is Area2D and child.get_script() != null:
			# Check class name via script — "Projectile" class_name is declared in Projectile.gd.
			if child.get_class() == "Projectile" or (child.get_script() != null and
					"Projectile" in child.get_script().resource_path):
				var proj := child as Node2D
				if global_position.distance_to(proj.global_position) <= 40.0:
					return true
	return false


func _flash_absorb() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(0.0, 0.0, 0.5, 1.0)
	var t := get_tree().create_timer(0.10)
	t.timeout.connect(func() -> void:
		if is_instance_valid(_sprite) and current_state != State.DEAD:
			_sprite.modulate = SHADOW_COLOR
	)


func _flash_parry() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(0.80, 0.00, 1.00, 1.0)
	var t := get_tree().create_timer(0.20)
	t.timeout.connect(func() -> void:
		if is_instance_valid(_sprite) and current_state != State.DEAD:
			_sprite.modulate = SHADOW_COLOR
	)


# ──────────────────────────────────────────────
#  ATTACK OVERRIDE — Dark Souls combat
# ──────────────────────────────────────────────

## Called by EnemyBase._process_attack() when cooldown expires.
func _on_attack() -> void:
	var player: Node = get_player()
	if player == null:
		return

	var dist: float = global_position.distance_to((player as Node2D).global_position)

	# Choose an attack based on distance, phase, and randomness.
	var chosen: AttackType = _choose_attack(dist)
	_execute_attack(chosen, player)


func _choose_attack(dist: float) -> AttackType:
	# Phase 2: occasionally spam katana_attack_cont.
	if _in_phase2 and randf() < KATANA_SPAM_CHANCE:
		return AttackType.KATANA_CONT

	# Close range: punch combo or counter opportunity.
	if dist <= attack_range * 0.8:
		var r: float = randf()
		if r < 0.40:
			return AttackType.PUNCH_COMBO
		elif r < 0.65:
			return AttackType.SWORD_SLASH
		else:
			return AttackType.KATANA_ASSAULT

	# Medium range: dash in with an attack.
	if dist <= attack_range * 2.5:
		var r: float = randf()
		if r < 0.50:
			return AttackType.DASH_ATTACK
		elif r < 0.80:
			return AttackType.KATANA_ASSAULT
		else:
			return AttackType.SWORD_SLASH

	# Out of range during attack state — dash in.
	return AttackType.DASH_ATTACK


func _execute_attack(atype: AttackType, player: Node) -> void:
	var dmg: float = attack_damage
	var p2d := player as Node2D

	# Activate parry window at the START of any attack.
	_parry_active = true
	_parry_timer  = PARRY_WINDOW

	match atype:
		AttackType.PUNCH_COMBO:
			_play_animation("punch")
			await get_tree().create_timer(0.12).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			_play_animation("punch_jab")
			await get_tree().create_timer(0.12).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			_play_animation("punch_cross")
			await get_tree().create_timer(0.12).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			_deal_melee_damage(player, dmg * 0.8)
			_deal_melee_damage(player, dmg * 0.9)
			_deal_melee_damage(player, dmg)

		AttackType.SWORD_SLASH:
			_play_animation("sword_attack")
			await get_tree().create_timer(0.20).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			_deal_melee_damage(player, dmg * 1.2)

		AttackType.KATANA_ASSAULT:
			_play_animation("katana_attack")
			await get_tree().create_timer(0.15).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			_deal_melee_damage(player, dmg)

		AttackType.KATANA_CONT:
			_katana_cont_count = 0
			var hits: int = 3 if _in_phase2 else 2
			for _i in range(hits):
				if not is_instance_valid(self) or current_state == State.DEAD: return
				_play_animation("katana_attack_cont")
				await get_tree().create_timer(0.10).timeout
				if not is_instance_valid(self) or current_state == State.DEAD: return
				_deal_melee_damage(player, dmg * 0.85)
				_katana_cont_count += 1

		AttackType.DASH_ATTACK:
			_play_animation("dash")
			# Dash toward the player.
			var dir: float = sign((p2d.global_position - global_position).x)
			velocity.x = dir * DASH_IMPULSE
			await get_tree().create_timer(0.18).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			velocity.x = 0.0
			_play_animation("katana_attack")
			await get_tree().create_timer(0.10).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			_deal_melee_damage(player, dmg * 1.15)

		AttackType.COUNTER:
			# Instantaneous counter — very brief wind-up, high damage.
			_play_animation("punch_cross")
			await get_tree().create_timer(0.08).timeout
			if not is_instance_valid(self) or current_state == State.DEAD: return
			_deal_melee_damage(player, dmg * 1.5)


func _queue_counter_attack() -> void:
	var player: Node = get_player()
	if player == null or current_state == State.DEAD:
		return
	# Small delay so the counter feels responsive but not instant.
	await get_tree().create_timer(0.05).timeout
	if not is_instance_valid(self) or current_state == State.DEAD: return
	_execute_attack(AttackType.COUNTER, player)


func _deal_melee_damage(player: Node, amount: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var dist: float = global_position.distance_to((player as Node2D).global_position)
	if dist <= attack_range * 1.3 and player.has_method("take_damage"):
		player.take_damage(amount)


# ──────────────────────────────────────────────
#  CHASE OVERRIDE — unpredictable movement mix
# ──────────────────────────────────────────────

func _process_chase(delta: float) -> void:
	var player: Node2D = get_player() as Node2D
	if player == null:
		_enter_state(State.IDLE)
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float        = to_player.length()

	if dist > detection_range * 1.5:
		_enter_state(State.PATROL)
		return

	if dist <= attack_range:
		_enter_state(State.ATTACK)
		return

	# Rotate between three approach styles for unpredictability.
	_approach_timer -= delta
	if _approach_timer <= 0.0:
		_approach_style  = randi() % 3
		_approach_timer  = randf_range(0.5, 1.2)

	match _approach_style:
		0:  # Walk
			_play_animation("walk")
			velocity.x = sign(to_player.x) * move_speed

		1:  # Short dash burst
			_play_animation("dash")
			velocity.x = sign(to_player.x) * (move_speed * 1.8)

		2:  # Roll approach — roll closer then pause
			_play_animation("roll")
			velocity.x = sign(to_player.x) * (move_speed * 1.4)


# ──────────────────────────────────────────────
#  DODGE ROLL — triggered probabilistically
# ──────────────────────────────────────────────

## Called when the shadow decides to dodge instead of chase (random chance in _process_hurt).
func _do_dodge_roll(away_from_dir: float) -> void:
	if current_state == State.DEAD:
		return
	_dodge_direction = -away_from_dir
	_dodge_timer     = 0.28
	_play_animation("roll")


## Override hurt handling — sometimes roll away instead of just staggering.
func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	_play_animation("hurt")
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)

	# 40% chance to dodge-roll away on hurt recovery.
	if _hurt_timer <= 0.0:
		var player: Node2D = get_player() as Node2D
		if player != null and randf() < 0.40:
			var dir: float = sign(player.global_position.x - global_position.x)
			_do_dodge_roll(dir)
			# Transition to CHASE immediately so the state machine stops calling _process_hurt.
			# _do_dodge_roll sets velocity and the dodge timer handles motion for 0.28 s.
			_enter_state(State.CHASE)
		else:
			_enter_state(State.CHASE)


# ──────────────────────────────────────────────
#  SPRITE DIRECTION — always face player (overrides velocity-based flip)
# ──────────────────────────────────────────────

func _update_sprite_direction() -> void:
	# Shadow always faces the player — handled by _face_player() called each frame.
	# Only fall back to velocity-based flip if no player is visible.
	var player: Node2D = get_player() as Node2D
	if player != null:
		return  # _face_player() already handled it
	super._update_sprite_direction()
