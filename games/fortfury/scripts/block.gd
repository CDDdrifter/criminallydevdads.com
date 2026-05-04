extends RigidBody2D

# ── Block types ───────────────────────────────────────────────────────────────
const BLOCK_DATA: Dictionary = {
	"wood":             {"color": Color(0.55, 0.36, 0.18), "hp": 45,  "density": 1.0, "can_burn": true,  "bounce": 0.2},
	"stone":            {"color": Color(0.55, 0.55, 0.55), "hp": 110, "density": 2.2, "can_burn": false, "bounce": 0.1},
	"glass":            {"color": Color(0.70, 0.90, 1.00, 0.7), "hp": 14, "density": 0.9, "can_burn": false, "bounce": 0.3},
	"metal":            {"color": Color(0.45, 0.50, 0.55), "hp": 220, "density": 4.0, "can_burn": false, "bounce": 0.05},
	"barrel":           {"color": Color(0.40, 0.28, 0.14), "hp": 55,  "density": 1.5, "can_burn": true,  "bounce": 0.15},
	"explosive_crate":  {"color": Color(0.85, 0.70, 0.10), "hp": 35,  "density": 1.2, "can_burn": true,  "bounce": 0.1},
	"ice_block":        {"color": Color(0.70, 0.90, 1.00), "hp": 80,  "density": 1.1, "can_burn": false, "bounce": 0.4},
	"sandbag":          {"color": Color(0.75, 0.68, 0.45), "hp": 95,  "density": 3.5, "can_burn": false, "bounce": 0.02},
	"rubber_block":     {"color": Color(0.20, 0.20, 0.20), "hp": 60,  "density": 1.3, "can_burn": false, "bounce": 1.05},
	"reinforced":       {"color": Color(0.35, 0.38, 0.42), "hp": 450, "density": 5.0, "can_burn": false, "bounce": 0.03},
}

const CELL_SIZE := 64.0

var mat_type: String = "wood"
var max_hp: float = 45.0
var hp: float = 45.0
var frozen_color: Color = Color.WHITE
var is_frozen: bool = false
var freeze_timer: float = 0.0
var on_fire: bool = false
var fire_timer: float = 0.0
var fire_tick: float = 0.0

signal block_destroyed(block: Node)
signal chain_exploded(position: Vector2, radius: float, force: float, damage: float)
signal ice_shattered(position: Vector2)

func setup(type: String) -> void:
	mat_type = type
	var d: Dictionary = BLOCK_DATA.get(type, BLOCK_DATA["wood"])
	max_hp = d["hp"]
	hp = max_hp
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = d["bounce"]
	physics_material_override.friction = 0.8
	mass = d["density"] * 2.0
	linear_damp = 1.5
	angular_damp = 2.0
	collision_layer = 2
	collision_mask = 3
	queue_redraw()

func take_damage(amount: float) -> void:
	if hp <= 0:
		return
	hp -= amount
	if freeze:
		freeze = false
	queue_redraw()
	if hp <= 0:
		_die()

func take_fire_damage(dmg: float, duration: float) -> void:
	if not BLOCK_DATA.get(mat_type, {}).get("can_burn", false):
		return
	on_fire = true
	fire_timer = max(fire_timer, duration)

func freeze_block(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration
	if not freeze:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		freeze = true

func _process(delta: float) -> void:
	if is_frozen:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			is_frozen = false
			freeze = false
		queue_redraw()

	if on_fire:
		fire_timer -= delta
		fire_tick -= delta
		if fire_tick <= 0.0:
			fire_tick = 0.5
			take_damage(10.0)
		if fire_timer <= 0.0:
			on_fire = false
		queue_redraw()

func _die() -> void:
	match mat_type:
		"barrel":
			chain_exploded.emit(global_position, 140.0, 200.0, 40.0)
		"explosive_crate":
			chain_exploded.emit(global_position, 220.0, 350.0, 70.0)
		"ice_block":
			ice_shattered.emit(global_position)

	block_destroyed.emit(self)
	queue_free()

func _draw() -> void:
	var d: Dictionary = BLOCK_DATA.get(mat_type, BLOCK_DATA["wood"])
	var col: Color = d["color"]
	var half := CELL_SIZE * 0.5
	var damage_ratio := 1.0 - (hp / max_hp)

	if is_frozen:
		col = col.lerp(Color(0.55, 0.92, 1.0), 0.55)
	if on_fire:
		col = col.lerp(Color(1.0, 0.35, 0.0), 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.012))

	col = col.darkened(damage_ratio * 0.45)

	# Drop shadow for depth
	draw_rect(Rect2(-half + 3, -half + 3, CELL_SIZE, CELL_SIZE), Color(0, 0, 0, 0.28))

	# Main face
	draw_rect(Rect2(-half, -half, CELL_SIZE, CELL_SIZE), col)

	# Bevel highlights — top and left edges lighter
	draw_rect(Rect2(-half, -half, CELL_SIZE - 1, 5), col.lightened(0.30))
	draw_rect(Rect2(-half, -half, 5, CELL_SIZE - 1), col.lightened(0.20))

	# Bevel shadows — bottom and right edges darker
	draw_rect(Rect2(-half + 1, half - 5, CELL_SIZE - 1, 5), col.darkened(0.35))
	draw_rect(Rect2(half - 5, -half + 1, 5, CELL_SIZE - 1), col.darkened(0.28))

	# Material detail overlay
	match mat_type:
		"wood":
			var gc := Color(0.28, 0.17, 0.05, 0.45)
			for gy in [14, 27, 40, 53]:
				draw_line(Vector2(-half + 5, -half + gy), Vector2(half - 5, -half + gy), gc, 1.5)
			draw_line(Vector2(-half + 22, -half), Vector2(-half + 22, half), Color(0.22, 0.13, 0.04, 0.18), 1.5)
		"stone":
			# Mortar lines create brick pattern
			draw_rect(Rect2(-half + 2, -half + 20, CELL_SIZE - 4, 2), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(-half + 2, -half + 42, CELL_SIZE - 4, 2), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(0, -half, 2, 20), Color(0, 0, 0, 0.20))
			draw_rect(Rect2(-half + 14, -half + 22, 2, 20), Color(0, 0, 0, 0.20))
		"glass":
			# Two diagonal shine streaks
			draw_line(Vector2(-half + 8, -half + 4), Vector2(-half + 20, -half + 28), Color(1, 1, 1, 0.55), 3.0)
			draw_line(Vector2(-half + 22, -half + 4), Vector2(-half + 30, -half + 18), Color(1, 1, 1, 0.30), 2.0)
			draw_rect(Rect2(-half + 2, -half + 2, CELL_SIZE - 4, CELL_SIZE - 4), Color(0.6, 0.85, 1.0, 0.08))
		"metal":
			# Rivets at corners + panel lines
			for rx in [-half + 8, half - 8]:
				for ry in [-half + 8, half - 8]:
					draw_circle(Vector2(rx, ry), 3.5, Color(0, 0, 0, 0.4))
					draw_circle(Vector2(rx, ry), 2.0, Color(1, 1, 1, 0.30))
			draw_rect(Rect2(-half + 12, -half + 12, CELL_SIZE - 24, CELL_SIZE - 24), Color(1, 1, 1, 0.06), false, 1.5)
		"barrel":
			draw_circle(Vector2.ZERO, half - 5, Color(col.r * 0.85, col.g * 0.7, col.b * 0.5))
			draw_circle(Vector2.ZERO, half - 5, Color(0, 0, 0, 0.35), false, 2.5)
			for band_y in [-10, 0, 10]:
				draw_line(Vector2(-half + 7, band_y), Vector2(half - 7, band_y), Color(0.22, 0.20, 0.18, 0.65), 2.5)
		"explosive_crate":
			draw_rect(Rect2(-half + 4, -half + 4, CELL_SIZE - 8, CELL_SIZE - 8), Color(0.85, 0.75, 0.1, 0.15))
			draw_rect(Rect2(-half + 4, -half + 4, CELL_SIZE - 8, CELL_SIZE - 8), Color(0, 0, 0, 0.3), false, 2.0)
			draw_line(Vector2(-half + 6, -half + 6), Vector2(half - 6, half - 6), Color(0.95, 0.15, 0.1, 0.85), 2.5)
			draw_line(Vector2(half - 6, -half + 6), Vector2(-half + 6, half - 6), Color(0.95, 0.15, 0.1, 0.85), 2.5)
			# Warning glow pulse
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			draw_rect(Rect2(-half + 2, -half + 2, CELL_SIZE - 4, CELL_SIZE - 4), Color(1.0, 0.5, 0.0, 0.08 * pulse), false, 2.0)
		"ice_block":
			draw_rect(Rect2(-half + 3, -half + 3, CELL_SIZE - 6, CELL_SIZE - 6), Color(0.8, 0.95, 1.0, 0.18))
			draw_line(Vector2(-half + 10, 0), Vector2(half - 10, 0), Color(1, 1, 1, 0.5), 2.0)
			draw_line(Vector2(0, -half + 10), Vector2(0, half - 10), Color(1, 1, 1, 0.5), 2.0)
			draw_line(Vector2(-half + 8, -half + 8), Vector2(half - 8, half - 8), Color(1, 1, 1, 0.22), 1.5)
		"sandbag":
			var sc := Color(0.82, 0.74, 0.50)
			draw_circle(Vector2(-11, 2), 12, sc)
			draw_circle(Vector2(11, 2), 12, sc)
			draw_circle(Vector2(0, -9), 11, sc.lightened(0.1))
			draw_circle(Vector2(0, 10), 10, sc.darkened(0.1))
			# Stitching
			draw_line(Vector2(-11, 2), Vector2(11, 2), Color(0.55, 0.45, 0.28, 0.6), 1.5)
		"reinforced":
			draw_rect(Rect2(-half + 5, -half + 5, CELL_SIZE - 10, CELL_SIZE - 10), Color(1, 1, 1, 0.07), false, 3.0)
			# Cross bracing
			draw_line(Vector2(-half + 10, -half + 10), Vector2(half - 10, half - 10), Color(1, 1, 1, 0.18), 2.5)
			draw_line(Vector2(half - 10, -half + 10), Vector2(-half + 10, half - 10), Color(1, 1, 1, 0.18), 2.5)
			for rv in [-12, 12]:
				draw_line(Vector2(-half + 8, rv), Vector2(half - 8, rv), Color(1, 1, 1, 0.15), 2.0)
				draw_line(Vector2(rv, -half + 8), Vector2(rv, half - 8), Color(1, 1, 1, 0.15), 2.0)

	# Damage cracks — more organic looking
	if damage_ratio > 0.25:
		var cc := Color(0.05, 0.03, 0.02, damage_ratio * 0.75)
		draw_line(Vector2(-half + 6, -half + 8), Vector2(-3, 6), cc, 1.8)
		draw_line(Vector2(-3, 6), Vector2(half - 10, half - 5), cc, 1.8)
		draw_line(Vector2(-3, 6), Vector2(-half + 14, half - 12), cc, 1.4)
	if damage_ratio > 0.55:
		var cc2 := Color(0.05, 0.03, 0.02, damage_ratio * 0.85)
		draw_line(Vector2(half - 8, -half + 6), Vector2(4, -4), cc2, 1.8)
		draw_line(Vector2(4, -4), Vector2(-half + 8, half - 10), cc2, 1.8)
		draw_line(Vector2(4, -4), Vector2(half - 6, half - 8), cc2, 1.4)

	# Ice frozen overlay
	if is_frozen:
		draw_rect(Rect2(-half, -half, CELL_SIZE, CELL_SIZE), Color(0.55, 0.90, 1.0, 0.18))
		draw_rect(Rect2(-half, -half, CELL_SIZE, CELL_SIZE), Color(0.7, 0.95, 1.0, 0.35), false, 2.0)

	# Fire flicker overlay
	if on_fire:
		var ft := Time.get_ticks_msec() * 0.01
		for fi in 4:
			var fx := randf_range(-half + 8, half - 8)
			draw_line(Vector2(fx, half - 4), Vector2(fx + randf_range(-6, 6), half - 16 - fi * 4), Color(1.0, 0.45 + fi * 0.1, 0.0, 0.6), 2.5)

	# HP bar
	if hp < max_hp:
		var bar_w := CELL_SIZE - 6.0
		var bar_h := 5.0
		var fill := (hp / max_hp) * bar_w
		var bar_col := Color(0.2, 0.85, 0.2) if hp > max_hp * 0.5 else Color(0.9, 0.55, 0.0) if hp > max_hp * 0.25 else Color(0.92, 0.12, 0.12)
		draw_rect(Rect2(-half + 3, half - 9, bar_w, bar_h), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(-half + 3, half - 9, fill, bar_h), bar_col)
		draw_rect(Rect2(-half + 3, half - 9, bar_w, bar_h), Color(0, 0, 0, 0.3), false, 1.0)
