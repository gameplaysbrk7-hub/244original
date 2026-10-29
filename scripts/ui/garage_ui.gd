extends Control
## Garagem: escolher e comprar motos, pintura, peças, adesivos e suspensão.
## Tudo é aplicado ao modelo 3D real da moto (a câmera de vitrine gira ao redor dela).

const GameState := preload("res://scripts/save/game_state.gd")
const BikeCatalog := preload("res://scripts/vehicle/bike_catalog.gd")
const BikeModel := preload("res://scripts/vehicle/bike_model.gd")
const Kit := preload("res://scripts/ui/ui_kit.gd")

signal closed
signal orbit_requested(relative: Vector2)

const GOLD := Color(1.0, 0.85, 0.3)
const COLORS := [
	Color(0.85, 0.12, 0.1), Color(0.95, 0.5, 0.1), Color(0.95, 0.8, 0.1), Color(0.15, 0.65, 0.3),
	Color(0.1, 0.7, 0.75), Color(0.1, 0.3, 0.8), Color(0.5, 0.2, 0.75), Color(0.9, 0.3, 0.6),
	Color(0.95, 0.95, 0.95), Color(0.08, 0.08, 0.1), Color(0.4, 0.4, 0.45), Color(0.75, 0.75, 0.8),
]

var state: Node
var bike: Node3D

var _preview_id: String = "starter"
var _tab: String = "paint"
var _paint_target: String = "body_color"
var _status: String = ""
var _box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(610, 0)
	panel.add_theme_stylebox_override("panel", Kit.style(Color(0.07, 0.08, 0.11, 0.93), 0))
	hbox.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	margin.add_child(_box)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.gui_input.connect(_on_view_input)
	hbox.add_child(spacer)


func open() -> void:
	visible = true
	_preview_id = state.selected_bike
	_tab = "paint"
	_preview(_preview_id)
	_rebuild()


## Fecha sem emitir `closed` e volta a mostrar a moto escolhida.
func close() -> void:
	if visible:
		visible = false
		_preview(state.selected_bike)


func _on_view_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		orbit_requested.emit(motion.relative)


func _preview(id: String) -> void:
	var prof := BikeCatalog.load_profile(id)
	var c: Dictionary = state.get_custom(id, BikeModel.default_custom(prof))
	bike.set_profile(prof, c)


func _custom() -> Dictionary:
	return state.get_custom(_preview_id, BikeModel.default_custom(BikeCatalog.load_profile(_preview_id)))


func _unlocked() -> bool:
	return state.unlocked_bikes.has(_preview_id)


func _rebuild() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	Kit.label(_box, "GARAGEM    " + GameState.format_money(state.money), 40, GOLD)
	var entry := BikeCatalog.bike_entry(_preview_id)
	var prof := BikeCatalog.load_profile(_preview_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	Kit.button(row, "<", _cycle.bind(-1), Color(0.2, 0.2, 0.28), Vector2(90, 64), 32)
	var name_lbl := Kit.label(row, str(entry["name"]), 34)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.button(row, ">", _cycle.bind(1), Color(0.2, 0.2, 0.28), Vector2(90, 64), 32)
	Kit.label(_box, "Vel. máx. %d km/h   Aceleração %.0f   Grau %.1f" % [int(prof.max_speed * 3.6), prof.accel, prof.wheelie_lift], 22, Color(0.8, 0.85, 0.9))
	if _unlocked():
		var in_use: bool = state.selected_bike == _preview_id
		var b := Kit.button(_box, "EM USO" if in_use else "USAR ESTA MOTO", _buy_or_use, Color(0.15, 0.45, 0.25), Vector2(540, 58), 28)
		b.disabled = in_use
		_build_tabs()
	else:
		Kit.button(_box, "COMPRAR  " + GameState.format_money(int(entry["price"])), _buy_or_use, Color(0.5, 0.35, 0.1), Vector2(540, 58), 28)
		Kit.label(_box, "Compre a moto para personalizar.", 24, Color(0.8, 0.85, 0.9))
	if _status != "":
		Kit.label(_box, _status, 24, Color(1.0, 0.6, 0.5))
		_status = ""
	Kit.button(_box, "VOLTAR", _on_back, Color(0.25, 0.25, 0.3), Vector2(540, 58), 28)


func _build_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_box.add_child(tabs)
	for t in [["paint", "PINTURA"], ["parts", "PEÇAS"], ["stickers", "ADESIVOS"], ["susp", "SUSP."]]:
		var col := Color(0.25, 0.4, 0.65) if _tab == t[0] else Color(0.16, 0.2, 0.3)
		Kit.button(tabs, str(t[1]), _set_tab.bind(str(t[0])), col, Vector2(128, 54), 22)
	match _tab:
		"paint":
			_tab_paint()
		"parts":
			_tab_parts()
		"stickers":
			_tab_stickers()
		"susp":
			_tab_susp()


func _tab_paint() -> void:
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 6)
	_box.add_child(sel)
	for t in [["body_color", "Carenagem"], ["frame_color", "Quadro"], ["rim_color", "Rodas"]]:
		var col := Color(0.25, 0.4, 0.65) if _paint_target == t[0] else Color(0.16, 0.2, 0.3)
		Kit.button(sel, str(t[1]), _set_paint_target.bind(str(t[0])), col, Vector2(170, 52), 24)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	for c in COLORS:
		Kit.button(grid, "", _set_value.bind(_paint_target, c), c, Vector2(80, 64), 20)


func _tab_parts() -> void:
	_item_row("Rodas esportivas", "roda_esportiva", "rim_style", 1, 0)
	_item_row("Baú traseiro", "bau", "topcase", true, false)
	_item_row("Escape esportivo", "escape_esportivo", "exhaust", "esportivo", "padrao")
	var mirrors: bool = _custom()["mirrors"]
	Kit.button(_box, "Retrovisores: " + ("LIGADOS" if mirrors else "DESLIGADOS"), _set_value.bind("mirrors", not mirrors), Color(0.16, 0.2, 0.3), Vector2(540, 58), 24)


func _tab_stickers() -> void:
	var cur: String = _custom()["sticker"]
	Kit.button(_box, "Nenhum" + ("  (equipado)" if cur == "nenhum" else ""), _set_value.bind("sticker", "nenhum"), Color(0.16, 0.2, 0.3), Vector2(540, 58), 24)
	_sticker_row("Listras", "adesivo_listras", "listras", cur)
	_sticker_row("Número 77", "adesivo_numero", "numero", cur)


func _tab_susp() -> void:
	var cur := int(_custom()["suspension"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_box.add_child(row)
	var names := ["MACIA", "MÉDIA", "FIRME"]
	for i in 3:
		var col := Color(0.25, 0.4, 0.65) if cur == i else Color(0.16, 0.2, 0.3)
		Kit.button(row, names[i], _set_value.bind("suspension", i), col, Vector2(170, 58), 24)
	Kit.label(_box, "Macia: inclina mais e esterça menos.\nFirme: esterça mais e inclina menos.", 22, Color(0.8, 0.85, 0.9))


func _item_row(label: String, item_id: String, key: String, on_value: Variant, off_value: Variant) -> void:
	var owned: bool = state.owned_items.has(item_id)
	var equipped: bool = _custom()[key] == on_value
	var txt := label
	if not owned:
		txt += "  -  " + GameState.format_money(int(BikeCatalog.item_entry(item_id)["price"]))
	elif equipped:
		txt += "  (equipado - tocar para remover)"
	else:
		txt += "  (tocar para equipar)"
	Kit.button(_box, txt, _toggle_item.bind(item_id, key, on_value, off_value), Color(0.16, 0.2, 0.3), Vector2(540, 58), 22)


func _sticker_row(label: String, item_id: String, value: String, current: String) -> void:
	var owned: bool = state.owned_items.has(item_id)
	var txt := label
	if not owned:
		txt += "  -  " + GameState.format_money(int(BikeCatalog.item_entry(item_id)["price"]))
	elif current == value:
		txt += "  (equipado)"
	Kit.button(_box, txt, _pick_sticker.bind(item_id, value), Color(0.16, 0.2, 0.3), Vector2(540, 58), 24)


# ------------------------------------------------------------------- ações

func _set_tab(t: String) -> void:
	_tab = t
	_rebuild()


func _set_paint_target(t: String) -> void:
	_paint_target = t
	_rebuild()


func _cycle(dir: int) -> void:
	var ids := BikeCatalog.ids()
	var idx := ids.find(_preview_id)
	_preview_id = ids[(idx + dir + ids.size()) % ids.size()]
	_preview(_preview_id)
	_rebuild()


func _buy_or_use() -> void:
	if _unlocked():
		state.selected_bike = _preview_id
		state.save_game()
	else:
		var price := int(BikeCatalog.bike_entry(_preview_id)["price"])
		if state.buy_bike(_preview_id, price):
			state.selected_bike = _preview_id
			state.save_game()
		else:
			_status = "Dinheiro insuficiente."
	_rebuild()


func _set_value(key: String, value: Variant) -> void:
	if not _unlocked():
		return
	state.set_custom_value(_preview_id, key, value)
	bike.apply_customization(_custom())
	state.save_game()
	_rebuild()


func _toggle_item(item_id: String, key: String, on_value: Variant, off_value: Variant) -> void:
	if not state.owned_items.has(item_id):
		if not state.buy_item(item_id, int(BikeCatalog.item_entry(item_id)["price"])):
			_status = "Dinheiro insuficiente."
			_rebuild()
			return
	var now_on: bool = _custom()[key] == on_value
	_set_value(key, off_value if now_on else on_value)


func _pick_sticker(item_id: String, value: String) -> void:
	if not state.owned_items.has(item_id):
		if not state.buy_item(item_id, int(BikeCatalog.item_entry(item_id)["price"])):
			_status = "Dinheiro insuficiente."
			_rebuild()
			return
	_set_value("sticker", value)


func _on_back() -> void:
	close()
	closed.emit()
