extends Node
## Estado persistente do jogador: dinheiro, motos, personalizações e missões concluídas.
## Salvamento em JSON com checksum, gravação atômica (.tmp) e cópia de segurança (.bak).
## Arquivo ausente ou corrompido nunca derruba o jogo: cai no backup ou no estado padrão.

const BikeCatalog := preload("res://scripts/vehicle/bike_catalog.gd")

signal money_changed(amount: int)

const SAVE_VERSION := 1
const START_MONEY := 500
const REPEAT_PERCENT := 0.4

var save_path: String = "user://save.json"
var money: int = START_MONEY
var selected_bike: String = "starter"
var unlocked_bikes: Array = ["starter"]
var owned_items: Array = []
var bike_custom: Dictionary = {}   # id da moto -> {chave: valor}; cores como "#rrggbb"
var completed: Dictionary = {}     # id da missão -> vezes concluída
var _claimed_runs: Dictionary = {} # execuções de missão que já pagaram (só em memória)


static func format_money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return "R$ " + out


func reset_defaults() -> void:
	money = START_MONEY
	selected_bike = "starter"
	unlocked_bikes = ["starter"]
	owned_items = []
	bike_custom = {}
	completed = {}


# ------------------------------------------------------------------ economia

func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)


func spend(price: int) -> bool:
	if price < 0 or money < price:
		return false
	money -= price
	money_changed.emit(money)
	return true


func buy_bike(id: String, price: int) -> bool:
	if unlocked_bikes.has(id) or not BikeCatalog.has_bike(id):
		return false
	if not spend(price):
		return false
	unlocked_bikes.append(id)
	save_game()
	return true


func buy_item(id: String, price: int) -> bool:
	if owned_items.has(id):
		return false
	if not spend(price):
		return false
	owned_items.append(id)
	save_game()
	return true


## Paga a recompensa de uma execução de missão uma única vez.
## Primeira conclusão paga o valor cheio; repetições pagam REPEAT_PERCENT.
func claim_reward(mission_id: String, run_id: String, base: int) -> int:
	if _claimed_runs.has(run_id):
		return 0
	_claimed_runs[run_id] = true
	var times := int(completed.get(mission_id, 0))
	var amount := base if times == 0 else int(round(base * REPEAT_PERCENT))
	completed[mission_id] = times + 1
	add_money(amount)
	save_game()
	return amount


# ------------------------------------------------------------ personalização

func get_custom(bike_id: String, base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	var stored: Dictionary = bike_custom.get(bike_id, {})
	for k in stored:
		if not out.has(k):
			continue
		var v: Variant = stored[k]
		if typeof(out[k]) == TYPE_COLOR:
			if typeof(v) == TYPE_STRING and Color.html_is_valid(v):
				out[k] = Color.html(v)
		elif typeof(out[k]) == TYPE_INT and typeof(v) == TYPE_FLOAT:
			out[k] = int(v)
		elif typeof(out[k]) == typeof(v):
			out[k] = v
	return out


func set_custom_value(bike_id: String, key: String, value: Variant) -> void:
	var d: Dictionary = bike_custom.get(bike_id, {})
	d[key] = value.to_html(false) if typeof(value) == TYPE_COLOR else value
	bike_custom[bike_id] = d


# ---------------------------------------------------------------- persistência

func to_data() -> Dictionary:
	return {
		"money": money,
		"selected_bike": selected_bike,
		"unlocked_bikes": unlocked_bikes,
		"owned_items": owned_items,
		"bike_custom": bike_custom,
		"completed": completed,
	}


func save_game() -> bool:
	var body := JSON.stringify(to_data())
	var wrapper := {"version": SAVE_VERSION, "check": body.sha256_text(), "data": body}
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(wrapper))
	f.close()
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(save_path):
		dir.copy(save_path, save_path + ".bak")
	return dir.rename(tmp, save_path) == OK


func load_game() -> bool:
	for path in [save_path, save_path + ".bak"]:
		var d := _read_file(path)
		if not d.is_empty() and _apply_data(d):
			return true
	reset_defaults()
	return false


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var wrapper: Variant = json.data
	if typeof(wrapper) != TYPE_DICTIONARY:
		return {}
	var body: Variant = wrapper.get("data", null)
	var check: Variant = wrapper.get("check", null)
	if typeof(body) != TYPE_STRING or typeof(check) != TYPE_STRING:
		return {}
	if String(body).sha256_text() != String(check):
		return {}
	var inner := JSON.new()
	if inner.parse(String(body)) != OK or typeof(inner.data) != TYPE_DICTIONARY:
		return {}
	return inner.data


func _apply_data(d: Dictionary) -> bool:
	var unlocked: Array = []
	var u: Variant = d.get("unlocked_bikes", [])
	if typeof(u) == TYPE_ARRAY:
		for id in u:
			if typeof(id) == TYPE_STRING and BikeCatalog.has_bike(id) and not unlocked.has(id):
				unlocked.append(id)
	if not unlocked.has("starter"):
		unlocked.append("starter")
	var sel: Variant = d.get("selected_bike", "starter")
	selected_bike = String(sel) if typeof(sel) == TYPE_STRING and unlocked.has(sel) else "starter"
	unlocked_bikes = unlocked
	money = maxi(0, _int(d, "money", START_MONEY))
	var items: Variant = d.get("owned_items", [])
	owned_items = []
	if typeof(items) == TYPE_ARRAY:
		for it in items:
			if typeof(it) == TYPE_STRING and not BikeCatalog.item_entry(it).is_empty() and not owned_items.has(it):
				owned_items.append(it)
	var cust: Variant = d.get("bike_custom", {})
	bike_custom = cust if typeof(cust) == TYPE_DICTIONARY else {}
	var comp: Variant = d.get("completed", {})
	completed = {}
	if typeof(comp) == TYPE_DICTIONARY:
		for k in comp:
			if typeof(comp[k]) == TYPE_FLOAT or typeof(comp[k]) == TYPE_INT:
				completed[str(k)] = maxi(0, int(comp[k]))
	return true


static func _int(d: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return fallback
