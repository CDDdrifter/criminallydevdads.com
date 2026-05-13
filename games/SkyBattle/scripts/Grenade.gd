extends RigidBody2D

var thrower: Node = null

var _fuse: float    = 3.0
var _arm: float     = 0.45
var _armed: bool    = false
var _exploded: bool = false

const EXPLOSION_FX = preload("res://scripts/ExplosionFX.gd")
const BLAST_RADIUS: float = 115.0
const BLAST_DAMAGE: int   = 85

func _ready() -> void:
	contact_monitor       = true
	max_contacts_reported = 6
	gravity_scale         = 1.2
	linear_damp           = 0.3
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _exploded:
		return
	if _arm > 0.0:
		_arm -= delta
		if _arm <= 0.0:
			_armed = true
	_fuse -= delta
	if _fuse <= 0.0:
		_explode()
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if not _armed or _exploded or body == thrower:
		return
	_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	# Island terrain destruction
	var islands: IslandWorld = get_node_or_null("/root/Match/IslandWorld")
	if islands:
		islands.apply_explosion(position, BLAST_RADIUS)

	# Ground terrain destruction
	var ground: Terrain = get_node_or_null("/root/Match/Terrain")
	if ground:
		ground.apply_explosion(position, BLAST_RADIUS)

	# Player damage
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or not p.is_alive():
			continue
		var dist: float = position.distance_to(p.position)
		if dist <= BLAST_RADIUS:
			var falloff: float = 1.0 - clampf(dist / BLAST_RADIUS, 0.0, 1.0)
			var dmg: int       = maxi(12, int(float(BLAST_DAMAGE) * falloff))
			p.take_damage(dmg, thrower)

	# Visual
	var match_node := get_node_or_null("/root/Match")
	if match_node:
		var fx := Node2D.new()
		fx.set_script(EXPLOSION_FX)
		fx.position = position
		match_node.add_child(fx)
		fx.play(BLAST_RADIUS * 1.2)

	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.3, 0.3, 0.35))
	if _armed:
		var blink: bool = fmod(float(Time.get_ticks_msec()) / 200.0, 1.0) > 0.5
		if blink:
			draw_circle(Vector2(0.0, -6.0), 2.5, Color(1.0, 0.2, 0.1))
