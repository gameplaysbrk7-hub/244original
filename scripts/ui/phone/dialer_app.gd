extends "res://scripts/ui/phone/phone_app.gd"
## App Telefone: teclado de discador (só visual e sonoro, os números não aparecem) e o contato
## do GUINCHO, que aciona o serviço real do jogo e fecha o celular.

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]


func setup() -> void:
	var box := make_root()
	title(box, "Telefone")
	var label := "GUINCHO  -  %s\nReboca sua moto até você (a pé)" % GameState.format_money(main.TOW_COST)
	Kit.button(box, label, _call_tow, Color(0.55, 0.33, 0.1), Vector2(440, 96), 24)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for k in KEYS:
		var b := Kit.button(grid, k, func(): pass, Color(0.16, 0.18, 0.26), Vector2(138, 86), 40)
		b.pressed.connect(_press.bind(k, b))


func _press(key: String, b: Button) -> void:
	main.audio.play_key(key)
	b.modulate = Color(1.7, 1.7, 1.7)
	create_tween().tween_property(b, "modulate", Color.WHITE, 0.15)


func _call_tow() -> void:
	main.call_tow()
	phone.close()
