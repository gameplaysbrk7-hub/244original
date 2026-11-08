extends Control
## Base dos aplicativos do celular. As interfaces são desenhadas dentro da tela do aparelho
## (em pixels do aparelho, 472 de largura útil), nunca como menus externos.

const Kit := preload("res://scripts/ui/ui_kit.gd")
const GameState := preload("res://scripts/save/game_state.gd")

var main: Node        # o jogo
var phone: Control    # o celular


func setup() -> void:
	pass


func on_open() -> void:
	pass


## Chamado cerca de 4 vezes por segundo enquanto o app está aberto.
func refresh() -> void:
	pass


## Botão "voltar" do celular: devolva true se tratou (ex.: voltou de uma subpágina).
func go_back() -> bool:
	return false


## Pilha vertical padrão do app (com margem), preenchendo a área do app.
func make_root() -> VBoxContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


func clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func title(parent: Control, txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 38)
	l.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(l)
	return l


func text(parent: Control, txt: String, font_size: int = 22, color: Color = Color(0.85, 0.9, 0.95)) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


## Cartão com fundo arredondado; devolve a pilha interna.
func card(parent: Control, color: Color = Color(0.1, 0.12, 0.2, 0.95)) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.style(color, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return box


func button_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row


## Texto de tempo mm:ss.
static func clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


static func compass(d: Vector2) -> String:
	var deg := fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)
	var names := ["Norte", "Nordeste", "Leste", "Sudeste", "Sul", "Sudoeste", "Oeste", "Noroeste"]
	return names[int(round(deg / 45.0)) % 8]
