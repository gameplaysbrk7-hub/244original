extends Control
## Menus por toque: tela inicial, pausa, missões e configurações.

const GameState := preload("res://scripts/save/game_state.gd")
const Catalog := preload("res://scripts/missions/mission_catalog.gd")
const Kit := preload("res://scripts/ui/ui_kit.gd")

signal play_pressed
signal resume_pressed
signal garage_pressed
signal restart_pressed
signal to_title_pressed
signal quit_pressed
signal mission_start_requested(id: String)
signal mission_cancel_requested
signal settings_changed

const PER_PAGE := 4
const GOLD := Color(1.0, 0.85, 0.3)

var state: Node
var missions: Node
var settings: Node
var in_game: bool = false

var _box: VBoxContainer
var _current: String = "title"
var _page: int = 0
var _status: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.style(Color(0.07, 0.08, 0.11, 0.95), 24))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	margin.add_child(_box)


func open(panel_name: String) -> void:
	_current = panel_name
	visible = true
	_rebuild()


func close() -> void:
	visible = false


func set_status(text: String) -> void:
	_status = text
	if visible:
		_rebuild()


func _rebuild() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	match _current:
		"title":
			_build_title()
		"pause":
			_build_pause()
		"missions":
			_build_missions()
		"settings":
			_build_settings()
	if _status != "":
		Kit.label(_box, _status, 24, Color(1.0, 0.6, 0.5))
		_status = ""


func _build_title() -> void:
	Kit.label(_box, "MOTO GRAU", 68, GOLD)
	Kit.label(_box, "Simulador de motos urbano", 24, Color(0.8, 0.85, 0.9))
	Kit.label(_box, GameState.format_money(state.money), 34, GOLD)
	Kit.button(_box, "JOGAR", func(): play_pressed.emit(), Color(0.15, 0.45, 0.25))
	Kit.button(_box, "GARAGEM", func(): garage_pressed.emit())
	Kit.button(_box, "CONFIGURAÇÕES", func(): open("settings"))
	Kit.button(_box, "SAIR", func(): quit_pressed.emit(), Color(0.4, 0.15, 0.15))


func _build_pause() -> void:
	Kit.label(_box, "PAUSADO", 56, GOLD)
	Kit.label(_box, GameState.format_money(state.money), 32, GOLD)
	Kit.button(_box, "CONTINUAR", func(): resume_pressed.emit(), Color(0.15, 0.45, 0.25))
	Kit.button(_box, "MISSÕES", func(): open("missions"))
	Kit.button(_box, "GARAGEM", func(): garage_pressed.emit())
	Kit.button(_box, "CONFIGURAÇÕES", func(): open("settings"))
	Kit.button(_box, "REINICIAR", func(): restart_pressed.emit())
	Kit.button(_box, "MENU INICIAL", func(): to_title_pressed.emit(), Color(0.4, 0.15, 0.15))


func _build_missions() -> void:
	var list: Array = Catalog.MISSIONS
	var pages := maxi(1, int(ceil(list.size() / float(PER_PAGE))))
	_page = clampi(_page, 0, pages - 1)
	Kit.label(_box, "MISSÕES   " + GameState.format_money(state.money), 40, GOLD)
	var busy: bool = missions.is_active()
	if busy:
		Kit.label(_box, "Em andamento: " + str(missions.active.get("title", "")), 26, Color(0.6, 1.0, 0.8))
		Kit.button(_box, "CANCELAR MISSÃO", func(): mission_cancel_requested.emit(), Color(0.45, 0.2, 0.15))
	for i in range(_page * PER_PAGE, mini(list.size(), (_page + 1) * PER_PAGE)):
		var m: Dictionary = list[i]
		var done := int(state.completed.get(str(m["id"]), 0))
		var tag := "  (feita; repetição paga 40%)" if done > 0 else ""
		var txt := "%s  -  %s%s\n%s" % [m["title"], GameState.format_money(int(m["reward"])), tag, m["desc"]]
		var b := Kit.button(_box, txt, _start_mission.bind(str(m["id"])), Color(0.16, 0.22, 0.32), Vector2(760, 84), 22)
		b.disabled = busy
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	_box.add_child(nav)
	var prev := Kit.button(nav, "<", _change_page.bind(-1), Color(0.2, 0.2, 0.28), Vector2(120, 60), 32)
	prev.disabled = _page == 0
	Kit.label(nav, "%d / %d" % [_page + 1, pages], 26)
	var nxt := Kit.button(nav, ">", _change_page.bind(1), Color(0.2, 0.2, 0.28), Vector2(120, 60), 32)
	nxt.disabled = _page >= pages - 1
	Kit.button(_box, "VOLTAR", func(): open("pause"), Color(0.25, 0.25, 0.3), Vector2(460, 64), 30)


func _build_settings() -> void:
	Kit.label(_box, "CONFIGURAÇÕES", 48, GOLD)
	_slider("steer", 0.4, 2.0, 0.05, settings.steer_sensitivity)
	_slider("opacity", 0.15, 1.0, 0.05, settings.control_opacity)
	_slider("traffic", 0.0, 30.0, 1.0, float(settings.traffic_density))
	Kit.label(_box, "Reposicionar controles e volume: em breve", 20, Color(0.7, 0.72, 0.78))
	Kit.button(_box, "VOLTAR", func(): open("pause" if in_game else "title"), Color(0.25, 0.25, 0.3))


func _slider(which: String, min_v: float, max_v: float, step: float, value: float) -> void:
	var lbl := Kit.label(_box, _slider_text(which, value), 26)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(520, 48)
	s.value_changed.connect(_on_slider.bind(which, lbl))
	_box.add_child(s)


func _slider_text(which: String, v: float) -> String:
	match which:
		"steer":
			return "Sensibilidade da direção: %.2f" % v
		"opacity":
			return "Opacidade dos controles: %d%%" % int(v * 100.0)
	return "Densidade do trânsito: %d carros" % int(v)


func _on_slider(v: float, which: String, lbl: Label) -> void:
	lbl.text = _slider_text(which, v)
	match which:
		"steer":
			settings.steer_sensitivity = v
		"opacity":
			settings.control_opacity = v
		"traffic":
			settings.traffic_density = int(v)
	settings_changed.emit()


func _start_mission(id: String) -> void:
	mission_start_requested.emit(id)


func _change_page(delta: int) -> void:
	_page += delta
	_rebuild()
