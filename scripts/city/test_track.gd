extends RefCounted
## Pista de testes procedural (Fase 1): chão, céu, luz, rampa, cones, prédios e muros.
## Tudo com colisão simples (caixas e cilindros).

const HALF := 80.0


static func build(root: Node3D) -> void:
	_environment(root)
	_ground(root)
	_walls(root)
	_props(root)


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
	sun.directional_shadow_max_distance = 45.0
	root.add_child(sun)


static func _ground(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(HALF * 2.0, 2.0, HALF * 2.0)
	cs.shape = shape
	body.position = Vector3(0, -1, 0)
	body.add_child(cs)
	root.add_child(body)

	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.22, 0.22, 0.24))
	for i in 64:
		img.set_pixel(i, 0, Color(0.32, 0.32, 0.35))
		img.set_pixel(0, i, Color(0.32, 0.32, 0.35))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(40, 40, 1)
	mat.roughness = 0.95
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF * 2.0, HALF * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	root.add_child(mi)

	# Faixa central tracejada
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.2, 0.02, 2.0)
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.95, 0.8, 0.1)
	for i in 26:
		var s := MeshInstance3D.new()
		s.mesh = stripe
		s.material_override = stripe_mat
		s.position = Vector3(0, 0.011, 72.0 - i * 6.0)
		root.add_child(s)


static func _walls(root: Node3D) -> void:
	var c := Color(0.6, 0.6, 0.62)
	_box(root, Vector3(0, 2, -HALF - 0.5), Vector3(HALF * 2 + 2, 4, 1), c)
	_box(root, Vector3(0, 2, HALF + 0.5), Vector3(HALF * 2 + 2, 4, 1), c)
	_box(root, Vector3(-HALF - 0.5, 2, 0), Vector3(1, 4, HALF * 2 + 2), c)
	_box(root, Vector3(HALF + 0.5, 2, 0), Vector3(1, 4, HALF * 2 + 2), c)


static func _props(root: Node3D) -> void:
	# Rampa (sobe em direção a -Z)
	_box(root, Vector3(10, 0.38, -20), Vector3(4, 0.3, 6), Color(0.5, 0.45, 0.4), Vector3(deg_to_rad(10.0), 0, 0))
	# Slalom de cones ao longo da pista
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.25
	cone.height = 0.7
	cone.radial_segments = 10
	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color(1.0, 0.45, 0.05)
	for i in 10:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.25
		cyl.height = 0.7
		cs.shape = cyl
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = cone_mat
		body.add_child(mi)
		body.position = Vector3(2.2 if i % 2 == 0 else -2.2, 0.35, 20.0 - i * 8.0)
		root.add_child(body)
	# Prédios simples
	var colors := [Color(0.8, 0.7, 0.55), Color(0.55, 0.65, 0.8), Color(0.75, 0.5, 0.5), Color(0.6, 0.75, 0.6)]
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := 6.0 + float((i * 7) % 5) * 2.0
		_box(root, Vector3(side * 28.0, h * 0.5, 60.0 - i * 16.0), Vector3(10, h, 12), colors[i % 4])


static func _box(root: Node3D, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	root.add_child(body)
	return body
