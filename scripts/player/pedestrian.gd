extends CharacterBody3D
## Personagem a pé: anda, corre, desce e sobe da moto, cai ao bater e levanta a moto do chão.
## Origem do nó = pés no chão; frente = -Z.

const Humanoid := preload("res://scripts/player/humanoid.gd")

signal stepped(running: bool)
signal mount_finished
signal lift_finished

enum State { WALK, DISMOUNT, MOUNT, TUMBLE, GETUP, LIFT }

const WALK_SPEED := 2.6
const RUN_SPEED := 6.2
const GRAVITY := 24.0
const DISMOUNT_TIME := 0.5
const MOUNT_TIME := 0.55
const TUMBLE_TIME := 1.1
const GETUP_TIME := 1.0
const LIFT_TIME := 1.7

var state: int = State.WALK
var human: Humanoid
var input_move: Vector2 = Vector2.ZERO   # x: direita, y: para trás (em relação à câmera)
var input_run: bool = false
var view_yaw: float = 0.0
var speed: float = 0.0
var yaw: float = 0.0
var lift_progress: float = 0.0

var _phase: float = 0.0
var _last_step: int = 0
var _t: float = 0.0
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _slide: Vector3 = Vector3.ZERO
var _spin: float = 0.0
var _bike: Node3D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	human = Humanoid.new()
	human.build(self)
	human.pose(_stand())


# ------------------------------------------------------------------ poses

static func _stand() -> Dictionary:
	return {
		"hip": Vector3(0, 0.93, 0), "chest": Vector3(0, 1.42, 0), "head": Vector3(0, 1.62, 0), "head_yaw": 0.0,
		"hand_l": Vector3(-0.3, 0.82, 0.02), "hand_r": Vector3(0.3, 0.82, 0.02),
		"foot_l": Vector3(-0.12, 0.08, 0.0), "foot_r": Vector3(0.12, 0.08, 0.0),
	}


static func _seated() -> Dictionary:
	return {
		"hip": Vector3(0, 0.93, 0.0), "chest": Vector3(0, 1.4, -0.28), "head": Vector3(0, 1.6, -0.34), "head_yaw": 0.0,
		"hand_l": Vector3(-0.31, 1.08, -0.82), "hand_r": Vector3(0.31, 1.08, -0.82),
		"foot_l": Vector3(-0.25, 0.46, -0.26), "foot_r": Vector3(0.25, 0.46, -0.26),
	}


static func _lying(t: float) -> Dictionary:
	return {
		"hip": Vector3(0, 0.14, 0), "chest": Vector3(0, 0.16, -0.45), "head": Vector3(0, 0.2, -0.68), "head_yaw": 0.3,
		"hand_l": Vector3(-0.55, 0.1, -0.5 + 0.1 * sin(t * 9.0)), "hand_r": Vector3(0.55, 0.1, -0.35 - 0.1 * sin(t * 9.0)),
		"foot_l": Vector3(-0.2, 0.09, 0.75 + 0.15 * sin(t * 7.0)), "foot_r": Vector3(0.2, 0.09, 0.7 - 0.15 * sin(t * 7.0)),
	}


static func _kneel() -> Dictionary:
	return {
		"hip": Vector3(0, 0.45, 0.15), "chest": Vector3(0, 0.92, -0.15), "head": Vector3(0, 1.1, -0.2), "head_yaw": 0.0,
		"hand_l": Vector3(-0.3, 0.45, -0.35), "hand_r": Vector3(0.3, 0.45, -0.35),
		"foot_l": Vector3(-0.15, 0.1, 0.55), "foot_r": Vector3(0.15, 0.1, 0.55),
	}


static func _squat() -> Dictionary:
	return {
		"hip": Vector3(0, 0.55, 0.05), "chest": Vector3(0, 0.98, -0.22), "head": Vector3(0, 1.15, -0.28), "head_yaw": 0.0,
		"hand_l": Vector3(-0.2, 0.3, -0.62), "hand_r": Vector3(0.2, 0.3, -0.62),
		"foot_l": Vector3(-0.18, 0.08, 0.05), "foot_r": Vector3(0.18, 0.08, 0.05),
	}


static func walk_pose(phase: float, run: float, moving: float) -> Dictionary:
	var p := _stand()
	var stride := lerpf(0.26, 0.5, run) * moving
	var lift := lerpf(0.13, 0.3, run) * moving
	var swing := lerpf(0.22, 0.4, run) * moving
	var bob := lerpf(0.025, 0.06, run) * moving
	var hip_y := lerpf(0.92, 0.85, run)
	var lean := 0.12 * run * moving
	var hip := Vector3(0, hip_y - bob * absf(sin(phase)), 0)
	p["hip"] = hip
	p["chest"] = hip + Vector3(0, 0.49, -lean)
	p["head"] = hip + Vector3(0, 0.69, -lean * 1.5)
	for i in 2:
		var s := "l" if i == 0 else "r"
		var sgn := -1.0 if i == 0 else 1.0
		var ph := phase + (0.0 if i == 0 else PI)
		p["foot_" + s] = Vector3(0.12 * sgn, 0.08 + lift * maxf(0.0, cos(ph)), -stride * sin(ph))
		var oph := phase + (PI if i == 0 else 0.0)
		var hand_y := lerpf(0.82, 1.0, run)
		p["hand_" + s] = Vector3(lerpf(0.3, 0.26, run) * sgn, hand_y, 0.02 - swing * sin(oph) - 0.1 * run * moving)
	return p


# ------------------------------------------------------------- transições

func begin_dismount(seat_pos: Vector3, side_pos: Vector3, bike_yaw: float) -> void:
	visible = true
	state = State.DISMOUNT
	_t = 0.0
	_from = seat_pos
	_to = side_pos
	yaw = bike_yaw
	rotation.y = yaw
	global_position = seat_pos
	velocity = Vector3.ZERO
	speed = 0.0


func begin_mount(bike: Node3D) -> void:
	state = State.MOUNT
	_t = 0.0
	_bike = bike
	_from = global_position
	_to = bike.global_transform * Vector3(0, 0, -0.12)
	_yaw_from = yaw
	_yaw_to = bike.global_rotation.y
	velocity = Vector3.ZERO
	speed = 0.0


func begin_tumble(crash_velocity: Vector3, bike_yaw: float) -> void:
	visible = true
	state = State.TUMBLE
	_t = 0.0
	yaw = bike_yaw
	rotation.y = yaw
	_slide = Vector3(crash_velocity.x, 0.0, crash_velocity.z)
	if _slide.length() > 12.0:
		_slide = _slide.normalized() * 12.0
	_spin = randf_range(-3.0, 3.0)
	speed = 0.0


func begin_lift(bike: Node3D) -> void:
	state = State.LIFT
	_t = 0.0
	_bike = bike
	lift_progress = 0.0
	_from = global_position
	var side: float = bike.fall_side
	_to = bike.global_transform * Vector3(side * 0.9, 0.0, -0.5)
	_to.y = global_position.y
	var face: Vector3 = -side * bike.global_transform.basis.x
	face.y = 0.0
	_yaw_from = yaw
	_yaw_to = atan2(-face.x, -face.z)
	velocity = Vector3.ZERO
	speed = 0.0


## Coloca o personagem em pé ao lado da moto (usado ao reposicionar a moto).
func reset_beside(pos: Vector3, bike_yaw: float) -> void:
	visible = true
	state = State.WALK
	global_position = pos
	yaw = bike_yaw
	rotation.y = yaw
	velocity = Vector3.ZERO
	speed = 0.0


func can_act() -> bool:
	return state == State.WALK


# ------------------------------------------------------------------ física

func _physics_process(delta: float) -> void:
	if not visible:
		return
	match state:
		State.WALK:
			_walk(delta)
		State.DISMOUNT:
			_t += delta / DISMOUNT_TIME
			var e := smoothstep(0.0, 1.0, minf(_t, 1.0))
			var pos := _from.lerp(_to, e)
			pos.y += 0.12 * sin(PI * minf(_t, 1.0))
			global_position = pos
			var p := Humanoid.lerp_pose(_seated(), _stand(), e)
			p["foot_r"] = (p["foot_r"] as Vector3) + Vector3(0, 0.3 * sin(PI * minf(_t, 1.0)), 0)
			human.pose(p)
			if _t >= 1.0:
				state = State.WALK
		State.MOUNT:
			_t += delta / MOUNT_TIME
			var e := smoothstep(0.0, 1.0, minf(_t, 1.0))
			global_position = _from.lerp(_to, e) + Vector3(0, 0.1 * sin(PI * minf(_t, 1.0)), 0)
			yaw = lerp_angle(_yaw_from, _yaw_to, e)
			rotation.y = yaw
			var p := Humanoid.lerp_pose(_stand(), _seated(), e)
			p["foot_r"] = (p["foot_r"] as Vector3) + Vector3(0, 0.3 * sin(PI * minf(_t, 1.0)), 0)
			human.pose(p)
			if _t >= 1.0:
				mount_finished.emit()
		State.TUMBLE:
			_t += delta / TUMBLE_TIME
			_slide = _slide.move_toward(Vector3.ZERO, 7.0 * delta)
			_spin = lerpf(_spin, 0.0, 1.0 - exp(-3.0 * delta))
			yaw += _spin * delta
			rotation.y = yaw
			velocity.x = _slide.x
			velocity.z = _slide.z
			velocity.y -= GRAVITY * delta
			move_and_slide()
			var fall := smoothstep(0.0, 0.22, _t)
			human.pose(Humanoid.lerp_pose(_stand(), _lying(_t * TUMBLE_TIME), fall))
			if _t >= 1.0:
				state = State.GETUP
				_t = 0.0
		State.GETUP:
			_t += delta / GETUP_TIME
			velocity = Vector3(0, velocity.y - GRAVITY * delta, 0)
			move_and_slide()
			var p: Dictionary
			if _t < 0.5:
				p = Humanoid.lerp_pose(_lying(0.0), _kneel(), smoothstep(0.0, 1.0, _t * 2.0))
			else:
				p = Humanoid.lerp_pose(_kneel(), _stand(), smoothstep(0.0, 1.0, (_t - 0.5) * 2.0))
			human.pose(p)
			if _t >= 1.0:
				state = State.WALK
		State.LIFT:
			_t += delta / LIFT_TIME
			var go := smoothstep(0.0, 0.2, _t)
			global_position = _from.lerp(_to, go)
			yaw = lerp_angle(_yaw_from, _yaw_to, go)
			rotation.y = yaw
			var p: Dictionary
			if _t < 0.4:
				p = Humanoid.lerp_pose(_stand(), _squat(), smoothstep(0.0, 1.0, _t / 0.4))
			else:
				var u := smoothstep(0.0, 1.0, (_t - 0.4) / 0.6)
				p = Humanoid.lerp_pose(_squat(), _stand(), u)
				p["hand_l"] = Vector3(-0.2, lerpf(0.3, 0.95, u), -0.62)
				p["hand_r"] = Vector3(0.2, lerpf(0.3, 0.95, u), -0.62)
			lift_progress = smoothstep(0.35, 1.0, clampf(_t, 0.0, 1.0))
			human.pose(p)
			if _t >= 1.0:
				lift_progress = 1.0
				state = State.WALK
				lift_finished.emit()


func _walk(delta: float) -> void:
	var move := input_move
	if move.length() > 1.0:
		move = move.normalized()
	var wanted := 0.0
	if move.length() > 0.12:
		wanted = (RUN_SPEED if input_run else WALK_SPEED) * move.length()
		var wdir := Basis(Vector3.UP, view_yaw) * Vector3(move.x, 0.0, move.y)
		wdir.y = 0.0
		wdir = wdir.normalized()
		yaw = lerp_angle(yaw, atan2(-wdir.x, -wdir.z), 1.0 - exp(-10.0 * delta))
		rotation.y = yaw
		speed = move_toward(speed, wanted, 14.0 * delta)
		velocity.x = wdir.x * speed
		velocity.z = wdir.z * speed
	else:
		speed = move_toward(speed, 0.0, 16.0 * delta)
		var heading := Vector3(-sin(yaw), 0.0, -cos(yaw))
		velocity.x = heading.x * speed
		velocity.z = heading.z * speed
	velocity.y -= GRAVITY * delta
	move_and_slide()

	var run_blend := clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	var moving := clampf(speed / 1.2, 0.0, 1.0)
	_phase += speed * delta * (PI / lerpf(0.7, 1.15, run_blend))
	var step_index := int(floor(_phase / PI))
	if step_index != _last_step:
		_last_step = step_index
		if speed > 0.8:
			stepped.emit(run_blend > 0.5)
	var p := walk_pose(_phase, run_blend, moving)
	if moving < 0.2:
		p["chest"] = (p["chest"] as Vector3) + Vector3(0, 0.006 * sin(Time.get_ticks_msec() * 0.003), 0)
	human.pose(p)
