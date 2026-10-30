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
var _car_mats: Array = []
var _glass_mat: StandardMaterial3D
var _tire_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _tail_mat: StandardMaterial3D
var _chrome_mat: StandardMaterial3D
var _plate_mat: StandardMaterial3D
var _box_cache: Dictionary = {}
var _wheel_mesh: CylinderMesh
var _hub_mesh: CylinderMesh


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


func set_density(count: int) -> void:
	density = clampi(count, 0, MAX_CARS)
	while cars.size() > density:
		var last = cars.pop_back()
		last.queue_free()
	while cars.size() < density and not nodes.is_empty():
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
		# Chegou ao cruzamento: escolhe o próximo trecho e segue sem parar
		_next_edge(car)
		span = car.b - car.a
		length = span.length()
		dir = span / length
		t = (pos - car.a).dot(dir)

	# Direção: persegue um ponto à frente na faixa
	var target: Vector3 = car.a + dir * clampf(t + LOOK, 0.0, length)
	var to_target := target - pos
	var desired := atan2(-to_target.x, -to_target.z)
	var turn := absf(angle_difference(car.yaw, desired))
	car.yaw = lerp_angle(car.yaw, desired, 1.0 - exp(-4.0 * delta))
	var fwd := Vector3(-sin(car.yaw), 0.0, -cos(car.yaw))
	var right := Vector3(-fwd.z, 0.0, fwd.x)

	var target_speed := CRUISE
	if turn > 0.35:
		target_speed = 4.5   # reduz em curvas

	# Semáforo do próximo cruzamento
	var stopped_for_light := false
	var center: Vector3 = nodes[car.to_node]
	var dist_center := (center - pos).dot(dir)
	var stop_zone: float = car.speed * car.speed / 12.0 + 4.0
	var axis := 0 if absf(dir.x) > absf(dir.z) else 1
	if dist_center > STOP_LINE and dist_center < STOP_LINE + stop_zone and light_state(axis) != 0:
		target_speed = 0.0
		stopped_for_light = true

	# Obstáculo à frente (moto ou outro carro), por geometria simples
	var reach := 4.0 + car.speed * 1.2
	if _obstacle_ahead(car, pos, fwd, right, reach):
		target_speed = 0.0

	var rate := 14.0 if target_speed < car.speed else 5.0
	car.speed = move_toward(car.speed, target_speed, rate * delta)
	car.motion = fwd * car.speed
	car.position = pos + car.motion * delta
	car.rotation.y = car.yaw

	# Anti-travamento: carro parado sem motivo de semáforo por muito tempo é reposicionado
	if car.speed < 0.3 and not stopped_for_light:
		car.blocked_time += delta
		if car.blocked_time > 10.0:
			_place_car(car)
	else:
		car.blocked_time = 0.0


func _obstacle_ahead(car: TrafficCar, pos: Vector3, fwd: Vector3, right: Vector3, reach: float) -> bool:
	for other in cars:
		if other != car and _in_front(other.position, pos, fwd, right, reach):
			return true
	if player != null and _in_front(player.global_position, pos, fwd, right, reach):
		return true
	return false


static func _in_front(other: Vector3, pos: Vector3, fwd: Vector3, right: Vector3, reach: float) -> bool:
	var rel := other - pos
	rel.y = 0.0
	var ahead := rel.dot(fwd)
	if ahead < 1.0 or ahead > reach + 2.2:
		return false
	return absf(rel.dot(right)) < 2.0


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
	car.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.3, 4.2)
	cs.shape = shape
	cs.position = Vector3(0, 0.65, 0)
	car.add_child(cs)
	_add_visual(car, cars.size())
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
			car.speed = 3.0
			car.motion = Vector3.ZERO
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
	_wheel_mesh = CylinderMesh.new()
	_wheel_mesh.top_radius = 0.32
	_wheel_mesh.bottom_radius = 0.32
	_wheel_mesh.height = 0.25
	_wheel_mesh.radial_segments = 14
	_hub_mesh = CylinderMesh.new()
	_hub_mesh.top_radius = 0.17
	_hub_mesh.bottom_radius = 0.17
	_hub_mesh.height = 0.27
	_hub_mesh.radial_segments = 10
	for c in CAR_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.35
		m.metallic = 0.35
		_car_mats.append(m)
	_glass_mat = _plain(Color(0.1, 0.16, 0.24), 0.1)
	_tire_mat = _plain(Color(0.04, 0.04, 0.04), 0.95)
	_dark_mat = _plain(Color(0.08, 0.08, 0.09), 0.8)
	_chrome_mat = _plain(Color(0.75, 0.75, 0.8), 0.25)
	_chrome_mat.metallic = 0.9
	_plate_mat = _plain(Color(0.95, 0.95, 0.95), 0.6)
	_head_mat = _plain(Color(1.0, 0.97, 0.85), 0.3)
	_head_mat.emission_enabled = true
	_head_mat.emission = Color(1.0, 0.97, 0.85)
	_tail_mat = _plain(Color(0.9, 0.05, 0.05), 0.4)
	_tail_mat.emission_enabled = true
	_tail_mat.emission = Color(0.9, 0.05, 0.05)


func _plain(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var key := str(size)
	if not _box_cache.has(key):
		var b := BoxMesh.new()
		b.size = size
		_box_cache[key] = b
	return _mesh(parent, _box_cache[key], pos, mat)


func _add_visual(car: Node3D, idx: int) -> void:
	var body_mat: StandardMaterial3D = _car_mats[idx % _car_mats.size()]
	var style := (idx / 2) % 3   # 0 sedã, 1 hatch, 2 van
	_part(car, Vector3(1.8, 0.55, 4.2), Vector3(0, 0.55, 0), body_mat)
	match style:
		0:
			_part(car, Vector3(1.64, 0.4, 1.9), Vector3(0, 1.07, 0.25), _glass_mat)
			_part(car, Vector3(1.6, 0.07, 2.0), Vector3(0, 1.3, 0.25), body_mat)
			_part(car, Vector3(1.78, 0.08, 0.9), Vector3(0, 0.84, -1.45), body_mat)
		1:
			_part(car, Vector3(1.64, 0.42, 2.3), Vector3(0, 1.08, 0.55), _glass_mat)
			_part(car, Vector3(1.6, 0.07, 2.4), Vector3(0, 1.32, 0.55), body_mat)
			_part(car, Vector3(1.78, 0.08, 0.8), Vector3(0, 0.84, -1.5), body_mat)
		_:
			_part(car, Vector3(1.8, 1.15, 2.9), Vector3(0, 1.2, 0.6), body_mat)
			_part(car, Vector3(1.7, 0.45, 0.05), Vector3(0, 1.45, -0.87), _glass_mat)
			_part(car, Vector3(1.82, 0.3, 1.2), Vector3(0, 1.5, 0.0), _glass_mat)
	_part(car, Vector3(1.86, 0.2, 0.15), Vector3(0, 0.32, -2.12), _dark_mat)
	_part(car, Vector3(1.86, 0.2, 0.15), Vector3(0, 0.32, 2.12), _dark_mat)
	for sx in [-0.62, 0.62]:
		_part(car, Vector3(0.38, 0.13, 0.05), Vector3(sx, 0.66, -2.11), _head_mat)
		_part(car, Vector3(0.3, 0.1, 0.05), Vector3(sx * 1.05, 0.68, 2.11), _tail_mat)
		_part(car, Vector3(0.12, 0.1, 0.07), Vector3(sx * 1.6, 1.0, -0.7), body_mat)
	_part(car, Vector3(0.4, 0.12, 0.02), Vector3(0, 0.4, -2.2), _plate_mat)
	_part(car, Vector3(0.4, 0.12, 0.02), Vector3(0, 0.55, 2.2), _plate_mat)
	_part(car, Vector3(1.2, 0.05, 0.03), Vector3(0, 0.62, -2.12), _chrome_mat)
	for sx in [-0.9, 0.9]:
		for sz in [-1.35, 1.35]:
			var w := _mesh(car, _wheel_mesh, Vector3(sx, 0.32, sz), _tire_mat)
			w.rotation = Vector3(0, 0, PI / 2.0)
			var hub := _mesh(car, _hub_mesh, Vector3(sx, 0.32, sz), _chrome_mat)
			hub.rotation = Vector3(0, 0, PI / 2.0)


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
