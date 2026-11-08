extends Control
## Minimapa (norte para cima) centrado na moto: ruas, pontos de interesse e trânsito.

var zoom_m: float = 130.0        # metros mostrados na largura
var fixed_center: bool = false   # true: mapa grande centrado na cidade
var show_names: bool = false     # true: escreve o nome dos pontos de interesse
var clamp_to_world: bool = false # true: a vista segue o jogador mas não passa das bordas da cidade

var bike: Node3D
var traffic: Node
var missions: Node
var info: Dictionary = {}


func _init() -> void:
	size = Vector2(190, 190)
	custom_minimum_size = size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _center() -> Vector3:
	if fixed_center:
		return Vector3.ZERO
	var c := bike.global_position
	if clamp_to_world:
		var world_half: float = float(info.get("half", 100.0))
		var lim_x := maxf(0.0, world_half - zoom_m * 0.5)
		var lim_z := maxf(0.0, world_half - zoom_m * size.y / size.x * 0.5)
		c.x = clampf(c.x, -lim_x, lim_x)
		c.z = clampf(c.z, -lim_z, lim_z)
	return c


## Posição da seta do jogador no mapa (usa a posição real do personagem no mundo).
func player_map_pos() -> Vector2:
	return _w2m(bike.global_position)


func _w2m(p: Vector3) -> Vector2:
	var c := _center()
	return size * 0.5 + Vector2(p.x - c.x, p.z - c.z) * (size.x / zoom_m)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.1, 0.65))
	if bike == null or info.is_empty():
		return
	var s := size.x / zoom_m
	var half: float = info["half"]
	var rw: float = info["road_w"]
	var road_col := Color(0.5, 0.5, 0.56)
	for r in info["roads"]:
		var rr: float = r
		draw_rect(Rect2(_w2m(Vector3(rr - rw * 0.5, 0, -half)), Vector2(rw * s, half * 2.0 * s)), road_col)
		draw_rect(Rect2(_w2m(Vector3(-half, 0, rr - rw * 0.5)), Vector2(half * 2.0 * s, rw * s)), road_col)
	draw_rect(Rect2(_w2m(Vector3(-half, 0, -half)), Vector2(half * 2.0 * s, half * 2.0 * s)), Color(1, 1, 1, 0.4), false, 2.0)

	var font := ThemeDB.fallback_font
	for p in info["pois"]:
		var m := _w2m(p["pos"])
		draw_circle(m, 7.0, p["color"])
		draw_string(font, m + Vector2(-4, 5), p["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
		if show_names:
			draw_string(font, m + Vector2(10, 5), p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if traffic != null:
		for car in traffic.cars:
			draw_circle(_w2m(car.position), 2.5, Color(0.85, 0.85, 0.85))

	if missions != null and missions.has_objective_pos():
		var mp := _w2m(missions.objective_pos())
		var q := Vector2(clampf(mp.x, 10.0, size.x - 10.0), clampf(mp.y, 10.0, size.y - 10.0))
		var diamond := PackedVector2Array([q + Vector2(0, -10), q + Vector2(10, 0), q + Vector2(0, 10), q + Vector2(-10, 0)])
		draw_colored_polygon(diamond, Color(1.0, 0.85, 0.1))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color.BLACK, 2.0)
	var yaw := bike.global_rotation.y
	var f := Vector2(-sin(yaw), -cos(yaw))
	var perp := Vector2(-f.y, f.x)
	var c := player_map_pos()
	var k := 1.0 if size.x < 300.0 else 1.7
	draw_colored_polygon(PackedVector2Array([c + f * 11.0 * k, c - f * 6.0 * k + perp * 6.0 * k, c - f * 6.0 * k - perp * 6.0 * k]), Color(1.0, 0.9, 0.2))
	draw_polyline(PackedVector2Array([c + f * 11.0 * k, c - f * 6.0 * k + perp * 6.0 * k, c - f * 6.0 * k - perp * 6.0 * k, c + f * 11.0 * k]), Color.BLACK, 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)
