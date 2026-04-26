## PlayerSkin.gd
## A skin is a folder of sprite sheets that exactly match the base character
## animation sheets (same frame sizes, same count per row).
## Drag a PlayerSkin .tres resource onto Player → Skin in the Inspector,
## or set GameData.selected_skin before loading the world.
@tool
extends Resource
class_name PlayerSkin

## Display name shown in the skin picker.
@export var skin_name: String = "Default"

## Path to the folder containing the replacement sprite sheets.
## Must contain the same filenames as res://assets/sprites/player/:
##   idle.png, walk.png, run.png, jump.png, land.png, crouch_idle.png,
##   crouch_walk.png, hurt.png, death.png, mine.png, attack.png, wall_slide.png
## Leave empty to use the default base character.
@export_dir var skin_folder: String = ""

## Preview image shown in the skin picker (ideally a cropped idle frame).
@export var preview_texture: Texture2D = null
