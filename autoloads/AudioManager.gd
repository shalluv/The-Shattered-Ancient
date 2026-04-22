extends Node

## Central audio manager – handles BGM cross-fade, SFX pool, and volume persistence.
## Registered as autoload "AudioManager".

const SAVE_PATH := "user://settings.cfg"
const CROSSFADE_DURATION := 1.0
const SFX_POOL_SIZE := 8
const DEFAULT_VOLUME := 0.8 # linear 0–1

# ── BGM track definitions (frequency in Hz for placeholder tones) ──
const BGM_TRACKS: Dictionary = {
	"main_menu": 220.0,
	"lobby": 262.0,
	"combat": 330.0,
	"boss": 440.0,
	"elite": 370.0,
	"village": 294.0,
	"shop": 277.0,
	"game_over": 196.0,
	"victory": 523.0,
}

# ── SFX definitions (frequency, duration, type) ──
const SFX_DEFS: Dictionary = {
	"ui_click": {"freq": 800.0, "duration": 0.06, "type": "sine"},
	"ui_hover": {"freq": 600.0, "duration": 0.03, "type": "sine"},
	"attack_hit": {"freq": 200.0, "duration": 0.08, "type": "noise"},
	"unit_death": {"freq": 150.0, "duration": 0.15, "type": "noise"},
	"enemy_death": {"freq": 120.0, "duration": 0.18, "type": "noise"},
	"room_clear": {"freq": 523.0, "duration": 0.3, "type": "sine"},
	"projectile_fire": {"freq": 900.0, "duration": 0.05, "type": "sine"},
	"projectile_hit": {"freq": 250.0, "duration": 0.06, "type": "noise"},
	"shop_buy": {"freq": 659.0, "duration": 0.2, "type": "sine"},
	"absorption": {"freq": 440.0, "duration": 0.25, "type": "sine"},
}

# Scene name → BGM track key mapping
const SCENE_BGM_MAP: Dictionary = {
	"MainMenu": "lobby",
	"Lobby": "lobby",
	"MetaUpgrades": "lobby",
	"ArmyDraft": "lobby",
	"RunMapScreen": "lobby",
	"PathChoice": "lobby",
	"Settings": "",
	"BoonSelection": "",
	"MiniBossReward": "",
	"GameOver": "",
	"RoomShop": "shop",
	"RoomHero": "elite",
}

var _bgm_a: AudioStreamPlayer = null
var _bgm_b: AudioStreamPlayer = null
var _active_bgm: AudioStreamPlayer = null
var _current_bgm_key: String = ""

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

var _sfx_cache: Dictionary = {}
var _bgm_cache: Dictionary = {}

var _volumes: Dictionary = {
	"Master": DEFAULT_VOLUME,
	"Music": DEFAULT_VOLUME,
	"SFX": DEFAULT_VOLUME,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bgm_a = AudioStreamPlayer.new()
	_bgm_a.bus = "Music"
	add_child(_bgm_a)

	_bgm_b = AudioStreamPlayer.new()
	_bgm_b.bus = "Music"
	add_child(_bgm_b)

	_active_bgm = _bgm_a

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	_load_volumes()
	_apply_all_volumes()


# ── Public API ─────────────────────────────────────────────

func play_bgm(track_key: String) -> void:
	if track_key == "" or track_key == _current_bgm_key:
		return
	if not BGM_TRACKS.has(track_key):
		return

	_current_bgm_key = track_key
	var stream := _get_bgm_stream(track_key)

	var old_bgm := _active_bgm
	var new_bgm := _bgm_b if _active_bgm == _bgm_a else _bgm_a
	_active_bgm = new_bgm

	new_bgm.stream = stream
	new_bgm.volume_db = -80.0
	new_bgm.play()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(new_bgm, "volume_db", 0.0, CROSSFADE_DURATION)
	if old_bgm.playing:
		tw.tween_property(old_bgm, "volume_db", -80.0, CROSSFADE_DURATION)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		if old_bgm != _active_bgm:
			old_bgm.stop()
	)


func stop_bgm() -> void:
	_current_bgm_key = ""
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bgm_a, "volume_db", -80.0, 0.5)
	tw.tween_property(_bgm_b, "volume_db", -80.0, 0.5)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		_bgm_a.stop()
		_bgm_b.stop()
	)


func play_sfx(sfx_key: String) -> void:
	if not SFX_DEFS.has(sfx_key):
		return
	var stream := _get_sfx_stream(sfx_key)
	var player := _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = 0.0
	player.play()


func set_bus_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_volumes[bus_name] = linear
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if linear <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
	_save_volumes()


func get_bus_volume(bus_name: String) -> float:
	return _volumes.get(bus_name, DEFAULT_VOLUME)


func update_bgm_for_scene(scene_name: String) -> void:
	# Check direct mapping first
	if SCENE_BGM_MAP.has(scene_name):
		var key: String = SCENE_BGM_MAP[scene_name]
		if key != "":
			play_bgm(key)
		return

	# Pattern-based matching for combat/village scenes
	if scene_name.begins_with("RoomBoss"):
		play_bgm("boss")
	elif scene_name.begins_with("RoomMiniBoss"):
		play_bgm("elite")
	elif scene_name.begins_with("CombatSmall") or scene_name == "RoomMedium":
		play_bgm("combat")
	elif scene_name.begins_with("Village"):
		play_bgm("village")
	elif scene_name.begins_with("Room"):
		play_bgm("combat")


# ── Placeholder audio generation ──────────────────────────

func _get_bgm_stream(track_key: String) -> AudioStream:
	if _bgm_cache.has(track_key):
		return _bgm_cache[track_key]

	# Try loading real audio file first
	var file_stream := _try_load_audio("res://audio/bgm/" + track_key)
	if file_stream:
		_bgm_cache[track_key] = file_stream
		return file_stream

	# Fallback to generated placeholder
	var freq: float = BGM_TRACKS[track_key]
	var stream := _generate_tone(freq, 4.0, true)
	_bgm_cache[track_key] = stream
	return stream


func _get_sfx_stream(sfx_key: String) -> AudioStream:
	if _sfx_cache.has(sfx_key):
		return _sfx_cache[sfx_key]

	# Try loading real audio file first
	var file_stream := _try_load_audio("res://audio/sfx/" + sfx_key)
	if file_stream:
		_sfx_cache[sfx_key] = file_stream
		return file_stream

	# Fallback to generated placeholder
	var def: Dictionary = SFX_DEFS[sfx_key]
	var stream: AudioStreamWAV
	if def["type"] == "noise":
		stream = _generate_noise(def["duration"])
	else:
		stream = _generate_tone(def["freq"], def["duration"], false)
	_sfx_cache[sfx_key] = stream
	return stream


func _try_load_audio(base_path: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		var path: String = base_path + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _generate_tone(freq: float, duration: float, looping: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var t := float(i) / sample_rate
		var sample := sin(t * freq * TAU) * 0.3

		# Apply fade-in/out for non-looping sounds
		if not looping:
			var fade_samples := int(0.01 * sample_rate)
			if i < fade_samples:
				sample *= float(i) / fade_samples
			elif i > num_samples - fade_samples:
				sample *= float(num_samples - i) / fade_samples

		var int_sample := clampi(int(sample * 32767), -32768, 32767)
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = num_samples
	return stream


func _generate_noise(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var sample := randf_range(-0.25, 0.25)

		# Envelope: quick attack, exponential decay
		var t := float(i) / num_samples
		sample *= (1.0 - t) * (1.0 - t)

		var int_sample := clampi(int(sample * 32767), -32768, 32767)
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


# ── Volume persistence ─────────────────────────────────────

func _apply_all_volumes() -> void:
	for bus_name in _volumes:
		var linear: float = _volumes[bus_name]
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			if linear <= 0.001:
				AudioServer.set_bus_mute(bus_idx, true)
			else:
				AudioServer.set_bus_mute(bus_idx, false)
				AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))


func _save_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for bus_name in _volumes:
		cfg.set_value("audio", bus_name, _volumes[bus_name])
	cfg.save(SAVE_PATH)


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for bus_name in _volumes:
		if cfg.has_section_key("audio", bus_name):
			_volumes[bus_name] = cfg.get_value("audio", bus_name, DEFAULT_VOLUME)
