extends CharacterBody3D
## Moto arcade-híbrida (Fase 2): aceleração, freios, direção com inclinação,
## grau com equilíbrio assistido, stoppie, borrachão, derrapagem lateral,
## queda e reposicionamento.
## Origem do nó = contato da roda traseira com o solo; frente = -Z.

const BikeModel := preload("res://scripts/vehicle/bike_model.gd")
const VehicleProfile := preload("res://scripts/vehicle/vehicle_profile.gd")

signal crashed
signal wheelie_finished(duration: float, score: int)
signal stoppie_finished(duration: float, score: int)

const GRAVITY := 24.0
const STOPPIE_MAX := 0.55

var profile: VehicleProfile
var custom: Dictionary = {}
var parts: Dictionary = {}
var front_axle_z: float = -1.3

# Entradas (preenchidas por quem controla a moto)
var input_throttle: float = 0.0
var input_brake_front: float = 0.0
var input_brake_rear: float = 0.0
var input_steer: float = 0.0
var input_wheelie: bool = false
var input_balance: bool = false
var input_drift: bool = false

# Estado
var speed: float = 0.0
var pitch: float = 0.0          # grau: dianteira para cima (rad)
var pitch_vel: float = 0.0
var stoppie: float = 0.0        # stoppie: traseira para cima (rad)
var stoppie_vel: float = 0.0
var lean: float = 0.0
var move_yaw: float = 0.0       # direção real de deslocamento (difere do corpo na derrapagem)
var burnout: bool = false
var drifting: bool = false
var fallen: bool = false
var carrying: bool = false     # levando um pedido (mostra a bolsa de entrega)
var fall_timer: float = 0.0
var fall_side: float = 1.0
var wheelie_time: float = 0.0
var wheelie_score: float = 0.0
var stoppie_time: float = 0.0
var stoppie_score: float = 0.0

var _spawn_transform: Transform3D
var _stoppie_pivot: Node3D
var _pitch_pivot: Node3D
var _lean_pivot: Node3D
var _fork: Node3D
var _front_wheel: Node3D
var _rear_wheel: Node3D
var _smoke: CPUParticles3D
var _cs: CollisionShape3D
var _steer_mult: float = 1.0
var _lean_mult: float = 1.0


func _ready() -> void:
	if profile == null:
		profile = load("res://resources/vehicles/starter.tres")
	if custom.is_empty():
		custom = BikeModel.default_custom(profile)
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.3

	_cs = CollisionShape3D.new()
	_cs.shape = BoxShape3D.new()
	add_child(_cs)

	_smoke = CPUParticles3D.new()
	_smoke.position = Vector3(0, 0.08, 0.1)
	_smoke.amount = 20
	_smoke.lifetime = 0.8
	_smoke.local_coords = false
	_smoke.emitting = false
	_smoke.direction = Vector3(0, 1, 0.6)
	_smoke.spread = 35.0
	_smoke.initial_velocity_min = 0.4
	_smoke.initial_velocity_max = 1.2
	_smoke.gravity = Vector3(0, 0.6, 0)
	_smoke.scale_amount_min = 0.8
	_smoke.scale_amount_max = 2.0
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 6
	puff.rings = 3
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(0.85, 0.85, 0.85, 0.5)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = puff_mat
	_smoke.mesh = puff
	add_child(_smoke)

	_build_visuals()
	_spawn_transform = global_transform
	move_yaw = rotation.y


## Troca o perfil (e a customização) da moto, reconstruindo o visual e a colisão.
func set_profile(p: VehicleProfile, c: Dictionary) -> void:
	profile = p
	custom = c
	if is_inside_tree():
		_build_visuals()


func set_carrying(on: bool) -> void:
	carrying = on
	if parts.has("bag"):
		(parts["bag"] as Node3D).visible = on


func apply_customization(c: Dictionary) -> void:
	custom = c
	if not parts.is_empty():
		BikeModel.apply_custom(parts, custom)
	_apply_suspension()


func _build_visuals() -> void:
	if _stoppie_pivot != null:
		_stoppie_pivot.queue_free()
	front_axle_z = -profile.wheelbase
	_stoppie_pivot = Node3D.new()
	_stoppie_pivot.position = Vector3(0, 0, front_axle_z)
	add_child(_stoppie_pivot)
	var offset := Node3D.new()
	offset.position = Vector3(0, 0, -front_axle_z)
	_stoppie_pivot.add_child(offset)
	_pitch_pivot = Node3D.new()
	offset.add_child(_pitch_pivot)
	_lean_pivot = Node3D.new()
	_pitch_pivot.add_child(_lean_pivot)
	parts = BikeModel.build(profile, custom)
	_lean_pivot.add_child(parts["root"])
	_fork = parts["fork"]
	_front_wheel = parts["front_wheel"]
	_rear_wheel = parts["rear_wheel"]
	BikeModel.apply_custom(parts, custom)
	(parts["bag"] as Node3D).visible = carrying
	_apply_suspension()
	var shape := _cs.shape as BoxShape3D
	shape.size = Vector3(0.5, 1.0, profile.wheelbase + 0.6)
	_cs.position = Vector3(0, 0.5, -profile.wheelbase * 0.5 + 0.05)


func _apply_suspension() -> void:
	var level := clampi(int(custom.get("suspension", 1)), 0, 2)
	_steer_mult = [0.96, 1.0, 1.06][level]
	_lean_mult = [1.15, 1.0, 0.9][level]


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	speed = 0.0
	pitch = 0.0
	pitch_vel = 0.0
	stoppie = 0.0
	stoppie_vel = 0.0
	lean = 0.0
	fallen = false
	burnout = false
	drifting = false
	wheelie_time = 0.0
	wheelie_score = 0.0
	stoppie_time = 0.0
	stoppie_score = 0.0
	move_yaw = rotation.y


func _physics_process(delta: float) -> void:
	if fallen:
		_update_fallen(delta)
		return

	var thr := clampf(input_throttle, 0.0, 1.0)
	var fb := clampf(input_brake_front, 0.0, 1.0)
	var rb := clampf(input_brake_rear, 0.0, 1.0)

	# --- Longitudinal
	var drive := thr * profile.accel * (1.0 - clampf(speed / profile.max_speed, 0.0, 1.0))
	var resist := profile.rolling_resistance + profile.air_drag * speed + fb * profile.brake_front + rb * profile.brake_rear
	speed = clampf(speed + (drive - resist) * delta, 0.0, profile.max_speed)

	# --- Borrachão (parado/lento) e derrapagem lateral (em velocidade)
	burnout = input_drift and thr > 0.3 and speed < 6.0
	drifting = input_drift and not burnout and speed >= 6.0 and absf(input_steer) > 0.2 and pitch <= 0.05
	if burnout:
		speed = move_toward(speed, 2.0, 12.0 * delta)

	# --- Grau (equilíbrio em torno do eixo traseiro)
	var lifting := thr > 0.2 and speed > 2.5 and fb < 0.3 and (input_wheelie or pitch > 0.08)
	var torque := -profile.wheelie_gravity * sin(pitch) - 2.2 * pitch_vel
	if lifting:
		torque += thr * profile.wheelie_lift * (1.0 + 0.015 * speed)
	if pitch > 0.0:
		torque -= rb * 8.0 + fb * 14.0
	var assist := input_balance and pitch > 0.1 and thr > 0.1 and speed > 4.0
	if assist:
		torque += 14.0 * (0.5 - pitch) - 2.0 * pitch_vel
	var was_pitch := pitch
	pitch_vel += torque * delta
	pitch += pitch_vel * delta
	if pitch <= 0.0:
		if was_pitch > 0.3 and pitch_vel < -2.5:
			speed *= 0.93
		pitch = 0.0
		pitch_vel = 0.0
	if pitch >= profile.wheelie_max_pitch:
		_crash()
		return

	if pitch > 0.15:
		wheelie_time += delta
		var mult := 0.6 if assist else 1.0
		wheelie_score += delta * (5.0 + speed * 0.8) * (1.0 + pitch * 1.5) * mult
	elif pitch <= 0.0 and wheelie_time > 0.0:
		if wheelie_time >= 1.0:
			wheelie_finished.emit(wheelie_time, int(wheelie_score))
		wheelie_time = 0.0
		wheelie_score = 0.0

	# --- Stoppie (freio dianteiro forte em velocidade levanta a traseira)
	var stoppie_on := fb > 0.6 and speed > 10.0 and pitch <= 0.0 and thr < 0.3
	var st_torque := -profile.wheelie_gravity * 1.4 * sin(stoppie) - 3.0 * stoppie_vel
	if stoppie_on:
		st_torque += fb * (speed - 8.0) * 0.25
	st_torque -= rb * 5.0 * signf(stoppie)
	stoppie_vel += st_torque * delta
	stoppie += stoppie_vel * delta
	if stoppie <= 0.0:
		stoppie = 0.0
		stoppie_vel = 0.0
	if stoppie >= STOPPIE_MAX:
		_crash()
		return
	if stoppie > 0.12:
		stoppie_time += delta
		stoppie_score += delta * (4.0 + speed * 0.6) * (1.0 + stoppie * 2.0)
	elif stoppie <= 0.0 and stoppie_time > 0.0:
		if stoppie_time >= 0.8:
			stoppie_finished.emit(stoppie_time, int(stoppie_score))
		stoppie_time = 0.0
		stoppie_score = 0.0

	# --- Queda em curva: frear forte com a dianteira inclinado em alta velocidade
	if speed > 25.0 and absf(input_steer) > 0.9 and fb > 0.5:
		fall_side = signf(-input_steer)
		_crash()
		return

	# --- Direção
	var rate: float
	if burnout:
		rate = profile.steer_rate * _steer_mult * 1.2 * clampf(input_steer, -1.0, 1.0)
	else:
		var speed_factor := clampf(speed / 6.0, 0.0, 1.0)
		rate = profile.steer_rate * _steer_mult * clampf(input_steer, -1.0, 1.0) * speed_factor / (1.0 + speed * profile.steer_falloff)
		if drifting:
			rate *= 1.6
	rate *= 1.0 - 0.5 * clampf(pitch, 0.0, 1.0)
	rotate_y(-rate * delta)
	var lean_target := -clampf(input_steer, -1.0, 1.0) * profile.max_lean * _lean_mult * clampf(speed / 12.0, 0.0, 1.0)
	lean = lerpf(lean, lean_target, 1.0 - exp(-6.0 * delta))

	# Direção real do deslocamento: acompanha o corpo rápido (aderência) ou devagar (derrapagem)
	var grip := 2.2 if drifting else 20.0
	move_yaw = lerp_angle(move_yaw, rotation.y, 1.0 - exp(-grip * delta))
	if drifting:
		speed = maxf(0.0, speed - absf(angle_difference(move_yaw, rotation.y)) * 5.0 * delta)

	# --- Movimento
	var fwd := Vector3(-sin(move_yaw), 0.0, -cos(move_yaw))
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	velocity.y -= GRAVITY * delta
	move_and_slide()

	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if n.y < 0.5:
			var cv := col.get_collider_velocity()
			var other := col.get_collider()
			if other != null:
				var mv: Variant = other.get("motion")
				if typeof(mv) == TYPE_VECTOR3:
					cv = mv
			var rel := fwd * speed - cv
			rel.y = 0.0
			var into := -rel.dot(n)
			if into > 0.0:
				speed = maxf(0.0, speed - into * 1.1)
				if into > profile.crash_speed_loss * 0.6:
					_crash()
					break

	if global_position.y < -20.0:
		respawn()
	_update_visuals(delta)


func _crash() -> void:
	if fallen:
		return
	fallen = true
	fall_timer = 0.0
	if absf(lean) > 0.05:
		fall_side = 1.0 if lean >= 0.0 else -1.0
	elif absf(fall_side) < 0.5:
		fall_side = 1.0
	speed = 0.0
	pitch = 0.0
	pitch_vel = 0.0
	stoppie = 0.0
	stoppie_vel = 0.0
	burnout = false
	drifting = false
	wheelie_time = 0.0
	wheelie_score = 0.0
	stoppie_time = 0.0
	stoppie_score = 0.0
	crashed.emit()


func _update_fallen(delta: float) -> void:
	fall_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	lean = lerpf(lean, fall_side * 1.45, 1.0 - exp(-8.0 * delta))
	if fall_timer > 1.8:
		fallen = false
		lean = 0.0
		speed = 0.0
		move_yaw = rotation.y
	_update_visuals(delta)


func _update_visuals(delta: float) -> void:
	_pitch_pivot.rotation.x = pitch
	_stoppie_pivot.rotation.x = -stoppie
	_lean_pivot.rotation.z = lean
	var spin := speed / profile.wheel_radius * delta
	_front_wheel.rotation.x -= spin
	_rear_wheel.rotation.x -= spin + (30.0 * delta if burnout else 0.0)
	var steer_visual := -clampf(input_steer, -1.0, 1.0) * 0.35
	_fork.rotation.y = lerpf(_fork.rotation.y, steer_visual, 1.0 - exp(-12.0 * delta))
	_smoke.emitting = burnout or drifting
