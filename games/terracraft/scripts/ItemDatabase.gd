## ItemDatabase.gd — Global singleton (Autoload)
## ─────────────────────────────────────────────────────────────────────────────
## THE MASTER REGISTRY of every item, block, tool, food, armor, and resource
## in TerraCraft.  This file is registered as an Autoload in Project Settings
## under the name "ItemDB", so every other script can call ItemDB.get_item("stone")
## from anywhere without any extra setup.
##
## ─────────────────────────────────────────────────────────────────────────────
##  ARCHITECTURE OVERVIEW
## ─────────────────────────────────────────────────────────────────────────────
##  Everything is stored in one large Dictionary called `items`.
##  The key is the item's string ID (e.g. "ruby_ore", "diamond_pick").
##  The value is a nested Dictionary containing all of that item's properties.
##
##  Other scripts read from this file via the helper functions at the bottom
##  (get_item, get_drop, has_tile, get_tile_atlas_coords, etc.).
##  They NEVER access `items` directly — always use a helper.
##
## ─────────────────────────────────────────────────────────────────────────────
##  HOW THE TILE SYSTEM WORKS (important background)
## ─────────────────────────────────────────────────────────────────────────────
##  The game renders blocks using a TileMapLayer with a single large texture
##  called an "atlas".  The atlas is a 256×256 pixel image divided into a
##  16×16 grid of 16×16 pixel tiles (16 columns, 16 rows).
##
##  Every block entry has a "tile_id" field: Vector2i(column, row).
##  This tells the TileMapLayer exactly which square of the atlas to display.
##
##  The atlas itself is GENERATED AT RUNTIME by TileTextureGenerator.gd using
##  procedural pixel-art drawing routines.  You can REPLACE any tile with a
##  real PNG file — see TileTextureGenerator.gd for the override path.
##
## ─────────────────────────────────────────────────────────────────────────────
##  COMPLETE STEP-BY-STEP: HOW TO ADD A NEW BLOCK (e.g. "Ruby Ore")
## ─────────────────────────────────────────────────────────────────────────────
##
##  STEP 1 — Add the ore block entry to `items` in this file.
##    Copy the "diamond_ore" entry and change the values:
##      "ruby_ore": {
##        "name": "Ruby Ore", "type": "block",
##        "icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "square",
##        "max_stack": 99, "placeable": true, "tile_id": Vector2i(5, 2),
##        "edible": false, "food_value": 0, "damage": 0,
##        "tool_speed": 1.0, "tool_type": "pick", "mine_level": 4,
##        "drop_item": "ruby", "drop_count": 1
##      },
##    The tile_id Vector2i(5, 2) means column 5, row 2 of the atlas.
##    Pick any UNUSED atlas cell — check TileTextureGenerator.ATLAS_LAYOUT to see
##    which cells are already taken (ruby_ore already uses column 5 row 2).
##
##  STEP 2 — Add the drop item ("ruby") to `items` in this file.
##    Copy the "diamond" entry:
##      "ruby": {
##        "name": "Ruby", "type": "material",
##        "icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "diamond",
##        "max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
##        ...
##      },
##    tile_id = Vector2i(-1,-1) means "no world tile" — it's inventory-only.
##
##  STEP 3 — Register the atlas appearance in TileTextureGenerator.gd.
##    In the ATLAS_LAYOUT array, add:
##      ["ruby_ore", 5, 2, "ore"],
##    "ore" is the draw style — it draws a stone base with coloured dots.
##    Also add to TILE_COLORS:
##      "ruby_ore": Color(0.502, 0.502, 0.502),   # stone base colour
##    And add to ORE_COLORS:
##      "ruby_ore": Color(0.878, 0.118, 0.220),   # the bright red dot colour
##    (These are already present in TileTextureGenerator.gd for ruby_ore.)
##
##  STEP 4 — Make the ore generate in the world.
##    In WorldGenerator.gd, add an entry to ORE_RULES:
##      { "id": "ruby_ore", "min_depth": 150, "max_depth": 255, "rarity": 0.08 },
##    (Already present — ruby_ore is a working example.)
##
##  STEP 5 — Optionally add a crafting recipe.
##    In CraftingSystem.gd, find the RECIPES array and add an entry.
##    Example (ruby pickaxe): { "result": "ruby_pick", "count": 1,
##      "ingredients": {"ruby": 3, "stick": 2} }
##
##  STEP 6 — Optionally add a custom PNG texture.
##    Drop a 16×16 PNG at:  res://assets/tiles/ruby_ore.png
##    The generator will use your PNG instead of the procedural drawing.
##    For the inventory icon, use:  res://assets/items/ruby.png
##
##  THAT IS EVERYTHING.  No other files need changing for a new ore block.
##
## ─────────────────────────────────────────────────────────────────────────────
##  HOW TO ADD A NEW TOOL WITH DURABILITY, MINING SPEED, AND TIER
## ─────────────────────────────────────────────────────────────────────────────
##  Tools follow the same pattern — they are just items with extra fields.
##  To add e.g. a "ruby_pick" (Ruby Pickaxe):
##
##  1. Add this entry to `items` (copy "diamond_pick" and change values):
##       "ruby_pick": {
##         "name": "Ruby Pickaxe", "type": "tool",
##         "icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "pick",
##         "max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
##         "edible": false, "food_value": 0, "damage": 12,
##         "tool_speed": 6.0,    # ← higher = mines faster (diamond is 5.0)
##         "tool_type": "pick",  # ← "pick" mines stone/ores; "axe" for wood; "shovel" for dirt
##         "mine_level": 5,      # ← 5 = ruby tier; blocks with mine_level <= 5 can be mined
##         "drop_item": null, "drop_count": 0,
##         "durability": 2000    # ← how many uses before it breaks
##       },
##
##  2. In CraftingSystem.gd, add the recipe so the player can craft it.
##
##  FIELD MEANINGS FOR TOOLS:
##    tool_speed  — multiplier applied to the base mining time.
##                  1.0 = bare hand speed.  diamond_pick is 5.0 (5× faster).
##                  Increasing this makes the tool mine faster.
##    mine_level  — the MINIMUM mine_level this tool satisfies.
##                  A block with mine_level: 4 needs a tool with mine_level >= 4.
##                  Tier mapping:  0=hand  1=wood  2=stone  3=iron  4=diamond  5+=custom
##    durability  — total uses before the tool breaks and is removed from inventory.
##                  Stored on the item stack in inventory, decremented by Player.gd
##                  each time a block is mined or an enemy is hit.
##                  Missing "durability" key = unbreakable (e.g. bare hands).
##
## ─────────────────────────────────────────────────────────────────────────────
##  HOW TO SWAP A TILE TEXTURE FOR A REAL PNG SPRITE
## ─────────────────────────────────────────────────────────────────────────────
##  The tile atlas is generated procedurally but any tile can be overridden:
##
##  FOR WORLD TILES (what you see placed in the world):
##    Create a 16×16 PNG and save it to:
##      res://assets/tiles/{tile_id}.png
##    Example: res://assets/tiles/ruby_ore.png
##    The TileTextureGenerator.generate_atlas() method checks this path first.
##    If the file exists, it blits your PNG directly and skips procedural drawing.
##
##  FOR INVENTORY ICONS (hotbar, inventory screen):
##    Create any size PNG and save it to:
##      res://assets/items/{item_id}.png
##    Example: res://assets/items/ruby.png
##    TileTextureGenerator.get_icon() checks this path and scales to 16×16.
##
##  PRIORITY ORDER:
##    1. res://assets/items/{id}.png  (your custom art — highest priority)
##    2. Atlas crop from tile_id      (for placeable blocks)
##    3. Procedural shape drawing     (built-in fallback)
##
## ─────────────────────────────────────────────────────────────────────────────
##  WHICH OTHER SCRIPTS CARE ABOUT THIS FILE
## ─────────────────────────────────────────────────────────────────────────────
##  Chunk.gd          — calls has_tile() and get_tile_atlas_coords() to render tiles
##  WorldGenerator.gd — uses string IDs (e.g. "ruby_ore") which must exist here
##  Player.gd         — calls get_tool_speed(), get_mine_level(), get_drop() for mining
##  Inventory.gd      — calls get_item() to display item names/icons in the UI
##  CraftingSystem.gd — references item IDs in recipe definitions
##  TileTextureGenerator.gd — reads tile_id to know atlas coords; reads icon_color for fallback
##
## ─────────────────────────────────────────────────────────────────────────────
##  GOTCHAS / ORDERING RULES
## ─────────────────────────────────────────────────────────────────────────────
##  • String IDs are case-sensitive.  "Ruby_Ore" != "ruby_ore".  Use snake_case.
##  • Every placeable block MUST have a valid tile_id (not Vector2i(-1,-1)).
##    If you forget, Chunk.gd will log a warning and the tile will be invisible.
##  • Two items cannot share the same tile_id; they would look identical in-world.
##  • The mine_level on a BLOCK is the MINIMUM level required to collect it.
##    The mine_level on a TOOL is the level that tool PROVIDES.
##    Player.gd checks:  tool.mine_level >= block.mine_level   to allow mining.
##  • drop_item: null means "drop nothing" (e.g. ice, glass pane).
##    drop_item omitted or missing also drops nothing — use null explicitly.
##  • drop_count can be a plain int (always that many) or [min, max] Array
##    (random range, inclusive).  get_drop() handles both forms.
##  • Adding a new block here does NOT make it generate in the world — you must
##    also add it to WorldGenerator.ORE_RULES (for ores) or write a placement
##    function in WorldGenerator._place_surface_decor() (for surface blocks).
## ─────────────────────────────────────────────────────────────────────────────

extends Node

# ─────────────────────────────────────────────
#  ITEM FIELD GUIDE  (quick reference)
# ─────────────────────────────────────────────
# name        — display name shown in UI (e.g. hotbar tooltip, inventory slot)
# type        — category string: "block" | "tool" | "weapon" | "food" | "material" | "armor"
#               Controls which UI slot it appears in and what actions are available.
# icon_color  — Color(r, g, b) used when drawing the procedural icon.
#               Does NOT affect the world tile — that comes from tile_id + TileTextureGenerator.
#               Override with res://assets/items/{id}.png to use real art.
# icon_shape  — hint for procedural icon drawing in TileTextureGenerator._draw_item_icon():
#               "square"  → solid block face      (used for most blocks)
#               "circle"  → round shape           (foods, gems, saplings)
#               "diamond" → rhombus/gem shape     (raw materials, ingots)
#               "sword"   → blade outline         (swords, sticks, arrows)
#               "axe"     → axe head outline      (axes)
#               "pick"    → pickaxe head outline  (pickaxes)
# max_stack   — how many of this item fit in one inventory slot.
#               0 = cannot be picked up / stored (e.g. water, lava).
#               1 = no stacking (tools, weapons, armor).
#               16, 64, 99 = normal stacking amounts.
# placeable   — true if the player can place this from inventory into the world.
#               If true, tile_id MUST be a valid Vector2i (not -1,-1).
# tile_id     — Vector2i(atlas_column, atlas_row) of this tile in the 256×256 atlas.
#               Must match an entry in TileTextureGenerator.ATLAS_LAYOUT.
#               Set to Vector2i(-1,-1) for items that are never placed in the world.
# edible      — true if the player can right-click to eat this item.
# food_value  — hunger points restored on eating (0–100; player max hunger is 100).
# damage      — melee damage dealt to enemies per hit (0 if not a weapon/tool).
#               Also used for contact damage on cactus/lava blocks.
# tool_speed  — mining speed multiplier when this item is the active hotbar slot.
#               1.0 = bare hand (baseline).  wood=1.5  stone=2.0  iron=3.0  diamond=5.0
#               Applied as:  actual_mine_time = base_time / tool_speed
# tool_type   — which block category this tool is effective against:
#               "pick"   → stone, ores, bricks (mine_level check also applies)
#               "axe"    → logs, planks, wooden blocks
#               "shovel" → dirt, sand, gravel, snow
#               "sword"  → deals bonus damage to enemies
#               null     → no bonus; uses bare-hand speed on all blocks
# mine_level  — DUAL MEANING depending on whether this is a block or a tool:
#               On a BLOCK: minimum level tool required to collect it.
#                 0 = breakable by bare hands
#                 1 = needs any pickaxe (wood or better)
#                 2 = needs stone pickaxe or better
#                 3 = needs iron pickaxe or better
#                 4 = needs diamond pickaxe or better
#                 99 = indestructible (water, lava, bedrock)
#               On a TOOL:  the level this tool provides (must be >= block's mine_level).
# drop_item   — String ID of the item that drops when this block is broken.
#               null = drops nothing.
#               Use the same ID as the block to make it drop itself (e.g. "cobblestone").
#               Use a different ID to drop a refined item (e.g. "coal_ore" → "coal").
# drop_count  — number of items to drop.  Can be:
#               int  → always that many (e.g. 1)
#               Array[int, int] → random between min and max inclusive (e.g. [1, 3])
# durability  — (tools/weapons only) total uses before the item breaks and disappears.
#               Omit this key to make the item unbreakable.
# light_radius — (light blocks only) radius of the light glow in tiles.
# light_color  — (light blocks only) Color of the emitted light.
# bonus_max_health — (armor only) extra max HP while equipped.
# bonus_armor      — (armor only) damage reduction fraction (0.0–1.0).
# bonus_speed      — (armor only) movement speed bonus in pixels/sec.
# bonus_mining_speed — (armor/arms only) extra tool_speed bonus while equipped.
# ─────────────────────────────────────────────

## `items` — the master registry Dictionary.
## Key   = unique string ID used everywhere in code (snake_case, e.g. "ruby_ore").
## Value = Dictionary of properties.  See the field guide above.
##
## ORDERING NOTE: ordering within this Dictionary does not matter for gameplay.
## Entries are grouped by category for readability only.
var items: Dictionary = {

	# ══════════════════════════════════════════════════════════════════════════
	#  NATURAL BLOCKS
	#  These are the blocks that make up the world terrain.
	#  WorldGenerator.gd places them during chunk generation.
	#  Most are mineable by hand or with basic tools.
	# ══════════════════════════════════════════════════════════════════════════

	# "air" is a special sentinel entry.  Air tiles are NOT stored in Chunk._tile_data
	# (absent key = air), so this entry is here only so code can look it up safely.
	# max_stack: 0 and placeable: false means it can never appear in inventory or be placed.
	"air": {
		"name": "Air", "type": "block",
		"icon_color": Color(0, 0, 0, 0), "icon_shape": "square",
		"max_stack": 0, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	# Dirt — the most common shallow block; fills the layer just below the grass surface.
	# tool_type "shovel" means shovels mine it faster, but bare hands still work (mine_level 0).
	# drop_item "dirt" = drops itself when broken.
	"dirt": {
		"name": "Dirt", "type": "block",
		"icon_color": Color(0.55, 0.37, 0.2), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "dirt", "drop_count": 1
	},
	# Grass — the top surface layer in non-desert/snow biomes.
	# Note: drop_item is "dirt", NOT "grass" — breaking grass yields dirt, not grass.
	# To change this (e.g. make grass drop itself), change drop_item to "grass".
	"grass": {
		"name": "Grass Block", "type": "block",
		"icon_color": Color(0.3, 0.65, 0.2), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "dirt", "drop_count": 1
	},
	# Stone — the main underground block.  Requires any pickaxe (mine_level 1).
	# drop_item "cobblestone" means mining stone gives cobblestone, not stone.
	# This is intentional — stone blocks can only be obtained with Silk Touch (not implemented).
	# TO CHANGE: set drop_item to "stone" if you want mining stone to give stone directly.
	"stone": {
		"name": "Stone", "type": "block",
		"icon_color": Color(0.55, 0.55, 0.55), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(2, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "cobblestone", "drop_count": 1
	},
	# Cobblestone — the "mined stone" resource, used for crafting tools and building.
	# mine_level 1 = any pickaxe can mine it.
	"cobblestone": {
		"name": "Cobblestone", "type": "block",
		"icon_color": Color(0.45, 0.45, 0.45), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(3, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "cobblestone", "drop_count": 1
	},
	# Sand — surface block in desert biomes.  Also fills beaches near water.
	"sand": {
		"name": "Sand", "type": "block",
		"icon_color": Color(0.93, 0.87, 0.6), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(4, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "sand", "drop_count": 1
	},
	# Gravel — can drop flint randomly (handled by World.mine_block special-case logic).
	"gravel": {
		"name": "Gravel", "type": "block",
		"icon_color": Color(0.5, 0.48, 0.45), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(5, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "gravel", "drop_count": 1
	},
	# Water — cannot be picked up normally; use a bucket_empty to collect.
	# mine_level 99 = effectively indestructible (no tool can "mine" water).
	# max_stack 0 = cannot exist in inventory directly.
	# damage 0 here — drowning damage is handled separately in Player.gd.
	"water": {
		"name": "Water", "type": "block",
		"icon_color": Color(0.2, 0.5, 0.9, 0.7), "icon_shape": "square",
		"max_stack": 0, "placeable": false, "tile_id": Vector2i(6, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 99,
		"drop_item": null, "drop_count": 0
	},
	# Lava — damages the player on contact (damage: 5 per second, applied by World.gd).
	# Like water, it cannot be mined directly.
	"lava": {
		"name": "Lava", "type": "block",
		"icon_color": Color(1.0, 0.3, 0.0, 0.9), "icon_shape": "square",
		"max_stack": 0, "placeable": false, "tile_id": Vector2i(7, 0),
		"edible": false, "food_value": 0, "damage": 5,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 99,
		"drop_item": null, "drop_count": 0
	},
	# Bedrock — the absolute floor of the world.  Totally indestructible.
	# WorldGenerator.gd places it on the bottom 3 rows of every chunk.
	# mine_level 99 ensures no tool can ever break it.
	"bedrock": {
		"name": "Bedrock", "type": "block",
		"icon_color": Color(0.15, 0.15, 0.15), "icon_shape": "square",
		"max_stack": 0, "placeable": false, "tile_id": Vector2i(8, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 99,
		"drop_item": null, "drop_count": 0
	},
	"snow": {
		"name": "Snow", "type": "block",
		"icon_color": Color(0.92, 0.95, 1.0), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(9, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "snow", "drop_count": 1
	},
	"ice": {
		"name": "Ice", "type": "block",
		"icon_color": Color(0.7, 0.85, 1.0, 0.8), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(10, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": null, "drop_count": 0   # melts, drops nothing
	},
	"clay": {
		"name": "Clay", "type": "block",
		"icon_color": Color(0.7, 0.7, 0.75), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(11, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "clay_ball", "drop_count": 4
	},
	"clay_ball": {
		"name": "Clay Ball", "type": "material",
		"icon_color": Color(0.7, 0.7, 0.75), "icon_shape": "circle",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},

	# ══════════════════════════════════════════════════════════════════════════
	#  WOOD & PLANTS
	#  Logs, leaves, saplings, planks.  Placed by WorldGenerator tree functions.
	#  Leaves have tool_speed 0.3 (slow) because they aren't really "mined".
	#  drop_count [0, 1] means leaves have a 50% chance of dropping a sapling
	#  (the actual range is handled by get_drop() which calls randi_range).
	#  bonus_drop_item / bonus_drop_chance let leaves also drop apples (20% chance).
	# ══════════════════════════════════════════════════════════════════════════

	"log_oak": {
		"name": "Oak Log", "type": "block",
		"icon_color": Color(0.55, 0.38, 0.18), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "log_oak", "drop_count": 1
	},
	"log_birch": {
		"name": "Birch Log", "type": "block",
		"icon_color": Color(0.85, 0.82, 0.7), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "log_birch", "drop_count": 1
	},
	"log_pine": {
		"name": "Pine Log", "type": "block",
		"icon_color": Color(0.35, 0.22, 0.1), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(2, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "log_pine", "drop_count": 1
	},
	"leaves_oak": {
		"name": "Oak Leaves", "type": "block",
		"icon_color": Color(0.2, 0.6, 0.15, 0.9), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(3, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.3, "tool_type": "axe", "mine_level": 0,
		"drop_item": "sapling_oak", "drop_count": [0, 1],
		"bonus_drop_item": "apple", "bonus_drop_chance": 0.2,
	},
	"leaves_birch": {
		"name": "Birch Leaves", "type": "block",
		"icon_color": Color(0.55, 0.75, 0.25, 0.9), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(4, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.3, "tool_type": "axe", "mine_level": 0,
		"drop_item": "sapling_birch", "drop_count": [0, 1]
	},
	"leaves_pine": {
		"name": "Pine Leaves", "type": "block",
		"icon_color": Color(0.1, 0.4, 0.1, 0.9), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(5, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.3, "tool_type": "axe", "mine_level": 0,
		"drop_item": "sapling_pine", "drop_count": [0, 1]
	},
	"sapling_oak": {
		"name": "Oak Sapling", "type": "block",
		"icon_color": Color(0.2, 0.7, 0.2), "icon_shape": "circle",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(3, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.5, "tool_type": null, "mine_level": 0,
		"drop_item": "sapling_oak", "drop_count": 1
	},
	"sapling_birch": {
		"name": "Birch Sapling", "type": "block",
		"icon_color": Color(0.6, 0.8, 0.3), "icon_shape": "circle",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(4, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.5, "tool_type": null, "mine_level": 0,
		"drop_item": "sapling_birch", "drop_count": 1
	},
	"sapling_pine": {
		"name": "Pine Sapling", "type": "block",
		"icon_color": Color(0.1, 0.4, 0.1), "icon_shape": "circle",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(5, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.5, "tool_type": null, "mine_level": 0,
		"drop_item": "sapling_pine", "drop_count": 1
	},
	"planks_oak": {
		"name": "Oak Planks", "type": "block",
		"icon_color": Color(0.75, 0.6, 0.3), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(6, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "planks_oak", "drop_count": 1
	},
	"planks_birch": {
		"name": "Birch Planks", "type": "block",
		"icon_color": Color(0.9, 0.85, 0.65), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(7, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "planks_birch", "drop_count": 1
	},
	"stick": {
		"name": "Stick", "type": "material",
		"icon_color": Color(0.6, 0.4, 0.15),
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 1,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},

	# ══════════════════════════════════════════════════════════════════════════
	#  ORE BLOCKS  (generated underground by WorldGenerator.ORE_RULES)
	# ──────────────────────────────────────────────────────────────────────────
	#  All ores follow the same pattern:
	#    - type "block", placeable true
	#    - tile_id in atlas row 2 (row index 2 = third row)
	#    - tool_type "pick" (pickaxes only)
	#    - mine_level >= 1 (bare hands cannot collect ore)
	#    - drop_item points to the raw material that drops
	#
	#  TO ADD A NEW ORE:
	#    1. Add an entry here (copy ruby_ore below as template).
	#    2. Pick an unused atlas cell for tile_id.
	#    3. Add the same tile_id to TileTextureGenerator.ATLAS_LAYOUT (style "ore").
	#    4. Add the ore color to TileTextureGenerator.ORE_COLORS.
	#    5. Add a rule to WorldGenerator.ORE_RULES with depth range and rarity.
	#    6. Add the drop item entry (the gem/ingot) below in RAW MATERIALS.
	#
	#  mine_level reference:  1=wood pick  2=stone pick  3=iron pick  4=diamond pick
	# ══════════════════════════════════════════════════════════════════════════

	"coal_ore": {
		"name": "Coal Ore", "type": "block",
		"icon_color": Color(0.2, 0.2, 0.2), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 2),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "coal", "drop_count": [1, 3]
	},
	"iron_ore": {
		"name": "Iron Ore", "type": "block",
		"icon_color": Color(0.8, 0.6, 0.4), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 2),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "iron_ore", "drop_count": 1
	},
	"gold_ore": {
		"name": "Gold Ore", "type": "block",
		"icon_color": Color(1.0, 0.85, 0.1), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(2, 2),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 3,
		"drop_item": "gold_ore", "drop_count": 1
	},
	"diamond_ore": {
		"name": "Diamond Ore", "type": "block",
		"icon_color": Color(0.2, 0.9, 0.9), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(3, 2),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 4,
		"drop_item": "diamond", "drop_count": [1, 2]
	},
	"emerald_ore": {
		"name": "Emerald Ore", "type": "block",
		"icon_color": Color(0.1, 0.8, 0.3), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(4, 2),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 4,
		"drop_item": "emerald", "drop_count": 1
	},
	# ── RUBY ORE — a complete worked example of adding a new ore ─────────────
	# This entry was added as a template to show exactly what every field does.
	# WorldGenerator.ORE_RULES already has a matching rule for this ore:
	#   { "id": "ruby_ore", "min_depth": 150, "max_depth": 255, "rarity": 0.08 }
	# which means ruby ore spawns 150–255 tiles below the surface, with 8% probability
	# at each eligible stone tile.  That makes it rarer than diamond (0.1 at 120–250).
	#
	# tile_id Vector2i(5, 2):  column 5, row 2 of the atlas — already registered in
	# TileTextureGenerator.ATLAS_LAYOUT as ["ruby_ore", 5, 2, "ore"].
	# The "ore" draw style draws a stone-grey square with bright red dots (ORE_COLORS["ruby_ore"]).
	#
	# mine_level: 4 = requires a diamond pickaxe or better.
	# drop_item: "ruby" = breaking this block gives 1 ruby gem (defined below).
	#
	# TO ADD YOUR OWN ORE: copy this entire block, change "ruby_ore" to your ID,
	# change all the values, pick an atlas column/row that isn't used yet, and
	# follow the 5-step process in the file header comments above.
	"ruby_ore": {
		"name": "Ruby Ore", "type": "block",
		"icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(5, 2),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 4,
		"drop_item": "ruby", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  RAW MATERIALS / GEMS / INGOTS
	# ══════════════════════════════════════

	"coal": {
		"name": "Coal", "type": "material",
		"icon_color": Color(0.15, 0.15, 0.15), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"charcoal": {
		"name": "Charcoal", "type": "material",
		"icon_color": Color(0.22, 0.18, 0.14), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"iron_ingot": {
		"name": "Iron Ingot", "type": "material",
		"icon_color": Color(0.75, 0.75, 0.75), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"gold_ingot": {
		"name": "Gold Ingot", "type": "material",
		"icon_color": Color(1.0, 0.9, 0.0), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"diamond": {
		"name": "Diamond", "type": "material",
		"icon_color": Color(0.2, 0.9, 0.9), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"emerald": {
		"name": "Emerald", "type": "material",
		"icon_color": Color(0.1, 0.8, 0.3), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"ruby": {
		"name": "Ruby", "type": "material",
		"icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"flint": {
		"name": "Flint", "type": "material",
		"icon_color": Color(0.3, 0.3, 0.35), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 2,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"string": {
		"name": "String", "type": "material",
		"icon_color": Color(0.9, 0.9, 0.9),
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"bone": {
		"name": "Bone", "type": "material",
		"icon_color": Color(0.95, 0.93, 0.85),
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 3,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"shadow_essence": {
		"name": "Shadow Essence", "type": "material",
		"icon_color": Color(0.18, 0.05, 0.28), "icon_shape": "circle",
		"max_stack": 32, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0,
		"description": "Dropped by Shadow enemies. Used in dark crafting.",
	},
	"wool": {
		"name": "Wool", "type": "material",
		"icon_color": Color(0.95, 0.95, 0.95), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(8, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": "wool", "drop_count": 1
	},
	"feather": {
		"name": "Feather", "type": "material",
		"icon_color": Color(0.95, 0.95, 0.95), "icon_shape": "circle",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"leather": {
		"name": "Leather", "type": "material",
		"icon_color": Color(0.6, 0.35, 0.15), "icon_shape": "square",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},

	# ══════════════════════════════════════
	#  FOOD
	# ══════════════════════════════════════

	"apple": {
		"name": "Apple", "type": "food",
		"icon_color": Color(0.9, 0.1, 0.1), "icon_shape": "circle",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 15, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"raw_beef": {
		"name": "Raw Beef", "type": "food",
		"icon_color": Color(0.7, 0.3, 0.2), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 5, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"cooked_beef": {
		"name": "Cooked Beef", "type": "food",
		"icon_color": Color(0.6, 0.25, 0.05), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 40, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"raw_pork": {
		"name": "Raw Pork", "type": "food",
		"icon_color": Color(0.9, 0.65, 0.6), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 5, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"cooked_pork": {
		"name": "Cooked Pork", "type": "food",
		"icon_color": Color(0.8, 0.45, 0.2), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 35, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"raw_chicken": {
		"name": "Raw Chicken", "type": "food",
		"icon_color": Color(0.95, 0.85, 0.7), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 4, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"cooked_chicken": {
		"name": "Cooked Chicken", "type": "food",
		"icon_color": Color(0.85, 0.65, 0.2), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 30, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"mutton_raw": {
		"name": "Raw Mutton", "type": "food",
		"icon_color": Color(0.8, 0.4, 0.35), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 4, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"mutton_cooked": {
		"name": "Cooked Mutton", "type": "food",
		"icon_color": Color(0.65, 0.3, 0.1), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 32, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"bread": {
		"name": "Bread", "type": "food",
		"icon_color": Color(0.85, 0.65, 0.25), "icon_shape": "square",
		"max_stack": 16, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 25, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"rotten_flesh": {
		"name": "Rotten Flesh", "type": "food",
		"icon_color": Color(0.45, 0.25, 0.15), "icon_shape": "square",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": true, "food_value": 3, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"spider_eye": {
		"name": "Spider Eye", "type": "material",
		"icon_color": Color(0.6, 0.1, 0.1), "icon_shape": "circle",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"slime_ball": {
		"name": "Slime Ball", "type": "material",
		"icon_color": Color(0.3, 0.8, 0.3), "icon_shape": "circle",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"arrow": {
		"name": "Arrow", "type": "material",
		"icon_color": Color(0.7, 0.6, 0.4),
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 4,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"wheat": {
		"name": "Wheat", "type": "material",
		"icon_color": Color(0.9, 0.8, 0.3),
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"wheat_seeds": {
		# Obtained by breaking tall grass.  Plant on dirt or grass to grow wheat.
		"name": "Wheat Seeds", "type": "block",
		"icon_color": Color(0.4, 0.75, 0.25), "icon_shape": "circle",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(6, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.1, "tool_type": null, "mine_level": 0,
		"drop_item": "wheat_seeds", "drop_count": 1
	},
	"wheat_crop": {
		# Grown from planted wheat seeds after ~30 seconds.
		# Breaking it yields wheat + extra seeds (handled by World.mine_block).
		"name": "Wheat Crop", "type": "block",
		"icon_color": Color(0.88, 0.75, 0.18), "icon_shape": "square",
		"max_stack": 0, "placeable": false, "tile_id": Vector2i(7, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.1, "tool_type": null, "mine_level": 0,
		"drop_item": "wheat", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  TOOLS  (wood tier)
	# ══════════════════════════════════════

	"wood_pick": {
		"name": "Wooden Pickaxe", "type": "tool",
		"icon_color": Color(0.75, 0.6, 0.3), "icon_shape": "pick",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 3,
		"tool_speed": 1.5, "tool_type": "pick", "mine_level": 1,
		"drop_item": null, "drop_count": 0,
		"durability": 60
	},
	"wood_axe": {
		"name": "Wooden Axe", "type": "tool",
		"icon_color": Color(0.75, 0.6, 0.3), "icon_shape": "axe",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 4,
		"tool_speed": 2.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": null, "drop_count": 0,
		"durability": 60
	},
	# ─────────────────────────────────────────────────────────────────────────
	# MASTER WEAPON SPRITESHEET — master_weapon.png
	# ─────────────────────────────────────────────────────────────────────────
	# atlas_id: "weapons"  →  registered in TileTextureGenerator.SPRITE_ATLASES
	# atlas_coords: Vector2i(col, row) — 32×32 px cells, origin at top-left
	#
	# CURRENT LAYOUT (row 2 of master_weapon.png):
	#   col  0 → wood sword         col  1 → stone sword
	#   col  2 → stone pickaxe      col  3 → stone axe
	#   col  4 → spear              col  5 → iron axe
	#   col  6 → iron sword         col  7 → battle axe (ruby axe)
	#   col  8 → heavy pickaxe      col  9 → iron pickaxe
	#   col 10 → arrow              col 11 → fancy battle axe
	#   col 12 → double pick        col 13 → diamond pickaxe
	#   col 14 → diamond sword      col 15 → katana
	#
	# HOW TO ADJUST / EXTEND:
	#   • If a weapon cell is wrong, change "atlas_coords" here — no other file needed.
	#   • Items with a res://assets/items/{id}.png take priority over atlas coords.
	#   • To add a new weapon row or biome sheet, see TileTextureGenerator.SPRITE_ATLASES.
	# ─────────────────────────────────────────────────────────────────────────

	"wood_sword": {
		"name": "Wooden Sword", "type": "weapon",
		"icon_color": Color(0.75, 0.6, 0.3), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 6,
		"tool_speed": 1.0, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 60,
		"atlas_id": "weapons", "atlas_coords": Vector2i(0, 2),
	},
	"wood_shovel": {
		"name": "Wooden Shovel", "type": "tool",
		"icon_color": Color(0.75, 0.6, 0.3), "icon_shape": "shovel",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 2,
		"tool_speed": 2.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 60,
	},

	"stone_shovel": {
		"name": "Stone Shovel", "type": "tool",
		"icon_color": Color(0.55, 0.55, 0.55), "icon_shape": "shovel",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 4,
		"tool_speed": 3.0, "tool_type": "shovel", "mine_level": 1,
		"drop_item": null, "drop_count": 0, "durability": 132,
	},

	# ══════════════════════════════════════
	#  TOOLS  (stone tier)
	# ══════════════════════════════════════

	"stone_pick": {
		"name": "Stone Pickaxe", "type": "tool",
		"icon_color": Color(0.55, 0.55, 0.55), "icon_shape": "pick",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 5,
		"tool_speed": 2.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": null, "drop_count": 0, "durability": 132,
		"atlas_id": "weapons", "atlas_coords": Vector2i(2, 2),
	},
	"stone_axe": {
		"name": "Stone Axe", "type": "tool",
		"icon_color": Color(0.55, 0.55, 0.55), "icon_shape": "axe",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 7,
		"tool_speed": 2.5, "tool_type": "axe", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 132,
		"atlas_id": "weapons", "atlas_coords": Vector2i(3, 2),
	},
	"stone_sword": {
		"name": "Stone Sword", "type": "weapon",
		"icon_color": Color(0.55, 0.55, 0.55), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 10,
		"tool_speed": 1.0, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 132,
		"atlas_id": "weapons", "atlas_coords": Vector2i(1, 2),
	},

	# ══════════════════════════════════════
	#  TOOLS  (iron tier)
	# ══════════════════════════════════════

	"iron_axe": {
		"name": "Iron Axe", "type": "tool",
		"icon_color": Color(0.75, 0.75, 0.75), "icon_shape": "axe",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 10,
		"tool_speed": 3.5, "tool_type": "axe", "mine_level": 3,
		"drop_item": null, "drop_count": 0, "durability": 251,
		"atlas_id": "weapons", "atlas_coords": Vector2i(5, 2),
	},
	"iron_shovel": {
		"name": "Iron Shovel", "type": "tool",
		"icon_color": Color(0.75, 0.75, 0.75), "icon_shape": "shovel",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 5,
		"tool_speed": 4.0, "tool_type": "shovel", "mine_level": 3,
		"drop_item": null, "drop_count": 0, "durability": 251,
	},
	"iron_pick": {
		"name": "Iron Pickaxe", "type": "tool",
		"icon_color": Color(0.75, 0.75, 0.75), "icon_shape": "pick",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 7,
		"tool_speed": 3.0, "tool_type": "pick", "mine_level": 3,
		"drop_item": null, "drop_count": 0, "durability": 251,
		"atlas_id": "weapons", "atlas_coords": Vector2i(9, 2),
	},
	"iron_sword": {
		"name": "Iron Sword", "type": "weapon",
		"icon_color": Color(0.75, 0.75, 0.75), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 15,
		"tool_speed": 1.0, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 251,
		"atlas_id": "weapons", "atlas_coords": Vector2i(6, 2),
	},

	# ══════════════════════════════════════
	#  TOOLS  (gold tier)
	# ══════════════════════════════════════
	"gold_pick": {
		"name": "Gold Pickaxe", "type": "tool",
		"icon_color": Color(1.0, 0.85, 0.10), "icon_shape": "pick",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 9,
		"tool_speed": 4.5, "tool_type": "pick", "mine_level": 3,
		"drop_item": null, "drop_count": 0, "durability": 250,
	},
	"gold_axe": {
		"name": "Gold Axe", "type": "tool",
		"icon_color": Color(1.0, 0.85, 0.10), "icon_shape": "axe",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 11,
		"tool_speed": 4.0, "tool_type": "axe", "mine_level": 2,
		"drop_item": null, "drop_count": 0, "durability": 250,
	},
	"gold_shovel": {
		"name": "Gold Shovel", "type": "tool",
		"icon_color": Color(1.0, 0.85, 0.10), "icon_shape": "shovel",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 7,
		"tool_speed": 5.0, "tool_type": "shovel", "mine_level": 2,
		"drop_item": null, "drop_count": 0, "durability": 250,
	},

	# ══════════════════════════════════════
	#  TOOLS  (diamond tier)
	# ══════════════════════════════════════
	"diamond_pick": {
		"name": "Diamond Pickaxe", "type": "tool",
		"icon_color": Color(0.2, 0.9, 0.9), "icon_shape": "pick",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 10,
		"tool_speed": 5.0, "tool_type": "pick", "mine_level": 4,
		"drop_item": null, "drop_count": 0, "durability": 1562,
		"atlas_id": "weapons", "atlas_coords": Vector2i(13, 2),
	},
	"diamond_axe": {
		"name": "Diamond Axe", "type": "tool",
		"icon_color": Color(0.2, 0.9, 0.9), "icon_shape": "axe",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 14,
		"tool_speed": 5.5, "tool_type": "axe", "mine_level": 4,
		"drop_item": null, "drop_count": 0, "durability": 1562,
	},
	"diamond_shovel": {
		"name": "Diamond Shovel", "type": "tool",
		"icon_color": Color(0.2, 0.9, 0.9), "icon_shape": "shovel",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 8,
		"tool_speed": 6.0, "tool_type": "shovel", "mine_level": 4,
		"drop_item": null, "drop_count": 0, "durability": 1562,
	},
	"diamond_sword": {
		"name": "Diamond Sword", "type": "weapon",
		"icon_color": Color(0.2, 0.9, 0.9), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 25,
		"tool_speed": 1.0, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 1562,
		"atlas_id": "weapons", "atlas_coords": Vector2i(14, 2),
	},

	# ══════════════════════════════════════
	#  TOOLS  (ruby tier)
	# ══════════════════════════════════════
	"ruby_pick": {
		"name": "Ruby Pickaxe", "type": "tool",
		"icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "pick",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 13,
		"tool_speed": 6.5, "tool_type": "pick", "mine_level": 5,
		"drop_item": null, "drop_count": 0, "durability": 2000,
	},
	"ruby_axe": {
		"name": "Ruby Axe", "type": "tool",
		"icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "axe",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 16,
		"tool_speed": 7.0, "tool_type": "axe", "mine_level": 5,
		"drop_item": null, "drop_count": 0, "durability": 2000,
		"atlas_id": "weapons", "atlas_coords": Vector2i(7, 2),
	},
	"ruby_shovel": {
		"name": "Ruby Shovel", "type": "tool",
		"icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "shovel",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 10,
		"tool_speed": 7.5, "tool_type": "shovel", "mine_level": 5,
		"drop_item": null, "drop_count": 0, "durability": 2000,
	},
	"ruby_sword": {
		"name": "Ruby Sword", "type": "weapon",
		"icon_color": Color(0.9, 0.1, 0.2), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 32,
		"tool_speed": 1.0, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 2000,
	},

	# ══════════════════════════════════════
	#  TOOLS  (emerald tier)
	# ══════════════════════════════════════
	"emerald_pick": {
		"name": "Emerald Pickaxe", "type": "tool",
		"icon_color": Color(0.1, 0.8, 0.3), "icon_shape": "pick",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 12,
		"tool_speed": 6.0, "tool_type": "pick", "mine_level": 5,
		"drop_item": null, "drop_count": 0, "durability": 1800,
	},
	"emerald_axe": {
		"name": "Emerald Axe", "type": "tool",
		"icon_color": Color(0.1, 0.8, 0.3), "icon_shape": "axe",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 15,
		"tool_speed": 6.5, "tool_type": "axe", "mine_level": 5,
		"drop_item": null, "drop_count": 0, "durability": 1800,
	},
	"emerald_shovel": {
		"name": "Emerald Shovel", "type": "tool",
		"icon_color": Color(0.1, 0.8, 0.3), "icon_shape": "shovel",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 9,
		"tool_speed": 7.0, "tool_type": "shovel", "mine_level": 5,
		"drop_item": null, "drop_count": 0, "durability": 1800,
	},
	"emerald_sword": {
		"name": "Emerald Sword", "type": "weapon",
		"icon_color": Color(0.1, 0.8, 0.3), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 30,
		"tool_speed": 1.0, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 1800,
	},

	# ══════════════════════════════════════
	#  WEAPONS — Katana
	# ══════════════════════════════════════
	"katana": {
		"name": "Katana", "type": "weapon",
		"icon_color": Color(0.88, 0.88, 0.95), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 20,
		"attack_speed": 2.0, "tool_type": "katana", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 400,
		"atlas_id": "weapons", "atlas_coords": Vector2i(15, 2),
	},
	"gold_sword": {
		"name": "Gold Sword", "type": "weapon",
		"icon_color": Color(1.0, 0.85, 0.1), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 18,
		"attack_speed": 1.4, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 200,
	},

	# ══════════════════════════════════════
	#  WEAPONS — Special Melee
	# ══════════════════════════════════════
	"shadow_blade": {
		"name": "Shadow Blade", "type": "weapon",
		"icon_color": Color(0.2, 0.05, 0.35), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 28,
		"attack_speed": 1.8, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 900,
		"description": "Dark energy infused blade. Fast strikes.",
	},
	"war_hammer": {
		"name": "War Hammer", "type": "weapon",
		"icon_color": Color(0.55, 0.45, 0.35), "icon_shape": "hammer",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 45,
		"attack_speed": 0.8, "tool_type": "sword", "mine_level": 3,
		"drop_item": null, "drop_count": 0, "durability": 1200,
		"description": "Slow but devastating two-hander. Breaks blocks faster too.",
	},
	"twin_daggers": {
		"name": "Twin Daggers", "type": "weapon",
		"icon_color": Color(0.8, 0.8, 0.9), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 14,
		"attack_speed": 3.5, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 500,
		"description": "Dual blades — very fast low-damage combo.",
	},
	"spear": {
		"name": "Spear", "type": "weapon",
		"icon_color": Color(0.7, 0.7, 0.65), "icon_shape": "spear",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 22,
		"attack_speed": 1.5, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 700,
		"atlas_id": "weapons", "atlas_coords": Vector2i(4, 2),
		"description": "Long reach, stab style.",
	},
	"flail": {
		"name": "Flail", "type": "weapon",
		"icon_color": Color(0.6, 0.55, 0.5), "icon_shape": "hammer",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 30,
		"attack_speed": 1.2, "tool_type": "sword", "mine_level": 0,
		"drop_item": null, "drop_count": 0, "durability": 800,
		"description": "Swinging weapon. Unpredictable arc.",
	},

	# ══════════════════════════════════════
	#  WEAPONS — Ranged / Guns
	#  tool_type = "gun" → triggers shoot animations and shoot_fire on attack
	#  "fire_rate" = attacks per second when held
	#  "projectile_speed" = px/s (used by future projectile system)
	# ══════════════════════════════════════
	"wood_bow": {
		"name": "Wooden Bow", "type": "weapon",
		"icon_color": Color(0.65, 0.45, 0.2), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 8,
		"attack_speed": 0.8, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 0.8, "projectile_speed": 500.0, "ammo": "arrow",
		"drop_item": null, "drop_count": 0,
		"durability": 80
	},
	"iron_bow": {
		"name": "Iron Bow", "type": "weapon",
		"icon_color": Color(0.75, 0.75, 0.8), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 14,
		"attack_speed": 1.0, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 1.0, "projectile_speed": 600.0, "ammo": "arrow",
		"drop_item": null, "drop_count": 0,
		"durability": 250
	},
	"crossbow": {
		"name": "Crossbow", "type": "weapon",
		"icon_color": Color(0.6, 0.4, 0.2), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 22,
		"attack_speed": 0.6, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 0.6, "projectile_speed": 700.0, "ammo": "arrow",
		"drop_item": null, "drop_count": 0,
		"durability": 300
	},
	"pistol": {
		"name": "Pistol", "type": "weapon",
		"icon_color": Color(0.3, 0.3, 0.35), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 18,
		"attack_speed": 1.5, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 1.5, "projectile_speed": 900.0, "ammo": "bullet",
		"drop_item": null, "drop_count": 0,
		"durability": 350
	},
	"rifle": {
		"name": "Rifle", "type": "weapon",
		"icon_color": Color(0.25, 0.25, 0.3), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 32,
		"attack_speed": 1.0, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 1.0, "projectile_speed": 1100.0, "ammo": "bullet",
		"drop_item": null, "drop_count": 0,
		"durability": 500
	},
	"shotgun": {
		"name": "Shotgun", "type": "weapon",
		"icon_color": Color(0.4, 0.35, 0.3), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 45,
		"attack_speed": 0.5, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 0.5, "projectile_speed": 800.0, "ammo": "bullet",
		"drop_item": null, "drop_count": 0,
		"durability": 300
	},
	"machine_gun": {
		"name": "Machine Gun", "type": "weapon",
		"icon_color": Color(0.2, 0.2, 0.25), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 12,
		"attack_speed": 5.0, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 5.0, "projectile_speed": 1000.0, "ammo": "bullet",
		"drop_item": null, "drop_count": 0,
		"durability": 600
	},
	"flamethrower": {
		"name": "Flamethrower", "type": "weapon",
		"icon_color": Color(1.0, 0.45, 0.1), "icon_shape": "sword",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 8,
		"attack_speed": 6.0, "tool_type": "gun", "mine_level": 0,
		"fire_rate": 6.0, "projectile_speed": 400.0, "ammo": "fuel",
		"drop_item": null, "drop_count": 0,
		"durability": 500
	},

	# ── Ammo items ─────────────────────────────────────────────────────────
	"bullet": {
		"name": "Bullet", "type": "ammo",
		"icon_color": Color(0.7, 0.6, 0.2), "icon_shape": "circle",
		"max_stack": 99, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0,
		"durability": -1
	},
	"fuel": {
		"name": "Fuel", "type": "ammo",
		"icon_color": Color(0.9, 0.5, 0.1), "icon_shape": "circle",
		"max_stack": 99, "placeable": false, "tile_id": Vector2i(-1,-1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0,
		"durability": -1
	},

	# ══════════════════════════════════════
	#  BIOME / DECORATION BLOCKS
	# ══════════════════════════════════════

	"snow_grass": {
		# Grass block with snow on top — used on the surface in snow biomes
		"name": "Snowy Grass", "type": "block",
		"icon_color": Color(0.85, 0.90, 0.95), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "dirt", "drop_count": 1
	},
	"tall_grass": {
		# Decorative tall grass — placed on plains grass surface tiles
		# Breaking tall grass has a chance to drop wheat seeds.
		"name": "Tall Grass", "type": "block",
		"icon_color": Color(0.35, 0.70, 0.25, 0.8), "icon_shape": "square",
		"max_stack": 99, "placeable": false, "tile_id": Vector2i(1, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.1, "tool_type": null, "mine_level": 0,
		"drop_item": "wheat_seeds", "drop_count": [0, 1]
	},
	"cactus": {
		# Desert decoration — damages player on contact (add Area2D logic)
		"name": "Cactus", "type": "block",
		"icon_color": Color(0.2, 0.55, 0.15), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(2, 3),
		"edible": false, "food_value": 0, "damage": 1,
		"tool_speed": 0.5, "tool_type": null, "mine_level": 0,
		"drop_item": "cactus", "drop_count": 1
	},
	"snow_block": {
		# Solid snow block (different from the thin snow layer "snow")
		"name": "Snow Block", "type": "block",
		"icon_color": Color(0.93, 0.96, 1.0), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(9, 0),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "snow_block", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  LIGHT / UTILITY BLOCKS
	# ══════════════════════════════════════

	"torch": {
		"name": "Torch", "type": "block",
		"icon_color": Color(1.0, 0.85, 0.2), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(9, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": "torch", "drop_count": 1,
		"light_radius": 8.0, "light_color": Color(1.0, 0.85, 0.4, 1.0)
	},
	"campfire": {
		"name": "Campfire", "type": "block",
		"icon_color": Color(1.0, 0.4, 0.0), "icon_shape": "square",
		"max_stack": 1, "placeable": true, "tile_id": Vector2i(10, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "campfire", "drop_count": 1,
		"light_radius": 10.0, "light_color": Color(1.0, 0.5, 0.1, 1.0)
	},
	"chest": {
		"name": "Chest", "type": "block",
		"icon_color": Color(0.7, 0.5, 0.2), "icon_shape": "square",
		"max_stack": 1, "placeable": true, "tile_id": Vector2i(11, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "chest", "drop_count": 1
	},
	"crafting_table": {
		"name": "Crafting Table", "type": "block",
		"icon_color": Color(0.65, 0.42, 0.18), "icon_shape": "square",
		"max_stack": 1, "placeable": true, "tile_id": Vector2i(12, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "crafting_table", "drop_count": 1
	},
	"furnace": {
		"name": "Furnace", "type": "block",
		"icon_color": Color(0.4, 0.4, 0.4), "icon_shape": "square",
		"max_stack": 1, "placeable": true, "tile_id": Vector2i(13, 1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "furnace", "drop_count": 1
	},

	# ══════════════════════════════════════════════════════════════════════
	#  FURNITURE & UTILITY BLOCKS
	# ══════════════════════════════════════════════════════════════════════

	"bed": {
		"name": "Bed", "type": "block",
		"icon_color": Color(0.85, 0.20, 0.20), "icon_shape": "square",
		"max_stack": 1, "placeable": true, "tile_id": Vector2i(8, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "bed", "drop_count": 1,
	},
	"crystal_gate": {
		"name": "Crystal Gate", "type": "block",
		"icon_color": Color(0.70, 0.95, 1.00), "icon_shape": "square",
		"max_stack": 4, "placeable": true, "tile_id": Vector2i(9, 3),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.8, "tool_type": "pick", "mine_level": 0,
		"drop_item": "crystal_gate", "drop_count": 1,
	},

	# ══════════════════════════════════════
	#  STONE / BRICK VARIANTS
	# ══════════════════════════════════════

	"stone_brick": {
		"name": "Stone Brick", "type": "block",
		"icon_color": Color(0.42, 0.42, 0.42), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "stone_brick", "drop_count": 1
	},
	"mossy_stone_brick": {
		"name": "Mossy Stone Brick", "type": "block",
		"icon_color": Color(0.31, 0.42, 0.29), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "mossy_stone_brick", "drop_count": 1
	},
	"cracked_stone_brick": {
		"name": "Cracked Stone Brick", "type": "block",
		"icon_color": Color(0.38, 0.38, 0.38), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(2, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "cracked_stone_brick", "drop_count": 1
	},
	"chiseled_stone": {
		"name": "Chiseled Stone", "type": "block",
		"icon_color": Color(0.50, 0.50, 0.50), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(3, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "chiseled_stone", "drop_count": 1
	},
	"sandstone": {
		"name": "Sandstone", "type": "block",
		"icon_color": Color(0.88, 0.81, 0.62), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(4, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "sandstone", "drop_count": 1
	},
	"sandstone_smooth": {
		"name": "Smooth Sandstone", "type": "block",
		"icon_color": Color(0.91, 0.85, 0.66), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(5, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "sandstone_smooth", "drop_count": 1
	},
	"sandstone_chiseled": {
		"name": "Chiseled Sandstone", "type": "block",
		"icon_color": Color(0.88, 0.81, 0.62), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(6, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "sandstone_chiseled", "drop_count": 1
	},
	"brick": {
		"name": "Brick Block", "type": "block",
		"icon_color": Color(0.70, 0.30, 0.20), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(7, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "brick", "drop_count": 1
	},
	"mud_brick": {
		"name": "Mud Brick", "type": "block",
		"icon_color": Color(0.55, 0.41, 0.26), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(8, 4),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 0,
		"drop_item": "mud_brick", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  WOOD VARIANTS
	# ══════════════════════════════════════

	"planks_spruce": {
		"name": "Spruce Planks", "type": "block",
		"icon_color": Color(0.41, 0.29, 0.14), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 5),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "planks_spruce", "drop_count": 1
	},
	"planks_jungle": {
		"name": "Jungle Planks", "type": "block",
		"icon_color": Color(0.65, 0.46, 0.26), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 5),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "planks_jungle", "drop_count": 1
	},
	"planks_dark_oak": {
		"name": "Dark Oak Planks", "type": "block",
		"icon_color": Color(0.26, 0.16, 0.07), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(2, 5),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "planks_dark_oak", "drop_count": 1
	},
	"log_spruce": {
		"name": "Spruce Log", "type": "block",
		"icon_color": Color(0.22, 0.15, 0.07), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(3, 5),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "log_spruce", "drop_count": 1
	},
	"log_jungle": {
		"name": "Jungle Log", "type": "block",
		"icon_color": Color(0.38, 0.29, 0.13), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(4, 5),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "log_jungle", "drop_count": 1
	},
	"leaves_spruce": {
		"name": "Spruce Leaves", "type": "block",
		"icon_color": Color(0.09, 0.31, 0.08, 0.9), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(5, 5),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.3, "tool_type": "axe", "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"leaves_jungle": {
		"name": "Jungle Leaves", "type": "block",
		"icon_color": Color(0.20, 0.60, 0.08, 0.9), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(6, 5),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.3, "tool_type": "axe", "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},

	# ══════════════════════════════════════
	#  STRUCTURE / DECORATIVE
	# ══════════════════════════════════════

	"pillar": {
		"name": "Stone Pillar", "type": "block",
		"icon_color": Color(0.82, 0.82, 0.82), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "pillar", "drop_count": 1
	},
	"arch_stone": {
		"name": "Stone Arch", "type": "block",
		"icon_color": Color(0.50, 0.50, 0.50), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "arch_stone", "drop_count": 1
	},
	"window_glass": {
		"name": "Window Glass", "type": "block",
		"icon_color": Color(0.78, 0.91, 0.98, 0.6), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(2, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.3, "tool_type": "pick", "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"fence_wood": {
		"name": "Wood Fence", "type": "block",
		"icon_color": Color(0.70, 0.57, 0.33), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(3, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "fence_wood", "drop_count": 1
	},
	"fence_stone_wall": {
		"name": "Stone Wall", "type": "block",
		"icon_color": Color(0.42, 0.42, 0.42), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(4, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "fence_stone_wall", "drop_count": 1
	},
	"bookshelf": {
		"name": "Bookshelf", "type": "block",
		"icon_color": Color(0.61, 0.49, 0.30), "icon_shape": "square",
		"max_stack": 16, "placeable": true, "tile_id": Vector2i(5, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "bookshelf", "drop_count": 1
	},
	"hay_bale": {
		"name": "Hay Bale", "type": "block",
		"icon_color": Color(0.82, 0.71, 0.20), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(6, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.5, "tool_type": null, "mine_level": 0,
		"drop_item": "hay_bale", "drop_count": 1
	},
	"barrel": {
		"name": "Barrel", "type": "block",
		"icon_color": Color(0.51, 0.36, 0.18), "icon_shape": "square",
		"max_stack": 8, "placeable": true, "tile_id": Vector2i(7, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "barrel", "drop_count": 1
	},
	"stairs_stone": {
		"name": "Stone Stairs", "type": "block",
		"icon_color": Color(0.50, 0.50, 0.50), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(8, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "stairs_stone", "drop_count": 1
	},
	"stairs_wood": {
		"name": "Wood Stairs", "type": "block",
		"icon_color": Color(0.70, 0.57, 0.33), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(9, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "stairs_wood", "drop_count": 1
	},
	"slab_stone": {
		"name": "Stone Slab", "type": "block",
		"icon_color": Color(0.50, 0.50, 0.50), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(10, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "slab_stone", "drop_count": 1
	},
	"slab_wood": {
		"name": "Wood Slab", "type": "block",
		"icon_color": Color(0.70, 0.57, 0.33), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(11, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "slab_wood", "drop_count": 1
	},
	"anvil": {
		"name": "Anvil", "type": "block",
		"icon_color": Color(0.28, 0.28, 0.28), "icon_shape": "square",
		"max_stack": 1, "placeable": true, "tile_id": Vector2i(12, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "anvil", "drop_count": 1
	},
	"workbench_stone": {
		"name": "Stone Workbench", "type": "block",
		"icon_color": Color(0.50, 0.50, 0.50), "icon_shape": "square",
		"max_stack": 1, "placeable": true, "tile_id": Vector2i(13, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "workbench_stone", "drop_count": 1
	},
	"torch_wall": {
		"name": "Wall Torch", "type": "block",
		"icon_color": Color(1.0, 0.85, 0.2), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(14, 6),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": "torch", "drop_count": 1,
		"light_radius": 7.0, "light_color": Color(1.0, 0.85, 0.4, 1.0)
	},

	# ══════════════════════════════════════
	#  ORE / RESOURCE BLOCKS
	# ══════════════════════════════════════

	"copper_ore": {
		"name": "Copper Ore", "type": "block",
		"icon_color": Color(0.80, 0.50, 0.20), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 7),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "copper_ingot", "drop_count": 1
	},
	"copper_ingot": {
		"name": "Copper Ingot", "type": "material",
		"icon_color": Color(0.80, 0.50, 0.20), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"tin_ore": {
		"name": "Tin Ore", "type": "block",
		"icon_color": Color(0.70, 0.75, 0.78), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 7),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "tin_ore", "drop_count": 1
	},
	"silver_ore": {
		"name": "Silver Ore", "type": "block",
		"icon_color": Color(0.82, 0.84, 0.90), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(2, 7),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 3,
		"drop_item": "silver_ingot", "drop_count": 1
	},
	"silver_ingot": {
		"name": "Silver Ingot", "type": "material",
		"icon_color": Color(0.75, 0.75, 0.80), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"quartz": {
		"name": "Quartz", "type": "material",
		"icon_color": Color(0.94, 0.91, 0.88), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"quartz_block": {
		"name": "Quartz Block", "type": "block",
		"icon_color": Color(0.94, 0.91, 0.88), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(3, 7),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "quartz_block", "drop_count": 1
	},
	"obsidian": {
		"name": "Obsidian", "type": "block",
		"icon_color": Color(0.10, 0.06, 0.18), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(4, 7),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 4,
		"drop_item": "obsidian", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  NATURE DECORATION
	# ══════════════════════════════════════

	"mushroom_red": {
		"name": "Red Mushroom", "type": "block",
		"icon_color": Color(0.82, 0.10, 0.10), "icon_shape": "circle",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(0, 8),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.1, "tool_type": null, "mine_level": 0,
		"drop_item": "mushroom_red", "drop_count": 1
	},
	"mushroom_brown": {
		"name": "Brown Mushroom", "type": "block",
		"icon_color": Color(0.51, 0.36, 0.18), "icon_shape": "circle",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(1, 8),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.1, "tool_type": null, "mine_level": 0,
		"drop_item": "mushroom_brown", "drop_count": 1
	},
	"vines": {
		"name": "Vines", "type": "block",
		"icon_color": Color(0.20, 0.50, 0.10), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(2, 8),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.1, "tool_type": "axe", "mine_level": 0,
		"drop_item": "vines", "drop_count": 1
	},
	"lily_pad": {
		"name": "Lily Pad", "type": "block",
		"icon_color": Color(0.18, 0.50, 0.10), "icon_shape": "circle",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(3, 8),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.1, "tool_type": null, "mine_level": 0,
		"drop_item": "lily_pad", "drop_count": 1
	},

	# ══════════════════════════════════════════════════════════════════════
	#  EQUIPMENT  (armour that buffs the player — equip via inventory)
	#  Fields:  slot  tier  bonus_max_health  bonus_armor  bonus_speed
	# ══════════════════════════════════════════════════════════════════════

	"wood_helmet": {
		"name": "Wooden Helmet", "type": "armor", "slot": "head", "tier": "wood",
		"icon_color": Color(0.55, 0.37, 0.18), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 5.0, "bonus_armor": 0.04,
	},
	"stone_helmet": {
		"name": "Stone Helmet", "type": "armor", "slot": "head", "tier": "stone",
		"icon_color": Color(0.62, 0.62, 0.62), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 10.0, "bonus_armor": 0.08,
	},
	"iron_helmet": {
		"name": "Iron Helmet", "type": "armor", "slot": "head", "tier": "iron",
		"icon_color": Color(0.78, 0.82, 0.88), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 20.0, "bonus_armor": 0.12,
	},
	"gold_helmet": {
		"name": "Gold Helmet", "type": "armor", "slot": "head", "tier": "gold",
		"icon_color": Color(1.0, 0.85, 0.10), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 30.0, "bonus_armor": 0.15,
	},
	"wood_chestplate": {
		"name": "Wooden Chestplate", "type": "armor", "slot": "chest", "tier": "wood",
		"icon_color": Color(0.55, 0.37, 0.18), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 8.0, "bonus_armor": 0.06,
	},
	"stone_chestplate": {
		"name": "Stone Chestplate", "type": "armor", "slot": "chest", "tier": "stone",
		"icon_color": Color(0.62, 0.62, 0.62), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 15.0, "bonus_armor": 0.10,
	},
	"iron_chestplate": {
		"name": "Iron Chestplate", "type": "armor", "slot": "chest", "tier": "iron",
		"icon_color": Color(0.78, 0.82, 0.88), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 25.0, "bonus_armor": 0.15,
	},
	"gold_chestplate": {
		"name": "Gold Chestplate", "type": "armor", "slot": "chest", "tier": "gold",
		"icon_color": Color(1.0, 0.85, 0.10), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 35.0, "bonus_armor": 0.20,
	},
	"wood_leggings": {
		"name": "Wooden Leggings", "type": "armor", "slot": "legs", "tier": "wood",
		"icon_color": Color(0.55, 0.37, 0.18), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 4.0, "bonus_armor": 0.03, "bonus_speed": 5.0,
	},
	"stone_leggings": {
		"name": "Stone Leggings", "type": "armor", "slot": "legs", "tier": "stone",
		"icon_color": Color(0.62, 0.62, 0.62), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 8.0, "bonus_armor": 0.07, "bonus_speed": 10.0,
	},
	"iron_leggings": {
		"name": "Iron Leggings", "type": "armor", "slot": "legs", "tier": "iron",
		"icon_color": Color(0.78, 0.82, 0.88), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 15.0, "bonus_armor": 0.10, "bonus_speed": 15.0,
	},
	"gold_leggings": {
		"name": "Gold Leggings", "type": "armor", "slot": "legs", "tier": "gold",
		"icon_color": Color(1.0, 0.85, 0.10), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 22.0, "bonus_armor": 0.13, "bonus_speed": 20.0,
	},

	# ══════════════════════════════════════
	#  ARMOUR  (leather tier)
	# ══════════════════════════════════════
	"leather_helmet": {
		"name": "Leather Helmet", "type": "armor", "slot": "head", "tier": "leather",
		"icon_color": Color(0.6, 0.35, 0.15), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 3.0, "bonus_armor": 0.02,
	},
	"leather_chestplate": {
		"name": "Leather Chestplate", "type": "armor", "slot": "chest", "tier": "leather",
		"icon_color": Color(0.6, 0.35, 0.15), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 5.0, "bonus_armor": 0.04,
	},
	"leather_leggings": {
		"name": "Leather Leggings", "type": "armor", "slot": "legs", "tier": "leather",
		"icon_color": Color(0.6, 0.35, 0.15), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 4.0, "bonus_armor": 0.03,
	},
	"leather_boots": {
		"name": "Leather Boots", "type": "armor", "slot": "feet", "tier": "leather",
		"icon_color": Color(0.6, 0.35, 0.15),
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_max_health": 2.0, "bonus_armor": 0.02,
	},

	"iron_arms": {
		"name": "Iron Gauntlets", "type": "armor", "slot": "arms", "tier": "iron",
		"icon_color": Color(0.78, 0.82, 0.88), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_mining_speed": 0.25, "bonus_armor": 0.05,
	},
	"gold_arms": {
		"name": "Gold Gauntlets", "type": "armor", "slot": "arms", "tier": "gold",
		"icon_color": Color(1.0, 0.85, 0.10), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 1,
		"bonus_mining_speed": 0.50, "bonus_armor": 0.08,
	},

	# ══════════════════════════════════════
	#  BUCKETS
	# ══════════════════════════════════════

	"bucket_empty": {
		"name": "Bucket", "type": "tool",
		"icon_color": Color(0.6, 0.6, 0.6), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "none", "mine_level": 0,
		"drop_item": "bucket_empty", "drop_count": 1
	},
	"bucket_water": {
		"name": "Water Bucket", "type": "tool",
		"icon_color": Color(0.2, 0.5, 1.0), "icon_shape": "square",
		"max_stack": 1, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "none", "mine_level": 0,
		"drop_item": "bucket_water", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  COLORED CONCRETE  (8 variants)
	# ══════════════════════════════════════
	"concrete_white": {
		"name": "White Concrete", "type": "block",
		"icon_color": Color(0.92, 0.92, 0.92), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(0, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_white", "drop_count": 1
	},
	"concrete_red": {
		"name": "Red Concrete", "type": "block",
		"icon_color": Color(0.72, 0.10, 0.10), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(1, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_red", "drop_count": 1
	},
	"concrete_orange": {
		"name": "Orange Concrete", "type": "block",
		"icon_color": Color(0.88, 0.46, 0.08), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(2, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_orange", "drop_count": 1
	},
	"concrete_yellow": {
		"name": "Yellow Concrete", "type": "block",
		"icon_color": Color(0.92, 0.84, 0.08), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(3, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_yellow", "drop_count": 1
	},
	"concrete_green": {
		"name": "Green Concrete", "type": "block",
		"icon_color": Color(0.12, 0.56, 0.12), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(4, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_green", "drop_count": 1
	},
	"concrete_blue": {
		"name": "Blue Concrete", "type": "block",
		"icon_color": Color(0.10, 0.26, 0.80), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(5, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_blue", "drop_count": 1
	},
	"concrete_purple": {
		"name": "Purple Concrete", "type": "block",
		"icon_color": Color(0.45, 0.10, 0.70), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(6, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_purple", "drop_count": 1
	},
	"concrete_black": {
		"name": "Black Concrete", "type": "block",
		"icon_color": Color(0.10, 0.10, 0.10), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(7, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.2, "tool_type": "pick", "mine_level": 1,
		"drop_item": "concrete_black", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  POLISHED & DECORATIVE STONE VARIANTS
	# ══════════════════════════════════════
	"polished_stone": {
		"name": "Polished Stone", "type": "block",
		"icon_color": Color(0.58, 0.58, 0.60), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(8, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "polished_stone", "drop_count": 1
	},
	"granite": {
		"name": "Granite", "type": "block",
		"icon_color": Color(0.68, 0.44, 0.36), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(9, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "granite", "drop_count": 1
	},
	"diorite": {
		"name": "Diorite", "type": "block",
		"icon_color": Color(0.80, 0.78, 0.76), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(10, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "diorite", "drop_count": 1
	},
	"andesite": {
		"name": "Andesite", "type": "block",
		"icon_color": Color(0.45, 0.44, 0.42), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(11, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "andesite", "drop_count": 1
	},
	"terracotta": {
		"name": "Terracotta", "type": "block",
		"icon_color": Color(0.72, 0.42, 0.28), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(12, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "terracotta", "drop_count": 1
	},
	"marble": {
		"name": "Marble", "type": "block",
		"icon_color": Color(0.94, 0.92, 0.90), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(13, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "marble", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  FUNCTIONAL BUILDING BLOCKS
	# ══════════════════════════════════════
	"iron_bars": {
		"name": "Iron Bars", "type": "block",
		"icon_color": Color(0.54, 0.54, 0.57), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(14, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "iron_bars", "drop_count": 1
	},
	"glass_pane": {
		"name": "Glass Pane", "type": "block",
		"icon_color": Color(0.76, 0.90, 0.96, 0.55), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(15, 9),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.3, "tool_type": "pick", "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"ladder": {
		"name": "Ladder", "type": "block",
		"icon_color": Color(0.68, 0.56, 0.30), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(0, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "ladder", "drop_count": 1
	},
	"trapdoor": {
		"name": "Trapdoor", "type": "block",
		"icon_color": Color(0.62, 0.48, 0.24), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(1, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "trapdoor", "drop_count": 1
	},
	"glowstone": {
		"name": "Glowstone", "type": "block",
		"icon_color": Color(1.0, 0.88, 0.48), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(2, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 0.5, "tool_type": "pick", "mine_level": 0,
		"drop_item": "glowstone", "drop_count": 1,
		"light_radius": 8.0, "light_color": Color(1.0, 0.94, 0.60)
	},
	"nether_brick": {
		"name": "Nether Brick", "type": "block",
		"icon_color": Color(0.28, 0.08, 0.08), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(3, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "nether_brick", "drop_count": 1
	},
	"end_stone": {
		"name": "End Stone", "type": "block",
		"icon_color": Color(0.88, 0.88, 0.66), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(4, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "end_stone", "drop_count": 1
	},
	"mycelium": {
		"name": "Mycelium", "type": "block",
		"icon_color": Color(0.48, 0.36, 0.48), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(5, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "shovel", "mine_level": 0,
		"drop_item": "dirt", "drop_count": 1
	},

	# ══════════════════════════════════════
	#  NEW ORES & RESOURCES
	# ══════════════════════════════════════
	"mithril_ore": {
		"name": "Mithril Ore", "type": "block",
		"icon_color": Color(0.38, 0.70, 0.90), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(6, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 4,
		"drop_item": "mithril_ingot", "drop_count": 1
	},
	"mithril_ingot": {
		"name": "Mithril Ingot", "type": "material",
		"icon_color": Color(0.38, 0.70, 0.90), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"topaz_ore": {
		"name": "Topaz Ore", "type": "block",
		"icon_color": Color(1.0, 0.68, 0.16), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(7, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 3,
		"drop_item": "topaz", "drop_count": 1
	},
	"topaz": {
		"name": "Topaz", "type": "material",
		"icon_color": Color(1.0, 0.70, 0.18), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},
	"sapphire_ore": {
		"name": "Sapphire Ore", "type": "block",
		"icon_color": Color(0.10, 0.28, 0.90), "icon_shape": "square",
		"max_stack": 64, "placeable": true, "tile_id": Vector2i(8, 10),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 3,
		"drop_item": "sapphire", "drop_count": 1
	},
	"sapphire": {
		"name": "Sapphire", "type": "material",
		"icon_color": Color(0.12, 0.30, 0.92), "icon_shape": "diamond",
		"max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": null, "mine_level": 0,
		"drop_item": null, "drop_count": 0
	},

	# ══════════════════════════════════════
	#  BUILDING & DECORATIVE BLOCKS
	# ══════════════════════════════════════

	"brick_wall": {
		"name": "Brick Wall", "type": "block",
		"icon_color": Color(0.72, 0.35, 0.25), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(0, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "brick_wall", "drop_count": 1
	},
	"wood_plank_wall": {
		"name": "Wooden Plank Wall", "type": "block",
		"icon_color": Color(0.72, 0.57, 0.32), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(1, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "wood_plank_wall", "drop_count": 1
	},
	"cobblestone_wall": {
		"name": "Cobblestone Wall", "type": "block",
		"icon_color": Color(0.50, 0.50, 0.50), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(2, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "cobblestone_wall", "drop_count": 1
	},
	"mossy_cobblestone": {
		"name": "Mossy Cobblestone", "type": "block",
		"icon_color": Color(0.36, 0.50, 0.32), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(3, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "mossy_cobblestone", "drop_count": 1
	},
	"dark_stone": {
		"name": "Dark Stone", "type": "block",
		"icon_color": Color(0.18, 0.18, 0.20), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(4, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "dark_stone", "drop_count": 1
	},
	"iron_block": {
		"name": "Iron Block", "type": "block",
		"icon_color": Color(0.78, 0.80, 0.82), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(5, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "iron_block", "drop_count": 1
	},
	"gold_block": {
		"name": "Gold Block", "type": "block",
		"icon_color": Color(0.95, 0.82, 0.10), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(6, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 2,
		"drop_item": "gold_block", "drop_count": 1
	},
	"clay_brick": {
		"name": "Clay Brick", "type": "block",
		"icon_color": Color(0.78, 0.50, 0.38), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(7, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "pick", "mine_level": 1,
		"drop_item": "clay_brick", "drop_count": 1
	},
	"wood_beam": {
		"name": "Wooden Beam", "type": "block",
		"icon_color": Color(0.60, 0.45, 0.22), "icon_shape": "square",
		"max_stack": 99, "placeable": true, "tile_id": Vector2i(8, 11),
		"edible": false, "food_value": 0, "damage": 0,
		"tool_speed": 1.0, "tool_type": "axe", "mine_level": 0,
		"drop_item": "wood_beam", "drop_count": 1
	},
}

# ─────────────────────────────────────────────
#  INIT — generate unbreakable variants
# ─────────────────────────────────────────────

func _ready() -> void:
	_generate_inf_variants()

## Generates an `id_inf` copy of every breakable tool and weapon with durability = -1.
## Called once at startup so creative inventory and crafting can reference them.
func _generate_inf_variants() -> void:
	var to_add: Dictionary = {}
	for id: String in items.keys():
		var data: Dictionary = items[id]
		var item_type: String = data.get("type", "")
		if item_type not in ["tool", "weapon"]:
			continue
		if not data.has("durability"):
			continue
		var dur = data.get("durability", 0)
		if dur < 0:
			continue  # already unbreakable
		var inf_id := id + "_inf"
		if items.has(inf_id):
			continue
		var inf_data: Dictionary = data.duplicate(true)
		inf_data["name"] = "Infinite " + str(data.get("name", id))
		inf_data["durability"] = -1
		to_add[inf_id] = inf_data
	for inf_id: String in to_add.keys():
		items[inf_id] = to_add[inf_id]

# ─────────────────────────────────────────────
#  HELPER FUNCTIONS
# ─────────────────────────────────────────────

func get_item(id: String) -> Dictionary:
	## Returns item data by ID. Returns an empty dict if not found.
	return items.get(id, {})

func get_display_name(id: String) -> String:
	var d := get_item(id)
	return d.get("name", id)

func is_placeable(id: String) -> bool:
	var d := get_item(id)
	return d.get("placeable", false)

func get_tile_id(id: String) -> Vector2i:
	var d := get_item(id)
	return d.get("tile_id", Vector2i(-1, -1))

func is_food(id: String) -> bool:
	var d := get_item(id)
	return d.get("edible", false)

func get_food_value(id: String) -> float:
	var d := get_item(id)
	return float(d.get("food_value", 0))

func get_damage(id: String) -> float:
	var d := get_item(id)
	return float(d.get("damage", 0))

func get_tool_speed(id: String) -> float:
	var d := get_item(id)
	return float(d.get("tool_speed", 1.0))

func get_mine_level(id: String) -> int:
	var d := get_item(id)
	return d.get("mine_level", 0)

func get_tool_type(id: String) -> String:
	var d := get_item(id)
	return d.get("tool_type", "")

func get_drop(id: String) -> Array:
	## Returns [drop_item_id, drop_count] for a block when broken.
	## Also fires bonus_drop (e.g. apples from leaves) and gives them directly to the player.
	var d := get_item(id)
	var drop_id: String = d.get("drop_item", id) if d.get("drop_item") != null else ""
	var count = d.get("drop_count", 1)
	if count is Array:
		count = randi_range(count[0], count[1])
	# Bonus drop (e.g. apple from oak leaves)
	var bonus_id: String = d.get("bonus_drop_item", "")
	var bonus_chance: float = float(d.get("bonus_drop_chance", 0.0))
	if bonus_id != "" and randf() < bonus_chance:
		_pending_bonus_drop = [bonus_id, 1]
	else:
		_pending_bonus_drop = []
	return [drop_id, count]

## Consumed by World.gd after get_drop() — delivers any bonus drop to the player.
var _pending_bonus_drop: Array = []

func has_light(id: String) -> bool:
	return items.get(id, {}).has("light_radius")

func get_light_radius(id: String) -> float:
	return float(items.get(id, {}).get("light_radius", 0.0))

func get_light_color(id: String) -> Color:
	return items.get(id, {}).get("light_color", Color.WHITE)

# ─────────────────────────────────────────────
#  TILE RENDERING HELPERS  (used by Chunk.gd)
# ─────────────────────────────────────────────

func has_tile(id: String) -> bool:
	## Returns true if this item_id has a valid tile atlas entry for rendering.
	## Called by Chunk._set_tilemap_cell() before drawing a tile.
	## Returns false for items that are NOT placeable blocks (e.g. swords, food).
	if not items.has(id):
		return false
	var tile: Vector2i = items[id].get("tile_id", Vector2i(-1, -1))
	return tile != Vector2i(-1, -1)

func get_tile_atlas_coords(id: String) -> Vector2i:
	## Returns the atlas grid position (column, row) for the tile with this item_id.
	## Used by TileMapLayer.set_cell() to pick the correct graphic from the atlas texture.
	## Returns Vector2i(0, 0) as a safe fallback if the id is missing.
	##
	## HOW THE ATLAS WORKS:
	##   The tile texture is a grid of 16x16 pixel squares.
	##   Vector2i(column, row) picks which square to display.
	##   Row 0 = natural blocks, Row 1 = wood/plants, Row 2 = ores, Row 3 = biome decor.
	##   See TileTextureGenerator.gd for the full layout.
	return items.get(id, {}).get("tile_id", Vector2i(0, 0))
