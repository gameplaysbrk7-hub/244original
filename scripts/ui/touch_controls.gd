extends Control
## Controles de toque com multitoque real. Todos os botões são funcionais.
## Toque fora dos botões: esquerda = direção (joystick flutuante), resto = câmera.

signal camera_drag(relative: Vector2)
signal camera_zoom(pixels: float)
signal camera_drag_ended
signal camera_reset_pressed
signal respawn_pressed
signal pause_pressed
signal view_toggle_pressed

var steer: float = 0.0
var throttle: float = 0.0
var brake_front: bool = false
var brake_rear: bool = false
var wheelie: bool = false
var balance: bool = false
var drift: bool = false
var ui_opacity: float = 0.55
var steer_sensitivity: float = 1.0

var _touches: Dictionary = {}   # índice do dedo -> função ("stick", "throttle", ..., "camera")
var _cam_pos: Dictionary = {}   # índice do dedo -> última posição (câmera)
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_pos: Vector2 = Vector2.ZERO
var _throttle_held: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _unit() -> float:
	var s := get_viewport_rect().size
	return minf(s.x, s.y)


func _layout() -> Dictionary:
	var s := get_viewport_rect().size
	var r := _unit() * 0.12
	return {
		"throttle": {"c": Vector2(s.x - 1.7 * r, s.y - 1.7 * r), "r": 1.3 * r, "t": "ACEL", "col": Color(0.3, 1.0, 0.45)},
		"brake_front": {"c": Vector2(s.x - 4.0 * r, s.y - 1.2 * r), "r": 0.8 * r, "t": "F.DIANT", "col": Color(1.0, 0.4, 0.35)},
		"brake_rear": {"c": Vector2(s.x - 3.6 * r, s.y - 3.0 * r), "r": 0.8 * r, "t": "F.TRAS", "col": Color(1.0, 0.55, 0.3)},
		"balance": {"c": Vector2(s.x - 5.4 * r, s.y - 2.6 * r), "r": 0.75 * r, "t": "EQUIL", "col": Color(0.4, 0.9, 1.0)},
		"drift": {"c": Vector2(s.x - 6.6 * r, s.y - 0.9 * r), "r": 0.7 * r, "t": "DERRAP", "col": Color(0.9, 0.9, 0.5)},
		"view": {"c": Vector2(s.x - 4.4 * r, 0.8 * r), "r": 0.5 * r, "t": "VISÃO", "col": Color(0.6, 1.0, 0.8)},
		"pause": {"c": Vector2(s.x - 0.8 * r, 0.8 * r), "r": 0.5 * r, "t": "PAUSA", "col": Color.WHITE},
		"camera_reset": {"c": Vector2(s.x - 2.0 * r, 0.8 * r), "r": 0.5 * r, "t": "CÂM", "col": Color(0.5, 0.8, 1.0)},
		"respawn": {"c": Vector2(s.x - 3.2 * r, 0.8 * r), "r": 0.5 * r, "t": "VOLTAR", "col": Color(0.8, 0.6, 1.0)},
	}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_on_drag(d.index, d.position, d.relative)


func _on_press(idx: int, pos: Vector2) -> void:
	var lay := _layout()
	for id in lay:
		var b: Dictionary = lay[id]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		if pos.distance_to(c) <= r * 1.15:
			_touches[idx] = id
			match id:
				"throttle":
					throttle = maxf(throttle, 0.3)
				"pause":
					pause_pressed.emit()
				"camera_reset":
					camera_reset_pressed.emit()
				"respawn":
					respawn_pressed.emit()
				"view":
					view_toggle_pressed.emit()
			_recompute()
			return
	var s := get_viewport_rect().size
	if pos.x < s.x * 0.45 and pos.y > s.y * 0.3 and not _touches.values().has("stick"):
		_touches[idx] = "stick"
		_stick_origin = pos
		_stick_pos = pos
		return
	_touches[idx] = "camera"
	_cam_pos[idx] = pos


func _on_release(idx: int) -> void:
	if not _touches.has(idx):
		return
	var kind: String = _touches[idx]
	_touches.erase(idx)
	_cam_pos.erase(idx)
	if kind == "camera":
		camera_drag_ended.emit()
	_recompute()


func _on_drag(idx: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(idx):
		return
	var kind: String = _touches[idx]
	if kind == "stick":
		var radius := _unit() * 0.15
		var delta := pos - _stick_origin
		if delta.length() > radius:
			_stick_origin = pos - delta.normalized() * radius
			delta = pos - _stick_origin
		_stick_pos = pos
		var x := clampf(delta.x / radius, -1.0, 1.0)
		steer = clampf(signf(x) * pow(absf(x), 1.4) * steer_sensitivity, -1.0, 1.0)
		# Puxar o analógico para trás (dedo para baixo) liga o grau; com histerese
		var pull := clampf(delta.y / radius, 0.0, 1.0)
		if wheelie:
			wheelie = pull > 0.35
		else:
			wheelie = pull > 0.55
	elif kind == "camera":
		var prev: Vector2 = _cam_pos.get(idx, pos)
		if _cam_pos.size() >= 2:
			var other_idx: int = -1
			for k in _cam_pos:
				if k != idx:
					other_idx = k
					break
			if other_idx != -1:
				var other: Vector2 = _cam_pos[other_idx]
				camera_zoom.emit(prev.distance_to(other) - pos.distance_to(other))
		else:
			camera_drag.emit(relative)
		_cam_pos[idx] = pos


func _recompute() -> void:
	var v := _touches.values()
	brake_front = v.has("brake_front")
	brake_rear = v.has("brake_rear")
	balance = v.has("balance")
	drift = v.has("drift")
	_throttle_held = v.has("throttle")
	if not v.has("stick"):
		steer = 0.0
		wheelie = false


func _release_all() -> void:
	_touches.clear()
	_cam_pos.clear()
	_recompute()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _process(delta: float) -> void:
	if _throttle_held:
		throttle = move_toward(throttle, 1.0, 2.2 * delta)
	else:
		throttle = move_toward(throttle, 0.0, 6.0 * delta)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var held := _touches.values()
	var lay := _layout()
	for id in lay:
		var b: Dictionary = lay[id]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var col: Color = b["col"]
		var down := held.has(id)
		var fill := col
		fill.a = ui_opacity * (0.75 if down else 0.3)
		draw_circle(c, r, fill)
		var edge := col
		edge.a = minf(1.0, ui_opacity + 0.25)
		draw_arc(c, r, 0.0, TAU, 40, edge, 4.0)
		var fs := int(r * 0.38)
		draw_string(font, c + Vector2(-r, fs * 0.35), b["t"], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, minf(1.0, ui_opacity + 0.35)))

	var s := get_viewport_rect().size
	var u := _unit()
	var sr := u * 0.15
	var active := held.has("stick")
	var base := _stick_origin if active else Vector2(2.0 * u * 0.12 + sr * 0.2, s.y - 1.8 * u * 0.12)
	draw_arc(base, sr, 0.0, TAU, 48, Color(1, 1, 1, ui_opacity * 0.8), 4.0)
	draw_circle(base, sr, Color(1, 1, 1, ui_opacity * 0.12))
	var knob := _stick_pos if active else base
	var knob_col := Color(1.0, 0.8, 0.2) if wheelie else Color(1, 1, 1)
	draw_circle(knob, sr * 0.38, Color(knob_col.r, knob_col.g, knob_col.b, ui_opacity * (0.9 if active else 0.4)))
	if wheelie:
		draw_string(font, knob + Vector2(-sr, -sr * 0.55), "GRAU!", HORIZONTAL_ALIGNMENT_CENTER, sr * 2.0, 30, Color(1.0, 0.85, 0.2))
	if not active:
		draw_string(font, base + Vector2(-sr, sr + 28.0), "DIREÇÃO", HORIZONTAL_ALIGNMENT_CENTER, sr * 2.0, 22, Color(1, 1, 1, ui_opacity))
		draw_string(font, base + Vector2(-sr, sr + 54.0), "puxe p/ trás = GRAU", HORIZONTAL_ALIGNMENT_CENTER, sr * 2.0, 18, Color(1, 0.85, 0.3, ui_opacity))
