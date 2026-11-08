extends Node3D
## Missões em tempo real. Duas famílias, cada uma com ofertas, estatísticas e ganhos próprios:
##  - Entregas (app Entregas): ACEITAR -> ir à hamburgueria -> COLETAR (botão de interação) ->
##    ir ao cliente -> ENTREGAR (botão dentro do app, nada automático).
##  - Corridas (app Corridas): desafios de grau e percursos com checkpoints.
## A recompensa é paga uma vez por execução (GameState.claim_reward).

const Catalog := preload("res://scripts/missions/mission_catalog.gd")

signal started(mission: Dictionary)
signal completed(mission: Dictionary, reward: int)
signal failed(mission: Dictionary, reason: String)
signal carrying_changed(on: bool)
signal offer_changed(kind: String)

const DELIVERY_RADIUS := 7.0
const CHECKPOINT_RADIUS := 7.0
const RECENT_DECLINES := 4

var state: Node
var bike: Node3D
var tracker: Node3D   # quem é medido nos objetivos (moto ou personagem a pé)
var rng := RandomNumberGenerator.new()
var poi_positions: Dictionary = {}
var poi_names: Dictionary = {}
var active: Dictionary = {}
var stage: int = 0
var time_left: float = 0.0
var delivery_offer: Dictionary = {}
var race_offer: Dictionary = {}
var session_deliveries: int = 0
var session_races: int = 0

var _finished: bool = true
var _run_counter: int = 0
var _run_id: String = ""
var _marker: MeshInstance3D
var _declined_deliveries: Array = []
var _declined_races: Array = []


func _ready() -> void:
	rng.randomize()


func setup(game_state: Node, bike_node: Node3D, pois: Array) -> void:
	state = game_state
	bike = bike_node
	tracker = bike_node
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


func is_delivery_active() -> bool:
	return (not _finished) and active.get("type", "") == "delivery"


# ------------------------------------------------------------ ofertas de entrega

## Sorteia uma oferta nova (uma por vez). Evita repetir as recusadas recentemente.
func roll_delivery_offer(from_pos: Vector3) -> Dictionary:
	var burgers := _ids_with_prefix("hamburgueria_")
	var houses := _ids_with_prefix("casa_")
	if burgers.is_empty() or houses.is_empty():
		delivery_offer = {}
		return delivery_offer
	var best: Dictionary = {}
	for attempt in 30:
		var b: String = burgers[rng.randi() % burgers.size()]
		var origin: Vector3 = poi_positions[b]
		var far: Array = []
		for h in houses:
			var hp: Vector3 = poi_positions[h]
			if _flat_distance(origin, hp) >= 50.0:
				far.append(h)
		var pool: Array = far if not far.is_empty() else houses
		var dest: String = pool[rng.randi() % pool.size()]
		var dp: Vector3 = poi_positions[dest]
		best = Catalog.make_delivery(b, dest, str(poi_names.get(b, b)), str(poi_names.get(dest, dest)), _flat_distance(origin, dp), _flat_distance(from_pos, origin))
		if not _declined_deliveries.has(best["id"]):
			break
	delivery_offer = best
	offer_changed.emit("delivery")
	return best


func decline_delivery(from_pos: Vector3) -> Dictionary:
	if not delivery_offer.is_empty():
		_declined_deliveries.append(delivery_offer["id"])
		while _declined_deliveries.size() > RECENT_DECLINES:
			_declined_deliveries.pop_front()
	return roll_delivery_offer(from_pos)


## Aceita a oferta atual: a entrega fica ativa e o mapa mostra a hamburgueria (retirada).
func accept_delivery() -> bool:
	if not _finished or delivery_offer.is_empty():
		return false
	active = delivery_offer.duplicate(true)
	delivery_offer = {}
	stage = 0
	time_left = float(active["time"])
	_run_counter += 1
	_run_id = "%s#%d" % [active["id"], _run_counter]
	_finished = false
	_update_marker()
	carrying_changed.emit(false)
	started.emit(active.duplicate(true))
	return true


func can_pickup_at(id: String) -> bool:
	return is_delivery_active() and stage == 0 and active.get("from", "") == id


## Botão de interação COLETAR: retira o pedido e começa o trajeto até o cliente.
func pickup() -> bool:
	if not (is_delivery_active() and stage == 0):
		return false
	stage = 1
	_update_marker()
	carrying_changed.emit(true)
	return true


func can_deliver(pos: Vector3) -> bool:
	if not (is_delivery_active() and stage == 1):
		return false
	return _flat_distance(pos, objective_pos()) < DELIVERY_RADIUS


## Botão ENTREGAR do app Entregas: só conclui no endereço certo, depois da coleta.
func deliver(pos: Vector3) -> bool:
	if not can_deliver(pos):
		return false
	_complete()
	return true


# ------------------------------------------------------------- ofertas de corrida

func roll_race_offer() -> Dictionary:
	var ids: Array = []
	for m in Catalog.MISSIONS:
		ids.append(m["id"])
	var pool: Array = []
	for id in ids:
		if not _declined_races.has(id):
			pool.append(id)
	if pool.is_empty():
		pool = ids
	race_offer = Catalog.find(str(pool[rng.randi() % pool.size()]))
	offer_changed.emit("race")
	return race_offer


func decline_race() -> Dictionary:
	if not race_offer.is_empty():
		_declined_races.append(race_offer["id"])
		while _declined_races.size() > mini(RECENT_DECLINES, Catalog.MISSIONS.size() - 1):
			_declined_races.pop_front()
	return roll_race_offer()


func accept_race() -> bool:
	if race_offer.is_empty():
		return false
	if start(str(race_offer["id"])):
		race_offer = {}
		return true
	return false


# ------------------------------------------------------------------- execução

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
	carrying_changed.emit(false)
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
			if stage == 0:
				return "Retire o pedido na %s e toque em COLETAR  (%s)" % [poi_names.get(active["from"], active["from"]), t]
			return "Entregue na %s (app Entregas)  (%s)" % [poi_names.get(active["to"], active["to"]), t]
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
		"wheelie":
			if float(bike.wheelie_time) >= float(active["target"]):
				_complete()
		"checkpoints":
			if _flat_distance(_tracked_pos(), objective_pos()) < CHECKPOINT_RADIUS:
				stage += 1
				if stage >= (active["points"] as Array).size():
					_complete()
	_update_marker()


func _complete() -> void:
	_finished = true
	var m := active.duplicate(true)
	var reward: int = state.claim_reward(str(m["id"]), _run_id, int(m["reward"]))
	if m["type"] == "delivery":
		state.record_stat("delivery", reward)
		session_deliveries += 1
	else:
		state.record_stat("race", reward)
		session_races += 1
	active = {}
	_update_marker()
	carrying_changed.emit(false)
	completed.emit(m, reward)


func _fail(reason: String) -> void:
	_finished = true
	var m := active.duplicate(true)
	active = {}
	_update_marker()
	carrying_changed.emit(false)
	failed.emit(m, reason)


func _update_marker() -> void:
	var visible_now := has_objective_pos()
	_marker.visible = visible_now
	if visible_now:
		_marker.global_position = objective_pos() + Vector3(0, 15, 0)


func _ids_with_prefix(prefix: String) -> Array:
	var out: Array = []
	for id in poi_positions:
		if str(id).begins_with(prefix):
			out.append(str(id))
	out.sort()
	return out


func _tracked_pos() -> Vector3:
	var who: Node3D = tracker if is_instance_valid(tracker) else bike
	return who.global_position


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
