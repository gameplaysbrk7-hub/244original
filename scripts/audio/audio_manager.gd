extends Node
## Áudio do jogo: motor com rotação e marchas, derrapagem, vento, ambiente urbano,
## impactos, queda, interface e jingles de missão. Volumes por barramento.

const SoundBank := preload("res://scripts/audio/sound_bank.gd")

const GEARS := 5

var bike: Node3D

var _engine: AudioStreamPlayer
var _skid: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _pool: Array = []
var _impact: AudioStreamWAV
var _crash: AudioStreamWAV
var _click: AudioStreamWAV
var _success: AudioStreamWAV
var _fail: AudioStreamWAV
var _rpm: float = 0.2
var _gear: int = 0
var _shift_dip: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["SFX", "Ambient", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	_engine = _loop(SoundBank.engine(), "SFX")
	_skid = _loop(SoundBank.skid(), "SFX")
	_wind = _loop(SoundBank.wind(), "SFX")
	_ambient = _loop(SoundBank.ambient(), "Ambient")
	_ambient.volume_db = -16.0
	_ui = AudioStreamPlayer.new()
	_ui.bus = "UI"
	add_child(_ui)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_impact = SoundBank.impact()
	_crash = SoundBank.crash()
	_click = SoundBank.click()
	_success = SoundBank.success()
	_fail = SoundBank.fail()


func apply_volumes(master: float, sfx: float, ambient: float) -> void:
	_set_bus("Master", master)
	_set_bus("SFX", sfx)
	_set_bus("Ambient", ambient)
	_set_bus("UI", sfx)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _loop(stream: AudioStreamWAV, bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus_name
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	if bike == null:
		return
	var paused := get_tree().paused
	for p in [_engine, _skid, _wind, _ambient]:
		p.stream_paused = paused
	if paused:
		return
	var speed: float = bike.speed
	var thr := clampf(float(bike.input_throttle), 0.0, 1.0)
	var max_speed: float = bike.profile.max_speed
	var span := max_speed / (GEARS + 0.4)
	var g := mini(int(speed / span), GEARS - 1)
	if g != _gear:
		if g > _gear:
			_shift_dip = 0.35
		_gear = g
	_shift_dip = move_toward(_shift_dip, 0.0, delta * 1.5)
	var in_gear := clampf((speed - g * span) / span, 0.0, 1.0)
	var target := 0.18 + in_gear * 0.6 + thr * 0.2 - _shift_dip
	if speed < 1.0 and thr < 0.1:
		target = 0.2
	if bike.burnout:
		target = 0.98
	if bike.fallen:
		target = 0.12
	_rpm = lerpf(_rpm, clampf(target, 0.1, 1.0), 1.0 - exp(-10.0 * delta))
	_engine.pitch_scale = lerpf(0.65, 2.4, _rpm)
	_engine.volume_db = lerpf(-20.0, -5.0, clampf(_rpm * (0.5 + 0.5 * thr), 0.0, 1.0))

	var skid: float = bike.skid_level
	_skid.volume_db = linear_to_db(skid * 0.7) if skid > 0.02 else -80.0
	_skid.pitch_scale = 0.9 + speed / 60.0
	var ratio := clampf(speed / max_speed, 0.0, 1.0)
	_wind.volume_db = lerpf(-45.0, -12.0, ratio)
	_wind.pitch_scale = 0.8 + 0.6 * ratio


func play_impact(strength: float) -> void:
	_play(_impact, lerpf(-14.0, -3.0, clampf(strength / 12.0, 0.0, 1.0)), randf_range(0.9, 1.1))


func play_crash() -> void:
	_play(_crash, -3.0, 1.0)


func play_success() -> void:
	_play(_success, -6.0, 1.0)


func play_fail() -> void:
	_play(_fail, -6.0, 1.0)


func play_click() -> void:
	_ui.stream = _click
	_ui.play()


func _play(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
