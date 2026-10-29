extends RefCounted
## Constrói a moto e o piloto proceduralmente. Origem = contato da roda traseira; frente = -Z.
## O visual depende do perfil (estilo, entre-eixos, raio da roda) e da customização.
## As peças usam materiais compartilhados: trocar cor não duplica modelos.

static func default_custom(profile) -> Dictionary:
	return {
		"body_color": profile.body_color,
		"frame_color": Color(0.1, 0.1, 0.12),
		"rim_color": Color(0.75, 0.75, 0.8),
		"sticker": "nenhum",     # nenhum | listras | numero
		"mirrors": true,
		"topcase": false,
		"exhaust": "padrao",     # padrao | esportivo
		"rim_style": 0,          # 0 padrão, 1 esportiva
		"suspension": 1,         # 0 macia, 1 média, 2 firme
	}


static func build(profile, custom: Dictionary) -> Dictionary:
	var wb: float = profile.wheelbase
	var wr: float = profile.wheel_radius
	var style: int = profile.style
	var mats := {
		"body": _mat(custom["body_color"], 0.3, 0.25),
		"frame": _mat(custom["frame_color"], 0.5, 0.6),
		"rim": _mat(custom["rim_color"], 0.3, 0.8),
		"dark": _mat(Color(0.07, 0.07, 0.08), 0.8),
		"metal": _mat(Color(0.68, 0.68, 0.72), 0.25, 0.9),
		"tire": _mat(Color(0.03, 0.03, 0.03), 0.95),
		"seat": _mat(Color(0.05, 0.05, 0.06), 0.85),
		"jacket": _mat(Color(0.1, 0.3, 0.75), 0.75),
		"pants": _mat(Color(0.12, 0.12, 0.16), 0.9),
		"helmet": _mat(Color(0.95, 0.95, 0.95), 0.2),
		"white": _mat(Color(0.95, 0.95, 0.95), 0.5),
	}
	var glass := _mat(Color(0.12, 0.18, 0.28, 0.65), 0.1, 0.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["glass"] = glass
	var lamp := _mat(Color(1.0, 0.97, 0.8), 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.97, 0.8)
	mats["lamp"] = lamp
	var tail := _mat(Color(0.9, 0.05, 0.05), 0.4)
	tail.emission_enabled = true
	tail.emission = Color(0.9, 0.05, 0.05)
	mats["tail"] = tail
	var screen := _mat(Color(0.2, 1.0, 0.5), 0.3)
	screen.emission_enabled = true
	screen.emission = Color(0.2, 1.0, 0.5)
	mats["screen"] = screen

	var root := Node3D.new()
	var parts := {"root": root, "mats": mats, "rim_std": [], "rim_sport": []}

	# ---------- rodas
	var rear := _wheel(root, Vector3(0, wr, 0), wr, mats, style == 2)
	var drop := 0.62 + (0.16 if style == 2 else 0.0)
	var head := Vector3(0, wr + drop, -wb + 0.25)
	var fork := Node3D.new()
	fork.position = head
	root.add_child(fork)
	var front := _wheel(fork, Vector3(0, -drop, -0.25), wr, mats, style == 2)
	parts["rear_wheel"] = rear["pivot"]
	parts["front_wheel"] = front["pivot"]
	parts["fork"] = fork
	parts["rim_std"] = [rear["std"], front["std"]]
	parts["rim_sport"] = [rear["sport"], front["sport"]]

	# ---------- quadro, balança e amortecedor
	var frame: Material = mats["frame"]
	var metal: Material = mats["metal"]
	var dark: Material = mats["dark"]
	var body: Material = mats["body"]
	_limb(root, head + Vector3(0, -0.06, 0.1), Vector3(0, 0.86, -0.1), 0.05, frame)
	_limb(root, Vector3(0, 0.62, -wb + 0.4), Vector3(0, 0.4, -0.78), 0.04, frame)
	_limb(root, Vector3(0, 0.4, -0.78), Vector3(0, 0.78, -0.05), 0.04, frame)
	for sx in [-1.0, 1.0]:
		_limb(root, Vector3(0.1 * sx, 0.42, -0.78), Vector3(0.1 * sx, wr, 0.0), 0.03, frame)
	_limb(root, Vector3(0, 0.42, -0.5), Vector3(0, 0.8, -0.22), 0.035, metal)
	_limb(root, Vector3(0, 0.48, -0.47), Vector3(0, 0.74, -0.27), 0.05, body)

	# ---------- motor e escape de série
	var mid := -wb * 0.5
	_add(root, _box(Vector3(0.3, 0.32, 0.4)), Vector3(0, 0.5, mid), dark)
	_add(root, _box(Vector3(0.26, 0.2, 0.26)), Vector3(0, 0.73, mid - 0.06), metal, Vector3(-0.35, 0, 0))
	for k in 4:
		_add(root, _box(Vector3(0.34, 0.015, 0.22)), Vector3(0, 0.66 + k * 0.045, mid - 0.06), metal, Vector3(-0.35, 0, 0))
	_limb(root, Vector3(0.06, 0.64, mid - 0.18), Vector3(0.21, 0.42, mid + 0.08), 0.03, metal)
	var exhaust_std := Node3D.new()
	root.add_child(exhaust_std)
	_limb(exhaust_std, Vector3(0.21, 0.42, mid + 0.08), Vector3(0.22, 0.44, 0.3), 0.045, metal)
	_add(exhaust_std, _cyl(0.07, 0.07, 0.42), Vector3(0.22, 0.45, 0.4), metal, Vector3(PI / 2.0, 0, 0))
	_add(exhaust_std, _cyl(0.05, 0.05, 0.02), Vector3(0.22, 0.45, 0.62), dark, Vector3(PI / 2.0, 0, 0))
	parts["exhaust_std"] = exhaust_std
	var exhaust_sport := Node3D.new()
	root.add_child(exhaust_sport)
	_limb(exhaust_sport, Vector3(0.21, 0.42, mid + 0.08), Vector3(0.23, 0.55, 0.1), 0.05, metal)
	_add(exhaust_sport, _cyl(0.095, 0.085, 0.55), Vector3(0.24, 0.64, 0.28), metal, Vector3(PI / 2.0 - 0.28, 0, 0))
	_add(exhaust_sport, _cyl(0.07, 0.07, 0.03), Vector3(0.24, 0.7, 0.55), dark, Vector3(PI / 2.0 - 0.28, 0, 0))
	parts["exhaust_sport"] = exhaust_sport

	# ---------- tanque, banco, rabeta
	var tank_y := 0.95
	var tank_len := 0.62
	var seat_y := 0.84
	if style == 1:
		tank_y = 0.9
		tank_len = 0.7
		seat_y = 0.86
	elif style == 2:
		tank_y = 1.0
		tank_len = 0.55
		seat_y = 0.92
	var tank_z := mid - 0.12
	var tank := CapsuleMesh.new()
	tank.radius = 0.16
	tank.height = tank_len
	_add(root, tank, Vector3(0, tank_y, tank_z), body, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.82))
	_add(root, _box(Vector3(0.27, 0.09, 0.62)), Vector3(0, seat_y, -0.1), mats["seat"])
	var hump_y := seat_y + 0.08
	if style == 1:
		_add(root, _box(Vector3(0.22, 0.13, 0.5)), Vector3(0, hump_y + 0.02, 0.26), body, Vector3(0.18, 0, 0))
	else:
		_add(root, _box(Vector3(0.2, 0.1, 0.4)), Vector3(0, hump_y - 0.02, 0.28), body, Vector3(0.12, 0, 0))
		_add(root, _box(Vector3(0.16, 0.03, 0.46)), Vector3(0, wr + 0.28, 0.12), body, Vector3(-0.08, 0, 0))
	_add(root, _box(Vector3(0.18, 0.11, 0.015)), Vector3(0, 0.72, 0.52), mats["white"], Vector3(0.35, 0, 0))
	_add(root, _box(Vector3(0.14, 0.045, 0.03)), Vector3(0, 0.84, 0.52), mats["tail"])
	for sx in [-1.0, 1.0]:
		_add(root, _box(Vector3(0.12, 0.03, 0.03)), Vector3(0.27 * sx, 0.42 if style != 1 else 0.52, -0.4), metal)

	# ---------- adesivos
	var stripes := Node3D.new()
	root.add_child(stripes)
	for sx in [-1.0, 1.0]:
		_add(stripes, _box(Vector3(0.04, 0.012, tank_len * 0.9)), Vector3(0.035 * sx, tank_y + 0.13, tank_z), mats["white"], Vector3(0, 0, 0))
		_add(stripes, _box(Vector3(0.04, 0.012, 0.4)), Vector3(0.035 * sx, hump_y + 0.07, 0.28), mats["white"])
	parts["sticker_stripes"] = stripes
	var numbers := Node3D.new()
	root.add_child(numbers)
	for sx in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = "77"
		lbl.font_size = 64
		lbl.pixel_size = 0.0035
		lbl.outline_size = 10
		lbl.modulate = Color.WHITE
		lbl.outline_modulate = Color.BLACK
		lbl.position = Vector3(0.18 * sx, tank_y - 0.03, tank_z)
		lbl.rotation = Vector3(0, PI / 2.0 * sx, 0)
		numbers.add_child(lbl)
	parts["sticker_number"] = numbers

	# ---------- baú
	var topcase := Node3D.new()
	root.add_child(topcase)
	var case_y := hump_y + 0.22
	_add(topcase, _box(Vector3(0.36, 0.04, 0.4)), Vector3(0, hump_y + 0.05, 0.3), metal)
	_add(topcase, _box(Vector3(0.4, 0.3, 0.42)), Vector3(0, case_y + 0.08, 0.36), dark)
	_add(topcase, _box(Vector3(0.3, 0.04, 0.34)), Vector3(0, case_y + 0.25, 0.36), body)
	parts["topcase"] = topcase

	# ---------- garfo, guidão, farol, painel
	var legs_top := Vector3(0, 0, 0)
	for sx in [-1.0, 1.0]:
		_limb(fork, legs_top + Vector3(0.09 * sx, 0, 0), Vector3(0.09 * sx, -drop, -0.25), 0.03, metal)
		_limb(fork, Vector3(0.09 * sx, -drop * 0.55, -0.14), Vector3(0.09 * sx, -drop, -0.25), 0.04, dark)
	_add(fork, _box(Vector3(0.26, 0.05, 0.07)), Vector3(0, 0.0, 0.0), metal)
	_add(fork, _box(Vector3(0.05, 0.1, 0.07)), Vector3(0.12, -drop + 0.22, -0.2), metal)
	_add(fork, _box(Vector3(0.14, 0.04, 0.06)), Vector3(0, 0.13, -0.02), dark)
	_add(fork, _box(Vector3(0.09, 0.03, 0.01)), Vector3(0, 0.155, -0.045), mats["screen"], Vector3(-0.5, 0, 0))
	if style == 1:
		# esportiva: carenagem, para-brisa, guidão baixo
		var fair := CapsuleMesh.new()
		fair.radius = 0.19
		fair.height = 0.55
		_add(fork, fair, Vector3(0, 0.1, -0.2), body, Vector3(PI / 2.0 - 0.15, 0, 0), Vector3(1.0, 1.0, 0.9))
		_add(fork, _box(Vector3(0.28, 0.2, 0.015)), Vector3(0, 0.27, -0.14), mats["glass"], Vector3(-0.75, 0, 0))
		for sx in [-1.0, 1.0]:
			_add(fork, _box(Vector3(0.1, 0.045, 0.02)), Vector3(0.1 * sx, 0.08, -0.42), mats["lamp"])
			_add(fork, _box(Vector3(0.24, 0.03, 0.03)), Vector3(0.2 * sx, -0.01, 0.05), dark)
			_add(fork, _box(Vector3(0.09, 0.04, 0.04)), Vector3(0.33 * sx, -0.01, 0.05), mats["seat"])
		_add(fork, _box(Vector3(0.16, 0.03, 0.5)), Vector3(0, -drop + wr + 0.1, -0.25), body)
	elif style == 2:
		# trail: farol retangular, bico, guidão alto, protetores de mão
		_add(fork, _box(Vector3(0.24, 0.17, 0.1)), Vector3(0, 0.07, -0.2), mats["lamp"])
		_add(fork, _box(Vector3(0.28, 0.03, 0.3)), Vector3(0, -0.12, -0.36), body, Vector3(0.3, 0, 0))
		_add(fork, _box(Vector3(0.82, 0.035, 0.035)), Vector3(0, 0.22, 0.04), dark)
		for sx in [-1.0, 1.0]:
			_limb(fork, Vector3(0.12 * sx, 0.02, 0.02), Vector3(0.14 * sx, 0.22, 0.04), 0.02, metal)
			_add(fork, _box(Vector3(0.03, 0.1, 0.1)), Vector3(0.4 * sx, 0.22, -0.03), dark)
			_add(fork, _box(Vector3(0.1, 0.045, 0.045)), Vector3(0.38 * sx, 0.22, 0.04), mats["seat"])
		_add(fork, _box(Vector3(0.15, 0.03, 0.5)), Vector3(0, -drop + wr + 0.22, -0.28), body, Vector3(-0.12, 0, 0))
	else:
		var hl := SphereMesh.new()
		hl.radius = 0.11
		hl.height = 0.22
		hl.radial_segments = 14
		hl.rings = 8
		_add(fork, hl, Vector3(0, 0.03, -0.2), mats["lamp"], Vector3.ZERO, Vector3(1, 1, 0.8))
		_add(fork, _cyl(0.115, 0.115, 0.03), Vector3(0, 0.03, -0.27), metal, Vector3(PI / 2.0, 0, 0))
		_add(fork, _box(Vector3(0.74, 0.035, 0.035)), Vector3(0, 0.14, 0.06), dark)
		for sx in [-1.0, 1.0]:
			_add(fork, _box(Vector3(0.1, 0.045, 0.045)), Vector3(0.34 * sx, 0.14, 0.06), mats["seat"])
		_add(fork, _box(Vector3(0.15, 0.03, 0.46)), Vector3(0, -drop + wr + 0.1, -0.25), body)
	var mirrors := Node3D.new()
	fork.add_child(mirrors)
	for sx in [-1.0, 1.0]:
		_limb(mirrors, Vector3(0.3 * sx, 0.16, 0.0), Vector3(0.36 * sx, 0.36, -0.03), 0.012, dark)
		_add(mirrors, _box(Vector3(0.12, 0.07, 0.015)), Vector3(0.38 * sx, 0.38, -0.03), dark, Vector3(0.0, 0.0, 0.2 * sx))
	parts["mirrors"] = mirrors

	_rider(root, mats, style, wb, head, drop)
	return parts


static func apply_custom(parts: Dictionary, custom: Dictionary) -> void:
	var mats: Dictionary = parts["mats"]
	(mats["body"] as StandardMaterial3D).albedo_color = custom["body_color"]
	(mats["frame"] as StandardMaterial3D).albedo_color = custom["frame_color"]
	(mats["rim"] as StandardMaterial3D).albedo_color = custom["rim_color"]
	(parts["mirrors"] as Node3D).visible = bool(custom["mirrors"])
	(parts["topcase"] as Node3D).visible = bool(custom["topcase"])
	(parts["sticker_stripes"] as Node3D).visible = custom["sticker"] == "listras"
	(parts["sticker_number"] as Node3D).visible = custom["sticker"] == "numero"
	var sport_exhaust: bool = custom["exhaust"] == "esportivo"
	(parts["exhaust_std"] as Node3D).visible = not sport_exhaust
	(parts["exhaust_sport"] as Node3D).visible = sport_exhaust
	var sport_rim: bool = int(custom["rim_style"]) == 1
	for n in parts["rim_std"]:
		(n as Node3D).visible = not sport_rim
	for n in parts["rim_sport"]:
		(n as Node3D).visible = sport_rim


static func _rider(root: Node3D, mats: Dictionary, style: int, wb: float, head: Vector3, drop: float) -> void:
	var hip := Vector3(0, 0.93, -0.12)
	var shoulder := Vector3(0, 1.42, -0.42)
	var head_pos := Vector3(0, 1.62, -0.48)
	var hand_y := head.y + 0.13
	var hand_x := 0.32
	var knee := Vector3(0.27, 0.82, -0.55)
	var foot := Vector3(0.24, 0.44, -0.42)
	if style == 1:
		hip = Vector3(0, 0.98, -0.05)
		shoulder = Vector3(0, 1.22, -0.55)
		head_pos = Vector3(0, 1.4, -0.68)
		hand_y = head.y - 0.0
		hand_x = 0.33
		knee = Vector3(0.26, 0.86, -0.6)
		foot = Vector3(0.24, 0.55, -0.32)
	elif style == 2:
		hip = Vector3(0, 1.0, -0.1)
		shoulder = Vector3(0, 1.5, -0.38)
		head_pos = Vector3(0, 1.7, -0.42)
		hand_y = head.y + 0.22
		hand_x = 0.38
		knee = Vector3(0.26, 0.9, -0.55)
		foot = Vector3(0.24, 0.5, -0.4)
	var hand_z := -wb + 0.32
	var jacket: Material = mats["jacket"]
	var pants: Material = mats["pants"]
	var dark: Material = mats["dark"]
	_limb(root, hip, shoulder, 0.15, jacket)
	_add(root, _box(Vector3(0.28, 0.2, 0.12)), shoulder + Vector3(0, -0.12, 0.02), mats["body"])
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.3
	sph.radial_segments = 14
	sph.rings = 8
	_add(root, sph, head_pos, mats["helmet"])
	_add(root, _box(Vector3(0.2, 0.075, 0.1)), head_pos + Vector3(0, 0.01, -0.1), mats["glass"])
	_add(root, _box(Vector3(0.03, 0.01, 0.28)), head_pos + Vector3(0, 0.15, 0.0), mats["body"])
	for sx in [-1.0, 1.0]:
		var sh := shoulder + Vector3(0.19 * sx, -0.02, 0)
		var hand := Vector3(hand_x * sx, hand_y, hand_z)
		var elbow := Vector3((sh.x + hand.x) * 0.5 + 0.07 * sx, (sh.y + hand.y) * 0.5 - 0.06, (sh.z + hand.z) * 0.5 + 0.04)
		_limb(root, sh, elbow, 0.05, jacket)
		_limb(root, elbow, hand, 0.045, jacket)
		var glove := SphereMesh.new()
		glove.radius = 0.055
		glove.height = 0.11
		glove.radial_segments = 8
		glove.rings = 4
		_add(root, glove, hand, dark)
		var hp := Vector3(0.13 * sx, hip.y, hip.z)
		var kn := Vector3(knee.x * sx, knee.y, knee.z)
		var ft := Vector3(foot.x * sx, foot.y, foot.z)
		_limb(root, hp, kn, 0.07, pants)
		_limb(root, kn, ft, 0.06, pants)
		_add(root, _box(Vector3(0.12, 0.1, 0.26)), ft + Vector3(0, -0.03, -0.05), dark)


static func _wheel(parent: Node3D, pos: Vector3, radius: float, mats: Dictionary, trail: bool) -> Dictionary:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var thick := 0.19 if trail else 0.15
	var tire := TorusMesh.new()
	tire.outer_radius = radius
	tire.inner_radius = radius - thick
	tire.rings = 24
	tire.ring_segments = 10
	_add(pivot, tire, Vector3.ZERO, mats["tire"], Vector3(0, 0, PI / 2.0))
	var rim_r := radius - thick
	_add(pivot, _cyl(rim_r, rim_r, 0.1), Vector3.ZERO, mats["rim"], Vector3(0, 0, PI / 2.0))
	_add(pivot, _cyl(0.05, 0.05, 0.2), Vector3.ZERO, mats["metal"], Vector3(0, 0, PI / 2.0))
	_add(pivot, _cyl(rim_r * 0.58, rim_r * 0.58, 0.012), Vector3(0.07, 0, 0), mats["metal"], Vector3(0, 0, PI / 2.0))
	var std := Node3D.new()
	pivot.add_child(std)
	for k in 6:
		_add(std, _box(Vector3(0.02, rim_r * 2.0 - 0.02, 0.015)), Vector3.ZERO, mats["metal"], Vector3(k * PI / 6.0, 0, 0))
	var sport := Node3D.new()
	pivot.add_child(sport)
	for k in 5:
		_add(sport, _box(Vector3(0.05, rim_r * 2.0 - 0.01, 0.035)), Vector3.ZERO, mats["rim"], Vector3(k * PI / 5.0, 0, 0))
	return {"pivot": pivot, "std": std, "sport": sport}


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


static func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = 14
	c.rings = 1
	return c


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = d.length()
	cm.radial_segments = 8
	cm.rings = 1
	var mi := _add(parent, cm, (a + b) * 0.5, mat)
	mi.quaternion = Quaternion(Vector3.UP, d.normalized())
