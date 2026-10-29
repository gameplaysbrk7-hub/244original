extends CanvasLayer
## HUD: velocidade, saldo, objetivo da missão, grau/stoppie, equilíbrio, minimapa e mensagens.

const BalanceMeter := preload("res://scripts/ui/balance_meter.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")
const GameState := preload("res://scripts/save/game_state.gd")

var _speed: Label
var _money: Label
var _objective: Label
var _wheelie: Label
var _msg: Label
var _meter: Control
var _minimap: Control
var _msg_time: float = 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_speed = _label(54, false)
	_speed.position = Vector2(24, 8)
	_money = _label(36, false)
	_money.position = Vector2(24, 66)
	_money.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_objective = _label(28, false)
	_objective.position = Vector2(24, 110)
	_objective.custom_minimum_size = Vector2(430, 0)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	_wheelie = _label(38, false)
	_wheelie.position = Vector2(24, 190)
	_msg = _label(54, true)
	_msg.offset_top = 215.0
	_meter = BalanceMeter.new()
	_meter.position = Vector2(24, 245)
	_meter.visible = false
	add_child(_meter)


func _label(font_size: int, full: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if full:
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


func setup_minimap(bike: Node3D, info: Dictionary, traffic: Node, missions: Node) -> void:
	_minimap = Minimap.new()
	_minimap.bike = bike
	_minimap.info = info
	_minimap.traffic = traffic
	_minimap.missions = missions
	add_child(_minimap)


func set_money(amount: int) -> void:
	_money.text = GameState.format_money(amount)


func set_objective(text: String) -> void:
	_objective.text = text
	_objective.visible = text != ""


func update_hud(bike: Node) -> void:
	_speed.text = "%d km/h" % int(bike.speed * 3.6)
	if bike.pitch > 0.1:
		_wheelie.text = "GRAU %.1fs  +%d" % [bike.wheelie_time, int(bike.wheelie_score)]
		_wheelie.visible = true
	elif bike.stoppie > 0.1:
		_wheelie.text = "STOPPIE %.1fs  +%d" % [bike.stoppie_time, int(bike.stoppie_score)]
		_wheelie.visible = true
	else:
		_wheelie.visible = false
	_meter.visible = bike.pitch > 0.02
	_meter.value = bike.pitch / bike.profile.wheelie_max_pitch
	_meter.queue_redraw()


func show_message(text: String) -> void:
	_msg.text = text
	_msg_time = 3.0


func show_wheelie_result(duration: float, score: int) -> void:
	show_message("GRAU! %.1fs  +%d pontos" % [duration, score])


func show_stoppie_result(duration: float, score: int) -> void:
	show_message("STOPPIE! %.1fs  +%d pontos" % [duration, score])


func _process(delta: float) -> void:
	if _minimap != null:
		_minimap.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 95.0, 10.0)
		_minimap.queue_redraw()
	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			_msg.text = ""
