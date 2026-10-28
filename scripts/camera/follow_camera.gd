extends Node3D
## Câmera em terceira pessoa: segue suavemente, órbita 360° por gesto,
## zoom por pinça e prevenção de atravessar paredes (raycast).

const MIN_DISTANCE := 2.5
const MAX_DISTANCE := 9.0
const DEFAULT_DISTANCE := 4.6
const DEFAULT_PITCH := 18.0

var target: Node3D
var camera: Camera3D
var distance: float = DEFAULT_DISTANCE
var pitch_deg: float = DEFAULT_PITCH
var yaw_offset: float = 0.0
var orbit_sensitivity: float = 0.35  # graus por pixel

var _yaw: float = 0.0
var _focus: Vector3 = Vector3.ZERO
var _cam_pos: Vector3 = Vector3.ZERO
var _first: bool = true


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 300.0
	add_child(camera)
	camera.current = true


func snap() -> void:
	_first = true


func orbit(relative: Vector2) -> void:
	yaw_offset -= deg_to_rad(relative.x * orbit_sensitivity)
	yaw_offset = wrapf(yaw_offset, -PI, PI)
	pitch_deg = clampf(pitch_deg + relative.y * orbit_sensitivity, 5.0, 60.0)


func zoom(pixels: float) -> void:
	distance = clampf(distance + pixels * 0.01, MIN_DISTANCE, MAX_DISTANCE)


func reset_view() -> void:
	yaw_offset = 0.0
	pitch_deg = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE


func _physics_process(delta: float) -> void:
	if target == null or camera == null:
		return
	var target_yaw := target.global_rotation.y
	var focus_goal := target.global_position + Vector3(0.0, 1.1, 0.0)
	if _first:
		_yaw = target_yaw
		_focus = focus_goal
	else:
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-3.0 * delta))
		_focus = _focus.lerp(focus_goal, 1.0 - exp(-12.0 * delta))

	var total_yaw := _yaw + yaw_offset
	var p := deg_to_rad(pitch_deg)
	var offset := Vector3(sin(total_yaw) * cos(p), sin(p), cos(total_yaw) * cos(p)) * distance
	var desired := _focus + offset

	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(_focus, desired, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		if _first:
			_cam_pos = desired
		else:
			_cam_pos = _cam_pos.lerp(desired, 1.0 - exp(-14.0 * delta))
	else:
		var hp: Vector3 = hit["position"]
		_cam_pos = hp + (_focus - hp).normalized() * 0.2
	_first = false

	camera.global_position = _cam_pos
	if not _cam_pos.is_equal_approx(_focus):
		camera.look_at(_focus, Vector3.UP)
