extends RefCounted
## Constrói as três motos e o piloto proceduralmente. Origem = contato da roda traseira; frente = -Z.
##   estilo 0: GC 125  - clássica de meados de 2009 (farol redondo, garfo com sanfonas, amortecedores duplos)
##   estilo 1: GC 160  - utilitária moderna (farol de LED, carenagens angulares, painel digital, rodas de liga)
##   estilo 2: TORRADO 300 - trail alta (bico, garfo invertido dourado, guidão alto, pneus de trilha)
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
		"rim_style": 1 if int(profile.style) == 1 else 0,   # 0 raiada, 1 liga leve
		"suspension": 1,         # 0 macia, 1 média, 2 firme
	}


static func build(profile, custom: Dictionary) -> Dictionary:
	var mats := _materials(custom)
	var root := Node3D.new()
	var parts := {"root": root, "mats": mats}
	var ctx := {
		"wb": float(profile.wheelbase), "wr": float(profile.wheel_radius),
		"style": int(profile.style), "mats": mats, "root": root, "parts": parts,
	}
	match int(profile.style):
		0:
			_gc125(ctx)
		1:
			_gc160(ctx)
		_:
			_torrado(ctx)
	_extras(ctx)
	_rider(root, mats, int(profile.style), float(profile.wheelbase), ctx["head"])
	return parts


static func apply_custom(parts: Dictionary, custom: Dictionary) -> void:
	var mats: Dictionary = parts["mats"]
	var body_color: Color = custom["body_color"]
	(mats["body"] as StandardMaterial3D).albedo_color = body_color
	(mats["accent"] as StandardMaterial3D).albedo_color = body_color.darkened(0.35)
	(mats["frame"] as StandardMaterial3D).albedo_color = custom["frame_color"]
	(mats["rim"] as StandardMaterial3D).albedo_color = custom["rim_color"]
	(parts["mirrors"] as Node3D).visible = bool(custom["mirrors"])
	(parts["topcase"] as Node3D).visible = bool(custom["topcase"])
	(parts["sticker_stripes"] as Node3D).visible = custom["sticker"] == "listras"
	(parts["sticker_number"] as Node3D).visible = custom["sticker"] == "numero"
	var sport_exhaust: bool = custom["exhaust"] == "esportivo"
	(parts["exhaust_std"] as Node3D).visible = not sport_exhaust
	(parts["exhaust_sport"] as Node3D).visible = sport_exhaust
	var alloy: bool = int(custom["rim_style"]) == 1
	for n in parts["rim_std"]:
		(n as Node3D).visible = not alloy
	for n in parts["rim_sport"]:
		(n as Node3D).visible = alloy


# ====================================================================== GC 125
static func _gc125(ctx: Dictionary) -> void:
	var wb: float = ctx["wb"]
	var wr: float = ctx["wr"]
	var mats: Dictionary = ctx["mats"]
	var root: Node3D = ctx["root"]
	var parts: Dictionary = ctx["parts"]
	var body: Material = mats["body"]
	var frame: Material = mats["frame"]
	var metal: Material = mats["metal"]
	var chrome: Material = mats["chrome"]
	var dark: Material = mats["dark"]
	var drop := 0.58
	var head := Vector3(0, wr + drop, -wb + 0.25)
	ctx["head"] = head

	var rear := _wheel(root, Vector3(0, wr, 0), wr, mats, {"drum": true})
	var fork := Node3D.new()
	fork.position = head
	root.add_child(fork)
	var front := _wheel(fork, Vector3(0, -drop, -0.25), wr, mats, {"disc": true})
	_register(parts, rear, front, fork)

	# quadro tubular
	_limb(root, head + Vector3(0, -0.04, 0.06), Vector3(0, 0.8, -0.3), 0.04, frame)
	_limb(root, head + Vector3(0, -0.12, 0.08), Vector3(0, 0.36, -0.74), 0.04, frame)
	for sx in [-1.0, 1.0]:
		_limb(root, Vector3(0.09 * sx, 0.36, -0.74), Vector3(0.09 * sx, 0.4, -0.45), 0.03, frame)
		_limb(root, Vector3(0.09 * sx, 0.78, -0.3), Vector3(0.09 * sx, 0.8, 0.42), 0.025, frame)
		_limb(root, Vector3(0.09 * sx, 0.4, -0.76), Vector3(0.09 * sx, wr, 0.0), 0.03, frame)
		_limb(root, Vector3(0.09 * sx, 0.78, 0.1), Vector3(0.09 * sx, wr + 0.1, 0.0), 0.02, frame)
		# amortecedores duplos
		_limb(root, Vector3(0.15 * sx, wr + 0.12, 0.03), Vector3(0.165 * sx, 0.55, -0.04), 0.045, dark)
		_limb(root, Vector3(0.165 * sx, 0.5, -0.05), Vector3(0.17 * sx, 0.8, -0.12), 0.025, chrome)
		# pedaleiras
		_add(root, _box(Vector3(0.12, 0.025, 0.03)), Vector3(0.27 * sx, 0.38, -0.38), chrome)
		# piscas
		_add(root, _sphere(0.04), Vector3(0.14 * sx, wr + 0.26, 0.5), mats["amber"])
		# trilho do bagageiro
		_limb(root, Vector3(0.11 * sx, 0.88, 0.05), Vector3(0.11 * sx, 0.9, 0.52), 0.015, chrome)
	_limb(root, Vector3(-0.11, 0.9, 0.52), Vector3(0.11, 0.9, 0.52), 0.015, chrome)

	# motor, cilindro com aletas, tampas e corrente
	var mid := -0.62
	_add(root, _box(Vector3(0.28, 0.3, 0.36)), Vector3(0, 0.42, mid), dark)
	_add(root, _box(Vector3(0.2, 0.26, 0.22)), Vector3(0, 0.62, mid - 0.1), metal, Vector3(-0.5, 0, 0))
	for k in 5:
		_add(root, _box(Vector3(0.28, 0.012, 0.2)), Vector3(0, 0.55 + k * 0.045, mid - 0.1 - k * 0.012), metal, Vector3(-0.5, 0, 0))
	for sx in [-1.0, 1.0]:
		_add(root, _cyl(0.1, 0.1, 0.03), Vector3(0.16 * sx, 0.42, mid + 0.02), chrome, Vector3(0, 0, PI / 2.0))
	_add(root, _cyl(0.06, 0.06, 0.02), Vector3(0.17, 0.4, -0.12), chrome, Vector3(0, 0, PI / 2.0))
	_limb(root, Vector3(0.18, 0.4, -0.12), Vector3(0.18, wr + 0.09, 0.0), 0.01, dark)
	_limb(root, Vector3(0.18, 0.4, -0.12), Vector3(0.18, wr - 0.09, 0.0), 0.01, dark)

	# escapamentos
	var std := Node3D.new()
	root.add_child(std)
	_limb(std, Vector3(0.05, 0.5, -0.78), Vector3(0.2, 0.3, -0.58), 0.04, chrome)
	_limb(std, Vector3(0.2, 0.3, -0.58), Vector3(0.21, 0.31, -0.05), 0.042, chrome)
	_add(std, _cyl(0.075, 0.075, 0.62), Vector3(0.21, 0.33, 0.28), chrome, Vector3(PI / 2.0 - 0.04, 0, 0))
	_add(std, _cyl(0.055, 0.055, 0.03), Vector3(0.21, 0.335, 0.6), dark, Vector3(PI / 2.0 - 0.04, 0, 0))
	parts["exhaust_std"] = std
	var sport := Node3D.new()
	root.add_child(sport)
	_limb(sport, Vector3(0.05, 0.5, -0.78), Vector3(0.2, 0.32, -0.55), 0.045, chrome)
	_limb(sport, Vector3(0.2, 0.32, -0.55), Vector3(0.22, 0.4, -0.05), 0.045, chrome)
	_add(sport, _cyl(0.095, 0.085, 0.46), Vector3(0.23, 0.5, 0.2), chrome, Vector3(PI / 2.0 - 0.25, 0, 0))
	_add(sport, _cyl(0.07, 0.07, 0.03), Vector3(0.23, 0.55, 0.43), dark, Vector3(PI / 2.0 - 0.25, 0, 0))
	parts["exhaust_sport"] = sport

	# tanque com protetores de joelho, tampa, banco, tampas laterais, paralama e lanterna
	var tank := CapsuleMesh.new()
	tank.radius = 0.15
	tank.height = 0.58
	_add(root, tank, Vector3(0, 0.97, -0.55), body, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.86))
	for sx in [-1.0, 1.0]:
		_add(root, _box(Vector3(0.035, 0.14, 0.22)), Vector3(0.155 * sx, 0.93, -0.5), dark)
		_add(root, _box(Vector3(0.05, 0.22, 0.36)), Vector3(0.15 * sx, 0.62, -0.18), body)
	_add(root, _cyl(0.04, 0.04, 0.02), Vector3(0, 1.11, -0.5), chrome)
	_add(root, _box(Vector3(0.27, 0.09, 0.8)), Vector3(0, 0.84, -0.02), mats["seat"])
	_add(root, _box(Vector3(0.22, 0.04, 0.8)), Vector3(0, 0.78, -0.02), dark)
	_add(root, _box(Vector3(0.17, 0.02, 0.52)), Vector3(0, wr + 0.27, 0.22), body, Vector3(-0.12, 0, 0))
	_add(root, _box(Vector3(0.16, 0.07, 0.06)), Vector3(0, wr + 0.2, 0.5), mats["tail"])
	_add(root, _box(Vector3(0.18, 0.12, 0.015)), Vector3(0, wr + 0.1, 0.53), mats["white"])

	# garfo telescópico com sanfonas, farol redondo, mostradores redondos
	for sx in [-1.0, 1.0]:
		_limb(fork, Vector3(0.085 * sx, 0, 0), Vector3(0.085 * sx, -drop * 0.5, -0.125), 0.03, chrome)
		_limb(fork, Vector3(0.085 * sx, -drop * 0.1, -0.025), Vector3(0.085 * sx, -drop * 0.55, -0.135), 0.043, dark)
		_limb(fork, Vector3(0.085 * sx, -drop * 0.55, -0.135), Vector3(0.085 * sx, -drop, -0.25), 0.034, metal)
		_add(fork, _sphere(0.035), Vector3(0.21 * sx, -0.02, -0.13), mats["amber"])
		_add(fork, _box(Vector3(0.1, 0.012, 0.025)), Vector3(0.3 * sx, 0.145, -0.03), metal)
		_add(fork, _box(Vector3(0.11, 0.04, 0.04)), Vector3(0.33 * sx, 0.13, 0.05), mats["seat"])
		var dial := _add(fork, _cyl(0.055, 0.055, 0.04), Vector3(0.07 * sx, 0.15, -0.02), dark, Vector3(PI / 2.0 - 0.7, 0, 0))
		_add(fork, _cyl(0.042, 0.042, 0.006), dial.position + Vector3(0, 0.014, 0.012), mats["screen"], Vector3(PI / 2.0 - 0.7, 0, 0))
	_add(fork, _box(Vector3(0.26, 0.05, 0.07)), Vector3(0, 0, 0), metal)
	_add(fork, _box(Vector3(0.74, 0.03, 0.03)), Vector3(0, 0.13, 0.05), mats["dark"])
	_add(fork, _cyl(0.12, 0.12, 0.12), Vector3(0, 0.05, -0.14), metal, Vector3(PI / 2.0, 0, 0))
	_add(fork, _sphere(0.115), Vector3(0, 0.05, -0.2), mats["lamp"], Vector3.ZERO, Vector3(1, 1, 0.7))
	_add(fork, _cyl(0.13, 0.13, 0.035), Vector3(0, 0.05, -0.265), chrome, Vector3(PI / 2.0, 0, 0))
	_add(fork, _box(Vector3(0.13, 0.022, 0.4)), Vector3(0, -drop + wr + 0.07, -0.25), chrome)
	_mirrors(fork, mats, true, parts)

	ctx["tank_y"] = 0.97
	ctx["tank_z"] = -0.55
	ctx["tank_len"] = 0.58
	ctx["tank_top"] = 1.105
	ctx["tank_side"] = 0.16
	ctx["tail_top"] = 0.9
	ctx["tail_z"] = 0.28


# ====================================================================== GC 160
static func _gc160(ctx: Dictionary) -> void:
	var wb: float = ctx["wb"]
	var wr: float = ctx["wr"]
	var mats: Dictionary = ctx["mats"]
	var root: Node3D = ctx["root"]
	var parts: Dictionary = ctx["parts"]
	var body: Material = mats["body"]
	var accent: Material = mats["accent"]
	var frame: Material = mats["frame"]
	var metal: Material = mats["metal"]
	var chrome: Material = mats["chrome"]
	var dark: Material = mats["dark"]
	var drop := 0.6
	var head := Vector3(0, wr + drop, -wb + 0.25)
	ctx["head"] = head

	var rear := _wheel(root, Vector3(0, wr, 0), wr, mats, {"disc": true})
	var fork := Node3D.new()
	fork.position = head
	root.add_child(fork)
	var front := _wheel(fork, Vector3(0, -drop, -0.25), wr, mats, {"disc": true})
	_register(parts, rear, front, fork)

	_limb(root, head + Vector3(0, -0.04, 0.06), Vector3(0, 0.82, -0.3), 0.04, frame)
	_limb(root, head + Vector3(0, -0.12, 0.08), Vector3(0, 0.36, -0.72), 0.04, frame)
	for sx in [-1.0, 1.0]:
		_limb(root, Vector3(0.09 * sx, 0.38, -0.74), Vector3(0.09 * sx, wr, 0.0), 0.032, frame)
		_limb(root, Vector3(0.09 * sx, 0.8, -0.3), Vector3(0.09 * sx, 0.84, 0.42), 0.025, frame)
		# amortecedores com mola colorida
		_limb(root, Vector3(0.15 * sx, wr + 0.14, 0.02), Vector3(0.162 * sx, 0.56, -0.05), 0.045, accent)
		_limb(root, Vector3(0.162 * sx, 0.52, -0.06), Vector3(0.17 * sx, 0.78, -0.12), 0.025, chrome)
		_add(root, _box(Vector3(0.12, 0.025, 0.03)), Vector3(0.27 * sx, 0.4, -0.36), metal)
		# piscas de LED
		_add(root, _box(Vector3(0.05, 0.03, 0.04)), Vector3(0.17 * sx, 0.9, 0.52), mats["amber"])
		# painéis laterais
		_add(root, _box(Vector3(0.05, 0.22, 0.4)), Vector3(0.155 * sx, 0.64, -0.15), body, Vector3(0, 0, 0.05 * sx))
		_add(root, _box(Vector3(0.053, 0.05, 0.4)), Vector3(0.155 * sx, 0.52, -0.15), accent)
		# alça traseira
		_limb(root, Vector3(0.1 * sx, 0.96, 0.05), Vector3(0.1 * sx, 1.0, 0.46), 0.016, metal)
		# carenagens do tanque
		_add(root, _box(Vector3(0.09, 0.2, 0.42)), Vector3(0.2 * sx, 0.93, -0.56), accent, Vector3(0, 0, -0.25 * sx))
	_limb(root, Vector3(-0.1, 1.0, 0.46), Vector3(0.1, 1.0, 0.46), 0.016, metal)

	# motor preto com tampas prateadas
	var mid := -0.58
	_add(root, _box(Vector3(0.3, 0.3, 0.4)), Vector3(0, 0.42, mid), dark)
	_add(root, _box(Vector3(0.24, 0.24, 0.26)), Vector3(0, 0.64, mid - 0.1), metal, Vector3(-0.45, 0, 0))
	for k in 5:
		_add(root, _box(Vector3(0.3, 0.012, 0.22)), Vector3(0, 0.57 + k * 0.04, mid - 0.1 - k * 0.012), dark, Vector3(-0.45, 0, 0))
	for sx in [-1.0, 1.0]:
		_add(root, _cyl(0.1, 0.1, 0.03), Vector3(0.16 * sx, 0.42, mid + 0.02), metal, Vector3(0, 0, PI / 2.0))
	_add(root, _box(Vector3(0.04, 0.06, 0.5)), Vector3(0.17, 0.38, -0.3), dark)

	# escapamentos
	var std := Node3D.new()
	root.add_child(std)
	_limb(std, Vector3(0.05, 0.5, -0.76), Vector3(0.2, 0.34, -0.5), 0.04, metal)
	_add(std, _cyl(0.08, 0.08, 0.5), Vector3(0.2, 0.34, 0.15), dark, Vector3(PI / 2.0, 0, 0))
	_add(std, _box(Vector3(0.04, 0.11, 0.34)), Vector3(0.27, 0.38, 0.15), metal)
	_add(std, _cyl(0.06, 0.06, 0.04), Vector3(0.2, 0.34, 0.41), chrome, Vector3(PI / 2.0, 0, 0))
	parts["exhaust_std"] = std
	var sport := Node3D.new()
	root.add_child(sport)
	_limb(sport, Vector3(0.05, 0.5, -0.76), Vector3(0.2, 0.34, -0.5), 0.045, chrome)
	_add(sport, _cyl(0.1, 0.09, 0.5), Vector3(0.23, 0.46, 0.18), chrome, Vector3(PI / 2.0 - 0.22, 0, 0))
	_add(sport, _cyl(0.07, 0.07, 0.03), Vector3(0.23, 0.5, 0.42), dark, Vector3(PI / 2.0 - 0.22, 0, 0))
	parts["exhaust_sport"] = sport

	# tanque angular, banco, rabeta e lanterna de LED
	_add(root, _box(Vector3(0.28, 0.2, 0.46)), Vector3(0, 0.98, -0.56), body, Vector3(0.05, 0, 0))
	_add(root, _box(Vector3(0.1, 0.02, 0.1)), Vector3(0, 1.09, -0.5), metal)
	_add(root, _box(Vector3(0.28, 0.1, 0.78)), Vector3(0, 0.86, -0.02), mats["seat"])
	_add(root, _box(Vector3(0.22, 0.1, 0.5)), Vector3(0, 0.93, 0.28), body, Vector3(0.14, 0, 0))
	_add(root, _box(Vector3(0.2, 0.12, 0.1)), Vector3(0, 0.88, 0.54), accent)
	_add(root, _box(Vector3(0.2, 0.035, 0.03)), Vector3(0, 0.9, 0.595), mats["tail"])
	_add(root, _box(Vector3(0.17, 0.02, 0.42)), Vector3(0, wr + 0.22, 0.24), body)
	_add(root, _box(Vector3(0.2, 0.12, 0.012)), Vector3(0, wr + 0.1, 0.56), mats["white"])

	# garfo com tubos pretos, farol de LED, painel digital
	for sx in [-1.0, 1.0]:
		_limb(fork, Vector3(0.09 * sx, 0, 0), Vector3(0.09 * sx, -drop * 0.5, -0.13), 0.034, dark)
		_limb(fork, Vector3(0.09 * sx, -drop * 0.5, -0.13), Vector3(0.09 * sx, -drop, -0.25), 0.03, metal)
		_add(fork, _box(Vector3(0.04, 0.16, 0.14)), Vector3(0.17 * sx, 0.06, -0.12), body, Vector3(0, 0.3 * sx, 0))
		_add(fork, _box(Vector3(0.04, 0.025, 0.03)), Vector3(0.2 * sx, -0.04, -0.2), mats["amber"])
		_add(fork, _box(Vector3(0.1, 0.012, 0.025)), Vector3(0.3 * sx, 0.165, -0.03), metal)
		_add(fork, _box(Vector3(0.1, 0.04, 0.04)), Vector3(0.33 * sx, 0.15, 0.06), mats["seat"])
	_add(fork, _box(Vector3(0.26, 0.05, 0.07)), Vector3(0, 0, 0), metal)
	_add(fork, _box(Vector3(0.3, 0.14, 0.14)), Vector3(0, 0.07, -0.14), body)
	_add(fork, _box(Vector3(0.24, 0.1, 0.04)), Vector3(0, 0.06, -0.215), mats["lamp"])
	_add(fork, _box(Vector3(0.22, 0.015, 0.02)), Vector3(0, 0.135, -0.215), mats["lamp"])
	_add(fork, _box(Vector3(0.26, 0.08, 0.18)), Vector3(0, 0.17, -0.1), accent, Vector3(-0.2, 0, 0))
	_add(fork, _box(Vector3(0.2, 0.09, 0.05)), Vector3(0, 0.22, 0.0), dark, Vector3(-0.5, 0, 0))
	_add(fork, _box(Vector3(0.15, 0.055, 0.01)), Vector3(0, 0.235, 0.025), mats["screen"], Vector3(-0.5, 0, 0))
	_add(fork, _box(Vector3(0.72, 0.03, 0.03)), Vector3(0, 0.15, 0.06), dark)
	_add(fork, _box(Vector3(0.14, 0.025, 0.4)), Vector3(0, -drop + wr + 0.08, -0.25), body)
	_mirrors(fork, mats, false, parts)

	ctx["tank_y"] = 0.98
	ctx["tank_z"] = -0.56
	ctx["tank_len"] = 0.46
	ctx["tank_top"] = 1.085
	ctx["tank_side"] = 0.25
	ctx["tail_top"] = 0.98
	ctx["tail_z"] = 0.28


# =================================================================== TORRADO 300
static func _torrado(ctx: Dictionary) -> void:
	var wb: float = ctx["wb"]
	var wr: float = ctx["wr"]
	var mats: Dictionary = ctx["mats"]
	var root: Node3D = ctx["root"]
	var parts: Dictionary = ctx["parts"]
	var body: Material = mats["body"]
	var accent: Material = mats["accent"]
	var frame: Material = mats["frame"]
	var metal: Material = mats["metal"]
	var chrome: Material = mats["chrome"]
	var dark: Material = mats["dark"]
	var gold: Material = mats["gold"]
	var drop := 0.82
	var head := Vector3(0, wr + drop, -wb + 0.25)
	ctx["head"] = head

	var rear := _wheel(root, Vector3(0, wr, 0), wr, mats, {"knobs": true, "thick": 0.19, "disc": true})
	var fork := Node3D.new()
	fork.position = head
	root.add_child(fork)
	var front := _wheel(fork, Vector3(0, -drop, -0.25), wr, mats, {"knobs": true, "thick": 0.19, "disc": true})
	_register(parts, rear, front, fork)

	# quadro de berço, balança longa, protetor de cárter, monoamortecedor
	_limb(root, head + Vector3(0, -0.08, 0.1), Vector3(0, 1.05, -0.45), 0.04, frame)
	_limb(root, head + Vector3(0, -0.2, 0.1), Vector3(0, 0.5, -0.86), 0.04, frame)
	for sx in [-1.0, 1.0]:
		_limb(root, Vector3(0.1 * sx, 0.5, -0.86), Vector3(0.1 * sx, 0.46, -0.35), 0.03, frame)
		_limb(root, Vector3(0.1 * sx, 1.0, -0.2), Vector3(0.1 * sx, 1.06, 0.5), 0.028, frame)
		_limb(root, Vector3(0.1 * sx, 0.5, -0.9), Vector3(0.1 * sx, wr, 0.0), 0.035, frame)
		_add(root, _box(Vector3(0.14, 0.03, 0.04)), Vector3(0.29 * sx, 0.5, -0.4), metal)
		_limb(root, Vector3(0.1 * sx, 1.12, 0.1), Vector3(0.1 * sx, 1.14, 0.56), 0.016, metal)
		_add(root, _box(Vector3(0.1, 0.22, 0.5)), Vector3(0.19 * sx, 1.0, -0.84), accent, Vector3(0, 0, -0.18 * sx))
		_add(root, _box(Vector3(0.055, 0.2, 0.34)), Vector3(0.16 * sx, 0.82, -0.1), body)
	_limb(root, Vector3(-0.1, 1.14, 0.56), Vector3(0.1, 1.14, 0.56), 0.016, metal)
	_limb(root, Vector3(0, 0.56, -0.5), Vector3(0, 1.0, -0.26), 0.05, accent)
	_limb(root, Vector3(0, 0.62, -0.48), Vector3(0, 0.95, -0.28), 0.028, chrome)
	_add(root, _box(Vector3(0.3, 0.04, 0.6)), Vector3(0, 0.33, -0.72), metal)

	# motor alto
	var mid := -0.7
	_add(root, _box(Vector3(0.3, 0.34, 0.42)), Vector3(0, 0.56, mid), dark)
	_add(root, _box(Vector3(0.26, 0.26, 0.28)), Vector3(0, 0.82, mid - 0.08), metal, Vector3(-0.35, 0, 0))
	for k in 5:
		_add(root, _box(Vector3(0.3, 0.012, 0.24)), Vector3(0, 0.74 + k * 0.045, mid - 0.08 - k * 0.01), dark, Vector3(-0.35, 0, 0))
	_add(root, _cyl(0.07, 0.07, 0.02), Vector3(0.17, 0.5, -0.1), metal, Vector3(0, 0, PI / 2.0))
	_limb(root, Vector3(0.18, 0.5, -0.1), Vector3(0.18, wr + 0.11, 0.0), 0.012, dark)
	_limb(root, Vector3(0.18, 0.5, -0.1), Vector3(0.18, wr - 0.11, 0.0), 0.012, dark)

	# escapamentos altos
	var std := Node3D.new()
	root.add_child(std)
	_limb(std, Vector3(0.04, 0.74, -0.95), Vector3(0.2, 0.62, -0.7), 0.04, metal)
	_limb(std, Vector3(0.2, 0.62, -0.7), Vector3(0.22, 0.78, -0.2), 0.042, metal)
	_add(std, _cyl(0.075, 0.075, 0.62), Vector3(0.22, 0.92, 0.14), metal, Vector3(PI / 2.0 - 0.32, 0, 0))
	_add(std, _box(Vector3(0.03, 0.12, 0.4)), Vector3(0.285, 0.95, 0.14), dark)
	_add(std, _cyl(0.055, 0.055, 0.03), Vector3(0.22, 1.03, 0.43), dark, Vector3(PI / 2.0 - 0.32, 0, 0))
	parts["exhaust_std"] = std
	var sport := Node3D.new()
	root.add_child(sport)
	_limb(sport, Vector3(0.04, 0.74, -0.95), Vector3(0.2, 0.62, -0.7), 0.045, chrome)
	_limb(sport, Vector3(0.2, 0.62, -0.7), Vector3(0.23, 0.8, -0.2), 0.045, chrome)
	_add(sport, _cyl(0.1, 0.09, 0.55), Vector3(0.23, 0.95, 0.12), chrome, Vector3(PI / 2.0 - 0.4, 0, 0))
	_add(sport, _cyl(0.075, 0.075, 0.03), Vector3(0.23, 1.06, 0.42), dark, Vector3(PI / 2.0 - 0.4, 0, 0))
	parts["exhaust_sport"] = sport

	# tanque estreito, banco longo, rabeta fina e paralama traseiro
	var tank := CapsuleMesh.new()
	tank.radius = 0.13
	tank.height = 0.5
	_add(root, tank, Vector3(0, 1.15, -0.62), body, Vector3(PI / 2.0, 0, 0), Vector3(1.0, 1.0, 0.85))
	_add(root, _cyl(0.04, 0.04, 0.02), Vector3(0, 1.26, -0.56), metal)
	_add(root, _box(Vector3(0.27, 0.09, 0.85)), Vector3(0, 1.07, -0.05), mats["seat"])
	_add(root, _box(Vector3(0.2, 0.08, 0.55)), Vector3(0, 1.1, 0.4), body, Vector3(0.18, 0, 0))
	_add(root, _box(Vector3(0.17, 0.02, 0.45)), Vector3(0, 0.8, 0.34), body, Vector3(-0.25, 0, 0))
	_add(root, _box(Vector3(0.14, 0.04, 0.03)), Vector3(0, 0.98, 0.68), mats["tail"])
	_add(root, _box(Vector3(0.18, 0.11, 0.012)), Vector3(0, 0.88, 0.66), mats["white"])
	for sx in [-1.0, 1.0]:
		_add(root, _sphere(0.035), Vector3(0.14 * sx, 0.95, 0.62), mats["amber"])

	# garfo invertido dourado, bico, máscara do farol, para-brisa, guidão alto com protetores
	for sx in [-1.0, 1.0]:
		_limb(fork, Vector3(0.09 * sx, 0, 0), Vector3(0.09 * sx, -drop * 0.5, -0.125), 0.042, gold)
		_limb(fork, Vector3(0.09 * sx, -drop * 0.5, -0.125), Vector3(0.09 * sx, -drop, -0.25), 0.03, dark)
		_limb(fork, Vector3(0.1 * sx, 0.02, 0.02), Vector3(0.14 * sx, 0.25, 0.06), 0.02, metal)
		_add(fork, _box(Vector3(0.035, 0.13, 0.13)), Vector3(0.43 * sx, 0.26, -0.02), dark)
		_add(fork, _box(Vector3(0.12, 0.045, 0.045)), Vector3(0.4 * sx, 0.26, 0.06), mats["seat"])
		_add(fork, _box(Vector3(0.1, 0.012, 0.025)), Vector3(0.32 * sx, 0.28, 0.0), metal)
		_add(fork, _sphere(0.03), Vector3(0.14 * sx, 0.0, -0.22), mats["amber"])
	_add(fork, _box(Vector3(0.28, 0.05, 0.07)), Vector3(0, 0, 0), metal)
	_add(fork, _box(Vector3(0.3, 0.05, 0.07)), Vector3(0, -0.15, -0.04), metal)
	_add(fork, _box(Vector3(0.3, 0.26, 0.1)), Vector3(0, 0.12, -0.22), accent)
	_add(fork, _box(Vector3(0.2, 0.14, 0.04)), Vector3(0, 0.1, -0.28), mats["lamp"])
	_add(fork, _box(Vector3(0.2, 0.03, 0.34)), Vector3(0, -0.06, -0.33), body, Vector3(-0.4, 0, 0))
	_add(fork, _box(Vector3(0.22, 0.14, 0.01)), Vector3(0, 0.3, -0.18), mats["glass"], Vector3(-0.9, 0, 0))
	_add(fork, _box(Vector3(0.14, 0.07, 0.04)), Vector3(0, 0.2, 0.0), dark, Vector3(-0.5, 0, 0))
	_add(fork, _box(Vector3(0.1, 0.045, 0.01)), Vector3(0, 0.213, 0.022), mats["screen"], Vector3(-0.5, 0, 0))
	_add(fork, _box(Vector3(0.88, 0.03, 0.03)), Vector3(0, 0.26, 0.06), dark)
	_add(fork, _box(Vector3(0.5, 0.022, 0.022)), Vector3(0, 0.21, 0.04), metal)
	_add(fork, _box(Vector3(0.14, 0.02, 0.46)), Vector3(0, -drop + wr + 0.3, -0.27), body, Vector3(-0.12, 0, 0))
	_mirrors(fork, mats, false, parts)

	ctx["tank_y"] = 1.15
	ctx["tank_z"] = -0.62
	ctx["tank_len"] = 0.5
	ctx["tank_top"] = 1.265
	ctx["tank_side"] = 0.24
	ctx["tail_top"] = 1.16
	ctx["tail_z"] = 0.4


# ====================================================== extras, rodas e utilidades

static func _extras(ctx: Dictionary) -> void:
	var root: Node3D = ctx["root"]
	var mats: Dictionary = ctx["mats"]
	var parts: Dictionary = ctx["parts"]
	var tank_z: float = ctx["tank_z"]
	var tank_len: float = ctx["tank_len"]
	var tank_top: float = ctx["tank_top"]
	var tank_y: float = ctx["tank_y"]
	var side: float = ctx["tank_side"]
	var tail_top: float = ctx["tail_top"]
	var tail_z: float = ctx["tail_z"]
	var stripes := Node3D.new()
	root.add_child(stripes)
	for sx in [-1.0, 1.0]:
		_add(stripes, _box(Vector3(0.04, 0.012, tank_len * 0.9)), Vector3(0.035 * sx, tank_top, tank_z), mats["white"])
		_add(stripes, _box(Vector3(0.04, 0.012, 0.36)), Vector3(0.035 * sx, tail_top + 0.07, tail_z), mats["white"])
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
		lbl.position = Vector3((side + 0.01) * sx, tank_y - 0.04, tank_z)
		lbl.rotation = Vector3(0, PI / 2.0 * sx, 0)
		numbers.add_child(lbl)
	parts["sticker_number"] = numbers
	var topcase := Node3D.new()
	root.add_child(topcase)
	_add(topcase, _box(Vector3(0.36, 0.04, 0.4)), Vector3(0, tail_top + 0.04, tail_z + 0.1), mats["metal"])
	_add(topcase, _box(Vector3(0.4, 0.3, 0.42)), Vector3(0, tail_top + 0.22, tail_z + 0.1), mats["dark"])
	_add(topcase, _box(Vector3(0.3, 0.04, 0.34)), Vector3(0, tail_top + 0.39, tail_z + 0.1), mats["body"])
	parts["topcase"] = topcase
	# Bolsa de entrega (aparece durante entregas)
	var bag := Node3D.new()
	root.add_child(bag)
	var red := _mat(Color(0.82, 0.1, 0.08), 0.6)
	var yellow := _mat(Color(1.0, 0.82, 0.1), 0.6)
	_add(bag, _box(Vector3(0.44, 0.42, 0.46)), Vector3(0, tail_top + 0.26, tail_z + 0.12), red)
	_add(bag, _box(Vector3(0.46, 0.05, 0.48)), Vector3(0, tail_top + 0.43, tail_z + 0.12), yellow)
	_add(bag, _box(Vector3(0.46, 0.08, 0.1)), Vector3(0, tail_top + 0.26, tail_z + 0.12), yellow)
	bag.visible = false
	parts["bag"] = bag


static func _mirrors(fork: Node3D, mats: Dictionary, round_mirror: bool, parts: Dictionary) -> void:
	var mirrors := Node3D.new()
	fork.add_child(mirrors)
	for sx in [-1.0, 1.0]:
		_limb(mirrors, Vector3(0.3 * sx, 0.16, 0.0), Vector3(0.36 * sx, 0.36, -0.03), 0.012, mats["dark"])
		if round_mirror:
			_add(mirrors, _cyl(0.06, 0.06, 0.015), Vector3(0.38 * sx, 0.4, -0.04), mats["dark"], Vector3(PI / 2.0 - 0.3, 0, 0))
		else:
			_add(mirrors, _box(Vector3(0.12, 0.07, 0.015)), Vector3(0.38 * sx, 0.38, -0.03), mats["dark"], Vector3(0, 0, 0.2 * sx))
	parts["mirrors"] = mirrors


static func _register(parts: Dictionary, rear: Dictionary, front: Dictionary, fork: Node3D) -> void:
	parts["rear_wheel"] = rear["pivot"]
	parts["front_wheel"] = front["pivot"]
	parts["fork"] = fork
	parts["rim_std"] = [rear["std"], front["std"]]
	parts["rim_sport"] = [rear["sport"], front["sport"]]


static func _materials(custom: Dictionary) -> Dictionary:
	var body_color: Color = custom["body_color"]
	var mats := {
		"body": _mat(body_color, 0.3, 0.25),
		"accent": _mat(body_color.darkened(0.35), 0.4, 0.2),
		"frame": _mat(custom["frame_color"], 0.5, 0.6),
		"rim": _mat(custom["rim_color"], 0.3, 0.8),
		"dark": _mat(Color(0.07, 0.07, 0.08), 0.8),
		"metal": _mat(Color(0.62, 0.62, 0.68), 0.3, 0.85),
		"chrome": _mat(Color(0.88, 0.88, 0.92), 0.12, 1.0),
		"gold": _mat(Color(0.86, 0.66, 0.16), 0.3, 0.9),
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
	mats["lamp"] = _glow(Color(1.0, 0.97, 0.8))
	mats["tail"] = _glow(Color(0.9, 0.05, 0.05))
	mats["screen"] = _glow(Color(0.2, 1.0, 0.5))
	mats["amber"] = _glow(Color(1.0, 0.6, 0.05))
	return mats


static func _glow(color: Color) -> StandardMaterial3D:
	var m := _mat(color, 0.3)
	m.emission_enabled = true
	m.emission = color
	return m


static func _rider(root: Node3D, mats: Dictionary, style: int, wb: float, head: Vector3) -> void:
	var hip := Vector3(0, 0.93, -0.12)
	var shoulder := Vector3(0, 1.4, -0.4)
	var head_pos := Vector3(0, 1.6, -0.46)
	var hand_y := head.y + 0.13
	var hand_x := 0.31
	var knee := Vector3(0.26, 0.8, -0.52)
	var foot := Vector3(0.25, 0.4, -0.38)
	if style == 1:
		hip = Vector3(0, 0.95, -0.1)
		shoulder = Vector3(0, 1.42, -0.4)
		head_pos = Vector3(0, 1.62, -0.46)
		hand_y = head.y + 0.15
		hand_x = 0.32
		knee = Vector3(0.26, 0.82, -0.52)
		foot = Vector3(0.25, 0.43, -0.38)
	elif style == 2:
		hip = Vector3(0, 1.14, -0.1)
		shoulder = Vector3(0, 1.62, -0.3)
		head_pos = Vector3(0, 1.82, -0.34)
		hand_y = head.y + 0.26
		hand_x = 0.4
		knee = Vector3(0.27, 1.0, -0.5)
		foot = Vector3(0.25, 0.5, -0.4)
	var hand_z := -wb + 0.31
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
		_add(root, _sphere(0.055), hand, dark)
		var hp := Vector3(0.13 * sx, hip.y, hip.z)
		var kn := Vector3(knee.x * sx, knee.y, knee.z)
		var ft := Vector3(foot.x * sx, foot.y, foot.z)
		_limb(root, hp, kn, 0.07, pants)
		_limb(root, kn, ft, 0.06, pants)
		_add(root, _box(Vector3(0.12, 0.1, 0.26)), ft + Vector3(0, -0.03, -0.05), dark)


static func _wheel(parent: Node3D, pos: Vector3, radius: float, mats: Dictionary, opts: Dictionary) -> Dictionary:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var thick: float = opts.get("thick", 0.15)
	var tire := TorusMesh.new()
	tire.outer_radius = radius
	tire.inner_radius = radius - thick
	tire.rings = 24
	tire.ring_segments = 10
	_add(pivot, tire, Vector3.ZERO, mats["tire"], Vector3(0, 0, PI / 2.0))
	if opts.get("knobs", false):
		for k in 18:
			var ang := TAU * k / 18.0
			_add(pivot, _box(Vector3(thick * 0.9, 0.05, 0.07)), Vector3(0, cos(ang) * (radius - 0.012), sin(ang) * (radius - 0.012)), mats["tire"], Vector3(ang, 0, 0))
	var rim_r := radius - thick
	_add(pivot, _cyl(rim_r, rim_r, 0.1), Vector3.ZERO, mats["rim"], Vector3(0, 0, PI / 2.0))
	_add(pivot, _cyl(0.05, 0.05, 0.2), Vector3.ZERO, mats["metal"], Vector3(0, 0, PI / 2.0))
	if opts.get("drum", false):
		_add(pivot, _cyl(0.125, 0.125, 0.16), Vector3(-0.02, 0, 0), mats["chrome"], Vector3(0, 0, PI / 2.0))
	if opts.get("disc", false):
		_add(pivot, _cyl(rim_r * 0.6, rim_r * 0.6, 0.012), Vector3(0.07, 0, 0), mats["metal"], Vector3(0, 0, PI / 2.0))
	var std := Node3D.new()
	pivot.add_child(std)
	for k in 6:
		_add(std, _box(Vector3(0.02, rim_r * 2.0 - 0.02, 0.015)), Vector3.ZERO, mats["metal"], Vector3(k * PI / 6.0, 0, 0))
	var alloy := Node3D.new()
	pivot.add_child(alloy)
	for k in 5:
		_add(alloy, _box(Vector3(0.05, rim_r * 2.0 - 0.01, 0.035)), Vector3.ZERO, mats["rim"], Vector3(k * PI / 5.0, 0, 0))
	return {"pivot": pivot, "std": std, "sport": alloy}


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


static func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


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
