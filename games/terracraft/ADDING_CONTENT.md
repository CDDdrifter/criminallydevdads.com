# TerraCraft — Content Addition Guide

Everything you need to add any item, block, tool, food, ore, or custom asset.
Work through each section that applies to what you're adding.

---

## TABLE OF CONTENTS

1. [File Map — which file does what](#1-file-map)
2. [Item Types — what fields each type needs](#2-item-types)
3. [Step-by-step: Add a BLOCK (placed in world, mined)](#3-add-a-block)
4. [Step-by-step: Add an ORE (spawns underground)](#4-add-an-ore)
5. [Step-by-step: Add a TOOL or WEAPON](#5-add-a-tool-or-weapon)
6. [Step-by-step: Add FOOD](#6-add-food)
7. [Step-by-step: Add a MATERIAL / RESOURCE (not placeable)](#7-add-a-material--resource)
8. [Step-by-step: Add a CRAFTING RECIPE](#8-add-a-crafting-recipe)
9. [Step-by-step: Add a SURFACE DECORATION (spawns on world surface)](#9-add-a-surface-decoration)
10. [Step-by-step: Add a LIGHT-EMITTING BLOCK](#10-add-a-light-emitting-block)
11. [Step-by-step: Swap / Override any VISUAL (PNG art)](#11-swap-any-visual-with-a-png)
12. [Field Reference — every field explained](#12-field-reference)

---

## 1. File Map

| File | What it controls |
|------|-----------------|
| `scripts/ItemDatabase.gd` | Every item, block, tool, food — their stats, icon color, stack size, drop |
| `scripts/TileTextureGenerator.gd` | Procedural tile art + icon art. ATLAS_LAYOUT controls which tiles exist in the world renderer |
| `scripts/WorldGenerator.gd` | What the world generates (ores, surface blocks, decorations, biomes) |
| `scripts/CraftingSystem.gd` | All crafting recipes |
| `scripts/Chunk.gd` | PASSABLE_TILES — things with no collision (torches, plants, water) |
| `scripts/WeatherSystem.gd` | BURNABLE — things lightning can destroy |
| `assets/tiles/` | Drop a PNG here to override a world tile's appearance |
| `assets/items/` | Drop a PNG here to override an inventory icon |

---

## 2. Item Types

Every item in `ItemDatabase.gd` has a `"type"` field. Here's what each type means
and what optional fields matter for it:

| type | Placed in world | Mined | Equipped | Eaten | Notes |
|------|:-:|:-:|:-:|:-:|-------|
| `"block"` | yes | yes | no | no | needs `tile_id`, `mine_level`, `tool_type`, `drop_item` |
| `"material"` | no | no | no | no | raw resources, ingots, gems — just `max_stack` |
| `"tool"` | no | no | yes | no | needs `tool_speed`, `tool_type`, `mine_level`, `damage` |
| `"weapon"` | no | no | yes | no | needs `damage`; optionally `tool_speed`/`tool_type` |
| `"food"` | no | no | no | yes | needs `edible: true`, `food_value` |
| `"armor"` | no | no | yes | no | needs `defense` field |

---

## 3. Add a Block

A "block" is anything that exists as a solid tile in the world AND can sit in
your inventory. Minimal example: `ruby_block`.

### Step 1 — ItemDatabase.gd
Open `scripts/ItemDatabase.gd`. Find the section that matches your block type
(natural blocks, ores, furniture, etc.) and add a new entry:

```gdscript
"ruby_block": {
    "name": "Ruby Block",           # shown in inventory tooltip
    "type": "block",
    "icon_color": Color(0.87, 0.12, 0.22), # fallback color if no PNG
    "icon_shape": "square",         # used for procedural icon
    "max_stack": 99,
    "placeable": true,              # can the player place this?
    "tile_id": Vector2i(5, 9),      # atlas column, row (pick an unused slot)
    "edible": false, "food_value": 0,
    "damage": 0,
    "tool_speed": 1.0,
    "tool_type": "pick",            # what tool mines it fastest
    "mine_level": 3,                # 0=hand 1=wood 2=stone 3=iron 4=diamond
    "drop_item": "ruby_block",      # what drops when mined
    "drop_count": 1,
},
```

### Step 2 — TileTextureGenerator.gd (register in atlas)
Open `scripts/TileTextureGenerator.gd`.

**2a.** Find `ATLAS_LAYOUT` and add a row — use the same atlas coords as `tile_id` above:
```gdscript
["ruby_block", 5, 9, "solid"],   # [id, atlas_x, atlas_y, draw_style]
```
Place it in the row that matches atlas row 9. If row 9 doesn't exist yet, add it
after the last row — just make sure atlas_x stays within 0–15 (16 columns max).

**2b.** Find `TILE_COLORS` and add the base color:
```gdscript
"ruby_block": Color(0.87, 0.12, 0.22),
```

**2c.** (Optional) Add a custom draw style in `_draw_tile()` if "solid" doesn't
look right. Copy the `"stone"` or `"ore"` case and rename it.

OR — skip steps 2a/2b/2c entirely and just drop a 16×16 PNG at
`assets/tiles/ruby_block.png` (see Section 11).

### Step 3 — Chunk.gd (only if the block has no collision)
Open `scripts/Chunk.gd`. Find `PASSABLE_TILES`. Add your block ID here ONLY if
players should walk through it (like torches, plants, water):
```gdscript
"ruby_block": true,   # only add this line if it has NO collision
```
Leave it out if it's a solid block — that's the default.

### Step 4 — Crafting (optional)
If the block can be crafted, see Section 8.

### Step 5 — Test
Launch the game. Open inventory and use the `/give` command or place it via
crafting. If the tile appears pink/magenta in the world, the atlas_x/atlas_y
doesn't match or the ATLAS_LAYOUT entry is missing.

---

## 4. Add an Ore

Ores spawn underground automatically via `ORE_RULES`. You need the block entry
(Section 3) PLUS two extra things.

### Step 1 — Follow Section 3 for the ore block
Example for `"amethyst_ore"`. Use `"mine_level": 2` for stone-tier, etc.
The `"drop_item"` should be the raw gem/ingot, not the ore itself:
```gdscript
"amethyst_ore": {
	...same as any block...
	"mine_level": 2,
	"drop_item": "amethyst_gem",   # what drops when mined
	"drop_count": [1, 2],          # [min, max] for random drop count
},
```

### Step 2 — WorldGenerator.gd (make it generate underground)
Open `scripts/WorldGenerator.gd`. Find `ORE_RULES`:
```gdscript
const ORE_RULES: Array[Dictionary] = [
	{ "id": "coal_ore",    "min_depth":   5, "max_depth":  20, "rarity": 0.28 },
	...
	# ADD YOUR ORE HERE:
	{ "id": "amethyst_ore", "min_depth": 80, "max_depth": 200, "rarity": 0.09 },
]
```
- `min_depth` / `max_depth` — tile rows below the surface (5 = just underground, 250 = near bedrock)
- `rarity` — 0.0 to 1.0. 0.28 = very common, 0.08 = rare. Keep new ores 0.05–0.15.

That's all for ore spawning. Nothing else to change.

### Step 3 — Add the drop item (the gem/ingot)
The `"drop_item"` must also exist in `ItemDatabase.gd` as a material:
```gdscript
"amethyst_gem": {
    "name": "Amethyst Gem", "type": "material",
    "icon_color": Color(0.60, 0.20, 0.80), "icon_shape": "diamond",
    "max_stack": 64, "placeable": false, "tile_id": Vector2i(-1, -1),
    "edible": false, "food_value": 0, "damage": 0,
    "tool_speed": 1.0, "tool_type": null, "mine_level": 0,
    "drop_item": null, "drop_count": 0,
},
```
Materials don't need atlas entries — they only show up in inventory.

---

## 5. Add a Tool or Weapon

Tools and weapons are NOT placeable, don't need atlas entries, and use procedural
icons unless you supply a PNG.

### Step 1 — ItemDatabase.gd

**Tool example** (`amethyst_pickaxe`):
```gdscript
"amethyst_pickaxe": {
    "name": "Amethyst Pickaxe", "type": "tool",
    "icon_color": Color(0.60, 0.20, 0.80), "icon_shape": "pick",
    "max_stack": 1,
    "placeable": false, "tile_id": Vector2i(-1, -1),
    "edible": false, "food_value": 0,
    "damage": 4,                  # damage to enemies on hit
    "tool_speed": 3.5,            # mining speed multiplier (1.0 = bare hand, wood=1.5, iron=2.5)
    "tool_type": "pick",          # "pick" | "axe" | "shovel" | "sword"
    "mine_level": 3,              # unlocks iron-level blocks and below
    "drop_item": null, "drop_count": 0,
    "durability": 400,            # optional — how many uses before breaking
},
```

**Weapon example** (`ruby_sword`):
```gdscript
"ruby_sword": {
    "name": "Ruby Sword", "type": "weapon",
    "icon_color": Color(0.87, 0.12, 0.22), "icon_shape": "sword",
    "max_stack": 1,
    "placeable": false, "tile_id": Vector2i(-1, -1),
    "edible": false, "food_value": 0,
    "damage": 18,                 # damage per swing
    "tool_speed": 1.0,
    "tool_type": "sword",
    "mine_level": 0,
    "drop_item": null, "drop_count": 0,
    "durability": 600,
},
```

### Step 2 — CraftingSystem.gd
Add a recipe (see Section 8). Tools are normally crafted at a table.

### Step 3 — (Optional) Custom icon
Drop `assets/items/amethyst_pickaxe.png` to override the procedural icon.

---

## 6. Add Food

```gdscript
"blueberry": {
    "name": "Blueberry", "type": "food",
    "icon_color": Color(0.30, 0.20, 0.80), "icon_shape": "circle",
    "max_stack": 16,
    "placeable": false, "tile_id": Vector2i(-1, -1),
    "edible": true,
    "food_value": 15,             # hunger restored (max 100)
    "damage": 0,
    "tool_speed": 1.0, "tool_type": null, "mine_level": 0,
    "drop_item": null, "drop_count": 0,
},
```

No atlas entry needed. Optionally add a PNG at `assets/items/blueberry.png`.

---

## 7. Add a Material / Resource

Pure inventory item — no world presence, no eating, no placing.
Ingots, gems, string, feathers, etc.

```gdscript
"iron_ingot": {
    "name": "Iron Ingot", "type": "material",
    "icon_color": Color(0.75, 0.75, 0.75), "icon_shape": "square",
    "max_stack": 64,
    "placeable": false, "tile_id": Vector2i(-1, -1),
    "edible": false, "food_value": 0, "damage": 0,
    "tool_speed": 1.0, "tool_type": null, "mine_level": 0,
    "drop_item": null, "drop_count": 0,
},
```

---

## 8. Add a Crafting Recipe

Open `scripts/CraftingSystem.gd`. Find the `RECIPES` array.
Add a new Dictionary anywhere in the array (order doesn't matter):

```gdscript
{
	"id": "amethyst_pickaxe",   # item_id that gets crafted (must exist in ItemDatabase)
	"count": 1,                  # how many the player receives
	"requires_table": true,      # true = must stand near a crafting table
	"ingredients": [
		{"id": "amethyst_gem", "count": 3},
		{"id": "stick",        "count": 2},
	],
},
```

Rules:
- `"id"` must already exist in `ItemDatabase.gd`
- Every ingredient `"id"` must also exist in `ItemDatabase.gd`
- `"requires_table": false` = player can craft from inventory screen anywhere
- `"requires_table": true` = player must be near a placed `crafting_table` block
- There is no limit on ingredient count

---

## 9. Add a Surface Decoration

Surface decorations are blocks placed on top of the ground during world generation
(tall grass, cactus, saplings, mushrooms, etc.).

### Step 1 — Add the block to ItemDatabase.gd and TileTextureGenerator.gd
Follow Section 3. Make sure `"placeable": false` if players shouldn't place it
by hand, OR `"placeable": true` if they can.

Add it to `Chunk.PASSABLE_TILES` if it has no collision (plants, flowers, etc.).

### Step 2 — WorldGenerator.gd
Open `scripts/WorldGenerator.gd`. Find `_place_surface_decor()`.
Add your decoration logic inside the biome `match` block:

```gdscript
_BiomeType.PLAINS:
    if rng.randf() < 0.08:
        _place_tree(tiles, local_x, surface_y, "oak", rng)
    elif surface_tile == "grass" and rng.randf() < 0.40:
        tiles[Vector2i(local_x, surface_y - 1)] = "tall_grass"
    # ADD YOUR DECORATION — example: mushrooms in plains, 2% chance
    elif surface_tile == "grass" and rng.randf() < 0.02:
        tiles[Vector2i(local_x, surface_y - 1)] = "mushroom_red"
```

`surface_y - 1` = one tile above the ground (that's where decorations sit).
`surface_y` = the ground tile itself.

To add to ALL biomes, put it outside the `match` block after it.

### Step 3 — WeatherSystem.gd (optional)
If your decoration is organic/flammable and should burn during lightning strikes:
```gdscript
const BURNABLE: Array = [
	"grass", "dirt_with_grass", ...
	"mushroom_red",   # add your tile id here
]
```

---

## 10. Add a Light-Emitting Block

Any block can emit a PointLight2D by adding two fields to its ItemDatabase entry:

```gdscript
"glowstone": {
	...all normal block fields...
	"light_radius": 9.0,                      # radius of the light cone in tiles
	"light_color":  Color(1.0, 0.95, 0.6, 1.0), # light tint color
},
```

That's it. `World.gd` automatically reads these fields when the block is placed
and creates a PointLight2D node. Removing the block removes the light.

For flickering: the existing flicker system in `World.gd` applies to ALL placed
lights automatically — no extra work needed.

Typical `light_radius` values for reference:
- Torch: 8.0
- Campfire: 10.0
- Torch wall: 7.0
- Glowstone (if you add it): 9.0

---

## 11. Swap Any Visual With a PNG

No code required. Just drop a PNG file in the right folder and relaunch.

### World tile (how it looks placed in the world)
```
assets/tiles/{tile_id}.png
```
Example: `assets/tiles/grass.png` replaces the grass block in the world.

### Inventory / hotbar icon
```
assets/items/{item_id}.png
```
Example: `assets/items/iron_sword.png` replaces the iron sword icon.

Rules for both:
- File name must exactly match the item/tile ID (lowercase, underscores, no spaces)
- Recommended size: **16×16 pixels** (any size is accepted, scaled to 16×16)
- Transparent PNG works
- Item icon PNGs override BOTH block icons AND tool/weapon procedural icons
- After dropping a new PNG, right-click it in Godot FileSystem → **Reimport**, then relaunch

The full list of tile IDs is in `TileTextureGenerator.gd → ATLAS_LAYOUT`.
The full list of item IDs is in `ItemDatabase.gd → items` dictionary keys.

---

## 12. Field Reference

Complete list of every field used in `ItemDatabase.gd` entries:

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `name` | String | yes | Display name shown in UI tooltips |
| `type` | String | yes | `"block"` `"tool"` `"weapon"` `"food"` `"material"` `"armor"` |
| `icon_color` | Color | yes | Fallback color for procedural icon (used if no PNG) |
| `icon_shape` | String | yes | `"square"` `"circle"` `"diamond"` — shape for procedural icon |
| `max_stack` | int | yes | Max items per inventory slot. 1 for tools/weapons |
| `placeable` | bool | yes | Can the player place this as a world tile? |
| `tile_id` | Vector2i | yes | Atlas column,row for world rendering. `Vector2i(-1,-1)` if not placeable |
| `edible` | bool | yes | Can the player eat this? |
| `food_value` | float | yes | Hunger restored when eaten (0–100). 0 if not edible |
| `damage` | float | yes | Damage dealt to enemies per hit. 0 if not a weapon |
| `tool_speed` | float | yes | Mining speed multiplier. 1.0 = bare hand baseline |
| `tool_type` | String/null | yes | `"pick"` `"axe"` `"shovel"` `"sword"` or `null` |
| `mine_level` | int | yes | Min tool tier to harvest this block. 0=any, 1=wood+, 2=stone+, 3=iron+, 4=diamond+ |
| `drop_item` | String/null | yes | Item ID that drops when block is broken. `null` = nothing |
| `drop_count` | int or Array | yes | How many drop. Use `[min, max]` array for random range |
| `light_radius` | float | optional | If set, block emits a PointLight2D with this radius (in tiles) |
| `light_color` | Color | optional | Color of emitted light (only used if `light_radius` is set) |
| `durability` | int | optional | Uses before tool/weapon breaks. Omit = unbreakable |
| `defense` | float | optional | Damage reduction when worn (armor type only) |

---

## Quick Checklist by Item Type

### New ORE
- [ ] `ItemDatabase.gd` — ore block entry (`type: "block"`, `mine_level` 1–4)
- [ ] `ItemDatabase.gd` — drop material entry (`type: "material"`)
- [ ] `TileTextureGenerator.gd` — add to `ATLAS_LAYOUT` + `TILE_COLORS`
- [ ] `WorldGenerator.gd` — add to `ORE_RULES`
- [ ] (optional) `CraftingSystem.gd` — smelt recipe if needed
- [ ] (optional) `assets/tiles/your_ore.png`

### New TOOL
- [ ] `ItemDatabase.gd` — tool entry (`type: "tool"`, `tool_type`, `tool_speed`, `mine_level`)
- [ ] `CraftingSystem.gd` — crafting recipe
- [ ] (optional) `assets/items/your_tool.png`

### New PLACEABLE BLOCK (furniture, decorative, etc.)
- [ ] `ItemDatabase.gd` — block entry
- [ ] `TileTextureGenerator.gd` — `ATLAS_LAYOUT` + `TILE_COLORS`
- [ ] `Chunk.gd` `PASSABLE_TILES` — only if no collision
- [ ] (optional) `CraftingSystem.gd` — recipe
- [ ] (optional) `assets/tiles/your_block.png`

### New SURFACE DECORATION (plant, flower, mushroom)
- [ ] `ItemDatabase.gd` — block entry (`placeable: false` or true)
- [ ] `TileTextureGenerator.gd` — `ATLAS_LAYOUT` + `TILE_COLORS`
- [ ] `Chunk.gd` `PASSABLE_TILES` — add it (decorations shouldn't block movement)
- [ ] `WorldGenerator.gd` `_place_surface_decor()` — add spawn logic
- [ ] (optional) `WeatherSystem.gd` `BURNABLE` — if it should burn in lightning
- [ ] (optional) `assets/tiles/your_decor.png`

### New FOOD
- [ ] `ItemDatabase.gd` — food entry (`edible: true`, `food_value`)
- [ ] (optional) `CraftingSystem.gd` — recipe
- [ ] (optional) `assets/items/your_food.png`
