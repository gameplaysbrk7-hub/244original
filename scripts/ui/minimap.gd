extends Control
## Minimapa (norte para cima) centrado na moto: ruas, pontos de interesse e trânsito.

const ZOOM_M := 130.0   # metros mostrados na largura do minimapa

var bike: Node3D
var traffic: Node
var missions: Node
var info: Dictionary = {}


func _init() -> void:
	size = Vector2(190, 190)
	custom_minimum_size = size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _w2m(p: Vector3) -> Vector2:
	var c := bike.global_position
	return size * 0.5 + Vector2(p.x - c.x, p.z - c.z) * (size.x / ZOOM_M)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.1, 0.65))
	if bike == null or info.is_empty():
		return
	var s := size.x / ZOOM_M
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
	var c := size * 0.5
	draw_colored_polygon(PackedVector2Array([c + f * 11.0, c - f * 6.0 + perp * 6.0, c - f * 6.0 - perp * 6.0]), Color(1.0, 0.9, 0.2))
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)
