extends RefCounted
## Missões do jogo. Tipos: "delivery" (pegar e entregar), "wheelie" (grau longo),
## "checkpoints" (percurso com pontos em ordem). Tempos em segundos, recompensa em R$.

const MISSIONS := [
	{"id": "entrega_oficina", "type": "delivery", "title": "Peça para a oficina",
		"desc": "Pegue a encomenda na GARAGEM e leve até a OFICINA.",
		"from": "garagem", "to": "oficina", "time": 70.0, "reward": 250},
	{"id": "entrega_norte", "type": "delivery", "title": "Entrega no extremo oeste",
		"desc": "Pegue no POSTO e entregue no ponto ENTREGA 1.",
		"from": "posto", "to": "entrega_1", "time": 100.0, "reward": 450},
	{"id": "entrega_leste", "type": "delivery", "title": "Pedido urgente",
		"desc": "Pegue na OFICINA e entregue no ponto ENTREGA 2.",
		"from": "oficina", "to": "entrega_2", "time": 90.0, "reward": 400},
	{"id": "entrega_sul", "type": "delivery", "title": "Rota longa",
		"desc": "Pegue na GARAGEM e entregue no ponto ENTREGA 4.",
		"from": "garagem", "to": "entrega_4", "time": 110.0, "reward": 500},
	{"id": "grau_5", "type": "wheelie", "title": "Desafio de grau: 5 s",
		"desc": "Mantenha o grau por 5 segundos seguidos.",
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
