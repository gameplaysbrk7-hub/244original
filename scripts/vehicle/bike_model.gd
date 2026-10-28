extends RefCounted
## Constrói a moto e o piloto proceduralmente (sem arquivos externos).
## Origem = contato da roda traseira com o solo; frente = -Z.

static func build(body_color: Color) -> Dictionary:
	var root := Node3D.new()
	var body_mat := _mat(body_color, 0.45, 0.2)
	var dark := _mat(Color(0.08, 0.08, 0.09), 0.8)
	var metal := _mat(Color(0.6, 0.6, 0.65), 0.35, 0.8)
	var tire_mat := _mat(Color(0.03, 0.03, 0.03), 0.95)
	var jacket := _mat(Color(0.1, 0.3, 0.75), 0.8)
	var pants := _mat(Color(0.12, 0.12, 0.16), 0.9)
	var helmet := _mat(Color(0.95, 0.95, 0.95), 0.3)
	var tail := _mat(Color(0.9, 0.05, 0.05), 0.5)
	tail.emission_enabled = true
	tail.emission = Color(0.9, 0.05, 0.05)
	var lamp := _mat(Color(1.0, 0.95, 0.7), 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.95, 0.7)

	var rear_wheel := _wheel(root, Vector3(0, 0.33, 0), tire_mat, metal)

	_add(root, _box(Vector3(0.12, 0.08, 0.75)), Vector3(0, 0.36, -0.37), dark)
	_add(root, _box(Vector3(0.16, 0.22, 0.9)), Vector3(0, 0.62, -0.62), dark)
	_add(root, _box(Vector3(0.3, 0.3, 0.4)), Vector3(0, 0.5, -0.6), metal)
	_add(root, _box(Vector3(0.28, 0.24, 0.5)), Vector3(0, 0.88, -0.65), body_mat)
	_add(root, _box(Vector3(0.26, 0.1, 0.6)), Vector3(0, 0.82, -0.1), dark)
	_add(root, _box(Vector3(0.2, 0.08, 0.4)), Vector3(0, 0.78, 0.3), body_mat)
	_add(root, _box(Vector3(0.14, 0.06, 0.06)), Vector3(0, 0.8, 0.52), tail)
	var exhaust := CylinderMesh.new()
	exhaust.top_radius = 0.05
	exhaust.bottom_radius = 0.05
	exhaust.height = 0.8
	exhaust.radial_segments = 10
	_add(root, exhaust, Vector3(0.2, 0.38, -0.1), metal, Vector3(PI / 2.0, 0, 0))

	# Garfo + guidão + roda dianteira (gira em Y para esterçar)
	var fork := Node3D.new()
	fork.position = Vector3(0, 0.95, -1.05)
	root.add_child(fork)
	_limb(fork, Vector3(0.08, 0, 0), Vector3(0.08, -0.62, -0.25), 0.025, metal)
	_limb(fork, Vector3(-0.08, 0, 0), Vector3(-0.08, -0.62, -0.25), 0.025, metal)
	_add(fork, _box(Vector3(0.7, 0.04, 0.04)), Vector3(0, 0.12, 0.05), dark)
	var sph := SphereMesh.new()
	sph.radius = 0.1
	sph.height = 0.2
	sph.radial_segments = 12
	sph.rings = 6
	_add(fork, sph, Vector3(0, 0.0, -0.17), lamp)
	_add(fork, _box(Vector3(0.16, 0.04, 0.45)), Vector3(0, -0.24, -0.25), body_mat)
	var front_wheel := _wheel(fork, Vector3(0, -0.62, -0.25), tire_mat, metal)

	# Piloto simplificado
	_limb(root, Vector3(0, 0.95, -0.15), Vector3(0, 1.42, -0.45), 0.16, jacket)
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.28
	head.radial_segments = 12
	head.rings = 6
	_add(root, head, Vector3(0, 1.62, -0.5), helmet)
	_add(root, _box(Vector3(0.2, 0.07, 0.08)), Vector3(0, 1.63, -0.62), dark)
	for s in [-1.0, 1.0]:
		_limb(root, Vector3(0.2 * s, 1.38, -0.45), Vector3(0.3 * s, 1.2, -0.7), 0.05, jacket)
		_limb(root, Vector3(0.3 * s, 1.2, -0.7), Vector3(0.3 * s, 1.1, -0.98), 0.045, jacket)
		_limb(root, Vector3(0.13 * s, 0.92, -0.15), Vector3(0.27 * s, 0.8, -0.6), 0.07, pants)
		_limb(root, Vector3(0.27 * s, 0.8, -0.6), Vector3(0.22 * s, 0.42, -0.45), 0.06, pants)

	return {"root": root, "fork": fork, "front_wheel": front_wheel, "rear_wheel": rear_wheel}


static func _mat(color: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var d := b - a
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = d.length()
	cm.radial_segments = 8
	cm.rings = 1
	var mi := _add(parent, cm, (a + b) * 0.5, mat)
	mi.quaternion = Quaternion(Vector3.UP, d.normalized())


static func _wheel(parent: Node3D, pos: Vector3, tire_mat: Material, rim_mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var tire := CylinderMesh.new()
	tire.top_radius = 0.33
	tire.bottom_radius = 0.33
	tire.height = 0.16
	tire.radial_segments = 20
	tire.rings = 1
	_add(pivot, tire, Vector3.ZERO, tire_mat, Vector3(0, 0, PI / 2.0))
	var rim := CylinderMesh.new()
	rim.top_radius = 0.22
	rim.bottom_radius = 0.22
	rim.height = 0.18
	rim.radial_segments = 16
	rim.rings = 1
	_add(pivot, rim, Vector3.ZERO, rim_mat, Vector3(0, 0, PI / 2.0))
	# "Raio" para a rotação ser visível
	_add(pivot, _box(Vector3(0.19, 0.46, 0.05)), Vector3.ZERO, rim_mat)
	return pivot
