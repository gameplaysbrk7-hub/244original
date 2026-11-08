extends RefCounted
## Humanoide articulado procedural. Cada membro é um cilindro entre duas articulações.
## Uma pose é um dicionário de posições alvo (quadril, peito, cabeça, mãos, pés);
## a cinemática inversa de 2 ossos calcula joelhos e cotovelos.
## Chaves de pose: hip, chest, head, head_yaw, hand_l, hand_r, foot_l, foot_r.

const THIGH := 0.45
const SHIN := 0.45
const UPPER := 0.34
const FORE := 0.34

var root: Node3D
var head_node: Node3D
var bag_node: Node3D     # bag de entregas, presa às costas (acompanha o tronco)
var phone_node: Node3D   # celular na mão direita

var _limbs: Dictionary = {}
var _hands: Dictionary = {}
var _boots: Dictionary = {}
var _pelvis: MeshInstance3D


func build(parent: Node3D, jacket_color: Color = Color(0.1, 0.3, 0.75)) -> void:
	root = Node3D.new()
	parent.add_child(root)
	var jacket := _mat(jacket_color, 0.75)
	var pants := _mat(Color(0.12, 0.12, 0.16), 0.9)
	var dark := _mat(Color(0.07, 0.07, 0.08), 0.8)
	var helmet := _mat(Color(0.95, 0.95, 0.95), 0.2)
	var glass := _mat(Color(0.12, 0.18, 0.28, 0.65), 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_limbs["torso"] = _limb_mesh(0.15, jacket)
	for s in ["l", "r"]:
		_limbs["upper_" + s] = _limb_mesh(0.05, jacket)
		_limbs["fore_" + s] = _limb_mesh(0.045, jacket)
		_limbs["thigh_" + s] = _limb_mesh(0.075, pants)
		_limbs["shin_" + s] = _limb_mesh(0.06, pants)
		var hand := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.055
		sph.height = 0.11
		sph.radial_segments = 8
		sph.rings = 4
		hand.mesh = sph
		hand.material_override = dark
		root.add_child(hand)
		_hands[s] = hand
		var boot := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.1, 0.26)
		boot.mesh = bm
		boot.material_override = dark
		root.add_child(boot)
		_boots[s] = boot
	_pelvis = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.3, 0.16, 0.2)
	_pelvis.mesh = pm
	_pelvis.material_override = pants
	root.add_child(_pelvis)
	head_node = Node3D.new()
	root.add_child(head_node)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.15
	hs.height = 0.3
	hs.radial_segments = 14
	hs.rings = 8
	head.mesh = hs
	head.material_override = helmet
	head_node.add_child(head)
	var visor := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.2, 0.075, 0.1)
	visor.mesh = vm
	visor.material_override = glass
	visor.position = Vector3(0, 0.01, -0.1)
	head_node.add_child(visor)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.03, 0.01, 0.28)
	stripe.mesh = sm
	stripe.material_override = jacket
	stripe.position = Vector3(0, 0.15, 0)
	head_node.add_child(stripe)
	_build_bag()
	_build_phone()


func set_bag_visible(on: bool) -> void:
	bag_node.visible = on


func set_phone_visible(on: bool) -> void:
	phone_node.visible = on


func _build_bag() -> void:
	bag_node = Node3D.new()
	root.add_child(bag_node)
	var red := _mat(Color(0.82, 0.1, 0.08), 0.6)
	var yellow := _mat(Color(1.0, 0.82, 0.1), 0.6)
	var dark := _mat(Color(0.06, 0.06, 0.07), 0.8)
	_box_child(bag_node, Vector3(0.38, 0.44, 0.26), Vector3(0, 0.02, 0.27), red)
	_box_child(bag_node, Vector3(0.40, 0.07, 0.28), Vector3(0, 0.26, 0.27), yellow)
	_box_child(bag_node, Vector3(0.40, 0.08, 0.27), Vector3(0, 0.02, 0.27), yellow)
	for sx in [-1.0, 1.0]:
		_box_child(bag_node, Vector3(0.05, 0.46, 0.03), Vector3(0.12 * sx, 0.02, -0.16), dark)
	bag_node.visible = false


func _build_phone() -> void:
	phone_node = Node3D.new()
	(_hands["r"] as Node3D).add_child(phone_node)
	phone_node.position = Vector3(0, 0.03, -0.05)
	phone_node.rotation = Vector3(-0.5, 0, 0)
	_box_child(phone_node, Vector3(0.07, 0.15, 0.012), Vector3.ZERO, _mat(Color(0.12, 0.12, 0.14), 0.4))
	var screen := _mat(Color(0.2, 0.45, 1.0), 0.3)
	screen.emission_enabled = true
	screen.emission = Color(0.2, 0.45, 1.0)
	_box_child(phone_node, Vector3(0.062, 0.138, 0.002), Vector3(0, 0, 0.0075), screen)
	phone_node.visible = false


func _box_child(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func pose(p: Dictionary) -> void:
	var hip: Vector3 = p["hip"]
	var chest: Vector3 = p["chest"]
	_set_limb(_limbs["torso"], hip, chest)
	if bag_node.visible:
		var dn := (chest - hip).normalized()
		var back := Vector3.RIGHT.cross(dn).normalized()
		bag_node.transform = Transform3D(Basis(Vector3.RIGHT, dn, back).orthonormalized(), (hip + chest) * 0.5)
	_pelvis.position = hip + Vector3(0, -0.02, 0)
	head_node.position = p["head"]
	head_node.rotation.y = float(p.get("head_yaw", 0.0))
	for i in 2:
		var s := "l" if i == 0 else "r"
		var sgn := -1.0 if i == 0 else 1.0
		var hj := hip + Vector3(0.12 * sgn, 0.0, 0.0)
		var foot: Vector3 = p["foot_" + s]
		var knee := ik(hj, foot, THIGH, SHIN, Vector3(0.25 * sgn, 0.0, -1.0))
		_set_limb(_limbs["thigh_" + s], hj, knee)
		_set_limb(_limbs["shin_" + s], knee, foot)
		(_boots[s] as Node3D).position = foot + Vector3(0, -0.03, -0.05)
		var sj := chest + Vector3(0.2 * sgn, -0.04, 0.0)
		var hand: Vector3 = p["hand_" + s]
		var elbow := ik(sj, hand, UPPER, FORE, Vector3(0.8 * sgn, -0.5, 0.4))
		_set_limb(_limbs["upper_" + s], sj, elbow)
		_set_limb(_limbs["fore_" + s], elbow, hand)
		(_hands[s] as Node3D).position = hand


## Cinemática inversa de 2 ossos: devolve a posição da articulação do meio (joelho/cotovelo).
static func ik(a: Vector3, b: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var ab := b - a
	var d := clampf(ab.length(), 0.05, l1 + l2 - 0.001)
	var dir := ab.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := pole - dir * pole.dot(dir)
	if side.length() < 0.001:
		side = dir.cross(Vector3.UP)
		if side.length() < 0.001:
			side = Vector3.RIGHT
	return a + dir * x + side.normalized() * h


static func lerp_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		var va: Variant = a[k]
		var vb: Variant = b.get(k, va)
		if typeof(va) == TYPE_VECTOR3:
			out[k] = (va as Vector3).lerp(vb, t)
		elif typeof(va) == TYPE_FLOAT:
			out[k] = lerpf(va, float(vb), t)
		else:
			out[k] = vb
	return out


static func _set_limb(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	mi.position = (a + b) * 0.5
	mi.scale = Vector3(1.0, length, 1.0)
	var dir := d / length
	if dir.dot(Vector3.DOWN) > 0.9999:
		mi.quaternion = Quaternion(Vector3.RIGHT, PI)
	else:
		mi.quaternion = Quaternion(Vector3.UP, dir)


func _limb_mesh(radius: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	root.add_child(mi)
	return mi


static func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m
