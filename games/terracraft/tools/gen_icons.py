"""
gen_icons.py — TerraCraft icon generator
=========================================
Generates 32×32 RGBA PNG icon files for weapon/tool tiers that don't have
unique sprites. Uses the diamond-tier cells from master_weapon.png as a base,
then applies a hue/saturation shift to produce tinted variants.

Output files go into subdirectories under assets/items/:
    assets/items/ruby_sword/ruby_sword.png
    assets/items/emerald_pick/emerald_pick.png
    ... etc.

TileTextureGenerator.gd checks for <id>/<id>.png BEFORE falling back to the
atlas_coords lookup in ItemDatabase.gd, so these PNGs take automatic priority.

Run from the TerraCraft project root:
    python tools/gen_icons.py

Requirements:
    pip install Pillow

────────────────────────────────────────────────────────
 HOW TO ADD A NEW TIER
────────────────────────────────────────────────────────
1.  Pick source cells from master_weapon.png.
    The atlas is 32×32 cells, each 32×32 pixels.
    Row 2 holds the main weapon/tool row — see ItemDatabase.gd atlas_coords.
    Example source cells (col, row):
        diamond_sword  → (14, 2)
        diamond_pick   → (13, 2)
        diamond_axe    → (12, 2)
        diamond_shovel → ( 4, 2)   ← shared by all shovel tiers
        iron_sword     → ( 6, 2)   ← used as katana base

2.  Choose a hue (H) and saturation (S) for the new tier.
    H is 0.0-1.0 where:
        0.00 = red       (ruby)
        0.08 = orange
        0.13 = gold/yellow
        0.36 = green     (emerald)
        0.50 = cyan
        0.60 = blue
        0.75 = purple
    S is 0.0 (grey) to 1.0 (vivid).

3.  Add a block like this:

        print("\\n[my_new_tier]")
        MY_H, MY_S = 0.75, 0.90   # purple, vivid
        save(tint(d_sword,  MY_H, MY_S), "mytier_sword")
        save(tint(d_pick,   MY_H, MY_S), "mytier_pick")
        save(tint(d_axe,    MY_H, MY_S), "mytier_axe")
        save(tint(d_shovel, MY_H, MY_S), "mytier_shovel")

4.  Run the script and reload Godot.

────────────────────────────────────────────────────────
 HOW TO ADD AN ICON FOR BLOCKS / ORES / FOOD
────────────────────────────────────────────────────────
Blocks don't use master_weapon.png — they use the tile atlas (tiles.png or
similar) configured in TileTextureGenerator.SPRITE_ATLASES.

To add a custom block icon, just drop:
    assets/items/<item_id>.png   (or <item_id>/<item_id>.png)

You can also generate tinted block icons here if you have a source cell
from the block atlas.  Crop from that atlas instead of master_weapon.png:

    block_atlas = Image.open(r"assets\\textures\\tiles.png").convert("RGBA")
    ore_cell = crop_cell(block_atlas, col, row)
    save(tint(ore_cell, 0.36, 0.85), "emerald_ore")

────────────────────────────────────────────────────────
 CHANGING BASE SPRITES
────────────────────────────────────────────────────────
If you draw new sprites directly into master_weapon.png (e.g. a proper axe
shape in row 3), update the crop_cell() calls at the top of main() to point
to your new cell:
    d_axe = crop_cell(atlas, 0, 3)   # your new axe in row 3, col 0
"""

import sys
import os
from PIL import Image
import colorsys

# ─────────────────────────────────────────────
#  PATHS  (relative to project root)
# ─────────────────────────────────────────────
ATLAS   = r"assets\items\master_weapon.png"
OUT_DIR = r"assets\items"
CELL    = 32   # each atlas cell is 32×32 pixels


def crop_cell(atlas_img: Image.Image, col: int, row: int) -> Image.Image:
    """
    Return a 32×32 RGBA crop from the atlas at grid position (col, row).
    col and row are 0-based atlas grid coordinates — same as atlas_coords
    in ItemDatabase.gd.

    Row 2 is the weapon/tool row.  Row 0-1 are blocks/furniture.
    Rows 3-31 are empty — use them for new custom sprites.
    """
    x = col * CELL
    y = row * CELL
    return atlas_img.crop((x, y, x + CELL, y + CELL)).convert("RGBA")


def tint(src: Image.Image, target_h: float, target_s: float,
         min_l: float = 0.15, max_l: float = 0.92) -> Image.Image:
    """
    Hue-replace every opaque pixel in src, preserving luminance structure.

    Parameters
    ----------
    target_h : float  0.0-1.0 hue of the output color.
                      0.00 = red, 0.13 = gold, 0.36 = green, 0.60 = blue
    target_s : float  0.0-1.0 saturation (0=greyscale, 1=vivid).
    min_l    : float  Minimum lightness — dark pixels won't go pure black.
    max_l    : float  Maximum lightness — bright pixels won't go pure white.

    Returns a new 32×32 RGBA image.
    """
    out = Image.new("RGBA", src.size)
    pixels_in  = src.load()
    pixels_out = out.load()

    for py in range(src.height):
        for px in range(src.width):
            r, g, b, a = pixels_in[px, py]
            if a < 8:
                # Fully transparent — preserve as transparent.
                pixels_out[px, py] = (0, 0, 0, 0)
                continue

            # Compute luminance of original pixel (perceptual weights).
            orig_l = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            # Remap to [min_l, max_l] to preserve dark/light detail.
            l = min_l + orig_l * (max_l - min_l)

            new_r, new_g, new_b = colorsys.hls_to_rgb(target_h, l, target_s)
            pixels_out[px, py] = (
                int(new_r * 255),
                int(new_g * 255),
                int(new_b * 255),
                a,
            )

    return out


def save(img: Image.Image, item_id: str) -> None:
    """
    Save img to assets/items/<item_id>/<item_id>.png.

    The subdirectory structure is preferred by TileTextureGenerator.
    If the subdirectory doesn't exist it is created automatically.
    """
    subdir = os.path.join(OUT_DIR, item_id)
    os.makedirs(subdir, exist_ok=True)
    path = os.path.join(subdir, f"{item_id}.png")
    img.save(path)
    print(f"  saved  {path}")


def main() -> None:
    if not os.path.exists(ATLAS):
        sys.exit(
            f"ERROR: atlas not found at {ATLAS!r}\n"
            f"Run this script from the TerraCraft project root directory."
        )

    atlas = Image.open(ATLAS).convert("RGBA")
    print(f"Atlas: {atlas.size[0]}×{atlas.size[1]} "
          f"({atlas.size[0]//CELL} cols × {atlas.size[1]//CELL} rows)")

    # ──────────────────────────────────────────────────────────────
    #  SOURCE CELLS  (col, row) from master_weapon.png
    #
    #  These are the diamond-tier sprites — best quality base for tinting.
    #  atlas_coords in ItemDatabase.gd tells you where each sprite lives.
    #  Row 2 = main weapon/tool row.  Each cell is 32×32 px.
    #
    #  To use a different base, change the (col, row) arguments.
    # ──────────────────────────────────────────────────────────────
    d_pick   = crop_cell(atlas, 13, 2)   # diamond_pick  — pick shape
    d_axe    = crop_cell(atlas, 12, 2)   # diamond_axe   — axe shape
    d_sword  = crop_cell(atlas, 14, 2)   # diamond_sword — sword shape
    d_shovel = crop_cell(atlas,  4, 2)   # diamond_shovel — shovel shape
    i_sword  = crop_cell(atlas,  6, 2)   # iron_sword    — used as katana base (slender blade)

    # ──────────────────────────────────────────────────────────────
    #  RUBY TIER  (H=0.00 = red,  S=0.90 vivid)
    # ──────────────────────────────────────────────────────────────
    print("\n[ruby tier]")
    RUBY_H, RUBY_S = 0.00, 0.90
    save(tint(d_pick,   RUBY_H, RUBY_S), "ruby_pick")
    save(tint(d_axe,    RUBY_H, RUBY_S), "ruby_axe")
    save(tint(d_sword,  RUBY_H, RUBY_S), "ruby_sword")
    save(tint(d_shovel, RUBY_H, RUBY_S), "ruby_shovel")

    # ──────────────────────────────────────────────────────────────
    #  EMERALD TIER  (H=0.36 = green, S=0.85)
    # ──────────────────────────────────────────────────────────────
    print("\n[emerald tier]")
    EM_H, EM_S = 0.36, 0.85
    save(tint(d_pick,   EM_H, EM_S), "emerald_pick")
    save(tint(d_axe,    EM_H, EM_S), "emerald_axe")
    save(tint(d_sword,  EM_H, EM_S), "emerald_sword")
    save(tint(d_shovel, EM_H, EM_S), "emerald_shovel")

    # ──────────────────────────────────────────────────────────────
    #  GOLD SWORD  (H=0.13 = yellow-gold, S=0.95)
    #  Note: gold_pick and gold_axe already have their own unique cells
    #  in master_weapon.png at (8,2) and (11,2).
    # ──────────────────────────────────────────────────────────────
    print("\n[gold sword]")
    GOLD_H, GOLD_S = 0.13, 0.95
    save(tint(d_sword, GOLD_H, GOLD_S), "gold_sword")

    # ──────────────────────────────────────────────────────────────
    #  KATANA  (H=0.60 = cold steel blue-white, low saturation)
    #  Uses iron_sword as base — it has a slender blade silhouette.
    #  min_l=0.25 keeps edge details; max_l=0.97 makes the blade gleam.
    # ──────────────────────────────────────────────────────────────
    print("\n[katana]")
    KAT_H, KAT_S = 0.60, 0.20
    save(tint(i_sword, KAT_H, KAT_S, min_l=0.25, max_l=0.97), "katana")

    # ──────────────────────────────────────────────────────────────
    #  ADD NEW TIERS HERE
    #
    #  Template (copy, paste, and edit):
    #
    #  print("\n[mytier]")
    #  MY_H, MY_S = 0.75, 0.90   # purple, vivid
    #  save(tint(d_sword,  MY_H, MY_S), "mytier_sword")
    #  save(tint(d_pick,   MY_H, MY_S), "mytier_pick")
    #  save(tint(d_axe,    MY_H, MY_S), "mytier_axe")
    #  save(tint(d_shovel, MY_H, MY_S), "mytier_shovel")
    #
    #  Then in ItemDatabase.gd, add entries for mytier_sword etc.
    #  TileTextureGenerator will find the PNGs automatically — no atlas_coords needed.
    # ──────────────────────────────────────────────────────────────

    print("\nDone. Reload the Godot project to reimport the new icons.")
    print("(FileSystem dock > right-click assets/items > Reimport, or just restart.)")


if __name__ == "__main__":
    main()
