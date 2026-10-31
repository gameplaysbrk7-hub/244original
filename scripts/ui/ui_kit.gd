extends RefCounted
## Pequenas ferramentas para montar menus por toque (botões grandes, estilo único).

static var on_click: Callable   # definido pelo jogo para tocar o som de clique


static func _click() -> void:
	if on_click.is_valid():
		on_click.call()


static func style(color: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	return s


static func button(parent: Control, text: String, cb: Callable, color: Color = Color(0.16, 0.2, 0.3), min_size: Vector2 = Vector2(460, 70), font: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_color_override("font_disabled_color", Color(0.62, 0.64, 0.7))
	b.add_theme_stylebox_override("normal", style(color))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", style(color.lightened(0.3)))
	b.add_theme_stylebox_override("disabled", style(color.darkened(0.45)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	b.pressed.connect(_click)
	parent.add_child(b)
	return b


static func label(parent: Control, text: String, size: int = 28, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l
