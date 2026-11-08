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
var first_person: bool = false
var showroom: bool = false
var head_node: Node3D           # 1ª pessoa: nó da cabeça que a câmera acompanha
var fp_roll: float = 0.0        # inclinação lateral na 1ª pessoa (curvas)
var free_orbit: bool = false   # a pé: a câmera não gira sozinha com o personagem
var showroom_distance: float = 3.6
var view_pitch: float = 0.0  # inclinação da moto (grau/stoppie), usada na 1ª pessoa

var _yaw: float = 0.0
var _focus: Vector3 = Vector3.ZERO
var _cam_pos: Vector3 = Vector3.ZERO
var _first: bool = true
var _show_yaw: float = 0.6
var _saved_distance: float = DEFAULT_DISTANCE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = 300.0
	camera.near = 0.05
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


func begin_foot(who: Node3D) -> void:
	if not free_orbit:
		_saved_distance = distance
	free_orbit = true
	yaw_offset = who.global_rotation.y
	distance = minf(distance, 4.2)
	_first = true


func end_foot() -> void:
	if free_orbit:
		distance = _saved_distance
	free_orbit = false
	yaw_offset = 0.0
	_first = true


## Direção para onde a câmera olha (usada para andar relativo à câmera).
func get_view_yaw() -> float:
	return (0.0 if free_orbit else _yaw) + yaw_offset


func toggle_view() -> void:
	first_person = not first_person
	_first = true


func reset_view() -> void:
	yaw_offset = 0.0
	pitch_deg = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE


func _physics_process(delta: float) -> void:
	if target == null or camera == null:
		return
	if showroom:
		_update_showroom(delta)
		return
	if first_person:
		_update_first_person()
		return
	var target_yaw := target.global_rotation.y
	var focus_goal := target.global_position + Vector3(0.0, 1.1, 0.0)
	if _first:
		_yaw = target_yaw
		_focus = focus_goal
	else:
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-3.0 * delta))
		_focus = _focus.lerp(focus_goal, 1.0 - exp(-12.0 * delta))

	if free_orbit:
		_yaw = 0.0
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


func _update_first_person() -> void:
	var head: Vector3
	if is_instance_valid(head_node):
		head = head_node.global_position      # cabeça real do personagem: inclina, balança e gira com ele
	else:
		head = target.global_position + Vector3(0.0, 1.68, 0.0)
	var yaw: float
	if free_orbit:
		yaw = yaw_offset                      # a pé: o jogador olha para onde girar a câmera
	else:
		yaw = target.global_rotation.y + clampf(yaw_offset, -1.6, 1.6)
	var look_pitch := deg_to_rad(clampf((pitch_deg - DEFAULT_PITCH) * 0.5, -35.0, 45.0))
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, view_pitch * 0.7 - look_pitch) * Basis(Vector3.FORWARD, fp_roll)
	camera.global_transform = Transform3D(b, head + b * Vector3(0.0, 0.03, -0.12))


func _update_showroom(delta: float) -> void:
	_show_yaw += delta * 0.45
	var focus: Vector3 = target.global_transform * Vector3(0.0, 0.7, -0.65)
	var total_yaw := target.global_rotation.y + _show_yaw + yaw_offset
	var p := deg_to_rad(12.0)
	var offset := Vector3(sin(total_yaw) * cos(p), sin(p), cos(total_yaw) * cos(p)) * showroom_distance
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)
	_first = true
