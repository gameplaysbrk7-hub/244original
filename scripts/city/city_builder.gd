extends RefCounted
## Cidade procedural (Fase 4 gráfica): 3x3 cruzamentos, texturas geradas por código,
## prédios com lojas, toldos, letreiros e caixas d'água, casas com telhado e muros,
## árvores, postes, faixas e faixas de pedestre, horizonte com montanhas e névoa.
## Retorna um dicionário com ruas, pontos de interesse e ponto de partida.

const HALF := 100.0
const ROAD_W := 12.0
const ROADS := [-60.0, 0.0, 60.0]
const BLOCKS := [[-100.0, -66.0], [-54.0, -6.0], [6.0, 54.0], [66.0, 100.0]]
const PALETTE := [
	Color(0.9, 0.82, 0.64), Color(0.66, 0.76, 0.9), Color(0.88, 0.62, 0.58),
	Color(0.7, 0.84, 0.7), Color(0.94, 0.9, 0.78), Color(0.76, 0.7, 0.86),
]
const AWNINGS := [Color(0.8, 0.1, 0.1), Color(0.1, 0.4, 0.8), Color(0.1, 0.6, 0.3), Color(0.92, 0.7, 0.1)]
const SHOPS := ["MERCADO", "PADARIA", "FARMÁCIA", "LANCHONETE", "LOJA", "BAR"]

static var _tex_cache: Dictionary = {}
static var _lit: Array = []   # materiais que acendem à noite (janelas, vitrines)


static func build(root: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261028
	var pois: Array = []
	_lit = []
	var env_info := _environment(root)
	_horizon(root)
	_ground_and_roads(root)
	_road_markings(root)
	_walls(root)
	var lamps := _lamps(root)
	_trees(root, rng)
	_blocks(root, rng, pois)
	return {
		"roads": ROADS,
		"half": HALF,
		"road_w": ROAD_W,
		"spawn": Vector3(3, 0.05, 40),
		"pois": pois,
		"env": env_info["env"],
		"sky": env_info["sky"],
		"sun": env_info["sun"],
		"lit_materials": _lit.duplicate(),
		"lamps": lamps,
	}


# ---------------------------------------------------------------- ambiente

static func _environment(root: Node3D) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.44, 0.82)
	sky_mat.sky_horizon_color = Color(0.74, 0.84, 0.94)
	sky_mat.ground_horizon_color = Color(0.74, 0.82, 0.88)
	sky_mat.ground_bottom_color = Color(0.4, 0.46, 0.46)
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.83, 0.92)
	env.fog_density = 0.0032
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(sun)
	return {"env": env, "sky": sky_mat, "sun": sun}


static func _horizon(root: Node3D) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 70.0
	cone.height = 50.0
	cone.radial_segments = 7
	cone.rings = 1
	var far_mat := _mat(Color(0.32, 0.45, 0.4))
	var near_mat := _mat(Color(0.25, 0.4, 0.3))
	for i in 18:
		var a := TAU * i / 18.0
		var r := 215.0 + (i % 3) * 18.0
		var h := 0.8 + (i % 4) * 0.25
		var mi := _mesh(root, cone, Vector3(cos(a) * r, 25.0 * h - 3.0, sin(a) * r), far_mat if i % 2 == 0 else near_mat)
		mi.scale = Vector3(1.0, h, 1.0)


# ------------------------------------------------------------- chão e ruas

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
	_mesh(root, plane, Vector3.ZERO, _tex_mat("concrete", Color.WHITE, 0.25))

	var asphalt := _tex_mat("asphalt", Color.WHITE, 0.5)
	for r in ROADS:
		var rr: float = r
		_mesh(root, _box_mesh(Vector3(ROAD_W, 0.02, HALF * 2.0)), Vector3(rr, 0.01, 0.0), asphalt)
		_mesh(root, _box_mesh(Vector3(HALF * 2.0, 0.02, ROAD_W)), Vector3(0.0, 0.02, rr), asphalt)


static func _road_markings(root: Node3D) -> void:
	var yellow := _mat(Color(0.95, 0.8, 0.1))
	var white := _mat(Color(0.93, 0.93, 0.93))
	# Tracejado central
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
	_multimesh(root, _box_mesh(Vector3(0.2, 0.01, 2.5)), zt, yellow, null)
	_multimesh(root, _box_mesh(Vector3(2.5, 0.01, 0.2)), xt, yellow, null)
	# Linhas laterais contínuas entre cruzamentos
	for r in ROADS:
		var rr: float = r
		for b in BLOCKS:
			var c0: float = b[0]
			var c1: float = b[1]
			var length := c1 - c0
			var mid := (c0 + c1) * 0.5
			for side in [-5.6, 5.6]:
				_mesh(root, _box_mesh(Vector3(0.14, 0.01, length)), Vector3(rr + side, 0.045, mid), white)
				_mesh(root, _box_mesh(Vector3(length, 0.01, 0.14)), Vector3(mid, 0.055, rr + side), white)
	# Faixas de pedestre nos quatro lados de cada cruzamento
	var cz: Array[Transform3D] = []
	var cx: Array[Transform3D] = []
	for ra in ROADS:
		for rb in ROADS:
			var ax: float = ra
			var az: float = rb
			var k := -4.8
			while k <= 4.81:
				for side in [-8.4, 8.4]:
					cz.append(Transform3D(Basis(), Vector3(ax + k, 0.05, az + side)))
					cx.append(Transform3D(Basis(), Vector3(ax + side, 0.06, az + k)))
				k += 1.2
	_multimesh(root, _box_mesh(Vector3(0.6, 0.01, 3.0)), cz, white, null)
	_multimesh(root, _box_mesh(Vector3(3.0, 0.01, 0.6)), cx, white, null)


static func _walls(root: Node3D) -> void:
	var mat := _tex_mat("concrete", Color(0.85, 0.85, 0.88), 0.25)
	_box_body(root, Vector3(0, 2, -HALF - 0.5), Vector3(HALF * 2 + 2, 4, 1), mat)
	_box_body(root, Vector3(0, 2, HALF + 0.5), Vector3(HALF * 2 + 2, 4, 1), mat)
	_box_body(root, Vector3(-HALF - 0.5, 2, 0), Vector3(1, 4, HALF * 2 + 2), mat)
	_box_body(root, Vector3(HALF + 0.5, 2, 0), Vector3(1, 4, HALF * 2 + 2), mat)


static func _lamps(root: Node3D) -> Array:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.1
	pole.height = 5.0
	pole.radial_segments = 8
	var arm := _box_mesh(Vector3(0.9, 0.08, 0.08))
	var bulb := SphereMesh.new()
	bulb.radius = 0.22
	bulb.height = 0.36
	bulb.radial_segments = 8
	bulb.rings = 4
	var pole_mat := _mat(Color(0.28, 0.3, 0.33))
	var bulb_mat := _mat(Color(1.0, 0.95, 0.7))
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.95, 0.7)
	var shape := CylinderShape3D.new()
	shape.radius = 0.12
	shape.height = 5.0
	var out: Array = []
	var alt := 1.0
	for r in ROADS:
		var rr: float = r
		var c := -90.0
		while c <= 90.0:
			if not _near_road(c, 12.0):
				# [posição do poste, direção para o centro da rua]
				var specs := [
					[Vector3(rr + 7.5 * alt, 2.5, c), Vector3(-alt, 0.0, 0.0)],
					[Vector3(c, 2.5, rr - 7.5 * alt), Vector3(0.0, 0.0, alt)],
				]
				for sp in specs:
					var p: Vector3 = sp[0]
					var toward: Vector3 = sp[1]
					var body := StaticBody3D.new()
					body.collision_layer = 8
					body.position = p
					var cs := CollisionShape3D.new()
					cs.shape = shape
					body.add_child(cs)
					_mesh(body, pole, Vector3.ZERO, pole_mat)
					var arm_mi := _mesh(body, arm, toward * 0.4 + Vector3(0, 2.45, 0), pole_mat)
					if absf(toward.z) > 0.5:
						arm_mi.rotation.y = PI / 2.0
					_mesh(body, bulb, toward * 0.8 + Vector3(0, 2.35, 0), bulb_mat)
					out.append(p + toward * 0.8 + Vector3(0, 2.35, 0))
					root.add_child(body)
				alt = -alt
			c += 24.0
	return out


static func _trees(root: Node3D, rng: RandomNumberGenerator) -> void:
	var trunk_t: Array[Transform3D] = []
	var leaf_t: Array[Transform3D] = []
	var leaf_c: Array[Color] = []
	var shape := CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = 3.0
	var greens := [Color(0.18, 0.5, 0.2), Color(0.25, 0.58, 0.22), Color(0.14, 0.42, 0.24), Color(0.3, 0.55, 0.15)]
	for r in ROADS:
		var rr: float = r
		var c := -78.0
		while c <= 78.0:
			if not _near_road(c, 12.0):
				for side in [-7.2, 7.2]:
					for pos in [Vector3(rr + side, 0.0, c), Vector3(c, 0.0, rr + side)]:
						var body := StaticBody3D.new()
						body.collision_layer = 8
						body.position = pos + Vector3(0, 1.5, 0)
						var cs := CollisionShape3D.new()
						cs.shape = shape
						body.add_child(cs)
						root.add_child(body)
						var s := rng.randf_range(0.85, 1.25)
						trunk_t.append(Transform3D(Basis.from_scale(Vector3(1, s, 1)), pos + Vector3(0, 1.3 * s, 0)))
						var col: Color = greens[rng.randi() % greens.size()]
						leaf_t.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), pos + Vector3(0, 3.5 * s, 0)))
						leaf_c.append(col)
						leaf_t.append(Transform3D(Basis.from_scale(Vector3(s * 0.7, s * 0.7, s * 0.7)), pos + Vector3(0.6 * s, 4.5 * s, 0.3 * s)))
						leaf_c.append(col.lightened(0.1))
			c += 24.0
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.24
	trunk.height = 2.6
	trunk.radial_segments = 7
	_multimesh(root, trunk, trunk_t, _mat(Color(0.35, 0.24, 0.15)), null)
	var leaf := SphereMesh.new()
	leaf.radius = 1.5
	leaf.height = 2.8
	leaf.radial_segments = 10
	leaf.rings = 6
	var leaf_mat := _mat(Color.WHITE)
	leaf_mat.vertex_color_use_as_albedo = true
	_multimesh(root, leaf, leaf_t, leaf_mat, leaf_c)


# -------------------------------------------------------------- quarteirões

static func _blocks(root: Node3D, rng: RandomNumberGenerator, pois: Array) -> void:
	var hamb := {"0,1": "1", "3,2": "2", "1,3": "3"}   # quarteirões com hamburgueria
	var houses := [0]                                   # contador de casas de entrega
	for ix in 4:
		for iz in 4:
			var bx: Array = BLOCKS[ix]
			var bz: Array = BLOCKS[iz]
			var x0 := float(bx[0])
			var x1 := float(bx[1])
			var z0 := float(bz[0])
			var z1 := float(bz[1])
			if ix == 1 and iz == 1:
				_training_area(root, pois)
			elif ix == 2 and iz == 1:
				_gas_station(root, pois)
			elif ix == 1 and iz == 2:
				_workshop_block(root, rng, pois)
			elif ix == 2 and iz == 2:
				_garage_block(root, pois)
			elif (ix == 0 or ix == 3) and (iz == 0 or iz == 3):
				_residential_block(root, rng, x0, x1, z0, z1, pois, houses)
			else:
				_commercial_block(root, rng, x0, x1, z0, z1, pois, str(hamb.get("%d,%d" % [ix, iz], "")))


static func _commercial_block(root: Node3D, rng: RandomNumberGenerator, x0: float, x1: float, z0: float, z1: float, pois: Array, hamb_id: String) -> void:
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
			var h := rng.randf_range(7.0, 21.0)
			var shop := rng.randf() < 0.7
			var color_idx := rng.randi() % PALETTE.size()
			var is_hamb := hamb_id != "" and i == 0 and j == 0
			if is_hamb:
				h = 8.0
				color_idx = 4
				shop = false
			var pos := Vector3(cx, h * 0.5, cz)
			var size := Vector3(w, h, d)
			_building(root, pos, size, color_idx, rng, shop)
			if is_hamb:
				_hamburgueria(root, pois, pos, size, hamb_id)


static func _residential_block(root: Node3D, rng: RandomNumberGenerator, x0: float, x1: float, z0: float, z1: float, pois: Array, houses: Array) -> void:
	var nx := maxi(1, int((x1 - x0) / 17.0))
	var nz := maxi(1, int((z1 - z0) / 17.0))
	var lot_w := (x1 - x0) / nx
	var lot_d := (z1 - z0) / nz
	for i in nx:
		for j in nz:
			var lcx := x0 + lot_w * (i + 0.5)
			var lcz := z0 + lot_d * (j + 0.5)
			var delivery := (i + j) % 2 == 0
			var label := ""
			if delivery:
				houses[0] += 1
				label = "CASA %d" % houses[0]
			var gate := _house(root, lcx, lcz, lot_w, lot_d, rng, label)
			if delivery:
				_poi(root, pois, "casa_%d" % houses[0], label, "C", gate, Color(0.4, 1.0, 0.5))


static func _training_area(root: Node3D, pois: Array) -> void:
	# Pátio de treino: asfalto, slalom de cones, rampa e pilhas de pneus
	_mesh(root, _box_mesh(Vector3(40, 0.02, 44)), Vector3(-30, 0.02, -30), _tex_mat("asphalt", Color(0.9, 0.9, 0.95), 0.5))
	var white := _mat(Color(0.93, 0.93, 0.93))
	for sx in [-19.0, 19.0]:
		_mesh(root, _box_mesh(Vector3(0.2, 0.01, 44)), Vector3(-30 + sx, 0.04, -30), white)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.26
	cone.height = 0.7
	cone.radial_segments = 10
	var stripe := CylinderMesh.new()
	stripe.top_radius = 0.1
	stripe.bottom_radius = 0.13
	stripe.height = 0.12
	stripe.radial_segments = 10
	var cone_mat := _mat(Color(1.0, 0.42, 0.05))
	var shape := CylinderShape3D.new()
	shape.radius = 0.25
	shape.height = 0.7
	for i in 10:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		_mesh(body, cone, Vector3.ZERO, cone_mat)
		_mesh(body, stripe, Vector3(0, 0.05, 0), _mat(Color.WHITE))
		body.position = Vector3(-30.0 + (2.2 if i % 2 == 0 else -2.2), 0.35, -48.0 + i * 4.0)
		root.add_child(body)
	_box_body(root, Vector3(-15, 0.38, -30), Vector3(4, 0.3, 6), _mat(Color(0.55, 0.5, 0.45)), Vector3(deg_to_rad(10.0), 0, 0))
	var tire := CylinderMesh.new()
	tire.top_radius = 0.42
	tire.bottom_radius = 0.42
	tire.height = 0.3
	tire.radial_segments = 12
	var tire_mat := _mat(Color(0.05, 0.05, 0.05))
	var tire_shape := CylinderShape3D.new()
	tire_shape.radius = 0.42
	tire_shape.height = 0.9
	for p in [Vector3(-48, 0, -50), Vector3(-12, 0, -50), Vector3(-48, 0, -10), Vector3(-12, 0, -10)]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = tire_shape
		cs.position = Vector3(0, 0.45, 0)
		body.add_child(cs)
		for k in 3:
			_mesh(body, tire, Vector3(0, 0.15 + k * 0.3, 0), tire_mat)
		body.position = p
		root.add_child(body)
	_poi(root, pois, "treino", "TREINO", "T", Vector3(-22, 0, -30), Color(0.3, 1.0, 0.5))


static func _gas_station(root: Node3D, pois: Array) -> void:
	var steel := _mat(Color(0.78, 0.78, 0.8))
	var red := _mat(Color(0.85, 0.12, 0.1))
	_mesh(root, _box_mesh(Vector3(13, 0.5, 9)), Vector3(30, 5.2, -30), _mat(Color(0.95, 0.95, 0.95)))
	_mesh(root, _box_mesh(Vector3(13.2, 0.3, 9.2)), Vector3(30, 4.9, -30), red)
	for sx in [-5.5, 5.5]:
		for sz in [-3.5, 3.5]:
			_box_body(root, Vector3(30.0 + sx, 2.5, -30.0 + sz), Vector3(0.5, 5, 0.5), steel)
	var pump_mat := _mat(Color(0.92, 0.92, 0.92))
	var dark := _mat(Color(0.1, 0.1, 0.12))
	for px in [26.0, 34.0]:
		_box_body(root, Vector3(px, 0.75, -30), Vector3(0.7, 1.5, 0.5), pump_mat)
		_mesh(root, _box_mesh(Vector3(0.72, 0.4, 0.52)), Vector3(px, 1.2, -30), red)
		_mesh(root, _box_mesh(Vector3(0.3, 0.2, 0.02)), Vector3(px, 1.0, -29.74), dark)
	_building(root, Vector3(42, 2.5, -44), Vector3(8, 5, 6), 4, null, false)
	_mesh(root, _box_mesh(Vector3(6.5, 2.4, 0.1)), Vector3(42, 1.4, -40.95), _lit_glass(Color(0.15, 0.2, 0.25)))
	_label(root, "POSTO", Vector3(30, 6.1, -25.4), Color(1, 1, 1), 0.0)
	_poi(root, pois, "posto", "POSTO", "P", Vector3(30, 0, -22), Color(1.0, 0.3, 0.3))


static func _workshop_block(root: Node3D, rng: RandomNumberGenerator, pois: Array) -> void:
	_building(root, Vector3(-30, 4, 36), Vector3(18, 8, 14), 2, rng, false)
	# Portões de enrolar da oficina voltados para a avenida
	_mesh(root, _box_mesh(Vector3(0.12, 3.2, 5.0)), Vector3(-20.94, 1.6, 33), _mat(Color(0.5, 0.52, 0.55)))
	_mesh(root, _box_mesh(Vector3(0.12, 3.2, 5.0)), Vector3(-20.94, 1.6, 39), _mat(Color(0.5, 0.52, 0.55)))
	_label(root, "OFICINA", Vector3(-20.8, 5.2, 36), Color(1.0, 0.75, 0.2), PI / 2.0)
	_building(root, Vector3(-30, 3, 14), Vector3(14, 6, 8), 4, rng, true)
	_poi(root, pois, "oficina", "OFICINA", "O", Vector3(-12, 0, 36), Color(1.0, 0.6, 0.1))


static func _garage_block(root: Node3D, pois: Array) -> void:
	_building(root, Vector3(36, 3.5, 30), Vector3(16, 7, 14), 1, null, false)
	_mesh(root, _box_mesh(Vector3(0.12, 3.6, 7.0)), Vector3(27.94, 1.8, 30), _mat(Color(0.08, 0.08, 0.1)))
	_mesh(root, _box_mesh(Vector3(0.14, 0.2, 7.4)), Vector3(27.93, 3.7, 30), _mat(Color(0.3, 0.7, 1.0)))
	_label(root, "GARAGEM", Vector3(27.8, 5.4, 30), Color(0.4, 0.75, 1.0), -PI / 2.0)
	_building(root, Vector3(30, 3, 50), Vector3(12, 6, 6), 3, null, false)
	_poi(root, pois, "garagem", "GARAGEM", "G", Vector3(18, 0, 30), Color(0.4, 0.7, 1.0))


# ------------------------------------------------------- prédios e casas

static func _building(root: Node3D, pos: Vector3, size: Vector3, color_idx: int, rng: Variant, shop: bool) -> void:
	_box_body(root, pos, size, _tex_mat("facade", PALETTE[color_idx % PALETTE.size()], 0.2))
	var top := pos.y + size.y * 0.5
	var concrete := _mat(Color(0.62, 0.62, 0.64))
	_mesh(root, _box_mesh(Vector3(size.x - 0.1, 0.1, size.z - 0.1)), Vector3(pos.x, top + 0.05, pos.z), _mat(Color(0.3, 0.3, 0.33)))
	# Platibanda
	var pm := _mat(Color(0.86, 0.86, 0.86))
	_mesh(root, _box_mesh(Vector3(size.x, 0.6, 0.25)), Vector3(pos.x, top + 0.3, pos.z - size.z * 0.5 + 0.12), pm)
	_mesh(root, _box_mesh(Vector3(size.x, 0.6, 0.25)), Vector3(pos.x, top + 0.3, pos.z + size.z * 0.5 - 0.12), pm)
	_mesh(root, _box_mesh(Vector3(0.25, 0.6, size.z)), Vector3(pos.x - size.x * 0.5 + 0.12, top + 0.3, pos.z), pm)
	_mesh(root, _box_mesh(Vector3(0.25, 0.6, size.z)), Vector3(pos.x + size.x * 0.5 - 0.12, top + 0.3, pos.z), pm)
	if size.y > 6.0 and size.x > 8.0:
		# Caixa d'água
		var tank := CylinderMesh.new()
		tank.top_radius = 1.0
		tank.bottom_radius = 1.0
		tank.height = 1.7
		tank.radial_segments = 12
		var tx := pos.x + size.x * 0.22
		var tz := pos.z - size.z * 0.22
		_mesh(root, tank, Vector3(tx, top + 1.6, tz), _mat(Color(0.55, 0.7, 0.85)))
		_mesh(root, _cone(1.05, 0.5), Vector3(tx, top + 2.7, tz), _mat(Color(0.5, 0.65, 0.8)))
		for dx in [-0.7, 0.7]:
			for dz in [-0.7, 0.7]:
				_mesh(root, _box_mesh(Vector3(0.12, 0.8, 0.12)), Vector3(tx + dx, top + 0.4, tz + dz), concrete)
		# Ar-condicionado e antena
		_mesh(root, _box_mesh(Vector3(1.0, 0.7, 0.8)), Vector3(pos.x - size.x * 0.25, top + 0.35, pos.z + size.z * 0.2), _mat(Color(0.85, 0.87, 0.9)))
		var ant := CylinderMesh.new()
		ant.top_radius = 0.03
		ant.bottom_radius = 0.04
		ant.height = 3.0
		ant.radial_segments = 6
		_mesh(root, ant, Vector3(pos.x - size.x * 0.3, top + 1.5, pos.z - size.z * 0.25), _mat(Color(0.3, 0.3, 0.32)))
		_mesh(root, _box_mesh(Vector3(0.9, 0.04, 0.04)), Vector3(pos.x - size.x * 0.3, top + 2.4, pos.z - size.z * 0.25), _mat(Color(0.3, 0.3, 0.32)))
	if shop and rng != null:
		var n := _facing_dir(pos.x, pos.z)
		var along_x := absf(n.x) > 0.5
		var half := size.x * 0.5 if along_x else size.z * 0.5
		var width := (size.z if along_x else size.x) * 0.8
		var front := Vector3(pos.x, 0.0, pos.z) + n * (half + 0.06)
		_mesh(root, _box_mesh(Vector3(0.12, 2.6, width) if along_x else Vector3(width, 2.6, 0.12)), front + Vector3(0, 1.3, 0), _lit_glass(Color(0.14, 0.2, 0.28)))
		var awn: Color = AWNINGS[rng.randi() % AWNINGS.size()]
		var aw_pos := Vector3(pos.x, 0.0, pos.z) + n * (half + 0.7) + Vector3(0, 3.0, 0)
		_mesh(root, _box_mesh(Vector3(1.4, 0.1, width) if along_x else Vector3(width, 0.1, 1.4)), aw_pos, _mat(awn))
		_label(root, SHOPS[rng.randi() % SHOPS.size()], Vector3(pos.x, 3.9, pos.z) + n * (half + 0.15), Color(1, 1, 1), atan2(n.x, n.z))


## Hamburgueria: prédio baixo com vitrine, toldo, letreiro e um hambúrguer gigante no telhado.
static func _hamburgueria(root: Node3D, pois: Array, pos: Vector3, size: Vector3, id: String) -> void:
	var n := _facing_dir(pos.x, pos.z)
	var along_x := absf(n.x) > 0.5
	var half := size.x * 0.5 if along_x else size.z * 0.5
	var width := (size.z if along_x else size.x) * 0.85
	var base := Vector3(pos.x, 0.0, pos.z)
	_mesh(root, _box_mesh(Vector3(0.12, 2.8, width) if along_x else Vector3(width, 2.8, 0.12)), base + n * (half + 0.06) + Vector3(0, 1.4, 0), _lit_glass(Color(0.18, 0.22, 0.28)))
	var red := _mat(Color(0.85, 0.1, 0.08))
	var yellow := _mat(Color(1.0, 0.8, 0.1))
	_mesh(root, _box_mesh(Vector3(1.6, 0.1, width) if along_x else Vector3(width, 0.1, 1.6)), base + n * (half + 0.8) + Vector3(0, 3.1, 0), red)
	_mesh(root, _box_mesh(Vector3(0.1, 0.14, width) if along_x else Vector3(width, 0.14, 0.1)), base + n * (half + 1.58) + Vector3(0, 3.0, 0), yellow)
	_label(root, "HAMBURGUERIA", base + n * (half + 0.15) + Vector3(0, 4.3, 0), Color(1.0, 0.85, 0.1), atan2(n.x, n.z))
	# Hambúrguer gigante no telhado
	var top := pos.y + size.y * 0.5
	var c := Vector3(pos.x, top + 1.0, pos.z)
	var bun := _mat(Color(0.88, 0.58, 0.22))
	var bun_bottom := CylinderMesh.new()
	bun_bottom.top_radius = 1.6
	bun_bottom.bottom_radius = 1.5
	bun_bottom.height = 0.5
	bun_bottom.radial_segments = 20
	_mesh(root, bun_bottom, c, bun)
	var patty := CylinderMesh.new()
	patty.top_radius = 1.7
	patty.bottom_radius = 1.7
	patty.height = 0.45
	patty.radial_segments = 20
	_mesh(root, patty, c + Vector3(0, 0.5, 0), _mat(Color(0.32, 0.16, 0.08)))
	var cheese := _mesh(root, _box_mesh(Vector3(3.4, 0.1, 3.4)), c + Vector3(0, 0.82, 0), yellow)
	cheese.rotation.y = PI / 4.0
	var lettuce := CylinderMesh.new()
	lettuce.top_radius = 1.8
	lettuce.bottom_radius = 1.8
	lettuce.height = 0.2
	lettuce.radial_segments = 20
	_mesh(root, lettuce, c + Vector3(0, 1.0, 0), _mat(Color(0.3, 0.7, 0.2)))
	var top_bun := SphereMesh.new()
	top_bun.radius = 1.6
	top_bun.height = 3.2
	top_bun.radial_segments = 20
	top_bun.rings = 10
	var tb := _mesh(root, top_bun, c + Vector3(0, 1.1, 0), bun)
	tb.scale = Vector3(1.0, 0.6, 1.0)
	var marker := base + n * (half + 4.6)
	_poi(root, pois, "hamburgueria_" + id, "HAMBURGUERIA " + id, "H", marker, Color(1.0, 0.55, 0.1))


static func _house(root: Node3D, cx: float, cz: float, lot_w: float, lot_d: float, rng: RandomNumberGenerator, label: String) -> Vector3:
	var n := _facing_dir(cx, cz)
	var along_x := absf(n.x) > 0.5
	var w := lot_w - 6.5
	var d := lot_d - 6.5
	var h := 3.4
	var color: Color = PALETTE[rng.randi() % PALETTE.size()]
	_box_body(root, Vector3(cx, h * 0.5, cz), Vector3(w, h, d), _tex_mat("stucco", color, 0.2))
	var prism := PrismMesh.new()
	prism.size = Vector3(w + 0.9, 1.7, d + 0.9)
	_mesh(root, prism, Vector3(cx, h + 0.85, cz), _tex_mat("roof", Color.WHITE, 0.4))
	var half := w * 0.5 if along_x else d * 0.5
	var width := d if along_x else w
	var front := Vector3(cx, 0.0, cz) + n * (half + 0.05)
	_mesh(root, _box_mesh(Vector3(0.1, 2.1, 1.0) if along_x else Vector3(1.0, 2.1, 0.1)), front + Vector3(0, 1.05, 0), _mat(Color(0.35, 0.22, 0.14)))
	var glass := _lit_glass(Color(0.2, 0.3, 0.4))
	var number_text := label if label != "" else str(10 + rng.randi() % 989)
	_label(root, number_text, front + Vector3(0, 2.75, 0) + n * 0.05, Color(0.4, 1.0, 0.5) if label != "" else Color(1, 1, 1), atan2(n.x, n.z))
	for off in [-width * 0.3, width * 0.3]:
		var wp := front + Vector3(0, 1.7, 0) + (Vector3(0, 0, off) if along_x else Vector3(off, 0, 0))
		_mesh(root, _box_mesh(Vector3(0.1, 1.0, 1.2) if along_x else Vector3(1.2, 1.0, 0.1)), wp, glass)
	# Muro baixo com portão aberto voltado para a rua
	var wall_mat := _tex_mat("stucco", Color(0.85, 0.8, 0.72), 0.2)
	var lot_half := lot_w * 0.5 if along_x else lot_d * 0.5
	var lot_len := lot_d if along_x else lot_w
	var seg := (lot_len - 3.2) * 0.5
	var wall_center := Vector3(cx, 0.0, cz) + n * (lot_half - 0.5)
	for sgn in [-1.0, 1.0]:
		var off: float = sgn * (1.6 + seg * 0.5)
		var pos := wall_center + Vector3(0, 0.9, 0) + (Vector3(0, 0, off) if along_x else Vector3(off, 0, 0))
		_box_body(root, pos, Vector3(0.25, 1.8, seg) if along_x else Vector3(seg, 1.8, 0.25), wall_mat)
	return wall_center


static func _facing_dir(cx: float, cz: float) -> Vector3:
	var best_x := 1e9
	var dir_x := 1.0
	var best_z := 1e9
	var dir_z := 1.0
	for r in ROADS:
		var rr: float = r
		if absf(cx - rr) < best_x:
			best_x = absf(cx - rr)
			dir_x = 1.0 if rr >= cx else -1.0
		if absf(cz - rr) < best_z:
			best_z = absf(cz - rr)
			dir_z = 1.0 if rr >= cz else -1.0
	if best_x <= best_z:
		return Vector3(dir_x, 0, 0)
	return Vector3(0, 0, dir_z)


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
	_mesh(root, cyl, pos + Vector3(0, 0.08, 0), m)
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


static func _label(root: Node3D, text: String, pos: Vector3, color: Color, yaw: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.014
	l.outline_size = 14
	l.modulate = color
	l.position = pos
	l.rotation = Vector3(0, yaw, 0)
	root.add_child(l)


static func _cone(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	return c


static func _texture(kind: String) -> ImageTexture:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var r := RandomNumberGenerator.new()
	r.seed = hash(kind)
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var c := Color.WHITE
			match kind:
				"asphalt":
					var v := 0.17 + r.randf() * 0.05
					if r.randf() < 0.02:
						v += 0.14
					c = Color(v, v, v * 1.05)
				"concrete":
					var v2 := 0.66 + r.randf() * 0.04
					if x % 32 == 0 or y % 32 == 0:
						v2 -= 0.12
					c = Color(v2, v2, v2 * 0.98)
				"facade":
					var v3 := 0.93 + r.randf() * 0.04
					c = Color(v3, v3, v3)
					if y == 31 or y == 63:
						c = Color(0.78, 0.78, 0.78)
					for wx in [6, 38]:
						for wy in [6, 38]:
							if x >= wx and x < wx + 20 and y >= wy and y < wy + 22:
								c = Color(0.82, 0.82, 0.84)
								if x >= wx + 2 and x < wx + 18 and y >= wy + 2 and y < wy + 20:
									var t := float(y - wy) / 22.0
									c = Color(0.36 - 0.2 * t, 0.5 - 0.26 * t, 0.66 - 0.3 * t)
				"facade_lit":
					c = Color(0, 0, 0)
					for wx in [6, 38]:
						for wy in [6, 38]:
							if wx == 38 and wy == 6:
								continue   # uma janela apagada por bloco
							if x >= wx + 2 and x < wx + 18 and y >= wy + 2 and y < wy + 20:
								c = Color(1.0, 0.85, 0.5)
				"stucco":
					var v4 := 0.9 + r.randf() * 0.07
					c = Color(v4, v4, v4)
				"roof":
					var v5 := 0.74 + r.randf() * 0.06
					if y % 8 < 2:
						v5 -= 0.25
					c = Color(v5, v5 * 0.42, v5 * 0.3)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[kind] = tex
	return tex


static func _tex_mat(kind: String, color: Color, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _texture(kind)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = 0.9
	if kind == "facade":
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_texture = _texture("facade_lit")
		m.emission_energy_multiplier = 0.0
		_lit.append(m)
	return m


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


static func _lit_glass(color: Color) -> StandardMaterial3D:
	var m := _mat(color)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.5)
	m.emission_energy_multiplier = 0.0
	_lit.append(m)
	return m


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mesh.get_aabb().size.length() < 30.0:
		mi.visibility_range_end = 150.0   # peças pequenas somem longe (economiza desenho)
		mi.visibility_range_end_margin = 10.0
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _multimesh(root: Node3D, mesh: Mesh, xforms: Array[Transform3D], mat: Material, colors: Variant) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors != null
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if colors != null:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	root.add_child(mmi)


static func _near_road(c: float, margin: float) -> bool:
	for r in ROADS:
		if absf(c - float(r)) < margin:
			return true
	return false
