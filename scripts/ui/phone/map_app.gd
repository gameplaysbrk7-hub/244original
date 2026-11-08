extends "res://scripts/ui/phone/phone_app.gd"
## App Mapa: ocupa toda a tela do aparelho (que gira 90 graus e se aproxima da câmera).
## O mapa segue o personagem (a pé ou na moto) e a seta amarela mostra a posição e a direção reais.

const Minimap := preload("res://scripts/ui/minimap.gd")

var _map: Control


func setup() -> void:
	# O conteúdo é desenhado na horizontal (840 x 480) e girado 90 graus dentro da área vertical
	# do aparelho: quando o celular gira, o mapa fica em pé para o jogador.
	size = Vector2(840, 480)
	pivot_offset = size * 0.5
	rotation = PI * 0.5
	position = (Vector2(480, 840) - size) * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map = Minimap.new()
	_map.size = size
	_map.custom_minimum_size = size
	_map.zoom_m = 215.0
	_map.clamp_to_world = true
	_map.show_names = true
	_map.info = main.city_info
	_map.traffic = main.traffic
	_map.missions = main.missions
	_map.bike = main.active_player()
	add_child(_map)


func on_open() -> void:
	_map.bike = main.active_player()
	_map.queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		_map.bike = main.active_player()
		_map.queue_redraw()
