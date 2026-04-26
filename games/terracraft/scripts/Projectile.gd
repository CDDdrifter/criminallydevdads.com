extends Area2D

## Projectile.gd — Visual bullet for guns.
##
## Spawned programmatically by Player._spawn_projectile() — no .tscn needed.
## Set `direction`, `speed`, `damage`, `max_range`, and `owner_node` BEFORE
## calling add_child() on this node so _ready() can orient the visual correctly.
##
## Collision:
##   • Passes through terrain that lacks take_damage() (blocks won't be shot through — see below).
##   • Stops on StaticBody2D (world tile physics) to give bullets a solid feel.
##   • Deals `damage` to the first damageable CharacterBody2D / Node it hits.
##
## To customise per-gun feel, add "projectile_speed" to the item's entry in
## ItemDatabase.gd (e.g. pistol = 900, rifle = 1400, shotgun = 650).

class_name Projectile

# ─────────────────────────────────────────────────────────────────────────────
#  Configuration — set before add_child()
# ─────────────────────────────────────────────────────────────────────────────

## Normalised travel direction.
var direction:  Vector2 = Vector2.RIGHT

## Travel speed in pixels per second.  Override via ItemDatabase "projectile_speed".
var speed:      float   = 900.0

## Damage dealt on first hit.
var damage:     float   = 15.0

## Maximum travel distance (pixels) before the projectile auto-despawns.
var max_range:  float   = 500.0

## The node that fired this projectile — never counted as a hit target.
var owner_node: Node    = null

# ─────────────────────────────────────────────────────────────────────────────
#  Internal state
# ─────────────────────────────────────────────────────────────────────────────

var _travelled: float = 0.0
var _done:      bool  = false   # one hit per projectile; prevents double-free


func _ready() -> void:
	# ── Collision circle ──────────────────────────────────────────────────────
	var cshape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	cshape.shape  = circle
	add_child(cshape)

	# ── Bullet visual — small bright rectangle oriented along travel direction ─
	var poly := Polygon2D.new()
	var ang  := direction.angle()
	var hw   := 2.0   # half-width  (px)
	var hl   := 8.0   # half-length (px)
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hl).rotated(ang),
		Vector2( hw, -hl).rotated(ang),
		Vector2( hw,  hl).rotated(ang),
		Vector2(-hw,  hl).rotated(ang),
	])
	poly.color = Color(1.0, 0.95, 0.45, 1.0)   # warm yellow
	add_child(poly)

	# ── Physics layers ────────────────────────────────────────────────────────
	# Collision layer 0 means the projectile is invisible to other probes.
	# Mask 0xFFFF catches everything; we filter hits in _on_body_entered.
	collision_layer = 0
	collision_mask  = 0xFFFF
	monitoring      = true
	monitorable     = false

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := direction * speed * delta
	global_position += step
	_travelled      += step.length()
	if _travelled >= max_range:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if body == owner_node:
		return   # never self-hit

	# ── Solid terrain: stop the bullet ───────────────────────────────────────
	if body is StaticBody2D:
		_done = true
		_spawn_impact()
		queue_free()
		return

	# ── Damageable target: hit it ─────────────────────────────────────────────
	if body.has_method("take_damage"):
		_done = true
		body.take_damage(damage)
		var kb := direction.normalized()
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity += kb * 350.0
		_spawn_impact()
		queue_free()


func _spawn_impact() -> void:
	## Small white flash at the hit point — freed after 0.08 s.
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(-6.0, -6.0), Vector2(6.0, -6.0),
		Vector2( 6.0,  6.0), Vector2(-6.0,  6.0),
	])
	flash.color = Color(1.0, 1.0, 0.85, 0.85)
	flash.global_position = global_position
	get_tree().get_root().add_child(flash)
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(flash.queue_free)
