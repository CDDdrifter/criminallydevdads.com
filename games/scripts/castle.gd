extends Node2D

# Builds and tracks one castle (player or enemy side).
# All blocks are children of this node.

const CELL := 64.0
const GROUND_Y := 964.0

var side: String = "player"  # "player" or "enemy"
var config: Dictionary = {}
var blocks: Array = []
var total_hp: float = 0.0
var current_hp: float = 0.0
var anchor_x: float = 0.0   # left edge of castle footprint

signal castle_damaged(side: String, current: float, max_hp: float)
signal castle_destroyed(side: String)

func build(cfg: Dictionary, s: String, ax: float) -> void:
	config = cfg
	side = s
	anchor_x = ax
	_spawn_blocks()
	_recalc_hp()

func _spawn_blocks() -> void:
	var layout: String = config.get("layout", "wall")
	var w: int = config.get("w", 4)
	var h: int = config.get("h", 4)
	var mats: Array = config.get("mats", ["wood"])
	var hp_mult: float = config.get("hp_mult", 1.0)

	# Apply global upgrades for player castle
	if side == "player":
		hp_mult *= (1.0 + GameState.castle_hp_bonus)

	var grid := _generate_grid(layout, w, h)

	for row in range(grid.size()):
		for col in range(grid[row].size()):
			if not grid[row][col]:
				continue
			var mat := _pick_mat(mats, row, h)
			_spawn_block(col, row, h, mat, hp_mult)

func _generate_grid(layout: String, w: int, h: int) -> Array:
	var grid: Array = []
	for row in h:
		grid.append([])
		for col in w:
			grid[row].append(false)

	match layout:
		"wall":
			for row in h:
				for col in w:
					grid[row][col] = true
		"tower":
			for row in h:
				for col in w:
					# Solid columns at edges, hollow inside if wide enough
					if w <= 2 or col == 0 or col == w - 1 or row == 0:
						grid[row][col] = true
		"fortress":
			for row in h:
				for col in w:
					# Solid perimeter + floor
					if col == 0 or col == w - 1 or row == 0:
						grid[row][col] = true
					elif row == h - 1:
						grid[row][col] = randi() % 2 == 0  # battlements
		"pyramid":
			for row in h:
				var margin := row * (w / (2 * h + 1.0))
				var left := int(margin)
				var right := w - 1 - int(margin)
				for col in w:
					if col >= left and col <= right:
						grid[row][col] = true
		"bunker":
			for row in h:
				for col in w:
					# Heavy solid base, thinner top
					if row < h / 2:
						grid[row][col] = true
					else:
						if col > 0 and col < w - 1:
							grid[row][col] = true
		"mixed":
			for row in h:
				for col in w:
					var rng := col * 13 + row * 7
					grid[row][col] = (rng % 3) != 0
			# Ensure at least one block per column bottom
			for col in w:
				grid[0][col] = true

	return grid

func _pick_mat(mats: Array, row: int, total_h: int) -> String:
	if mats.size() == 1:
		return mats[0]
	# Bottom rows use stronger materials
	var ratio := float(row) / float(total_h)
	if ratio < 0.35:
		return mats[min(1, mats.size() - 1)]
	return mats[0]

func _spawn_block(col: int, row: int, total_h: int, mat: String, hp_mult: float) -> void:
	var block := preload("res://scripts/block.gd").new()
	var col_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(CELL, CELL)
	col_shape.shape = rect
	block.add_child(col_shape)

	# Position: row 0 = ground level, ascending rows go up
	var world_x := anchor_x + col * CELL + CELL * 0.5
	var world_y := GROUND_Y - row * CELL - CELL * 0.5

	block.position = Vector2(world_x, world_y)
	block.setup(mat)

	# Apply HP multiplier
	block.max_hp *= hp_mult
	block.hp = block.max_hp

	block.block_destroyed.connect(_on_block_destroyed)
	block.chain_exploded.connect(_on_chain_exploded)
	block.ice_shattered.connect(_on_ice_shattered)

	add_child(block)
	blocks.append(block)

func _recalc_hp() -> void:
	total_hp = 0.0
	for b in blocks:
		if is_instance_valid(b):
			total_hp += b.max_hp
	current_hp = total_hp

func update_hp() -> void:
	var new_hp := 0.0
	for b in blocks:
		if is_instance_valid(b):
			new_hp += b.hp
	current_hp = new_hp
	castle_damaged.emit(side, current_hp, total_hp)
	if current_hp <= total_hp * 0.15:
		castle_destroyed.emit(side)

func _on_block_destroyed(block: Node) -> void:
	blocks.erase(block)
	update_hp()

func _on_chain_exploded(pos: Vector2, radius: float, force: float, damage: float) -> void:
	# Bubble up to game.gd
	get_parent().call("_do_explosion", pos, radius, force, damage, "")

func _on_ice_shattered(pos: Vector2) -> void:
	for b in blocks:
		if is_instance_valid(b) and b.global_position.distance_to(pos) < 110:
			b.freeze_block(2.5)

func get_center() -> Vector2:
	if blocks.is_empty():
		return Vector2(anchor_x + CELL * 2, GROUND_Y - CELL * 2)
	var sum := Vector2.ZERO
	var count := 0
	for b in blocks:
		if is_instance_valid(b):
			sum += b.global_position
			count += 1
	return sum / max(count, 1)

func get_hp_ratio() -> float:
	return current_hp / max(total_hp, 1.0)

func is_destroyed() -> bool:
	return blocks.is_empty() or current_hp <= total_hp * 0.15
