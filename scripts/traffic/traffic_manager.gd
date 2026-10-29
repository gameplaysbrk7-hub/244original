extends Node3D
## Trânsito simplificado: carros seguem faixas entre cruzamentos (mão direita),
## respeitam semáforos, freiam diante de obstáculos (moto ou outros carros) e
## escolhem o próximo trecho aleatoriamente. Carros distantes ficam congelados e ocultos.

const TrafficCar := preload("res://scripts/traffic/traffic_car.gd")

const LANE := 3.2
const LOOK := 6.0
const CRUISE := 9.0
const STOP_LINE := 8.0
const CYCLE := 20.0
const ACTIVE_RANGE := 110.0
const MAX_CARS := 30
const LIGHT_COLORS := [Color(0.1, 1.0, 0.2), Color(1.0, 0.85, 0.1), Color(1.0, 0.1, 0.1)]
const CAR_COLORS := [
	Color(0.8, 0.8, 0.82), Color(0.15, 0.15, 0.18), Color(0.7, 0.1, 0.1),
	Color(0.15, 0.3, 0.7), Color(0.9, 0.75, 0.1), Color(0.2, 0.5, 0.3),
]

var density: int = 10
var player: Node3D
var cars: Array = []
var time: float = 0.0
var nodes: Array = []
var _neighbors: Array = []
var _rng := RandomNumberGenerator.new()
var _lamps: Array = []
var _lamp_state: Array = [-1, -1]
var _body_mesh: BoxMesh
var _cabin_mesh: BoxMesh
var _wheel_mesh: CylinderMesh
var _car_mats: Array = []
var _glass_mat: StandardMaterial3D
var _tire_mat: StandardMaterial3D


func setup(roads: Array, player_node: Node3D, car_count: int) -> void:
	player = player_node
	density = clampi(car_count, 0, MAX_CARS)
	_rng.seed = 424242
	var n := roads.size()
	for i in n:
		for j in n:
			nodes.append(Vector3(float(roads[i]), 0.0, float(roads[j])))
	for i in n:
		for j in n:
			var nb: Array = []
			if i > 0:
				nb.append((i - 1) * n + j)
			if i < n - 1:
				nb.append((i + 1) * n + j)
			if j > 0:
				nb.append(i * n + j - 1)
			if j < n - 1:
				nb.append(i * n + j + 1)
			_neighbors.append(nb)
	_build_assets()
	_build_signals()
	_apply_lights()
	for k in density:
		_spawn_car()


func light_state(axis: int) -> int:
	var t := fmod(time, CYCLE)
	if axis == 0:
		if t < 8.0:
			return 0
		if t < 10.0:
			return 1
		return 2
	if t < 10.0:
		return 2
	if t < 18.0:
		return 0
	if t < 20.0:
		return 1
	return 2


func _physics_process(delta: float) -> void:
	time += delta
	_apply_lights()
	for car in cars:
		var near: bool = player == null or car.position.distance_to(player.global_position) < ACTIVE_RANGE
		car.visible = near
		if near:
			_step_car(car, delta)


# ------------------------------------------------------------------ carros

func _step_car(car: TrafficCar, delta: float) -> void:
	var pos: Vector3 = car.position
	var span: Vector3 = car.b - car.a
	var length := span.length()
	var dir := span / length
	var t := (pos - car.a).dot(dir)
	if t >= length - 4.0:
		_next_edge(car)
		return

	var target: Vector3 = car.a + dir * clampf(t + LOOK, 0.0, length)
	var to_target := target - pos
	var desired := atan2(-to_target.x, -to_target.z)
	car.yaw = lerp_angle(car.yaw, desired, 1.0 - exp(-4.0 * delta))
	var fwd := Vector3(-sin(car.yaw), 0.0, -cos(car.yaw))

	var target_speed := CRUISE
	# Semáforo do próximo cruzamento
	var center: Vector3 = nodes[car.to_node]
	var dist_center := (center - pos).dot(dir)
	var stop_zone: float = car.speed * car.speed / 12.0 + 4.0
	var axis := 0 if absf(dir.x) > absf(dir.z) else 1
	if dist_center > STOP_LINE and dist_center < STOP_LINE + stop_zone and light_state(axis) != 0:
		target_speed = 0.0
	# Obstáculo à frente (moto ou outro carro)
	var reach := 3.0 + car.speed * 1.0
	var origin := pos + Vector3(0, 0.6, 0) + fwd * 2.4
	var exclude: Array[RID] = [car.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(origin, origin + fwd * reach, 2 | 4, exclude)
	var blocked := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if blocked:
		target_speed = 0.0
	if blocked and car.speed < 0.3:
		car.blocked_time += delta
		if car.blocked_time > 12.0:
			_place_car(car)
			return
	else:
		car.blocked_time = 0.0

	var rate := 14.0 if target_speed < car.speed else 5.0
	car.speed = move_toward(car.speed, target_speed, rate * delta)
	car.position = pos + fwd * car.speed * delta
	car.rotation.y = car.yaw


func _next_edge(car: TrafficCar) -> void:
	var options: Array = []
	for nb in _neighbors[car.to_node]:
		if nb != car.from_node:
			options.append(nb)
	if options.is_empty():
		options = _neighbors[car.to_node]
	var next: int = options[_rng.randi() % options.size()]
	_set_edge(car, car.to_node, next)


func _set_edge(car: TrafficCar, from_idx: int, to_idx: int) -> void:
	var d: Vector3 = (nodes[to_idx] - nodes[from_idx]).normalized()
	var right := Vector3(-d.z, 0.0, d.x)
	car.a = nodes[from_idx] + right * LANE
	car.b = nodes[to_idx] + right * LANE
	car.from_node = from_idx
	car.to_node = to_idx


func _spawn_car() -> void:
	var car := TrafficCar.new()
	car.collision_layer = 4
	car.collision_mask = 0
	car.sync_to_physics = true
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.3, 4.2)
	cs.shape = shape
	cs.position = Vector3(0, 0.65, 0)
	car.add_child(cs)
	_add_visual(car, cars.size() % CAR_COLORS.size())
	_place_car(car)
	add_child(car)
	cars.append(car)


func _place_car(car: TrafficCar) -> void:
	for attempt in 12:
		var from_idx := _rng.randi() % nodes.size()
		var nb: Array = _neighbors[from_idx]
		var to_idx: int = nb[_rng.randi() % nb.size()]
		_set_edge(car, from_idx, to_idx)
		var span: Vector3 = car.b - car.a
		var length := span.length()
		var dir := span / length
		var p: Vector3 = car.a + dir * _rng.randf_range(12.0, length - 14.0)
		if _free_spot(car, p) or attempt == 11:
			car.position = p
			car.yaw = atan2(-dir.x, -dir.z)
			car.rotation.y = car.yaw
			car.speed = 0.0
			car.blocked_time = 0.0
			return


func _free_spot(car: TrafficCar, p: Vector3) -> bool:
	for other in cars:
		if other != car and other.position.distance_to(p) < 9.0:
			return false
	if player != null and player.global_position.distance_to(p) < 12.0:
		return false
	return true


# ------------------------------------------------------------ visual/semáforos

func _build_assets() -> void:
	_body_mesh = BoxMesh.new()
	_body_mesh.size = Vector3(1.8, 0.7, 4.2)
	_cabin_mesh = BoxMesh.new()
	_cabin_mesh.size = Vector3(1.6, 0.6, 2.0)
	_wheel_mesh = CylinderMesh.new()
	_wheel_mesh.top_radius = 0.32
	_wheel_mesh.bottom_radius = 0.32
	_wheel_mesh.height = 0.25
	_wheel_mesh.radial_segments = 12
	for c in CAR_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.5
		m.metallic = 0.3
		_car_mats.append(m)
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.1, 0.15, 0.25)
	_tire_mat = StandardMaterial3D.new()
	_tire_mat.albedo_color = Color(0.04, 0.04, 0.04)


func _add_visual(car: Node3D, color_idx: int) -> void:
	_mesh(car, _body_mesh, Vector3(0, 0.55, 0), _car_mats[color_idx])
	_mesh(car, _cabin_mesh, Vector3(0, 1.2, 0.3), _glass_mat)
	for sx in [-0.9, 0.9]:
		for sz in [-1.4, 1.4]:
			var w := _mesh(car, _wheel_mesh, Vector3(sx, 0.32, sz), _tire_mat)
			w.rotation = Vector3(0, 0, PI / 2.0)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_signals() -> void:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.1
	pole.height = 4.2
	pole.radial_segments = 8
	var lamp := SphereMesh.new()
	lamp.radius = 0.28
	lamp.height = 0.56
	lamp.radial_segments = 8
	lamp.rings = 4
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.2, 0.22)
	var shape := CylinderShape3D.new()
	shape.radius = 0.12
	shape.height = 4.2
	for center in nodes:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var body := StaticBody3D.new()
				body.collision_layer = 8
				body.position = Vector3(center.x + sx * 7.5, 2.1, center.z + sz * 7.5)
				var cs := CollisionShape3D.new()
				cs.shape = shape
				body.add_child(cs)
				_mesh(body, pole, Vector3.ZERO, pole_mat)
				var lamp_mat := StandardMaterial3D.new()
				lamp_mat.emission_enabled = true
				_mesh(body, lamp, Vector3(0, 2.3, 0), lamp_mat)
				_lamps.append({"mat": lamp_mat, "axis": 0 if sx * sz > 0.0 else 1})
				add_child(body)


func _apply_lights() -> void:
	var st: Array = [light_state(0), light_state(1)]
	if st == _lamp_state:
		return
	_lamp_state = st
	for l in _lamps:
		var mat: StandardMaterial3D = l["mat"]
		var c: Color = LIGHT_COLORS[st[l["axis"]]]
		mat.albedo_color = c
		mat.emission = c
