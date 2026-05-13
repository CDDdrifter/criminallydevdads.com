extends Node

signal match_started
signal match_ended(winner_name: String)
signal player_killed(killer: String, victim: String)
signal players_remaining(count: int)

enum MatchState { MENU, PLAYING, ENDED }

var state: MatchState = MatchState.MENU
var alive_players: Array = []
var local_player: Node   = null

# Plane position — written by Match, read by Player._do_onplane
var plane_x: float           = -99999.0
var plane_phase_active: bool = false

var controller_connected: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_changed)
	# Web: Gamepad API often reports nothing until the player presses a button; treating
	# "no session yet" as disconnected avoids phantom joy_axis(0,…) reads breaking aim.
	if OS.has_feature("web"):
		controller_connected = false
	else:
		controller_connected = Input.get_connected_joypads().size() > 0

func _on_joy_changed(_device: int, _connected: bool) -> void:
	controller_connected = Input.get_connected_joypads().size() > 0

func start_match() -> void:
	state = MatchState.PLAYING
	match_started.emit()

func register_player(p: Node) -> void:
	if p not in alive_players:
		alive_players.append(p)

func on_player_died(p: Node, killer_name: String) -> void:
	alive_players.erase(p)
	var victim_name: String = p.player_name if p.get("player_name") != null else "Player"
	player_killed.emit(killer_name, victim_name)
	players_remaining.emit(alive_players.size())
	if alive_players.size() <= 1:
		var winner := ""
		if alive_players.size() == 1:
			var w: Node = alive_players[0]
			winner = w.player_name if w.get("player_name") != null else "Player"
		state = MatchState.ENDED
		match_ended.emit(winner)

func get_alive_count() -> int:
	return alive_players.size()

func go_to_menu() -> void:
	state              = MatchState.MENU
	alive_players.clear()
	local_player       = null
	plane_x            = -99999.0
	plane_phase_active = false
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func go_to_match() -> void:
	state              = MatchState.MENU
	alive_players.clear()
	local_player       = null
	plane_x            = Constants.PLANE_START_X
	plane_phase_active = true
	get_tree().change_scene_to_file("res://scenes/game/Match.tscn")
