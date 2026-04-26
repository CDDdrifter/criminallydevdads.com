class_name AnimalBase
extends CharacterBody2D

## Base class for passive animals: Sheep, Cow, Pig, Chicken.
## Handles idle/wander/flee states, damage, death, drops, and shearing.

enum State { IDLE, WANDER, FLEE }

@export var animal_type: String = "generic"
@export var drop_table: Array = []   # Array of {item, chance, min, max}
@export var max_health: float = 10.0
@export var move_speed: float = 60.0
@export var flee_speed_multiplier: float = 2.2

const GRAVITY := 500.0
const WANDER_INTERVAL_MIN := 2.0
const WANDER_INTERVAL_MAX := 5.5
const IDLE_INTERVAL_MIN := 1.0
const IDLE_INTERVAL_MAX := 3.0
const FLEE_DURATION := 3.5
const SHEAR_COOLDOWN := 30.0        # Seconds between shears

## LOD: animals beyond this distance from the player just apply gravity.
## 500 px = ~31 tiles. Halves per-frame cost for distant herds.
const AI_ACTIVE_DIST: float = 500.0
const LOD_CHECK_INTERVAL: float = 0.60   # seconds between distance checks

var health: float
var state: State = State.IDLE
var _wander_dir := Vector2.ZERO
var _state_timer := 0.0
var _flee_timer := 0.0
var _shear_cooldown := 0.0
var _dead := false
var _on_floor_last := false
var _lod_timer: float = 0.0
var _lod_dormant: bool = false
var _player_cache: Node = null   # cached via _get_player(); refreshed if freed

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_timer: Timer = $HurtTimer


func _ready() -> void:
	health = max_health
	_enter_idle()
	add_to_group("animals")
	collision_layer = 4  # same layer as enemies so AttackArea (mask=4) detects them
	# Stagger LOD checks so all animals don't check on the same frame.
	_lod_timer = randf_range(0.0, LOD_CHECK_INTERVAL)
	_generate_sprites()


func _physics_process(delta: float) -> void:
	if _dead:
		return

	# ── LOD culling (every 0.6 s) ─────────────────────────────────────────────
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = LOD_CHECK_INTERVAL
		var player: Node2D = _get_player() as Node2D
		if player != null:
			_lod_dormant = global_position.distance_squared_to(player.global_position) \
				> AI_ACTIVE_DIST * AI_ACTIVE_DIST
		else:
			_lod_dormant = false

	if _lod_dormant:
		# Dormant: gravity only — wander AI paused.
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		move_and_slide()
		return

	_update_timers(delta)
	_apply_gravity(delta)

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 4 * delta)
		State.WANDER:
			velocity.x = _wander_dir.x * move_speed
		State.FLEE:
			velocity.x = _wander_dir.x * move_speed * flee_speed_multiplier

	move_and_slide()
	_update_animation()


func _update_timers(delta: float) -> void:
	_state_timer -= delta
	if _shear_cooldown > 0.0:
		_shear_cooldown -= delta

	match state:
		State.IDLE:
			if _state_timer <= 0.0:
				_enter_wander()
		State.WANDER:
			if _state_timer <= 0.0:
				_enter_idle()
		State.FLEE:
			_flee_timer -= delta
			if _flee_timer <= 0.0:
				_enter_idle()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0


func _update_animation() -> void:
	if not is_instance_valid(sprite):
		return
	if abs(velocity.x) > 5.0:
		if sprite.animation != "walk":
			sprite.play("walk")
		sprite.flip_h = velocity.x < 0.0
	else:
		if sprite.animation != "idle":
			sprite.play("idle")


func _enter_idle() -> void:
	state = State.IDLE
	_wander_dir = Vector2.ZERO
	_state_timer = randf_range(IDLE_INTERVAL_MIN, IDLE_INTERVAL_MAX)


func _enter_wander() -> void:
	state = State.WANDER
	_wander_dir = Vector2(randf_range(-1.0, 1.0), 0.0).normalized()
	# Occasionally stand still (zero x = pause)
	if randf() < 0.25:
		_wander_dir = Vector2.ZERO
	_state_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)


func _enter_flee(from_position: Vector2) -> void:
	state = State.FLEE
	_flee_timer = FLEE_DURATION
	var dir := (global_position - from_position).normalized()
	if abs(dir.x) < 0.1:
		dir.x = 1.0 if randf() > 0.5 else -1.0
	_wander_dir = Vector2(sign(dir.x), 0.0)
	_state_timer = FLEE_DURATION


# ── Public API ─────────────────────────────────────────────────────────────

func take_damage(amount: float, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	health -= amount
	_flash_hurt()
	_enter_flee(attacker_position)
	if health <= 0.0:
		_die()


func try_shear(player: Node) -> bool:
	if animal_type != "sheep":
		return false
	if _dead:
		return false
	if _shear_cooldown > 0.0:
		return false
	_shear_cooldown = SHEAR_COOLDOWN
	_spawn_drop("wool", 1, 3)
	return true


func interact(player: Node) -> void:
	# Right-click interaction: shear sheep, could pet others etc.
	if animal_type == "sheep":
		try_shear(player)


# ── Private helpers ────────────────────────────────────────────────────────

func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	if is_instance_valid(sprite):
		sprite.play("die")
	_roll_drops()
	# Wait for death animation then remove
	await get_tree().create_timer(1.2).timeout
	queue_free()


func _roll_drops() -> void:
	for entry in drop_table:
		var chance: float = entry.get("chance", 1.0)
		if randf() <= chance:
			var min_count: int = entry.get("min", 1)
			var max_count: int = entry.get("max", 1)
			var amount := randi_range(min_count, max_count)
			_spawn_drop(entry.get("item", ""), amount, amount)


func _spawn_drop(item_id: String, min_count: int, max_count: int) -> void:
	if item_id.is_empty():
		return
	var amount := randi_range(min_count, max_count)
	if amount <= 0:
		return

	var dropped: Node = null
	# Try to load the DroppedItem scene
	var scene_path := "res://scenes/DroppedItem.tscn"
	if ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path)
		dropped = packed.instantiate()
	else:
		# Fallback: create bare Area2D if scene not found
		dropped = load("res://scripts/DroppedItem.gd").new()

	if dropped and dropped.has_method("setup"):
		dropped.setup(item_id, amount)
	elif dropped:
		dropped.set("item_id", item_id)
		dropped.set("count", amount)

	if dropped:
		dropped.global_position = global_position + Vector2(randf_range(-8, 8), -4)
		get_parent().add_child(dropped)


func _flash_hurt() -> void:
	if not is_instance_valid(sprite):
		return
	if sprite.sprite_frames != null && sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		await get_tree().create_timer(0.2).timeout
		if not _dead and is_instance_valid(sprite):
			sprite.play("idle")
	else:
		# Modulate flash fallback
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE


# ------------------------------------------------------------------
# PROCEDURAL SPRITE GENERATION
# ------------------------------------------------------------------

func _generate_sprites() -> void:
	if not is_instance_valid(sprite):
		return
	var sf: SpriteFrames = sprite.sprite_frames
	if sf == null:
		return
	var t := animal_type.to_lower()
	if t == "sheep":
		_gen_sheep(sf)
	elif t == "cow":
		_gen_cow(sf)
	elif t == "pig":
		_gen_pig(sf)
	elif t == "chicken":
		_gen_chicken(sf)
	else:
		_gen_generic_animal(sf)


func _gen_sheep(sf: SpriteFrames) -> void:
	var wool  := Color(0.92, 0.90, 0.86)
	var body  := Color(0.72, 0.70, 0.66)
	var face  := Color(0.30, 0.25, 0.20)
	var legs  := Color(0.20, 0.18, 0.14)
	var hurt  := Color(0.90, 0.30, 0.25)
	var t_idle := _animal_tex(wool, face, legs, body, 0)
	var t_w1   := _animal_tex(wool, face, legs, body, 1)
	var t_w2   := _animal_tex(wool, face, legs, body, 2)
	var t_hurt := _animal_tex(hurt, face, legs, hurt, 0)
	var t_die  := _animal_tex(hurt, face, legs, hurt, 3)
	_set_anim_frames(sf, "idle", [t_idle])
	_set_anim_frames(sf, "walk", [t_idle, t_w1, t_idle, t_w2])
	if sf.has_animation("hurt"):
		_set_anim_frames(sf, "hurt", [t_hurt])
	if sf.has_animation("die"):
		_set_anim_frames(sf, "die", [t_hurt, t_die])


func _gen_cow(sf: SpriteFrames) -> void:
	var body := Color(0.85, 0.82, 0.78)   # white-ish with patches
	var spot := Color(0.22, 0.15, 0.10)   # dark brown patches (face)
	var legs := Color(0.20, 0.16, 0.12)
	var hurt := Color(0.90, 0.30, 0.25)
	var t_idle := _animal_tex(body, spot, legs, body, 0)
	var t_w1   := _animal_tex(body, spot, legs, body, 1)
	var t_w2   := _animal_tex(body, spot, legs, body, 2)
	var t_hurt := _animal_tex(hurt, spot, legs, hurt, 0)
	var t_die  := _animal_tex(hurt, spot, legs, hurt, 3)
	_set_anim_frames(sf, "idle", [t_idle])
	_set_anim_frames(sf, "walk", [t_idle, t_w1, t_idle, t_w2])
	if sf.has_animation("hurt"):
		_set_anim_frames(sf, "hurt", [t_hurt])
	if sf.has_animation("die"):
		_set_anim_frames(sf, "die", [t_hurt, t_die])


func _gen_pig(sf: SpriteFrames) -> void:
	var body := Color(0.95, 0.72, 0.70)   # pink
	var snout := Color(0.85, 0.55, 0.55)
	var legs := Color(0.85, 0.60, 0.58)
	var hurt := Color(0.90, 0.30, 0.25)
	var t_idle := _animal_tex(body, snout, legs, body, 0)
	var t_w1   := _animal_tex(body, snout, legs, body, 1)
	var t_w2   := _animal_tex(body, snout, legs, body, 2)
	var t_hurt := _animal_tex(hurt, snout, legs, hurt, 0)
	var t_die  := _animal_tex(hurt, snout, legs, hurt, 3)
	_set_anim_frames(sf, "idle", [t_idle])
	_set_anim_frames(sf, "walk", [t_idle, t_w1, t_idle, t_w2])
	if sf.has_animation("hurt"):
		_set_anim_frames(sf, "hurt", [t_hurt])
	if sf.has_animation("die"):
		_set_anim_frames(sf, "die", [t_hurt, t_die])


func _gen_chicken(sf: SpriteFrames) -> void:
	# Chickens are small — reuse the same 18×12 texture but with white/red colors
	var body := Color(0.95, 0.93, 0.88)   # white feathers
	var beak := Color(0.95, 0.70, 0.15)   # yellow beak / face
	var legs := Color(0.90, 0.65, 0.15)   # yellow legs
	var hurt := Color(0.90, 0.30, 0.25)
	var t_idle := _animal_tex(body, beak, legs, body, 0)
	var t_w1   := _animal_tex(body, beak, legs, body, 1)
	var t_w2   := _animal_tex(body, beak, legs, body, 2)
	var t_hurt := _animal_tex(hurt, beak, legs, hurt, 0)
	var t_die  := _animal_tex(hurt, beak, legs, hurt, 3)
	_set_anim_frames(sf, "idle", [t_idle])
	_set_anim_frames(sf, "walk", [t_idle, t_w1, t_idle, t_w2])
	if sf.has_animation("hurt"):
		_set_anim_frames(sf, "hurt", [t_hurt])
	if sf.has_animation("die"):
		_set_anim_frames(sf, "die", [t_hurt, t_die])


func _gen_generic_animal(sf: SpriteFrames) -> void:
	var body := Color(0.65, 0.50, 0.35)
	var face := Color(0.40, 0.30, 0.20)
	var legs := Color(0.30, 0.22, 0.14)
	var hurt := Color(0.90, 0.30, 0.25)
	var t_idle := _animal_tex(body, face, legs, body, 0)
	var t_w1   := _animal_tex(body, face, legs, body, 1)
	var t_w2   := _animal_tex(body, face, legs, body, 2)
	var t_hurt := _animal_tex(hurt, face, legs, hurt, 0)
	_set_anim_frames(sf, "idle", [t_idle])
	_set_anim_frames(sf, "walk", [t_idle, t_w1, t_idle, t_w2])
	if sf.has_animation("hurt"):
		_set_anim_frames(sf, "hurt", [t_hurt])
	if sf.has_animation("die"):
		_set_anim_frames(sf, "die", [t_hurt])


## 18×12 four-legged animal sprite.
## pose: 0=stand 1=walk-a 2=walk-b 3=dead
func _animal_tex(body: Color, face: Color, legs: Color, belly: Color, pose: int) -> ImageTexture:
	var img := Image.create(18, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Body
	_img_rect(img, 3, 2, 11, 6, body)
	# Belly (slightly different shade on underside)
	_img_rect(img, 4, 6, 9, 2, belly)
	# Head
	_img_rect(img, 13, 1, 5, 5, body)
	_img_rect(img, 14, 2, 3, 3, face)
	img.set_pixel(15, 2, Color(0.05, 0.05, 0.05))
	# Legs (4 legs, positions depend on pose)
	var lf := 0  # front-left offset
	var lr := 0  # back-right offset
	match pose:
		1: lf = -1; lr = 1
		2: lf = 1;  lr = -1
		3: lf = 2;  lr = 2
	var leg_y := 8
	if pose == 3:
		leg_y = 9
	_img_rect(img, 4,  leg_y + lf, 2, 4, legs)   # front-left
	_img_rect(img, 7,  leg_y + lr, 2, 4, legs)   # front-right
	_img_rect(img, 10, leg_y + lr, 2, 4, legs)   # back-left
	_img_rect(img, 13, leg_y + lf, 2, 4, legs)   # back-right
	return ImageTexture.create_from_image(img)


func _set_anim_frames(sf: SpriteFrames, anim: StringName, textures: Array) -> void:
	if not sf.has_animation(anim):
		return
	while sf.get_frame_count(anim) > 0:
		sf.remove_frame(anim, 0)
	for tex in textures:
		if tex != null:
			sf.add_frame(anim, tex)


func _img_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and px < iw and py >= 0 and py < ih:
				img.set_pixel(px, py, c)


func _get_player() -> Node:
	if _player_cache == null or not is_instance_valid(_player_cache):
		var players := get_tree().get_nodes_in_group("player")
		_player_cache = players[0] if not players.is_empty() else null
	return _player_cache
