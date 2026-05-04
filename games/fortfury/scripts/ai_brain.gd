extends Node

# AI targeting engine. Called by game.gd each AI turn.
# Returns a launch velocity to fire at the player's castle.

const POWER := 14.5
const GRAVITY := 980.0

var difficulty: float = 0.5  # 0=easy, 1=expert
var rng := RandomNumberGenerator.new()

func setup(diff: float) -> void:
	difficulty = diff
	rng.randomize()

# Returns velocity vector to fire from ai_pos toward target_pos.
# Returns Vector2.ZERO if no valid shot found.
func calculate_shot(ai_pos: Vector2, target_pos: Vector2) -> Vector2:
	var best_vel := Vector2.ZERO
	var best_score := INF

	# Try different flight times (1.0–4.5 seconds in steps)
	var steps := 40
	for i in steps:
		var t := 1.0 + float(i) / float(steps) * 3.5
		var vx := (target_pos.x - ai_pos.x) / t
		var vy := (target_pos.y - ai_pos.y - 0.5 * GRAVITY * t * t) / t

		var vel := Vector2(vx, vy)
		var speed := vel.length()
		var max_speed := POWER * 155.0  # POWER * MAX_PULL

		if speed > max_speed or speed < 80:
			continue

		# Penalize extreme angles
		var angle: float = abs(rad_to_deg(vel.angle()))
		if angle > 150 or angle < 15:
			continue

		var score: float = abs(speed - max_speed * 0.6) + abs(t - 2.2) * 20
		if score < best_score:
			best_score = score
			best_vel = vel

	if best_vel == Vector2.ZERO:
		return Vector2.ZERO

	# Add error based on difficulty (inverted: high difficulty = low error)
	var error_scale := (1.0 - difficulty) * 180.0
	var error := Vector2(
		rng.randf_range(-error_scale, error_scale),
		rng.randf_range(-error_scale * 0.6, error_scale * 0.6)
	)
	return best_vel + error

# Pick which bomb the AI uses this turn
func pick_bomb(available: Array, unlocked: Array, turn: int) -> String:
	var choices: Array = []
	for b in available:
		if b in unlocked:
			choices.append(b)
	if choices.is_empty():
		return "standard"

	# Low-difficulty AI uses standard more
	if randf() > difficulty and "standard" in choices:
		return "standard"

	# Weight toward impactful bombs based on difficulty
	var weighted: Array = []
	for b in choices:
		var w := 1
		match b:
			"nuke", "shockwave", "cluster": 
				w = 3 if difficulty > 0.7 else 1
			"fire", "lightning", "laser": 
				w = 2 if difficulty > 0.5 else 1
			"standard", "heavy", "splitter": 
				w = 2
		for _i in w:
			weighted.append(b)
	return weighted[rng.randi_range(0, weighted.size() - 1)]

# Draw the AI "catapult" — mirrored slingshot on the right side
func draw_catapult(canvas: CanvasItem, pos: Vector2) -> void:
	canvas.draw_set_transform(pos, 0, Vector2(-1, 1))  # mirror
	canvas.draw_line(Vector2.ZERO, Vector2(-28, -55), Color(0.40, 0.25, 0.10), 6)
	canvas.draw_line(Vector2.ZERO, Vector2(28, -55), Color(0.40, 0.25, 0.10), 6)
	canvas.draw_circle(Vector2.ZERO, 8, Color(0.35, 0.22, 0.08))
	canvas.draw_circle(Vector2(-28, -55), 5, Color(0.55, 0.35, 0.15))
	canvas.draw_circle(Vector2(28, -55), 5, Color(0.55, 0.35, 0.15))
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
