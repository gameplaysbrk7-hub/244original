extends RefCounted
## Missões do menu: "wheelie" (grau longo) e "checkpoints" (percurso com pontos em ordem).
## As entregas ("delivery") não ficam no menu: nascem sorteadas nas hamburguerias (veja make_delivery).
## Tempos em segundos, recompensa em R$.

const MISSIONS := [
	{"id": "grau_5", "type": "wheelie", "title": "Desafio de grau: 5 s",
		"desc": "Puxe o analógico para trás e mantenha o grau por 5 segundos.",
		"target": 5.0, "time": 120.0, "reward": 350},
	{"id": "grau_10", "type": "wheelie", "title": "Desafio de grau: 10 s",
		"desc": "Mantenha o grau por 10 segundos seguidos.",
		"target": 10.0, "time": 180.0, "reward": 800},
	{"id": "percurso_centro", "type": "checkpoints", "title": "Circuito do centro",
		"desc": "Passe por todos os pontos, em ordem, antes do tempo acabar.",
		"points": [Vector3(0, 0, 0), Vector3(0, 0, -60), Vector3(60, 0, -60), Vector3(60, 0, 0), Vector3(60, 0, 60), Vector3(0, 0, 60)],
		"time": 75.0, "reward": 600},
	{"id": "percurso_grande", "type": "checkpoints", "title": "Volta completa",
		"desc": "Percorra o contorno da cidade passando por todos os pontos.",
		"points": [Vector3(-60, 0, 60), Vector3(-60, 0, 0), Vector3(-60, 0, -60), Vector3(0, 0, -60), Vector3(60, 0, -60), Vector3(60, 0, 0), Vector3(60, 0, 60), Vector3(0, 0, 60)],
		"time": 115.0, "reward": 1100},
]


static func find(id: String) -> Dictionary:
	for m in MISSIONS:
		if m["id"] == id:
			return m.duplicate(true)
	return {}


## Monta uma oferta de entrega: tempo e pagamento dependem da distância do trajeto (e da retirada).
static func make_delivery(from_id: String, to_id: String, from_name: String, to_name: String, route_dist: float, pickup_dist: float) -> Dictionary:
	var reward := int(round((100.0 + route_dist * 2.5 + pickup_dist * 0.5) / 10.0)) * 10
	return {
		"id": "entrega_%s_%s" % [from_id, to_id],
		"type": "delivery",
		"title": "Entrega para %s" % to_name,
		"desc": "Retire na %s (botão COLETAR) e entregue na %s pelo app Entregas." % [from_name, to_name],
		"from": from_id,
		"to": to_id,
		"from_name": from_name,
		"to_name": to_name,
		"route": route_dist,
		"pickup": pickup_dist,
		"time": 60.0 + (route_dist + pickup_dist) * 0.3,
		"reward": reward,
	}
