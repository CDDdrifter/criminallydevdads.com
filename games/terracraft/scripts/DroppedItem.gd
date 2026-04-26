class_name DroppedItem
extends Area2D

## Represents an item dropped in the world.
## Handles physics arc on spawn, pickup by player, and despawn.

@export var item_id: String = ""
@export var count: int = 1

const PICKUP_DELAY := 0.6       # Seconds before the item can be picked up
const DESPAWN_TIME := 300.0     # Seconds until the item vanishes
const BOB_SPEED := 2.5
const BOB_AMOUNT := 2.5

var _can_pickup := false
var _base_y := 0.0
var _bob_time := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var pickup_timer: Timer = $PickupTimer
@onready var despawn_timer: Timer = $DespawnTimer


func _ready() -> void:
	_base_y = position.y
	_apply_visuals()
	_start_arc()

	pickup_timer.wait_time = PICKUP_DELAY
	pickup_timer.one_shot = true
	pickup_timer.timeout.connect(_on_pickup_ready)
	pickup_timer.start()

	despawn_timer.wait_time = DESPAWN_TIME
	despawn_timer.one_shot = true
	despawn_timer.timeout.connect(_on_despawn)
	despawn_timer.start()

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _can_pickup:
		return
	# Gentle bob after landing
	_bob_time += delta * BOB_SPEED
	position.y = _base_y + sin(_bob_time) * BOB_AMOUNT


func setup(id: String, amount: int = 1) -> void:
	item_id = id
	count = amount


func _apply_visuals() -> void:
	if not is_instance_valid(sprite):
		return

	var db = get_node_or_null("/root/ItemDB")
	if db == null:
		db = get_node_or_null("/root/ItemDatabase")
	if db != null and db.has_method("get_item"):
		var item = db.get_item(item_id)
		if item and not item.is_empty():
			sprite.modulate = item.get("icon_color", item.get("color", Color.WHITE))
	else:
		# Fallback: use a simple color map until ItemDatabase is available
		var fallback_colors := {
			"dirt": Color(0.545, 0.353, 0.169),
			"grass": Color(0.302, 0.686, 0.098),
			"stone": Color(0.502, 0.502, 0.502),
			"wood": Color(0.427, 0.318, 0.173),
			"coal": Color(0.15, 0.15, 0.15),
			"iron_ore": Color(0.816, 0.659, 0.518),
			"gold_ore": Color(1.0, 0.843, 0.0),
			"diamond": Color(0.392, 0.941, 0.941),
		}
		sprite.modulate = fallback_colors.get(item_id, Color.WHITE)

	if count > 1 and is_instance_valid(label):
		label.text = str(count)
		label.visible = true
	elif is_instance_valid(label):
		label.visible = false


func _start_arc() -> void:
	# Tween: pop upward then fall back down via gravity simulation
	var arc_height := randf_range(18.0, 32.0)
	var arc_x := randf_range(-20.0, 20.0)
	var start_pos := position
	var peak_pos := position + Vector2(arc_x * 0.5, -arc_height)
	var land_pos := position + Vector2(arc_x, 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	# Rise
	tween.tween_property(self, "position", peak_pos, 0.18).set_ease(Tween.EASE_OUT)
	# Fall
	tween.tween_property(self, "position", land_pos, 0.22).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		_base_y = position.y
	)


func _on_pickup_ready() -> void:
	_can_pickup = true


func _on_body_entered(body: Node) -> void:
	if not _can_pickup:
		return
	if body.has_method("add_item"):
		var success: bool = body.add_item(item_id, count)
		if success:
			_collect()


func _collect() -> void:
	AudioManager.play_pickup()
	# Visual pop-up tween before removal
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(queue_free)


func _on_despawn() -> void:
	# Fade out and remove
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.finished.connect(queue_free)
