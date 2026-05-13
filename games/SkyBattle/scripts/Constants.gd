class_name Constants

# ── Tiles ────────────────────────────────────────────────────────────────────
const TILE_SIZE: int = 32
const TILE_DIRT:  int = 0
const TILE_STONE: int = 1
const TILE_WOOD:  int = 2
const TILE_METAL: int = 3
const TILE_GRASS: int = 4

const TILE_HP: Dictionary = {
	0: 30, 1: 80, 2: 20, 3: 120, 4: 15,
}
const TILE_COLORS: Dictionary = {
	0: Color(0.45, 0.32, 0.18),
	1: Color(0.52, 0.52, 0.52),
	2: Color(0.60, 0.40, 0.20),
	3: Color(0.55, 0.55, 0.62),
	4: Color(0.28, 0.62, 0.22),
}

# ── World ─────────────────────────────────────────────────────────────────────
const ISLAND_COUNT: int   = 20
const WORLD_LEFT: float   = -4000.0
const WORLD_RIGHT: float  =  4000.0
const WORLD_TOP: float    = -4000.0
const WORLD_BOTTOM: float =  400.0

# Ground terrain (world-space tile coords, node at origin)
const MAP_WIDTH: int              = 250    # tiles; tile_x -125 to 124
const MAP_HEIGHT: int             = 14     # tiles; world_y 0 to 448
const GROUND_TILE_X_OFFSET: int   = -125   # = int(WORLD_LEFT / TILE_SIZE)
const GROUND_SURFACE_BASE: int    = 2
const GROUND_SURFACE_AMP: int     = 3

# ── Plane ─────────────────────────────────────────────────────────────────────
const PLANE_HEIGHT: float   = -4500.0
const PLANE_SPEED: float    = 260.0
const PLANE_START_X: float  = -4300.0

# ── Player ────────────────────────────────────────────────────────────────────
const PLAYER_SPEED: float         = 230.0
const PLAYER_JUMP_VELOCITY: float = -540.0
const PLAYER_DOUBLE_JUMP: float   = -480.0
const PLAYER_MAX_HP: int          = 100
const PLAYER_MAX_SHIELD: int      = 50
const GRAVITY: float              = 980.0
const COYOTE_TIME: float          = 0.12
const JUMP_BUFFER_TIME: float     = 0.12
const JETPACK_FORCE: float        = -640.0
const JETPACK_FUEL_MAX: float     = 4.0
const JETPACK_BURN_RATE: float    = 1.0
const JETPACK_REFUEL_RATE: float  = 0.5

const FREEFALL_SPEED: float        = 1200.0
const PARACHUTE_FALL_SPEED: float  = 80.0
const PARACHUTE_HORIZ_SPEED: float = 300.0

# ── Physics Layers ────────────────────────────────────────────────────────────
const LAYER_TERRAIN:    int = 1
const LAYER_PLAYER:     int = 2
const LAYER_BOT:        int = 4
const LAYER_PROJECTILE: int = 8
const LAYER_LOOT:       int = 16

# ── Camera ────────────────────────────────────────────────────────────────────
const ZOOM_PLANE:    float = 0.18
const ZOOM_FREEFALL: float = 0.30
const ZOOM_GAMEPLAY: float = 1.0
const ZOOM_LERP:     float = 3.0

# ── Match ─────────────────────────────────────────────────────────────────────
const BOT_COUNT: int              = 11
const ZONE_START_DELAY: float     = 90.0
const ZONE_PHASE_DURATION: float  = 40.0
const ZONE_SHRINK_DURATION: float = 15.0
const ZONE_DMG_PER_SEC: float     = 5.0

# ── Weapons ───────────────────────────────────────────────────────────────────
const WEAPON_DATA: Array = [
	{"id":0,"name":"Pistol",          "damage":28,"fire_rate":0.40,"mag":12,"reload":1.5,"spread":0.04,"auto":false,"speed":1400,"range":900,  "color":Color(0.75,0.75,0.75)},
	{"id":1,"name":"Rifle",           "damage":32,"fire_rate":0.10,"mag":30,"reload":2.0,"spread":0.03,"auto":true, "speed":1600,"range":1200, "color":Color(0.25,0.80,0.25)},
	{"id":2,"name":"Shotgun",         "damage":18,"fire_rate":0.75,"mag":8, "reload":2.5,"spread":0.15,"auto":false,"speed":1200,"range":500,  "color":Color(0.20,0.55,1.00),"pellets":6},
	{"id":3,"name":"SMG",             "damage":18,"fire_rate":0.07,"mag":40,"reload":1.8,"spread":0.06,"auto":true, "speed":1300,"range":700,  "color":Color(0.65,0.18,0.90)},
	{"id":4,"name":"Sniper",          "damage":85,"fire_rate":1.20,"mag":5, "reload":3.0,"spread":0.01,"auto":false,"speed":2400,"range":2500, "color":Color(1.00,0.78,0.10)},
	{"id":5,"name":"GrenadeLauncher", "damage":0, "fire_rate":0.90,"mag":6, "reload":2.5,"spread":0.02,"auto":false,"speed":0,   "range":0,    "color":Color(1.00,0.40,0.10),"explosive":true},
	{"id":6,"name":"Knife",           "damage":45,"fire_rate":0.55,"mag":-1,"reload":0.0,"spread":0.0, "auto":false,"speed":0,   "range":75,   "color":Color(0.85,0.85,0.70),"melee":true},
]
