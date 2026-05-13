extends Node2D

const PLAYER_SCENE = preload("res://scenes/player/Player.tscn")
const BOT_SCENE    = preload("res://scenes/enemies/Bot.tscn")
const HUD_SCENE    = preload("res://scenes/ui/HUD.tscn")
const LOOT_SCENE   = preload("res://scenes/loot/LootPickup.tscn")

var terrain: Terrain       = null
var islands: IslandWorld   = null
var zone: ZoneSystem       = null
var local_player: Player   = null
var hud: CanvasLayer       = null

var _plane_x: float     = Constants.PLANE_START_X
var _plane_active: bool = true

const BOT_NAMES: Array = [
	"Ghost", "Viper", "Storm", "Reaper", "Blaze",
	"Nova", "Hex", "Jinx", "Cobra", "Titan", "Echo"
]

func _ready() -> void:
	_build_world()
	_spawn_loot()
	_spawn_players()
	GameManager.start_match()
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.player_killed.connect(_on_kill)
	_plane_x = Constants.PLANE_START_X
	GameManager.plane_x = _plane_x
	GameManager.plane_phase_active = true

func _build_world() -> void:
	# Ground terrain
	terrain      = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(randi())

	# Floating islands above ground
	islands      = IslandWorld.new()
	islands.name = "IslandWorld"
	add_child(islands)
	islands.generate(randi())

	# Zone
	zone      = ZoneSystem.new()
	zone.name = "Zone"
	add_child(zone)
	zone.setup(Constants.WORLD_LEFT, Constants.WORLD_RIGHT)

func _spawn_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system()) ^ 0xBEEF

	# Loot on islands
	islands.spawn_loot(self, LOOT_SCENE, rng)

	# Loot on ground surface
	var step: float = (Constants.WORLD_RIGHT - Constants.WORLD_LEFT) / 40.0
	for i in range(40):
		if rng.randf() > 0.6:
			continue
		var wx: float = Constants.WORLD_LEFT + step * float(i) + rng.randf_range(0.0, step)
		var wy: float = terrain.get_surface_y_at_world_x(wx) - 20.0
		var loot = LOOT_SCENE.instantiate()
		loot.position = Vector2(wx, wy)
		loot.randomize_loot(rng)
		add_child(loot)

func _spawn_players() -> void:
	# All players start on the plane — they drop at their own time
	local_player             = PLAYER_SCENE.instantiate()
	local_player.name        = "LocalPlayer"
	local_player.player_name = "You"
	local_player.is_local    = true
	local_player.world_ref   = islands
	local_player.terrain_ref = terrain
	local_player.position    = Vector2(_plane_x, Constants.PLANE_HEIGHT)
	add_child(local_player)

	var cam := Camera2D.new()
	cam.name         = "Camera2D"
	cam.zoom         = Vector2(Constants.ZOOM_PLANE, Constants.ZOOM_PLANE)
	cam.limit_left   = int(Constants.WORLD_LEFT  - 400.0)
	cam.limit_right  = int(Constants.WORLD_RIGHT + 400.0)
	cam.limit_top    = int(Constants.PLANE_HEIGHT - 200.0)
	cam.limit_bottom = int(Constants.WORLD_BOTTOM + 400.0)
	local_player.add_child(cam)

	GameManager.register_player(local_player)
	GameManager.local_player = local_player
	local_player.died.connect(_on_local_player_died)

	hud      = HUD_SCENE.instantiate()
	hud.name = "HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(local_player, zone)

	var tc_layer := CanvasLayer.new()
	tc_layer.layer = 10
	tc_layer.name  = "TouchControlsLayer"
	add_child(tc_layer)
	var tc: Node = (load("res://scripts/TouchControls.gd") as GDScript).new()
	tc.name = "TouchControls"
	tc_layer.add_child(tc)
	tc.call("setup", local_player)

	for i in range(Constants.BOT_COUNT):
		var bot             := BOT_SCENE.instantiate()
		bot.name            = "Bot_%d" % i
		bot.player_name     = BOT_NAMES[i % BOT_NAMES.size()]
		bot.world_ref       = islands
		bot.terrain_ref     = terrain
		bot.position        = Vector2(_plane_x, Constants.PLANE_HEIGHT)
		add_child(bot)
		GameManager.register_player(bot)

func _process(delta: float) -> void:
	# Advance plane
	if _plane_active:
		_plane_x += Constants.PLANE_SPEED * delta
		GameManager.plane_x = _plane_x

		if _plane_x > Constants.WORLD_RIGHT + 400.0:
			_end_plane_phase()

		queue_redraw()

	# Zone damage — all alive players
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or not p.is_alive():
			continue
		var ps = p.get("state")
		if ps == Player.State.ONPLANE or ps == Player.State.FREEFALL or ps == Player.State.PARACHUTE:
			continue
		var dmg: float = zone.get_zone_damage(p.position.x)
		if dmg > 0.0:
			p.take_damage(int(dmg * delta), null)

func _end_plane_phase() -> void:
	_plane_active = false
	GameManager.plane_phase_active = false
	# Force-drop anyone still on the plane
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p.get("state") == Player.State.ONPLANE:
			p.force_drop()

func _on_kill(killer: String, victim: String) -> void:
	if hud and hud.has_method("add_kill_feed"):
		hud.add_kill_feed(killer, victim)
	if hud and hud.has_method("update_count"):
		hud.update_count(GameManager.get_alive_count())

func _on_local_player_died() -> void:
	if not is_instance_valid(local_player):
		return
	var cam := local_player.get_node_or_null("Camera2D")
	if not cam:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p.is_alive() and p != local_player:
			local_player.remove_child(cam)
			p.add_child(cam)
			return

func _on_match_ended(winner: String) -> void:
	if hud and hud.has_method("show_winner"):
		hud.show_winner(winner)
	var t := get_tree().create_timer(6.0)
	t.timeout.connect(GameManager.go_to_menu)

# ── Draw plane ────────────────────────────────────────────────────────────────
func _draw() -> void:
	if not _plane_active:
		return
	var px: float = _plane_x
	var py: float = Constants.PLANE_HEIGHT

	# Contrail
	draw_line(Vector2(px - 120.0, py), Vector2(px - 350.0, py + 15.0),
			  Color(1.0, 1.0, 1.0, 0.15), 6.0)

	# Fuselage
	draw_rect(Rect2(px - 70.0, py - 14.0, 140.0, 28.0), Color(0.55, 0.58, 0.68))
	# Nose cone
	var nose_pts := PackedVector2Array([
		Vector2(px + 70.0, py),
		Vector2(px + 110.0, py - 8.0),
		Vector2(px + 70.0, py + 14.0)
	])
	draw_colored_polygon(nose_pts, Color(0.48, 0.52, 0.62))
	# Cockpit
	draw_rect(Rect2(px + 10.0, py - 26.0, 44.0, 18.0), Color(0.35, 0.55, 0.80, 0.9))
	# Wings
	var wing_pts := PackedVector2Array([
		Vector2(px - 20.0, py + 14.0),
		Vector2(px + 30.0, py + 14.0),
		Vector2(px - 10.0, py + 60.0),
		Vector2(px - 50.0, py + 60.0)
	])
	draw_colored_polygon(wing_pts, Color(0.50, 0.53, 0.63))
	# Tail
	var tail_pts := PackedVector2Array([
		Vector2(px - 70.0, py - 14.0),
		Vector2(px - 40.0, py - 14.0),
		Vector2(px - 50.0, py - 38.0),
		Vector2(px - 80.0, py - 38.0)
	])
	draw_colored_polygon(tail_pts, Color(0.50, 0.53, 0.63))

	# Drop path dashed line to ground
	var surface_y: float = terrain.get_surface_y_at_world_x(px)
	var dash_step: float = 40.0
	var y: float = py + 30.0
	while y < surface_y:
		var y2: float = minf(y + dash_step * 0.5, surface_y)
		draw_line(Vector2(px, y), Vector2(px, y2), Color(1.0, 1.0, 0.6, 0.25), 2.0)
		y += dash_step
