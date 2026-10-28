extends CharacterBody3D
## Moto arcade-híbrida (Fase 1): aceleração, freios, direção com inclinação,
## grau com equilíbrio, queda e reposicionamento.
## Origem do nó = contato da roda traseira com o solo; frente = -Z.

const BikeModel := preload("res://scripts/vehicle/bike_model.gd")
const VehicleProfile := preload("res://scripts/vehicle/vehicle_profile.gd")

signal crashed
signal wheelie_finished(duration: float, score: int)

const GRAVITY := 24.0

var profile: VehicleProfile

# Entradas (preenchidas por quem controla a moto)
var input_throttle: float = 0.0
var input_brake_front: float = 0.0
var input_brake_rear: float = 0.0
var input_steer: float = 0.0
var input_wheelie: bool = false

# Estado
var speed: float = 0.0
var pitch: float = 0.0
var pitch_vel: float = 0.0
var lean: float = 0.0
var fallen: bool = false
var fall_timer: float = 0.0
var fall_side: float = 1.0
var wheelie_time: float = 0.0
var wheelie_score: float = 0.0

var _spawn_transform: Transform3D
var _pitch_pivot: Node3D
var _lean_pivot: Node3D
var _fork: Node3D
var _front_wheel: Node3D
var _rear_wheel: Node3D


func _ready() -> void:
	if profile == null:
		profile = load("res://resources/vehicles/starter.tres")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 1.0, 1.9)
	cs.shape = shape
	cs.position = Vector3(0, 0.5, -0.6)
	add_child(cs)

	_pitch_pivot = Node3D.new()
	add_child(_pitch_pivot)
	_lean_pivot = Node3D.new()
	_pitch_pivot.add_child(_lean_pivot)
	var parts: Dictionary = BikeModel.build(profile.body_color)
	_lean_pivot.add_child(parts["root"])
	_fork = parts["fork"]
	_front_wheel = parts["front_wheel"]
	_rear_wheel = parts["rear_wheel"]

	_spawn_transform = global_transform


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	speed = 0.0
	pitch = 0.0
	pitch_vel = 0.0
	lean = 0.0
	fallen = false
	wheelie_time = 0.0
	wheelie_score = 0.0


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

	# --- Grau (equilíbrio em torno do eixo traseiro)
	var lifting := thr > 0.2 and speed > 2.5 and fb < 0.3 and (input_wheelie or pitch > 0.08)
	var torque := -profile.wheelie_gravity * sin(pitch) - 2.2 * pitch_vel
	if lifting:
		torque += thr * profile.wheelie_lift * (1.0 + 0.015 * speed)
	if pitch > 0.0:
		torque -= rb * 8.0 + fb * 14.0
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
		wheelie_score += delta * (5.0 + speed * 0.8) * (1.0 + pitch * 1.5)
	elif pitch <= 0.0 and wheelie_time > 0.0:
		if wheelie_time >= 1.0:
			wheelie_finished.emit(wheelie_time, int(wheelie_score))
		wheelie_time = 0.0
		wheelie_score = 0.0

	# --- Direção
	var speed_factor := clampf(speed / 6.0, 0.0, 1.0)
	var rate := profile.steer_rate * clampf(input_steer, -1.0, 1.0) * speed_factor / (1.0 + speed * profile.steer_falloff)
	rate *= 1.0 - 0.5 * clampf(pitch, 0.0, 1.0)
	rotate_y(-rate * delta)
	var lean_target := -clampf(input_steer, -1.0, 1.0) * profile.max_lean * clampf(speed / 12.0, 0.0, 1.0)
	lean = lerpf(lean, lean_target, 1.0 - exp(-6.0 * delta))

	# --- Movimento
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	velocity.y -= GRAVITY * delta
	move_and_slide()

	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if n.y < 0.5:
			var into := -fwd.dot(n) * speed
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
	fall_side = 1.0 if lean >= 0.0 else -1.0
	speed = 0.0
	pitch = 0.0
	pitch_vel = 0.0
	wheelie_time = 0.0
	wheelie_score = 0.0
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
	_update_visuals(delta)


func _update_visuals(delta: float) -> void:
	_pitch_pivot.rotation.x = pitch
	_lean_pivot.rotation.z = lean
	var spin := speed / 0.33 * delta
	_rear_wheel.rotation.x -= spin
	_front_wheel.rotation.x -= spin
	var steer_visual := -clampf(input_steer, -1.0, 1.0) * 0.35
	_fork.rotation.y = lerpf(_fork.rotation.y, steer_visual, 1.0 - exp(-12.0 * delta))
