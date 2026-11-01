extends Control
## Celular do jogador: sobe da borda inferior da tela até ficar todo visível do lado direito.
## Os ícones fazem parte da imagem; as áreas de toque são calculadas sobre ela.
## Fecha no pequeno "X" do canto superior direito do celular.

signal app_pressed(app: String)
signal closed

const BASE := Vector2(555, 1041)        # tamanho da imagem do celular (pixels)
const APPS := {
	"mapa": Rect2(51, 169, 140, 164),
	"entregas": Rect2(207, 169, 140, 164),
	"corridas": Rect2(365, 169, 140, 164),
	"configuracoes": Rect2(52, 368, 140, 164),
	"ligacoes": Rect2(209, 368, 140, 164),
	"camera": Rect2(367, 368, 140, 164),
}
const CLOSE_CENTER := Vector2(496, 112)
const CLOSE_RADIUS := 20.0
const SLIDE_TIME := 0.35

var shown: float = 0.0   # 0 escondido, 1 totalmente visível

var _want_open: bool = false
var _tex: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_tex = load("res://assets/ui/phone.png")


func open() -> void:
	visible = true
	_want_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func close() -> void:
	_want_open = false


## Esconde sem animação (usado ao trocar de tela).
func hide_now() -> void:
	_want_open = false
	shown = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return _want_open


## Retângulo do celular na tela agora (sobe da borda de baixo até o lado direito).
func phone_rect() -> Rect2:
	var h := size.y * 0.94
	var w := h * BASE.x / BASE.y
	var final_pos := Vector2(size.x - w - size.x * 0.02, (size.y - h) * 0.5)
	var e := smoothstep(0.0, 1.0, shown)
	return Rect2(Vector2(final_pos.x, lerpf(size.y + 8.0, final_pos.y, e)), Vector2(w, h))


func to_screen(local: Vector2) -> Vector2:
	var r := phone_rect()
	return r.position + local / BASE * r.size


func app_center(app: String) -> Vector2:
	var rect: Rect2 = APPS[app]
	return to_screen(rect.position + rect.size * 0.5)


func close_center() -> Vector2:
	return to_screen(CLOSE_CENTER)


func _process(delta: float) -> void:
	if not visible:
		return
	shown = move_toward(shown, 1.0 if _want_open else 0.0, delta / SLIDE_TIME)
	if not _want_open and shown <= 0.0:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		closed.emit()
		return
	queue_redraw()


func _draw() -> void:
	var e := smoothstep(0.0, 1.0, shown)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35 * e))
	var r := phone_rect()
	draw_texture_rect(_tex, r, false)
	# Pequeno "X" para fechar, no canto superior direito do celular
	var c := to_screen(CLOSE_CENTER)
	var rad := CLOSE_RADIUS / BASE.x * r.size.x
	draw_circle(c, rad, Color(0, 0, 0, 0.55))
	draw_arc(c, rad, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
	var k := rad * 0.42
	draw_line(c + Vector2(-k, -k), c + Vector2(k, k), Color.WHITE, 3.0)
	draw_line(c + Vector2(-k, k), c + Vector2(k, -k), Color.WHITE, 3.0)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not _want_open or shown < 0.95:
		return
	var r := phone_rect()
	var local := (mb.position - r.position) / r.size * BASE
	if local.distance_to(CLOSE_CENTER) <= CLOSE_RADIUS * 2.0:
		close()
		return
	for app in APPS:
		if (APPS[app] as Rect2).has_point(local):
			app_pressed.emit(str(app))
			return
