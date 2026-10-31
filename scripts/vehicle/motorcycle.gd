extends CharacterBody3D
## Moto arcade-híbrida (Fase 2): aceleração, freios, direção com inclinação,
## grau com equilíbrio assistido, stoppie, borrachão, derrapagem lateral,
## queda e reposicionamento.
## Origem do nó = contato da roda traseira com o solo; frente = -Z.

const BikeModel := preload("res://scripts/vehicle/bike_model.gd")
const VehicleProfile := preload("res://scripts/vehicle/vehicle_profile.gd")
const Humanoid := preload("res://scripts/player/humanoid.gd")

signal crashed
signal impacted(strength: float)
signal wheelie_finished(duration: float, score: int)
signal stoppie_finished(duration: float, score: int)

const GRAVITY := 24.0
const STOPPIE_MAX := 0.55
const REVERSE_SPEED := 1.4

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
var fallen: bool = false         # caída no chão: só levanta quando o jogador levantar a moto
var parked: bool = false         # estacionada (jogador desceu): ignora comandos
var reversing: bool = false      # andando de ré
var being_lifted: bool = false   # jogador está levantando a moto
var lift_t: float = 0.0
var crash_velocity: Vector3 = Vector3.ZERO
var rider_on_bike: bool = true
var skid_level: float = 0.0      # intensidade de derrapagem/frenagem (usada pelo áudio)
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
var _headlight: SpotLight3D
var _rider: Humanoid
var _rider_base: Dictionary = {}
var _rider_cur: Dictionary = {}
var _rider_phase: float = 0.0
var _rb_prev: float = 0.0
var _reverse_ok: bool = false
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

	_headlight = SpotLight3D.new()
	_headlight.position = Vector3(0, 1.0, -profile.wheelbase)
	_headlight.rotation = Vector3(-0.12, 0, 0)
	_headlight.spot_range = 28.0
	_headlight.spot_angle = 32.0
	_headlight.light_energy = 2.5
	_headlight.shadow_enabled = false
	_headlight.visible = false
	add_child(_headlight)

	_build_visuals()
	_spawn_transform = global_transform
	move_yaw = rotation.y


## Troca o perfil (e a customização) da moto, reconstruindo o visual e a colisão.
func set_profile(p: VehicleProfile, c: Dictionary) -> void:
	profile = p
	custom = c
	if is_inside_tree():
		_build_visuals()


func set_rider_visible(on: bool) -> void:
	rider_on_bike = on
	if _rider != null:
		_rider.root.visible = on


## Posição do banco no mundo (para o personagem descer/subir).
func seat_world() -> Vector3:
	return global_transform * Vector3(0, 0, -0.12)


func begin_lift() -> void:
	being_lifted = true
	lift_t = 0.0


func set_lift_progress(t: float) -> void:
	lift_t = clampf(t, 0.0, 1.0)


## Termina de levantar a moto: fica em pé e estacionada (sem piloto).
func finish_lift() -> void:
	being_lifted = false
	fallen = false
	parked = true
	lean = 0.0
	speed = 0.0
	velocity = Vector3.ZERO
	move_yaw = rotation.y
	_update_visuals(0.016)


func set_carrying(on: bool) -> void:
	carrying = on
	if parts.has("bag"):
		(parts["bag"] as Node3D).visible = on


func set_headlight(on: bool) -> void:
	if _headlight != null:
		_headlight.visible = on


func apply_customization(c: Dictionary) -> void:
	custom = c
	if not parts.is_empty():
		BikeModel.apply_custom(parts, custom)
	_apply_suspension()


func _build_visuals() -> void:
	if _stoppie_pivot != null:
		_stoppie_pivot.queue_free()
	front_axle_z = -profile.wheelbase
	if _headlight != null:
		_headlight.position = Vector3(0, 1.0, front_axle_z)
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
	_rider = Humanoid.new()
	_rider.build(_lean_pivot)
	_rider_base = BikeModel.rider_pose(profile)
	_rider_cur = _rider_base.duplicate()
	_rider.pose(_rider_cur)
	_rider.root.visible = rider_on_bike
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
	being_lifted = false
	reversing = false
	_reverse_ok = false
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
	if parked:
		_update_parked(delta)
		return

	var thr := clampf(input_throttle, 0.0, 1.0)
	var fb := clampf(input_brake_front, 0.0, 1.0)
	var rb := clampf(input_brake_rear, 0.0, 1.0)

	# --- Marcha à ré: só com a moto parada e um novo toque no freio traseiro
	var fresh_rb := rb > 0.5 and _rb_prev <= 0.5
	_rb_prev = rb
	if fresh_rb and absf(speed) < 0.5 and thr < 0.1 and fb < 0.3:
		_reverse_ok = true
	if rb < 0.3 or thr > 0.1 or fb > 0.3 or speed > 0.6:
		_reverse_ok = false
	reversing = _reverse_ok

	# --- Longitudinal
	if reversing:
		speed = move_toward(speed, -REVERSE_SPEED, 3.5 * delta)
	elif speed < 0.0:
		speed = move_toward(speed, 0.0, 6.0 * delta)
	else:
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
			impacted.emit(4.0)
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

	# --- Intensidade sonora de derrapagem/frenagem
	var skid := 0.0
	if burnout:
		skid = 1.0
	elif drifting:
		skid = clampf(absf(angle_difference(move_yaw, rotation.y)) * 3.0 + 0.3, 0.0, 1.0)
	elif speed > 8.0 and (fb > 0.8 or rb > 0.8):
		skid = 0.25
	if stoppie > 0.1:
		skid = maxf(skid, 0.6)
	skid_level = skid

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
		var speed_factor := clampf(absf(speed) / 6.0, 0.0, 1.0)
		if reversing:
			speed_factor = 0.55
		var dir_sign := 1.0 if speed >= 0.0 else -1.0
		rate = profile.steer_rate * _steer_mult * clampf(input_steer, -1.0, 1.0) * speed_factor * dir_sign / (1.0 + absf(speed) * profile.steer_falloff)
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
				if into > 2.0:
					impacted.emit(into)
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
	crash_velocity = Vector3(velocity.x, 0.0, velocity.z)
	fallen = true
	reversing = false
	_reverse_ok = false
	skid_level = 0.0
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
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if being_lifted:
		lean = fall_side * 1.45 * (1.0 - smoothstep(0.0, 1.0, lift_t))
	else:
		lean = lerpf(lean, fall_side * 1.45, 1.0 - exp(-8.0 * delta))
	_update_visuals(delta)


func _update_parked(delta: float) -> void:
	speed = move_toward(speed, 0.0, 12.0 * delta)
	skid_level = 0.0
	burnout = false
	drifting = false
	reversing = false
	var fwd := Vector3(-sin(move_yaw), 0.0, -cos(move_yaw))
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	velocity.y -= GRAVITY * delta
	move_and_slide()
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
	_update_rider(delta)


## Anima o piloto: inclina com a curva e a frenagem, recua no grau, põe os pés no chão
## para andar de ré e apoia um pé quando a moto está parada.
func _update_rider(delta: float) -> void:
	if _rider == null or not rider_on_bike:
		return
	var base_hip: Vector3 = _rider_base["hip"]
	var hip := base_hip
	var chest: Vector3 = _rider_base["chest"]
	var head: Vector3 = _rider_base["head"]
	var foot_l: Vector3 = _rider_base["foot_l"]
	var foot_r: Vector3 = _rider_base["foot_r"]
	var shift := Vector3(-lean * 0.06, 0.0, -0.05 * input_brake_front + 0.08 * clampf(pitch, 0.0, 1.0))
	chest += shift
	head += shift * 1.3
	var head_yaw := 0.0
	if reversing:
		_rider_phase += absf(speed) * delta * PI / (2.0 * 0.28)
		var drop_y := minf(0.0, 0.98 - base_hip.y)
		var slide := Vector3(0.0, drop_y, -0.1)
		hip += slide
		chest += slide + Vector3(-0.08, 0.0, 0.0)
		head += slide + Vector3(-0.1, 0.0, 0.0)
		head_yaw = 1.5
		for i in 2:
			var sgn := -1.0 if i == 0 else 1.0
			var ph := _rider_phase + (0.0 if i == 0 else PI)
			var foot := Vector3(0.3 * sgn, 0.08 + 0.14 * maxf(0.0, cos(ph)), -0.3 + 0.28 * sin(ph))
			if i == 0:
				foot_l = foot
			else:
				foot_r = foot
	elif absf(speed) < 0.8 and input_throttle < 0.1:
		foot_l = Vector3(-0.3, 0.08, -0.3)
		chest += Vector3(-0.06, 0.0, 0.0)
		head += Vector3(-0.06, 0.0, 0.0)
	var target := {
		"hip": hip, "chest": chest, "head": head, "head_yaw": head_yaw,
		"hand_l": _rider_base["hand_l"], "hand_r": _rider_base["hand_r"],
		"foot_l": foot_l, "foot_r": foot_r,
	}
	_rider_cur = Humanoid.lerp_pose(_rider_cur, target, 1.0 - exp(-12.0 * delta))
	_rider.pose(_rider_cur)
