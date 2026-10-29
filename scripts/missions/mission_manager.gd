extends Node3D
## Executa uma missão por vez: entrega, desafio de grau ou percurso com checkpoints.
## Cada execução tem um identificador próprio; a recompensa é paga uma única vez por execução
## (veja GameState.claim_reward). Missões em andamento não são salvas, então recarregar
## o jogo não permite receber de novo.

const Catalog := preload("res://scripts/missions/mission_catalog.gd")

signal started(mission: Dictionary)
signal completed(mission: Dictionary, reward: int)
signal failed(mission: Dictionary, reason: String)

const DELIVERY_RADIUS := 5.5
const CHECKPOINT_RADIUS := 7.0

var state: Node
var bike: Node3D
var poi_positions: Dictionary = {}
var poi_names: Dictionary = {}
var active: Dictionary = {}
var stage: int = 0
var time_left: float = 0.0

var _finished: bool = true
var _run_counter: int = 0
var _run_id: String = ""
var _marker: MeshInstance3D


func setup(game_state: Node, bike_node: Node3D, pois: Array) -> void:
	state = game_state
	bike = bike_node
	for p in pois:
		poi_positions[p["id"]] = p["pos"]
		poi_names[p["id"]] = p["name"]
	var beam := CylinderMesh.new()
	beam.top_radius = 2.5
	beam.bottom_radius = 2.5
	beam.height = 30.0
	beam.radial_segments = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker = MeshInstance3D.new()
	_marker.mesh = beam
	_marker.material_override = mat
	_marker.visible = false
	add_child(_marker)


func is_active() -> bool:
	return not _finished


func start(id: String) -> bool:
	if not _finished:
		return false
	var m := Catalog.find(id)
	if m.is_empty():
		return false
	active = m
	stage = 0
	time_left = float(m["time"])
	_run_counter += 1
	_run_id = "%s#%d" % [id, _run_counter]
	_finished = false
	_update_marker()
	started.emit(active.duplicate(true))
	return true


func cancel() -> void:
	if _finished:
		return
	_fail("Missão cancelada")


func has_objective_pos() -> bool:
	return not _finished and active.get("type", "") != "wheelie"


func objective_pos() -> Vector3:
	if _finished:
		return Vector3.ZERO
	match active["type"]:
		"delivery":
			return poi_positions.get(active["from"] if stage == 0 else active["to"], Vector3.ZERO)
		"checkpoints":
			var pts: Array = active["points"]
			return pts[mini(stage, pts.size() - 1)]
	return Vector3.ZERO


func objective_text() -> String:
	if _finished:
		return ""
	var t := "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	match active["type"]:
		"delivery":
			var target_id: String = active["from"] if stage == 0 else active["to"]
			var verb := "Pegue a encomenda em" if stage == 0 else "Entregue em"
			return "%s %s  (%s)" % [verb, poi_names.get(target_id, target_id), t]
		"wheelie":
			return "Grau: %.1f / %.0f s  (%s)" % [float(bike.wheelie_time), float(active["target"]), t]
		"checkpoints":
			return "Ponto %d de %d  (%s)" % [stage + 1, (active["points"] as Array).size(), t]
	return ""


func _physics_process(delta: float) -> void:
	if _finished:
		return
	time_left -= delta
	if time_left <= 0.0:
		_fail("Tempo esgotado")
		return
	match active["type"]:
		"delivery":
			if _flat_distance(bike.global_position, objective_pos()) < DELIVERY_RADIUS:
				stage += 1
				if stage >= 2:
					_complete()
		"wheelie":
			if float(bike.wheelie_time) >= float(active["target"]):
				_complete()
		"checkpoints":
			if _flat_distance(bike.global_position, objective_pos()) < CHECKPOINT_RADIUS:
				stage += 1
				if stage >= (active["points"] as Array).size():
					_complete()
	_update_marker()


func _complete() -> void:
	_finished = true
	var m := active.duplicate(true)
	var reward: int = state.claim_reward(str(m["id"]), _run_id, int(m["reward"]))
	active = {}
	_update_marker()
	completed.emit(m, reward)


func _fail(reason: String) -> void:
	_finished = true
	var m := active.duplicate(true)
	active = {}
	_update_marker()
	failed.emit(m, reason)


func _update_marker() -> void:
	var visible_now := has_objective_pos()
	_marker.visible = visible_now
	if visible_now:
		_marker.global_position = objective_pos() + Vector3(0, 15, 0)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
