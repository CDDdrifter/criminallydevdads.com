# CraftingSystem.gd
# Manages all crafting recipes and inventory-based crafting logic.
# Use as an Autoload (recommended) or attach to a UI node.
#
# ============================================================
# HOW TO ADD A NEW RECIPE
# ============================================================
# 1. Open the RECIPES array below.
# 2. Copy any existing recipe Dictionary as a template and paste it at the end
#    of the array (before the closing bracket).
# 3. Set the fields:
#      "id"               — the item_id string of what gets crafted (must match your
#                           item database).
#      "count"            — how many of that item the player receives per craft.
#      "requires_table"   — true = player must be near a crafting table.
#                           false means it can be crafted from the inventory screen.
#      "requires_furnace" — true = only available via the Furnace UI.
#                           Omit or set false for normal recipes.
#      "smelt_time"       — (optional) seconds to smelt (default 3.0).
#                           Only meaningful when requires_furnace = true.
#      "ingredients"      — Array of {"id": String, "count": int} dicts.  Every
#                           ingredient id must appear in the player's inventory.
# 4. Make sure the item ids used in "ingredients" already exist in your item
#    database (ItemDB or equivalent).  If they don't, add them there first.
# 5. The recipe is immediately available — no other registration step needed.
#    get_available_recipes() will surface it as soon as the player has the items.
#
# Example:
#   {
#     "id": "golden_sword",
#     "count": 1,
#     "requires_table": true,
#     "ingredients": [
#       {"id": "gold_ingot", "count": 2},
#       {"id": "stick",      "count": 1},
#     ],
#   },
# ============================================================

extends Node

# ------------------------------------------------------------------
# RECIPE DATABASE
# ------------------------------------------------------------------
# Tip: keep recipes ordered loosely by progression tier so designers can
# scan them quickly. Tier 0 = basic survival, Tier 1 = wood tools, etc.

const RECIPES: Array = [
	# ----------------------------------------------------------------
	# TIER 0 — RAW PROCESSING (no table needed)
	# ----------------------------------------------------------------
	{
		"id": "planks_oak",
		"count": 4,
		"requires_table": false,
		"ingredients": [
			{"id": "log_oak", "count": 1},
		],
	},
	{
		"id": "planks_birch",
		"count": 4,
		"requires_table": false,
		"ingredients": [
			{"id": "log_birch", "count": 1},
		],
	},
	{
		"id": "stick",
		"count": 4,
		"requires_table": false,
		"ingredients": [
			{"id": "planks_oak", "count": 2},
		],
	},

	# ----------------------------------------------------------------
	# TIER 0 — BASIC FURNITURE / BLOCKS (no table)
	# ----------------------------------------------------------------
	{
		"id": "crafting_table",
		"count": 1,
		"requires_table": false,
		"ingredients": [
			{"id": "planks_oak", "count": 4},
		],
	},
	{
		"id": "chest",
		"count": 1,
		"requires_table": false,
		"ingredients": [
			{"id": "planks_oak", "count": 8},
		],
	},
	{
		"id": "torch",
		"count": 4,
		"requires_table": false,
		"ingredients": [
			{"id": "stick", "count": 1},
			{"id": "coal",  "count": 1},
		],
	},
	{
		"id": "campfire",
		"count": 1,
		"requires_table": false,
		"ingredients": [
			{"id": "log_oak", "count": 3},
			{"id": "stick",   "count": 3},
			{"id": "flint",   "count": 1},
		],
	},
	{
		"id": "furnace",
		"count": 1,
		"requires_table": false,
		"ingredients": [
			{"id": "cobblestone", "count": 8},
		],
	},

	# ----------------------------------------------------------------
	# TIER 1 — WOOD TOOLS (crafting table required)
	# ----------------------------------------------------------------
	{
		"id": "wood_pick",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "planks_oak", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "wood_axe",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "planks_oak", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "wood_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "planks_oak", "count": 2},
			{"id": "stick",      "count": 1},
		],
	},
	{
		"id": "wood_shovel",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "planks_oak", "count": 1},
			{"id": "stick",      "count": 2},
		],
	},

	# ----------------------------------------------------------------
	# TIER 2 — STONE TOOLS (crafting table required)
	# ----------------------------------------------------------------
	{
		"id": "stone_pick",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "cobblestone", "count": 3},
			{"id": "stick",       "count": 2},
		],
	},
	{
		"id": "stone_axe",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "cobblestone", "count": 3},
			{"id": "stick",       "count": 2},
		],
	},
	{
		"id": "stone_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "cobblestone", "count": 2},
			{"id": "stick",       "count": 1},
		],
	},

	# ----------------------------------------------------------------
	# TIER 3 — IRON TOOLS (crafting table required)
	# ----------------------------------------------------------------
	{
		"id": "iron_axe",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "iron_shovel",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 1},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "stone_shovel",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "cobblestone", "count": 1},
			{"id": "stick",       "count": 2},
		],
	},
	{
		"id": "iron_pick",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "iron_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 2},
			{"id": "stick",      "count": 1},
		],
	},

	# ----------------------------------------------------------------
	# TIER 4 — DIAMOND TOOLS (crafting table required)
	# ----------------------------------------------------------------
	# Gold tools
	{ "id": "gold_pick",   "count": 1, "requires_table": true,
	  "ingredients": [{"id": "gold_ingot", "count": 3}, {"id": "stick", "count": 2}] },
	{ "id": "gold_axe",    "count": 1, "requires_table": true,
	  "ingredients": [{"id": "gold_ingot", "count": 3}, {"id": "stick", "count": 2}] },
	{ "id": "gold_shovel", "count": 1, "requires_table": true,
	  "ingredients": [{"id": "gold_ingot", "count": 1}, {"id": "stick", "count": 2}] },
	# Diamond tools
	{
		"id": "diamond_pick",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "diamond", "count": 3},
			{"id": "stick",   "count": 2},
		],
	},
	{ "id": "diamond_axe",    "count": 1, "requires_table": true,
	  "ingredients": [{"id": "diamond", "count": 3}, {"id": "stick", "count": 2}] },
	{ "id": "diamond_shovel", "count": 1, "requires_table": true,
	  "ingredients": [{"id": "diamond", "count": 1}, {"id": "stick", "count": 2}] },
	{
		"id": "diamond_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "diamond", "count": 2},
			{"id": "stick",   "count": 1},
		],
	},
	# Ruby tools
	{ "id": "ruby_pick",   "count": 1, "requires_table": true,
	  "ingredients": [{"id": "ruby", "count": 3}, {"id": "stick", "count": 2}] },
	{ "id": "ruby_axe",    "count": 1, "requires_table": true,
	  "ingredients": [{"id": "ruby", "count": 3}, {"id": "stick", "count": 2}] },
	{ "id": "ruby_shovel", "count": 1, "requires_table": true,
	  "ingredients": [{"id": "ruby", "count": 1}, {"id": "stick", "count": 2}] },
	{ "id": "ruby_sword",  "count": 1, "requires_table": true,
	  "ingredients": [{"id": "ruby", "count": 2}, {"id": "stick", "count": 1}] },
	# Emerald tools
	{ "id": "emerald_pick",   "count": 1, "requires_table": true,
	  "ingredients": [{"id": "emerald", "count": 3}, {"id": "stick", "count": 2}] },
	{ "id": "emerald_axe",    "count": 1, "requires_table": true,
	  "ingredients": [{"id": "emerald", "count": 3}, {"id": "stick", "count": 2}] },
	{ "id": "emerald_shovel", "count": 1, "requires_table": true,
	  "ingredients": [{"id": "emerald", "count": 1}, {"id": "stick", "count": 2}] },
	{ "id": "emerald_sword",  "count": 1, "requires_table": true,
	  "ingredients": [{"id": "emerald", "count": 2}, {"id": "stick", "count": 1}] },

	# ----------------------------------------------------------------
	# TIER 5 — SPECIAL MELEE WEAPONS (crafting table required)
	# ----------------------------------------------------------------
	# Shadow Blade — iron base + shadow essence (drops from Shadow enemies)
	{
		"id": "shadow_blade",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot",    "count": 2},
			{"id": "shadow_essence","count": 3},
			{"id": "stick",         "count": 1},
		],
	},
	# War Hammer — heavy iron build, no stick (solid grip)
	{
		"id": "war_hammer",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 5},
			{"id": "stick",      "count": 2},
		],
	},
	# Twin Daggers — iron-light, quick craft
	{
		"id": "twin_daggers",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 2},
			{"id": "stick",      "count": 2},
		],
	},
	# Spear — long-reach, iron tip on two sticks
	{
		"id": "spear",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 2},
			{"id": "stick",      "count": 3},
		],
	},
	# Flail — iron ball + chain (represented by iron ingots + sticks)
	{
		"id": "flail",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 3},
			{"id": "stick",      "count": 2},
			{"id": "shadow_essence", "count": 1},
		],
	},

	# ----------------------------------------------------------------
	# FOOD
	# ----------------------------------------------------------------
	{
		"id": "bread",
		"count": 1,
		"requires_table": false,
		"ingredients": [
			{"id": "wheat", "count": 3},
		],
	},

	# ----------------------------------------------------------------
	# LEATHER ARMOUR (crafting table required)
	# ----------------------------------------------------------------
	{
		"id": "leather_helmet",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "leather", "count": 5},
		],
	},
	{
		"id": "leather_chestplate",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "leather", "count": 8},
		],
	},
	{
		"id": "leather_leggings",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "leather", "count": 7},
		],
	},
	{
		"id": "leather_boots",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "leather", "count": 4},
		],
	},

	# ── FURNITURE ──────────────────────────────────────────────────────────────
	{
		"id": "bed", "count": 1, "requires_table": true,
		"ingredients": [
			{"id": "planks_oak", "count": 3},
			{"id": "wool", "count": 3},
		],
	},
	{
		"id": "crystal_gate", "count": 1, "requires_table": true,
		"ingredients": [
			{"id": "window_glass", "count": 5},
			{"id": "diamond", "count": 2},
		],
	},

	# ── EQUIPMENT (requires crafting table) ─────────────────────────────────
	{
		"id": "wood_helmet", "count": 1, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 5}],
	},
	{
		"id": "stone_helmet", "count": 1, "requires_table": true,
		"ingredients": [{"id": "stone", "count": 5}, {"id": "stick", "count": 2}],
	},
	{
		"id": "iron_helmet", "count": 1, "requires_table": true,
		"ingredients": [{"id": "iron_ingot", "count": 5}],
	},
	{
		"id": "gold_helmet", "count": 1, "requires_table": true,
		"ingredients": [{"id": "gold_ingot", "count": 5}],
	},
	{
		"id": "wood_chestplate", "count": 1, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 8}],
	},
	{
		"id": "stone_chestplate", "count": 1, "requires_table": true,
		"ingredients": [{"id": "stone", "count": 8}, {"id": "stick", "count": 2}],
	},
	{
		"id": "iron_chestplate", "count": 1, "requires_table": true,
		"ingredients": [{"id": "iron_ingot", "count": 8}],
	},
	{
		"id": "gold_chestplate", "count": 1, "requires_table": true,
		"ingredients": [{"id": "gold_ingot", "count": 8}],
	},
	{
		"id": "wood_leggings", "count": 1, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 7}],
	},
	{
		"id": "stone_leggings", "count": 1, "requires_table": true,
		"ingredients": [{"id": "stone", "count": 7}, {"id": "stick", "count": 2}],
	},
	{
		"id": "iron_leggings", "count": 1, "requires_table": true,
		"ingredients": [{"id": "iron_ingot", "count": 7}],
	},
	{
		"id": "gold_leggings", "count": 1, "requires_table": true,
		"ingredients": [{"id": "gold_ingot", "count": 7}],
	},
	{
		"id": "iron_arms", "count": 1, "requires_table": true,
		"ingredients": [{"id": "iron_ingot", "count": 6}],
	},
	{
		"id": "gold_arms", "count": 1, "requires_table": true,
		"ingredients": [{"id": "gold_ingot", "count": 6}],
	},

	# ----------------------------------------------------------------
	# NEW BLOCKS — stone/brick variants
	# ----------------------------------------------------------------
	{
		"id": "stone_brick", "count": 4, "requires_table": true,
		"ingredients": [{"id": "cobblestone", "count": 4}],
	},
	{
		"id": "mossy_stone_brick", "count": 4, "requires_table": true,
		"ingredients": [{"id": "stone_brick", "count": 4}, {"id": "vines", "count": 1}],
	},
	{
		"id": "cracked_stone_brick", "count": 1, "requires_table": false,
		"ingredients": [{"id": "stone_brick", "count": 1}],
	},
	{
		"id": "chiseled_stone", "count": 2, "requires_table": true,
		"ingredients": [{"id": "stone_brick", "count": 2}],
	},
	{
		"id": "sandstone", "count": 4, "requires_table": false,
		"ingredients": [{"id": "sand", "count": 4}],
	},
	{
		"id": "sandstone_smooth", "count": 4, "requires_table": true,
		"ingredients": [{"id": "sandstone", "count": 4}],
	},
	{
		"id": "sandstone_chiseled", "count": 2, "requires_table": true,
		"ingredients": [{"id": "sandstone", "count": 2}],
	},
	{
		"id": "mud_brick", "count": 4, "requires_table": false,
		"ingredients": [{"id": "clay_ball", "count": 4}],
	},
	{
		"id": "pillar", "count": 2, "requires_table": true,
		"ingredients": [{"id": "stone_brick", "count": 2}],
	},
	{
		"id": "arch_stone", "count": 1, "requires_table": true,
		"ingredients": [{"id": "stone_brick", "count": 3}],
	},
	# ----------------------------------------------------------------
	# NEW BLOCKS — wood variants
	# ----------------------------------------------------------------
	{
		"id": "planks_spruce", "count": 4, "requires_table": false,
		"ingredients": [{"id": "log_spruce", "count": 1}],
	},
	{
		"id": "planks_jungle", "count": 4, "requires_table": false,
		"ingredients": [{"id": "log_jungle", "count": 1}],
	},
	{
		"id": "planks_dark_oak", "count": 4, "requires_table": false,
		"ingredients": [{"id": "log_oak", "count": 1}],
	},
	# ----------------------------------------------------------------
	# NEW BLOCKS — decorative/structural
	# ----------------------------------------------------------------
	{
		"id": "window_glass", "count": 4, "requires_table": true,
		"ingredients": [{"id": "sand", "count": 4}],
	},
	{
		"id": "fence_wood", "count": 3, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 4}, {"id": "stick", "count": 2}],
	},
	{
		"id": "fence_stone_wall", "count": 3, "requires_table": true,
		"ingredients": [{"id": "cobblestone", "count": 6}],
	},
	{
		"id": "bookshelf", "count": 1, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 6}, {"id": "coal", "count": 1}],
	},
	{
		"id": "hay_bale", "count": 1, "requires_table": false,
		"ingredients": [{"id": "wheat", "count": 9}],
	},
	{
		"id": "barrel", "count": 1, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 6}, {"id": "stick", "count": 2}],
	},
	{
		"id": "stairs_stone", "count": 4, "requires_table": true,
		"ingredients": [{"id": "cobblestone", "count": 6}],
	},
	{
		"id": "stairs_wood", "count": 4, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 6}],
	},
	{
		"id": "slab_stone", "count": 6, "requires_table": true,
		"ingredients": [{"id": "cobblestone", "count": 3}],
	},
	{
		"id": "slab_wood", "count": 6, "requires_table": true,
		"ingredients": [{"id": "planks_oak", "count": 3}],
	},
	{
		"id": "anvil", "count": 1, "requires_table": true,
		"ingredients": [{"id": "iron_ingot", "count": 3}, {"id": "cobblestone", "count": 4}],
	},
	{
		"id": "workbench_stone", "count": 1, "requires_table": false,
		"ingredients": [{"id": "cobblestone", "count": 4}],
	},
	# ----------------------------------------------------------------
	# NEW BLOCKS — ore/resource
	# ----------------------------------------------------------------
	{
		"id": "quartz_block", "count": 4, "requires_table": false,
		"ingredients": [{"id": "quartz", "count": 4}],
	},

	# Bucket — 3 iron ingots
	{
		"id": "bucket_empty", "count": 1, "requires_table": true,
		"ingredients": [{"id": "iron_ingot", "count": 3}],
	},

	# ----------------------------------------------------------------
	# BUILDING & DECORATIVE BLOCK RECIPES
	# ----------------------------------------------------------------
	{
		"id": "brick_wall", "count": 4, "requires_table": false,
		"ingredients": [{"id": "brick", "count": 4}],
	},
	{
		"id": "stone_brick", "count": 4, "requires_table": false,
		"ingredients": [{"id": "stone", "count": 4}],
	},
	{
		"id": "wood_plank_wall", "count": 4, "requires_table": false,
		"ingredients": [{"id": "planks_oak", "count": 2}],
	},
	{
		"id": "iron_block", "count": 1, "requires_table": true,
		"ingredients": [{"id": "iron_ingot", "count": 9}],
	},
	{
		"id": "gold_block", "count": 1, "requires_table": true,
		"ingredients": [{"id": "gold_ingot", "count": 9}],
	},
	{
		"id": "glass_pane", "count": 4, "requires_table": false,
		"ingredients": [{"id": "window_glass", "count": 4}],
	},
	{
		"id": "marble", "count": 4, "requires_table": true,
		"ingredients": [{"id": "stone", "count": 4}],
	},
	{
		"id": "cobblestone_wall", "count": 4, "requires_table": false,
		"ingredients": [{"id": "cobblestone", "count": 4}],
	},
	{
		"id": "mossy_cobblestone", "count": 4, "requires_table": false,
		"ingredients": [{"id": "cobblestone", "count": 4}, {"id": "vines", "count": 1}],
	},
	{
		"id": "clay_brick", "count": 4, "requires_table": false,
		"requires_furnace": true,
		"smelt_time": 3.0,
		"ingredients": [{"id": "clay_ball", "count": 4}],
	},
	{
		"id": "wood_beam", "count": 4, "requires_table": false,
		"ingredients": [{"id": "log_oak", "count": 1}],
	},

	# ---- ADD NEW RECIPES ABOVE THIS LINE ----

	# ----------------------------------------------------------------
	# FURNACE SMELTING — requires_furnace = true
	# Player must interact with a furnace block to access these.
	# smelt_time = seconds per operation (default 3.0).
	# ----------------------------------------------------------------
	{
		"id": "iron_ingot",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 3.0,
		"ingredients": [{"id": "iron_ore", "count": 1}],
	},
	{
		"id": "gold_ingot",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 4.0,
		"ingredients": [{"id": "gold_ore", "count": 1}],
	},
	{
		"id": "window_glass",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 2.0,
		"ingredients": [{"id": "sand", "count": 1}],
	},
	{
		"id": "charcoal",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 2.5,
		"ingredients": [{"id": "log_oak", "count": 1}],
	},
	{
		"id": "cooked_beef",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 2.0,
		"ingredients": [{"id": "raw_beef", "count": 1}],
	},
	{
		"id": "cooked_pork",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 2.0,
		"ingredients": [{"id": "raw_pork", "count": 1}],
	},
	{
		"id": "cooked_chicken",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 2.0,
		"ingredients": [{"id": "raw_chicken", "count": 1}],
	},
	{
		"id": "brick",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 3.0,
		"ingredients": [{"id": "clay", "count": 1}],
	},
	{
		"id": "copper_ingot",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 3.0,
		"ingredients": [{"id": "copper_ore", "count": 1}],
	},
	{
		"id": "silver_ingot",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 4.0,
		"ingredients": [{"id": "silver_ore", "count": 1}],
	},
	{
		"id": "diamond",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 5.0,
		"ingredients": [{"id": "diamond_ore", "count": 1}],
	},
	{
		"id": "ruby",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 5.0,
		"ingredients": [{"id": "ruby_ore", "count": 1}],
	},
	{
		"id": "emerald",
		"count": 1,
		"requires_table": false,
		"requires_furnace": true,
		"smelt_time": 5.0,
		"ingredients": [{"id": "emerald_ore", "count": 1}],
	},

	# ----------------------------------------------------------------
	# WEAPONS — crafting table required
	# ----------------------------------------------------------------
	{
		"id": "iron_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 2},
			{"id": "stick",      "count": 1},
		],
	},
	{
		"id": "gold_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "gold_ingot", "count": 2},
			{"id": "stick",      "count": 1},
		],
	},
	{
		"id": "diamond_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "diamond",    "count": 2},
			{"id": "stick",      "count": 1},
		],
	},
	{
		"id": "iron_axe",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "gold_axe",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "gold_ingot", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "diamond_axe",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "diamond",    "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "iron_pick",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "gold_pick",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "gold_ingot", "count": 3},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "diamond_pick",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "diamond",    "count": 3},
			{"id": "stick",      "count": 2},
		],
	},

	# ── Katana & Special Weapons ─────────────────────────────────────────────
	{
		"id": "katana",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 3},
			{"id": "stick",      "count": 1},
		],
	},
	{
		"id": "gold_sword",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "gold_ingot", "count": 2},
			{"id": "stick",      "count": 1},
		],
	},

	# ── Ranged Weapons ───────────────────────────────────────────────────────
	{
		"id": "wood_bow",
		"count": 1,
		"requires_table": false,
		"ingredients": [
			{"id": "stick",      "count": 3},
			{"id": "planks_oak", "count": 2},
		],
	},
	{
		"id": "iron_bow",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 2},
			{"id": "stick",      "count": 2},
		],
	},
	{
		"id": "crossbow",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 3},
			{"id": "stick",      "count": 2},
			{"id": "planks_oak", "count": 1},
		],
	},
	{
		"id": "pistol",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 4},
			{"id": "coal",       "count": 2},
		],
	},
	{
		"id": "rifle",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 6},
			{"id": "coal",       "count": 4},
		],
	},
	{
		"id": "shotgun",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 5},
			{"id": "gold_ingot", "count": 1},
			{"id": "coal",       "count": 3},
		],
	},
	{
		"id": "machine_gun",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 8},
			{"id": "diamond",    "count": 1},
			{"id": "coal",       "count": 6},
		],
	},
	{
		"id": "flamethrower",
		"count": 1,
		"requires_table": true,
		"ingredients": [
			{"id": "iron_ingot", "count": 6},
			{"id": "gold_ingot", "count": 2},
			{"id": "coal",       "count": 8},
		],
	},

	# ── Ammo ────────────────────────────────────────────────────────────────
	{
		"id": "bullet",
		"count": 8,
		"requires_table": false,
		"requires_furnace": false,
		"ingredients": [
			{"id": "iron_ingot", "count": 1},
		],
	},
]

# ------------------------------------------------------------------
# RECIPE LOOKUP CACHE
# Built lazily on first call to avoid startup overhead.
# ------------------------------------------------------------------
var _recipe_cache: Dictionary = {}  # recipe_id -> recipe Dictionary

func _ensure_cache() -> void:
	if not _recipe_cache.is_empty():
		return
	for recipe in RECIPES:
		_recipe_cache[recipe["id"]] = recipe

# ------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------

## Returns true if the player has enough ingredients and the location requirements
## (near crafting table, near furnace) are satisfied.
##
## inventory    : Array of { "id": String, "count": int } slot dicts.
## near_table   : true when player is adjacent to a crafting table.
## near_furnace : true when player is adjacent to a furnace (FurnaceUI passes this).
func can_craft(recipe_id: String, inventory: Array,
		near_table: bool = false, near_furnace: bool = false) -> bool:
	_ensure_cache()
	if not _recipe_cache.has(recipe_id):
		push_warning("CraftingSystem.can_craft: unknown recipe '%s'" % recipe_id)
		return false

	var recipe: Dictionary = _recipe_cache[recipe_id]

	# Location checks.
	if recipe.get("requires_table", false) and not near_table:
		return false
	# Furnace recipes are only available when near a furnace.
	if recipe.get("requires_furnace", false) and not near_furnace:
		return false

	# Check each ingredient.
	for ingredient in recipe["ingredients"]:
		if _count_item(inventory, ingredient["id"]) < int(ingredient["count"]):
			return false

	return true

## Attempts to craft recipe_id.
## On success: removes ingredients from inventory, adds the crafted item, returns true.
## On failure: leaves inventory untouched, returns false.
##
## inventory    : Array of item Dictionaries (mutated in place).
## near_table   : true when player is adjacent to a crafting table.
## near_furnace : true when calling from FurnaceUI.
func craft(recipe_id: String, inventory: Array,
		near_table: bool = false, near_furnace: bool = false) -> bool:
	if not can_craft(recipe_id, inventory, near_table, near_furnace):
		return false

	_ensure_cache()
	var recipe: Dictionary = _recipe_cache[recipe_id]

	# Remove ingredients.
	for ingredient in recipe["ingredients"]:
		_remove_item(inventory, ingredient["id"], int(ingredient["count"]))

	# Add the crafted item.
	_add_item(inventory, recipe["id"], int(recipe["count"]))

	# Notify quest system.
	var _qs := get_node_or_null("/root/QuestSystem")
	if _qs != null:
		_qs.on_item_crafted(recipe["id"], int(recipe["count"]))

	return true

## Returns all recipes the player can currently craft given their inventory
## and context (near table, near furnace).
## Pass near_furnace=true to get furnace-only recipes; those are excluded by default.
func get_available_recipes(inventory: Array,
		near_table: bool = false, near_furnace: bool = false) -> Array:
	var result: Array = []
	for recipe in RECIPES:
		if can_craft(recipe["id"], inventory, near_table, near_furnace):
			result.append(recipe)
	return result

## Returns only furnace recipes (requires_furnace = true), regardless of inventory.
## Used by FurnaceUI to build its full recipe list.
func get_furnace_recipes() -> Array:
	var result: Array = []
	for recipe in RECIPES:
		if recipe.get("requires_furnace", false):
			result.append(recipe)
	return result

## Returns a flat copy of the full RECIPES array.
## Useful for populating a recipe book / discovery UI.
func get_all_recipes() -> Array:
	return RECIPES.duplicate(false)

# ------------------------------------------------------------------
# INVENTORY HELPERS
# These operate on an Array of { "id": String, "count": int } dicts.
# Replace with calls to your own inventory class if it exposes a
# different interface.
# ------------------------------------------------------------------

## Returns the total count of item_id across all stacks in inventory.
func _count_item(inventory: Array, item_id: String) -> int:
	var total: int = 0
	for slot in inventory:
		if slot.get("id", "") == item_id:
			total += int(slot.get("count", 0))
	return total

## Removes `amount` of item_id from inventory, consuming stacks as needed.
## Assumes can_craft() was checked first so there is enough stock.
func _remove_item(inventory: Array, item_id: String, amount: int) -> void:
	var remaining: int = amount
	for slot in inventory:
		if remaining <= 0:
			break
		if slot.get("id", "") != item_id:
			continue
		var take: int = mini(int(slot.get("count", 0)), remaining)
		slot["count"] -= take
		remaining -= take

	# Clean up empty stacks.
	var i: int = inventory.size() - 1
	while i >= 0:
		if inventory[i].get("count", 0) <= 0:
			inventory.remove_at(i)
		i -= 1

## Adds `amount` of item_id to inventory.
## Merges into an existing stack if one is found; otherwise appends a new slot.
func _add_item(inventory: Array, item_id: String, amount: int) -> void:
	# Try to merge into an existing stack first.
	for slot in inventory:
		if slot.get("id", "") == item_id:
			slot["count"] = int(slot.get("count", 0)) + amount
			return
	# No existing stack — create a new one.
	inventory.append({"id": item_id, "count": amount})
