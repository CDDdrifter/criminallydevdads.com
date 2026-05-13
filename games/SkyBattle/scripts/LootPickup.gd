extends Area2D

enum LootType { WEAPON, JETPACK, MEDKIT, SHIELD }

var display_name: String    = "Item"
var loot_type: LootType     = LootType.WEAPON
var loot_data: Dictionary   = {}
var _bob_offset: float      = 0.0

func _ready() -> void:
	collision_layer = Constants.LAYER_LOOT
	collision_mask  = 0
	add_to_group("loot")
	# Random bob phase
	_bob_offset = randf() * TAU

func _process(delta: float) -> void:
	queue_redraw()

func randomize_loot(rng: RandomNumberGenerator) -> void:
	var roll: int = rng.randi() % 10
	if roll == 0:
		loot_type    = LootType.JETPACK
		display_name = "Fuel Canister"
		loot_data    = {}
	elif roll <= 2:
		loot_type    = LootType.MEDKIT
		display_name = "Medkit (+50 HP)"
		loot_data    = {"amount": 50}
	elif roll == 3:
		loot_type    = LootType.SHIELD
		display_name = "Shield Cell"
		loot_data    = {"amount": 25}
	else:
		loot_type = LootType.WEAPON
		var idx: int = rng.randi() % Constants.WEAPON_DATA.size()
		loot_data    = Constants.WEAPON_DATA[idx].duplicate()
		display_name = loot_data.get("name", "Weapon")

func collect(player: Node) -> void:
	if not is_instance_valid(player):
		return
	match loot_type:
		LootType.WEAPON:
			if player.has_method("pickup_weapon"):
				player.pickup_weapon(loot_data)
		LootType.JETPACK:
			if player.has_method("refuel_jetpack"):
				player.refuel_jetpack()
		LootType.MEDKIT:
			if player.has_method("heal"):
				player.heal(loot_data.get("amount", 50))
		LootType.SHIELD:
			if player.has_method("add_shield"):
				player.add_shield(loot_data.get("amount", 25))
	queue_free()

func _draw() -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var bob: float = sin(t * 2.5 + _bob_offset) * 3.0

	match loot_type:
		LootType.WEAPON:
			var wc: Color = loot_data.get("color", Color(0.7, 0.7, 0.7)) if not loot_data.is_empty() else Color(0.7, 0.7, 0.7)
			draw_rect(Rect2(-10.0, -8.0 + bob, 20.0, 16.0), wc)
			draw_rect(Rect2(-10.0, -8.0 + bob, 20.0, 16.0), Color.WHITE, false, 1.5)
			# Barrel
			draw_rect(Rect2(8.0, -3.0 + bob, 8.0, 6.0), wc.darkened(0.2))
		LootType.JETPACK:
			draw_rect(Rect2(-7.0, -14.0 + bob, 14.0, 24.0), Color(0.45, 0.50, 0.65))
			draw_circle(Vector2(0.0, -18.0 + bob), 4.0, Color(0.70, 0.75, 0.90))
			draw_circle(Vector2(-4.0, 12.0 + bob), 4.0, Color(1.0, 0.45, 0.1, 0.7 + sin(t * 8.0) * 0.3))
			draw_circle(Vector2(4.0,  12.0 + bob), 4.0, Color(1.0, 0.45, 0.1, 0.7 + sin(t * 8.0 + 1.0) * 0.3))
		LootType.MEDKIT:
			draw_rect(Rect2(-10.0, -10.0 + bob, 20.0, 20.0), Color(0.75, 0.12, 0.12))
			draw_rect(Rect2(-2.5, -8.0 + bob, 5.0, 16.0), Color.WHITE)
			draw_rect(Rect2(-8.0, -2.5 + bob, 16.0, 5.0), Color.WHITE)
		LootType.SHIELD:
			draw_circle(Vector2(0.0, bob), 10.0, Color(0.25, 0.55, 1.0, 0.4))
			draw_arc(Vector2(0.0, bob), 10.0, 0.0, TAU, 16, Color(0.35, 0.65, 1.0), 2.5)

	# Glow ring
	var glow: float = 0.18 + 0.10 * sin(t * 3.0)
	draw_arc(Vector2(0.0, bob), 14.0, 0.0, TAU, 16, Color(1.0, 1.0, 0.85, glow), 1.5)

	# Name tag
	draw_string(ThemeDB.fallback_font, Vector2(-22.0, -26.0 + bob),
				display_name, HORIZONTAL_ALIGNMENT_LEFT, 44, 9,
				Color(1.0, 1.0, 1.0, 0.80))
