extends RigidBody2D

# ── Bomb catalog ──────────────────────────────────────────────────────────────
const TYPES: Dictionary = {
	"standard":  {"color": Color(0.15, 0.15, 0.15), "size": 14, "shape": "circle", "mass": 4.0,  "blast_r": 140, "blast_f": 320, "damage": 55,  "special": ""},
	"heavy":     {"color": Color(0.25, 0.22, 0.18), "size": 18, "shape": "circle", "mass": 9.0,  "blast_r": 100, "blast_f": 500, "damage": 95,  "special": ""},
	"splitter":  {"color": Color(0.80, 0.45, 0.10), "size": 13, "shape": "tri",    "mass": 3.5,  "blast_r": 110, "blast_f": 240, "damage": 45,  "special": "split"},
	"bouncer":   {"color": Color(0.15, 0.70, 0.20), "size": 12, "shape": "circle", "mass": 3.0,  "blast_r": 120, "blast_f": 280, "damage": 50,  "special": "bounce"},
	"driller":   {"color": Color(0.60, 0.55, 0.40), "size": 14, "shape": "pill",   "mass": 6.0,  "blast_r": 80,  "blast_f": 200, "damage": 65,  "special": "drill"},
	"shockwave": {"color": Color(0.10, 0.60, 0.90), "size": 16, "shape": "circle", "mass": 5.0,  "blast_r": 300, "blast_f": 600, "damage": 40,  "special": ""},
	"cluster":   {"color": Color(0.80, 0.20, 0.15), "size": 15, "shape": "hex",    "mass": 5.5,  "blast_r": 90,  "blast_f": 200, "damage": 35,  "special": "cluster"},
	"freeze":    {"color": Color(0.55, 0.85, 1.00), "size": 14, "shape": "circle", "mass": 4.0,  "blast_r": 160, "blast_f": 180, "damage": 30,  "special": "freeze"},
	"laser":     {"color": Color(0.90, 0.10, 0.80), "size": 13, "shape": "pill",   "mass": 3.0,  "blast_r": 60,  "blast_f": 100, "damage": 80,  "special": "laser"},
	"fire":      {"color": Color(0.95, 0.40, 0.05), "size": 14, "shape": "circle", "mass": 3.5,  "blast_r": 130, "blast_f": 200, "damage": 30,  "special": "fire"},
	"lightning": {"color": Color(0.95, 0.95, 0.20), "size": 14, "shape": "circle", "mass": 3.0,  "blast_r": 200, "blast_f": 150, "damage": 40,  "special": "lightning"},
	"nuke":      {"color": Color(0.30, 0.85, 0.20), "size": 20, "shape": "circle", "mass": 12.0, "blast_r": 500, "blast_f": 900, "damage": 150, "special": ""},
	"magnet":    {"color": Color(0.70, 0.15, 0.80), "size": 14, "shape": "hex",    "mass": 5.0,  "blast_r": 280, "blast_f": 400, "damage": 35,  "special": "magnet"},
	"ghost":     {"color": Color(0.80, 0.85, 1.00, 0.5), "size": 13, "shape": "circle", "mass": 2.0, "blast_r": 120, "blast_f": 250, "damage": 50, "special": "ghost"},
	"sticky":    {"color": Color(0.55, 0.40, 0.10), "size": 14, "shape": "circle", "mass": 5.0,  "blast_r": 150, "blast_f": 350, "damage": 70,  "special": "sticky"},
	"vortex":    {"color": Color(0.40, 0.10, 0.90), "size": 16, "shape": "circle", "mass": 4.5,  "blast_r": 220, "blast_f": 500, "damage": 55,  "special": "vortex"},
}

var bomb_type: String = "standard"
var data: Dictionary = {}
var launched: bool = false
var bounce_count: int = 0
var drill_count: int = 0
var phase_count: int = 0
var sticky_stuck: bool = false
var sticky_timer: float = 0.0
var vortex_active: bool = false
var vortex_timer: float = 0.0
var fire_zone_spawned: bool = false
var special_used: bool = false
var _air_time: float = 0.0
var owner_side: String = "player"  # "player" or "ai"
var wind_force: float = 0.0

signal exploded(position: Vector2, radius: float, force: float, damage: float, special: String)
signal split_bomb(position: Vector2, velocity: Vector2, type: String, side: String)
signal request_lightning(position: Vector2, radius: float, damage: float)
signal request_fire_zone(position: Vector2)

func setup(type: String, side: String, wind: float) -> void:
	bomb_type = type
	owner_side = side
	wind_force = wind
	data = TYPES.get(type, TYPES["standard"]).duplicate()
	mass = data["mass"]
	collision_layer = 4
	collision_mask = 3  # ground + blocks

	if type == "ghost":
		collision_mask = 1  # only ground

	# No bounce on any bomb by default; only bouncer is designed to bounce
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.6
	physics_material_override.bounce = 0.85 if type == "bouncer" else 0.0

	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not launched:
		return
	_air_time += delta

	# Apply wind
	if wind_force != 0.0:
		apply_central_force(Vector2(wind_force * 120.0, 0))

	# Vortex pull phase
	if vortex_active:
		vortex_timer -= delta
		# Attract nearby blocks (handled by game.gd via signal)
		if vortex_timer <= 0.0:
			vortex_active = false
			_detonate()
		return

	# Sticky fuse
	if sticky_stuck:
		sticky_timer -= delta
		if sticky_timer <= 0.0:
			_detonate()
		return

	# Rotate to face velocity direction
	if linear_velocity.length() > 50:
		rotation = linear_velocity.angle()

	queue_redraw()

func activate_special() -> void:
	if special_used or not launched:
		return
	special_used = true
	var s: String = data.get("special", "")
	match s:
		"split":    _do_split()
		"vortex":   _start_vortex()
		"ghost":    _do_ghost_phase()
		"laser":    _do_laser()
		"sticky":   pass  # already handled on impact

func _on_body_entered(body: Node) -> void:
	if not launched:
		return
	# Ignore contacts in the first 0.15 s so the bomb clears the launch point
	if _air_time < 0.15:
		return
	var s: String = data.get("special", "")
	match s:
		"bounce":
			bounce_count += 1
			if bounce_count >= 6:
				_detonate()
		"drill":
			if body.has_method("take_damage"):
				body.take_damage(data["damage"] * 0.5)
				drill_count += 1
				if drill_count >= 8:
					_detonate()
		"ghost":
			if body.is_in_group("ground"):
				_detonate()
			elif phase_count < 4 and body.has_method("take_damage"):
				body.take_damage(data["damage"] * 0.5)
				phase_count += 1
		"sticky":
			if not sticky_stuck:
				sticky_stuck = true
				sticky_timer = 2.5
				linear_velocity = Vector2.ZERO
				angular_velocity = 0.0
				freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
				freeze = true
		_:
			if body.is_in_group("ground") or body.has_method("take_damage"):
				_detonate()

func _detonate() -> void:
	if not launched:
		return
	launched = false  # prevent double detonation
	var s: String = data.get("special", "")
	match s:
		"cluster":
			_spawn_cluster()
		"freeze":
			exploded.emit(global_position, data["blast_r"], 50.0, data["damage"], "freeze")
		"fire":
			request_fire_zone.emit(global_position)
			exploded.emit(global_position, data["blast_r"], data["blast_f"], data["damage"], "")
		"lightning":
			request_lightning.emit(global_position, data["blast_r"], data["damage"])
			exploded.emit(global_position, 60.0, 80.0, 10.0, "")
		"magnet":
			exploded.emit(global_position, data["blast_r"], data["blast_f"], data["damage"], "magnet")
		"laser":
			_do_laser()
		_:
			exploded.emit(global_position, data["blast_r"], data["blast_f"], data["damage"], "")
	queue_free()

func _do_split() -> void:
	var angles := [-22.0, 0.0, 22.0]
	var spd := linear_velocity.length() * 0.85
	for a in angles:
		var dir := linear_velocity.normalized().rotated(deg_to_rad(a))
		split_bomb.emit(global_position, dir * spd, "standard", owner_side)
	queue_free()

func _start_vortex() -> void:
	vortex_active = true
	vortex_timer = 1.5
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true

func _do_ghost_phase() -> void:
	modulate = Color(1, 1, 1, 0.25)
	collision_mask = 1  # only ground

func _do_laser() -> void:
	# Ray-cast horizontally in the travel direction
	var dir: float = sign(linear_velocity.x) if linear_velocity.x != 0 else (1.0 if owner_side == "player" else -1.0)
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(dir * 2500, 0), 2)
	var results: Array = []
	# Cast multiple rays along vertical band
	for dy in [-20, -10, 0, 10, 20]:
		var q2 := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, dy), global_position + Vector2(dir * 2500, dy), 2)
		var r := space.intersect_ray(q2)
		if r and r.collider not in results.map(func(x): return x.get("collider")):
			if r.collider.has_method("take_damage"):
				r.collider.take_damage(data["damage"] * 1.2)
	exploded.emit(global_position, 40.0, 50.0, 0.0, "")
	queue_free()

func _spawn_cluster() -> void:
	var count := 8
	for i in count:
		var angle := TAU * i / count
		var vel := Vector2(cos(angle), sin(angle)) * 280.0
		split_bomb.emit(global_position, vel, "standard", owner_side)
	exploded.emit(global_position, data["blast_r"] * 0.5, data["blast_f"] * 0.4, data["damage"] * 0.3, "")
	queue_free()

func _draw() -> void:
	var col: Color = data.get("color", Color.GRAY)
	var sz: float = data.get("size", 14)
	var shape: String = data.get("shape", "circle")

	# Outer glow
	draw_circle(Vector2.ZERO, sz * 1.65, Color(col.r, col.g, col.b, 0.18))
	draw_circle(Vector2.ZERO, sz * 1.25, Color(col.r, col.g, col.b, 0.28))

	match shape:
		"circle":
			# Shadow
			draw_circle(Vector2(sz * 0.18, sz * 0.18), sz, Color(0, 0, 0, 0.28))
			draw_circle(Vector2.ZERO, sz, col)
			# Darkened bottom half
			draw_circle(Vector2(0, sz * 0.18), sz * 0.88, col.darkened(0.18))
			# Rim
			draw_circle(Vector2.ZERO, sz, Color(0, 0, 0, 0.45), false, 2.0)
			# Highlight
			draw_circle(Vector2(-sz * 0.30, -sz * 0.30), sz * 0.35, Color(1, 1, 1, 0.38))
			draw_circle(Vector2(-sz * 0.22, -sz * 0.22), sz * 0.15, Color(1, 1, 1, 0.55))
		"tri":
			var pts: PackedVector2Array = [Vector2(0, -sz), Vector2(sz * 0.92, sz * 0.72), Vector2(-sz * 0.92, sz * 0.72)]
			var pts_shd: PackedVector2Array = [Vector2(sz * 0.18, -sz + sz * 0.18), Vector2(sz * 1.10, sz * 0.90), Vector2(-sz * 0.74, sz * 0.90)]
			draw_colored_polygon(pts_shd, Color(0, 0, 0, 0.25))
			draw_colored_polygon(pts, col)
			draw_colored_polygon(pts, col.lightened(0.18))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.45), 2.0)
			draw_circle(Vector2(-sz * 0.25, -sz * 0.28), sz * 0.22, Color(1, 1, 1, 0.35))
		"pill":
			draw_rect(Rect2(-sz * 0.5 + 1, -sz + 1, sz, sz * 2.0), Color(0, 0, 0, 0.22), true, 0.0)
			draw_rect(Rect2(-sz * 0.5, -sz, sz, sz * 2.0), col, true, 0.0)
			draw_circle(Vector2(0, -sz), sz * 0.5, col)
			draw_circle(Vector2(0, sz), sz * 0.5, col.darkened(0.2))
			draw_rect(Rect2(-sz * 0.5, -sz, sz * 0.28, sz * 2.0), col.lightened(0.22), true, 0.0)
			draw_circle(Vector2(-sz * 0.12, -sz * 0.55), sz * 0.18, Color(1, 1, 1, 0.40))
		"hex":
			var pts := PackedVector2Array()
			var pts_shd := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 - PI / 6.0
				pts.append(Vector2(cos(a) * sz, sin(a) * sz))
				pts_shd.append(Vector2(cos(a) * sz + 2, sin(a) * sz + 2))
			draw_colored_polygon(pts_shd, Color(0, 0, 0, 0.25))
			draw_colored_polygon(pts, col)
			# Inner lighter face
			var pts_inner := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 - PI / 6.0
				pts_inner.append(Vector2(cos(a) * sz * 0.65, sin(a) * sz * 0.65))
			draw_colored_polygon(pts_inner, col.lightened(0.22))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.45), 2.0)
			draw_circle(Vector2(-sz * 0.22, -sz * 0.22), sz * 0.20, Color(1, 1, 1, 0.35))

	# Fuse cord + glowing tip for non-special bombs
	if not launched and shape == "circle":
		draw_line(Vector2(0, -sz), Vector2(sz * 0.4, -sz - 10), Color(0.35, 0.28, 0.14), 2.5)
		draw_circle(Vector2(sz * 0.4, -sz - 10), 3.5, Color(1.0, 0.75, 0.1))

	# Sticky fuse ring countdown
	if sticky_stuck:
		var frac := sticky_timer / 2.5
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.014)
		draw_arc(Vector2.ZERO, sz + 7, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, Color(1.0, 0.85, 0.0, pulse), 4.0)
		draw_circle(Vector2.ZERO, sz + 7, Color(1.0, 0.85, 0.0, 0.12), false, 1.0)

	# Vortex swirl
	if vortex_active:
		var t := Time.get_ticks_msec() * 0.005
		for i in 4:
			var a := t + TAU * i / 4.0
			var r := sz + 12 + sin(t * 2.5 + i * 1.2) * 6
			draw_circle(Vector2(cos(a) * r, sin(a) * r), 5, Color(0.55, 0.10, 1.0, 0.75))
			draw_circle(Vector2(cos(a) * r, sin(a) * r), 3, Color(0.85, 0.55, 1.0, 0.55))
