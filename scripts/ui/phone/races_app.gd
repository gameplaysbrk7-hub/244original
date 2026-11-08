extends "res://scripts/ui/phone/phone_app.gd"
## App Corridas: mesma estrutura do app de entregas, com ofertas, estatísticas e ganhos próprios.

const GOLD := Color(1.0, 0.85, 0.3)

var _box: VBoxContainer
var _sig: String = ""
var _time_label: Label


func setup() -> void:
	_box = make_root()


func on_open() -> void:
	_sig = ""
	refresh()


func refresh() -> void:
	var m = main.missions
	if m.race_offer.is_empty() and not m.is_active():
		m.roll_race_offer()
	var st: Dictionary = main.state.stats
	var sig := "%s|%s|%s|%d|%d|%d" % [m.is_active(), str(m.active.get("id", "")), str(m.race_offer.get("id", "")), int(st["races"]), int(st["race_earned"]), m.session_races]
	if sig != _sig:
		_sig = sig
		_rebuild()
	if _time_label != null and m.is_active():
		_time_label.text = "Tempo restante: %s" % clock(m.time_left)


func _rebuild() -> void:
	var m = main.missions
	clear(_box)
	_time_label = null
	title(_box, "Corridas")
	var st: Dictionary = main.state.stats
	var stats := card(_box)
	text(stats, "Corridas concluídas: %d" % int(st["races"]), 24, Color.WHITE)
	text(stats, "Total recebido: %s" % GameState.format_money(int(st["race_earned"])), 24, GOLD)
	text(stats, "Nesta sessão: %d" % m.session_races, 22)
	if m.is_active() and str(m.active.get("type", "")) != "delivery":
		var a: Dictionary = m.active
		var c := card(_box, Color(0.12, 0.15, 0.26, 0.95))
		text(c, "CORRIDA EM ANDAMENTO", 20, Color(0.6, 0.85, 1.0))
		text(c, str(a["title"]), 28, Color.WHITE)
		text(c, m.objective_text(), 20, Color(1.0, 0.8, 0.4))
		_time_label = text(c, "", 24, GOLD)
		text(c, "Pagamento: %s" % GameState.format_money(int(a["reward"])), 28, GOLD)
		Kit.button(_box, "CANCELAR CORRIDA", _cancel, Color(0.5, 0.18, 0.15), Vector2(440, 52), 22)
	elif m.is_active():
		var busy := card(_box)
		text(busy, "Termine a entrega em andamento (app Entregas) para receber ofertas de corrida.", 22)
	else:
		_build_offer(m)


func _build_offer(m) -> void:
	var o: Dictionary = m.race_offer
	var c := card(_box, Color(0.18, 0.12, 0.22, 0.95))
	text(c, "NOVA CORRIDA", 20, Color(0.85, 0.7, 1.0))
	if o.is_empty():
		text(c, "Sem ofertas no momento.", 24)
		return
	text(c, str(o["title"]), 28, Color.WHITE)
	text(c, str(o["desc"]), 21)
	text(c, "Tempo: %s" % clock(float(o["time"])), 22)
	text(c, "Pagamento: %s" % GameState.format_money(int(o["reward"])), 30, GOLD)
	var row := button_row(_box)
	Kit.button(row, "ACEITAR", _accept, Color(0.15, 0.5, 0.25), Vector2(214, 64), 26)
	Kit.button(row, "RECUSAR", _decline, Color(0.5, 0.18, 0.15), Vector2(214, 64), 26)


func _accept() -> void:
	main.missions.accept_race()
	_sig = ""
	refresh()


func _decline() -> void:
	main.missions.decline_race()
	_sig = ""
	refresh()


func _cancel() -> void:
	main.missions.cancel()
	_sig = ""
	refresh()
