extends "res://scripts/ui/phone/phone_app.gd"
## App Entregas (estilo aplicativo de delivery): uma oferta por vez com ACEITAR e RECUSAR,
## painel de desempenho e, no endereço do cliente, o botão ENTREGAR (a entrega não é automática).

const GOLD := Color(1.0, 0.85, 0.3)

var _box: VBoxContainer
var _sig: String = ""
var _time_label: Label
var _dist_label: Label


func setup() -> void:
	_box = make_root()


func on_open() -> void:
	_sig = ""
	refresh()


func refresh() -> void:
	var m = main.missions
	var pos: Vector3 = main.player_position()
	if m.delivery_offer.is_empty() and not m.is_active():
		m.roll_delivery_offer(pos)
	var st: Dictionary = main.state.stats
	var sig := "%s|%d|%s|%s|%s|%d|%d|%d" % [m.is_delivery_active(), m.stage, m.can_deliver(pos), str(m.delivery_offer.get("id", "")), m.is_active(), int(st["deliveries"]), int(st["delivery_earned"]), m.session_deliveries]
	if sig != _sig:
		_sig = sig
		_rebuild()
	_update_dynamic(m, pos)


func _rebuild() -> void:
	var m = main.missions
	clear(_box)
	_time_label = null
	_dist_label = null
	title(_box, "Entregas")
	var st: Dictionary = main.state.stats
	var stats := card(_box)
	text(stats, "Entregas concluídas: %d" % int(st["deliveries"]), 24, Color.WHITE)
	text(stats, "Total recebido: %s" % GameState.format_money(int(st["delivery_earned"])), 24, GOLD)
	text(stats, "Nesta sessão: %d" % m.session_deliveries, 22)
	if m.is_delivery_active():
		_build_active(m)
	elif m.is_active():
		var busy := card(_box)
		text(busy, "Termine a missão em andamento (app Corridas) para receber novas ofertas.", 22)
	else:
		_build_offer(m)


func _build_offer(m) -> void:
	var o: Dictionary = m.delivery_offer
	var c := card(_box, Color(0.1, 0.2, 0.14, 0.95))
	text(c, "NOVA OFERTA", 20, Color(0.6, 1.0, 0.7))
	if o.is_empty():
		text(c, "Sem ofertas no momento.", 24)
		return
	text(c, "Retirada: %s" % o["from_name"], 26, Color.WHITE)
	text(c, "Destino: %s" % o["to_name"], 26, Color.WHITE)
	text(c, "Até a retirada: %d m" % int(o["pickup"]), 22)
	text(c, "Trajeto: %d m" % int(o["route"]), 22)
	text(c, "Tempo: %s" % clock(float(o["time"])), 22)
	text(c, "Pagamento: %s" % GameState.format_money(int(o["reward"])), 30, GOLD)
	var row := button_row(_box)
	Kit.button(row, "ACEITAR", _accept, Color(0.15, 0.5, 0.25), Vector2(214, 64), 26)
	Kit.button(row, "RECUSAR", _decline, Color(0.5, 0.18, 0.15), Vector2(214, 64), 26)


func _build_active(m) -> void:
	var a: Dictionary = m.active
	var c := card(_box, Color(0.12, 0.15, 0.26, 0.95))
	text(c, "ENTREGA EM ANDAMENTO", 20, Color(0.6, 0.85, 1.0))
	text(c, "De %s para %s" % [a["from_name"], a["to_name"]], 24, Color.WHITE)
	if m.stage == 0:
		text(c, "1. Vá até a %s e toque em COLETAR." % a["from_name"], 22, Color(1.0, 0.8, 0.4))
	else:
		text(c, "2. Leve o pedido até a %s." % a["to_name"], 22, Color(1.0, 0.8, 0.4))
	_dist_label = text(c, "", 24, Color.WHITE)
	_time_label = text(c, "", 24, GOLD)
	text(c, "Pagamento: %s" % GameState.format_money(int(a["reward"])), 28, GOLD)
	if m.stage == 1:
		if m.can_deliver(main.player_position()):
			Kit.button(_box, "ENTREGAR", _deliver, Color(0.15, 0.5, 0.25), Vector2(440, 72), 32)
		else:
			text(_box, "Chegue ao endereço do cliente para entregar.", 20, Color(0.75, 0.78, 0.85))
	Kit.button(_box, "CANCELAR ENTREGA", _cancel, Color(0.5, 0.18, 0.15), Vector2(440, 52), 22)


func _update_dynamic(m, pos: Vector3) -> void:
	if _time_label == null or not m.is_delivery_active():
		return
	_time_label.text = "Tempo restante: %s" % clock(m.time_left)
	var target: Vector3 = m.objective_pos()
	var d := Vector2(target.x - pos.x, target.z - pos.z)
	_dist_label.text = "Distância: %d m   Direção: %s" % [int(d.length()), compass(d)]


func _accept() -> void:
	main.missions.accept_delivery()
	_sig = ""
	refresh()


func _decline() -> void:
	main.missions.decline_delivery(main.player_position())
	_sig = ""
	refresh()


func _deliver() -> void:
	main.missions.deliver(main.player_position())
	_sig = ""
	refresh()


func _cancel() -> void:
	main.missions.cancel()
	_sig = ""
	refresh()
