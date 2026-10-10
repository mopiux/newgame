extends Node
## Audio service: Music/SFX/UI buses, pooled SFX voices with pitch variation,
## per-sound throttling and crossfaded music. Sound ids map to files in
## res://assets/audio/sfx/<id>.wav (or .ogg) and music/<id>.ogg.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 24
const MIN_INTERVAL := 0.045  # same sound can't retrigger faster than this
const MUSIC_DB := -7.0       # music sits under the effects
const AMBIENCE_DB := -12.0

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _missing_reported: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_id := ""
var _ambience: AudioStreamPlayer
var _ambience_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("UI")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_current = _music_a
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Music"
	_ambience.volume_db = AMBIENCE_DB
	add_child(_ambience)
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func apply_volumes() -> void:
	_set_bus_volume("Master", Settings.get_value("audio", "master"))
	_set_bus_volume("Music", Settings.get_value("audio", "music"))
	_set_bus_volume("SFX", Settings.get_value("audio", "sfx"))
	_set_bus_volume("UI", Settings.get_value("audio", "sfx"))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _stream(dir: String, id: String) -> AudioStream:
	var key := dir + id
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var path: String = dir + id + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null and not _missing_reported.has(key):
		_missing_reported[key] = true
		push_warning("Audio: missing sound " + key)
	_cache[key] = stream
	return stream


## Plays a one-shot sound. pitch_var randomises pitch +/- that fraction.
func sfx(id: String, volume_db: float = 0.0, pitch_var: float = 0.08, pitch: float = 1.0, bus: String = "SFX") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -1.0)) < MIN_INTERVAL:
		return
	_last_played[id] = now
	var stream := _stream(SFX_DIR, id)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.play()


func ui(id: String = "ui_move") -> void:
	sfx(id, -4.0, 0.03, 1.0, "UI")


func music(id: String, fade: float = 1.2) -> void:
	if id == _music_id:
		return
	_music_id = id
	var next := _music_b if _music_current == _music_a else _music_a
	var stream: AudioStream = _stream(MUSIC_DIR, id) if id != "" else null
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music_current, "volume_db", -80.0, fade)
	if stream:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		next.stream = stream
		next.volume_db = -40.0
		next.play()
		tw.tween_property(next, "volume_db", MUSIC_DB, fade)
	var old := _music_current
	tw.chain().tween_callback(func(): if old != _music_current: old.stop())
	_music_current = next


func ambience(id: String) -> void:
	if id == _ambience_id:
		return
	_ambience_id = id
	var stream: AudioStream = _stream(MUSIC_DIR, id) if id != "" else null
	if stream == null:
		_ambience.stop()
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambience.stream = stream
	_ambience.play()


func current_music() -> String:
	return _music_id
