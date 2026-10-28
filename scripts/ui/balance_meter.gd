extends Control
## Indicador vertical de equilíbrio do grau (0 = roda no chão, 1 = limite de queda).

var value: float = 0.0
var sweet_min: float = 0.2
var sweet_max: float = 0.5


func _init() -> void:
	custom_minimum_size = Vector2(36, 260)
	size = Vector2(36, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var h := size.y
	draw_rect(Rect2(0, 0, size.x, h), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(0, h * (1.0 - sweet_max), size.x, h * (sweet_max - sweet_min)), Color(0.2, 0.9, 0.3, 0.5))
	draw_rect(Rect2(0, 0, size.x, h * 0.15), Color(1.0, 0.2, 0.2, 0.5))
	var y := h * (1.0 - clampf(value, 0.0, 1.0))
	draw_rect(Rect2(-4, y - 4, size.x + 8, 8), Color.WHITE)
