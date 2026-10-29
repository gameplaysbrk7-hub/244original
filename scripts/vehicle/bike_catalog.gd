extends RefCounted
## Catálogo de motos e itens de personalização da loja.

const BIKES := [
	{"id": "starter", "name": "Zangão 125", "price": 0, "path": "res://resources/vehicles/starter.tres"},
	{"id": "corisco", "name": "Corisco 160", "price": 5500, "path": "res://resources/vehicles/corisco.tres"},
	{"id": "trovao", "name": "Trovão 250", "price": 9000, "path": "res://resources/vehicles/trovao.tres"},
]

const ITEMS := [
	{"id": "adesivo_listras", "name": "Adesivo: listras", "price": 300},
	{"id": "adesivo_numero", "name": "Adesivo: número 77", "price": 300},
	{"id": "bau", "name": "Baú traseiro", "price": 600},
	{"id": "escape_esportivo", "name": "Escape esportivo", "price": 800},
	{"id": "roda_esportiva", "name": "Rodas esportivas", "price": 700},
]


static func ids() -> Array:
	var out: Array = []
	for e in BIKES:
		out.append(e["id"])
	return out


static func has_bike(id: String) -> bool:
	for e in BIKES:
		if e["id"] == id:
			return true
	return false


static func bike_entry(id: String) -> Dictionary:
	for e in BIKES:
		if e["id"] == id:
			return e.duplicate()
	return {}


static func load_profile(id: String) -> Resource:
	var e := bike_entry(id)
	if e.is_empty():
		e = bike_entry("starter")
	return load(e["path"])


static func item_entry(id: String) -> Dictionary:
	for e in ITEMS:
		if e["id"] == id:
			return e.duplicate()
	return {}
