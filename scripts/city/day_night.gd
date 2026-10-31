extends Node
## Ciclo de dia e noite: posição/cor do sol, cores do céu, névoa, luz ambiente, janelas acesas,
## farol da moto e um pequeno grupo de luzes de poste reaproveitadas junto do jogador.

signal night_changed(is_night: bool)

const DAY_TOP := Color(0.22, 0.44, 0.82)
const DAY_HORIZON := Color(0.74, 0.84, 0.94)
const NIGHT_TOP := Color(0.015, 0.025, 0.07)
const NIGHT_HORIZON := Color(0.05, 0.06, 0.12)
const DUSK := Color(0.95, 0.5, 0.28)

var time_of_day: float = 9.0
var day_minutes: float = 8.0        # minutos reais por dia (0 = tempo parado)
var use_lamp_lights: bool = true
var night: float = 0.0

var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _lit: Array = []
var _lamps: Array = []
var _bike: Node3D
var _omnis: Array = []
var _applied_night: float = -1.0
var _was_night: bool = false
var _lamp_timer: float = 0.0


func setup(env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D, lit_materials: Array, lamp_positions: Array, bike: Node3D) -> void:
	_env = env
	_sky = sky
	_sun = sun
	_lit = lit_materials
	_lamps = lamp_positions
	_bike = bike
	for i in 4:
		var o := OmniLight3D.new()
		o.omni_range = 16.0
		o.light_color = Color(1.0, 0.85, 0.55)
		o.light_energy = 0.0
		o.shadow_enabled = false
		o.visible = false
		add_child(o)
		_omnis.append(o)
	_apply(true)


func set_time(hours: float) -> void:
	time_of_day = fposmod(hours, 24.0)
	_apply(true)


func clock_text() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]


func is_night() -> bool:
	return night > 0.5


func _process(delta: float) -> void:
	if _sun == null:
		return
	if day_minutes > 0.0:
		time_of_day = fposmod(time_of_day + delta * 24.0 / (day_minutes * 60.0), 24.0)
	_apply(false)
	_lamp_timer -= delta
	if _lamp_timer <= 0.0:
		_lamp_timer = 0.6
		_update_lamp_lights()


func _apply(force: bool) -> void:
	if _sun == null:
		return
	var e := sin((time_of_day - 6.0) / 24.0 * TAU)   # elevação do sol: -1 (meia-noite) a 1 (meio-dia)
	var d := smoothstep(-0.12, 0.25, e)
	night = 1.0 - d
	var warm := (1.0 - smoothstep(0.1, 0.5, e)) * d
	var dusk := clampf(1.0 - absf(e) / 0.3, 0.0, 1.0)

	if e > -0.05:
		_sun.rotation_degrees = Vector3(-(maxf(e, 0.0) * 65.0 + 5.0), lerpf(-110.0, 70.0, clampf((time_of_day - 6.0) / 12.0, 0.0, 1.0)), 0.0)
	else:
		_sun.rotation_degrees = Vector3(-35.0, 150.0, 0.0)   # luz da lua
	var sun_energy := 0.3 + 0.95 * smoothstep(0.0, 0.5, e)
	_sun.light_energy = lerpf(0.18, sun_energy, d)
	_sun.light_color = Color(0.5, 0.6, 0.9).lerp(Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.6, 0.3), warm), d)

	var top := NIGHT_TOP.lerp(DAY_TOP, d)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, d).lerp(DUSK, dusk * 0.55)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = horizon
	_sky.ground_horizon_color = horizon
	_sky.ground_bottom_color = horizon.darkened(0.45)
	_env.ambient_light_energy = lerpf(0.22, 1.0, d)
	_env.fog_light_color = horizon

	if force or absf(night - _applied_night) > 0.03:
		_applied_night = night
		for m in _lit:
			(m as StandardMaterial3D).emission_energy_multiplier = night * 1.3
		if is_instance_valid(_bike) and _bike.has_method("set_headlight"):
			_bike.set_headlight(night > 0.4)
	var now_night := night > 0.5
	if now_night != _was_night:
		_was_night = now_night
		night_changed.emit(now_night)


func _update_lamp_lights() -> void:
	var active := use_lamp_lights and night > 0.05 and is_instance_valid(_bike) and not _lamps.is_empty()
	if not active:
		for o in _omnis:
			o.visible = false
		return
	var center: Vector3 = _bike.global_position
	var near: Array = []
	for p in _lamps:
		near.append([center.distance_squared_to(p), p])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in _omnis.size():
		var o: OmniLight3D = _omnis[i]
		if i < near.size():
			o.position = near[i][1]
			o.light_energy = night * 2.6
			o.visible = true
		else:
			o.visible = false
