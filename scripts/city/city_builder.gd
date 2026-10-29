extends RefCounted
## Cidade procedural (Fase 3): grade de 3x3 cruzamentos, quarteirões com prédios,
## posto, oficina, garagem, área de treino e pontos de entrega. Tudo com colisão simples.
## Retorna um dicionário com ruas, pontos de interesse e ponto de partida.

const HALF := 100.0
const ROAD_W := 12.0
const ROADS := [-60.0, 0.0, 60.0]
const PALETTE := [
	Color(0.85, 0.78, 0.62), Color(0.62, 0.72, 0.85), Color(0.82, 0.58, 0.55),
	Color(0.66, 0.8, 0.66), Color(0.9, 0.86, 0.75), Color(0.7, 0.66, 0.8),
]

static var _win_tex: ImageTexture


static func build(root: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261028
	var pois: Array = []
	_environment(root)
	_ground_and_roads(root)
	_walls(root)
	_lamps(root)
	_blocks(root, rng, pois)
	var deliveries := [Vector3(-60, 0, -30), Vector3(60, 0, 30), Vector3(30, 0, 60), Vector3(-30, 0, -60)]
	for i in 4:
		_poi(root, pois, "entrega_%d" % (i + 1), "ENTREGA %d" % (i + 1), str(i + 1), deliveries[i], Color(1.0, 0.9, 0.2))
	return {
		"roads": ROADS,
		"half": HALF,
		"road_w": ROAD_W,
		"spawn": Vector3(3, 0.05, 40),
		"pois": pois,
	}


# ---------------------------------------------------------------- ambiente

static func _environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)


static func _ground_and_roads(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(HALF * 2.0, 2.0, HALF * 2.0)
	cs.shape = shape
	body.position = Vector3(0, -1, 0)
	body.add_child(cs)
	root.add_child(body)

	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF * 2.0, HALF * 2.0)
	_mesh(root, plane, Vector3.ZERO, _mat(Color(0.62, 0.62, 0.6)))

	var asphalt := _mat(Color(0.16, 0.16, 0.18))
	for r in ROADS:
		var rr: float = r
		_mesh(root, _box_mesh(Vector3(ROAD_W, 0.02, HALF * 2.0)), Vector3(rr, 0.01, 0.0), asphalt)
		_mesh(root, _box_mesh(Vector3(HALF * 2.0, 0.02, ROAD_W)), Vector3(0.0, 0.02, rr), asphalt)

	# Faixas tracejadas (MultiMesh: um único desenho por direção)
	var zt: Array[Transform3D] = []
	var xt: Array[Transform3D] = []
	for r in ROADS:
		var rr: float = r
		var c := -96.0
		while c <= 96.0:
			if not _near_road(c, 9.0):
				zt.append(Transform3D(Basis(), Vector3(rr, 0.045, c)))
				xt.append(Transform3D(Basis(), Vector3(c, 0.045, rr)))
			c += 6.0
	var dash_mat := _mat(Color(0.95, 0.8, 0.1))
	_multimesh(root, _box_mesh(Vector3(0.2, 0.01, 2.5)), zt, dash_mat)
	_multimesh(root, _box_mesh(Vector3(2.5, 0.01, 0.2)), xt, dash_mat)


static func _walls(root: Node3D) -> void:
	var mat := _mat(Color(0.6, 0.6, 0.62))
	_box_body(root, Vector3(0, 2, -HALF - 0.5), Vector3(HALF * 2 + 2, 4, 1), mat)
	_box_body(root, Vector3(0, 2, HALF + 0.5), Vector3(HALF * 2 + 2, 4, 1), mat)
	_box_body(root, Vector3(-HALF - 0.5, 2, 0), Vector3(1, 4, HALF * 2 + 2), mat)
	_box_body(root, Vector3(HALF + 0.5, 2, 0), Vector3(1, 4, HALF * 2 + 2), mat)


static func _lamps(root: Node3D) -> void:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.08
	pole.bottom_radius = 0.1
	pole.height = 5.0
	pole.radial_segments = 8
	var bulb := SphereMesh.new()
	bulb.radius = 0.25
	bulb.height = 0.5
	bulb.radial_segments = 8
	bulb.rings = 4
	var pole_mat := _mat(Color(0.25, 0.25, 0.28))
	var bulb_mat := _mat(Color(1.0, 0.95, 0.7))
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.95, 0.7)
	var shape := CylinderShape3D.new()
	shape.radius = 0.12
	shape.height = 5.0
	var alt := 1.0
	for r in ROADS:
		var rr: float = r
		var c := -90.0
		while c <= 90.0:
			if not _near_road(c, 12.0):
				for p in [Vector3(rr + 7.5 * alt, 2.5, c), Vector3(c, 2.5, rr - 7.5 * alt)]:
					var body := StaticBody3D.new()
					body.collision_layer = 8
					body.position = p
					var cs := CollisionShape3D.new()
					cs.shape = shape
					body.add_child(cs)
					_mesh(body, pole, Vector3.ZERO, pole_mat)
					_mesh(body, bulb, Vector3(0, 2.6, 0), bulb_mat)
					root.add_child(body)
				alt = -alt
			c += 24.0


# -------------------------------------------------------------- quarteirões

static func _blocks(root: Node3D, rng: RandomNumberGenerator, pois: Array) -> void:
	var xs := [[-100.0, -66.0], [-54.0, -6.0], [6.0, 54.0], [66.0, 100.0]]
	for ix in 4:
		for iz in 4:
			if ix == 1 and iz == 1:
				_training_area(root, pois)
			elif ix == 2 and iz == 1:
				_gas_station(root, pois)
			elif ix == 1 and iz == 2:
				_workshop_block(root, pois)
			elif ix == 2 and iz == 2:
				_garage_block(root, pois)
			else:
				var bx: Array = xs[ix]
				var bz: Array = xs[iz]
				_fill_block(root, rng, float(bx[0]), float(bx[1]), float(bz[0]), float(bz[1]))


static func _fill_block(root: Node3D, rng: RandomNumberGenerator, x0: float, x1: float, z0: float, z1: float) -> void:
	var nx := maxi(1, int((x1 - x0) / 24.0))
	var nz := maxi(1, int((z1 - z0) / 24.0))
	var lot_w := (x1 - x0) / nx
	var lot_d := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			var cx := x0 + lot_w * (i + 0.5)
			var cz := z0 + lot_d * (j + 0.5)
			var w := lot_w - rng.randf_range(5.0, 8.0)
			var d := lot_d - rng.randf_range(5.0, 8.0)
			var h := rng.randf_range(5.0, 20.0)
			_building(root, Vector3(cx, h * 0.5, cz), Vector3(w, h, d), rng.randi() % PALETTE.size())


static func _training_area(root: Node3D, pois: Array) -> void:
	# Slalom de cones e rampa (sobe em direção a -Z)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.25
	cone.height = 0.7
	cone.radial_segments = 10
	var cone_mat := _mat(Color(1.0, 0.45, 0.05))
	var shape := CylinderShape3D.new()
	shape.radius = 0.25
	shape.height = 0.7
	for i in 10:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		_mesh(body, cone, Vector3.ZERO, cone_mat)
		body.position = Vector3(-30.0 + (2.2 if i % 2 == 0 else -2.2), 0.35, -48.0 + i * 4.0)
		root.add_child(body)
	_box_body(root, Vector3(-15, 0.38, -30), Vector3(4, 0.3, 6), _mat(Color(0.5, 0.45, 0.4)), Vector3(deg_to_rad(10.0), 0, 0))
	_poi(root, pois, "treino", "TREINO", "T", Vector3(-22, 0, -30), Color(0.3, 1.0, 0.5))


static func _gas_station(root: Node3D, pois: Array) -> void:
	var steel := _mat(Color(0.75, 0.75, 0.78))
	_mesh(root, _box_mesh(Vector3(12, 0.4, 8)), Vector3(30, 5, -30), _mat(Color(0.9, 0.15, 0.1)))
	for sx in [-5.0, 5.0]:
		for sz in [-3.0, 3.0]:
			_box_body(root, Vector3(30.0 + sx, 2.5, -30.0 + sz), Vector3(0.5, 5, 0.5), steel)
	var pump_mat := _mat(Color(0.9, 0.9, 0.9))
	_box_body(root, Vector3(27, 0.7, -30), Vector3(0.6, 1.4, 0.6), pump_mat)
	_box_body(root, Vector3(33, 0.7, -30), Vector3(0.6, 1.4, 0.6), pump_mat)
	_building(root, Vector3(42, 2.5, -44), Vector3(8, 5, 6), 4)
	_poi(root, pois, "posto", "POSTO", "P", Vector3(30, 0, -22), Color(1.0, 0.3, 0.3))


static func _workshop_block(root: Node3D, pois: Array) -> void:
	_building(root, Vector3(-30, 4, 36), Vector3(18, 8, 14), 2)
	_building(root, Vector3(-30, 3, 14), Vector3(14, 6, 8), 4)
	_poi(root, pois, "oficina", "OFICINA", "O", Vector3(-12, 0, 36), Color(1.0, 0.6, 0.1))


static func _garage_block(root: Node3D, pois: Array) -> void:
	_building(root, Vector3(36, 3.5, 30), Vector3(16, 7, 14), 1)
	_mesh(root, _box_mesh(Vector3(0.2, 3.5, 6)), Vector3(27.95, 1.75, 30), _mat(Color(0.1, 0.1, 0.12)))
	_building(root, Vector3(30, 3, 50), Vector3(12, 6, 6), 3)
	_poi(root, pois, "garagem", "GARAGEM", "G", Vector3(18, 0, 30), Color(0.4, 0.7, 1.0))


# ------------------------------------------------------------------ helpers

static func _poi(root: Node3D, pois: Array, id: String, label: String, short: String, pos: Vector3, color: Color) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.2
	cyl.height = 0.1
	cyl.radial_segments = 24
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	_mesh(root, cyl, pos + Vector3(0, 0.06, 0), m)
	var l := Label3D.new()
	l.text = label
	l.font_size = 64
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 12
	l.position = pos + Vector3(0, 4.5, 0)
	root.add_child(l)
	pois.append({"id": id, "name": label, "short": short, "pos": pos, "color": color})


static func _building(root: Node3D, pos: Vector3, size: Vector3, color_idx: int) -> void:
	var mat := _mat(PALETTE[color_idx % PALETTE.size()])
	mat.albedo_texture = _window_texture()
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
	_box_body(root, pos, size, mat)


static func _window_texture() -> ImageTexture:
	if _win_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		img.fill(Color(0.92, 0.92, 0.92))
		for wx in [4, 18]:
			for y in range(6, 20):
				for x in range(wx, wx + 10):
					img.set_pixel(x, y, Color(0.25, 0.3, 0.42))
		_win_tex = ImageTexture.create_from_image(img)
	return _win_tex


static func _box_body(root: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	_mesh(body, _box_mesh(size), Vector3.ZERO, mat)
	root.add_child(body)
	return body


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


static func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _multimesh(root: Node3D, mesh: Mesh, xforms: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	root.add_child(mmi)


static func _near_road(c: float, margin: float) -> bool:
	for r in ROADS:
		if absf(c - float(r)) < margin:
			return true
	return false
