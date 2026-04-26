## AudioManager.gd — Autoload
## Drag AudioStream files onto the @export properties in the Inspector to replace
## the built-in procedural synthesis.  Any slot left empty falls back to generated sound.
## Background music tracks loop automatically in sequence or shuffled.
extends Node

# ===========================================================================
# Inspector-assignable Sound Effects
# Drag your .wav / .mp3 / .ogg files from the FileSystem dock onto these.
# ===========================================================================
@export_group("SFX — Mining")
@export var sfx_mine_hit:      AudioStream = null
@export var sfx_mine_complete: AudioStream = null

@export_group("SFX — Building")
@export var sfx_place:         AudioStream = null

@export_group("SFX — Player")
@export var sfx_jump:          AudioStream = null
@export var sfx_footstep:      AudioStream = null
@export var sfx_hurt:          AudioStream = null
@export var sfx_death:         AudioStream = null
@export var sfx_eat:           AudioStream = null
@export var sfx_equip:         AudioStream = null
@export var sfx_splash:        AudioStream = null  ## entering / exiting water

@export_group("SFX — Items")
@export var sfx_pickup:        AudioStream = null
@export var sfx_craft:         AudioStream = null

@export_group("SFX — UI")
@export var sfx_inventory_open:  AudioStream = null
@export var sfx_inventory_close: AudioStream = null
@export var sfx_chest_open:      AudioStream = null
@export var sfx_ui_click:        AudioStream = null

@export_group("SFX — Enemies")
@export var sfx_enemy_hurt:    AudioStream = null
@export var sfx_enemy_death:   AudioStream = null

# ===========================================================================
# Volume controls
# ===========================================================================
@export_group("Volume")
@export_range(-60, 0) var sfx_volume_db:       float = -10.0
@export_range(-60, 0) var footstep_volume_db:  float = -20.0
@export_range(-60, 0) var music_volume_db:     float = -15.0

# ===========================================================================
# Background Music
# Add AudioStream tracks to this array — they play in order (or shuffled),
# each looping if marked loop, then advancing to the next track.
# ===========================================================================
@export_group("Background Music")
@export var music_enabled: bool = true
@export var music_tracks: Array[AudioStream] = []
@export var music_shuffle: bool = false

# ===========================================================================
# Internal
# ===========================================================================
const RATE      := 44100.0
const POOL_SIZE := 8

var _pool:  Array = []
var _idx:   int   = 0

var _music_player: AudioStreamPlayer = null
var _music_order:  Array             = []
var _music_pos:    int               = 0

# Tracks whether player was in water last frame (for splash detection).
var _was_in_water: bool = false


func _ready() -> void:
	# SFX pool — rotating set of players for overlapping sounds.
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

	# Dedicated music player.
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = music_volume_db
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	_rebuild_music_order()
	_play_next_track()


# ---------------------------------------------------------------------------
# Music helpers
# ---------------------------------------------------------------------------

func _rebuild_music_order() -> void:
	_music_order.clear()
	for i in music_tracks.size():
		_music_order.append(i)
	if music_shuffle:
		_music_order.shuffle()
	_music_pos = 0


func _play_next_track() -> void:
	if not music_enabled or music_tracks.is_empty():
		return
	if _music_pos >= _music_order.size():
		_rebuild_music_order()   # restart / re-shuffle when list exhausted
	var idx: int = _music_order[_music_pos]
	_music_pos += 1
	var track: AudioStream = music_tracks[idx]
	if track == null:
		_on_music_finished()
		return
	_music_player.stream = track
	_music_player.volume_db = music_volume_db
	_music_player.play()


func _on_music_finished() -> void:
	_play_next_track()


## Call from game code to pause/resume music (e.g. pause menu).
func set_music_paused(paused: bool) -> void:
	if _music_player:
		_music_player.stream_paused = paused


## Immediately cross-fade to a specific track index.
func play_music_track(index: int) -> void:
	if index < 0 or index >= music_tracks.size():
		return
	_music_player.stop()
	_music_player.stream = music_tracks[index]
	_music_player.volume_db = music_volume_db
	_music_player.play()


# ---------------------------------------------------------------------------
# SFX playback helpers
# ---------------------------------------------------------------------------

## Play a file-based stream, or run the procedural_fallback callable if nil.
func _play(stream: AudioStream, vol_db: float, procedural_fallback: Callable) -> void:
	if stream != null:
		var p: AudioStreamPlayer = _pool[_idx]
		_idx = (_idx + 1) % POOL_SIZE
		p.stream    = stream
		p.volume_db = vol_db
		p.play()
	else:
		procedural_fallback.call()


## Push procedurally generated frames to the pool.
func _play_frames(frames: PackedVector2Array, vol_db: float = -10.0) -> void:
	if frames.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_idx]
	_idx = (_idx + 1) % POOL_SIZE

	var gen := AudioStreamGenerator.new()
	gen.mix_rate     = RATE
	gen.buffer_length = float(frames.size()) / RATE + 0.05
	p.stream    = gen
	p.volume_db = vol_db
	p.play()

	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb != null:
		pb.push_buffer(frames)


# ---------------------------------------------------------------------------
# Waveform builders (used only when no audio file is assigned)
# ---------------------------------------------------------------------------

static func _sine(freq: float, dur: float, amp: float = 1.0) -> PackedVector2Array:
	var n := int(RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		var t   := float(i) / RATE
		var env := 1.0 - float(i) / n
		var s   := sin(TAU * freq * t) * env * amp
		buf[i]   = Vector2(s, s)
	return buf


static func _noise(dur: float, amp: float = 1.0) -> PackedVector2Array:
	var n := int(RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		var env := 1.0 - float(i) / n
		var s   := randf_range(-1.0, 1.0) * env * amp
		buf[i]   = Vector2(s, s)
	return buf


static func _sweep(f0: float, f1: float, dur: float, amp: float = 1.0) -> PackedVector2Array:
	var n := int(RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		var t    := float(i) / RATE
		var frac := float(i) / n
		var freq := lerpf(f0, f1, frac)
		var env  := 1.0 - frac
		var s    := sin(TAU * freq * t) * env * amp
		buf[i]    = Vector2(s, s)
	return buf


static func _mix(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var n := mini(a.size(), b.size())
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] + b[i]) * 0.5
	return out


# ===========================================================================
# Public Sound API — call from anywhere in the game
# ===========================================================================

func play_mine_hit() -> void:
	_play(sfx_mine_hit, sfx_volume_db, func():
		var dur := randf_range(0.04, 0.09)
		_play_frames(_noise(dur, randf_range(0.55, 0.85)), randf_range(-16.0, -11.0)))


func play_mine_complete() -> void:
	_play(sfx_mine_complete, sfx_volume_db, func():
		var base_f := randf_range(70.0, 110.0)
		var dur    := randf_range(0.10, 0.14)
		_play_frames(_mix(_noise(dur), _sine(base_f, dur, 0.5)), randf_range(-10.0, -6.0)))


func play_place() -> void:
	_play(sfx_place, sfx_volume_db, func():
		var freq := randf_range(280.0, 420.0)
		var dur  := randf_range(0.05, 0.09)
		_play_frames(_sine(freq, dur, 0.85), randf_range(-14.0, -10.0)))


func play_jump() -> void:
	_play(sfx_jump, sfx_volume_db, func():
		var f0  := randf_range(160.0, 240.0)
		var f1  := randf_range(500.0, 680.0)
		var dur := randf_range(0.15, 0.21)
		_play_frames(_sweep(f0, f1, dur, 0.75), randf_range(-12.0, -8.0)))


func play_footstep() -> void:
	_play(sfx_footstep, footstep_volume_db, func():
		var freq := randf_range(50.0, 105.0)
		var dur  := randf_range(0.04, 0.07)
		_play_frames(_mix(_noise(dur, randf_range(0.28, 0.42)), _sine(freq, dur, 0.25)), footstep_volume_db))


func play_pickup() -> void:
	_play(sfx_pickup, sfx_volume_db, func():
		var f0  := randf_range(440.0, 560.0)
		var f1  := randf_range(820.0, 1000.0)
		var dur := randf_range(0.08, 0.13)
		_play_frames(_sweep(f0, f1, dur, 0.85), randf_range(-10.0, -6.0)))


func play_hurt() -> void:
	_play(sfx_hurt, sfx_volume_db, func():
		var base_f := randf_range(130.0, 210.0)
		var dur    := randf_range(0.14, 0.22)
		_play_frames(_mix(_noise(dur, randf_range(0.7, 1.0)), _sine(base_f, dur, 0.4)),
				randf_range(-8.0, -4.0)))


func play_death() -> void:
	_play(sfx_death, sfx_volume_db, func():
		var dur := randf_range(0.45, 0.65)
		_play_frames(_noise(dur, randf_range(0.85, 1.0)), randf_range(-5.0, -3.0)))


func play_enemy_hurt() -> void:
	_play(sfx_enemy_hurt, sfx_volume_db, func():
		var dur  := randf_range(0.06, 0.11)
		var freq := randf_range(100.0, 200.0)
		_play_frames(_mix(_noise(dur, 0.65), _sine(freq, dur, 0.3)), randf_range(-13.0, -8.0)))


func play_enemy_death() -> void:
	_play(sfx_enemy_death, sfx_volume_db, func():
		var dur := randf_range(0.18, 0.28)
		_play_frames(_noise(dur, randf_range(0.7, 0.9)), randf_range(-10.0, -6.0)))


func play_craft() -> void:
	_play(sfx_craft, sfx_volume_db, func():
		var freq := randf_range(580.0, 740.0)
		var dur  := randf_range(0.14, 0.22)
		_play_frames(_sine(freq, dur, 0.9), randf_range(-10.0, -6.0)))


func play_eat() -> void:
	_play(sfx_eat, sfx_volume_db, func():
		# Crunchy munch sound
		for _i in 3:
			var dur := randf_range(0.03, 0.06)
			_play_frames(_noise(dur, randf_range(0.4, 0.7)), randf_range(-14.0, -10.0)))


func play_equip() -> void:
	_play(sfx_equip, sfx_volume_db, func():
		var freq := randf_range(320.0, 480.0)
		var dur  := randf_range(0.06, 0.10)
		_play_frames(_sine(freq, dur, 0.7), randf_range(-15.0, -11.0)))


func play_splash() -> void:
	_play(sfx_splash, sfx_volume_db, func():
		var dur := randf_range(0.12, 0.20)
		_play_frames(_mix(_noise(dur, 0.9), _sweep(800.0, 200.0, dur, 0.4)),
				randf_range(-12.0, -8.0)))


func play_inventory_open() -> void:
	_play(sfx_inventory_open, sfx_volume_db, func():
		_play_frames(_sweep(300.0, 500.0, 0.08, 0.6), -16.0))


func play_inventory_close() -> void:
	_play(sfx_inventory_close, sfx_volume_db, func():
		_play_frames(_sweep(500.0, 300.0, 0.08, 0.6), -16.0))


func play_chest_open() -> void:
	_play(sfx_chest_open, sfx_volume_db, func():
		var dur := randf_range(0.18, 0.26)
		_play_frames(_mix(_noise(dur, 0.5), _sweep(180.0, 320.0, dur, 0.4)),
				randf_range(-12.0, -8.0)))


func play_ui_click() -> void:
	_play(sfx_ui_click, sfx_volume_db, func():
		_play_frames(_sine(randf_range(600.0, 900.0), 0.04, 0.5), -18.0))
