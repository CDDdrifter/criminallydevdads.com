## WeatherSystem.gd
## Handles weather effects: rain, snow, falling leaves, thunder, lightning strikes.
## All particles are screen-space (CanvasLayer child) so they follow the camera.
## Add to World node via add_child() in World._ready().
extends Node

# Tiles that can be destroyed by lightning (organic/flammable).
const BURNABLE: Array = [
	"grass", "dirt_with_grass", "oak_log", "birch_log", "pine_log",
	"oak_leaves", "birch_leaves", "pine_leaves", "hay", "wheat", "tall_grass",
	"sapling_oak", "sapling_birch", "sapling_pine",
]

var _canvas: CanvasLayer = null
var _rain_p:  CPUParticles2D = null
var _snow_p:  CPUParticles2D = null
var _leaf_p:  CPUParticles2D = null
var _flash:   ColorRect      = null
var _bolt:    Line2D         = null

var _vp: Vector2 = Vector2.ZERO
var _biome: String = ""
var _is_raining: bool = false
var _is_snowing: bool = false
var _leaves_on:  bool = false

# Thunder
var _thunder_cd:   float = 999.0
var _flash_timer:  float = 0.0
var _bolt_timer:   float = 0.0


func _ready() -> void:
	call_deferred("_deferred_init")


func _deferred_init() -> void:
	_vp = get_viewport().get_visible_rect().size
	if _vp.x < 10.0:
		_vp = Vector2(DisplayServer.window_get_size())

	_canvas = CanvasLayer.new()
	_canvas.layer = 4          # below HUD (5), above world tiles
	add_child(_canvas)

	_rain_p = _make_rain()
	_snow_p = _make_snow()
	_leaf_p = _make_leaves()

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_flash.visible = false
	_canvas.add_child(_flash)

	_bolt = Line2D.new()
	_bolt.width = 3.0
	_bolt.default_color = Color(0.75, 0.85, 1.0, 1.0)
	_bolt.visible = false
	_canvas.add_child(_bolt)

	get_viewport().size_changed.connect(_on_resize)


func _on_resize() -> void:
	_vp = get_viewport().get_visible_rect().size
	_rebuild_emitters()


func _rebuild_emitters() -> void:
	var hw: float = _vp.x * 0.5 + 120.0
	var top: float = -30.0
	for p: CPUParticles2D in [_rain_p, _snow_p, _leaf_p]:
		if p == null:
			continue
		p.position = Vector2(_vp.x * 0.5, top)
		p.emission_rect_extents = Vector2(hw, 2.0)


# ─── Public API ──────────────────────────────────────────────────────────────

func update_biome(biome: String) -> void:
	if biome == _biome:
		return
	_biome = biome
	_apply_biome()


func _apply_biome() -> void:
	var enabled: bool = GameData.fx.get("weather", true) and GameData.fx.get("enabled", true)
	if not enabled:
		_set_rain(false); _set_snow(false); _set_leaves(false)
		return
	match _biome:
		"snow":
			_set_rain(false); _set_snow(true); _set_leaves(false)
		"desert":
			_set_rain(false); _set_snow(false); _set_leaves(false)
		"forest":
			_set_rain(true);  _set_snow(false)
			_set_leaves(GameData.fx.get("leaves", true))
		_:  # plains + anything else
			_set_rain(true);  _set_snow(false); _set_leaves(false)


func _set_rain(on: bool) -> void:
	_is_raining = on
	if _rain_p:
		_rain_p.emitting = on
	_thunder_cd = randf_range(20.0, 50.0) if on else 999.0


func _set_snow(on: bool) -> void:
	_is_snowing = on
	if _snow_p:
		_snow_p.emitting = on


func _set_leaves(on: bool) -> void:
	_leaves_on = on
	if _leaf_p:
		_leaf_p.emitting = on


# ─── Per-frame logic ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not GameData.fx.get("enabled", true):
		return

	# Flash fade
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash != null:
			_flash.color.a = clamp(_flash_timer * 3.5, 0.0, 0.7)
			if _flash_timer <= 0.0:
				_flash.visible = false
	if _bolt_timer > 0.0:
		_bolt_timer -= delta
		if _bolt != null:
			_bolt.modulate.a = clamp(_bolt_timer * 4.0, 0.0, 1.0)
			if _bolt_timer <= 0.0:
				_bolt.visible = false

	# Thunder timer
	if _is_raining and GameData.fx.get("lightning", true):
		_thunder_cd -= delta
		if _thunder_cd <= 0.0:
			_trigger_lightning()
			_thunder_cd = randf_range(18.0, 55.0)


func _trigger_lightning() -> void:
	# Screen flash
	if _flash:
		_flash.visible = true
		_flash.color.a = 0.7
	_flash_timer = 0.30

	# Bolt
	if _bolt:
		var x: float = randf_range(_vp.x * 0.1, _vp.x * 0.9)
		_bolt.clear_points()
		var y: float = 0.0
		while y < _vp.y + 40.0:
			_bolt.add_point(Vector2(x + randf_range(-18.0, 18.0), y))
			y += randf_range(18.0, 55.0)
		_bolt.visible = true
		_bolt.modulate.a = 1.0
	_bolt_timer = 0.22

	# Burn tiles near a random point around the player
	var world: Node = get_tree().get_first_node_in_group("world")
	var player: Node = get_tree().get_first_node_in_group("player")
	if world and player and world.has_method("set_tile_at_world_pos") and world.has_method("get_tile_at_world_pos"):
		var strike_x: float = player.global_position.x + randf_range(-300.0, 300.0)
		_burn_column(world, strike_x, player.global_position.y)


func _burn_column(world: Node, world_x: float, near_y: float) -> void:
	# Scan down from above the player to find the surface, then burn a small patch.
	var ts: int = GameData.TILE_SIZE
	var scan_start_y: float = near_y - 300.0
	var surface_world_y: float = near_y

	for step in range(60):
		var check: Vector2 = Vector2(world_x, scan_start_y + step * ts)
		var tid: String = world.get_tile_at_world_pos(check)
		if tid != "" and tid != "air":
			surface_world_y = check.y
			break

	# Destroy burnable tiles in a 3×3 patch around strike point
	for dy in range(-1, 3):
		for dx in range(-1, 2):
			var wp: Vector2 = Vector2(world_x + dx * ts, surface_world_y + dy * ts)
			var tid: String = world.get_tile_at_world_pos(wp)
			if tid in BURNABLE:
				world.set_tile_at_world_pos(wp, "")


# ─── Particle constructors ────────────────────────────────────────────────────

func _make_rain() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting       = false
	p.amount         = GameData.fx_particles(40)
	p.lifetime       = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2((_vp.x * 0.5) + 120.0, 2.0)
	p.direction      = Vector2(0.18, 1.0)
	p.spread         = 4.0
	p.initial_velocity_min = 380.0
	p.initial_velocity_max = 460.0
	p.gravity        = Vector2(0.0, 60.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color          = Color(0.55, 0.70, 0.92, 0.45)
	p.position       = Vector2(_vp.x * 0.5, -30.0)
	_canvas.add_child(p)
	return p


func _make_snow() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting       = false
	p.amount         = GameData.fx_particles(20)
	p.lifetime       = 5.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2((_vp.x * 0.5) + 120.0, 2.0)
	p.direction      = Vector2(0.12, 1.0)
	p.spread         = 28.0
	p.initial_velocity_min = 28.0
	p.initial_velocity_max = 55.0
	p.gravity        = Vector2(0.0, 6.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color          = Color(1.0, 1.0, 1.0, 0.80)
	p.position       = Vector2(_vp.x * 0.5, -30.0)
	_canvas.add_child(p)
	return p


func _make_leaves() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting       = false
	p.amount         = GameData.fx_particles(8)
	p.lifetime       = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2((_vp.x * 0.5) + 120.0, 2.0)
	p.direction      = Vector2(0.35, 1.0)
	p.spread         = 38.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 38.0
	p.gravity        = Vector2(8.0, 7.0)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color          = Color(0.85, 0.45, 0.10, 0.88)
	p.position       = Vector2(_vp.x * 0.5, -30.0)
	_canvas.add_child(p)
	return p
