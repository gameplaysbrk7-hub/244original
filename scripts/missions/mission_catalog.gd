extends RefCounted
## Missões do jogo. Tipos: "delivery" (pegar o pedido numa hamburgueria e entregar numa casa),
## "wheelie" (grau longo), "checkpoints" (percurso com pontos em ordem).
## Tempos em segundos, recompensa em R$.

const MISSIONS := [
	{"id": "entrega_1", "type": "delivery", "title": "Primeiro pedido",
		"desc": "Pegue o pedido na HAMBURGUERIA 1 e entregue na CASA 1.",
		"from": "hamburgueria_1", "to": "casa_1", "time": 120.0, "reward": 300},
	{"id": "entrega_2", "type": "delivery", "title": "Pedido do almoço",
		"desc": "Pegue o pedido na HAMBURGUERIA 2 e entregue na CASA 3.",
		"from": "hamburgueria_2", "to": "casa_3", "time": 130.0, "reward": 400},
	{"id": "entrega_3", "type": "delivery", "title": "Lanche da tarde",
		"desc": "Pegue o pedido na HAMBURGUERIA 3 e entregue na CASA 5.",
		"from": "hamburgueria_3", "to": "casa_5", "time": 140.0, "reward": 450},
	{"id": "entrega_4", "type": "delivery", "title": "Entrega do outro lado",
		"desc": "Pegue o pedido na HAMBURGUERIA 1 e entregue na CASA 7.",
		"from": "hamburgueria_1", "to": "casa_7", "time": 160.0, "reward": 550},
	{"id": "entrega_5", "type": "delivery", "title": "Pedido da família",
		"desc": "Pegue o pedido na HAMBURGUERIA 2 e entregue na CASA 2.",
		"from": "hamburgueria_2", "to": "casa_2", "time": 180.0, "reward": 650},
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
