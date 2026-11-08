extends "res://scripts/ui/phone/phone_app.gd"
## App Configurações, no estilo de um smartphone: categorias com ícone, título e descrição,
## e subpáginas com opções. Todas as opções alteram sistemas reais do jogo e são salvas.

const CATEGORIES := [
	{"id": "graficos", "title": "GRÁFICOS", "desc": "Qualidade, resolução, distância, sombras e efeitos", "color": Color(0.2, 0.45, 0.9), "icon": "screen"},
	{"id": "controles", "title": "CONTROLES", "desc": "Botões, tamanho, sensibilidade e opacidade", "color": Color(0.85, 0.5, 0.15), "icon": "stick"},
	{"id": "audio", "title": "ÁUDIO", "desc": "Volume geral, motor e efeitos, ambiente", "color": Color(0.2, 0.65, 0.4), "icon": "speaker"},
	{"id": "jogabilidade", "title": "JOGABILIDADE", "desc": "Trânsito, dia e noite, câmera e minimapa", "color": Color(0.6, 0.3, 0.8), "icon": "flag"},
]

var _box: VBoxContainer
var _page: String = ""


func setup() -> void:
	_box = make_root()
	_build()


func on_open() -> void:
	_page = ""
	_build()


func go_back() -> bool:
	if _page == "":
		return false
	_page = ""
	_build()
	return true


## Usado também pelos testes: altera uma opção como se o jogador a tivesse mudado.
func set_value(key: String, value: Variant) -> void:
	_assign(key, value)
	main.apply_settings_change(true)


func _build() -> void:
	clear(_box)
	if _page == "":
		title(_box, "Configurações")
		for cat in CATEGORIES:
			_category_button(cat)
	else:
		_build_page()


func _category_button(cat: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(448, 108)
	b.add_theme_stylebox_override("normal", Kit.style(Color(0.12, 0.14, 0.22, 0.95), 16))
	b.add_theme_stylebox_override("hover", Kit.style(Color(0.16, 0.18, 0.28, 0.95), 16))
	b.add_theme_stylebox_override("pressed", Kit.style(Color(0.22, 0.25, 0.38, 0.95), 16))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_open_page.bind(str(cat["id"])))
	_box.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -10.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(68, 68)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, str(cat["icon"]), cat["color"]))
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var t := Label.new()
	t.text = str(cat["title"])
	t.add_theme_font_size_override("font_size", 28)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(t)
	var d := Label.new()
	d.text = str(cat["desc"])
	d.add_theme_font_size_override("font_size", 17)
	d.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(280, 0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(d)
	var arrow := Label.new()
	arrow.text = ">"
	arrow.add_theme_font_size_override("font_size", 36)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)


func _draw_icon(ic: Control, kind: String, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(16)
	ic.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(68, 68)))
	var w := Color.WHITE
	match kind:
		"screen":
			ic.draw_rect(Rect2(14, 16, 40, 28), w, false, 3.0)
			ic.draw_line(Vector2(34, 44), Vector2(34, 52), w, 3.0)
			ic.draw_line(Vector2(24, 52), Vector2(44, 52), w, 3.0)
			ic.draw_colored_polygon(PackedVector2Array([Vector2(18, 40), Vector2(28, 26), Vector2(36, 36), Vector2(42, 30), Vector2(50, 40)]), w)
		"stick":
			ic.draw_arc(Vector2(34, 44), 14.0, 0.0, TAU, 20, w, 3.0)
			ic.draw_line(Vector2(34, 44), Vector2(26, 24), w, 4.0)
			ic.draw_circle(Vector2(25, 21), 7.0, w)
		"speaker":
			ic.draw_colored_polygon(PackedVector2Array([Vector2(14, 28), Vector2(24, 28), Vector2(36, 17), Vector2(36, 51), Vector2(24, 40), Vector2(14, 40)]), w)
			ic.draw_arc(Vector2(38, 34), 9.0, -0.9, 0.9, 10, w, 3.0)
			ic.draw_arc(Vector2(38, 34), 16.0, -0.9, 0.9, 10, w, 3.0)
		"flag":
			ic.draw_line(Vector2(22, 14), Vector2(22, 54), w, 4.0)
			ic.draw_colored_polygon(PackedVector2Array([Vector2(24, 16), Vector2(52, 26), Vector2(24, 38)]), w)


func _open_page(id: String) -> void:
	Kit._click()
	_page = id
	_build()


func _build_page() -> void:
	match _page:
		"graficos":
			title(_box, "Gráficos")
			_opt("quality", "Qualidade", ["Automática", "Baixa", "Média", "Alta"], [0, 1, 2, 3])
			_opt("render_scale", "Resolução", ["Automática", "100%", "85%", "70%", "50%"], [0.0, 1.0, 0.85, 0.7, 0.5])
			_opt("view_distance", "Distância de renderização", ["Automática", "Curta (100 m)", "Média (180 m)", "Longa (280 m)"], [0, 100, 180, 280])
			_opt("shadows", "Sombras", ["Automáticas", "Desligadas", "Ligadas"], [0, 1, 2])
			_tog("effects", "Efeitos visuais (névoa, fumaça, luzes)")
		"controles":
			title(_box, "Controles")
			_action("REPOSICIONAR BOTÕES", _reposition)
			_slider("control_scale", "Tamanho dos controles", 0.7, 1.4, 0.05, func(v): return "%d%%" % int(v * 100.0))
			_slider("steer_sensitivity", "Sensibilidade da direção", 0.4, 2.0, 0.05, func(v): return "%.2f" % v)
			_slider("camera_sensitivity", "Sensibilidade da câmera", 0.5, 2.0, 0.05, func(v): return "%.2f" % v)
			_slider("control_opacity", "Opacidade dos controles", 0.15, 1.0, 0.05, func(v): return "%d%%" % int(v * 100.0))
		"audio":
			title(_box, "Áudio")
			_slider("volume_master", "Volume geral", 0.0, 1.0, 0.05, func(v): return "%d%%" % int(v * 100.0))
			_slider("volume_sfx", "Motor e efeitos sonoros", 0.0, 1.0, 0.05, func(v): return "%d%%" % int(v * 100.0))
			_slider("volume_ambient", "Ambiente da cidade", 0.0, 1.0, 0.05, func(v): return "%d%%" % int(v * 100.0))
			text(_box, "O jogo ainda não tem música; os sons são gerados por código.", 18, Color(0.7, 0.74, 0.82))
		"jogabilidade":
			title(_box, "Jogabilidade")
			_slider("traffic_density", "Densidade do trânsito", 0.0, 30.0, 1.0, func(v): return "%d carros" % int(v))
			_slider("day_minutes", "Duração do dia", 0.0, 30.0, 1.0, func(v): return ("%d min" % int(v)) if v > 0.5 else "tempo parado")
			_tog("camera_first_person", "Câmera em primeira pessoa")
			_tog("show_minimap", "Mostrar minimapa")


# ------------------------------------------------------------------- widgets

func _slider(key: String, label: String, min_v: float, max_v: float, step: float, fmt: Callable) -> void:
	var value := float(main.settings.get(key))
	var lbl := text(_box, label + ": " + str(fmt.call(value)), 22, Color.WHITE)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(440, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(_on_slider.bind(key, label, fmt, lbl))
	s.drag_ended.connect(_on_drag_end)
	_box.add_child(s)


func _on_slider(v: float, key: String, label: String, fmt: Callable, lbl: Label) -> void:
	lbl.text = label + ": " + str(fmt.call(v))
	_assign(key, v)
	main.apply_settings_change(false)


func _on_drag_end(_changed: bool) -> void:
	main.apply_settings_change(true)


func _opt(key: String, label: String, names: Array, values: Array) -> void:
	var idx := _nearest(values, main.settings.get(key))
	var b := Kit.button(_box, "%s: %s" % [label, names[idx]], func(): pass, Color(0.16, 0.2, 0.3), Vector2(440, 60), 22)
	b.pressed.connect(_cycle.bind(b, key, label, names, values))


func _cycle(b: Button, key: String, label: String, names: Array, values: Array) -> void:
	var idx := (_nearest(values, main.settings.get(key)) + 1) % values.size()
	_assign(key, values[idx])
	b.text = "%s: %s" % [label, names[idx]]
	main.apply_settings_change(true)


func _tog(key: String, label: String) -> void:
	var on: bool = bool(main.settings.get(key))
	var b := Kit.button(_box, "%s: %s" % [label, "LIGADO" if on else "DESLIGADO"], func(): pass, Color(0.16, 0.2, 0.3), Vector2(440, 60), 22)
	b.pressed.connect(_toggle.bind(b, key, label))


func _toggle(b: Button, key: String, label: String) -> void:
	var now := not bool(main.settings.get(key))
	_assign(key, now)
	b.text = "%s: %s" % [label, "LIGADO" if now else "DESLIGADO"]
	main.apply_settings_change(true)


func _action(label: String, cb: Callable) -> void:
	Kit.button(_box, label, cb, Color(0.2, 0.35, 0.5), Vector2(440, 60), 24)


func _reposition() -> void:
	main.begin_edit_controls_from_phone()


func _nearest(values: Array, current: Variant) -> int:
	var best := 0
	var best_d := INF
	for i in values.size():
		var d := absf(float(values[i]) - float(current))
		if d < best_d:
			best_d = d
			best = i
	return best


func _assign(key: String, v: Variant) -> void:
	var cur: Variant = main.settings.get(key)
	if typeof(cur) == TYPE_BOOL:
		main.settings.set(key, bool(v))
	elif typeof(cur) == TYPE_INT:
		main.settings.set(key, int(round(float(v))))
	else:
		main.settings.set(key, float(v))
