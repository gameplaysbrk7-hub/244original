extends Control
## Mapa grande da cidade (app Mapa do celular): ruas, pontos de interesse com nome,
## carros, a posição do jogador e o objetivo da missão.

const Minimap := preload("res://scripts/ui/minimap.gd")
const Kit := preload("res://scripts/ui/ui_kit.gd")

signal closed

var _map: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	Kit.label(box, "MAPA DA CIDADE", 36, Color(1.0, 0.85, 0.3))
	_map = Minimap.new()
	_map.zoom_m = 215.0
	_map.fixed_center = true
	_map.show_names = true
	box.add_child(_map)
	Kit.label(box, "Seta amarela: você  |  Losango amarelo: objetivo da missão", 20, Color(0.85, 0.9, 0.95))
	Kit.button(box, "FECHAR", _close, Color(0.25, 0.25, 0.3), Vector2(360, 56), 28)


func setup(tracked: Node3D, info: Dictionary, traffic: Node, missions: Node) -> void:
	_map.bike = tracked
	_map.info = info
	_map.traffic = traffic
	_map.missions = missions


func set_tracking(node: Node3D) -> void:
	_map.bike = node


func open() -> void:
	var side := minf(get_viewport_rect().size.x, get_viewport_rect().size.y) * 0.66
	_map.custom_minimum_size = Vector2(side, side)
	_map.size = Vector2(side, side)
	visible = true


func close() -> void:
	visible = false


func _close() -> void:
	visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if visible:
		_map.queue_redraw()
