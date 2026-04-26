# EnemyBase.gd
# Base class for all enemies in TerraCraft.
# Extend this class (via `class_name MyEnemy extends EnemyBase`) to create new enemy types.
#
# ============================================================
# HOW TO ADD A NEW ENEMY TYPE
# ============================================================
# 1. Create a new scene, e.g. res://scenes/enemies/Zombie.tscn
# 2. Set the root node's script to a NEW .gd file that starts with:
#      class_name Zombie extends EnemyBase
# 3. In the Zombie scene, add an AnimatedSprite2D child.  Name it exactly
#    "AnimatedSprite2D". Add animations: "idle", "walk", "attack", "hurt", "die".
# 4. Add a CollisionShape2D child with the enemy's hitbox.
# 5. In the Zombie script, override any virtual methods you need, e.g.:
#      func _on_attack() -> void:
#          # custom attack logic (projectile, melee swing, etc.)
# 6. In the Godot Inspector, tweak the exported properties (max_health, move_speed …)
#    to suit this enemy. Those values are what designers will edit.
# 7. Populate drop_table in the Inspector or in _ready():
#      drop_table = [
#          {"item_id": "zombie_flesh", "min_count": 1, "max_count": 3, "chance": 0.8},
#          {"item_id": "iron_ingot",   "min_count": 1, "max_count": 1, "chance": 0.05},
#      ]
# 8. If the enemy flies, check is_flying = true. Gravity will be skipped automatically.
# 9. Add a "DroppedItem" scene to res://scenes/DroppedItem.tscn if not present
#    (see _drop_loot() for what properties it expects).
# 10. Register the enemy scene in World.gd's spawn table (see World.gd for details).
# ============================================================

class_name EnemyBase
extends CharacterBody2D

# ------------------------------------------------------------------
# STATE MACHINE
# ------------------------------------------------------------------
enum State {
	IDLE,    # Standing still; transitions to PATROL occasionally
	PATROL,  # Walking left/right within patrol_distance
	CHASE,   # Player spotted; move toward them
	ATTACK,  # Close enough to hit player
	HURT,    # Brief stun after receiving damage
	DEAD     # Playing death anim; will despawn after a short delay
}

# ------------------------------------------------------------------
# EXPORTED PROPERTIES — edit per-enemy in the Inspector
# ------------------------------------------------------------------
@export_group("Stats")
@export var max_health: float = 20.0
@export var move_speed: float = 80.0
@export var attack_damage: float = 8.0
## Pixel radius within which this enemy deals melee damage.
@export var attack_range: float = 28.0
## Pixel radius within which this enemy notices the player.
@export var detection_range: float = 250.0
## Seconds between successive attacks.
@export var attack_cooldown: float = 1.5
## 0 = full knockback applied; 1 = no knockback applied at all.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

@export_group("Movement")
## If true the enemy ignores gravity (e.g. bats, ghosts).
@export var is_flying: bool = false
## How many pixels left/right the enemy wanders from its spawn X.
@export var patrol_distance: float = 80.0

@export_group("Tier")
## Enemy tier controls visual color and stat multipliers:
##   0 = BASIC  — light grey tint, standard stats  (common enemy)
##   1 = ELITE  — silver-grey tint, 2.5× stats      (rare tough enemy)
##   2 = BOSS   — black tint,       8× stats, regen  (world boss)
## Set this in the Inspector for each enemy scene.
## Kill counts per tier are tracked in GameData.record_kill().
@export_range(0, 2) var enemy_tier: int = 0

@export_group("Drops")
## Each entry: { "item_id": String, "min_count": int, "max_count": int, "chance": float 0-1 }
@export var drop_table: Array = []

# ------------------------------------------------------------------
# INTERNAL STATE
# ------------------------------------------------------------------
var current_state: State = State.IDLE
var current_health: float = 0.0  # set to max_health in _ready()

## Cached player reference — retrieved once via get_player().
var _player: Node = null

## Direction the enemy is facing: +1 = right, -1 = left.
var _facing: int = 1

## Patrol origin (set in _ready so the enemy patrols around its spawn point).
var _patrol_origin_x: float = 0.0
## Current patrol target X position.
var _patrol_target_x: float = 0.0

## Seconds remaining on the attack cooldown timer.
var _attack_timer: float = 0.0
## Seconds remaining in the HURT stun.
var _hurt_timer: float = 0.3
## Counts down in IDLE before switching to PATROL.
var _idle_timer: float = 0.0
## Set to true once the death sequence has been triggered (prevents repeat calls).
var _death_triggered: bool = false

const GRAVITY: float = 980.0

# ------------------------------------------------------------------
# LOD (Level-of-Detail) — skip full AI for enemies far from player
# ------------------------------------------------------------------
## Beyond this distance (px) the enemy enters dormant mode:
## gravity + deceleration still apply but the state machine is paused.
## At 60 fps, 28 active enemies each running full AI costs ~2-3 ms/frame.
## Dormant enemies cost ~0.1 ms each — a ~10× saving at range.
const AI_ACTIVE_DIST: float = 640.0   # 40 tiles

## How often (seconds) to check distance and toggle dormant state.
const LOD_CHECK_INTERVAL: float = 0.50

var _lod_timer:   float = 0.0   ## countdown until next LOD distance check
var _lod_dormant: bool  = false  ## true when beyond AI_ACTIVE_DIST

## Player-detection throttle — only check in IDLE/PATROL states, not every frame.
const DETECT_INTERVAL: float = 0.12   # ~8 checks/sec instead of 60
var _detect_cd: float = 0.0

# ------------------------------------------------------------------
# NODE REFERENCES
# ------------------------------------------------------------------
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

# ------------------------------------------------------------------
# LIFECYCLE
# ------------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemy")  # World.gd counts enemies by this group
	_apply_tier_modifiers()  # scale stats and tint sprite BEFORE setting health
	current_health = max_health
	_patrol_origin_x = global_position.x
	_patrol_target_x = global_position.x + patrol_distance
	_idle_timer = randf_range(1.5, 4.0)
	# Stagger first LOD check so all enemies don't check simultaneously.
	_lod_timer = randf_range(0.0, LOD_CHECK_INTERVAL)
	_generate_sprites()


## Scales stats and applies a colour tint based on enemy_tier.
## Called from _ready() before anything else so health is correctly set.
func _apply_tier_modifiers() -> void:
	match enemy_tier:
		0:  # BASIC — light grey tint, no stat change
			if _sprite != null:
				_sprite.modulate = Color(0.78, 0.78, 0.78)   # pale grey wash
		1:  # ELITE — silver/steel grey, 2.5× stats
			max_health     *= 2.5
			move_speed     *= 1.4
			attack_damage  *= 2.5
			detection_range *= 1.3
			knockback_resistance = clampf(knockback_resistance + 0.35, 0.0, 0.95)
			if _sprite != null:
				_sprite.modulate = Color(0.55, 0.55, 0.60)   # steel grey
			add_to_group("elite_enemy")
		2:  # BOSS — true black, 8× stats, slow, high knockback resistance
			max_health     *= 8.0
			move_speed     *= 1.15
			attack_damage  *= 6.0
			detection_range *= 2.0
			attack_cooldown *= 0.6
			knockback_resistance = 0.95
			if _sprite != null:
				_sprite.modulate = Color(0.08, 0.08, 0.08)   # near-black
			add_to_group("boss_enemy")

func _physics_process(delta: float) -> void:
	# Dead enemies do no physics processing — the death tween handles them.
	if current_state == State.DEAD:
		return

	# ── LOD distance check (every 0.5 s) ─────────────────────────────────────
	# Enemies beyond AI_ACTIVE_DIST only apply gravity — full state machine paused.
	# This cuts per-frame AI cost by ~10× for off-screen enemies.
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = LOD_CHECK_INTERVAL
		var p: Node2D = get_player() as Node2D
		if p != null:
			_lod_dormant = global_position.distance_squared_to(p.global_position) \
				> AI_ACTIVE_DIST * AI_ACTIVE_DIST
		else:
			_lod_dormant = false

	if _lod_dormant:
		# Dormant path: gravity + decelerate + slide — no AI.
		if not is_flying and not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		floor_snap_length = 8.0
		move_and_slide()
		return

	# ── Active AI path ────────────────────────────────────────────────────────
	_attack_timer = maxf(_attack_timer - delta, 0.0)

	# Apply gravity unless flying.
	if not is_flying and not is_on_floor():
		velocity.y += GRAVITY * delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)

	# Snap to floor so the enemy doesn't float on shallow slopes.
	floor_snap_length = 8.0
	move_and_slide()
	_update_sprite_direction()

# ------------------------------------------------------------------
# STATE PROCESSORS
# ------------------------------------------------------------------

func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)

	_idle_timer -= delta
	if _idle_timer <= 0.0:
		var dir: int = 1 if randi() % 2 == 0 else -1
		_patrol_target_x = _patrol_origin_x + dir * patrol_distance
		_enter_state(State.PATROL)
		return

	_play_animation("idle")

	# Throttled detection: check ~8×/sec instead of every frame.
	_detect_cd -= delta
	if _detect_cd <= 0.0:
		_detect_cd = DETECT_INTERVAL
		if _can_see_player():
			_enter_state(State.CHASE)

func _process_patrol(delta: float) -> void:
	_play_animation("walk")

	var dir: float = sign(_patrol_target_x - global_position.x)

	if absf(global_position.x - _patrol_target_x) < 4.0 or is_on_wall():
		_patrol_target_x = _patrol_origin_x + (-dir * patrol_distance)

	velocity.x = dir * move_speed

	# Throttled detection: shared timer with idle.
	_detect_cd -= delta
	if _detect_cd <= 0.0:
		_detect_cd = DETECT_INTERVAL
		if _can_see_player():
			_enter_state(State.CHASE)

func _process_chase(delta: float) -> void:
	var player: Node2D = get_player() as Node2D
	if player == null:
		_enter_state(State.IDLE)
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# Lost sight of player — go back to patrol.
	if dist > detection_range * 1.5:
		_enter_state(State.PATROL)
		return

	# Close enough to attack.
	if dist <= attack_range:
		_enter_state(State.ATTACK)
		return

	_play_animation("walk")
	velocity.x = sign(to_player.x) * move_speed

	# Flying enemies also move vertically.
	if is_flying:
		velocity.y = sign(to_player.y) * move_speed

func _process_attack(delta: float) -> void:
	# Stop moving while attacking.
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)

	var player: Node2D = get_player() as Node2D
	if player == null:
		_enter_state(State.IDLE)
		return

	var dist: float = global_position.distance_to(player.global_position)

	# Player moved out of range — chase again.
	if dist > attack_range * 1.2:
		_enter_state(State.CHASE)
		return

	if _attack_timer <= 0.0:
		_play_animation("attack")
		_attack_timer = attack_cooldown
		_on_attack()

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	_play_animation("hurt")
	# Gradually bleed off horizontal knockback velocity.
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
	if _hurt_timer <= 0.0:
		# Always chase after being hurt — the hit makes the enemy aggro regardless of range.
		_enter_state(State.CHASE)

# ------------------------------------------------------------------
# STATE TRANSITIONS
# ------------------------------------------------------------------

func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			_idle_timer = randf_range(1.5, 4.0)
		State.PATROL:
			pass  # target already set by caller
		State.HURT:
			_hurt_timer = 0.3
		State.DEAD:
			_trigger_death()

# ------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------

## Deal damage to this enemy.
## knockback is a world-space impulse vector (pixels/sec).
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount
	AudioManager.play_enemy_hurt()

	# Apply knockback once, scaled by resistance.
	velocity += knockback * (1.0 - knockback_resistance)

	# White hit-flash for combat feedback.
	_flash_hit()

	if current_health <= 0.0:
		_enter_state(State.DEAD)
	else:
		_enter_state(State.HURT)


func _flash_hit() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)   # bright white flash
	var t := get_tree().create_timer(0.12)
	t.timeout.connect(func() -> void:
		if is_instance_valid(_sprite):
			# Restore tier tint
			match enemy_tier:
				0: _sprite.modulate = Color(0.78, 0.78, 0.78)
				1: _sprite.modulate = Color(0.55, 0.55, 0.60)
				2: _sprite.modulate = Color(0.08, 0.08, 0.08)
				_: _sprite.modulate = Color.WHITE
	)

## Returns the player node (cached after first call).
## Player must belong to the group "player".
func get_player() -> Node:
	if _player == null or not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] if not players.is_empty() else null
	return _player

# ------------------------------------------------------------------
# VIRTUAL METHODS — override in subclasses
# ------------------------------------------------------------------

## Called once per attack cycle. Override for custom attack behaviour
## (e.g. ranged projectiles, AoE swings, status effects).
# ------------------------------------------------------------------
# VIRTUAL METHODS — override in subclasses
# ------------------------------------------------------------------

## Called once per attack cycle. Override for custom attack behaviour
## (e.g. ranged projectiles, AoE swings, status effects).
func _on_attack() -> void:
	var player: Node = get_player()
	if player == null:
		return
		
	# Check if player has the method before calling
	if player.has_method("take_damage"):
		# FIX: Only pass ONE argument (attack_damage) 
		# to match what your Player script expects!
		player.take_damage(attack_damage)
# ------------------------------------------------------------------
# INTERNAL HELPERS
# ------------------------------------------------------------------

## Returns true if the player is within detection_range and line-of-sight
## (simple distance check; add a raycast here for a more realistic feel).
func _can_see_player() -> bool:
	var player: Node2D = get_player() as Node2D
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

## Play an animation if it exists and isn't already playing.
func _play_animation(anim_name: String) -> void:
	if _sprite == null:
		return
	if _sprite.animation != anim_name:
		_sprite.play(anim_name)

## Flip the sprite to match the current movement direction.
func _update_sprite_direction() -> void:
	if _sprite == null:
		return
	if velocity.x > 0.01:
		_facing = 1
		_sprite.flip_h = false
	elif velocity.x < -0.01:
		_facing = -1
		_sprite.flip_h = true

## Begin the death sequence: play animation, drop loot, then free the node.
func _trigger_death() -> void:
	if _death_triggered:
		return
	_death_triggered = true

	velocity = Vector2.ZERO
	set_physics_process(false)
	_play_animation("die")

	# Record this kill in GameData so class unlocks and stats persist across worlds.
	GameData.record_kill(enemy_tier)

	# Notify QuestSystem with the appropriate group(s).
	var qs := get_node_or_null("/root/QuestSystem")
	if qs != null:
		qs.on_enemy_killed("any")
		if enemy_tier == 1:
			qs.on_enemy_killed("elite_enemy")
		elif enemy_tier == 2:
			qs.on_enemy_killed("boss_enemy")

	_drop_loot()

	# Wait for the death animation before removing from scene.
	await get_tree().create_timer(1.5).timeout
	queue_free()

## Iterate the drop_table and spawn DroppedItem nodes for each successful roll.
## DroppedItem scene must exist at res://scenes/DroppedItem.tscn and expose:
##   - item_id: String
##   - stack_count: int
func _drop_loot() -> void:
	# Pre-load the dropped item scene once.
	var dropped_item_scene: PackedScene = load("res://scenes/DroppedItem.tscn")
	if dropped_item_scene == null:
		push_warning("EnemyBase._drop_loot: res://scenes/DroppedItem.tscn not found.")
		return

	for entry in drop_table:
		# Validate entry keys to catch designer errors early.
		if not ("item_id" in entry and "min_count" in entry and "max_count" in entry and "chance" in entry):
			push_warning("EnemyBase: malformed drop_table entry: %s" % str(entry))
			continue

		# Roll the drop chance.
		if randf() > float(entry["chance"]):
			continue

		var count: int = randi_range(int(entry["min_count"]), int(entry["max_count"]))
		if count <= 0:
			continue

		var item_node = dropped_item_scene.instantiate()
		item_node.item_id = entry["item_id"]
		item_node.count = count
		# Scatter drops slightly so they don't stack perfectly.
		item_node.global_position = global_position + Vector2(randf_range(-12.0, 12.0), -8.0)
		get_parent().add_child(item_node)

# ------------------------------------------------------------------
# PROCEDURAL SPRITE GENERATION
# ------------------------------------------------------------------
# Builds minimal pixel-art frames so enemies are visible without art assets.
# Assign real PNG textures to SpriteFrames in the Godot editor to override.

func _generate_sprites() -> void:
	if _sprite == null:
		return
	var n: String = name.to_lower()
	if "slime" in n:
		_gen_slime_sprites()
	elif "spider" in n:
		_gen_spider_sprites()
	elif "skeleton" in n:
		_gen_skeleton_sprites()
	else:
		_gen_zombie_sprites()


func _gen_zombie_sprites() -> void:
	_apply_humanoid_sprites(
		Color(0.50, 0.73, 0.40),  # skin
		Color(0.20, 0.38, 0.10),  # hair
		Color(0.28, 0.36, 0.18),  # shirt
		Color(0.20, 0.20, 0.14),  # pants
		Color(0.15, 0.12, 0.08),  # shoes
		Color(0.85, 0.20, 0.20)   # hurt
	)


func _gen_skeleton_sprites() -> void:
	_apply_humanoid_sprites(
		Color(0.92, 0.90, 0.82),  # bone (skin)
		Color(0.12, 0.12, 0.12),  # dark
		Color(0.70, 0.68, 0.60),  # shirt (ribs shading)
		Color(0.70, 0.68, 0.60),  # pants
		Color(0.12, 0.12, 0.12),  # shoes
		Color(0.90, 0.30, 0.30)   # hurt
	)


func _apply_humanoid_sprites(skin: Color, hair: Color, shirt: Color,
		pants: Color, shoes: Color, hurt: Color) -> void:
	var sf: SpriteFrames = _sprite.sprite_frames
	if sf == null:
		return
	var t_idle := _humanoid_tex(skin, hair, shirt, pants, shoes, 0)
	var t_w1   := _humanoid_tex(skin, hair, shirt, pants, shoes, 1)
	var t_w2   := _humanoid_tex(skin, hair, shirt, pants, shoes, 2)
	var t_atk  := _humanoid_tex(skin, hair, shirt, pants, shoes, 3)
	var t_hurt := _humanoid_tex(hurt, hair, shirt, pants, shoes, 0)
	var t_die  := _humanoid_tex(hurt, hair, Color(0.18, 0.18, 0.10), pants, shoes, 4)
	_set_anim_frames(sf, "idle",   [t_idle])
	_set_anim_frames(sf, "walk",   [t_idle, t_w1, t_idle, t_w2])
	_set_anim_frames(sf, "attack", [t_atk, t_idle, t_atk])
	_set_anim_frames(sf, "hurt",   [t_hurt])
	_set_anim_frames(sf, "die",    [t_hurt, t_die])


func _gen_slime_sprites() -> void:
	var sf: SpriteFrames = _sprite.sprite_frames
	if sf == null:
		return
	var body := Color(0.20, 0.80, 0.30)
	var hurt := Color(0.90, 0.30, 0.20)
	_set_anim_frames(sf, "idle",   [_slime_tex(body, 0), _slime_tex(body, 1)])
	_set_anim_frames(sf, "walk",   [_slime_tex(body, 0), _slime_tex(body, 1)])
	_set_anim_frames(sf, "attack", [_slime_tex(body, 1), _slime_tex(body, 0), _slime_tex(body, 1)])
	_set_anim_frames(sf, "hurt",   [_slime_tex(hurt, 0)])
	_set_anim_frames(sf, "die",    [_slime_tex(hurt, 0), _slime_tex(Color(0.55, 0.15, 0.05), 2)])


func _gen_spider_sprites() -> void:
	var sf: SpriteFrames = _sprite.sprite_frames
	if sf == null:
		return
	var t_norm  := _spider_tex(false)
	var t_alt   := _spider_tex(true)
	var t_hurt  := _spider_tex_hurt()
	_set_anim_frames(sf, "idle",   [t_norm])
	_set_anim_frames(sf, "walk",   [t_norm, t_alt, t_norm, t_alt])
	_set_anim_frames(sf, "attack", [t_alt, t_norm, t_alt])
	_set_anim_frames(sf, "hurt",   [t_hurt])
	_set_anim_frames(sf, "die",    [t_hurt, t_norm])


func _set_anim_frames(sf: SpriteFrames, anim: StringName, textures: Array) -> void:
	if not sf.has_animation(anim):
		return
	while sf.get_frame_count(anim) > 0:
		sf.remove_frame(anim, 0)
	for tex in textures:
		if tex != null:
			sf.add_frame(anim, tex)


## 10×20 humanoid. pose: 0=stand 1=walk-l 2=walk-r 3=attack 4=dead-flat
func _humanoid_tex(sk: Color, hr: Color, sh: Color, pn: Color, sv: Color, pose: int) -> ImageTexture:
	var img := Image.create(10, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_img_rect(img, 3, 0, 4, 4, sk)         # head
	_img_rect(img, 3, 0, 4, 1, hr)         # hair
	img.set_pixel(4, 2, Color(0.05, 0.05, 0.05))  # left eye
	img.set_pixel(6, 2, Color(0.05, 0.05, 0.05))  # right eye
	_img_rect(img, 3, 4, 4, 5, sh)         # torso
	var ar := 4
	if pose == 3:
		ar = 2
	_img_rect(img, 1, 4, 2, 4, sk)         # left arm
	_img_rect(img, 7, ar, 2, 4, sk)        # right arm (raised on attack)
	var ll := 0; var rl := 0
	match pose:
		1: ll = -2; rl = 2
		2: ll = 2;  rl = -2
		4: ll = 3;  rl = 3
	_img_rect(img, 3, 9 + ll, 2, 6, pn)   # left leg
	_img_rect(img, 5, 9 + rl, 2, 6, pn)   # right leg
	_img_rect(img, 3, 15 + ll, 2, 3, sv)  # left shoe
	_img_rect(img, 5, 15 + rl, 2, 3, sv)  # right shoe
	return ImageTexture.create_from_image(img)


## 14×12 slime blob. pose: 0=normal 1=squish 2=splat
func _slime_tex(body: Color, pose: int) -> ImageTexture:
	var img := Image.create(14, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hi := Color(minf(body.r * 1.4, 1.0), minf(body.g * 1.4, 1.0), minf(body.b * 1.4, 1.0), 1.0)
	match pose:
		0:
			_img_rect(img, 2, 2, 10, 7, body)
			_img_rect(img, 1, 3, 12, 5, body)
			_img_rect(img, 3, 1, 8, 1, body)
			_img_rect(img, 3, 2, 3, 2, hi)
			img.set_pixel(4, 5, Color(0.05, 0.05, 0.05))
			img.set_pixel(9, 5, Color(0.05, 0.05, 0.05))
		1:
			_img_rect(img, 0, 4, 14, 6, body)
			_img_rect(img, 1, 3, 12, 7, body)
			_img_rect(img, 2, 4, 3, 2, hi)
			img.set_pixel(3, 6, Color(0.05, 0.05, 0.05))
			img.set_pixel(10, 6, Color(0.05, 0.05, 0.05))
		2:
			_img_rect(img, 0, 8, 14, 3, body)
			_img_rect(img, 2, 7, 10, 1, body)
	return ImageTexture.create_from_image(img)


## 16×10 spider (normal leg position)
func _spider_tex(alt_legs: bool) -> ImageTexture:
	var img := Image.create(16, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bc := Color(0.15, 0.10, 0.10)
	var lc := Color(0.22, 0.16, 0.16)
	var ec := Color(0.90, 0.10, 0.10)
	_img_rect(img, 5, 2, 6, 5, bc)
	_img_rect(img, 4, 3, 8, 3, bc)
	img.set_pixel(6, 3, ec); img.set_pixel(7, 3, ec)
	img.set_pixel(8, 3, ec); img.set_pixel(9, 3, ec)
	var ly := 1 if alt_legs else 2
	_img_rect(img, 0, ly,     2, 1, lc)
	_img_rect(img, 1, ly + 1, 2, 1, lc)
	_img_rect(img, 2, ly + 2, 2, 1, lc)
	_img_rect(img, 3, ly + 3, 2, 1, lc)
	_img_rect(img, 11, ly,     2, 1, lc)
	_img_rect(img, 12, ly + 1, 2, 1, lc)
	_img_rect(img, 13, ly + 2, 2, 1, lc)
	_img_rect(img, 14, ly + 3, 2, 1, lc)
	return ImageTexture.create_from_image(img)


func _spider_tex_hurt() -> ImageTexture:
	var img := Image.create(16, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bc := Color(0.75, 0.15, 0.15)
	var lc := Color(0.60, 0.12, 0.12)
	var ec := Color(1.0, 0.80, 0.10)
	_img_rect(img, 5, 2, 6, 5, bc)
	_img_rect(img, 4, 3, 8, 3, bc)
	img.set_pixel(6, 3, ec); img.set_pixel(7, 3, ec)
	img.set_pixel(8, 3, ec); img.set_pixel(9, 3, ec)
	_img_rect(img, 0, 2, 2, 1, lc); _img_rect(img, 1, 3, 2, 1, lc)
	_img_rect(img, 2, 4, 2, 1, lc); _img_rect(img, 3, 5, 2, 1, lc)
	_img_rect(img, 11, 2, 2, 1, lc); _img_rect(img, 12, 3, 2, 1, lc)
	_img_rect(img, 13, 4, 2, 1, lc); _img_rect(img, 14, 5, 2, 1, lc)
	return ImageTexture.create_from_image(img)


## Fills a rectangle in an Image (clipped to image bounds).
func _img_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and px < iw and py >= 0 and py < ih:
				img.set_pixel(px, py, c)
