extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Each level dict:
#   id, name, zone, world_width, cam_zoom,
#   player_castle: {layout, w, h, mats, hp_mult}
#   enemy_castle:  {layout, w, h, mats, hp_mult}
#   player_bombs (list of available bomb types), player_bomb_count
#   ai_bombs, ai_bomb_count, ai_difficulty (0..1)
#   wind (-1..1), biome, modifiers []
# ─────────────────────────────────────────────────────────────────────────────

static func get_level(id: int) -> Dictionary:
	if id < 1 or id > ALL_LEVELS.size():
		return {}
	# Normalize all keys to plain String (handles &"key" StringName literals)
	var raw: Dictionary = ALL_LEVELS[id - 1]
	var result := {}
	for k in raw:
		result[str(k)] = raw[k]
	return result

static func get_zone_levels(zone_id: int) -> Array:
	var result: Array = []
	for lvl in ALL_LEVELS:
		if lvl["zone_id"] == zone_id:
			result.append(lvl)
	return result

static func total_levels() -> int:
	return ALL_LEVELS.size()

# Helper to build a compact castle config
static func _castle(layout: String, w: int, h: int, mats: Array, hp_mult: float = 1.0) -> Dictionary:
	return {"layout": layout, "w": w, "h": h, "mats": mats, "hp_mult": hp_mult}

# Helper to build a level entry
static func _L(id: int, name: String, zone_id: int, zone: String,
		ww: int, zoom: float,
		pc: Dictionary, ec: Dictionary,
		pbombs: Array, pbcount: int,
		abombs: Array, abcount: int,
		ai_diff: float, wind: float, biome: String,
		mods: Array = []) -> Dictionary:
	return {
		"id": id, "name": name, "zone_id": zone_id, "zone": zone,
		"world_width": ww, "cam_zoom": zoom,
		"player_castle": pc, "enemy_castle": ec,
		"player_bombs": pbombs, "player_bomb_count": pbcount,
		"ai_bombs": abombs, "ai_bomb_count": abcount,
		"ai_difficulty": ai_diff, "wind": wind, "biome": biome,
		"modifiers": mods,
	}

const ALL_LEVELS: Array = [
# ══════════════════════════════════════════════════════════════════════════════
# ZONE 1 — Training Grounds  (1–10)  Wood castles, easy AI, no wind
# ══════════════════════════════════════════════════════════════════════════════
	# id  name                          zid  zone                ww    zoom
	{&"id":1,  &"name":"First Strike",       "zone_id":1,"zone":"Training Grounds","world_width":1920,"cam_zoom":1.0,
	 "player_castle":{"layout":"wall",   "w":3,"h":3,"mats":["wood"],"hp_mult":1.0},
	 "enemy_castle": {"layout":"wall",   "w":3,"h":3,"mats":["wood"],"hp_mult":0.8},
	 "player_bombs":["standard"],"player_bomb_count":10,
	 "ai_bombs":["standard"],"ai_bomb_count":8,
	 "ai_difficulty":0.15,"wind":0.0,"biome":"grassland","modifiers":[]},

	{&"id":2,  &"name":"Crumble Gate",        "zone_id":1,"zone":"Training Grounds","world_width":1920,"cam_zoom":1.0,
	 "player_castle":{"layout":"wall",   "w":3,"h":3,"mats":["wood"],"hp_mult":1.0},
	 "enemy_castle": {"layout":"tower",  "w":2,"h":5,"mats":["wood"],"hp_mult":0.9},
	 "player_bombs":["standard"],"player_bomb_count":9,
	 "ai_bombs":["standard"],"ai_bomb_count":8,
	 "ai_difficulty":0.20,"wind":0.0,"biome":"grassland","modifiers":[]},

	{&"id":3,  &"name":"Timber Fort",         "zone_id":1,"zone":"Training Grounds","world_width":1920,"cam_zoom":1.0,
	 "player_castle":{"layout":"fortress","w":4,"h":3,"mats":["wood"],"hp_mult":1.0},
	 "enemy_castle": {"layout":"wall",   "w":4,"h":3,"mats":["wood"],"hp_mult":1.0},
	 "player_bombs":["standard","heavy"],"player_bomb_count":9,
	 "ai_bombs":["standard"],"ai_bomb_count":8,
	 "ai_difficulty":0.22,"wind":0.0,"biome":"grassland","modifiers":[]},

	{&"id":4,  &"name":"Log Barricade",       "zone_id":1,"zone":"Training Grounds","world_width":1920,"cam_zoom":1.0,
	 "player_castle":{"layout":"wall",   "w":4,"h":3,"mats":["wood"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"bunker", "w":4,"h":2,"mats":["wood","stone"],"hp_mult":1.0},
	 "player_bombs":["standard","heavy"],"player_bomb_count":8,
	 "ai_bombs":["standard"],"ai_bomb_count":8,
	 "ai_difficulty":0.25,"wind":0.0,"biome":"grassland","modifiers":[]},

	{&"id":5,  &"name":"Palisade Rush",       "zone_id":1,"zone":"Training Grounds","world_width":1920,"cam_zoom":1.0,
	 "player_castle":{"layout":"fortress","w":4,"h":4,"mats":["wood"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"fortress","w":4,"h":4,"mats":["wood"],"hp_mult":1.0},
	 "player_bombs":["standard","heavy","splitter"],"player_bomb_count":9,
	 "ai_bombs":["standard","heavy"],"ai_bomb_count":8,
	 "ai_difficulty":0.28,"wind":0.0,"biome":"grassland","modifiers":[]},

	{&"id":6,  &"name":"Twin Towers",         "zone_id":1,"zone":"Training Grounds","world_width":2000,"cam_zoom":0.96,
	 "player_castle":{"layout":"wall",   "w":4,"h":3,"mats":["wood"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"tower",  "w":3,"h":6,"mats":["wood"],"hp_mult":1.1},
	 "player_bombs":["standard","heavy","splitter"],"player_bomb_count":9,
	 "ai_bombs":["standard","heavy"],"ai_bomb_count":8,
	 "ai_difficulty":0.30,"wind":0.0,"biome":"grassland","modifiers":[]},

	{&"id":7,  &"name":"Splinter Point",      "zone_id":1,"zone":"Training Grounds","world_width":2000,"cam_zoom":0.96,
	 "player_castle":{"layout":"fortress","w":5,"h":3,"mats":["wood"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"pyramid","w":5,"h":4,"mats":["wood"],"hp_mult":1.0},
	 "player_bombs":["standard","heavy","splitter","bouncer"],"player_bomb_count":9,
	 "ai_bombs":["standard","heavy"],"ai_bomb_count":9,
	 "ai_difficulty":0.32,"wind":0.0,"biome":"grassland","modifiers":[]},

	{&"id":8,  &"name":"Wood and Stone",      "zone_id":1,"zone":"Training Grounds","world_width":2000,"cam_zoom":0.96,
	 "player_castle":{"layout":"wall",   "w":4,"h":4,"mats":["wood","stone"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"wall",   "w":5,"h":3,"mats":["stone"],"hp_mult":1.0},
	 "player_bombs":["standard","heavy","splitter","bouncer"],"player_bomb_count":9,
	 "ai_bombs":["standard","heavy"],"ai_bomb_count":9,
	 "ai_difficulty":0.33,"wind":0.0,"biome":"village","modifiers":[]},

	{&"id":9,  &"name":"First Defence",       "zone_id":1,"zone":"Training Grounds","world_width":2100,"cam_zoom":0.94,
	 "player_castle":{"layout":"fortress","w":5,"h":4,"mats":["wood","stone"],"hp_mult":1.2},
	 "enemy_castle": {"layout":"fortress","w":5,"h":4,"mats":["stone"],"hp_mult":1.1},
	 "player_bombs":["standard","heavy","splitter","bouncer"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter"],"ai_bomb_count":9,
	 "ai_difficulty":0.36,"wind":0.0,"biome":"village","modifiers":[]},

	{&"id":10, &"name":"Zone 1 Boss",         "zone_id":1,"zone":"Training Grounds","world_width":2100,"cam_zoom":0.94,
	 "player_castle":{"layout":"fortress","w":5,"h":4,"mats":["wood","stone"],"hp_mult":1.2},
	 "enemy_castle": {"layout":"bunker", "w":6,"h":4,"mats":["stone","wood"],"hp_mult":1.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter"],"ai_bomb_count":10,
	 "ai_difficulty":0.40,"wind":0.0,"biome":"village","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 2 — Village Wars  (11–20)  Stone mix, light wind begins
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":11, &"name":"Stone Cold",          "zone_id":2,"zone":"Village Wars","world_width":2100,"cam_zoom":0.94,
	 "player_castle":{"layout":"wall",   "w":4,"h":4,"mats":["stone"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"wall",   "w":4,"h":4,"mats":["stone"],"hp_mult":1.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter"],"ai_bomb_count":10,
	 "ai_difficulty":0.38,"wind":0.05,"biome":"village","modifiers":[]},

	{&"id":12, &"name":"Glass Jaw",           "zone_id":2,"zone":"Village Wars","world_width":2100,"cam_zoom":0.94,
	 "player_castle":{"layout":"fortress","w":4,"h":4,"mats":["stone"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"tower",  "w":3,"h":6,"mats":["glass","stone"],"hp_mult":1.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter"],"ai_bomb_count":10,
	 "ai_difficulty":0.40,"wind":0.08,"biome":"village","modifiers":[]},

	{&"id":13, &"name":"Barrel Alley",        "zone_id":2,"zone":"Village Wars","world_width":2200,"cam_zoom":0.92,
	 "player_castle":{"layout":"wall",   "w":5,"h":4,"mats":["stone","wood"],"hp_mult":1.1},
	 "enemy_castle": {"layout":"wall",   "w":5,"h":4,"mats":["wood","barrel"],"hp_mult":1.1},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter"],"ai_bomb_count":10,
	 "ai_difficulty":0.42,"wind":0.10,"biome":"village","modifiers":["chain_field"]},

	{&"id":14, &"name":"The High Road",       "zone_id":2,"zone":"Village Wars","world_width":2200,"cam_zoom":0.92,
	 "player_castle":{"layout":"pyramid","w":5,"h":5,"mats":["stone"],"hp_mult":1.2},
	 "enemy_castle": {"layout":"pyramid","w":6,"h":5,"mats":["stone"],"hp_mult":1.1},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter","bouncer"],"ai_bomb_count":10,
	 "ai_difficulty":0.43,"wind":0.12,"biome":"village","modifiers":[]},

	{&"id":15, &"name":"Cracked Foundation",  "zone_id":2,"zone":"Village Wars","world_width":2200,"cam_zoom":0.92,
	 "player_castle":{"layout":"fortress","w":5,"h":5,"mats":["stone"],"hp_mult":1.2},
	 "enemy_castle": {"layout":"fortress","w":5,"h":5,"mats":["stone","glass"],"hp_mult":1.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter","bouncer"],"ai_bomb_count":10,
	 "ai_difficulty":0.44,"wind":0.10,"biome":"village","modifiers":[]},

	{&"id":16, &"name":"Catapult Clash",      "zone_id":2,"zone":"Village Wars","world_width":2300,"cam_zoom":0.90,
	 "player_castle":{"layout":"wall",   "w":5,"h":4,"mats":["stone"],"hp_mult":1.2},
	 "enemy_castle": {"layout":"bunker", "w":5,"h":4,"mats":["stone","sandbag"],"hp_mult":1.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter","bouncer"],"ai_bomb_count":11,
	 "ai_difficulty":0.46,"wind":0.12,"biome":"desert","modifiers":[]},

	{&"id":17, &"name":"Sandbag Stronghold",  "zone_id":2,"zone":"Village Wars","world_width":2300,"cam_zoom":0.90,
	 "player_castle":{"layout":"fortress","w":5,"h":4,"mats":["stone"],"hp_mult":1.2},
	 "enemy_castle": {"layout":"fortress","w":5,"h":4,"mats":["stone","sandbag"],"hp_mult":1.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster"],"player_bomb_count":10,
	 "ai_bombs":["standard","heavy","splitter","shockwave"],"ai_bomb_count":11,
	 "ai_difficulty":0.47,"wind":0.14,"biome":"desert","modifiers":[]},

	{&"id":18, &"name":"Rubber Wall",         "zone_id":2,"zone":"Village Wars","world_width":2300,"cam_zoom":0.90,
	 "player_castle":{"layout":"wall",   "w":5,"h":5,"mats":["stone"],"hp_mult":1.3},
	 "enemy_castle": {"layout":"mixed",  "w":5,"h":5,"mats":["stone","rubber"],"hp_mult":1.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster"],"player_bomb_count":11,
	 "ai_bombs":["standard","heavy","splitter","shockwave"],"ai_bomb_count":11,
	 "ai_difficulty":0.48,"wind":0.15,"biome":"desert","modifiers":[]},

	{&"id":19, &"name":"Dusk Raid",           "zone_id":2,"zone":"Village Wars","world_width":2400,"cam_zoom":0.88,
	 "player_castle":{"layout":"fortress","w":5,"h":5,"mats":["stone"],"hp_mult":1.3},
	 "enemy_castle": {"layout":"tower",  "w":3,"h":8,"mats":["stone","sandbag"],"hp_mult":1.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze"],"player_bomb_count":11,
	 "ai_bombs":["standard","heavy","splitter","shockwave"],"ai_bomb_count":11,
	 "ai_difficulty":0.50,"wind":0.18,"biome":"desert","modifiers":[]},

	{&"id":20, &"name":"Zone 2 Stronghold",   "zone_id":2,"zone":"Village Wars","world_width":2400,"cam_zoom":0.88,
	 "player_castle":{"layout":"fortress","w":6,"h":5,"mats":["stone"],"hp_mult":1.3},
	 "enemy_castle": {"layout":"bunker", "w":7,"h":5,"mats":["stone","sandbag"],"hp_mult":1.6},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","splitter","shockwave","cluster"],"ai_bomb_count":12,
	 "ai_difficulty":0.52,"wind":0.20,"biome":"desert","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 3 — Border Conflict  (21–30)  Stone + glass + barrels, medium AI
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":21, &"name":"Glass Ceiling",       "zone_id":3,"zone":"Border Conflict","world_width":2400,"cam_zoom":0.88,
	 "player_castle":{"layout":"fortress","w":5,"h":5,"mats":["stone"],"hp_mult":1.3},
	 "enemy_castle": {"layout":"fortress","w":5,"h":5,"mats":["stone","glass"],"hp_mult":1.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser"],"player_bomb_count":11,
	 "ai_bombs":["standard","heavy","splitter","shockwave","cluster"],"ai_bomb_count":11,
	 "ai_difficulty":0.50,"wind":0.20,"biome":"forest","modifiers":[]},

	{&"id":22, &"name":"Chain Reaction",      "zone_id":3,"zone":"Border Conflict","world_width":2400,"cam_zoom":0.88,
	 "player_castle":{"layout":"wall",   "w":5,"h":5,"mats":["stone"],"hp_mult":1.3},
	 "enemy_castle": {"layout":"mixed",  "w":6,"h":4,"mats":["stone","barrel","explosive_crate"],"hp_mult":1.1},
	 "player_bombs":["standard","heavy","splitter","bouncer","shockwave","cluster","freeze","laser"],"player_bomb_count":11,
	 "ai_bombs":["standard","heavy","shockwave","cluster"],"ai_bomb_count":11,
	 "ai_difficulty":0.52,"wind":0.22,"biome":"forest","modifiers":["chain_field"]},

	{&"id":23, &"name":"Ice Breaker",         "zone_id":3,"zone":"Border Conflict","world_width":2500,"cam_zoom":0.87,
	 "player_castle":{"layout":"wall",   "w":5,"h":5,"mats":["stone"],"hp_mult":1.4},
	 "enemy_castle": {"layout":"wall",   "w":6,"h":4,"mats":["ice_block","stone"],"hp_mult":1.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","shockwave","cluster","freeze","laser","fire"],"player_bomb_count":11,
	 "ai_bombs":["standard","heavy","shockwave","freeze"],"ai_bomb_count":11,
	 "ai_difficulty":0.53,"wind":0.20,"biome":"forest","modifiers":[]},

	{&"id":24, &"name":"Fortress Row",        "zone_id":3,"zone":"Border Conflict","world_width":2500,"cam_zoom":0.87,
	 "player_castle":{"layout":"fortress","w":6,"h":5,"mats":["stone"],"hp_mult":1.4},
	 "enemy_castle": {"layout":"fortress","w":6,"h":5,"mats":["stone","sandbag"],"hp_mult":1.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","shockwave","cluster","freeze","laser","fire"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","freeze"],"ai_bomb_count":12,
	 "ai_difficulty":0.54,"wind":0.22,"biome":"forest","modifiers":[]},

	{&"id":25, &"name":"Crossfire",           "zone_id":3,"zone":"Border Conflict","world_width":2500,"cam_zoom":0.87,
	 "player_castle":{"layout":"pyramid","w":6,"h":5,"mats":["stone"],"hp_mult":1.4},
	 "enemy_castle": {"layout":"pyramid","w":7,"h":6,"mats":["stone"],"hp_mult":1.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","splitter"],"ai_bomb_count":12,
	 "ai_difficulty":0.55,"wind":0.25,"biome":"forest","modifiers":[]},

	{&"id":26, &"name":"Layered Defence",     "zone_id":3,"zone":"Border Conflict","world_width":2600,"cam_zoom":0.86,
	 "player_castle":{"layout":"fortress","w":6,"h":5,"mats":["stone"],"hp_mult":1.5},
	 "enemy_castle": {"layout":"bunker", "w":6,"h":5,"mats":["stone","sandbag","reinforced"],"hp_mult":1.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","splitter"],"ai_bomb_count":12,
	 "ai_difficulty":0.56,"wind":0.25,"biome":"forest","modifiers":[]},

	{&"id":27, &"name":"Burning Ramparts",    "zone_id":3,"zone":"Border Conflict","world_width":2600,"cam_zoom":0.86,
	 "player_castle":{"layout":"wall",   "w":6,"h":5,"mats":["stone"],"hp_mult":1.5},
	 "enemy_castle": {"layout":"wall",   "w":6,"h":5,"mats":["wood","stone","barrel"],"hp_mult":1.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire"],"ai_bomb_count":12,
	 "ai_difficulty":0.57,"wind":0.28,"biome":"forest","modifiers":["chain_field"]},

	{&"id":28, &"name":"Night Assault",       "zone_id":3,"zone":"Border Conflict","world_width":2600,"cam_zoom":0.86,
	 "player_castle":{"layout":"fortress","w":6,"h":5,"mats":["stone"],"hp_mult":1.5},
	 "enemy_castle": {"layout":"mixed",  "w":7,"h":5,"mats":["stone","glass","barrel"],"hp_mult":1.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","freeze"],"ai_bomb_count":12,
	 "ai_difficulty":0.58,"wind":0.30,"biome":"forest","modifiers":[]},

	{&"id":29, &"name":"The Keep",            "zone_id":3,"zone":"Border Conflict","world_width":2700,"cam_zoom":0.85,
	 "player_castle":{"layout":"fortress","w":6,"h":6,"mats":["stone"],"hp_mult":1.5},
	 "enemy_castle": {"layout":"fortress","w":7,"h":6,"mats":["stone","sandbag"],"hp_mult":1.6},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","freeze"],"ai_bomb_count":13,
	 "ai_difficulty":0.60,"wind":0.30,"biome":"mountain","modifiers":[]},

	{&"id":30, &"name":"Zone 3 Citadel",      "zone_id":3,"zone":"Border Conflict","world_width":2700,"cam_zoom":0.85,
	 "player_castle":{"layout":"fortress","w":7,"h":6,"mats":["stone"],"hp_mult":1.6},
	 "enemy_castle": {"layout":"bunker", "w":8,"h":5,"mats":["stone","sandbag","reinforced"],"hp_mult":1.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","freeze","splitter"],"ai_bomb_count":13,
	 "ai_difficulty":0.62,"wind":0.32,"biome":"mountain","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 4 — Mountain Pass  (31–40)  Long range, harder materials, wind picks up
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":31, &"name":"High Altitude",       "zone_id":4,"zone":"Mountain Pass","world_width":2700,"cam_zoom":0.85,
	 "player_castle":{"layout":"wall",   "w":6,"h":5,"mats":["stone","metal"],"hp_mult":1.5},
	 "enemy_castle": {"layout":"wall",   "w":6,"h":5,"mats":["stone","metal"],"hp_mult":1.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning"],"ai_bomb_count":12,
	 "ai_difficulty":0.60,"wind":0.35,"biome":"mountain","modifiers":[]},

	{&"id":32, &"name":"Metal Mind",          "zone_id":4,"zone":"Mountain Pass","world_width":2800,"cam_zoom":0.84,
	 "player_castle":{"layout":"fortress","w":6,"h":5,"mats":["stone","metal"],"hp_mult":1.5},
	 "enemy_castle": {"layout":"tower",  "w":3,"h":9,"mats":["metal"],"hp_mult":1.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning"],"ai_bomb_count":12,
	 "ai_difficulty":0.62,"wind":0.38,"biome":"mountain","modifiers":[]},

	{&"id":33, &"name":"Avalanche Gate",      "zone_id":4,"zone":"Mountain Pass","world_width":2800,"cam_zoom":0.84,
	 "player_castle":{"layout":"pyramid","w":6,"h":5,"mats":["stone","metal"],"hp_mult":1.5},
	 "enemy_castle": {"layout":"pyramid","w":7,"h":6,"mats":["stone","metal"],"hp_mult":1.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning"],"ai_bomb_count":13,
	 "ai_difficulty":0.63,"wind":0.40,"biome":"mountain","modifiers":[]},

	{&"id":34, &"name":"Rocky Ridge",         "zone_id":4,"zone":"Mountain Pass","world_width":2800,"cam_zoom":0.84,
	 "player_castle":{"layout":"bunker", "w":6,"h":4,"mats":["stone","metal"],"hp_mult":1.6},
	 "enemy_castle": {"layout":"bunker", "w":7,"h":4,"mats":["metal","sandbag"],"hp_mult":1.6},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke"],"ai_bomb_count":13,
	 "ai_difficulty":0.64,"wind":0.38,"biome":"mountain","modifiers":[]},

	{&"id":35, &"name":"Windshear",           "zone_id":4,"zone":"Mountain Pass","world_width":2900,"cam_zoom":0.83,
	 "player_castle":{"layout":"fortress","w":6,"h":6,"mats":["stone","metal"],"hp_mult":1.6},
	 "enemy_castle": {"layout":"fortress","w":7,"h":5,"mats":["stone","metal"],"hp_mult":1.6},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost"],"player_bomb_count":12,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","freeze"],"ai_bomb_count":13,
	 "ai_difficulty":0.65,"wind":0.50,"biome":"mountain","modifiers":["high_wind"]},

	{&"id":36, &"name":"Crumble Peak",        "zone_id":4,"zone":"Mountain Pass","world_width":2900,"cam_zoom":0.83,
	 "player_castle":{"layout":"mixed",  "w":6,"h":6,"mats":["stone","metal"],"hp_mult":1.6},
	 "enemy_castle": {"layout":"mixed",  "w":7,"h":6,"mats":["stone","metal","reinforced"],"hp_mult":1.7},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","freeze"],"ai_bomb_count":13,
	 "ai_difficulty":0.66,"wind":0.45,"biome":"mountain","modifiers":[]},

	{&"id":37, &"name":"Glacial Wall",        "zone_id":4,"zone":"Mountain Pass","world_width":2900,"cam_zoom":0.83,
	 "player_castle":{"layout":"wall",   "w":7,"h":5,"mats":["stone","metal"],"hp_mult":1.6},
	 "enemy_castle": {"layout":"wall",   "w":7,"h":6,"mats":["ice_block","metal"],"hp_mult":1.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","freeze"],"ai_bomb_count":13,
	 "ai_difficulty":0.67,"wind":0.42,"biome":"arctic","modifiers":[]},

	{&"id":38, &"name":"Frozen Fortress",     "zone_id":4,"zone":"Mountain Pass","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"fortress","w":7,"h":6,"mats":["stone","metal"],"hp_mult":1.7},
	 "enemy_castle": {"layout":"fortress","w":8,"h":6,"mats":["ice_block","metal","sandbag"],"hp_mult":1.7},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","freeze","nuke"],"ai_bomb_count":13,
	 "ai_difficulty":0.68,"wind":0.45,"biome":"arctic","modifiers":[]},

	{&"id":39, &"name":"Iron Curtain",        "zone_id":4,"zone":"Mountain Pass","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"fortress","w":7,"h":6,"mats":["metal"],"hp_mult":1.7},
	 "enemy_castle": {"layout":"fortress","w":8,"h":6,"mats":["metal","reinforced"],"hp_mult":1.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","freeze","nuke"],"ai_bomb_count":14,
	 "ai_difficulty":0.70,"wind":0.48,"biome":"arctic","modifiers":[]},

	{&"id":40, &"name":"Zone 4 Summit",       "zone_id":4,"zone":"Mountain Pass","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"fortress","w":7,"h":7,"mats":["metal","stone"],"hp_mult":1.8},
	 "enemy_castle": {"layout":"bunker", "w":9,"h":6,"mats":["metal","reinforced","sandbag"],"hp_mult":2.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","freeze","nuke","laser"],"ai_bomb_count":14,
	 "ai_difficulty":0.72,"wind":0.50,"biome":"arctic","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 5 — Desert Siege  (41–50)  Hard AI, strong wind, sand environments
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":41, &"name":"Sand Storm",          "zone_id":5,"zone":"Desert Siege","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"bunker", "w":7,"h":5,"mats":["metal","stone"],"hp_mult":1.8},
	 "enemy_castle": {"layout":"bunker", "w":7,"h":5,"mats":["metal","sandbag"],"hp_mult":1.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser"],"ai_bomb_count":13,
	 "ai_difficulty":0.70,"wind":0.55,"biome":"desert","modifiers":["high_wind"]},

	{&"id":42, &"name":"Mirage Wall",         "zone_id":5,"zone":"Desert Siege","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"pyramid","w":7,"h":6,"mats":["stone","metal"],"hp_mult":1.8},
	 "enemy_castle": {"layout":"pyramid","w":8,"h":6,"mats":["stone","sandbag"],"hp_mult":1.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze"],"ai_bomb_count":13,
	 "ai_difficulty":0.71,"wind":0.52,"biome":"desert","modifiers":[]},

	{&"id":43, &"name":"Desert Fox",          "zone_id":5,"zone":"Desert Siege","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"fortress","w":7,"h":6,"mats":["stone","metal"],"hp_mult":1.9},
	 "enemy_castle": {"layout":"mixed",  "w":8,"h":6,"mats":["stone","metal","barrel"],"hp_mult":1.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze"],"ai_bomb_count":14,
	 "ai_difficulty":0.72,"wind":0.50,"biome":"desert","modifiers":["chain_field"]},

	{&"id":44, &"name":"Scorched Earth",      "zone_id":5,"zone":"Desert Siege","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"wall",   "w":7,"h":6,"mats":["metal","stone"],"hp_mult":1.9},
	 "enemy_castle": {"layout":"wall",   "w":8,"h":7,"mats":["metal","reinforced"],"hp_mult":1.9},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet"],"ai_bomb_count":14,
	 "ai_difficulty":0.73,"wind":0.55,"biome":"desert","modifiers":[]},

	{&"id":45, &"name":"Dust Devil",          "zone_id":5,"zone":"Desert Siege","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"fortress","w":7,"h":7,"mats":["metal","stone"],"hp_mult":2.0},
	 "enemy_castle": {"layout":"fortress","w":8,"h":7,"mats":["metal","reinforced"],"hp_mult":2.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","freeze"],"ai_bomb_count":14,
	 "ai_difficulty":0.74,"wind":0.58,"biome":"desert","modifiers":["high_wind"]},

	{&"id":46, &"name":"Oasis Defence",       "zone_id":5,"zone":"Desert Siege","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"bunker", "w":8,"h":6,"mats":["metal"],"hp_mult":2.0},
	 "enemy_castle": {"layout":"bunker", "w":8,"h":6,"mats":["metal","reinforced"],"hp_mult":2.1},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet"],"ai_bomb_count":14,
	 "ai_difficulty":0.75,"wind":0.55,"biome":"desert","modifiers":[]},

	{&"id":47, &"name":"The Dune Line",       "zone_id":5,"zone":"Desert Siege","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"mixed",  "w":8,"h":6,"mats":["metal","stone"],"hp_mult":2.0},
	 "enemy_castle": {"layout":"mixed",  "w":9,"h":6,"mats":["metal","reinforced","sandbag"],"hp_mult":2.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.76,"wind":0.58,"biome":"desert","modifiers":[]},

	{&"id":48, &"name":"Buried Citadel",      "zone_id":5,"zone":"Desert Siege","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":8,"h":7,"mats":["metal","stone"],"hp_mult":2.1},
	 "enemy_castle": {"layout":"fortress","w":9,"h":7,"mats":["metal","reinforced"],"hp_mult":2.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.77,"wind":0.60,"biome":"desert","modifiers":[]},

	{&"id":49, &"name":"Last Oasis",          "zone_id":5,"zone":"Desert Siege","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":8,"h":7,"mats":["metal"],"hp_mult":2.1},
	 "enemy_castle": {"layout":"tower",  "w":4,"h":12,"mats":["metal","reinforced"],"hp_mult":2.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.78,"wind":0.60,"biome":"desert","modifiers":[]},

	{&"id":50, &"name":"Zone 5 Fortress",     "zone_id":5,"zone":"Desert Siege","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":8,"h":8,"mats":["metal","stone"],"hp_mult":2.2},
	 "enemy_castle": {"layout":"bunker", "w":10,"h":7,"mats":["metal","reinforced","sandbag"],"hp_mult":2.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky"],"ai_bomb_count":15,
	 "ai_difficulty":0.80,"wind":0.62,"biome":"desert","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 6 — Forest Siege  (51–60)  Chain explosives, hard AI, medium-long range
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":51,&"name":"Deep Woods",       "zone_id":6,"zone":"Forest Siege","world_width":2800,"cam_zoom":0.84,
	 "player_castle":{"layout":"fortress","w":7,"h":6,"mats":["metal","stone"],"hp_mult":2.0},
	 "enemy_castle": {"layout":"mixed",  "w":8,"h":6,"mats":["wood","barrel","explosive_crate","stone"],"hp_mult":1.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke"],"ai_bomb_count":13,
	 "ai_difficulty":0.78,"wind":0.30,"biome":"forest","modifiers":["chain_field"]},

	{&"id":52,&"name":"Vine Fortress",    "zone_id":6,"zone":"Forest Siege","world_width":2800,"cam_zoom":0.84,
	 "player_castle":{"layout":"wall",   "w":7,"h":6,"mats":["metal"],"hp_mult":2.0},
	 "enemy_castle": {"layout":"fortress","w":8,"h":6,"mats":["stone","wood","barrel"],"hp_mult":2.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke"],"ai_bomb_count":13,
	 "ai_difficulty":0.79,"wind":0.32,"biome":"forest","modifiers":[]},

	{&"id":53,&"name":"Inferno",          "zone_id":6,"zone":"Forest Siege","world_width":2900,"cam_zoom":0.83,
	 "player_castle":{"layout":"bunker", "w":7,"h":6,"mats":["metal","stone"],"hp_mult":2.1},
	 "enemy_castle": {"layout":"mixed",  "w":8,"h":6,"mats":["wood","barrel","explosive_crate"],"hp_mult":1.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser"],"ai_bomb_count":13,
	 "ai_difficulty":0.80,"wind":0.35,"biome":"forest","modifiers":["chain_field"]},

	{&"id":54,&"name":"Root Network",     "zone_id":6,"zone":"Forest Siege","world_width":2900,"cam_zoom":0.83,
	 "player_castle":{"layout":"pyramid","w":7,"h":7,"mats":["metal","stone"],"hp_mult":2.1},
	 "enemy_castle": {"layout":"pyramid","w":8,"h":7,"mats":["stone","sandbag"],"hp_mult":2.1},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":13,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser"],"ai_bomb_count":14,
	 "ai_difficulty":0.80,"wind":0.35,"biome":"forest","modifiers":[]},

	{&"id":55,&"name":"Canopy Clash",     "zone_id":6,"zone":"Forest Siege","world_width":2900,"cam_zoom":0.83,
	 "player_castle":{"layout":"fortress","w":7,"h":7,"mats":["metal","stone"],"hp_mult":2.2},
	 "enemy_castle": {"layout":"fortress","w":9,"h":7,"mats":["stone","metal","sandbag"],"hp_mult":2.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet"],"ai_bomb_count":14,
	 "ai_difficulty":0.81,"wind":0.38,"biome":"forest","modifiers":[]},

	{&"id":56,&"name":"Bark and Iron",    "zone_id":6,"zone":"Forest Siege","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"fortress","w":8,"h":7,"mats":["metal"],"hp_mult":2.2},
	 "enemy_castle": {"layout":"bunker", "w":9,"h":6,"mats":["stone","reinforced","sandbag"],"hp_mult":2.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet"],"ai_bomb_count":14,
	 "ai_difficulty":0.82,"wind":0.40,"biome":"forest","modifiers":[]},

	{&"id":57,&"name":"Ember Gate",       "zone_id":6,"zone":"Forest Siege","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"wall",   "w":8,"h":7,"mats":["metal","stone"],"hp_mult":2.2},
	 "enemy_castle": {"layout":"wall",   "w":9,"h":7,"mats":["metal","reinforced"],"hp_mult":2.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost"],"ai_bomb_count":14,
	 "ai_difficulty":0.82,"wind":0.42,"biome":"apocalypse","modifiers":[]},

	{&"id":58,&"name":"Ash City",         "zone_id":6,"zone":"Forest Siege","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"mixed",  "w":8,"h":7,"mats":["metal","stone"],"hp_mult":2.3},
	 "enemy_castle": {"layout":"mixed",  "w":9,"h":7,"mats":["metal","reinforced","barrel"],"hp_mult":2.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.83,"wind":0.44,"biome":"apocalypse","modifiers":["chain_field"]},

	{&"id":59,&"name":"Forest King",      "zone_id":6,"zone":"Forest Siege","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"fortress","w":8,"h":8,"mats":["metal","stone"],"hp_mult":2.3},
	 "enemy_castle": {"layout":"fortress","w":9,"h":8,"mats":["metal","reinforced"],"hp_mult":2.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.84,"wind":0.45,"biome":"apocalypse","modifiers":[]},

	{&"id":60,&"name":"Zone 6 Behemoth",  "zone_id":6,"zone":"Forest Siege","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":9,"h":8,"mats":["metal","stone"],"hp_mult":2.4},
	 "enemy_castle": {"layout":"bunker", "w":11,"h":7,"mats":["metal","reinforced","sandbag"],"hp_mult":2.7},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky"],"ai_bomb_count":15,
	 "ai_difficulty":0.85,"wind":0.48,"biome":"apocalypse","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 7 — Arctic Assault  (61–70)  Ice, freeze bombs, very hard AI
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":61,&"name":"Permafrost",       "zone_id":7,"zone":"Arctic Assault","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"fortress","w":8,"h":7,"mats":["metal","stone"],"hp_mult":2.3},
	 "enemy_castle": {"layout":"wall",   "w":9,"h":7,"mats":["ice_block","metal"],"hp_mult":2.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet"],"ai_bomb_count":14,
	 "ai_difficulty":0.82,"wind":0.40,"biome":"arctic","modifiers":[]},

	{&"id":62,&"name":"Ice Tower",        "zone_id":7,"zone":"Arctic Assault","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"bunker", "w":8,"h":7,"mats":["metal"],"hp_mult":2.3},
	 "enemy_castle": {"layout":"tower",  "w":4,"h":10,"mats":["ice_block","metal"],"hp_mult":2.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet"],"ai_bomb_count":14,
	 "ai_difficulty":0.83,"wind":0.42,"biome":"arctic","modifiers":[]},

	{&"id":63,&"name":"Blizzard Raid",    "zone_id":7,"zone":"Arctic Assault","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"pyramid","w":8,"h":7,"mats":["metal","stone"],"hp_mult":2.4},
	 "enemy_castle": {"layout":"pyramid","w":9,"h":7,"mats":["ice_block","sandbag"],"hp_mult":2.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.84,"wind":0.50,"biome":"arctic","modifiers":["high_wind"]},

	{&"id":64,&"name":"Frozen Citadel",   "zone_id":7,"zone":"Arctic Assault","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"fortress","w":8,"h":8,"mats":["metal","stone"],"hp_mult":2.4},
	 "enemy_castle": {"layout":"fortress","w":9,"h":8,"mats":["ice_block","metal","reinforced"],"hp_mult":2.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.84,"wind":0.48,"biome":"arctic","modifiers":[]},

	{&"id":65,&"name":"Polar Siege",      "zone_id":7,"zone":"Arctic Assault","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"wall",   "w":8,"h":8,"mats":["metal"],"hp_mult":2.5},
	 "enemy_castle": {"layout":"bunker", "w":9,"h":7,"mats":["ice_block","metal","reinforced"],"hp_mult":2.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost"],"ai_bomb_count":15,
	 "ai_difficulty":0.85,"wind":0.52,"biome":"arctic","modifiers":[]},

	{&"id":66,&"name":"Frost Cannon",     "zone_id":7,"zone":"Arctic Assault","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":9,"h":8,"mats":["metal","stone"],"hp_mult":2.5},
	 "enemy_castle": {"layout":"mixed",  "w":10,"h":7,"mats":["ice_block","metal","sandbag"],"hp_mult":2.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost","sticky"],"ai_bomb_count":15,
	 "ai_difficulty":0.86,"wind":0.55,"biome":"arctic","modifiers":[]},

	{&"id":67,&"name":"Glacier Wall",     "zone_id":7,"zone":"Arctic Assault","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":9,"h":8,"mats":["metal"],"hp_mult":2.6},
	 "enemy_castle": {"layout":"fortress","w":10,"h":8,"mats":["ice_block","reinforced"],"hp_mult":2.6},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost","sticky"],"ai_bomb_count":15,
	 "ai_difficulty":0.87,"wind":0.58,"biome":"arctic","modifiers":[]},

	{&"id":68,&"name":"Tundra Bastion",   "zone_id":7,"zone":"Arctic Assault","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"bunker", "w":9,"h":8,"mats":["metal","reinforced"],"hp_mult":2.6},
	 "enemy_castle": {"layout":"bunker", "w":10,"h":8,"mats":["metal","reinforced","sandbag"],"hp_mult":2.7},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost","sticky"],"ai_bomb_count":15,
	 "ai_difficulty":0.87,"wind":0.60,"biome":"arctic","modifiers":[]},

	{&"id":69,&"name":"Arctic Command",   "zone_id":7,"zone":"Arctic Assault","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":9,"h":9,"mats":["metal","reinforced"],"hp_mult":2.7},
	 "enemy_castle": {"layout":"fortress","w":10,"h":9,"mats":["metal","reinforced","ice_block"],"hp_mult":2.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.88,"wind":0.62,"biome":"arctic","modifiers":[]},

	{&"id":70,&"name":"Zone 7 Ice Dragon","zone_id":7,"zone":"Arctic Assault","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":9,"h":9,"mats":["metal","reinforced"],"hp_mult":2.8},
	 "enemy_castle": {"layout":"bunker", "w":12,"h":8,"mats":["ice_block","reinforced","metal"],"hp_mult":3.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","freeze","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.90,"wind":0.65,"biome":"arctic","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 8 — Industrial War  (71–80)  Metal, very hard AI, all bomb types active
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":71,&"name":"Steel City",       "zone_id":8,"zone":"Industrial War","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"fortress","w":9,"h":8,"mats":["metal","reinforced"],"hp_mult":2.7},
	 "enemy_castle": {"layout":"fortress","w":10,"h":8,"mats":["metal","reinforced"],"hp_mult":2.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex"],"ai_bomb_count":14,
	 "ai_difficulty":0.88,"wind":0.40,"biome":"apocalypse","modifiers":[]},

	{&"id":72,&"name":"Forge Master",     "zone_id":8,"zone":"Industrial War","world_width":3000,"cam_zoom":0.82,
	 "player_castle":{"layout":"bunker", "w":9,"h":7,"mats":["metal","reinforced"],"hp_mult":2.7},
	 "enemy_castle": {"layout":"tower",  "w":4,"h":13,"mats":["metal","reinforced"],"hp_mult":2.6},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex"],"ai_bomb_count":14,
	 "ai_difficulty":0.89,"wind":0.42,"biome":"apocalypse","modifiers":[]},

	{&"id":73,&"name":"Rivet Rampart",    "zone_id":8,"zone":"Industrial War","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"wall",   "w":9,"h":8,"mats":["metal"],"hp_mult":2.8},
	 "enemy_castle": {"layout":"wall",   "w":10,"h":8,"mats":["reinforced","metal"],"hp_mult":2.9},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.89,"wind":0.44,"biome":"apocalypse","modifiers":[]},

	{&"id":74,&"name":"Molten Core",      "zone_id":8,"zone":"Industrial War","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"pyramid","w":9,"h":8,"mats":["metal","reinforced"],"hp_mult":2.8},
	 "enemy_castle": {"layout":"pyramid","w":10,"h":8,"mats":["reinforced","metal"],"hp_mult":2.9},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":14,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.90,"wind":0.46,"biome":"apocalypse","modifiers":["chain_field"]},

	{&"id":75,&"name":"Iron Maiden",      "zone_id":8,"zone":"Industrial War","world_width":3100,"cam_zoom":0.81,
	 "player_castle":{"layout":"fortress","w":9,"h":9,"mats":["reinforced","metal"],"hp_mult":2.9},
	 "enemy_castle": {"layout":"fortress","w":10,"h":9,"mats":["reinforced","metal"],"hp_mult":3.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.90,"wind":0.48,"biome":"apocalypse","modifiers":[]},

	{&"id":76,&"name":"Rust Storm",       "zone_id":8,"zone":"Industrial War","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":9,"h":9,"mats":["reinforced","metal"],"hp_mult":2.9},
	 "enemy_castle": {"layout":"bunker", "w":11,"h":8,"mats":["reinforced","metal","sandbag"],"hp_mult":3.1},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.91,"wind":0.50,"biome":"apocalypse","modifiers":[]},

	{&"id":77,&"name":"Gear Works",       "zone_id":8,"zone":"Industrial War","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"mixed",  "w":9,"h":9,"mats":["reinforced","metal"],"hp_mult":3.0},
	 "enemy_castle": {"layout":"mixed",  "w":11,"h":8,"mats":["reinforced","metal"],"hp_mult":3.1},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.91,"wind":0.52,"biome":"apocalypse","modifiers":[]},

	{&"id":78,&"name":"The Smelter",      "zone_id":8,"zone":"Industrial War","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":10,"h":9,"mats":["reinforced","metal"],"hp_mult":3.0},
	 "enemy_castle": {"layout":"fortress","w":11,"h":9,"mats":["reinforced","metal"],"hp_mult":3.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.92,"wind":0.55,"biome":"apocalypse","modifiers":[]},

	{&"id":79,&"name":"War Machine",      "zone_id":8,"zone":"Industrial War","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"bunker", "w":10,"h":9,"mats":["reinforced"],"hp_mult":3.1},
	 "enemy_castle": {"layout":"bunker", "w":12,"h":8,"mats":["reinforced","metal"],"hp_mult":3.3},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.92,"wind":0.55,"biome":"apocalypse","modifiers":[]},

	{&"id":80,&"name":"Zone 8 Titan",     "zone_id":8,"zone":"Industrial War","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":10,"h":10,"mats":["reinforced","metal"],"hp_mult":3.2},
	 "enemy_castle": {"layout":"bunker", "w":13,"h":9,"mats":["reinforced","metal"],"hp_mult":3.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","shockwave","cluster","fire","lightning","nuke","laser","magnet","ghost","sticky","vortex","freeze"],"ai_bomb_count":15,
	 "ai_difficulty":0.93,"wind":0.58,"biome":"apocalypse","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 9 — Apocalypse  (81–90)  Everything, expert AI
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":81,&"name":"Hellgate",         "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":10,"h":9,"mats":["reinforced","metal"],"hp_mult":3.2},
	 "enemy_castle": {"layout":"fortress","w":11,"h":9,"mats":["reinforced","metal"],"hp_mult":3.4},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.92,"wind":0.55,"biome":"apocalypse","modifiers":[]},

	{&"id":82,&"name":"Demon Wall",       "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":10,"h":10,"mats":["reinforced","metal"],"hp_mult":3.3},
	 "enemy_castle": {"layout":"wall",   "w":12,"h":10,"mats":["reinforced","metal"],"hp_mult":3.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.92,"wind":0.57,"biome":"apocalypse","modifiers":[]},

	{&"id":83,&"name":"Chaos Engine",     "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"mixed",  "w":10,"h":10,"mats":["reinforced","metal"],"hp_mult":3.3},
	 "enemy_castle": {"layout":"mixed",  "w":12,"h":9,"mats":["reinforced","metal","barrel"],"hp_mult":3.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.93,"wind":0.58,"biome":"apocalypse","modifiers":["chain_field"]},

	{&"id":84,&"name":"Wrath Gate",       "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":10,"h":10,"mats":["reinforced"],"hp_mult":3.4},
	 "enemy_castle": {"layout":"fortress","w":12,"h":10,"mats":["reinforced","metal"],"hp_mult":3.6},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.93,"wind":0.60,"biome":"apocalypse","modifiers":[]},

	{&"id":85,&"name":"Void Seige",       "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"bunker", "w":10,"h":9,"mats":["reinforced","metal"],"hp_mult":3.4},
	 "enemy_castle": {"layout":"bunker", "w":12,"h":9,"mats":["reinforced"],"hp_mult":3.7},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.94,"wind":0.60,"biome":"apocalypse","modifiers":[]},

	{&"id":86,&"name":"Dark Citadel",     "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":10,"h":10,"mats":["reinforced","metal"],"hp_mult":3.5},
	 "enemy_castle": {"layout":"fortress","w":13,"h":10,"mats":["reinforced","metal"],"hp_mult":3.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.94,"wind":0.62,"biome":"apocalypse","modifiers":[]},

	{&"id":87,&"name":"Nightmare Barrage","zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"mixed",  "w":10,"h":10,"mats":["reinforced","metal"],"hp_mult":3.5},
	 "enemy_castle": {"layout":"mixed",  "w":13,"h":10,"mats":["reinforced","metal","sandbag"],"hp_mult":3.9},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.95,"wind":0.64,"biome":"apocalypse","modifiers":["high_wind","chain_field"]},

	{&"id":88,&"name":"Infernal Keep",    "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":11,"h":10,"mats":["reinforced","metal"],"hp_mult":3.6},
	 "enemy_castle": {"layout":"fortress","w":13,"h":10,"mats":["reinforced","metal"],"hp_mult":4.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.95,"wind":0.65,"biome":"apocalypse","modifiers":[]},

	{&"id":89,&"name":"End Times",        "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":11,"h":11,"mats":["reinforced","metal"],"hp_mult":3.7},
	 "enemy_castle": {"layout":"bunker", "w":14,"h":10,"mats":["reinforced","metal"],"hp_mult":4.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.96,"wind":0.65,"biome":"apocalypse","modifiers":[]},

	{&"id":90,&"name":"Zone 9 Omega",     "zone_id":9,"zone":"Apocalypse","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":11,"h":11,"mats":["reinforced","metal"],"hp_mult":3.8},
	 "enemy_castle": {"layout":"bunker", "w":15,"h":10,"mats":["reinforced","metal"],"hp_mult":4.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.97,"wind":0.68,"biome":"apocalypse","modifiers":["boss"]},

# ══════════════════════════════════════════════════════════════════════════════
# ZONE 10 — Legendary  (91–100)  Max difficulty, boss castles
# ══════════════════════════════════════════════════════════════════════════════
	{&"id":91,&"name":"The Reckoning",    "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":11,"h":11,"mats":["reinforced","metal"],"hp_mult":4.0},
	 "enemy_castle": {"layout":"fortress","w":13,"h":11,"mats":["reinforced","metal"],"hp_mult":4.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.96,"wind":0.60,"biome":"apocalypse","modifiers":[]},

	{&"id":92,&"name":"Titan's Gate",     "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":11,"h":12,"mats":["reinforced","metal"],"hp_mult":4.0},
	 "enemy_castle": {"layout":"fortress","w":14,"h":11,"mats":["reinforced","metal"],"hp_mult":4.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.96,"wind":0.62,"biome":"apocalypse","modifiers":[]},

	{&"id":93,&"name":"Fortress Omega",   "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"bunker", "w":12,"h":10,"mats":["reinforced","metal"],"hp_mult":4.1},
	 "enemy_castle": {"layout":"bunker", "w":14,"h":11,"mats":["reinforced","metal"],"hp_mult":5.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.97,"wind":0.63,"biome":"apocalypse","modifiers":[]},

	{&"id":94,&"name":"God of War",       "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":12,"h":11,"mats":["reinforced","metal"],"hp_mult":4.2},
	 "enemy_castle": {"layout":"fortress","w":14,"h":12,"mats":["reinforced","metal"],"hp_mult":5.2},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.97,"wind":0.64,"biome":"apocalypse","modifiers":[]},

	{&"id":95,&"name":"Warlord's Keep",   "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":12,"h":11,"mats":["reinforced","metal"],"hp_mult":4.3},
	 "enemy_castle": {"layout":"mixed",  "w":15,"h":11,"mats":["reinforced","metal"],"hp_mult":5.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.97,"wind":0.65,"biome":"apocalypse","modifiers":["chain_field"]},

	{&"id":96,&"name":"The Colossus",     "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":12,"h":12,"mats":["reinforced","metal"],"hp_mult":4.4},
	 "enemy_castle": {"layout":"bunker", "w":15,"h":12,"mats":["reinforced","metal"],"hp_mult":5.8},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.98,"wind":0.65,"biome":"apocalypse","modifiers":[]},

	{&"id":97,&"name":"Last Stand",       "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":12,"h":12,"mats":["reinforced","metal"],"hp_mult":4.5},
	 "enemy_castle": {"layout":"fortress","w":15,"h":12,"mats":["reinforced","metal"],"hp_mult":6.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.98,"wind":0.68,"biome":"apocalypse","modifiers":["high_wind"]},

	{&"id":98,&"name":"Eternal Siege",    "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":12,"h":12,"mats":["reinforced","metal"],"hp_mult":4.6},
	 "enemy_castle": {"layout":"fortress","w":16,"h":12,"mats":["reinforced","metal"],"hp_mult":6.5},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.98,"wind":0.70,"biome":"apocalypse","modifiers":["boss"]},

	{&"id":99,&"name":"Doomsday",         "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":12,"h":13,"mats":["reinforced","metal"],"hp_mult":4.8},
	 "enemy_castle": {"layout":"bunker", "w":16,"h":13,"mats":["reinforced","metal"],"hp_mult":7.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":0.99,"wind":0.72,"biome":"apocalypse","modifiers":["boss","chain_field","high_wind"]},

	{&"id":100,&"name":"Fort Fury FINAL", "zone_id":10,"zone":"Legendary","world_width":3200,"cam_zoom":0.80,
	 "player_castle":{"layout":"fortress","w":12,"h":13,"mats":["reinforced","metal"],"hp_mult":5.0},
	 "enemy_castle": {"layout":"bunker", "w":18,"h":13,"mats":["reinforced","metal"],"hp_mult":8.0},
	 "player_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"player_bomb_count":15,
	 "ai_bombs":["standard","heavy","splitter","bouncer","driller","shockwave","cluster","freeze","laser","fire","lightning","nuke","magnet","ghost","sticky","vortex"],"ai_bomb_count":15,
	 "ai_difficulty":1.0,"wind":0.75,"biome":"apocalypse","modifiers":["boss","chain_field","high_wind"]},
]
