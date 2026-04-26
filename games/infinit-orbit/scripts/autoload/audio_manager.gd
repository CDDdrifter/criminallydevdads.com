# audio_manager.gd — Audio singleton (AutoLoad)
# Generates all sound effects procedurally via AudioStreamGenerator.
# No external audio files required — pure synthesis.
extends Node

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const MUSIC_BUS := "Music"
const SFX_BUS   := "Master"

# ─── NODES ────────────────────────────────────────────────────────────────────
var _music_player: AudioStreamPlayer
var _sfx_pool: Array = []
const SFX_POOL_SIZE := 8

# Current music track index
var _current_music_idx: int = -1
var _music_fade_tween: Tween

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -8.0
	add_child(_music_player)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = 0.0
		add_child(p)
		_sfx_pool.append(p)

	# Apply saved settings
	_apply_settings()

func _apply_settings() -> void:
	var sfx_on  := SaveManager.get_setting("sfx")
	var music_on := SaveManager.get_setting("music")
	# Volume: 0 if disabled, normal if enabled
	for p in _sfx_pool:
		p.volume_db = 0.0 if sfx_on else -80.0
	_music_player.volume_db = -8.0 if music_on else -80.0

# ─── SFX ──────────────────────────────────────────────────────────────────────
func play_sfx(sfx_name: String) -> void:
	if not SaveManager.get_setting("sfx"):
		return
	var stream := _generate_sfx(sfx_name)
	if stream == null:
		return
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = 1.0
	player.play()

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# All busy: reuse first
	return _sfx_pool[0]

func _generate_sfx(name: String) -> AudioStream:
	match name:
		"tap":
			return _synth_tone(440.0, 0.08, 0.0, 0.06)
		"ring_pass":
			return _synth_tone(660.0, 0.12, 0.0, 0.10)
		"coin":
			return _synth_tone(880.0, 0.10, 0.02, 0.06)
		"shield_hit":
			return _synth_noise(0.15)
		"shield_break":
			return _synth_tone(220.0, 0.20, 0.0, 0.18)
		"level_up":
			return _synth_chord([523.0, 659.0, 784.0], 0.25)
		"boss_ring":
			return _synth_tone(110.0, 0.30, 0.0, 0.25)
		"game_over":
			return _synth_sweep(440.0, 110.0, 0.4)
		"shop_buy":
			return _synth_tone(523.0, 0.15, 0.02, 0.12)
		"reward":
			return _synth_chord([523.0, 659.0, 784.0, 1047.0], 0.3)
		"crate_open":
			return _synth_sweep(220.0, 880.0, 0.35)
		"ui_click":
			return _synth_tone(330.0, 0.05, 0.0, 0.04)
	return null

# ─── SYNTHESIS HELPERS ────────────────────────────────────────────────────────
func _synth_tone(freq: float, duration: float, attack: float, decay: float) -> AudioStream:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var data := PackedFloat32Array()
	data.resize(sample_count)
	for i in sample_count:
		var t := float(i) / sample_rate
		var env := 1.0
		if t < attack:
			env = t / attack
		elif t > attack:
			env = 1.0 - ((t - attack) / decay)
		env = clampf(env, 0.0, 1.0)
		data[i] = sin(TAU * freq * t) * env * 0.5
	return _pack_stream(data, sample_rate)

func _synth_noise(duration: float) -> AudioStream:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var data := PackedFloat32Array()
	data.resize(sample_count)
	for i in sample_count:
		var env := 1.0 - float(i) / sample_count
		data[i] = (rng.randf() * 2.0 - 1.0) * env * 0.4
	return _pack_stream(data, sample_rate)

func _synth_chord(freqs: Array, duration: float) -> AudioStream:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var data := PackedFloat32Array()
	data.resize(sample_count)
	for i in sample_count:
		var t := float(i) / sample_rate
		var env := 1.0 - (t / duration)
		var val := 0.0
		for f in freqs:
			val += sin(TAU * f * t)
		data[i] = (val / freqs.size()) * env * 0.4
	return _pack_stream(data, sample_rate)

func _synth_sweep(freq_start: float, freq_end: float, duration: float) -> AudioStream:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var data := PackedFloat32Array()
	data.resize(sample_count)
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / sample_count
		var freq := lerpf(freq_start, freq_end, t)
		var env := 1.0 - t
		phase += TAU * freq / sample_rate
		data[i] = sin(phase) * env * 0.5
	return _pack_stream(data, sample_rate)

func _pack_stream(data: PackedFloat32Array, sample_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	var byte_data := PackedByteArray()
	byte_data.resize(data.size() * 2)
	for i in data.size():
		var sample := int(clampf(data[i], -1.0, 1.0) * 32767.0)
		byte_data[i * 2]     = sample & 0xFF
		byte_data[i * 2 + 1] = (sample >> 8) & 0xFF
	stream.data = byte_data
	return stream

# ─── MUSIC ────────────────────────────────────────────────────────────────────
func play_music_track(track_id: int) -> void:
	if not SaveManager.get_setting("music"):
		return
	if track_id == _current_music_idx:
		return
	_current_music_idx = track_id
	var stream := _generate_music(track_id)
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_current_music_idx = -1

func set_music_enabled(enabled: bool) -> void:
	_music_player.volume_db = -8.0 if enabled else -80.0
	if not enabled:
		_music_player.stop()

func set_sfx_enabled(enabled: bool) -> void:
	for p in _sfx_pool:
		p.volume_db = 0.0 if enabled else -80.0

func _generate_music(track_id: int) -> AudioStream:
	# Generates a simple looping ambient drone
	var sample_rate := 22050
	var duration := 4.0  # 4 second loop
	var sample_count := int(sample_rate * duration)
	var data := PackedFloat32Array()
	data.resize(sample_count)
	var base_freqs := [
		[55.0, 82.5, 110.0],   # Menu — low A bass
		[73.4, 110.0, 146.8],  # Gameplay — D ambient
		[82.5, 110.0, 165.0],  # Boss — tense E
	]
	var freqs: Array = base_freqs[track_id % 3]
	var rng := RandomNumberGenerator.new()
	rng.seed = track_id * 12345
	for i in sample_count:
		var t := float(i) / sample_rate
		var val := 0.0
		for j in freqs.size():
			var mod := 1.0 + 0.003 * sin(TAU * 0.4 * t + j)
			val += sin(TAU * freqs[j] * mod * t) * (0.6 - j * 0.1)
		# Soft noise layer
		val += (rng.randf() * 2.0 - 1.0) * 0.03
		data[i] = clampf(val * 0.3, -1.0, 1.0)
	var stream := _pack_stream(data, sample_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream
