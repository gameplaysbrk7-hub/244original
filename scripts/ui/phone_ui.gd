extends Control
## Celular do jogador, integrado à jogabilidade (o mundo continua em tempo real).
## - Sobe da borda inferior até ficar todo visível do lado direito.
## - Tela inicial = imagem original com os ícones; ao abrir um app troca na hora para a imagem
##   de fundo preto, e o app é desenhado DENTRO da tela do aparelho.
## - HOME (círculo da barra de navegação) volta à tela inicial em qualquer app; o triângulo volta
##   uma etapa dentro do app. O pequeno X do canto superior direito fecha o celular.
## - O app Mapa aproxima o celular da câmera e o gira 90 graus (tela cheia, na horizontal).

const AppBase := preload("res://scripts/ui/phone/phone_app.gd")
const MapApp := preload("res://scripts/ui/phone/map_app.gd")
const DeliveriesApp := preload("res://scripts/ui/phone/deliveries_app.gd")
const RacesApp := preload("res://scripts/ui/phone/races_app.gd")
const SettingsApp := preload("res://scripts/ui/phone/settings_app.gd")
const DialerApp := preload("res://scripts/ui/phone/dialer_app.gd")

signal closed
signal action_requested(action: String)

const BASE := Vector2(555, 1041)               # tamanho da imagem do celular (pixels)
const APP_AREA := Rect2(40, 140, 472, 760)     # área dos apps dentro da tela
const MAP_AREA := Rect2(36, 70, 480, 840)      # área do mapa (usada na horizontal)
const HOME_CENTER := Vector2(276, 944)
const BACK_CENTER := Vector2(125, 944)
const NAV_RADIUS := 40.0
const CLOSE_CENTER := Vector2(496, 112)
const CLOSE_RADIUS := 20.0
const SLIDE_TIME := 0.35
const ZOOM_TIME := 0.5
const APPS := {
	"mapa": Rect2(51, 169, 140, 164),
	"entregas": Rect2(207, 169, 140, 164),
	"corridas": Rect2(365, 169, 140, 164),
	"configuracoes": Rect2(52, 368, 140, 164),
	"ligacoes": Rect2(209, 368, 140, 164),
	"camera": Rect2(367, 368, 140, 164),
}

var main: Node             # o jogo (acesso a missões, estado, configurações...)
var shown: float = 0.0     # 0 escondido, 1 totalmente visível
var zoom: float = 0.0      # 0 normal, 1 mapa em tela cheia (girado 90 graus)
var app: String = ""       # app aberto ("" = tela inicial)

var _want_open: bool = false
var _want_zoom: bool = false
var _device: Control
var _tex_rect: TextureRect
var _overlay: Control
var _app_host: Control
var _map_host: Control
var _tex_home: Texture2D
var _tex_app: Texture2D
var _apps: Dictionary = {}
var _refresh_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_tex_home = load("res://assets/ui/phone.png")
	_tex_app = load("res://assets/ui/phone_app.png")

	_device = Control.new()
	_device.size = BASE
	_device.pivot_offset = BASE * 0.5
	_device.mouse_filter = Control.MOUSE_FILTER_STOP
	_device.gui_input.connect(_on_device_input)
	add_child(_device)

	_tex_rect = TextureRect.new()
	_tex_rect.texture = _tex_home
	_tex_rect.size = BASE
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_device.add_child(_tex_rect)

	_app_host = Control.new()
	_app_host.position = APP_AREA.position
	_app_host.size = APP_AREA.size
	_app_host.clip_contents = true
	_app_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_device.add_child(_app_host)

	_map_host = Control.new()
	_map_host.position = MAP_AREA.position
	_map_host.size = MAP_AREA.size
	_map_host.clip_contents = true
	_map_host.mouse_filter = Control.MOUSE_FILTER_IGNORE   # não pode interceptar toques dos outros apps
	_map_host.visible = false
	_device.add_child(_map_host)

	_overlay = Control.new()
	_overlay.size = BASE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_device.add_child(_overlay)


# ------------------------------------------------------------------ controle

func open() -> void:
	visible = true
	_want_open = true
	go_home()


func close() -> void:
	_want_open = false


## Esconde sem animação (pausa, troca de tela, foto).
func hide_now() -> void:
	_want_open = false
	_want_zoom = false
	shown = 0.0
	zoom = 0.0
	visible = false
	go_home()


func is_open() -> bool:
	return _want_open


func go_home() -> void:
	app = ""
	_want_zoom = false
	if _tex_rect != null:
		_tex_rect.texture = _tex_home
	for k in _apps:
		(_apps[k] as Control).visible = false
	if _map_host != null:
		_map_host.visible = false


## HOME dentro de um app: tela inicial instantânea; o mapa desfaz zoom e giro gradualmente.
func go_back() -> void:
	if app == "":
		return
	var node: Control = _apps.get(app)
	if node != null and node.go_back():
		return
	go_home()


func open_app(app_name: String) -> void:
	if app_name == "camera":
		action_requested.emit("camera")
		return
	if not APPS.has(app_name):
		return
	app = app_name
	_tex_rect.texture = _tex_app
	var node := _get_app(app_name)
	for k in _apps:
		(_apps[k] as Control).visible = (k == app_name)
	_want_zoom = app_name == "mapa"
	_map_host.visible = app_name == "mapa"
	node.on_open()


func current_app() -> Control:
	return _apps.get(app)


func _get_app(app_name: String) -> Control:
	if _apps.has(app_name):
		return _apps[app_name]
	var scripts := {"mapa": MapApp, "entregas": DeliveriesApp, "corridas": RacesApp, "configuracoes": SettingsApp, "ligacoes": DialerApp}
	var node: Control = scripts[app_name].new()
	node.main = main
	node.phone = self
	(_map_host if app_name == "mapa" else _app_host).add_child(node)
	node.setup()
	_apps[app_name] = node
	return node


## Retângulo do aparelho na tela (para bloquear os toques do jogo por baixo dele).
func screen_rect() -> Rect2:
	if not visible or _device == null:
		return Rect2()
	var t := _device.get_global_transform()
	var rect := Rect2(t * Vector2.ZERO, Vector2.ZERO)
	for p in [t * Vector2(BASE.x, 0.0), t * BASE, t * Vector2(0.0, BASE.y)]:
		rect = rect.expand(p)
	return rect


func device_to_screen(local: Vector2) -> Vector2:
	return _device.get_global_transform() * local


func app_center(app_name: String) -> Vector2:
	var r: Rect2 = APPS[app_name]
	return r.position + r.size * 0.5


# ------------------------------------------------------------------ entrada

func _on_device_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_device.accept_event()
	if not _want_open or shown < 0.95:
		return
	var p := mb.position
	if zoom < 0.2 and p.distance_to(CLOSE_CENTER) <= CLOSE_RADIUS * 2.0:
		close()
		return
	if p.distance_to(HOME_CENTER) <= NAV_RADIUS:
		go_back_home()
		return
	if p.distance_to(BACK_CENTER) <= NAV_RADIUS:
		go_back()
		return
	if app == "":
		for k in APPS:
			if (APPS[k] as Rect2).has_point(p):
				open_app(str(k))
				return


## Botão HOME: sempre volta à tela inicial, em qualquer aplicativo.
func go_back_home() -> void:
	go_home()


# ---------------------------------------------------------------- animação

func _process(delta: float) -> void:
	if not visible:
		return
	shown = move_toward(shown, 1.0 if _want_open else 0.0, delta / SLIDE_TIME)
	zoom = move_toward(zoom, 1.0 if (_want_zoom and _want_open) else 0.0, delta / ZOOM_TIME)
	if not _want_open and shown <= 0.0:
		visible = false
		closed.emit()
		return
	_update_transform()
	if _apps.has("mapa"):
		(_apps["mapa"] as Control).modulate.a = clampf((zoom - 0.7) / 0.3, 0.0, 1.0)
	_refresh_timer += delta
	if _refresh_timer >= 0.25:
		_refresh_timer = 0.0
		var node: Control = _apps.get(app)
		if node != null:
			node.refresh()
	_overlay.queue_redraw()
	queue_redraw()


func _update_transform() -> void:
	var s := size
	var h0 := s.y * 0.94
	var sc0 := h0 / BASE.y
	var w0 := BASE.x * sc0
	var slide := smoothstep(0.0, 1.0, shown)
	var center0 := Vector2(s.x - w0 * 0.5 - s.x * 0.02, lerpf(s.y + h0 * 0.5 + 8.0, s.y * 0.5, slide))
	var sc1 := minf(s.x / BASE.y, s.y / BASE.x) * 0.97
	var z := smoothstep(0.0, 1.0, zoom)
	var center := center0.lerp(s * 0.5, z)
	var sc := lerpf(sc0, sc1, z)
	_device.pivot_offset = BASE * 0.5
	_device.scale = Vector2(sc, sc)
	_device.rotation = lerpf(0.0, -PI * 0.5, z)
	_device.position = center - BASE * 0.5


func _draw() -> void:
	var e := smoothstep(0.0, 1.0, shown)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, lerpf(0.12, 0.6, smoothstep(0.0, 1.0, zoom)) * e))


func _draw_overlay() -> void:
	if zoom > 0.2:
		return
	# Pequeno "X" para fechar o celular (canto superior direito)
	_overlay.draw_circle(CLOSE_CENTER, CLOSE_RADIUS, Color(0, 0, 0, 0.55))
	_overlay.draw_arc(CLOSE_CENTER, CLOSE_RADIUS, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
	var k := CLOSE_RADIUS * 0.42
	_overlay.draw_line(CLOSE_CENTER + Vector2(-k, -k), CLOSE_CENTER + Vector2(k, k), Color.WHITE, 3.0)
	_overlay.draw_line(CLOSE_CENTER + Vector2(-k, k), CLOSE_CENTER + Vector2(k, -k), Color.WHITE, 3.0)
