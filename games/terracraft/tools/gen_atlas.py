"""
gen_atlas.py — TerraCraft comprehensive sprite-atlas baker
===========================================================
Generates 5 PNG atlas files covering every item, block, weapon, tool,
material, armor piece, and food item in the game.

It parses ItemDatabase.gd to find IDs, types, and colors.
Output images are saved to assets/atlas/ for use by the game.
"""

import os
import re
import math
from PIL import Image, ImageDraw

# -- CONFIGURATION --
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS_DIR = os.path.join(BASE_DIR, "scripts")
OUT_DIR = os.path.join(BASE_DIR, "assets", "atlas")

CELL_SIZE = 16
COLS = 16  # 256 / 16

# Colors
TRANS = (0, 0, 0, 0)
HANDLE = (115, 77, 38, 255) # Color(0.45, 0.30, 0.15) approx
OUTLINE = (0, 0, 0, 180)

def darken(c):
    return tuple(max(0, int(x * 0.6)) for x in c[:3]) + (c[3],)

def lighten(c):
    return tuple(min(255, int(x * 1.3)) for x in c[:3]) + (c[3],)

def fill_rect(img, x, y, w, h, col):
    draw = ImageDraw.Draw(img)
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=col)

def draw_border(img, x, y, w, h, col=OUTLINE):
    draw = ImageDraw.Draw(img)
    draw.rectangle([x, y, x + w - 1, y + h - 1], outline=col)

def set_px(img, x, y, col):
    img.putpixel((x, y), col)

def draw_icon(img, item_id, item):
    icon_color = item.get("icon_color", (200, 200, 200, 255))
    col = icon_color
    dark = darken(col)
    light = lighten(col)
    
    h_col = (115, 77, 38, 255)
    h_dark = darken(h_col)
    
    shape = item.get("icon_shape", "")
    if not shape:
        if any(x in item_id for x in ["sword", "blade", "dagger", "katana"]): shape = "sword"
        elif any(x in item_id for x in ["pick", "pickaxe"]): shape = "pick"
        elif "axe" in item_id: shape = "axe"
        elif "shovel" in item_id: shape = "shovel"
        elif "hoe" in item_id: shape = "hoe"
        elif any(x in item_id for x in ["spear", "halberd"]): shape = "spear"
        elif any(x in item_id for x in ["hammer", "mace", "flail"]): shape = "hammer"

    if shape == "sword":
        fill_rect(img, 7, 1, 2, 10, col)
        fill_rect(img, 7, 1, 1, 10, light)
        fill_rect(img, 4, 10, 8, 2, dark)
        fill_rect(img, 5, 10, 6, 1, col)
        fill_rect(img, 7, 12, 2, 3, h_col)
        fill_rect(img, 6, 14, 4, 1, dark)
        draw_border(img, 7, 1, 2, 10)
        draw_border(img, 4, 10, 8, 2)

    elif shape == "pick":
        for i in range(8):
            set_px(img, 2+i, 14-i, h_col)
            set_px(img, 3+i, 14-i, h_dark)
        fill_rect(img, 2, 2, 12, 3, col)
        fill_rect(img, 2, 2, 3, 4, col)
        fill_rect(img, 11, 2, 3, 4, col)
        fill_rect(img, 3, 3, 10, 1, light)
        draw_border(img, 2, 2, 12, 3)

    elif shape == "axe":
        fill_rect(img, 7, 6, 2, 9, h_col)
        fill_rect(img, 8, 6, 1, 9, h_dark)
        fill_rect(img, 3, 2, 6, 6, col)
        fill_rect(img, 2, 3, 2, 4, dark)
        fill_rect(img, 4, 3, 4, 1, light)
        fill_rect(img, 6, 4, 4, 2, dark)
        draw_border(img, 3, 2, 6, 6)

    elif shape == "shovel":
        fill_rect(img, 7, 0, 2, 11, h_col)
        fill_rect(img, 8, 0, 1, 11, h_dark)
        fill_rect(img, 4, 11, 8, 4, col)
        fill_rect(img, 5, 10, 6, 2, col)
        fill_rect(img, 5, 11, 1, 3, light)
        draw_border(img, 4, 11, 8, 4)

    elif shape == "hoe":
        fill_rect(img, 7, 5, 2, 10, h_col)
        fill_rect(img, 3, 2, 8, 3, col)
        draw_border(img, 3, 2, 8, 3)

    elif shape == "spear":
        fill_rect(img, 7, 4, 2, 12, h_col)
        fill_rect(img, 7, 0, 2, 4, col)
        set_px(img, 7, 0, TRANS)
        set_px(img, 8, 0, light)
        draw_border(img, 7, 0, 2, 4)

    elif shape == "hammer":
        fill_rect(img, 7, 7, 2, 9, h_col)
        fill_rect(img, 3, 1, 10, 7, col)
        fill_rect(img, 4, 2, 8, 5, light)
        draw_border(img, 3, 1, 10, 7)

    elif item_id == "bow" or "bow" in item_id:
        for i in range(5):
            fill_rect(img, 2, 2+i*2, 2+i, 2, h_col)
            fill_rect(img, 2, 12-i*2, 2+i, 2, h_col)
        fill_rect(img, 13, 3, 1, 10, (230, 230, 230, 200))
        draw_border(img, 2, 2, 6, 12)

    elif item_id == "arrow":
        fill_rect(img, 7, 4, 1, 8, h_col)
        fill_rect(img, 6, 1, 3, 3, dark)
        fill_rect(img, 6, 13, 3, 2, (230, 230, 230, 255))
        draw_border(img, 6, 1, 3, 3)

    elif item_id == "stick":
        for i in range(12):
            set_px(img, 2+i, 13-i, h_col)
            set_px(img, 3+i, 13-i, h_dark)

    elif item_id == "apple":
        fill_rect(img, 4, 3, 8, 10, col)
        fill_rect(img, 3, 5, 10, 6, col)
        fill_rect(img, 5, 2, 6, 2, col)
        fill_rect(img, 8, 1, 1, 2, h_dark)
        set_px(img, 5, 5, light)

    elif item_id == "bread":
        fill_rect(img, 2, 7, 12, 6, col)
        fill_rect(img, 3, 5, 10, 3, light)
        fill_rect(img, 2, 7, 12, 1, dark)

    elif item_id.endswith("_ingot"):
        fill_rect(img, 3, 4, 10, 8, col)
        fill_rect(img, 4, 3, 8, 2, light)
        fill_rect(img, 3, 11, 10, 1, dark)
        draw_border(img, 3, 3, 10, 9)

    elif item_id in ["diamond", "emerald", "ruby", "quartz"]:
        fill_rect(img, 5, 4, 6, 8, col)
        fill_rect(img, 3, 6, 10, 4, col)
        fill_rect(img, 6, 5, 4, 2, light)
        draw_border(img, 3, 4, 10, 8)

    elif item_id == "bone":
        bc = (240, 235, 215, 255)
        fill_rect(img, 7, 2, 2, 12, bc)
        fill_rect(img, 5, 1, 6, 3, bc)
        fill_rect(img, 5, 12, 6, 3, bc)
        draw_border(img, 7, 2, 2, 12)

    elif item.get("type") == "armor":
        slot = item.get("slot", "")
        if slot == "head":
            fill_rect(img, 3, 4, 10, 9, col)
            fill_rect(img, 5, 3, 6, 2, light)
            draw_border(img, 3, 4, 10, 9)
        elif slot == "chest":
            fill_rect(img, 2, 2, 12, 12, col)
            fill_rect(img, 6, 2, 4, 12, dark)
            draw_border(img, 2, 2, 12, 12)
        elif slot == "legs":
            fill_rect(img, 2, 1, 12, 7, col)
            fill_rect(img, 2, 8, 5, 7, col)
            fill_rect(img, 9, 8, 5, 7, col)
            draw_border(img, 2, 1, 12, 14)
        elif slot == "feet":
            fill_rect(img, 2, 10, 5, 5, col)
            fill_rect(img, 9, 10, 5, 5, col)
            draw_border(img, 2, 10, 12, 5)

    else:
        fill_rect(img, 1, 1, 14, 14, col)
        draw_border(img, 1, 1, 14, 14)

def parse_item_db():
    db_path = os.path.join(SCRIPTS_DIR, "ItemDatabase.gd")
    with open(db_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    items = {}
    # Find item blocks "id": { ... }
    blocks = re.findall(r'"([a-z0-9_]+)":\s*\{([^\}]+)\}', content)
    for bid, body in blocks:
        item = {"id": bid}
        nm = re.search(r'"name":\s*"([^"]+)"', body)
        tp = re.search(r'"type":\s*"([^"]+)"', body)
        sl = re.search(r'"slot":\s*"([^"]+)"', body)
        sh = re.search(r'"icon_shape":\s*"([^"]+)"', body)
        
        # Color parsing
        cl = re.search(r'Color\(([^)]+)\)', body)
        if cl:
            parts = [float(x.strip()) for x in cl.group(1).split(",")]
            if len(parts) == 3: parts.append(1.0)
            item["icon_color"] = (int(parts[0]*255), int(parts[1]*255), int(parts[2]*255), int(parts[3]*255))
        
        if nm: item["name"] = nm.group(1)
        if tp: item["type"] = tp.group(1)
        if sl: item["slot"] = sl.group(1)
        if sh: item["icon_shape"] = sh.group(1)
        items[bid] = item
    return items

def main():
    if not os.path.exists(OUT_DIR): os.makedirs(OUT_DIR)
    items = parse_item_db()
    
    # Categorize
    cats = {"blocks": [], "tools": [], "weapons": [], "materials": [], "armor_food": []}
    for item in items.values():
        t = item.get("type", "")
        if t == "block": cats["blocks"].append(item)
        elif t == "tool": cats["tools"].append(item)
        elif t == "weapon": cats["weapons"].append(item)
        elif t == "material": cats["materials"].append(item)
        else: cats["armor_food"].append(item)

    for cat_name, entries in cats.items():
        if not entries: continue
        rows = math.ceil(len(entries) / COLS)
        atlas = Image.new("RGBA", (COLS * CELL_SIZE, rows * CELL_SIZE), (0,0,0,0))
        
        for i, item in enumerate(entries):
            x = (i % COLS) * CELL_SIZE
            y = (i // COLS) * CELL_SIZE
            cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0,0,0,0))
            draw_icon(cell, item["id"], item)
            atlas.paste(cell, (x, y))
            
        atlas.save(os.path.join(OUT_DIR, cat_name + ".png"))
        print(f"Saved {cat_name}.png")

if __name__ == "__main__":
    main()
